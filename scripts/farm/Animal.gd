class_name FarmAnimal
extends Node2D
## 牧场动物：鸡 / 牛等。
##
## 数值来自 config/animals.json（种类、产物、购买价）和 config/gameplay.json（好感、繁殖）。
## 稀有毛色来自 config/rarity.json，并在出生瞬间由 RarityUtil 判定。
##
## 状态会随存档保存：种类、位置、好感、是否已喂、稀有毛色、年龄；
## 不保存任何配置表字段。

const DB := preload("res://scripts/core/ConfigDB.gd")
const Rarity := preload("res://scripts/core/RarityUtil.gd")
const Quality := preload("res://scripts/core/QualityUtil.gd")

signal produce_ready_changed
signal petted

const TILE := 32

var type_id := "chicken"
var animal_name := ""
var friendship := 30.0
var friendship_max := 100.0
var fed_today := false
var petted_today := false
var produce_ready := false
var is_rare := false
var rare_color := ""
var rare_color_name := ""
var age_days := 0
var building := "coop"

var _home := Vector2.ZERO
var _wander_target := Vector2.ZERO
var _wander_timer := 1.0
var _facing := 1
var _moving := false
var _phase := 0.0
var _walk := 0.0


func setup(p_type_id: String, world_position: Vector2, p_building := "") -> void:
	type_id = p_type_id
	position = world_position
	_home = world_position
	_wander_target = world_position
	var rules := DB.get_animal_rules()
	friendship_max = float(rules.get("friendship_max", 100))
	friendship = float(rules.get("friendship_start", 30))
	var definition := DB.get_animal(type_id)
	if p_building.is_empty():
		building = str(definition.get("barn_type", "coop"))
	else:
		building = p_building
	if animal_name.is_empty():
		animal_name = str(definition.get("name", type_id))
	_phase = randf() * TAU
	queue_redraw()


func get_definition() -> Dictionary:
	return DB.get_animal(type_id)


func get_display_name() -> String:
	var base := str(get_definition().get("name", type_id))
	if is_rare and not rare_color_name.is_empty():
		return "%s · %s" % [rare_color_name, base]
	return base


func get_product_id() -> String:
	return str(get_definition().get("product_id", "none"))


func get_product_name() -> String:
	return str(get_definition().get("product_name", ""))


func can_produce() -> bool:
	var rules := DB.get_animal_rules()
	return get_product_id() != "none" \
		and friendship >= float(rules.get("produce_friendship_min", 0))


# ============================================================
# 每日流程
# ============================================================

## 跨日结算。was_fed 表示昨天是否喂过。
func advance_day(was_fed: bool) -> void:
	var rules := DB.get_animal_rules()
	age_days += 1

	if was_fed:
		friendship = minf(friendship_max, friendship + float(rules.get("friendship_per_feed", 1)))
		sick = false
		if can_produce():
			produce_ready = true
	else:
		friendship = maxf(0.0, friendship - float(rules.get("friendship_decay_no_feed", 4)))
		# 饿一天有小概率生病；喂食次日恢复
		if not sick and randf() < 0.06:
			sick = true

	fed_today = false
	petted_today = false
	produce_ready_changed.emit()
	queue_redraw()


func feed() -> void:
	fed_today = true


func pet() -> bool:
	if petted_today:
		return false
	petted_today = true
	var rules := DB.get_animal_rules()
	friendship = minf(friendship_max, friendship + float(rules.get("friendship_per_pet", 5)))
	petted.emit()
	celebrate()
	_jump_timer = 0.35
	return true


## 收走产物。返回物品实例；没有可收的返回空字典。
func collect_product() -> Dictionary:
	if not produce_ready:
		return {}
	produce_ready = false
	produce_ready_changed.emit()

	var product_id := get_product_id()
	if product_id == "none":
		return {}

	# 产物品质由好感决定。
	var quality := Quality.roll_animal_quality(friendship, friendship_max)
	return {
		"item_id": product_id,
		"category": "animal_product",
		"name": get_product_name(),
		"count": 1,
		"is_rare": is_rare,
		"rare_name": rare_color_name,
		"quality": quality,
		"quality_name": Quality.get_quality_name(quality),
		"price": Quality.apply_quality_price(DB.get_sell_price(product_id), quality),
		"animal": animal_name,
	}


## 出生时判定稀有毛色（双亲是否稀有影响概率）。
func roll_birth_traits(parent_a_rare: bool, parent_b_rare: bool) -> void:
	var definition := get_definition()
	var can_rare := bool(definition.get("can_rare_color", true))
	var result := Rarity.roll_animal_rarity(parent_a_rare, parent_b_rare, can_rare)
	is_rare = bool(result.get("is_rare", false))
	rare_color = str(result.get("rare_color", ""))
	rare_color_name = str(result.get("rare_color_name", ""))
	queue_redraw()


