class_name QualityUtil
extends RefCounted
## 品质判定（普通 / 银 / 金 / 星光）。
##
## 按《代码架构规范》2.7 与《个人单机开发要求》：
##   - 概率表放 config/quality.json
##   - 每次判定新建 RNG（和 RarityUtil 一致）
##   - 品质倍率放 config/economy.json → quality_multiplier
##
## 用法：
##     var quality := QualityUtil.roll_crop_quality(tile.fertilized)
##     var price := QualityUtil.apply_quality_price(base_price, quality)

const DB := preload("res://scripts/core/ConfigDB.gd")

const QUALITY_ORDER := ["normal", "silver", "gold", "star"]
const QUALITY_NAMES := {
	"normal": "普通",
	"silver": "银",
	"gold": "金",
	"star": "星光",
}

static var _seed_counter := 0


static func _new_rng(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		_seed_counter += 1
		var entropy := Time.get_ticks_usec() * 0x100000001 + Time.get_ticks_msec() * 7919
		rng.seed = entropy + _seed_counter * 0x9E3779B9
	rng.randi()
	rng.randi()
	return rng


static func get_quality_name(quality_id: String) -> String:
	return str(QUALITY_NAMES.get(quality_id, quality_id))


## 按概率表抽一个品质。table 是 { "normal": 0.7, "silver": 0.2, ... }
static func roll_from_table(table: Dictionary, rng_seed := -1) -> String:
	if table.is_empty():
		return "normal"
	var total := 0.0
	for key: Variant in table.keys():
		total += maxf(0.0, float(table[key]))
	if total <= 0.0:
		return "normal"

	var rng := _new_rng(rng_seed)
	var pick := rng.randf() * total
	for quality: String in QUALITY_ORDER:
		if not table.has(quality):
			continue
		pick -= maxf(0.0, float(table[quality]))
		if pick <= 0.0:
			return quality
	return "normal"


## 作物品质：施肥后高档概率提升。
static func roll_crop_quality(is_fertilized: bool, rng_seed := -1) -> String:
	var config: Dictionary = DB.get_quality().get("crop", {})
	var table: Dictionary = config.get("fertilized" if is_fertilized else "unfertilized", {})
	return roll_from_table(table, rng_seed)


## 动物产物品质：好感高时更好。
static func roll_animal_quality(friendship: float, friendship_max := 100.0, rng_seed := -1) -> String:
	var config: Dictionary = DB.get_quality().get("animal", {})
	var ratio := friendship / maxf(1.0, friendship_max)
	var table: Dictionary = config.get("high_friendship" if ratio >= 0.6 else "low_friendship", {})
	return roll_from_table(table, rng_seed)


## 鱼品质：高级鱼竿更好。
static func roll_fish_quality(has_high_rod: bool, rng_seed := -1) -> String:
	var config: Dictionary = DB.get_quality().get("fish", {})
	var table: Dictionary = config.get("high_rod" if has_high_rod else "normal_rod", {})
	return roll_from_table(table, rng_seed)


## 品质售价倍率（config/economy.json）。
static func quality_multiplier(quality_id: String) -> float:
	var multipliers: Dictionary = DB.get_economy().get("quality_multiplier", {})
	return float(multipliers.get(quality_id, 1.0))


static func apply_quality_price(base_price: int, quality_id: String) -> int:
	return int(round(float(base_price) * quality_multiplier(quality_id)))


static func quality_index(quality_id: String) -> int:
	var index := QUALITY_ORDER.find(quality_id)
	return maxi(0, index)
