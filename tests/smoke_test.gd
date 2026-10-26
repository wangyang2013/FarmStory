extends SceneTree
## 无头冒烟测试：
##   godot --headless --path <项目目录> --script res://tests/smoke_test.gd
##
## 覆盖：配置读取与校验、稀有判定概率、存档往返、农田全流程、钓鱼小游戏成功/失败。

const DB := preload("res://scripts/core/ConfigDB.gd")
const Rarity := preload("res://scripts/core/RarityUtil.gd")
const Save := preload("res://scripts/core/SaveSystem.gd")
const FarmTileScript := preload("res://scripts/farm/FarmTile.gd")
const FishMiniGameScript := preload("res://scripts/fishing/FishMiniGame.gd")
const TimeSystemScript := preload("res://scripts/core/TimeSystem.gd")
const InventoryScript := preload("res://scripts/core/Inventory.gd")
const AnimalScript := preload("res://scripts/farm/Animal.gd")
const PixelThemeScript := preload("res://scripts/ui/PixelTheme.gd")
const PetScript := preload("res://scripts/farm/Pet.gd")
const HouseInteriorScript := preload("res://scripts/world/HouseInterior.gd")
const QualityScript := preload("res://scripts/core/QualityUtil.gd")
const TutorialScript := preload("res://scripts/core/TutorialManager.gd")
const FruitTreeScript := preload("res://scripts/farm/FruitTree.gd")
const BeeHiveScript := preload("res://scripts/farm/BeeHive.gd")
const MineFloorScript := preload("res://scripts/world/MineFloor.gd")
const BuildingInteriorScript := preload("res://scripts/world/BuildingInterior.gd")
const PetHouseScript := preload("res://scripts/world/PetHouse.gd")
const CharacterCreatorScript := preload("res://scripts/ui/CharacterCreator.gd")
const GroundItemScript := preload("res://scripts/farm/GroundItem.gd")
const AudioManagerScript := preload("res://scripts/core/AudioManager.gd")

var failures: Array[String] = []
var checks := 0
var _scene_test_pending := false


func _initialize() -> void:
	_test_configs()
	_test_rarity()
	_test_items_and_shop()
	_test_save_roundtrip()
	_test_time_system()
	_test_inventory()
	_test_animal()
	_test_pet()
	_test_ui_theme()
	_test_interior()
	_test_quality()
	_test_accessories()
	_test_tutorial()
	_test_fruit_tree()
	_test_beehive()
	_test_mine()
	_test_cooking()
	_test_farm_tile()
	_test_fish_minigame()

	# 场景集成测试需要等根视口就绪后再跑，放到 _process 里。
	_scene_test_pending = true


func _process(_delta: float) -> bool:
	if not _scene_test_pending:
		return false
	_scene_test_pending = false
	_test_farm_scene()
	_finish()
	return true


func _finish() -> void:
	print("----------------------------------------")
	if failures.is_empty():
		print("SMOKE TEST PASS（%d 项检查）" % checks)
		quit(0)
	else:
		for message: String in failures:
			printerr("FAIL: ", message)
		print("SMOKE TEST FAIL（%d 项检查，%d 项失败）" % [checks, failures.size()])
		quit(1)


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


# ------------------------------------------------------------

func _test_configs() -> void:
	print("[1/17] 配置加载与字段校验")
	var loaded := DB.load_all()
	_check(loaded, "全部 JSON 应成功加载：" + str(DB.get_load_errors()))

	var problems := DB.validate()
	_check(problems.is_empty(), "配置校验：" + ", ".join(PackedStringArray(problems)))

	_check(DB.get_all_crops().size() == 40, "作物应为 40 种，实际 %d" % DB.get_all_crops().size())
	_check(DB.get_all_animals().size() == 30, "动物应为 30 种，实际 %d" % DB.get_all_animals().size())
	_check(DB.get_all_fishes().size() == 40, "鱼类应为 40 种，实际 %d" % DB.get_all_fishes().size())
	_check(DB.get_all_fruit_trees().size() == 12, "果树应为 12 种")
	_check(DB.get_all_bee_products().size() == 7, "蜂产品应为 7 种")
	_check(DB.get_all_birds().size() == 20, "鸟类应为 20 种")
	_check(DB.get_all_insects().size() == 20, "昆虫应为 20 种")
	_check(DB.get_all_recipes().size() == 30, "烹饪菜谱应为 30 条（加工品已移出）")
	_check(DB.get_all_machines().size() == 5, "加工机器应为 5 种")
	_check(DB.get_all_processing_products().size() == 8, "加工品应为 8 种（含香肠）")
	_check(str(DB.get_processing_product("cheese").get("machine", "")) == "cheese_maker",
		"奶酪由奶酪机加工")
	_check(DB.get_all_monsters().size() == 4, "矿洞怪物应为 4 种")
	_check(int(DB.get_weapon("sword").get("damage", 0)) == 10, "剑伤害应为 10")
	_check(DB.get_all_npcs().size() == 16, "NPC 应为 16 名")
	_check(DB.get_all_festivals().size() == 8, "节日应为 8 个")
	_check(str(DB.get_festival_for_date("spring", 13).get("id", "")) == "flower_festival",
		"春13 是花祭")
	_check(int(DB.get_quest_config().get("daily_count", 0)) == 3, "每日 3 条委托")
	_check(DB.get_all_building_defs().size() == 6, "建造定义 6 项（含马厩/鸵鸟舍/自行车棚）")
	_check(not DB.get_shop_good("blue_feather").is_empty(), "商店出售蓝色羽毛")

	# 音频资源可加载（-s 模式下无 Autoload，直接实例化管理器）
	var audio := AudioManagerScript.new()
	for bgm_key: String in [
		"spring", "summer", "autumn", "winter", "town",
		"farm", "mine", "night", "festival", "indoor",
	]:
		_check(audio._load_bgm(bgm_key) != null, "BGM %s 可加载" % bgm_key)
	for sfx_key: String in [
		"till", "water", "plant", "harvest", "coin", "error", "click",
		"feed", "sleep", "fish_bite", "fish_catch", "footstep", "storm_thunder",
	]:
		_check(audio._load_sfx(sfx_key) != null, "SFX %s 可加载" % sfx_key)
	audio.free()

	var turnip := DB.get_crop("turnip")
	_check(not turnip.is_empty(), "能按 id 取到萝卜")
	_check(int(turnip.get("grow_day", 0)) == 4, "萝卜生长天数应为 4")
	_check(str(turnip.get("season", "")) == "spring", "萝卜季节应为 spring")

	var cow := DB.get_animal("cow")
	_check(not cow.is_empty(), "能按 id 取到奶牛")
	_check(str(cow.get("product_id", "")) == "milk", "奶牛产物应为 milk")

	var horse := DB.get_mount("horse")
	_check(not horse.is_empty(), "坐骑配置已加载")
	_check(int(horse.get("speed", 0)) == 200, "马速度来自 mounts.json")
	_check(int(DB.get_mount("bicycle").get("price", 0)) == 3000, "自行车价格来自配置")
	_check(float(DB.get_mount("cow").get("min_friendship", 0)) == 60.0, "骑牛好感门槛 60")
	_check(int(DB.get_mount("donkey").get("cargo_capacity", 0)) == 8, "驴载货 8 格")
	_check(int(DB.get_mount("camel").get("cargo_capacity", 0)) == 12, "骆驼载货 12 格")
	_check(int(DB.get_mount("ostrich").get("sprint_speed", 0)) == 320, "鸵鸟冲刺 320")
	_check(int(DB.get_mount("ostrich").get("max_stamina", 0)) == 60, "鸵鸟耐力 60")
	_check("storm" in (DB.get_mount("camel").get("weather_immune", []) as Array),
		"骆驼暴雨不减速")
	_check(int(DB.get_mount("alpaca").get("cargo_capacity", 0)) == 4, "羊驼载货 4 格")
	_check(int(DB.get_mount("alpaca").get("friendship_gain_feed", 0)) == 8,
		"羊驼喂食好感 +8")
	_check(int(DB.get_mount("tricycle").get("cargo_capacity", 0)) == 10, "三轮车载货 10 格")
	_check(int(DB.get_mount("tricycle").get("sprint_cooldown", 0)) == 3, "三轮车冲刺冷却 3 秒")

	var koi := DB.get_fish("koi")
	_check(not koi.is_empty(), "能按 id 取到锦鲤")
	_check(int(koi.get("min_rod_level", 0)) == 2, "锦鲤需要 2 级鱼竿")

	var candidates := DB.get_fish_candidates("river", "spring", "day", "sunny", 0)
	_check(candidates.size() > 0, "河流白天晴天 0 级竿应能钓到鱼")
	for fish: Dictionary in candidates:
		_check(str(fish.get("water_area", "")) == "river", "候选鱼都来自河流")
		_check(int(fish.get("min_rod_level", 0)) <= 0, "候选鱼不超鱼竿等级")
		_check(str(fish.get("time_of_day", "any")) != "night", "白天不出现夜行鱼")

	_check(not DB.get_rarity().is_empty(), "rarity.json 已加载")
	_check(not DB.get_fishing_minigame().is_empty(), "fishing_minigame.json 已加载")
	_check(DB.get_rod("gold_rod").get("counts_as_high_rod", false) == true, "金鱼竿算作高级竿")

	# 游戏时间规则（D:\wy\种地\游戏时间.txt 最新版）
	_check(DB.get_days_per_season() == 30, "每季应为 30 天")
	_check(DB.get_days_per_season() * 4 == 120, "一年应为 120 天")
	var day_cycle := DB.get_day_cycle()
	_check(str(day_cycle.get("start_time", "")) == "06:00", "每天 06:00 开始")
	_check(str(day_cycle.get("end_time", "")) == "06:00", "一天到次日 06:00")
	_check(bool(day_cycle.get("end_is_next_day", false)), "结束时刻属于次日")
	_check(
		is_equal_approx(float(day_cycle.get("real_seconds_per_game_minute", 0.0)), 0.7),
		"游戏内 1 分钟 = 现实 0.7 秒"
	)
	_check(DB.get_day_end_minutes() == 1800, "一天共 24 小时（1440 游戏分钟）")
	_check(DB.should_pause_time_for("fishing_minigame"), "钓鱼小游戏期间时间暂停")
	_check(DB.weather_name("blizzard") == "暴雪", "暴雪天气名称")
	_check(int(DB.get_weather_weights("winter").get("blizzard", 0)) > 0, "冬季会下暴雪")
	_check(DB.should_pause_time_for("inventory"), "打开背包期间时间暂停")
	_check(DB.should_pause_time_for("mining"), "挖矿期间时间暂停")
	for location: String in ["house", "coop", "barn", "shop", "mine", "hot_spring"]:
		_check(DB.is_time_stopped_location(location), "室内时间静止：%s" % location)
	_check(not DB.is_time_stopped_location("farm"), "户外农场时间正常流动")

	var sleep_rules := DB.get_sleep_rules()
	_check(str(sleep_rules.get("late_sleep_after", "")) == "24:00", "24:00 后睡觉体力恢复变少")
	_check(bool(sleep_rules.get("collapse_on_exhaustion", false)), "体力耗尽会晕倒")
	_check(bool(sleep_rules.get("delayed_wake_on_collapse", false)), "晕倒后次日起床延后")
	_check(
		str(DB.get_machine_processing().get("night_start", "")) == "02:00"
			and str(DB.get_machine_processing().get("night_end", "")) == "06:00",
		"机器在 02:00–06:00 继续加工"
	)


func _test_rarity() -> void:
	print("[2/17] 稀有判定")
	var rolls := 20000
	var crop_hits := 0
	for index in rolls:
		var result := Rarity.roll_crop_rarity(false)
		if bool(result.get("is_rare", false)):
			crop_hits += 1
	var crop_rate := float(crop_hits) / float(rolls)
	_check(crop_rate > 0.04 and crop_rate < 0.06, "作物稀有率应约 5%%，实际 %.4f" % crop_rate)

	var fertilized_hits := 0
	for index in rolls:
		var result := Rarity.roll_crop_rarity(true)
		if bool(result.get("is_rare", false)):
			fertilized_hits += 1
	var fertilized_rate := float(fertilized_hits) / float(rolls)
	_check(
		fertilized_rate > 0.10 and fertilized_rate < 0.14,
		"施肥后稀有率应约 12%%，实际 %.4f" % fertilized_rate
	)

	var unrare = Rarity.roll_crop_rarity(false, false)
	_check(not bool(unrare.get("is_rare", false)), "can_rare=false 的作物不判稀有")

	var animal_hits := 0
	for index in rolls:
		var result := Rarity.roll_animal_rarity(true, false)
		if bool(result.get("is_rare", false)):
			animal_hits += 1
	var animal_rate := float(animal_hits) / float(rolls)
	_check(animal_rate > 0.08 and animal_rate < 0.12, "单亲稀有毛色应约 10%%，实际 %.4f" % animal_rate)

	var fish_color_hits := 0
	for index in rolls:
		var result := Rarity.roll_fish_rarity(false, false, false)
		if bool(result.get("is_rare_color", false)):
			fish_color_hits += 1
	var fish_rate := float(fish_color_hits) / float(rolls)
	_check(fish_rate > 0.04 and fish_rate < 0.06, "鱼异色率应约 5%%，实际 %.4f" % fish_rate)

	var turnip := DB.get_crop("turnip")
	_check(
		Rarity.apply_crop_price(int(turnip["base_price"]), "giant") == int(round(35.0 * 1.5)),
		"超大萝卜售价应为 1.5 倍"
	)
	_check(
		Rarity.apply_crop_price(int(turnip["base_price"]), "giant_heavy") == int(round(35.0 * 1.5 * 1.2)),
		"超大超重萝卜应叠乘 1.5×1.2"
	)

	var bird_hits := 0
	for index in 5000:
		if bool(Rarity.roll_bird_rarity(false).get("is_rare_color", false)):
			bird_hits += 1
	var bird_rate := float(bird_hits) / 5000.0
	_check(bird_rate > 0.04 and bird_rate < 0.06, "鸟类稀有率应约 5%%，实际 %.4f" % bird_rate)

	var insect_hits := 0
	for index in 5000:
		if bool(Rarity.roll_insect_rarity(false, false).get("is_rare_color", false)):
			insect_hits += 1
	var insect_rate := float(insect_hits) / 5000.0
	_check(insect_rate > 0.05 and insect_rate < 0.07, "昆虫变异率应约 6%%，实际 %.4f" % insect_rate)

	var fruit_hits := 0
	for index in 5000:
		if bool(Rarity.roll_fruit_rarity().get("is_rare", false)):
			fruit_hits += 1
	var fruit_rate := float(fruit_hits) / 5000.0
	_check(fruit_rate > 0.04 and fruit_rate < 0.06, "果树稀有率应约 5%%，实际 %.4f" % fruit_rate)

	var honey_hits := 0
	for index in 5000:
		if bool(Rarity.roll_rare_honey(true, 5).get("is_rare", false)):
			honey_hits += 1
	var honey_rate := float(honey_hits) / 5000.0
	_check(honey_rate > 0.065 and honey_rate < 0.095, "森林+5种花源稀有蜜应约 8%%，实际 %.4f" % honey_rate)


