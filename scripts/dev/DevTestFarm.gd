extends Node2D
## 开发测试场景（不是正式农场场景）。
##
## 用来直观验证：
##   - 32×32 地块与 FarmTile 的锄地 / 播种 / 浇水 / 施肥 / 收获
##   - 季节规则（春季作物到夏天枯萎、冬季户外不能种、温室可种）
##   - WASD 移动 + 鼠标点击地块
##   - FishMiniGame 拉扯小游戏与稀有结果
##
## 操作：
##   WASD / 方向键  移动
##   鼠标左键       对附近地块使用当前工具
##   1 锄头  2 播种  3 浇水  4 施肥  5 收获
##   Q / E          切换种子
##   N              下一天
##   F              钓鱼
##   R              重置

const DB := preload("res://scripts/core/ConfigDB.gd")
const FarmTileScript := preload("res://scripts/farm/FarmTile.gd")
const FishMiniGameScript := preload("res://scripts/fishing/FishMiniGame.gd")

const TILE := 32
const WORLD_W := 40
const WORLD_H := 30
const FARM_ORIGIN := Vector2i(12, 9)
const FARM_SIZE := Vector2i(12, 8)
const PLAYER_SPEED := 140.0
const FARM_REACH := 2.5

const TOOL_NAMES := ["锄头", "播种", "浇水", "施肥", "收获"]
const SEASONS := ["spring", "summer", "autumn", "winter"]

var season := "spring"
var day := 1
var year := 1
var weather := "sunny"
var money := 500
var greenhouse := false
var selected_tool := 0

var seed_ids: Array[String] = []
var seed_index := 0

var tiles: Dictionary = {}
var player: FarmerMarker
var camera: Camera2D
var highlight: Line2D
var hovered := Vector2i(-1, -1)

var ui_font: Font
var info_label: Label
var tool_label: Label
var hover_label: Label
var log_label: Label
var greenhouse_button: Button
var minigame: FishMiniGame
var log_lines: Array[String] = []


# 32×32 占位农夫。正式版本换成行走图 Sprite2D。
class FarmerMarker:
	extends Node2D

	func _draw() -> void:
		draw_rect(Rect2(-8, -2, 16, 4), Color(0, 0, 0, 0.25), true)
		draw_rect(Rect2(-6, -10, 5, 9), Color("#3c4a72"), true)
		draw_rect(Rect2(1, -10, 5, 9), Color("#3c4a72"), true)
		draw_rect(Rect2(-7, -2, 7, 3), Color("#4a3222"), true)
		draw_rect(Rect2(0, -2, 7, 3), Color("#4a3222"), true)
		draw_rect(Rect2(-8, -26, 16, 15), Color("#4d6fa8"), true)
		draw_rect(Rect2(-11, -24, 4, 10), Color("#f0c39a"), true)
		draw_rect(Rect2(7, -24, 4, 10), Color("#f0c39a"), true)
		draw_rect(Rect2(-6, -37, 12, 11), Color("#f0c39a"), true)
		draw_rect(Rect2(-6, -37, 12, 4), Color("#6b4a2f"), true)
		draw_rect(Rect2(-4, -31, 2, 2), Color("#3a2a1e"), true)
		draw_rect(Rect2(2, -31, 2, 2), Color("#3a2a1e"), true)
		draw_rect(Rect2(-11, -39, 22, 4), Color("#e5c065"), true)
		draw_rect(Rect2(-7, -46, 14, 8), Color("#d8ae52"), true)
		draw_rect(Rect2(-7, -46, 14, 2), Color("#f3d98e"), true)
		draw_rect(Rect2(-7, -41, 14, 2), Color("#9c6b3f"), true)


func _ready() -> void:
	ui_font = PixelTheme.font()
	weather = _roll_weather()
	_refresh_seed_ids()
	_build_farm()
	_build_player_and_camera()
	_build_highlight()
	_build_ui()
	_update_hud()


# ============================================================
# 世界
# ============================================================

