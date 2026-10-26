class_name FarmTile
extends Node2D
## 单块农田。
##
## 负责一块 32×32 地块的完整生命周期：
##   锄地 → 播种 → 浇水 → 跨日生长 → 成熟 → 收获（稀有判定）
##
## 所有作物数值（生长天数、季节、售价、是否复收、是否可稀有……）
## 全部来自 config/crops.json，本脚本不写任何作物数据。
##
## 美术：16px 像素单位绘制，暖调低饱和，无粗黑描边，预绘制软阴影。

const DB := preload("res://scripts/core/ConfigDB.gd")
const Rarity := preload("res://scripts/core/RarityUtil.gd")
const Quality := preload("res://scripts/core/QualityUtil.gd")
const Art := preload("res://scripts/art/PixelArt.gd")
const Anim := preload("res://scripts/art/ActionAnimator.gd")
const WIND_SHADER := preload("res://scripts/fx/crop_wind.gdshader")

const TILE_SIZE := 32
const ART_UNITS := 16

signal state_changed
signal crop_harvested(item: Dictionary)
signal crop_withered

## 温室地块忽略季节限制，雨天也自动浇水。
@export var greenhouse := false
## 调试用：画出 16×16 网格。
@export var debug_show_grid := false

var grid_pos := Vector2i.ZERO
var tilled := false
var seed_id := ""
var current_day := 0
var watered := false
var fertilized := false
var ripe := false
var is_rare := false
var rare_type := ""
var is_withered := false
var planted_year := 1
var _water_fx := 0.0
var _fertilize_fx := 0.0
var _fx_time := 0.0


func _ready() -> void:
	position = Vector2(grid_pos) * float(TILE_SIZE)
	var wind := ShaderMaterial.new()
	wind.shader = WIND_SHADER
	wind.set_shader_parameter("phase",
		fmod(float(grid_pos.x * 17 + grid_pos.y * 29), TAU))
	material = wind
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_fx_time += delta
	if ripe and not is_withered:
		queue_redraw()
	else:
		set_process(false)


func setup(p_grid_pos: Vector2i, p_greenhouse := false) -> void:
	grid_pos = p_grid_pos
	greenhouse = p_greenhouse
	position = Vector2(grid_pos) * float(TILE_SIZE)
	_redraw()


# ============================================================
# 查询
# ============================================================

func has_crop() -> bool:
	return not seed_id.is_empty()


func get_crop_def() -> Dictionary:
	return DB.get_crop(seed_id)


func get_grow_day() -> int:
	var definition := get_crop_def()
	return maxi(1, int(definition.get("grow_day", 1)))


func get_crop_name() -> String:
	return str(get_crop_def().get("name", seed_id))


func is_crop_ripe() -> bool:
	return has_crop() and ripe and not is_withered


func can_till() -> bool:
	return not tilled and not has_crop()


func get_growth_ratio() -> float:
	if not has_crop():
		return 0.0
	return clampf(float(current_day) / float(get_grow_day()), 0.0, 1.0)


func get_interaction_label() -> String:
	if is_withered:
		return "枯萎了（用锄头清理）"
	if has_crop():
		if ripe:
			return "收获 · %s" % get_crop_name()
		if not watered:
			return "浇水 · %s（%d/%d）" % [get_crop_name(), current_day, get_grow_day()]
		return "生长中 · %s（%d/%d）" % [get_crop_name(), current_day, get_grow_day()]
	if tilled:
		return "播种"
	return "锄地"


# ============================================================
# 操作
# ============================================================

func till() -> bool:
	if not can_till():
		return false
	tilled = true
	_emit_changed()
	return true


func can_plant(p_seed_id: String, p_season: String) -> Dictionary:
	if not tilled:
		return {"ok": false, "reason": "土地还没有翻过"}
	if has_crop():
		return {"ok": false, "reason": "这块地已经种了东西"}
	if is_withered:
		return {"ok": false, "reason": "需要先清理枯萎的作物"}

	var definition := DB.get_crop(p_seed_id)
	if definition.is_empty():
		return {"ok": false, "reason": "未知的种子：%s" % p_seed_id}

	if greenhouse:
		return {"ok": true, "reason": ""}

	var crop_season := str(definition.get("season", ""))
	if p_season == "winter":
		return {
			"ok": false,
			"reason": "%s只能在温室里种" % str(definition.get("name", p_seed_id)),
		}
	if crop_season != p_season:
		return {
			"ok": false,
			"reason": "%s适合在%s季种植（现在是%s季）" % [
				str(definition.get("name", p_seed_id)),
				DB.season_name(crop_season),
				DB.season_name(p_season),
			],
		}
	return {"ok": true, "reason": ""}


