class_name SaveSystem
extends RefCounted
## 本地 JSON 存档（单机，不使用数据库）。
##
## 按《个人单机开发要求》实现：
##   - 显式 save_version + 逐级迁移
##   - 3 个存档槽 save01/02/03.json，各自独立 .bak.json
##   - 写档走「临时文件 → 备份旧档 → 重命名」，绝不直接覆盖
##   - 读档失败回退 bak，再失败返回空档并提示
##
## 存档只放动态状态：日期、天气、钱、体力、地块、动物/宠物实例、背包、图鉴；
## 绝不写入 crops.json / animals.json / fishes.json 这类只读配置表。

const SAVE_VERSION := 5
const SLOT_COUNT := 3
const SAVE_DIR := "user://"
const SAVE_PREFIX := "save"
const TEMP_SUFFIX := ".tmp.json"
const BACKUP_SUFFIX := ".bak.json"

## 兼容旧代码的默认路径（= 1 号槽）。
const SAVE_PATH := "user://save01.json"
const BACKUP_PATH := "user://save01.bak.json"
const TEMP_PATH := "user://save01.tmp.json"

static var _current_slot := 1
static var _warned := false


# ------------------------------------------------------------
# 槽位
# ------------------------------------------------------------

static func set_slot(slot: int) -> void:
	_current_slot = clampi(slot, 1, SLOT_COUNT)


static func get_slot() -> int:
	return _current_slot


static func slot_path(slot: int) -> String:
	return "%s%s%02d.json" % [SAVE_DIR, SAVE_PREFIX, clampi(slot, 1, SLOT_COUNT)]


static func slot_backup_path(slot: int) -> String:
	return "%s%s%02d%s" % [SAVE_DIR, SAVE_PREFIX, clampi(slot, 1, SLOT_COUNT), BACKUP_SUFFIX]


static func slot_temp_path(slot: int) -> String:
	return "%s%s%02d%s" % [SAVE_DIR, SAVE_PREFIX, clampi(slot, 1, SLOT_COUNT), TEMP_SUFFIX]


static func slot_thumb_path(slot: int) -> String:
	return "%ssave%02d_thumb.png" % [SAVE_DIR, clampi(slot, 1, SLOT_COUNT)]


## 保存存档缩略图（统一缩放到 160×90，最近邻）。
static func save_thumbnail(slot: int, image: Image) -> void:
	if image == null or image.is_empty():
		return
	var copy := image.duplicate()
	if copy.get_width() != 160 or copy.get_height() != 90:
		copy.resize(160, 90, Image.INTERPOLATE_NEAREST)
	copy.save_png(slot_thumb_path(slot))


static func load_thumbnail(slot: int) -> Texture2D:
	var path := slot_thumb_path(slot)
	if not FileAccess.file_exists(path):
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


static func get_save_path() -> String:
	return slot_path(_current_slot)


# ------------------------------------------------------------
# 写入 / 读取
# ------------------------------------------------------------

static func save_data(data: Dictionary, slot := -1) -> bool:
	var use_slot := _current_slot if slot < 0 else clampi(slot, 1, SLOT_COUNT)
	var payload := data.duplicate(true)
	payload["save_version"] = SAVE_VERSION
	payload["saved_at"] = Time.get_datetime_string_from_system(false, true)
	if not payload.has("created_at") or str(payload.get("created_at", "")).is_empty():
		payload["created_at"] = payload["saved_at"]
	if not payload.has("play_time_seconds"):
		payload["play_time_seconds"] = 0.0

	var text := JSON.stringify(payload, "\t", false, true)

	# 1) 写临时文件
	var temp_path := slot_temp_path(use_slot)
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		_warn("无法写入临时存档：%s（错误码 %d）" % [temp_path, FileAccess.get_open_error()])
		return false
	file.store_string(text)
	file.flush()
	file.close()

	# 2) 校验临时文件能解析，避免写坏后覆盖好档
	if _read_dictionary(temp_path).is_empty():
		_warn("临时存档校验失败，保留旧存档。")
		_cleanup(temp_path)
		return false

	# 3) 备份现有主档
	_backup_existing(use_slot)

	# 4) 重命名（Windows 下已存在的目标会失败，先删）
	var save_path := slot_path(use_slot)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)

	if DirAccess.rename_absolute(temp_path, save_path) == OK:
		return true

	# 兜底：直接写主档
	_cleanup(temp_path)
	var fallback := FileAccess.open(save_path, FileAccess.WRITE)
	if fallback == null:
		_warn("无法写入主存档：%s" % save_path)
		return false
	fallback.store_string(text)
	fallback.flush()
	fallback.close()
	return true


