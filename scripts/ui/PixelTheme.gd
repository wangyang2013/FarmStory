class_name PixelTheme
extends RefCounted
## 游戏 UI 主题（参考星露谷布局，按美术要求做减法）。
##
## 风格约定：
## - 浅米白面板 + 细浅棕边框 + 小圆角
## - 字体小巧清爽，物品格子大小统一，提示框简洁
## - 无立体浮雕、无发光、无复杂花纹、无高饱和颜色
##
## 用法：
##     var style := PixelTheme.panel_style()
##     panel.add_theme_stylebox_override("panel", style)
##     label.add_theme_font_override("font", PixelTheme.font())

const DB := preload("res://scripts/core/ConfigDB.gd")

const C_PANEL := Color("#f7f0e0")
const C_PANEL_ALT := Color("#efe4cd")
const C_BORDER := Color("#cbb692")
const C_BORDER_SOFT := Color("#ddccae")
const C_SLOT := Color("#f1e6d0")
const C_SLOT_SELECTED := Color("#fbf4e4")
const C_ACCENT := Color("#a9855c")
const C_INK := Color("#5a4a38")
const C_INK_SOFT := Color("#8a7862")
const C_DISABLED := Color("#ece5d6")
const C_DISABLED_TEXT := Color("#b3a894")

const C_GOOD := Color("#6f8f58")
const C_BAD := Color("#a87362")

static var _cache: Dictionary = {}


# ============================================================
# 字体
# ============================================================

const PIXEL_FONT_PATH := "res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.ttf"
## Fusion Pixel 原生 12px；规范要求字号取 12 的倍数。
const MIN_FONT_SIZE := 12


static func display_font_size(size: int) -> int:
	return 24 if size > 18 else 12


## 像素风字体：Fusion Pixel 12px（简体中文，OFL 授权），关闭抗锯齿与亚像素定位。
## 找不到字体文件时回退系统字体，保证开发环境不中断。
static func font() -> Font:
	if _cache.has("font"):
		return _cache["font"]
	var pixel_font: Font = null
	var loaded := load(PIXEL_FONT_PATH)
	if loaded is Font:
		pixel_font = loaded
	else:
		push_warning("[PixelTheme] 未找到像素字体，回退系统字体：%s" % PIXEL_FONT_PATH)
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray([
			"Microsoft YaHei", "Microsoft YaHei UI", "SimHei",
			"Noto Sans CJK SC", "WenQuanYi Micro Hei", "sans-serif",
		])
		pixel_font = system_font
	pixel_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	pixel_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_cache["font"] = pixel_font
	return pixel_font


# ============================================================
# 样式
# ============================================================

static func _flat(
	bg: Color,
	border: Color,
	radius: int,
	border_width: int,
	margin_h: int,
	margin_v: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	return style


## 主面板：浅米白底 + 细浅棕边框。
static func panel_style() -> StyleBoxFlat:
	if not _cache.has("panel"):
		_cache["panel"] = _flat(C_PANEL, C_BORDER, 2, 1, 5, 3)
	return _cache["panel"]


## 地图面板（规范）：#FDF5E6 底、#8B6D52 细边框、直角。
static func map_panel_style() -> StyleBoxFlat:
	if not _cache.has("map_panel"):
		_cache["map_panel"] = _flat(
			Color("#fdf5e6"), Color("#8b6d52"), 0, 1, 6, 4
		)
	return _cache["map_panel"]


## 标题行：稍深一档的米色，仅底边有分隔线。
static func header_style() -> StyleBoxFlat:
	if not _cache.has("header"):
		var style := _flat(C_PANEL_ALT, C_BORDER_SOFT, 2, 0, 5, 3)
		style.border_width_bottom = 2
		style.border_color = C_BORDER_SOFT
		_cache["header"] = style
	return _cache["header"]


## 物品格：统一大小、细边框。
static func slot_style(selected := false) -> StyleBoxFlat:
	var key := "slot_selected" if selected else "slot"
	if not _cache.has(key):
		if selected:
			_cache[key] = _flat(C_SLOT_SELECTED, C_ACCENT, 1, 2, 2, 2)
		else:
			_cache[key] = _flat(C_SLOT, C_BORDER_SOFT, 1, 1, 2, 2)
	return _cache[key]


## 列表行。
static func row_style(hover := false) -> StyleBoxFlat:
	var key := "row_hover" if hover else "row"
	if not _cache.has(key):
		_cache[key] = _flat(
			Color(1, 1, 1, 0.42) if not hover else Color(1, 1, 1, 0.66),
			C_BORDER_SOFT, 2, 1, 4, 3
		)
	return _cache[key]


static func button_style(state := "") -> StyleBoxFlat:
	var key := "button"
	var bg := Color("#f3e9d5")
	var border := C_BORDER
	match state:
		"hover":
			key = "button_hover"
			bg = Color("#fbf6e9")
			border = C_ACCENT
		"pressed":
			key = "button_pressed"
			bg = Color("#e7dbc4")
			border = C_ACCENT
		"disabled":
			key = "button_disabled"
			bg = C_DISABLED
			border = C_BORDER_SOFT
		_:
			pass
	if not _cache.has(key):
		_cache[key] = _flat(bg, border, 2, 1, 5, 3)
	return _cache[key]


## 像素风滑块：细轨道 + 方形滑块，避免引擎默认的圆角灰条。
static func slider_track_style() -> StyleBoxFlat:
	if not _cache.has("slider_track"):
		_cache["slider_track"] = _flat(Color("#e0d2b4"), C_BORDER_SOFT, 0, 1, 0, 0)
	return _cache["slider_track"]


static func slider_fill_style() -> StyleBoxFlat:
	if not _cache.has("slider_fill"):
		_cache["slider_fill"] = _flat(Color("#a9855c"), C_BORDER, 0, 0, 0, 0)
	return _cache["slider_fill"]


static func slider_grabber_texture() -> Texture2D:
	if _cache.has("slider_grabber"):
		return _cache["slider_grabber"]
	var image := Image.create(7, 11, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for y in 11:
		for x in 7:
			var color := C_PANEL
			if x == 0 or y == 0 or x == 6 or y == 10:
				color = C_BORDER
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	_cache["slider_grabber"] = texture
	return texture


## 像素风滚动条：细轨道 + 方形滑块。
static func apply_scrollbar(scroll: ScrollContainer) -> void:
	var track := _flat(Color("#efe4cd"), C_BORDER_SOFT, 0, 1, 0, 0)
	var grabber := _flat(Color("#c9b48c"), C_BORDER, 0, 1, 0, 0)
	var grabber_hl := _flat(Color("#b39a6f"), C_BORDER, 0, 1, 0, 0)
	var bar := scroll.get_v_scroll_bar()
	bar.custom_minimum_size = Vector2(8, 0)
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("grabber", grabber)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_hl)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_hl)


