class_name FatigueVignette
extends Control
## 疲劳暗角：体力低于 20% 时屏幕边缘逐渐变暗，并随呼吸轻微起伏。
## 纯色块叠加，不做平滑渐变（像素规范）。

var intensity := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	if intensity <= 0.0:
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	if intensity <= 0.0:
		return
	var size := get_rect().size
	var pulse := 0.85 + 0.15 * sin(_t * 2.4)
	var strength := intensity * pulse
	# 四边色阶收边：每一侧 4 档，越靠边越深
	var bands := 4
	for index in bands:
		var t := float(index) / float(bands)
		var alpha := strength * (1.0 - t) * 0.20
		var offset := float(index) * 6.0
		draw_rect(Rect2(0, offset, size.x, 6), Color(0.10, 0.08, 0.20, alpha), true)
		draw_rect(Rect2(0, size.y - offset - 6, size.x, 6),
			Color(0.10, 0.08, 0.20, alpha), true)
		draw_rect(Rect2(offset, 0, 6, size.y), Color(0.10, 0.08, 0.20, alpha), true)
		draw_rect(Rect2(size.x - offset - 6, 0, 6, size.y),
			Color(0.10, 0.08, 0.20, alpha), true)
