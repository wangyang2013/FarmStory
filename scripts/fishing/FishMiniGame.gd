class_name FishMiniGame
extends Control
## 钓鱼拉扯小游戏。
##
## 玩法：鱼咬钩后，按住鼠标左键 / 空格收线，松开缓线。
##   - 收线：进度上涨，同时张力上涨；张力到 1.0 会断线。
##   - 松手：张力回落，进度缓慢倒退。
##   - 鱼会周期性发力（挣扎），此时张力涨得更快、进度掉得更快。
##   - 进度到 1.0 成功，掉到 0、断线或超时失败。
##
## 所有数值来自 config/fishing_minigame.json；
## 鱼竿等级、鱼饵、渔具效果来自 config/fishing_tools.json；
## 稀有判定交给 RarityUtil（每次新建 RNG）。
##
## 用法：
##     minigame.finished.connect(_on_fish_finished)
##     minigame.start(fish_def, {"rod_id": "gold_rod", "bait_id": "high_bait", "tackle_id": "strong_line"})

const DB := preload("res://scripts/core/ConfigDB.gd")
const Rarity := preload("res://scripts/core/RarityUtil.gd")
const Quality := preload("res://scripts/core/QualityUtil.gd")

signal finished(success: bool, result: Dictionary)
signal stats_changed(progress: float, tension: float, time_left: float)
signal fish_struggling(active: bool)

const PANEL_SIZE := Vector2(224, 104)

var config: Dictionary = {}

## 时间系统接入时读取此属性：小游戏运行期间暂停游戏内时间。
var pauses_game_time := true

# 本局配置
var fish_def: Dictionary = {}
var rod_id := ""
var rod_tier := 0
var has_high_rod := false
var bait_id := ""
var tackle_id := ""
var is_rain := false
var is_dusk := false

# 本局状态
var progress := 0.0
var tension := 0.0
var time_left := 0.0
var running := false
var reeling := false
var is_fish_pulling := false
var last_result: Dictionary = {}

# 内部
var _difficulty := 1.0
var _reel_speed := 0.22
var _tension_rise := 0.34
var _bait_rare_bonus := 0.0
var _escape_reduction := 0.0
var _auto_reel_progress := 0.0
var _pull_time_left := 0.0
var _next_pull_time := 0.0
var _pull_strength := 0.85
var _rng: RandomNumberGenerator
var _font: Font
var _finished_emitted := false
var _anim_time := 0.0


func _ready() -> void:
	_ensure_config()
	_ensure_font()
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)


# ============================================================
# 启动 / 流程
# ============================================================

