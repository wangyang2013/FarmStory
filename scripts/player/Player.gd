class_name Player
extends CharacterBody2D
## 玩家：WASD / 方向键移动，四方向朝向，体力管理。
##
## 具体动作（锄地/浇水/播种/收获/钓鱼）由 Farm 决定，Player 只负责移动与体力。
## 数值来自 config/gameplay.json；外观来自存档的 player_appearance。
##
## 美术：Q 版小头身，16px 像素单位绘制，暖调低饱和，无粗黑描边。

signal stamina_changed(current: float, maximum: float)
signal exhausted
signal health_changed(current: int, maximum: int)
signal fainted

const DB := preload("res://scripts/core/ConfigDB.gd")
const Art := preload("res://scripts/art/PixelArt.gd")

const TILE := 32

var speed := 140.0
var run_multiplier := 1.6
var stamina := 100.0
var stamina_max := 100.0
var hp := 100
var max_hp := 100
var attack_power := 10
var defense := 0
var invincible_seconds := 1.0
var invincible_timer := 0.0
var _hit_flash := 0.0
var facing := "down"
## 地图点击寻路的扩展接口目标。
var navigation_target := Vector2.ZERO
## A* 路径点（世界坐标）；非空时自动行走。
var nav_path := PackedVector2Array()
var _nav_index := 0
var input_locked := false
var look: Dictionary = Art.default_look()

var _walk_phase := 0.0
var _moving := false

# 钓鱼动作：抛竿 → 浮漂停在水面 → 收竿
var fishing_pose := false
var fishing_target := Vector2.ZERO
var _fishing_time := 0.0
var _catch_effect := 0.0
var _catch_from := Vector2.ZERO

# 工具动作：4 帧挥动 + 动作锁定
var action_kind := ""
var action_timer := 0.0
var action_duration := 0.26
var action_direction := Vector2.DOWN

# 坐下：2 帧（规范：坐下 2 帧）
var sitting := false
var _sit_time := 0.0

# 骑乘：由 Farm 控制上下坐骑与耐力，Player 只负责移动速度和骑乘姿势。
var riding := false
var ride_speed := 200.0
var ride_sprint_speed := 280.0
var ride_sprinting := false
var ride_sprint_blocked := false
## 骑手相对坐骑的抬升（16px 逻辑单位），由坐骑配置决定。
var ride_rider_offset := -13.5


func _ready() -> void:
	add_to_group("player")
	var config := DB.get_player_config()
	speed = float(config.get("speed", 140.0))
	run_multiplier = float(config.get("run_multiplier", 1.6))
	stamina_max = float(config.get("stamina_max", 100.0))
	stamina = clampf(float(config.get("start_stamina", stamina_max)), 0.0, stamina_max)
	var combat := DB.get_combat_player()
	max_hp = int(combat.get("max_hp", 100))
	hp = max_hp
	attack_power = int(combat.get("attack", 10))
	defense = int(combat.get("defense", 0))
	invincible_seconds = float(combat.get("invincible_seconds", 1.0))
	_build_collision()
	stamina_changed.emit(stamina, stamina_max)
	health_changed.emit(hp, max_hp)
	queue_redraw()


func _process(delta: float) -> void:
	if invincible_timer > 0.0:
		invincible_timer = maxf(0.0, invincible_timer - delta)
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		modulate = Color(1, 0.55, 0.55) if fmod(_hit_flash, 0.16) > 0.08 else Color.WHITE
	elif modulate != Color.WHITE:
		modulate = Color.WHITE
	if fishing_pose:
		_fishing_time += delta
		queue_redraw()
	if _catch_effect > 0.0:
		_catch_effect = maxf(0.0, _catch_effect - delta)
		queue_redraw()
	# 工具挥动：动作期间锁定移动，遵循《动画效果清单》4 帧挥动。
	if action_timer > 0.0:
		action_timer = maxf(0.0, action_timer - delta)
		queue_redraw()
		if action_timer <= 0.0:
			action_kind = ""