static func apply_slider(slider: HSlider) -> void:
	slider.add_theme_stylebox_override("slider", slider_track_style())
	slider.add_theme_stylebox_override("grabber_area", slider_fill_style())
	slider.add_theme_stylebox_override("grabber_area_highlight", slider_fill_style())
	slider.add_theme_icon_override("grabber", slider_grabber_texture())
	slider.add_theme_icon_override("grabber_highlight", slider_grabber_texture())


static func bar_background() -> StyleBoxFlat:
	if not _cache.has("bar_bg"):
		_cache["bar_bg"] = _flat(Color("#e6dac0"), C_BORDER_SOFT, 3, 1, 0, 0)
	return _cache["bar_bg"]


static func bar_fill(color: Color) -> StyleBoxFlat:
	var key := "bar_fill_%s" % color.to_html(false)
	if not _cache.has(key):
		_cache[key] = _flat(color, color, 2, 0, 0, 0)
	return _cache[key]


static func tooltip_style() -> StyleBoxFlat:
	if not _cache.has("tooltip"):
		_cache["tooltip"] = _flat(Color("#fdf8ec"), C_BORDER, 4, 1, 8, 5)
	return _cache["tooltip"]


# ============================================================
# 应用辅助
# ============================================================

static func apply_button(button: Button, font_size := 14) -> void:
	button.add_theme_font_override("font", font())
	button.add_theme_font_size_override("font_size", display_font_size(font_size))
	button.add_theme_stylebox_override("normal", button_style("normal"))
	button.add_theme_stylebox_override("hover", button_style("hover"))
	button.add_theme_stylebox_override("pressed", button_style("pressed"))
	button.add_theme_stylebox_override("disabled", button_style("disabled"))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", C_INK)
	button.add_theme_color_override("font_hover_color", C_INK)
	button.add_theme_color_override("font_pressed_color", C_INK)
	button.add_theme_color_override("font_disabled_color", C_DISABLED_TEXT)


static func apply_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_override("font", font())
	label.add_theme_font_size_override("font_size", display_font_size(font_size))
	label.add_theme_color_override("font_color", color)
	# Fusion Pixel 在小字号下有少量下探像素；加 2px 行距避免底部被裁。
	label.add_theme_constant_override("line_spacing", 2)


# ============================================================
# 16px 地图图标（规范：16×16，1px 深色描边）
# ============================================================

static func _stamp(img: Image, rect: Rect2i, color: Color) -> void:
	img.fill_rect(rect.grow(1), Color("#4a3b28"))
	img.fill_rect(rect, color)


