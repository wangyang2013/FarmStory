class_name BeeHive
extends Node2D
## 蜂箱（按《牧场物语游戏设计文档》4.13 与 config/beekeeping.json）。
##
## 规则全部来自配置：
##   - 每箱最多 1 只蜂王；健康值 0–100
##   - 周围 5×5 内每种开花植物 +5% 采蜜效率（最多计 8 种）
##   - 每 harvest_interval_days 天可收一次蜜
##   - 雨天不采蜜；冬季户外停产（温室蜂箱正常）
##   - 健康 ≥80 有概率额外获得蜂蜡
##   - 无花源 / 不喂糖水 / 病害 → 健康下降；<20 有概率逃群
##   - 每季 5% 概率发生病害
##
## 存档只存实例状态：坐标、健康、蜂王、距上次收蜜天数、病害、品质。

const DB := preload("res://scripts/core/ConfigDB.gd")
const Quality := preload("res://scripts/core/QualityUtil.gd")
const Art := preload("res://scripts/art/PixelArt.gd")

const TILE := 32

signal hive_changed

var grid_pos := Vector2i.ZERO
var has_queen := false
var health := 60.0
var days_since_harvest := 0
var diseased := false
var greenhouse := false
var last_quality := ""
var last_rare_honey := ""
var escaped := false

var _phase := 0.0


func _ready() -> void:
	position = Vector2(grid_pos) * TILE + Vector2(TILE * 0.5, TILE)
	_phase = randf() * TAU
	queue_redraw()


func setup(p_grid_pos: Vector2i, p_greenhouse := false) -> void:
	grid_pos = p_grid_pos
	greenhouse = p_greenhouse
	position = Vector2(grid_pos) * TILE + Vector2(TILE * 0.5, TILE)
	var config := DB.get_hive_config()
	health = float(config.get("start_health", 60))
	queue_redraw()


func get_hive_config() -> Dictionary:
	return DB.get_hive_config()


func get_flower_bonus() -> Dictionary:
	return DB.get_flower_bonus_config()


func get_rare_honey_config() -> Dictionary:
	return DB.get_rare_honey_config()


func get_interval_days() -> int:
	return maxi(1, int(get_hive_config().get("harvest_interval_days", 3)))


## 采蜜效率加成：5×5 内每种花源 +5%，最多 8 种。
func get_efficiency(flower_type_count: int) -> float:
	var config := get_flower_bonus()
	var per := float(config.get("efficiency_per_flower_type", 0.05))
	var max_types := int(config.get("max_flower_types", 8))
	return 1.0 + per * mini(flower_type_count, max_types)


func can_harvest(season: String, weather: String) -> bool:
	if not has_queen or escaped:
		return false
	if diseased:
		return false
	if days_since_harvest < get_interval_days():
		return false
	if weather == "rain" or weather == "storm":
		return false
	if season == "winter" and not greenhouse:
		return false
	return true


## 跨日结算。
func advance_day(season: String, weather: String, flower_type_count: int) -> void:
	if escaped:
		return
	days_since_harvest += 1

	if diseased:
		health = maxf(0.0, health - 5.0)
	elif not has_queen:
		health = maxf(0.0, health - 2.0)
	else:
		var bonus := 0.0
		if flower_type_count <= 0:
			bonus -= 2.0
		else:
			bonus += 1.0
		if weather == "rain" or weather == "storm":
			bonus -= 0.5
		if season == "winter" and not greenhouse:
			bonus -= 0.5
		health = clampf(health + bonus, 0.0, 100.0)

	# 逃群
	if health < 20.0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		if rng.randf() < 0.10:
			escaped = true
			has_queen = false
			health = 0.0
	hive_changed.emit()
	queue_redraw()


## 每季 5% 概率病害（由 Farm 在换季时调用）。
func roll_season_disease() -> void:
	if escaped or diseased:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if rng.randf() < 0.05:
		diseased = true
		hive_changed.emit()
		queue_redraw()


## 喂糖水：健康 +10。
func feed_sugar_water() -> bool:
	if escaped:
		return false
	health = clampf(health + 10.0, 0.0, 100.0)
	hive_changed.emit()
	queue_redraw()
	return true


## 用蜂群药物治病。
func heal_disease() -> bool:
	if not diseased:
		return false
	diseased = false
	health = clampf(health + 15.0, 0.0, 100.0)
	hive_changed.emit()
	queue_redraw()
	return true


## 放入蜂王。
func place_queen() -> bool:
	if escaped:
		return false
	if has_queen:
		return false
	has_queen = true
	health = maxf(health, 50.0)
	hive_changed.emit()
	queue_redraw()
	return true


