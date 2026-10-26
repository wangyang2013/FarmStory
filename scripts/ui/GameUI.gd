class_name GameUI
extends CanvasLayer
## 游戏界面：HUD、物品栏、商店、帮助、对话框、提示、淡入淡出、钓鱼小游戏容器。
##
## 布局参考星露谷（时钟在右上、体力在右下、物品栏在底部居中），
## 视觉按美术要求做减法：浅米白面板、细浅棕边框、小圆角、小巧字体、无厚重装饰。
##
## UI 只负责显示与转发操作，具体买卖 / 存档逻辑都在 Farm。

const DB := preload("res://scripts/core/ConfigDB.gd")
const MineFloorScript := preload("res://scripts/world/MineFloor.gd")
const FishMiniGameScript := preload("res://scripts/fishing/FishMiniGame.gd")
const Art := preload("res://scripts/art/PixelArt.gd")
const SaveSystem := preload("res://scripts/core/SaveSystem.gd")
const UITheme := preload("res://scripts/ui/PixelTheme.gd")

const HOTBAR_SIZE := 10
const COLLECTION_SORT_ORDER := ["default", "name", "price", "uncollected"]
const COLLECTION_SORT_NAMES := {
	"default": "默认", "name": "名称", "price": "价格", "uncollected": "未收集优先",
}

var farm
var font: Font

var root: Control
var date_label: Label
var time_label: Label
var weather_label: Label
var money_label: Label
var stamina_label: Label
var stamina_bar: ProgressBar
var health_frame: PanelContainer
var health_bar: ProgressBar
var health_label: Label
var weather_icon: Control
var year_label: Label
var pause_icon: Label
var status_icon: Label
var banner_panel: PanelContainer
var banner_label: Label
var _stamina_pulse := 0.0
var hotbar_box: HBoxContainer
var prompt_panel: PanelContainer
var prompt_label: Label
var toast_box: VBoxContainer
var fade_rect: ColorRect

var inventory_panel: Control
var inventory_grid: GridContainer
var inventory_title: Label
var shop_panel: Control
var shop_money_label: Label
var shop_buy_list: VBoxContainer
var shop_sell_list: VBoxContainer
var shop_sell_all: Button
var help_panel: Control
var save_panel: Control
var save_list: VBoxContainer
var _export_dialog: FileDialog
var _import_dialog: FileDialog
var _transfer_slot_select: OptionButton
var _export_slot := 1
var _import_slot := 1
var settings_panel: Control
var settings_box: VBoxContainer
var cooking_panel: Control
var cooking_list: VBoxContainer
var cooking_title: Label

var machine_panel: Control
var machine_list: VBoxContainer
var machine_title: Label
var _machine

var festival_panel: Control
var festival_title: Label
var festival_desc: Label
var festival_result: Label
var festival_button: Button
var _festival: Dictionary = {}

var notice_board_panel: Control
var notice_list: VBoxContainer
var notice_quests_tab: Button
var notice_buildings_tab: Button
var notice_refresh_button: Button
var _notice_tab := "quests"

var credits_panel: Control
var storage_panel: Control
var storage_inv_grid: GridContainer
var storage_box_grid: GridContainer
var storage_title: Label
var storage_info: Label
var _storage_kind := "storage"

var mail_panel: Control
var mail_list: VBoxContainer
var mail_body: Label

var cellar_panel: Control
var cellar_inv_grid: GridContainer
var cellar_box_grid: GridContainer
var cellar_info: Label

var achievements_panel: Control
var achievements_list: VBoxContainer

var library_panel: Control
var library_list: VBoxContainer
var library_info: Label
var clinic_panel: Control
var clinic_info: Label

var mount_panel: Control
var mount_title: Label
var mount_list: VBoxContainer
var mount_info: Label
var _mount_building := "stable"

var mount_cargo_panel: Control
var mount_cargo_title: Label
var mount_cargo_info: Label
var mount_cargo_list: VBoxContainer
var _cargo_mount_id := ""

var pet_panel: Control
var pet_title: Label
var pet_info: Label
var pet_box: VBoxContainer
var _pet_panel_id := ""
var _pet_shop_type := "dog"

var pet_name_panel: Control
var pet_name_input: LineEdit
var _name_pet_id := ""
var _name_return_panel := false

var collection_panel: Control
var collection_grid: GridContainer
var collection_title: Label
var collection_info: Label
var collection_sort_button: Button
var _collection_category := "crop"
var _collection_sort := "default"

var museum_panel: Control
var museum_grid: GridContainer
var museum_title: Label
var museum_info: Label
var _museum_tab := "artifact"

var dialogue_panel: PanelContainer
var dialogue_name: Label
var dialogue_text: Label
var dialogue_portrait: Control
var dialogue_tween: Tween
var dialogue_tail: Control
var _dialogue_full_text := ""
var _dialogue_index := 0.0
var _dialogue_speed := 28.0   # 每秒多少字
var _dialogue_typing := false

var minigame: FishMiniGame

var compass: Control
var fatigue_vignette: Control
var farm_sign_label: Label

var _modal := ""
var _selected_index := 0
var _hotbar_buttons: Array[Button] = []
var _shop_tab := "seeds"
var _shop_seed_tab: Button
var _shop_animal_tab: Button
var _shop_pet_tab: Button
var _shop_accessory_tab: Button
var _shop_tree_tab: Button
var _shop_bee_tab: Button
var _shop_machine_tab: Button
var _shop_furniture_tab: Button
var _portrait_look: Dictionary = Art.default_look()


func setup(p_farm: Node) -> void:
	farm = p_farm
	font = UITheme.font()
	# 地图/界面在暂停逻辑下仍可响应（规范要求 ProcessMode = Always）。
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	if farm.player != null:
		farm.player.health_changed.connect(func(_current, _maximum) -> void: refresh_hud())


# ============================================================
# 构建
# ============================================================

## 统一标签：默认单行，避免被行内布局挤压换行。
func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	UITheme.apply_label(label, size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## 长正文标签：在固定宽度内自动换行（不撑宽弹窗）。
func _wrap_label(text: String, size: int, color: Color, width: float) -> Label:
	var label := _label(text, size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	label.size_flags_horizontal = Control.SIZE_FILL
	return label


## 单行列表文字：超长裁剪，不撑宽弹窗。
func _clip_label(text: String, size: int, color: Color) -> Label:
	var label := _label(text, size, color)
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label


## 统一按钮：宽高由调用方指定。
func _button(text: String, size := 14) -> Button:
	var button := Button.new()
	button.text = text
	UITheme.apply_button(button, size)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	return button


## 列表里的长文字按钮：文字超长时裁剪，不撑宽弹窗。
func _clip_button(text: String, size := 10) -> Button:
	var button := _button(text, size)
	button.clip_text = true
	return button


func _compact_tab(button: Button) -> void:
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style: StyleBoxFlat = UITheme.button_style(state).duplicate()
		style.content_margin_left = 2
		style.content_margin_right = 2
		button.add_theme_stylebox_override(state, style)


func _build() -> void:
	root = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_build_farm_sign_label()
	_build_clock()
	_build_energy()
	_build_banner()
	_build_hotbar()
	_build_prompt()
	_build_toasts()
	_build_quick_buttons()
	_build_compass()
	_build_fatigue_vignette()
	_build_inventory()
	_build_storage()
	_build_mail()
	_build_cellar()
	_build_achievements()
	_build_library()
	_build_clinic()
	_build_mount_panel()
	_build_mount_cargo()
	_build_pet_panel()
	_build_pet_name_panel()
	_build_shop()
	_build_help()
	_build_save_panel()
	_build_settings_panel()
	_build_cooking_panel()
	_build_machine_panel()
	_build_festival_panel()
	_build_notice_board()
	_build_collection()
	_build_museum()
	_build_credits()
	_build_dialogue()
	_build_minigame()

	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.10, 0.08, 0.06, 1.0)
	fade_rect.modulate.a = 0.0
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade_rect)
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


# ---------- 牧场名牌文字（屏幕空间） ----------

func _build_farm_sign_label() -> void:
	farm_sign_label = Label.new()
	farm_sign_label.visible = false
	farm_sign_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	farm_sign_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	farm_sign_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	farm_sign_label.size = Vector2(160, 14)
	farm_sign_label.add_theme_font_override("font", font)
	farm_sign_label.add_theme_font_size_override("font_size", 12)
	farm_sign_label.add_theme_color_override("font_color", Color("#4a3520"))
	root.add_child(farm_sign_label)


# ---------- 右上角时钟 ----------

func _build_clock() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.custom_minimum_size = Vector2(122, 0)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top)

	date_label = _label("春 · 1日", 13, UITheme.C_INK)
	top.add_child(date_label)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(top_spacer)

	weather_icon = UITheme.PixelIcon.new()
	weather_icon.kind = "sun"
	weather_icon.custom_minimum_size = Vector2(10, 10)
	weather_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(weather_icon)

	weather_label = _label("晴", 11, UITheme.C_INK_SOFT)
	top.add_child(weather_label)

	# 暂停图标 / 疲劳提示（默认隐藏）
	pause_icon = _label("⏸", 11, UITheme.C_INK_SOFT)
	pause_icon.visible = false
	top.add_child(pause_icon)

	status_icon = _label("", 10, UITheme.C_BAD)
	status_icon.visible = false
	top.add_child(status_icon)

	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 8)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(middle)

	time_label = _label("06:00", 14, UITheme.C_INK)
	middle.add_child(time_label)

	year_label = _label("第 1 年", 10, UITheme.C_INK_SOFT)
	middle.add_child(year_label)

	var divider := ColorRect.new()
	divider.color = UITheme.C_BORDER_SOFT
	divider.custom_minimum_size = Vector2(0, 1)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(divider)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 5)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bottom)

	var coin := UITheme.PixelIcon.new()
	coin.kind = "coin"
	coin.custom_minimum_size = Vector2(10, 10)
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(coin)

	money_label = _label("500 G", 12, Color("#8a6a3f"))
	bottom.add_child(money_label)


# ---------- 右下角体力 ----------

func _build_energy() -> void:
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 3)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
	holder.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN

	health_frame = PanelContainer.new()
	health_frame.add_theme_stylebox_override("panel", UITheme.panel_style())
	health_frame.custom_minimum_size = Vector2(13, 60)
	health_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_frame.visible = false
	holder.add_child(health_frame)

	health_bar = ProgressBar.new()
	health_bar.max_value = 100
	health_bar.value = 100
	health_bar.show_percentage = false
	health_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	health_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	health_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	health_bar.add_theme_stylebox_override("background", UITheme.bar_background())
	health_bar.add_theme_stylebox_override("fill", UITheme.bar_fill(Color("#c4553f")))
	health_frame.add_child(health_bar)

	health_label = _label("100", 10, UITheme.C_BAD)
	health_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_label.visible = false
	holder.add_child(health_label)

	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.panel_style())
	frame.custom_minimum_size = Vector2(13, 90)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(frame)

	stamina_bar = ProgressBar.new()
	stamina_bar.max_value = 100
	stamina_bar.value = 100
	stamina_bar.show_percentage = false
	stamina_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	stamina_bar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamina_bar.add_theme_stylebox_override("background", UITheme.bar_background())
	stamina_bar.add_theme_stylebox_override("fill", UITheme.bar_fill(UITheme.C_GOOD))
	frame.add_child(stamina_bar)

	stamina_label = _label("100", 10, UITheme.C_INK)
	stamina_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(stamina_label)


# ---------- 底部物品栏 ----------

func _build_hotbar() -> void:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.panel_style())
	root.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 4)
	frame.grow_horizontal = Control.GROW_DIRECTION_BOTH
	frame.grow_vertical = Control.GROW_DIRECTION_BEGIN

	hotbar_box = HBoxContainer.new()
	hotbar_box.add_theme_constant_override("separation", 3)
	hotbar_box.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(hotbar_box)

	for index in HOTBAR_SIZE:
		var button := Button.new()
		button.custom_minimum_size = Vector2(32, 32)
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_stylebox_override("normal", UITheme.slot_style(false))
		button.add_theme_stylebox_override("hover", UITheme.slot_style(false))
		button.add_theme_stylebox_override("pressed", UITheme.slot_style(true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", UITheme.C_INK)
		button.add_theme_color_override("font_hover_color", UITheme.C_INK)
		button.add_theme_color_override("font_pressed_color", UITheme.C_INK)
		button.pressed.connect(func() -> void: _on_hotbar_pressed(index))
		hotbar_box.add_child(button)
		_hotbar_buttons.append(button)


# ---------- 交互提示 ----------

## 日期 / 季节横幅：每天 6:00 弹出，约 1.5 秒后淡出。
func _build_banner() -> void:
	banner_panel = PanelContainer.new()
	banner_panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_panel.visible = false
	root.add_child(banner_panel)
	banner_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 90)
	banner_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH

	banner_label = _label("", 14, UITheme.C_INK)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_panel.add_child(banner_label)


func show_banner(text: String, duration := 1.5) -> void:
	banner_label.text = text
	banner_panel.visible = true
	banner_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(banner_panel, "modulate:a", 1.0, 0.18)
	tween.tween_interval(duration)
	tween.tween_property(banner_panel, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void: banner_panel.visible = false)


func _build_prompt() -> void:
	prompt_panel = PanelContainer.new()
	prompt_panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_panel.visible = false
	root.add_child(prompt_panel)
	prompt_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 38)
	prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	prompt_label = _label("", 10, UITheme.C_INK)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_panel.add_child(prompt_label)


func _build_toasts() -> void:
	toast_box = VBoxContainer.new()
	toast_box.add_theme_constant_override("separation", 5)
	toast_box.alignment = BoxContainer.ALIGNMENT_CENTER
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 84)
	toast_box.grow_horizontal = Control.GROW_DIRECTION_BOTH


# ---------- 左上角快捷按钮 ----------

func _build_quick_buttons() -> void:
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 5)
	root.add_child(buttons)
	buttons.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, 6)
	buttons.grow_horizontal = Control.GROW_DIRECTION_END

	var save_button := _button("存档 F5", 10)
	save_button.custom_minimum_size = Vector2(34, 15)
	save_button.pressed.connect(func() -> void: open_save_panel())
	buttons.add_child(save_button)

	var load_button := _button("读档 F9", 10)
	load_button.custom_minimum_size = Vector2(34, 15)
	load_button.pressed.connect(func() -> void: farm.request_load())
	buttons.add_child(load_button)

	var new_button := _button("新游戏", 10)
	new_button.custom_minimum_size = Vector2(32, 15)
	new_button.pressed.connect(func() -> void: farm.request_new_game())
	buttons.add_child(new_button)

	var help_button := _button("帮助 H", 10)
	help_button.custom_minimum_size = Vector2(32, 15)
	help_button.pressed.connect(func() -> void: toggle_help())
	buttons.add_child(help_button)

	var map_button := _button("地图 M", 10)
	map_button.custom_minimum_size = Vector2(32, 15)
	map_button.pressed.connect(func() -> void: farm.toggle_map())
	buttons.add_child(map_button)

	var collection_button := _button("图鉴 C", 10)
	collection_button.custom_minimum_size = Vector2(32, 15)
	collection_button.pressed.connect(func() -> void: toggle_collection())
	buttons.add_child(collection_button)


# ---------- 弹窗外壳 ----------

## 弹窗外壳：宽度写死，不允许被内容撑开；长文本改为换行。
func _modal_shell(title: String, panel_size: Vector2) -> Dictionary:
	# 统一缩小 8%，并限制最大宽高
	var width := minf(roundf(panel_size.x * 0.92), 344.0)
	var height := minf(roundf(panel_size.y * 0.92), 218.0)
	var fixed_size := Vector2(width, height)
	var inner_width := width - 22.0

	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.08, 0.06, 0.42)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.visible = false
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.custom_minimum_size = fixed_size
	panel.clip_contents = true
	dim.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var column := VBoxContainer.new()
	# 固定内容宽度：标签自动换行，容器不再按内容撑宽
	column.custom_minimum_size = Vector2(inner_width, 0)
	column.size_flags_horizontal = Control.SIZE_FILL
	column.add_theme_constant_override("separation", 7)
	panel.add_child(column)

	# 标题行（浅米色，仅底部分隔线）
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", UITheme.header_style())
	column.add_child(header)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	header.add_child(header_row)

	var title_label := _label(title, 13, UITheme.C_INK)
	header_row.add_child(title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_child(spacer)

	var money := _label("500 G", 11, Color("#8a6a3f"))
	header_row.add_child(money)

	var close := _button("关闭 Esc", 10)
	close.custom_minimum_size = Vector2(36, 13)
	header_row.add_child(close)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 7)
	column.add_child(body)

	return {
		"dim": dim,
		"panel": panel,
		"column": body,
		"title": title_label,
		"money": money,
		"close": close,
	}


