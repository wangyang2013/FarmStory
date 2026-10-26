class_name PetHouse
extends Node2D
## 宠物栖息地：狗屋 / 猫窝 / 鸟笼 / 鱼缸 / 龟池 / 围栏等。
## 数据来自 config/pet_houses.json；occupants 记录入住宠物 ID。
## 按脚底 Y 排序，宠物本身仍是独立的 FarmPet 节点。

const Art := preload("res://scripts/art/PixelArt.gd")
const DB := preload("res://scripts/core/ConfigDB.gd")

var house_id := ""
var house_type := "dog_house"
var house_name := ""
var level := 1
var location := "outdoor"
var occupancy: Array[String] = []
var decorations: Array[String] = []
var cleanliness := 80.0
var has_missing := false

var _t := 0.0


func setup(p_type: String, p_id: String, world_position: Vector2,
		p_location := "outdoor") -> void:
	house_type = p_type
	house_id = p_id
	location = p_location
	position = world_position
	house_name = str(get_definition().get("name", p_type))
	cleanliness = float(DB.get_pet_config().get("status", {})
		.get("start", {}).get("cleanliness", 80))
	queue_redraw()


func get_definition() -> Dictionary:
	return DB.get_pet_house_def(house_type)


func get_max_level() -> int:
	return maxi(1, int(get_definition().get("max_level", 3)))


func get_upgrade_cost() -> int:
	return maxi(0, int(get_definition().get("upgrade_cost", 0)))


## 基础容量 + 每级 +1；升级后容量提升。
func get_capacity() -> int:
	return maxi(1, int(get_definition().get("capacity", 1))) + maxi(0, level - 1)


func is_full() -> bool:
	return occupancy.size() >= get_capacity()


func add_occupant(pet_id: String) -> bool:
	if is_full() or pet_id in occupancy:
		return false
	occupancy.append(pet_id)
	queue_redraw()
	return true


func remove_occupant(pet_id: String) -> void:
	occupancy.erase(pet_id)
	queue_redraw()


func has_occupant(pet_id: String) -> bool:
	return pet_id in occupancy


## 入住宠物的站立/摆放锚点。
func get_anchor() -> Vector2:
	var offsets := {
		"dog_house": Vector2(0, -8),
		"cat_bed": Vector2(0, -4),
		"cat_tree": Vector2(0, -20),
		"bird_cage": Vector2(0, -26),
		"red_panda_den": Vector2(0, -8),
		"fish_tank": Vector2(0, -16),
		"turtle_tank": Vector2(0, -10),
		"turtle_pond": Vector2(0, -6),
		"rabbit_hutch": Vector2(0, -8),
		"hamster_cage": Vector2(0, -8),
		"guinea_pig_cage": Vector2(0, -8),
		"hedgehog_den": Vector2(0, -5),
		"squirrel_house": Vector2(0, -22),
		"ferret_cage": Vector2(0, -14),
		"chinchilla_cage": Vector2(0, -14),
		"young_animal_pen": Vector2(0, -4),
		"duck_pond": Vector2(0, -6),
		"reptile_tank": Vector2(0, -12),
		"amphibian_tank": Vector2(0, -10),
		"insect_box": Vector2(0, -6),
		"butterfly_house": Vector2(0, -14),
		"crab_tank": Vector2(0, -10),
		"aviary": Vector2(0, -26),
		"fox_den": Vector2(0, -8),
		"deer_pen": Vector2(0, -5),
		"otter_pool": Vector2(0, -6),
		"penguin_pool": Vector2(0, -6),
		"seal_pool": Vector2(0, -6),
		"dragon_den": Vector2(0, -12),
		"saltwater_tank": Vector2(0, -18),
		"jellyfish_tank": Vector2(0, -18),
		"planted_tank": Vector2(0, -12),
	}
	return position + offsets.get(house_type, Vector2(0, -8))


