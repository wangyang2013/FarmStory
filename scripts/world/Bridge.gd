class_name Bridge
extends Node2D
## 木桥：横跨河道，桥面低于角色与建筑，高于水面。

var span := Vector2(128.0, 64.0)


func setup(rect: Rect2) -> void:
	position = rect.position
	span = rect.size
	z_index = -1
	queue_redraw()


func _draw() -> void:
	# 桥面木板：横向板 + 深色板缝
	draw_rect(Rect2(Vector2.ZERO, span), Color("#a9825c"), true)
	var row_y := 0.0
	while row_y < span.y:
		draw_rect(Rect2(0.0, row_y, span.x, 5.0), Color("#b89268"), true)
		draw_rect(Rect2(0.0, row_y + 5.0, span.x, 1.0), Color("#7d5a3c"), true)
		row_y += 8.0
	# 两侧栏杆
	draw_rect(Rect2(0.0, 0.0, span.x, 3.0), Color("#5f4326"), true)
	draw_rect(Rect2(0.0, span.y - 3.0, span.x, 3.0), Color("#5f4326"), true)
	var post_x := 2.0
	while post_x < span.x:
		draw_rect(Rect2(post_x, -2.0, 4.0, 7.0), Color("#6b4a2f"), true)
		draw_rect(Rect2(post_x, span.y - 5.0, 4.0, 7.0), Color("#6b4a2f"), true)
		post_x += 24.0