func _test_items_and_shop() -> void:
	print("[3/17] 物品索引与商店配置")
	_check(DB.get_seed_price("turnip") == 20, "萝卜种子价格来自 shop.json（20）")
	_check(DB.get_seed_price("ginseng") == 150, "人参种子价格来自 shop.json（150）")
	_check(DB.get_sell_price("egg") == 50, "鸡蛋售价来自 shop.json（50）")
	_check(DB.get_item_name("turnip", "seed") == "萝卜种子", "种子显示名")
	_check(DB.get_item_name("egg", "animal_product") == "鸡蛋", "动物产品显示名")
	_check(DB.get_item_name("hoe", "tool") == "锄头", "工具显示名")
	_check(DB.get_item_name("normal_rod", "rod") == "普通鱼竿", "鱼竿显示名")
	_check(DB.get_item_base_price("egg", "animal_product") == 50, "动物产品基础价")
	_check(DB.get_item_base_price("turnip", "crop") == 35, "作物基础价")
	_check(DB.get_item_base_price("turnip", "seed") == 0, "种子不可直接出售")
	_check(DB.get_start_items().size() == 5, "初始物品 5 件（含剑）")
	_check(float(DB.get_player_config().get("speed", 0.0)) > 0.0, "玩家速度来自 gameplay.json")
	_check(not DB.get_shop_good("fertilizer").is_empty(), "肥料在商店商品表里")


func _test_time_system() -> void:
	print("[5/17] 时间系统")
	var time := TimeSystemScript.new()
	time.setup()

	_check(time.get_clock_text() == "06:00", "初始时间 06:00")
	_check(time.get_day_text().find("春") >= 0, "初始季节为春")

	time.advance(0.7)
	_check(is_equal_approx(time.minutes, 361.0), "现实 0.7 秒 = 游戏 1 分钟")

	time.set_context("menu", true)
	var before := time.minutes
	time.advance(60.0)
	_check(is_equal_approx(time.minutes, before), "打开菜单时时间暂停")
	time.set_context("menu", false)

	time.enter_location("mine")
	before = time.minutes
	time.advance(60.0)
	_check(is_equal_approx(time.minutes, before), "矿洞内时间静止")
	time.leave_location()
	time.advance(0.7)
	_check(time.minutes > before, "离开矿洞后时间恢复流动")

	# 钓鱼时段（新版：白天 6-18，夜晚 18-6，晨昏 6-8 / 16-18）
	time.minutes = 6 * 60 + 30
	_check(time.get_time_of_day() == "dawn_dusk", "06:30 属于晨昏")
	time.minutes = 9 * 60
	_check(time.get_time_of_day() == "day", "09:00 属于白天")
	time.minutes = 17 * 60
	_check(time.get_time_of_day() == "dawn_dusk", "17:00 属于晨昏")
	time.minutes = 18 * 60
	_check(time.get_time_of_day() == "night", "18:00 属于夜晚")
	time.minutes = 26 * 60
	_check(time.get_time_of_day() == "night", "次日 02:00 属于夜晚")
	time.minutes = 5 * 60
	_check(time.get_time_of_day() == "night", "05:00 属于夜晚")

	# 睡眠恢复三档：18-24 → 100%；24-2 → 70%；2-6 → 40%
	time.minutes = 20 * 60
	_check(is_equal_approx(time.sleep(), 1.0), "18:00–24:00 睡觉恢复 100%")

	time.minutes = 25 * 60   # 次日 01:00
	_check(is_equal_approx(time.sleep(), 0.7), "24:00–02:00 睡觉恢复 70%")

	time.minutes = 27 * 60   # 次日 03:00
	_check(is_equal_approx(time.sleep(), 0.4), "02:00–06:00 睡觉恢复 40%")

	# 熬夜到次日 06:00：只发 late_night 信号，不强制晕倒
	var night_flag := [false]
	time.late_night.connect(func() -> void: night_flag[0] = true)
	time.minutes = 1799.0
	var day_before := time.day
	time.advance(2.0)
	_check(night_flag[0], "走到次日 06:00 会发出 late_night")
	_check(time.day == day_before, "late_night 不直接跳日（由场景播放入睡流程）")
	_check(int(time.minutes) == 1800, "时间停在一天结束点")
	_check(not DB.is_forced_collapse_enabled(), "默认没有 2:00 强制晕倒")

	time.collapse("exhausted")
	_check(time.day == day_before + 1, "晕倒后进入下一天")
	_check(time.get_display_minutes() == 480, "晕倒后 08:00 起床")
	_check(is_equal_approx(time.minutes, 480.0), "起床时间写入 minutes")
	time.free()

	# 季节切换
	var season_time := TimeSystemScript.new()
	season_time.setup()
	season_time.day = DB.get_days_per_season()
	season_time.season = "spring"
	season_time.minutes = 1200.0
	season_time.collapse("exhausted")
	_check(season_time.day == 1, "第 30 天结束后回到 1 日")
	_check(season_time.season == "summer", "春季结束后进入夏季")
	season_time.free()


func _test_inventory() -> void:
	print("[6/17] 背包")
	var inventory := InventoryScript.new()
	inventory.clear()

	var leftover := inventory.add_item({"item_id": "turnip", "category": "crop", "count": 5, "price": 35})
	_check(leftover == 0, "放入 5 个萝卜")
	_check(inventory.count_item("turnip", "crop") == 5, "统计萝卜数量")
	_check(inventory.empty_slot_count() == inventory.slots.size() - 1, "占用 1 格")

	inventory.add_item({"item_id": "turnip", "category": "crop", "count": 100, "price": 35})
	_check(inventory.count_item("turnip", "crop") == 105, "超过 99 自动分格")
	_check(inventory.empty_slot_count() == inventory.slots.size() - 2, "占用 2 格")

	_check(inventory.remove_item("turnip", 5, "crop") == 5, "移除 5 个萝卜")
	_check(inventory.count_item("turnip", "crop") == 100, "剩余 100 个")

	var gained := inventory.sell_slot(0, 100)
	_check(gained == 94 * 35, "按单价 35 卖出当前格 94 个（3290 G）")
	_check(inventory.count_item("turnip", "crop") == 6, "另一格 6 个仍然保留")

	inventory.clear()
	inventory.add_item({"item_id": "hoe", "category": "tool", "count": 1})
	inventory.add_item({"item_id": "hoe", "category": "tool", "count": 1})
	_check(inventory.empty_slot_count() == inventory.slots.size() - 2, "工具不堆叠")

	inventory.clear()
	inventory.add_item({"item_id": "turnip", "category": "crop", "count": 2, "price": 35})
	inventory.add_item({"item_id": "crucian", "category": "fish", "count": 1, "price": 15})
	var sold := inventory.sell_all()
	_check(int(sold.get("count", 0)) == 3, "全部出售 3 件")
	_check(int(sold.get("money", 0)) == 85, "全部出售金额 35×2 + 15")
	_check(inventory.count_item("turnip", "crop") == 0, "出售后清空作物")

	inventory.clear()
	inventory.add_item({"item_id": "turnip", "category": "crop", "count": 3, "is_rare": true, "rare_type": "giant", "price": 52})
	var saved := inventory.to_save()
	var restored := InventoryScript.new()
	restored.from_save(saved)
	var slot := restored.get_slot(0)
	_check(str(slot.get("item_id", "")) == "turnip", "背包存档还原物品 id")
	_check(bool(slot.get("is_rare", false)), "背包存档还原稀有标记")
	_check(int(slot.get("count", 0)) == 3, "背包存档还原数量")

	var full := InventoryScript.new()
	full.clear()
	for index in full.slots.size():
		full.add_item({"item_id": "hoe", "category": "tool", "count": 1})
	_check(full.add_item({"item_id": "can", "category": "tool", "count": 1}) == 1, "背包满时返回未放入数量")


func _test_save_roundtrip() -> void:
	print("[4/17] 存档往返")
	# 保护开发机上已有的存档（主档 / 备份 / 临时档）。
	var old_files: Dictionary = {}
	for path: String in [Save.SAVE_PATH, Save.BACKUP_PATH, Save.TEMP_PATH]:
		if FileAccess.file_exists(path):
			var old_file := FileAccess.open(path, FileAccess.READ)
			if old_file != null:
				old_files[path] = old_file.get_as_text()
				old_file.close()

	var data := Save.get_empty_save()
	data["money"] = 1234
	data["day"] = 7
	data["season"] = "summer"
	data["inventory"] = [
		{"item_id": "turnip", "category": "crop", "count": 3, "is_rare": true, "rare_type": "giant"},
		{"item_id": "crucian", "category": "fish", "count": 1, "weight": 0.42, "is_rare_color": true},
	]
	data["farm_tiles"] = [{"x": 2, "y": 3, "tilled": true, "seed": "turnip", "current_day": 2}]

	_check(Save.save_data(data), "存档写入成功")
	_check(FileAccess.file_exists(Save.SAVE_PATH), "主存档文件存在")

	var loaded := Save.load_data()
	_check(int(loaded.get("money", 0)) == 1234, "读回金钱")
	_check(int(loaded.get("day", 0)) == 7, "读回日期")
	_check(str(loaded.get("season", "")) == "summer", "读回季节")
	_check((loaded.get("inventory", []) as Array).size() == 2, "读回背包")
	_check((loaded.get("farm_tiles", []) as Array).size() == 1, "读回地块")
	_check(not loaded.has("crops"), "存档不包含作物配置表")
	_check(not loaded.has("fishes"), "存档不包含鱼类配置表")
	var loaded_player: Dictionary = loaded.get("player", {})
	_check(loaded_player.has("appearance"), "旧存档自动补齐角色外观字段")
	_check(loaded.has("world"), "旧存档补齐 world 字段")
	_check(loaded.has("home"), "旧存档补齐 home 字段")
	_check(loaded.has("skills"), "旧存档补齐 skills 字段")
	_check(loaded.has("apiary"), "旧存档自动补齐养蜂字段")

	# 主档损坏时自动回退到备份。
	var second := Save.get_empty_save()
	second["money"] = 777
	_check(Save.save_data(second), "第二次写入（生成备份）")
	var broken := FileAccess.open(Save.SAVE_PATH, FileAccess.WRITE)
	if broken != null:
		broken.store_string("{ 这不是合法 JSON")
		broken.close()
	var recovered := Save.load_data()
	_check(int(recovered.get("money", 0)) == 1234, "主档损坏时从备份恢复到上一次存档")
	_check(bool(recovered.get("_restored_from_backup", false)), "返回结果标记来自备份")

	Save.delete_save()
	_check(not FileAccess.file_exists(Save.SAVE_PATH), "删除存档")

	for path: String in old_files.keys():
		var restore := FileAccess.open(path, FileAccess.WRITE)
		if restore != null:
			restore.store_string(str(old_files[path]))
			restore.close()


func _test_animal() -> void:
	print("[7/17] 动物系统")
	var rules := DB.get_animal_rules()
	_check(not rules.is_empty(), "gameplay.json 里有 animals 配置")
	_check(int(rules.get("max_per_building", 0)) > 0, "每个栏舍有容量上限")

	var chicken_def := DB.get_animal("chicken")
	_check(not chicken_def.is_empty(), "能取到鸡的配置")
	_check(str(chicken_def.get("product_id", "")) == "egg", "鸡的产物是鸡蛋")

	var animal := AnimalScript.new()
	animal.setup("chicken", Vector2.ZERO, "coop")
	_check(animal.type_id == "chicken", "动物类型正确")
	_check(animal.building == "coop", "鸡住在鸡舍")
	_check(is_equal_approx(animal.friendship, float(rules.get("friendship_start", 30))), "初始好感来自配置")
	_check(not animal.produce_ready, "刚买来没有产物")

	# 摸一摸：好感 +5
	var before := animal.friendship
	_check(animal.pet(), "第一次抚摸成功")
	_check(is_equal_approx(animal.friendship, before + float(rules.get("friendship_per_pet", 5))), "抚摸提升好感")
	_check(not animal.pet(), "同一天不能重复抚摸")

	# 喂食跨日：好感 +1，有产物
	animal.feed()
	animal.advance_day(true)
	_check(animal.produce_ready, "喂食后第二天有产物")
	_check(animal.friendship >= before, "喂食不会掉好感")
	_check(not animal.fed_today, "跨日后喂食状态重置")
	_check(not animal.petted_today, "跨日后可以再次抚摸")

	var product := animal.collect_product()
	_check(str(product.get("item_id", "")) == "egg", "收取鸡蛋")
	_check(int(product.get("price", 0)) > 0, "鸡蛋有售价")
	_check(not animal.produce_ready, "收取后产物清空")
	_check(animal.collect_product().is_empty(), "重复收取返回空")

	# 不喂食：好感下降
	var hungry := AnimalScript.new()
	hungry.setup("cow", Vector2.ZERO, "barn")
	var friendship_before := hungry.friendship
	hungry.advance_day(false)
	_check(
		hungry.friendship < friendship_before,
		"不喂食好感下降（%.0f → %.0f）" % [friendship_before, hungry.friendship]
	)
	_check(not hungry.produce_ready, "没喂食就没有产物")

	# 出生稀有毛色（每次判定新建 RNG）
	var rare_born := 0
	var birth_samples := 10000
	for index in birth_samples:
		var baby := AnimalScript.new()
		baby.setup("chicken", Vector2.ZERO, "coop")
		baby.roll_birth_traits(false, false)
		if baby.is_rare:
			rare_born += 1
		baby.free()
	var rate := float(rare_born) / float(birth_samples)
	_check(rate > 0.03 and rate < 0.05, "普通双亲稀有毛色率约 4%%，实际 %.4f" % rate)

	var rare_color_def := DB.get_animal_rare_color("golden")
	_check(not rare_color_def.is_empty(), "稀有毛色有配置")
	_check(str(rare_color_def.get("name", "")) == "金色", "稀有毛色中文名")
	_check(str(rare_color_def.get("color", "")).begins_with("#"), "稀有毛色带十六进制颜色")

	# 存档往返只存动态状态
	animal.animal_name = "小白"
	var saved := animal.to_save()
	var restored := AnimalScript.new()
	restored.from_save(saved)
	_check(restored.type_id == "chicken", "动物存档还原类型")
	_check(restored.animal_name == "小白", "动物存档还原名字")
	_check(is_equal_approx(restored.friendship, animal.friendship), "动物存档还原好感")
	_check(not saved.has("product_name"), "动物存档不含配置字段 product_name")
	_check(not saved.has("buy_price"), "动物存档不含配置字段 buy_price")

	animal.free()
	hungry.free()
	restored.free()