func advance_day() -> void:
	cleanliness = maxf(0.0, cleanliness - 10.0)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if house_type == "cat_bed":
		_draw_cat_bed()
	elif house_type == "cat_tree":
		_draw_cat_tree()
	elif house_type in [
		"fish_tank", "turtle_tank", "reptile_tank", "amphibian_tank",
		"crab_tank", "saltwater_tank", "jellyfish_tank", "planted_tank",
	]:
		_draw_tank(house_type)
	elif house_type in [
		"turtle_pond", "duck_pond", "otter_pool", "penguin_pool", "seal_pool",
	]:
		_draw_pond(house_type)
	elif house_type in ["young_animal_pen", "deer_pen"]:
		_draw_pen(house_type)
	elif house_type in [
		"bird_cage", "hamster_cage", "hedgehog_den", "ferret_cage",
		"chinchilla_cage", "insect_box", "butterfly_house", "aviary",
	]:
		_draw_cage(house_type)
	elif house_type == "dragon_den":
		_draw_dragon_den()
	else:
		_draw_wood_house()
	_draw_decorations()
	_draw_status()


func _draw_decorations() -> void:
	for decoration: String in decorations:
		match decoration:
			"toy_ball":
				Art.shadow(self, -9.0, -0.4, 2.0, 0.8)
				Art.ellipse(self, -9.0, -2.0, 1.8, 1.8, Color("#c4553f"))
				Art.ellipse(self, -9.4, -2.6, 0.7, 0.6, Color("#e8a08a"))
			"swing":
				Art.rect(self, -12.0, -26.0, 10.0, 0.6, Color("#c9a276"))
				Art.rect(self, -10.4, -25.4, 0.6, 4.0, Color("#c9a276"))
				Art.rect(self, -4.6, -25.4, 0.6, 4.0, Color("#c9a276"))
				Art.rect(self, -10.8, -21.6, 7.2, 1.0, Color("#8c6a4a"))
			"mirror":
				Art.rect(self, 9.0, -29.0, 5.0, 6.0, Color("#c9a276"))
				Art.rect(self, 9.6, -28.4, 3.8, 4.8, Color("#b9d2dc"))
			"water_plant":
				for index in 3:
					var x := -14.0 + float(index) * 2.0
					Art.rect(self, x, -26.0, 0.8, 7.0, Color("#6f9a60"))
			"sun_lamp":
				Art.rect(self, 8.0, -38.0, 3.0, 2.0, Color("#e8c95a"))
				Art.rect(self, 9.2, -36.0, 0.6, 4.0, Color("#c9a276"))
			"chew_wood":
				Art.rect(self, -15.0, -3.0, 6.0, 2.0, Color("#b08a62"))
				Art.rect(self, -14.2, -2.4, 4.4, 0.8, Color("#d8b48a"))
			"grass_nest":
				Art.ellipse(self, 10.0, -3.0, 4.0, 2.0, Color("#d8c08a"))
				Art.ellipse(self, 10.0, -3.6, 2.6, 1.2, Color("#e8d7b0"))


func _base_shadow(width: float) -> void:
	Art.rect(self, -width * 0.5 - 1.0, 0.5, width, 2.5, Color(0.24, 0.21, 0.34, 0.20))
	Art.rect(self, -width * 0.4 - 1.0, 0.5, width * 0.8, 1.5, Color(0.22, 0.19, 0.32, 0.16))


