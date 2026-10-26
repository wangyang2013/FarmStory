class_name RideMount
extends Node2D
## 坐骑：马 / 牛 / 自行车。程序化像素绘制，骑乘时跟随玩家并显示耐力。
##
## 坐标以 16px 逻辑单位绘制（Art.* 内部 ×2），锚点在坐骑脚底中心。
## 骑乘时 z_index = -1，保证坐骑始终在骑手（Player）下方。

const Art := preload("res://scripts/art/PixelArt.gd")

var mount_type := "horse"
var mount_name := ""
var facing := "down"
var moving := false
var sprinting := false
var ridden := false
var fatigue := false
var stamina := 100.0
var max_stamina := 100.0
var cargo_capacity := 0
var cargo_used := 0
var follow_target: Player = null

var _phase := 0.0
var _t := 0.0


func setup(p_type: String, p_position: Vector2) -> void:
	mount_type = p_type
	position = p_position
	_phase = float(mount_type.length() % 4)
	queue_redraw()


func set_ridden(value: bool) -> void:
	ridden = value
	z_index = -1 if value else 0
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	if ridden and follow_target != null and is_instance_valid(follow_target):
		position = follow_target.position + Vector2(0, 2)
		facing = follow_target.facing
		moving = follow_target.is_moving()
		sprinting = follow_target.ride_sprinting and moving
	if moving:
		_phase += delta * (14.0 if sprinting else 9.0)
	else:
		_phase += delta * 2.0
	queue_redraw()


func _draw() -> void:
	match mount_type:
		"cow":
			_draw_cow()
		"donkey":
			_draw_donkey()
		"camel":
			_draw_camel()
		"ostrich":
			_draw_ostrich()
		"alpaca":
			_draw_alpaca()
		"bicycle":
			_draw_bicycle()
		"tricycle":
			_draw_tricycle()
		_:
			_draw_horse()
	_draw_status()


## 每帧帧号（4 帧循环）。
func _frame() -> int:
	return int(floor(_phase)) % 4


## 腿部上下偏移（4 帧）。
func _leg_swing(phase_offset: int) -> float:
	var offsets: Array[float] = [0.0, 1.0, 0.0, -1.0]
	return offsets[(_frame() + phase_offset) % 4]


func _line(a: Vector2, b: Vector2, color: Color, width := 1.0) -> void:
	draw_line(a * Art.U, b * Art.U, color, width, false)


# ============================================================
# 马
# ============================================================

func _draw_horse() -> void:
	_draw_equine(Color("#a9744f"), Color("#5a3f2a"), 1.0, false)


func _draw_donkey() -> void:
	_draw_equine(Color("#9a948c"), Color("#5f5a52"), 0.8, true)