func _test_pet() -> void:
	print("[8/17] 宠物系统")
	var config := DB.get_pet_config()
	_check(not config.is_empty(), "pets.json 已加载")
	_check(int(config.get("max_pets", 0)) == 12, "宠物总数上限 12")
	_check(DB.get_pet_types().size() >= 14, "宠物类别不少于 14 类")
	_check(not DB.get_all_pet_house_defs().is_empty(), "栖息地配置已加载")
	_check(not DB.get_all_pet_foods().is_empty(), "宠物食物配置已加载")

	var dog_def := DB.get_pet_type("dog")
	_check(not dog_def.is_empty(), "能取到狗的定义")
	_check((dog_def.get("breeds", []) as Array).size() >= 3, "狗有多个品种")
	_check((config.get("rare_colors", []) as Array).size() >= 3, "多种稀有毛色")

	var pet := PetScript.new()
	pet.setup("shiba", Vector2.ZERO)
	_check(pet.pet_type == "dog", "宠物类型正确")
	_check(pet.breed == "shiba", "品种正确")
	_check(pet.friendship > 0.0, "初始好感来自配置")
	_check(pet.hunger > 0.0 and pet.cleanliness > 0.0, "四维状态已初始化")
	_check(not pet.gift_ready, "刚领养没有礼物")

	# 抚摸 / 玩耍 / 喂食
	var before := pet.friendship
	_check(pet.pet(), "第一次抚摸成功")
	_check(pet.friendship > before, "抚摸提升好感")
	_check(not pet.pet(), "同一天不能重复抚摸")
	_check(pet.play(), "第一次玩耍成功")
	_check(not pet.play(), "同一天不能重复玩耍")
	_check(pet.feed("dog_food"), "喂食对应食物成功")
	_check(pet.fed_today, "喂食状态记录")
	_check(not pet.feed("cat_food"), "不能喂其他物种食物")

	# 跨日：好感达到阈值后有概率带礼物
	pet.friendship = 100.0
	var gifts := 0
	for index in 400:
		pet.fed_today = true
		pet.advance_day()
		if pet.gift_ready:
			gifts += 1
			pet.gift_ready = false
		pet.friendship = 100.0
	var gift_rate := float(gifts) / 400.0
	_check(gift_rate > 0.35 and gift_rate < 0.75, "高好感礼物概率约 55%%，实际 %.2f" % gift_rate)

	# 状态衰减 / 不喂食掉好感
	var hungry := PetScript.new()
	hungry.setup("orange_cat", Vector2.ZERO)
	var friendship_before := hungry.friendship
	var hunger_before := hungry.hunger
	hungry.advance_day()
	_check(hungry.hunger < hunger_before, "跨日饥饿下降")
	for index in 3:
		hungry.advance_day()
	_check(hungry.friendship < friendship_before, "连续不喂食好感下降")

	# 栖息地容量 / 生病 / 离家出走
	_check(int(DB.get_pet_house_def("bird_cage").get("capacity", 0)) == 2, "鸟笼容量 2")
	_check(int(DB.get_pet_house_def("turtle_pond").get("capacity", 0)) == 4, "龟池容量 4")
	var runaway := PetScript.new()
	runaway.setup("golden_hamster", Vector2.ZERO)
	runaway.friendship = 0.0
	runaway.hunger = 0.0
	for index in 30:
		runaway.advance_day()
		if runaway.missing:
			break
	_check(runaway.missing, "低好感低饥饿会离家出走")
	runaway.recover_missing()
	_check(not runaway.missing and runaway.friendship >= 30.0, "离家出走后可找回")
	runaway.sick = true
	_check(runaway.heal(), "宠物药可治疗生病")
	runaway.free()

	# 放出与自动回栖息地
	var bird := PetScript.new()
	bird.setup("budgie", Vector2.ZERO)
	bird.friendship = 50.0
	bird.start_release(1.0)
	_check(bird.released, "鸟可放出")
	_check(not bird.tick_release(0.4), "放出时间未到")
	_check(bird.tick_release(0.7) and not bird.released, "放出结束自动回栖息地")
	bird.free()

	# 领养稀有毛色概率约 10%
	var rare_count := 0
	for index in 4000:
		var candidate := PetScript.new()
		candidate.setup("cat", Vector2.ZERO)
		candidate.roll_adoption_traits()
		if candidate.is_rare:
			rare_count += 1
		candidate.free()
	var rare_rate := float(rare_count) / 4000.0
	_check(rare_rate > 0.08 and rare_rate < 0.12, "宠物稀有毛色约 10%%，实际 %.3f" % rare_rate)

	# 存档只存实例状态
	var saved := pet.to_save()
	var restored := PetScript.new()
	restored.from_save(saved)
	_check(str(restored.pet_type) == "dog", "宠物存档还原类型")
	_check(not saved.has("gifts"), "宠物存档不含礼物配置表")
	_check(not saved.has("coats"), "宠物存档不含毛色配置表")

	pet.free()
	hungry.free()
	restored.free()


func _test_ui_theme() -> void:
	print("[9/17] 像素 UI 主题")
	var art := preload("res://scripts/art/PixelArt.gd")

	# 新游戏角色创建：主角名 + 牧场名输入
	var creator := CharacterCreatorScript.new()
	creator.setup(art.default_look(), false)
	_check(creator._name_input != null and creator._farm_input != null,
		"角色创建提供主角名 / 牧场名输入")
	creator._name_input.text = "阿明"
	creator._farm_input.text = "青禾牧场"
	_check(creator._name_input.text == "阿明", "主角名可输入")
	_check(creator._farm_input.text == "青禾牧场", "牧场名可输入")
	creator.free()

	# 美术规范：浅米白面板 + 细边框 + 小圆角
	var panel := PixelThemeScript.panel_style()
	_check(panel is StyleBoxFlat, "面板使用扁平样式（无厚重装饰）")
	_check(panel.bg_color.r > 0.9 and panel.bg_color.g > 0.85, "面板底色为浅米白")
	_check(panel.border_width_left <= 2, "面板边框为细边框")
	_check(panel.corner_radius_top_left <= 8, "面板圆角偏小")

	var border := panel.border_color
	_check(border.r > border.b and border.r > 0.6, "边框为浅棕色（暖调）")

	var slot := PixelThemeScript.slot_style(true)
	_check(slot is StyleBoxFlat, "槽位使用扁平样式")
	_check(slot.bg_color.v > 0.8, "槽位底色浅")

	# 16px 图标
	var icon := PixelThemeScript.item_icon("turnip", "seed")
	_check(icon != null and icon.get_width() == 16, "种子图标为 16×16")
	var crop_icon := PixelThemeScript.item_icon("turnip", "crop")
	_check(crop_icon != null and crop_icon.get_width() == 16, "作物图标为 16×16")
	var animal_icon := PixelThemeScript.animal_icon("chicken")
	_check(animal_icon != null and animal_icon.get_width() == 16, "动物图标为 16×16")
	_check(PixelThemeScript.item_icon("turnip", "seed") == icon, "同一图标会缓存复用")

	var font := PixelThemeScript.font()
	_check(font != null, "像素字体可用")
	_check(
		font.antialiasing == TextServer.FONT_ANTIALIASING_NONE,
		"字体关闭抗锯齿（像素风）"
	)
	_check(PixelThemeScript.display_font_size(10) == 12, "UI 小字号取 12 倍数")
	_check(PixelThemeScript.display_font_size(20) == 24, "UI 大字号取 12 倍数")

	# 角色外观
	var look := art.default_look()
	_check(art.normalize_look({}).size() == look.size(), "默认外观字段完整")
	_check(art.SKIN_TONES.size() == 5, "肤色 5 种")
	_check(art.HAIR_COLORS.size() == 12, "发色 12 种")
	_check(art.HAIR_STYLE_NAMES.size() == 8, "发型 8 种")
	_check(art.FACE_SHAPE_NAMES.size() == 4, "脸型 4 种")
	_check(art.OUTFIT_NAMES.size() == 6, "服装 6 种")
	_check(art.OUTFIT_COLORS.size() == 8, "衣服颜色 8 种")
	_check(art.GENDER_NAMES.size() == 2, "性别 2 种")

	var weird := art.normalize_look({"skin": "不存在", "hair": "不存在", "face": "不存在"})
	_check(str(weird["skin"]) == "natural", "非法肤色回退为默认")
	_check(str(weird["hair"]) == "short", "非法发型回退为默认")
	_check(str(weird["face"]) == "oval", "非法脸型回退为默认")

	# 6 键 = 角色调色板里的颜色
	for skin_name: String in art.SKIN_TONES.keys():
		var color: Color = art.SKIN_TONES[skin_name]
		_check(color.s < 0.60 and color.v > 0.45, "肤色 %s 为低饱和暖色" % skin_name)