## 播放工具动作（锄头 / 水壶 / 斧头 / 镐 / 种子）。
## 返回动作时长，供调用方决定何时生效。
func play_tool_action(kind: String, direction: Vector2, duration := 0.26) -> float:
	action_kind = kind
	action_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.DOWN
	action_duration = maxf(0.12, duration)
	action_timer = action_duration
	if absf(action_direction.x) > absf(action_direction.y):
		facing = "right" if action_direction.x > 0.0 else "left"
	else:
		facing = "down" if action_direction.y > 0.0 else "up"
	queue_redraw()
	return action_duration


func is_action_locked() -> bool:
	return action_timer > 0.0


func is_moving() -> bool:
	return _moving


## 坐下 / 起身（2 帧呼吸姿态）。
func set_sitting(value: bool) -> void:
	if sitting == value:
		return
	sitting = value
	_sit_time = 0.0
	queue_redraw()


## 上 / 下坐骑：骑乘时隐藏腿、改用坐骑速度（不消耗玩家体力）。
func set_riding(value: bool, normal_speed := 200.0, sprint_speed := 280.0,
		rider_offset := -13.5) -> void:
	riding = value
	ride_speed = normal_speed
	ride_sprint_speed = sprint_speed
	ride_rider_offset = rider_offset
	ride_sprinting = false
	ride_sprint_blocked = false
	velocity = Vector2.ZERO
	action_kind = ""
	action_timer = 0.0
	fishing_pose = false
	set_sitting(false)
	queue_redraw()


## 疲劳度：体力 <20% 移速 -20%，<10%（重伤）移速再降。
func stamina_speed_multiplier() -> float:
	var ratio := stamina / maxf(1.0, stamina_max)
	if ratio < 0.10:
		return 0.6
	if ratio < 0.20:
		return 0.8
	return 1.0


## 开始钓鱼动作：面向水面，浮漂抛向 target_world。
func start_fishing_animation(target_world: Vector2) -> void:
	fishing_pose = true
	fishing_target = target_world
	_fishing_time = 0.0
	var offset := target_world - position
	if absf(offset.x) > absf(offset.y):
		facing = "right" if offset.x > 0.0 else "left"
	else:
		facing = "down" if offset.y > 0.0 else "up"
	queue_redraw()


func stop_fishing_animation() -> void:
	if not fishing_pose:
		return
	fishing_pose = false
	queue_redraw()


## 钓到鱼：水花 + 鱼跃向玩家。
func play_fish_catch_effect(from_world: Vector2) -> void:
	_catch_from = to_local(from_world)
	_catch_effect = 0.6
	queue_redraw()


func take_damage(amount: int) -> void:
	if invincible_timer > 0.0 or hp <= 0:
		return
	var damage := maxi(1, amount - defense)
	hp = maxi(0, hp - damage)
	invincible_timer = invincible_seconds
	_hit_flash = 0.35
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		fainted.emit()


func restore_health(ratio := 1.0) -> void:
	hp = clampi(int(round(float(max_hp) * ratio)), 0, max_hp)
	invincible_timer = 0.0
	_hit_flash = 0.0
	modulate = Color.WHITE
	health_changed.emit(hp, max_hp)


## 地图箭头朝向：默认朝上为 0 弧度，顺时针。供大地图/小地图旋转箭头使用。
func get_facing_angle() -> float:
	match facing:
		"right":
			return PI * 0.5
		"down":
			return PI
		"left":
			return -PI * 0.5
		_:
			return 0.0


## 点击寻路的扩展接口：等 NPC/寻路系统落地后接入 NavigationAgent2D。
func set_navigation_target(target_pos: Vector2) -> void:
	navigation_target = target_pos


## 由 Farm.navigate_to() 设置 A* 路径点（世界坐标）。
func set_navigation_path(points: PackedVector2Array) -> void:
	nav_path = points
	_nav_index = 0


func set_look(new_look: Dictionary) -> void:
	look = Art.normalize_look(new_look)
	queue_redraw()


func _build_collision() -> void:
	if get_node_or_null("Body") != null:
		return
	var shape := CollisionShape2D.new()
	shape.name = "Body"
	var rect := RectangleShape2D.new()
	rect.size = Vector2(18, 14)
	shape.shape = rect
	shape.position = Vector2(0, 6)
	add_child(shape)
	collision_layer = 1
	collision_mask = 1