static func load_data(slot := -1) -> Dictionary:
	var use_slot := _current_slot if slot < 0 else clampi(slot, 1, SLOT_COUNT)
	var data := _read_dictionary(slot_path(use_slot))
	var restored := false

	if data.is_empty():
		data = _read_dictionary(slot_backup_path(use_slot))
		restored = not data.is_empty()
		if restored:
			push_warning("[SaveSystem] 主存档不可用，已从备份恢复（槽 %d）。" % use_slot)

	if data.is_empty():
		return get_empty_save()

	var migrated := migrate(data)
	if restored:
		migrated["_restored_from_backup"] = true
	return migrated


static func has_save(slot := -1) -> bool:
	var use_slot := _current_slot if slot < 0 else clampi(slot, 1, SLOT_COUNT)
	return FileAccess.file_exists(slot_path(use_slot)) \
		or FileAccess.file_exists(slot_backup_path(use_slot))


static func delete_save(slot := -1) -> void:
	var use_slot := _current_slot if slot < 0 else clampi(slot, 1, SLOT_COUNT)
	for path: String in [
		slot_path(use_slot), slot_backup_path(use_slot),
		slot_temp_path(use_slot), slot_thumb_path(use_slot),
	]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## 槽位摘要，给存档界面显示：天数 / 季节 / 金钱 / 游玩时长 / 保存时间。
static func get_slot_summary(slot: int) -> Dictionary:
	var path := slot_path(slot)
	var exists := FileAccess.file_exists(path) or FileAccess.file_exists(slot_backup_path(slot))
	if not exists:
		return {"slot": slot, "exists": false}
	var data := _read_dictionary(path)
	if data.is_empty():
		data = _read_dictionary(slot_backup_path(slot))
	if data.is_empty():
		return {"slot": slot, "exists": false}
	var world: Dictionary = data.get("world", {})
	var player_data: Dictionary = data.get("player", {})
	return {
		"slot": slot,
		"exists": true,
		"player_name": str(player_data.get("name", "")),
		"farm_name": str(data.get("farm_name", "")),
		"day": int(world.get("day", data.get("day", 1))),
		"season": str(world.get("season", data.get("season", "spring"))),
		"year": int(world.get("year", data.get("year", 1))),
		"money": int(player_data.get("money", data.get("money", 0))),
		"play_time_seconds": float(data.get("play_time_seconds", 0.0)),
		"saved_at": str(data.get("saved_at", "")),
		"save_version": int(data.get("save_version", 1)),
	}


# ------------------------------------------------------------
# 导入 / 导出
# ------------------------------------------------------------

## 把某个槽位导出为独立 JSON 文件（含缩略图 Base64），便于备份/迁移。
static func export_slot(slot: int, path: String) -> bool:
	var use_slot := clampi(slot, 1, SLOT_COUNT)
	var data := _read_dictionary(slot_path(use_slot))
	if data.is_empty():
		data = _read_dictionary(slot_backup_path(use_slot))
	if data.is_empty():
		return false
	data = migrate(data)
	var bundle := {
		"farm_story_save": true,
		"export_version": 1,
		"exported_at": Time.get_datetime_string_from_system(false, true),
		"data": data,
	}
	var thumb_path := slot_thumb_path(use_slot)
	if FileAccess.file_exists(thumb_path):
		var thumb := FileAccess.get_file_as_bytes(thumb_path)
		if not thumb.is_empty():
			bundle["thumbnail_base64"] = Marshalls.raw_to_base64(thumb)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_warn("无法写入导出文件：%s（错误码 %d）" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(bundle, "\t", false, true))
	file.flush()
	file.close()
	return true