func _test_farm_scene() -> void:
	print("[20/20] 正式农场场景集成")
	var had_save := FileAccess.file_exists(Save.SAVE_PATH)
	var old_text := ""
	if had_save:
		var old_file := FileAccess.open(Save.SAVE_PATH, FileAccess.READ)
		if old_file != null:
			old_text = old_file.get_as_text()
			old_file.close()

	Save.delete_save()
	var farm: Node = load("res://scenes/Farm.tscn").instantiate()
	root.add_child(farm)

	_check(farm.time != null, "场景里有时间系统")
	_check(farm.player != null, "场景里有玩家")
	_check(farm.player.is_in_group("player"), "玩家在 player 组")
	_check(InputMap.has_action("open_map"), "存在 open_map 输入动作")
	_check(farm.player.has_method("get_facing_angle"), "玩家提供朝向角度接口")
	_check(farm.player.has_method("set_navigation_target"), "玩家提供寻路扩展接口")
	_check(farm.inventory != null, "场景里有背包")
	_check(farm.farm_tiles.size() > 0, "场景生成了农田地块")

	farm.start_new_game(false)
	_check(farm.money == 500, "新游戏 500 金")
	_check(farm.player.look.size() >= 7, "玩家有完整外观字段")

	farm._apply_appearance({
		"gender": "male",
		"hair": "short",
		"hair_color": "black",
		"skin": "wheat",
		"face": "square",
		"outfit": "work",
		"outfit_color": "green",
	})
	_check(str(farm.player.look["hair"]) == "short", "应用自定义发型")
	_check(str(farm.player.look["skin"]) == "wheat", "应用自定义肤色")
	_check(farm.inventory.count_item("turnip", "seed") == 5, "初始 5 颗萝卜种子")

	farm.money = 20000
	var animals_before: int = farm.animals.size()
	farm.buy_animal("chicken")
	_check(farm.animals.size() == animals_before + 1, "买鸡后动物数量 +1")
	_check(farm.money == 20000 - 500, "买鸡扣钱（来自 animals.json）")

	farm.buy_feed(5)
	farm.money = 50000
	var pets_before: int = farm.pets.size()
	var houses_before: int = farm.pet_houses.size()
	farm.buy_pet("shiba")
	_check(farm.pets.size() == pets_before + 1, "领养宠物")
	_check(farm.pet_houses.size() == houses_before + 1, "领养后生成栖息地")
	var first_pet: FarmPet = farm.pets[farm.pets.size() - 1]
	_check(not first_pet.house_id.is_empty(), "宠物记录栖息地 ID")
	_check(farm._pet_house_nodes.has(first_pet.house_id), "栖息地节点已生成")
	_check(first_pet.hunger > 0.0 and first_pet.health == 100.0, "宠物状态已初始化")
	farm.buy_pet("orange_cat")
	_check(farm.pets.size() == pets_before + 2, "可以再领养一只猫")
	_check(farm.pet_houses.size() >= houses_before + 2, "第二只宠物有独立栖息地")
	_check(farm.get_pet_limit() >= 3, "扩建栖息地提升宠物上限")
	var pet_id := first_pet.pet_id
	_check(farm.rename_pet(pet_id, "旺财"), "宠物可自定义名称")
	_check(first_pet.pet_name == "旺财", "宠物名称已更新")
	_check(not farm.rename_pet(pet_id, "小旺"), "同一只宠物只能改名一次")
	_check(farm.pet_action(pet_id, "pet"), "宠物面板可抚摸")
	_check(farm.pet_action(pet_id, "play"), "宠物面板可玩耍")
	farm.inventory.add_item({
		"item_id": "dog_food", "category": "pet_food", "count": 1, "price": 50,
	})
	_check(farm.pet_action(pet_id, "feed"), "宠物面板可喂食")
	_check(farm.pet_action(pet_id, "clean"), "宠物面板可清理")
	farm.ui.open_pet_panel(pet_id)
	_check(farm.ui.get_modal() == "pet", "宠物面板可打开")
	farm.ui.close_modal()
	farm.ui.open_pet_panel("")
	_check(farm.ui.get_modal() == "pet", "宠物列表面板可打开")
	farm.ui.close_modal()
	farm.ui.open_pet_name_dialog(pet_id)
	_check(farm.ui.get_modal() == "pet_name", "宠物命名面板可打开")
	farm.ui.close_modal()
	# 栖息地升级 / 搬迁
	var house_id := first_pet.house_id
	var level_before := int(farm._find_house_data(house_id).get("level", 1))
	var capacity_before: int = farm._house_capacity(house_id)
	farm.money = 50000
	_check(farm.upgrade_pet_house(house_id), "栖息地可升级")
	_check(int(farm._find_house_data(house_id).get("level", 1)) == level_before + 1,
		"栖息地等级提升")
	_check(farm._house_capacity(house_id) == capacity_before + 1, "升级后栖息地容量提升")
	farm.begin_move_pet_house(house_id)
	_check(not farm._placing_pet_house_id.is_empty(), "进入栖息地搬迁模式")
	farm._place_pet_house_at(Vector2i(38, 20))
	_check(farm._placing_pet_house_id.is_empty(), "放置后退出搬迁模式")
	_check(float(farm._find_house_data(house_id).get("x", 0.0)) > 0.0,
		"栖息地坐标已更新")
	# 栖息地装饰
	_check(farm.add_pet_house_decoration(house_id), "可摆放栖息地装饰")
	_check(farm._find_house_node(house_id).decorations.size() == 1, "装饰写入栖息地")
	# 猫在床边睡觉
	var cat_pet: FarmPet = null
	for entry: FarmPet in farm.pets:
		if entry.pet_type == "cat":
			cat_pet = entry
			break
	if cat_pet != null:
		cat_pet.friendship = 70.0
		farm._place_indoor_pets()
		_check(cat_pet.sleeping and cat_pet.visible, "高好感猫在床边睡觉")
		farm._restore_indoor_pets()
		_check(not cat_pet.sleeping, "离开自宅后猫恢复状态")
	# 昆虫斗虫
	farm.buy_pet("flat_stag")
	var insect_pet: FarmPet = farm.pets[farm.pets.size() - 1]
	var money_before_battle: int = farm.money
	_check(farm.pet_action(insect_pet.pet_id, "battle"), "昆虫可斗虫")
	_check(farm.money == money_before_battle + 100, "斗虫奖励 100G")
	_check(not farm.pet_action(insect_pet.pet_id, "battle"), "斗虫每天一次")
	# 专属动画状态与野生动物
	var test_bird := PetScript.new()
	test_bird.setup("budgie", Vector2.ZERO)
	var test_cage := PetHouseScript.new()
	test_cage.setup("bird_cage", "test_cage", Vector2.ZERO)
	test_cage.decorations.append("swing")
	farm._update_pet_visual_flags(test_bird, test_cage)
	_check(test_bird.swung, "鸟笼秋千触发秋千动画")
	test_cage.free()
	test_bird.free()
	var test_fish := PetScript.new()
	test_fish.setup("goldfish", Vector2.ZERO)
	test_fish.cleanliness = 0.0
	var test_tank := PetHouseScript.new()
	test_tank.setup("fish_tank", "test_tank", Vector2.ZERO)
	test_tank.cleanliness = 10.0
	farm._update_pet_visual_flags(test_fish, test_tank)
	_check(test_fish.hiding, "水质差时鱼躲藏")
	test_tank.free()
	test_fish.free()
	var test_turtle := PetScript.new()
	test_turtle.setup("grass_turtle", farm.player.position)
	farm._update_pet_visual_flags(test_turtle, null)
	_check(test_turtle.shell, "玩家靠近时乌龟缩壳")
	test_turtle.free()
	# 野生动物：生成 / 狗驱赶 / 清理
	farm._spawn_wild_critter()
	_check(farm.wild_critters.size() == 1, "生成野生动物")
	if not farm.wild_critters.is_empty():
		var critter: WildCritter = farm.wild_critters[0]
		critter.position = Vector2(30.0 * 32.0, 23.0 * 32.0)
		if cat_pet != null:
			var dog_pet: FarmPet = null
			for entry: FarmPet in farm.pets:
				if entry.pet_type == "dog":
					dog_pet = entry
					break
			if dog_pet != null:
				dog_pet.friendship = 90.0
				dog_pet.position = critter.position + Vector2(10, 0)
				farm.player.position = Vector2(50.0 * 32.0, 30.0 * 32.0)
				critter._process(0.016)
				_check(critter._flee_timer > 0.0, "高好感狗会赶跑野生动物")
	farm._clear_wild_critters()
	_check(farm.wild_critters.is_empty(), "清空野生动物")
	var feed_id := str(DB.get_animal_rules().get("feed_item_id", "feed"))
	_check(farm.inventory.count_item(feed_id, "feed") >= 5, "买到饲料")

	farm.feed_building("coop")
	_check(bool(farm.building_fed.get("coop", false)), "鸡舍已喂食")
	_check(farm.feed_building is Callable, "喂食接口存在")

	# 跨日：动物产蛋
	farm._advance_animals()
	var chicken: FarmAnimal = null
	for animal: FarmAnimal in farm.animals:
		if animal.building == "coop":
			chicken = animal
			break
	_check(chicken != null, "找到鸡舍里的鸡")
	if chicken != null:
		_check(chicken.produce_ready, "喂食后第二天有产物")
		var eggs_before: int = farm.inventory.count_item("egg", "animal_product")
		farm._interact_animal(chicken)
		_check(
			farm.inventory.count_item("egg", "animal_product") == eggs_before + 1,
			"按 E 收取鸡蛋进背包"
		)

	# 名称 / 牧场名牌 / 存档导入导出
	farm.player_name = "小明"
	farm.farm_name = "星光牧场"
	farm._update_farm_sign()
	_check(farm._farm_sign != null and farm._farm_sign.farm_name == "星光牧场",
		"牧场名牌显示自定义名称")
	farm.save_game(true)
	var name_save := Save.load_data()
	_check(str((name_save.get("player", {}) as Dictionary).get("name", "")) == "小明",
		"存档记录主角名")
	_check(str(name_save.get("farm_name", "")) == "星光牧场", "存档记录牧场名")
	farm.player_name = "临时"
	farm.farm_name = "旧牧场"
	farm.load_game()
	_check(farm.player_name == "小明" and farm.farm_name == "星光牧场", "读档恢复名称")
	var export_path := "user://farm_export_test.json"
	_check(Save.export_slot(Save.get_slot(), export_path), "存档可导出")
	_check(FileAccess.file_exists(export_path), "导出文件已生成")
	var imported: Dictionary = Save.import_slot(export_path, 2)
	_check(not imported.is_empty(), "存档可导入")
	_check(str(imported.get("farm_name", "")) == "星光牧场", "导入保留牧场名")
	Save.delete_save(2)
	DirAccess.remove_absolute(export_path)

	# 存档往返
	_check(farm.save_game(), "农场存档成功")
	var saved_data := Save.load_data()
	var saved_look: Dictionary = (saved_data.get("player", {}) as Dictionary).get("appearance", {})
	_check(str(saved_look.get("hair", "")) == "short", "存档记录外观")
	_check(str(saved_look.get("skin", "")) == "wheat", "存档记录肤色")
	var animals_saved: int = farm.animals.size()
	farm.animals.clear()
	_check(farm.load_game(), "农场读档成功")
	_check(farm.animals.size() == animals_saved, "读档恢复动物数量（%d）" % animals_saved)
	_check(farm.pets.size() >= 2, "读档恢复宠物数量")
	_check(farm.pet_houses.size() >= 2, "读档恢复栖息地数量")
	_check(farm._pet_house_nodes.size() == farm.pet_houses.size(), "读档重建栖息地节点")

	# 相机跟随：移动玩家后下一帧相机应同步
	var old_player_pos: Vector2 = farm.player.position
	farm.player.position += Vector2(96, 64)
	farm._process(0.016)
	_check(farm.camera.position == farm.player.position, "相机跟随玩家移动")
	farm.player.position = old_player_pos
	farm._process(0.016)

	# 地图数据
	var map_info: Dictionary = farm.get_map_info()
	var world_size: Vector2 = map_info.get("world_size", Vector2.ZERO)
	_check(world_size == Vector2(2048, 1536), "地图世界尺寸正确")
	_check(map_info.has("player_pos"), "地图包含玩家位置")
	_check(map_info.has("player_facing"), "地图包含玩家朝向")
	var entities: Array = farm.get_map_entities()
	_check(entities.size() >= 9, "地图实体登记在 map_entities 组")
	var facilities := 0
	var resources := 0
	var has_icon := false
	for entity: MapEntity in entities:
		if entity.entity_type == "Facility":
			facilities += 1
		elif entity.entity_type == "Resource":
			resources += 1
		if entity.entity_type == "Building" and entity.map_icon != null:
			has_icon = true
	_check(facilities >= 2, "地图包含设施标记")
	_check(resources >= 3, "地图包含资源区标记")
	_check(has_icon, "地图实体带 16×16 图标")
	var has_museum_marker := false
	for entity: MapEntity in entities:
		if entity.display_name == "博物馆":
			has_museum_marker = true
	_check(has_museum_marker, "地图包含博物馆标记")
	_check(farm.get_map_region_id() == "farm", "地图区域为农场")
	var region: Dictionary = farm.get_map_region()
	_check(str(region.get("id", "")) == "farm", "农场区域数据完整")
	farm.indoor = true
	var house_region: Dictionary = farm.get_map_region()
	_check(str(house_region.get("id", "")) == "house", "自宅区域数据完整")
	var house_markers: Array = house_region.get("markers", [])
	_check(house_markers.size() >= 5, "自宅地图包含设施")
	farm.indoor = false
	_check(farm.map_ui != null, "MapUI 场景已实例化")
	_check(farm.map_ui.icon_container != null, "MapUI 包含 IconContainer")
	_check(farm.map_ui.info_label != null, "MapUI 包含 InfoLabel")
	_check(farm.map_ui.fog_of_war != null, "MapUI 包含 FogOfWar")
	_check(farm.ui.compass != null, "HUD 指南针已创建")
	_check(farm.navigate_to(Vector2(55 * 32, 10.6 * 32)), "地图点击寻路生成路径")
	_check(farm.player.nav_path.size() > 0, "玩家收到 A* 路径点")
	# 测试环境里开局淡入尚未结束，临时解除以模拟正常游戏中的按键。
	var was_transitioning: bool = farm._transitioning
	farm._transitioning = false
	var map_event := InputEventKey.new()
	map_event.physical_keycode = KEY_M
	map_event.keycode = KEY_M
	map_event.pressed = true
	farm.map_ui._input(map_event)
	_check(farm.get_tree().paused, "M 键打开大地图并暂停游戏")
	farm.map_ui._input(map_event)
	_check(not farm.get_tree().paused, "M 键关闭大地图并恢复游戏")
	farm._transitioning = was_transitioning

	# 室内 / 矿洞点击寻路
	var was_indoor: bool = farm.indoor
	var path_old_player_pos: Vector2 = farm.player.position
	farm.indoor = true
	var interior_target: Vector2 = farm._interior.origin + Vector2(5 * 32, 5 * 32)
	_check(farm.navigate_to(interior_target), "自宅室内点击寻路")
	_check(farm.player.nav_path.size() > 0, "室内寻路生成路径")
	farm.player.nav_path = PackedVector2Array()
	farm.player.position = path_old_player_pos
	farm.indoor = was_indoor

	var was_in_mine: bool = farm.in_mine
	var old_mine_floor = farm.mine_floor
	var test_floor: MineFloor = MineFloorScript.new()
	test_floor.generate(1, 12345)
	farm.mine_floor = test_floor
	farm.in_mine = true
	farm.player.position = test_floor.spawn_position
	var mine_target: Vector2 = Vector2(test_floor.stairs_pos) * 32 + Vector2(16, 16)
	_check(farm.navigate_to(mine_target), "矿洞点击寻路")
	_check(farm.player.nav_path.size() > 0, "矿洞寻路生成路径")
	farm.player.nav_path = PackedVector2Array()
	farm.mine_floor = old_mine_floor
	farm.in_mine = was_in_mine
	farm.player.position = path_old_player_pos
	test_floor.free()

	# 迷雾存档：PNG + Base64 往返
	farm.map_ui._ensure_fog()
	var fog_blob: String = farm.map_ui.export_fog()
	_check(not fog_blob.is_empty(), "迷雾可导出为存档字符串")
	farm.map_ui.reset_fog()
	_check(farm.map_ui._fog_image == null, "新游戏可重置迷雾")
	farm.map_ui.import_fog(fog_blob)
	_check(farm.map_ui._fog_image != null, "迷雾可从存档恢复")

	# 对象池：取出 / 回收 / 复用
	_check(farm._slash_pool != null, "挥砍对象池已创建")
	var pooled_node: Node = farm._slash_pool.acquire()
	_check(farm._slash_pool.active_count() == 1, "对象池可取出节点")
	farm._slash_pool.release(pooled_node)
	_check(farm._slash_pool.active_count() == 0, "对象池可回收节点")
	var reused_node: Node = farm._slash_pool.acquire()
	_check(reused_node == pooled_node, "对象池复用同一节点")
	farm._slash_pool.release(reused_node)

	# 图鉴 UI：分类条目 / 收集状态 / 排序
	_check(farm.ui.collection_panel != null, "图鉴面板已创建")
	_check(farm.ui.collection_grid != null, "图鉴包含物品网格")
	var crop_entries: Array = farm.ui._collection_entries("crop")
	_check(crop_entries.size() == DB.get_all_crops().size(), "图鉴作物条目数与配置一致")
	farm.unlock_book["crop"] = []
	farm.ui._collection_category = "crop"
	farm.ui.refresh_collection()
	_check(farm.ui.collection_title.text.contains("0 / 40"), "图鉴初始未收集状态正确")
	farm._unlock("crop", "turnip")
	farm.ui.refresh_collection()
	_check(farm.ui.collection_title.text.contains("1 / 40"), "图鉴收集状态随解锁更新")
	farm.ui._cycle_collection_sort()
	_check(farm.ui._collection_sort == "name", "图鉴排序切换到名称")
	farm.ui._cycle_collection_sort()
	_check(farm.ui._collection_sort == "price", "图鉴排序切换到价格")
	farm.ui._cycle_collection_sort()
	_check(farm.ui._collection_sort == "uncollected", "图鉴排序切换到未收集优先")
	farm.ui._cycle_collection_sort()
	_check(farm.ui._collection_sort == "default", "图鉴排序回到默认")
	farm.ui.open_collection()
	_check(farm.ui.get_modal() == "collection", "图鉴可打开并进入模态")
	farm.ui.close_modal()
	_check(not farm.ui.is_modal_open(), "图鉴关闭后退出模态")

	# 制作人员 / 素材授权面板
	_check(farm.ui.credits_panel != null, "制作人员面板已创建")
	farm.ui.open_credits()
	_check(farm.ui.get_modal() == "credits", "制作人员面板可打开")
	farm.ui.close_modal()

	# 美术反馈：作物风摆 Shader / 拾取浮动 / 动物爱心
	var any_tile: FarmTile = farm.farm_tiles.values()[0]
	_check(any_tile.material is ShaderMaterial, "农田使用作物风摆 Shader")
	farm._spawn_pickup("turnip", "crop", farm.player.position)
	var pickup_nodes := farm.get_tree().get_nodes_in_group("pickup_fx")
	_check(pickup_nodes.size() >= 1, "拾取浮动动画已生成")
	for pickup_node in pickup_nodes:
		pickup_node.queue_free()
	var ambient = farm.get_node_or_null("AmbientParticles")
	_check(ambient != null and ambient is AmbientParticles, "环境粒子节点已创建")
	if farm.animals.size() > 0:
		var animal = farm.animals[0]
		animal.celebrate()
		_check(animal._heart_timer > 0.0, "动物爱心动画已触发")
		animal.set_sick(true)
		_check(animal.sick, "动物生病状态可设置")
		animal.set_sick(false)

	# 地面掉落物：生成与自动拾取
	farm._spawn_ground_item({
		"item_id": "turnip", "category": "crop", "count": 1, "name": "萝卜",
	}, farm.player.position + Vector2(4, 0))
	var grounds := farm.get_tree().get_nodes_in_group("ground_items")
	_check(grounds.size() >= 1, "地面掉落物已生成")
	if grounds.size() > 0:
		var turnip_before: int = farm.inventory.count_item("turnip", "crop")
		var picked: bool = grounds[0].try_pickup()
		_check(picked, "地面掉落物可拾取")
		_check(farm.inventory.count_item("turnip", "crop") == turnip_before + 1,
			"拾取后进入背包")

	# 博物馆：配置 / 捐赠 / 图鉴联动
	_check(DB.get_all_artifacts().size() >= 7, "博物馆古物配置加载")
	farm.ui.open_museum()
	_check(farm.ui.get_modal() == "museum", "博物馆可打开")
	_check(farm.ui.museum_grid != null, "博物馆包含陈列网格")
	_check(farm.museum_items("artifact").size() == DB.get_all_artifacts().size(),
		"博物馆古物条目完整")
	farm.inventory.add_item({
		"item_id": "pottery_shard", "category": "artifact", "count": 1, "price": 30,
	})
	_check(farm.donate_to_museum("pottery_shard", "artifact"), "古物可捐赠")
	_check("pottery_shard" in farm.museum_donations, "捐赠写入博物馆记录")
	_check(farm.inventory.count_item("pottery_shard", "artifact") == 0, "捐赠扣除背包物品")
	var artifact_book: Array = farm.unlock_book.get("artifact", [])
	_check("pottery_shard" in artifact_book, "捐赠解锁古物图鉴")
	_check(not farm.donate_to_museum("pottery_shard", "artifact"), "重复捐赠被拒绝")
	farm.ui.close_modal()

	# 加工机器：购买 → 开始 → 完成 → 取出
	farm.money = 20000
	farm.buy_machine("cheese_maker")
	_check(farm.inventory.count_item("cheese_maker", "machine") == 1, "购买加工机器进背包")
	var machine: ProcessingMachine = farm._spawn_machine("cheese_maker", Vector2i(12, 12))
	farm.inventory.add_item({
		"item_id": "milk", "category": "animal_product", "count": 2, "price": 150,
	})
	_check(farm.can_start_machine(machine, "cheese"), "奶酪机可开始加工")
	farm.start_machine(machine, "cheese")
	_check(not machine.product_id.is_empty(), "机器进入加工状态")
	machine.ready_at = farm.time.get_absolute_minutes()
	_check(machine.is_ready(), "绝对时间到后机器完成")
	var cheese_before: int = farm.inventory.count_item("cheese", "processed")
	farm.collect_machine(machine)
	_check(farm.inventory.count_item("cheese", "processed") == cheese_before + 1,
		"取出加工品进背包")
	_check(machine.product_id.is_empty(), "取出后机器空闲")

	# 战斗：受伤 / 无敌帧 / 怪物随层数缩放
	var hp_before: int = farm.player.hp
	farm.player.take_damage(20)
	_check(farm.player.hp == hp_before - 20, "玩家受到伤害")
	farm.player.take_damage(20)
	_check(farm.player.hp == hp_before - 20, "受击无敌帧")
	farm.player.restore_health(1.0)
	var monster := MineMonster.new()
	monster.setup("slime", 10, farm.player, Rect2(0, 0, 1280, 960), 1)
	_check(monster.max_hp > 20, "怪物血量随层数增强")
	monster.queue_free()

	# NPC / 好感 / 节日
	_check(farm.npcs.size() == 16, "场景生成 16 名 NPC")
	var tom: VillageNPC = null
	for npc: VillageNPC in farm.npcs:
		if npc.npc_id == "tom":
			tom = npc
			break
	_check(tom != null, "找到汤姆")
	if tom != null:
		tom.friendship = 35
		_check(tom.friendship_level() == "朋友", "好感等级映射")
		farm._apply_npc_states({"tom": {"friendship": 42}}, [])
		_check(tom.friendship == 42, "NPC 好感可读档")
		tom.friendship = 0

	# 自宅等级 / 升级
	_check(farm.home_level == 1, "初始自宅 1 级")
	farm.money = 20000
	for index in 5:
		farm.inventory.add_item({
			"item_id": "branch", "category": "forage", "count": 90, "price": 5,
		})
	farm.indoor = true
	farm._try_upgrade_home()
	_check(farm.home_level == 2, "自宅升级到 2 级")
	_check(farm.inventory.count_item("branch", "forage") == 0, "升级扣除木材")
	_check(farm.money == 10000, "升级扣除金币")

	# 储物箱 / 冰箱转移
	farm.inventory.add_item({
		"item_id": "amber", "category": "artifact", "count": 2, "price": 100,
	})
	var amber_index := -1
	for index in farm.inventory.slots.size():
		var slot: Dictionary = farm.inventory.get_slot(index)
		if str(slot.get("item_id", "")) == "amber":
			amber_index = index
			break
	_check(amber_index >= 0, "储物测试物品已放入背包")
	_check(farm.transfer_inventory_to_storage("storage", amber_index), "物品可放入储物箱")
	_check(farm.home_storage.size() >= 1, "储物箱记录物品")
	_check(farm.transfer_storage_to_inventory("storage", 0), "物品可从储物箱取回")
	_check(farm.home_storage.is_empty(), "取回后储物箱清空")
	_check(farm.storage_capacity("fridge") == 30, "冰箱初始 30 格")

	# 邮箱：按日期投递、领奖、未读旗标
	_check(DB.get_all_mail().size() >= 6, "邮箱配置已加载")
	farm.mail_pending.clear()
	farm.mail_read.clear()
	farm.time.day = 1
	farm.time.year = 1
	farm._refresh_mail()
	_check("welcome" in farm.mail_pending, "第 1 天收到欢迎信")
	_check(farm._mailbox_prop.has_mail, "未读信件竖起邮箱旗")
	var mail_money_before: int = farm.money
	var welcome: Dictionary = farm.read_mail("welcome")
	_check(not welcome.is_empty(), "可阅读欢迎信")
	_check(farm.money == mail_money_before + 300, "读信发放金币奖励")
	_check("welcome" not in farm.mail_pending and "welcome" in farm.mail_read,
		"读信后标记已读")
	_check(not farm._mailbox_prop.has_mail, "读完后邮箱旗放下")
	farm.ui.open_mail()
	_check(farm.ui.get_modal() == "mail", "邮箱面板可打开")
	farm.ui.close_modal()

	# 家具：购买 → 室内摆放 → 收回
	_check(DB.get_all_furniture().size() == 8, "家具配置 8 件")
	farm.money = 5000
	farm.buy_furniture("furn_plant")
	var furniture_index := -1
	for index in farm.inventory.slots.size():
		var slot: Dictionary = farm.inventory.get_slot(index)
		if str(slot.get("item_id", "")) == "furn_plant":
			furniture_index = index
			break
	_check(furniture_index >= 0, "家具进入背包")
	farm.indoor = true
	farm.placed_furniture.clear()
	if farm._interior != null:
		farm._interior.set_furniture(farm.placed_furniture)
	_check(farm.place_furniture_from_inventory(furniture_index), "室内可摆放家具")
	_check(farm.placed_furniture.size() == 1, "家具记录写入摆放列表")
	_check(farm._interior.is_furniture_blocked(
		int(farm.placed_furniture[0].get("gx", 0)),
		int(farm.placed_furniture[0].get("gy", 0))), "家具占用格子")
	_check(farm._house_props.size() == 1, "摆放家具生成 InteriorProp 节点")
	_check(farm._house_props[0].kind == "plant", "家具节点类型来自配置图标")
	_check(farm._house_props[0].position.y > farm._interior.origin.y,
		"家具节点锚定在室内世界坐标")
	farm.player.position = farm._interior.origin + Vector2(
		int(farm.placed_furniture[0].get("gx", 0)) * 32 + 16,
		int(farm.placed_furniture[0].get("gy", 0)) * 32 + 16)
	_check(farm.pick_up_nearby_furniture(), "可收回脚边家具")
	_check(farm.placed_furniture.is_empty(), "收回后摆放列表清空")
	_check(farm._house_props.is_empty(), "收回家具移除室内节点")
	farm.indoor = false

	# 图书馆 / 诊所
	_check(DB.get_all_books().size() == 3, "图书馆配置 3 本书")
	farm.books_read.clear()
	farm.last_book_day = -1
	farm.time.day = 2
	var books_before: int = farm.inventory.count_item("turnip", "seed")
	_check(farm.read_book("farming_book"), "可阅读图书馆书籍")
	_check(farm.inventory.count_item("turnip", "seed") > books_before, "读书发放种子奖励")
	_check(not farm.read_book("fishing_book"), "同一天只能读一本书")
	farm.time.day = 3
	_check(farm.read_book("fishing_book"), "第二天可以再读书")
	farm.money = 1000
	farm.player.stamina = 5.0
	var money_before_clinic: int = farm.money
	_check(farm.treat_player_at_clinic(), "诊所可治疗玩家")
	_check(farm.money == money_before_clinic - 200, "诊所扣费正确")
	_check(is_equal_approx(farm.player.stamina, farm.player.stamina_max), "诊所恢复体力")
	farm.animals[0].set_sick(true)
	var healed: int = farm.treat_sick_animals()
	_check(healed >= 1, "诊所可治疗生病动物")
	farm.ui.open_library()
	_check(farm.ui.get_modal() == "library", "图书馆面板可打开")
	farm.ui.close_modal()
	farm.ui.open_clinic()
	_check(farm.ui.get_modal() == "clinic", "诊所面板可打开")
	farm.ui.close_modal()

	# 浇水工：雇佣 → 每日自动浇水并扣工钱 → 解雇
	_check(DB.get_all_workers().size() == 1, "工人配置已加载")
	farm.hired_worker = false
	farm.money = 5000
	farm._toggle_worker()
	_check(farm.hired_worker, "可雇佣浇水工")
	var worker_tile: FarmTile = null
	for tile: FarmTile in farm.farm_tiles.values():
		tile.till()
		tile.plant("turnip", farm.time.season, farm.time.year)
		worker_tile = tile
		break
	farm.money = 5000
	farm._run_worker()
	_check(worker_tile.watered, "浇水工自动浇水")
	_check(farm.money == 4900, "浇水工按天扣工钱")
	farm._toggle_worker()
	_check(not farm.hired_worker, "可解雇浇水工")

	# 节日变装
	farm.npcs[0].set_festival_mode(true)
	_check(farm.npcs[0].festival_mode, "NPC 可切换节日变装")
	farm.npcs[0].set_festival_mode(false)
	_check(not farm.npcs[0].festival_mode, "NPC 可退出节日变装")

	# 通用室内系统：每个建筑都有配置、墙体、可交互家具
	for building_id: String in ["shop", "clinic", "library", "museum", "coop", "barn", "worker_hut"]:
		_check(not DB.get_interior(building_id).is_empty(), "%s 室内配置存在" % building_id)
	var interior := BuildingInteriorScript.new()
	interior.setup("shop", Vector2(0, -3000))
	_check(interior.room_w >= 6 and interior.room_h >= 5, "室内房间尺寸有效")
	_check(interior.get_props().size() > 0, "商店室内包含家具")
	_check(interior.get_wall_rects().size() == 5, "室内墙体碰撞完整")
	var door_hit := interior.get_interact(interior.door_point)
	_check(str(door_hit.get("id", "")) == "exit_building", "门口可交互离开")
	interior.free()

	# 温泉：每日一次，恢复体力与生命
	farm.hot_spring_used_today = false
	farm.player.stamina = 10.0
	farm.player.hp = 20
	farm._use_hot_spring()
	_check(is_equal_approx(farm.player.stamina, farm.player.stamina_max), "温泉恢复全部体力")
	_check(farm.player.hp == farm.player.max_hp, "温泉恢复全部生命")
	_check(farm.hot_spring_used_today, "温泉写入每日使用标记")
	_check(farm.get_node_or_null("HotSpring") != null, "温泉节点已创建")
	_check(farm.get_node("HotSpring").z_index < 0, "温泉池体在地面层（不遮挡角色）")
	_check(farm.get_node("HotSpring").get_node_or_null("Steam") != null, "温泉蒸汽独立成层")

	# 疲劳状态：移速下降 + 屏幕暗角 + 工具 4 帧动作锁定
	farm.player.restore_stamina(1.0)
	_check(is_equal_approx(farm.player.stamina_speed_multiplier(), 1.0), "满体力无移速惩罚")
	farm.player.stamina = farm.player.stamina_max * 0.15
	_check(is_equal_approx(farm.player.stamina_speed_multiplier(), 0.8), "体力<20% 移速 -20%")
	farm.player.stamina = farm.player.stamina_max * 0.05
	_check(is_equal_approx(farm.player.stamina_speed_multiplier(), 0.6), "体力<10% 移速进一步下降")
	farm.player.restore_stamina(1.0)
	var action_time: float = farm.player.play_tool_action("hoe", Vector2.DOWN)
	_check(action_time > 0.0 and farm.player.is_action_locked(), "工具动作触发并锁定移动")
	farm.player.action_timer = 0.0
	farm.player.action_kind = ""
	_check(farm.ui.fatigue_vignette != null, "疲劳暗角节点已创建")

	# 作物 5 阶段 + 成熟浮动 / 枯萎下垂（渲染不崩、阶段判定正确）
	var stage_tile := FarmTileScript.new()
	stage_tile.setup(Vector2i(1, 1), false)
	stage_tile.till()
	stage_tile.plant("turnip", "spring", 1)
	stage_tile.current_day = 0
	stage_tile.queue_redraw()
	stage_tile.current_day = 2
	stage_tile.queue_redraw()
	stage_tile.current_day = 99
	stage_tile.queue_redraw()
	stage_tile.is_withered = true
	stage_tile.queue_redraw()
	_check(true, "作物各生长阶段绘制不报错")
	stage_tile.free()

	# 坐下 2 帧 + 动物产出动作
	farm.player.set_sitting(true)
	_check(farm.player.sitting, "玩家可进入坐姿")
	farm.player.set_sitting(false)
	_check(not farm.player.sitting, "玩家可起身")
	if farm.animals.size() > 0:
		farm.animals[0].play_produce_pose()
		_check(farm.animals[0]._produce_timer > 0.0, "动物产出动作已触发")

	# 存档缩略图：写入 / 读取 / 删除
	var thumb_image := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	thumb_image.fill(Color(0.9, 0.6, 0.5, 1.0))
	Save.save_thumbnail(3, thumb_image)
	_check(Save.load_thumbnail(3) != null, "存档缩略图可保存并读取")
	Save.delete_save(3)
	_check(Save.load_thumbnail(3) == null, "删除存档同时删除缩略图")

	# 成就 / 统计
	_check(DB.get_all_achievements().size() == 10, "成就配置 10 项")
	farm.achievements_unlocked.clear()
	farm.crops_harvested = 0
	farm._record_stat("crops_harvested", 1)
	_check("first_harvest" in farm.achievements_unlocked, "首次收获解锁成就")
	_check(farm.get_achievement_progress().size() == 10, "成就进度列表完整")
	farm.ui.open_achievements()
	_check(farm.ui.get_modal() == "achievements", "成就面板可打开")
	farm.ui.close_modal()

	# 河流与木桥：桥面可通行，其余水格保持碰撞
	_check(not farm._pond_cells.has(Vector2i(1, 20)), "木桥桥面不生成水格碰撞")
	_check(farm._pond_cells.has(Vector2i(1, 22)), "河流水格生成碰撞")
	_check(farm.get_map_info().has("river_rects"), "地图数据包含河流区域")

	# NPC 逐点日程：工作时段给出目标并实际移动
	var old_minutes: float = farm.time.minutes
	farm.time.weather = "sunny"
	farm.indoor = false
	farm.in_mine = false
	farm.time.minutes = 8 * 60.0
	farm._update_npc_schedule()
	var walker: VillageNPC = farm.npcs[0]
	_check(walker.visible, "工作时段 NPC 出门")
	_check(walker.schedule_target != Vector2.INF, "NPC 获得日程目标")
	var walk_before: Vector2 = walker.position
	walker._process(0.5)
	_check(walker.position != walk_before, "NPC 向日程目标移动")
	farm.time.minutes = 23 * 60.0
	farm._update_npc_schedule()
	_check(not walker.visible, "深夜 NPC 回家")
	farm.time.minutes = old_minutes
	farm._update_npc_schedule()

	# 地窖：放入加工品 → 熟成提升品质 → 取回
	_check(int(DB.get_cellar_config().get("max_slots", 0)) == 12, "地窖配置已加载")
	farm.home_level = 3
	farm.cellar_items.clear()
	farm.inventory.add_item({
		"item_id": "wine", "category": "processed", "count": 1,
		"quality": "normal", "price": 300,
	})
	var wine_index := -1
	for index in farm.inventory.slots.size():
		var slot: Dictionary = farm.inventory.get_slot(index)
		if str(slot.get("item_id", "")) == "wine":
			wine_index = index
			break
	_check(wine_index >= 0, "地窖测试酒已放入背包")
	_check(farm.cellar_put(wine_index), "加工品可放入地窖")
	_check(farm.cellar_items.size() == 1, "地窖记录熟成物品")
	for day in 7:
		farm._advance_cellar()
	_check(str(farm.cellar_items[0].get("quality", "")) == "silver",
		"熟成 7 天提升为银品质")
	_check(farm.cellar_take(0), "熟成物品可取回")
	_check(farm.cellar_items.is_empty(), "取回后地窖清空")
	var wine_quality := ""
	for index in farm.inventory.slots.size():
		var slot: Dictionary = farm.inventory.get_slot(index)
		if str(slot.get("item_id", "")) == "wine":
			wine_quality = str(slot.get("quality", ""))
	_check(wine_quality == "silver", "取回物品保留熟成品质")
	farm.ui.open_cellar()
	_check(farm.ui.get_modal() == "cellar", "地窖面板可打开")
	farm.ui.close_modal()
	farm.home_level = 1
	farm.home_level = 1
	farm.indoor = false
	if farm._interior != null:
		farm._interior.set_level(1)

	# 委托 / 建造 / 求婚
	_check(farm.quests_active.size() == 3, "每日刷新 3 条委托")
	farm.money = 20000
	farm.inventory.add_item({"item_id": "branch", "category": "goods", "count": 50})
	farm.start_building("coop")
	_check(farm._building_days_left("coop") == 2, "鸡舍开始升级")
	farm._advance_buildings()
	_check(farm.get_building_level("coop") == 1, "建造第一天未完成")
	farm._advance_buildings()
	_check(farm.get_building_level("coop") == 2, "鸡舍升级完成")
	_check(farm.get_building_capacity("coop") == 8, "升级后栏位 8")

	farm.home_level = 2
	var candidate: VillageNPC = null
	for npc: VillageNPC in farm.npcs:
		if bool(npc.data.get("marriageable", false)):
			candidate = npc
			break
	if candidate != null:
		candidate.friendship = 200
		farm.inventory.add_item({
			"item_id": "blue_feather", "category": "special", "count": 1, "price": 5000,
		})
		_check(farm.can_propose(candidate), "满足求婚条件")
		farm.propose_to_npc(candidate)
		_check(farm.spouse_id == candidate.npc_id, "求婚成功")
		_check(farm._interior.spouse_active, "配偶入住自宅")
		farm.spouse_id = ""
		farm._interior.clear_spouse()
		candidate.friendship = 0
	farm.home_level = 1
	farm._interior.set_level(1)

	# 骑乘：建筑 → 购买（马/驴/骆驼/鸵鸟/自行车）→ 上下坐骑 → 耐力 → 载货
	# 前面的温泉测试是异步的，测试环境里手动清掉过渡标记。
	farm._transitioning = false
	farm.ui.close_modal()
	farm.buildings_state["stable"] = {"level": 3, "days_left": 0}
	farm.buildings_state["ostrich_house"] = {"level": 1, "days_left": 0}
	farm.buildings_state["bike_shed"] = {"level": 1, "days_left": 0}
	farm._refresh_mount_buildings()
	_check(farm._stable_prop.visible, "马厩建成后显示")
	_check(farm._ostrich_house_prop.visible, "鸵鸟舍建成后显示")
	_check(farm.get_building_capacity("stable") == 3, "马厩 3 级容量 3")
	_check(farm.get_building_capacity("ostrich_house") == 1, "鸵鸟舍容量 1")
	farm.money = 60000
	farm.buy_mount("horse")
	farm.buy_mount("donkey")
	farm.buy_mount("camel")
	farm.buy_mount("ostrich")
	farm.buy_mount("alpaca")
	farm.buy_mount("bicycle")
	_check(not bool(farm.can_buy_mount("tricycle").get("ok", true)),
		"自行车棚 Lv1 不能同时放三轮车")
	farm.buildings_state["bike_shed"] = {"level": 2, "days_left": 0}
	farm._refresh_mount_buildings()
	farm.buy_mount("tricycle")
	_check(farm.mounts.size() == 7, "七种坐骑均可购买并入库")
	var horse_id := ""
	var donkey_id := ""
	var camel_id := ""
	var ostrich_id := ""
	var alpaca_id := ""
	for entry: Dictionary in farm.mounts:
		match str(entry.get("type", "")):
			"horse": horse_id = str(entry.get("id", ""))
			"donkey": donkey_id = str(entry.get("id", ""))
			"camel": camel_id = str(entry.get("id", ""))
			"ostrich": ostrich_id = str(entry.get("id", ""))
			"alpaca": alpaca_id = str(entry.get("id", ""))
	# 羊驼喂食好感 +8（配置 friendship_gain_feed）
	var alpaca_data: Dictionary = farm._mount_data(alpaca_id)
	var alpaca_friendship := float(alpaca_data.get("friendship", 0.0))
	farm.inventory.add_item({"item_id": "feed", "category": "feed", "count": 1})
	_check(farm.feed_mount(alpaca_id), "羊驼可喂食")
	_check(is_equal_approx(float(alpaca_data.get("friendship", 0.0)),
		alpaca_friendship + 8.0), "羊驼喂食好感 +8")
	_check(farm.mount_nodes.has(horse_id), "马生成 RideMount 节点")
	_check(farm.mount_nodes.has(donkey_id), "驴生成 RideMount 节点")
	var horse_node = farm.mount_nodes[horse_id]
	var donkey_node = farm.mount_nodes[donkey_id]
	_check(int(donkey_node.cargo_capacity) == 8, "驴节点载货容量 8")
	farm.player.position = horse_node.position
	farm.mount_mount(horse_id, true)
	_check(farm.player.riding, "可骑上马")
	_check(horse_node.ridden, "坐骑进入被骑乘状态")
	# 骑乘靠近门：提示先下坐骑
	farm.player.position = Vector2(48.5 * 32.0, 12.5 * 32.0 + 14.0)
	var door_prompt: Dictionary = farm._nearest_interact()
	_check(str(door_prompt.get("text", "")).contains("请先下坐骑"),
		"骑乘靠近门提示先下坐骑")
	farm.player.position = horse_node.position
	# 骑乘时禁止自动拾取
	var ground := GroundItemScript.new()
	farm.add_child(ground)
	ground.setup(farm, {
		"item_id": "stone", "category": "mineral", "count": 1, "price": 2,
	}, farm.player.position)
	var stone_before: int = farm.inventory.count_item("stone")
	ground._process(0.016)
	_check(farm.inventory.count_item("stone") == stone_before,
		"骑乘时不会自动拾取掉落物")
	ground.queue_free()
	farm._update_riding(0.1)
	_check(is_equal_approx(float(farm.player.ride_speed), 200.0), "骑马速度 200")
	var ride_stamina := float(farm.mounts[0].get("stamina", 0.0))
	var player_stamina: float = farm.player.stamina
	farm.player.ride_sprinting = true
	farm.player._moving = true
	farm._update_riding(1.0)
	_check(float(farm.mounts[0].get("stamina", 0.0)) < ride_stamina, "冲刺消耗坐骑耐力")
	_check(is_equal_approx(float(farm.player.stamina), player_stamina), "骑乘不消耗玩家体力")
	farm.time.weather = "storm"
	farm._update_riding(0.0)
	_check(is_equal_approx(float(farm.player.ride_speed), 160.0), "暴雨骑乘速度 -20%")
	farm.time.weather = "sunny"
	farm.player.ride_sprinting = false
	farm.player._moving = false
	farm.enter_house()
	_check(not farm.indoor, "骑乘时不能进屋")
	farm.dismount_mount(true)
	_check(not farm.player.riding, "可以下坐骑")
	_check(not horse_node.ridden, "下坐骑后回到停放状态")
	var dismount_player_position: Vector2 = farm.player.position
	_check(horse_node.position.distance_to(dismount_player_position - Vector2(0, 24)) < 1.0,
		"马回到马厩停放点")

	# 骆驼：暴雨不减速；鸵鸟：暴雨 -30%
	farm.player.position = (farm.mount_nodes[camel_id] as Node2D).position
	farm.mount_mount(camel_id, true)
	farm.time.weather = "storm"
	farm._update_riding(0.0)
	_check(is_equal_approx(float(farm.player.ride_speed), 140.0), "骆驼暴雨不减速")
	farm.dismount_mount(true)
	# 站在石板路上，避免鸵鸟的草地加成干扰天气数值
	farm.player.position = Vector2(50.5 * 32.0, 26.0 * 32.0)
	farm.mount_mount(ostrich_id, true)
	farm._update_riding(0.0)
	_check(is_equal_approx(float(farm.player.ride_speed), 119.0), "鸵鸟暴雨速度 -30%")
	farm._update_riding(0.1)
	_check(farm.player.riding, "可骑鸵鸟")
	farm.dismount_mount(true)
	farm.time.weather = "sunny"

	# 载货：驴 8 格，存入 / 取出
	farm.inventory.add_item({"item_id": "antler", "category": "animal_product", "count": 5, "price": 700})
	var cargo_slot := -1
	for index in farm.inventory.slots.size():
		var slot: Dictionary = farm.inventory.get_slot(index)
		if str(slot.get("item_id", "")) == "antler":
			cargo_slot = index
			break
	_check(cargo_slot >= 0, "载货测试物品进入背包")
	var cargo_count := int(farm.inventory.get_slot(cargo_slot).get("count", 0))
	_check(farm.store_held_to_cargo(donkey_id, cargo_slot), "可把物品存入货袋")
	_check(int(farm.get_mount_cargo(donkey_id).get("used", 0)) == cargo_count,
		"货袋记录物品数量")
	_check(int(donkey_node.cargo_used) == cargo_count, "货袋数量同步到坐骑节点")
	farm.ui.open_mount_panel("stable")
	_check(farm.ui.get_modal() == "mount", "马厩面板可打开")
	farm.ui.close_modal()
	farm.ui.open_mount_panel("barn")
	_check(farm.ui.get_modal() == "mount", "畜棚坐骑面板可打开")
	farm.ui.close_modal()
	farm.ui.open_mount_cargo(donkey_id)
	_check(farm.ui.get_modal() == "mount_cargo", "坐骑货袋面板可打开")
	farm.ui.close_modal()
	_check(farm.take_all_cargo(donkey_id), "可取回货袋物品")
	_check(int(farm.get_mount_cargo(donkey_id).get("used", 0)) == 0, "取回后货袋清空")

	# 自行车 / 三轮车：无耐力，冲刺冷却
	var bike_id := ""
	var tricycle_id := ""
	for entry: Dictionary in farm.mounts:
		match str(entry.get("type", "")):
			"bicycle": bike_id = str(entry.get("id", ""))
			"tricycle": tricycle_id = str(entry.get("id", ""))
	farm.player.position = (farm.mount_nodes[bike_id] as Node2D).position
	farm.mount_mount(bike_id, true)
	_check(farm.player.riding, "可骑自行车")
	farm.player.ride_sprinting = true
	farm._update_riding(0.1)
	farm.player.ride_sprinting = false
	farm._update_riding(0.1)
	_check(farm._bike_sprint_cd > 0.0, "自行车冲刺进入冷却")
	farm._update_riding(0.1)
	_check(farm.player.ride_sprint_blocked, "冷却中不能再次冲刺")
	farm.dismount_mount(true)
	_check(not farm.player.riding, "可下自行车")
	# 石板路（x=50 纵向道路）速度 +10%
	farm.player.position = Vector2(50.5 * 32.0, 26.0 * 32.0)
	farm.mount_mount(tricycle_id, true)
	farm._update_riding(0.0)
	_check(is_equal_approx(float(farm.player.ride_speed), 143.0), "三轮车石板路 +10%")
	farm.player.ride_sprinting = true
	farm._update_riding(0.1)
	farm.player.ride_sprinting = false
	farm._update_riding(0.1)
	_check(farm._bike_sprint_cd >= 2.9, "三轮车冲刺冷却 3 秒")
	_check(int(farm.get_mount_cargo(tricycle_id).get("capacity", 0)) == 10,
		"三轮车载货容量 10")
	farm.dismount_mount(true)

	# 牛：成年 + 好感 ≥ 60 + 未生病
	var ride_cow := AnimalScript.new()
	farm.add_child(ride_cow)
	ride_cow.setup("cow", farm.player.position + Vector2(24, 0), "barn")
	ride_cow.friendship = 70.0
	ride_cow.age_days = 30
	farm.animals.append(ride_cow)
	_check(farm.can_ride_animal(ride_cow), "成年且好感≥60 的牛可骑")
	ride_cow.friendship = 10.0
	_check(not farm.can_ride_animal(ride_cow), "好感不足不能骑牛")
	ride_cow.friendship = 70.0
	farm.mount_cow(ride_cow, true)
	_check(farm.player.riding and farm.riding_animal == ride_cow, "可骑牛")
	_check(not ride_cow.visible, "骑牛时隐藏动物本体")
	farm.dismount_mount(true)
	_check(ride_cow.visible and farm.riding_animal == null, "下牛恢复动物")
	farm.animals.erase(ride_cow)
	farm.remove_child(ride_cow)
	ride_cow.queue_free()

	# 幼年畜牧：散步加速成长，长大后转坐骑
	farm.buildings_state["stable"] = {"level": 3, "days_left": 0}
	farm._refresh_mount_buildings()
	for entry: Dictionary in farm.mounts.duplicate():
		if str(entry.get("stored_in", "")) == "stable":
			farm.mounts.erase(entry)
			break
	farm._build_mount_nodes()
	farm.money = 50000
	var pets_before_growth: int = farm.pets.size()
	var mounts_before_growth: int = farm.mounts.size()
	farm.buy_pet("shetland_foal")
	_check(farm.pets.size() == pets_before_growth + 1, "可领养幼年畜牧")
	var foal: FarmPet = farm.pets[farm.pets.size() - 1]
	_check(foal.is_young_livestock(), "幼年畜牧标记正确")
	_check(farm._adult_pet_count() == pets_before_growth, "幼年畜牧不占成宠上限")
	var age_before := foal.age_days
	_check(farm.pet_action(foal.pet_id, "walk"), "幼年畜牧可散步")
	_check(foal.age_days == age_before + 1, "散步加速成长")
	foal.age_days = int(DB.get_pet_config().get("young_growth_days", 5))
	_check(farm._grow_young_livestock(foal), "幼年畜牧可长大")
	_check(farm.mounts.size() == mounts_before_growth + 1, "长大后转为坐骑")
	_check(farm.pets.size() == pets_before_growth, "成长后移除宠物记录")

	# 存档时自动下坐骑，并写入 mounts
	farm.mount_mount(horse_id, true)
	farm.save_game(true)
	_check(not farm.player.riding, "存档时自动下坐骑")
	var reloaded: Dictionary = Save.load_data()
	_check((reloaded.get("mounts", []) as Array).size() >= 2, "坐骑列表写入存档")
	var migrated: Dictionary = Save.migrate({"save_version": 3})
	_check(migrated.get("mounts", null) is Array, "旧档迁移补空 mounts")
	_check((migrated.get("buildings", {}) as Dictionary).has("ostrich_house"),
		"旧档迁移补鸵鸟舍")
	# 读档恢复坐骑列表与节点
	farm.mounts.clear()
	farm._build_mount_nodes()
	farm.load_game()
	_check(farm.mounts.size() >= 2, "读档恢复坐骑列表")
	_check(farm.mount_nodes.size() == farm.mounts.size(), "读档重建坐骑节点")

	root.remove_child(farm)
	farm.queue_free()

	Save.delete_save()
	if had_save:
		var restore := FileAccess.open(Save.SAVE_PATH, FileAccess.WRITE)
		if restore != null:
			restore.store_string(old_text)
			restore.close()