## 马 / 驴共用的四足坐骑绘制（驴缩小、长耳、灰色）。
func _draw_equine(body: Color, mane: Color, scale: float, long_ears: bool) -> void:
	var body_dark := Art.shade_cool(body, 0.30)
	var body_light := Art.tint_warm(body, 0.24)
	var hoof := Color("#3f342c")
	var saddle := Color("#7d4f30")
	var pad := Color("#b5534f")
	var bob := 0.4 if moving and _frame() % 2 == 1 else 0.0
	var flip := -1.0 if facing == "left" else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale * flip, scale))
	Art.shadow(self, 0, -0.4, 12.0, 3.2)

	if facing == "up":
		# 背面：屁股与尾巴，头被身体挡住
		Art.rect(self, -12.0, -9.0 - bob, 2.6, 7.0, mane)
		Art.ellipse(self, 0, -10.0 - bob, 8.0, 5.0, body)
		Art.ellipse(self, -1.0, -11.5 - bob, 5.0, 2.2, body_light)
		_draw_horse_legs(-6.0, -2.0, 2.0, 6.0, body_dark, hoof)
		Art.rect(self, -2.0, -10.0 - bob, 4.0, 6.0, mane)
		if long_ears:
			Art.rect(self, -3.2, -27.0 - bob, 1.2, 4.0, body_dark)
			Art.rect(self, 2.0, -27.0 - bob, 1.2, 4.0, body_dark)
	else:
		# 侧 / 正面
		_draw_horse_legs(-8.0, -4.0, 4.0, 8.0, body_dark, hoof)
		# 尾巴
		Art.rect(self, -12.4, -13.0 - bob, 2.6, 7.0, mane)
		# 身体
		Art.ellipse(self, 0, -10.0 - bob, 11.0, 4.8, body)
		Art.ellipse(self, -1.0, -11.5 - bob, 8.2, 2.0, body_light)
		# 鞍具
		Art.rect(self, -3.4, -15.4 - bob, 7.0, 2.4, saddle)
		Art.rect(self, -4.2, -12.8 - bob, 9.0, 1.1, pad)
		if facing == "down":
			# 正面：脖颈与头朝镜头
			Art.rect(self, -3.4, -17.0 - bob, 6.8, 7.0, body)
			Art.rect(self, -4.2, -22.0 - bob, 8.4, 6.0, body_light)
			Art.rect(self, -3.0, -16.6 - bob, 6.0, 1.0, mane)
			Art.poly(self, PackedVector2Array([
				Vector2(-4.6, -22.0 - bob), Vector2(-3.2, -25.0 - bob),
				Vector2(-2.2, -22.0 - bob),
			]), body_dark)
			Art.poly(self, PackedVector2Array([
				Vector2(4.6, -22.0 - bob), Vector2(3.2, -25.0 - bob),
				Vector2(2.2, -22.0 - bob),
			]), body_dark)
			Art.rect(self, -2.6, -19.6 - bob, 1.0, 1.2, Color("#2f2622"))
			Art.rect(self, 1.6, -19.6 - bob, 1.0, 1.2, Color("#2f2622"))
			Art.rect(self, -2.2, -17.6 - bob, 4.4, 1.6, Art.shade_cool(Color("#d8b48a"), 0.25))
			if long_ears:
				Art.rect(self, -3.2, -27.0 - bob, 1.2, 3.6, body_dark)
				Art.rect(self, 2.0, -27.0 - bob, 1.2, 3.6, body_dark)
		else:
			# 侧面：脖子与头朝右
			Art.poly(self, PackedVector2Array([
				Vector2(6.0, -13.0 - bob), Vector2(10.4, -13.4 - bob),
				Vector2(13.2, -19.0 - bob), Vector2(9.0, -20.0 - bob),
			]), body)
			Art.rect(self, 10.0, -20.4 - bob, 6.0, 4.6, body_light)
			Art.rect(self, 13.6, -18.2 - bob, 3.2, 2.8, body_dark)
			Art.rect(self, 9.4, -21.0 - bob, 1.2, 2.0, mane)
			Art.rect(self, 9.4, -19.4 - bob, 5.8, 1.0, mane)
			Art.rect(self, 12.4, -19.0 - bob, 0.9, 1.2, Color("#2f2622"))
			Art.poly(self, PackedVector2Array([
				Vector2(11.0, -20.4 - bob), Vector2(12.2, -22.6 - bob),
				Vector2(13.2, -20.4 - bob),
			]), body_dark)
			if long_ears:
				Art.rect(self, 10.4, -26.4 - bob, 1.4, 4.6, body_dark)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_horse_legs(x0: float, x1: float, x2: float, x3: float,
		color: Color, hoof: Color) -> void:
	var legs: Array[float] = [x0, x1, x2, x3]
	for index in legs.size():
		var swing := _leg_swing(0 if index % 2 == 0 else 2)
		var leg_x: float = legs[index]
		if swing > 0.0:
			Art.rect(self, leg_x, -7.0 + swing * 0.5, 1.8, 6.4 - swing * 0.5, color)
			Art.rect(self, leg_x, -1.2 + swing * 0.5, 2.0, 1.2, hoof)
		elif swing < 0.0:
			Art.rect(self, leg_x, -7.0, 1.8, 6.4 + swing * 0.5, color)
			Art.rect(self, leg_x, -1.2 + swing * 0.5, 2.0, 1.2, hoof)
		else:
			Art.rect(self, leg_x, -7.0, 1.8, 6.4, color)
			Art.rect(self, leg_x, -1.2, 2.0, 1.2, hoof)