func plant(p_seed_id: String, p_season: String, p_year := 1) -> Dictionary:
	var check := can_plant(p_seed_id, p_season)
	if not bool(check.get("ok", false)):
		return check

	seed_id = p_seed_id
	current_day = 0
	watered = false
	fertilized = false
	ripe = false
	is_rare = false
	rare_type = ""
	is_withered = false
	planted_year = p_year
	set_process(false)

	var definition := get_crop_def()
	_emit_changed()
	return {"ok": true, "reason": "", "crop": definition}


func water() -> bool:
	if not tilled or not has_crop() or is_withered or watered:
		return false
	watered = true
	_emit_changed()
	return true


func fertilize() -> bool:
	if not tilled or not has_crop() or is_withered or fertilized:
		return false
	fertilized = true
	_emit_changed()
	return true


func advance_day(p_season: String, p_weather: String) -> void:
	var effective_watered := watered
	if not greenhouse and (p_weather == "rain" or p_weather == "storm"):
		effective_watered = true

	if has_crop() and not is_withered:
		var definition := get_crop_def()
		if not _season_allows(definition, p_season):
			is_withered = true
			ripe = false
			crop_withered.emit()
		elif not ripe:
			if effective_watered and current_day < get_grow_day():
				current_day += 1
				if current_day >= get_grow_day():
					ripe = true
					set_process(true)
				Anim.grow_pop(self)

	watered = false
	_emit_changed()


func harvest() -> Dictionary:
	if not has_crop():
		return {"ok": false, "reason": "这里没有作物"}
	if is_withered:
		return {"ok": false, "reason": "作物已经枯萎了，只能清理"}
	if not ripe:
		return {"ok": false, "reason": "作物还没有成熟"}

	var definition := get_crop_def()
	var base_price := int(definition.get("base_price", 0))
	var can_rare := bool(definition.get("can_rare", true))

	var rarity := Rarity.roll_crop_rarity(fertilized, can_rare)
	var rarity_type := str(rarity.get("rare_type", ""))

	# 品质（普通 / 银 / 金 / 星光），和稀有是两套独立判定。
	var quality := Quality.roll_crop_quality(fertilized)
	var price := Quality.apply_quality_price(base_price, quality)
	price = int(round(float(price) * float(rarity.get("price_multiplier", 1.0))))

	var item := {
		"item_id": seed_id,
		"name": str(definition.get("name", seed_id)),
		"category": "crop",
		"season": str(definition.get("season", "")),
		"is_flower": bool(definition.get("is_flower", false)),
		"base_price": base_price,
		"is_rare": bool(rarity.get("is_rare", false)),
		"rare_type": rarity_type,
		"rare_name": str(rarity.get("rare_name", "")),
		"quality": quality,
		"quality_name": Quality.get_quality_name(quality),
		"price": price,
		"fertilized": fertilized,
		"planted_year": planted_year,
	}

	is_rare = bool(rarity.get("is_rare", false))
	rare_type = rarity_type

	if bool(definition.get("repeat_harvest", false)):
		# 复收作物：保留成株形态，只重置成熟标记（规范：多次采收后回到"结果"状态）
		current_day = get_grow_day()
		ripe = false
		watered = false
		fertilized = false
	else:
		seed_id = ""
		current_day = 0
		ripe = false
		watered = false
		fertilized = false

	is_rare = false
	rare_type = ""

	crop_harvested.emit(item)
	_emit_changed()
	return {"ok": true, "reason": "", "item": item, "crop": definition}


func clear_crop(keep_tilled := true) -> void:
	seed_id = ""
	current_day = 0
	watered = false
	fertilized = false
	ripe = false
	is_rare = false
	rare_type = ""
	is_withered = false
	if not keep_tilled:
		tilled = false
	_emit_changed()


# ============================================================
# 存档
# ============================================================

func to_save() -> Dictionary:
	return {
		"x": grid_pos.x,
		"y": grid_pos.y,
		"tilled": tilled,
		"seed": seed_id,
		"grow_day": get_grow_day() if has_crop() else 0,
		"current_day": current_day,
		"watered": watered,
		"fertilized": fertilized,
		"ripe": ripe,
		"is_rare": is_rare,
		"rare_type": rare_type,
		"withered": is_withered,
		"planted_year": planted_year,
		"greenhouse": greenhouse,
	}


