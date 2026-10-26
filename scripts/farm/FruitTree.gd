class_name FruitTree
extends Node2D
## 果树（按《牧场物语游戏设计文档》第六章与《角色NPC…设计要求》5.2）。
##
## 规则全部来自 config/fruit_trees.json：
##   - 种下后永久生长，前几年是幼树，到 mature_year 成年
##   - 成年后在固定季节结果，每年一次（repeat_yearly）
##   - 不需要浇水，但需要周围 3×3 留空
##   - 结果时 5% 概率出稀有大果，售价 ×1.5
##   - 可以用斧头砍倒
##
## 存档只存实例状态：树苗 id、坐标、种植年份、是否成熟/结果/稀有。

const DB := preload("res://scripts/core/ConfigDB.gd")
const Rarity := preload("res://scripts/core/RarityUtil.gd")
const Quality := preload("res://scripts/core/QualityUtil.gd")
const Art := preload("res://scripts/art/PixelArt.gd")

const TILE := 32

signal tree_changed

var tree_id := "apple_tree"
var grid_pos := Vector2i.ZERO
var planted_year := 1
var mature := false
var ripe := false
var is_rare_fruit := false
var _shake := 0.0
var _phase := 0.0
## 本季是否已经结过一次果（防止同季重复结果）。
var _fruited_season := ""


func _ready() -> void:
	position = Vector2(grid_pos) * TILE + Vector2(TILE * 0.5, TILE)
	_phase = randf() * TAU
	queue_redraw()


func setup(p_tree_id: String, p_grid_pos: Vector2i, p_year := 1, already_mature := false) -> void:
	tree_id = p_tree_id
	grid_pos = p_grid_pos
	planted_year = p_year
	mature = already_mature
	position = Vector2(grid_pos) * TILE + Vector2(TILE * 0.5, TILE)
	_phase = randf() * TAU
	_phase = randf() * TAU
	queue_redraw()


func get_definition() -> Dictionary:
	return DB.get_fruit_tree(tree_id)


func get_tree_name() -> String:
	return str(get_definition().get("name", tree_id))


func get_fruit_id() -> String:
	return str(get_definition().get("fruit_id", ""))


func get_fruit_name() -> String:
	return str(get_definition().get("fruit_name", ""))


func get_season() -> String:
	return str(get_definition().get("season", "autumn"))


func get_mature_year() -> int:
	return maxi(1, int(get_definition().get("mature_year", 4)))


## 3×3 范围（以树为中心）。
func get_footprint() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			result.append(grid_pos + Vector2i(dx, dy))
	return result


# ============================================================
# 生长 / 换季
# ============================================================

## 跨年检查：种下满 mature_year 年就成年。
func update_maturity(current_year: int) -> void:
	if mature:
		return
	if current_year - planted_year + 1 >= get_mature_year():
		mature = true
		tree_changed.emit()
		queue_redraw()


## 跨日检查：成年树在当季结果，每季只结一次。
func advance_day(season: String) -> void:
	if season != get_season():
		# 离开结果季，重置本季标记，明年同一季节会再结果
		_fruited_season = ""
		return
	if not mature or ripe:
		return
	if _fruited_season == season:
		return
	_fruited_season = season
	ripe = true
	is_rare_fruit = bool(Rarity.roll_fruit_rarity().get("is_rare", false))
	tree_changed.emit()
	queue_redraw()


## 收获果实。返回 { ok, reason, item }
func harvest() -> Dictionary:
	if not mature:
		return {"ok": false, "reason": "这棵树还没成年"}
	if not ripe:
		return {"ok": false, "reason": "现在不是结果季节，或者果实已经摘过了"}

	var definition := get_definition()
	var base_price := int(definition.get("base_price", 0))
	var quality := Quality.roll_from_table({
		"normal": 0.7, "silver": 0.2, "gold": 0.09, "star": 0.01,
	})
	var multiplier := 1.5 if is_rare_fruit else 1.0
	var price := int(round(float(base_price) * Quality.quality_multiplier(quality) * multiplier))

	var item := {
		"item_id": get_fruit_id(),
		"name": get_fruit_name(),
		"category": "fruit",
		"count": 1,
		"is_rare": is_rare_fruit,
		"rare_type": "giant_fruit" if is_rare_fruit else "",
		"rare_name": "硕大" if is_rare_fruit else "",
		"quality": quality,
		"quality_name": Quality.get_quality_name(quality),
		"price": price,
		"from_tree": tree_id,
	}

	var was_rare := is_rare_fruit
	ripe = false
	is_rare_fruit = false
	_shake = 1.0
	var tween := create_tween()
	tween.tween_property(self, "_shake", 0.0, 0.5)
	tree_changed.emit()
	queue_redraw()

	return {"ok": true, "reason": "", "item": item, "was_rare": was_rare}


