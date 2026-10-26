extends SceneTree
## 截图 / 场景集成验证工具：
## 驱动正式 Farm 场景，生成 README 用的预览图。

const Save := preload("res://scripts/core/SaveSystem.gd")

const TILE := 32

var frames := 0
var farm: Node


func _initialize() -> void:
	farm = load("res://scenes/Farm.tscn").instantiate()
	root.add_child(farm)


func _process(_delta: float) -> bool:
	frames += 1

	if frames == 8:
		Save.delete_save()
		_close_creator()
		farm.start_new_game(false)

	if frames == 20:
		_setup_demo()

	if frames == 26:
		farm.ui.hide_dialogue()
		for child in farm.ui.toast_box.get_children():
			child.queue_free()
		farm.time.weather = "sunny"
		farm.ui.refresh_hud()

	if frames == 30:
		_save_png("res://farm_preview.png")

	if frames == 32:
		farm.player.position = Vector2(32.0 * TILE, 12.0 * TILE)
		farm.camera.position = farm.player.position
		farm.camera.reset_smoothing()

	if frames == 33:
		_save_png("res://crop_wind_preview.png")

	if frames == 34:
		farm.player.position = Vector2(30.0 * TILE, 22.0 * TILE)
		farm.camera.position = farm.player.position
		farm.camera.reset_smoothing()

	if frames == 36:
		_save_png("res://npc_preview.png")

	if frames == 40:
		farm.enter_house()

	if frames == 66:
		farm.toggle_map()

	if frames == 68:
		_save_png("res://map_house_preview.png")
		farm.map_ui.close_map()

	if frames == 70:
		_save_png("res://house_preview.png")
		farm.exit_house()

	if frames == 100:
		farm.ui.open_shop()

	if frames == 112:
		_save_png("res://shop_preview.png")

	if frames == 114:
		farm.ui._switch_shop_tab("machines")

	if frames == 117:
		_save_png("res://shop_machines_preview.png")

	if frames == 118:
		farm.ui._switch_shop_tab("animals")

	if frames == 122:
		farm.ui._switch_shop_tab("pets")

	if frames == 126:
		_save_png("res://pets_preview.png")
		farm.ui._switch_shop_tab("animals")

	if frames == 130:
		_save_png("res://shop_animals_preview.png")
		farm.ui._switch_shop_tab("accessories")

	if frames == 133:
		farm.ui.close_modal()
		farm.ui.hide_dialogue()
		farm.ui.set_prompt("")
		farm.player.position = Vector2(48.5 * TILE, 18.0 * TILE)
		farm.camera.position = farm.player.position
		farm.camera.reset_smoothing()

	if frames == 136:
		if not farm.pets.is_empty():
			farm.add_pet_house_decoration(farm.pets[0].house_id)
		_save_png("res://pet_house_preview.png")

	if frames == 154:
		if not farm.pets.is_empty():
			farm.ui.open_pet_panel(farm.pets[0].pet_id)

	if frames == 155:
		_save_png("res://pet_panel_preview.png")
		farm.ui.close_modal()

	if frames == 167:
		if not farm.pets.is_empty():
			farm.ui.open_pet_name_dialog(farm.pets[0].pet_id)

	if frames == 168:
		_save_png("res://pet_name_preview.png")
		farm.ui.close_modal()

	if frames == 134:
		_save_png("res://accessories_preview.png")
		farm.ui.close_modal()

	if frames == 136:
		farm.ui.open_inventory()

	if frames == 148:
		_save_png("res://inventory_preview.png")
		farm.ui.close_modal()

	if frames == 150:
		farm.ui.open_settings_panel()

	if frames == 153:
		_save_png("res://settings_preview.png")
		farm.ui.close_modal()

	if frames == 156:
		farm.ui.show_dialogue("清晨", "第 1 年 · 春季 · 4 日\n天气：雨\n下雨了，作物会自动浇水。", 8.0)

	if frames == 164:
		_save_png("res://dialogue_preview.png")

	if frames == 170:
		farm.ui.hide_dialogue()
		farm.player.position = Vector2(51.0 * TILE, 31.0 * TILE)
		farm.camera.position = farm.player.position
		farm.camera.reset_smoothing()
		# 正午属于 day 时段，确保初始鱼竿能抽到鱼
		farm.time.minutes = 720.0
		# 预览跳过抛竿等待，直接进入张力界面
		farm.fishing_cast_time = 0.0
		farm._try_fishing()

	if frames == 172:
		# 预览中抛竿动画已开始，直接推进到浮漂落水后的状态
		farm.player._fishing_time = 1.0
		if farm.ui.get_minigame().running:
			farm.ui.get_minigame().progress = 0.58
			farm.ui.get_minigame().tension = 0.64
			farm.ui.get_minigame().is_fish_pulling = true
			farm.ui.get_minigame().time_left = 14.2
			farm.ui.get_minigame().queue_redraw()

	if frames == 180:
		_save_png("res://fishing_preview.png")
		farm.ui.get_minigame().cancel()

	if frames == 184:
		for child in farm.ui.toast_box.get_children():
			child.queue_free()
		farm.enter_mine(7)

	if frames == 202:
		farm.ui.fade_rect.modulate.a = 0.0
		for child in farm.ui.toast_box.get_children():
			child.queue_free()
		farm.ui.hide_dialogue()
		farm.ui.set_prompt("")
		# 把玩家放到第 10 层附近的一块石头旁，便于看清
		if farm.mine_floor.rocks.size() > 0:
			var rock: Node2D = farm.mine_floor.rocks[0]
			farm.player.position = rock.position + Vector2(0, 26)
			farm.camera.position = farm.player.position
			farm.camera.reset_smoothing()

	if frames == 206:
		farm.toggle_map()

	if frames == 212:
		_save_png("res://map_mine_preview.png")
		farm.map_ui.close_map()

	if frames == 218:
		_save_png("res://mine_preview.png")
		farm.exit_mine()

	if frames == 232:
		farm.inventory.add_item({"item_id": "wheat", "category": "crop", "count": 6, "quality": "normal", "price": 30})
		farm.inventory.add_item({"item_id": "egg", "category": "animal_product", "count": 3, "quality": "normal", "price": 50})

	if frames == 240:
		farm.ui.open_cooking()

	if frames == 260:
		_save_png("res://cooking_preview.png")
		farm.ui.close_modal()

	if frames == 262:
		farm.inventory.add_item({
			"item_id": "milk", "category": "animal_product", "count": 2, "price": 150,
		})
		if farm.machines.size() > 0:
			farm.ui.open_machine(farm.machines[0])

	if frames == 267:
		_save_png("res://machine_preview.png")
		farm.ui.close_modal()

	if frames == 269:
		farm.ui.toggle_help()

	if frames == 273:
		_save_png("res://help_preview.png")
		farm.ui.close_modal()
		farm.toggle_map()

	if frames == 275:
		# 悬停自宅图标，验证 InfoPanel
		var target: Control = null
		for child in farm.map_ui.icon_container.get_children():
			if child is Control and str(child.get_meta("entity_name", "")) == "自宅":
				target = child
				break
		if target != null:
			farm.ui.get_viewport().warp_mouse(target.get_global_rect().get_center())

	if frames == 280:
		_save_png("res://map_preview.png")
		farm.map_ui.close_map()

	if frames == 282:
		farm._open_creator(false)

	if frames == 300:
		_save_png("res://creator_preview.png")
		_close_creator()

	if frames == 302:
		# 图鉴预览：解锁部分条目，展示已收集 / 未收集两种状态
		for crop_id: String in ["turnip", "potato", "strawberry", "cauliflower", "pumpkin"]:
			farm._unlock("crop", crop_id)
		for fish_id: String in ["crucian", "carp", "catfish"]:
			farm._unlock("fish", fish_id)
		for ore_id: String in ["copper", "iron", "gold"]:
			farm._unlock("mineral", ore_id)
		farm.ui.open_collection()

	if frames == 306:
		_save_png("res://collection_preview.png")
		farm.ui.close_modal()

	if frames == 310:
		farm.inventory.add_item({
			"item_id": "pottery_shard", "category": "artifact", "count": 1, "price": 30,
		})
		farm.inventory.add_item({
			"item_id": "amber", "category": "artifact", "count": 1, "price": 100,
		})
		farm.donate_to_museum("pottery_shard", "artifact")
		farm.ui.open_museum()

	if frames == 314:
		_save_png("res://museum_preview.png")
		farm.ui.close_modal()

	if frames == 317:
		farm.home_storage.append({
			"item_id": "copper", "category": "mineral", "count": 12, "price": 15,
		})
		farm.home_storage.append({
			"item_id": "turnip", "category": "crop", "count": 5, "price": 35,
		})
		farm.ui.open_storage("storage")

	if frames == 322:
		_save_png("res://storage_preview.png")
		farm.ui.close_modal()

	if frames == 326:
		farm.ui.open_mail()

	if frames == 330:
		_save_png("res://mail_preview.png")
		farm.ui.close_modal()

	if frames == 332:
		farm.home_level = 3
		farm.inventory.add_item({
			"item_id": "wine", "category": "processed", "count": 1,
			"quality": "normal", "price": 320,
		})
		farm.inventory.add_item({
			"item_id": "cheese", "category": "processed", "count": 1,
			"quality": "silver", "price": 900,
		})
		for index in farm.inventory.slots.size():
			var slot: Dictionary = farm.inventory.get_slot(index)
			if str(slot.get("item_id", "")) == "cheese":
				farm.cellar_put(index)
				break
		farm.ui.open_cellar()

	if frames == 336:
		_save_png("res://cellar_preview.png")
		farm.ui.close_modal()

	if frames == 338:
		farm.time.weather = "blizzard"
		farm.time.minutes = 12 * 60.0
		farm.ui.refresh_hud()

	if frames == 342:
		_save_png("res://blizzard_preview.png")
		farm.time.weather = "sunny"

	if frames == 344:
		farm._record_stat("crops_harvested", 1)
		farm.ui.open_achievements()

	if frames == 348:
		_save_png("res://achievements_preview.png")
		farm.ui.close_modal()

	if frames == 350:
		farm.save_game(true)
		farm.ui.open_save_panel()

	if frames == 354:
		_save_png("res://save_preview.png")
		farm.ui.close_modal()

	if frames == 356:
		farm.ui.hide_dialogue()
		farm.ui.set_prompt("")
		farm.player.position = Vector2(17.0 * TILE, 34.2 * TILE)
		farm.camera.position = farm.player.position
		farm.camera.reset_smoothing()

	if frames == 360:
		_save_png("res://hot_spring_preview.png")

	if frames == 361:
		farm.hot_spring_used_today = false
		farm._use_hot_spring()

	if frames == 376:
		for child in farm.ui.toast_box.get_children():
			child.queue_free()
		farm.ui.hide_dialogue()
		farm.ui.set_prompt("")

	if frames == 378:
		var bath_fx = load("res://scripts/fx/BathEffect.gd").new()
		farm.add_child(bath_fx)
		bath_fx.setup(Vector2(17.0 * TILE, 34.2 * TILE - 8.0))

	if frames == 380:
		_save_png("res://hot_spring_bath_preview.png")

	if frames == 384:
		farm.ui.hide_dialogue()
		farm.ui.set_prompt("")
		farm.player.position = Vector2(10.0 * TILE, 16.4 * TILE)
		farm.camera.position = farm.player.position
		farm.camera.reset_smoothing()

	if frames == 390:
		_save_png("res://town_buildings_preview.png")
		farm.ui.open_library()

	if frames == 396:
		_save_png("res://library_preview.png")
		farm.ui.close_modal()

	if frames == 400:
		for child in farm.ui.toast_box.get_children():
			child.queue_free()
		farm._transitioning = false
		farm.enter_house()

	if frames == 422:
		for child in farm.ui.toast_box.get_children():
			child.queue_free()
		farm.placed_furniture = [
			{"id": "furn_rug", "gx": 3, "gy": 7},
			{"id": "furn_bookshelf", "gx": 6, "gy": 7},
			{"id": "furn_plant", "gx": 1, "gy": 7},
			{"id": "furn_fishtank", "gx": 9, "gy": 4},
			{"id": "furn_table", "gx": 4, "gy": 3},
			{"id": "furn_chair", "gx": 2, "gy": 3},
			{"id": "furn_gramophone", "gx": 10, "gy": 6},
		]
		if farm._interior != null:
			farm._interior.set_furniture(farm.placed_furniture)
			farm._refresh_house_props()
			farm.player.position = farm._interior.origin + Vector2(6 * 32, 6 * 32)
		farm.ui.hide_dialogue()
		farm.ui.set_prompt("")
		farm.ui.force_clear_fade()
		farm.camera.position = farm.player.position
		farm.camera.reset_smoothing()

	if frames == 426:
		_save_png("res://furniture_preview.png")

	if frames == 430:
		farm.exit_house()

	if frames == 452:
		farm.enter_building("shop")

	if frames == 478:
		farm.ui.hide_dialogue()
		farm.ui.set_prompt("")
		for child in farm.ui.toast_box.get_children():
			child.queue_free()
		farm.ui.fade_rect.modulate.a = 0.0
		_save_png("res://interior_shop_preview.png")
		farm.exit_building()

	if frames == 506:
		farm.enter_building("museum")

	if frames == 532:
		farm.ui.hide_dialogue()
		farm.ui.set_prompt("")
		for child in farm.ui.toast_box.get_children():
			child.queue_free()
		farm.ui.fade_rect.modulate.a = 0.0
		_save_png("res://interior_museum_preview.png")
		farm.exit_building()

	# 留出足够帧数让之前的室内退出过渡（0.32 秒实时计时）彻底结束
	if frames == 620:
		farm._transitioning = false
		farm.indoor = false
		farm.current_building = ""
		farm.buildings_state["stable"] = {"level": 3, "days_left": 0}
		farm.buildings_state["ostrich_house"] = {"level": 1, "days_left": 0}
		farm.buildings_state["bike_shed"] = {"level": 2, "days_left": 0}
		farm._refresh_mount_buildings()
		farm.money = 60000
		for mount_type: String in [
			"horse", "donkey", "camel", "ostrich", "alpaca", "bicycle", "tricycle",
		]:
			farm.buy_mount(mount_type)
		farm.player.position = Vector2(52.0 * TILE, 30.0 * TILE)
		farm.ui.hide_dialogue()
		farm.ui.set_prompt("")
		for child in farm.ui.toast_box.get_children():
			child.queue_free()
		farm.ui.force_clear_fade()
		farm.ui.refresh_hud()
		farm.camera.position = farm.player.position
		farm.camera.reset_smoothing()

	if frames == 640:
		farm.player.position = Vector2(52.0 * TILE, 30.0 * TILE)
		farm.camera.position = farm.player.position
		farm.camera.reset_smoothing()
		farm.ui.hide_dialogue()
		farm.ui.set_prompt("")
		for child in farm.ui.toast_box.get_children():
			child.queue_free()
		farm.ui.force_clear_fade()
		farm.ui.refresh_hud()
		_save_png("res://mount_preview.png")

	if frames == 650:
		var horse_id := ""
		for entry: Dictionary in farm.mounts:
			if str(entry.get("type", "")) == "horse":
				horse_id = str(entry.get("id", ""))
		farm.mount_mount(horse_id, true)
		farm.player.position += Vector2(40, 30)
		farm.camera.position = farm.player.position
		farm.camera.reset_smoothing()

	if frames == 655:
		farm.ui.hide_dialogue()
		for child in farm.ui.toast_box.get_children():
			child.queue_free()

	if frames == 660:
		farm.ui.set_prompt("")
		farm.ui.force_clear_fade()
		_save_png("res://mount_ride_preview.png")

	if frames == 670:
		farm.dismount_mount(true)

	if frames == 672:
		farm._spawn_wild_critter()
		if not farm.wild_critters.is_empty():
			var critter: WildCritter = farm.wild_critters[0]
			critter.position = farm.player.position + Vector2(36, 10)
			critter.set_process(false)
			farm.player.position += Vector2(-20, 20)
			farm.camera.position = farm.player.position
			farm.camera.reset_smoothing()

	if frames == 674:
		farm.ui.hide_dialogue()
		farm.ui.set_prompt("")
		for child in farm.ui.toast_box.get_children():
			child.queue_free()
		farm.ui.force_clear_fade()
		_save_png("res://wildlife_preview.png")
		farm._clear_wild_critters()

	if frames == 675:
		farm.player.position = Vector2(45.0 * 32.0, 14.0 * 32.0)
		farm.camera.position = farm.player.position
		farm.camera.reset_smoothing()
		farm.ui.hide_dialogue()
		farm.ui.set_prompt("")
		for child in farm.ui.toast_box.get_children():
			child.queue_free()
		farm.ui.force_clear_fade()

	if frames == 677:
		_save_png("res://farm_sign_preview.png")

	if frames == 680:
		Save.delete_save()
		print("done: money=", farm.money, " animals=", farm.animals.size(),
			" mounts=", farm.mounts.size())
		quit()
		return true
	return false


