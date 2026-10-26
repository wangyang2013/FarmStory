class_name FarmPet
extends Node2D
## 宠物：狗 / 猫 / 鸟 / 小熊猫 / 鱼 / 乌龟。
##
## 合并旧版狗猫逻辑与新版宠物系统：
##   - 品种、价格、栖息地、食物全部来自 config/pets.json / pet_houses.json / pet_food.json
##   - 好感 + 饥饿 / 心情 / 清洁 / 健康四维状态
##   - 狗猫跟随并带回小礼物；鸟 / 鱼 / 乌龟固定在自己的栖息地
##   - 领养时独立 roll 稀有毛色
##
## 存档只存实例状态，配置不写入存档。

const DB := preload("res://scripts/core/ConfigDB.gd")
const Art := preload("res://scripts/art/PixelArt.gd")

const TILE := 32

var pet_id := ""
var pet_type := "dog"
var breed := "shiba"
var pet_name := ""
var is_rare := false
var rare_color := ""
var rare_color_name := ""

var friendship := 20.0
var friendship_max := 100.0
var hunger := 70.0
var mood := 70.0
var cleanliness := 80.0
var health := 100.0
var sick := false
var gift_ready := false
var gift: Dictionary = {}
var house_id := ""
var in_house := false
var following := true
var missing := false
var missing_days := 0
var adopted_day := 1
var name_changed := false
var age_days := 0
var released := false
var release_timer := 0.0
var basking := false
var sleeping := false
var swung := false
var hiding := false
var shell := false
var battled_today := false
var _eat_timer := 0.0
var _clean_timer := 0.0

var fed_today := false
var petted_today := false
var played_today := false
var cleaned_today := false
var walked_today := false

var _home := Vector2.ZERO
var _wander_target := Vector2.ZERO
var _wander_timer := 1.0
var _facing := 1
var _moving := false
var _phase := 0.0
var _walk := 0.0
var _behavior_t := 0.0
var _hungry_days := 0
var _dirty_days := 0
var _runaway_days := 0


func setup(p_breed: String, world_position: Vector2) -> void:
	var definition := _resolve_breed(p_breed)
	pet_type = str(definition.get("type_id", "dog"))
	breed = str(definition.get("id", "shiba"))
	pet_name = str(definition.get("name", pet_type))
	position = world_position
	_home = world_position
	_wander_target = world_position

	var config := DB.get_pet_config()
	friendship_max = float(config.get("friendship_max", 100))
	friendship = float(config.get("friendship_start", 20))
	var status: Dictionary = config.get("status", {})
	var start: Dictionary = status.get("start", {})
	hunger = float(start.get("hunger", 70))
	mood = float(start.get("mood", 70))
	cleanliness = float(start.get("cleanliness", 80))
	health = float(start.get("health", 100))
	var can_follow := bool(definition.get("can_follow", false))
	following = can_follow
	in_house = not can_follow
	_phase = randf() * TAU
	queue_redraw()


func _resolve_breed(id: String) -> Dictionary:
	var definition := DB.get_pet_breed(id)
	if not definition.is_empty():
		return definition
	var type_entry := DB.get_pet_type(id)
	var breeds: Array = type_entry.get("breeds", [])
	if not breeds.is_empty() and breeds[0] is Dictionary:
		return DB.get_pet_breed(str((breeds[0] as Dictionary).get("id", "")))
	return DB.get_pet_breed("shiba")


func get_definition() -> Dictionary:
	return DB.get_pet_breed(breed)


func get_type_definition() -> Dictionary:
	return DB.get_pet_type(pet_type)


func get_display_name() -> String:
	var base := pet_name if not pet_name.is_empty() else str(get_definition().get("name", breed))
	if is_rare and not rare_color_name.is_empty():
		return "%s · %s" % [rare_color_name, base]
	return base


func get_breed_name() -> String:
	return str(get_definition().get("name", breed))


func get_color() -> Color:
	if is_rare:
		var rare_def := DB.get_pet_rare_color(rare_color)
		var hex := str(rare_def.get("color", ""))
		if not hex.is_empty():
			return Color(hex)
	var color := str(get_definition().get("color", ""))
	return Color(color) if not color.is_empty() else Color("#c8a97e")


func get_accent() -> Color:
	var color := str(get_definition().get("accent", ""))
	return Color(color) if not color.is_empty() else get_color().lightened(0.25)


## 领养时决定稀有毛色；平时毛色由品种决定。
func roll_adoption_traits() -> void:
	var definition := get_definition()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() < float(definition.get("rare_chance", 0.10)):
		var rare_colors: Array = DB.get_pet_config().get("rare_colors", [])
		if not rare_colors.is_empty():
			var picked: Variant = rare_colors[rng.randi_range(0, rare_colors.size() - 1)]
			if picked is Dictionary:
				is_rare = true
				rare_color = str(picked.get("id", ""))
				rare_color_name = str(picked.get("name", ""))
	queue_redraw()


func can_pet() -> bool:
	return bool(get_definition().get("can_pet", false)) and not sick and not missing


func can_play() -> bool:
	return bool(get_definition().get("can_play", false)) and not sick and not missing


func can_follow() -> bool:
	return bool(get_definition().get("can_follow", false)) and not sick and not missing


func add_friendship(amount: float) -> void:
	friendship = clampf(friendship + amount, 0.0, friendship_max)


func _interaction_value(key: String, fallback: float) -> float:
	var interactions: Dictionary = DB.get_pet_config().get("interactions", {})
	return float(interactions.get(key, fallback))


func pet() -> bool:
	if petted_today or not can_pet():
		return false
	petted_today = true
	add_friendship(_interaction_value("pet_friendship", 3.0))
	mood = minf(100.0, mood + float(_status_config("pet_mood", 10.0)))
	queue_redraw()
	return true


func play() -> bool:
	if played_today or not can_play():
		return false
	played_today = true
	add_friendship(_interaction_value("play_friendship", 2.0))
	mood = minf(100.0, mood + float(_status_config("play_mood", 20.0)))
	queue_redraw()
	return true


func clean() -> bool:
	if cleaned_today or missing:
		return false
	cleaned_today = true
	add_friendship(_interaction_value("clean_friendship", 2.0))
	cleanliness = minf(100.0, cleanliness + float(_status_config("clean_amount", 40.0)))
	_clean_timer = 0.9
	queue_redraw()
	return true


## 喂食：必须是对应物种的食物。
func feed(food_id: String) -> bool:
	if fed_today or missing:
		return false
	var food := DB.get_pet_food(food_id)
	if food.is_empty():
		return false
	var allowed: Array = food.get("for", [])
	if not allowed.is_empty() and pet_type not in allowed:
		return false
	fed_today = true
	add_friendship(float(food.get("friendship", _interaction_value("feed_friendship", 5.0))))
	var status: Dictionary = DB.get_pet_config().get("status", {})
	var feed_status: Dictionary = status.get("feed", {})
	hunger = minf(100.0, hunger + float(feed_status.get("hunger", 30)))
	mood = minf(100.0, mood + float(feed_status.get("mood", 5)))
	health = minf(100.0, health + 2.0)
	_eat_timer = 0.7
	queue_redraw()
	return true


func heal() -> bool:
	if not sick:
		return false
	sick = false
	health = 100.0
	queue_redraw()
	return true


func feed_with_fallback(food_id: String) -> bool:
	return feed(food_id)


func _status_config(key: String, fallback: float) -> float:
	var status: Dictionary = DB.get_pet_config().get("status", {})
	return float(status.get(key, fallback))


func collect_gift() -> Dictionary:
	if not gift_ready:
		return {}
	gift_ready = false
	var result := gift.duplicate(true)
	gift = {}
	queue_redraw()
	return result