## 收蜜。返回 { ok, reason, items: [{item_id, name, count, quality, price}] }
func harvest(season: String, weather: String, flower_type_count: int) -> Dictionary:
	if not can_harvest(season, weather):
		if not has_queen:
			return {"ok": false, "reason": "蜂箱里还没有蜂王"}
		if escaped:
			return {"ok": false, "reason": "蜂群已经逃走了"}
		if diseased:
			return {"ok": false, "reason": "蜂群生病了，先用蜂群药物治疗"}
		if days_since_harvest < get_interval_days():
			return {"ok": false, "reason": "还没到收蜜的时候（%d/%d 天）" % [days_since_harvest, get_interval_days()]}
		if weather == "rain" or weather == "storm":
			return {"ok": false, "reason": "雨天蜜蜂不出巢"}
		return {"ok": false, "reason": "冬季户外蜂箱停产（放进温室才能产蜜）"}

	days_since_harvest = 0
	var efficiency := get_efficiency(flower_type_count)
	var amount := maxi(1, int(round(1.0 + float(flower_type_count) * 0.3 * efficiency)))
	amount = mini(amount, 4)

	# 品质：花源种类 + 健康度影响
	var quality_table := {
		"normal": 0.70, "silver": 0.20, "gold": 0.09, "star": 0.01,
	}
	if flower_type_count >= 3:
		quality_table = {"normal": 0.50, "silver": 0.28, "gold": 0.18, "star": 0.04}
	if health >= 80.0:
		quality_table = {"normal": 0.40, "silver": 0.30, "gold": 0.24, "star": 0.06}
	var quality := Quality.roll_from_table(quality_table)

	# 稀有蜂蜜：基础 5%，森林农场 +2%，5×5 内花源 ≥5 +1%
	var rarity := DB.get_rare_honey_config()
	var rare_chance := float(rarity.get("base_chance", 0.05))
	if flower_type_count >= int(rarity.get("many_flower_threshold", 5)):
		rare_chance += float(rarity.get("many_flower_bonus", 0.01))
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var rare_honey := ""
	if rng.randf() < rare_chance:
		var types: Array = rarity.get("types", [])
		if not types.is_empty():
			rare_honey = str(types[rng.randi_range(0, types.size() - 1)])

	var items: Array = []
	items.append({
		"item_id": "honey",
		"name": "蜂蜜",
		"category": "bee_product",
		"count": amount,
		"quality": quality,
		"price": Quality.apply_quality_price(200, quality),
	})

	# 健康 ≥80 有概率额外蜂蜡
	if health >= 80.0 and rng.randf() < 0.35:
		items.append({
			"item_id": "beeswax",
			"name": "蜂蜡",
			"category": "bee_product",
			"count": 1,
			"quality": "normal",
			"price": 120,
		})

	# 稀有蜂蜜单独给 1 个
	if not rare_honey.is_empty():
		var product := DB.get_bee_product(rare_honey)
		items.append({
			"item_id": rare_honey,
			"name": str(product.get("name", rare_honey)),
			"category": "bee_product",
			"count": 1,
			"quality": "star",
			"is_rare": true,
			"price": int(DB.get_sell_price(rare_honey)),
		})

	last_quality = quality
	last_rare_honey = rare_honey
	hive_changed.emit()
	queue_redraw()
	return {"ok": true, "reason": "", "items": items}


# ============================================================
# 存档
# ============================================================

func to_save() -> Dictionary:
	return {
		"x": grid_pos.x,
		"y": grid_pos.y,
		"has_queen": has_queen,
		"health": health,
		"days_since_harvest": days_since_harvest,
		"diseased": diseased,
		"greenhouse": greenhouse,
		"escaped": escaped,
		"last_quality": last_quality,
		"last_rare_honey": last_rare_honey,
	}


func from_save(data: Dictionary) -> void:
	grid_pos = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	has_queen = bool(data.get("has_queen", false))
	health = clampf(float(data.get("health", 60.0)), 0.0, 100.0)
	days_since_harvest = maxi(0, int(data.get("days_since_harvest", 0)))
	diseased = bool(data.get("diseased", false))
	greenhouse = bool(data.get("greenhouse", false))
	escaped = bool(data.get("escaped", false))
	last_quality = str(data.get("last_quality", ""))
	last_rare_honey = str(data.get("last_rare_honey", ""))
	position = Vector2(grid_pos) * TILE + Vector2(TILE * 0.5, TILE)
	queue_redraw()


# ============================================================
# 绘制
# ============================================================

func _process(delta: float) -> void:
	_phase += delta
	if has_queen and not escaped:
		queue_redraw()


func _draw() -> void:
	Art.shadow(self, 0, 0, 8.0, 2.6)

	# 蜂箱：木箱 + 分层 + 进出口
	Art.rect(self, -5.5, -14.0, 11.0, 14.0, Color("#c9a46a"))
	Art.rect(self, -5.0, -13.4, 10.0, 12.8, Color("#d8b87e"))
	# 层缝
	Art.hline(self, -5.0, -9.0, 10.0, Color("#b08e58"))
	Art.hline(self, -5.0, -5.0, 10.0, Color("#b08e58"))
	# 顶盖
	Art.rect(self, -6.5, -16.0, 13.0, 2.6, Color("#8c6a4a"))
	Art.rect(self, -6.0, -15.6, 12.0, 1.0, Color("#a9825c"))
	# 出入口
	Art.rect(self, -1.6, -4.0, 3.2, 1.6, Color("#4a3520"))

	# 蜜蜂：健康且有蜂王时在箱口飞舞（简单像素点）
	if has_queen and not escaped and not diseased:
		for index in 3:
			var angle := _phase * (2.0 + float(index) * 0.4) + float(index) * 2.1
			var bx := cos(angle) * (4.0 + float(index))
			var by := -4.0 + sin(angle * 1.7) * 3.0
			Art.rect(self, bx, by, 1.0, 1.0, Color("#e3c25a"))

	# 状态标记
	if escaped:
		Art.rect(self, -2.0, -12.0, 4.0, 2.0, Color("#a87362"))
	elif diseased:
		# 病气泡：灰色小点
		Art.rect(self, 4.0, -20.0, 2.0, 2.0, Color("#9c9080"))
		Art.rect(self, 5.0, -22.0, 1.6, 1.6, Color("#b0a494"))
	elif days_since_harvest >= get_interval_days() and has_queen:
		# 可收蜜提示：金色小点
		Art.rect(self, 5.0, -20.0, 2.0, 2.0, Color("#e8c56a"))