# ---------- 背包 ----------

func _build_inventory() -> void:
	var shell := _modal_shell("背包", Vector2(294, 184))
	inventory_panel = shell["dim"]
	inventory_title = shell["title"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)

	column.add_child(_label("点击物品切换手持（编号 1-0 对应前 10 格）", 10, UITheme.C_INK_SOFT))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(246, 100)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)

	inventory_grid = GridContainer.new()
	inventory_grid.columns = 8
	inventory_grid.add_theme_constant_override("h_separation", 5)
	inventory_grid.add_theme_constant_override("v_separation", 5)
	UITheme.apply_scrollbar(scroll)
	scroll.add_child(inventory_grid)


# ---------- 储物箱 / 冰箱 ----------

func _build_storage() -> void:
	var shell := _modal_shell("储物箱", Vector2(392, 224))
	storage_panel = shell["dim"]
	storage_title = shell["title"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)

	storage_info = _label("", 10, UITheme.C_INK_SOFT)
	column.add_child(storage_info)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	column.add_child(columns)

	columns.add_child(_storage_column("背包", true))
	columns.add_child(_storage_column("储物", false))


func _storage_column(title: String, inventory_side: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label(title, 10, UITheme.C_INK))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(150, 136)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.apply_scrollbar(scroll)
	box.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(grid)
	if inventory_side:
		storage_inv_grid = grid
	else:
		storage_box_grid = grid
	return box


func open_storage(kind: String) -> void:
	if is_modal_open():
		return
	_storage_kind = kind
	refresh_storage()
	_set_modal("storage")


func refresh_storage() -> void:
	if farm == null or storage_inv_grid == null:
		return
	for child in storage_inv_grid.get_children():
		child.queue_free()
	for child in storage_box_grid.get_children():
		child.queue_free()

	for index in farm.inventory.slots.size():
		var slot: Dictionary = farm.inventory.get_slot(index)
		storage_inv_grid.add_child(_storage_cell(slot, index, true))
	var stacks: Array = farm.storage_slots(_storage_kind)
	var capacity: int = farm.storage_capacity(_storage_kind)
	for index in capacity:
		var stack: Dictionary = stacks[index] if index < stacks.size() else {}
		storage_box_grid.add_child(_storage_cell(stack, index, false))

	storage_title.text = "冰箱" if _storage_kind == "fridge" else "储物箱"
	storage_info.text = "点击物品在背包与%s之间转移 · %d / %d" % [
		"冰箱" if _storage_kind == "fridge" else "储物箱",
		stacks.size(), capacity,
	]