## 从独立 JSON 文件导入到目标槽，返回迁移后的存档；失败返回空字典。
static func import_slot(path: String, target_slot := -1) -> Dictionary:
	var use_slot := _current_slot if target_slot < 0 else clampi(target_slot, 1, SLOT_COUNT)
	if not FileAccess.file_exists(path):
		return {}
	var bundle := _read_dictionary(path)
	if bundle.is_empty():
		return {}
	var raw: Variant = bundle.get("data", bundle)
	if not (raw is Dictionary):
		return {}
	var data: Dictionary = (raw as Dictionary).duplicate(true)
	if data.is_empty():
		return {}
	if not data.has("save_version") and not data.has("player"):
		return {}
	var migrated := migrate(data)
	if not save_data(migrated, use_slot):
		return {}
	var thumb_b64 := str(bundle.get("thumbnail_base64", ""))
	if not thumb_b64.is_empty():
		var bytes := Marshalls.base64_to_raw(thumb_b64)
		if not bytes.is_empty():
			var image := Image.new()
			if image.load_png_from_buffer(bytes) == OK:
				image.save_png(slot_thumb_path(use_slot))
	return migrated


# ------------------------------------------------------------
# 版本迁移
# ------------------------------------------------------------

## 逐级补字段，不覆盖已有值。
static func migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("save_version", 1))

	if version < 2:
		if not data.has("play_time_seconds"):
			data["play_time_seconds"] = 0.0
		version = 2

	if version < 3:
		if not data.has("pet_list"):
			data["pet_list"] = []
		if not data.has("fishing_tools"):
			data["fishing_tools"] = {
				"crab_pots_placed": 0,
				"bait_equipped": "",
				"tackle_equipped": "",
				"crab_pot_inventory": {},
			}
		if not data.has("equipment"):
			data["equipment"] = {"tools": {}, "rod": "normal_rod", "bait": "", "tackle": ""}
		version = 3

	if version < 4:
		# 骑乘系统：旧档补空坐骑列表；马厩 / 鸵鸟舍 / 自行车棚由默认结构补齐。
		if not data.has("mounts") or not (data["mounts"] is Array):
			data["mounts"] = []
		var old_buildings: Variant = data.get("buildings", {})
		if old_buildings is Dictionary:
			for building_id: String in ["stable", "ostrich_house", "bike_shed"]:
				if not (old_buildings as Dictionary).has(building_id):
					(old_buildings as Dictionary)[building_id] = {
						"level": 0, "building": false, "days_left": 0,
					}
		version = 4

	if version < 5:
		# 宠物系统：旧档补 pets / pet_houses / pet_limits。
		if not data.has("pets") or not (data["pets"] is Array):
			data["pets"] = []
		if not data.has("pet_houses") or not (data["pet_houses"] is Array):
			data["pet_houses"] = []
		if not data.has("pet_limits") or not (data["pet_limits"] is Dictionary):
			data["pet_limits"] = {
				"max_pets": 12,
				"unlocked_by": ["initial", "first_expansion", "second_expansion"],
			}
		version = 5

	data["save_version"] = version

	# 用默认结构补齐缺失字段（已有值优先）。
	var merged := _deep_merge(get_empty_save(), data)
	merged["save_version"] = version
	return _sanitize(merged)


# ------------------------------------------------------------
# 默认存档结构
# ------------------------------------------------------------