## 地图实体图标：建筑暖棕、设施灰棕、NPC 亮色，统一 1px 深色描边。
static func map_icon(kind: String) -> Texture2D:
	var key := "map_icon_%s" % kind
	if _cache.has(key):
		return _cache[key]

	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	match kind:
		"house":
			_stamp(img, Rect2i(6, 2, 4, 1), Color("#b0603f"))
			_stamp(img, Rect2i(4, 3, 8, 2), Color("#b0603f"))
			_stamp(img, Rect2i(3, 5, 10, 2), Color("#a35d42"))
			_stamp(img, Rect2i(3, 7, 10, 7), Color("#e2c9a1"))
			_stamp(img, Rect2i(4, 8, 2, 2), Color("#8fb8cf"))
			_stamp(img, Rect2i(10, 8, 2, 2), Color("#8fb8cf"))
			_stamp(img, Rect2i(7, 10, 2, 4), Color("#7d5028"))
		"shop":
			_stamp(img, Rect2i(4, 2, 8, 2), Color("#8a5a3f"))
			_stamp(img, Rect2i(2, 4, 12, 2), Color("#8a5a3f"))
			for index in 4:
				var stripe := Color("#e5d3b6") if index % 2 == 0 else Color("#b0603f")
				img.fill_rect(Rect2i(2 + index * 3, 6, 2, 2), stripe)
			_stamp(img, Rect2i(2, 7, 12, 7), Color("#c99d74"))
			_stamp(img, Rect2i(4, 8, 2, 2), Color("#8fb8cf"))
			_stamp(img, Rect2i(7, 10, 2, 4), Color("#7d5028"))
		"coop":
			_stamp(img, Rect2i(5, 4, 6, 1), Color("#a35d42"))
			_stamp(img, Rect2i(4, 5, 8, 2), Color("#a35d42"))
			_stamp(img, Rect2i(3, 7, 10, 7), Color("#d8b283"))
			_stamp(img, Rect2i(7, 10, 2, 4), Color("#7d5028"))
		"barn":
			_stamp(img, Rect2i(4, 3, 8, 2), Color("#8a4f3a"))
			_stamp(img, Rect2i(2, 5, 12, 2), Color("#8a4f3a"))
			_stamp(img, Rect2i(2, 7, 12, 7), Color("#b98a5f"))
			_stamp(img, Rect2i(6, 9, 4, 5), Color("#8a5a3f"))
		"mine":
			_stamp(img, Rect2i(2, 5, 12, 10), Color("#6f6558"))
			_stamp(img, Rect2i(4, 6, 8, 2), Color("#8a5a3f"))
			_stamp(img, Rect2i(4, 8, 2, 7), Color("#8a5a3f"))
			_stamp(img, Rect2i(10, 8, 2, 7), Color("#8a5a3f"))
			_stamp(img, Rect2i(5, 8, 6, 7), Color("#2f2a24"))
		"bin":
			_stamp(img, Rect2i(3, 6, 10, 2), Color("#8a5a3f"))
			_stamp(img, Rect2i(4, 8, 8, 6), Color("#a97d55"))
			img.fill_rect(Rect2i(6, 8, 4, 1), Color("#4a3b28"))
		"bed":
			_stamp(img, Rect2i(2, 5, 12, 9), Color("#8a5a3f"))
			_stamp(img, Rect2i(3, 6, 10, 3), Color("#f0e6d2"))
			_stamp(img, Rect2i(3, 9, 10, 4), Color("#7fa3c0"))
			img.fill_rect(Rect2i(4, 6, 3, 2), Color("#fdf8ec"))
		"mirror":
			_stamp(img, Rect2i(5, 2, 6, 12), Color("#8a5a3f"))
			_stamp(img, Rect2i(6, 3, 4, 10), Color("#bcd6e6"))
			img.fill_rect(Rect2i(7, 4, 1, 5), Color("#eef7fc"))
		"chest":
			_stamp(img, Rect2i(3, 5, 10, 9), Color("#a9713f"))
			_stamp(img, Rect2i(3, 5, 10, 3), Color("#8a5a3f"))
			_stamp(img, Rect2i(7, 8, 2, 3), Color("#e5c065"))
		"stove":
			_stamp(img, Rect2i(3, 4, 10, 10), Color("#5a5148"))
			_stamp(img, Rect2i(5, 7, 6, 4), Color("#2f2a24"))
			img.fill_rect(Rect2i(6, 8, 4, 2), Color("#d9803f"))
			img.fill_rect(Rect2i(5, 3, 6, 1), Color("#8a8578"))
		"door":
			_stamp(img, Rect2i(5, 2, 6, 12), Color("#7d5028"))
			_stamp(img, Rect2i(6, 3, 4, 10), Color("#a9713f"))
			img.fill_rect(Rect2i(9, 8, 1, 1), Color("#e5c065"))
		"museum":
			_stamp(img, Rect2i(2, 6, 12, 8), Color("#d9ccb4"))
			_stamp(img, Rect2i(2, 3, 12, 2), Color("#9d8f8f"))
			_stamp(img, Rect2i(5, 1, 6, 3), Color("#9d8f8f"))
			for col in 3:
				img.fill_rect(Rect2i(4 + col * 4, 6, 1, 8), Color("#b7bec6"))
			_stamp(img, Rect2i(7, 9, 2, 5), Color("#7f5c3e"))
		"library":
			_stamp(img, Rect2i(2, 6, 12, 8), Color("#d8ad6a"))
			_stamp(img, Rect2i(2, 3, 12, 2), Color("#7d7488"))
			_stamp(img, Rect2i(5, 1, 6, 3), Color("#7d7488"))
			_stamp(img, Rect2i(4, 8, 3, 4), Color("#eee3c8"))
			_stamp(img, Rect2i(9, 8, 3, 4), Color("#eee3c8"))
			_stamp(img, Rect2i(7, 10, 2, 4), Color("#7f5c3e"))
		"clinic":
			_stamp(img, Rect2i(2, 6, 12, 8), Color("#f2ecdd"))
			_stamp(img, Rect2i(2, 3, 12, 2), Color("#b0604e"))
			_stamp(img, Rect2i(5, 1, 6, 3), Color("#b0604e"))
			_stamp(img, Rect2i(7, 7, 2, 5), Color("#c4553f"))
			_stamp(img, Rect2i(5, 8, 6, 1), Color("#c4553f"))
			_stamp(img, Rect2i(7, 11, 2, 3), Color("#8a6a4a"))
		"plant":
			_stamp(img, Rect2i(5, 10, 6, 5), Color("#a9713f"))
			_stamp(img, Rect2i(6, 8, 4, 2), Color("#7e9971"))
			_stamp(img, Rect2i(4, 5, 8, 4), Color("#7e9971"))
			_stamp(img, Rect2i(6, 3, 4, 3), Color("#93b083"))
		"rug":
			_stamp(img, Rect2i(2, 5, 12, 7), Color("#8aa06c"))
			_stamp(img, Rect2i(3, 6, 10, 5), Color("#6f8a58"))
			img.fill_rect(Rect2i(2, 4, 12, 1), Color("#d8c39a"))
			img.fill_rect(Rect2i(2, 12, 12, 1), Color("#d8c39a"))
		"table":
			_stamp(img, Rect2i(2, 5, 12, 3), Color("#b89268"))
			_stamp(img, Rect2i(3, 8, 2, 6), Color("#7d5a3c"))
			_stamp(img, Rect2i(11, 8, 2, 6), Color("#7d5a3c"))
		"chair":
			_stamp(img, Rect2i(4, 3, 8, 7), Color("#a97e52"))
			_stamp(img, Rect2i(5, 4, 6, 5), Color("#c9a276"))
			_stamp(img, Rect2i(4, 10, 2, 4), Color("#7d5a3c"))
			_stamp(img, Rect2i(10, 10, 2, 4), Color("#7d5a3c"))
		"fishtank":
			_stamp(img, Rect2i(2, 4, 12, 9), Color("#9fb4c0"))
			_stamp(img, Rect2i(3, 5, 10, 7), Color("#6fa3ad"))
			_stamp(img, Rect2i(5, 7, 3, 2), Color("#d9a05e"))
			_stamp(img, Rect2i(9, 9, 2, 1), Color("#e8c47a"))
			_stamp(img, Rect2i(2, 12, 12, 1), Color("#8c6a4a"))
		"gramophone":
			_stamp(img, Rect2i(3, 9, 10, 4), Color("#8c6a4a"))
			_stamp(img, Rect2i(5, 4, 6, 5), Color("#d8bd84"))
			_stamp(img, Rect2i(6, 2, 4, 3), Color("#e3c98c"))
			_stamp(img, Rect2i(7, 10, 2, 2), Color("#5f4326"))
		"calendar":
			_stamp(img, Rect2i(3, 3, 10, 10), Color("#eee3c8"))
			img.fill_rect(Rect2i(3, 3, 10, 2), Color("#c4553f"))
			img.fill_rect(Rect2i(5, 7, 6, 1), Color("#8a7862"))
			img.fill_rect(Rect2i(5, 9, 4, 1), Color("#8a7862"))
		"bookshelf":
			_stamp(img, Rect2i(2, 2, 12, 12), Color("#8c6a4a"))
			for row in 3:
				img.fill_rect(Rect2i(3, 3 + row * 4, 10, 3), Color("#b89268"))
				img.fill_rect(Rect2i(4, 3 + row * 4, 2, 3),
					[Color("#b5735f"), Color("#5fae7a"), Color("#7a8fc9")][row])
				img.fill_rect(Rect2i(7, 3 + row * 4, 2, 3),
					[Color("#e8b45a"), Color("#c47b9c"), Color("#d8bd84")][row])
		"stairs":
			_stamp(img, Rect2i(3, 3, 10, 10), Color("#8a8578"))
			img.fill_rect(Rect2i(4, 4, 8, 2), Color("#b9b3a6"))
			img.fill_rect(Rect2i(4, 7, 8, 2), Color("#a8a194"))
			img.fill_rect(Rect2i(4, 10, 8, 2), Color("#b9b3a6"))
			img.fill_rect(Rect2i(8, 5, 2, 6), Color("#4a3b28"))
			img.fill_rect(Rect2i(6, 9, 6, 2), Color("#4a3b28"))
		"cheese_maker":
			_stamp(img, Rect2i(3, 4, 10, 8), Color("#8f969b"))
			_stamp(img, Rect2i(2, 2, 12, 3), Color("#6f767b"))
			img.fill_rect(Rect2i(7, 1, 2, 2), Color("#c9d0d4"))
		"loom":
			_stamp(img, Rect2i(2, 3, 12, 10), Color("#8a5a3f"))
			_stamp(img, Rect2i(4, 5, 8, 6), Color("#e5d3b6"))
		"workbench":
			_stamp(img, Rect2i(2, 7, 12, 6), Color("#a9713f"))
			_stamp(img, Rect2i(3, 9, 2, 5), Color("#6b4423"))
			_stamp(img, Rect2i(11, 9, 2, 5), Color("#6b4423"))
		"pickling_barrel", "wine_barrel":
			_stamp(img, Rect2i(4, 3, 8, 11), Color("#a9713f"))
			img.fill_rect(Rect2i(3, 6, 10, 1), Color("#6b4423"))
			img.fill_rect(Rect2i(3, 11, 10, 1), Color("#6b4423"))
		"tv":
			_stamp(img, Rect2i(2, 4, 12, 8), Color("#4f4a44"))
			_stamp(img, Rect2i(4, 5, 8, 5), Color("#b9cfd4"))
		"bath":
			_stamp(img, Rect2i(2, 7, 12, 6), Color("#e9e6dd"))
			_stamp(img, Rect2i(4, 8, 8, 3), Color("#b9d2dc"))
		"fridge":
			_stamp(img, Rect2i(4, 2, 8, 12), Color("#d9d6cd"))
			img.fill_rect(Rect2i(5, 4, 6, 1), Color("#8d8b86"))
			img.fill_rect(Rect2i(9, 5, 1, 2), Color("#8d8b86"))
		"npc":
			_stamp(img, Rect2i(6, 2, 4, 4), Color("#f0c9a0"))
			_stamp(img, Rect2i(5, 6, 6, 7), Color("#d9534f"))
		_:
			_stamp(img, Rect2i(5, 5, 6, 6), Color("#c4553f"))

	var texture := ImageTexture.create_from_image(img)
	_cache[key] = texture
	return texture