func _storage_cell(slot: Dictionary, index: int, from_inventory: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(24, 24)
	button.add_theme_stylebox_override("normal", UITheme.slot_style(false))
	button.add_theme_stylebox_override("hover", UITheme.slot_style(true))
	button.add_theme_stylebox_override("pressed", UITheme.slot_style(true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if slot.is_empty():
		return button

	var item_id := str(slot.get("item_id", ""))
	var category := str(slot.get("category", ""))
	var count := int(slot.get("count", 1))
	button.tooltip_text = "%s ×%d" % [DB.get_item_name(item_id, category), count]
	var icon := TextureRect.new()
	icon.texture = UITheme.item_icon(item_id, category)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size = Vector2(20, 20)
	icon.position = Vector2(4, 2)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var count_label := _label(str(count), 9, UITheme.C_INK)
	count_label.position = Vector2(15, 15)
	button.add_child(count_label)
	button.pressed.connect(func() -> void:
		if from_inventory:
			farm.transfer_inventory_to_storage(_storage_kind, index)
		else:
			farm.transfer_storage_to_inventory(_storage_kind, index)
	)
	return button


# ---------- 邮箱 ----------

func _build_mail() -> void:
	var shell := _modal_shell("邮箱", Vector2(356, 224))
	mail_panel = shell["dim"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)

	var list_scroll := ScrollContainer.new()
	list_scroll.custom_minimum_size = Vector2(304, 88)
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.apply_scrollbar(list_scroll)
	column.add_child(list_scroll)
	mail_list = VBoxContainer.new()
	mail_list.add_theme_constant_override("separation", 3)
	list_scroll.add_child(mail_list)

	var body_scroll := ScrollContainer.new()
	body_scroll.custom_minimum_size = Vector2(304, 60)
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.apply_scrollbar(body_scroll)
	column.add_child(body_scroll)
	mail_body = _label("选择一封信阅读。", 12, UITheme.C_INK)
	mail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mail_body.custom_minimum_size = Vector2(284, 0)
	body_scroll.add_child(mail_body)


func open_mail() -> void:
	if is_modal_open():
		return
	mail_body.text = "选择一封信阅读。"
	refresh_mail()
	_set_modal("mail")


func refresh_mail() -> void:
	if farm == null or mail_list == null:
		return
	for child in mail_list.get_children():
		child.queue_free()
	var letters: Array = farm.get_mail_letters()
	if letters.is_empty():
		mail_list.add_child(_label("邮箱里没有新的信件。", 10, UITheme.C_INK_SOFT))
		return
	for letter: Dictionary in letters:
		var button := _clip_button("● %s　%s" % [
			str(letter.get("from", "匿名")), str(letter.get("title", "信件")),
		], 10)
		button.custom_minimum_size = Vector2(298, 16)
		var letter_id := str(letter.get("id", ""))
		button.pressed.connect(func() -> void: _read_mail(letter_id))
		mail_list.add_child(button)


func _read_mail(letter_id: String) -> void:
	if farm == null:
		return
	var letter: Dictionary = farm.read_mail(letter_id)
	if letter.is_empty():
		refresh_mail()
		return
	mail_body.text = "【%s】%s\n\n%s" % [
		str(letter.get("from", "")), str(letter.get("title", "")),
		str(letter.get("body", "")),
	]
	refresh_mail()


# ---------- 地窖 ----------

func _build_cellar() -> void:
	var shell := _modal_shell("地窖", Vector2(360, 220))
	cellar_panel = shell["dim"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)
	var money: Label = shell["money"]
	money.visible = false

	cellar_info = _label("", 10, UITheme.C_INK_SOFT)
	column.add_child(cellar_info)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	column.add_child(columns)
	columns.add_child(_cellar_column("背包（加工品）", true))
	columns.add_child(_cellar_column("地窖熟成", false))


func _cellar_column(title: String, inventory_side: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.add_child(_label(title, 10, UITheme.C_INK))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(148, 132)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.apply_scrollbar(scroll)
	box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5 if inventory_side else 4
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(grid)
	if inventory_side:
		cellar_inv_grid = grid
	else:
		cellar_box_grid = grid
	return box


func open_cellar() -> void:
	if is_modal_open():
		return
	refresh_cellar()
	_set_modal("cellar")


func refresh_cellar() -> void:
	if farm == null or cellar_inv_grid == null:
		return
	for child in cellar_inv_grid.get_children():
		child.queue_free()
	for child in cellar_box_grid.get_children():
		child.queue_free()

	# 背包里所有加工品
	var shown := 0
	for index in farm.inventory.slots.size():
		var slot: Dictionary = farm.inventory.get_slot(index)
		if slot.is_empty() or str(slot.get("category", "")) != "processed":
			continue
		cellar_inv_grid.add_child(_cellar_cell(slot, index, true))
		shown += 1
	for index in maxi(0, 5 - shown):
		cellar_inv_grid.add_child(_cellar_cell({}, -1, true))

	var capacity: int = farm.cellar_capacity()
	var stacks: Array = farm.cellar_items
	for index in capacity:
		var stack: Dictionary = stacks[index] if index < stacks.size() else {}
		cellar_box_grid.add_child(_cellar_cell(stack, index, false))
	cellar_info.text = "每 7 天提升 1 档品质 · %d / %d" % [stacks.size(), capacity]


func _cellar_cell(slot: Dictionary, index: int, from_inventory: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(26, 26)
	button.add_theme_stylebox_override("normal", UITheme.slot_style(false))
	button.add_theme_stylebox_override("hover", UITheme.slot_style(true))
	button.add_theme_stylebox_override("pressed", UITheme.slot_style(true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if slot.is_empty() or index < 0:
		return button

	var item_id := str(slot.get("item_id", ""))
	var category := str(slot.get("category", ""))
	var quality := str(slot.get("quality", "normal"))
	var count := int(slot.get("count", 1))
	button.tooltip_text = "%s ×%d · %s" % [
		DB.get_item_name(item_id, category), count, _quality_text(quality),
	]
	var icon := TextureRect.new()
	icon.texture = UITheme.item_icon(item_id, category)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size = Vector2(18, 18)
	icon.position = Vector2(4, 2)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	var count_label := _label(str(count), 9, UITheme.C_INK)
	count_label.position = Vector2(13, 13)
	button.add_child(count_label)
	if quality != "normal":
		var badge := ColorRect.new()
		badge.color = _quality_color(quality)
		badge.size = Vector2(5, 5)
		badge.position = Vector2(2, 2)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(badge)
	button.pressed.connect(func() -> void:
		if from_inventory:
			farm.cellar_put(index)
		else:
			farm.cellar_take(index)
	)
	return button


func _quality_text(quality: String) -> String:
	match quality:
		"silver":
			return "银"
		"gold":
			return "金"
		"star":
			return "星光"
		_:
			return "普通"


func _quality_color(quality: String) -> Color:
	match quality:
		"silver":
			return Color("#b9c4cc")
		"gold":
			return Color("#e0b84e")
		"star":
			return Color("#e8d36a")
		_:
			return Color("#cbb692")


# ---------- 成就 / 统计 ----------

func _build_achievements() -> void:
	var shell := _modal_shell("成就 / 统计", Vector2(356, 232))
	achievements_panel = shell["dim"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)
	var money: Label = shell["money"]
	money.visible = false

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(304, 154)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.apply_scrollbar(scroll)
	column.add_child(scroll)
	achievements_list = VBoxContainer.new()
	achievements_list.add_theme_constant_override("separation", 5)
	scroll.add_child(achievements_list)


func open_achievements() -> void:
	if is_modal_open():
		close_modal()
	refresh_achievements()
	_set_modal("achievements")


func refresh_achievements() -> void:
	if farm == null or achievements_list == null:
		return
	for child in achievements_list.get_children():
		child.queue_free()
	for item: Dictionary in farm.get_achievement_progress():
		var definition: Dictionary = item.get("definition", {})
		var unlocked := bool(item.get("unlocked", false))
		var value := int(item.get("value", 0))
		var threshold := maxi(1, int(item.get("threshold", 1)))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var mark := _label("★" if unlocked else "·", 12,
			Color("#c58a2e") if unlocked else UITheme.C_INK_SOFT)
		mark.custom_minimum_size = Vector2(12, 12)
		mark.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(mark)
		var info := VBoxContainer.new()
		info.add_theme_constant_override("separation", 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := _label(str(definition.get("name", "")), 12,
			UITheme.C_INK if unlocked else UITheme.C_INK_SOFT)
		info.add_child(title)
		info.add_child(_label(str(definition.get("desc", "")), 10, UITheme.C_INK_SOFT))
		var progress := _label("已完成" if unlocked else "%d / %d" % [
			mini(value, threshold), threshold,
		], 10, Color("#8a6a3f") if unlocked else UITheme.C_INK_SOFT)
		info.add_child(progress)
		row.add_child(info)
		achievements_list.add_child(row)


# ---------- 图书馆 ----------

func _build_library() -> void:
	var shell := _modal_shell("图书馆", Vector2(340, 220))
	library_panel = shell["dim"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)
	var money: Label = shell["money"]
	money.visible = false

	library_info = _label("每天可以读一本书，读完可领取研究奖励。", 10, UITheme.C_INK_SOFT)
	column.add_child(library_info)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(289, 142)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.apply_scrollbar(scroll)
	column.add_child(scroll)
	library_list = VBoxContainer.new()
	library_list.add_theme_constant_override("separation", 5)
	scroll.add_child(library_list)


func open_library() -> void:
	if is_modal_open():
		return
	refresh_library()
	_set_modal("library")


func refresh_library() -> void:
	if farm == null or library_list == null:
		return
	for child in library_list.get_children():
		child.queue_free()
	for entry: Dictionary in farm.get_library_books():
		var book: Dictionary = entry.get("book", {})
		var read := bool(entry.get("read", false))
		var can_read := bool(entry.get("can_read", false))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var texts := VBoxContainer.new()
		texts.add_theme_constant_override("separation", 0)
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var book_name := _clip_label(
			str(book.get("name", "")),
			12, UITheme.C_INK if can_read else UITheme.C_INK_SOFT)
		book_name.custom_minimum_size = Vector2(206, 0)
		texts.add_child(book_name)
		var book_desc := _wrap_label(str(book.get("desc", "")), 10,
			UITheme.C_INK_SOFT, 206.0)
		texts.add_child(book_desc)
		row.add_child(texts)
		var button := _button("已读" if read else "阅读", 10)
		button.custom_minimum_size = Vector2(48, 18)
		button.disabled = read or not can_read
		var book_id := str(book.get("id", ""))
		button.pressed.connect(func() -> void:
			if farm.read_book(book_id):
				refresh_library()
		)
		row.add_child(button)
		library_list.add_child(row)
	if farm.last_book_day == farm.time.get_absolute_day():
		library_info.text = "今天已经读过书了，明天再来。"


# ---------- 诊所 ----------

func _build_clinic() -> void:
	var shell := _modal_shell("诊所", Vector2(320, 196))
	clinic_panel = shell["dim"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)
	var money: Label = shell["money"]
	money.visible = false

	clinic_info = _label("", 10, UITheme.C_INK_SOFT)
	clinic_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clinic_info.custom_minimum_size = Vector2(270, 0)
	column.add_child(clinic_info)

	var treated_button := _button("治疗自己（恢复体力与生命）", 10)
	treated_button.custom_minimum_size = Vector2(270, 20)
	treated_button.pressed.connect(func() -> void:
		if farm.treat_player_at_clinic():
			refresh_clinic()
	)
	column.add_child(treated_button)

	var animal_button := _button("治疗生病动物", 10)
	animal_button.custom_minimum_size = Vector2(270, 20)
	animal_button.pressed.connect(func() -> void:
		farm.treat_sick_animals()
		refresh_clinic()
	)
	column.add_child(animal_button)

	var note := _clip_label("诊所营业 9:00–16:00，治疗按次收费。", 10, UITheme.C_INK_SOFT)
	column.add_child(note)


func open_clinic() -> void:
	if is_modal_open():
		return
	refresh_clinic()
	_set_modal("clinic")


func refresh_clinic() -> void:
	if farm == null or clinic_info == null:
		return
	var prices: Dictionary = farm.clinic_prices()
	var sick: int = farm.sick_animal_count()
	var animal_price := int(prices.get("animal_treatment_price", 100))
	clinic_info.text = "玩家治疗 %d G · 生病动物 %d 只（每只 %d G）" % [
		int(prices.get("treatment_price", 200)), sick, animal_price,
	]


# ---------- 马厩 / 自行车棚 ----------

func _build_mount_panel() -> void:
	var shell := _modal_shell("马厩", Vector2(330, 190))
	mount_panel = shell["dim"]
	mount_title = shell["title"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)

	mount_info = _label("", 10, UITheme.C_INK_SOFT)
	mount_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mount_info.custom_minimum_size = Vector2(280, 0)
	column.add_child(mount_info)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 116)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	UITheme.apply_scrollbar(scroll)
	mount_list = VBoxContainer.new()
	mount_list.add_theme_constant_override("separation", 5)
	mount_list.custom_minimum_size = Vector2(272, 0)
	scroll.add_child(mount_list)


func open_mount_panel(building_id: String) -> void:
	if is_modal_open():
		return
	_mount_building = building_id
	refresh_mount_panel()
	_set_modal("mount")


func refresh_mount_panel() -> void:
	if mount_list == null:
		return
	var titles := {
		"stable": "马厩", "ostrich_house": "鸵鸟舍",
		"bike_shed": "自行车棚", "barn": "畜棚",
	}
	mount_title.text = str(titles.get(_mount_building, "坐骑"))
	mount_info.text = "Shift 冲刺消耗耐力；下坐骑后耐力缓慢恢复。货袋可在骑乘中按 K 打开。"
	for child in mount_list.get_children():
		child.queue_free()
	var entries: Array = farm.get_mounts_in(_mount_building)
	if entries.is_empty() and _mount_building != "barn":
		mount_list.add_child(_label(
			"这里还没有坐骑。先在公告板建造，再去杂货铺「牧场」页购买。",
			11, UITheme.C_INK_SOFT))
		return
	for entry: Dictionary in entries:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.row_style())
		mount_list.add_child(row)
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		row.add_child(box)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(texts)
		texts.add_child(_clip_label(str(entry.get("name", "")), 12, UITheme.C_INK))
		var detail := "耐力 %d/%d" % [
			int(entry.get("stamina", 0)), int(entry.get("max_stamina", 0)),
		]
		if _mount_building == "bike_shed":
			detail = "状态良好 · 冲刺冷却 2 秒"
		else:
			detail = "好感 %d · %s" % [int(entry.get("friendship", 0)), detail]
		var cargo_capacity := int(entry.get("cargo_capacity", 0))
		if cargo_capacity > 0:
			detail += " · 载货 %d/%d" % [int(entry.get("cargo_used", 0)), cargo_capacity]
		texts.add_child(_wrap_label(detail, 10, UITheme.C_INK_SOFT, 96.0))
		var mount_id := str(entry.get("id", ""))
		var ride := _button("骑乘", 10)
		ride.custom_minimum_size = Vector2(36, 15)
		ride.pressed.connect(func() -> void:
			close_modal()
			farm.mount_mount(mount_id)
		)
		box.add_child(ride)
		if _mount_building in ["stable", "ostrich_house", "barn"]:
			var feed := _button("喂食", 10)
			feed.custom_minimum_size = Vector2(36, 15)
			feed.disabled = bool(entry.get("fed_today", false))
			feed.pressed.connect(func() -> void:
				farm.feed_mount(mount_id)
				refresh_mount_panel()
			)
			box.add_child(feed)
			var pet := _button("抚摸", 10)
			pet.custom_minimum_size = Vector2(36, 15)
			pet.disabled = bool(entry.get("petted_today", false))
			pet.pressed.connect(func() -> void:
				farm.pet_mount(mount_id)
				refresh_mount_panel()
			)
			box.add_child(pet)
		if cargo_capacity > 0:
			var cargo_button := _button("货袋", 10)
			cargo_button.custom_minimum_size = Vector2(36, 15)
			cargo_button.pressed.connect(func() -> void:
				close_modal()
				open_mount_cargo(mount_id)
			)
			box.add_child(cargo_button)

	# 畜棚：牛是动物本体，单独列出
	if _mount_building == "barn":
		for cow_entry: Dictionary in farm.get_barn_mount_entries():
			var row := PanelContainer.new()
			row.add_theme_stylebox_override("panel", UITheme.row_style())
			mount_list.add_child(row)
			var box := HBoxContainer.new()
			box.add_theme_constant_override("separation", 8)
			row.add_child(box)
			var texts := VBoxContainer.new()
			texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			box.add_child(texts)
			texts.add_child(_clip_label(str(cow_entry.get("name", "牛")), 12, UITheme.C_INK))
			var detail := "好感 %d · 耐力 %d/%d" % [
				int(cow_entry.get("friendship", 0)),
				int(cow_entry.get("stamina", 0)),
				int(cow_entry.get("max_stamina", 0)),
			]
			var reason := str(cow_entry.get("reason", ""))
			if not reason.is_empty():
				detail += " · " + reason
			texts.add_child(_wrap_label(detail, 10, UITheme.C_INK_SOFT, 190.0))
			var cow_index := int(cow_entry.get("index", 0))
			var ride := _button("骑乘", 10)
			ride.custom_minimum_size = Vector2(36, 15)
			ride.disabled = not bool(cow_entry.get("rideable", false))
			ride.pressed.connect(func() -> void:
				close_modal()
				farm.mount_barn_animal(cow_index)
			)
			box.add_child(ride)


# ---------- 坐骑货袋 ----------

func _build_mount_cargo() -> void:
	var shell := _modal_shell("坐骑货袋", Vector2(330, 190))
	mount_cargo_panel = shell["dim"]
	mount_cargo_title = shell["title"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)

	mount_cargo_info = _label("", 10, UITheme.C_INK_SOFT)
	mount_cargo_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mount_cargo_info.custom_minimum_size = Vector2(280, 0)
	column.add_child(mount_cargo_info)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 78)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	UITheme.apply_scrollbar(scroll)
	mount_cargo_list = VBoxContainer.new()
	mount_cargo_list.add_theme_constant_override("separation", 4)
	mount_cargo_list.custom_minimum_size = Vector2(272, 0)
	scroll.add_child(mount_cargo_list)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)
	var store_button := _button("存入手持物品", 10)
	store_button.custom_minimum_size = Vector2(86, 16)
	store_button.pressed.connect(func() -> void:
		farm.store_held_to_cargo(_cargo_mount_id)
		refresh_mount_cargo()
	)
	buttons.add_child(store_button)
	var take_button := _button("全部取出", 10)
	take_button.custom_minimum_size = Vector2(62, 16)
	take_button.pressed.connect(func() -> void:
		farm.take_all_cargo(_cargo_mount_id)
		refresh_mount_cargo()
	)
	buttons.add_child(take_button)


func open_mount_cargo(mount_id: String) -> void:
	if is_modal_open():
		return
	_cargo_mount_id = mount_id
	refresh_mount_cargo()
	_set_modal("mount_cargo")


func refresh_mount_cargo() -> void:
	if mount_cargo_list == null:
		return
	var cargo: Dictionary = farm.get_mount_cargo(_cargo_mount_id)
	mount_cargo_title.text = "货袋 · %s" % str(cargo.get("name", "坐骑"))
	mount_cargo_info.text = "载货 %d/%d · 不能存放工具与任务物品。" % [
		int(cargo.get("used", 0)), int(cargo.get("capacity", 0)),
	]
	for child in mount_cargo_list.get_children():
		child.queue_free()
	var items: Array = cargo.get("items", [])
	if items.is_empty():
		mount_cargo_list.add_child(_label("货袋是空的。骑乘中按 K 可随时打开。", 11, UITheme.C_INK_SOFT))
		return
	for stack: Dictionary in items:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.row_style())
		mount_cargo_list.add_child(row)
		var label := _clip_label("%s ×%d" % [
			DB.get_item_name(str(stack.get("item_id", "")), str(stack.get("category", ""))),
			int(stack.get("count", 1)),
		], 11, UITheme.C_INK)
		row.add_child(label)


# ---------- 宠物面板 ----------

func _build_pet_panel() -> void:
	var shell := _modal_shell("宠物", Vector2(340, 204))
	pet_panel = shell["dim"]
	pet_title = shell["title"]
	var money: Label = shell["money"]
	money.visible = false
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)

	pet_info = _label("", 10, UITheme.C_INK_SOFT)
	pet_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pet_info.custom_minimum_size = Vector2(286, 0)
	column.add_child(pet_info)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(286, 118)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	UITheme.apply_scrollbar(scroll)
	pet_box = VBoxContainer.new()
	pet_box.add_theme_constant_override("separation", 5)
	pet_box.custom_minimum_size = Vector2(278, 0)
	scroll.add_child(pet_box)


func _build_pet_name_panel() -> void:
	var shell := _modal_shell("给宠物起名", Vector2(300, 132))
	pet_name_panel = shell["dim"]
	var money: Label = shell["money"]
	money.visible = false
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(_cancel_pet_name)
	var info := _label("最多 8 个字；每只宠物只能改名一次。", 10, UITheme.C_INK_SOFT)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(250, 0)
	column.add_child(info)
	pet_name_input = LineEdit.new()
	pet_name_input.add_theme_font_override("font", font)
	pet_name_input.add_theme_font_size_override("font_size", 12)
	pet_name_input.add_theme_color_override("font_color", UITheme.C_INK)
	pet_name_input.add_theme_stylebox_override("normal", UITheme.slot_style(false))
	pet_name_input.add_theme_stylebox_override("focus", UITheme.slot_style(true))
	pet_name_input.max_length = 8
	pet_name_input.custom_minimum_size = Vector2(250, 22)
	pet_name_input.placeholder_text = "输入宠物名字"
	column.add_child(pet_name_input)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var ok := _button("确定", 10)
	ok.custom_minimum_size = Vector2(56, 18)
	ok.pressed.connect(_confirm_pet_name)
	row.add_child(ok)
	var cancel := _button("取消", 10)
	cancel.custom_minimum_size = Vector2(56, 18)
	cancel.pressed.connect(_cancel_pet_name)
	row.add_child(cancel)


func open_pet_name_dialog(pet_id: String, return_to_panel := false) -> void:
	if is_modal_open():
		return
	_name_pet_id = pet_id
	_name_return_panel = return_to_panel
	var data: Dictionary = farm.get_pet_panel_data(pet_id)
	pet_name_input.text = str(data.get("base_name", ""))
	_set_modal("pet_name")
	pet_name_input.grab_focus()
	pet_name_input.select_all()


func _confirm_pet_name() -> void:
	var pet_id := _name_pet_id
	var success: bool = farm.rename_pet(pet_id, pet_name_input.text)
	close_modal()
	if success and _name_return_panel:
		open_pet_panel(pet_id)


func _cancel_pet_name() -> void:
	var pet_id := _name_pet_id
	var return_panel := _name_return_panel
	close_modal()
	if return_panel and not pet_id.is_empty():
		open_pet_panel(pet_id)


func open_pet_panel(pet_id: String) -> void:
	if is_modal_open():
		return
	_pet_panel_id = pet_id
	refresh_pet_panel()
	_set_modal("pet")


func _pet_row(name_text: String, detail: String, action: Callable,
		button_text := "查看") -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UITheme.row_style())
	pet_box.add_child(row)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(texts)
	texts.add_child(_clip_label(name_text, 11, UITheme.C_INK))
	texts.add_child(_clip_label(detail, 10, UITheme.C_INK_SOFT))
	var button := _button(button_text, 10)
	button.custom_minimum_size = Vector2(40, 15)
	button.pressed.connect(action)
	box.add_child(button)


func refresh_pet_panel() -> void:
	if pet_box == null:
		return
	for child in pet_box.get_children():
		child.queue_free()
	var data: Dictionary = farm.get_pet_panel_data(_pet_panel_id)
	if _pet_panel_id.is_empty() or data.is_empty():
		_pet_panel_id = ""
		pet_title.text = "宠物"
		var ids: Array = farm.get_pet_ids()
		pet_info.text = "共 %d 只 · 上限 %d · 点击查看状态" % [
			ids.size(), int(farm.get_pet_limit()),
		]
		if ids.is_empty():
			pet_box.add_child(_label(
				"还没有宠物。去杂货铺「宠物」页领养，或按 E 与院子里的宠物互动。",
				11, UITheme.C_INK_SOFT))
			return
		for pet_id: Variant in ids:
			var current_id := str(pet_id)
			var entry: Dictionary = farm.get_pet_panel_data(current_id)
			if entry.is_empty():
				continue
			var detail := "%s · 好感 %d · 心情 %d" % [
				str(entry.get("breed", "")), int(entry.get("friendship", 0)),
				int(entry.get("mood", 0)),
			]
			if bool(entry.get("missing", false)):
				detail = "离家出走 · 已 %d 天" % int(entry.get("missing_days", 0))
			_pet_row(str(entry.get("name", "")), detail,
				func() -> void:
					_pet_panel_id = current_id
					refresh_pet_panel(),
				"查看")
		var all_button := _button("打开宠物店", 10)
		all_button.custom_minimum_size = Vector2(0, 16)
		all_button.pressed.connect(func() -> void:
			close_modal()
			open_shop()
			_switch_shop_tab("pets")
		)
		pet_box.add_child(all_button)
		return

	pet_title.text = str(data.get("name", "宠物"))
	var status := ""
	if bool(data.get("missing", false)):
		status = " · 离家出走第 %d 天（3 天内可找回）" % int(data.get("missing_days", 0))
	elif bool(data.get("released", false)):
		status = " · 已放出（%d 秒后回栖息地）" % int(data.get("release_timer", 0))
	elif bool(data.get("sleeping", false)):
		status = " · 在床边睡觉"
	elif bool(data.get("sick", false)):
		status = " · 生病，需要宠物药"
	elif bool(data.get("basking", false)):
		status = " · 晒背中"
	pet_info.text = "%s（%s）%s\n好感 %d · 心情 %d · 饥饿 %d · 清洁 %d · 健康 %d\n栖息地：%s Lv.%d · 容量 %d（清洁 %d）" % [
		str(data.get("name", "")), str(data.get("breed", "")), status,
		int(data.get("friendship", 0)), int(data.get("mood", 0)),
		int(data.get("hunger", 0)), int(data.get("cleanliness", 0)),
		int(data.get("health", 0)), str(data.get("house_name", "无")),
		int(data.get("house_level", 1)), int(data.get("house_capacity", 1)),
		int(data.get("house_cleanliness", 0)),
	]
	if bool(data.get("young", false)):
		pet_info.text += "\n成长：%d / %d 天（散步可加速）" % [
			int(data.get("age_days", 0)), int(data.get("growth_days", 5)),
		]
	var pet_id := str(data.get("id", ""))
	var food_id := str(data.get("food_id", ""))
	var food_name := str(DB.get_pet_food(food_id).get("name", "食物"))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 5)
	pet_box.add_child(actions)
	var feed := _button("喂食 %s" % food_name, 10)
	feed.custom_minimum_size = Vector2(74, 16)
	feed.disabled = bool(data.get("fed_today", false)) or bool(data.get("missing", false))
	feed.pressed.connect(func() -> void:
		farm.pet_action(pet_id, "feed")
		refresh_pet_panel()
	)
	actions.add_child(feed)
	var pet_button := _button("抚摸", 10)
	pet_button.custom_minimum_size = Vector2(38, 16)
	pet_button.disabled = bool(data.get("petted_today", false)) \
		or not bool(data.get("can_pet", false)) or bool(data.get("missing", false))
	pet_button.pressed.connect(func() -> void:
		farm.pet_action(pet_id, "pet")
		refresh_pet_panel()
	)
	actions.add_child(pet_button)
	var play := _button("玩耍", 10)
	play.custom_minimum_size = Vector2(38, 16)
	play.disabled = bool(data.get("played_today", false)) \
		or not bool(data.get("can_play", false)) or bool(data.get("missing", false))
	play.pressed.connect(func() -> void:
		farm.pet_action(pet_id, "play")
		refresh_pet_panel()
	)
	actions.add_child(play)

	var actions2 := HBoxContainer.new()
	actions2.add_theme_constant_override("separation", 5)
	pet_box.add_child(actions2)
	var clean_label := "清理"
	if str(data.get("type", "")) in ["fish", "turtle", "reptile", "aquatic_extended"]:
		clean_label = "换水"
	var clean := _button(clean_label, 10)
	clean.custom_minimum_size = Vector2(38, 16)
	clean.disabled = bool(data.get("cleaned_today", false)) or bool(data.get("missing", false))
	clean.pressed.connect(func() -> void:
		farm.pet_action(pet_id, "clean")
		refresh_pet_panel()
	)
	actions2.add_child(clean)
	if bool(data.get("young", false)):
		var walk := _button("散步", 10)
		walk.custom_minimum_size = Vector2(38, 16)
		walk.disabled = bool(data.get("walked_today", false)) \
			or bool(data.get("missing", false))
		walk.pressed.connect(func() -> void:
			farm.pet_action(pet_id, "walk")
			refresh_pet_panel()
		)
		actions2.add_child(walk)
	if bool(data.get("can_release", false)):
		var release := _button("放出", 10)
		release.custom_minimum_size = Vector2(38, 16)
		release.disabled = bool(data.get("released", false)) \
			or bool(data.get("missing", false)) \
			or float(data.get("friendship", 0)) < float(data.get("release_friendship", 50))
		release.pressed.connect(func() -> void:
			farm.pet_action(pet_id, "release")
			refresh_pet_panel()
		)
		actions2.add_child(release)
	if str(data.get("type", "")) == "insect":
		var battle := _button("斗虫", 10)
		battle.custom_minimum_size = Vector2(38, 16)
		battle.disabled = bool(data.get("battled_today", false)) \
			or bool(data.get("missing", false))
		battle.pressed.connect(func() -> void:
			farm.pet_action(pet_id, "battle")
			refresh_pet_panel()
		)
		actions2.add_child(battle)
	if not bool(data.get("name_changed", false)) and not bool(data.get("missing", false)):
		var rename := _button("改名", 10)
		rename.custom_minimum_size = Vector2(38, 16)
		rename.pressed.connect(func() -> void:
			close_modal()
			open_pet_name_dialog(pet_id, true)
		)
		actions2.add_child(rename)
	if bool(data.get("sick", false)):
		var heal := _button("治疗 200G", 10)
		heal.custom_minimum_size = Vector2(64, 16)
		heal.pressed.connect(func() -> void:
			farm.pet_action(pet_id, "heal")
			refresh_pet_panel()
		)
		actions2.add_child(heal)
	if bool(data.get("missing", false)):
		var recover := _button("找回", 10)
		recover.custom_minimum_size = Vector2(38, 16)
		recover.pressed.connect(func() -> void:
			farm.pet_action(pet_id, "recover")
			refresh_pet_panel()
		)
		actions2.add_child(recover)
	var back := _button("返回列表", 10)
	back.custom_minimum_size = Vector2(56, 16)
	back.pressed.connect(func() -> void:
		_pet_panel_id = ""
		refresh_pet_panel()
	)
	actions2.add_child(back)

	var house_id := str(data.get("house_id", ""))
	if not house_id.is_empty():
		var actions3 := HBoxContainer.new()
		actions3.add_theme_constant_override("separation", 5)
		pet_box.add_child(actions3)
		var level := int(data.get("house_level", 1))
		var max_level := int(data.get("house_max_level", 1))
		if level < max_level:
			var cost := int(data.get("house_upgrade_cost", 0))
			var upgrade := _button("升级 %dG" % cost, 10)
			upgrade.custom_minimum_size = Vector2(72, 16)
			upgrade.disabled = farm.money < cost or bool(data.get("missing", false))
			upgrade.pressed.connect(func() -> void:
				farm.upgrade_pet_house(house_id)
				refresh_pet_panel()
			)
			actions3.add_child(upgrade)
		var move := _button("搬迁", 10)
		move.custom_minimum_size = Vector2(50, 16)
		move.pressed.connect(func() -> void:
			close_modal()
			farm.begin_move_pet_house(house_id)
		)
		actions3.add_child(move)
		var next_decoration: Dictionary = data.get("next_decoration", {})
		if not next_decoration.is_empty():
			var deco_price := int(next_decoration.get("price", 0))
			var decorate := _button("装饰 %dG" % deco_price, 10)
			decorate.custom_minimum_size = Vector2(72, 16)
			decorate.disabled = farm.money < deco_price \
				or bool(data.get("missing", false))
			decorate.pressed.connect(func() -> void:
				farm.add_pet_house_decoration(house_id)
				refresh_pet_panel()
			)
			actions3.add_child(decorate)