## 跨日：四维状态衰减、生病、礼物与离家出走判定。
func advance_day() -> void:
	var config := DB.get_pet_config()
	var status: Dictionary = config.get("status", {})
	var was_fed := fed_today
	var was_cleaned := cleaned_today
	fed_today = false
	petted_today = false
	played_today = false
	cleaned_today = false
	walked_today = false
	battled_today = false
	released = false
	release_timer = 0.0
	sleeping = false
	basking = false
	if pet_type == "young_livestock":
		age_days += 1

	if missing:
		queue_redraw()
		return

	var decay: Dictionary = status.get("decay", {})
	hunger = maxf(0.0, hunger - float(decay.get("hunger", 20)))
	mood = maxf(0.0, mood - float(decay.get("mood", 10)))
	cleanliness = maxf(0.0, cleanliness - float(decay.get("cleanliness", 15)))

	if not was_fed:
		_hungry_days += 1
		if _hungry_days >= 3:
			add_friendship(-10.0)
			_hungry_days = 0
	else:
		_hungry_days = 0

	if not was_cleaned and cleanliness <= 0.0:
		_dirty_days += 1
		if _dirty_days >= 3:
			add_friendship(-5.0)
			_dirty_days = 0
	elif cleanliness > 0.0:
		_dirty_days = 0

	if hunger <= 0.0:
		health -= float(status.get("hunger_health_loss", 10))
	if cleanliness <= 0.0:
		health -= float(status.get("dirty_health_loss", 5))
	if was_fed and cleanliness > 40.0:
		health = minf(100.0, health + 5.0)
	health = clampf(health, 0.0, 100.0)
	if health <= 0.0:
		sick = true

	gift_ready = false
	gift = {}
	var definition := get_definition()
	var min_friendship := float(definition.get("gift_friendship_min", 999.0))
	if was_fed and friendship >= min_friendship:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if rng.randf() < float(definition.get("gift_chance", 0.5)):
			var gifts: Array = definition.get("gifts", [])
			if not gifts.is_empty():
				var picked: Variant = gifts[rng.randi_range(0, gifts.size() - 1)]
				if picked is Dictionary:
					gift = (picked as Dictionary).duplicate(true)
					gift["count"] = 1
					gift_ready = true

	var runaway: Dictionary = status.get("runaway", {})
	if friendship < float(runaway.get("friendship", 10)) \
			and hunger < float(runaway.get("hunger", 20)):
		_runaway_days += 1
		if _runaway_days >= int(runaway.get("days", 3)):
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			if rng.randf() < float(runaway.get("chance", 0.5)):
				missing = true
				missing_days = 0
				following = false
				visible = false
	else:
		_runaway_days = 0
	queue_redraw()


## 离家出走：3 天内找回；返回是否应被永久移除。
func tick_missing_day() -> bool:
	if not missing:
		return false
	missing_days += 1
	return missing_days > int(DB.get_pet_config().get("status", {})
		.get("runaway", {}).get("missing_days", 3))


func recover_missing() -> void:
	if not missing:
		return
	missing = false
	missing_days = 0
	visible = true
	var runaway: Dictionary = DB.get_pet_config().get("status", {}).get("runaway", {})
	friendship = float(runaway.get("recover_friendship", 30))
	hunger = maxf(hunger, 60.0)
	mood = maxf(mood, 50.0)
	in_house = true
	following = false
	position = _home
	queue_redraw()


func is_companion() -> bool:
	return bool(get_definition().get("can_follow", false))


func is_young_livestock() -> bool:
	return pet_type == "young_livestock"


func start_release(seconds: float) -> void:
	released = true
	release_timer = maxf(1.0, seconds)
	in_house = false
	following = false
	queue_redraw()


## 返回是否到时自动回栖息地。
func tick_release(delta: float) -> bool:
	if not released:
		return false
	release_timer = maxf(0.0, release_timer - delta)
	if release_timer > 0.0:
		return false
	released = false
	in_house = not is_companion()
	following = is_companion()
	queue_redraw()
	return true


func follows_player() -> bool:
	var threshold := float(DB.get_pet_config().get("follow_friendship", 50.0))
	return is_companion() and following and not in_house and not sick and not missing \
		and friendship >= threshold


# ============================================================
# 行为
# ============================================================

func _process(delta: float) -> void:
	_phase += delta * 3.0
	_behavior_t += delta
	if _eat_timer > 0.0:
		_eat_timer = maxf(0.0, _eat_timer - delta)
	if _clean_timer > 0.0:
		_clean_timer = maxf(0.0, _clean_timer - delta)
	if _moving:
		_walk += delta * 8.0
	if in_house and pet_type == "fish":
		position.x += sin(_behavior_t * 1.1) * 8.0 * delta
	if in_house and swung:
		position = _home + Vector2(-7.0, -14.0 + sin(_behavior_t * 2.2) * 1.6)
	elif in_house and hiding:
		position = _home + Vector2(-14.0, 2.0)
	elif in_house and shell:
		position = _home
	if not missing:
		queue_redraw()


## 跟随：高好感时缩短跟随距离，鸟 / 鱼 / 乌龟不跟随。
func follow(delta: float, player_position: Vector2) -> void:
	if not follows_player():
		return
	var follow_range := float(get_definition().get("follow_range", 2)) * TILE
	var to_player := player_position - position
	var distance := to_player.length()
	if distance <= follow_range:
		_moving = false
		return
	var speed := 26.0 if distance < 150.0 else 44.0
	var direction := to_player.normalized()
	position += direction * speed * delta
	if absf(direction.x) > 0.05:
		_facing = 1 if direction.x > 0.0 else -1
	_moving = true


func wander(delta: float, bounds: Rect2) -> void:
	if missing:
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = 2.0 + randf() * 4.0
		_wander_target = Vector2(
			randf_range(bounds.position.x + 16.0, bounds.end.x - 16.0),
			randf_range(bounds.position.y + 20.0, bounds.end.y - 8.0)
		)
	var speed := 12.0 if pet_type == "turtle" else 26.0
	var to_target := _wander_target - position
	if to_target.length() > 3.0:
		var direction := to_target.normalized()
		position += direction * speed * delta
		if absf(direction.x) > 0.05:
			_facing = 1 if direction.x > 0.0 else -1
		_moving = true
	else:
		_moving = false


## 展示型宠物在栖息地内的轻微动作（鸟晃、鱼游、龟爬）。
func idle_in_house(delta: float, anchor: Vector2) -> void:
	_home = anchor
	if pet_type == "fish":
		position = anchor + Vector2(sin(_behavior_t * 1.1) * 7.0, 0.0)
	elif pet_type == "bird":
		position = anchor + Vector2(0.0, sin(_behavior_t * 2.0) * 1.0)
	elif pet_type == "turtle":
		position = anchor + Vector2(sin(_behavior_t * 0.4) * 6.0, 0.0)
	else:
		position = anchor


# ============================================================
# 存档
# ============================================================

func to_save() -> Dictionary:
	return {
		"id": pet_id,
		"type": pet_type,
		"breed": breed,
		"name": pet_name,
		"x": position.x,
		"y": position.y,
		"is_rare": is_rare,
		"rare_color": rare_color,
		"rare_color_name": rare_color_name,
		"friendship": friendship,
		"hunger": hunger,
		"mood": mood,
		"cleanliness": cleanliness,
		"health": health,
		"sick": sick,
		"fed_today": fed_today,
		"petted_today": petted_today,
		"played_today": played_today,
		"cleaned_today": cleaned_today,
		"gift_ready": gift_ready,
		"gift": gift.duplicate(true),
		"house_id": house_id,
		"in_house": in_house,
		"following": following,
		"missing": missing,
		"missing_days": missing_days,
		"adopted_day": adopted_day,
		"name_changed": name_changed,
		"age_days": age_days,
		"walked_today": walked_today,
		"released": released,
		"release_timer": release_timer,
		"battled_today": battled_today,
	}


