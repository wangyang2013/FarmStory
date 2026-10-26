class_name WildCritter
extends Node2D
## 农场里的野生小动物（兔子 / 松鼠的通用小体型）。
## 狗好感 ≥80 靠近时会被赶跑；玩家靠得太近也会逃走。

const Art := preload("res://scripts/art/PixelArt.gd")

var farm
var critter_color := Color("#b08a62")
var _home := Vector2.ZERO
var _target := Vector2.ZERO
var _timer := 1.5
var _facing := 1
var _moving := false
var _phase := 0.0
var _flee_timer := 0.0
var _flee_dir := Vector2.RIGHT
var _scared_by_dog := false


func setup(p_farm: Node, world_position: Vector2) -> void:
	farm = p_farm
	position = world_position
	_home = world_position
	_target = world_position
	_phase = randf() * TAU
	var palette := [Color("#b08a62"), Color("#9a8a72"), Color("#c9a06a")]
	critter_color = palette[randi() % palette.size()]
	add_to_group("wildlife")
	queue_redraw()


func _process(delta: float) -> void:
	_phase += delta
	if _flee_timer > 0.0:
		_flee_timer = maxf(0.0, _flee_timer - delta)
		position += _flee_dir * 96.0 * delta
		_moving = true
		if _flee_timer <= 0.0:
			queue_free()
		queue_redraw()
		return

	_timer -= delta
	if _timer <= 0.0:
		_timer = 2.0 + randf() * 3.0
		_target = _home + Vector2(randf_range(-40.0, 40.0), randf_range(-20.0, 20.0))
	var to_target := _target - position
	if to_target.length() > 3.0:
		position += to_target.normalized() * 22.0 * delta
		_facing = 1 if to_target.x > 0.0 else -1
		_moving = true
	else:
		_moving = false

	# 玩家 / 高好感狗靠近时逃跑
	if farm != null and farm.player != null:
		if position.distance_to(farm.player.position) <= 26.0:
			_flee(farm.player.position, false)
			return
		for pet: Variant in farm.pets:
			if pet.pet_type == "dog" and pet.friendship >= 80.0 and not pet.missing:
				if position.distance_to(pet.position) <= 46.0:
					_flee(pet.position, true)
					return
	queue_redraw()


func _flee(from: Vector2, by_dog: bool) -> void:
	if _flee_timer > 0.0:
		return
	_flee_dir = (position - from)
	if _flee_dir.length() < 0.01:
		_flee_dir = Vector2.RIGHT
	_flee_dir = _flee_dir.normalized()
	_flee_timer = 1.1
	_scared_by_dog = by_dog
	if by_dog and farm != null and farm.ui != null:
		farm.ui.toast("小狗把野生小动物赶跑了", "good")


func _draw() -> void:
	Art.shadow(self, 0, -0.4, 4.0, 1.4)
	var bob := sin(_phase * 3.0) * (0.4 if _moving else 0.15)
	draw_set_transform(Vector2(0, -bob), 0.0, Vector2(float(_facing), 1))
	var dark := critter_color.darkened(0.16)
	# 身体 + 头
	Art.ellipse(self, 0, -4.6, 3.0, 2.4, critter_color)
	Art.ellipse(self, 2.4, -6.0, 1.8, 1.6, critter_color)
	# 长耳
	Art.rect(self, 2.0, -9.8, 1.0, 3.8, critter_color)
	Art.rect(self, 3.4, -9.8, 1.0, 3.8, critter_color)
	Art.rect(self, 2.2, -9.2, 0.5, 2.6, Color("#e8b0b0"))
	Art.rect(self, 3.6, -9.2, 0.5, 2.6, Color("#e8b0b0"))
	# 眼睛 / 尾巴 / 腿
	Art.rect(self, 3.2, -6.4, 0.6, 0.7, Color("#2f2622"))
	Art.ellipse(self, -3.4, -4.2, 1.2, 1.0, Color("#f7f0dd"))
	Art.rect(self, -1.6, -2.0, 0.9, 2.0, dark)
	Art.rect(self, 0.8, -2.0, 0.9, 2.0, dark)
	Art.reset_transform(self)
