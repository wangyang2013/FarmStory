class_name GroundItem
extends Node2D
## 地上的掉落物：图标上下浮动 2px + 软阴影，玩家靠近自动拾取。
## 背包满时留在原地，腾出空间后可再次拾取。

const PixelTheme := preload("res://scripts/ui/PixelTheme.gd")

const PICKUP_RADIUS := 22.0

var farm
var item: Dictionary = {}

var _t := 0.0
var _base_y := 0.0
var _icon: Texture2D


func setup(p_farm: Node, p_item: Dictionary, world_position: Vector2) -> void:
	farm = p_farm
	item = p_item.duplicate(true)
	position = world_position
	_base_y = world_position.y
	_icon = PixelTheme.item_icon(
		str(item.get("item_id", "")), str(item.get("category", "")))
	_t = randf() * TAU
	z_index = 6
	add_to_group("ground_items")
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	# 上下浮动 2px，周期 1.5 秒（规范）
	position.y = _base_y + sin(_t * TAU / 1.5) * 2.0
	queue_redraw()
	if farm == null or farm.player == null:
		return
	# 设计规范：骑乘时默认禁止采集 / 拾取
	if farm.player.riding:
		return
	if position.distance_to(farm.player.position) <= PICKUP_RADIUS:
		try_pickup()


## 返回是否成功拾取；背包满时保持原地。
func try_pickup() -> bool:
	if farm == null or item.is_empty():
		return false
	if not farm.inventory.can_add(item):
		return false
	farm.inventory.add_item(item)
	farm.ui.toast("拾取 %s" % str(item.get("name", item.get("item_id", ""))), "good")
	farm.ui.refresh_hud()
	item.clear()
	queue_free()
	return true


func _draw() -> void:
	# 软阴影（深紫蓝）
	draw_set_transform(Vector2(0.0, 1.5), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 5.0, Color(0.24, 0.21, 0.34, 0.16))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if _icon != null:
		draw_texture_rect(_icon, Rect2(-8.0, -17.0, 16.0, 16.0), false)