func from_save(data: Dictionary) -> void:
	var saved_type := str(data.get("type", "dog"))
	var saved_breed := str(data.get("breed", ""))
	if saved_breed.is_empty():
		saved_breed = _legacy_breed(saved_type, str(data.get("coat", "")))
	var definition := _resolve_breed(saved_breed)
	pet_type = str(definition.get("type_id", "dog"))
	breed = str(definition.get("id", "shiba"))
	pet_id = str(data.get("id", ""))
	pet_name = str(data.get("name", definition.get("name", breed)))
	position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	_home = position
	_wander_target = position
	is_rare = bool(data.get("is_rare", false))
	rare_color = str(data.get("rare_color", ""))
	rare_color_name = str(data.get("rare_color_name", ""))

	var config := DB.get_pet_config()
	friendship_max = float(config.get("friendship_max", 100))
	friendship = clampf(float(data.get("friendship", 20.0)), 0.0, friendship_max)
	var start: Dictionary = config.get("status", {}).get("start", {})
	hunger = clampf(float(data.get("hunger", start.get("hunger", 70))), 0.0, 100.0)
	mood = clampf(float(data.get("mood", start.get("mood", 70))), 0.0, 100.0)
	cleanliness = clampf(float(data.get("cleanliness", start.get("cleanliness", 80))), 0.0, 100.0)
	health = clampf(float(data.get("health", start.get("health", 100))), 0.0, 100.0)
	sick = bool(data.get("sick", false))
	fed_today = bool(data.get("fed_today", false))
	petted_today = bool(data.get("petted_today", false))
	played_today = bool(data.get("played_today", false))
	cleaned_today = bool(data.get("cleaned_today", false))
	gift_ready = bool(data.get("gift_ready", false))
	var saved_gift: Variant = data.get("gift", {})
	gift = saved_gift.duplicate(true) if saved_gift is Dictionary else {}
	house_id = str(data.get("house_id", ""))
	in_house = bool(data.get("in_house", not is_companion()))
	following = bool(data.get("following", is_companion()))
	missing = bool(data.get("missing", false))
	missing_days = int(data.get("missing_days", 0))
	adopted_day = int(data.get("adopted_day", 1))
	name_changed = bool(data.get("name_changed", false))
	age_days = maxi(0, int(data.get("age_days", 0)))
	walked_today = bool(data.get("walked_today", false))
	released = bool(data.get("released", false))
	release_timer = float(data.get("release_timer", 0.0))
	battled_today = bool(data.get("battled_today", false))
	visible = not missing
	queue_redraw()


func _legacy_breed(saved_type: String, coat: String) -> String:
	var map := {
		"dog": {"brown": "shiba", "cream": "golden_retriever", "gray": "husky"},
		"cat": {"tabby": "orange_cat", "white": "white_cat", "black": "black_cat"},
	}
	var table: Dictionary = map.get(saved_type, {})
	var mapped := str(table.get(coat, ""))
	if not mapped.is_empty():
		return mapped
	var type_entry := DB.get_pet_type(saved_type)
	var breeds: Array = type_entry.get("breeds", [])
	if not breeds.is_empty() and breeds[0] is Dictionary:
		return str((breeds[0] as Dictionary).get("id", ""))
	return "shiba"


# ============================================================
# 16px 绘制
# ============================================================

func _draw() -> void:
	if missing:
		return
	var bob := sin(_phase) * (0.5 if not _moving else 0.9)
	Art.shadow(self, 0, -0.4, 5.0, 1.6)
	draw_set_transform(Vector2(0, -bob), 0.0, Vector2(float(_facing), 1))

	var color := get_color()
	if sleeping and pet_type == "cat":
		_draw_sleeping_cat(color)
		_draw_status_icons()
		Art.reset_transform(self)
		return
	if shell and pet_type in ["turtle", "reptile"]:
		_draw_shell_only(color)
		_draw_status_icons()
		Art.reset_transform(self)
		return
	if hiding and pet_type in ["fish", "aquatic_extended"]:
		_draw_hiding_fish(color)
		_draw_status_icons()
		Art.reset_transform(self)
		return
	match _art_kind():
		"cat":
			_draw_cat(color)
		"bird":
			_draw_bird(color)
		"fish":
			_draw_fish(color)
		"turtle":
			_draw_turtle(color)
		"red_panda":
			_draw_red_panda(color)
		"rabbit":
			_draw_rabbit(color)
		"rodent":
			_draw_rodent(color)
		"hedgehog":
			_draw_hedgehog(color)
		"squirrel":
			_draw_squirrel(color)
		"ferret":
			_draw_ferret(color)
		"foal":
			_draw_quadruped(color, "foal")
		"lamb":
			_draw_quadruped(color, "lamb")
		"calf":
			_draw_quadruped(color, "calf")
		"pig":
			_draw_quadruped(color, "pig")
		"duck":
			_draw_waterfowl(color, false)
		"goose":
			_draw_waterfowl(color, true)
		"lizard":
			_draw_lizard(color)
		"snake":
			_draw_snake(color)
		"frog":
			_draw_frog(color)
		"salamander":
			_draw_salamander(color)
		"beetle", "butterfly", "mantis", "spider":
			_draw_insect(_art_kind(), color)
		"owl":
			_draw_owl(color)
		"fox":
			_draw_fox(color)
		"deer":
			_draw_deer(color)
		"otter":
			_draw_otter(color)
		"penguin":
			_draw_penguin(color)
		"seal":
			_draw_seal(color)
		"dragon":
			_draw_dragon(color)
		"seahorse":
			_draw_seahorse(color)
		"jellyfish":
			_draw_jellyfish(color)
		"crab":
			_draw_crab(color)
		"shrimp":
			_draw_shrimp(color)
		_:
			_draw_dog(color)

	if _art_kind() in ["dog", "cat", "red_panda"]:
		_draw_tail(color)
	if gift_ready:
		_draw_gift_bubble()
	_draw_status_icons()
	Art.reset_transform(self)


func _draw_sleeping_cat(body_color: Color) -> void:
	var dark := body_color.darkened(0.14)
	Art.ellipse(self, 0, -4.0, 4.6, 2.6, body_color)
	Art.ellipse(self, 2.6, -4.6, 2.4, 2.0, body_color)
	Art.ellipse(self, -2.4, -5.0, 1.6, 1.6, body_color.darkened(0.10))
	Art.rect(self, 2.6, -4.4, 0.9, 0.5, Color("#5a4a38"))
	Art.rect(self, 4.2, -4.4, 0.9, 0.5, Color("#5a4a38"))
	Art.ellipse(self, 4.0, -3.0, 0.8, 0.5, Color("#b57f74"))
	Art.rect(self, -4.8, -3.4, 3.0, 0.9, dark)


func _draw_shell_only(body_color: Color) -> void:
	var accent := get_accent()
	Art.ellipse(self, 0, -4.0, 4.8, 3.2, body_color.darkened(0.10))
	Art.ellipse(self, 0, -4.6, 3.6, 2.2, accent)
	for index in 3:
		Art.rect(self, -2.4 + float(index) * 2.0, -6.2, 0.7, 4.2,
			body_color.darkened(0.20))
	Art.rect(self, 5.2, -12.0, 0.9, 0.6, Color("#8a7862"))
	Art.rect(self, 6.3, -12.0, 0.9, 0.6, Color("#8a7862"))
	Art.rect(self, 7.4, -12.0, 0.9, 0.6, Color("#8a7862"))


func _draw_hiding_fish(body_color: Color) -> void:
	for index in 3:
		var x := -6.0 + float(index) * 2.0
		Art.rect(self, x, -10.0, 0.8, 7.0, Color("#6f9a60"))
	Art.rect(self, -2.0, -5.0, 1.2, 1.6, body_color)
	Art.poly(self, PackedVector2Array([
		Vector2(-0.8, -5.0), Vector2(1.4, -6.2), Vector2(1.4, -3.8),
	]), get_accent())
	Art.ellipse(self, -1.0, -9.0, 0.6, 0.6, Color(0.8, 0.9, 0.95, 0.6))