func _close_creator() -> void:
	for child in farm.get_children():
		if child is CharacterCreator:
			farm.remove_child(child)
			child.queue_free()
	farm._transitioning = false
	farm.player.input_locked = false


func _setup_demo() -> void:
	# 农田
	var ids := ["turnip", "turnip", "potato", "cucumber", "strawberry", "turnip"]
	var index := 0
	for y in range(10, 13):
		for x in range(26, 31):
			var key := Vector2i(x, y)
			if not farm.farm_tiles.has(key):
				continue
			var tile: FarmTile = farm.farm_tiles[key]
			tile.till()
			tile.plant(ids[index % ids.size()], farm.time.season, farm.time.year)
			index += 1

	for day_index in 3:
		for tile: FarmTile in farm.farm_tiles.values():
			if tile.has_crop() and not tile.is_withered:
				tile.water()
		farm.time.sleep()

	# 牧场：买动物、喂食
	farm.money = 20000
	farm.buy_animal("chicken")
	farm.buy_animal("chicken")
	farm.buy_animal("chicken")
	farm.buy_animal("cow")
	farm.buy_feed(10)
	farm.feed_building("coop")
	farm.feed_building("barn")

	# 宠物
	farm.money = 40000
	farm.buy_pet("shiba")
	farm.buy_pet("orange_cat")
	farm.buy_pet("budgie")
	farm.buy_pet("goldfish")
	farm.buy_pet("holland_lop")
	farm.buy_pet("golden_hamster")
	farm.buy_pet("grass_turtle")

	# 果树：种两棵成熟的，一棵结果
	farm.money = 20000
	farm.buy_sapling("apple_tree")
	farm.plant_fruit_tree("apple_tree", Vector2i(11, 37))
	var AppleTreeClass = load("res://scripts/farm/FruitTree.gd")
	for tree in farm.fruit_trees:
		tree.mature = true
		tree.ripe = true
		tree.planted_year = 1
		tree.queue_redraw()
	farm.plant_fruit_tree("peach_tree", Vector2i(17, 38))
	for tree in farm.fruit_trees:
		tree.mature = true
		tree.queue_redraw()

	for animal: FarmAnimal in farm.animals:
		animal.advance_day(true)

	# 加工机器：放在牧场入口附近，供预览
	farm._spawn_machine("cheese_maker", Vector2i(24, 25))

	# 让村民出现在广场，便于预览
	farm.time.minutes = 600.0
	farm._update_npc_schedule()

	farm.player.position = Vector2(29.0 * TILE, 26.0 * TILE)
	farm.ui.refresh_hud()


func _save_png(path: String) -> void:
	# 截图前强制清掉淡入淡出与夜晚色调，避免残影
	if farm != null:
		if farm.ui != null:
			farm.ui.force_clear_fade()
		if farm.day_light != null and not farm.in_mine:
			farm.day_light.color = Color.WHITE
	var image := root.get_texture().get_image()
	# 480×270 渲染目标 → 4x 最近邻放大，作为 README 预览图
	image.resize(image.get_width() * 4, image.get_height() * 4, Image.INTERPOLATE_NEAREST)
	var error := image.save_png(path)
	print("saved ", path, " error=", error)