## 玩家地图箭头：默认朝上，奶油光晕 + 深色描边 + 红色箭头。
static func player_marker_icon(size := 16) -> Texture2D:
	var key := "player_marker_%d" % size
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mask := PackedByteArray()
	mask.resize(size * size)
	if size <= 8:
		_set_mask_row(mask, size, 1, 3, 4)
		_set_mask_row(mask, size, 2, 2, 5)
		_set_mask_row(mask, size, 3, 1, 6)
		for row in range(4, 7):
			_set_mask_row(mask, size, row, 3, 4)
	else:
		_set_mask_row(mask, size, 2, 7, 8)
		_set_mask_row(mask, size, 3, 6, 9)
		_set_mask_row(mask, size, 4, 5, 10)
		_set_mask_row(mask, size, 5, 4, 11)
		for row in range(6, 10):
			_set_mask_row(mask, size, row, 7, 8)

	var dark := PackedByteArray()
	dark.resize(size * size)
	for y in size:
		for x in size:
			if mask[y * size + x] == 1:
				continue
			var edge := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < size and ny < size \
							and mask[ny * size + nx] == 1:
						edge = true
			if edge:
				dark[y * size + x] = 1

	for y in size:
		for x in size:
			if mask[y * size + x] == 1:
				img.set_pixel(x, y, Color("#d9534f"))
			elif dark[y * size + x] == 1:
				img.set_pixel(x, y, Color("#4a3b28"))
			else:
				var halo := false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var nx := x + dx
						var ny := y + dy
						if nx >= 0 and ny >= 0 and nx < size and ny < size \
								and dark[ny * size + nx] == 1:
							halo = true
				if halo:
					img.set_pixel(x, y, Color("#fdf8ec"))

	var texture := ImageTexture.create_from_image(img)
	_cache[key] = texture
	return texture


static func _set_mask_row(mask: PackedByteArray, size: int, y: int, x0: int, x1: int) -> void:
	for x in range(x0, x1 + 1):
		if x >= 0 and y >= 0 and x < size and y < size:
			mask[y * size + x] = 1


# ============================================================
# 16px 物品图标（程序化生成，无粗黑描边）
# ============================================================

const ICON_SIZE := 16