func _draw_tail(body_color: Color) -> void:
	if pet_type == "red_panda":
		var wag := sin(_phase * 4.0) * (2.2 if _moving else 1.2)
		var base := Vector2(-4.8, -7.0)
		var tip := base + Vector2(-3.0 + wag * 0.4, 1.0 + wag)
		draw_line(base, tip, get_accent(), 2.2, false)
		draw_line(tip, tip + Vector2(-1.6, 0.6), body_color, 2.0, false)
		return
	if pet_type == "dog":
		var kind := str(get_definition().get("tail", "long"))
		if kind == "curly":
			Art.ellipse(self, -5.4, -8.6, 1.2, 1.2, body_color)
			Art.ellipse(self, -6.0, -9.6, 0.9, 0.9, body_color.darkened(0.12))
		elif kind == "short":
			Art.ellipse(self, -5.0, -8.0, 1.0, 0.9, body_color)
		else:
			var wag := sin(_phase * 9.0) * (2.0 if _moving else 1.0)
			draw_line(Vector2(-4.6, -7.6),
				Vector2(-6.2 + wag * 0.5, -11.0 + wag),
				body_color.darkened(0.12), 1.2, false)
			draw_circle(Vector2(-6.2 + wag * 0.5, -11.0 + wag), 0.9, body_color)
		return
	if pet_type == "cat":
		if str(get_definition().get("tail", "up")) == "long":
			for index in 3:
				Art.ellipse(self, -4.6 - float(index) * 0.9,
					-6.4 - float(index) * 1.3, 1.4, 1.4, body_color)
		else:
			var wag := sin(_phase * 4.0) * 1.2
			Art.rect(self, -5.0, -9.6, 1.2, 4.0, body_color)
			Art.rect(self, -5.8 + wag * 0.3, -10.8, 1.4, 1.4, body_color)


func _draw_gift_bubble() -> void:
	Art.ellipse(self, 0, -18, 2.6, 2.2, Color(1.0, 0.97, 0.90, 0.55))
	Art.ellipse(self, 0, -18.4, 2.0, 1.8, Color("#f7f0dd"))
	var item_id := str(gift.get("item_id", ""))
	if item_id.begins_with("wild") or item_id == "branch":
		Art.rect(self, -1.0, -19.4, 2.0, 2.0, Color("#b57f74"))
	else:
		Art.ellipse(self, 0, -18.4, 1.2, 1.4, Color("#8fadc0"))


## 状态提示：病气泡 / 饥饿 / 脏污。
func _draw_status_icons() -> void:
	if sick:
		Art.ellipse(self, 0, -18.0, 2.4, 2.0, Color(0.72, 0.85, 0.90, 0.85))
		Art.rect(self, -1.0, -18.8, 2.0, 0.7, Color("#5f97b0"))
		Art.rect(self, -0.35, -18.1, 0.7, 1.4, Color("#5f97b0"))
	elif hunger < 20.0:
		Art.rect(self, -1.3, -18.6, 2.6, 2.6, Color("#e8d7b8"))
		Art.rect(self, -0.4, -18.0, 0.8, 1.2, Color("#c4553f"))
		Art.rect(self, -0.4, -16.4, 0.8, 0.8, Color("#c4553f"))
	elif cleanliness < 20.0:
		for index in 2:
			var x := -1.8 + float(index) * 2.2
			Art.rect(self, x, -17.4, 0.8, 2.8, Color(0.55, 0.70, 0.48, 0.75))
	if sleeping:
		Art.rect(self, 5.0, -16.0, 2.0, 0.6, Color("#5a4a38"))
		Art.rect(self, 5.6, -18.0, 2.4, 0.6, Color("#5a4a38"))
		Art.rect(self, 6.2, -20.0, 2.8, 0.6, Color("#5a4a38"))
	if basking:
		Art.ellipse(self, -6.0, -18.0, 1.8, 1.8, Color("#e8c95a"))
		for index in 4:
			var angle := TAU * float(index) / 4.0
			Art.rect(self, -6.0 + cos(angle) * 2.6 - 0.3,
				-18.0 + sin(angle) * 2.6 - 0.3, 0.6, 0.6, Color("#e8c95a"))
	if _eat_timer > 0.0:
		Art.rect(self, 3.0, -6.0, 0.8, 0.8, Color("#c9a276"))
		Art.rect(self, 4.4, -5.4, 0.6, 0.6, Color("#c9a276"))
	if _clean_timer > 0.0:
		var t := 1.0 - clampf(_clean_timer / 0.9, 0.0, 1.0)
		for index in 3:
			var sx := -5.0 + float(index) * 4.0
			var sy := -12.0 - t * 8.0 - float(index) * 2.0
			Art.rect(self, sx, sy, 0.8, 2.0, Color(1.0, 0.95, 0.75, 1.0 - t))
			Art.rect(self, sx - 0.6, sy + 0.6, 2.0, 0.8,
				Color(1.0, 0.95, 0.75, 1.0 - t))


func _draw_dog(body_color: Color) -> void:
	var definition := get_definition()
	var accent := get_accent()
	var dark := body_color.darkened(0.14)
	var step := sin(_walk) * 0.8 if _moving else 0.0
	var short := str(definition.get("build", "")) == "short"
	var leg_len := 2.1 if short else 3.0

	Art.rect(self, -3.0, -leg_len + step, 1.2, leg_len, dark)
	Art.rect(self, -0.8, -leg_len - step, 1.2, leg_len, dark)
	Art.rect(self, 1.8, -leg_len + step, 1.2, leg_len, dark)

	Art.rrect(self, -4.0, -8.0, 8.0, 5.2, 2.2, body_color)
	Art.rrect(self, 2.6, -12.0, 5.2, 4.6, 1.8, body_color)
	var fluffy := bool(definition.get("fluffy", false)) \
		or str(definition.get("id", "")) in ["samoyed", "poodle", "border_collie"]
	if fluffy:
		Art.ellipse(self, -2.2, -7.2, 2.4, 1.8, accent)
		Art.ellipse(self, 2.0, -7.4, 2.2, 1.7, accent)
		Art.ellipse(self, 2.2, -11.6, 1.6, 1.4, accent)
	if str(definition.get("id", "")) == "border_collie":
		Art.rect(self, 5.2, -11.8, 1.6, 3.8, accent)
	if bool(definition.get("mask", false)):
		Art.rrect(self, 3.4, -10.6, 4.2, 2.8, 1.2, accent)
	var floppy := str(definition.get("ears", "pointy")) == "floppy"
	if floppy:
		Art.rrect(self, 2.2, -12.4, 1.8, 3.2, 0.9, accent)
		Art.rrect(self, 6.6, -12.4, 1.8, 3.2, 0.9, accent)
	else:
		Art.poly(self, PackedVector2Array([
			Vector2(2.6, -11.8), Vector2(3.2, -14.2), Vector2(4.4, -11.8),
		]), dark)
		Art.poly(self, PackedVector2Array([
			Vector2(6.0, -11.8), Vector2(7.0, -14.2), Vector2(7.8, -11.8),
		]), dark)
	Art.ellipse(self, 7.4, -9.2, 1.4, 1.0, accent)
	Art.rect(self, 8.4, -9.6, 0.8, 0.8, dark)
	Art.rect(self, 5.6, -10.8, 0.8, 0.9, Color("#5a4a38"))
	Art.rect(self, 3.0, -8.4, 4.0, 0.8, Color("#a8735c"))


