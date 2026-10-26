class_name Compass
extends Control
## HUD 指南针：替代原小地图，显示玩家当前朝向。

const UITheme := preload("res://scripts/ui/PixelTheme.gd")

var farm
var _facing := "down"


func setup(p_farm) -> void:
	farm = p_farm
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if farm != null and farm.player != null:
		_facing = str(farm.player.facing)
	queue_redraw()


func _process(_delta: float) -> void:
	if farm == null or farm.player == null:
		return
	var facing := str(farm.player.facing)
	if facing != _facing:
		_facing = facing
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#f6efdd"), true)
	draw_rect(Rect2(Vector2.ZERO, size), Color("#cbb692"), false, 1.0)
	var center := size * 0.5
	draw_arc(center, 14.0, 0.0, TAU, 24, Color("#8a7862"), 1.0, false)

	var font := UITheme.font()
	for item: Dictionary in [
		{"text": "北", "pos": Vector2(center.x - 6.0, 10.0)},
		{"text": "东", "pos": Vector2(size.x - 14.0, center.y + 4.0)},
		{"text": "南", "pos": Vector2(center.x - 6.0, size.y - 3.0)},
		{"text": "西", "pos": Vector2(3.0, center.y + 4.0)},
	]:
		var pos: Vector2 = item["pos"]
		draw_string(font, pos, str(item["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			UITheme.C_INK_SOFT)

	var angle := PI * 0.5
	match _facing:
		"up":
			angle = -PI * 0.5
		"left":
			angle = PI
		"right":
			angle = 0.0
		_:
			angle = PI * 0.5
	var tip := center + Vector2(cos(angle), sin(angle)) * 11.0
	var wing_a := center + Vector2(cos(angle + 2.5), sin(angle + 2.5)) * 4.0
	var wing_b := center + Vector2(cos(angle - 2.5), sin(angle - 2.5)) * 4.0
	draw_colored_polygon(PackedVector2Array([tip, wing_a, wing_b]), Color("#c4553f"))
	draw_circle(center, 1.8, Color("#5a4a38"))