static func get_empty_save() -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"created_at": "",
		"saved_at": "",
		"play_time_seconds": 0.0,

		# ---------- 玩家 ----------
		"player": {
			"name": "",
			"gender": "female",
			"appearance": {
				"hairstyle": "ponytail",
				"hair_color": "brown",
				"skin_color": "natural",
				"face_shape": "oval",
				"features": "round_eye_flat_brow",
				"outfit": "casual",
				"outfit_color": "blue",
				"accessories": {
					"head": "", "face": "", "neck": "", "hand": "", "back": "",
				},
			},
			"money": 500,
			"stamina": 100,
			"max_stamina": 100,
			"hp": 100,
			"max_hp": 100,
			"position": {"x": 0, "y": 0},
			"farm_map": "standard",
			"tools": {
				"hoe": {"level": "copper", "durability": 100},
				"watering_can": {"level": "copper", "capacity": 40},
				"axe": {"level": "copper"},
				"pickaxe": {"level": "copper"},
				"fishing_rod": {"level": "copper"},
			},
		},

		# ---------- 世界 ----------
		"world": {
			"day": 1,
			"season": "spring",
			"year": 1,
			"weather": "sunny",
			"tomorrow_weather": "sunny",
			"time_minutes": 360,
			"location": "farm",
			"time_paused": false,
			"wind": {"direction": "east", "strength": "medium"},
		},

		# ---------- 背包 ----------
		"inventory": {
			"capacity": 24,
			"items": [],
			"hotbar": [],
		},
		"equipment": {
			"tools": {},
			"rod": "normal_rod",
			"bait": "",
			"tackle": "",
		},

		# ---------- 农场 ----------
		"farm_tiles": [],
		"fruit_trees_planted": [],
		"animal_list": [],
		"pets": [],
		"pet_houses": [],
		"pet_limits": {
			"max_pets": 12,
			"unlocked_by": ["initial", "first_expansion", "second_expansion"],
		},
		"mounts": [],
		"shipping_bin": {"capacity": 30, "items": [], "pending_income": 0},

		# ---------- 建筑 / 室内 ----------
		"buildings": {
			"coop": {"level": 1, "building": false, "days_left": 0},
			"barn": {"level": 1, "building": false, "days_left": 0},
			"greenhouse": {"level": 0, "building": false, "days_left": 0},
			"worker_hut": {"level": 0, "building": false, "days_left": 0},
			"stable": {"level": 0, "building": false, "days_left": 0},
			"ostrich_house": {"level": 0, "building": false, "days_left": 0},
			"bike_shed": {"level": 0, "building": false, "days_left": 0},
		},
		"home": {
			"level": 1,
			"rooms": ["bedroom"],
			"home_storage": {"capacity": 30, "items": []},
			"mailbox": [],
			"bath_used_today": false,
			"books_read": [],
			"furniture": [],
			"special_display": {
				"fish_tank": [], "display_case": [], "gramophone": "", "calendar": true,
			},
		},
		"coop": {
			"level": 1, "capacity": 8, "feed_trough": 0,
			"incubator": null, "sick_pen": [], "animals": [],
		},
		"barn": {
			"level": 1, "capacity": 8, "feed_trough": 0,
			"milking_machine": true, "shearing_station": true,
			"sick_pen": [], "animals": [],
		},
		"greenhouse": {"size": 6, "heater_on": true, "fuel": 10, "tiles": []},
		"building": {},

		# ---------- 系统 ----------
		"apiary": {
			"hives": [],
			"products": {},
			"unlock_book": [],
		},
		"fishing_tools": {
			"crab_pots_placed": 0,
			"bait_equipped": "",
			"tackle_equipped": "",
			"crab_pot_inventory": {},
		},
		"mine": {
			"deepest_floor": 0,
			"collected_ores": {},
			"collected_gems": {},
			"donated_artifacts": [],
		},
		"museum_donations": [],
		"recipes_unlocked": [],
		"shops": {},

		# ---------- 社交 / 进度 ----------
		"npc_friendship": {},
		"npc_states": {},
		"quests": {"active": [], "completed": [], "daily_refreshed_day": 0},
		"events_seen": [],
		"festival_records": {},
		"workers": [],
		"spouse": "",
		"children": [],
		"unlock_book": {
			"crop": [], "animal": [], "fish": [], "pet": [],
			"fruit": [], "bee_product": [], "bird": [], "insect": [],
			"mineral": [], "artifact": [], "fossil": [], "percentage": {},
		},

		# ---------- 成长 ----------
		"skills": {
			"farming": {"level": 1, "exp": 0},
			"mining": {"level": 1, "exp": 0},
			"fishing": {"level": 1, "exp": 0},
			"foraging": {"level": 1, "exp": 0},
			"combat": {"level": 1, "exp": 0},
		},
		"achievements": [],
		"stats": {
			"play_time": 0,
			"crops_harvested": 0,
			"fish_caught": 0,
			"gifts_given": 0,
			"mines_cleared": 0,
			"total_earned": 0,
			"animals_bred": 0,
		},
		"tutorial_step": 0,
		"tutorial_completed": false,
		"accessories_owned": [],
		"accessories_equipped": {
			"head": "", "face": "", "neck": "", "hand": "", "back": "",
		},

		"settings": {
			"bgm_volume": 0.8,
			"sfx_volume": 0.8,
			"fullscreen": false,
		},
	}


