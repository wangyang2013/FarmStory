class_name CharacterCreator
extends CanvasLayer
## 角色创建 / 外观编辑。
##
## 支持设计文档要求的自定义项：
##   性别、脸型（4）、发型（8）、发色（12）、肤色（5）、服装（6）、衣服颜色（8）
##
## 美术沿用 16px 像素角色（PixelArt.draw_character），
## 所有选项与中文名都来自 PixelArt 的常量表。

signal confirmed(look: Dictionary)
signal cancelled

const Art := preload("res://scripts/art/PixelArt.gd")
const UITheme := preload("res://scripts/ui/PixelTheme.gd")

var _look: Dictionary = Art.default_look()
var _edit_mode := false
var _font: Font

var _root: Control
var _preview: Control
var _options_box: VBoxContainer
var _title_label: Label
var _confirm_button: Button
var _name_input: LineEdit
var _farm_input: LineEdit
var player_name_value := "农夫"
var farm_name_value := "阳光牧场"


func setup(initial_look: Dictionary, edit_mode := false) -> void:
	_look = Art.normalize_look(initial_look)
	_edit_mode = edit_mode
	_font = UITheme.font()
	layer = 20
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.08, 0.06, 0.04, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_style())
	panel.custom_minimum_size = Vector2(404, 264)
	_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	panel.add_child(column)

	# 标题栏
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	column.add_child(header)

	_title_label = _label("创建角色" if not _edit_mode else "修改外观", 12, UITheme.C_INK)
	header.add_child(_title_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	var hint := _label("随时可在镜子前修改", 8, UITheme.C_INK_SOFT)
	header.add_child(hint)

	var divider := ColorRect.new()
	divider.color = UITheme.C_BORDER_SOFT
	divider.custom_minimum_size = Vector2(0, 1)
	column.add_child(divider)

	# 新游戏：主角名 + 牧场名（镜子编辑外观时不显示）
	if not _edit_mode:
		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 4)
		column.add_child(name_row)
		name_row.add_child(_label("主角", 11, UITheme.C_INK_SOFT))
		_name_input = _line_edit("主角名称", 116)
		name_row.add_child(_name_input)
		var name_spacer := Control.new()
		name_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_row.add_child(name_spacer)
		name_row.add_child(_label("牧场", 11, UITheme.C_INK_SOFT))
		_farm_input = _line_edit("牧场名称", 142)
		name_row.add_child(_farm_input)

	# 主体：预览 + 选项
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	column.add_child(body)

	var preview_frame := PanelContainer.new()
	preview_frame.add_theme_stylebox_override("panel", UITheme.row_style())
	preview_frame.custom_minimum_size = Vector2(84, 176)
	body.add_child(preview_frame)

	_preview = CharacterPreview.new()
	_preview.creator = self
	_preview.custom_minimum_size = Vector2(78, 168)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_child(_preview)

	var options_scroll := ScrollContainer.new()
	options_scroll.custom_minimum_size = Vector2(296, 166)
	options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	options_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(options_scroll)

	_options_box = VBoxContainer.new()
	_options_box.add_theme_constant_override("separation", 2)
	_options_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options_box.custom_minimum_size = Vector2(284, 0)
	options_scroll.add_child(_options_box)

	# 底部按钮
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 4)
	column.add_child(footer)

	var random_button := _button("随机", 11)
	random_button.custom_minimum_size = Vector2(48, 17)
	random_button.pressed.connect(_on_random)
	footer.add_child(random_button)

	var footer_spacer := Control.new()
	footer_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(footer_spacer)

	if _edit_mode:
		var cancel_button := _button("取消", 11)
		cancel_button.custom_minimum_size = Vector2(48, 17)
		cancel_button.pressed.connect(_on_cancel)
		footer.add_child(cancel_button)

	_confirm_button = _button("确定", 11)
	_confirm_button.custom_minimum_size = Vector2(58, 18)
	_confirm_button.pressed.connect(_on_confirm)
	footer.add_child(_confirm_button)

	_rebuild_options()