# ============================================================
# 牛
# ============================================================

func _draw_cow() -> void:
	var body := Color("#efe9dc")
	var patch := Color("#8c6a4a")
	var body_dark := Art.shade_cool(body, 0.22)
	var horn := Color("#e8dcc0")
	var muzzle := Color("#c98f8a")
	var bob := 0.3 if moving and _frame() % 2 == 1 else 0.0

	if facing == "left":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	Art.shadow(self, 0, -0.4, 11.0, 3.0)

	if facing == "up":
		Art.ellipse(self, 0, -9.0 - bob, 7.6, 4.6, body)
		Art.ellipse(self, -2.0, -10.4 - bob, 3.0, 1.8, patch)
		_draw_cow_legs(-5.4, -2.0, 2.0, 5.4, body_dark)
		Art.rect(self, -1.2, -9.4 - bob, 2.4, 5.0, muzzle)
	else:
		_draw_cow_legs(-6.6, -3.4, 3.4, 6.6, body_dark)
		Art.ellipse(self, 0, -9.0 - bob, 10.0, 4.4, body)
		Art.ellipse(self, -3.0, -10.4 - bob, 3.2, 2.4, patch)
		Art.ellipse(self, 3.6, -8.6 - bob, 2.4, 1.8, patch)
		if facing == "down":
			Art.rect(self, -3.2, -15.0 - bob, 6.4, 6.0, body)
			Art.rect(self, -4.0, -18.6 - bob, 8.0, 5.0, body)
			Art.poly(self, PackedVector2Array([
				Vector2(-4.4, -18.4 - bob), Vector2(-7.0, -20.4 - bob),
				Vector2(-3.4, -19.6 - bob),
			]), horn)
			Art.poly(self, PackedVector2Array([
				Vector2(4.4, -18.4 - bob), Vector2(7.0, -20.4 - bob),
				Vector2(3.4, -19.6 - bob),
			]), horn)
			Art.rect(self, -2.0, -16.0 - bob, 4.0, 2.0, muzzle)
			Art.rect(self, -3.0, -17.4 - bob, 1.0, 1.0, Color("#2f2622"))
			Art.rect(self, 2.0, -17.4 - bob, 1.0, 1.0, Color("#2f2622"))
		else:
			Art.rect(self, 4.6, -13.6 - bob, 5.6, 5.0, body)
			Art.rect(self, 8.2, -15.0 - bob, 4.6, 4.2, body)
			Art.poly(self, PackedVector2Array([
				Vector2(8.0, -15.0 - bob), Vector2(8.8, -18.0 - bob),
				Vector2(10.2, -15.2 - bob),
			]), horn)
			Art.rect(self, 11.0, -13.2 - bob, 2.6, 2.2, muzzle)
			Art.rect(self, 10.0, -14.4 - bob, 0.9, 1.0, Color("#2f2622"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cow_legs(x0: float, x1: float, x2: float, x3: float, color: Color) -> void:
	var legs: Array[float] = [x0, x1, x2, x3]
	for index in legs.size():
		var swing := _leg_swing(0 if index % 2 == 0 else 2)
		var leg_x: float = legs[index]
		Art.rect(self, leg_x, -5.4 + swing * 0.4, 1.7, 5.4 - absf(swing) * 0.4, color)
		Art.rect(self, leg_x, -0.9, 1.9, 0.9, Color("#6f5a48"))


# ============================================================
# 骆驼
# ============================================================

func _draw_camel() -> void:
	var body := Color("#c9a676")
	var body_dark := Art.shade_cool(body, 0.28)
	var body_light := Art.tint_warm(body, 0.22)
	var mane := Color("#8c6a4a")
	var bob := 0.3 if moving and _frame() % 2 == 1 else 0.0
	var flip := -1.0 if facing == "left" else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))
	Art.shadow(self, 0, -0.4, 13.0, 3.4)

	var offsets: Array[float] = [0.0, 1.0, 0.0, -1.0]
	for index in 4:
		var leg_x := -9.0 + float(index) * 5.6
		var swing: float = offsets[(_frame() + index) % 4]
		Art.rect(self, leg_x, -7.0 + swing * 0.4, 1.9, 7.0 - absf(swing) * 0.4, body_dark)
		Art.rect(self, leg_x, -0.9, 2.1, 0.9, Color("#6f5a48"))

	# 身体 + 双峰
	Art.ellipse(self, 0, -11.0 - bob, 12.0, 4.6, body)
	Art.ellipse(self, -3.6, -15.2 - bob, 3.4, 2.6, body)
	Art.ellipse(self, 3.6, -15.2 - bob, 3.4, 2.6, body)
	Art.ellipse(self, -3.6, -15.8 - bob, 2.0, 1.2, body_light)
	Art.ellipse(self, 3.6, -15.8 - bob, 2.0, 1.2, body_light)
	Art.rect(self, -13.0, -13.0 - bob, 1.8, 6.0, mane)

	if facing == "up":
		# 背面：头在身体另一侧，只露出耳朵
		Art.rect(self, -1.6, -19.0 - bob, 1.4, 2.0, body_dark)
		Art.rect(self, 0.8, -19.0 - bob, 1.4, 2.0, body_dark)
	elif facing == "down":
		# 正面：长脖子与头朝镜头
		Art.rect(self, -2.4, -23.0 - bob, 4.8, 12.0, body)
		Art.rect(self, -3.2, -27.0 - bob, 6.4, 5.0, body_light)
		Art.rect(self, -2.2, -24.6 - bob, 4.4, 1.4, body_dark)
		Art.rect(self, -2.0, -26.0 - bob, 1.0, 1.0, Color("#2f2622"))
		Art.rect(self, 1.0, -26.0 - bob, 1.0, 1.0, Color("#2f2622"))
	else:
		# 侧面：脖子前伸
		Art.poly(self, PackedVector2Array([
			Vector2(8.0, -13.0 - bob), Vector2(11.6, -14.0 - bob),
			Vector2(15.0, -22.0 - bob), Vector2(11.4, -23.0 - bob),
		]), body)
		Art.rect(self, 12.6, -24.2 - bob, 5.2, 3.6, body_light)
		Art.rect(self, 15.8, -22.8 - bob, 2.4, 2.0, body_dark)
		Art.rect(self, 13.6, -23.8 - bob, 0.9, 1.0, Color("#2f2622"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ============================================================
# 鸵鸟
# ============================================================

func _draw_ostrich() -> void:
	var body := Color("#6f5a48")
	var body_light := Color("#8a7460")
	var skin := Color("#d9b48a")
	var beak := Color("#d9a05e")
	var bob := 0.5 if moving and _frame() % 2 == 1 else 0.0
	var flip := -1.0 if facing == "left" else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))
	Art.shadow(self, 0, -0.4, 9.0, 2.8)

	# 细长双腿（冲刺时步幅更大）
	var leg_offsets: Array[float] = [0.0, 1.4, 0.0, -1.4]
	for index in 2:
		var leg_x := -3.0 + float(index) * 6.0
		var swing: float = leg_offsets[(_frame() + index * 2) % 4]
		Art.rect(self, leg_x, -9.0 + swing * 0.3, 1.4, 9.0 - absf(swing) * 0.3, skin)
		Art.rect(self, leg_x - 0.4, -0.8, 2.4, 0.8, Color("#c98f6a"))

	# 蓬松身体 + 尾羽
	Art.ellipse(self, 0, -12.0 - bob, 7.6, 4.6, body)
	Art.ellipse(self, -1.0, -13.4 - bob, 5.0, 2.4, body_light)
	Art.rect(self, -8.6, -14.2 - bob, 3.2, 2.2, body_light)
	Art.rect(self, -9.6, -13.2 - bob, 2.6, 1.6, Color("#efe9dc"))

	# 冲刺时翅膀微张 + 羽毛抖动
	if sprinting:
		Art.poly(self, PackedVector2Array([
			Vector2(-4.0, -14.0 - bob), Vector2(2.0, -19.0 - bob),
			Vector2(6.0, -14.0 - bob),
		]), body_light)
		Art.rect(self, 2.6, -18.0 - bob, 4.2, 1.0, Color("#efe9dc"))
		Art.rect(self, 1.0, -17.0 - bob, 3.4, 0.8, Color("#efe9dc"))

	# 脖子与头（S 形，正/背面略偏中）
	var neck_x := 0.0 if facing == "up" else 5.2
	Art.rect(self, neck_x - 0.9, -22.0 - bob, 1.8, 10.0, skin)
	Art.rect(self, neck_x - 1.4, -24.4 - bob, 3.8, 3.2, skin)
	Art.rect(self, neck_x + 1.6, -23.6 - bob, 2.4, 1.2, beak)
	Art.rect(self, neck_x - 0.2, -23.6 - bob, 1.0, 1.0, Color("#2f2622"))
	Art.rect(self, neck_x - 1.8, -25.6 - bob, 1.4, 1.6, body)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ============================================================
