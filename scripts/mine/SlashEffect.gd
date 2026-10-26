extends Node2D
## 剑挥砍的白色弧光，短暂显示后回收（有对象池时）或销毁。

var pool: ObjectPool
var _life := 0.16
var _max_life := 0.16


func setup(world_position: Vector2, angle: float) -> void:
	position = world_position
	rotation = angle
	z_index = 20
	_life = _max_life
	queue_redraw()


func _process(delta: float) -> void:
	_life -= delta
	queue_redraw()
	if _life > 0.0:
		return
	if pool != null:
		pool.release(self)
	else:
		queue_free()


func _draw() -> void:
	var alpha := clampf(_life / _max_life, 0.0, 1.0)
	draw_arc(Vector2.ZERO, 15.0, -0.7, 0.7, 8, Color(1.0, 0.97, 0.88, alpha), 2.0)
	draw_arc(Vector2.ZERO, 19.0, -0.5, 0.5, 6, Color(1.0, 0.97, 0.88, alpha * 0.55), 1.0)