## p_options 可用字段：
##   rod_id / rod_tier / has_high_rod
##   bait_id / tackle_id
##   is_rain / is_dusk
##   difficulty_delta / escape_reduction / auto_reel_progress（显式覆盖渔具效果）
func start(p_fish_def: Dictionary, p_options: Dictionary = {}) -> void:
	_ensure_config()
	_ensure_font()
	fish_def = p_fish_def.duplicate(true)

	rod_id = str(p_options.get("rod_id", ""))
	bait_id = str(p_options.get("bait_id", ""))
	tackle_id = str(p_options.get("tackle_id", ""))
	is_rain = bool(p_options.get("is_rain", false))
	is_dusk = bool(p_options.get("is_dusk", false))

	# 鱼竿：来自 fishing_tools.json
	rod_tier = int(p_options.get("rod_tier", 0))
	has_high_rod = bool(p_options.get("has_high_rod", false))
	if not rod_id.is_empty():
		var rod: Dictionary = DB.get_rod(rod_id)
		if not rod.is_empty():
			rod_tier = int(rod.get("tier", rod_tier))
			has_high_rod = bool(rod.get("counts_as_high_rod", has_high_rod))

	# 鱼饵：稀有加成
	_bait_rare_bonus = 0.0
	if not bait_id.is_empty():
		var bait: Dictionary = DB.get_bait(bait_id)
		var bait_effects: Dictionary = bait.get("effects", {})
		_bait_rare_bonus = float(bait_effects.get("rare_bonus", 0.0))

	# 渔具：难度 / 防脱 / 自动收线
	var difficulty_delta := 0.0
	_escape_reduction = 0.0
	_auto_reel_progress = 0.0
	if not tackle_id.is_empty():
		var tackle: Dictionary = DB.get_tackle(tackle_id)
		var tackle_effects: Dictionary = tackle.get("effects", {})
		difficulty_delta = float(tackle_effects.get("minigame_difficulty_delta", 0.0))
		_escape_reduction = clampf(float(tackle_effects.get("escape_reduction", 0.0)), 0.0, 0.9)
		_auto_reel_progress = clampf(float(tackle_effects.get("minigame_auto_progress", 0.0)), 0.0, 1.0)

	# 显式覆盖（便于工具/测试）
	difficulty_delta = float(p_options.get("difficulty_delta", difficulty_delta))
	_escape_reduction = clampf(float(p_options.get("escape_reduction", _escape_reduction)), 0.0, 0.9)
	_auto_reel_progress = clampf(float(p_options.get("auto_reel_progress", _auto_reel_progress)), 0.0, 0.98)

	# 每次开局新建 RNG，不和其他系统共用。
	_rng = RandomNumberGenerator.new()
	var rng_seed := int(p_options.get("rng_seed", -1))
	if rng_seed >= 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()

	# 难度：越重的鱼越难，鱼竿等级提高收线速度。
	var weight_reference := maxf(0.001, float(config.get("weight_reference_max", 30.0)))
	var weight_max := maxf(0.001, float(fish_def.get("weight_max", 1.0)))
	var weight_factor := clampf(log(1.0 + weight_max) / log(1.0 + weight_reference), 0.0, 1.0)
	_difficulty = maxf(
		0.5,
		1.0
		+ weight_factor * float(config.get("weight_difficulty_scale", 0.45))
		+ difficulty_delta
	)

	_reel_speed = float(config.get("reel_progress_per_sec", 0.22)) \
		* (1.0 + float(rod_tier) * float(config.get("rod_reel_bonus_per_tier", 0.03))) \
		/ _difficulty
	_tension_rise = float(config.get("tension_rise_per_sec", 0.34)) * _difficulty

	progress = clampf(
		float(config.get("start_progress", 0.2)) + _auto_reel_progress,
		0.01,
		0.98
	)
	tension = 0.0
	time_left = float(config.get("time_limit", 22.0))
	running = true
	reeling = false
	is_fish_pulling = false
	_pull_time_left = 0.0
	_pull_strength = float(config.get("fish_pull_base_strength", 0.85))
	_next_pull_time = _rng.randf_range(
		float(config.get("fish_pull_min_interval", 1.0)),
		float(config.get("fish_pull_max_interval", 2.5))
	)
	last_result.clear()
	_finished_emitted = false
	visible = true

	if is_inside_tree():
		set_process(true)
	stats_changed.emit(progress, tension, time_left)
	_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	_anim_time += delta
	# 掉帧时限制单帧步长，避免一帧直接断线。
	advance(minf(delta, 0.05), reeling)
	_redraw()


## 推进一帧。public 便于无头测试与回放。
func advance(delta: float, holding: bool) -> void:
	if not running or delta <= 0.0:
		return

	time_left -= delta
	if time_left <= 0.0:
		_finish(false, "timeout")
		return

	if is_fish_pulling:
		_pull_time_left -= delta
		if _pull_time_left <= 0.0:
			is_fish_pulling = false
			fish_struggling.emit(false)
		else:
			tension += _tension_rise * _pull_strength * delta
			progress -= float(config.get("pull_progress_loss", 0.12)) \
				* (1.0 - _escape_reduction) * delta
	else:
		_next_pull_time -= delta
		if _next_pull_time <= 0.0:
			_start_pull()

	if holding:
		progress += _reel_speed * delta
		var pull_multiplier := 1.0
		if is_fish_pulling:
			pull_multiplier = float(config.get("tension_pull_multiplier", 1.35))
		tension += _tension_rise * pull_multiplier * delta
	else:
		tension -= float(config.get("tension_fall_per_sec", 0.22)) * delta
		progress -= float(config.get("idle_progress_decay", 0.05)) \
			* (1.0 - _escape_reduction) * delta

	progress = clampf(progress, 0.0, 1.0)
	tension = clampf(tension, 0.0, 1.2)
	stats_changed.emit(progress, tension, time_left)

	if tension >= 1.0:
		_finish(false, "line_broken")
		return
	if progress >= 1.0:
		_finish(true, "caught")
		return
	if progress <= 0.0:
		_finish(false, "escaped")


func cancel() -> void:
	if running:
		_finish(false, "cancelled")