# 羊驼
# ============================================================

func _draw_alpaca() -> void:
	var wool := Color("#efe6d4")
	var wool_dark := Art.shade_cool(wool, 0.22)
	var skin := Color("#d9b48a")
	var bob := 0.25 if moving and _frame() % 2 == 1 else 0.0
	var flip := -1.0 if facing == "left" else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))
	Art.shadow(self, 0, -0.4, 9.0, 2.8)

	# 短腿
	var offsets: Array[float] = [0.0, 0.8, 0.0, -0.8]
	for index in 4:
		var leg_x := -5.4 + float(index) * 3.6
		var swing: float = offsets[(_frame() + index) % 4]
		Art.rect(self, leg_x, -5.6 + swing * 0.3, 1.5, 5.6 - absf(swing) * 0.3, skin)
		Art.rect(self, leg_x - 0.2, -0.8, 1.9, 0.8, Color("#b08a62"))

	# 蓬松身体（多个椭圆叠加）
	Art.ellipse(self, 0, -10.0 - bob, 8.0, 5.0, wool)
	Art.ellipse(self, -4.4, -12.0 - bob, 3.4, 3.0, wool)
	Art.ellipse(self, 3.4, -11.6 - bob, 3.2, 2.8, wool)
	Art.ellipse(self, 0, -13.2 - bob, 4.6, 2.2, wool_dark)
	Art.rect(self, -6.4, -8.6 - bob, 2.2, 4.0, wool)
	Art.rect(self, 4.4, -8.4 - bob, 2.2, 3.8, wool)

	# 脖子与头（羊驼长颈，头小）
	Art.rect(self, 4.6, -19.0 - bob, 3.2, 9.0, wool)
	Art.rect(self, 5.2, -21.4 - bob, 4.4, 3.6, wool)
	Art.rect(self, 8.4, -20.4 - bob, 2.4, 2.2, skin)
	Art.poly(self, PackedVector2Array([
		Vector2(5.4, -21.4 - bob), Vector2(5.0, -24.2 - bob),
		Vector2(6.8, -21.4 - bob),
	]), wool_dark)
	Art.poly(self, PackedVector2Array([
		Vector2(7.6, -21.4 - bob), Vector2(8.6, -23.8 - bob),
		Vector2(9.2, -21.2 - bob),
	]), wool_dark)
	Art.rect(self, 8.6, -20.6 - bob, 0.9, 1.0, Color("#2f2622"))
	Art.rect(self, 5.8, -19.6 - bob, 2.0, 0.9, Art.tint_warm(wool, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ============================================================
# 自行车
# ============================================================

func _draw_bicycle() -> void:
	var frame := Color("#b5534f")
	var frame_dark := Art.shade_cool(frame, 0.34)
	var metal := Color("#9aa4a8")
	var tire := Color("#4a4440")
	var rim := Color("#c9d0d2")

	if facing == "left":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1, 1))
	Art.shadow(self, 0, -0.4, 10.0, 2.4)

	var spin := sin(_phase * 1.6) * 0.6
	if facing == "up" or facing == "down":
		# 正 / 背面：单轮 + 立管 + 车把
		Art.ellipse(self, 0, -5.0, 4.4, 4.4, tire)
		Art.ellipse(self, 0, -5.0, 2.8, 2.8, rim)
		Art.rect(self, -0.8, -14.0, 1.6, 9.4, frame)
		Art.rect(self, -6.0, -14.6, 12.0, 1.4, frame_dark)
		Art.rect(self, -4.0, -16.4, 2.0, 2.0, metal)
		Art.rect(self, 2.0, -16.4, 2.0, 2.0, metal)
		Art.rect(self, -1.4, -8.0, 2.8, 1.4, tire)
	else:
		# 侧面：两轮 + 三角车架
		for wheel_x: float in [-8.0, 7.0]:
			Art.ellipse(self, wheel_x, -4.6, 4.6, 4.6, tire)
			Art.ellipse(self, wheel_x, -4.6, 2.9, 2.9, rim)
			Art.ellipse(self, wheel_x, -4.6, 0.8, 0.8, frame_dark)
			for spoke in 4:
				var angle := float(spoke) * PI * 0.5 + spin
				_line(Vector2(wheel_x, -4.6),
					Vector2(wheel_x + cos(angle) * 2.6, -4.6 + sin(angle) * 2.6),
					Color(0.55, 0.60, 0.62, 0.85), 1.0)
		# 车架
		_line(Vector2(-8.0, -4.6), Vector2(-1.4, -4.6), frame, 2.0)
		_line(Vector2(-1.4, -4.6), Vector2(-2.6, -12.0), frame, 2.0)
		_line(Vector2(-2.6, -12.0), Vector2(5.2, -11.4), frame, 2.0)
		_line(Vector2(5.2, -11.4), Vector2(7.0, -4.6), frame, 2.0)
		_line(Vector2(-1.4, -4.6), Vector2(5.2, -11.4), frame_dark, 1.6)
		# 车把 / 车座 / 踏板
		Art.rect(self, 4.4, -13.0, 3.6, 1.4, metal)
		_line(Vector2(5.2, -11.4), Vector2(5.2, -13.0), metal, 1.4)
		Art.rect(self, -4.6, -13.2, 4.4, 1.6, Color("#5a4a38"))
		Art.rect(self, -3.0, -6.2, 3.4, 1.2, frame_dark)
		# 车铃
		Art.ellipse(self, 5.4, -13.8, 0.9, 0.9, Color("#e3c98c"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ============================================================
# 三轮车
# ============================================================

func _draw_tricycle() -> void:
	var frame := Color("#5f7f9c")
	var frame_dark := Art.shade_cool(frame, 0.30)
	var metal := Color("#9aa4a8")
	var tire := Color("#4a4440")
	var rim := Color("#c9d0d2")
	var box := Color("#a9825c")
	var box_dark := Color("#8c6a4a")
	var flip := -1.0 if facing == "left" else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(flip, 1.0))
	Art.shadow(self, 0, -0.4, 11.0, 2.8)
	var spin := sin(_phase * 1.4) * 0.5
	var bob := 0.25 if moving and _frame() % 2 == 1 else 0.0

	if facing == "up" or facing == "down":
		# 正 / 背面：前轮 + 两个后轮
		for wheel_x: float in [-5.6, 0.0, 5.6]:
			Art.ellipse(self, wheel_x, -4.6, 3.4, 3.4, tire)
			Art.ellipse(self, wheel_x, -4.6, 1.6, 1.6, rim)
		Art.rect(self, -7.0, -14.0 - bob, 14.0, 7.0, box)
		Art.rect(self, -7.0, -14.0 - bob, 14.0, 1.2, Color("#c9a276"))
		Art.rect(self, -0.8, -17.0 - bob, 1.6, 4.0, frame_dark)
		Art.rect(self, -6.0, -17.6 - bob, 12.0, 1.2, metal)
	else:
		# 侧面：前轮 + 后轮（另一只后轮半透明错开）
		for wheel_x: float in [-9.0, 6.8]:
			Art.ellipse(self, wheel_x, -4.6, 4.2, 4.2, tire)
			Art.ellipse(self, wheel_x, -4.6, 2.4, 2.4, rim)
			for spoke in 3:
				var angle := float(spoke) * PI * 2.0 / 3.0 + spin
				_line(Vector2(wheel_x, -4.6),
					Vector2(wheel_x + cos(angle) * 2.2, -4.6 + sin(angle) * 2.2),
					Color(0.55, 0.60, 0.62, 0.85), 1.0)
		Art.ellipse(self, -9.0, -6.0, 3.2, 3.2, Color(0.24, 0.22, 0.20, 0.45))
		# 车架
		_line(Vector2(-9.0, -4.6), Vector2(-2.0, -5.0), frame_dark, 2.0)
		_line(Vector2(-2.0, -5.0), Vector2(3.0, -11.0), frame, 2.0)
		_line(Vector2(3.0, -11.0), Vector2(6.8, -4.6), frame, 2.0)
		_line(Vector2(-2.0, -5.0), Vector2(-2.6, -12.0), frame_dark, 2.0)
		# 货斗
		Art.rect(self, -13.0, -12.0 - bob, 8.0, 6.0, box)
		Art.rect(self, -13.0, -12.0 - bob, 8.0, 1.2, Color("#c9a276"))
		Art.rect(self, -12.4, -10.4 - bob, 6.8, 0.8, box_dark)
		# 车座 / 车把 / 车铃
		Art.rect(self, -4.4, -13.6, 4.0, 1.5, Color("#5a4a38"))
		Art.rect(self, 3.6, -14.0, 3.4, 1.2, metal)
		_line(Vector2(6.8, -4.6), Vector2(5.4, -14.0), metal, 1.4)
		Art.ellipse(self, 5.0, -14.8, 0.9, 0.9, Color("#e3c98c"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ============================================================
# 状态：耐力条 / 疲劳
# ============================================================

func _draw_status() -> void:
	if not ridden:
		return
	if max_stamina > 0.0:
		var ratio := clampf(stamina / maxf(1.0, max_stamina), 0.0, 1.0)
		var color := Color("#6fae6a")
		if ratio < 0.2:
			color = Color("#c4553f")
		elif ratio < 0.5:
			color = Color("#d8b45a")
		Art.rect(self, -10.0, -30.0, 20.0, 2.4, Color(0.16, 0.13, 0.18, 0.65))
		Art.rect(self, -9.4, -29.5, 18.8 * ratio, 1.4, color)
	if cargo_capacity > 0:
		# 货袋图标（驴 / 骆驼 / 自行车）
		Art.rect(self, -18.6, -23.2, 5.0, 4.4, Color("#a9825c"))
		Art.rect(self, -18.6, -23.2, 5.0, 0.9, Color("#c9a276"))
		Art.rect(self, -17.4, -24.2, 2.6, 1.2, Color("#8c6a4a"))
	if fatigue:
		Art.ellipse(self, 8.6, -23.6, 1.2, 1.8, Color("#8fc6d4"))
		Art.ellipse(self, 10.8, -20.6, 0.9, 1.3, Color("#8fc6d4"))
	# 移动扬尘
	if moving and ridden:
		var puff := fmod(_t * 3.0, 1.0)
		var alpha := (1.0 - puff) * 0.35
		Art.ellipse(self, -9.0 - puff * 3.0, -0.6, 1.8, 0.7,
			Color(0.72, 0.64, 0.50, alpha))
		var puff_b := fmod(puff + 0.5, 1.0)
		Art.ellipse(self, -7.0 - puff_b * 3.0, -0.4, 1.4, 0.6,
			Color(0.72, 0.64, 0.50, (1.0 - puff_b) * 0.30))