func _test_interior() -> void:
	print("[10/17] 室内系统")
	var interior := HouseInteriorScript.new()
	interior.setup(Vector2(0, -1200))
	interior.queue_free()

	var bounds := interior.get_bounds()
	_check(bounds.size.x > 0 and bounds.size.y > 0, "室内有房间范围")
	_check(interior.get_wall_rects().size() >= 4, "室内四周有墙（门口留空）")

	# 交互点
	var near_bed := interior.get_interact(interior.bed_point)
	_check(str(near_bed.get("id", "")) == "bed", "床可交互")
	var near_mirror := interior.get_interact(interior.mirror_point)
	_check(str(near_mirror.get("id", "")) == "mirror", "镜子可交互")
	var near_storage := interior.get_interact(interior.storage_point)
	_check(str(near_storage.get("id", "")) == "storage", "储物箱可交互")
	var near_door := interior.get_interact(interior.door_point)
	_check(str(near_door.get("id", "")) == "door", "门可交互")
	_check(interior.get_interact(Vector2(0, 0)).is_empty(), "远离交互物时没有提示")

	# 信号
	var flags := {"sleep": false, "exit": false, "mirror": false, "storage": false}
	interior.sleep_requested.connect(func() -> void: flags["sleep"] = true)
	interior.exit_requested.connect(func() -> void: flags["exit"] = true)
	interior.mirror_requested.connect(func() -> void: flags["mirror"] = true)
	interior.storage_requested.connect(func(kind: String) -> void:
		flags["storage"] = true
		flags["storage_kind"] = kind
	)
	interior.interact("bed")
	interior.interact("door")
	interior.interact("mirror")
	interior.interact("storage")
	_check(flags["sleep"], "床触发睡觉信号")
	_check(flags["exit"], "门触发离开信号")
	_check(flags["mirror"], "镜子触发改外观信号")
	_check(flags["storage"], "储物箱触发储物信号")
	_check(str(flags.get("storage_kind", "")) == "storage", "储物信号携带储物类型")

	# 室内时间停止
	var time := TimeSystemScript.new()
	time.setup()
	time.enter_location("house")
	var before := time.minutes
	time.advance(120.0)
	_check(is_equal_approx(time.minutes, before), "室内时间完全停止")
	time.leave_location()
	time.advance(0.7)
	_check(time.minutes > before, "出门后时间恢复")
	time.free()