static func _new_icon() -> Image:
	var image := Image.create(ICON_SIZE, ICON_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	return image


static func _put(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)


static func _rect(image: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for py in range(y, y + h):
		for px in range(x, x + w):
			_put(image, px, py, color)


static func _disc(image: Image, cx: float, cy: float, radius: float, color: Color) -> void:
	var r := int(ceil(radius))
	for py in range(int(cy) - r, int(cy) + r + 1):
		for px in range(int(cx) - r, int(cx) + r + 1):
			var dx := float(px) + 0.5 - cx
			var dy := float(py) + 0.5 - cy
			if dx * dx + dy * dy <= radius * radius:
				_put(image, px, py, color)


## 低饱和暖色：同一 id 稳定映射到一种柔和颜色。
static func _soft_color(text: String, saturation := 0.34, value := 0.76) -> Color:
	var h := 0
	for index in text.length():
		h = (h * 31 + text.unicode_at(index)) % 360
	# 把色相往暖色区拉（排除刺眼的洋红/青绿）
	var hue := float((h % 300) + 20) / 360.0
	return Color.from_hsv(hue, saturation, value)


static func _texture(image: Image) -> ImageTexture:
	return ImageTexture.create_from_image(image)


static func item_icon(item_id: String, category := "") -> Texture2D:
	var key := "icon:%s:%s" % [item_id, category]
	if _cache.has(key):
		return _cache[key]

	var image := _new_icon()
	match category:
		"tool":
			_icon_tool(image, item_id)
		"rod":
			_icon_rod(image)
		"seed":
			_icon_seed(image, item_id)
		"crop":
			_icon_crop(image, item_id)
		"fish":
			_icon_fish(image, item_id)
		"animal_product":
			_icon_animal_product(image, item_id)
		"feed":
			_icon_feed(image)
		"fertilizer":
			_icon_fertilizer(image)
		"accessory":
			_icon_accessory(image, item_id)
		"fruit":
			_icon_fruit(image, item_id)
		"bee_product":
			_icon_bee_product(image, item_id)
		"bee_goods":
			_icon_bee_goods(image, item_id)
		"mineral":
			_icon_mineral(image, item_id)
		"artifact":
			_icon_artifact(image, item_id)
		"furniture":
			_icon_furniture(image, item_id)
		"machine":
			_icon_machine(image, item_id)
		"processed":
			_icon_processed(image, item_id)
		"weapon":
			_icon_weapon(image, item_id)
		"monster_drop":
			_icon_monster_drop(image, item_id)
		_:
			_icon_generic(image, item_id)

	var texture := _texture(image)
	_cache[key] = texture
	return texture


static func _icon_tool(image: Image, tool_id: String) -> void:
	var wood := Color("#a9825c")
	var wood_dark := Color("#8c6a4a")
	if tool_id == "hoe":
		_rect(image, 4, 12, 3, 2, wood_dark)
		_rect(image, 6, 9, 3, 3, wood)
		_rect(image, 8, 5, 2, 5, wood)
		_rect(image, 9, 3, 5, 3, Color("#b9c1c4"))
		_rect(image, 9, 5, 5, 1, Color("#9aa4a9"))
	else:
		_rect(image, 4, 6, 8, 7, Color("#9fb4c0"))
		_rect(image, 5, 7, 5, 2, Color("#b8cbd4"))
		_rect(image, 3, 8, 2, 2, Color("#9fb4c0"))
		_rect(image, 11, 8, 3, 3, Color("#8ca6b3"))
		_rect(image, 6, 13, 5, 1, Color("#8ca6b3"))


static func _icon_rod(image: Image) -> void:
	_rect(image, 3, 12, 2, 2, Color("#8c6a4a"))
	_rect(image, 5, 9, 2, 3, Color("#a9825c"))
	_rect(image, 7, 6, 2, 3, Color("#c0a077"))
	_rect(image, 9, 3, 1, 4, Color("#b9c1c4"))
	_disc(image, 10.5, 11.5, 1.4, Color("#8fadc0"))


static func _icon_seed(image: Image, crop_id: String) -> void:
	var band := _soft_color(crop_id)
	_rect(image, 4, 3, 8, 10, Color("#eadfc6"))
	_rect(image, 4, 3, 8, 1, Color("#d9caa9"))
	_rect(image, 4, 12, 8, 1, Color("#d9caa9"))
	_rect(image, 5, 4, 6, 3, band)
	_rect(image, 7, 8, 1, 4, Color("#7fa066"))
	_disc(image, 6.0, 9.5, 1.4, Color("#8fae75"))
	_disc(image, 9.0, 10.5, 1.4, Color("#8fae75"))


static func _icon_crop(image: Image, crop_id: String) -> void:
	var color := _soft_color(crop_id, 0.42, 0.78)
	var shade := color.darkened(0.12)
	_disc(image, 8.0, 9.0, 4.2, color)
	_disc(image, 6.0, 7.5, 1.8, color.lightened(0.12))
	_rect(image, 4, 12, 8, 1, shade)
	_rect(image, 7, 2, 1, 4, Color("#7fa066"))
	_disc(image, 5.5, 3.5, 1.4, Color("#8fae75"))
	_disc(image, 9.5, 3.5, 1.4, Color("#8fae75"))


static func _icon_fish(image: Image, fish_id: String) -> void:
	var color := _soft_color(fish_id, 0.30, 0.70)
	_disc(image, 7.0, 8.5, 3.6, color)
	_rect(image, 10, 6, 3, 5, color)
	_rect(image, 12, 5, 2, 7, color.darkened(0.10))
	_put(image, 5, 7, Color("#4a3b32"))
	_rect(image, 7, 9, 3, 1, color.lightened(0.18))


## 古物图标：土色残片 + 裂纹，避免发光。
## 家具图标：按家具配置里的 icon 字段画对应剪影。
static func _icon_furniture(image: Image, furniture_id: String) -> void:
	var definition := DB.get_furniture(furniture_id)
	var icon_kind := str(definition.get("icon", "plant"))
	match icon_kind:
		"rug":
			_stamp(image, Rect2i(2, 5, 12, 7), Color("#8aa06c"))
			_stamp(image, Rect2i(3, 6, 10, 5), Color("#6f8a58"))
			_stamp(image, Rect2i(2, 4, 12, 1), Color("#d8c39a"))
			_stamp(image, Rect2i(2, 12, 12, 1), Color("#d8c39a"))
		"table":
			_stamp(image, Rect2i(2, 5, 12, 3), Color("#b89268"))
			_stamp(image, Rect2i(3, 8, 2, 6), Color("#7d5a3c"))
			_stamp(image, Rect2i(11, 8, 2, 6), Color("#7d5a3c"))
		"chair":
			_stamp(image, Rect2i(4, 3, 8, 7), Color("#a97e52"))
			_stamp(image, Rect2i(5, 4, 6, 5), Color("#c9a276"))
			_stamp(image, Rect2i(4, 10, 2, 4), Color("#7d5a3c"))
			_stamp(image, Rect2i(10, 10, 2, 4), Color("#7d5a3c"))
		"fishtank":
			_stamp(image, Rect2i(2, 4, 12, 9), Color("#9fb4c0"))
			_stamp(image, Rect2i(3, 5, 10, 7), Color("#6fa3ad"))
			_stamp(image, Rect2i(5, 7, 3, 2), Color("#d9a05e"))
			_stamp(image, Rect2i(9, 9, 2, 1), Color("#e8c47a"))
			_stamp(image, Rect2i(2, 12, 12, 1), Color("#8c6a4a"))
		"gramophone":
			_stamp(image, Rect2i(3, 9, 10, 4), Color("#8c6a4a"))
			_stamp(image, Rect2i(5, 4, 6, 5), Color("#d8bd84"))
			_stamp(image, Rect2i(6, 2, 4, 3), Color("#e3c98c"))
			_stamp(image, Rect2i(7, 10, 2, 2), Color("#5f4326"))
		"calendar":
			_stamp(image, Rect2i(3, 3, 10, 10), Color("#eee3c8"))
			_stamp(image, Rect2i(3, 3, 10, 2), Color("#c4553f"))
			_stamp(image, Rect2i(5, 7, 6, 1), Color("#8a7862"))
			_stamp(image, Rect2i(5, 9, 4, 1), Color("#8a7862"))
		"bookshelf":
			_stamp(image, Rect2i(2, 2, 12, 12), Color("#8c6a4a"))
			for row in 3:
				_stamp(image, Rect2i(3, 3 + row * 4, 10, 3), Color("#b89268"))
				var colors := [Color("#b5735f"), Color("#5fae7a"), Color("#7a8fc9")]
				_stamp(image, Rect2i(4, 3 + row * 4, 2, 3), colors[row])
		_:
			_stamp(image, Rect2i(5, 10, 6, 5), Color("#a9713f"))
			_stamp(image, Rect2i(4, 5, 8, 5), Color("#7e9971"))
			_stamp(image, Rect2i(6, 3, 4, 3), Color("#93b083"))


static func _icon_artifact(image: Image, artifact_id: String) -> void:
	var color := _soft_color(artifact_id, 0.30, 0.55)
	var shade := color.darkened(0.20)
	_rect(image, 4, 6, 8, 6, color)
	_rect(image, 6, 4, 5, 9, color.lightened(0.10))
	_rect(image, 4, 11, 8, 1, shade)
	_rect(image, 8, 7, 1, 3, Color(0.30, 0.26, 0.22, 0.55))
	_rect(image, 10, 9, 1, 2, Color(0.30, 0.26, 0.22, 0.45))
	_put(image, 6, 7, shade)


static func _icon_animal_product(image: Image, product_id: String) -> void:
	if product_id.find("milk") >= 0:
		_rect(image, 5, 4, 6, 10, Color("#eef0ea"))
		_rect(image, 5, 2, 6, 3, Color("#9fb4c4"))
		_rect(image, 6, 8, 4, 3, Color("#f8faf6"))
		_rect(image, 5, 13, 6, 1, Color("#d6dbd2"))
	else:
		_disc(image, 8.0, 9.0, 4.2, Color("#f2e9d6"))
		_disc(image, 6.5, 7.5, 1.4, Color("#faf5e8"))
		_rect(image, 6, 3, 4, 2, Color("#e3d7bf"))


static func _icon_feed(image: Image) -> void:
	_rect(image, 3, 6, 10, 7, Color("#cbb282"))
	_rect(image, 3, 6, 10, 1, Color("#b69d6d"))
	_rect(image, 3, 12, 10, 1, Color("#b69d6d"))
	_rect(image, 7, 5, 2, 8, Color("#a9825c"))
	for index in 4:
		_rect(image, 4 + index * 2, 3, 1, 3, Color("#d8c294"))


static func _icon_fertilizer(image: Image) -> void:
	_rect(image, 4, 6, 8, 8, Color("#b09a76"))
	_rect(image, 6, 4, 4, 2, Color("#c3ad87"))
	_rect(image, 6, 9, 4, 2, Color("#e6dcc4"))


static func _icon_pet(image: Image, pet_id: String) -> void:
	var color := Color("#c8a97e") if pet_id == "cat" else Color("#b08a62")
	if pet_id == "cat":
		_rect(image, 3, 8, 9, 4, color)
		_disc(image, 10.0, 6.0, 2.6, color)
		_rect(image, 8, 2, 1, 2, color)
		_rect(image, 11, 2, 1, 2, color)
		_put(image, 9, 6, Color("#5a4a38"))
		_put(image, 11, 6, Color("#5a4a38"))
		_rect(image, 12, 8, 2, 1, Color("#8c7a68"))
		_rect(image, 4, 12, 1, 2, color.darkened(0.15))
		_rect(image, 9, 12, 1, 2, color.darkened(0.15))
	else:
		_rect(image, 3, 8, 9, 4, color)
		_disc(image, 10.0, 6.5, 2.4, color)
		_rect(image, 8, 5, 1, 3, color.darkened(0.15))
		_rect(image, 11, 5, 1, 3, color.darkened(0.15))
		_put(image, 10, 6, Color("#5a4a38"))
		_rect(image, 4, 12, 1, 2, color.darkened(0.15))
		_rect(image, 9, 12, 1, 2, color.darkened(0.15))
		_rect(image, 2, 7, 1, 3, color)


static func _icon_accessory(image: Image, accessory_id: String) -> void:
	var definition: Dictionary = DB.get_accessory(accessory_id)
	var color := Color("#c9a46a")
	if not definition.is_empty():
		var hex := str(definition.get("color", ""))
		if not hex.is_empty():
			color = Color(hex)

	match accessory_id:
		"straw_hat", "beret":
			_rect(image, 3, 7, 10, 2, color)
			_rect(image, 5, 4, 6, 3, color.darkened(0.10))
			_rect(image, 5, 4, 6, 1, color.lightened(0.18))
		"round_glasses", "sunglasses":
			_disc(image, 5.5, 8.0, 2.2, color)
			_disc(image, 10.5, 8.0, 2.2, color)
			_rect(image, 7.5, 7.6, 1.4, 0.8, color.darkened(0.15))
		"scarf", "pendant":
			_rect(image, 3, 6, 10, 3, color)
			_rect(image, 8, 9, 2, 4, color.darkened(0.12))
		"bracelet", "gardening_gloves":
			_rect(image, 5, 6, 6, 5, color)
			_rect(image, 5, 6, 6, 1, color.lightened(0.15))
		"small_backpack", "cape":
			_rect(image, 4, 5, 8, 8, color)
			_rect(image, 4, 5, 8, 1, color.lightened(0.15))
		"flower_crown":
			for index in 4:
				_disc(image, 3.5 + float(index) * 3.0, 8.0, 1.6, color)
		_:
			_disc(image, 8.0, 8.0, 4.0, color)


static func _icon_fruit(image: Image, fruit_id: String) -> void:
	var color := _soft_color(fruit_id, 0.42, 0.8)
	_disc(image, 8.0, 9.0, 4.4, color)
	_disc(image, 6.2, 7.4, 1.8, color.lightened(0.16))
	_rect(image, 8, 2, 1, 4, Color("#6b4a3a"))
	_rect(image, 9, 3, 3, 1, Color("#6b4a3a"))
	_disc(image, 11.0, 3.5, 1.6, Color("#7fa066"))


static func _icon_bee_product(image: Image, product_id: String) -> void:
	if product_id == "beeswax":
		_rect(image, 4, 6, 8, 7, Color("#e8d8a8"))
		_rect(image, 4, 6, 8, 2, Color("#f4e8c4"))
		_rect(image, 6, 9, 4, 1, Color("#d3c090"))
	else:
		# 蜂蜜罐
		_rect(image, 5, 5, 6, 9, Color("#e3b954"))
		_rect(image, 5, 8, 6, 2, Color("#f0d27a"))
		_rect(image, 4, 3, 8, 3, Color("#a9825c"))
		_rect(image, 6, 11, 3, 2, Color("#fff2c8"))


static func _icon_bee_goods(image: Image, good_id: String) -> void:
	match good_id:
		"beehive":
			_rect(image, 4, 6, 8, 8, Color("#d8b87e"))
			_rect(image, 3, 4, 10, 3, Color("#8c6a4a"))
			_rect(image, 7, 11, 2, 2, Color("#4a3520"))
		"queen_bee":
			_disc(image, 8.0, 9.0, 3.2, Color("#e3c25a"))
			_rect(image, 6, 8, 1, 3, Color("#4a3520"))
			_rect(image, 8, 8, 1, 3, Color("#4a3520"))
			_rect(image, 5, 5, 2, 1, Color("#f0f0f0"))
			_rect(image, 9, 5, 2, 1, Color("#f0f0f0"))
		"sugar_water":
			_rect(image, 6, 5, 4, 9, Color("#dfeef2"))
			_rect(image, 6, 9, 4, 4, Color("#e8d8a8"))
			_rect(image, 5, 3, 6, 2, Color("#a9825c"))
		"bee_medicine":
			_rect(image, 6, 5, 4, 9, Color("#c8d8e0"))
			_rect(image, 7, 8, 2, 3, Color("#b57f74"))
			_rect(image, 5, 3, 6, 2, Color("#8c9aa6"))
		_:
			_disc(image, 8.0, 8.0, 4.0, _soft_color(good_id))


static func _icon_mineral(image: Image, mineral_id: String) -> void:
	var ore_colors := {
		"stone": Color("#a9a49a"), "copper": Color("#c98a4b"), "iron": Color("#8d98a5"),
		"gold": Color("#d8b64a"), "mythril": Color("#8fb8d8"), "iridium": Color("#9a7fb0"),
		"granite": Color("#b0aca4"), "marble": Color("#e0ddd6"),
		"agate": Color("#b07a5a"), "amethyst": Color("#a98ac4"), "aquamarine": Color("#8fc4d8"),
		"emerald": Color("#5fae7a"), "ruby": Color("#c94a5a"), "sapphire": Color("#4a6ac9"),
		"garnet": Color("#a04a4a"), "diamond": Color("#e8f0f4"),
	}
	var color: Color = ore_colors.get(mineral_id, Color("#a9a49a"))
	# 灰色石块 + 彩色矿脉
	for point: Array in [[4, 5], [8, 4], [5, 8], [9, 9], [6, 11], [10, 6]]:
		_rect(image, int(point[0]), int(point[1]), 3, 3, Color("#9c978d"))
	_rect(image, 5, 6, 2, 2, color)
	_rect(image, 9, 5, 2, 2, color)
	_rect(image, 7, 9, 2, 2, color)
	_rect(image, 4, 10, 2, 2, color.lightened(0.12))


static func _icon_machine(image: Image, machine_id: String) -> void:
	var wood := Color("#a9713f")
	var dark := Color("#6b4423")
	match machine_id:
		"cheese_maker":
			_rect(image, 3, 5, 10, 8, Color("#8f969b"))
			_rect(image, 2, 3, 12, 3, Color("#6f767b"))
			_rect(image, 7, 2, 2, 2, Color("#c9d0d4"))
			_rect(image, 4, 10, 8, 2, Color("#5f666b"))
		"loom":
			_rect(image, 3, 3, 2, 11, wood)
			_rect(image, 11, 3, 2, 11, wood)
			_rect(image, 2, 2, 12, 2, dark)
			_rect(image, 5, 5, 6, 7, Color("#e5d3b6"))
		"workbench":
			_rect(image, 2, 6, 12, 3, wood)
			_rect(image, 3, 9, 2, 5, dark)
			_rect(image, 11, 9, 2, 5, dark)
		_:
			_rect(image, 4, 4, 8, 9, wood)
			_rect(image, 3, 5, 10, 1, dark)
			_rect(image, 3, 10, 10, 1, dark)
			_rect(image, 7, 7, 2, 2, Color("#4a3b28"))


static func _icon_processed(image: Image, product_id: String) -> void:
	match product_id:
		"cheese":
			_rect(image, 3, 6, 10, 6, Color("#e5c065"))
			_rect(image, 5, 4, 6, 2, Color("#f3d98e"))
			_put(image, 6, 8, Color("#c9a13f"))
		"butter":
			_rect(image, 4, 6, 8, 6, Color("#f3d98e"))
			_rect(image, 4, 5, 8, 1, Color("#fff0bd"))
		"cloth":
			_rect(image, 3, 5, 10, 7, Color("#dfe9f2"))
			_rect(image, 3, 8, 10, 1, Color("#b9c9d6"))
		"pickled_veggies":
			_rect(image, 5, 3, 6, 10, Color("#d9e6c2"))
			_rect(image, 6, 4, 4, 7, Color("#7f9c4f"))
			_rect(image, 5, 2, 6, 2, Color("#8b6d52"))
		"wine":
			_rect(image, 6, 3, 4, 3, Color("#7a2f3f"))
			_rect(image, 7, 5, 2, 6, Color("#4a1f2b"))
			_rect(image, 6, 10, 4, 2, Color("#7a2f3f"))
			_rect(image, 7, 1, 2, 2, Color("#c9a86a"))
		"beer":
			_rect(image, 4, 5, 8, 9, Color("#c99d3f"))
			_rect(image, 4, 4, 8, 2, Color("#f0e6d2"))
			_rect(image, 12, 7, 2, 4, Color("#8a6a2f"))
		"honey_bottle":
			_rect(image, 6, 3, 4, 2, Color("#8b6d52"))
			_rect(image, 5, 5, 6, 8, Color("#e5b94f"))
			_rect(image, 6, 6, 4, 1, Color("#f3d98e"))
		_:
			_disc(image, 8.0, 8.0, 4.2, Color("#e5c065"))


static func _icon_weapon(image: Image, weapon_id: String) -> void:
	_rect(image, 7, 2, 2, 9, Color("#c9d0d4"))
	_rect(image, 8, 2, 1, 9, Color("#eef7fc"))
	_rect(image, 6, 10, 4, 2, Color("#e5c065"))
	_rect(image, 7, 12, 2, 3, Color("#7d5028"))


static func _icon_monster_drop(image: Image, item_id: String) -> void:
	if item_id == "bat_wing":
		_rect(image, 4, 5, 8, 6, Color("#8b7aa8"))
		_rect(image, 1, 6, 4, 3, Color("#6f5f8c"))
		_rect(image, 11, 6, 4, 3, Color("#6f5f8c"))
	else:
		_rect(image, 4, 5, 8, 7, Color("#7fae6a"))
		_rect(image, 5, 7, 2, 2, Color("#93c27e"))
		_rect(image, 9, 10, 2, 2, Color("#93c27e"))


static func _icon_generic(image: Image, item_id: String) -> void:
	_disc(image, 8.0, 8.0, 4.2, _soft_color(item_id, 0.25, 0.8))


## 动物图标（鸡 / 牛），16×16。
static func animal_icon(animal_id: String) -> Texture2D:
	var key := "animal_icon:" + animal_id
	if _cache.has(key):
		return _cache[key]

	var image := _new_icon()
	if animal_id in ["dog", "cat"]:
		_icon_pet(image, animal_id)
		var pet_texture := _texture(image)
		_cache[key] = pet_texture
		return pet_texture

	var big := animal_id in [
		"cow", "buffalo", "horse", "yak", "camel", "donkey",
		"deer", "alpaca", "ostrich", "sheep", "goat",
	]
	var body := Color("#efe9dc")
	var patch := Color("#8c7a68")

	if big:
		_rect(image, 2, 8, 11, 5, body)
		_disc(image, 6.0, 10.0, 2.0, patch)
		_disc(image, 10.0, 11.0, 1.4, patch)
		_disc(image, 12.0, 7.0, 2.0, body)
		_rect(image, 12, 5, 1, 2, Color("#d9cdb8"))
		_put(image, 13, 7, Color("#7a6650"))
		_rect(image, 4, 13, 1, 2, Color("#8c7a68"))
		_rect(image, 9, 13, 1, 2, Color("#8c7a68"))
	else:
		_disc(image, 7.0, 9.5, 3.6, body)
		_disc(image, 10.0, 6.0, 2.0, body)
		_rect(image, 9, 3, 1, 1, Color("#b57f74"))
		_rect(image, 11, 3, 1, 1, Color("#b57f74"))
		_rect(image, 12, 6, 2, 1, Color("#c9ac74"))
		_put(image, 11, 6, Color("#5a4a38"))
		_rect(image, 5, 13, 1, 2, Color("#b69d6d"))
		_rect(image, 9, 13, 1, 2, Color("#b69d6d"))

	var texture := _texture(image)
	_cache[key] = texture
	return texture


# ============================================================
# 小图标（HUD）
# ============================================================

class PixelIcon:
	extends Control

	var kind := "coin"


	func _draw() -> void:
		var s := minf(size.x, size.y)
		if s <= 0.0:
			return
		var center := size * 0.5
		var unit := s / 16.0
		var ink := Color("#5a4a38")

		match kind:
			"coin":
				draw_circle(center, 6.0 * unit, Color("#d8bd84"))
				draw_circle(center, 4.6 * unit, Color("#e8d29a"))
				draw_line(center + Vector2(-1.6, -2.0) * unit, center + Vector2(-1.6, 2.0) * unit, Color("#a9855c"), unit)
				draw_line(center + Vector2(-1.6, 2.0) * unit, center + Vector2(1.6, 2.0) * unit, Color("#a9855c"), unit)
				draw_line(center + Vector2(1.6, 2.0) * unit, center + Vector2(1.6, -2.0) * unit, Color("#a9855c"), unit)
			"sun":
				draw_circle(center, 4.4 * unit, Color("#e3c98c"))
				for index in 8:
					var angle := TAU * float(index) / 8.0
					var from := center + Vector2(cos(angle), sin(angle)) * 5.6 * unit
					var to := center + Vector2(cos(angle), sin(angle)) * 7.2 * unit
					draw_line(from, to, Color("#e3c98c"), unit)
			"rain":
				draw_circle(center + Vector2(-1.6, -1.6) * unit, 3.0 * unit, Color("#b8c6cf"))
				draw_circle(center + Vector2(1.4, -1.2) * unit, 3.4 * unit, Color("#cbd7de"))
				for index in 3:
					var x := center.x + (-2.8 + float(index) * 2.4) * unit
					draw_line(Vector2(x, center.y + 2.0 * unit), Vector2(x - unit, center.y + 5.0 * unit), Color("#8fadc0"), unit)
			"snow":
				draw_circle(center, 1.6 * unit, Color("#dbe4e8"))
				for index in 6:
					var angle := TAU * float(index) / 6.0
					draw_line(center, center + Vector2(cos(angle), sin(angle)) * 5.6 * unit, Color("#dbe4e8"), unit)
			"blizzard":
				draw_circle(center + Vector2(0, -1.5) * unit, 1.4 * unit, Color("#e6eef2"))
				for index in 3:
					var y := center.y + float(index - 1) * 3.2 * unit
					draw_line(Vector2(center.x - 6.0 * unit, y),
						Vector2(center.x + 6.0 * unit, y - unit),
						Color("#c8d6dd"), unit)
			"storm":
				draw_circle(center + Vector2(-1.6, -1.8) * unit, 3.0 * unit, Color("#a3aeb6"))
				draw_circle(center + Vector2(1.4, -1.2) * unit, 3.4 * unit, Color("#b6c1c8"))
				draw_line(center + Vector2(0.4, 1.6) * unit, center + Vector2(-1.2, 5.0) * unit, Color("#dcc07e"), unit)
				draw_line(center + Vector2(-1.2, 5.0) * unit, center + Vector2(1.2, 5.0) * unit, Color("#dcc07e"), unit)
			"energy":
				draw_circle(center, 4.6 * unit, Color("#8fae75"))
				draw_line(center + Vector2(0.6, -3.0) * unit, center + Vector2(-1.2, 0.2) * unit, Color("#f6efdd"), unit)
				draw_line(center + Vector2(-1.2, 0.2) * unit, center + Vector2(0.6, 0.2) * unit, Color("#f6efdd"), unit)
				draw_line(center + Vector2(0.6, 0.2) * unit, center + Vector2(-0.6, 3.0) * unit, Color("#f6efdd"), unit)
			_:
				draw_circle(center, 4.0 * unit, ink)