# ---------- 商店 ----------

func _build_shop() -> void:
	var shell := _modal_shell("杂货铺", Vector2(372, 204))
	shop_panel = shell["dim"]
	shop_money_label = shell["money"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	column.add_child(columns)

	var buy_column := VBoxContainer.new()
	buy_column.custom_minimum_size = Vector2(178, 0)
	buy_column.add_theme_constant_override("separation", 4)
	columns.add_child(buy_column)

	var tabs := GridContainer.new()
	tabs.columns = 4
	tabs.add_theme_constant_override("h_separation", 4)
	tabs.add_theme_constant_override("v_separation", 3)
	buy_column.add_child(tabs)

	_shop_seed_tab = _clip_button("种子", 11)
	_shop_seed_tab.custom_minimum_size = Vector2(38, 14)
	_shop_seed_tab.pressed.connect(func() -> void: _switch_shop_tab("seeds"))
	_compact_tab(_shop_seed_tab)
	tabs.add_child(_shop_seed_tab)

	_shop_animal_tab = _clip_button("牧场", 11)
	_shop_animal_tab.custom_minimum_size = Vector2(38, 14)
	_shop_animal_tab.pressed.connect(func() -> void: _switch_shop_tab("animals"))
	_compact_tab(_shop_animal_tab)
	tabs.add_child(_shop_animal_tab)

	_shop_pet_tab = _clip_button("宠物", 11)
	_shop_pet_tab.custom_minimum_size = Vector2(38, 14)
	_shop_pet_tab.pressed.connect(func() -> void: _switch_shop_tab("pets"))
	_compact_tab(_shop_pet_tab)
	tabs.add_child(_shop_pet_tab)

	_shop_bee_tab = _clip_button("养蜂", 11)
	_shop_bee_tab.custom_minimum_size = Vector2(38, 14)
	_shop_bee_tab.pressed.connect(func() -> void: _switch_shop_tab("bees"))
	_compact_tab(_shop_bee_tab)
	tabs.add_child(_shop_bee_tab)

	_shop_tree_tab = _clip_button("果树", 11)
	_shop_tree_tab.custom_minimum_size = Vector2(38, 14)
	_shop_tree_tab.pressed.connect(func() -> void: _switch_shop_tab("trees"))
	_compact_tab(_shop_tree_tab)
	tabs.add_child(_shop_tree_tab)

	_shop_accessory_tab = _clip_button("饰品", 11)
	_shop_accessory_tab.custom_minimum_size = Vector2(38, 14)
	_shop_accessory_tab.pressed.connect(func() -> void: _switch_shop_tab("accessories"))
	_compact_tab(_shop_accessory_tab)
	tabs.add_child(_shop_accessory_tab)

	_shop_machine_tab = _clip_button("加工", 11)
	_shop_machine_tab.custom_minimum_size = Vector2(38, 14)
	_shop_machine_tab.pressed.connect(func() -> void: _switch_shop_tab("machines"))
	_compact_tab(_shop_machine_tab)
	tabs.add_child(_shop_machine_tab)

	_shop_furniture_tab = _clip_button("家具", 11)
	_shop_furniture_tab.custom_minimum_size = Vector2(38, 14)
	_shop_furniture_tab.pressed.connect(func() -> void: _switch_shop_tab("furniture"))
	_compact_tab(_shop_furniture_tab)
	tabs.add_child(_shop_furniture_tab)

	var buy_scroll := ScrollContainer.new()
	buy_scroll.custom_minimum_size = Vector2(166, 112)
	buy_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	buy_column.add_child(buy_scroll)
	shop_buy_list = VBoxContainer.new()
	shop_buy_list.add_theme_constant_override("separation", 4)
	shop_buy_list.custom_minimum_size = Vector2(164, 0)
	buy_scroll.add_child(shop_buy_list)

	var sell_column := VBoxContainer.new()
	sell_column.custom_minimum_size = Vector2(124, 0)
	sell_column.add_theme_constant_override("separation", 5)
	columns.add_child(sell_column)
	var sell_title := _label("出售（左键 1 / Shift 5）", 11, UITheme.C_INK)
	sell_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sell_title.custom_minimum_size = Vector2(118, 0)
	sell_column.add_child(sell_title)

	var sell_scroll := ScrollContainer.new()
	sell_scroll.custom_minimum_size = Vector2(112, 96)
	sell_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sell_column.add_child(sell_scroll)
	shop_sell_list = VBoxContainer.new()
	shop_sell_list.add_theme_constant_override("separation", 4)
	shop_sell_list.custom_minimum_size = Vector2(120, 0)
	sell_scroll.add_child(shop_sell_list)

	shop_sell_all = _button("全部出售", 11)
	shop_sell_all.custom_minimum_size = Vector2(0, 20)
	shop_sell_all.pressed.connect(func() -> void: farm.sell_all())
	sell_column.add_child(shop_sell_all)


# ---------- 帮助 ----------

func _build_help() -> void:
	var shell := _modal_shell("操作说明", Vector2(300, 208))
	help_panel = shell["dim"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(func() -> void: toggle_help())
	var money: Label = shell["money"]
	money.visible = false

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(252, 132)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	UITheme.apply_scrollbar(scroll)

	var text := _label(
		"WASD / 方向键　移动\n" +
		"鼠标左键　　　对附近地块使用手持物品\n" +
		"空格　　　　　对面前地块使用手持物品\n" +
		"E　　　　　　 互动（睡觉 / 商店 / 出货箱 / 喂食 / 摸动物 / 照镜子）\n" +
		"F　　　　　　 在池塘边钓鱼\n" +
		"I / Tab　　　 打开背包\n" +
		"M　　　　　　 打开农场地图\n" +
		"C　　　　　　 打开图鉴（收集/排序）\n" +
		"G　　　　　　 给附近村民送礼\n" +
		"R　　　　　　 骑乘 / 下坐骑（也可在坐骑旁按 E）\n" +
		"Shift　　　　 骑乘冲刺（消耗坐骑耐力）\n" +
		"K　　　　　　 骑乘中打开坐骑货袋（驴 / 骆驼 / 自行车）\n" +
		"P　　　　　　 打开宠物面板（状态 / 喂食 / 抚摸 / 清理）\n" +
		"U　　　　　　 室内升级自宅\n" +
		"1-0 / 滚轮　　切换手持物品\n" +
		"= / -　　　　 画面放大 / 缩小\n" +
		"F5 / F9　　　 保存 / 读档\n" +
		"H / Esc　　　 帮助 / 关闭窗口\n\n" +
		"流程：锄地 → 播种 → 每天浇水 → 成熟后收获 → 出货箱或商店卖钱 → 买更多种子。\n" +
		"天气：雨天会自动浇水。作物只在浇过水的夜里生长。\n" +
		"时间：06:00 开始，一天到次日 06:00；室内与打开菜单时时间暂停。\n" +
		"牧场：在商店买鸡或牛，站到食槽旁按 E 喂食，第二天动物会产出蛋奶。\n" +
		"坐骑：公告板建造马厩/自行车棚后，在商店「牧场」页购买；牛需好感≥60 才能骑。\n" +
		"外观：在房子门口的镜子前按 E，可以随时修改角色外观。",
		11, UITheme.C_INK
	)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(238, 0)
	scroll.add_child(text)


# ---------- 存档槽 ----------

func _build_save_panel() -> void:
	var shell := _modal_shell("存档", Vector2(356, 238))
	save_panel = shell["dim"]
	var money: Label = shell["money"]
	money.visible = false
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)

	column.add_child(_label("选择存档槽：同一槽位会覆盖旧进度，并保留上一次的备份。", 10, UITheme.C_INK_SOFT))

	save_list = VBoxContainer.new()
	save_list.add_theme_constant_override("separation", 6)
	column.add_child(save_list)

	var transfer_row := HBoxContainer.new()
	transfer_row.add_theme_constant_override("separation", 4)
	column.add_child(transfer_row)
	transfer_row.add_child(_label("目标槽", 10, UITheme.C_INK_SOFT))
	_transfer_slot_select = OptionButton.new()
	UITheme.apply_button(_transfer_slot_select, 10)
	_transfer_slot_select.custom_minimum_size = Vector2(62, 17)
	for slot in range(1, SaveSystem.SLOT_COUNT + 1):
		_transfer_slot_select.add_item("存档 %d" % slot)
	_transfer_slot_select.select(SaveSystem.get_slot() - 1)
	transfer_row.add_child(_transfer_slot_select)
	var export_button := _button("导出", 10)
	export_button.custom_minimum_size = Vector2(40, 17)
	export_button.pressed.connect(_open_export_dialog)
	transfer_row.add_child(export_button)
	var import_button := _button("导入", 10)
	import_button.custom_minimum_size = Vector2(40, 17)
	import_button.pressed.connect(_open_import_dialog)
	transfer_row.add_child(import_button)


func open_save_panel() -> void:
	if is_modal_open():
		return
	refresh_save_panel()
	if _transfer_slot_select != null:
		_transfer_slot_select.select(SaveSystem.get_slot() - 1)
	_set_modal("save")


func refresh_save_panel() -> void:
	for child in save_list.get_children():
		child.queue_free()

	for slot in range(1, SaveSystem.SLOT_COUNT + 1):
		var summary := SaveSystem.get_slot_summary(slot)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.row_style())
		save_list.add_child(row)

		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		row.add_child(box)

		# 缩略图（72×41，最近邻）
		var thumb_panel := PanelContainer.new()
		thumb_panel.custom_minimum_size = Vector2(72, 41)
		thumb_panel.add_theme_stylebox_override("panel", UITheme.slot_style(false))
		var thumb := TextureRect.new()
		thumb.texture = SaveSystem.load_thumbnail(slot)
		thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		thumb.custom_minimum_size = Vector2(68, 37)
		thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb_panel.add_child(thumb)
		box.add_child(thumb_panel)

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(texts)
		var farm_title := str(summary.get("farm_name", ""))
		var slot_title := "存档槽 %d" % slot
		if not farm_title.is_empty():
			slot_title += "　" + farm_title
		var title_label := _label(slot_title, 11, UITheme.C_INK)
		title_label.clip_text = true
		title_label.custom_minimum_size = Vector2(160, 0)
		texts.add_child(title_label)

		if bool(summary.get("exists", false)):
			var minutes := int(float(summary.get("play_time_seconds", 0.0)) / 60.0)
			var hours := int(minutes / 60)
			var line_one := _label(
				"%s%d日 · %d年 · %dG" % [
					DB.season_name(str(summary.get("season", "spring"))),
					int(summary.get("day", 1)),
					int(summary.get("year", 1)),
					int(summary.get("money", 0)),
				],
				11, UITheme.C_INK_SOFT
			)
			line_one.clip_text = true
			line_one.custom_minimum_size = Vector2(160, 0)
			texts.add_child(line_one)
			var player_title := str(summary.get("player_name", ""))
			var play_prefix := "游玩 "
			if not player_title.is_empty():
				play_prefix = player_title + " · "
			var saved_at := str(summary.get("saved_at", ""))
			var saved_date := saved_at.substr(0, 10) if saved_at.length() >= 10 else saved_at
			var line_two := _label(
				play_prefix + "%02d:%02d · %s" % [hours, minutes % 60, saved_date],
				10, UITheme.C_INK_SOFT
			)
			line_two.clip_text = true
			line_two.custom_minimum_size = Vector2(160, 0)
			texts.add_child(line_two)
		else:
			texts.add_child(_label("空", 10, UITheme.C_INK_SOFT))

		var save_button := _button("保存", 10)
		save_button.custom_minimum_size = Vector2(30, 15)
		save_button.pressed.connect(func() -> void:
			SaveSystem.set_slot(slot)
			if _transfer_slot_select != null:
				_transfer_slot_select.select(slot - 1)
			farm.save_game(false)
			refresh_save_panel()
		)
		box.add_child(save_button)

		var load_button := _button("读取", 10)
		load_button.custom_minimum_size = Vector2(30, 15)
		load_button.disabled = not bool(summary.get("exists", false))
		load_button.pressed.connect(func() -> void:
			SaveSystem.set_slot(slot)
			if _transfer_slot_select != null:
				_transfer_slot_select.select(slot - 1)
			farm.request_load()
			close_modal()
		)
		box.add_child(load_button)


func _open_export_dialog() -> void:
	_export_slot = _transfer_slot_select.selected + 1 \
		if _transfer_slot_select != null else SaveSystem.get_slot()
	if _export_dialog == null:
		_export_dialog = FileDialog.new()
		_export_dialog.title = "导出存档"
		_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_export_dialog.use_native_dialog = true
		_export_dialog.size = Vector2i(620, 380)
		_export_dialog.filters = PackedStringArray(["*.json ; 农场存档"])
		_export_dialog.file_selected.connect(_on_export_selected)
		root.add_child(_export_dialog)
	_export_dialog.current_file = "farm_save_%d.json" % _export_slot
	_export_dialog.popup_centered()


func _on_export_selected(path: String) -> void:
	farm.export_save_slot(_export_slot, path)
	refresh_save_panel()


func _open_import_dialog() -> void:
	_import_slot = _transfer_slot_select.selected + 1 \
		if _transfer_slot_select != null else SaveSystem.get_slot()
	if _import_dialog == null:
		_import_dialog = FileDialog.new()
		_import_dialog.title = "导入存档"
		_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_import_dialog.use_native_dialog = true
		_import_dialog.size = Vector2i(620, 380)
		_import_dialog.filters = PackedStringArray(["*.json ; 农场存档"])
		_import_dialog.file_selected.connect(_on_import_selected)
		root.add_child(_import_dialog)
	_import_dialog.popup_centered()


func _on_import_selected(path: String) -> void:
	var target_slot := _import_slot
	var confirm := ConfirmationDialog.new()
	confirm.title = "导入存档"
	confirm.dialog_text = "导入会覆盖存档槽 %d（仍会保留备份）。\n确定导入吗？" % target_slot
	confirm.ok_button_text = "导入"
	confirm.cancel_button_text = "取消"
	confirm.confirmed.connect(func() -> void:
		farm.import_save_slot(path, target_slot)
		refresh_save_panel()
		confirm.queue_free()
	)
	add_child(confirm)
	confirm.popup_centered()


# ---------- 设置 ----------