func _draw() -> void:
	# 草地
	for y in WORLD_H:
		for x in WORLD_W:
			var color := Color("#6faa52") if (x + y) % 2 == 0 else Color("#6ca84f")
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), color, true)
	# 池塘（右上）
	for y in range(3, 10):
		for x in range(31, 39):
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), Color("#4e8fd8"), true)
	# 小路
	for x in range(0, FARM_ORIGIN.x + FARM_SIZE.x):
		draw_rect(Rect2(x * TILE, (FARM_ORIGIN.y - 1) * TILE, TILE, TILE), Color("#cbb184"), true)
	# 农场范围提示
	draw_rect(
		Rect2(FARM_ORIGIN.x * TILE, FARM_ORIGIN.y * TILE, FARM_SIZE.x * TILE, FARM_SIZE.y * TILE),
		Color(1, 1, 1, 0.10),
		false,
		2.0
	)


func _build_farm() -> void:
	for y in FARM_SIZE.y:
		for x in FARM_SIZE.x:
			var pos := FARM_ORIGIN + Vector2i(x, y)
			var tile := FarmTileScript.new()
			add_child(tile)
			tile.setup(pos, greenhouse)
			tiles[pos] = tile


func _build_player_and_camera() -> void:
	player = FarmerMarker.new()
	player.position = Vector2(
		(FARM_ORIGIN.x + FARM_SIZE.x * 0.5) * TILE,
		(FARM_ORIGIN.y + FARM_SIZE.y * 0.5) * TILE
	)
	add_child(player)

	camera = Camera2D.new()
	camera.zoom = Vector2(2.5, 2.5)
	camera.position = player.position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = WORLD_W * TILE
	camera.limit_bottom = WORLD_H * TILE
	add_child(camera)
	camera.make_current()


func _build_highlight() -> void:
	highlight = Line2D.new()
	highlight.width = 2.0
	highlight.default_color = Color("#ffe08a")
	highlight.closed = true
	highlight.points = PackedVector2Array([
		Vector2(1, 1),
		Vector2(TILE - 1, 1),
		Vector2(TILE - 1, TILE - 1),
		Vector2(1, TILE - 1),
	])
	highlight.visible = false
	add_child(highlight)


# ============================================================
# UI
# ============================================================

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := Panel.new()
	panel.position = Vector2(24, 24)
	panel.size = Vector2(700, 306)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.09, 0.07, 0.92)
	style.border_color = Color("#d8b56a")
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var title := _make_label("开发测试场景 · 农场 + 钓鱼", 22, Color("#ffe6a6"))
	title.position = Vector2(16, 10)
	title.size = Vector2(668, 30)
	panel.add_child(title)

	info_label = _make_label("", 18, Color("#f6ead2"))
	info_label.position = Vector2(16, 44)
	info_label.size = Vector2(668, 26)
	panel.add_child(info_label)

	tool_label = _make_label("", 15, Color("#cfe0b0"))
	tool_label.position = Vector2(16, 74)
	tool_label.size = Vector2(668, 46)
	tool_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(tool_label)

	hover_label = _make_label("", 14, Color("#d8c7a8"))
	hover_label.position = Vector2(16, 122)
	hover_label.size = Vector2(668, 24)
	panel.add_child(hover_label)

	var buttons := [
		["下一天 (N)", Vector2(16, 154), Vector2(140, 38), _next_day],
		["钓鱼 (F)", Vector2(166, 154), Vector2(110, 38), _start_fishing],
		["全部浇水", Vector2(286, 154), Vector2(120, 38), _water_all],
		["温室：关", Vector2(416, 154), Vector2(120, 38), _toggle_greenhouse],
		["重置 (R)", Vector2(546, 154), Vector2(120, 38), _reset_world],
	]
	for entry: Array in buttons:
		var button := _make_button(str(entry[0]), entry[1], entry[2])
		var callback: Callable = entry[3]
		button.pressed.connect(callback)
		panel.add_child(button)
		if str(entry[0]).begins_with("温室"):
			greenhouse_button = button

	log_label = _make_label("", 14, Color("#e8d9b8"))
	log_label.position = Vector2(16, 204)
	log_label.size = Vector2(668, 90)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(log_label)

	minigame = FishMiniGameScript.new()
	minigame.position = Vector2(560, 700)
	minigame.size = Vector2(800, 300)
	minigame.visible = false
	minigame.finished.connect(_on_fishing_finished)
	root.add_child(minigame)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", ui_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_button(text: String, position: Vector2, size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.add_theme_font_override("font", ui_font)
	button.add_theme_font_size_override("font_size", 15)
	return button


# ============================================================
# 输入与主循环
# ============================================================