func _draw_cat(body_color: Color) -> void:
	var definition := get_definition()
	var accent := get_accent()
	var dark := body_color.darkened(0.14)
	var step := sin(_walk) * 0.7 if _moving else 0.0

	Art.rect(self, -2.8, -2.6 + step, 1.0, 2.6, dark)
	Art.rect(self, -0.6, -2.6 - step, 1.0, 2.6, dark)
	Art.rect(self, 1.6, -2.6 + step, 1.0, 2.6, dark)

	Art.rrect(self, -3.6, -7.2, 7.6, 4.6, 2.0, body_color)
	if bool(definition.get("patches", false)):
		Art.ellipse(self, -1.4, -5.8, 1.8, 1.2, accent)
		Art.ellipse(self, 1.4, -6.4, 1.2, 0.9, Color("#5f5a54"))
	if bool(definition.get("stripes", false)):
		for index in 2:
			Art.rect(self, -2.2 + float(index) * 1.6, -7.0, 0.6, 3.4,
				body_color.darkened(0.18))
	if bool(definition.get("fluffy", false)) or "maine_coon" in breed:
		Art.ellipse(self, -1.8, -6.6, 2.4, 1.8, accent)
		Art.ellipse(self, 2.2, -7.6, 2.0, 1.6, accent)
	Art.rrect(self, 2.4, -11.2, 5.0, 4.4, 1.8, body_color)
	if bool(definition.get("mask", false)):
		Art.rect(self, 3.2, -9.2, 3.4, 1.6, Color("#5f4a3a"))
	if str(definition.get("ears", "pointy")) == "floppy":
		Art.rrect(self, 2.2, -11.0, 1.8, 2.4, 0.8, dark)
		Art.rrect(self, 6.0, -11.0, 1.8, 2.4, 0.8, dark)
	else:
		Art.poly(self, PackedVector2Array([
			Vector2(2.8, -11.0), Vector2(3.6, -13.4), Vector2(4.6, -11.0),
		]), body_color)
		Art.poly(self, PackedVector2Array([
			Vector2(5.4, -11.0), Vector2(6.4, -13.4), Vector2(7.2, -11.0),
		]), body_color)
	Art.rect(self, 4.8, -9.8, 0.8, 1.0, Color("#5a4a38"))
	Art.rect(self, 6.6, -9.8, 0.8, 1.0, Color("#5a4a38"))
	Art.rect(self, 6.0, -8.6, 0.8, 0.6, Color("#b57f74"))
	Art.rect(self, 7.0, -8.4, 1.6, 0.4, Color(0.45, 0.40, 0.34, 0.5))


func _draw_bird(body_color: Color) -> void:
	var accent := get_accent()
	var tail_long := str(get_definition().get("tail", "")) == "long"
	Art.ellipse(self, 0, -6.0, 2.8, 2.4, body_color)
	Art.ellipse(self, 2.0, -9.2, 1.8, 1.8, body_color)
	if breed == "cockatiel":
		Art.rect(self, 2.2, -12.8, 0.8, 3.6, accent)
		Art.ellipse(self, 0.6, -8.8, 0.9, 0.9, Color("#e8a05e"))
	elif breed == "lovebird":
		Art.ellipse(self, 0.4, -8.6, 1.0, 0.9, accent)
	elif breed == "finch":
		Art.rect(self, 3.6, -9.2, 1.4, 0.8, Color("#c95f4f"))
	Art.rect(self, 3.6, -9.2, 1.4, 0.8, accent)
	Art.rect(self, 2.6, -9.8, 0.7, 0.8, Color("#2f2622"))
	Art.rect(self, -2.2, -7.4, 2.6 if tail_long else 1.8, 1.0, accent)
	Art.rect(self, -0.8, -3.8, 0.6, 1.8, Color("#c9a276"))
	Art.rect(self, 0.8, -3.8, 0.6, 1.8, Color("#c9a276"))
	if bool(get_type_definition().get("special_behavior", "") == "sing") \
			and friendship >= 50.0 and fmod(_behavior_t, 6.0) < 1.2:
		Art.rect(self, 4.4, -13.0, 1.0, 2.4, Color("#5a4a38"))
		Art.ellipse(self, 4.9, -13.8, 1.0, 0.7, Color("#5a4a38"))


func _draw_fish(body_color: Color) -> void:
	var accent := get_accent()
	var swim := sin(_behavior_t * 2.2) * 0.8
	var rx := 3.4
	var ry := 2.0
	if "discus" in breed:
		rx = 3.8
		ry = 3.0
	elif "angelfish" in breed:
		rx = 2.8
		ry = 2.9
	elif "koi" in breed or "goldfish" in breed:
		rx = 3.8
	Art.ellipse(self, 0, -7.0, rx, ry, body_color)
	if "neon" in breed:
		Art.rect(self, -2.4, -7.8, 4.8, 0.6, Color("#5f97d8"))
		Art.rect(self, -2.4, -7.0, 4.8, 0.5, Color("#c4553f"))
	elif "koi" in breed:
		Art.ellipse(self, -1.2, -7.0, 1.2, 0.9, accent)
		Art.ellipse(self, 1.4, -6.4, 0.8, 0.6, Color("#3f3a36"))
	elif "discus" in breed:
		Art.rect(self, -2.0, -8.6, 4.0, 0.8, accent)
	Art.poly(self, PackedVector2Array([
		Vector2(-3.0, -7.0), Vector2(-5.6, -9.0 + swim),
		Vector2(-5.6, -5.0 - swim),
	]), accent)
	Art.poly(self, PackedVector2Array([
		Vector2(0.0, -9.0), Vector2(1.6, -10.8 + swim), Vector2(2.0, -8.6),
	]), accent)
	Art.rect(self, 2.0, -7.6, 0.7, 0.7, Color("#2f2622"))
	Art.rect(self, -1.4, -7.4, 1.6, 0.8, Color(1.0, 1.0, 1.0, 0.25))


func _draw_turtle(body_color: Color) -> void:
	var accent := get_accent()
	var shell_ry := 3.6 if "box_turtle" in breed else 3.0
	Art.ellipse(self, 0, -4.2, 4.8, shell_ry, body_color)
	Art.ellipse(self, 0, -4.8, 3.4, 1.8, accent)
	for index in 3:
		Art.rect(self, -2.2 + float(index) * 1.8, -6.4, 0.6, 3.4,
			body_color.darkened(0.20))
	Art.ellipse(self, 4.6, -3.6, 1.6, 1.3, Color("#8a9a62"))
	Art.rect(self, 5.6, -3.8, 0.6, 0.6, Color("#2f2622"))
	if "red_eared" in breed:
		Art.rect(self, 5.0, -4.2, 1.1, 0.8, Color("#c4553f"))
	Art.rect(self, -2.8, -1.6, 1.2, 1.6, Color("#8a9a62"))
	Art.rect(self, 1.6, -1.6, 1.2, 1.6, Color("#8a9a62"))
	Art.rect(self, -0.6, -7.6, 1.2, 0.8, accent)


