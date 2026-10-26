class_name FestivalFx
extends Node2D
## 节日场景特效：彩带飘落、烟花绽放、聚光灯扫动、奖杯升起。

const DURATION := 4.0

var _t := 0.0
var _confetti: Array[Dictionary] = []


func setup(world_position: Vector2) -> void:
	position = world_position
	z_as_relative = false
	z_index = 24
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var colors := [
		Color("#d9534f"), Color("#e8b45a"), Color("#5fae7a"),
		Color("#7a8fc9"), Color("#c47b9c"), Color("#f2ead8"),
	]
	for index in 26:
		_confetti.append({
			"x": rng.randf_range(-90.0, 90.0),
			"y": rng.randf_range(-70.0, -30.0),
			"vy": rng.randf_range(26.0, 58.0),
			"sway": rng.randf_range(0.6, 2.2),
			"phase": rng.randf() * TAU,
			"color": colors[index % colors.size()],
			"size": Vector2(rng.randf_range(1.5, 2.5), rng.randf_range(1.0, 2.0)),
		})
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _t >= DURATION:
		queue_free()


func _draw() -> void:
	var fade := clampf(1.0 - (_t - DURATION + 1.0), 0.0, 1.0)

	# 聚光灯：两道扇形光柱左右扫动
	for index in 2:
		var sweep := sin(_t * 0.9 + float(index) * PI) * 40.0
		var base_x := -70.0 + float(index) * 140.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(base_x, -96.0),
			Vector2(base_x + sweep - 22.0, 6.0),
			Vector2(base_x + sweep + 22.0, 6.0),
		]), Color(1.0, 0.95, 0.74, 0.10 * fade))

	# 烟花：每 0.6 秒一发，8 向炸开
	var burst := fmod(_t, 0.6) / 0.6
	if burst < 1.0:
		var center := Vector2(
			sin(floor(_t / 0.6) * 2.4) * 60.0,
			-80.0 - floor(_t / 0.6) % 2 * 14.0)
		for index in 8:
			var angle := TAU * float(index) / 8.0
			var radius := 6.0 + burst * 26.0
			var pos := center + Vector2(cos(angle), sin(angle)) * radius
			draw_rect(Rect2(roundf(pos.x), roundf(pos.y), 2.0, 2.0),
				Color(1.0, 0.88, 0.55, (1.0 - burst) * 0.9 * fade))

	# 彩带
	for chip: Dictionary in _confetti:
		var y: float = float(chip["y"]) + float(chip["vy"]) * _t
		if y > 14.0:
			y = fmod(y + 84.0, 84.0) - 70.0
		var x: float = float(chip["x"]) + sin(_t * float(chip["sway"])
			+ float(chip["phase"])) * 10.0
		var size: Vector2 = chip["size"]
		var color: Color = chip["color"]
		draw_rect(Rect2(roundf(x), roundf(y), size.x, size.y),
			Color(color.r, color.g, color.b, 0.9 * fade))

	# 奖杯：从中央升起
	if _t > 0.4:
		var rise := clampf((_t - 0.4) / 0.8, 0.0, 1.0)
		var trophy_y := -10.0 - rise * 26.0
		var gold := Color("#e8c24a")
		draw_rect(Rect2(-5.0, trophy_y, 10.0, 7.0), gold, true)
		draw_rect(Rect2(-7.0, trophy_y + 1.0, 2.0, 4.0), gold, true)
		draw_rect(Rect2(5.0, trophy_y + 1.0, 2.0, 4.0), gold, true)
		draw_rect(Rect2(-1.5, trophy_y + 7.0, 3.0, 2.0), gold.darkened(0.15), true)
		draw_rect(Rect2(-3.0, trophy_y + 9.0, 6.0, 1.5), gold.darkened(0.2), true)
