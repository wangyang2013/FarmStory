class_name WoodChips
extends Node2D
## 砍树木屑：8 块小碎木在重力作用下飞散、落地并淡出。

const LIFETIME := 0.7

var _t := 0.0
var _chips: Array[Dictionary] = []


func setup(world_position: Vector2, palette: Array = []) -> void:
	position = world_position
	z_index = 25
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var colors: Array = palette
	if colors.is_empty():
		colors = [Color("#a9825c"), Color("#8c6a4a"), Color("#c9a276")]
	for index in 9:
		_chips.append({
			"pos": Vector2(rng.randf_range(-4.0, 4.0), rng.randf_range(-14.0, -6.0)),
			"vel": Vector2(rng.randf_range(-42.0, 42.0), rng.randf_range(-58.0, -22.0)),
			"size": Vector2(rng.randf_range(1.5, 3.0), rng.randf_range(1.0, 2.0)),
			"color": colors[index % colors.size()],
		})
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	for chip: Dictionary in _chips:
		var vel: Vector2 = chip["vel"]
		vel.y += 220.0 * delta
		var pos: Vector2 = chip["pos"]
		pos += vel * delta
		if pos.y > 0.0:
			pos.y = 0.0
			vel = Vector2(vel.x * 0.4, 0.0)
		chip["vel"] = vel
		chip["pos"] = pos
	queue_redraw()
	if _t >= LIFETIME:
		queue_free()


func _draw() -> void:
	var alpha := clampf(1.0 - _t / LIFETIME, 0.0, 1.0)
	for chip: Dictionary in _chips:
		var pos: Vector2 = chip["pos"]
		var size: Vector2 = chip["size"]
		var color: Color = chip["color"]
		draw_rect(Rect2(roundf(pos.x), roundf(pos.y), size.x, size.y),
			Color(color.r, color.g, color.b, alpha))