func _build_settings_panel() -> void:
	var shell := _modal_shell("设置", Vector2(324, 212))
	settings_panel = shell["dim"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)

	var money_label_in_header: Label = shell["money"]
	money_label_in_header.visible = false

	settings_box = VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 2)
	column.add_child(settings_box)

	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 6)
	column.add_child(bottom_row)
	var achievements_button := _button("成就 / 统计", 10)
	achievements_button.custom_minimum_size = Vector2(140, 18)
	achievements_button.pressed.connect(open_achievements)
	bottom_row.add_child(achievements_button)
	var credits_button := _button("制作人员", 10)
	credits_button.custom_minimum_size = Vector2(120, 18)
	credits_button.pressed.connect(open_credits)
	bottom_row.add_child(credits_button)


func _build_credits() -> void:
	var shell := _modal_shell("制作人员", Vector2(360, 200))
	credits_panel = shell["dim"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)
	var money: Label = shell["money"]
	money.visible = false

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(304, 134)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.apply_scrollbar(scroll)
	column.add_child(scroll)

	var text := _label(
		"引擎：Godot 4.7.2（MIT License）\n\n" +
		"字体：Fusion Pixel 12px · TakWolf · SIL OFL 1.1\n" +
		"文件：assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf\n\n" +
		"BGM：Zane Little《A Bag of Chips》\n" +
		"来源：OpenGameArt.org · CC0 1.0（无需署名）\n\n" +
		"音效：Kenney · RPG Audio / Interface Sounds / Impact Sounds\n" +
		"来源：kenney.nl · CC0 1.0（无需署名）\n" +
		"授权原文：audio/LICENSES/\n\n" +
		"世界美术与 UI：本项目程序化生成\n" +
		"（scripts/art/PixelArt.gd、scripts/ui/PixelTheme.gd）\n\n" +
		"风格参考：Stardew Valley。未使用、描图或复制其任何素材。",
		12, UITheme.C_INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(282, 0)
	scroll.add_child(text)


func open_credits() -> void:
	if is_modal_open():
		close_modal()
	_set_modal("credits")


func open_settings_panel() -> void:
	if is_modal_open():
		return
	refresh_settings_panel()
	_set_modal("settings")


## 音量行：像素风的「− 数值 +」，不用引擎默认滑块。
func _volume_row(label_text: String, settings_key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var label := _label(label_text, 11, UITheme.C_INK)
	label.custom_minimum_size = Vector2(48, 22)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	var value := float(AudioManager.get_setting(settings_key, 0.8))
	var value_label := _label("%d%%" % int(round(value * 100)), 11, UITheme.C_INK)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.custom_minimum_size = Vector2(34, 22)
	row.add_child(value_label)

	var minus := _button("-", 10)
	minus.custom_minimum_size = Vector2(20, 22)
	minus.pressed.connect(func() -> void:
		var next := clampf(roundf((value - 0.1) * 10.0) / 10.0, 0.0, 1.0)
		AudioManager.set_volume(settings_key.replace("_volume", ""), next)
		refresh_settings_panel()
	)
	row.add_child(minus)

	var plus := _button("+", 10)
	plus.custom_minimum_size = Vector2(20, 22)
	plus.pressed.connect(func() -> void:
		var next := clampf(roundf((value + 0.1) * 10.0) / 10.0, 0.0, 1.0)
		AudioManager.set_volume(settings_key.replace("_volume", ""), next)
		refresh_settings_panel()
	)
	row.add_child(plus)

	return row


func _option_row(label_text: String, options: Array, current: String, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)

	var label := _label(label_text, 11, UITheme.C_INK)
	label.custom_minimum_size = Vector2(48, 22)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	for option: Dictionary in options:
		var id := str(option.get("id", ""))
		var text := str(option.get("text", id))
		var button := _button(("· %s" % text) if id == current else text, 8)
		button.custom_minimum_size = Vector2(0, 16)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_color_override("font_color", UITheme.C_ACCENT if id == current else UITheme.C_INK)
		button.pressed.connect(func() -> void:
			on_change.call(id)
			refresh_settings_panel()
		)
		row.add_child(button)
	return row


func refresh_settings_panel() -> void:
	for child in settings_box.get_children():
		child.queue_free()

	var audio_title := _label("音频", 10, UITheme.C_ACCENT)
	audio_title.custom_minimum_size = Vector2(0, 16)
	audio_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	settings_box.add_child(audio_title)

	var audio_grid := GridContainer.new()
	audio_grid.columns = 2
	audio_grid.add_theme_constant_override("h_separation", 6)
	audio_grid.add_theme_constant_override("v_separation", 2)
	settings_box.add_child(audio_grid)
	audio_grid.add_child(_volume_row("主音量", "master_volume"))
	audio_grid.add_child(_volume_row("音效", "sfx_volume"))
	audio_grid.add_child(_volume_row("BGM", "bgm_volume"))
	audio_grid.add_child(_volume_row("环境", "ambient_volume"))

	var game_title := _label("游戏", 10, UITheme.C_ACCENT)
	game_title.custom_minimum_size = Vector2(0, 16)
	game_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	settings_box.add_child(game_title)
	settings_box.add_child(_option_row("时间流速", [
		{"id": "slow", "text": "慢"}, {"id": "normal", "text": "正常"}, {"id": "fast", "text": "快"},
	], str(farm.time.speed_id), func(id: String) -> void:
		farm.time.set_speed_id(id)
		AudioManager.set_setting("time_speed", id)
	))

	settings_box.add_child(_option_row("特效", [
		{"id": "full", "text": "全开"}, {"id": "reduced", "text": "减弱"},
	], "reduced" if bool(AudioManager.get_setting("reduce_effects", false)) else "full",
		func(id: String) -> void:
			AudioManager.set_setting("reduce_effects", id == "reduced")
	))

	settings_box.add_child(_option_row("窗口", [
		{"id": "windowed", "text": "窗口"}, {"id": "fullscreen", "text": "全屏"},
	], str(AudioManager.get_setting("window_mode", "windowed")), func(id: String) -> void:
		AudioManager.set_setting("window_mode", id)
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if id == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)
	))

	var hint := _label("设置立即生效并自动保存", 8, UITheme.C_INK_SOFT)
	settings_box.add_child(hint)


# ---------- 厨房 ----------

func _build_cooking_panel() -> void:
	var shell := _modal_shell("厨房", Vector2(336, 208))
	cooking_panel = shell["dim"]
	cooking_title = shell["title"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)

	var money_in_header: Label = shell["money"]
	money_in_header.visible = false

	column.add_child(_label("只显示能做的菜；食材品质决定成品品质", 8, UITheme.C_INK_SOFT))

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(285, 126)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	UITheme.apply_scrollbar(scroll)

	cooking_list = VBoxContainer.new()
	cooking_list.add_theme_constant_override("separation", 2)
	cooking_list.custom_minimum_size = Vector2(274, 0)
	scroll.add_child(cooking_list)


# ---------- 小地图 ----------

func _build_compass() -> void:
	compass = Compass.new()
	compass.position = Vector2(428, 82)
	compass.custom_minimum_size = Vector2(44, 44)
	compass.size = Vector2(44, 44)
	root.add_child(compass)
	compass.setup(farm)


func set_compass_visible(value: bool) -> void:
	if compass != null:
		compass.visible = value


func _build_fatigue_vignette() -> void:
	fatigue_vignette = FatigueVignette.new()
	fatigue_vignette.name = "FatigueVignette"
	root.add_child(fatigue_vignette)
	fatigue_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fatigue_vignette.move_to_front()


# ---------- 加工机器 ----------

func _build_machine_panel() -> void:
	var shell := _modal_shell("加工机", Vector2(340, 168))
	machine_panel = shell["dim"]
	machine_title = shell["title"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)
	var money: Label = shell["money"]
	money.visible = false

	column.add_child(_label("放入原料后按游戏时间加工，完成后取出。", 10, UITheme.C_INK_SOFT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(288, 92)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	UITheme.apply_scrollbar(scroll)
	machine_list = VBoxContainer.new()
	machine_list.add_theme_constant_override("separation", 4)
	machine_list.custom_minimum_size = Vector2(280, 0)
	scroll.add_child(machine_list)


func open_machine(machine) -> void:
	if machine == null or is_modal_open():
		return
	_machine = machine
	refresh_machine()
	_set_modal("machine")


func refresh_machine() -> void:
	if _machine == null or machine_list == null:
		return
	machine_title.text = _machine.get_display_name()
	for child in machine_list.get_children():
		child.queue_free()
	if not str(_machine.product_id).is_empty():
		_add_machine_status_row()
		return
	var products: Array = DB.get_machine_products(str(_machine.machine_id))
	if products.is_empty():
		machine_list.add_child(_label("这台机器暂无配方", 10, UITheme.C_INK_SOFT))
		return
	for product: Dictionary in products:
		_add_machine_recipe_row(product)


func _add_machine_recipe_row(product: Dictionary) -> void:
	var product_id := str(product.get("id", ""))
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UITheme.row_style())
	machine_list.add_child(row)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(texts)
	texts.add_child(_label(str(product.get("name", product_id)), 11, UITheme.C_INK))
	texts.add_child(_label("%s · %s" % [
		_machine_inputs_text(product), _duration_label(int(product.get("minutes", 0))),
	], 10, UITheme.C_INK_SOFT))
	var can: bool = farm.can_start_machine(_machine, product_id)
	var button := _button("放入" if can else "缺料", 10)
	button.custom_minimum_size = Vector2(38, 16)
	button.disabled = not can
	button.pressed.connect(func() -> void:
		farm.start_machine(_machine, product_id)
		refresh_machine()
	)
	box.add_child(button)


func _add_machine_status_row() -> void:
	var product := DB.get_processing_product(str(_machine.product_id))
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UITheme.row_style())
	machine_list.add_child(row)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	row.add_child(box)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(texts)
	texts.add_child(_label(str(product.get("name", _machine.product_id)), 11, UITheme.C_INK))
	var status := "已完成，可以取出"
	if _machine.is_working():
		status = "制作中 · 剩余 %s" % _duration_label(_machine.remaining_minutes())
	texts.add_child(_label(status, 10, UITheme.C_INK_SOFT))
	var ready: bool = _machine.is_ready()
	var button := _button("取出" if ready else "等待", 10)
	button.custom_minimum_size = Vector2(38, 16)
	button.disabled = not ready
	button.pressed.connect(func() -> void:
		farm.collect_machine(_machine)
		refresh_machine()
	)
	box.add_child(button)


func _machine_inputs_text(product: Dictionary) -> String:
	var inputs: Dictionary = product.get("inputs", {})
	var parts: Array[String] = []
	for key: Variant in inputs.keys():
		var label := "任意作物" if str(key) == "any_crop" else DB.get_item_name(str(key))
		parts.append("%s×%d" % [label, int(inputs[key])])
	return "　".join(PackedStringArray(parts))


func _duration_label(minutes: int) -> String:
	if minutes >= 1440:
		return "%d 天" % ceili(float(minutes) / 1440.0)
	if minutes >= 60:
		return "%d 小时" % ceili(float(minutes) / 60.0)
	return "%d 分钟" % minutes


# ---------- 村镇公告板 ----------

func _build_notice_board() -> void:
	var shell := _modal_shell("村镇公告板", Vector2(352, 212))
	notice_board_panel = shell["dim"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)
	var money: Label = shell["money"]
	money.visible = false

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 5)
	column.add_child(tabs)
	notice_quests_tab = _button("委托", 11)
	notice_quests_tab.custom_minimum_size = Vector2(40, 15)
	notice_quests_tab.pressed.connect(func() -> void: _switch_notice_tab("quests"))
	tabs.add_child(notice_quests_tab)
	notice_buildings_tab = _button("建造", 11)
	notice_buildings_tab.custom_minimum_size = Vector2(40, 15)
	notice_buildings_tab.pressed.connect(func() -> void: _switch_notice_tab("buildings"))
	tabs.add_child(notice_buildings_tab)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 112)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	UITheme.apply_scrollbar(scroll)
	notice_list = VBoxContainer.new()
	notice_list.add_theme_constant_override("separation", 4)
	notice_list.custom_minimum_size = Vector2(292, 0)
	scroll.add_child(notice_list)

	notice_refresh_button = _button("刷新委托（100G）", 10)
	notice_refresh_button.custom_minimum_size = Vector2(120, 16)
	notice_refresh_button.pressed.connect(func() -> void:
		farm.manual_refresh_quests()
		refresh_notice_board()
	)
	column.add_child(notice_refresh_button)


func open_notice_board() -> void:
	if is_modal_open():
		return
	refresh_notice_board()
	_set_modal("notice_board")


func _switch_notice_tab(tab_id: String) -> void:
	_notice_tab = tab_id
	refresh_notice_board()


func refresh_notice_board() -> void:
	if notice_list == null:
		return
	notice_quests_tab.add_theme_color_override(
		"font_color", UITheme.C_ACCENT if _notice_tab == "quests" else UITheme.C_INK
	)
	notice_buildings_tab.add_theme_color_override(
		"font_color", UITheme.C_ACCENT if _notice_tab == "buildings" else UITheme.C_INK
	)
	notice_refresh_button.visible = _notice_tab == "quests"
	for child in notice_list.get_children():
		child.queue_free()
	if _notice_tab == "quests":
		_build_quest_rows()
	else:
		_build_building_rows()


func _build_quest_rows() -> void:
	if farm.quests_active.is_empty():
		notice_list.add_child(_label("今天没有委托，明天再来看看。", 12, UITheme.C_INK_SOFT))
		return
	var today: int = farm.time.get_absolute_day()
	var quest_total: int = farm.quests_active.size()
	for index in quest_total:
		var quest: Dictionary = farm.quests_active[index]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.row_style())
		notice_list.add_child(row)
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		row.add_child(box)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(texts)
		texts.add_child(_clip_label(
			"交付 %s ×%d" % [str(quest.get("item_name", "")), int(quest.get("count", 1))],
			12, UITheme.C_INK
		))
		var days_left: int = maxi(0, int(quest.get("expire_day", 0)) - today)
		texts.add_child(_clip_label(
			"%s · %dG · 好感+%d · 剩余 %d 天" % [
				str(quest.get("giver", "村民")),
				int(quest.get("reward_coins", 0)),
				int(quest.get("reward_friendship", 2)),
				days_left,
			],
			12, UITheme.C_INK_SOFT
		))
		var can_deliver: bool = farm.inventory.count_item(
			str(quest.get("item_id", "")), str(quest.get("category", ""))
		) >= int(quest.get("count", 1))
		var deliver := _button("交付" if can_deliver else "缺货", 10)
		deliver.custom_minimum_size = Vector2(40, 16)
		deliver.disabled = not can_deliver
		var quest_index := index
		deliver.pressed.connect(func() -> void:
			farm.complete_quest(quest_index)
			refresh_notice_board()
		)
		box.add_child(deliver)
		var abandon := _button("放弃", 10)
		abandon.custom_minimum_size = Vector2(36, 16)
		abandon.pressed.connect(func() -> void:
			farm.abandon_quest(quest_index)
			refresh_notice_board()
		)
		box.add_child(abandon)


func _build_building_rows() -> void:
	for definition: Dictionary in DB.get_all_building_defs():
		var building_id := str(definition.get("id", ""))
		var name := str(definition.get("name", building_id))
		var level: int = farm.get_building_level(building_id)
		var days_left: int = farm._building_days_left(building_id)
		var next := DB.get_building_next_level(building_id, level)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.row_style())
		notice_list.add_child(row)
		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		row.add_child(box)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(texts)
		texts.add_child(_label("%s　Lv.%d" % [name, level], 12, UITheme.C_INK))
		var subtitle := "已满级"
		var can_build := false
		if days_left > 0:
			subtitle = "建造中 · 剩余 %d 天" % days_left
		elif not next.is_empty():
			var materials: Dictionary = next.get("materials", {})
			var parts: Array[String] = []
			for item_id: Variant in materials.keys():
				parts.append("%s×%d" % [DB.get_item_name(str(item_id)), int(materials[item_id])])
			subtitle = "升级：%s · %dG · %d天" % [
				"　".join(PackedStringArray(parts)),
				int(next.get("coins", 0)),
				int(next.get("days", 1)),
			]
			var build_check: Dictionary = farm.can_start_building(building_id)
			can_build = bool(build_check.get("ok", false))
		texts.add_child(_wrap_label(subtitle, 12, UITheme.C_INK_SOFT, 190.0))
		var button := _button("升级" if level >= 1 else "建造", 10)
		button.custom_minimum_size = Vector2(40, 16)
		button.disabled = days_left > 0 or next.is_empty() or not can_build
		button.pressed.connect(func() -> void:
			farm.start_building(building_id)
			refresh_notice_board()
		)
		box.add_child(button)


# ---------- 节日 ----------

