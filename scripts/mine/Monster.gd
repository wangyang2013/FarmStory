class_name MineMonster
extends Node2D
## 矿洞怪物：巡逻 / 追击 / 近身攻击；受击闪烁、击退、血量条与掉落。

signal died(monster)

const DB := preload("res://scripts/core/ConfigDB.gd")
const TILE := 32

var monster_id := ""
var display_name := ""
var max_hp := 20
var hp := 20
var attack := 5
var speed := 28.0
var drops: Array = []
var target
var bounds := Rect2(0, 0, 1280, 960)

var _rng := RandomNumberGenerator.new()
var _dir := Vector2.ZERO
var _wander_timer := 0.0
var _attack_timer := 0.0
var _knockback := Vector2.ZERO
var _flash := 0.0
var _dead := false
var _anim := 0.0


func setup(monster_id_value: String, floor_num: int, p_target, p_bounds: Rect2, seed_value: int) -> void:
	monster_id = monster_id_value
	var definition := DB.get_monster(monster_id)
	display_name = str(definition.get("name", monster_id))
	var scaling := DB.get_combat_scaling()
	var hp_scale := 1.0 + float(floor_num) * float(scaling.get("hp_per_floor", 0.02))
	var attack_scale := 1.0 + float(floor_num) * float(scaling.get("attack_per_floor", 0.03))
	max_hp = maxi(1, roundi(float(definition.get("hp", 20)) * hp_scale))
	hp = max_hp
	attack = maxi(1, roundi(float(definition.get("attack", 5)) * attack_scale))
	speed = float(definition.get("speed", 28.0))
	var drop_list: Variant = definition.get("drops", [])
	drops = drop_list.duplicate(true) if drop_list is Array else []
	target = p_target
	bounds = p_bounds
	_rng.seed = seed_value
	_wander_timer = _rng.randf_range(0.4, 1.4)
	_choose_wander()
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if _dead:
		return
	_anim += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_flash = maxf(0.0, _flash - delta)
	modulate = Color(1.6, 1.0, 1.0) if _flash > 0.0 else Color.WHITE

	var target_pos := Vector2.ZERO
	var has_target := is_instance_valid(target)
	if has_target and bool(target.input_locked):
		queue_redraw()
		return
	if has_target:
		target_pos = target.position
		var distance := position.distance_to(target_pos)
		if distance <= 170.0:
			_dir = (target_pos - position).normalized()
			if distance <= 24.0 and _attack_timer <= 0.0:
				_attack_timer = 1.0
				if target.has_method("take_damage"):
					target.take_damage(attack)
		else:
			_tick_wander(delta)
	else:
		_tick_wander(delta)

	position += (_dir * speed + _knockback) * delta
	_knockback = _knockback.move_toward(Vector2.ZERO, 420.0 * delta)
	position.x = clampf(position.x, bounds.position.x + 12.0, bounds.end.x - 12.0)
	position.y = clampf(position.y, bounds.position.y + 12.0, bounds.end.y - 12.0)
	queue_redraw()


func _tick_wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = _rng.randf_range(0.8, 2.0)
		_choose_wander()


func _choose_wander() -> void:
	var angle := _rng.randf_range(0.0, TAU)
	_dir = Vector2(cos(angle), sin(angle)) * 0.55


func take_damage(amount: int, from_pos := Vector2.ZERO) -> void:
	if _dead:
		return
	hp = maxi(0, hp - amount)
	_flash = 0.25
	if from_pos != Vector2.ZERO:
		_knockback = (position - from_pos).normalized() * 110.0
	queue_redraw()
	if hp <= 0:
		_dead = true
		died.emit(self)
		queue_free()


func _draw() -> void:
	var bob := sin(_anim * 6.0) * 1.0
	match monster_id:
		"bat":
			draw_rect(Rect2(-9, -15 + bob, 18, 7), Color("#6f5f8c"), true)
			draw_rect(Rect2(-11, -13 + bob, 5, 3), Color("#8b7aa8"), true)
			draw_rect(Rect2(6, -13 + bob, 5, 3), Color("#8b7aa8"), true)
			draw_rect(Rect2(-5, -12 + bob, 10, 8), Color("#8b7aa8"), true)
			draw_rect(Rect2(-4, -10 + bob, 2, 2), Color("#f0e6d2"), true)
			draw_rect(Rect2(2, -10 + bob, 2, 2), Color("#f0e6d2"), true)
		"mole":
			draw_rect(Rect2(-9, -10 + bob, 18, 10), Color("#9a7a58"), true)
			draw_rect(Rect2(-6, -7 + bob, 3, 3), Color("#3f3328"), true)
			draw_rect(Rect2(3, -7 + bob, 3, 3), Color("#3f3328"), true)
			draw_rect(Rect2(-2, -5 + bob, 4, 2), Color("#c9a0a0"), true)
		"deep":
			draw_rect(Rect2(-8, -16 + bob, 16, 14), Color("#6b5a8e"), true)
			draw_rect(Rect2(-6, -13 + bob, 4, 4), Color("#d9534f"), true)
			draw_rect(Rect2(2, -13 + bob, 4, 4), Color("#d9534f"), true)
			draw_rect(Rect2(-8, -3 + bob, 16, 3), Color("#4c3f6b"), true)
		_:
			draw_rect(Rect2(-9, -8 + bob, 18, 8), Color("#7fae6a"), true)
			draw_rect(Rect2(-7, -10 + bob, 14, 3), Color("#93c27e"), true)
			draw_rect(Rect2(-5, -5 + bob, 2, 2), Color("#2f3a28"), true)
			draw_rect(Rect2(3, -5 + bob, 2, 2), Color("#2f3a28"), true)
	if hp < max_hp:
		var ratio := float(hp) / float(maxi(1, max_hp))
		draw_rect(Rect2(-9, -23, 18, 3), Color(0.1, 0.08, 0.06, 0.55), true)
		draw_rect(Rect2(-9, -23, 18.0 * ratio, 2), Color("#c4553f"), true)