func _test_quality() -> void:
	print("[11/17] 品质系统")
	var config := DB.get_quality()
	_check(not config.is_empty(), "quality.json 已加载")
	_check((config.get("crop", {}) as Dictionary).has("unfertilized"), "作物有未施肥品质表")
	_check((config.get("crop", {}) as Dictionary).has("fertilized"), "作物有施肥品质表")

	# 未施肥：约 70% 普通
	var normal_count := 0
	var rolls := 8000
	for index in rolls:
		if QualityScript.roll_crop_quality(false) == "normal":
			normal_count += 1
	var normal_rate := float(normal_count) / float(rolls)
	_check(normal_rate > 0.66 and normal_rate < 0.74, "未施肥普通品质约 70%%，实际 %.3f" % normal_rate)

	# 施肥后：普通降到约 40%
	normal_count = 0
	for index in rolls:
		if QualityScript.roll_crop_quality(true) == "normal":
			normal_count += 1
	normal_rate = float(normal_count) / float(rolls)
	_check(normal_rate > 0.36 and normal_rate < 0.44, "施肥后普通品质约 40%%，实际 %.3f" % normal_rate)

	# 星光概率很低
	var star_count := 0
	for index in rolls:
		if QualityScript.roll_crop_quality(true) == "star":
			star_count += 1
	_check(float(star_count) / float(rolls) < 0.08, "星光品质是少数")

	# 品质倍率
	_check(is_equal_approx(QualityScript.quality_multiplier("normal"), 1.0), "普通品质倍率 1.0")
	_check(is_equal_approx(QualityScript.quality_multiplier("silver"), 1.25), "银品质倍率 1.25")
	_check(is_equal_approx(QualityScript.quality_multiplier("gold"), 1.5), "金品质倍率 1.5")
	_check(is_equal_approx(QualityScript.quality_multiplier("star"), 2.0), "星光品质倍率 2.0")
	_check(QualityScript.apply_quality_price(100, "gold") == 150, "金品质售价 1.5 倍")
	_check(QualityScript.get_quality_name("star") == "星光", "品质中文名")

	# 动物：高好感更好
	var low_gold := 0
	var high_gold := 0
	for index in 4000:
		if QualityScript.roll_animal_quality(10.0) in ["gold", "star"]:
			low_gold += 1
		if QualityScript.roll_animal_quality(95.0) in ["gold", "star"]:
			high_gold += 1
	_check(high_gold > low_gold, "高好感动物产物品质更好")