func _build_festival_panel() -> void:
	var shell := _modal_shell("节日", Vector2(312, 196))
	festival_panel = shell["dim"]
	festival_title = shell["title"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)
	var money: Label = shell["money"]
	money.visible = false

	festival_desc = _label("", 10, UITheme.C_INK)
	festival_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	festival_desc.custom_minimum_size = Vector2(244, 0)
	column.add_child(festival_desc)

	festival_result = _label("", 10, UITheme.C_INK_SOFT)
	festival_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	festival_result.custom_minimum_size = Vector2(244, 34)
	column.add_child(festival_result)

	festival_button = _button("参加", 11)
	festival_button.custom_minimum_size = Vector2(70, 18)
	festival_button.pressed.connect(_on_festival_pressed)
	column.add_child(festival_button)


func open_festival(festival: Dictionary) -> void:
	if festival.is_empty() or is_modal_open():
		return
	_festival = festival
	refresh_festival()
	_set_modal("festival")


func refresh_festival() -> void:
	if festival_panel == null or _festival.is_empty():
		return
	festival_title.text = str(_festival.get("name", "节日"))
	var start_hour := int(_festival.get("start_hour", 9))
	var end_hour := int(_festival.get("end_hour", 18))
	festival_desc.text = "%s\n时间：%d:00 - %d:00　地点：村口广场" % [
		str(_festival.get("description", "")), start_hour, end_hour,
	]
	if farm.is_festival_done(_festival):
		festival_button.disabled = true
		festival_button.text = "今年已参加"
		festival_result.text = "今年已经参加过这个节日了，明年再来吧。"
	else:
		festival_button.disabled = false
		festival_button.text = "参加比赛" if bool(_festival.get("competition", false)) else "参加庆典"
		festival_result.text = "根据背包里最好的作品评分。" \
			if bool(_festival.get("competition", false)) else "和村民们一起庆祝。"


func _on_festival_pressed() -> void:
	var result: Dictionary = farm.participate_festival(_festival)
	if not bool(result.get("ok", false)):
		festival_result.text = str(result.get("reason", "现在无法参加"))
		return
	festival_button.disabled = true
	festival_button.text = "已参加"
	festival_result.text = "%s · 得分 %.2f（%s）\n获得 %d G · 全体村民好感 +%d" % [
		str(result.get("rank_name", "")),
		float(result.get("score", 0.0)),
		str(result.get("label", "")),
		int(result.get("coins", 0)),
		int(result.get("friendship", 0)),
	]


func open_cooking() -> void:
	if is_modal_open():
		return
	refresh_cooking()
	_set_modal("cooking")


func refresh_cooking() -> void:
	for child in cooking_list.get_children():
		child.queue_free()

	var entries: Array = farm.get_cookable_recipes()
	var cookable := 0
	for entry: Dictionary in entries:
		if bool(entry.get("can_cook", false)):
			cookable += 1
	cooking_title.text = "厨房　可做 %d / %d" % [cookable, entries.size()]

	# 能做的排前面
	var sorted := entries.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return bool(a.get("can_cook", false)) and not bool(b.get("can_cook", false))
	)

	for entry: Dictionary in sorted:
		var recipe: Dictionary = entry["recipe"]
		var can: bool = entry.get("can_cook", false)
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", UITheme.row_style())
		cooking_list.add_child(row)

		var box := HBoxContainer.new()
		box.add_theme_constant_override("separation", 5)
		row.add_child(box)

		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(texts)
		texts.add_child(_label(str(recipe.get("name", "")), 9, UITheme.C_INK))

		var ingredient_text: Array[String] = []
		for key: Variant in (recipe.get("ingredients", {}) as Dictionary).keys():
			ingredient_text.append("%s×%d" % [
				_ingredient_label(str(key)),
				int(recipe["ingredients"][key]),
			])
		texts.add_child(_label("　".join(PackedStringArray(ingredient_text)), 7, UITheme.C_INK_SOFT))

		var button := _button("做" if can else "缺料", 8)
		button.custom_minimum_size = Vector2(38, 18)
		button.disabled = not can
		var recipe_id := str(recipe.get("id", ""))
		button.pressed.connect(func() -> void:
			farm.cook_recipe(recipe_id)
			refresh_cooking()
		)
		box.add_child(button)


func _ingredient_label(ingredient_id: String) -> String:
	match ingredient_id:
		"fish_any":
			return "任意鱼"
		"high_grade_fish":
			return "高级鱼"
		"meat_any":
			return "任意肉"
		"veggie_any":
			return "任意蔬菜"
		"fruit_any":
			return "任意水果"
		"shrimp":
			return "虾"
		_:
			return DB.get_item_name(ingredient_id)


# ---------- 对话框 ----------

func _build_dialogue() -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.visible = false
	dialogue_panel.custom_minimum_size = Vector2(270, 0)
	root.add_child(dialogue_panel)
	dialogue_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 44)
	dialogue_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dialogue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dialogue_panel.add_child(row)

	var text_column := VBoxContainer.new()
	text_column.add_theme_constant_override("separation", 3)
	text_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_column)

	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.row_style())
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_column.add_child(plate)

	dialogue_name = _label("清晨", 9, UITheme.C_ACCENT)
	plate.add_child(dialogue_name)

	dialogue_text = _label("", 9, UITheme.C_INK)
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.custom_minimum_size = Vector2(0, 20)
	text_column.add_child(dialogue_text)

	var portrait_frame := PanelContainer.new()
	portrait_frame.add_theme_stylebox_override("panel", UITheme.slot_style(false))
	portrait_frame.custom_minimum_size = Vector2(28, 28)
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(portrait_frame)

	dialogue_portrait = PortraitSticker.new()
	dialogue_portrait.custom_minimum_size = Vector2(24, 24)
	dialogue_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait_frame.add_child(dialogue_portrait)

	# 气泡尾巴：指向下方（说话者位置）
	dialogue_tail = DialogueTail.new()
	dialogue_tail.custom_minimum_size = Vector2(16, 8)
	dialogue_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dialogue_tail)
	dialogue_tail.visible = false


class DialogueTail:
	extends Control

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var points := PackedVector2Array([
			Vector2(0, 0), Vector2(w, 0), Vector2(w * 0.42, h),
		])
		draw_colored_polygon(points, UITheme.C_PANEL)
		draw_line(Vector2(0, 0), Vector2(w * 0.42, h), UITheme.C_BORDER, 1.0)
		draw_line(Vector2(w * 0.42, h), Vector2(w, 0), UITheme.C_BORDER, 1.0)


class PortraitSticker:
	extends Control

	var look: Dictionary = Art.default_look()


	func _draw() -> void:
		var s := minf(size.x, size.y)
		if s <= 0.0:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color("#e7efdc"), true)
		var extra := s / 34.0
		Art.draw_character(
			self, look, "down", 0.0, false,
			Vector2(size.x * 0.5, size.y * 0.92), extra
		)


func set_portrait_look(look: Dictionary) -> void:
	_portrait_look = Art.normalize_look(look)
	if dialogue_portrait != null:
		dialogue_portrait.look = _portrait_look
		dialogue_portrait.queue_redraw()


func show_dialogue(speaker: String, text: String, duration := 3.4, portrait_look := {}) -> void:
	if is_modal_open():
		return
	if portrait_look.is_empty():
		if farm != null and farm.player != null:
			_portrait_look = farm.player.look
		else:
			_portrait_look = Art.default_look()
	else:
		_portrait_look = portrait_look
	dialogue_name.text = speaker
	dialogue_portrait.look = _portrait_look
	dialogue_portrait.queue_redraw()
	dialogue_panel.visible = true
	dialogue_panel.modulate.a = 0.0
	if dialogue_tail != null:
		dialogue_tail.visible = true
		dialogue_tail.modulate.a = 0.0

	# 逐字显示（按交互键可跳过，见 Farm 的 E 处理）
	_dialogue_full_text = text
	_dialogue_index = 0.0
	_dialogue_typing = true
	dialogue_text.text = ""
	_update_dialogue_tail()

	if dialogue_tween != null and dialogue_tween.is_valid():
		dialogue_tween.kill()
	dialogue_tween = create_tween()
	dialogue_tween.tween_property(dialogue_panel, "modulate:a", 1.0, 0.16)
	dialogue_tween.tween_interval(duration)
	dialogue_tween.tween_property(dialogue_panel, "modulate:a", 0.0, 0.3)
	dialogue_tween.tween_callback(func() -> void:
		dialogue_panel.visible = false
		if dialogue_tail != null:
			dialogue_tail.visible = false
	)


## 把气泡尾巴对齐到对话框底部中央。
func _update_dialogue_tail() -> void:
	if dialogue_tail == null or not dialogue_tail.visible:
		return
	var rect: Rect2 = dialogue_panel.get_global_rect()
	dialogue_tail.size = Vector2(16, 8)
	dialogue_tail.position = Vector2(rect.get_center().x - 8, rect.end.y - 2)


func _process(delta: float) -> void:
	if dialogue_panel != null and dialogue_panel.visible and dialogue_tail != null:
		dialogue_tail.modulate.a = dialogue_panel.modulate.a
		_update_dialogue_tail()
	if _dialogue_typing:
		_dialogue_index += _dialogue_speed * delta
		var visible_chars := int(_dialogue_index)
		if visible_chars >= _dialogue_full_text.length():
			dialogue_text.text = _dialogue_full_text
			_dialogue_typing = false
		else:
			dialogue_text.text = _dialogue_full_text.substr(0, visible_chars)


## 跳过逐字，直接显示全文。返回是否消耗了这次输入。
func skip_dialogue_typing() -> bool:
	if not _dialogue_typing:
		return false
	_dialogue_index = float(_dialogue_full_text.length())
	dialogue_text.text = _dialogue_full_text
	_dialogue_typing = false
	return true


func hide_dialogue() -> void:
	if dialogue_tween != null and dialogue_tween.is_valid():
		dialogue_tween.kill()
	if dialogue_panel != null:
		dialogue_panel.visible = false


# ---------- 钓鱼 ----------

func _build_minigame() -> void:
	minigame = FishMiniGameScript.new()
	minigame.visible = false
	minigame.custom_minimum_size = Vector2(224, 104)
	root.add_child(minigame)
	minigame.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	minigame.position = Vector2(8, 83)
	minigame.size = Vector2(224, 104)
	minigame.finished.connect(_on_minigame_finished)


# ============================================================
# HUD 刷新
# ============================================================

func refresh_hud() -> void:
	if farm == null:
		return
	var time: TimeSystem = farm.time
	var season_index: int = ["spring", "summer", "autumn", "winter"].find(time.season)
	var season_colors: Array[Color] = [
		Color("#6f8f58"), Color("#a9855c"), Color("#a8735c"), Color("#6f8ea0"),
	]
	var season_color: Color = season_colors[clampi(season_index, 0, 3)]

	date_label.text = "%s · %d日" % [time.get_season_name(), time.day]
	date_label.add_theme_color_override("font_color", season_color)
	time_label.text = time.get_clock_text()
	year_label.text = "第 %d 年" % time.year
	weather_label.text = time.get_weather_name()
	weather_icon.kind = _weather_icon_kind(time.weather)
	weather_icon.queue_redraw()
	money_label.text = "%d G" % int(farm.money)

	var player: Player = farm.player
	var ratio: float = player.stamina / maxf(1.0, player.stamina_max)
	stamina_bar.value = player.stamina
	stamina_bar.max_value = player.stamina_max
	stamina_label.text = "%d" % int(round(player.stamina))
	var color: Color = UITheme.C_GOOD
	if ratio <= 0.25:
		color = UITheme.C_BAD
	elif ratio <= 0.5:
		color = Color("#c9a46a")
	stamina_bar.add_theme_stylebox_override("fill", UITheme.bar_fill(color))

	if health_bar != null:
		health_bar.max_value = player.max_hp
		health_bar.value = player.hp
		var show_health: bool = farm.in_mine or player.hp < player.max_hp
		health_frame.visible = show_health
		health_label.visible = show_health
		health_label.text = "%d" % player.hp

	# 暂停图标
	pause_icon.visible = time.is_time_paused()

	# 疲劳 / 熬夜提示
	var fatigue_ratio := DB.get_fatigue_warning_ratio()
	if fatigue_vignette != null:
		# 体力 <20% 开始出现边缘暗角，越低越明显
		var vignette := 0.0
		if ratio < 0.20:
			vignette = clampf((0.20 - ratio) / 0.20, 0.0, 1.0)
		fatigue_vignette.intensity = vignette
		fatigue_vignette.queue_redraw()
	if ratio <= fatigue_ratio:
		status_icon.text = "疲劳"
		status_icon.add_theme_color_override("font_color", UITheme.C_BAD)
		status_icon.visible = true
	elif time.minutes >= 1440.0:
		status_icon.text = "熬夜中"
		status_icon.add_theme_color_override("font_color", Color("#a9855c"))
		status_icon.visible = true
	else:
		status_icon.visible = false

	refresh_hotbar()


func _weather_icon_kind(weather: String) -> String:
	match weather:
		"rain":
			return "rain"
		"snow":
			return "snow"
		"blizzard":
			return "blizzard"
		"storm":
			return "storm"
		_:
			return "sun"


func refresh_hotbar() -> void:
	if farm == null:
		return
	var inventory: Inventory = farm.inventory
	_selected_index = farm.selected_index
	var hotbar_count := mini(HOTBAR_SIZE, _hotbar_buttons.size())
	for index in hotbar_count:
		var button := _hotbar_buttons[index]
		var slot := inventory.get_slot(index)
		var selected: bool = index == _selected_index
		button.add_theme_stylebox_override("normal", UITheme.slot_style(selected))
		_fill_slot_button(button, slot, index, Vector2(24, 24))


func _fill_slot_button(button: Button, slot: Dictionary, index: int, slot_size: Vector2) -> void:
	button.text = ""
	for child in button.get_children():
		child.queue_free()

	button.tooltip_text = ""
	if slot.is_empty():
		# 只有快捷栏前 10 格标注 1-0 快捷键
		if index < HOTBAR_SIZE:
			var key_label := _label(str((index + 1) % 10), 9, Color(0.35, 0.30, 0.24, 0.35))
			key_label.position = Vector2(3, 1)
			button.add_child(key_label)
		return

	var item_id := str(slot.get("item_id", ""))
	var category := str(slot.get("category", ""))
	var item_name := DB.get_item_name(item_id, category)
	var item_count := int(slot.get("count", 0))
	if category in ["tool", "rod"]:
		button.tooltip_text = item_name
	else:
		button.tooltip_text = "%s ×%d" % [item_name, item_count]
	var icon_size: float = slot_size.y * 0.74

	var icon := TextureRect.new()
	icon.texture = UITheme.item_icon(item_id, category)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size = Vector2(icon_size, icon_size)
	icon.position = Vector2((slot_size.x - icon_size) * 0.5, (slot_size.y - icon_size) * 0.5 - 2.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)

	# 品质角标：普通无标记，银 / 金 / 星光各一个色块（文档 9.3）
	var quality := str(slot.get("quality", "normal"))
	if quality in ["silver", "gold", "star"]:
		var quality_block := ColorRect.new()
		quality_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
		match quality:
			"silver":
				quality_block.color = Color("#b9c4cc")
			"gold":
				quality_block.color = Color("#d8b64a")
			_:
				quality_block.color = Color("#e8a0d0")
		quality_block.size = Vector2(4, 4)
		quality_block.position = Vector2(slot_size.x - 6, 3)
		button.add_child(quality_block)

	var count := int(slot.get("count", 0))
	if category in ["tool", "rod"]:
		count = 0
	if count > 0:
		var count_label := _label("×%d" % count, 10, UITheme.C_INK)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count_label.size = Vector2(slot_size.x - 4.0, 14.0)
		count_label.position = Vector2(0, slot_size.y - 15.0)
		button.add_child(count_label)

	if bool(slot.get("is_rare", false)):
		var star := _label("*", 10, Color("#8a6a2a"))
		star.position = Vector2(3, 1)
		button.add_child(star)


func set_prompt(text: String) -> void:
	prompt_label.text = text
	prompt_panel.visible = not text.is_empty()


func toast(text: String, kind := "", force := false) -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_child(panel)

	var color := UITheme.C_INK
	if kind == "good":
		color = UITheme.C_GOOD
	elif kind == "bad":
		color = UITheme.C_BAD
	var label := _label(text, 13, color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)

	while toast_box.get_child_count() > 2:
		var oldest := toast_box.get_child(0)
		toast_box.remove_child(oldest)
		oldest.queue_free()

	var panel_id := panel.get_instance_id()
	var tween := create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		var node: Object = instance_from_id(panel_id)
		if node != null and is_instance_valid(node):
			node.queue_free()
	)