# ============================================================
# 控件
# ============================================================

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	UITheme.apply_label(label, font_size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(text: String, font_size := 14) -> Button:
	var button := Button.new()
	button.text = text
	UITheme.apply_button(button, font_size)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	return button


func _line_edit(placeholder: String, width: float) -> LineEdit:
	var input := LineEdit.new()
	input.placeholder_text = placeholder
	input.max_length = 8
	input.custom_minimum_size = Vector2(width, 18)
	input.add_theme_font_override("font", _font)
	input.add_theme_font_size_override("font_size", 11)
	input.add_theme_color_override("font_color", UITheme.C_INK)
	input.add_theme_stylebox_override("normal", UITheme.slot_style(false))
	input.add_theme_stylebox_override("focus", UITheme.slot_style(true))
	if placeholder == "主角名称":
		input.text = "农夫"
	elif placeholder == "牧场名称":
		input.text = "阳光牧场"
	return input


func _swatch(color: Color, field: String, value: String, selected: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(15, 15)
	button.tooltip_text = value
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	if selected:
		style.border_color = UITheme.C_ACCENT
		style.set_border_width_all(2)
	else:
		style.border_color = UITheme.C_BORDER_SOFT
		style.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func() -> void:
		_look[field] = value
		_rebuild_options()
	)
	return button


func _option_group(title: String, entries: Dictionary, field: String) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 1)
	_options_box.add_child(group)

	group.add_child(_label(title, 11, UITheme.C_INK_SOFT))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.add_theme_constant_override("h_separation", 5)
	group.add_child(row)

	for key: Variant in entries.keys():
		var id := str(key)
		var name := str(entries[key])
		var button := _button(name, 11)
		button.custom_minimum_size = Vector2(0, 17)
		var selected := str(_look.get(field, "")) == id
		if selected:
			button.add_theme_color_override("font_color", UITheme.C_ACCENT)
		button.pressed.connect(func() -> void:
			_look[field] = id
			_rebuild_options()
		)
		row.add_child(button)


func _color_group(title: String, colors: Dictionary, names: Dictionary, field: String) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation", 1)
	_options_box.add_child(group)
	group.add_child(_label(title, 11, UITheme.C_INK_SOFT))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	group.add_child(row)

	for key: Variant in colors.keys():
		var id := str(key)
		var color: Color = colors[key]
		var selected := str(_look.get(field, "")) == id
		row.add_child(_swatch(color, field, id, selected))


func _rebuild_options() -> void:
	for child in _options_box.get_children():
		child.queue_free()

	_option_group("性别", Art.GENDER_NAMES, "gender")
	_option_group("脸型", Art.FACE_SHAPE_NAMES, "face")
	_option_group("发型", Art.HAIR_STYLE_NAMES, "hair")
	_color_group("发色", Art.HAIR_COLORS, Art.HAIR_COLOR_NAMES, "hair_color")
	_color_group("肤色", Art.SKIN_TONES, Art.SKIN_NAMES, "skin")
	_option_group("服装", Art.OUTFIT_NAMES, "outfit")
	_color_group("衣服颜色", Art.OUTFIT_COLORS, Art.OUTFIT_COLOR_NAMES, "outfit_color")

	if _preview != null:
		_preview.queue_redraw()


# ============================================================
# 预览
# ============================================================

class CharacterPreview:
	extends Control

	var creator: CharacterCreator


	func _draw() -> void:
		if creator == null:
			return
		var bg := Color("#f3ead6")
		draw_rect(Rect2(Vector2.ZERO, size), bg, true)
		# 地面
		var ground := Color("#dfe8cf")
		draw_rect(Rect2(0, size.y * 0.70, size.x, size.y * 0.30), ground, true)
		# 角色放大绘制（extra_scale 叠加在 16px 网格的 ×2 之上）
		var extra := minf(size.x / 46.0, size.y / 76.0)
		Art.draw_character(
			self, creator._look, "down", 0.0, false,
			Vector2(size.x * 0.5, size.y * 0.74), extra
		)


# ============================================================
# 事件
# ============================================================

func _on_random() -> void:
	_look = {
		"gender": _pick(Art.GENDER_NAMES.keys()),
		"face": _pick(Art.FACE_SHAPE_NAMES.keys()),
		"hair": _pick(Art.HAIR_STYLE_NAMES.keys()),
		"hair_color": _pick(Art.HAIR_COLORS.keys()),
		"skin": _pick(Art.SKIN_TONES.keys()),
		"outfit": _pick(Art.OUTFIT_NAMES.keys()),
		"outfit_color": _pick(Art.OUTFIT_COLORS.keys()),
	}
	_rebuild_options()


func _pick(keys: Array) -> String:
	# 每次随机都新建 RNG，不与其它系统共用。
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return str(keys[rng.randi_range(0, keys.size() - 1)])


func _on_confirm() -> void:
	if not _edit_mode:
		player_name_value = _name_input.text.strip_edges() if _name_input != null else ""
		if player_name_value.is_empty():
			player_name_value = "农夫"
		if player_name_value.length() > 8:
			player_name_value = player_name_value.substr(0, 8)
		farm_name_value = _farm_input.text.strip_edges() if _farm_input != null else ""
		if farm_name_value.is_empty():
			farm_name_value = "阳光牧场"
		if farm_name_value.length() > 8:
			farm_name_value = farm_name_value.substr(0, 8)
	confirmed.emit(Art.normalize_look(_look))
	queue_free()


func _on_cancel() -> void:
	cancelled.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and _edit_mode:
			_on_cancel()
			get_viewport().set_input_as_handled()
