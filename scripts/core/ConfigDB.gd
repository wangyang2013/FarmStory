class_name ConfigDB
extends RefCounted
## 只读配置库。
##
## 所有数值都来自 res://config/*.json，脚本里只保留字段名与取数逻辑。
## 启动时由 ConfigBootstrap（Autoload）调用 load_all()，也可以随时按需加载。
##
## 用法：
##     var turnip := ConfigDB.get_crop("turnip")
##     print(turnip["name"], " 成熟需要 ", turnip["grow_day"], " 天")

const CONFIG_DIR := "res://config/"

const FILE_MAP := {
	"crops": "crops.json",
	"animals": "animals.json",
	"fishes": "fishes.json",
	"fruit_trees": "fruit_trees.json",
	"fishing_tools": "fishing_tools.json",
	"beekeeping": "beekeeping.json",
	"birds": "birds.json",
	"insects": "insects.json",
	"recipes": "recipes.json",
	"rarity": "rarity.json",
	"fishing_minigame": "fishing_minigame.json",
	"environment": "environment.json",
	"gameplay": "gameplay.json",
	"shop": "shop.json",
	"pets": "pets.json",
	"pet_houses": "pet_houses.json",
	"pet_food": "pet_food.json",
	"pet_decorations": "pet_decorations.json",
	"economy": "economy.json",
	"quality": "quality.json",
	"accessories": "accessories.json",
	"processing": "processing.json",
	"combat": "combat.json",
	"npcs": "npcs.json",
	"festivals": "festivals.json",
	"quests": "quests.json",
	"buildings": "buildings.json",
	"museum_artifacts": "museum.json",
	"mail": "mail.json",
	"cellar": "cellar.json",
	"achievements": "achievements.json",
	"library": "library.json",
	"services": "services.json",
	"workers": "workers.json",
	"furniture": "furniture.json",
	"interiors": "interiors.json",
	"mounts": "mounts.json",
}

## 文档要求的关键字段。缺字段会在 validate() 里报出来，避免运行到一半才崩。
const REQUIRED_FIELDS := {
	"crops": [
		"id", "name", "season", "grow_day", "repeat_harvest",
		"base_price", "can_rare", "is_flower", "greenhouse_only",
	],
	"animals": [
		"id", "name", "category", "barn_type", "product_id",
		"product_name", "can_rare_color", "buy_price",
	],
	"fishes": [
		"id", "name", "water_area", "season", "time_of_day", "weather",
		"weight_min", "weight_max", "base_price",
		"can_rare_color", "can_giant", "can_heavy", "min_rod_level",
	],
}

const SEASON_NAMES := {
	"spring": "春",
	"summer": "夏",
	"autumn": "秋",
	"winter": "冬",
	"any": "全季",
}

const TIME_NAMES := {
	"day": "白天",
	"night": "夜晚",
	"dawn_dusk": "晨昏",
	"any": "全天",
	"spring_summer": "春夏季",
}

const WEATHER_NAMES := {
	"sunny": "晴",
	"rain": "雨",
	"storm": "暴雨",
	"snow": "雪",
	"blizzard": "暴雪",
	"any": "任意",
}

static var _raw: Dictionary = {}
static var _by_id: Dictionary = {}
static var _ids: Dictionary = {}
static var _loaded := false
static var _load_errors: Array[String] = []


# ------------------------------------------------------------
# 加载
# ------------------------------------------------------------

## 读取全部配置。force = true 可热重载（编辑器里改完 JSON 直接调用）。
static func load_all(force := false) -> bool:
	if _loaded and not force:
		return _load_errors.is_empty()

	_raw.clear()
	_by_id.clear()
	_ids.clear()
	_load_errors.clear()

	for key: String in FILE_MAP.keys():
		var path: String = CONFIG_DIR + FILE_MAP[key]
		var data: Variant = _read_json(path)
		if data == null:
			_load_errors.append("无法读取或解析：%s" % path)
			continue
		_raw[key] = data
		if data is Array:
			_build_index(key, data)
		elif data is Dictionary:
			_build_nested_index(key, data)

	_loaded = true
	_validate_required_fields()
	_build_item_index()

	var summary := "crops=%d animals=%d fishes=%d birds=%d insects=%d recipes=%d" % [
		_id_list("crops").size(),
		_id_list("animals").size(),
		_id_list("fishes").size(),
		_id_list("birds").size(),
		_id_list("insects").size(),
		_id_list("recipes").size(),
	]
	if _load_errors.is_empty():
		print("[ConfigDB] 配置加载完成：", summary)
	else:
		print("[ConfigDB] 配置加载完成（有 %d 个问题）：%s" % [_load_errors.size(), summary])
		for message: String in _load_errors:
			push_error("[ConfigDB] " + message)
	return _load_errors.is_empty()


static func is_loaded() -> bool:
	return _loaded


static func get_load_errors() -> Array[String]:
	return _load_errors.duplicate()


static func _ensure_loaded() -> void:
	if not _loaded:
		load_all()