func from_save(data: Dictionary) -> void:
	grid_pos = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	position = Vector2(grid_pos) * float(TILE_SIZE)
	greenhouse = bool(data.get("greenhouse", greenhouse))
	tilled = bool(data.get("tilled", false))
	watered = bool(data.get("watered", false))
	fertilized = bool(data.get("fertilized", false))
	ripe = bool(data.get("ripe", false))
	is_rare = bool(data.get("is_rare", false))
	rare_type = str(data.get("rare_type", ""))
	is_withered = bool(data.get("withered", false))
	planted_year = maxi(1, int(data.get("planted_year", 1)))

	var saved_seed := str(data.get("seed", ""))
	if saved_seed.is_empty() or DB.get_crop(saved_seed).is_empty():
		seed_id = ""
		current_day = 0
		ripe = false
	else:
		seed_id = saved_seed
		current_day = clampi(int(data.get("current_day", 0)), 0, get_grow_day())
		if current_day >= get_grow_day():
			ripe = true
			set_process(true)

	_redraw()


# ============================================================
# 内部
# ============================================================

func _season_allows(definition: Dictionary, p_season: String) -> bool:
	if greenhouse:
		return true
	var crop_season := str(definition.get("season", ""))
	if crop_season != p_season:
		return false
	if p_season == "winter" and bool(definition.get("greenhouse_only", false)):
		return false
	return true


func _emit_changed() -> void:
	state_changed.emit()
	_redraw()


## 浇水反馈：湿土渐变 + 水花粒子（由 Farm 调用）。
func play_water_fx() -> void:
	_water_fx = 1.0
	_redraw()
	var tween := create_tween()
	tween.tween_property(self, "_water_fx", 0.0, 0.6)


## 施肥反馈：冒星星色点 2 秒（规范要求）。
func play_fertilize_fx() -> void:
	_fertilize_fx = 1.0
	_redraw()
	var tween := create_tween()
	tween.tween_property(self, "_fertilize_fx", 0.0, 2.0)


func _redraw() -> void:
	if is_inside_tree():
		queue_redraw()


# ============================================================
# 16px 像素绘制
# ============================================================

func _draw() -> void:
	if greenhouse:
		Art.rect(self, 0, 0, ART_UNITS, ART_UNITS, Color(0.62, 0.78, 0.78, 0.10))

	if tilled:
		_draw_soil()
	else:
		# 未翻地只留极淡的边界提示，保持画面干净
		Art.rrect(self, 1.0, 1.0, 14.0, 14.0, 1.5, Color(1, 1, 1, 0.045))

	if has_crop():
		_draw_crop()

	if _water_fx > 0.0:
		_draw_water_fx()
	if _fertilize_fx > 0.0:
		_draw_fertilize_fx()

	if debug_show_grid:
		for index in range(1, ART_UNITS):
			Art.vline(self, float(index), 0.0, ART_UNITS, Color(1, 1, 1, 0.10))
			Art.hline(self, 0.0, float(index), ART_UNITS, Color(1, 1, 1, 0.10))


func _draw_water_fx() -> void:
	# 小水滴：向上溅射后落下（用简单的位置插值表现）
	for index in 4:
		var phase := 1.0 - _water_fx
		var x := 4.0 + float(index) * 2.8
		var y := 11.0 - sin(phase * PI) * 4.0 - float(index % 2) * 1.2
		Art.rect(self, x, y, 0.8, 0.8, Color(0.62, 0.78, 0.88, _water_fx * 0.8))


func _draw_fertilize_fx() -> void:
	for index in 3:
		var x := 5.0 + float(index) * 3.2
		var y := 9.0 - (1.0 - _fertilize_fx) * 3.0 - float(index) * 0.8
		Art.rect(self, x, y, 0.8, 0.8, Color(0.92, 0.86, 0.66, _fertilize_fx))