## 给 TimeSystem 用：是否应暂停游戏内时间。
func is_pausing_game_time() -> bool:
	return running and pauses_game_time


func _start_pull() -> void:
	is_fish_pulling = true
	fish_struggling.emit(true)
	_pull_time_left = _rng.randf_range(
		float(config.get("fish_pull_duration_min", 0.5)),
		float(config.get("fish_pull_duration_max", 1.4))
	)
	_pull_strength = float(config.get("fish_pull_base_strength", 0.85)) \
		* _rng.randf_range(0.8, 1.3) * _difficulty
	_next_pull_time = _rng.randf_range(
		float(config.get("fish_pull_min_interval", 1.0)),
		float(config.get("fish_pull_max_interval", 2.5))
	)


func _finish(success: bool, reason: String) -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	running = false
	reeling = false
	if is_fish_pulling:
		is_fish_pulling = false
		fish_struggling.emit(false)
	if is_inside_tree():
		set_process(false)

	if success:
		last_result = _build_success_result(reason)
	else:
		last_result = {
			"success": false,
			"reason": reason,
			"item_id": str(fish_def.get("id", "")),
		}

	finished.emit(success, last_result)
	_redraw()


func _build_success_result(reason: String) -> Dictionary:
	var rarity := Rarity.roll_fish_rarity(
		has_high_rod,
		is_rain,
		is_dusk,
		fish_def,
		_bait_rare_bonus
	)

	var weight_min := float(fish_def.get("weight_min", 0.01))
	var weight_max := float(fish_def.get("weight_max", 0.1))
	if weight_max < weight_min:
		weight_max = weight_min
	var weight := _rng.randf_range(weight_min, weight_max)
	if bool(rarity.get("is_heavy", false)):
		weight *= float(config.get("heavy_weight_multiplier", 1.25))

	var base_price := int(fish_def.get("base_price", 0))
	var rarity_label := Rarity.fish_rare_label(rarity)
	var quality := Quality.roll_fish_quality(has_high_rod)

	return {
		"success": true,
		"reason": reason,
		"item_id": str(fish_def.get("id", "")),
		"name": str(fish_def.get("name", "")),
		"category": "fish",
		"water_area": str(fish_def.get("water_area", "")),
		"weight": snappedf(weight, 0.01),
		"is_rare_color": bool(rarity.get("is_rare_color", false)),
		"is_giant": bool(rarity.get("is_giant", false)),
		"is_heavy": bool(rarity.get("is_heavy", false)),
		"rare_name": rarity_label,
		"quality": quality,
		"quality_name": Quality.get_quality_name(quality),
		"base_price": base_price,
		"price": Quality.apply_quality_price(
			Rarity.apply_fish_price(base_price, rarity), quality
		),
		"rod_id": rod_id,
		"bait_id": bait_id,
		"tackle_id": tackle_id,
		"time_left": snappedf(maxf(time_left, 0.0), 0.01),
	}


## 给 UI 的一句话结果。
func get_result_text() -> String:
	if last_result.is_empty():
		return ""
	if bool(last_result.get("success", false)):
		var rare_label := str(last_result.get("rare_name", ""))
		var prefix := "✨ " if not rare_label.is_empty() else ""
		var suffix := (" · " + rare_label) if not rare_label.is_empty() else ""
		return "%s钓到了 %s（%.2f kg）%s" % [
			prefix,
			str(last_result.get("name", "")),
			float(last_result.get("weight", 0.0)),
			suffix,
		]
	match str(last_result.get("reason", "")):
		"timeout":
			return "鱼儿溜走了……"
		"line_broken":
			return "鱼线断了！"
		"escaped":
			return "鱼儿挣脱了！"
		"cancelled":
			return "收竿了。"
		_:
			return "没有钓到鱼。"


# ============================================================
# 输入
# ============================================================

func _input(event: InputEvent) -> void:
	if not running:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		reeling = event.pressed
		if is_inside_tree():
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenTouch:
		reeling = event.pressed
		return

	if event is InputEventKey:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			reeling = event.pressed
			if is_inside_tree():
				get_viewport().set_input_as_handled()
		elif event.pressed and event.keycode == KEY_ESCAPE:
			cancel()


# ============================================================
# 绘制（占位 UI，正式美术可替换成场景）
# ============================================================

func _ensure_config() -> void:
	if config.is_empty():
		config = DB.get_fishing_minigame()