# ============================================================
# 行为
# ============================================================

var sick := false
## 骑乘耐力（仅牛使用；马/自行车的数据在 Farm.mounts 里）。
var ride_stamina := 80.0
var ride_stamina_max := 80.0
var _heart_timer := 0.0
var _jump_timer := 0.0
var _produce_timer := 0.0


func _process(delta: float) -> void:
	_phase += delta * 3.0
	if _moving:
		_walk += delta * 7.0
	if _heart_timer > 0.0:
		_heart_timer = maxf(0.0, _heart_timer - delta)
	if _jump_timer > 0.0:
		_jump_timer = maxf(0.0, _jump_timer - delta)
	if _produce_timer > 0.0:
		_produce_timer = maxf(0.0, _produce_timer - delta)
	# 生病：整体偏冷发灰
	if sick:
		modulate = Color(0.78, 0.80, 0.82)
	elif modulate != Color.WHITE:
		modulate = Color.WHITE
	queue_redraw()


## 被摸 / 好感提升：头顶冒粉色爱心。
func celebrate() -> void:
	_heart_timer = 1.2
	queue_redraw()


## 挤奶 / 剪毛 / 收蛋：产出动作（低头侧身抖动 0.5 秒）。
func play_produce_pose() -> void:
	_produce_timer = 0.5
	queue_redraw()


## 在指定矩形内随机走动。
func wander(delta: float, bounds: Rect2) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = 2.0 + randf() * 4.0
		_wander_target = Vector2(
			randf_range(bounds.position.x + 16.0, bounds.end.x - 16.0),
			randf_range(bounds.position.y + 20.0, bounds.end.y - 8.0)
		)

	var to_target := _wander_target - position
	if to_target.length() > 3.0:
		var speed := 14.0 if type_id in ["cow", "buffalo", "horse", "yak", "camel"] else 22.0
		var direction := to_target.normalized()
		position += direction * speed * delta
		if absf(direction.x) > 0.05:
			_facing = 1 if direction.x > 0.0 else -1
		_moving = true
	else:
		_moving = false


# ============================================================
# 存档
# ============================================================

func to_save() -> Dictionary:
	return {
		"type": type_id,
		"name": animal_name,
		"x": position.x,
		"y": position.y,
		"friendship": friendship,
		"fed_today": fed_today,
		"petted_today": petted_today,
		"produce_ready": produce_ready,
		"is_rare": is_rare,
		"rare_color": rare_color,
		"rare_color_name": rare_color_name,
		"age_days": age_days,
		"building": building,
		"sick": sick,
		"ride_stamina": ride_stamina,
		"ride_stamina_max": ride_stamina_max,
	}


func from_save(data: Dictionary) -> void:
	type_id = str(data.get("type", "chicken"))
	var definition := DB.get_animal(type_id)
	if definition.is_empty():
		type_id = "chicken"
		definition = DB.get_animal(type_id)

	position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	_home = position
	_wander_target = position
	animal_name = str(data.get("name", definition.get("name", type_id)))
	friendship = clampf(float(data.get("friendship", 30.0)), 0.0, friendship_max)
	fed_today = bool(data.get("fed_today", false))
	petted_today = bool(data.get("petted_today", false))
	produce_ready = bool(data.get("produce_ready", false))
	is_rare = bool(data.get("is_rare", false))
	rare_color = str(data.get("rare_color", ""))
	rare_color_name = str(data.get("rare_color_name", ""))
	age_days = maxi(0, int(data.get("age_days", 0)))
	building = str(data.get("building", definition.get("barn_type", "coop")))
	sick = bool(data.get("sick", false))
	ride_stamina_max = maxf(1.0, float(data.get("ride_stamina_max", 80.0)))
	ride_stamina = clampf(float(data.get("ride_stamina", ride_stamina_max)),
		0.0, ride_stamina_max)
	queue_redraw()


func set_sick(value: bool) -> void:
	sick = value
	queue_redraw()


# ============================================================
# 16px 像素绘制（无粗黑描边，暖调低饱和）
# ============================================================

const Art := preload("res://scripts/art/PixelArt.gd")


func _body_color() -> Color:
	if is_rare:
		var color_def := DB.get_animal_rare_color(rare_color)
		var hex := str(color_def.get("color", ""))
		if not hex.is_empty():
			return Color(hex).lightened(0.08)
	return Color("#efe9dc")


func _is_big() -> bool:
	return type_id in [
		"cow", "buffalo", "horse", "yak", "camel", "donkey",
		"deer", "alpaca", "ostrich", "sheep", "goat",
	]


