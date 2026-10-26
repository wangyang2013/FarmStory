class_name FruitDrop
extends Node2D
## 摇树果实掉落：从树冠落到地面（带回弹），再飞向玩家。

const FALL_TIME := 0.45
const FLY_TIME := 0.45

var target_position := Vector2.ZERO
var color := Color("#d05a5a")

var _t := 0.0
var _from := Vector2.ZERO
var _ground := Vector2.ZERO


func setup(canopy_world: Vector2, ground_world: Vector2, player_world: Vector2,
		fruit_color: Color) -> void:
	_from = canopy_world
	_ground = ground_world
	target_position = player_world + Vector2(0, -20)
	color = fruit_color
	position = canopy_world
	z_index = 30
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	var fall := clampf(_t / FALL_TIME, 0.0, 1.0)
	if fall < 1.0:
		# 下落带轻微左右摇摆
		position = _from.lerp(_ground, fall * fall)
		position.x += sin(_t * 12.0) * 1.5 * (1.0 - fall)
	else:
		var fly := clampf((_t - FALL_TIME) / FLY_TIME, 0.0, 1.0)
		position = _ground.lerp(target_position, ease(fly, 2.0))
		modulate.a = 1.0 - clampf((fly - 0.7) / 0.3, 0.0, 1.0)
		if fly >= 1.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	# 果实：主色 + 暖色高光（落地前带一点压扁）
	var squash := 1.0
	if _t > FALL_TIME and _t < FALL_TIME + 0.1:
		squash = 0.7
	draw_circle(Vector2(0, -3.0 * squash), 3.4, color)
	draw_circle(Vector2(-1.0, -4.0 * squash), 1.4, color.lightened(0.25))
	draw_rect(Rect2(-0.5, -7.0 * squash, 1.0, 2.0), Color("#6f8f58"), true)