func _ensure_font() -> void:
	if _font != null:
		return
	# 与全局 UI 共用 Fusion Pixel 像素中文字体。
	_font = PixelTheme.font()


func _panel_size() -> Vector2:
	if size.x >= 200.0 and size.y >= 96.0:
		return size
	return PANEL_SIZE


func _redraw() -> void:
	if is_inside_tree():
		queue_redraw()


func _draw() -> void:
	_ensure_font()
	var panel := _panel_size()
	var width := panel.x
	var height := panel.y

	# 米色面板 + 细边框 + 小圆角，与全局 UI 统一（不做粗木框）。
	draw_style_box(PixelTheme.panel_style(), Rect2(Vector2.ZERO, panel))

	var margin := 8.0
	var title := "上钩了！"
	if not fish_def.is_empty():
		title = "上钩！" + str(fish_def.get("name", ""))
	draw_string(_font, Vector2(margin, 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#3b2a1a"))
	draw_string(
		_font,
		Vector2(margin, 17),
		"剩余 %.1f 秒" % maxf(time_left, 0.0),
		HORIZONTAL_ALIGNMENT_RIGHT,
		width - margin * 2.0,
		12,
		Color("#7d6646")
	)

	# 收线进度
	draw_string(_font, Vector2(margin, 33), "收线进度", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#7d6646"))
	var progress_bar := Rect2(margin, 38, width - margin * 2.0, 10)
	draw_rect(progress_bar, Color("#e0d2b4"), true)
	draw_rect(
		Rect2(progress_bar.position + Vector2(2, 2),
			Vector2((progress_bar.size.x - 4) * progress, progress_bar.size.y - 4)),
		Color("#8fae75"),
		true
	)
	draw_rect(progress_bar, Color("#cbb692"), false, 1.0)
	# 鱼标记：挣扎时左右抖动
	var fish_x := progress_bar.position.x + progress_bar.size.x * progress
	if is_fish_pulling:
		fish_x += sin(_anim_time * 22.0) * 2.0
	var fish_y := progress_bar.position.y + 5.0
	draw_circle(Vector2(fish_x, fish_y), 3.2, Color("#8fadc0"))
	draw_circle(Vector2(fish_x - 4.2, fish_y), 2.0, Color("#8fadc0"))
	draw_circle(Vector2(fish_x + 1.0, fish_y - 1.8), 0.8, Color(0.1, 0.15, 0.2))
	if is_fish_pulling:
		draw_arc(Vector2(fish_x, fish_y), 6.0 + sin(_anim_time * 16.0), 0.0, TAU, 10,
			Color(0.85, 0.95, 0.95, 0.55), 1.0, false)

	# 张力
	draw_string(_font, Vector2(margin, 57), "鱼线张力", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#7d6646"))
	var tension_bar := Rect2(margin, 62, width - margin * 2.0, 10)
	var tension_color := Color("#d8bd84")
	if tension >= 0.75:
		tension_color = Color("#b57f6e")
	draw_rect(tension_bar, Color("#e0d2b4"), true)
	draw_rect(
		Rect2(tension_bar.position + Vector2(2, 2),
			Vector2((tension_bar.size.x - 4) * clampf(tension, 0.0, 1.0), tension_bar.size.y - 4)),
		tension_color,
		true
	)
	draw_rect(tension_bar, Color("#cbb692"), false, 1.0)
	# 张力警戒线
	var warning_x := tension_bar.position.x + tension_bar.size.x * 0.75
	draw_line(
		Vector2(warning_x, tension_bar.position.y),
		Vector2(warning_x, tension_bar.position.y + tension_bar.size.y),
		Color(1, 1, 1, 0.55),
		1.0
	)

	# 状态提示
	var status := "按住收线，松开缓线"
	var status_color := Color("#7d6646")
	if is_fish_pulling:
		status = "鱼在挣扎！快松手"
		status_color = Color("#a8503f")
	elif reeling and tension >= 0.75:
		status = "张力过高！快松手"
		status_color = Color("#b5642f")
	draw_string(_font, Vector2(margin, 82), status, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, status_color)

	# 结果
	if not running and not last_result.is_empty():
		var result_text := get_result_text()
		var result_color := Color("#3f6b2a") if bool(last_result.get("success", false)) else Color("#8f3325")
		draw_string(
			_font,
			Vector2(margin, height - 6),
			result_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			result_color
		)