## 立刻取消淡入淡出并显示画面（截图 / 跳过过场用）。
func force_clear_fade() -> void:
	for tween in get_tree().get_processed_tweens():
		if tween.is_valid():
			var target := tween.get_total_elapsed_time()
			pass
	if fade_rect != null:
		fade_rect.modulate.a = 0.0


func fade_out(duration := 0.4) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, duration)


func fade_in(duration := 0.4) -> void:
	var tween := create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration)


# ============================================================
# 弹窗
# ============================================================

func get_modal() -> String:
	return _modal


func is_modal_open() -> bool:
	return not _modal.is_empty()


func _set_modal(name: String) -> void:
	_modal = name
	if not name.is_empty():
		hide_dialogue()
	inventory_panel.visible = name == "inventory"
	storage_panel.visible = name == "storage"
	mail_panel.visible = name == "mail"
	cellar_panel.visible = name == "cellar"
	achievements_panel.visible = name == "achievements"
	library_panel.visible = name == "library"
	clinic_panel.visible = name == "clinic"
	mount_panel.visible = name == "mount"
	mount_cargo_panel.visible = name == "mount_cargo"
	pet_panel.visible = name == "pet"
	pet_name_panel.visible = name == "pet_name"
	shop_panel.visible = name == "shop"
	help_panel.visible = name == "help"
	save_panel.visible = name == "save"
	settings_panel.visible = name == "settings"
	cooking_panel.visible = name == "cooking"
	machine_panel.visible = name == "machine"
	festival_panel.visible = name == "festival"
	notice_board_panel.visible = name == "notice_board"
	collection_panel.visible = name == "collection"
	museum_panel.visible = name == "museum"
	credits_panel.visible = name == "credits"
	if compass != null:
		compass.visible = name.is_empty()
	if not name.is_empty():
		farm.on_modal_opened(name)
	else:
		farm.on_modal_closed()


func open_inventory() -> void:
	if is_modal_open():
		return
	refresh_inventory()
	_set_modal("inventory")


func toggle_help() -> void:
	if _modal == "help":
		close_modal()
	elif not is_modal_open():
		_set_modal("help")


func open_shop() -> void:
	if is_modal_open():
		return
	refresh_shop()
	_set_modal("shop")


# ---------- 图鉴 ----------

