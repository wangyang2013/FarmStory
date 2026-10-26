class_name RarityUtil
extends RefCounted
## 稀有判定工具。
##
## 设计约束：
## 1. 概率、稀有类型、颜色、售价倍率全部来自 config/rarity.json，本文件不写死数值。
## 2. 每一次判定都新建 RandomNumberGenerator；
##    种子由「高精度时间 + 自增计数」混合，避免同一帧连续判定拿到相同序列。
## 3. 返回的 rare_color / rare_type 是稳定 id，显示名另外返回，方便以后改中文名。

const DB := preload("res://scripts/core/ConfigDB.gd")

## 只作为种子熵来源，不参与随机序列，因此不算全局共用 RNG。
static var _seed_counter := 0


## splitmix64：把「时间 + 自增计数」混合成分布良好的 64 位种子。
## 直接拿连续计数器当 seed 时，PCG 的前几个输出会明显相关，
## 表现就是「同一帧连续判定时稀有率偏离配置值」。
static func _mix_seed(value: int) -> int:
	var z := value + -7046029254386353131  # 0x9E3779B97F4A7C15 的有符号表示
	z = (z ^ (z >> 30)) * -4658895280553007687  # 0xBF58476D1CE4E5B9
	z = (z ^ (z >> 27)) * -7723592293110705685  # 0x94D049BB133111EB
	return z ^ (z >> 31)