func _process(delta: float) -> void:
	if player == null:
		return

	if minigame != null and minigame.running:
		camera.position = player.position
		return

	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		direction.y += 1.0

	if direction != Vector2.ZERO:
		player.position += direction.normalized() * PLAYER_SPEED * delta
		player.position.x = clampf(player.position.x, 16.0, WORLD_W * TILE - 16.0)
		player.position.y = clampf(player.position.y, 40.0, WORLD_H * TILE - 4.0)

	camera.position = player.position
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if minigame != null and minigame.running:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				selected_tool = 0
				_update_hud()
			KEY_2:
				selected_tool = 1
				_update_hud()
			KEY_3:
				selected_tool = 2
				_update_hud()
			KEY_4:
				selected_tool = 3
				_update_hud()
			KEY_5:
				selected_tool = 4
				_update_hud()
			KEY_Q:
				_cycle_seed(-1)
			KEY_E:
				_cycle_seed(1)
			KEY_N:
				_next_day()
			KEY_F:
				_start_fishing()
			KEY_R:
				_reset_world()
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_apply_tool()
		return


func _update_hover() -> void:
	var world_position := get_global_mouse_position()
	var tile_pos := Vector2i(
		floori(world_position.x / float(TILE)),
		floori(world_position.y / float(TILE))
	)
	if tile_pos == hovered:
		return
	hovered = tile_pos

	var has_tile := tiles.has(tile_pos)
	highlight.visible = has_tile
	if has_tile:
		highlight.position = Vector2(tile_pos) * float(TILE)
		highlight.default_color = Color("#ffe08a") if _in_reach(tile_pos) else Color("#8a8a8a")

	hover_label.text = ""
	if has_tile:
		var tile: FarmTile = tiles[tile_pos]
		hover_label.text = "地块 (%d,%d)：%s%s" % [
			tile_pos.x, tile_pos.y,
			tile.get_interaction_label(),
			"" if _in_reach(tile_pos) else "  · 太远了",
		]


# ============================================================
# 工具
# ============================================================

func _apply_tool() -> void:
	if not tiles.has(hovered):
		return
	if not _in_reach(hovered):
		_log("太远了，靠近一点再操作")
		return

	var tile: FarmTile = tiles[hovered]
	match selected_tool:
		0:
			if tile.till():
				_log("翻地成功")
			else:
				_log("这块地不能翻")
		1:
			if seed_ids.is_empty():
				_log("当前季节没有可选种子")
				return
			var seed_id := seed_ids[seed_index]
			var result := tile.plant(seed_id, season, year)
			if bool(result.get("ok", false)):
				_log("种下了 %s" % DB.get_crop(seed_id).get("name", seed_id))
			else:
				_log(str(result.get("reason", "不能播种")))
		2:
			if tile.water():
				_log("浇水成功")
			else:
				_log("这里不需要浇水")
		3:
			if tile.fertilize():
				_log("施肥成功（稀有率提升）")
			else:
				_log("这里不能施肥")
		4:
			var harvest_result := tile.harvest()
			if bool(harvest_result.get("ok", false)):
				var item: Dictionary = harvest_result.get("item", {})
				var price := int(item.get("price", 0))
				money += price
				var suffix := ""
				if bool(item.get("is_rare", false)):
					suffix = " ✨%s" % str(item.get("rare_name", ""))
				_log("收获 %s%s，+%d G" % [item.get("name", ""), suffix, price])
				_update_hud()
			else:
				_log(str(harvest_result.get("reason", "不能收获")))
	_update_hover()


func _water_all() -> void:
	var count := 0
	for tile: FarmTile in tiles.values():
		if tile.water():
			count += 1
	_log("给 %d 块地浇了水" % count)


func _toggle_greenhouse() -> void:
	greenhouse = not greenhouse
	for tile: FarmTile in tiles.values():
		tile.greenhouse = greenhouse
		tile.queue_redraw()
	if greenhouse_button != null:
		greenhouse_button.text = "温室：开" if greenhouse else "温室：关"
	_log("温室模式：%s" % ("开" if greenhouse else "关"))


func _cycle_seed(step: int) -> void:
	if seed_ids.is_empty():
		return
	seed_index = posmod(seed_index + step, seed_ids.size())
	_update_hud()