## 根据类别 / 品种选择绘制形态，新增品种无需改核心逻辑。
func _art_kind() -> String:
	var id := breed
	match pet_type:
		"dog":
			return "dog"
		"cat":
			return "cat"
		"bird":
			return "bird"
		"red_panda":
			return "red_panda"
		"fish":
			return "fish"
		"turtle":
			return "turtle"
		"rabbit":
			return "rabbit"
		"hamster", "guinea_pig", "chinchilla":
			return "rodent"
		"hedgehog":
			return "hedgehog"
		"squirrel":
			return "squirrel"
		"ferret":
			return "ferret"
		"young_livestock":
			if "duckling" in id:
				return "duck"
			if "gosling" in id:
				return "goose"
			if "lamb" in id:
				return "lamb"
			if "calf" in id:
				return "calf"
			if "piglet" in id:
				return "pig"
			return "foal"
		"reptile":
			if "snake" in id or "python" in id:
				return "snake"
			if "frog" in id or "toad" in id:
				return "frog"
			if "axolotl" in id or "newt" in id or "salamander" in id:
				return "salamander"
			if "tortoise" in id or "hermann" in id or "sulcata" in id:
				return "turtle"
			return "lizard"
		"insect":
			if "butterfly" in id:
				return "butterfly"
			if "mantis" in id:
				return "mantis"
			if "spider" in id:
				return "spider"
			if "hermit" in id:
				return "crab"
			return "beetle"
		"special":
			if "owl" in id:
				return "owl"
			if "fox" in id:
				return "fox"
			if "deer" in id or "muntjac" in id:
				return "deer"
			if "otter" in id:
				return "otter"
			if "penguin" in id:
				return "penguin"
			if "seal" in id:
				return "seal"
			if "dragon" in id:
				return "dragon"
			return "owl"
		"aquatic_extended":
			if "seahorse" in id:
				return "seahorse"
			if "jellyfish" in id:
				return "jellyfish"
			if "crab" in id:
				return "crab"
			if "shrimp" in id:
				return "shrimp"
			return "fish"
	return "dog"


func _draw_rabbit(body_color: Color) -> void:
	var dark := body_color.darkened(0.14)
	var accent := get_accent()
	var step := sin(_walk) * 0.6 if _moving else 0.0
	Art.rect(self, -2.6, -2.4 + step, 1.0, 2.4, dark)
	Art.rect(self, -0.4, -2.4 - step, 1.0, 2.4, dark)
	Art.rect(self, 1.6, -2.4 + step, 1.0, 2.4, dark)
	Art.ellipse(self, 0, -5.6, 3.4, 3.0, body_color)
	var fluffy := str(get_definition().get("build", "")) == "fluffy" \
		or "angora" in breed or "lionhead" in breed
	if fluffy:
		Art.ellipse(self, -2.2, -6.2, 2.2, 1.8, accent)
		Art.ellipse(self, 2.2, -6.8, 1.8, 1.6, accent)
	Art.ellipse(self, 2.6, -7.4, 2.4, 2.2, body_color)
	if str(get_definition().get("ears", "pointy")) == "floppy":
		Art.rect(self, 1.4, -8.6, 3.0, 1.2, body_color)
		Art.rect(self, 3.8, -8.6, 2.6, 1.2, body_color)
		Art.rect(self, 1.6, -8.4, 2.6, 0.5, Color("#e8b0b0"))
		Art.rect(self, 4.0, -8.4, 2.2, 0.5, Color("#e8b0b0"))
	else:
		Art.rect(self, 1.8, -11.0, 1.4, 4.0, body_color)
		Art.rect(self, 4.0, -11.0, 1.4, 4.0, body_color)
		Art.rect(self, 2.1, -10.2, 0.8, 2.6, Color("#e8b0b0"))
		Art.rect(self, 4.3, -10.2, 0.8, 2.6, Color("#e8b0b0"))
	if "lionhead" in breed:
		Art.ellipse(self, 2.0, -8.4, 2.4, 1.8, accent)
	Art.rect(self, 4.2, -7.6, 0.7, 0.8, Color("#2f2622"))
	Art.ellipse(self, -3.8, -4.6, 1.2, 1.2, Color("#f7f0dd"))


func _draw_rodent(body_color: Color) -> void:
	var dark := body_color.darkened(0.14)
	Art.ellipse(self, 0, -4.6, 3.0, 2.6, body_color)
	Art.ellipse(self, 2.4, -6.2, 2.0, 1.8, body_color)
	Art.ellipse(self, 2.0, -7.6, 0.9, 0.9, dark)
	Art.ellipse(self, 3.6, -7.6, 0.9, 0.9, dark)
	Art.rect(self, 4.0, -6.4, 0.7, 0.7, Color("#2f2622"))
	Art.rect(self, -3.4, -4.2, 1.4, 0.8, dark)
	Art.rect(self, 0.6, -2.2, 1.0, 2.2, dark)
	Art.rect(self, 2.2, -2.2, 1.0, 2.2, dark)


func _draw_hedgehog(body_color: Color) -> void:
	var dark := body_color.darkened(0.22)
	Art.ellipse(self, 0, -4.6, 3.6, 2.8, dark)
	for index in 6:
		var x := -3.0 + float(index) * 1.2
		Art.poly(self, PackedVector2Array([
			Vector2(x, -5.6), Vector2(x + 0.6, -8.2), Vector2(x + 1.2, -5.6),
		]), body_color)
	Art.ellipse(self, 2.8, -4.4, 1.8, 1.4, Color("#d9b48a"))
	Art.rect(self, 3.6, -4.6, 0.7, 0.7, Color("#2f2622"))
	Art.rect(self, -1.0, -2.2, 1.0, 2.2, dark)
	Art.rect(self, 1.0, -2.2, 1.0, 2.2, dark)


func _draw_squirrel(body_color: Color) -> void:
	_draw_rodent(body_color)
	var accent := get_accent()
	Art.ellipse(self, -4.2, -7.0, 2.4, 3.4, body_color)
	Art.ellipse(self, -5.0, -9.2, 1.6, 2.0, accent)


func _draw_ferret(body_color: Color) -> void:
	var dark := body_color.darkened(0.14)
	Art.ellipse(self, 0, -4.4, 4.2, 2.2, body_color)
	Art.ellipse(self, 3.4, -5.4, 2.0, 1.6, body_color)
	Art.rect(self, 4.8, -5.6, 0.7, 0.7, Color("#2f2622"))
	Art.rect(self, -4.2, -5.0, 2.4, 1.0, dark)
	Art.rect(self, -1.4, -2.2, 1.0, 2.2, dark)
	Art.rect(self, 1.4, -2.2, 1.0, 2.2, dark)


func _draw_quadruped(body_color: Color, kind: String) -> void:
	var dark := body_color.darkened(0.14)
	var accent := get_accent()
	var body_y := -7.0
	var leg_h := 4.0
	if kind == "lamb":
		Art.rect(self, -4.0, body_y + 2.6, 1.4, leg_h, dark)
		Art.rect(self, 2.6, body_y + 2.6, 1.4, leg_h, dark)
		Art.ellipse(self, 0, body_y, 5.0, 3.2, body_color)
		Art.ellipse(self, -2.4, body_y - 1.0, 3.0, 2.0, accent)
		Art.ellipse(self, 3.6, body_y - 1.6, 2.2, 2.0, body_color)
		Art.rect(self, 4.4, body_y - 2.4, 0.7, 0.7, Color("#2f2622"))
	elif kind == "calf":
		Art.rect(self, -4.6, body_y + 2.2, 1.6, 4.8, dark)
		Art.rect(self, 2.8, body_y + 2.2, 1.6, 4.8, dark)
		Art.ellipse(self, 0, body_y, 6.0, 3.4, body_color)
		Art.ellipse(self, -1.6, body_y - 0.8, 1.6, 1.4, accent)
		Art.ellipse(self, 1.8, body_y + 0.4, 1.2, 1.0, accent)
		Art.rect(self, 4.2, body_y - 2.6, 3.6, 3.0, body_color)
		Art.rect(self, 6.8, body_y - 2.0, 0.8, 0.8, Color("#2f2622"))
	elif kind == "pig":
		Art.rect(self, -3.6, body_y + 2.0, 1.4, 3.6, dark)
		Art.rect(self, 2.2, body_y + 2.0, 1.4, 3.6, dark)
		Art.ellipse(self, 0, body_y - 0.4, 4.8, 3.2, body_color)
		Art.ellipse(self, 3.6, body_y - 1.6, 2.4, 2.2, body_color)
		Art.ellipse(self, 5.2, body_y - 1.4, 1.2, 1.0, accent)
		Art.poly(self, PackedVector2Array([
			Vector2(2.4, body_y - 3.2), Vector2(3.0, body_y - 4.8),
			Vector2(4.0, body_y - 3.0),
		]), dark)
		Art.rect(self, 4.4, body_y - 2.6, 0.7, 0.7, Color("#2f2622"))
	else:
		Art.rect(self, -3.6, body_y + 2.0, 1.4, 5.0, dark)
		Art.rect(self, 2.2, body_y + 2.0, 1.4, 5.0, dark)
		Art.ellipse(self, 0, body_y - 0.6, 5.0, 3.0, body_color)
		Art.rect(self, 3.4, body_y - 5.0, 2.0, 4.0, body_color)
		Art.rect(self, 4.4, body_y - 6.2, 3.4, 2.4, body_color)
		Art.rect(self, 4.2, body_y - 5.6, 1.4, 0.8, dark)
		Art.rect(self, 6.8, body_y - 5.4, 0.7, 0.7, Color("#2f2622"))