func _draw_soil() -> void:
	var soil := Art.SOIL_WET if watered else Art.SOIL_DRY
	if is_withered:
		soil = Color("#a99a84")

	# 铺满整格，相邻地块连成一片，不出现格子缝
	Art.rect(self, 0, 0, ART_UNITS, ART_UNITS, soil)

	# 表层亮一点、底部略暗：伪俯视的厚度感
	Art.rect(self, 0, 0, ART_UNITS, 3.0, soil.lightened(0.06))
	Art.rect(self, 0, 12.6, ART_UNITS, 3.4, soil.darkened(0.08))

	# 犁沟
	var furrow := soil.darkened(0.10)
	for row in 3:
		Art.hline(self, 1.0, 5.0 + float(row) * 3.2, 14.0, furrow)
		Art.hline(self, 2.0, 5.8 + float(row) * 3.2, 12.0, soil.lightened(0.04))

	# 四边不规则毛边：用草地/泥土的交错像素打散直边
	var edge_dark := soil.darkened(0.14)
	var rng_seed := grid_pos.x * 31 + grid_pos.y * 17
	for index in 8:
		var t := float(index) / 8.0
		var jitter := float((rng_seed + index * 7) % 3)
		var depth := 1.0 + jitter * 0.5
		# 上边
		Art.rect(self, t * ART_UNITS, 0, 1.0, depth, edge_dark)
		# 下边
		Art.rect(self, t * ART_UNITS, ART_UNITS - depth, 1.0, depth, edge_dark)
		# 左右边
		Art.rect(self, 0, t * ART_UNITS, depth, 1.0, edge_dark)
		Art.rect(self, ART_UNITS - depth, t * ART_UNITS, depth, 1.0, edge_dark)

	if fertilized:
		var grain := Color(0.32, 0.26, 0.16, 0.22)
		Art.rect(self, 3.5, 4.2, 1.0, 1.0, grain)
		Art.rect(self, 11.0, 8.0, 1.0, 1.0, grain)
		Art.rect(self, 7.0, 11.5, 1.0, 1.0, grain)

	if watered:
		var sheen := Color(0.72, 0.82, 0.88, 0.16)
		Art.rect(self, 3.0, 3.5, 4.0, 1.0, sheen)
		Art.rect(self, 9.0, 10.5, 3.0, 1.0, sheen)