func _draw() -> void:
	var bob := sin(_phase) * (0.7 if _moving else 0.3)
	# 被摸：向上跳一下（最高 4px）
	if _jump_timer > 0.0:
		var jump_progress := 1.0 - _jump_timer / 0.35
		bob += sin(jump_progress * PI) * 4.0
	Art.shadow(self, 0, -0.4, 9.0 if _is_big() else 5.0, 2.0 if _is_big() else 1.4)
	# 稀有毛色：专属柔光粒子（不发光特效，仅色块）
	if is_rare:
		for index in 3:
			var t := fmod(_phase * 0.6 + float(index) * 0.33, 1.0)
			var px := sin(_phase * 1.7 + float(index) * 2.0) * 8.0
			var py := -6.0 - t * 12.0
			Art.rect(self, px, py, 0.5, 0.5,
				Color(1.0, 0.92, 0.65, 0.55 * (1.0 - t)))
	self.draw_set_transform(Vector2(0, -bob), 0.0, Vector2(float(_facing), 1))

	if _is_big():
		_draw_cow(_body_color())
	else:
		_draw_chicken(_body_color())

	if produce_ready:
		_draw_product_bubble()
	if sick:
		_draw_sick_bubble()
	if _heart_timer > 0.0:
		_draw_hearts()
	if _produce_timer > 0.0:
		_draw_produce_pose()

	Art.reset_transform(self)


## 产出动作：动物轻微侧倾 + 冒出一点星光。
func _draw_produce_pose() -> void:
	var t := 1.0 - _produce_timer / 0.5
	var lean := sin(t * PI * 3.0) * 2.0
	Art.rect(self, lean, -6.0, 1.0, 1.0, Color(1.0, 0.94, 0.72, 0.8 * (1.0 - t)))
	Art.rect(self, lean + 4.0, -10.0 - t * 4.0, 1.0, 1.0,
		Color(1.0, 0.94, 0.72, 0.6 * (1.0 - t)))


## 生病气泡：冷蓝色十字。
func _draw_sick_bubble() -> void:
	var y := -26.0 if _is_big() else -20.0
	Art.ellipse(self, 0, y, 3.4, 3.0, Color(0.95, 0.97, 1.0, 0.85))
	Art.ellipse(self, 0, y - 0.4, 2.6, 2.3, Color("#dfeef5"))
	Art.rect(self, -1.0, y - 1.4, 2.0, 0.8, Color("#5f8fa8"))
	Art.rect(self, -0.5, y - 2.0, 1.0, 3.0, Color("#5f8fa8"))


## 粉色爱心：三颗依次升起、淡出。
func _draw_hearts() -> void:
	var elapsed := 1.2 - _heart_timer
	for index in 3:
		var t := fmod(elapsed * 1.3 + float(index) * 0.33, 1.0)
		var alpha := (1.0 - t) * clampf(_heart_timer * 2.0, 0.0, 1.0)
		var hx := sin(t * TAU + float(index) * 2.1) * 4.0
		var hy := -20.0 - t * 9.0
		var color := Color(0.92, 0.55, 0.65, alpha)
		Art.ellipse(self, hx - 1.0, hy, 1.0, 0.9, color)
		Art.ellipse(self, hx + 1.0, hy, 1.0, 0.9, color)
		Art.poly(self, PackedVector2Array([
			Vector2(hx - 1.8, hy + 0.5), Vector2(hx + 1.8, hy + 0.5),
			Vector2(hx, hy + 2.2),
		]), color)


func _draw_product_bubble() -> void:
	var wobble := sin(_phase * 1.4) * 0.6
	Art.ellipse(self, 0, -30 + wobble, 3.2, 2.8, Color(1.0, 0.97, 0.90, 0.55))
	Art.ellipse(self, 0, -30.4 + wobble, 2.4, 2.2, Color("#f7f0dd"))
	var product_id := get_product_id()
	if product_id.find("milk") >= 0:
		Art.rect(self, -1.2, -32 + wobble, 2.4, 3.0, Color("#e9ece2"))
		Art.rect(self, -1.2, -32.8 + wobble, 2.4, 1.0, Color("#9fb4c4"))
	else:
		Art.ellipse(self, 0, -30.4 + wobble, 1.4, 1.8, Color("#f2e9d6"))


