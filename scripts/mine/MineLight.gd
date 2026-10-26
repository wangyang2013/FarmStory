class_name MineLight
extends Node2D
## 矿洞照明：玩家周围一圈暖色光晕，四周保持暗色（不发光特效，纯色阶）。

const RADIUS := 74.0

var _t := 0.0


func _ready() -> void:
	z_index = 9
	z_as_relative = false


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# 由外向内逐层叠加，模拟火把光衰减（像素规范：多档色阶，不做平滑渐变）
	var flicker := 0.92 + 0.08 * sin(_t * 7.0)
	var layers := 5
	for index in layers:
		var t := float(index) / float(layers)
		var radius := RADIUS * (1.0 - t * 0.6)
		var alpha := (0.08 + t * 0.05) * flicker
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.86, 0.62, alpha))