func _draw_crop() -> void:
	var definition := get_crop_def()
	if definition.is_empty():
		return
	var ratio := get_growth_ratio()
	var center_x := 8.0
	var base_y := 13.0
	# 5 个生长阶段：播种 / 幼苗 / 长叶 / 开花 / 成熟（形状必须变化）
	var stage := 0
	if ripe:
		stage = 4
	elif ratio >= 0.70:
		stage = 3
	elif ratio >= 0.42:
		stage = 2
	elif ratio > 0.0:
		stage = 1

	var stem := Color("#7fa066")
	var leaf := Color("#8fae75")
	var leaf_dark := Color("#729059")
	if is_withered:
		stem = Color("#a89a86")
		leaf = Color("#b3a793")
		leaf_dark = Color("#9c9080")

	if is_withered:
		_draw_withered_crop(center_x, base_y, ratio)
		return

	var is_flower := bool(definition.get("is_flower", false))
	var harvest_color := Art.crop_color(seed_id, is_flower)

	# 成熟时整株轻微上下浮动（规范：成熟作物上下浮动）
	var float_y := 0.0
	if stage == 4:
		float_y = roundf(sin(_fx_time * 2.4 + float(grid_pos.x) * 0.7) * 0.5)

	match stage:
		0:
			# 播种：土坑 + 一颗种子点
			Art.ellipse(self, center_x, base_y - 0.5, 2.2, 1.0, Color(0.36, 0.28, 0.20, 0.35))
			Art.rect(self, center_x - 0.5, base_y - 1.2, 1.0, 1.0, Color("#c9a878"))
		1:
			# 幼苗：两片嫩叶贴着地面
			var y1 := base_y - 2.0 + float_y
			Art.rect(self, center_x - 0.4, y1, 0.8, 2.0, stem)
			Art.ellipse(self, center_x - 1.5, y1, 1.4, 0.9, Color("#a9c46f"))
			Art.ellipse(self, center_x + 1.5, y1 - 0.3, 1.4, 0.9, leaf)
		2:
			# 长叶：茎 + 三片叶
			var h2 := 4.0 + ratio * 2.0
			Art.rect(self, center_x - 0.5, base_y - h2 + float_y, 1.0, h2, stem)
			Art.ellipse(self, center_x - 2.0, base_y - h2 * 0.55 + float_y, 1.8, 1.1, leaf)
			Art.ellipse(self, center_x + 2.0, base_y - h2 * 0.70 + float_y, 1.8, 1.1, leaf_dark)
			Art.ellipse(self, center_x - 1.4, base_y - h2 * 0.95 + float_y, 1.4, 0.9,
				Color("#a9c46f"))
		3:
			# 开花：更高的茎 + 花苞（作物自身的花色）
			var h3 := 6.5 + ratio * 2.0
			Art.rect(self, center_x - 0.5, base_y - h3 + float_y, 1.0, h3, stem)
			Art.ellipse(self, center_x - 2.2, base_y - h3 * 0.5 + float_y, 1.9, 1.0, leaf)
			Art.ellipse(self, center_x + 2.2, base_y - h3 * 0.68 + float_y, 1.9, 1.0, leaf_dark)
			Art.ellipse(self, center_x - 1.4, base_y - h3 * 0.9 + float_y, 1.4, 0.9,
				Color("#a9c46f"))
			var bud_y := base_y - h3 - 1.2 + float_y
			Art.ellipse(self, center_x, bud_y, 1.2, 1.4, harvest_color)
			Art.rect(self, center_x - 0.4, bud_y - 1.8, 0.8, 0.9, Color("#8fae75"))
		_:
			# 成熟：满株 + 果实/花朵
			var h4 := 8.5 + float_y
			Art.rect(self, center_x - 0.5, base_y - h4, 1.0, h4, stem)
			Art.ellipse(self, center_x - 2.2, base_y - h4 * 0.45, 2.0, 1.2, leaf)
			Art.ellipse(self, center_x + 2.2, base_y - h4 * 0.62, 2.0, 1.2, leaf_dark)
			Art.ellipse(self, center_x - 1.5, base_y - h4 * 0.85, 1.5, 1.0,
				Color("#a9c46f"))
			var fruit_y := base_y - h4 - 1.0
			if is_flower:
				Art.ellipse(self, center_x - 1.6, fruit_y, 1.2, 1.2, harvest_color)
				Art.ellipse(self, center_x + 1.6, fruit_y, 1.2, 1.2, harvest_color)
				Art.ellipse(self, center_x, fruit_y - 1.6, 1.2, 1.2, harvest_color)
				Art.ellipse(self, center_x, fruit_y + 1.6, 1.2, 1.2,
					harvest_color.lightened(0.08))
				Art.rect(self, center_x - 0.6, fruit_y - 0.6, 1.2, 1.2, Color("#e8d29a"))
			else:
				Art.ellipse(self, center_x, fruit_y, 2.6, 2.4, harvest_color)
				Art.ellipse(self, center_x - 0.8, fruit_y - 0.8, 1.0, 0.9,
					harvest_color.lightened(0.14))
				Art.rect(self, center_x - 0.5, fruit_y - 3.4, 1.0, 1.2, Color("#7fa066"))

			# 成熟提示：非常轻的暖色光点，不是发光特效
			var pulse := 0.55 + 0.25 * sin(_fx_time * 2.0 + float(grid_pos.x))
			Art.rect(self, center_x + 3.0, fruit_y - 2.0, 1.0, 1.0,
				Color(0.95, 0.90, 0.70, pulse))
			# 稀有作物：成熟期常驻金色柔光粒子（规范：稀有常驻柔光）
			if is_rare:
				for index in 3:
					var t := fmod(_fx_time * 0.5 + float(index) * 0.33, 1.0)
					var px := center_x + sin(_fx_time * 1.6 + float(index) * 2.0) * 4.0
					var py := fruit_y - 2.0 - t * 7.0
					Art.rect(self, px, py, 0.5, 0.5,
						Color(1.0, 0.88, 0.45, 0.6 * (1.0 - t)))


## 枯萎：茎顶向一侧弯垂、整体变黄褐（规范：枯萎作物下垂变暗）。
func _draw_withered_crop(center_x: float, base_y: float, ratio: float) -> void:
	var height := 2.5 + ratio * 6.5
	var stem := Color("#a89a86")
	var leaf := Color("#b3a793")
	# 下垂：茎沿曲线向右侧倒
	var mid_y := base_y - height * 0.55
	var tip := Vector2(center_x + height * 0.45, base_y - height * 0.75)
	Art.rect(self, center_x - 0.5, mid_y, 1.0, base_y - mid_y, stem)
	draw_line(Vector2(center_x, mid_y), tip, stem, 1.0, false)
	Art.ellipse(self, tip.x, tip.y + 0.6, 1.6, 0.9, leaf)
	Art.ellipse(self, center_x - 1.6, base_y - height * 0.35, 1.5, 0.8, leaf.darkened(0.1))
	Art.ellipse(self, center_x, base_y - height * 0.4, 2.4, 1.4, Color(0.42, 0.36, 0.28, 0.28))