func _draw_waterfowl(body_color: Color, goose: bool) -> void:
	var accent := get_accent()
	var bob := sin(_phase * 2.0) * 0.4
	Art.ellipse(self, 0, -4.6 + bob, 3.4, 2.4, body_color)
	Art.rect(self, 2.0, -9.0 + bob, 1.6, 4.6, body_color)
	Art.ellipse(self, 2.8, -10.0 + bob, 1.8, 1.6, body_color)
	Art.rect(self, 4.4, -9.8 + bob, 1.8, 0.8, accent)
	Art.rect(self, 2.8, -10.4 + bob, 0.7, 0.8, Color("#2f2622"))
	Art.rect(self, -1.2, -2.2, 0.8, 2.0, Color("#d9a05e"))
	Art.rect(self, 0.8, -2.2, 0.8, 2.0, Color("#d9a05e"))
	if goose:
		Art.rect(self, -1.6, -7.4 + bob, 2.0, 3.0, body_color)


func _draw_lizard(body_color: Color) -> void:
	var dark := body_color.darkened(0.18)
	Art.ellipse(self, 0, -4.0, 4.0, 1.8, body_color)
	Art.ellipse(self, 4.0, -4.4, 1.8, 1.4, body_color)
	Art.rect(self, 5.2, -4.6, 0.7, 0.7, Color("#2f2622"))
	for index in 4:
		var x := -3.0 + float(index) * 2.0
		Art.rect(self, x, -2.2, 0.8, 2.2, dark)
	Art.rect(self, -4.0, -4.6, 3.0, 1.0, dark)


func _draw_snake(body_color: Color) -> void:
	var accent := get_accent()
	Art.ellipse(self, -1.8, -3.0, 3.2, 2.0, body_color)
	Art.ellipse(self, 1.6, -4.4, 2.6, 1.8, body_color)
	Art.ellipse(self, 4.2, -4.8, 1.8, 1.4, body_color)
	Art.rect(self, 5.2, -5.0, 0.7, 0.7, Color("#2f2622"))
	Art.rect(self, 3.0, -3.8, 1.2, 0.6, accent)
	Art.rect(self, -4.6, -2.4, 2.0, 0.8, body_color)


func _draw_frog(body_color: Color) -> void:
	Art.ellipse(self, 0, -3.6, 4.0, 2.8, body_color)
	Art.ellipse(self, -1.8, -6.4, 1.4, 1.4, body_color)
	Art.ellipse(self, 1.8, -6.4, 1.4, 1.4, body_color)
	Art.rect(self, -2.2, -6.8, 0.8, 0.8, Color("#2f2622"))
	Art.rect(self, 1.4, -6.8, 0.8, 0.8, Color("#2f2622"))
	Art.rect(self, -3.4, -1.2, 1.4, 1.6, body_color)
	Art.rect(self, 2.0, -1.2, 1.4, 1.6, body_color)


func _draw_salamander(body_color: Color) -> void:
	_draw_lizard(body_color)
	var accent := get_accent()
	for index in 3:
		Art.rect(self, 3.6 + float(index) * 0.8, -6.2, 0.6, 2.0, accent)


func _draw_insect(kind: String, body_color: Color) -> void:
	var accent := get_accent()
	if kind == "butterfly":
		var flap := absf(sin(_phase * 4.0)) * 1.6
		Art.ellipse(self, -2.4, -6.0, 2.4, 2.0 + flap, body_color)
		Art.ellipse(self, 2.4, -6.0, 2.4, 2.0 + flap, body_color)
		Art.rect(self, -0.5, -8.0, 1.0, 5.0, Color("#3f3a36"))
		Art.rect(self, 1.2, -6.0, 1.2, 1.0, accent)
	elif kind == "mantis":
		Art.rect(self, -0.6, -9.0, 1.2, 8.0, body_color)
		Art.rect(self, -2.2, -7.0, 1.8, 0.8, body_color)
		Art.rect(self, 0.4, -7.0, 1.8, 0.8, body_color)
		Art.ellipse(self, 0, -9.6, 1.2, 1.0, body_color)
	elif kind == "spider":
		Art.ellipse(self, 0, -3.6, 2.4, 2.0, body_color)
		Art.ellipse(self, 0, -6.0, 1.4, 1.2, body_color)
		for index in 4:
			var x := -2.0 + float(index) * 1.4
			Art.rect(self, x, -2.4, 0.6, 2.4, accent)
			Art.rect(self, x, -5.2, 0.6, 2.0, accent)
	else:
		Art.ellipse(self, 0, -4.0, 3.0, 2.2, body_color)
		Art.rect(self, -0.4, -6.4, 1.2, 2.4, body_color)
		Art.rect(self, -1.6, -6.8, 1.0, 0.6, accent)
		Art.rect(self, 0.6, -6.8, 1.0, 0.6, accent)
		for index in 3:
			Art.rect(self, -2.8 + float(index) * 2.2, -2.2, 0.6, 2.2, accent)


func _draw_owl(body_color: Color) -> void:
	var accent := get_accent()
	Art.ellipse(self, 0, -5.0, 3.2, 3.8, body_color)
	Art.ellipse(self, 0, -7.4, 1.6, 1.4, accent)
	Art.ellipse(self, 0, -10.2, 3.0, 2.6, body_color)
	Art.ellipse(self, -1.2, -10.4, 1.0, 1.0, accent)
	Art.ellipse(self, 1.2, -10.4, 1.0, 1.0, accent)
	Art.rect(self, -1.4, -10.6, 0.6, 0.6, Color("#2f2622"))
	Art.rect(self, 0.8, -10.6, 0.6, 0.6, Color("#2f2622"))
	Art.rect(self, -0.4, -9.4, 0.8, 0.8, Color("#d9a05e"))
	Art.rect(self, -4.0, -11.6, 1.0, 1.6, body_color)
	Art.rect(self, 3.0, -11.6, 1.0, 1.6, body_color)
	Art.rect(self, -1.8, -1.2, 1.2, 1.2, Color("#d9a05e"))
	Art.rect(self, 0.6, -1.2, 1.2, 1.2, Color("#d9a05e"))


func _draw_fox(body_color: Color) -> void:
	var accent := get_accent()
	Art.ellipse(self, 0, -5.0, 3.6, 2.6, body_color)
	Art.ellipse(self, 3.0, -6.6, 2.2, 2.0, body_color)
	Art.poly(self, PackedVector2Array([
		Vector2(2.0, -7.4), Vector2(2.4, -10.0), Vector2(3.6, -7.8),
	]), body_color)
	Art.poly(self, PackedVector2Array([
		Vector2(4.4, -7.6), Vector2(5.4, -9.8), Vector2(5.8, -7.2),
	]), body_color)
	Art.rect(self, 4.4, -6.8, 0.7, 0.7, Color("#2f2622"))
	Art.ellipse(self, -4.2, -7.0, 2.6, 2.2, body_color)
	Art.ellipse(self, -5.4, -8.2, 1.6, 1.4, accent)
	Art.rect(self, -1.4, -2.2, 1.2, 2.2, body_color.darkened(0.15))
	Art.rect(self, 1.2, -2.2, 1.2, 2.2, body_color.darkened(0.15))