func _physics_process(delta: float) -> void:
	if input_locked:
		velocity = Vector2.ZERO
		_moving = false
		move_and_slide()
		queue_redraw()
		return

	# 只用 Input Map 的动作名，不直接读按键（方便以后改键）。
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var running := Input.is_action_pressed("run")

	# 点击寻路：手动输入优先，按下方向键会取消自动行走。
	if direction != Vector2.ZERO:
		nav_path.clear()
		_nav_index = 0
	elif not nav_path.is_empty():
		direction = _advance_navigation()
		running = false

	if riding:
		_update_riding_movement(direction, delta)
		move_and_slide()
		queue_redraw()
		return

	if direction != Vector2.ZERO:
		direction = direction.normalized()
		# 跑步只加速移动，不加速游戏时间（游戏时间对照表）。
		# 疲劳（<20% 体力）移速 -20%，重伤（<10%）进一步放慢。
		var current_speed := speed * (run_multiplier if running else 1.0) \
			* stamina_speed_multiplier()
		velocity = direction * current_speed
		if absf(direction.x) > absf(direction.y):
			facing = "right" if direction.x > 0.0 else "left"
		else:
			facing = "down" if direction.y > 0.0 else "up"
		_moving = true
		# 4 帧循环：走路约 8 帧/秒，跑步约 12 帧/秒
		_walk_phase += delta * (12.0 if running else 8.0)
	else:
		velocity = Vector2.ZERO
		_moving = false
		_walk_phase += delta * 2.0

	# 工具动作期间锁定移动
	if action_timer > 0.0:
		velocity = Vector2.ZERO
		_moving = false
	# 坐着时不能移动
	if sitting:
		velocity = Vector2.ZERO
		_moving = false
		_sit_time += delta

	move_and_slide()
	queue_redraw()


## 骑乘移动：Shift 冲刺，速度来自坐骑配置；不经过玩家体力衰减。
func _update_riding_movement(direction: Vector2, delta: float) -> void:
	ride_sprinting = false
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		ride_sprinting = Input.is_action_pressed("run") and not ride_sprint_blocked
		var current_speed := ride_sprint_speed if ride_sprinting else ride_speed
		velocity = direction * current_speed
		if absf(direction.x) > absf(direction.y):
			facing = "right" if direction.x > 0.0 else "left"
		else:
			facing = "down" if direction.y > 0.0 else "up"
		_moving = true
		_walk_phase += delta * (14.0 if ride_sprinting else 9.0)
	else:
		velocity = Vector2.ZERO
		_moving = false
		_walk_phase += delta * 2.0


func _advance_navigation() -> Vector2:
	while _nav_index < nav_path.size():
		var target := nav_path[_nav_index]
		var to_target := target - position
		if to_target.length() > 6.0:
			return to_target.normalized()
		_nav_index += 1
	nav_path.clear()
	_nav_index = 0
	return Vector2.ZERO


# ============================================================
# 体力
# ============================================================

func has_stamina(amount: float) -> bool:
	return stamina >= amount