func _draw_chicken(body: Color) -> void:
	# 毛发：受光面偏暖，背光面偏冷（色相偏移）
	var dark := Art.shade_cool(body, 0.28)
	# 4 帧行走：左右腿交替抬起
	var walk_swing: Array[float] = [0.0, 0.9, 0.0, -0.9]
	var step: float = walk_swing[int(_walk) % 4] if _moving else 0.0

	# 腿
	Art.rect(self, -2.0, -3.0 + maxf(0.0, step), 0.9, 3.0 - absf(step) * 0.3, Color("#c9a06a"))
	Art.rect(self, 1.2, -3.0 + maxf(0.0, -step), 0.9, 3.0 - absf(step) * 0.3, Color("#c9a06a"))

	# 身体
	Art.ellipse(self, 0, -7.0, 4.6, 4.0, body)
	Art.ellipse(self, 1.4, -6.4, 3.0, 3.0, dark)
	# 尾巴
	Art.poly(self, PackedVector2Array([
		Vector2(-3.6, -9.0), Vector2(-7.6, -11.0), Vector2(-4.6, -5.0),
	]), dark)

	# 头：静止时低头啄食
	var peck := 0.0
	if not _moving:
		peck = maxf(0.0, sin(_phase * 0.9)) * 1.4
	if sick:
		peck = 1.2
	Art.ellipse(self, 3.6, -11.6 + peck, 2.8, 2.6, body)
	# 鸡冠（柔和红）
	Art.rect(self, 2.6, -15.2 + peck, 1.0, 1.6, Color("#c48a82"))
	Art.rect(self, 4.0, -15.6 + peck, 1.0, 1.8, Color("#c48a82"))
	# 喙
	Art.rect(self, 6.0, -11.6 + peck, 1.6, 1.0, Color("#d6b072"))
	# 眼睛
	Art.rect(self, 4.4, -12.6 + peck, 0.8, 0.9, Color("#5a4a38"))
	# 翅膀（暖色受光面）
	Art.ellipse(self, -0.4, -7.0, 2.4, 1.8, Art.tint_warm(body, 0.22))


func _draw_cow(body: Color) -> void:
	var patch := Art.shade_cool(Color("#9c8a78"), 0.25) if not is_rare else Art.shade_cool(body, 0.30)
	var leg := Art.shade_cool(Color("#8c7a68"), 0.28)
	# 4 帧行走：四腿交替
	var walk_swing: Array[float] = [0.0, 1.1, 0.0, -1.1]
	var step: float = walk_swing[int(_walk) % 4] if _moving else 0.0

	# 腿
	Art.rect(self, -7.0, -5.0 + maxf(0.0, step), 2.0, 5.0 - absf(step) * 0.4, leg)
	Art.rect(self, -3.4, -5.0 + maxf(0.0, -step), 2.0, 5.0 - absf(step) * 0.4, leg)
	Art.rect(self, 2.6, -5.0 + maxf(0.0, -step), 2.0, 5.0 - absf(step) * 0.4, leg)
	Art.rect(self, 6.0, -5.0 + maxf(0.0, step), 2.0, 5.0 - absf(step) * 0.4, leg)

	# 尾巴
	Art.stepped_line(self, Vector2(-8.0, -11.0), Vector2(-10.4, -5.6), leg)
	Art.ellipse(self, -10.4, -5.0, 1.0, 1.2, Art.shade_cool(Color("#7a6a5a"), 0.20))

	# 身体（矩形感，伪俯视）
	Art.rrect(self, -8.6, -13.6, 17.2, 9.0, 3.4, body)
	# 背部受光暖色高光带
	Art.rect(self, -7.0, -13.4, 12.0, 0.8, Color(Art.tint_warm(body, 0.30), 0.55))
	# 斑块
	Art.ellipse(self, -4.0, -10.0, 2.6, 2.2, patch)
	Art.ellipse(self, 2.0, -11.6, 2.2, 1.8, patch)
	Art.ellipse(self, 5.0, -9.0, 1.8, 1.4, patch)

	# 头：静止时低头吃草
	var graze := 0.0
	if not _moving:
		graze = maxf(0.0, sin(_phase * 0.7 + 1.2)) * 1.0
	if sick:
		graze = 1.4
	Art.rrect(self, 7.4, -14.6 + graze, 8.0, 7.0, 2.6, body)
	Art.ellipse(self, 14.0, -10.4 + graze, 2.2, 1.8, Color("#d9b3a8"))
	# 耳朵
	Art.rect(self, 7.8, -16.4 + graze, 1.2, 1.8, Color("#d9cdb8"))
	Art.rect(self, 12.4, -16.4 + graze, 1.2, 1.8, Color("#d9cdb8"))
	# 眼睛
	Art.rect(self, 9.6, -12.6 + graze, 0.9, 1.0, Color("#5a4a38"))
	Art.rect(self, 12.2, -12.6 + graze, 0.9, 1.0, Color("#5a4a38"))
	# 铃铛
	Art.rect(self, 8.4, -8.4 + graze, 1.6, 1.4, Color("#d8bd84"))