func _next_day() -> void:
	for tile: FarmTile in tiles.values():
		tile.advance_day(season, weather)

	day += 1
	var days_per_season := DB.get_days_per_season()
	if day > days_per_season:
		day = 1
		var season_index := SEASONS.find(season)
		season_index = (season_index + 1) % SEASONS.size()
		if season_index == 0:
			year += 1
		season = SEASONS[season_index]
		_refresh_seed_ids()

	weather = _roll_weather()
	_log("第 %d 天 · %s季 · %s" % [day, DB.season_name(season), DB.weather_name(weather)])
	_update_hud()


func _roll_weather() -> String:
	var weights := DB.get_weather_weights(season)
	if weights.is_empty():
		return "sunny"
	var total := 0
	for value: Variant in weights.values():
		total += maxi(0, int(value))
	if total <= 0:
		return "sunny"

	# 每次新建 RNG，不与其他系统共用。
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll := rng.randi_range(1, total)
	for key: String in weights.keys():
		roll -= maxi(0, int(weights[key]))
		if roll <= 0:
			return key
	return "sunny"


func _refresh_seed_ids() -> void:
	seed_ids.clear()
	for definition: Dictionary in DB.get_crops_by_season(season):
		seed_ids.append(str(definition.get("id", "")))
	if seed_ids.is_empty():
		for definition: Dictionary in DB.get_all_crops():
			seed_ids.append(str(definition.get("id", "")))
	seed_index = clampi(seed_index, 0, maxi(0, seed_ids.size() - 1))


# ============================================================
# 钓鱼
# ============================================================

func _start_fishing() -> void:
	if minigame.running:
		return

	var candidates := DB.get_fish_candidates("river", season, "day", weather, 2)
	if candidates.is_empty():
		candidates = DB.get_fishes_by_area("river")
	if candidates.is_empty():
		_log("没有可钓的鱼")
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var fish: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]

	minigame.visible = true
	minigame.start(fish, {
		"rod_id": "silver_rod",
		"bait_id": "high_bait",
		"is_rain": weather == "rain" or weather == "storm",
		"is_dusk": false,
	})
	_log("抛竿：%s（%s）" % [fish.get("name", ""), DB.weather_name(weather)])


func _on_fishing_finished(success: bool, result: Dictionary) -> void:
	if success:
		var price := int(result.get("price", 0))
		money += price
		_log("🎣 %s  +%d G" % [minigame.get_result_text(), price])
	else:
		_log("🎣 %s" % minigame.get_result_text())
	_update_hud()

	await get_tree().create_timer(2.5).timeout
	if minigame != null and not minigame.running:
		minigame.visible = false


# ============================================================
# 其它
# ============================================================

func _reset_world() -> void:
	for tile: FarmTile in tiles.values():
		remove_child(tile)
		tile.free()
	tiles.clear()

	season = "spring"
	day = 1
	year = 1
	money = 500
	greenhouse = false
	selected_tool = 0
	seed_index = 0
	weather = _roll_weather()
	log_lines.clear()
	if greenhouse_button != null:
		greenhouse_button.text = "温室：关"

	_build_farm()
	player.position = Vector2(
		(FARM_ORIGIN.x + FARM_SIZE.x * 0.5) * TILE,
		(FARM_ORIGIN.y + FARM_SIZE.y * 0.5) * TILE
	)
	camera.position = player.position
	_refresh_seed_ids()
	_update_hud()
	_log("场景已重置")


func _in_reach(tile_pos: Vector2i) -> bool:
	var player_tile := Vector2i(
		floori(player.position.x / float(TILE)),
		floori(player.position.y / float(TILE))
	)
	return Vector2(tile_pos - player_tile).length() <= FARM_REACH


func _log(message: String) -> void:
	log_lines.push_front(message)
	while log_lines.size() > 3:
		log_lines.pop_back()
	if log_label != null:
		log_label.text = "\n".join(PackedStringArray(log_lines))


func _update_hud() -> void:
	if info_label == null:
		return
	info_label.text = "第 %d 年 · %s季 · 第 %d 天 · %s · %d G" % [
		year,
		DB.season_name(season),
		day,
		DB.weather_name(weather),
		money,
	]
	var seed_name := "—"
	if not seed_ids.is_empty():
		seed_name = str(DB.get_crop(seed_ids[seed_index]).get("name", seed_ids[seed_index]))
	tool_label.text = "工具 [%d] %s　｜　种子 %s（Q/E 切换）\nWASD 移动 · 鼠标左键使用 · N 下一天 · F 钓鱼" % [
		selected_tool + 1,
		TOOL_NAMES[selected_tool],
		seed_name,
	]