func spend_stamina(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if stamina < amount:
		return false
	stamina = maxf(0.0, stamina - amount)
	stamina_changed.emit(stamina, stamina_max)
	if stamina <= 0.0:
		exhausted.emit()
	return true


func restore_stamina(ratio: float) -> void:
	stamina = clampf(stamina_max * ratio, 0.0, stamina_max)
	stamina_changed.emit(stamina, stamina_max)


func restore_stamina_amount(amount: float) -> void:
	stamina = clampf(stamina + amount, 0.0, stamina_max)
	stamina_changed.emit(stamina, stamina_max)


# ============================================================
# 朝向 / 交互点
# ============================================================

func get_facing_vector() -> Vector2:
	match facing:
		"up":
			return Vector2.UP
		"down":
			return Vector2.DOWN
		"left":
			return Vector2.LEFT
		_:
			return Vector2.RIGHT


func get_tile_position() -> Vector2i:
	return Vector2i(floori(position.x / TILE), floori(position.y / TILE))


func get_facing_tile() -> Vector2i:
	return get_tile_position() + Vector2i(get_facing_vector())


func to_save() -> Dictionary:
	return {
		"x": position.x,
		"y": position.y,
		"facing": facing,
		"stamina": stamina,
		"max_stamina": stamina_max,
		"hp": hp,
		"max_hp": max_hp,
		"look": look.duplicate(true),
	}


func from_save(data: Dictionary) -> void:
	position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	max_hp = int(data.get("max_hp", max_hp))
	hp = clampi(int(data.get("hp", max_hp)), 0, max_hp)
	health_changed.emit(hp, max_hp)
	var saved_facing := str(data.get("facing", "down"))
	facing = saved_facing if saved_facing in ["up", "down", "left", "right"] else "down"
	stamina_max = maxf(1.0, float(data.get("max_stamina", stamina_max)))
	stamina = clampf(float(data.get("stamina", stamina_max)), 0.0, stamina_max)
	if data.has("look") and data["look"] is Dictionary:
		set_look(data["look"])
	stamina_changed.emit(stamina, stamina_max)
	queue_redraw()


# ============================================================
# 绘制（16px 像素单位）
# ============================================================

func _draw() -> void:
	if riding:
		# 骑乘姿势：整体抬高到坐骑背上，隐藏腿与独立阴影（坐骑自带）。
		Art.draw_character(self, look, facing, _walk_phase, _moving,
			Vector2(0.0, ride_rider_offset), 1.0, true)
		return
	if sitting:
		_draw_sitting()
		return
	Art.draw_character(self, look, facing, _walk_phase, _moving)
	if action_timer > 0.0:
		_draw_tool_action()
	if fishing_pose:
		_draw_fishing()
	if _catch_effect > 0.0:
		_draw_catch_effect()


## 工具挥动：4 帧（抬手 → 下挥 → 触地 → 回正）。
func _draw_tool_action() -> void:
	var progress := clampf(1.0 - action_timer / maxf(0.01, action_duration), 0.0, 1.0)
	var frame := clampi(int(progress * 4.0), 0, 3)
	# 各帧相对朝向的挥动角度（弧度）
	var angles: Array[float] = [-0.9, 0.15, 0.85, 0.35]
	var angle: float = angles[frame]
	var base_angle: float = action_direction.angle()
	var hand := action_direction * 5.0 + Vector2(0.0, -18.0)
	var tool_len := 11.0
	var tip := hand + Vector2(cos(base_angle + angle), sin(base_angle + angle)) * tool_len

	# 挥动残影（第 1~2 帧）
	if frame == 1 or frame == 2:
		draw_arc(hand, tool_len, base_angle + angle - 0.8, base_angle + angle,
			8, Color(1.0, 0.97, 0.86, 0.30), 1.0, false)

	var wood := Color("#8c6a4a")
	var metal := Color("#b9c1c4")
	draw_line(hand, tip, wood, 1.6, false)
	draw_line(hand, tip, Color("#c9a276"), 0.7, false)
	match action_kind:
		"water":
			draw_rect(Rect2(tip - Vector2(3, 2), Vector2(6, 5)), Color("#9fb4c0"), true)
			draw_rect(Rect2(tip - Vector2(3, 2), Vector2(6, 1.4)), Color("#b8cbd4"), true)
			draw_line(tip + Vector2(3, 1), tip + Vector2(5, 3), Color("#8ca6b3"), 1.0, false)
		"axe":
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-1, -2), tip + Vector2(4, -3), tip + Vector2(4, 3),
				tip + Vector2(-1, 2),
			]), metal)
		"pick":
			draw_line(tip + Vector2(-4, -3), tip + Vector2(4, -3), metal, 1.6, false)
			draw_line(tip + Vector2(-4, -3), tip + Vector2(-4, 0), metal, 1.2, false)
			draw_line(tip + Vector2(4, -3), tip + Vector2(4, 0), metal, 1.2, false)
		"seed":
			draw_rect(Rect2(tip - Vector2(2, 2), Vector2(4, 4)), Color("#eadfc6"), true)
			draw_rect(Rect2(tip - Vector2(2, 1), Vector2(4, 1.4)), Color("#8fae75"), true)
		_:
			# 锄头
			draw_rect(Rect2(tip - Vector2(1, 5), Vector2(2, 5)), wood, true)
			draw_colored_polygon(PackedVector2Array([
				tip + Vector2(-1, 4), tip + Vector2(6, 4), tip + Vector2(5, 6),
				tip + Vector2(-1, 6),
			]), metal)