func _build_collection() -> void:
	var shell := _modal_shell("图鉴", Vector2(356, 208))
	collection_panel = shell["dim"]
	collection_title = shell["title"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	column.add_child(tabs)
	for category: Dictionary in _collection_categories():
		var tab := _button(str(category.get("name", "")), 10)
		tab.custom_minimum_size = Vector2(34, 14)
		var category_id := str(category.get("id", ""))
		tab.pressed.connect(func() -> void: _select_collection_category(category_id))
		tabs.add_child(tab)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	collection_sort_button = _button("排序：默认", 10)
	collection_sort_button.custom_minimum_size = Vector2(78, 14)
	collection_sort_button.pressed.connect(_cycle_collection_sort)
	row.add_child(collection_sort_button)
	collection_info = _label("", 10, UITheme.C_INK_SOFT)
	collection_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(collection_info)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(304, 124)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.apply_scrollbar(scroll)
	column.add_child(scroll)

	collection_grid = GridContainer.new()
	collection_grid.columns = 10
	collection_grid.add_theme_constant_override("h_separation", 3)
	collection_grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(collection_grid)


func _collection_categories() -> Array[Dictionary]:
	return [
		{"id": "crop", "name": "作物"},
		{"id": "fish", "name": "鱼类"},
		{"id": "animal", "name": "动物"},
		{"id": "fruit", "name": "果树"},
		{"id": "bee_product", "name": "蜂产"},
		{"id": "bird", "name": "鸟类"},
		{"id": "insect", "name": "昆虫"},
		{"id": "mineral", "name": "矿物"},
		{"id": "artifact", "name": "古物"},
		{"id": "pet", "name": "宠物"},
		{"id": "pet_rare", "name": "宠物异色"},
	]


func _collection_category_name() -> String:
	for category: Dictionary in _collection_categories():
		if str(category.get("id", "")) == _collection_category:
			return str(category.get("name", _collection_category))
	return _collection_category


func _select_collection_category(category_id: String) -> void:
	_collection_category = category_id
	refresh_collection()


func _cycle_collection_sort() -> void:
	var index: int = COLLECTION_SORT_ORDER.find(_collection_sort)
	_collection_sort = str(COLLECTION_SORT_ORDER[(index + 1) % COLLECTION_SORT_ORDER.size()])
	if collection_sort_button != null:
		collection_sort_button.text = "排序：%s" % str(
			COLLECTION_SORT_NAMES.get(_collection_sort, "默认"))
	refresh_collection()


func open_collection() -> void:
	if is_modal_open():
		return
	refresh_collection()
	_set_modal("collection")


func toggle_collection() -> void:
	if _modal == "collection":
		close_modal()
	elif not is_modal_open():
		open_collection()


func refresh_collection() -> void:
	if farm == null or collection_grid == null:
		return
	for child in collection_grid.get_children():
		child.queue_free()

	var entries := _collection_entries(_collection_category)
	var collected_count := 0
	for entry: Dictionary in entries:
		entry["collected"] = _collection_collected(_collection_category, entry)
		if bool(entry["collected"]):
			collected_count += 1
	_sort_collection(entries)

	collection_title.text = "图鉴　%s　%d / %d" % [
		_collection_category_name(), collected_count, entries.size(),
	]
	collection_info.text = "点击图标查看详情 · 已收集 %d / %d" % [
		collected_count, entries.size(),
	]
	for entry: Dictionary in entries:
		collection_grid.add_child(_collection_cell(entry))


func _collection_entries(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match category:
		"crop":
			for definition: Dictionary in DB.get_all_crops():
				var id := str(definition.get("id", ""))
				result.append(_collection_entry(
					id, str(definition.get("name", id)),
					int(definition.get("base_price", 0)), id, "crop", [id]))
		"fish":
			for definition: Dictionary in DB.get_all_fishes():
				var id := str(definition.get("id", ""))
				result.append(_collection_entry(
					id, str(definition.get("name", id)),
					int(definition.get("base_price", 0)), id, "fish", [id]))
		"animal":
			for definition: Dictionary in DB.get_all_animals():
				var id := str(definition.get("id", ""))
				var product_id := str(definition.get("product_id", ""))
				result.append(_collection_entry(
					id, str(definition.get("name", id)),
					int(definition.get("buy_price", 0)),
					product_id if not product_id.is_empty() else id,
					"animal_product", [id, product_id]))
		"fruit":
			for definition: Dictionary in DB.get_all_fruit_trees():
				var fruit_id := str(definition.get("fruit_id", ""))
				result.append(_collection_entry(
					fruit_id, str(definition.get("fruit_name", fruit_id)),
					int(definition.get("base_price", 0)), fruit_id, "fruit",
					[fruit_id, str(definition.get("id", ""))]))
		"bee_product":
			for definition: Dictionary in DB.get_all_bee_products():
				var id := str(definition.get("id", ""))
				result.append(_collection_entry(
					id, str(definition.get("name", id)), 0, id, "bee_product", [id]))
		"bird":
			for definition: Dictionary in DB.get_all_birds():
				var id := str(definition.get("id", ""))
				result.append(_collection_entry(
					id, str(definition.get("name", id)),
					int(definition.get("base_price", 0)), id, "bird", [id]))
		"insect":
			for definition: Dictionary in DB.get_all_insects():
				var id := str(definition.get("id", ""))
				result.append(_collection_entry(
					id, str(definition.get("name", id)),
					int(definition.get("base_price", 0)), id, "insect", [id]))
		"mineral":
			for definition: Dictionary in MineFloorScript.ORES:
				var id := str(definition.get("id", ""))
				result.append(_collection_entry(
					id, str(definition.get("name", id)),
					int(definition.get("price", 0)), id, "mineral", [id]))
		"artifact":
			for definition: Dictionary in DB.get_all_artifacts():
				var id := str(definition.get("id", ""))
				result.append(_collection_entry(
					id, str(definition.get("name", id)),
					int(definition.get("price", 0)), id, "artifact", [id]))
		"pet":
			for definition: Dictionary in DB.get_all_pet_breeds():
				var id := str(definition.get("id", ""))
				var type_id := str(definition.get("type_id", ""))
				result.append(_collection_entry(
					id, "%s（%s）" % [str(definition.get("name", id)),
						str(definition.get("type_name", ""))],
					int(definition.get("price", 0)), type_id, "animal", [id]))
		"pet_rare":
			if farm != null and farm.unlock_book.get("pet_rare", []) is Array:
				for raw_key: Variant in farm.unlock_book.get("pet_rare", []):
					var key := str(raw_key)
					for candidate: Dictionary in DB.get_all_pet_breeds():
						var breed_id := str(candidate.get("id", ""))
						if not key.begins_with(breed_id + "_"):
							continue
						var color_id := key.substr(breed_id.length() + 1)
						var color := DB.get_pet_rare_color(color_id)
						result.append(_collection_entry(
							key, "%s · %s" % [str(candidate.get("name", breed_id)),
								str(color.get("name", color_id))],
							0, str(candidate.get("type_id", "")), "animal", [key]))
						break
	return result


func _collection_entry(
	id: String, display_name: String, price: int,
	icon_id: String, icon_cat: String, unlock_keys: Array
) -> Dictionary:
	return {
		"id": id,
		"name": display_name,
		"price": price,
		"icon_id": icon_id,
		"icon_cat": icon_cat,
		"unlock_keys": unlock_keys,
		"collected": false,
	}


func _collection_collected(category: String, entry: Dictionary) -> bool:
	if farm == null or not farm.unlock_book.has(category):
		return false
	if not (farm.unlock_book[category] is Array):
		return false
	var owned: Array = farm.unlock_book[category]
	for raw_key: Variant in entry.get("unlock_keys", []):
		var key := str(raw_key)
		if key.is_empty():
			continue
		for raw_owned: Variant in owned:
			var text := str(raw_owned)
			# 稀有 / 巨型 / 变色变体也算作该条目已收集
			if text == key or text.begins_with(key + "_"):
				return true
	return false


func _sort_collection(entries: Array[Dictionary]) -> void:
	match _collection_sort:
		"name":
			entries.sort_custom(_collection_sort_by_name)
		"price":
			entries.sort_custom(_collection_sort_by_price)
		"uncollected":
			entries.sort_custom(_collection_sort_uncollected)


func _collection_sort_by_name(a: Dictionary, b: Dictionary) -> bool:
	return str(a.get("name", "")) < str(b.get("name", ""))


func _collection_sort_by_price(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("price", 0)) > int(b.get("price", 0))


func _collection_sort_uncollected(a: Dictionary, b: Dictionary) -> bool:
	var a_owned := bool(a.get("collected", false))
	var b_owned := bool(b.get("collected", false))
	if a_owned == b_owned:
		return _collection_sort_by_name(a, b)
	return not a_owned


func _collection_cell(entry: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(26, 26)
	button.add_theme_stylebox_override("normal", UITheme.slot_style(false))
	button.add_theme_stylebox_override("hover", UITheme.slot_style(true))
	button.add_theme_stylebox_override("pressed", UITheme.slot_style(true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var collected := bool(entry.get("collected", false))
	if collected:
		var icon := TextureRect.new()
		icon.texture = UITheme.item_icon(
			str(entry.get("icon_id", "")), str(entry.get("icon_cat", "")))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.size = Vector2(20, 20)
		icon.position = Vector2(3, 2)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		button.tooltip_text = str(entry.get("name", ""))
	else:
		var unknown := _label("？", 12, Color(0.35, 0.30, 0.24, 0.45))
		unknown.position = Vector2(7, 3)
		button.add_child(unknown)
		button.tooltip_text = "未收集"

	var info: Dictionary = entry.duplicate(true)
	button.pressed.connect(func() -> void: _show_collection_info(info))
	return button


func _show_collection_info(entry: Dictionary) -> void:
	var collected := bool(entry.get("collected", false))
	var display := str(entry.get("name", "")) if collected else "？？？"
	var status := "已收集" if collected else "未收集"
	collection_info.text = "%s · %s · 参考价 %dG" % [
		display, status, int(entry.get("price", 0)),
	]


# ---------- 博物馆 ----------

func _build_museum() -> void:
	var shell := _modal_shell("博物馆", Vector2(356, 212))
	museum_panel = shell["dim"]
	museum_title = shell["title"]
	var column: VBoxContainer = shell["column"]
	var close: Button = shell["close"]
	close.pressed.connect(close_modal)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	column.add_child(tabs)
	for definition: Dictionary in [
		{"id": "artifact", "name": "古物"},
		{"id": "mineral", "name": "矿石"},
		{"id": "fish", "name": "鱼类"},
	]:
		var tab := _button(str(definition.get("name", "")), 10)
		tab.custom_minimum_size = Vector2(46, 14)
		var tab_id := str(definition.get("id", ""))
		tab.pressed.connect(func() -> void: _select_museum_tab(tab_id))
		tabs.add_child(tab)

	museum_info = _label("点击背包中拥有的展品进行捐赠。", 10, UITheme.C_INK_SOFT)
	column.add_child(museum_info)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(304, 124)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UITheme.apply_scrollbar(scroll)
	column.add_child(scroll)

	museum_grid = GridContainer.new()
	museum_grid.columns = 10
	museum_grid.add_theme_constant_override("h_separation", 3)
	museum_grid.add_theme_constant_override("v_separation", 3)
	scroll.add_child(museum_grid)


func open_museum() -> void:
	if is_modal_open():
		return
	refresh_museum()
	_set_modal("museum")


func _select_museum_tab(tab_id: String) -> void:
	_museum_tab = tab_id
	refresh_museum()


func refresh_museum() -> void:
	if farm == null or museum_grid == null:
		return
	for child in museum_grid.get_children():
		child.queue_free()
	var entries: Array = farm.museum_items(_museum_tab)
	var donated_count := 0
	for entry: Dictionary in entries:
		if bool(entry.get("donated", false)):
			donated_count += 1
		museum_grid.add_child(_museum_cell(entry))
	var tab_name := str(
		{"artifact": "古物", "mineral": "矿石", "fish": "鱼类"}.get(_museum_tab, "古物"))
	museum_title.text = "博物馆　%s　%d / %d" % [
		tab_name, donated_count, entries.size(),
	]


func _museum_cell(entry: Dictionary) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(26, 26)
	var donated := bool(entry.get("donated", false))
	button.add_theme_stylebox_override("normal", UITheme.slot_style(donated))
	button.add_theme_stylebox_override("hover", UITheme.slot_style(true))
	button.add_theme_stylebox_override("pressed", UITheme.slot_style(true))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var icon := TextureRect.new()
	icon.texture = UITheme.item_icon(
		str(entry.get("id", "")), str(entry.get("category", "")))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.size = Vector2(22, 22)
	icon.position = Vector2(4, 3)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not donated:
		icon.modulate = Color(1, 1, 1, 0.30 if int(entry.get("owned", 0)) <= 0 else 0.75)
	button.add_child(icon)

	if donated:
		var mark := _label("★", 10, Color("#c58a2e"))
		mark.position = Vector2(1, 0)
		button.add_child(mark)
	elif int(entry.get("owned", 0)) > 0:
		var count := _label("×%d" % int(entry.get("owned", 0)), 9, UITheme.C_INK)
		count.position = Vector2(13, 15)
		button.add_child(count)

	var info: Dictionary = entry.duplicate(true)
	button.pressed.connect(func() -> void: _on_museum_cell_pressed(info))
	return button


func _on_museum_cell_pressed(entry: Dictionary) -> void:
	var item_name := str(entry.get("name", ""))
	var desc := str(entry.get("desc", ""))
	var donated := bool(entry.get("donated", false))
	if donated:
		museum_info.text = "%s · 已陈列　%s" % [item_name, desc]
		return
	if farm != null and farm.donate_to_museum(
			str(entry.get("id", "")), str(entry.get("category", ""))):
		refresh_museum()
		museum_info.text = "%s · 已捐赠　%s" % [item_name, desc]
	else:
		museum_info.text = "%s · 未捐赠（需要背包中有该展品）　%s" % [item_name, desc]


func close_modal() -> void:
	if _modal == "shop":
		farm.on_shop_closed()
	if not _modal.is_empty():
		_set_modal("")


func refresh_inventory() -> void:
	if farm == null:
		return
	for child in inventory_grid.get_children():
		child.queue_free()

	var inventory: Inventory = farm.inventory
	for index in inventory.slots.size():
		var slot := inventory.get_slot(index)
		var button := Button.new()
		button.custom_minimum_size = Vector2(32, 32)
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_stylebox_override("normal", UITheme.slot_style(index == farm.selected_index))
		button.add_theme_stylebox_override("hover", UITheme.slot_style(index == farm.selected_index))
		button.add_theme_stylebox_override("pressed", UITheme.slot_style(true))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", UITheme.C_INK)
		button.add_theme_color_override("font_hover_color", UITheme.C_INK)
		button.add_theme_color_override("font_pressed_color", UITheme.C_INK)
		_fill_slot_button(button, slot, index, Vector2(24, 24))
		button.pressed.connect(func() -> void: farm.select_index(index))
		inventory_grid.add_child(button)

	inventory_title.text = "背包　%d / %d 格" % [
		inventory.slots.size() - inventory.empty_slot_count(),
		inventory.slots.size(),
	]


func refresh_shop() -> void:
	if farm == null:
		return
	shop_money_label.text = "%d G" % farm.money

	for child in shop_buy_list.get_children():
		child.queue_free()
	for child in shop_sell_list.get_children():
		child.queue_free()

	_shop_seed_tab.add_theme_color_override(
		"font_color", UITheme.C_ACCENT if _shop_tab == "seeds" else UITheme.C_INK
	)
	_shop_animal_tab.add_theme_color_override(
		"font_color", UITheme.C_ACCENT if _shop_tab == "animals" else UITheme.C_INK
	)
	_shop_pet_tab.add_theme_color_override(
		"font_color", UITheme.C_ACCENT if _shop_tab == "pets" else UITheme.C_INK
	)
	_shop_bee_tab.add_theme_color_override(
		"font_color", UITheme.C_ACCENT if _shop_tab == "bees" else UITheme.C_INK
	)
	_shop_tree_tab.add_theme_color_override(
		"font_color", UITheme.C_ACCENT if _shop_tab == "trees" else UITheme.C_INK
	)
	_shop_accessory_tab.add_theme_color_override(
		"font_color", UITheme.C_ACCENT if _shop_tab == "accessories" else UITheme.C_INK
	)
	_shop_machine_tab.add_theme_color_override(
		"font_color", UITheme.C_ACCENT if _shop_tab == "machines" else UITheme.C_INK
	)
	_shop_furniture_tab.add_theme_color_override(
		"font_color", UITheme.C_ACCENT if _shop_tab == "furniture" else UITheme.C_INK
	)

	if _shop_tab == "seeds":
		var season: String = farm.time.season
		for definition: Dictionary in DB.get_all_crops():
			var crop_id := str(definition.get("id", ""))
			if str(definition.get("season", "")) != season:
				continue
			var price := DB.get_seed_price(crop_id)
			_add_shop_row(
				shop_buy_list,
				"%s种子" % str(definition.get("name", crop_id)),
				"%s季 · %d 天成熟" % [DB.season_name(str(definition.get("season", ""))), int(definition.get("grow_day", 0))],
				price,
				farm.money >= price,
				func(shift: bool) -> void: farm.buy_seed(crop_id, 5 if shift else 1),
				"购买",
				UITheme.item_icon(crop_id, "seed")
			)

		for good: Dictionary in DB.get_shop_goods():
			var good_id := str(good.get("item_id", ""))
			var price := int(good.get("price", 0))
			_add_shop_row(
				shop_buy_list,
				str(good.get("name", good_id)),
				str(good.get("description", "")),
				price,
				farm.money >= price,
				func(shift: bool) -> void: farm.buy_good(good_id, 5 if shift else 1),
				"购买",
				UITheme.item_icon(good_id, str(good.get("category", "goods")))
			)
	elif _shop_tab == "bees":
		for good: Dictionary in farm.get_bee_shop_goods():
			var good_id := str(good.get("item_id", ""))
			var price := int(good.get("price", 0))
			_add_shop_row(
				shop_buy_list,
				str(good.get("name", good_id)),
				str(good.get("description", "")),
				price,
				farm.money >= price,
				func(shift: bool) -> void: farm.buy_good(good_id, 5 if shift else 1),
				"买",
				UITheme.item_icon(good_id, str(good.get("category", "goods")))
			)
	elif _shop_tab == "trees":
		for definition: Dictionary in DB.get_all_fruit_trees():
			var tree_id := str(definition.get("id", ""))
			var price := DB.get_sapling_price(tree_id)
			_add_shop_row(
				shop_buy_list,
				str(definition.get("name", tree_id)),
				"%s季结果 · 第 %d 年成年" % [
					DB.season_name(str(definition.get("season", ""))),
					int(definition.get("mature_year", 4)),
				],
				price,
				farm.money >= price,
				func(_shift: bool) -> void: farm.buy_sapling(tree_id),
				"买苗",
				UITheme.item_icon(str(definition.get("fruit_id", "")), "fruit")
			)
	elif _shop_tab == "accessories":
		for definition: Dictionary in DB.get_all_accessories():
			var accessory_id := str(definition.get("id", ""))
			var price := int(definition.get("price", 0))
			var owned: bool = accessory_id in farm.accessories_owned
			var slot := str(definition.get("slot", "head"))
			var equipped: bool = str((farm.accessories_equipped as Dictionary).get(slot, "")) == accessory_id
			var button_text := "已穿戴" if equipped else ("穿戴" if owned else "购买")
			_add_shop_row(
				shop_buy_list,
				"%s（%s）" % [str(definition.get("name", accessory_id)), DB.get_accessory_slot_name(slot)],
				str(definition.get("description", "")),
				price,
				equipped or (not owned and farm.money < price),
				func(_shift: bool) -> void: farm.buy_or_wear_accessory(accessory_id),
				button_text,
				UITheme.item_icon(accessory_id, "accessory")
			)
	elif _shop_tab == "machines":
		for machine: Dictionary in DB.get_all_machines():
			var machine_id := str(machine.get("id", ""))
			var price := int(machine.get("price", 0))
			_add_shop_row(
				shop_buy_list,
				str(machine.get("name", machine_id)),
				str(machine.get("description", "")),
				price,
				farm.money >= price,
				func(_shift: bool) -> void: farm.buy_machine(machine_id),
				"购买",
				UITheme.item_icon(machine_id, "machine")
			)
	elif _shop_tab == "furniture":
		for definition: Dictionary in DB.get_all_furniture():
			var furniture_id := str(definition.get("id", ""))
			var price := int(definition.get("price", 0))
			_add_shop_row(
				shop_buy_list,
				str(definition.get("name", furniture_id)),
				str(definition.get("desc", "")),
				price,
				farm.money >= price,
				func(_shift: bool) -> void: farm.buy_furniture(furniture_id),
				"购买",
				UITheme.item_icon(str(definition.get("icon", furniture_id)), "furniture")
			)
		shop_buy_list.add_child(_clip_label(
			"买到的家具会放进背包，回到自宅室内使用即可摆放（再次互动可收回）。",
			12, UITheme.C_INK_SOFT
		))
	elif _shop_tab == "pets":
		var type_select := OptionButton.new()
		UITheme.apply_button(type_select, 10)
		type_select.custom_minimum_size = Vector2(160, 18)
		type_select.add_item("全部宠物")
		type_select.set_item_metadata(0, "all")
		var selected_index := 0
		var item_index := 1
		for type_entry: Dictionary in DB.get_pet_types():
			var type_id := str(type_entry.get("id", ""))
			type_select.add_item(str(type_entry.get("name", type_id)))
			type_select.set_item_metadata(item_index, type_id)
			if type_id == _pet_shop_type:
				selected_index = item_index
			item_index += 1
		type_select.select(selected_index)
		type_select.item_selected.connect(func(selected: int) -> void:
			_pet_shop_type = str(type_select.get_item_metadata(selected))
			refresh_shop()
		)
		shop_buy_list.add_child(type_select)

		var breed_entries: Array = []
		if _pet_shop_type == "all":
			breed_entries = DB.get_all_pet_breeds()
		else:
			var type_definition := DB.get_pet_type(_pet_shop_type)
			for breed_entry: Variant in type_definition.get("breeds", []):
				if breed_entry is Dictionary:
					breed_entries.append(DB.get_pet_breed(
						str((breed_entry as Dictionary).get("id", ""))))
		for breed: Dictionary in breed_entries:
			var breed_id := str(breed.get("id", ""))
			var check: Dictionary = farm.can_buy_pet(breed_id)
			var subtitle := "%s · %s" % [
				str(breed.get("type_name", "")), str(breed.get("description", "")),
			]
			var reason := str(check.get("reason", ""))
			if not reason.is_empty():
				subtitle += " · " + reason
			elif int(check.get("house_cost", 0)) > 0:
				subtitle += " · 含%s %dG" % [
					str(DB.get_pet_house_def(str(check.get("house_type", "")))
						.get("name", "栖息地")),
					int(check.get("house_cost", 0)),
				]
			_add_shop_row(
				shop_buy_list,
				str(breed.get("name", breed_id)),
				subtitle,
				int(check.get("total", int(breed.get("price", 0)))),
				bool(check.get("ok", false)),
				func(_shift: bool) -> void:
					var new_pet_id: String = farm.buy_pet(breed_id)
					if not new_pet_id.is_empty():
						close_modal()
						open_pet_name_dialog(new_pet_id, false),
				"领养",
				UITheme.animal_icon(str(breed.get("type_id", "")))
			)

		shop_buy_list.add_child(_clip_label("宠物食物 / 药品", 11, UITheme.C_INK))
		var foods: Dictionary = DB.get_all_pet_foods()
		for food_id: Variant in foods.keys():
			var key := str(food_id)
			var food: Variant = foods[food_id]
			if not (food is Dictionary):
				continue
			var food_name := str((food as Dictionary).get("name", key))
			var food_price := int((food as Dictionary).get("price", 0))
			var for_types: Array = (food as Dictionary).get("for", [])
			var suitable: Array[String] = []
			for type_id: String in for_types:
				suitable.append(str(DB.get_pet_type(type_id).get("name", type_id)))
			var subtitle := "宠物药品"
			if not suitable.is_empty():
				subtitle = "适合：" + "、".join(PackedStringArray(suitable))
			_add_shop_row(
				shop_buy_list,
				food_name,
				subtitle,
				food_price,
				farm.money >= food_price,
				func(shift: bool) -> void: farm.buy_pet_food(key, 5 if shift else 1),
				"购买",
				UITheme.item_icon(key, "pet_food")
			)
		shop_buy_list.add_child(_wrap_label(
			"宠物会住进对应栖息地；没有空位时会自动扩建并收取栖息地费用。",
			10, UITheme.C_INK_SOFT, 164.0
		))
	else:
		var animal_ids: Array = farm.get_shop_animal_ids()
		if animal_ids.is_empty():
			shop_buy_list.add_child(_clip_label("栏位已满，暂时买不了新动物。", 11, UITheme.C_INK_SOFT))
		for animal_id: String in animal_ids:
			var definition := DB.get_animal(animal_id)
			var price := int(definition.get("buy_price", 0))
			_add_shop_row(
				shop_buy_list,
				str(definition.get("name", animal_id)),
				"产物：%s" % str(definition.get("product_name", "")),
				price,
				farm.money >= price and farm.can_buy_animal(animal_id),
				func(shift: bool) -> void: farm.buy_animal(animal_id),
				"购买",
				UITheme.animal_icon(animal_id)
			)

		var mount_goods: Array = farm.get_mount_shop_goods()
		if not mount_goods.is_empty():
			shop_buy_list.add_child(_clip_label("坐骑（马厩 / 自行车棚）", 11, UITheme.C_INK))
		for good: Dictionary in mount_goods:
			var mount_type := str(good.get("type", ""))
			var mount_icon: Texture2D = UITheme.item_icon("bicycle", "tool") \
				if mount_type in ["bicycle", "tricycle"] else UITheme.animal_icon(mount_type)
			_add_shop_row(
				shop_buy_list,
				str(good.get("name", mount_type)),
				str(good.get("desc", "")),
				int(good.get("price", 0)),
				bool(good.get("can_buy", false)),
				func(_shift: bool) -> void: farm.buy_mount(mount_type),
				"购买",
				mount_icon
			)

		var feed_price: int = farm.get_feed_price()
		if feed_price > 0:
			_add_shop_row(
				shop_buy_list,
				"饲料",
				"每只动物每天 1 份 · 在食槽旁喂食",
				feed_price,
				farm.money >= feed_price,
				func(shift: bool) -> void: farm.buy_feed(5 if shift else 1),
				"购买",
				UITheme.item_icon("feed", "feed")
			)

	var stacks: Array = farm.inventory.get_sellable_stacks()
	shop_sell_all.disabled = stacks.is_empty()
	if stacks.is_empty():
		shop_sell_list.add_child(_label("背包里还没有可出售的东西。", 11, UITheme.C_INK_SOFT))
		return

	for stack: Dictionary in stacks:
		var slot: Dictionary = stack["slot"]
		var index := int(stack["index"])
		var item_name := DB.get_item_name(str(slot.get("item_id", "")), str(slot.get("category", "")))
		var rare_suffix := ""
		if bool(slot.get("is_rare", false)):
			rare_suffix = "　✨" + str(slot.get("rare_name", ""))
		_add_shop_row(
			shop_sell_list,
			"%s ×%d%s" % [item_name, int(stack["count"]), rare_suffix],
			"单价 %d G" % int(stack["unit_price"]),
			int(stack["unit_price"]),
			true,
			func(shift: bool) -> void: farm.sell_stack(index, 5 if shift else 1),
			"出售",
			UITheme.item_icon(str(slot.get("item_id", "")), str(slot.get("category", "")))
		)


func _pet_type_short(type_id: String) -> String:
	var names := {
		"dog": "狗", "cat": "猫", "bird": "鸟", "red_panda": "熊猫",
		"fish": "鱼", "turtle": "乌龟", "rabbit": "兔", "hamster": "仓鼠",
		"guinea_pig": "豚鼠", "hedgehog": "刺猬", "squirrel": "松鼠",
		"ferret": "雪貂", "chinchilla": "龙猫", "young_livestock": "幼畜",
		"reptile": "爬宠", "insect": "昆虫", "special": "特殊",
		"aquatic_extended": "水生",
	}
	return str(names.get(type_id, type_id))


func _switch_shop_tab(tab: String) -> void:
	_shop_tab = tab
	refresh_shop()


func _add_shop_row(
	parent: VBoxContainer,
	title: String,
	subtitle: String,
	price: int,
	enabled: bool,
	action: Callable,
	button_text := "购买",
	icon_texture: Texture2D = null
) -> void:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", UITheme.row_style())
	row.tooltip_text = title + ("\n" + subtitle if not subtitle.is_empty() else "")
	parent.add_child(row)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)

	if icon_texture != null:
		var icon := TextureRect.new()
		icon.texture = icon_texture
		icon.custom_minimum_size = Vector2(13, 13)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	box.add_child(texts)
	texts.add_child(_clip_label(title, 11, UITheme.C_INK))
	if not subtitle.is_empty():
		texts.add_child(_wrap_label(subtitle, 10, UITheme.C_INK_SOFT, 84.0))

	var button_label := button_text
	if price > 0 and button_text not in ["已穿戴", "穿戴", "已拥有", "已满级"]:
		button_label = "%dG" % price
	var button := _clip_button(button_label, 10)
	button.custom_minimum_size = Vector2(44, 13)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = "%s %dG" % [button_text, price]
	button.disabled = not enabled
	button.pressed.connect(func() -> void:
		var shift := Input.is_key_pressed(KEY_SHIFT)
		action.call(shift)
	)
	box.add_child(button)


# ============================================================
# 钓鱼
# ============================================================

func start_fishing(fish: Dictionary, options: Dictionary) -> void:
	hide_dialogue()
	# 张力界面贴边，避开玩家与浮漂：默认左侧，朝左钓鱼时放右侧。
	var side := "left"
	if farm != null and farm.player != null and str(farm.player.facing) == "left":
		side = "right"
	var panel_size := Vector2(224, 104)
	var x := 8.0 if side == "left" else 480.0 - panel_size.x - 8.0
	minigame.position = Vector2(x, (270.0 - panel_size.y) * 0.5)
	minigame.size = panel_size
	minigame.visible = true
	_modal = "minigame"
	set_compass_visible(false)
	minigame.start(fish, options)
	farm.on_modal_opened("minigame")


func _on_minigame_finished(success: bool, result: Dictionary) -> void:
	farm.on_fishing_finished(success, result)
	minigame.visible = false
	if _modal == "minigame":
		_set_modal("")


func get_minigame() -> FishMiniGame:
	return minigame


func _on_hotbar_pressed(index: int) -> void:
	farm.select_index(index)