func _draw_wood_house() -> void:
	_base_shadow(48.0)
	var wall := Color("#b8865a")
	var roof := Color("#8a4a3a")
	Art.rect(self, -22.0, -26.0, 44.0, 26.0, wall)
	for row in 4:
		Art.rect(self, -22.0, -24.0 + float(row) * 6.0, 44.0, 0.8,
			Color(0.36, 0.24, 0.14, 0.18))
	Art.poly(self, PackedVector2Array([
		Vector2(-26.0, -25.0), Vector2(26.0, -25.0),
		Vector2(20.0, -36.0), Vector2(-20.0, -36.0),
	]), roof)
	Art.rect(self, -26.0, -26.0, 52.0, 1.4, Color("#a97e72"))
	Art.rect(self, -5.0, -16.0, 10.0, 16.0, Color("#5f4326"))
	Art.rect(self, -3.8, -14.0, 7.6, 14.0, Color("#7d5a3c"))
	Art.rect(self, 10.0, -20.0, 5.0, 5.0, Color("#6f4328"))
	Art.rect(self, 11.0, -19.0, 3.0, 3.0, Color("#b9d2dc"))
	Art.ellipse(self, -14.0, -2.0, 4.0, 2.0, Color("#c9a276"))
	Art.ellipse(self, -14.0, -2.6, 2.6, 1.2, Color("#e3d0a4"))


func _draw_cat_bed() -> void:
	_base_shadow(22.0)
	Art.ellipse(self, 0, -5.0, 10.0, 5.0, Color("#d8a8a0"))
	Art.ellipse(self, 0, -6.0, 7.0, 3.4, Color("#f2d8d0"))
	Art.ellipse(self, 0, -6.4, 4.6, 2.2, Color("#f7ece4"))


func _draw_cat_tree() -> void:
	_base_shadow(40.0)
	var wood := Color("#b08a62")
	var dark := Color("#8c6a4a")
	Art.rect(self, -4.0, -34.0, 8.0, 34.0, dark)
	Art.rect(self, -3.0, -34.0, 2.0, 34.0, wood)
	Art.rect(self, -14.0, -18.0, 28.0, 4.0, wood)
	Art.rect(self, -18.0, -28.0, 24.0, 4.0, wood)
	Art.rect(self, -9.0, -38.0, 18.0, 4.0, wood)
	Art.ellipse(self, 0, -40.0, 9.0, 4.0, Color("#d8a8a0"))
	Art.ellipse(self, 0, -41.0, 6.0, 2.4, Color("#f2d8d0"))
	Art.rect(self, 12.0, -24.0, 4.0, 24.0, Color("#c9a276"))


func _draw_cage(kind: String) -> void:
	var small := kind in ["hamster_cage", "hedgehog_den", "insect_box"]
	var width := 34.0 if small else 44.0
	var height := 24.0 if small else 40.0
	_base_shadow(width + 2.0)
	var wood := Color("#c9a276")
	var dark := Color("#8c6a4a")
	Art.rect(self, -width * 0.5, -height, width, height, Color(0.80, 0.86, 0.88, 0.22))
	Art.rect(self, -width * 0.5, -2.0, width, 2.0, dark)
	Art.rect(self, -width * 0.5, -height, 2.0, height, dark)
	Art.rect(self, width * 0.5 - 2.0, -height, 2.0, height, dark)
	Art.rect(self, -width * 0.5, -height, width, 2.0, wood)
	for index in 4:
		var x := -width * 0.5 + 4.0 + float(index) * (width - 8.0) / 3.0
		Art.rect(self, x, -height + 3.0, 0.8, height - 6.0, Color(0.55, 0.52, 0.44, 0.55))
	Art.rect(self, -width * 0.5 + 4.0, -height + 5.0, 6.0, 3.0, Color("#c9b48e"))
	Art.rect(self, width * 0.5 - 10.0, -height + 5.0, 5.0, 3.0, Color("#8fc6d4"))
	if kind == "butterfly_house":
		for index in 2:
			Art.ellipse(self, -6.0 + float(index) * 10.0, -height + 12.0,
				2.0, 1.4, Color("#e8a0c9"))
	elif kind == "aviary":
		Art.rect(self, -6.0, -height - 4.0, 12.0, 4.0, dark)