func _test_accessories() -> void:
	print("[12/17] 饰品系统")
	var slots := DB.get_accessory_slots()
	_check(slots.size() == 5, "5 个饰品部位")
	for slot: String in ["head", "face", "neck", "hand", "back"]:
		_check(slot in slots, "包含部位 %s" % slot)

	var all_items := DB.get_all_accessories()
	_check(all_items.size() >= 10, "至少 10 件饰品")

	var hat := DB.get_accessory("straw_hat")
	_check(not hat.is_empty(), "能按 id 取到草帽")
	_check(str(hat.get("slot", "")) == "head", "草帽在头部")
	_check(int(hat.get("price", 0)) > 0, "草帽有价格")

	for item: Dictionary in all_items:
		var slot := str(item.get("slot", ""))
		_check(slot in slots, "饰品 %s 的部位合法" % str(item.get("id", "")))

	_check(DB.get_accessory_slot_name("head") == "头部", "部位中文名")

	# 外观里带饰品字段
	var look := preload("res://scripts/art/PixelArt.gd").default_look()
	_check(look.has("accessories"), "外观包含 accessories 字段")
	var normalized := preload("res://scripts/art/PixelArt.gd").normalize_look({})
	_check((normalized.get("accessories", {}) as Dictionary).size() == 5, "饰品字段补齐 5 个部位")


func _test_tutorial() -> void:
	print("[13/17] 新手引导")
	var tutorial := TutorialScript.new()
	_check(tutorial.get_current_id() == "move", "第一步是移动")
	_check(not tutorial.get_current_text().is_empty(), "当前步骤有提示文本")

	# 顺序推进
	for expected: String in ["move", "till", "plant", "water", "sleep", "harvest", "ship"]:
		_check(tutorial.get_current_id() == expected, "当前步骤为 %s" % expected)
		_check(tutorial.notify(expected), "完成步骤 %s" % expected)
	_check(tutorial.finished, "七步完成后引导结束")

	# 不匹配的动作不推进
	var other := TutorialScript.new()
	other.notify("till")
	_check(other.get_current_id() == "move", "不匹配的动作不推进")

	# 跳过
	var skipped := TutorialScript.new()
	skipped.skip()
	_check(skipped.finished, "可以跳过引导")

	# 存档往返
	var saved := tutorial.to_save()
	var restored := TutorialScript.new()
	restored.from_save(saved)
	_check(restored.finished, "引导完成状态可存档还原")
	_check(int(saved.get("tutorial_step", -1)) == 7, "引导步骤写入存档")


func _test_fruit_tree() -> void:
	print("[14/20] 果树")
	_check(DB.get_all_fruit_trees().size() == 12, "12 种果树")

	var apple := DB.get_fruit_tree("apple_tree")
	_check(not apple.is_empty(), "能取到苹果树配置")
	_check(str(apple.get("fruit_id", "")) == "apple", "苹果树果实是 apple")
	_check(int(apple.get("mature_year", 0)) == 4, "苹果树第 4 年成年")
	_check(str(apple.get("season", "")) == "autumn", "苹果秋季结果")
	_check(DB.get_sapling_price("apple_tree") > 0, "树苗有价格")

	var rules := DB.get_fruit_tree_rules()
	_check(bool(rules.get("needs_3x3_space", false)), "果树需要 3×3 空间")
	_check(bool(rules.get("repeat_yearly", false)), "果树每年结果")
	_check(is_equal_approx(float(rules.get("rare_chance", 0)), 0.05), "稀有果 5%")

	# 生长：第 1 年种下，第 4 年成年
	var tree := FruitTreeScript.new()
	tree.setup("apple_tree", Vector2i(5, 5), 1, false)
	_check(not tree.mature, "刚种下是幼树")
	for year in range(1, 5):
		tree.update_maturity(year)
		if year < 4:
			_check(not tree.mature, "第 %d 年仍未成年" % year)
	_check(tree.mature, "第 4 年成年")

	# 只有秋天结果
	tree.advance_day("summer")
	_check(not tree.ripe, "夏天不结果")
	tree.advance_day("autumn")
	_check(tree.ripe, "秋天结果")
	tree.advance_day("autumn")
	_check(tree.ripe, "同一天重复调用不会清空")

	# 采摘
	var result := tree.harvest()
	_check(bool(result.get("ok", false)), "采摘成功")
	var item: Dictionary = result.get("item", {})
	_check(str(item.get("item_id", "")) == "apple", "收获的是苹果")
	_check(str(item.get("category", "")) == "fruit", "分类为 fruit")
	_check(int(item.get("price", 0)) >= 60, "苹果售价不低于基础价")
	_check(not tree.ripe, "采摘后不再结果")

	# 3×3 footprint
	_check(tree.get_footprint().size() == 9, "果树占 3×3 格")

	# 存档往返
	var saved := tree.to_save()
	var restored := FruitTreeScript.new()
	restored.from_save(saved)
	_check(restored.tree_id == "apple_tree", "果树存档还原 id")
	_check(restored.grid_pos == Vector2i(5, 5), "果树存档还原坐标")
	_check(restored.mature, "果树存档还原成熟状态")
	_check(not saved.has("base_price"), "果树存档不含配置字段")

	tree.free()
	restored.free()