static func _new_rng(rng_seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = _mix_seed(rng_seed)
	else:
		_seed_counter += 1
		var entropy := Time.get_ticks_usec() * 0x100000001 + Time.get_ticks_msec() * 7919
		rng.seed = _mix_seed(entropy + _seed_counter * 0x9E3779B9)
	# 丢掉前两个输出，进一步消除种子相近带来的首值相关性。
	rng.randi()
	rng.randi()
	return rng


static func _rarity_config() -> Dictionary:
	return DB.get_rarity()


static func _price_multipliers() -> Dictionary:
	return _rarity_config().get("price_multipliers", {})


# ============================================================
# 作物：giant / heavy / giant_heavy
# ============================================================

## is_fertilized 决定基础概率（普通 5%，施肥 12%）。
## can_rare 对应 crops.json 的 can_rare 字段。
## 返回：{ is_rare, rare_type, rare_name, price_multiplier }
static func roll_crop_rarity(
	is_fertilized: bool,
	can_rare := true,
	rng_seed := -1
) -> Dictionary:
	var result := {
		"is_rare": false,
		"rare_type": "",
		"rare_name": "",
		"price_multiplier": 1.0,
	}
	if not can_rare:
		return result

	var config: Dictionary = _rarity_config().get("crop", {})
	var chance := float(config.get("fertilized_chance", 0.12)) if is_fertilized \
		else float(config.get("base_chance", 0.05))

	var rng := _new_rng(rng_seed)
	if rng.randf() >= chance:
		return result

	var types: Array = config.get("types", [])
	if types.is_empty():
		result["is_rare"] = true
		result["rare_type"] = "giant"
		result["rare_name"] = crop_rare_label("giant")
		result["price_multiplier"] = crop_price_multiplier("giant")
		return result

	var total_weight := 0.0
	for item: Variant in types:
		if item is Dictionary:
			total_weight += maxf(0.0, float(item.get("weight", 1.0)))

	var pick := rng.randf() * total_weight
	var chosen := "giant"
	for item: Variant in types:
		if not (item is Dictionary):
			continue
		pick -= maxf(0.0, float(item.get("weight", 1.0)))
		if pick <= 0.0:
			chosen = str(item.get("id", "giant"))
			break

	result["is_rare"] = true
	result["rare_type"] = chosen
	result["rare_name"] = crop_rare_label(chosen)
	result["price_multiplier"] = crop_price_multiplier(chosen)
	return result


static func crop_rare_label(rare_type: String) -> String:
	match rare_type:
		"giant":
			return "超大"
		"heavy":
			return "超重"
		"giant_heavy":
			return "超大超重"
		_:
			return ""


static func crop_price_multiplier(rare_type: String) -> float:
	var multipliers := _price_multipliers()
	var giant := float(multipliers.get("giant", 1.5))
	var heavy := float(multipliers.get("heavy", 1.2))
	match rare_type:
		"giant":
			return giant
		"heavy":
			return heavy
		"giant_heavy":
			return giant * heavy
		_:
			return 1.0


## 稀有售价上限：文档要求不超过普通 3 倍（config/economy.json）。
static func _cap_multiplier(multiplier: float) -> float:
	var cap := DB.get_rare_price_cap()
	return minf(multiplier, cap)


static func apply_crop_price(base_price: int, rare_type: String) -> int:
	return int(round(float(base_price) * _cap_multiplier(crop_price_multiplier(rare_type))))


# ============================================================
# 畜牧：幼崽稀有毛色
# ============================================================

## 双亲普通 4% / 一方稀有 10% / 双亲稀有 22%。
## 返回：{ is_rare, rare_color(id), rare_color_name }
static func roll_animal_rarity(
	parent_a_rare: bool,
	parent_b_rare: bool,
	can_rare_color := true,
	rng_seed := -1
) -> Dictionary:
	var result := {
		"is_rare": false,
		"rare_color": "",
		"rare_color_name": "",
	}
	if not can_rare_color:
		return result

	var config: Dictionary = _rarity_config().get("animal", {})
	var chance := float(config.get("base_chance", 0.04))
	if parent_a_rare and parent_b_rare:
		chance = float(config.get("both_rare_parent_chance", 0.22))
	elif parent_a_rare or parent_b_rare:
		chance = float(config.get("one_rare_parent_chance", 0.10))

	var colors: Array = config.get("colors", [])
	if colors.is_empty():
		return result

	var rng := _new_rng(rng_seed)
	if rng.randf() >= chance:
		return result

	var color: Variant = colors[rng.randi_range(0, colors.size() - 1)]
	if color is Dictionary:
		result["is_rare"] = true
		result["rare_color"] = str(color.get("id", ""))
		result["rare_color_name"] = str(color.get("name", ""))
	return result


# ============================================================
# 鱼类：异色 / 超大 / 超重（三次独立 roll，可叠加）
# ============================================================

## fish_def 传入鱼配置时，会尊重 can_rare_color / can_giant / can_heavy。
## extra_bonus 用于高级鱼饵等额外加成。
## 返回：{ is_rare_color, is_giant, is_heavy, price_multiplier }
static func roll_fish_rarity(
	has_high_rod: bool,
	is_rain: bool,
	is_dusk: bool,
	fish_def: Dictionary = {},
	extra_bonus := 0.0,
	rng_seed := -1
) -> Dictionary:
	var config: Dictionary = _rarity_config().get("fish", {})
	var bonus := maxf(0.0, extra_bonus)
	if has_high_rod:
		bonus += float(config.get("high_rod_bonus", 0.02))
	if is_rain or is_dusk:
		bonus += float(config.get("rain_or_dusk_bonus", 0.01))

	var can_color := true
	var can_giant := true
	var can_heavy := true
	if not fish_def.is_empty():
		can_color = bool(fish_def.get("can_rare_color", true))
		can_giant = bool(fish_def.get("can_giant", true))
		can_heavy = bool(fish_def.get("can_heavy", true))

	# 三次独立 roll：顺序消耗同一个新建 RNG 的不同随机数。
	var rng := _new_rng(rng_seed)
	var rare_color := rng.randf() < float(config.get("rare_color_chance", 0.05)) + bonus
	var giant := rng.randf() < float(config.get("giant_chance", 0.04)) + bonus
	var heavy := rng.randf() < float(config.get("heavy_chance", 0.06)) + bonus

	rare_color = rare_color and can_color
	giant = giant and can_giant
	heavy = heavy and can_heavy

	var multipliers := _price_multipliers()
	var price_multiplier := 1.0
	if rare_color:
		price_multiplier *= float(multipliers.get("rare_color", 1.8))
	if giant:
		price_multiplier *= float(multipliers.get("giant", 1.5))
	if heavy:
		price_multiplier *= float(multipliers.get("heavy", 1.2))

	return {
		"is_rare_color": rare_color,
		"is_giant": giant,
		"is_heavy": heavy,
		"price_multiplier": _cap_multiplier(price_multiplier),
	}


static func apply_fish_price(base_price: int, rarity: Dictionary) -> int:
	return int(round(float(base_price) * _cap_multiplier(float(rarity.get("price_multiplier", 1.0)))))


static func fish_rare_label(rarity: Dictionary) -> String:
	var parts := PackedStringArray()
	if bool(rarity.get("is_rare_color", false)):
		parts.append("异色")
	if bool(rarity.get("is_giant", false)):
		parts.append("超大")
	if bool(rarity.get("is_heavy", false)):
		parts.append("超重")
	return "·".join(parts)


static func fish_is_rare(rarity: Dictionary) -> bool:
	return bool(rarity.get("is_rare_color", false)) \
		or bool(rarity.get("is_giant", false)) \
		or bool(rarity.get("is_heavy", false))


# ============================================================
# 果树：稀有大果
# ============================================================

static func roll_fruit_rarity(rng_seed := -1) -> Dictionary:
	var rules: Dictionary = DB.get_fruit_tree_rules()
	var chance := float(rules.get("rare_chance", 0.05))
	var multiplier := float(rules.get("rare_price_multiplier", 1.5))
	var rare_type := str(rules.get("rare_type", "giant_fruit"))

	var rng := _new_rng(rng_seed)
	var is_rare := rng.randf() < chance
	return {
		"is_rare": is_rare,
		"rare_type": rare_type if is_rare else "",
		"price_multiplier": multiplier if is_rare else 1.0,
	}


# ============================================================
# 蜂产品：稀有蜂蜜
# ============================================================

static func roll_rare_honey(
	is_forest_farm: bool,
	flower_type_count: int,
	rng_seed := -1
) -> Dictionary:
	var config: Dictionary = DB.get_rare_honey_config()
	var chance := float(config.get("base_chance", 0.05))
	if is_forest_farm:
		chance += float(config.get("forest_farm_bonus", 0.02))
	if flower_type_count >= int(config.get("many_flower_threshold", 5)):
		chance += float(config.get("many_flower_bonus", 0.01))

	var types: Array = config.get("types", [])
	if types.is_empty():
		return {"is_rare": false, "honey_id": ""}

	var rng := _new_rng(rng_seed)
	if rng.randf() >= chance:
		return {"is_rare": false, "honey_id": ""}
	return {
		"is_rare": true,
		"honey_id": str(types[rng.randi_range(0, types.size() - 1)]),
	}


# ============================================================
# 鸟类 / 昆虫：异色 / 巨大
# ============================================================

static func roll_bird_rarity(
	has_high_net: bool,
	can_rare_color := true,
	can_giant := true,
	rng_seed := -1
) -> Dictionary:
	return _roll_capture_rarity("bird", has_high_net, false, can_rare_color, can_giant, rng_seed)


static func roll_insect_rarity(
	has_high_net: bool,
	is_dusk: bool,
	can_rare_color := true,
	can_giant := true,
	rng_seed := -1
) -> Dictionary:
	return _roll_capture_rarity("insect", has_high_net, is_dusk, can_rare_color, can_giant, rng_seed)


static func _roll_capture_rarity(
	config_key: String,
	has_high_net: bool,
	is_dusk: bool,
	can_rare_color: bool,
	can_giant: bool,
	rng_seed: int
) -> Dictionary:
	var config: Dictionary = _rarity_config().get(config_key, {})
	var bonus := float(config.get("high_net_bonus", 0.02)) if has_high_net else 0.0
	if is_dusk:
		bonus += float(config.get("dusk_bonus", 0.01))
	var chance := float(config.get("base_chance", 0.05)) + bonus

	var rng := _new_rng(rng_seed)
	var rare_color := can_rare_color and rng.randf() < chance
	var giant := can_giant and rng.randf() < chance

	var multipliers := _price_multipliers()
	var price_multiplier := 1.0
	if rare_color:
		price_multiplier *= float(multipliers.get("rare_color", 1.8))
	if giant:
		price_multiplier *= float(multipliers.get("giant", 1.5))

	return {
		"is_rare_color": rare_color,
		"is_giant": giant,
		"price_multiplier": _cap_multiplier(price_multiplier),
	}


static func apply_generic_price(base_price: int, rarity: Dictionary) -> int:
	return int(round(float(base_price) * _cap_multiplier(float(rarity.get("price_multiplier", 1.0)))))