func _draw_tank(kind: String) -> void:
	var width := 44.0
	if kind in ["reptile_tank", "planted_tank"]:
		width = 40.0
	_base_shadow(width + 2.0)
	Art.rect(self, -width * 0.5, -18.0, width, 18.0, Color("#8c6a4a"))
	Art.rect(self, -width * 0.5, -18.0, width, 1.4, Color("#a9825c"))
	Art.rect(self, -width * 0.5 + 1.0, -34.0, width - 2.0, 16.0,
		Color(0.62, 0.82, 0.88, 0.38))
	Art.rect(self, -width * 0.5 + 1.0, -34.0, width - 2.0, 1.4,
		Color(0.80, 0.92, 0.96, 0.62))
	Art.rect(self, -width * 0.5 + 1.0, -20.0, width - 2.0, 2.0,
		Color(0.55, 0.75, 0.80, 0.45))
	for index in 3:
		var x := -width * 0.5 + 6.0 + float(index) * (width - 12.0) / 2.0
		Art.rect(self, x, -24.0, 1.4, 4.0, Color("#6f9a60"))
	if kind == "planted_tank":
		Art.rect(self, -width * 0.5 + 3.0, -20.0, width - 6.0, 2.0, Color("#8a9a5a"))
	elif kind == "turtle_tank":
		Art.rect(self, -width * 0.5 + 2.0, -21.0, width * 0.5, 3.0, Color("#d8c08a"))


func _draw_pond(kind: String) -> void:
	var width := 56.0
	if kind == "duck_pond":
		width = 52.0
	_base_shadow(width + 2.0)
	Art.ellipse(self, 0, -6.0, width * 0.5, 9.0, Color("#c9b48e"))
	Art.rect(self, -width * 0.5 + 4.0, -6.0, width - 8.0, 2.0, Color("#d8c08a"))
	Art.ellipse(self, 0, -8.0, width * 0.36, 6.0, Color("#6fa3ad"))
	Art.ellipse(self, 0, -9.0, width * 0.30, 4.4, Color("#8fc6d4"))
	Art.ellipse(self, -width * 0.22, -8.4, 3.0, 1.6, Color("#7fb3b0"))
	Art.rect(self, width * 0.28, -10.0, 8.0, 5.0, Color("#a3a39c"))


func _draw_pen(kind: String) -> void:
	var width := 64.0 if kind == "deer_pen" else 48.0
	_base_shadow(width + 2.0)
	Art.rect(self, -width * 0.5, -2.0, width, 2.0, Color(0.55, 0.45, 0.28, 0.25))
	for index in 4:
		var x := -width * 0.5 + 2.0 + float(index) * (width - 4.0) / 3.0
		Art.rect(self, x, -14.0, 1.8, 14.0, Color("#b08a62"))
	Art.rect(self, -width * 0.5, -12.0, width, 1.6, Color("#c9a276"))
	Art.rect(self, -width * 0.5, -6.0, width, 1.4, Color("#c9a276"))
	Art.ellipse(self, -width * 0.25, -3.0, 5.0, 2.4, Color("#d8c08a"))
	Art.ellipse(self, width * 0.2, -3.0, 3.0, 2.0, Color("#a9bf82"))


func _draw_dragon_den() -> void:
	_base_shadow(60.0)
	Art.ellipse(self, 0, -4.0, 26.0, 8.0, Color("#8f959c"))
	Art.ellipse(self, 0, -6.0, 20.0, 6.0, Color("#b3b8bd"))
	for index in 3:
		var angle := TAU * float(index) / 3.0 + 0.5
		Art.ellipse(self, cos(angle) * 9.0, -6.0 + sin(angle) * 3.0,
			1.6, 1.6, Color("#8fc6d4"))


func _draw_status() -> void:
	if cleanliness < 30.0:
		for index in 2:
			var x := -8.0 + float(index) * 9.0
			Art.rect(self, x, -34.0, 0.8, 3.0, Color(0.55, 0.70, 0.48, 0.7))
	if has_missing:
		Art.ellipse(self, 0, -42.0, 3.2, 2.6, Color(1.0, 0.97, 0.90, 0.85))
		Art.rect(self, -0.5, -43.6, 1.0, 2.0, Color("#c4553f"))
		Art.rect(self, -0.5, -41.0, 1.0, 1.0, Color("#c4553f"))
