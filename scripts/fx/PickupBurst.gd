class_name PickupBurst
extends Node2D
## 收获 / 采矿 / 钓鱼的拾取动画：物品浮现 → 飞向玩家 → 淡出。

const PixelTheme := preload("res://scripts/ui/PixelTheme.gd")

const DURATION := 0.55

var _icon: Texture2D
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _t := 0.0
var _phase := 0.0


func setup(item_id: String, category: String, from_world: Vector2, to_world: Vector2) -> void:
	_icon = PixelTheme.item_icon(item_id, category)
	_from = from_world
	_to = to_world
	position = from_world
	_phase = randf() * TAU
	z_index = 40
	add_to_group("pickup_fx")
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var fly := clampf((k - 0.35) / 0.65, 0.0, 1.0)
	position = _from.lerp(_to, ease(fly, 2.0))
	# 前 0.35 秒上下浮动 2px，随后被吸向玩家。
	position.y += sin(_t * 9.0 + _phase) * 2.0 * (1.0 - fly)
	modulate.a = 1.0 - clampf((k - 0.75) / 0.25, 0.0, 1.0)
	queue_redraw()
	if k >= 1.0:
		queue_free()


func _draw() -> void:
	if _icon == null:
		return
	# 软阴影（深紫蓝，贴合底部）
	draw_set_transform(Vector2(0.0, 3.0), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 4.0, Color(0.24, 0.21, 0.34, 0.16))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_texture_rect(_icon, Rect2(-8.0, -16.0, 16.0, 16.0), false)
