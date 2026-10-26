class_name BathEffect
extends Node2D
## 泡温泉特效：水汽、气泡、爱心与闪光，持续 1.6 秒后自动移除。

const DURATION := 1.6

var _t := 0.0
var _seeds: Array[float] = []


func setup(world_position: Vector2) -> void:
	position = world_position
	z_as_relative = false
	z_index = 22
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in 10:
		_seeds.append(rng.randf())
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		queue_free()


func _draw() -> void:
	var fade := clampf(1.0 - _t / DURATION, 0.0, 1.0)

	# 上升的水汽（三团，错开相位）
	for index in 3:
		var rise := fmod(_t * 0.55 + float(index) * 0.33, 1.0)
		var x := sin(_t * 1.6 + float(index) * 2.0) * 12.0
		var y := -6.0 - rise * 32.0
		var alpha := (1.0 - rise) * 0.72 * fade
		draw_circle(Vector2(x, y), 7.0 - rise * 3.0, Color(0.97, 0.99, 0.99, alpha))

	# 水面扩散波纹
	for index in 2:
		var ripple := fmod(_t * 0.9 + float(index) * 0.5, 1.0)
		draw_set_transform(Vector2(0, -4), 0.0, Vector2(1.0, 0.45))
		draw_arc(Vector2.ZERO, 8.0 + ripple * 26.0, 0.0, TAU, 20,
			Color(0.9, 0.98, 0.97, (1.0 - ripple) * 0.45 * fade), 1.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 气泡
	for index in 7:
		var t := fmod(_t * 0.9 + _seeds[index % _seeds.size()], 1.0)
		var bx := sin(_t * 2.0 + float(index)) * 14.0
		var by := -4.0 - t * 26.0
		draw_rect(Rect2(roundf(bx), roundf(by), 2.0, 2.0),
			Color(0.90, 0.98, 0.96, (1.0 - t) * 0.85 * fade))

	# 爱心（4 颗，依次升起）
	for index in 4:
		var t := fmod(_t * 0.75 + float(index) * 0.25, 1.0)
		if t > 0.88:
			continue
		var hx := -8.0 + float(index) * 5.0 + sin(_t * 2.0 + float(index)) * 3.0
		var hy := -28.0 - t * 20.0
		var color := Color(0.93, 0.52, 0.64, fade * (1.0 - t))
		draw_circle(Vector2(hx - 1.8, hy), 2.2, color)
		draw_circle(Vector2(hx + 1.8, hy), 2.2, color)
		draw_colored_polygon(PackedVector2Array([
			Vector2(hx - 3.6, hy + 1.4), Vector2(hx + 3.6, hy + 1.4), Vector2(hx, hy + 5.2),
		]), color)

	# 闪光星点
	for index in 6:
		var t := fmod(_t * 0.7 + _seeds[index % _seeds.size()], 1.0)
		var angle := TAU * float(index) / 6.0 + _t * 0.6
		var radius := 16.0 + t * 10.0
		var pos := Vector2(cos(angle), sin(angle) * 0.55) * radius
		var alpha := (1.0 - t) * fade * 0.9
		draw_rect(Rect2(roundf(pos.x), roundf(pos.y - 12.0), 2.0, 2.0),
			Color(1.0, 0.95, 0.75, alpha))