# ============================================================
# 存档
# ============================================================

func to_save() -> Dictionary:
	return {
		"tree_id": tree_id,
		"x": grid_pos.x,
		"y": grid_pos.y,
		"planted_year": planted_year,
		"mature": mature,
		"ripe": ripe,
		"is_rare_fruit": is_rare_fruit,
	}


func from_save(data: Dictionary) -> void:
	tree_id = str(data.get("tree_id", "apple_tree"))
	if DB.get_fruit_tree(tree_id).is_empty():
		tree_id = "apple_tree"
	grid_pos = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	planted_year = maxi(1, int(data.get("planted_year", 1)))
	mature = bool(data.get("mature", false))
	ripe = bool(data.get("ripe", false))
	is_rare_fruit = bool(data.get("is_rare_fruit", false))
	position = Vector2(grid_pos) * TILE + Vector2(TILE * 0.5, TILE)
	queue_redraw()


# ============================================================
# 绘制
# ============================================================

func _process(delta: float) -> void:
	if _shake > 0.0:
		_phase += delta * 18.0
		queue_redraw()
	else:
		_phase += delta * 1.2


func _draw() -> void:
	var sway := sin(_phase * 1.2) * (0.6 if mature else 0.3)
	if _shake > 0.0:
		sway += sin(_phase * 3.0) * _shake * 3.0

	if not mature:
		_draw_sapling(sway)
	else:
		_draw_mature(sway)


func _draw_sapling(sway: float) -> void:
	Art.shadow(self, 0, 0, 5.0, 1.8)
	# 细树干 + 两片小叶
	Art.rect(self, -0.5, -8.0, 1.0, 8.0, Color("#8c6a4a"))
	Art.ellipse(self, sway * 0.4 - 1.6, -8.5, 1.8, 1.2, Color("#8fae75"))
	Art.ellipse(self, sway * 0.4 + 1.6, -10.0, 1.8, 1.2, Color("#7fa066"))
	Art.rect(self, -2.0, -1.5, 4.0, 1.5, Color("#8c6a4a"))


func _draw_mature(sway: float) -> void:
	Art.shadow(self, 0, 0, 13.0, 4.0)

	# 树干：底部加宽
	Art.rect(self, -2.5, -26.0, 5.0, 26.0, Color("#8c6a4a"))
	Art.rect(self, -1.2, -26.0, 2.0, 25.0, Color("#a17d59"))
	Art.rect(self, -4.5, -2.5, 9.0, 2.5, Color("#8c6a4a"))

	# 树冠：三层，外亮内暗，随风轻摆
	var leaf_dark := Color("#6f8f58")
	var leaf := Color("#7fa066")
	var leaf_light := Color("#8fae75")

	Art.ellipse(self, sway, -34.0, 17.0, 13.0, leaf_dark)
	Art.ellipse(self, sway - 1.0, -36.0, 15.0, 11.5, leaf)
	Art.ellipse(self, sway - 2.0, -39.0, 10.5, 8.0, leaf_light)
	Art.ellipse(self, sway + 7.0, -33.0, 8.0, 6.0, leaf)
	Art.ellipse(self, sway - 8.0, -30.0, 7.0, 5.5, leaf_dark)
	Art.ellipse(self, sway + 3.0, -44.0, 6.0, 4.0, leaf_light)
	Art.ellipse(self, sway - 6.0, -41.0, 5.0, 3.5, leaf)

	# 果实：挂在树冠外缘，成熟时出现
	if ripe:
		var fruit_color := Art.crop_color(get_fruit_id())
		if is_rare_fruit:
			fruit_color = fruit_color.lightened(0.12)
		var radius := 2.6 if is_rare_fruit else 2.0
		var positions := [
			Vector2(-10.0, -33.0), Vector2(9.0, -38.0), Vector2(-3.0, -28.0),
			Vector2(13.0, -29.0), Vector2(-13.0, -40.0),
		]
		for index in positions.size():
			var p: Vector2 = positions[index] + Vector2(sway, 0)
			Art.ellipse(self, p.x, p.y, radius, radius, fruit_color)
			Art.rect(self, p.x - 0.5, p.y - radius - 1.0, 1.0, 1.0, Color("#5f8f3a"))
			if is_rare_fruit and index == 0:
				Art.rect(self, p.x + 1.0, p.y - radius - 2.0, 1.0, 1.0, Color(1, 0.95, 0.7, 0.8))
	else:
		# 未结果时树冠点缀几个深色叶团，避免一大块绿
		Art.ellipse(self, sway + 2.0, -32.0, 3.0, 2.2, leaf_dark)
		Art.ellipse(self, sway - 6.0, -36.0, 2.6, 2.0, leaf_dark)