# ------------------------------------------------------------
# 内部工具
# ------------------------------------------------------------

static func _read_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	if text.strip_edges().is_empty():
		return {}

	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("[SaveSystem] 存档解析失败：%s 第 %d 行：%s" % [
			path, json.get_error_line(), json.get_error_message(),
		])
		return {}
	if not (json.data is Dictionary):
		return {}
	return json.data


static func _sanitize(data: Dictionary) -> Dictionary:
	data["day"] = maxi(1, int(data.get("day", 1)))
	data["year"] = maxi(1, int(data.get("year", 1)))
	data["money"] = maxi(0, int(data.get("money", 0)))
	data["max_stamina"] = maxf(1.0, float(data.get("max_stamina", 100)))
	data["stamina"] = clampf(float(data.get("stamina", 100)), 0.0, float(data["max_stamina"]))
	data["time_minutes"] = clampi(int(data.get("time_minutes", 360)), 0, 1799)
	data["play_time_seconds"] = maxf(0.0, float(data.get("play_time_seconds", 0.0)))
	if not (str(data.get("season", "")) in ["spring", "summer", "autumn", "winter"]):
		data["season"] = "spring"
	if not (str(data.get("weather", "")) in ["sunny", "rain", "storm", "snow", "blizzard"]):
		data["weather"] = "sunny"
	if not (str(data.get("farm_map", "")) in ["standard", "river", "forest", "mountain", "wilderness"]):
		data["farm_map"] = "standard"

	for key: String in [
		"farm_tiles", "animal_list", "pet_list", "pets", "pet_houses", "inventory",
		"fruit_trees_planted", "recipes_unlocked",
	]:
		if not (data.get(key) is Array):
			data[key] = []
	return data


static func _deep_merge(defaults: Dictionary, loaded: Dictionary) -> Dictionary:
	var result := defaults.duplicate(true)
	for key: Variant in loaded.keys():
		var value: Variant = loaded[key]
		if result.has(key) and result[key] is Dictionary and value is Dictionary:
			result[key] = _deep_merge(result[key], value)
		else:
			result[key] = value
	return result


static func _backup_existing(slot: int) -> void:
	var source_path := slot_path(slot)
	if not FileAccess.file_exists(source_path):
		return
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return
	var text := source.get_as_text()
	source.close()

	# 旧主档损坏时不要覆盖掉上一次的好备份
	var probe := JSON.new()
	if probe.parse(text) != OK:
		push_warning("[SaveSystem] 旧主存档无法解析，保留现有备份不覆盖。")
		return

	var backup := FileAccess.open(slot_backup_path(slot), FileAccess.WRITE)
	if backup == null:
		push_warning("[SaveSystem] 无法写入备份存档。")
		return
	backup.store_string(text)
	backup.flush()
	backup.close()


static func _cleanup(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _warn(message: String) -> void:
	push_error("[SaveSystem] " + message)
	if not _warned:
		_warned = true