func _draw_deer(body_color: Color) -> void:
	var accent := get_accent()
	Art.ellipse(self, 0, -6.0, 4.6, 2.8, body_color)
	for index in 4:
		Art.rect(self, -3.4 + float(index) * 2.2, -3.4, 0.8, 3.4,
			body_color.darkened(0.15))
	Art.rect(self, 3.6, -9.0, 2.0, 4.0, body_color)
	Art.ellipse(self, 4.8, -10.0, 1.8, 1.6, body_color)
	Art.rect(self, 4.6, -13.0, 0.7, 3.0, accent)
	Art.rect(self, 6.0, -13.0, 0.7, 3.0, accent)
	Art.rect(self, 3.8, -13.0, 1.6, 0.7, accent)
	Art.rect(self, 5.6, -13.0, 1.6, 0.7, accent)
	Art.rect(self, 5.6, -9.8, 0.7, 0.7, Color("#2f2622"))


func _draw_otter(body_color: Color) -> void:
	var accent := get_accent()
	Art.ellipse(self, 0, -3.6, 4.4, 1.8, body_color)
	Art.ellipse(self, 3.8, -4.4, 1.8, 1.4, body_color)
	Art.rect(self, 5.2, -4.6, 0.7, 0.7, Color("#2f2622"))
	Art.ellipse(self, -4.2, -3.4, 2.2, 1.0, accent)
	Art.rect(self, -1.0, -1.6, 0.8, 1.6, body_color.darkened(0.15))


func _draw_penguin(body_color: Color) -> void:
	var accent := get_accent()
	Art.ellipse(self, 0, -5.0, 2.8, 4.4, body_color)
	Art.ellipse(self, 0, -4.4, 1.8, 3.2, accent)
	Art.ellipse(self, 0, -9.8, 2.0, 1.8, body_color)
	Art.rect(self, 1.6, -9.8, 1.4, 0.8, Color("#d9a05e"))
	Art.rect(self, 0.0, -10.2, 0.6, 0.6, Color("#2f2622"))
	Art.rect(self, -2.4, -0.8, 1.6, 0.8, Color("#d9a05e"))
	Art.rect(self, 0.8, -0.8, 1.6, 0.8, Color("#d9a05e"))


func _draw_seal(body_color: Color) -> void:
	var accent := get_accent()
	Art.ellipse(self, 0, -3.6, 4.4, 2.4, body_color)
	Art.ellipse(self, 2.8, -4.8, 2.2, 1.8, body_color)
	Art.rect(self, 4.2, -5.0, 0.7, 0.7, Color("#2f2622"))
	Art.ellipse(self, -3.0, -2.8, 1.6, 1.0, accent)
	Art.ellipse(self, 0.2, -2.6, 1.4, 0.8, accent)


func _draw_dragon(body_color: Color) -> void:
	var accent := get_accent()
	Art.ellipse(self, 0, -4.8, 3.4, 2.6, body_color)
	Art.ellipse(self, 3.2, -6.4, 2.2, 1.8, body_color)
	Art.poly(self, PackedVector2Array([
		Vector2(-2.0, -6.0), Vector2(-5.0, -10.0), Vector2(-1.0, -8.0),
	]), accent)
	Art.poly(self, PackedVector2Array([
		Vector2(1.0, -6.4), Vector2(4.0, -10.6), Vector2(4.4, -7.0),
	]), accent)
	Art.rect(self, 4.2, -7.4, 0.7, 0.7, Color("#2f2622"))
	Art.rect(self, 3.4, -8.6, 0.8, 1.0, Color("#e8c95a"))
	Art.rect(self, 4.8, -8.6, 0.8, 1.0, Color("#e8c95a"))
	Art.rect(self, -4.0, -5.2, 3.0, 0.8, body_color.darkened(0.15))
	Art.ellipse(self, -0.6, -3.2, 1.0, 0.8, Color("#f7f0dd"))


func _draw_seahorse(body_color: Color) -> void:
	var accent := get_accent()
	Art.ellipse(self, 0, -5.0, 1.6, 3.0, body_color)
	Art.ellipse(self, 0.8, -8.0, 1.4, 1.2, body_color)
	Art.rect(self, 1.6, -8.2, 1.4, 0.7, accent)
	Art.rect(self, 1.0, -8.4, 0.6, 0.6, Color("#2f2622"))
	Art.ellipse(self, -0.8, -2.4, 1.2, 1.0, body_color)
	Art.rect(self, -1.6, -2.0, 1.2, 0.6, accent)


func _draw_jellyfish(body_color: Color) -> void:
	var accent := get_accent()
	var pulse := sin(_phase * 2.0) * 0.6
	Art.ellipse(self, 0, -7.0 + pulse, 3.4, 2.4, body_color)
	Art.ellipse(self, 0, -7.4 + pulse, 2.2, 1.4, accent)
	for index in 4:
		var x := -2.0 + float(index) * 1.4
		Art.rect(self, x, -4.6 + pulse, 0.5, 3.0, accent)


func _draw_crab(body_color: Color) -> void:
	var accent := get_accent()
	Art.ellipse(self, 0, -3.6, 3.2, 2.2, body_color)
	Art.ellipse(self, -4.0, -4.8, 1.4, 1.6, accent)
	Art.ellipse(self, 4.0, -4.8, 1.4, 1.6, accent)
	Art.rect(self, -1.6, -5.6, 0.7, 0.7, Color("#2f2622"))
	Art.rect(self, 0.8, -5.6, 0.7, 0.7, Color("#2f2622"))
	for index in 3:
		Art.rect(self, -3.0 + float(index) * 2.4, -2.0, 0.6, 2.0, accent)


func _draw_shrimp(body_color: Color) -> void:
	var accent := get_accent()
	Art.ellipse(self, 0, -4.0, 2.6, 1.6, body_color)
	Art.ellipse(self, 2.0, -4.8, 1.2, 1.0, body_color)
	Art.rect(self, 3.2, -5.0, 1.8, 0.5, accent)
	Art.rect(self, -2.4, -4.6, 1.6, 0.6, accent)
	for index in 3:
		Art.rect(self, -1.4 + float(index) * 1.0, -2.4, 0.5, 1.6, accent)


func _draw_red_panda(body_color: Color) -> void:
	var accent := get_accent()
	var dark := body_color.darkened(0.18)
	var step := sin(_walk) * 0.6 if _moving else 0.0
	Art.rect(self, -3.2, -3.0 + step, 1.2, 3.0, dark)
	Art.rect(self, -0.8, -3.0 - step, 1.2, 3.0, dark)
	Art.rect(self, 1.8, -3.0 + step, 1.2, 3.0, dark)
	Art.ellipse(self, 0, -7.4, 4.4, 3.4, body_color)
	Art.ellipse(self, 3.2, -11.0, 3.2, 2.8, body_color)
	Art.ellipse(self, 3.6, -10.4, 2.2, 1.8, accent)
	Art.poly(self, PackedVector2Array([
		Vector2(1.4, -12.4), Vector2(2.0, -15.0), Vector2(3.2, -12.8),
	]), dark)
	Art.poly(self, PackedVector2Array([
		Vector2(4.6, -12.8), Vector2(5.8, -15.0), Vector2(6.2, -12.2),
	]), dark)
	Art.rect(self, 4.0, -10.6, 0.8, 0.9, Color("#2f2622"))
	Art.rect(self, 6.0, -10.6, 0.8, 0.9, Color("#2f2622"))
	Art.rect(self, 5.0, -9.4, 0.8, 0.6, Color("#8c6a4a"))