## 坐下：2 帧（身体下沉、腿收起），带 1px 呼吸。
func _draw_sitting() -> void:
	var frame := int(_sit_time * 2.0) % 2
	var bob := 1.0 if frame == 1 else 0.0
	var sitting_look := look.duplicate(true)
	# 坐姿：整体下移 2px，脚收起（用腿部贴图的偏移模拟）
	Art.draw_character(self, sitting_look, "down", 0.0, false,
		Vector2(0.0, 2.0 + bob * 0.5))
	# 收起的腿（在身体下方画一小段）
	var pants := Color("#8b8076")
	Art.rect(self, -2.8, -1.0 + bob * 0.5, 5.6, 1.4, pants)
	Art.rect(self, -3.1, -0.4 + bob * 0.5, 2.7, 1.0, Color("#7c6a54"))
	Art.rect(self, 0.4, -0.4 + bob * 0.5, 2.7, 1.0, Color("#7c6a54"))
func _draw_fishing() -> void:
	var hand := Vector2(8.0, -20.0)
	var rod_tip := Vector2(20.0, -34.0)
	match facing:
		"right":
			hand = Vector2(9.0, -20.0)
			rod_tip = Vector2(22.0, -36.0)
		"left":
			hand = Vector2(-9.0, -20.0)
			rod_tip = Vector2(-22.0, -36.0)
		"up":
			hand = Vector2(5.0, -24.0)
			rod_tip = Vector2(5.0, -48.0)
		_:
			hand = Vector2(8.0, -18.0)
			rod_tip = Vector2(20.0, -36.0)

	# 鱼竿：始终斜向上举，鱼线再从竿梢垂到水面浮漂。
	draw_line(hand, rod_tip, Color("#5a3f2a"), 2.0, false)
	draw_line(hand, rod_tip, Color("#d8b48a"), 1.0, false)

	# 浮漂：0.55 秒抛物线飞出，之后漂浮 + 抖动
	var local_target := to_local(fishing_target)
	var cast := clampf(_fishing_time / 0.55, 0.0, 1.0)
	var bobber := hand.lerp(local_target, cast)
	bobber.y -= sin(cast * PI) * 18.0
	if cast >= 1.0:
		bobber.y += sin(_fishing_time * 3.2) * 2.0
	draw_line(rod_tip, bobber, Color(0.96, 0.95, 0.86, 0.9), 1.0, false)
	draw_circle(bobber, 2.2, Color("#d9534f"))
	draw_rect(Rect2(bobber + Vector2(-1.6, -3.6), Vector2(3.2, 1.6)), Color("#f2ead8"))

	# 入水涟漪
	var splash_t := _fishing_time - 0.55
	if splash_t >= 0.0 and splash_t < 0.45:
		var alpha := (1.0 - splash_t / 0.45) * 0.6
		draw_arc(bobber, 3.0 + splash_t * 12.0, 0.0, TAU, 12,
			Color(0.85, 0.95, 0.95, alpha), 1.0, false)


func _draw_catch_effect() -> void:
	var t := 1.0 - clampf(_catch_effect / 0.6, 0.0, 1.0)
	# 水面涟漪
	if t < 0.6:
		var alpha := (0.6 - t) * 0.9
		draw_arc(_catch_from, 3.0 + t * 18.0, 0.0, TAU, 12,
			Color(0.85, 0.95, 0.95, alpha), 1.0, false)
	# 鱼从水面跃向玩家
	var pos := _catch_from.lerp(Vector2(0.0, -18.0), t)
	pos.y -= sin(t * PI) * 28.0
	draw_set_transform(pos, sin(t * 8.0) * 0.4, Vector2.ONE)
	draw_circle(Vector2.ZERO, 4.0, Color("#8fadc0"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-4.0, 0.0), Vector2(-8.0, -3.0), Vector2(-8.0, 3.0),
	]), Color("#7d9cb4"))
	draw_circle(Vector2(1.5, -1.0), 0.8, Color(0.1, 0.15, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