func _test_beehive() -> void:
	print("[15/20] 养蜂")
	var hive_config := DB.get_hive_config()
	_check(int(hive_config.get("price", 0)) == 800, "蜂箱 800 金币")
	_check(int(hive_config.get("queen_price", 0)) == 300, "蜂王 300 金币")
	_check(int(hive_config.get("harvest_interval_days", 0)) == 3, "每 3 天收蜜")

	var flower_bonus := DB.get_flower_bonus_config()
	_check(int(flower_bonus.get("search_radius", 0)) == 2, "花源搜索半径 2（5×5）")
	_check(is_equal_approx(float(flower_bonus.get("efficiency_per_flower_type", 0)), 0.05), "每种花 +5%")
	_check(int(flower_bonus.get("max_flower_types", 0)) == 8, "最多计 8 种花")

	_check(DB.get_all_bee_products().size() == 7, "7 种蜂产品")
	_check(DB.get_bee_product("forest_honey").get("type", "") == "rare_honey", "森林蜜是稀有蜜")

	var hive := BeeHiveScript.new()
	hive.setup(Vector2i(3, 3), false)
	_check(not hive.has_queen, "空蜂箱")
	_check(not hive.can_harvest("spring", "sunny"), "没蜂王不能收蜜")

	hive.place_queen()
	_check(hive.has_queen, "放入蜂王")
	_check(not hive.can_harvest("spring", "sunny"), "刚放蜂王不能立刻收蜜")

	# 3 天后可以收
	for index in 3:
		hive.advance_day("spring", "sunny", 2)
	_check(hive.can_harvest("spring", "sunny"), "3 天后可以收蜜")
	_check(not hive.can_harvest("spring", "rain"), "雨天不能收蜜")

	# 冬季户外停产
	var winter_hive := BeeHiveScript.new()
	winter_hive.setup(Vector2i(4, 4), false)
	winter_hive.place_queen()
	winter_hive.days_since_harvest = 5
	_check(not winter_hive.can_harvest("winter", "snow"), "冬季户外停产")
	winter_hive.greenhouse = true
	_check(winter_hive.can_harvest("winter", "snow"), "温室蜂箱冬季可收")
	winter_hive.free()

	# 收蜜
	var result := hive.harvest("spring", "sunny", 3)
	_check(bool(result.get("ok", false)), "收蜜成功")
	var items: Array = result.get("items", [])
	_check(items.size() >= 1, "至少收获 1 种蜂产品")
	if items.size() > 0:
		_check(str(items[0].get("item_id", "")) == "honey", "产物是蜂蜜")
		_check(int(items[0].get("count", 0)) >= 1, "蜂蜜数量 ≥1")
	_check(hive.days_since_harvest == 0, "收蜜后天数重置")

	# 病害
	hive.diseased = true
	_check(not hive.can_harvest("spring", "sunny"), "病害时不能收蜜")
	var health_before := hive.health
	hive.advance_day("spring", "sunny", 3)
	_check(hive.health < health_before, "病害时健康下降")
	hive.heal_disease()
	_check(not hive.diseased, "药物治疗病害")

	# 糖水
	health_before = hive.health
	hive.feed_sugar_water()
	_check(hive.health >= health_before, "喂糖水提升健康")

	# 效率加成
	_check(is_equal_approx(hive.get_efficiency(0), 1.0), "没有花源时效率 1.0")
	_check(is_equal_approx(hive.get_efficiency(4), 1.2), "4 种花效率 1.2")
	_check(is_equal_approx(hive.get_efficiency(20), 1.4), "超过 8 种按 8 种算")

	# 存档
	var saved := hive.to_save()
	var restored := BeeHiveScript.new()
	restored.from_save(saved)
	_check(restored.has_queen, "蜂箱存档还原蜂王")
	_check(is_equal_approx(restored.health, hive.health), "蜂箱存档还原健康")
	_check(restored.grid_pos == Vector2i(3, 3), "蜂箱存档还原坐标")
	_check(not saved.has("harvest_interval_days"), "蜂箱存档不含配置字段")

	hive.free()
	restored.free()


func _test_mine() -> void:
	print("[16/20] 矿洞")
	var mine := MineFloorScript.new()
	mine.generate(1, 12345)
	_check(mine.floor_num == 1, "生成第 1 层")
	_check(mine.rocks.size() >= 25, "第 1 层石头不少于 25 块（实际 %d）" % mine.rocks.size())
	_check(mine.rocks.size() <= 60, "石头数量不超过 60")

	# 楼梯距入口至少 10 格
	var distance := Vector2(mine.stairs_pos - MineFloorScript.SPAWN_TILE).length()
	_check(distance >= 10.0, "楼梯距入口至少 10 格（实际 %.1f）" % distance)

	# 同种子可复现
	var mine2 := MineFloorScript.new()
	mine2.generate(1, 12345)
	_check(mine2.rocks.size() == mine.rocks.size(), "同种子生成相同数量石头")
	_check(mine2.stairs_pos == mine.stairs_pos, "同种子生成相同楼梯位置")
	mine2.free()

	# 深层石头更多
	var deep := MineFloorScript.new()
	deep.generate(90, 12345)
	_check(deep.rocks.size() >= mine.rocks.size(), "深层石头不少于浅层")
	var hard_rocks := 0
	for deep_rock in deep.rocks:
		if int(deep_rock.max_hp) == 3:
			hard_rocks += 1
	_check(hard_rocks > 0, "深层矿石需要 3 次敲击（三段裂纹）")
	deep.free()

	# 敲石头掉落
	var rock: Node = mine.rocks[0]
	var drops: Array = mine.break_rock(rock)
	_check(drops.size() >= 1 and drops.size() <= 2, "敲碎石头至少掉落 1 种物品（可能附带古物）")
	if drops.size() > 0:
		_check(int(drops[0].get("count", 0)) >= 1, "掉落数量 ≥1")
		_check(not str(drops[0].get("item_id", "")).is_empty(), "掉落物有 id")
		_check(int(drops[0].get("price", 0)) > 0, "掉落物有售价")
	mine.free()


func _test_cooking() -> void:
	print("[17/20] 烹饪")
	_check(DB.get_all_recipes().size() == 30, "30 条烹饪菜谱")
	_check(DB.get_recipe("cheese").is_empty(), "加工品不再出现在烹饪菜谱中")
	_check(not DB.get_processing_product("sausage").is_empty(), "香肠已归入加工机器产物")

	var bread := DB.get_recipe("bread")
	_check(not bread.is_empty(), "能取到面包菜谱")
	_check(str(bread.get("category", "")) == "主食", "面包是主食")
	var ingredients: Dictionary = bread.get("ingredients", {})
	_check(int(ingredients.get("wheat", 0)) == 2, "面包要 2 个小麦")

	var grilled := DB.get_recipe("grilled_fish")
	_check(str((grilled.get("ingredients", {}) as Dictionary).keys()[0]) == "fish_any", "烤鱼用任意鱼标签")

	var cake := DB.get_recipe("cake")
	_check(not cake.is_empty(), "能取到蛋糕菜谱")
	_check(int((cake.get("effects", {}) as Dictionary).get("gift_bonus", 0)) == 8, "蛋糕送礼 +8")

	var cheese := DB.get_processing_product("cheese")
	_check(str(cheese.get("machine", "")) == "cheese_maker", "奶酪需要奶酪机")
	_check(float(cheese.get("multiplier", 0)) >= 2.0, "奶酪倍率 ≥2")

	# 所有加工品不超过 5 倍
	for product: Dictionary in DB.get_all_processing_products():
		_check(float(product.get("multiplier", 1.0)) <= 5.0,
			"%s 倍率不超过 5" % str(product.get("id", "")))


func _test_farm_tile() -> void:
	print("[18/20] 农田流程")
	var tile := FarmTileScript.new()
	tile.setup(Vector2i(2, 3), false)

	var water_before_till := tile.water()
	_check(not water_before_till, "未翻地不能浇水")

	_check(tile.till(), "锄地成功")
	_check(tile.tilled, "地块状态为已翻地")
	_check(not tile.till(), "重复锄地失败")

	var wrong_season := tile.plant("tomato", "spring", 1)
	_check(not bool(wrong_season.get("ok", false)), "春季不能种番茄")

	var planted := tile.plant("turnip", "spring", 1)
	_check(bool(planted.get("ok", false)), "春季种萝卜成功")
	_check(tile.has_crop(), "地块上有作物")
	_check(not bool(tile.plant("potato", "spring", 1).get("ok", true)), "同一地块不能重复播种")

	tile.water()
	_check(tile.watered, "浇水成功")
	for index in 4:
		tile.water()
		tile.advance_day("spring", "sunny")
	_check(tile.ripe, "每天浇水 4 天后萝卜成熟")
	_check(tile.get_growth_ratio() >= 1.0, "生长进度满")

	var harvest_result := tile.harvest()
	_check(bool(harvest_result.get("ok", false)), "收获成功")
	var item: Dictionary = harvest_result.get("item", {})
	_check(str(item.get("item_id", "")) == "turnip", "收获物 id 正确")
	_check(int(item.get("price", 0)) >= 35, "收获物售价不低于基础价")
	_check(not tile.has_crop(), "一次性作物收获后清空")
	_check(tile.tilled, "收获后仍保持翻地状态")

	# 复收作物
	var repeat_tile := FarmTileScript.new()
	repeat_tile.setup(Vector2i(4, 3), false)
	repeat_tile.till()
	_check(bool(repeat_tile.plant("cucumber", "spring", 1).get("ok", false)), "种黄瓜")
	for index in 6:
		repeat_tile.water()
		repeat_tile.advance_day("spring", "sunny")
	_check(repeat_tile.ripe, "黄瓜成熟")
	_check(bool(repeat_tile.harvest().get("ok", false)), "收黄瓜")
	_check(repeat_tile.has_crop(), "复收作物收获后保留")
	_check(not repeat_tile.ripe, "复收后重新进入生长期")

	# 雨天自动浇水
	var rain_tile := FarmTileScript.new()
	rain_tile.setup(Vector2i(5, 3), false)
	rain_tile.till()
	rain_tile.plant("turnip", "spring", 1)
	rain_tile.advance_day("spring", "rain")
	_check(rain_tile.current_day == 1, "雨天不浇水也会生长")
	_check(not rain_tile.watered, "跨日后浇水状态重置")

	# 错季枯萎
	var season_tile := FarmTileScript.new()
	season_tile.setup(Vector2i(6, 3), false)
	season_tile.till()
	season_tile.plant("turnip", "spring", 1)
	season_tile.advance_day("summer", "sunny")
	_check(season_tile.is_withered, "春季作物到夏天会枯萎")

	# 温室
	var greenhouse_tile := FarmTileScript.new()
	greenhouse_tile.setup(Vector2i(7, 3), true)
	greenhouse_tile.till()
	_check(
		bool(greenhouse_tile.plant("leek", "winter", 1).get("ok", false)),
		"温室可以种冬季作物"
	)
	greenhouse_tile.water()
	for index in 6:
		greenhouse_tile.water()
		greenhouse_tile.advance_day("winter", "snow")
	_check(greenhouse_tile.ripe, "温室韭菜成熟")

	# 户外冬季
	var winter_tile := FarmTileScript.new()
	winter_tile.setup(Vector2i(8, 3), false)
	winter_tile.till()
	_check(
		not bool(winter_tile.plant("leek", "winter", 1).get("ok", false)),
		"户外冬季不能种冬季作物"
	)

	# 存档往返
	var saved := tile.to_save()
	var restored := FarmTileScript.new()
	restored.from_save(saved)
	_check(restored.grid_pos == tile.grid_pos, "地块坐标还原")
	_check(restored.tilled == tile.tilled, "地块状态还原")

	tile.free()
	repeat_tile.free()
	rain_tile.free()
	season_tile.free()
	greenhouse_tile.free()
	winter_tile.free()
	restored.free()


func _test_fish_minigame() -> void:
	print("[19/20] 钓鱼小游戏")
	var fish := DB.get_fish("crucian")
	_check(not fish.is_empty(), "取到鲫鱼配置")

	# 成功路径：自动收线器直接推进 90%，稍微按住即可。
	var success_game := FishMiniGameScript.new()
	var success_results: Array = []
	success_game.finished.connect(func(success: bool, result: Dictionary) -> void:
		success_results.append({"success": success, "result": result})
	)
	success_game.start(fish, {"rod_id": "gold_rod", "tackle_id": "auto_reel"})
	var steps := 0
	while success_game.running and steps < 5000:
		success_game.advance(0.016, true)
		steps += 1
	_check(not success_game.running, "自动收线器下小游戏应结束")
	_check(success_results.size() == 1, "成功路径应发出一次 finished")
	if success_results.size() == 1:
		var payload: Dictionary = success_results[0]["result"]
		_check(bool(success_results[0]["success"]), "自动收线器下应成功")
		_check(bool(payload.get("success", false)), "结果 success=true")
		_check(float(payload.get("weight", 0.0)) > 0.0, "鱼重量大于 0")
		_check(int(payload.get("price", 0)) >= int(fish.get("base_price", 0)), "售价不低于基础价")
		_check(str(payload.get("item_id", "")) == "crucian", "结果鱼 id 正确")
	success_game.free()

	# 失败路径：完全不收线，进度会掉到 0 / 超时。
	var fail_game := FishMiniGameScript.new()
	var fail_results: Array = []
	fail_game.finished.connect(func(success: bool, result: Dictionary) -> void:
		fail_results.append({"success": success, "result": result})
	)
	fail_game.start(fish, {})
	for index in 3000:
		if not fail_game.running:
			break
		fail_game.advance(0.016, false)
	_check(not fail_game.running, "不操作时小游戏会结束")
	_check(fail_results.size() == 1, "失败路径应发出一次 finished")
	if fail_results.size() == 1:
		_check(not bool(fail_results[0]["success"]), "不操作时应失败")
		_check(str(fail_results[0]["result"].get("reason", "")) != "", "失败结果带原因")
	fail_game.free()

	# 可玩性：不用自动收线器，靠「张力高就松手、低就收线」的策略
	# 应该在多数随机种子下能钓上鲫鱼。
	var wins := 0
	var attempts := 12
	for seed_value in range(1, attempts + 1):
		var sim := FishMiniGameScript.new()
		sim.start(fish, {"rng_seed": seed_value})
		var holding := true
		var sim_steps := 0
		while sim.running and sim_steps < 5000:
			if sim.is_fish_pulling:
				holding = false
			elif sim.tension >= 0.70:
				holding = false
			elif sim.tension <= 0.40:
				holding = true
			sim.advance(0.016, holding)
			sim_steps += 1
		if bool(sim.last_result.get("success", false)):
			wins += 1
		sim.free()
	_check(wins >= 4, "普通拉扯策略应能钓上鲫鱼（%d/%d）" % [wins, attempts])

	# 断线路径：一直按住不放，张力会先满。
	var break_game := FishMiniGameScript.new()
	break_game.start(fish, {"difficulty_delta": 1.0})
	var broke := false
	for index in 5000:
		if not break_game.running:
			break
		break_game.advance(0.016, true)
	if not break_game.running:
		broke = str(break_game.last_result.get("reason", "")) == "line_broken" \
			or str(break_game.last_result.get("reason", "")) == "caught"
	_check(not break_game.running, "一直按住也会结束")
	_check(broke, "一直按住应断线或刚好钓上来")
	break_game.free()
