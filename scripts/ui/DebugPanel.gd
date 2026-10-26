class_name DebugPanel
extends CanvasLayer
## 调试作弊面板（仅 debug 构建可用）。
##
## 按《个人单机开发要求》第四章：
##   F1 开关面板 / F2 加钱 / F3 跳 1 小时 / F4 跳 1 天
##   F5 重载配置 / F6 碰撞框 / F7 作物全熟 / F8 解锁图鉴
##
## 面板本身不写业务逻辑，全部转发给 Farm。

const DB := preload("res://scripts/core/ConfigDB.gd")

var farm

var _player: Player
var _time: TimeSystem

var _root: Control
var _panel: PanelContainer
var _labels: Dictionary = {}
var _visible := false
var _draw_collision := false


func setup(p_farm: Node) -> void:
	farm = p_farm
	_player = farm.player
	_time = farm.time
	layer = 30
	_build()
	visible = false


func _build() -> void:
	var layer_root := Control.new()
	layer_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer_root)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", PixelTheme.panel_style())
	layer_root.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.custom_minimum_size = Vector2(300, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	_panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label("调试面板 F1", 14, PixelTheme.C_INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close := _button("关闭")
	close.pressed.connect(toggle)
	header.add_child(close)

	_labels["money"] = _label("", 12, PixelTheme.C_INK_SOFT)
	_labels["time"] = _label("", 12, PixelTheme.C_INK_SOFT)
	_labels["stamina"] = _label("", 12, PixelTheme.C_INK_SOFT)
	for key: String in _labels.keys():
		column.add_child(_labels[key])

	var rows := [
		[["+1000 钱", _add_money], ["跳 1 小时", _skip_hour]],
		[["跳 1 天", _skip_day], ["跳 1 季", _skip_season]],
		[["满体力", _fill_stamina], ["作物全熟", _ripen_crops]],
		[["动物满好感", _max_friendship], ["解锁图鉴", _unlock_book]],
		[["切天气", _cycle_weather], ["时间流速", _cycle_speed]],
		[["重载配置", _reload_config], ["显示碰撞", _toggle_collision]],
	]
	for row_defs: Array in rows:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		column.add_child(row)
		for entry: Array in row_defs:
			var button := _button(str(entry[0]))
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.custom_minimum_size = Vector2(0, 28)
			var callback: Callable = entry[1]
			button.pressed.connect(callback)
			row.add_child(button)

	var hint := _label("F2 加钱 · F3 跳时 · F4 跳天 · F5 重载 · F6 碰撞 · F7 全熟 · F8 图鉴", 10, PixelTheme.C_INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(280, 0)
	column.add_child(hint)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	PixelTheme.apply_label(label, size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, size := 12) -> Button:
	var button := Button.new()
	button.text = text
	PixelTheme.apply_button(button, size)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	return button


func toggle() -> void:
	_visible = not _visible
	visible = _visible
	if _visible:
		_refresh_labels()


func _refresh_labels() -> void:
	if _labels.is_empty():
		return
	(_labels["money"] as Label).text = "金钱：%d G" % int(farm.money)
	(_labels["time"] as Label).text = "时间：%s · %s季 %d日 · %s" % [
		_time.get_clock_text(),
		DB.season_name(_time.season),
		_time.day,
		DB.weather_name(_time.weather),
	]
	(_labels["stamina"] as Label).text = "体力：%d / %d · 流速 %s" % [
		int(_player.stamina), int(_player.stamina_max), _time.speed_id,
	]


func _process(_delta: float) -> void:
	if _visible:
		_refresh_labels()


# ============================================================
# 快捷键（仅 debug 构建）
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F1:
			toggle()
		KEY_F2:
			_add_money()
		KEY_F3:
			_skip_hour()
		KEY_F4:
			_skip_day()
		KEY_F5:
			_reload_config()
		KEY_F6:
			_toggle_collision()
		KEY_F7:
			_ripen_crops()
		KEY_F8:
			_unlock_book()
		_:
			return
	get_viewport().set_input_as_handled()


# ============================================================
# 操作
# ============================================================

func _add_money() -> void:
	farm.money += 1000
	farm.ui.refresh_hud()


func _skip_hour() -> void:
	_time.minutes = minf(float(DB.get_day_end_minutes()) - 1.0, _time.minutes + 60.0)
	farm.ui.refresh_hud()


func _skip_day() -> void:
	farm.force_next_day()


func _skip_season() -> void:
	var target := _time.day
	_time.day = DB.get_days_per_season()
	farm.force_next_day()
	_time.day = target


func _fill_stamina() -> void:
	_player.restore_stamina(1.0)


func _ripen_crops() -> void:
	var count := 0
	for tile: FarmTile in farm.farm_tiles.values():
		if tile.has_crop() and not tile.is_withered:
			tile.current_day = tile.get_grow_day()
			tile.ripe = true
			tile.queue_redraw()
			count += 1
	farm.ui.toast("调试：%d 块作物已成熟" % count, "good")


func _max_friendship() -> void:
	for animal: FarmAnimal in farm.animals:
		animal.friendship = animal.friendship_max
	for pet: FarmPet in farm.pets:
		pet.friendship = pet.friendship_max
	farm.ui.toast("调试：动物与宠物好感已满", "good")


func _unlock_book() -> void:
	var categories := [
		"crop", "animal", "fish", "fruit", "bee_product",
		"bird", "insect", "artifact",
	]
	for category: String in categories:
		farm.unlock_book[category] = []
	for crop: Dictionary in DB.get_all_crops():
		(farm.unlock_book["crop"] as Array).append(str(crop.get("id", "")))
	for animal: Dictionary in DB.get_all_animals():
		(farm.unlock_book["animal"] as Array).append(str(animal.get("id", "")))
	for fish: Dictionary in DB.get_all_fishes():
		(farm.unlock_book["fish"] as Array).append(str(fish.get("id", "")))
	for artifact: Dictionary in DB.get_all_artifacts():
		(farm.unlock_book["artifact"] as Array).append(str(artifact.get("id", "")))
	farm.ui.toast("调试：图鉴已全部解锁", "good")


func _cycle_weather() -> void:
	var order := ["sunny", "rain", "storm", "snow", "blizzard"]
	var index := order.find(_time.weather)
	_time.weather = order[(index + 1) % order.size()]
	farm.ui.refresh_hud()
	farm.ui.toast("调试：天气 → %s" % DB.weather_name(_time.weather), "good")


func _cycle_speed() -> void:
	var order := ["slow", "normal", "fast"]
	var index := order.find(_time.speed_id)
	var next: String = order[(index + 1) % order.size()]
	_time.set_speed_id(next)
	AudioManager.set_setting("time_speed", next)
	farm.ui.toast("调试：时间流速 → %s" % next, "good")


func _reload_config() -> void:
	var ok := DB.load_all(true)
	farm.ui.toast("调试：配置重载%s" % ("成功" if ok else "失败"), "good" if ok else "bad")


func _toggle_collision() -> void:
	_draw_collision = not _draw_collision
	farm.debug_draw_collision = _draw_collision
	farm.queue_redraw()
	farm.ui.toast("调试：碰撞框 %s" % ("开" if _draw_collision else "关"))
