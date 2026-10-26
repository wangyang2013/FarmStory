class_name MineTrap
extends Node2D
## 矿洞陷阱：暗坑掉血 / 滑坡消耗体力；触发后失效。

const TILE := 32

var kind := "pit"
var triggered := false


func setup(trap_kind: String, cell: Vector2i) -> void:
	kind = trap_kind
	position = Vector2(cell) * TILE + Vector2(TILE * 0.5, TILE * 0.5)
	queue_redraw()


func trigger() -> void:
	if triggered:
		return
	triggered = true
	modulate = Color(1, 1, 1, 0.45)
	queue_redraw()


func _draw() -> void:
	if kind == "slide":
		draw_rect(Rect2(-12, -6, 24, 12), Color("#8a7350"), true)
		draw_rect(Rect2(-9, -3, 6, 2), Color("#c9ae83"), true)
		draw_rect(Rect2(0, 0, 7, 2), Color("#c9ae83"), true)
		draw_rect(Rect2(-4, 3, 5, 2), Color("#c9ae83"), true)
	else:
		draw_rect(Rect2(-12, -7, 24, 14), Color("#2f2a24"), true)
		draw_rect(Rect2(-10, -5, 20, 10), Color("#171411"), true)
		draw_rect(Rect2(-12, -7, 24, 2), Color("#6f6558"), true)
		draw_rect(Rect2(-12, 5, 24, 2), Color("#6f6558"), true)