static func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("[ConfigDB] 配置文件不存在：" + path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[ConfigDB] 无法打开配置：%s（错误码 %d）" % [path, FileAccess.get_open_error()])
		return null
	var text := file.get_as_text()
	file.close()

	# JSON.parse：不认注释，配置里不要写注释。
	var json := JSON.new()
	var error := json.parse(text)
	if error != OK:
		push_error("[ConfigDB] JSON 解析失败：%s 第 %d 行：%s" % [
			path, json.get_error_line(), json.get_error_message(),
		])
		return null
	return json.data


static func _build_index(key: String, items: Array) -> void:
	var index: Dictionary = {}
	var order: Array[String] = []
	for item: Variant in items:
		if not (item is Dictionary) or not item.has("id"):
			_load_errors.append("%s 中有条目缺少 id" % key)
			continue
		var id := str(item["id"])
		if index.has(id):
			_load_errors.append("%s 中存在重复 id：%s" % [key, id])
			continue
		index[id] = item
		order.append(id)
	_by_id[key] = index
	_ids[key] = order


static func _build_nested_index(key: String, data: Dictionary) -> void:
	match key:
		"fishing_tools":
			_build_index("rods", data.get("rods", []))
			_build_index("crab_pots", data.get("crab_pots", []))
			_build_index("baits", data.get("baits", []))
			_build_index("tackles", data.get("tackles", []))
		"fruit_trees":
			_build_index("fruit_tree_list", data.get("trees", []))
		"beekeeping":
			_build_index("bee_products", data.get("products", []))
		_:
			pass


static func _validate_required_fields() -> void:
	for key: String in REQUIRED_FIELDS.keys():
		var index: Dictionary = _by_id.get(key, {})
		for id: String in index.keys():
			var definition: Dictionary = index[id]
			for field: String in REQUIRED_FIELDS[key]:
				if not definition.has(field):
					_load_errors.append("%s.%s 缺少字段 %s" % [key, id, field])


# ------------------------------------------------------------
# 通用访问
# ------------------------------------------------------------

static func _id_list(key: String) -> Array[String]:
	_ensure_loaded()
	var result: Array[String] = []
	for id: Variant in _ids.get(key, []):
		result.append(str(id))
	return result


static func _definition(key: String, id: String) -> Dictionary:
	_ensure_loaded()
	var index: Dictionary = _by_id.get(key, {})
	return index.get(id, {})


static func _definitions(key: String) -> Array:
	_ensure_loaded()
	var result: Array = []
	var index: Dictionary = _by_id.get(key, {})
	for id: Variant in _ids.get(key, []):
		result.append(index.get(str(id), {}))
	return result


static func _raw_section(key: String) -> Dictionary:
	_ensure_loaded()
	var section: Variant = _raw.get(key, {})
	return section if section is Dictionary else {}


# ------------------------------------------------------------
# 作物（40 种）
# ------------------------------------------------------------

static func get_crop(id: String) -> Dictionary:
	return _definition("crops", id)


static func get_all_crops() -> Array:
	return _definitions("crops")


static func get_crop_ids() -> Array[String]:
	return _id_list("crops")


static func get_crops_by_season(season: String) -> Array:
	var result: Array = []
	for definition: Dictionary in get_all_crops():
		if str(definition.get("season", "")) == season:
			result.append(definition)
	return result


# ------------------------------------------------------------
# 动物（30 种）
# ------------------------------------------------------------

static func get_animal(id: String) -> Dictionary:
	return _definition("animals", id)


static func get_all_animals() -> Array:
	return _definitions("animals")


static func get_animal_ids() -> Array[String]:
	return _id_list("animals")


static func get_animals_by_category(category: String) -> Array:
	var result: Array = []
	for definition: Dictionary in get_all_animals():
		if str(definition.get("category", "")) == category:
			result.append(definition)
	return result


# ------------------------------------------------------------
# 鱼类（40 种）
# ------------------------------------------------------------

static func get_fish(id: String) -> Dictionary:
	return _definition("fishes", id)


static func get_all_fishes() -> Array:
	return _definitions("fishes")


static func get_fish_ids() -> Array[String]:
	return _id_list("fishes")


static func get_fishes_by_area(water_area: String) -> Array:
	var result: Array = []
	for definition: Dictionary in get_all_fishes():
		if str(definition.get("water_area", "")) == water_area:
			result.append(definition)
	return result


static func fish_matches(
	definition: Dictionary,
	water_area: String,
	season: String,
	time_of_day: String,
	weather: String,
	rod_level: int
) -> bool:
	if definition.is_empty():
		return false
	if str(definition.get("water_area", "")) != water_area:
		return false
	if int(definition.get("min_rod_level", 0)) > rod_level:
		return false
	var required_season := str(definition.get("season", "any"))
	if required_season != "any" and required_season != season:
		return false
	var required_time := str(definition.get("time_of_day", "any"))
	if required_time != "any" and required_time != time_of_day:
		return false
	var required_weather := str(definition.get("weather", "any"))
	if required_weather != "any" and required_weather != weather:
		return false
	return true


## 返回当前水域/季节/时段/天气/鱼竿等级下所有可钓的鱼定义。
static func get_fish_candidates(
	water_area: String,
	season: String,
	time_of_day: String,
	weather: String,
	rod_level: int
) -> Array:
	var result: Array = []
	for definition: Dictionary in get_all_fishes():
		if fish_matches(definition, water_area, season, time_of_day, weather, rod_level):
			result.append(definition)
	return result


# ------------------------------------------------------------
# 鸟类 / 昆虫
# ------------------------------------------------------------

static func get_bird(id: String) -> Dictionary:
	return _definition("birds", id)


static func get_all_birds() -> Array:
	return _definitions("birds")


static func get_insect(id: String) -> Dictionary:
	return _definition("insects", id)


static func get_all_insects() -> Array:
	return _definitions("insects")


# ------------------------------------------------------------
# 菜谱
# ------------------------------------------------------------

static func get_recipe(id: String) -> Dictionary:
	return _definition("recipes", id)


static func get_all_recipes() -> Array:
	return _definitions("recipes")


# ------------------------------------------------------------
# 果树
# ------------------------------------------------------------

static func get_fruit_tree_rules() -> Dictionary:
	return _raw_section("fruit_trees").get("global_rules", {})


static func get_fruit_tree(id: String) -> Dictionary:
	return _definition("fruit_tree_list", id)


static func get_all_fruit_trees() -> Array:
	return _definitions("fruit_tree_list")


# ------------------------------------------------------------
# 钓鱼工具
# ------------------------------------------------------------

static func get_fishing_limits() -> Dictionary:
	return _raw_section("fishing_tools").get("global_limits", {})


static func get_rod(id: String) -> Dictionary:
	return _definition("rods", id)


static func get_all_rods() -> Array:
	return _definitions("rods")


static func get_bait(id: String) -> Dictionary:
	return _definition("baits", id)


static func get_all_baits() -> Array:
	return _definitions("baits")


static func get_tackle(id: String) -> Dictionary:
	return _definition("tackles", id)


static func get_all_tackles() -> Array:
	return _definitions("tackles")


static func get_crab_pot(id: String) -> Dictionary:
	return _definition("crab_pots", id)


static func get_all_crab_pots() -> Array:
	return _definitions("crab_pots")


# ------------------------------------------------------------
# 养蜂
# ------------------------------------------------------------

static func get_beekeeping() -> Dictionary:
	return _raw_section("beekeeping")


static func get_hive_config() -> Dictionary:
	return get_beekeeping().get("hive", {})


static func get_flower_bonus_config() -> Dictionary:
	return get_beekeeping().get("flower_bonus", {})


static func get_rare_honey_config() -> Dictionary:
	return get_beekeeping().get("rare_honey", {})


static func get_bee_product(id: String) -> Dictionary:
	return _definition("bee_products", id)


static func get_all_bee_products() -> Array:
	return _definitions("bee_products")


# ------------------------------------------------------------
# 博物馆古物
# ------------------------------------------------------------

static func get_all_artifacts() -> Array:
	return _definitions("museum_artifacts")


static func get_artifact(id: String) -> Dictionary:
	return _definition("museum_artifacts", id)


# ------------------------------------------------------------
# 邮箱信件
# ------------------------------------------------------------

static func get_all_mail() -> Array:
	return _definitions("mail")


static func get_mail(id: String) -> Dictionary:
	return _definition("mail", id)


static func get_cellar_config() -> Dictionary:
	return _raw_section("cellar")


static func get_all_achievements() -> Array:
	return _definitions("achievements")


static func get_all_books() -> Array:
	return _definitions("library")


static func get_book(id: String) -> Dictionary:
	return _definition("library", id)


static func get_services_config() -> Dictionary:
	return _raw_section("services")


static func get_all_workers() -> Array:
	return _definitions("workers")


static func get_worker(id: String) -> Dictionary:
	return _definition("workers", id)


static func get_all_furniture() -> Array:
	return _definitions("furniture")


static func get_furniture(id: String) -> Dictionary:
	return _definition("furniture", id)


static func get_interior(building_id: String) -> Dictionary:
	var data: Variant = _raw_section("interiors").get(building_id, {})
	return data if data is Dictionary else {}


static func get_all_interiors() -> Dictionary:
	_ensure_loaded()
	return _raw_section("interiors")


# ------------------------------------------------------------
# 稀有与钓鱼小游戏参数
# ------------------------------------------------------------

static func get_rarity() -> Dictionary:
	return _raw_section("rarity")


static func get_fishing_minigame() -> Dictionary:
	return _raw_section("fishing_minigame")


static func get_environment() -> Dictionary:
	return _raw_section("environment")


static func get_days_per_season() -> int:
	return maxi(1, int(get_environment().get("days_per_season", 30)))


static func get_day_cycle() -> Dictionary:
	return get_environment().get("day_cycle", {})


static func get_sleep_rules() -> Dictionary:
	return get_environment().get("sleep_rules", {})


static func get_machine_processing() -> Dictionary:
	return get_environment().get("machine_processing", {})


# ------------------------------------------------------------
# 时间相关扩展（游戏时间对照表）
# ------------------------------------------------------------

## 时间流速档位：slow / normal / fast。
static func get_day_speed_presets() -> Dictionary:
	return get_day_cycle().get("speed_presets", {})


static func get_real_seconds_per_game_minute(speed_id := "") -> float:
	var presets := get_day_speed_presets()
	if not speed_id.is_empty() and presets.has(speed_id):
		return float(presets[speed_id])
	return float(get_day_cycle().get("real_seconds_per_game_minute", 0.7))


## 睡觉恢复分档：18-24 → 100%；24-2 → 70%；2-6 → 40%。
## minutes 是「从当天 06:00 起算的绝对分钟」：1080 = 18:00，1440 = 次日 00:00，
## 1560 = 次日 02:00，1800 = 次日 06:00。
static func get_sleep_stamina_ratio(minutes: float) -> float:
	var rules := get_sleep_rules()
	var late := 1440.0   # 24:00
	var very_late := float(get_very_late_sleep_minutes()) + 1440.0  # 02:00 = 1560
	if minutes >= very_late:
		return float(rules.get("very_late_sleep_stamina_ratio", 0.4))
	if minutes >= late:
		return float(rules.get("late_sleep_stamina_ratio", 0.7))
	return 1.0


## 2:00 之后只是恢复更少，不强制晕倒（新版游戏时间对照表）。
## 保留接口：如果以后想开启，把 collapse_on_late_night 设为 true 即可。
static func is_forced_collapse_enabled() -> bool:
	return bool(get_sleep_rules().get("collapse_on_late_night", false))


static func get_very_late_sleep_minutes() -> int:
	return _time_text_to_minutes(str(get_sleep_rules().get("very_late_sleep_after", "02:00")))


static func get_collapse_wake_minutes() -> int:
	return _time_text_to_minutes(str(get_sleep_rules().get("collapse_wake_time", "08:00")))


static func get_shop_hours(shop_id: String) -> Dictionary:
	var hours: Dictionary = get_environment().get("shop_hours", {})
	var entry: Variant = hours.get(shop_id, {})
	return entry if entry is Dictionary else {}


## 判断当前时间商店是否营业。返回 { open: bool, reason: String }
static func is_shop_open(shop_id: String, current_minutes: int) -> Dictionary:
	var entry := get_shop_hours(shop_id)
	if entry.is_empty():
		return {"open": true, "reason": ""}
	var open_at := _time_text_to_minutes(str(entry.get("open", "09:00")))
	var close_at := _time_text_to_minutes(str(entry.get("close", "17:00")))
	var absolute := posmod(current_minutes, 1440)
	var is_open := absolute >= open_at and absolute < close_at
	return {
		"open": is_open,
		"reason": "" if is_open else "%s 的营业时间是 %s–%s" % [
			str(entry.get("name", "商店")),
			str(entry.get("open", "09:00")),
			str(entry.get("close", "17:00")),
		],
	}


static func get_banner_seconds(kind := "day") -> float:
	var banners: Dictionary = get_environment().get("banners", {})
	if kind == "season":
		return float(banners.get("season_banner_seconds", 2.0))
	return float(banners.get("day_banner_seconds", 1.5))


static func get_fatigue_warning_ratio() -> float:
	return float(get_environment().get("fatigue_warning_ratio", 0.2))


static func _time_text_to_minutes(text: String) -> int:
	var parts := text.split(":")
	if parts.size() != 2:
		return 0
	return int(parts[0].to_int()) * 60 + int(parts[1].to_int())


# ------------------------------------------------------------
# 经济
# ------------------------------------------------------------

static func get_economy() -> Dictionary:
	return _raw_section("economy")


static func get_quality() -> Dictionary:
	return _raw_section("quality")


# ------------------------------------------------------------
# 饰品
# ------------------------------------------------------------

static func get_accessory_config() -> Dictionary:
	return _raw_section("accessories")


static func get_accessory(id: String) -> Dictionary:
	var items: Variant = get_accessory_config().get("items", [])
	if items is Array:
		for item: Variant in items:
			if item is Dictionary and str(item.get("id", "")) == id:
				return item
	return {}


static func get_all_accessories() -> Array:
	var items: Variant = get_accessory_config().get("items", [])
	return items if items is Array else []


static func get_accessory_slot_name(slot: String) -> String:
	var names: Dictionary = get_accessory_config().get("slot_names", {})
	return str(names.get(slot, slot))


static func get_accessory_slots() -> Array:
	var slots: Variant = get_accessory_config().get("slots", [])
	return slots if slots is Array else []


static func get_start_money() -> int:
	return int(get_economy().get("start_money", 500))


static func get_rare_price_cap() -> float:
	return float(get_economy().get("rare_price_multiplier_cap", 3.0))


## 一天的结束时刻（分钟）。end_is_next_day = true 表示次日 06:00。
static func get_day_end_minutes() -> int:
	var cycle := get_day_cycle()
	var start_minutes := int(cycle.get("start_minutes", 360))
	var total := int(cycle.get("total_game_minutes", 1440))
	return start_minutes + total


## 室内地点（房屋 / 鸡舍 / 畜棚 / 商店 / 矿洞 / 温泉）时间完全停止。
static func is_time_stopped_location(location_id: String) -> bool:
	var locations: Variant = get_day_cycle().get("indoor_time_stopped_locations", [])
	return location_id in locations


## 背包 / 对话 / 钓鱼小游戏 / 剧情 / 菜单 / 挖矿时暂停。
static func should_pause_time_for(context_id: String) -> bool:
	var contexts: Variant = get_day_cycle().get("pause_during", [])
	return context_id in contexts


static func get_weather_weights(season: String) -> Dictionary:
	var weights: Dictionary = get_environment().get("weather_weights", {})
	var season_weights: Variant = weights.get(season, {})
	return season_weights if season_weights is Dictionary else {}


# ------------------------------------------------------------
# 玩法参数 / 商店 / 物品索引
# ------------------------------------------------------------

static var _item_index: Dictionary = {}


static func get_gameplay() -> Dictionary:
	return _raw_section("gameplay")


static func get_player_config() -> Dictionary:
	return get_gameplay().get("player", {})


static func get_stamina_costs() -> Dictionary:
	return get_gameplay().get("stamina_costs", {})


static func get_inventory_rules() -> Dictionary:
	return get_gameplay().get("inventory", {})


static func get_start_items() -> Array:
	var items: Variant = get_gameplay().get("start_items", [])
	return items if items is Array else []


static func get_animal_rules() -> Dictionary:
	return get_gameplay().get("animals", {})


# ------------------------------------------------------------
# 宠物
# ------------------------------------------------------------

static func get_pet_config() -> Dictionary:
	return _raw_section("pets")


static func get_pet_types() -> Array:
	var types: Variant = get_pet_config().get("types", [])
	return types if types is Array else []


static func get_pet_type(type_id: String) -> Dictionary:
	for entry: Variant in get_pet_types():
		if entry is Dictionary and str((entry as Dictionary).get("id", "")) == type_id:
			return entry
	return {}


## 品种定义会合并所属类型的公共字段（house_types / food_id / 互动能力等）。
static func get_pet_breed(breed_id: String) -> Dictionary:
	for entry: Variant in get_pet_types():
		if not (entry is Dictionary):
			continue
		var type_entry: Dictionary = entry
		for breed: Variant in type_entry.get("breeds", []):
			if not (breed is Dictionary):
				continue
			if str((breed as Dictionary).get("id", "")) != breed_id:
				continue
			var merged: Dictionary = (breed as Dictionary).duplicate(true)
			merged["type_id"] = str(type_entry.get("id", ""))
			merged["type_name"] = str(type_entry.get("name", ""))
			merged["category"] = str(type_entry.get("category", ""))
			merged["house_types"] = (type_entry.get("house_types", []) as Array).duplicate()
			merged["food_id"] = str(type_entry.get("food_id", ""))
			for key: String in [
				"can_pet", "can_play", "can_follow", "can_release",
				"release_friendship", "follow_range", "special_behavior", "rare_chance",
				"gift_friendship_min", "gift_chance", "gifts", "art", "can_leash_walk",
			]:
				if type_entry.has(key):
					merged[key] = type_entry[key]
			return merged
	return {}


static func get_all_pet_breeds() -> Array:
	var result: Array = []
	for entry: Variant in get_pet_types():
		if not (entry is Dictionary):
			continue
		for breed: Variant in (entry as Dictionary).get("breeds", []):
			if breed is Dictionary:
				var merged := get_pet_breed(str((breed as Dictionary).get("id", "")))
				if not merged.is_empty():
					result.append(merged)
	return result


## 兼容旧调用：按类型 id 或品种 id 取定义。
static func get_pet(id: String) -> Dictionary:
	var type_entry := get_pet_type(id)
	if not type_entry.is_empty():
		return type_entry
	return get_pet_breed(id)


## 兼容旧调用：返回全部宠物类型。
static func get_all_pets() -> Array:
	return get_pet_types()


static func get_pet_coat(pet_type: String, coat_id: String) -> Dictionary:
	var definition := get_pet_type(pet_type)
	for breed: Variant in definition.get("breeds", []):
		if breed is Dictionary and str((breed as Dictionary).get("id", "")) == coat_id:
			return breed
	return get_pet_breed(coat_id)


static func get_pet_rare_color(color_id: String) -> Dictionary:
	for color: Variant in get_pet_config().get("rare_colors", []):
		if color is Dictionary and str(color.get("id", "")) == color_id:
			return color
	return {}


static func get_pet_house_def(house_id: String) -> Dictionary:
	var definition: Variant = _raw_section("pet_houses").get(house_id, {})
	return definition if definition is Dictionary else {}


static func get_all_pet_house_defs() -> Dictionary:
	return _raw_section("pet_houses")


static func get_pet_food(food_id: String) -> Dictionary:
	var definition: Variant = _raw_section("pet_food").get(food_id, {})
	return definition if definition is Dictionary else {}


static func get_all_pet_foods() -> Dictionary:
	return _raw_section("pet_food")


static func get_all_pet_decorations() -> Dictionary:
	return _raw_section("pet_decorations")


const ANIMAL_CATEGORY_NAMES := {
	"poultry": "家禽",
	"livestock": "家畜",
	"special": "特殊箱养",
}


static func get_animal_category_name(category: String) -> String:
	return str(ANIMAL_CATEGORY_NAMES.get(category, category))


static func get_animal_rare_color(color_id: String) -> Dictionary:
	var config: Dictionary = get_rarity().get("animal", {})
	for color: Variant in config.get("colors", []):
		if color is Dictionary and str(color.get("id", "")) == color_id:
			return color
	return {}


# ------------------------------------------------------------
# 坐骑
# ------------------------------------------------------------

static func get_mount_config() -> Dictionary:
	return _raw_section("mounts")


static func get_mount(mount_type: String) -> Dictionary:
	var definition: Variant = get_mount_config().get(mount_type, {})
	return definition if definition is Dictionary else {}


static func get_all_mount_types() -> Array:
	return get_mount_config().keys()


static func get_tool_config(tool_id: String) -> Dictionary:
	var tools: Dictionary = get_gameplay().get("tool_items", {})
	var definition: Variant = tools.get(tool_id, {})
	return definition if definition is Dictionary else {}


static func get_shop_config() -> Dictionary:
	return _raw_section("shop")


static func get_sapling_price(tree_id: String) -> int:
	var prices: Dictionary = get_shop_config().get("sapling_prices", {})
	return int(prices.get(tree_id, 0))


static func get_shop_goods() -> Array:
	var goods: Variant = get_shop_config().get("goods", [])
	return goods if goods is Array else []


static func get_seed_price(crop_id: String) -> int:
	var prices: Dictionary = get_shop_config().get("seed_prices", {})
	return int(prices.get(crop_id, 0))


static func get_sell_price(item_id: String) -> int:
	var prices: Dictionary = get_shop_config().get("sell_prices", {})
	return int(prices.get(item_id, 0))


static func get_shop_good(item_id: String) -> Dictionary:
	for good: Dictionary in get_shop_goods():
		if str(good.get("item_id", "")) == item_id:
			return good
	return {}


# ------------------------------------------------------------
# 加工机器 / 加工品
# ------------------------------------------------------------

static func get_processing_config() -> Dictionary:
	return _raw_section("processing")


static func get_all_machines() -> Array:
	var machines: Variant = get_processing_config().get("machines", [])
	return machines if machines is Array else []


static func get_machine(id: String) -> Dictionary:
	for machine: Dictionary in get_all_machines():
		if str(machine.get("id", "")) == id:
			return machine
	return {}


static func get_all_processing_products() -> Array:
	var products: Variant = get_processing_config().get("products", [])
	return products if products is Array else []


static func get_processing_product(id: String) -> Dictionary:
	for product: Dictionary in get_all_processing_products():
		if str(product.get("id", "")) == id:
			return product
	return {}


static func get_machine_products(machine_id: String) -> Array:
	var result: Array = []
	for product: Dictionary in get_all_processing_products():
		if str(product.get("machine", "")) == machine_id:
			result.append(product)
	return result


# ------------------------------------------------------------
# 战斗 / 怪物 / 陷阱
# ------------------------------------------------------------

static func get_combat_config() -> Dictionary:
	return _raw_section("combat")


static func get_combat_player() -> Dictionary:
	var data: Variant = get_combat_config().get("player", {})
	return data if data is Dictionary else {}


static func get_weapon(weapon_id: String) -> Dictionary:
	var weapons: Dictionary = get_combat_config().get("weapons", {})
	var weapon: Variant = weapons.get(weapon_id, {})
	return weapon if weapon is Dictionary else {}


static func get_all_monsters() -> Array:
	var monsters: Variant = get_combat_config().get("monsters", [])
	return monsters if monsters is Array else []


static func get_monster(monster_id: String) -> Dictionary:
	for monster: Dictionary in get_all_monsters():
		if str(monster.get("id", "")) == monster_id:
			return monster
	return {}


static func get_monster_spawn_for_floor(floor_num: int) -> Dictionary:
	for entry: Dictionary in get_combat_config().get("spawn_table", []):
		if floor_num <= int(entry.get("max_floor", 0)):
			return entry
	return {}


static func get_traps_config() -> Dictionary:
	var traps: Variant = get_combat_config().get("traps", {})
	return traps if traps is Dictionary else {}


static func get_combat_scaling() -> Dictionary:
	var scaling: Variant = get_combat_config().get("scaling", {})
	return scaling if scaling is Dictionary else {}


static func get_combat_death() -> Dictionary:
	var death: Variant = get_combat_config().get("death", {})
	return death if death is Dictionary else {}


# ------------------------------------------------------------
# NPC / 节日
# ------------------------------------------------------------

static func get_all_npcs() -> Array:
	var npcs: Variant = _raw_section("npcs").get("npcs", [])
	return npcs if npcs is Array else []


static func get_npc_config() -> Dictionary:
	return _raw_section("npcs")


static func get_npc(npc_id: String) -> Dictionary:
	for npc: Dictionary in get_all_npcs():
		if str(npc.get("id", "")) == npc_id:
			return npc
	return {}


static func get_all_festivals() -> Array:
	var festivals: Variant = _raw_section("festivals").get("festivals", [])
	return festivals if festivals is Array else []


static func get_festival(festival_id: String) -> Dictionary:
	for festival: Dictionary in get_all_festivals():
		if str(festival.get("id", "")) == festival_id:
			return festival
	return {}


static func get_festival_for_date(season: String, day: int) -> Dictionary:
	for festival: Dictionary in get_all_festivals():
		if str(festival.get("season", "")) == season and int(festival.get("day", 0)) == day:
			return festival
	return {}


# ------------------------------------------------------------
# 委托 / 建造
# ------------------------------------------------------------

static func get_quest_config() -> Dictionary:
	return _raw_section("quests")


static func get_all_building_defs() -> Array:
	var buildings: Variant = _raw_section("buildings").get("buildings", [])
	return buildings if buildings is Array else []


static func get_building_def(building_id: String) -> Dictionary:
	for building: Dictionary in get_all_building_defs():
		if str(building.get("id", "")) == building_id:
			return building
	return {}


static func get_building_next_level(building_id: String, current_level: int) -> Dictionary:
	var definition := get_building_def(building_id)
	for level_def: Dictionary in definition.get("levels", []):
		if int(level_def.get("level", 0)) == current_level + 1:
			return level_def
	return {}


## 统一物品索引：id -> { name, category, base_price }。
## 数据全部来自 config/*.json；没有配置价格的物品 base_price 为 0。
static func _build_item_index() -> void:
	_item_index.clear()

	for definition: Dictionary in get_all_crops():
		var id := str(definition.get("id", ""))
		if id.is_empty():
			continue
		_item_index[id] = {
			"name": str(definition.get("name", id)),
			"category": "crop",
			"base_price": int(definition.get("base_price", 0)),
		}

	for definition: Dictionary in get_all_fishes():
		var id := str(definition.get("id", ""))
		if id.is_empty():
			continue
		_item_index[id] = {
			"name": str(definition.get("name", id)),
			"category": "fish",
			"base_price": int(definition.get("base_price", 0)),
		}

	for tree: Dictionary in get_all_fruit_trees():
		var fruit_id := str(tree.get("fruit_id", ""))
		if fruit_id.is_empty():
			continue
		_item_index[fruit_id] = {
			"name": str(tree.get("fruit_name", fruit_id)),
			"category": "fruit",
			"base_price": int(tree.get("base_price", 0)),
		}

	for definition: Dictionary in get_all_animals():
		var product_id := str(definition.get("product_id", ""))
		if product_id.is_empty() or product_id == "none":
			continue
		_item_index[product_id] = {
			"name": str(definition.get("product_name", product_id)),
			"category": "animal_product",
			"base_price": get_sell_price(product_id),
		}

	for definition: Dictionary in get_all_bee_products():
		var id := str(definition.get("id", ""))
		if id.is_empty():
			continue
		_item_index[id] = {
			"name": str(definition.get("name", id)),
			"category": "bee_product",
			"base_price": get_sell_price(id),
		}

	for good: Dictionary in get_shop_goods():
		var id := str(good.get("item_id", ""))
		if id.is_empty():
			continue
		_item_index[id] = {
			"name": str(good.get("name", id)),
			"category": str(good.get("category", "goods")),
			"base_price": int(good.get("price", 0)),
		}

	for machine: Dictionary in get_all_machines():
		var id := str(machine.get("id", ""))
		if id.is_empty():
			continue
		_item_index[id] = {
			"name": str(machine.get("name", id)),
			"category": "machine",
			"base_price": int(machine.get("price", 0)),
		}

	for product: Dictionary in get_all_processing_products():
		var id := str(product.get("id", ""))
		if id.is_empty():
			continue
		_item_index[id] = {
			"name": str(product.get("name", id)),
			"category": str(product.get("category", "processed")),
			"base_price": int(product.get("base_price", 0)),
		}

	for furniture: Dictionary in get_all_furniture():
		var furniture_id := str(furniture.get("id", ""))
		if furniture_id.is_empty():
			continue
		_item_index[furniture_id] = {
			"name": str(furniture.get("name", furniture_id)),
			"category": "furniture",
			"base_price": int(furniture.get("price", 0)),
		}

	for artifact: Dictionary in get_all_artifacts():
		var artifact_id := str(artifact.get("id", ""))
		if artifact_id.is_empty():
			continue
		_item_index[artifact_id] = {
			"name": str(artifact.get("name", artifact_id)),
			"category": "artifact",
			"base_price": int(artifact.get("price", 0)),
		}

	for monster: Dictionary in get_all_monsters():
		for drop: Dictionary in monster.get("drops", []):
			var item_id := str(drop.get("item_id", ""))
			if item_id.is_empty() or _item_index.has(item_id):
				continue
			_item_index[item_id] = {
				"name": str(drop.get("name", item_id)),
				"category": "monster_drop",
				"base_price": int(drop.get("price", 0)),
			}

	var pet_foods: Dictionary = get_all_pet_foods()
	for food_id: Variant in pet_foods.keys():
		var key := str(food_id)
		var food: Variant = pet_foods[food_id]
		if food is Dictionary:
			_item_index[key] = {
				"name": str(food.get("name", key)),
				"category": "pet_food",
				"base_price": int(food.get("price", 0)),
			}

	var weapons: Dictionary = get_combat_config().get("weapons", {})
	for weapon_id: Variant in weapons.keys():
		var key := str(weapon_id)
		var weapon: Variant = weapons[weapon_id]
		if weapon is Dictionary:
			_item_index[key] = {
				"name": str(weapon.get("name", key)),
				"category": "weapon",
				"base_price": 0,
			}

	# shop.json 的 sell_prices 可以给任意 id 覆盖售价。
	var sell_prices: Dictionary = get_shop_config().get("sell_prices", {})
	for id: Variant in sell_prices.keys():
		var key := str(id)
		if _item_index.has(key):
			_item_index[key]["base_price"] = int(sell_prices[id])
		else:
			_item_index[key] = {
				"name": key,
				"category": "goods",
				"base_price": int(sell_prices[id]),
			}


static func get_item_meta(item_id: String) -> Dictionary:
	_ensure_loaded()
	var meta: Variant = _item_index.get(item_id, {})
	return meta if meta is Dictionary else {}


static func get_item_name(item_id: String, category := "") -> String:
	_ensure_loaded()
	if item_id.is_empty():
		return ""
	match category:
		"seed":
			var crop := get_crop(item_id)
			return str(crop.get("name", item_id)) + "种子"
		"tool":
			var tool := get_tool_config(item_id)
			return str(tool.get("name", item_id))
		"rod":
			var rod := get_rod(item_id)
			return str(rod.get("name", item_id))
		"fertilizer":
			var good := get_shop_good(item_id)
			return str(good.get("name", item_id))
		"feed":
			return str(get_animal_rules().get("feed_name", "饲料"))
		"mineral":
			var ore_names := {
				"stone": "石头", "copper": "铜矿石", "iron": "铁矿石",
				"gold": "金矿石", "mythril": "秘银矿石", "iridium": "铱矿石",
				"granite": "花岗岩", "marble": "大理石",
				"agate": "玛瑙", "amethyst": "紫水晶", "aquamarine": "海蓝宝",
				"emerald": "翡翠", "ruby": "红宝石", "sapphire": "蓝宝石",
				"garnet": "石榴石", "diamond": "钻石",
			}
			return str(ore_names.get(item_id, item_id))
		"bee_goods":
			var names := {
				"beehive": "蜂箱", "queen_bee": "蜂王",
				"sugar_water": "糖水", "bee_medicine": "蜂群药物",
			}
			return str(names.get(item_id, item_id))
		"goods", "ingredient", "":
			# 食材类常见 id 的中文名（配置里没有独立条目时的兜底）
			var common := {
				"beef": "牛肉", "pork": "猪肉", "rice": "大米", "sugar": "糖",
				"water": "水", "kelp": "海带", "coffee_bean": "咖啡豆",
				"tea_leaf": "茶叶", "shrimp": "虾", "egg": "鸡蛋", "milk": "牛奶",
				"honey": "蜂蜜", "flour": "面粉", "salt": "盐",
			}
			if common.has(item_id):
				return str(common[item_id])
		_:
			pass
	var meta := get_item_meta(item_id)
	return str(meta.get("name", item_id))


static func get_item_base_price(item_id: String, category := "") -> int:
	_ensure_loaded()
	if category in ["seed", "tool", "rod", "fertilizer"]:
		return 0
	return int(get_item_meta(item_id).get("base_price", 0))


static func get_item_category(item_id: String) -> String:
	return str(get_item_meta(item_id).get("category", ""))


# ------------------------------------------------------------
# 显示名 / 校验
# ------------------------------------------------------------

static func season_name(season: String) -> String:
	return str(SEASON_NAMES.get(season, season))


static func time_name(time_of_day: String) -> String:
	return str(TIME_NAMES.get(time_of_day, time_of_day))


static func weather_name(weather: String) -> String:
	return str(WEATHER_NAMES.get(weather, weather))


## 开发期自检：返回发现的问题列表，空数组表示全部正常。
static func validate() -> Array[String]:
	_ensure_loaded()
	var problems: Array[String] = []
	problems.append_array(_load_errors)

	# 数量必须和设计文档一致（文档清单：40 / 30 / 40）。
	var expected := {"crops": 40, "animals": 30, "fishes": 40}
	for key: String in expected.keys():
		var actual := _id_list(key).size()
		if actual != int(expected[key]):
			problems.append("%s 数量为 %d，设计文档要求 %d" % [key, actual, int(expected[key])])

	# 引用完整性：动物产物、工具有效 id。
	for definition: Dictionary in get_all_animals():
		var product_id := str(definition.get("product_id", ""))
		if product_id.is_empty():
			problems.append("animal.%s 的 product_id 为空" % definition.get("id", "?"))

	for tree: Dictionary in get_all_fruit_trees():
		if str(tree.get("fruit_id", "")).is_empty():
			problems.append("fruit_tree.%s 缺少 fruit_id" % tree.get("id", "?"))

	# 稀有配置必须存在，否则 RarityUtil 会退回代码默认值。
	if get_rarity().is_empty():
		problems.append("rarity.json 未加载，稀有判定会使用默认值")
	if get_fishing_minigame().is_empty():
		problems.append("fishing_minigame.json 未加载，小游戏会使用默认值")

	return problems
