class_name VillageNPC
extends Node2D
## 村民：固定外观、日程站位、好感、生日与地图标记。

const Art := preload("res://scripts/art/PixelArt.gd")

var npc_id := ""
var display_name := ""
var role := ""
var data: Dictionary = {}
var look: Dictionary = {}
var friendship := 0
var talked_today := false
var gifted_today := false
var birthday_today := false
var festival_mode := false
var map_entity: MapEntity

## 日程站姿点（广场待机位）与当前移动目标。
var spot_position := Vector2.ZERO
var schedule_target := Vector2.INF
var walk_speed := 26.0

var _heart_timer := 0.0
var _phase := 0.0
var _walk_phase := 0.0
var _facing := "down"
var _moving := false
var working := false
var _work_phase := 0.0
var _wave_timer := 0.0
var _wave_cooldown := 0.0


## 日程工作姿态：工作时播放 4 帧动作。
func set_working(value: bool) -> void:
	working = value
	if not value:
		_work_phase = 0.0


func setup(p_data: Dictionary) -> void:
	data = p_data.duplicate(true)
	npc_id = str(data.get("id", ""))
	display_name = str(data.get("name", npc_id))
	role = str(data.get("role", ""))
	look = data.get("look", Art.default_look())
	var spot: Dictionary = data.get("spot", {"x": 17.0, "y": 11.4})
	position = Vector2(float(spot.get("x", 17.0)), float(spot.get("y", 11.4))) * 32.0
	spot_position = position
	schedule_target = position
	queue_redraw()


## 设置下一个日程目标；NPC 会在 _process 中逐点走过去。
func set_schedule_target(target: Vector2, speed := -1.0) -> void:
	schedule_target = target
	if speed > 0.0:
		walk_speed = speed


func set_active(value: bool) -> void:
	visible = value
	if map_entity != null:
		map_entity.is_active = value
		map_entity.position = position


func set_birthday(value: bool) -> void:
	if birthday_today != value:
		birthday_today = value
		queue_redraw()


## 节日变装：戴彩色三角帽，服饰换成本角色的撞色。
func set_festival_mode(value: bool) -> void:
	if festival_mode == value:
		return
	festival_mode = value
	if value:
		var palette := ["#d9534f", "#e8b45a", "#5fae7a", "#7a8fc9", "#c47b9c"]
		var index := absi(npc_id.hash()) % palette.size()
		look = look.duplicate(true)
		look["outfit_color"] = palette[index]
	else:
		look = data.get("look", Art.default_look())
	queue_redraw()


func add_friendship(delta: int) -> void:
	friendship = clampi(friendship + delta, 0, 250)
	if delta > 0:
		celebrate()


func celebrate() -> void:
	_heart_timer = 1.6
	queue_redraw()


func friendship_level() -> String:
	if friendship >= 200:
		return "可求婚"
	if friendship >= 100:
		return "挚友"
	if friendship >= 60:
		return "好友"
	if friendship >= 30:
		return "朋友"
	return "陌生"


func _process(delta: float) -> void:
	_phase += delta
	if _heart_timer > 0.0:
		_heart_timer = maxf(0.0, _heart_timer - delta)
	if working and not _moving:
		_work_phase += delta * 5.0
	# 玩家靠近 48px：招手 4 帧，冷却 5 秒
	_wave_cooldown = maxf(0.0, _wave_cooldown - delta)
	if _wave_timer > 0.0:
		_wave_timer = maxf(0.0, _wave_timer - delta)
	elif visible and _wave_cooldown <= 0.0:
		var player := get_tree().get_first_node_in_group("player")
		if player is Node2D and position.distance_to((player as Node2D).position) <= 48.0:
			_wave_timer = 1.0
			_wave_cooldown = 5.0
	if visible and schedule_target != Vector2.INF:
		var to_target := schedule_target - position
		var distance := to_target.length()
		if distance > 2.0:
			var step := minf(walk_speed * delta, distance)
			position += to_target / distance * step
			_moving = true
			_walk_phase += delta * 6.0
			if absf(to_target.x) > absf(to_target.y):
				_facing = "right" if to_target.x > 0.0 else "left"
			else:
				_facing = "down" if to_target.y > 0.0 else "up"
			if map_entity != null:
				map_entity.position = position
		elif _moving:
			_moving = false
	queue_redraw()


## 工作姿态：4 帧交替抬手/落手，像在敲打或整理货物。
func _draw_work_pose() -> void:
	var frame := int(_work_phase) % 4
	var lifts: Array[float] = [0.0, -3.0, -5.0, -2.0]
	var lift: float = lifts[frame]
	var hand := Color("#f2d7bd")
	var outfit := Color(str(look.get("outfit_color", "#7f9cb8")))
	# 右侧手臂
	draw_rect(Rect2(5.0, -20.0 + lift, 2.0, 4.0), outfit, true)
	draw_rect(Rect2(5.0, -16.0 + lift, 2.0, 2.0), hand, true)
	# 工具/动作提示：小像素点随帧闪动
	if frame == 2:
		draw_rect(Rect2(7.5, -18.0 + lift, 2.0, 1.0), Color("#d8bd84"), true)


## 招手姿态：4 帧抬手挥动。
func _draw_wave_pose() -> void:
	var frame := int((1.0 - _wave_timer) * 8.0) % 4
	var offsets: Array[Vector2] = [
		Vector2(4, -22), Vector2(6, -24), Vector2(4, -22), Vector2(2, -21),
	]
	var hand: Vector2 = offsets[frame]
	draw_rect(Rect2(hand, Vector2(2, 2)), Color("#f2d7bd"), true)
	draw_rect(Rect2(hand + Vector2(0, 2), Vector2(2, 2)), Color("#e8c6a4"), true)


func _draw() -> void:
	if not visible:
		return
	Art.draw_character(
		self, look, _facing,
		_walk_phase if _moving else _phase * 1.6,
		_moving
	)
	if working and not _moving:
		_draw_work_pose()
	if _wave_timer > 0.0:
		_draw_wave_pose()
	if festival_mode:
		# 节日三角帽
		draw_colored_polygon(PackedVector2Array([
			Vector2(-5, -33), Vector2(0, -43), Vector2(5, -33),
		]), Color("#d9534f"))
		draw_rect(Rect2(-5, -34, 10, 1.5), Color("#f2e8d4"), true)
		draw_rect(Rect2(-1, -42, 2, 2), Color("#f2e8d4"), true)
	if birthday_today:
		# 生日小蛋糕
		draw_rect(Rect2(-4, -43, 8, 5), Color("#f3d98e"), true)
		draw_rect(Rect2(-5, -44, 10, 1), Color("#fdf5e6"), true)
		draw_rect(Rect2(-1, -47, 1, 3), Color("#c4553f"), true)
		draw_rect(Rect2(1, -47, 1, 3), Color("#c4553f"), true)
	if _heart_timer > 0.0:
		var bob := sin((1.6 - _heart_timer) * 5.0) * 1.5
		var y := -39.0 - bob
		draw_rect(Rect2(-4, y, 2, 2), Color("#d98a9a"), true)
		draw_rect(Rect2(2, y, 2, 2), Color("#d98a9a"), true)
		draw_rect(Rect2(-2, y + 1, 1, 1), Color("#d98a9a"), true)
		draw_rect(Rect2(1, y + 1, 1, 1), Color("#d98a9a"), true)
		draw_rect(Rect2(-1, y + 2, 2, 1), Color("#d98a9a"), true)
