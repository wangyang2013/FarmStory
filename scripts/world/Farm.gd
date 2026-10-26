class_name Farm
extends Node2D
## 正式农场场景：地图、玩家、时间、背包、商店、出货箱、钓鱼。
##
## 玩法循环：锄地 → 播种 → 浇水 → 过夜生长 → 收获 → 卖出 → 买种子。
## 所有数值来自 config/*.json；本文件只写关卡布局与流程。

const DB := preload("res://scripts/core/ConfigDB.gd")
const Save := preload("res://scripts/core/SaveSystem.gd")
const FarmTileScript := preload("res://scripts/farm/FarmTile.gd")
const PlayerScript := preload("res://scripts/player/Player.gd")
const AnimalScript := preload("res://scripts/farm/Animal.gd")
const PetScript := preload("res://scripts/farm/Pet.gd")
const FruitTreeScript := preload("res://scripts/farm/FruitTree.gd")
const BeeHiveScript := preload("res://scripts/farm/BeeHive.gd")
const MachineScript := preload("res://scripts/farm/Machine.gd")
const MonsterScript := preload("res://scripts/mine/Monster.gd")
const MineTrapScript := preload("res://scripts/mine/MineTrap.gd")
const SlashScript := preload("res://scripts/mine/SlashEffect.gd")
const NPCScript := preload("res://scripts/npc/NPC.gd")
const MineFloorScript := preload("res://scripts/world/MineFloor.gd")
const WorldPropScript := preload("res://scripts/world/WorldProp.gd")
const GroundTileMapScript := preload("res://scripts/world/GroundTileMap.gd")
const GameUIScript := preload("res://scripts/ui/GameUI.gd")
const CharacterCreatorScript := preload("res://scripts/ui/CharacterCreator.gd")
const Anim := preload("res://scripts/art/ActionAnimator.gd")
const DebugPanelScript := preload("res://scripts/ui/DebugPanel.gd")
const TutorialScript := preload("res://scripts/core/TutorialManager.gd")
const HouseInteriorScript := preload("res://scripts/world/HouseInterior.gd")
const BuildingInteriorScript := preload("res://scripts/world/BuildingInterior.gd")
const InteriorPropScript := preload("res://scripts/world/InteriorProp.gd")
const MountScript := preload("res://scripts/world/Mount.gd")
const PetHouseScript := preload("res://scripts/world/PetHouse.gd")
const WildCritterScript := preload("res://scripts/world/WildCritter.gd")
const FarmSignScript := preload("res://scripts/world/FarmSign.gd")
const WeatherSystemScript := preload("res://scripts/world/WeatherSystem.gd")
const AmbientParticlesScript := preload("res://scripts/world/AmbientParticles.gd")
const BridgeScript := preload("res://scripts/world/Bridge.gd")
const HotSpringScript := preload("res://scripts/world/HotSpring.gd")
const Art := preload("res://scripts/art/PixelArt.gd")
const MapEntityScript := preload("res://scripts/map/MapEntity.gd")
const PickupBurstScript := preload("res://scripts/fx/PickupBurst.gd")
const BathEffectScript := preload("res://scripts/fx/BathEffect.gd")
const FruitDropScript := preload("res://scripts/fx/FruitDrop.gd")
const WoodChipsScript := preload("res://scripts/fx/WoodChips.gd")
const MineLightScript := preload("res://scripts/mine/MineLight.gd")
const FestivalFxScript := preload("res://scripts/fx/FestivalFx.gd")
const GroundItemScript := preload("res://scripts/farm/GroundItem.gd")
const MapUIScene := preload("res://scenes/MapUI.tscn")

const TILE := 32
# 大地图：分区参考「左上矿洞/博物馆 · 中上种植区 · 右上主屋/商店 ·
# 中央广场 · 中下畜牧区 · 右下捕鱼池 · 左下养鱼池」
const WORLD_W := 64
const WORLD_H := 48

const FARM_ORIGIN := Vector2i(24, 7)
const FARM_SIZE := Vector2i(18, 10)

# 主池塘（右下捕鱼区） / 小池塘（左下养鱼区）
const POND_RECT := Rect2i(46, 32, 13, 9)
const SMALL_POND_RECT := Rect2i(6, 28, 7, 5)

# 河流：左侧纵向 + 底部横向，主路处架木桥
const RIVER_LEFT := Rect2i(0, 0, 4, 48)
const RIVER_BOTTOM := Rect2i(0, 44, 64, 4)
const BRIDGE_LEFT := Rect2i(0, 20, 4, 2)

const SPAWN := Vector2(47.0 * TILE, 14.8 * TILE)

# 主屋区（右上）
const HOUSE_BASE := Vector2(48.5 * TILE, 12.5 * TILE)
const SHOP_BASE := Vector2(55.0 * TILE, 9.5 * TILE)
const BIN_BASE := Vector2(51.8 * TILE, 14.6 * TILE)
const BED_POINT := Vector2(HOUSE_BASE.x, HOUSE_BASE.y + 14.0)
const SHOP_POINT := Vector2(SHOP_BASE.x, SHOP_BASE.y + 16.0)
const BIN_POINT := Vector2(BIN_BASE.x, BIN_BASE.y + 12.0)

# 畜牧区（中下）：栅栏范围 + 鸡舍 / 畜棚 + 各自食槽
const PASTURE := Rect2(22.0 * TILE, 27.0 * TILE, 20.0 * TILE, 13.0 * TILE)
const COOP_BASE := Vector2(26.5 * TILE, 31.0 * TILE)
const BARN_BASE := Vector2(35.0 * TILE, 31.0 * TILE)
const COOP_TROUGH := Vector2(24.5 * TILE, 30.0 * TILE)
const BARN_TROUGH := Vector2(33.0 * TILE, 30.0 * TILE)
const COOP_POINT := Vector2(COOP_TROUGH.x, COOP_TROUGH.y + 12.0)
const BARN_POINT := Vector2(BARN_TROUGH.x, BARN_TROUGH.y + 12.0)
const COOP_DOOR_POINT := Vector2(COOP_BASE.x + 26.0, COOP_BASE.y + 6.0)
const BARN_DOOR_POINT := Vector2(BARN_BASE.x + 30.0, BARN_BASE.y + 6.0)

# 镜子：随时修改角色外观（主屋左侧）
const MIRROR_BASE := Vector2(43.5 * TILE, 14.5 * TILE)
const MIRROR_POINT := Vector2(MIRROR_BASE.x, MIRROR_BASE.y + 6.0)

# 邮箱：主屋门前
const MAILBOX_BASE := Vector2(45.2 * TILE, 14.8 * TILE)
const MAILBOX_POINT := Vector2(MAILBOX_BASE.x, MAILBOX_BASE.y + 8.0)

# 宠物小屋：主屋两侧（买狗/猫后出现）
const DOG_HOUSE_BASE := Vector2(44.6 * TILE, 16.6 * TILE)
const CAT_HOUSE_BASE := Vector2(54.4 * TILE, 16.6 * TILE)

# 温泉：左下休闲区
const HOT_SPRING_BASE := Vector2(17.0 * TILE, 32.0 * TILE)
const HOT_SPRING_POINT := Vector2(HOT_SPRING_BASE.x, HOT_SPRING_BASE.y + 14.0)

# 图书馆 / 诊所：主路北侧
const LIBRARY_BASE := Vector2(7.0 * TILE, 19.0 * TILE)
const LIBRARY_POINT := Vector2(LIBRARY_BASE.x, LIBRARY_BASE.y + 16.0)
const CLINIC_BASE := Vector2(13.0 * TILE, 19.0 * TILE)
const CLINIC_POINT := Vector2(CLINIC_BASE.x, CLINIC_BASE.y + 16.0)

# 工人小屋：牧场门外
const WORKER_HUT_BASE := Vector2(24.0 * TILE, 25.8 * TILE)
const WORKER_HUT_POINT := Vector2(WORKER_HUT_BASE.x, WORKER_HUT_BASE.y + 10.0)

# 马厩 / 鸵鸟舍 / 自行车棚：主屋与池塘之间的空地（4×3 / 4×3 / 3×2）
const STABLE_BASE := Vector2(47.5 * TILE, 28.0 * TILE)
const OSTRICH_HOUSE_BASE := Vector2(52.5 * TILE, 28.0 * TILE)
const BIKE_SHED_BASE := Vector2(57.5 * TILE, 28.0 * TILE)
const STABLE_POINT := Vector2(STABLE_BASE.x, STABLE_BASE.y + 22.0)
const OSTRICH_HOUSE_POINT := Vector2(OSTRICH_HOUSE_BASE.x, OSTRICH_HOUSE_BASE.y + 22.0)
const BIKE_SHED_POINT := Vector2(BIKE_SHED_BASE.x, BIKE_SHED_BASE.y + 22.0)
# 牧场名牌：主屋左侧草地
const FARM_SIGN_BASE := Vector2(44.8 * TILE, 13.2 * TILE)

const STABLE_PARK := Vector2(STABLE_BASE.x, STABLE_BASE.y + 16.0)
const OSTRICH_HOUSE_PARK := Vector2(OSTRICH_HOUSE_BASE.x, OSTRICH_HOUSE_BASE.y + 16.0)
const BIKE_SHED_PARK := Vector2(BIKE_SHED_BASE.x, BIKE_SHED_BASE.y + 14.0)
const BARN_PARK := Vector2(BARN_DOOR_POINT.x - 30.0, BARN_DOOR_POINT.y + 18.0)

# 中央广场：公告板 / NPC / 节日
const NOTICE_BOARD_BASE := Vector2(30.0 * TILE, 19.6 * TILE)
const NOTICE_BOARD_POINT := Vector2(NOTICE_BOARD_BASE.x, NOTICE_BOARD_BASE.y + 18.0)
const FESTIVAL_POINT := Vector2(30.0 * TILE, 20.6 * TILE)

# 矿洞入口（左上）
const MINE_ENTRANCE_BASE := Vector2(19.0 * TILE, 8.0 * TILE)
const MINE_ENTRANCE_POINT := Vector2(MINE_ENTRANCE_BASE.x, MINE_ENTRANCE_BASE.y + 14.0)

# 博物馆（左上，矿洞左侧）
const MUSEUM_BASE := Vector2(10.0 * TILE, 10.5 * TILE)
const MUSEUM_POINT := Vector2(MUSEUM_BASE.x, MUSEUM_BASE.y + 20.0)

# 画面缩放：默认 0.75 视野更大（约 20×11 格），= / - 调节
const CAMERA_ZOOM_STEPS := [0.5, 0.625, 0.75, 1.0, 1.25, 1.5]
const DEFAULT_CAMERA_ZOOM_INDEX := 2

var time: TimeSystem
var player: Player
var inventory: Inventory
var ui: GameUI
var camera: Camera2D
var camera_zoom_index := DEFAULT_CAMERA_ZOOM_INDEX
var map_ui
var mine_monsters: Array = []
var mine_traps: Array = []
var _attack_cooldown := 0.0
var npcs: Array = []
var festivals_done: Array = []
var _npc_timer := 0.0
var home_level := 1
var bath_used_today := false
var quests_active: Array = []
var quests_completed: Array = []
var quest_last_day := -1
var buildings_state: Dictionary = {}
var spouse_id := ""
var _quest_serial := 0
var day_light: CanvasModulate

var money := 500
var selected_index := 0
var unlock_book: Dictionary = {}
var museum_donations: Array[String] = []
var home_storage: Array = []
var fridge_storage: Array = []
var mail_pending: Array[String] = []
var mail_read: Array[String] = []
var cellar_items: Array = []
var _mailbox_prop: WorldProp
var _dog_house_prop: WorldProp
var _cat_house_prop: WorldProp
var _pond_cells: Array[Vector2i] = []
var _slash_pool: ObjectPool
var _fishing_cast := false
var fishing_cast_time := 0.7
var _mine_light: MineLight
var _last_thumbnail: Image
var _thumb_timer := 3.0
var accessories_owned: Array = []
var accessories_equipped: Dictionary = {"head": "", "face": "", "neck": "", "hand": "", "back": ""}
var total_earned := 0
var crops_harvested := 0
var fish_caught := 0
var ore_mined := 0
var days_played := 0
var achievements_unlocked: Array[String] = []
var hot_spring_used_today := false
var books_read: Array[String] = []
var last_book_day := -1
var clinic_treated_today := false
var hired_worker := false
## 室内家具：[{"id": "furn_rug", "gx": 3, "gy": 5}]（房间格坐标）
var placed_furniture: Array = []

var farm_tiles: Dictionary = {}
var animals: Array = []
var pets: Array = []
## 宠物栖息地实例：[{id, type, x, y, location, level, name, occupants, cleanliness, decorations}]
var pet_houses: Array = []
var _pet_house_nodes: Dictionary = {}
var _pet_serial := 0
var _pet_house_serial := 0
var _placing_pet_house_id := ""
var _indoor_pet_positions: Dictionary = {}
var _dog_chase_cooldown := 0.0
var wild_critters: Array = []
var _wild_spawn_timer := 12.0

var player_name := "农夫"
var farm_name := "阳光牧场"
var _farm_sign: FarmSign = null
var fruit_trees: Array = []
var beehives: Array = []
var machines: Array = []
var in_mine := false
var mine_floor_num := 1
var mine_floor: MineFloor
var mine_deepest := 0
var mine_ores: Dictionary = {}
var mine_gems: Dictionary = {}
var mine_outdoor_position := Vector2.ZERO
var _mine_root: Node2D
var building_fed: Dictionary = {"coop": false, "barn": false}
var props: Array = []
var _ground: GroundTileMap
var _terrain := PackedByteArray()
var _walls: StaticBody2D
var _hud_timer := 0.0
var _transitioning := false
var _started := false
var play_time := 0.0
## 工具输入缓冲：连按不丢输入（开发要求 7.5）。
var _input_buffer := 0.0
const INPUT_BUFFER_TIME := 0.15
var _buffered_tile := Vector2i(-1, -1)
var debug_draw_collision := false
var debug_panel: DebugPanel
var weather_fx: WeatherSystem
var tutorial: TutorialManager
var _tutorial_move_distance := 0.0
var _last_player_position := Vector2.ZERO
var indoor := false
## 当前所在建筑（空 = 自宅 / 室外）
var current_building := ""
var _building_interior: BuildingInterior
var _building_props: Array[InteriorProp] = []
var _house_props: Array[InteriorProp] = []

# ---------- 坐骑 ----------
## 坐骑数据（马 / 自行车；牛直接引用 animal_list 里的牛）。
var mounts: Array = []
## id -> RideMount 节点
var mount_nodes: Dictionary = {}
var riding_mount: RideMount = null
var riding_animal: FarmAnimal = null
var riding_mount_id := ""
var _bike_sprint_cd := 0.0
var _bike_sprint_used := false
var _stable_prop: WorldProp = null
var _ostrich_house_prop: WorldProp = null
var _bike_shed_prop: WorldProp = null
var _stable_scaffold_prop: WorldProp = null
var _ostrich_house_scaffold_prop: WorldProp = null
var _bike_shed_scaffold_prop: WorldProp = null
var _mount_walls: StaticBody2D = null
var _interior: HouseInterior
var _outdoor_position := SPAWN
var _saved_camera_limits := Rect2i()


func _ready() -> void:
	y_sort_enabled = true
	# 关闭窗口时自己处理保存，避免最后一次睡觉之后的进度丢失。
	get_tree().auto_accept_quit = false
	_build_player()
	_build_time()
	_build_inventory()
	_build_walls()
	_build_ground()
	_build_water_overlay()
	_build_props()
	_build_map_entities()
	_build_npcs()
	_setup_buildings()
	_build_farm_tiles()
	_build_interior()
	_build_camera()
	_build_day_light()
	_build_weather_layer()
	_build_ambient_particles()
	_build_ui()
	_build_map_ui()
	_build_tutorial()
	_build_debug_panel()
	_build_object_pools()
	_start_or_load()
	_refresh_mount_buildings()
	_build_mount_nodes()
	_started = true
	queue_redraw()


# ============================================================
# 构建
# ============================================================

func _build_player() -> void:
	player = PlayerScript.new()
	player.position = SPAWN
	player.stamina_changed.connect(_on_stamina_changed)
	player.exhausted.connect(_on_player_exhausted)
	player.fainted.connect(_on_player_fainted)
	add_child(player)


func _build_time() -> void:
	time = TimeSystem.new()
	add_child(time)
	time.day_started.connect(_on_day_started)
	time.late_night.connect(_on_late_night)


func _build_inventory() -> void:
	inventory = Inventory.new()
	inventory.changed.connect(_on_inventory_changed)


func _build_walls() -> void:
	_walls = StaticBody2D.new()
	_walls.name = "Walls"
	add_child(_walls)

	# 世界边界
	_add_wall(Rect2(-64, -64, WORLD_W * TILE + 128, 64))
	_add_wall(Rect2(-64, WORLD_H * TILE, WORLD_W * TILE + 128, 64))
	_add_wall(Rect2(-64, -64, 64, WORLD_H * TILE + 128))
	_add_wall(Rect2(WORLD_W * TILE, -64, 64, WORLD_H * TILE + 128))

	# 池塘碰撞在 _build_ground 生成水面后按实际水格补上（见 _build_pond_walls）。

	# 建筑按“底边占位”碰撞：上方可走到建筑后方，触发 FadeWhenBehind
	_add_wall(Rect2(HOUSE_BASE.x - 48, HOUSE_BASE.y - 30, 96, 30))
	_add_wall(Rect2(SHOP_BASE.x - 40, SHOP_BASE.y - 24, 80, 24))
	_add_wall(Rect2(MUSEUM_BASE.x - 108, MUSEUM_BASE.y - 56, 216, 56))
	_add_wall(Rect2(LIBRARY_BASE.x - 40, LIBRARY_BASE.y - 26, 80, 26))
	_add_wall(Rect2(CLINIC_BASE.x - 40, CLINIC_BASE.y - 24, 80, 24))
	_add_wall(Rect2(BIN_BASE.x - 20, BIN_BASE.y - 40, 40, 40))

	# 鸡舍 / 畜棚（6×3 / 7×4 的底边占位）
	_add_wall(Rect2(COOP_BASE.x - 48, COOP_BASE.y - 24, 96, 24))
	_add_wall(Rect2(BARN_BASE.x - 56, BARN_BASE.y - 26, 112, 26))
	# 食槽
	_add_wall(Rect2(COOP_TROUGH.x - 22, COOP_TROUGH.y - 20, 44, 18))
	_add_wall(Rect2(BARN_TROUGH.x - 22, BARN_TROUGH.y - 20, 44, 18))


func _add_wall(rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.position + rect.size * 0.5
	_walls.add_child(shape)


## 地面：16px 图块 + TileMapLayer（矩形网格，斜 45° 伪俯视）
func _build_ground() -> void:
	_terrain.resize(WORLD_W * WORLD_H)
	for ty in WORLD_H:
		for tx in WORLD_W:
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.GRASS

	# 池塘（主池 + 小池）：沙岸 + 椭圆噪声边缘
	_pond_cells.clear()
	_paint_pond(POND_RECT, 17)
	_paint_pond(SMALL_POND_RECT, 41)
	_paint_rivers()

	# —— 金色土路网 ——
	# 主路：横贯全图（左端从桥面之后开始）
	for ty in [20, 21]:
		for tx in range(4, 62):
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.PATH
	# 中央广场（公告板 / NPC / 节日）
	for ty in range(19, 24):
		for tx in range(26, 37):
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.PATH
	# 种植区环路
	for tx in range(23, 43):
		_terrain[6 * WORLD_W + tx] = GroundTileMapScript.PATH
		_terrain[18 * WORLD_W + tx] = GroundTileMapScript.PATH
	for ty in range(6, 19):
		_terrain[ty * WORLD_W + 23] = GroundTileMapScript.PATH
		_terrain[ty * WORLD_W + 42] = GroundTileMapScript.PATH
	# 主屋 / 商店 / 博物馆 / 矿洞支路
	for ty in range(13, 21):
		for tx in [47, 48]:
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.PATH
	for ty in range(10, 21):
		for tx in [55, 56]:
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.PATH
	for ty in range(11, 21):
		for tx in [9, 10]:
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.PATH
	for ty in range(9, 21):
		for tx in [18, 19]:
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.PATH
	# 广场 → 牧场门
	for ty in range(22, 27):
		for tx in [26, 27, 28]:
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.PATH
	# 种植区 → 主路
	for ty in range(18, 21):
		for tx in [31, 32]:
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.PATH
	# 主路 → 捕鱼池 / 池边步道
	for ty in range(22, 32):
		for tx in [50, 51]:
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.PATH
	for tx in range(45, 60):
		_terrain[31 * WORLD_W + tx] = GroundTileMapScript.PATH
	for ty in range(31, 43):
		_terrain[ty * WORLD_W + 45] = GroundTileMapScript.PATH
		_terrain[ty * WORLD_W + 59] = GroundTileMapScript.PATH
	# 主路 → 左下养鱼池
	for ty in range(22, 27):
		for tx in [4, 5]:
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.PATH
	for tx in range(4, 14):
		_terrain[26 * WORLD_W + tx] = GroundTileMapScript.PATH
	for tx in range(5, 14):
		_terrain[34 * WORLD_W + tx] = GroundTileMapScript.PATH

	# 牧场铺土：动物活动区是暖金色干土，留少量草块（参考牧场图）
	var px0 := int(PASTURE.position.x / TILE)
	var py0 := int(PASTURE.position.y / TILE)
	var px1 := int(PASTURE.end.x / TILE)
	var py1 := int(PASTURE.end.y / TILE)
	for ty in range(py0 + 1, py1):
		for tx in range(px0 + 1, px1):
			if (tx * 13 + ty * 7) % 11 == 0:
				continue
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.PATH

	_ground = GroundTileMapScript.new()
	_ground.name = "Ground"
	_ground.z_index = -10
	add_child(_ground)
	_ground.setup(WORLD_W, WORLD_H)
	_ground.paint(_terrain, WORLD_W, WORLD_H, time.season if time != null else "spring")
	_build_pond_walls()


## 河流：左侧纵向 + 底部横向；主路经过的桥面保留水底但不加碰撞。
func _paint_rivers() -> void:
	for y in RIVER_LEFT.size.y:
		for x in RIVER_LEFT.size.x:
			_terrain[y * WORLD_W + x] = GroundTileMapScript.WATER
			var on_bridge := y >= BRIDGE_LEFT.position.y \
				and y < BRIDGE_LEFT.end.y \
				and x >= BRIDGE_LEFT.position.x and x < BRIDGE_LEFT.end.x
			if not on_bridge:
				_pond_cells.append(Vector2i(x, y))
	for y in range(RIVER_BOTTOM.position.y, RIVER_BOTTOM.end.y):
		for x in RIVER_BOTTOM.size.x:
			_terrain[y * WORLD_W + x] = GroundTileMapScript.WATER
			_pond_cells.append(Vector2i(x, y))
	# 河岸：左侧一格 + 底部一格沙地（后续土路会覆盖交叉处）
	for y in range(0, RIVER_BOTTOM.position.y):
		_terrain[y * WORLD_W + RIVER_LEFT.end.x] = GroundTileMapScript.SAND
	for x in range(RIVER_LEFT.end.x, WORLD_W):
		_terrain[(RIVER_BOTTOM.position.y - 1) * WORLD_W + x] = GroundTileMapScript.SAND


## 绘制一个有机池塘：先铺沙岸，再按椭圆 + 噪声写水格。
func _paint_pond(rect: Rect2i, salt: int) -> void:
	for ty in range(rect.position.y - 1, rect.position.y + rect.size.y + 1):
		for tx in range(rect.position.x - 1, rect.position.x + rect.size.x + 1):
			if tx < 0 or ty < 0 or tx >= WORLD_W or ty >= WORLD_H:
				continue
			_terrain[ty * WORLD_W + tx] = GroundTileMapScript.SAND
	var center := Vector2(rect.position) + Vector2(rect.size) * 0.5
	var rx := float(rect.size.x) * 0.5
	var ry := float(rect.size.y) * 0.5
	for ty in range(rect.position.y, rect.position.y + rect.size.y):
		for tx in range(rect.position.x, rect.position.x + rect.size.x):
			var nx := (float(tx) + 0.5 - center.x) / rx
			var ny := (float(ty) + 0.5 - center.y) / ry
			var wobble := float((tx * 17 + ty * 31 + salt * 13) % 7) * 0.035
			if nx * nx + ny * ny <= 0.90 + wobble:
				_terrain[ty * WORLD_W + tx] = GroundTileMapScript.WATER
				_pond_cells.append(Vector2i(tx, ty))


## 按实际水格逐行生成池塘碰撞，避免木箱式矩形水面的隐形墙。
func _build_pond_walls() -> void:
	# 按“同一行内的连续水格段”生成碰撞：多个池塘不会连成横跨全图的墙。
	var rows: Dictionary = {}
	for cell: Vector2i in _pond_cells:
		if not rows.has(cell.y):
			rows[cell.y] = []
		var xs: Array = rows[cell.y]
		xs.append(cell.x)
	for raw_row: Variant in rows.keys():
		var row := int(raw_row)
		var xs: Array = rows[raw_row]
		xs.sort()
		var start := int(xs[0])
		var prev := start
		for index in range(1, xs.size()):
			var x := int(xs[index])
			if x == prev + 1:
				prev = x
				continue
			_add_wall(Rect2(start * TILE, row * TILE, (prev - start + 1) * TILE, TILE))
			start = x
			prev = x
		_add_wall(Rect2(start * TILE, row * TILE, (prev - start + 1) * TILE, TILE))


func _build_props() -> void:
	_add_prop("house", HOUSE_BASE)
	_add_prop("shop", SHOP_BASE)
	_add_prop("museum", MUSEUM_BASE)
	_add_prop("library", LIBRARY_BASE)
	_add_prop("clinic", CLINIC_BASE)
	_add_prop("worker_hut", WORKER_HUT_BASE)
	_add_wall(Rect2(WORKER_HUT_BASE.x - 24, WORKER_HUT_BASE.y - 22, 48, 22))
	_add_prop("bin", BIN_BASE)
	_add_prop("sign", NOTICE_BOARD_BASE)
	_farm_sign = FarmSignScript.new()
	_farm_sign.name = "FarmSign"
	add_child(_farm_sign)
	_farm_sign.setup(FARM_SIGN_BASE, farm_name)
	_add_prop("mirror", MIRROR_BASE)
	_mailbox_prop = _add_prop("mailbox", MAILBOX_BASE)
	_add_wall(Rect2(MAILBOX_BASE.x - 7, MAILBOX_BASE.y - 10, 14, 10))

	# 宠物小屋（默认隐藏，买狗/猫后显示）
	# 旧的狗屋/猫屋由 PetHouse 统一绘制，这里保留占位但不再显示。
	_dog_house_prop = _add_prop("dog_house", DOG_HOUSE_BASE)
	_dog_house_prop.visible = false
	_cat_house_prop = _add_prop("cat_house", CAT_HOUSE_BASE)
	_cat_house_prop.visible = false
	_add_wall(Rect2(DOG_HOUSE_BASE.x - 15, DOG_HOUSE_BASE.y - 12, 30, 12))
	_add_wall(Rect2(CAT_HOUSE_BASE.x - 14, CAT_HOUSE_BASE.y - 12, 28, 12))

	# 温泉
	var hot_spring := HotSpringScript.new()
	hot_spring.name = "HotSpring"
	hot_spring.position = HOT_SPRING_BASE
	add_child(hot_spring)
	_add_wall(Rect2(HOT_SPRING_BASE.x - 72, HOT_SPRING_BASE.y - 72, 144, 72))

	# 左侧河流上的木桥（主路跨河处）
	var bridge := BridgeScript.new()
	bridge.name = "Bridge"
	add_child(bridge)
	bridge.setup(Rect2(
		Vector2(BRIDGE_LEFT.position) * TILE,
		Vector2(BRIDGE_LEFT.size) * TILE
	))

	# 矿洞入口（用一块大石头表示）
	_add_prop("rock", MINE_ENTRANCE_BASE)
	_add_wall(Rect2(MINE_ENTRANCE_BASE.x - 18, MINE_ENTRANCE_BASE.y - 16, 36, 16))

	# 牧场
	_add_prop("coop", COOP_BASE)
	_add_prop("barn", BARN_BASE)
	_add_prop("trough", COOP_TROUGH)
	_add_prop("trough", BARN_TROUGH)
	_build_pasture_fence()

	# 坐骑建筑（默认隐藏，建造完成后显示）
	_stable_prop = _add_prop("stable", STABLE_BASE)
	_ostrich_house_prop = _add_prop("ostrich_house", OSTRICH_HOUSE_BASE)
	_bike_shed_prop = _add_prop("bike_shed", BIKE_SHED_BASE)
	_stable_scaffold_prop = _add_prop("scaffold", STABLE_BASE)
	_ostrich_house_scaffold_prop = _add_prop("scaffold", OSTRICH_HOUSE_BASE)
	_bike_shed_scaffold_prop = _add_prop("scaffold_small", BIKE_SHED_BASE)
	_stable_scaffold_prop.visible = false
	_ostrich_house_scaffold_prop.visible = false
	_bike_shed_scaffold_prop.visible = false

	# 这里的位置和碰撞是关卡设计，不是数值配置。
	# 64×48 大地图：边缘密林 + 分区之间的树木/灌木过渡。
	var trees := [
		# 北侧边缘
		Vector2(4.0, 1.5), Vector2(10.0, 2.0), Vector2(16.0, 1.5), Vector2(22.0, 2.0),
		Vector2(28.0, 1.5), Vector2(34.0, 2.0), Vector2(40.0, 1.5), Vector2(46.0, 2.0),
		Vector2(52.0, 1.5), Vector2(58.0, 2.0),
		# 南侧边缘（河流北岸）
		Vector2(4.0, 42.0), Vector2(10.0, 42.0), Vector2(16.0, 42.0), Vector2(22.0, 42.0),
		Vector2(28.0, 42.0), Vector2(34.0, 42.0), Vector2(40.0, 42.0), Vector2(46.0, 42.0),
		Vector2(52.0, 42.0), Vector2(58.0, 42.0),
		# 西 / 东边缘
		Vector2(5.0, 6.0), Vector2(5.5, 12.0), Vector2(5.0, 19.0), Vector2(6.5, 26.0),
		Vector2(5.5, 35.0),
		Vector2(62.0, 6.0), Vector2(62.0, 12.0), Vector2(62.0, 18.0), Vector2(62.0, 25.0),
		Vector2(62.0, 33.0),
		# 矿洞 / 博物馆区
		Vector2(4.0, 8.0), Vector2(15.0, 6.0), Vector2(21.0, 10.0), Vector2(15.0, 14.0),
		Vector2(21.0, 16.0), Vector2(5.0, 16.0),
		# 种植区周边
		Vector2(22.0, 6.0), Vector2(43.0, 6.0), Vector2(43.0, 13.0),
		Vector2(22.0, 19.0), Vector2(24.5, 19.0), Vector2(41.5, 19.0),
		# 畜牧区周边
		Vector2(20.0, 28.0), Vector2(20.0, 36.0), Vector2(44.0, 28.0), Vector2(44.0, 36.0),
		Vector2(20.0, 40.0), Vector2(44.0, 40.0),
		# 主屋 / 商店周边
		Vector2(44.0, 10.0), Vector2(59.0, 6.0), Vector2(44.0, 16.0), Vector2(59.0, 17.0),
		# 左下养鱼区
		Vector2(5.5, 27.0), Vector2(14.0, 28.0), Vector2(5.5, 33.0), Vector2(15.0, 33.0),
	]
	for tile_position: Vector2 in trees:
		_add_tree(tile_position)

	# 粉色花树：参考图里的开花树，打破全绿
	for tile_position: Vector2 in [
		Vector2(28.0, 4.0), Vector2(37.0, 4.0), Vector2(15.0, 23.0),
		Vector2(48.0, 24.0), Vector2(8.0, 24.0), Vector2(30.0, 43.0),
		Vector2(53.0, 43.0), Vector2(6.5, 23.0), Vector2(61.0, 23.0),
		Vector2(5.0, 7.0),
	]:
		_add_blossom_tree(tile_position)

	# 灌木与花丛（无碰撞）：建筑边缘、路旁、池塘与牧场周围
	for tile_position: Vector2 in [
		Vector2(5.0, 12.0), Vector2(14.0, 12.0), Vector2(7.0, 15.0),
		Vector2(16.0, 15.0), Vector2(20.0, 12.0),
		Vector2(22.5, 8.0), Vector2(41.5, 8.0), Vector2(22.5, 17.0),
		Vector2(41.5, 17.0), Vector2(22.5, 5.0), Vector2(41.5, 5.0),
		Vector2(46.0, 14.5), Vector2(52.0, 15.0), Vector2(59.0, 10.0),
		Vector2(44.0, 11.0), Vector2(58.0, 15.0),
		Vector2(25.0, 19.0), Vector2(37.0, 19.0), Vector2(27.0, 24.0),
		Vector2(35.0, 24.0),
		Vector2(21.0, 27.0), Vector2(43.0, 27.0), Vector2(21.0, 34.0),
		Vector2(43.0, 34.0),
		Vector2(4.5, 27.5), Vector2(14.0, 27.5), Vector2(4.5, 32.5),
		Vector2(14.0, 32.5),
		Vector2(10.0, 42.0), Vector2(18.0, 42.0), Vector2(25.0, 41.0),
		Vector2(33.0, 41.0), Vector2(39.0, 43.0),
	]:
		_add_bush(tile_position)

	# 针叶树：与阔叶树混植，参考图的密林边缘
	for tile_position: Vector2 in [
		Vector2(7.0, 1.5), Vector2(13.0, 1.5), Vector2(19.0, 1.5), Vector2(25.0, 1.5),
		Vector2(31.0, 1.5), Vector2(37.0, 1.5), Vector2(43.0, 1.5), Vector2(49.0, 1.5),
		Vector2(55.0, 1.5), Vector2(61.0, 1.5),
		Vector2(5.0, 8.0), Vector2(5.0, 30.0), Vector2(5.0, 40.0),
		Vector2(7.0, 42.0), Vector2(13.0, 42.0), Vector2(19.0, 42.0), Vector2(25.0, 42.0),
		Vector2(31.0, 42.0), Vector2(37.0, 42.0), Vector2(43.0, 42.0), Vector2(49.0, 42.0),
		Vector2(55.0, 42.0), Vector2(61.0, 42.0),
		Vector2(16.0, 22.0), Vector2(21.0, 4.0), Vector2(43.0, 4.0),
		Vector2(60.0, 28.0), Vector2(60.0, 38.0), Vector2(16.0, 12.0),
	]:
		_add_pine(tile_position)

	# 池边芦苇（主池 + 小池）
	for tile_position: Vector2 in [
		Vector2(45.8, 36.5), Vector2(59.2, 36.5), Vector2(52.5, 31.6),
		Vector2(52.5, 41.0), Vector2(48.5, 32.5), Vector2(56.5, 32.5),
		Vector2(48.5, 40.5), Vector2(56.5, 40.5),
		Vector2(5.8, 30.5), Vector2(13.2, 30.5), Vector2(9.5, 27.7),
		Vector2(9.5, 33.3), Vector2(7.0, 28.3), Vector2(12.0, 32.7),
	]:
		_add_reeds(tile_position)

	# 池塘石岸
	for tile_position: Vector2 in [
		Vector2(45.4, 34.5), Vector2(59.6, 38.0), Vector2(50.0, 31.4),
		Vector2(55.0, 41.6), Vector2(47.0, 39.8), Vector2(58.0, 33.4),
		Vector2(4.8, 29.0), Vector2(14.2, 31.0), Vector2(8.0, 27.4),
		Vector2(11.0, 33.8),
	]:
		_add_prop("pond_stone", tile_position * TILE)

	# 睡莲（水面）
	for tile_position: Vector2 in [
		Vector2(50.5, 34.5), Vector2(54.5, 38.5), Vector2(52.0, 39.0),
		Vector2(55.0, 34.8), Vector2(49.0, 37.5), Vector2(53.5, 33.5),
		Vector2(56.5, 37.5), Vector2(51.0, 36.0),
		Vector2(8.5, 29.5), Vector2(10.5, 31.5), Vector2(11.5, 30.0),
	]:
		_add_prop("lily", tile_position * TILE)

	var rocks := [
		Vector2(14.0, 18.0), Vector2(20.0, 25.0), Vector2(43.0, 25.0),
		Vector2(6.0, 22.0), Vector2(60.0, 24.0), Vector2(16.0, 40.0),
		Vector2(34.0, 42.0), Vector2(44.0, 22.0), Vector2(5.5, 36.0),
		Vector2(61.0, 26.0),
	]
	for tile_position: Vector2 in rocks:
		var world := tile_position * TILE
		_add_prop("rock", world)
		_add_wall(Rect2(world.x - 13, world.y - 10, 26, 10))


## 地图三层中的"静态标记"与"资源区"（底层地形由 MapPanel 直接绘制）。
func _build_map_entities() -> void:
	_add_map_entity("Building", "自宅", "睡觉恢复体力；升级后解锁厨房、冰箱和浴室。",
		"house", HOUSE_BASE, Vector2(10, 4))
	_add_map_entity("Building", "杂货铺", "购买种子、动物、宠物、蜂具和树苗，并出售背包物品。",
		"shop", SHOP_BASE, Vector2(9, 3))
	_add_map_entity("Building", "博物馆", "捐赠古物、矿石与鱼类，查看小镇收藏。",
		"museum", MUSEUM_BASE, Vector2(-14, 8))
	_add_map_entity("Facility", "温泉", "每天泡一次，恢复全部体力与生命。",
		"bath", HOT_SPRING_BASE, Vector2(-10, 8))
	_add_map_entity("Building", "图书馆", "每天读一本书，领取研究奖励。",
		"library", LIBRARY_BASE, Vector2(-14, 8))
	_add_map_entity("Building", "诊所", "付费治疗，恢复体力并治疗生病动物。",
		"clinic", CLINIC_BASE, Vector2(-10, 8))
	_add_map_entity("Facility", "雇工小屋", "雇一名浇水工，每天早上自动浇水。",
		"npc", WORKER_HUT_BASE, Vector2(-16, 8))
	_add_map_entity("Building", "鸡舍", "在食槽旁按 E 喂养，第二天收取鸡蛋。",
		"coop", COOP_BASE, Vector2(-10, 9))
	_add_map_entity("Building", "畜棚", "在食槽旁按 E 喂养，第二天收取牛奶。",
		"barn", BARN_BASE, Vector2(7, 9))
	_add_map_entity("Facility", "矿洞", "下矿挖掘矿石与宝石，越深越危险。",
		"mine", MINE_ENTRANCE_BASE, Vector2(9, 2))
	var bin := _add_map_entity("Facility", "出货箱", "把农产品放进去，第二天自动结算。",
		"bin", BIN_BASE, Vector2(7, 3))
	bin.show_label = false

	var pond_rect := Rect2(
		Vector2(POND_RECT.position) * TILE, Vector2(POND_RECT.size) * TILE
	)
	var farm_label := Vector2(
		FARM_ORIGIN.x * TILE + 6, (FARM_ORIGIN.y + FARM_SIZE.y) * TILE - 10
	)
	_add_map_entity("Resource", "农田", "翻地、播种、浇水，成熟后收获。",
		"", farm_label, Vector2.ZERO, false)
	_add_map_entity("Resource", "牧场", "动物活动区，在食槽旁按 E 喂食。",
		"", Vector2(PASTURE.position.x + 6, PASTURE.end.y - 10), Vector2.ZERO, false)
	_add_map_entity("Resource", "池塘", "在岸边按 F 钓鱼。",
		"", Vector2(pond_rect.position.x + 6, pond_rect.end.y - 10), Vector2.ZERO, false)


func _add_map_entity(
	entity_type: String,
	display_name: String,
	tooltip_desc: String,
	icon_kind: String,
	world_position: Vector2,
	label_offset: Vector2,
	show_on_minimap := true
) -> MapEntity:
	var entity := MapEntityScript.new()
	entity.entity_type = entity_type
	entity.display_name = display_name
	entity.tooltip_desc = tooltip_desc
	entity.map_icon = PixelTheme.map_icon(icon_kind) if not icon_kind.is_empty() else null
	entity.label_offset = label_offset
	entity.show_on_minimap = show_on_minimap
	entity.position = world_position
	add_child(entity)
	return entity


## 拾取动画：物品从来源处浮现并飞向底部背包栏（屏幕坐标换算到世界空间）。
func _spawn_pickup(item_id: String, category: String, from_world: Vector2) -> void:
	if item_id.is_empty() or player == null:
		return
	var ui_target := Vector2(240.0, 246.0)  # 480×270 下快捷栏中心
	var canvas := get_viewport().get_canvas_transform()
	var world_target: Vector2 = canvas.affine_inverse() * ui_target
	var fx := PickupBurstScript.new()
	add_child(fx)
	fx.setup(item_id, category, from_world, world_target)


## 背包满时把物品留在原地；靠近且背包有空位时自动拾取。
func _spawn_ground_item(item: Dictionary, world_position: Vector2) -> void:
	if item.is_empty():
		return
	var ground := GroundItemScript.new()
	add_child(ground)
	ground.setup(self, item, world_position)


func _add_prop(kind: String, world_position: Vector2) -> WorldProp:
	var prop := WorldPropScript.new()
	add_child(prop)
	prop.setup(kind, world_position)
	if time != null:
		prop.set_season(time.season)
	props.append(prop)
	return prop


## 季节变化时让所有场景装饰同步（树木换色 / 积雪等）。
func _sync_prop_season(value: String) -> void:
	for prop: WorldProp in props:
		prop.set_season(value)


## 牧场栅栏：只做碰撞（视觉在 Farm._draw 里统一画）。
func _build_pasture_fence() -> void:
	var left := PASTURE.position.x
	var top := PASTURE.position.y
	var right := PASTURE.end.x
	var bottom := PASTURE.end.y

	# 上边留一个门（x 在 26.5~28.5 格之间）
	_add_wall(Rect2(left, top, 2.5 * TILE, 8))
	_add_wall(Rect2(left + 4.5 * TILE, top, right - left - 4.5 * TILE, 8))
	# 下边
	_add_wall(Rect2(left, bottom - 8, right - left, 8))
	# 左右
	_add_wall(Rect2(left, top, 8, bottom - top))
	_add_wall(Rect2(right - 8, top, 8, bottom - top))


func _add_tree(tile_position: Vector2) -> void:
	var world := tile_position * TILE
	_add_prop("tree", world)
	_add_wall(Rect2(world.x - 8, world.y - 12, 16, 12))


func _add_blossom_tree(tile_position: Vector2) -> void:
	var world := tile_position * TILE
	_add_prop("blossom_tree", world)
	_add_wall(Rect2(world.x - 8, world.y - 12, 16, 12))


func _add_pine(tile_position: Vector2) -> void:
	var world := tile_position * TILE
	_add_prop("pine", world)
	_add_wall(Rect2(world.x - 8, world.y - 12, 16, 12))


func _add_bush(tile_position: Vector2) -> void:
	_add_prop("bush", tile_position * TILE)


func _add_reeds(tile_position: Vector2) -> void:
	_add_prop("reeds", tile_position * TILE)


func _build_farm_tiles() -> void:
	for y in FARM_SIZE.y:
		for x in FARM_SIZE.x:
			var tile_position := FARM_ORIGIN + Vector2i(x, y)
			var tile: FarmTile = FarmTileScript.new()
			add_child(tile)
			tile.setup(tile_position, false)
			farm_tiles[tile_position] = tile


func _build_interior() -> void:
	_interior = HouseInteriorScript.new()
	_interior.name = "HouseInterior"
	_interior.visible = false
	_interior.z_index = -20
	add_child(_interior)
	_interior.setup(Vector2(0, -1200), home_level)
	_interior.sleep_requested.connect(_sleep)
	_interior.exit_requested.connect(exit_house)
	_interior.mirror_requested.connect(func() -> void: _open_creator(true))
	_interior.storage_requested.connect(_open_home_storage)
	_interior.cellar_requested.connect(_open_cellar)
	_interior.kitchen_requested.connect(func() -> void: ui.open_cooking())
	_interior.tv_requested.connect(_on_tv_requested)
	_interior.bathroom_requested.connect(_on_bathroom_requested)
	_interior.spouse_talked.connect(_on_spouse_talked)


func _build_camera() -> void:
	camera = Camera2D.new()
	# 480×270 渲染目标；默认 0.75 让画面看到更多内容，可用 = / - 调节。
	camera.position = player.position
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = WORLD_W * TILE
	camera.limit_bottom = WORLD_H * TILE
	add_child(camera)
	_apply_camera_zoom()
	camera.make_current()


## 应用当前缩放档位。
func _apply_camera_zoom() -> void:
	if camera == null:
		return
	var index := clampi(camera_zoom_index, 0, CAMERA_ZOOM_STEPS.size() - 1)
	var value: float = CAMERA_ZOOM_STEPS[index]
	camera.zoom = Vector2(value, value)


## = / - 调整画面缩放（正数放大，负数缩小）。
func adjust_camera_zoom(direction: int) -> void:
	camera_zoom_index = clampi(
		camera_zoom_index + direction, 0, CAMERA_ZOOM_STEPS.size() - 1)
	_apply_camera_zoom()


func _build_ambient_particles() -> void:
	var ambient: AmbientParticles = AmbientParticlesScript.new()
	ambient.name = "AmbientParticles"
	ambient.farm = self
	add_child(ambient)


## 高频短命节点对象池（挥砍弧光等），避免频繁 new / free。
func _build_object_pools() -> void:
	_slash_pool = ObjectPool.new(
		self, func() -> Node: return SlashScript.new(), 4)


## 地图界面数据：世界尺寸、地标、玩家与动植物位置（世界像素坐标）。
func get_map_info() -> Dictionary:
	var animal_points := PackedVector2Array()
	for animal: Node2D in animals:
		animal_points.append(animal.position)
	var pet_points := PackedVector2Array()
	for pet: Node2D in pets:
		pet_points.append(pet.position)
	var tree_points := PackedVector2Array()
	for tree: Node2D in fruit_trees:
		tree_points.append(tree.position)
	var hive_points := PackedVector2Array()
	for hive: Node2D in beehives:
		hive_points.append(hive.position)

	var path_cells := PackedVector2Array()
	var sand_cells := PackedVector2Array()
	for y in WORLD_H:
		for x in WORLD_W:
			var kind := int(_terrain[y * WORLD_W + x])
			if kind == GroundTileMapScript.PATH:
				path_cells.append(Vector2(x, y) * TILE)
			elif kind == GroundTileMapScript.SAND:
				sand_cells.append(Vector2(x, y) * TILE)

	var tree_prop_points := PackedVector2Array()
	var rock_prop_points := PackedVector2Array()
	for prop in props:
		match str(prop.kind):
			"tree":
				tree_prop_points.append(prop.position)
			"rock":
				rock_prop_points.append(prop.position)

	var marker := Vector2.ZERO
	var facing := "down"
	if player != null:
		marker = player.position
		facing = str(player.facing)
	var location_text := "农场"
	if in_mine:
		marker = MINE_ENTRANCE_BASE + Vector2(0, 14)
		location_text = "矿洞 %d 层" % mine_floor_num
	elif indoor:
		marker = HOUSE_BASE
		location_text = "自宅"

	return {
		"world_size": Vector2(WORLD_W, WORLD_H) * TILE,
		"farm_rect": Rect2(Vector2(FARM_ORIGIN) * TILE, Vector2(FARM_SIZE) * TILE),
		"pond_rect": Rect2(Vector2(POND_RECT.position) * TILE, Vector2(POND_RECT.size) * TILE),
		"small_pond_rect": Rect2(
			Vector2(SMALL_POND_RECT.position) * TILE, Vector2(SMALL_POND_RECT.size) * TILE),
		"river_rects": [
			Rect2(Vector2(RIVER_LEFT.position) * TILE, Vector2(RIVER_LEFT.size) * TILE),
			Rect2(Vector2(RIVER_BOTTOM.position) * TILE, Vector2(RIVER_BOTTOM.size) * TILE),
		],
		"pasture_rect": PASTURE,
		"player_pos": marker,
		"player_facing": facing,
		"location_text": location_text,
		"animal_points": animal_points,
		"pet_points": pet_points,
		"tree_points": tree_points,
		"hive_points": hive_points,
		"path_cells": path_cells,
		"sand_cells": sand_cells,
		"tree_prop_points": tree_prop_points,
		"rock_prop_points": rock_prop_points,
	}


func get_map_region_id() -> String:
	if in_mine:
		return "mine"
	if indoor:
		return "house"
	return "farm"


## 当前区域的地图数据：农场 / 自宅 / 矿洞。
func get_map_region() -> Dictionary:
	var id := get_map_region_id()
	var player_pos := Vector2.ZERO
	var facing := "down"
	if player != null:
		player_pos = player.position
		facing = str(player.facing)

	if id == "house" and _interior != null:
		# 通用建筑室内：地图显示建筑名称、室内范围与家具点位
		if not current_building.is_empty() and _building_interior != null:
			var b_bounds := _building_interior.get_bounds()
			var b_markers: Array = []
			for entry: Dictionary in _building_interior.get_props():
				var label := str(entry.get("text", ""))
				if label.is_empty():
					continue
				b_markers.append({
					"name": str(entry.get("kind", "furniture")),
					"desc": label,
					"icon": "door" if str(entry.get("interact", "")) == "exit_building" else "chest",
					"pos": _building_interior.origin + Vector2(
						float(entry.get("x", 0)) * TILE,
						float(entry.get("y", 0)) * TILE),
					"offset": Vector2(7, 3),
				})
			b_markers.append({
				"name": "门", "desc": "按 E 离开。", "icon": "door",
				"pos": _building_interior.door_point, "offset": Vector2(7, 3),
			})
			return {
				"id": "building", "title": _building_interior.display_name,
				"origin": b_bounds.position,
				"world_size": b_bounds.size, "player_pos": player_pos,
				"player_facing": facing,
				"floor_color": Color("#d9c9a8"), "rock_points": PackedVector2Array(),
				"markers": b_markers,
			}
		var bounds := _interior.get_bounds()
		var markers := [
			{"name": "床", "desc": "按 E 睡觉，跳到次日 06:00。",
				"icon": "bed", "pos": _interior.bed_point, "offset": Vector2(7, 3)},
			{"name": "镜子", "desc": "按 E 修改角色外观。",
				"icon": "mirror", "pos": _interior.mirror_point, "offset": Vector2(7, 3)},
			{"name": "储物箱", "desc": "存放背包物品。",
				"icon": "chest", "pos": _interior.storage_point, "offset": Vector2(-34, 9)},
			{"name": "电视", "desc": "按 E 查看天气预报。",
				"icon": "tv", "pos": _interior.tv_point, "offset": Vector2(7, 3)},
			{"name": "门", "desc": "按 E 出门回到农场。",
				"icon": "door", "pos": _interior.door_point, "offset": Vector2(7, 3)},
		]
		if home_level >= 2:
			markers.append({
				"name": "厨房", "desc": "按 E 打开厨房烹饪。",
				"icon": "stove", "pos": _interior.kitchen_point, "offset": Vector2(-12, 9),
			})
			markers.append({
				"name": "浴室", "desc": "按 E 泡澡，每天恢复一次体力。",
				"icon": "bath", "pos": _interior.bathroom_point, "offset": Vector2(7, 3),
			})
			markers.append({
				"name": "冰箱", "desc": "按 E 打开冰箱（储物）。",
				"icon": "fridge", "pos": _interior.fridge_point, "offset": Vector2(-30, 9),
			})
		var spouse := _find_npc(spouse_id)
		if spouse != null:
			markers.append({
				"name": spouse.display_name, "desc": "配偶 · 按 E 聊天。",
				"icon": "npc", "pos": _interior.spouse_point, "offset": Vector2(7, 3),
			})
		return {
			"id": "house", "title": "自宅", "origin": bounds.position,
			"world_size": bounds.size, "player_pos": player_pos, "player_facing": facing,
			"floor_color": Color("#d9c9a8"), "rock_points": PackedVector2Array(),
			"markers": markers,
		}

	if id == "mine" and mine_floor != null:
		var rock_points := PackedVector2Array()
		for rock in mine_floor.rocks:
			rock_points.append(rock.position)
		var stairs_pos := Vector2(mine_floor.stairs_pos) * TILE + Vector2(TILE * 0.5, TILE)
		return {
			"id": "mine", "title": "矿洞 第 %d 层" % mine_floor_num,
			"origin": Vector2.ZERO,
			"world_size": Vector2(MineFloorScript.FLOOR_W, MineFloorScript.FLOOR_H) * TILE,
			"player_pos": player_pos, "player_facing": facing,
			"floor_color": Color("#6f6558"), "rock_points": rock_points,
			"markers": [
				{"name": "下层楼梯", "desc": "走到楼梯按 E 下楼。",
					"icon": "stairs", "pos": stairs_pos, "offset": Vector2(7, 3)},
				{"name": "返回入口", "desc": "走到梯井按 E 返回农场。",
					"icon": "door", "pos": mine_floor.spawn_position, "offset": Vector2(7, 3)},
			],
		}

	var info := get_map_info()
	return {
		"id": "farm", "title": "农场地图", "origin": Vector2.ZERO,
		"world_size": info.get("world_size", Vector2.ONE),
		"player_pos": player_pos, "player_facing": facing,
		"floor_color": Color("#b7cc8f"), "rock_points": PackedVector2Array(),
		"markers": [], "info": info,
	}


## 挂在地图组里的实体（建筑 / 设施 / 资源区 / 未来 NPC）。
func get_map_entities() -> Array:
	var result: Array = []
	for node: Node in get_tree().get_nodes_in_group("map_entities"):
		if is_ancestor_of(node):
			result.append(node)
	return result


## 点击寻路：从玩家当前位置走到目标附近（目标在墙内时自动找最近可行走格）。
func navigate_to(target: Vector2) -> bool:
	if player == null:
		return false
	if indoor:
		return _navigate_indoor(target)
	if in_mine:
		return _navigate_mine(target)
	var astar := _build_nav_grid()
	var start_cell := _nearest_walkable_cell(astar, _world_to_cell(player.position), 4)
	var goal_cell := _nearest_walkable_cell(astar, _world_to_cell(target), 6)
	if start_cell.x < 0 or goal_cell.x < 0:
		ui.toast("这个位置走不过去", "bad")
		return false
	var cells := astar.get_id_path(start_cell, goal_cell)
	if cells.is_empty():
		ui.toast("找不到前往目标的路", "bad")
		return false
	var points := PackedVector2Array()
	for cell: Vector2i in cells:
		points.append(Vector2(
			cell.x * TILE + TILE * 0.5,
			cell.y * TILE + TILE * 0.5
		))
	if points.size() > 1:
		points.remove_at(0)
	player.set_navigation_path(points)
	return true


func _build_nav_grid() -> AStarGrid2D:
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, WORLD_W, WORLD_H)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in WORLD_H:
		for x in WORLD_W:
			if int(_terrain[y * WORLD_W + x]) == GroundTileMapScript.WATER:
				astar.set_point_solid(Vector2i(x, y), true)
	if _walls != null:
		for child in _walls.get_children():
			if not (child is CollisionShape2D):
				continue
			var collision: CollisionShape2D = child
			if not (collision.shape is RectangleShape2D):
				continue
			var box: RectangleShape2D = collision.shape
			var rect := Rect2(collision.position - box.size * 0.5, box.size)
			var x0 := maxi(0, floori(rect.position.x / TILE))
			var y0 := maxi(0, floori(rect.position.y / TILE))
			var x1 := mini(WORLD_W - 1, floori((rect.end.x - 0.01) / TILE))
			var y1 := mini(WORLD_H - 1, floori((rect.end.y - 0.01) / TILE))
			for y in range(y0, y1 + 1):
				for x in range(x0, x1 + 1):
					astar.set_point_solid(Vector2i(x, y), true)
	for machine: ProcessingMachine in machines:
		astar.set_point_solid(machine.cell, true)
	return astar


## 室内寻路：12×9 房间网格，墙由房间边界限制。
func _navigate_indoor(target: Vector2) -> bool:
	if _interior == null:
		return false
	var bounds := _interior.get_bounds()
	var room_w := maxi(1, int(bounds.size.x / TILE))
	var room_h := maxi(1, int(bounds.size.y / TILE))
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, room_w, room_h)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	var start_cell := Vector2i(
		clampi(floori((player.position.x - bounds.position.x) / TILE), 0, room_w - 1),
		clampi(floori((player.position.y - bounds.position.y) / TILE), 0, room_h - 1))
	var goal_cell := Vector2i(
		clampi(floori((target.x - bounds.position.x) / TILE), 0, room_w - 1),
		clampi(floori((target.y - bounds.position.y) / TILE), 0, room_h - 1))
	return _apply_nav_path(astar, start_cell, goal_cell, bounds.position)


## 矿洞寻路：40×30 网格，边缘岩壁与未敲碎的石头不可走。
func _navigate_mine(target: Vector2) -> bool:
	if mine_floor == null:
		return false
	var floor_w := MineFloorScript.FLOOR_W
	var floor_h := MineFloorScript.FLOOR_H
	var astar := AStarGrid2D.new()
	astar.region = Rect2i(0, 0, floor_w, floor_h)
	astar.cell_size = Vector2(TILE, TILE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for x in floor_w:
		astar.set_point_solid(Vector2i(x, 0), true)
		astar.set_point_solid(Vector2i(x, floor_h - 1), true)
	for y in floor_h:
		astar.set_point_solid(Vector2i(0, y), true)
		astar.set_point_solid(Vector2i(floor_w - 1, y), true)
	for rock in mine_floor.rocks:
		if is_instance_valid(rock):
			var cell: Vector2i = rock.cell
			if cell.x >= 0 and cell.y >= 0 and cell.x < floor_w and cell.y < floor_h:
				astar.set_point_solid(cell, true)
	var start_cell := _nearest_walkable_cell_in(
		astar, _world_to_cell(player.position), 3, floor_w, floor_h)
	var goal_cell := _nearest_walkable_cell_in(
		astar, _world_to_cell(target), 4, floor_w, floor_h)
	return _apply_nav_path(astar, start_cell, goal_cell, Vector2.ZERO)


func _apply_nav_path(
	astar: AStarGrid2D, start_cell: Vector2i, goal_cell: Vector2i, origin: Vector2
) -> bool:
	if start_cell.x < 0 or goal_cell.x < 0:
		ui.toast("这个位置走不过去", "bad")
		return false
	var cells := astar.get_id_path(start_cell, goal_cell)
	if cells.is_empty():
		ui.toast("找不到前往目标的路", "bad")
		return false
	var points := PackedVector2Array()
	for cell: Vector2i in cells:
		points.append(origin + Vector2(
			cell.x * TILE + TILE * 0.5,
			cell.y * TILE + TILE * 0.5
		))
	if points.size() > 1:
		points.remove_at(0)
	player.set_navigation_path(points)
	return true


func _nearest_walkable_cell_in(
	astar: AStarGrid2D, cell: Vector2i, radius: int, width: int, height: int
) -> Vector2i:
	if _is_walkable_in(astar, cell, width, height):
		return cell
	for r in range(1, radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var candidate := cell + Vector2i(dx, dy)
				if _is_walkable_in(astar, candidate, width, height):
					return candidate
	return Vector2i(-1, -1)


func _is_walkable_in(
	astar: AStarGrid2D, cell: Vector2i, width: int, height: int
) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return false
	return not astar.is_point_solid(cell)


func _world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(floori(world_pos.x / TILE), floori(world_pos.y / TILE))


func _nearest_walkable_cell(astar: AStarGrid2D, cell: Vector2i, radius: int) -> Vector2i:
	if _is_walkable_cell(astar, cell):
		return cell
	for r in range(1, radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var candidate := cell + Vector2i(dx, dy)
				if _is_walkable_cell(astar, candidate):
					return candidate
	return Vector2i(-1, -1)


func _is_walkable_cell(astar: AStarGrid2D, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= WORLD_W or cell.y >= WORLD_H:
		return false
	return not astar.is_point_solid(cell)


## 水面波纹：2~3 帧循环，画在池塘上（不参与 Y-sort）。
class WaterOverlay:
	extends Node2D

	var cells: Array[Vector2i] = []
	var _t := 0.0


	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()


	func _draw() -> void:
		if cells.is_empty():
			return
		# 3 帧循环的波纹（每隔 0.9 秒切换一组位置）
		var frame := int(_t / 0.9) % 3
		var offsets: float = float(frame) * 3.0
		for index in 10:
			var cell: Vector2i = cells[(index * 17 + frame * 5) % cells.size()]
			var x := float(cell.x) * 32.0 + 5.0 \
				+ fmod(float(index) * 7.0 + offsets * 3.0, 20.0)
			var y := float(cell.y) * 32.0 + 5.0 \
				+ fmod(float(index) * 5.0 + offsets, 20.0)
			var width := 4.0 + float((index + frame) % 3) * 2.0
			draw_rect(Rect2(roundf(x), roundf(y), width, 1.0),
				Color(0.72, 0.90, 0.88, 0.40), true)
		# 气泡：只在水格内上浮
		for index in 3:
			var rise := fmod(_t * 0.5 + float(index) * 0.33, 1.0)
			var cell: Vector2i = cells[(index * 23 + 7) % cells.size()]
			var bx := float(cell.x) * 32.0 + 12.0 + sin(_t + float(index)) * 3.0
			var by := float(cell.y) * 32.0 + 26.0 - rise * 12.0
			draw_rect(Rect2(roundf(bx), roundf(by), 2.0, 2.0),
				Color(0.85, 0.95, 0.92, (1.0 - rise) * 0.5), true)


func _build_water_overlay() -> void:
	var overlay := WaterOverlay.new()
	overlay.name = "WaterOverlay"
	overlay.z_index = -8
	overlay.cells.assign(_pond_cells)
	add_child(overlay)


func _build_day_light() -> void:
	day_light = CanvasModulate.new()
	# 白天暖阳（不用纯白）：偏暖的米白
	day_light.color = Color(1.0, 0.985, 0.95)
	add_child(day_light)


func _build_weather_layer() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var fx := WeatherSystem.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(fx)
	fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fx.setup(self)
	weather_fx = fx


func _build_tutorial() -> void:
	tutorial = TutorialScript.new()
	tutorial.step_changed.connect(_on_tutorial_step)
	tutorial.completed.connect(func() -> void:
		ui.show_dialogue("提示", "新手引导完成！接下来可以自由种地、养动物、钓鱼了。", 3.0)
		save_game()
	)
	_last_player_position = player.position


func _on_tutorial_step(_step: int, text: String) -> void:
	if text.is_empty():
		return
	ui.show_dialogue("引导", text, 4.0)
	save_game()


func _build_debug_panel() -> void:
	debug_panel = DebugPanelScript.new()
	add_child(debug_panel)
	debug_panel.setup(self)


func _build_ui() -> void:
	ui = GameUIScript.new()
	ui.layer = 10
	add_child(ui)
	ui.setup(self)
	ui.refresh_hud()


func _build_map_ui() -> void:
	map_ui = MapUIScene.instantiate()
	add_child(map_ui)
	map_ui.setup(self)


func toggle_map() -> void:
	if map_ui != null:
		map_ui.toggle_map()


# ============================================================
# 启动 / 存档
# ============================================================

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if _started and not _transitioning:
			save_game()
		get_tree().quit()


func _start_or_load() -> void:
	if Save.has_save() and load_game():
		ui.toast("已读取存档", "good")
	else:
		start_new_game(false, true)


func start_new_game(save_after := true, with_creator := false) -> void:
	if player != null and player.riding:
		dismount_mount(true)
	mounts.clear()
	riding_mount = null
	riding_animal = null
	riding_mount_id = ""
	_bike_sprint_cd = 0.0
	_bike_sprint_used = false
	_pet_serial = 0
	_pet_house_serial = 0
	_clear_pets()
	_clear_wild_critters()
	if player != null:
		player.set_riding(false)
	if _stable_prop != null:
		_build_mount_nodes()
	player_name = "农夫"
	farm_name = "阳光牧场"
	_update_farm_sign()
	var template := Save.get_empty_save()
	money = int(template.get("money", 500))
	selected_index = 0
	unlock_book = (template.get("unlock_book", {}) as Dictionary).duplicate(true)
	museum_donations.clear()
	home_storage.clear()
	fridge_storage.clear()
	cellar_items.clear()
	total_earned = 0
	crops_harvested = 0
	fish_caught = 0
	ore_mined = 0
	days_played = 0
	achievements_unlocked.clear()
	hot_spring_used_today = false
	books_read.clear()
	last_book_day = -1
	hired_worker = false
	placed_furniture.clear()
	if _interior != null:
		_interior.set_furniture(placed_furniture)
		_refresh_house_props()

	time.setup()
	time.leave_location()
	mail_pending.clear()
	mail_read.clear()
	_refresh_mail()

	player.position = SPAWN
	player.facing = "down"
	player.restore_stamina(1.0)
	player.restore_health(1.0)
	home_level = 1
	bath_used_today = false
	camera_zoom_index = DEFAULT_CAMERA_ZOOM_INDEX
	_apply_camera_zoom()
	if map_ui != null:
		map_ui.reset_fog()
	if _interior != null:
		_interior.set_level(1)

	inventory.clear()
	for entry: Dictionary in DB.get_start_items():
		inventory.add_item({
			"item_id": str(entry.get("item_id", "")),
			"category": str(entry.get("category", "")),
			"count": int(entry.get("count", 1)),
		})

	_reset_tiles()
	_clear_fruit_trees()
	_clear_beehives()
	_clear_machines()
	_clear_animals()
	_clear_pets()
	_reset_npcs()
	_reset_quests_buildings()
	if tutorial != null:
		tutorial.reset()
		_tutorial_move_distance = 0.0
		_last_player_position = player.position
	building_fed = {"coop": false, "barn": false}
	ui.refresh_hud()
	ui.refresh_inventory()

	if with_creator:
		_open_creator(false)
	else:
		_apply_appearance(player.look)
		if save_after:
			save_game()


func save_game(silent := true) -> bool:
	# 按《代码架构规范》1.1 的顶层 schema 写入：
	# player / world / inventory / farm_tiles / animal_list / unlock_book ...
	# 设计规范：正在骑乘时先下坐骑再保存。
	if player.riding:
		dismount_mount(true)
	_sync_pet_house_data()
	var data := Save.get_empty_save()

	data["play_time_seconds"] = play_time
	data["stats"] = data.get("stats", {})
	(data["stats"] as Dictionary)["play_time"] = int(play_time)
	(data["stats"] as Dictionary)["total_earned"] = int(total_earned)
	(data["stats"] as Dictionary)["crops_harvested"] = int(crops_harvested)
	(data["stats"] as Dictionary)["fish_caught"] = int(fish_caught)
	(data["stats"] as Dictionary)["ore_mined"] = int(ore_mined)
	(data["stats"] as Dictionary)["days_played"] = int(days_played)
	data["achievements_unlocked"] = achievements_unlocked.duplicate()
	data["hot_spring_used_today"] = hot_spring_used_today
	data["books_read"] = books_read.duplicate()
	data["last_book_day"] = last_book_day
	data["hired_worker"] = hired_worker
	data["placed_furniture"] = placed_furniture.duplicate(true)

	var player_data: Dictionary = data["player"]
	player_data["appearance"] = player.look.duplicate(true)
	player_data["money"] = money
	player_data["stamina"] = player.stamina
	player_data["max_stamina"] = player.stamina_max
	player_data["hp"] = player.hp
	player_data["max_hp"] = player.max_hp
	player_data["position"] = {"x": player.position.x, "y": player.position.y}
	player_data["name"] = player_name
	player_data["gender"] = str(player.look.get("gender", "female"))
	player_data["tools"] = {
		"hoe": {"level": "copper", "durability": 100},
		"watering_can": {"level": "copper", "capacity": 40},
		"axe": {"level": "copper"},
		"pickaxe": {"level": "copper"},
		"fishing_rod": {"level": inventory.find_rod()},
	}

	var world: Dictionary = data["world"]
	world["day"] = time.day
	world["season"] = time.season
	world["year"] = time.year
	world["weather"] = time.weather
	world["tomorrow_weather"] = time.weather
	world["time_minutes"] = int(time.minutes)
	world["location"] = "house" if indoor else time.location_id
	world["time_paused"] = time.is_time_paused()
	world["camera_zoom_index"] = camera_zoom_index
	data["farm_name"] = farm_name
	if map_ui != null:
		world["fog_png"] = map_ui.export_fog()
	var home: Dictionary = data["home"]
	home["level"] = home_level
	home["bath_used_today"] = bath_used_today

	var inv: Dictionary = data["inventory"]
	inv["capacity"] = inventory.max_slots
	inv["items"] = inventory.to_save()
	inv["hotbar"] = _hotbar_to_save()

	data["farm_tiles"] = _tiles_to_save()
	data["fruit_trees_planted"] = _trees_to_save()
	data["apiary"] = _beehives_to_save()
	data["machines"] = _machines_to_save()
	data["npc_states"] = _npcs_to_save()
	data["festivals_done"] = festivals_done.duplicate()
	data["quests"] = {
		"active": quests_active.duplicate(true),
		"completed": quests_completed.duplicate(),
		"daily_refreshed_day": quest_last_day,
	}
	data["buildings"] = buildings_state.duplicate(true)
	data["spouse"] = spouse_id
	data["animal_list"] = _animals_to_save()
	data["pets"] = _pets_to_save()
	data["pet_houses"] = pet_houses.duplicate(true)
	data["pet_limits"] = {
		"max_pets": get_pet_limit(),
		"unlocked_by": ["initial", "first_expansion", "second_expansion"],
	}
	data["mounts"] = mounts.duplicate(true)
	data["unlock_book"] = unlock_book
	data["museum_donations"] = museum_donations.duplicate()
	data["home_storage"] = home_storage.duplicate(true)
	data["fridge_storage"] = fridge_storage.duplicate(true)
	data["mail_pending"] = mail_pending.duplicate()
	data["mail_read"] = mail_read.duplicate()
	data["cellar_items"] = cellar_items.duplicate(true)
	data["equipment"] = {
		"tools": {},
		"rod": inventory.find_rod(),
		"bait": "",
		"tackle": "",
	}
	data["mine"] = {
		"deepest_floor": mine_deepest,
		"collected_ores": mine_ores.duplicate(),
		"collected_gems": mine_gems.duplicate(),
		"donated_artifacts": [],
	}
	data["building"] = {
		"coop": {"fed_today": bool(building_fed.get("coop", false))},
		"barn": {"fed_today": bool(building_fed.get("barn", false))},
	}
	data["accessories_equipped"] = accessories_equipped.duplicate(true)
	data["accessories_owned"] = accessories_owned.duplicate()
	if tutorial != null:
		var tutorial_data := tutorial.to_save()
		data["tutorial_step"] = tutorial_data["tutorial_step"]
		data["tutorial_completed"] = tutorial_data["tutorial_completed"]

	var ok := Save.save_data(data)
	if ok and _last_thumbnail != null:
		Save.save_thumbnail(Save.get_slot(), _last_thumbnail)
	if not silent and ui != null:
		ui.toast("已保存" if ok else "保存失败", "good" if ok else "bad")
	if ok and EventBus != null:
		EventBus.save_completed.emit()
	elif EventBus != null:
		EventBus.save_failed.emit("写入失败")
	return ok


## 缓存一张无弹窗的游戏画面，供存档缩略图使用。
func _capture_thumbnail() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var texture := viewport.get_texture()
	if texture == null:
		return
	var image := texture.get_image()
	if image == null or image.is_empty():
		return
	image.resize(160, 90, Image.INTERPOLATE_NEAREST)
	_last_thumbnail = image


## 进入任意建筑（商店 / 诊所 / 图书馆 / 博物馆 / 鸡舍 / 畜棚 / 雇工小屋）。
func enter_building(building_id: String) -> void:
	if indoor or in_mine or _transitioning:
		return
	if player.riding:
		ui.toast("请先下坐骑再进屋", "bad")
		return
	var data := DB.get_interior(building_id)
	if data.is_empty():
		ui.toast("这栋建筑暂时进不去", "bad")
		return
	_transitioning = true
	player.input_locked = true
	player.set_sitting(false)
	ui.fade_out(0.3)
	await get_tree().create_timer(0.32).timeout

	_outdoor_position = player.position
	indoor = true
	current_building = building_id
	time.enter_location(building_id)

	_set_outdoor_visible(false)
	if _interior != null:
		_interior.visible = false
	_clear_building_interior()

	_building_interior = BuildingInteriorScript.new()
	_building_interior.name = "BuildingInterior"
	_building_interior.z_index = -12
	add_child(_building_interior)
	_building_interior.setup(building_id, Vector2(0.0, -2600.0))
	_spawn_interior_props()
	_add_indoor_walls(_building_interior.get_wall_rects())

	var bounds := _building_interior.get_bounds()
	player.position = _building_interior.door_point + Vector2(0, -48)
	player.facing = "up"
	player.z_index = 0

	_saved_camera_limits = Rect2i(
		camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom)
	# 室内用 1:1 缩放，房间更饱满、家具体积更清晰
	camera.zoom = Vector2(1.0, 1.0)
	camera.limit_left = int(bounds.position.x) - 8
	camera.limit_top = int(bounds.position.y) - 8
	camera.limit_right = int(bounds.end.x) + 8
	camera.limit_bottom = int(bounds.end.y) + 8
	camera.position = bounds.get_center()
	camera.reset_smoothing()

	_update_day_light()
	ui.refresh_hud()
	ui.show_banner(_building_interior.display_name, 1.2)
	ui.fade_in(0.3)
	_transitioning = false
	player.input_locked = false


## 离开当前建筑，回到门口。
func exit_building() -> void:
	if not indoor or current_building.is_empty() or _transitioning:
		return
	_transitioning = true
	player.input_locked = true
	ui.fade_out(0.3)
	await get_tree().create_timer(0.32).timeout

	indoor = false
	current_building = ""
	time.leave_location()
	_clear_building_interior()
	_set_outdoor_visible(true)
	_remove_indoor_walls()

	player.position = _outdoor_position + Vector2(0, 22)
	player.facing = "down"
	player.z_index = 0

	_apply_camera_zoom()
	camera.limit_left = _saved_camera_limits.position.x
	camera.limit_top = _saved_camera_limits.position.y
	camera.limit_right = _saved_camera_limits.end.x
	camera.limit_bottom = _saved_camera_limits.end.y
	camera.position = player.position
	camera.reset_smoothing()

	_update_day_light()
	ui.refresh_hud()
	ui.fade_in(0.3)
	player.input_locked = false
	_transitioning = false


## 创建室内家具节点（直接挂在 Farm 下，参与 Y-sort）。
func _spawn_interior_props() -> void:
	if _building_interior == null:
		return
	for entry: Dictionary in _building_interior.get_props():
		var prop := InteriorPropScript.new()
		prop.z_index = 0
		add_child(prop)
		var offset := Vector2(
			float(entry.get("x", 0)) * TILE,
			float(entry.get("y", 0)) * TILE)
		prop.setup(str(entry.get("kind", "crate")), _building_interior.origin + offset,
			float(entry.get("w", 0)))
		_building_props.append(prop)


func _clear_building_interior() -> void:
	for prop: InteriorProp in _building_props:
		if is_instance_valid(prop):
			remove_child(prop)
			prop.queue_free()
	_building_props.clear()
	if _building_interior != null:
		remove_child(_building_interior)
		_building_interior.queue_free()
		_building_interior = null


## 自宅已摆放家具：按格子生成 InteriorProp 节点（直接挂在 Farm 下，参与 Y-sort）。
## 锚点取家具格位底边中点，地毯压到 z=-1，避免站上去时盖住角色。
func _refresh_house_props() -> void:
	_clear_house_props()
	if not indoor or not current_building.is_empty() or _interior == null:
		return
	for entry: Dictionary in placed_furniture:
		var definition := DB.get_furniture(str(entry.get("id", "")))
		if definition.is_empty():
			continue
		var size: Array = definition.get("size", [1, 1])
		var w := maxi(1, int(size[0]))
		var h := maxi(1, int(size[1]))
		var kind := str(definition.get("icon", "plant"))
		var prop := InteriorPropScript.new()
		prop.z_index = -1 if kind == "rug" else 0
		add_child(prop)
		var anchor := _interior.origin + Vector2(
			(float(int(entry.get("gx", 0))) + float(w) * 0.5) * TILE,
			(float(int(entry.get("gy", 0))) + float(h)) * TILE - 2.0)
		prop.setup(kind, anchor, float(w))
		_house_props.append(prop)


func _clear_house_props() -> void:
	for prop: InteriorProp in _house_props:
		if is_instance_valid(prop):
			remove_child(prop)
			prop.queue_free()
	_house_props.clear()


## 室内家具交互分发。
func _interact_building_prop(action: String) -> void:
	match action:
		"exit_building":
			exit_building()
		"shop":
			ui.open_shop()
		"clinic":
			ui.open_clinic()
		"library":
			ui.open_library()
		"museum":
			ui.open_museum()
		"feed_coop":
			feed_building("coop")
		"feed_barn":
			feed_building("barn")
		"worker":
			_toggle_worker()
		_:
			ui.toast("这里暂时没有可用的功能")


func _hotbar_to_save() -> Array:
	var result: Array = []
	for index in mini(10, inventory.slots.size()):
		var slot := inventory.get_slot(index)
		result.append(str(slot.get("item_id", "")))
	return result


func load_game() -> bool:
	if not Save.has_save():
		return false
	var data := Save.load_data()
	if data.is_empty():
		return false

	var world: Dictionary = data.get("world", {})
	var player_data: Dictionary = data.get("player", {})
	player_name = str(player_data.get("name", "农夫"))
	if player_name.is_empty():
		player_name = "农夫"
	farm_name = str(data.get("farm_name", "阳光牧场"))
	if farm_name.is_empty():
		farm_name = "阳光牧场"
	_update_farm_sign()

	time.from_save({
		"day": world.get("day", data.get("day", 1)),
		"season": world.get("season", data.get("season", "spring")),
		"year": world.get("year", data.get("year", 1)),
		"weather": world.get("weather", data.get("weather", "sunny")),
		"time_minutes": world.get("time_minutes", data.get("time_minutes", 360)),
		"location": "farm",
		"speed": data.get("speed", "normal"),
	})
	_sync_prop_season(str(time.season))
	camera_zoom_index = int(world.get("camera_zoom_index", DEFAULT_CAMERA_ZOOM_INDEX))
	_apply_camera_zoom()
	if map_ui != null:
		map_ui.import_fog(str(world.get("fog_png", "")))

	play_time = float(data.get("play_time_seconds", 0.0))
	money = maxi(0, int(player_data.get("money", data.get("money", 500))))
	unlock_book = data.get("unlock_book", {})
	museum_donations.clear()
	var donations: Variant = data.get("museum_donations", [])
	if donations is Array:
		for entry: Variant in donations:
			museum_donations.append(str(entry))

	home_storage.clear()
	var stored: Variant = data.get("home_storage", [])
	if stored is Array:
		for stack: Variant in stored:
			if stack is Dictionary:
				home_storage.append((stack as Dictionary).duplicate(true))
	fridge_storage.clear()
	var chilled: Variant = data.get("fridge_storage", [])
	if chilled is Array:
		for stack: Variant in chilled:
			if stack is Dictionary:
				fridge_storage.append((stack as Dictionary).duplicate(true))

	mail_pending.clear()
	var pending_mail: Variant = data.get("mail_pending", [])
	if pending_mail is Array:
		for entry: Variant in pending_mail:
			mail_pending.append(str(entry))
	mail_read.clear()
	var read_mail_data: Variant = data.get("mail_read", [])
	if read_mail_data is Array:
		for entry: Variant in read_mail_data:
			mail_read.append(str(entry))
	cellar_items.clear()
	var cellar_data: Variant = data.get("cellar_items", [])
	if cellar_data is Array:
		for entry: Variant in cellar_data:
			if entry is Dictionary:
				cellar_items.append((entry as Dictionary).duplicate(true))
	_refresh_mail()

	var position: Dictionary = player_data.get("position", data.get("player_position", {}))
	player.from_save({
		"x": float(position.get("x", SPAWN.x)),
		"y": float(position.get("y", SPAWN.y)),
		"facing": "down",
		"stamina": float(player_data.get("stamina", data.get("stamina", player.stamina_max))),
		"max_stamina": float(player_data.get("max_stamina", data.get("max_stamina", player.stamina_max))),
		"hp": int(player_data.get("hp", player.max_hp)),
		"max_hp": int(player_data.get("max_hp", player.max_hp)),
	})

	var appearance: Variant = player_data.get("appearance", data.get("player_appearance", {}))
	_apply_appearance(appearance if appearance is Dictionary else {})

	# 背包：新结构是 {capacity, items, hotbar}，旧结构直接是数组
	var inv_data: Variant = data.get("inventory", [])
	if inv_data is Dictionary:
		inventory.from_save((inv_data as Dictionary).get("items", []))
	elif inv_data is Array:
		inventory.from_save(inv_data)

	if tutorial != null:
		tutorial.from_save({
			"tutorial_step": data.get("tutorial_step", 0),
			"tutorial_completed": data.get("tutorial_completed", false),
		})
	var mine_data: Dictionary = data.get("mine", {})
	mine_deepest = int(mine_data.get("deepest_floor", 0))
	mine_ores = mine_data.get("collected_ores", {}).duplicate()
	mine_gems = mine_data.get("collected_gems", {}).duplicate()

	accessories_owned = data.get("accessories_owned", [])
	var equipped: Variant = data.get("accessories_equipped", {})
	accessories_equipped = equipped.duplicate(true) if equipped is Dictionary else {
		"head": "", "face": "", "neck": "", "hand": "", "back": "",
	}

	var stats: Dictionary = data.get("stats", {})
	total_earned = int(stats.get("total_earned", 0))
	crops_harvested = int(stats.get("crops_harvested", 0))
	fish_caught = int(stats.get("fish_caught", 0))
	ore_mined = int(stats.get("ore_mined", 0))
	days_played = int(stats.get("days_played", 0))
	achievements_unlocked.clear()
	var unlocked_data: Variant = data.get("achievements_unlocked", [])
	if unlocked_data is Array:
		for entry: Variant in unlocked_data:
			achievements_unlocked.append(str(entry))
	hot_spring_used_today = bool(data.get("hot_spring_used_today", false))
	books_read.clear()
	var books_data: Variant = data.get("books_read", [])
	if books_data is Array:
		for entry: Variant in books_data:
			books_read.append(str(entry))
	last_book_day = int(data.get("last_book_day", -1))
	hired_worker = bool(data.get("hired_worker", false))
	placed_furniture.clear()
	var furniture_data: Variant = data.get("placed_furniture", [])
	if furniture_data is Array:
		for entry: Variant in furniture_data:
			if entry is Dictionary:
				placed_furniture.append((entry as Dictionary).duplicate(true))
	if _interior != null:
		_interior.set_furniture(placed_furniture)
		_refresh_house_props()
	_achievements_check(false)

	_reset_tiles()
	for entry: Variant in data.get("farm_tiles", []):
		if not (entry is Dictionary):
			continue
		var key := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		var tile: Variant = farm_tiles.get(key)
		if tile != null:
			tile.from_save(entry)

	_clear_beehives()
	var apiary: Variant = data.get("apiary", {})
	if apiary is Dictionary:
		for entry: Variant in (apiary as Dictionary).get("hives", []):
			if entry is Dictionary:
				_spawn_hive_from_save(entry)

	_clear_fruit_trees()
	for entry: Variant in data.get("fruit_trees_planted", []):
		if entry is Dictionary:
			_spawn_tree_from_save(entry)

	_clear_machines()
	for entry: Variant in data.get("machines", []):
		if entry is Dictionary:
			_spawn_machine_from_save(entry)

	_apply_quests_buildings(data.get("quests", {}), data.get("buildings", {}))

	mounts.clear()
	var mounts_data: Variant = data.get("mounts", [])
	if mounts_data is Array:
		for entry: Variant in mounts_data:
			if entry is Dictionary:
				mounts.append((entry as Dictionary).duplicate(true))
	_build_mount_nodes()
	_refresh_mount_buildings()

	_clear_animals()
	for entry: Variant in data.get("animal_list", []):
		if entry is Dictionary:
			_spawn_animal_from_save(entry)

	_clear_pets()
	_clear_wild_critters()
	var houses_data: Variant = data.get("pet_houses", [])
	if houses_data is Array:
		for entry: Variant in houses_data:
			if entry is Dictionary:
				var house_data: Dictionary = (entry as Dictionary).duplicate(true)
				pet_houses.append(house_data)
				_spawn_pet_house_node(house_data)
	# 新 schema 用 pets，旧版用 pet_list，两个都读
	for entry: Variant in data.get("pets", data.get("pet_list", [])):
		if entry is Dictionary:
			_spawn_pet_from_save(entry)
	_pet_serial = pets.size()
	_pet_house_serial = pet_houses.size()

	var building_data: Dictionary = data.get("building", {})
	for building: String in ["coop", "barn"]:
		var entry: Variant = building_data.get(building, {})
		building_fed[building] = bool((entry as Dictionary).get("fed_today", false)) if entry is Dictionary else false

	_apply_npc_states(data.get("npc_states", {}), data.get("festivals_done", []))
	spouse_id = str(data.get("spouse", ""))
	if not spouse_id.is_empty():
		var spouse := _find_npc(spouse_id)
		if spouse != null and _interior != null:
			_interior.set_spouse(spouse.display_name, spouse.look)
	var home: Dictionary = data.get("home", {})
	home_level = clampi(int(home.get("level", 1)), 1, 3)
	bath_used_today = bool(home.get("bath_used_today", false))
	if _interior != null:
		_interior.set_level(home_level)
	_update_npc_schedule()

	selected_index = 0
	ui.refresh_hud()
	ui.refresh_inventory()
	return true


func request_save() -> void:
	if ui.is_modal_open():
		return
	save_game(false)


func request_load() -> void:
	if _transitioning:
		return
	if not load_game():
		ui.toast("没有找到存档", "bad")
		return
	ui.toast("已读取存档", "good")


## 导出当前槽位到指定文件（先保存一次，确保内容最新）。
func export_current_save(path: String) -> bool:
	save_game(true)
	var ok := Save.export_slot(Save.get_slot(), path)
	if ok:
		ui.toast("存档已导出", "good")
	else:
		ui.toast("导出失败，请检查路径", "bad")
	return ok


## 导出指定槽位（若导出当前游戏槽位，先保存一次）。
func export_save_slot(slot: int, path: String) -> bool:
	if slot == Save.get_slot():
		save_game(true)
	var ok := Save.export_slot(slot, path)
	if ok:
		ui.toast("存档槽 %d 已导出" % slot, "good")
	else:
		ui.toast("导出失败：存档槽 %d 为空或路径不可写" % slot, "bad")
	return ok


## 导入到指定槽位；若目标是当前槽位，则立即读档。
func import_save_slot(path: String, slot: int) -> bool:
	var data := Save.import_slot(path, slot)
	if data.is_empty():
		ui.toast("导入失败：不是有效的存档文件", "bad")
		return false
	if slot == Save.get_slot():
		if ui.is_modal_open():
			ui.close_modal()
		load_game()
		ui.toast("存档槽 %d 已导入并读取" % slot, "good")
	else:
		ui.toast("已导入到存档槽 %d" % slot, "good")
	return true


## 从指定文件导入到当前槽位并立即读取。
func import_save_from(path: String) -> bool:
	return import_save_slot(path, Save.get_slot())


func request_new_game() -> void:
	if _transitioning:
		return
	var dialog := ConfirmationDialog.new()
	dialog.title = "重新开始"
	dialog.dialog_text = "确定要重新开始吗？当前进度会被覆盖。"
	dialog.ok_button_text = "重新开始"
	dialog.cancel_button_text = "取消"
	dialog.add_theme_font_override("font", ui.font)
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		Save.delete_save()
		start_new_game(true)
		ui.toast("新的农场生活开始了", "good")
	)
	dialog.popup_centered()


# ============================================================
# 地主循环
# ============================================================

func _process(delta: float) -> void:
	if not _started:
		return

	# 相机跟随玩家（室外 / 矿洞）；室内保持整间房固定构图。
	# 震动走 camera.offset，不受影响。
	if camera != null and player != null and not indoor:
		camera.position = player.position

	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	# 矿洞光圈跟随玩家
	if _mine_light != null and is_instance_valid(_mine_light) and player != null:
		_mine_light.position = player.position + Vector2(0, -10)
	_thumb_timer -= delta
	if _thumb_timer <= 0.0:
		_thumb_timer = 3.0
		if not ui.is_modal_open() and not _transitioning and not indoor and not in_mine:
			_capture_thumbnail()
	if in_mine and not _transitioning and not ui.is_modal_open() \
			and player != null and player.hp > 0:
		_check_mine_traps()

	_npc_timer -= delta
	if _npc_timer <= 0.0:
		_npc_timer = 1.0
		_update_npc_schedule()

	for animal: FarmAnimal in animals:
		if animal == riding_animal:
			continue
		animal.wander(delta, PASTURE.grow(-14.0))

	_dog_chase_cooldown = maxf(0.0, _dog_chase_cooldown - delta)
	for pet: FarmPet in pets:
		if pet.missing or indoor:
			continue
		pet.basking = pet.pet_type in ["turtle", "reptile"] \
			and str(time.weather) == "sunny"
		var house_node := _find_house_node(pet.house_id)
		var anchor := house_node.get_anchor() if house_node != null \
			else HOUSE_BASE + Vector2(0, 24)
		_update_pet_visual_flags(pet, house_node)
		if pet.released:
			if pet.pet_type == "bird":
				pet.position = player.position + Vector2(10, -30)
			else:
				pet.wander(delta, Rect2(anchor - Vector2(28, 16), Vector2(56, 32)))
			if pet.tick_release(delta):
				pet.position = anchor
				ui.toast("%s回到了栖息地" % pet.get_display_name(), "good")
			continue
		if pet.is_companion() and pet.follows_player():
			pet.follow(delta, player.position)
		elif pet.is_companion():
			pet.wander(delta, Rect2(anchor - Vector2(44, 24), Vector2(88, 56)))
		else:
			pet.idle_in_house(delta, anchor)

	# 狗赶跑灌木里的小动物（好感 ≥80 的视觉表现）
	if _dog_chase_cooldown <= 0.0 and not indoor and not in_mine:
		for pet: FarmPet in pets:
			if pet.pet_type != "dog" or pet.missing \
					or pet.friendship < float(DB.get_pet_config().get("dog_chase_friendship", 80)):
				continue
			for prop: WorldProp in props:
				if prop.kind == "bush" and prop.position.distance_to(pet.position) <= 64.0:
					prop.trample()
					_dog_chase_cooldown = float(
						DB.get_pet_config().get("dog_chase_cooldown", 30))
					AudioManager.play_sfx("click")
					ui.toast("%s赶跑了灌木里的小动物" % pet.get_display_name(), "good")
					break
			break

	# 走过草丛/灌木：触发 0.3 秒抖动
	if not indoor and not in_mine and player != null and player.is_moving():
		for prop: WorldProp in props:
			if prop.kind != "bush":
				continue
			if prop.trample_timer > 0.0:
				continue
			if prop.position.distance_to(player.position) <= 20.0:
				prop.trample()

	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.25
		ui.refresh_hud()

	if not ui.is_modal_open() and not _transitioning:
		play_time += delta
		_track_tutorial_move()

	# 输入缓冲倒计时，到点后执行
	if _input_buffer > 0.0:
		_input_buffer -= delta
		if _input_buffer <= 0.0 and _buffered_tile.x >= 0 and not _transitioning 				and not ui.is_modal_open():
			var pending := _buffered_tile
			_buffered_tile = Vector2i(-1, -1)
			_use_tile(pending)

	_update_wild_critters(delta)
	if not _placing_pet_house_id.is_empty():
		queue_redraw()
	_update_riding(delta)
	_update_prompt()
	_update_day_light()
	_update_farm_sign_label()
	_update_bgm()


func _track_tutorial_move() -> void:
	if tutorial == null or tutorial.finished:
		return
	if tutorial.get_current_id() != "move":
		return
	_tutorial_move_distance += player.position.distance_to(_last_player_position)
	_last_player_position = player.position
	if _tutorial_move_distance >= 64.0:
		tutorial.notify("move")


func _update_bgm() -> void:
	if AudioManager == null:
		return
	var is_night := time.get_display_minutes() >= 20 * 60
	var location := "mine" if time.location_id == "mine" else time.location_id
	var key := AudioManager.resolve_bgm_key(time.season, is_night, location)
	AudioManager.play_bgm(key)


func _update_prompt() -> void:
	if ui.is_modal_open() or _transitioning:
		ui.set_prompt("")
		return
	if in_mine:
		if mine_floor == null:
			ui.set_prompt("")
			return
		var stairs_world := Vector2(mine_floor.stairs_pos) * TILE + Vector2(16, 16)
		if player.position.distance_to(stairs_world) <= 1.8 * TILE:
			ui.set_prompt("按 E 下一层")
		elif player.position.distance_to(mine_floor.spawn_position) <= 1.8 * TILE:
			ui.set_prompt("按 E 离开矿洞")
		else:
			ui.set_prompt("点击石头敲矿 · 选中剑攻击 · E 下楼")
		return

	if indoor:
		if not current_building.is_empty() and _building_interior != null:
			var building_near := _building_interior.get_interact(player.position)
			ui.set_prompt(str(building_near.get("text", "")))
			return
		var indoor_near := _interior.get_interact(player.position)
		ui.set_prompt(str(indoor_near.get("text", "")))
		return
	var near := _nearest_interact()
	ui.set_prompt(str(near.get("text", "")))


func _update_day_light() -> void:
	# 室内：暖色 CanvasModulate（规范：室内光源偏暖黄），夜晚更偏橙红
	if indoor:
		var indoor_display := time.get_display_minutes()
		var indoor_night := indoor_display >= 19 * 60 or indoor_display < 6 * 60
		day_light.color = Color(0.94, 0.84, 0.78) if indoor_night \
			else Color(1.0, 0.95, 0.86)
		return
	# 矿洞：整体压暗成冷蓝灰，玩家周围由 MineLight 提供暖光圈（规范：低照度 + 光圈）
	if in_mine:
		day_light.color = Color(0.58, 0.62, 0.78)
		return
	var display := time.get_display_minutes()
	# 色彩规范：白天暖阳、黄昏橙紫、夜晚深蓝；过渡全部有色相偏移，不用纯白
	var night := Color(0.46, 0.48, 0.72)
	var dawn := Color(0.62, 0.58, 0.84)
	var sunrise := Color(1.0, 0.88, 0.78)
	var day := Color(1.0, 0.985, 0.95)
	var afternoon := Color(1.0, 0.86, 0.72)
	var dusk := Color(0.98, 0.74, 0.70)
	var evening := Color(0.60, 0.56, 0.80)
	var color := day
	if display < 300:
		color = night.lerp(dawn, clampf(float(display) / 300.0, 0.0, 1.0))
	elif display < 420:
		color = dawn.lerp(sunrise, float(display - 300) / 120.0)
	elif display < 480:
		color = sunrise.lerp(day, float(display - 420) / 60.0)
	elif display < 1020:
		color = day
	elif display < 1140:
		color = day.lerp(afternoon, float(display - 1020) / 120.0)
	elif display < 1260:
		color = afternoon.lerp(dusk, float(display - 1140) / 120.0)
	elif display < 1320:
		color = dusk.lerp(evening, float(display - 1260) / 60.0)
	else:
		color = evening.lerp(night, float(display - 1320) / 120.0)
	# 天气色调：雨天偏灰蓝、雪天偏冷白（规范：天气色彩）
	var weather := str(time.weather)
	match weather:
		"rain":
			color = color.lerp(Color(0.80, 0.86, 0.94), 0.35)
		"storm":
			color = color.lerp(Color(0.70, 0.76, 0.86), 0.45)
		"snow", "blizzard":
			color = color.lerp(Color(0.92, 0.95, 1.0), 0.25)
		_:
			pass
	day_light.color = color
	var is_night := display >= 19 * 60 or display < 6 * 60
	for prop: WorldProp in props:
		if prop.kind in WorldProp.BUILDING_KINDS:
			prop.set_night(is_night)
		elif prop.kind in ["bush", "blossom_tree"]:
			# 花丛/花树夜晚花叶闭合（规范：花昼夜开合）
			prop.is_night = is_night
			prop.queue_redraw()


# ============================================================
# 输入
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key == KEY_ESCAPE:
			if not _placing_pet_house_id.is_empty():
				cancel_move_pet_house()
				return
			if ui.get_modal() == "minigame":
				return
			if ui.is_modal_open():
				ui.close_modal()
			return
		if key == KEY_F5:
			request_save()
			return
		if key == KEY_F9:
			request_load()
			return
		if key == KEY_EQUAL or key == KEY_KP_ADD:
			adjust_camera_zoom(1)
			return
		if key == KEY_MINUS or key == KEY_KP_SUBTRACT:
			adjust_camera_zoom(-1)
			return

		# 钓鱼小游戏中只允许 Esc（由小游戏自己处理）
		if ui.get_modal() == "minigame":
			return

		if key == KEY_I or key == KEY_TAB:
			if ui.is_modal_open():
				ui.close_modal()
			else:
				ui.open_inventory()
			return
		if key == KEY_H:
			ui.toggle_help()
			return
		if key == KEY_C:
			ui.toggle_collection()
			return
		if ui.is_modal_open():
			return

		if key == KEY_U and indoor:
			_try_upgrade_home()
			return
		if key == KEY_G:
			_gift_nearby_npc()
			return
		if key == KEY_R:
			toggle_ride()
			return
		if key == KEY_K:
			open_ride_cargo()
			return
		if key == KEY_P:
			ui.open_pet_panel("")
			return
		if key == KEY_E:
			# 对话逐字显示时，E 先跳过打字
			if ui.skip_dialogue_typing():
				return
			_interact()
			return
		if key == KEY_F:
			_try_fishing()
			return
		if key == KEY_SPACE:
			_buffer_use(player.get_facing_tile())
			return
		if key >= KEY_0 and key <= KEY_9:
			var index: int = (key - KEY_0 + 9) % 10
			select_index(index)
			return

	if event is InputEventMouseButton:
		if ui.is_modal_open():
			return
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if not _placing_pet_house_id.is_empty():
				_place_pet_house_at(_mouse_tile())
				return
			if in_mine:
				_handle_mine_click()
				return
			_buffer_use(_mouse_tile())
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			select_index(posmod(selected_index - 1, mini(10, inventory.slots.size())))
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			select_index(posmod(selected_index + 1, mini(10, inventory.slots.size())))
			return


## 工具输入缓冲：短时间内的连续点击排队，避免丢输入。
func _buffer_use(tile_position: Vector2i) -> void:
	if _use_tile_immediate(tile_position):
		return
	_buffered_tile = tile_position
	_input_buffer = INPUT_BUFFER_TIME


func _use_tile_immediate(tile_position: Vector2i) -> bool:
	_use_tile(tile_position)
	return true


func _mouse_tile() -> Vector2i:
	var world := get_global_mouse_position()
	return Vector2i(floori(world.x / TILE), floori(world.y / TILE))


func select_index(index: int) -> void:
	if index < 0 or index >= inventory.slots.size():
		return
	selected_index = index
	ui.refresh_hotbar()
	if ui.get_modal() == "inventory":
		ui.refresh_inventory()


func get_selected_item() -> Dictionary:
	return inventory.get_slot(selected_index)


# ============================================================
# 互动
# ============================================================

func _nearest_interact() -> Dictionary:
	if player.riding:
		var doors := [
			{"point": BED_POINT, "radius": 62.0, "name": "自宅"},
			{"point": SHOP_POINT, "radius": 78.0, "name": "杂货铺"},
			{"point": COOP_DOOR_POINT, "radius": 54.0, "name": "鸡舍"},
			{"point": BARN_DOOR_POINT, "radius": 56.0, "name": "畜棚"},
			{"point": MINE_ENTRANCE_POINT, "radius": 62.0, "name": "矿洞"},
			{"point": LIBRARY_POINT, "radius": 54.0, "name": "图书馆"},
			{"point": CLINIC_POINT, "radius": 54.0, "name": "诊所"},
			{"point": MUSEUM_POINT, "radius": 64.0, "name": "博物馆"},
			{"point": WORKER_HUT_POINT, "radius": 54.0, "name": "雇工小屋"},
		]
		for door: Dictionary in doors:
			if player.position.distance_to(door["point"]) <= float(door["radius"]):
				return {
					"id": "dismount", "position": player.position, "radius": 0.0,
					"text": "请先下坐骑再进入%s · 按 E 下坐骑" % str(door["name"]),
				}
		return {
			"id": "dismount", "position": player.position, "radius": 0.0,
			"text": "按 E 下坐骑 · Shift 冲刺",
		}
	var best := {}
	var best_distance := INF

	# 停放中的坐骑：靠近按 E 骑乘
	for mount_id: Variant in mount_nodes.keys():
		var mount_node: RideMount = mount_nodes[mount_id]
		if mount_node == null or not is_instance_valid(mount_node) or mount_node.ridden:
			continue
		var mount_distance := player.position.distance_to(mount_node.position)
		if mount_distance <= 48.0 and mount_distance < best_distance:
			best_distance = mount_distance
			best = {
				"id": "mount",
				"mount_id": str(mount_id),
				"position": mount_node.position,
				"radius": 48.0,
				"text": "按 E 骑乘%s" % mount_node.mount_name,
			}

	# 蜂箱
	for hive: BeeHive in beehives:
		var hive_distance := player.position.distance_to(hive.position + Vector2(0, -8))
		if hive_distance <= 56.0 and hive_distance < best_distance:
			best_distance = hive_distance
			var hive_text := "按 E 查看蜂箱"
			if hive.escaped:
				hive_text = "蜂群已逃散 · 按 E 查看"
			elif hive.diseased:
				hive_text = "蜂群生病了 · 按 E 治疗"
			elif not hive.has_queen:
				hive_text = "空蜂箱 · 按 E 放入蜂王"
			elif hive.days_since_harvest >= hive.get_interval_days():
				hive_text = "按 E 收蜜（健康 %d）" % int(hive.health)
			else:
				hive_text = "蜂箱 · 还需 %d 天 · 健康 %d" % [
					hive.get_interval_days() - hive.days_since_harvest, int(hive.health)
				]
			best = {
				"id": "beehive",
				"hive": hive,
				"position": hive.position,
				"radius": 56.0,
				"text": hive_text,
			}

	# 果树（摘果）
	for tree: FruitTree in fruit_trees:
		if not tree.ripe:
			continue
		var tree_distance := player.position.distance_to(tree.position + Vector2(0, -16))
		if tree_distance <= 62.0 and tree_distance < best_distance:
			best_distance = tree_distance
			best = {
				"id": "fruit_tree",
				"tree": tree,
				"position": tree.position,
				"radius": 62.0,
				"text": "按 E 摘取%s" % tree.get_fruit_name(),
			}

	# 宠物（摸 / 收礼物）
	for pet: FarmPet in pets:
		if pet.missing:
			continue
		var pet_distance := player.position.distance_to(pet.position)
		if pet_distance <= 52.0 and pet_distance < best_distance:
			best_distance = pet_distance
			best = {
				"id": "pet",
				"pet": pet,
				"position": pet.position,
				"radius": 52.0,
				"text": "按 E 查看%s · 好感 %d" % [
					pet.get_display_name(), int(pet.friendship),
				],
			}

	# 离得最近的动物优先（摸 / 收产物）
	for animal: FarmAnimal in animals:
		var animal_distance := player.position.distance_to(animal.position)
		if animal_distance <= 56.0 and animal_distance < best_distance:
			best_distance = animal_distance
			var action := "摸摸"
			if animal.produce_ready:
				action = "收取" + animal.get_product_name()
			best = {
				"id": "animal",
				"animal": animal,
				"position": animal.position,
				"radius": 56.0,
				"text": "按 E %s · %s（好感 %d）" % [
					action, animal.get_display_name(), int(animal.friendship),
				],
			}

	# 加工机器
	for machine: ProcessingMachine in machines:
		var machine_distance := player.position.distance_to(machine.position + Vector2(0, -10))
		if machine_distance <= 54.0 and machine_distance < best_distance:
			best_distance = machine_distance
			var machine_text := "按 E 使用%s" % machine.get_display_name()
			if machine.is_ready():
				machine_text = "%s · 可取出" % machine.get_display_name()
			elif machine.is_working():
				machine_text = "%s · 制作中（%s）" % [
					machine.get_display_name(), _duration_text(machine.remaining_minutes()),
				]
			best = {
				"id": "machine",
				"machine": machine,
				"position": machine.position,
				"radius": 54.0,
				"text": machine_text,
			}

	# 村民
	for npc: VillageNPC in npcs:
		if not npc.visible:
			continue
		var npc_distance := player.position.distance_to(npc.position)
		if npc_distance <= 48.0 and npc_distance < best_distance:
			best_distance = npc_distance
			var npc_prompt := "按 E 与%s聊天 · G 送礼" % npc.display_name
			if can_propose(npc):
				npc_prompt = "按 E 向%s求婚（蓝色羽毛）" % npc.display_name
			best = {
				"id": "npc",
				"npc": npc,
				"position": npc.position,
				"radius": 48.0,
				"text": npc_prompt,
			}

	# 博物馆
	var museum_distance := player.position.distance_to(MUSEUM_POINT)
	if museum_distance <= 64.0 and museum_distance < best_distance:
		best_distance = museum_distance
		best = {
			"id": "enter_museum",
			"position": MUSEUM_POINT,
			"radius": 64.0,
			"text": "按 E 进入博物馆",
		}

	# 雇工小屋
	var worker_distance := player.position.distance_to(WORKER_HUT_POINT)
	if worker_distance <= 52.0 and worker_distance < best_distance:
		best_distance = worker_distance
		best = {
			"id": "enter_worker_hut",
			"position": WORKER_HUT_POINT,
			"radius": 52.0,
			"text": "按 E 进入雇工小屋",
		}

	# 图书馆
	var library_distance := player.position.distance_to(LIBRARY_POINT)
	if library_distance <= 56.0 and library_distance < best_distance:
		best_distance = library_distance
		best = {
			"id": "enter_library",
			"position": LIBRARY_POINT,
			"radius": 56.0,
			"text": "按 E 进入图书馆",
		}

	# 诊所
	var clinic_distance := player.position.distance_to(CLINIC_POINT)
	if clinic_distance <= 56.0 and clinic_distance < best_distance:
		best_distance = clinic_distance
		best = {
			"id": "enter_clinic",
			"position": CLINIC_POINT,
			"radius": 56.0,
			"text": "按 E 进入诊所",
		}

	# 温泉
	var spring_distance := player.position.distance_to(HOT_SPRING_POINT)
	if spring_distance <= 64.0 and spring_distance < best_distance:
		best_distance = spring_distance
		best = {
			"id": "hot_spring",
			"position": HOT_SPRING_POINT,
			"radius": 64.0,
			"text": "按 E 泡温泉（每天恢复一次体力）",
		}

	# 邮箱
	var mailbox_distance := player.position.distance_to(MAILBOX_POINT)
	if mailbox_distance <= 48.0 and mailbox_distance < best_distance:
		best_distance = mailbox_distance
		best = {
			"id": "mailbox",
			"position": MAILBOX_POINT,
			"radius": 48.0,
			"text": "按 E 查看邮箱",
		}

	# 公告板
	var board_distance := player.position.distance_to(NOTICE_BOARD_POINT)
	if board_distance <= 54.0 and board_distance < best_distance:
		best_distance = board_distance
		best = {
			"id": "notice_board",
			"position": NOTICE_BOARD_POINT,
			"radius": 54.0,
			"text": "按 E 查看村镇公告板",
		}

	# 节日会场
	var festival := get_active_festival()
	if not festival.is_empty():
		var festival_point := FESTIVAL_POINT
		var festival_distance := player.position.distance_to(festival_point)
		if festival_distance <= 56.0 and festival_distance < best_distance:
			best_distance = festival_distance
			var done := is_festival_done(festival)
			best = {
				"id": "festival",
				"festival": festival,
				"position": festival_point,
				"radius": 56.0,
				"text": "按 E %s%s" % [
					"查看" if done else "参加", str(festival.get("name", "节日")),
				],
			}

	var points := [
		{"id": "enter_house", "position": BED_POINT, "radius": 62.0, "text": "按 E 进屋"},
		{"id": "enter_shop", "position": SHOP_POINT, "radius": 78.0, "text": "按 E 进入杂货铺"},
		{"id": "enter_coop", "position": COOP_DOOR_POINT, "radius": 54.0, "text": "按 E 进入鸡舍"},
		{"id": "enter_barn", "position": BARN_DOOR_POINT, "radius": 56.0, "text": "按 E 进入畜棚"},
		{"id": "bin", "position": BIN_POINT, "radius": 58.0, "text": "按 E 把农产品全部卖掉"},
		{"id": "mirror", "position": MIRROR_POINT, "radius": 54.0, "text": "按 E 照镜子（修改外观）"},
		{"id": "mine", "position": MINE_ENTRANCE_POINT, "radius": 62.0, "text": "按 E 进入矿洞"},
		{"id": "feed_coop", "position": COOP_POINT, "radius": 64.0, "text": _feed_prompt("coop")},
		{"id": "feed_barn", "position": BARN_POINT, "radius": 64.0, "text": _feed_prompt("barn")},
	]
	if get_building_level("stable") >= 1:
		points.append({
			"id": "stable", "position": STABLE_POINT, "radius": 62.0,
			"text": "按 E 打开马厩",
		})
	if get_building_level("ostrich_house") >= 1:
		points.append({
			"id": "ostrich_house", "position": OSTRICH_HOUSE_POINT, "radius": 62.0,
			"text": "按 E 打开鸵鸟舍",
		})
	if get_building_level("bike_shed") >= 1:
		points.append({
			"id": "bike_shed", "position": BIKE_SHED_POINT, "radius": 62.0,
			"text": "按 E 打开自行车棚",
		})
	for point: Dictionary in points:
		var distance := player.position.distance_to(point["position"])
		if distance <= float(point["radius"]) and distance < best_distance:
			best_distance = distance
			best = point

	var water_distance := _distance_to_water()
	if water_distance <= 1.6 * TILE and water_distance < best_distance:
		best = {
			"id": "water",
			"position": Vector2.ZERO,
			"radius": 0.0,
			"text": "按 E 或 F 钓鱼",
		}
	return best


func _distance_to_water() -> float:
	var rect := Rect2(
		POND_RECT.position.x * TILE, POND_RECT.position.y * TILE,
		POND_RECT.size.x * TILE, POND_RECT.size.y * TILE
	)
	var closest := Vector2(
		clampf(player.position.x, rect.position.x, rect.end.x),
		clampf(player.position.y, rect.position.y, rect.end.y)
	)
	return player.position.distance_to(closest)


func _interact() -> void:
	if player.riding:
		# 设计规范：骑乘中与村民对话会自动下坐骑
		var npc_near: VillageNPC = null
		for npc: VillageNPC in npcs:
			if npc.visible and player.position.distance_to(npc.position) <= 48.0:
				npc_near = npc
				break
		dismount_mount(true)
		if npc_near != null:
			if can_propose(npc_near):
				propose_to_npc(npc_near)
			else:
				talk_to_npc(npc_near)
		return
	if in_mine:
		if mine_floor == null:
			return
		var stairs_world := Vector2(mine_floor.stairs_pos) * TILE + Vector2(16, 16)
		if player.position.distance_to(stairs_world) <= 1.8 * TILE:
			descend_mine()
			return
		if player.position.distance_to(mine_floor.spawn_position) <= 1.8 * TILE:
			exit_mine()
			return
		ui.toast("走到楼梯旁按 E 下一层，回到入口按 E 离开")
		return

	if indoor:
		# 坐着时按 E 起身
		if player.sitting:
			player.set_sitting(false)
			ui.toast("站起来了")
			return
		# 通用建筑室内：家具交互
		if not current_building.is_empty() and _building_interior != null:
			var building_near := _building_interior.get_interact(player.position)
			var building_id := str(building_near.get("id", ""))
			if building_id.is_empty():
				ui.toast("附近没有可以互动的东西")
				return
			_interact_building_prop(building_id)
			return
		# 手持家具 → 摆放在脚下
		var held_slot := inventory.get_slot(selected_index)
		if str(held_slot.get("category", "")) == "furniture":
			place_furniture_from_inventory(selected_index)
			return
		# 靠近椅子 → 坐下
		if _try_sit_on_nearby_chair():
			return
		var indoor_near := _interior.get_interact(player.position)
		var indoor_id := str(indoor_near.get("id", ""))
		if not indoor_id.is_empty():
			_interior.interact(indoor_id)
			return
		if pick_up_nearby_furniture():
			return
		ui.toast("附近没有可以互动的东西")
		return

	var near := _nearest_interact()
	match str(near.get("id", "")):
		"enter_shop":
			enter_building("shop")
		"enter_clinic":
			enter_building("clinic")
		"enter_library":
			enter_building("library")
		"enter_museum":
			enter_building("museum")
		"enter_coop":
			enter_building("coop")
		"enter_barn":
			enter_building("barn")
		"enter_worker_hut":
			enter_building("worker_hut")
		"enter_house":
			enter_house()
		"shop":
			_open_shop_if_open()
		"bin":
			sell_all(true)
		"water":
			_try_fishing()
		"animal":
			_interact_animal(near.get("animal"))
		"pet":
			_interact_pet(near.get("pet"))
		"fruit_tree":
			_harvest_fruit_tree(near.get("tree"))
		"beehive":
			_interact_beehive(near.get("hive"))
		"machine":
			ui.open_machine(near.get("machine"))
		"npc":
			var npc_target: VillageNPC = near.get("npc")
			if can_propose(npc_target):
				propose_to_npc(npc_target)
			else:
				talk_to_npc(npc_target)
		"museum":
			ui.open_museum()
		"mailbox":
			ui.open_mail()
		"hot_spring":
			_use_hot_spring()
		"library":
			ui.open_library()
		"clinic":
			ui.open_clinic()
		"worker":
			_toggle_worker()
		"notice_board":
			ui.open_notice_board()
		"festival":
			ui.open_festival(near.get("festival"))
		"feed_coop":
			feed_building("coop")
		"feed_barn":
			feed_building("barn")
		"mount":
			mount_mount(str(near.get("mount_id", "")))
		"stable":
			ui.open_mount_panel("stable")
		"ostrich_house":
			ui.open_mount_panel("ostrich_house")
		"bike_shed":
			ui.open_mount_panel("bike_shed")
		"mirror":
			_open_creator(true)
		"mine":
			enter_mine()
		_:
			ui.toast("附近没有可以互动的东西")


# ============================================================
# 烹饪
# ============================================================

## 食材标签匹配：把 "fish_any" 这类映射到背包里可用的实际 id。
func _resolve_ingredient(ingredient_id: String) -> String:
	match ingredient_id:
		"fish_any", "high_grade_fish":
			for slot: Variant in inventory.slots:
				if slot is Dictionary and str(slot.get("category", "")) == "fish":
					return str(slot.get("item_id", ""))
			return ""
		"meat_any":
			for candidate: String in ["pork", "beef", "mini_pork"]:
				if inventory.count_item(candidate) > 0:
					return candidate
			return ""
		"veggie_any":
			for slot: Variant in inventory.slots:
				if slot is Dictionary and str(slot.get("category", "")) == "crop":
					return str(slot.get("item_id", ""))
			return ""
		"fruit_any":
			for slot: Variant in inventory.slots:
				if slot is Dictionary and str(slot.get("category", "")) == "fruit":
					return str(slot.get("item_id", ""))
			return ""
		"shrimp":
			for candidate: String in ["river_shrimp", "sea_shrimp"]:
				if inventory.count_item(candidate) > 0:
					return candidate
			return ""
		"high_grade_fish":
			for slot: Variant in inventory.slots:
				if slot is Dictionary and str(slot.get("category", "")) == "fish":
					return str(slot.get("item_id", ""))
			return ""
		_:
			return ingredient_id


## 检查菜谱能否制作。返回 { ok, reason, resolved: {id: count} }
func can_cook(recipe: Dictionary) -> Dictionary:
	var ingredients: Dictionary = recipe.get("ingredients", {})
	var resolved: Dictionary = {}
	for key: Variant in ingredients.keys():
		var ingredient_id := str(key)
		var need := int(ingredients[key])
		var actual := _resolve_ingredient(ingredient_id)
		if actual.is_empty() or inventory.count_item(actual) < need:
			return {"ok": false, "reason": "缺少食材", "resolved": {}}
		resolved[actual] = int(resolved.get(actual, 0)) + need
	if not inventory.can_add({"item_id": str(recipe.get("id", "")), "category": "food", "count": 1}):
		return {"ok": false, "reason": "背包已满", "resolved": {}}
	return {"ok": true, "reason": "", "resolved": resolved}


## 制作一道菜。品质 = 食材平均品质。
func cook_recipe(recipe_id: String) -> Dictionary:
	var recipe := DB.get_recipe(recipe_id)
	if recipe.is_empty():
		return {"ok": false, "reason": "未知菜谱"}
	var check := can_cook(recipe)
	if not bool(check.get("ok", false)):
		ui.toast(str(check.get("reason", "无法制作")), "bad")
		SFXError()
		return {"ok": false, "reason": str(check.get("reason", ""))}

	# 扣食材并计算平均品质
	var resolved: Dictionary = check.get("resolved", {})
	var quality_sum := 0.0
	var quality_count := 0
	for item_id: String in resolved.keys():
		var need := int(resolved[item_id])
		# 找到对应槽位，读取品质
		for slot: Variant in inventory.slots:
			if slot is Dictionary and str(slot.get("item_id", "")) == item_id and need > 0:
				var take: int = mini(need, int(slot.get("count", 0)))
				quality_sum += float(QualityUtil.quality_index(str(slot.get("quality", "normal")))) * take
				quality_count += take
				need -= take
				if need <= 0:
					break
		inventory.remove_item(item_id, int(resolved[item_id]))

	var average := quality_sum / maxf(1.0, float(quality_count))
	var quality := "normal"
	if average >= 3.5:
		quality = "star"
	elif average >= 2.5:
		quality = "gold"
	elif average >= 1.5:
		quality = "silver"

	var base_price := 0
	for key: Variant in (recipe.get("ingredients", {}) as Dictionary).keys():
		base_price += DB.get_item_base_price(str(key)) * int(recipe["ingredients"][key])
	base_price = maxi(50, base_price)
	var multiplier := float(recipe.get("price_multiplier", 1.0))
	var price := int(round(float(base_price) * multiplier * QualityUtil.quality_multiplier(quality)))

	var item := {
		"item_id": recipe_id,
		"name": str(recipe.get("name", recipe_id)),
		"category": "food",
		"count": 1,
		"quality": quality,
		"quality_name": QualityUtil.get_quality_name(quality),
		"price": price,
	}
	inventory.add_item(item)
	ui.refresh_hud()
	AudioManager.play_sfx("harvest")
	ui.toast("做好了%s（%s）" % [str(recipe.get("name", "")), QualityUtil.get_quality_name(quality)], "good")
	save_game()
	return {"ok": true, "reason": "", "item": item}


func SFXError() -> void:
	AudioManager.play_sfx("error")


## 给烹饪面板用：列出可做 / 不可做的菜谱。
func get_cookable_recipes() -> Array:
	var result: Array = []
	for recipe: Dictionary in DB.get_all_recipes():
		var check := can_cook(recipe)
		result.append({
			"recipe": recipe,
			"can_cook": bool(check.get("ok", false)),
			"reason": str(check.get("reason", "")),
		})
	return result


# ============================================================
# 矿洞
# ============================================================

func _mine_seed() -> int:
	# 同一天种子固定，同一天同一层可复现
	return int(time.day * 1000 + time.year * 100000 + time.season.length() * 7)


func enter_mine(floor_target := 1) -> void:
	if in_mine or _transitioning:
		return
	if player.riding:
		ui.toast("请先下坐骑再进矿洞", "bad")
		return
	_transitioning = true
	player.input_locked = true
	ui.fade_out(0.3)
	await get_tree().create_timer(0.32).timeout

	mine_outdoor_position = player.position
	in_mine = true
	mine_floor_num = clampi(floor_target, 1, 100)
	time.enter_location("mine")

	_set_outdoor_visible(false)
	if day_light != null:
		day_light.color = Color(0.58, 0.62, 0.78)
	_build_mine_floor()
	_build_mine_light()

	player.position = mine_floor.spawn_position
	player.facing = "down"
	player.z_index = 10

	var bounds := Rect2(0, 0, MineFloor.FLOOR_W * TILE, MineFloor.FLOOR_H * TILE)
	_saved_camera_limits = Rect2i(camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(bounds.size.x)
	camera.limit_bottom = int(bounds.size.y)
	camera.position = player.position
	camera.reset_smoothing()

	ui.refresh_hud()
	for child in ui.toast_box.get_children():
		child.queue_free()
	ui.show_banner("矿洞 第 %d 层" % mine_floor_num, 1.2)
	ui.fade_in(0.3)
	_transitioning = false
	player.input_locked = false


func _build_mine_floor() -> void:
	if _mine_root != null:
		remove_child(_mine_root)
		_mine_root.queue_free()
	_mine_root = null
	_mine_light = null
	_mine_root = Node2D.new()
	_mine_root.name = "Mine"
	_mine_root.z_index = -5
	add_child(_mine_root)

	mine_floor = MineFloorScript.new()
	_mine_root.add_child(mine_floor)
	mine_floor.generate(mine_floor_num, _mine_seed())
	mine_monsters.clear()
	mine_traps.clear()
	_attack_cooldown = 0.0
	_spawn_mine_monsters()
	_spawn_mine_traps()
	mine_deepest = maxi(mine_deepest, mine_floor_num)


## 矿洞玩家光圈（挂在矿洞层之上，跟随玩家）。
func _build_mine_light() -> void:
	if _mine_light != null and is_instance_valid(_mine_light):
		_mine_light.queue_free()
	_mine_light = MineLightScript.new()
	add_child(_mine_light)
	_mine_light.position = player.position + Vector2(0, -10)


func descend_mine() -> void:
	if mine_floor_num >= 100:
		ui.toast("已经到矿洞最深层了", "bad")
		return
	_transitioning = true
	player.input_locked = true
	ui.fade_out(0.2)
	await get_tree().create_timer(0.22).timeout
	mine_floor_num += 1
	_build_mine_floor()
	player.position = mine_floor.spawn_position
	player.z_index = 10
	camera.position = player.position
	camera.reset_smoothing()
	ui.refresh_hud()
	ui.show_banner("第 %d 层" % mine_floor_num, 0.9)
	ui.fade_in(0.2)
	_transitioning = false
	player.input_locked = false


func exit_mine() -> void:
	if not in_mine or _transitioning:
		return
	_transitioning = true
	player.input_locked = true
	ui.fade_out(0.3)
	await get_tree().create_timer(0.32).timeout

	in_mine = false
	time.leave_location()
	if _mine_root != null:
		remove_child(_mine_root)
		_mine_root.queue_free()
		_mine_root = null
	if _mine_light != null and is_instance_valid(_mine_light):
		_mine_light.queue_free()
		_mine_light = null
	_set_outdoor_visible(true)

	player.position = MINE_ENTRANCE_POINT + Vector2(0, 40)
	player.z_index = 0

	camera.limit_left = _saved_camera_limits.position.x
	camera.limit_top = _saved_camera_limits.position.y
	camera.limit_right = _saved_camera_limits.end.x
	camera.limit_bottom = _saved_camera_limits.end.y
	camera.position = player.position
	camera.reset_smoothing()

	ui.refresh_hud()
	_update_day_light()
	ui.fade_in(0.3)
	_transitioning = false
	player.input_locked = false
	save_game()


## 敲石头：消耗 4 体力，掉落矿石。
func hit_mine_rock(rock: Variant) -> void:
	if not in_mine or mine_floor == null:
		return
	if not (rock is Object) or not rock.mine:
		return
	if not player.spend_stamina(4.0):
		ui.toast("体力不足，敲不动了", "bad")
		return
	AudioManager.play_sfx("till")
	Anim.shake_camera(camera, 2.0, 0.15)
	if not rock.hit():
		return

	var rock_pos: Vector2 = rock.position
	var drops: Array = mine_floor.break_rock(rock)
	# 碎石粒子
	var debris := WoodChipsScript.new()
	add_child(debris)
	debris.setup(rock_pos, [Color("#a3a39c"), Color("#bdb8ad"), Color("#7f8792")])
	for drop: Dictionary in drops:
		var item := drop.duplicate(true)
		if inventory.can_add(item):
			inventory.add_item(item)
			_spawn_pickup(str(item.get("item_id", "")), str(item.get("category", "")),
				rock_pos + Vector2(randf_range(-6.0, 6.0), -6.0))
			_record_mine_drop(
				str(item.get("item_id", "")), int(item.get("count", 1)),
				str(item.get("category", "")))
			ui.toast("获得 %s ×%d" % [str(item.get("name", "")), int(item.get("count", 1))], "good")
		else:
			_spawn_ground_item(item, rock_pos + Vector2(randf_range(-6.0, 6.0), -4.0))
			ui.toast("背包满了，%s 掉在地上" % str(item.get("name", "")), "bad")


# ============================================================
# 成就 / 统计
# ============================================================

func _achievement_stat(key: String) -> int:
	match key:
		"crops_harvested":
			return crops_harvested
		"fish_caught":
			return fish_caught
		"ore_mined":
			return ore_mined
		"days_played":
			return days_played
		"total_earned":
			return total_earned
		"quests_completed":
			return quests_completed.size()
		"festivals_done":
			return festivals_done.size()
		"museum_donations":
			return museum_donations.size()
		"animals_owned":
			return animals.size()
		_:
			return 0


func _achievements_check(announce := true) -> void:
	for definition: Dictionary in DB.get_all_achievements():
		var achievement_id := str(definition.get("id", ""))
		if achievement_id.is_empty() or achievement_id in achievements_unlocked:
			continue
		var value := _achievement_stat(str(definition.get("stat", "")))
		if value >= int(definition.get("threshold", 1)):
			achievements_unlocked.append(achievement_id)
			if announce:
				ui.toast("★ 成就达成：%s" % str(definition.get("name", achievement_id)), "good")


func _record_stat(key: String, amount: int) -> void:
	match key:
		"crops_harvested":
			crops_harvested += amount
		"fish_caught":
			fish_caught += amount
		"ore_mined":
			ore_mined += amount
		"days_played":
			days_played += amount
		"total_earned":
			total_earned += amount
	_achievements_check()


func get_achievement_progress() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition: Dictionary in DB.get_all_achievements():
		var achievement_id := str(definition.get("id", ""))
		result.append({
			"definition": definition,
			"value": _achievement_stat(str(definition.get("stat", ""))),
			"threshold": int(definition.get("threshold", 1)),
			"unlocked": achievement_id in achievements_unlocked,
		})
	return result


func _record_mine_drop(item_id: String, count: int, category: String) -> void:
	if category == "artifact":
		_unlock("artifact", item_id)
		return
	if item_id in ["stone", "copper", "iron", "gold", "mythril", "iridium", "granite", "marble"]:
		mine_ores[item_id] = int(mine_ores.get(item_id, 0)) + count
	elif item_id in ["amethyst", "emerald", "ruby", "diamond", "agate", "aquamarine", "sapphire", "garnet"]:
		mine_gems[item_id] = int(mine_gems.get(item_id, 0)) + count
	ore_mined += count
	_achievements_check()
	_unlock("mineral", item_id)


## 矿洞内的点击处理：优先敲石头 / 下楼 / 出洞。
func _handle_mine_click() -> bool:
	if not in_mine or mine_floor == null:
		return false
	var world := get_global_mouse_position()

	for rock: Node2D in mine_floor.rocks:
		if world.distance_to(rock.position + Vector2(0, -6)) <= 20.0:
			if player.position.distance_to(rock.position) <= 2.0 * TILE:
				hit_mine_rock(rock)
			else:
				ui.toast("太远了，靠近一点", "bad")
			return true

	if world.distance_to(Vector2(mine_floor.stairs_pos) * TILE + Vector2(16, 16)) <= 24.0:
		if player.position.distance_to(Vector2(mine_floor.stairs_pos) * TILE + Vector2(16, 16)) <= 2.0 * TILE:
			descend_mine()
		else:
			ui.toast("太远了，靠近楼梯", "bad")
		return true
	var held := get_selected_item()
	if str(held.get("category", "")) == "weapon":
		_attack_in_mine(world)
		return true
	return false


# ============================================================
# 矿洞战斗 / 陷阱
# ============================================================

func _spawn_mine_monsters() -> void:
	if mine_floor == null:
		return
	var spawn_info := DB.get_monster_spawn_for_floor(mine_floor_num)
	if spawn_info.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _mine_seed() + mine_floor_num * 977
	var count := rng.randi_range(int(spawn_info.get("min", 0)), int(spawn_info.get("max", 0)))
	var types: Array = spawn_info.get("types", ["slime"])
	if types.is_empty() or count <= 0:
		return
	var occupied: Dictionary = {
		MineFloorScript.SPAWN_TILE: true,
		mine_floor.stairs_pos: true,
	}
	var bounds := Rect2(
		0, 0, MineFloorScript.FLOOR_W * TILE, MineFloorScript.FLOOR_H * TILE
	)
	for index in count:
		var cell := _random_mine_cell(rng, occupied)
		if cell.x < 0:
			break
		var monster_id := str(types[rng.randi_range(0, types.size() - 1)])
		var monster := MonsterScript.new()
		mine_floor.add_child(monster)
		monster.position = Vector2(cell) * TILE + Vector2(TILE * 0.5, TILE * 0.5)
		monster.setup(monster_id, mine_floor_num, player, bounds, rng.randi())
		monster.died.connect(_on_monster_died)
		mine_monsters.append(monster)


func _spawn_mine_traps() -> void:
	if mine_floor == null:
		return
	var config := DB.get_traps_config()
	var rng := RandomNumberGenerator.new()
	rng.seed = _mine_seed() + mine_floor_num * 1319
	var count := rng.randi_range(int(config.get("min", 2)), int(config.get("max", 5)))
	var occupied: Dictionary = {
		MineFloorScript.SPAWN_TILE: true,
		mine_floor.stairs_pos: true,
	}
	for index in count:
		var cell := _random_mine_cell(rng, occupied)
		if cell.x < 0:
			break
		var trap := MineTrapScript.new()
		mine_floor.add_child(trap)
		trap.setup("pit" if rng.randf() < 0.55 else "slide", cell)
		mine_traps.append(trap)


func _random_mine_cell(rng: RandomNumberGenerator, occupied: Dictionary) -> Vector2i:
	for attempt in 200:
		var cell := Vector2i(
			rng.randi_range(2, MineFloorScript.FLOOR_W - 3),
			rng.randi_range(3, MineFloorScript.FLOOR_H - 3)
		)
		if occupied.has(cell):
			continue
		if Vector2(cell - MineFloorScript.SPAWN_TILE).length() < 3.0:
			continue
		if Vector2(cell - mine_floor.stairs_pos).length() < 3.0:
			continue
		var blocked := false
		for rock: Node2D in mine_floor.rocks:
			if rock.get("cell") == cell:
				blocked = true
				break
		if blocked:
			continue
		occupied[cell] = true
		return cell
	return Vector2i(-1, -1)


func _on_monster_died(monster: MineMonster) -> void:
	mine_monsters.erase(monster)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(time.get_absolute_minutes()) \
		^ int(monster.position.x) * 73856093 \
		^ int(monster.position.y) * 19349663
	for drop: Dictionary in monster.drops:
		if rng.randf() > float(drop.get("chance", 0.0)):
			continue
		var item_id := str(drop.get("item_id", ""))
		var count := int(drop.get("count", 1))
		var category := "monster_drop"
		if item_id in [
			"stone", "copper", "iron", "gold", "mythril", "iridium",
			"granite", "marble", "agate", "amethyst", "aquamarine",
			"emerald", "ruby", "sapphire", "garnet", "diamond",
		]:
			category = "mineral"
		var item := {
			"item_id": item_id, "category": category, "count": count,
			"quality": "normal", "price": int(drop.get("price", 0)),
		}
		if inventory.can_add(item):
			inventory.add_item(item)
			_record_mine_drop(item_id, count, category)
			ui.toast("获得 %s ×%d" % [str(drop.get("name", item_id)), count], "good")
		else:
			ui.toast("背包满了，%s 没捡起来" % str(drop.get("name", item_id)), "bad")


func _attack_in_mine(target_world := Vector2.INF) -> void:
	if not in_mine or player == null or _transitioning:
		return
	if _attack_cooldown > 0.0:
		return
	var held := get_selected_item()
	if str(held.get("category", "")) != "weapon":
		ui.toast("选中剑后点击攻击", "bad")
		return
	var weapon := DB.get_weapon(str(held.get("item_id", "")))
	if weapon.is_empty():
		weapon = DB.get_weapon("sword")
	_attack_cooldown = float(weapon.get("cooldown", 0.5))
	AudioManager.play_sfx("till")

	var direction := Vector2(player.get_facing_vector()).normalized()
	if target_world != Vector2.INF:
		var to_target := target_world - player.position
		if to_target.length() > 4.0:
			direction = to_target.normalized()
	if absf(direction.x) > absf(direction.y):
		player.facing = "right" if direction.x > 0.0 else "left"
	else:
		player.facing = "down" if direction.y > 0.0 else "up"

	var attack_center := player.position + direction * 22.0
	var damage := int(weapon.get("damage", 10))
	var hit_any := false
	for monster in mine_monsters.duplicate():
		if not is_instance_valid(monster):
			continue
		if Vector2(monster.position).distance_to(attack_center) <= 26.0:
			monster.take_damage(damage, player.position)
			hit_any = true
	if hit_any:
		Anim.shake_camera(camera, 1.5, 0.12)
	var slash: SlashScript = _slash_pool.acquire() as SlashScript
	slash.pool = _slash_pool
	slash.setup(player.position + direction * 12.0, direction.angle())


func _check_mine_traps() -> void:
	var config := DB.get_traps_config()
	for trap: MineTrap in mine_traps:
		if trap.triggered:
			continue
		if player.position.distance_to(trap.position) > 15.0:
			continue
		trap.trigger()
		if trap.kind == "slide":
			player.spend_stamina(float(config.get("slide_stamina", 5)))
			ui.toast("踩到滑坡，额外消耗体力", "bad")
		else:
			var damage := int(config.get("pit_damage", 10))
			player.take_damage(damage)
			Anim.shake_camera(camera, 2.0, 0.15)
			ui.toast("掉进暗坑，受到 %d 点伤害" % damage, "bad")
		if player.hp <= 0:
			return


func _on_player_fainted() -> void:
	if _transitioning or not in_mine:
		player.restore_health(1.0)
		return
	_transitioning = true
	player.input_locked = true
	ui.fade_out(0.4)
	await get_tree().create_timer(0.45).timeout

	in_mine = false
	time.leave_location()
	if _mine_root != null:
		remove_child(_mine_root)
		_mine_root.queue_free()
		_mine_root = null
	if _mine_light != null and is_instance_valid(_mine_light):
		_mine_light.queue_free()
		_mine_light = null
	mine_floor = null
	mine_monsters.clear()
	mine_traps.clear()
	_set_outdoor_visible(true)
	player.position = MINE_ENTRANCE_POINT + Vector2(0, 40)
	player.z_index = 0
	camera.limit_left = _saved_camera_limits.position.x
	camera.limit_top = _saved_camera_limits.position.y
	camera.limit_right = _saved_camera_limits.end.x
	camera.limit_bottom = _saved_camera_limits.end.y
	camera.position = player.position
	camera.reset_smoothing()

	time.sleep()
	var death := DB.get_combat_death()
	time.minutes = float(death.get("wake_minutes", 480))
	player.restore_stamina(float(death.get("stamina_ratio", 0.5)))
	player.restore_health(1.0)
	ui.refresh_hud()
	ui.show_banner("晕倒了…… 次日 08:00 在矿洞入口醒来", 2.2)
	ui.fade_in(0.3)
	_transitioning = false
	player.input_locked = false
	save_game()


# ============================================================
# 养蜂
# ============================================================

## 统计蜂箱 5×5 内的花源种类数。
## 养蜂商品：蜂箱、蜂王、糖水、蜂群药物。
func get_bee_shop_goods() -> Array:
	var hive_config := DB.get_hive_config()
	return [
		{
			"item_id": "beehive",
			"name": "蜂箱",
			"price": int(hive_config.get("price", 800)),
			"category": "bee_goods",
			"description": "放到草地上，占 1 格",
		},
		{
			"item_id": "queen_bee",
			"name": "蜂王",
			"price": int(hive_config.get("queen_price", 300)),
			"category": "bee_goods",
			"description": "放进蜂箱才能产蜜",
		},
		{
			"item_id": "sugar_water",
			"name": "糖水",
			"price": int(hive_config.get("sugar_water_price", 50)),
			"category": "bee_goods",
			"description": "喂给蜂群，健康 +10",
		},
		{
			"item_id": "bee_medicine",
			"name": "蜂群药物",
			"price": int(hive_config.get("medicine_price", 150)),
			"category": "bee_goods",
			"description": "治疗蜂群病害",
		},
	]


func count_flower_types(hive_pos: Vector2i) -> int:
	var radius := int(DB.get_flower_bonus_config().get("search_radius", 2))
	var types: Dictionary = {}
	var has_wild_flower := false

	for ty in range(hive_pos.y - radius, hive_pos.y + radius + 1):
		for tx in range(hive_pos.x - radius, hive_pos.x + radius + 1):
			var cell := Vector2i(tx, ty)
			var tile: Variant = farm_tiles.get(cell)
			if tile != null and tile.has_crop() and not tile.is_withered:
				var definition: Dictionary = tile.get_crop_def()
				if bool(definition.get("is_flower", false)):
					types[str(definition.get("id", ""))] = true
			for tree: FruitTree in fruit_trees:
				if tree.grid_pos == cell and tree.ripe:
					types["tree_" + tree.tree_id] = true
			var terrain_id := int(_terrain[ty * WORLD_W + tx]) if (tx >= 0 and ty >= 0 and tx < WORLD_W and ty < WORLD_H) else -1
			if terrain_id == GroundTileMap.GRASS and _has_wild_flower(cell):
				has_wild_flower = true

	var count := types.size()
	if has_wild_flower:
		count += 1
	return count


func _has_wild_flower(cell: Vector2i) -> bool:
	# 野外花：按坐标散列决定，保证稳定
	return ((cell.x * 37 + cell.y * 61) % 11) == 0


func can_place_beehive(cell: Vector2i) -> Dictionary:
	if cell.x < 1 or cell.y < 1 or cell.x >= WORLD_W - 1 or cell.y >= WORLD_H - 1:
		return {"ok": false, "reason": "太靠近地图边缘了"}
	if int(_terrain[cell.y * WORLD_W + cell.x]) != GroundTileMap.GRASS:
		return {"ok": false, "reason": "蜂箱只能放在草地上"}
	if farm_tiles.has(cell):
		return {"ok": false, "reason": "农田上不能放蜂箱"}
	if _tree_at(cell) != null:
		return {"ok": false, "reason": "这里有果树了"}
	for hive: BeeHive in beehives:
		if hive.grid_pos == cell:
			return {"ok": false, "reason": "这里已经有蜂箱了"}
	for prop in props:
		if Vector2(cell) * TILE == prop.position:
			return {"ok": false, "reason": "这里被建筑占用了"}
	return {"ok": true, "reason": ""}


func place_beehive(cell: Vector2i) -> bool:
	var check := can_place_beehive(cell)
	if not bool(check.get("ok", false)):
		ui.toast(str(check.get("reason", "这里不能放蜂箱")), "bad")
		return false
	var hive: BeeHive = BeeHiveScript.new()
	add_child(hive)
	hive.setup(cell, false)
	beehives.append(hive)
	AudioManager.play_sfx("plant")
	ui.toast("放好了蜂箱，记得放入蜂王", "good")
	save_game()
	return true


func _interact_beehive(hive: Variant) -> void:
	if not (hive is BeeHive):
		return
	var target: BeeHive = hive
	var hive_config := DB.get_hive_config()

	if target.escaped:
		ui.toast("蜂群已经逃走了，这箱蜂箱暂时空了", "bad")
		return

	if target.diseased:
		if inventory.count_item("bee_medicine", "goods") > 0:
			inventory.remove_item("bee_medicine", 1, "goods")
			target.heal_disease()
			AudioManager.play_sfx("feed")
			ui.toast("用蜂群药物治好了病害", "good")
		else:
			ui.toast("蜂群生病了，需要蜂群药物（商店有售）", "bad")
		return

	if not target.has_queen:
		if inventory.count_item("queen_bee", "goods") > 0:
			inventory.remove_item("queen_bee", 1, "goods")
			target.place_queen()
			AudioManager.play_sfx("feed")
			ui.toast("放入蜂王，蜂群开始工作了", "good")
		else:
			ui.toast("蜂箱里需要蜂王（商店有售）", "bad")
		return

	var flower_count := count_flower_types(target.grid_pos)
	var result := target.harvest(time.season, time.weather, flower_count)
	if not bool(result.get("ok", false)):
		# 不能收蜜时，检查是否能喂糖水
		if target.health < 70.0 and inventory.count_item("sugar_water", "goods") > 0:
			inventory.remove_item("sugar_water", 1, "goods")
			target.feed_sugar_water()
			AudioManager.play_sfx("feed")
			ui.toast("喂了糖水，蜂群健康 +10（%d）" % int(target.health), "good")
			return
		ui.toast(str(result.get("reason", "现在不能收蜜")), "bad")
		return

	var items: Array = result.get("items", [])
	var names: Array[String] = []
	for item: Dictionary in items:
		var entry := item.duplicate(true)
		entry["count"] = int(entry.get("count", 1))
		if inventory.can_add(entry):
			inventory.add_item(entry)
			_unlock("bee_product", str(entry.get("item_id", "")))
			names.append("%s×%d" % [str(entry.get("name", "")), int(entry["count"])])
		if bool(entry.get("is_rare", false)):
			Anim.rare_flash(target, 0.5)
	AudioManager.play_sfx("coin")
	ui.toast("收蜜：%s（花源 %d 种）" % ["、".join(PackedStringArray(names)), flower_count], "good")
	save_game()


func _advance_beehives(season: String) -> void:
	for hive: BeeHive in beehives:
		var flowers := count_flower_types(hive.grid_pos)
		hive.advance_day(season, time.weather, flowers)
		if hive.escaped:
			ui.toast("蜂群逃走了……", "bad", true)


func _roll_beehive_diseases() -> void:
	for hive: BeeHive in beehives:
		hive.roll_season_disease()
		if hive.diseased:
			ui.toast("有蜂箱感染了病害，需要蜂群药物", "bad", true)


func _beehives_to_save() -> Dictionary:
	var hives: Array = []
	for hive: BeeHive in beehives:
		hives.append(hive.to_save())
	return {
		"hives": hives,
		"products": {},
		"unlock_book": unlock_book.get("bee_product", []),
	}


func _clear_beehives() -> void:
	for hive: BeeHive in beehives:
		remove_child(hive)
		hive.queue_free()
	beehives.clear()


# ============================================================
# 加工机器
# ============================================================

func buy_machine(machine_id: String) -> void:
	var definition := DB.get_machine(machine_id)
	if definition.is_empty():
		return
	var price := int(definition.get("price", 0))
	if money < price:
		ui.toast("钱不够", "bad")
		return
	var item := {
		"item_id": machine_id, "category": "machine", "count": 1, "price": price,
	}
	if not inventory.can_add(item):
		ui.toast("背包空间不够", "bad")
		return
	money -= price
	inventory.add_item(item)
	ui.refresh_hud()
	ui.refresh_shop()
	AudioManager.play_sfx("coin")
	ui.toast("买了%s，选它后点空地放置" % str(definition.get("name", machine_id)), "good")


func can_place_machine(cell: Vector2i) -> Dictionary:
	if cell.x < 0 or cell.y < 0 or cell.x >= WORLD_W or cell.y >= WORLD_H:
		return {"ok": false, "reason": "太靠近地图边缘了"}
	var terrain := int(_terrain[cell.y * WORLD_W + cell.x])
	if terrain != GroundTileMapScript.GRASS and terrain != GroundTileMapScript.PATH:
		return {"ok": false, "reason": "机器只能放在草地或小路上"}
	if farm_tiles.has(cell):
		return {"ok": false, "reason": "不能和农田重叠"}
	if _tree_at(cell) != null:
		return {"ok": false, "reason": "这里已经有果树了"}
	for hive: BeeHive in beehives:
		if hive.grid_pos == cell:
			return {"ok": false, "reason": "这里已经有蜂箱了"}
	for machine: ProcessingMachine in machines:
		if machine.cell == cell:
			return {"ok": false, "reason": "这里已经有机器了"}
	for prop in props:
		if Vector2(cell) * TILE == prop.position:
			return {"ok": false, "reason": "这里被建筑占用了"}
	if _cell_intersects_wall(cell):
		return {"ok": false, "reason": "这里被挡住了"}
	return {"ok": true, "reason": ""}


func _cell_intersects_wall(cell: Vector2i) -> bool:
	if _walls == null:
		return false
	var cell_rect := Rect2(Vector2(cell) * TILE, Vector2(TILE, TILE))
	for child in _walls.get_children():
		if not (child is CollisionShape2D):
			continue
		var collision: CollisionShape2D = child
		if not (collision.shape is RectangleShape2D):
			continue
		var box: RectangleShape2D = collision.shape
		var wall_rect := Rect2(collision.position - box.size * 0.5, box.size)
		if cell_rect.intersects(wall_rect):
			return true
	return false


func _place_machine_from_held(held: Dictionary, cell: Vector2i) -> void:
	var machine_id := str(held.get("item_id", ""))
	var check := can_place_machine(cell)
	if not bool(check.get("ok", false)):
		ui.toast(str(check.get("reason", "这里不能放机器")), "bad")
		return
	inventory.remove_item(machine_id, 1, "machine")
	_spawn_machine(machine_id, cell)
	ui.refresh_hotbar()
	ui.refresh_inventory()
	save_game(true)
	ui.toast("放好了%s" % DB.get_item_name(machine_id, "machine"), "good")


func _spawn_machine(machine_id: String, cell: Vector2i, data := {}) -> ProcessingMachine:
	var machine := MachineScript.new()
	add_child(machine)
	machine.setup(machine_id, cell, data)
	var definition := DB.get_machine(machine_id)
	machine.map_entity = _add_map_entity(
		"Facility", machine.get_display_name(),
		str(definition.get("description", "")),
		machine_id, machine.position, Vector2(7, 3)
	)
	machines.append(machine)
	return machine


func _spawn_machine_from_save(entry: Dictionary) -> void:
	var machine_id := str(entry.get("id", ""))
	if machine_id.is_empty() or DB.get_machine(machine_id).is_empty():
		return
	var cell := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
	_spawn_machine(machine_id, cell, entry)


func _machines_to_save() -> Array:
	var result: Array = []
	for machine: ProcessingMachine in machines:
		result.append(machine.get_save())
	return result


func _clear_machines() -> void:
	for machine: ProcessingMachine in machines:
		if machine.map_entity != null and is_instance_valid(machine.map_entity):
			remove_child(machine.map_entity)
			machine.map_entity.queue_free()
		remove_child(machine)
		machine.queue_free()
	machines.clear()


func can_start_machine(machine: ProcessingMachine, product_id: String) -> bool:
	if machine == null or not machine.product_id.is_empty():
		return false
	var product := DB.get_processing_product(product_id)
	if product.is_empty():
		return false
	if str(product.get("machine", "")) != machine.machine_id:
		return false
	var inputs: Dictionary = product.get("inputs", {})
	for key: Variant in inputs.keys():
		var count := int(inputs[key])
		if str(key) == "any_crop":
			if inventory.count_category(["crop"]) < count:
				return false
		elif inventory.count_item(str(key)) < count:
			return false
	return true


func start_machine(machine: ProcessingMachine, product_id: String) -> void:
	if machine == null:
		return
	if not can_start_machine(machine, product_id):
		ui.toast("原料不足或机器正在工作", "bad")
		return
	var product := DB.get_processing_product(product_id)
	var inputs: Dictionary = product.get("inputs", {})
	for key: Variant in inputs.keys():
		var count := int(inputs[key])
		if str(key) == "any_crop":
			_take_any_crops(count)
		else:
			inventory.remove_item(str(key), count)
	var output := {
		"item_id": product_id,
		"category": str(product.get("category", "processed")),
		"count": 1,
		"quality": "normal",
		"price": int(product.get("base_price", 0)),
	}
	var ready_at := time.get_absolute_minutes() + int(product.get("minutes", 0))
	machine.start(product_id, ready_at, output)
	ui.refresh_hud()
	ui.refresh_inventory()
	save_game(true)
	if ui.get_modal() == "machine":
		ui.refresh_machine()
	ui.toast("开始加工%s" % str(product.get("name", product_id)), "good")


func _take_any_crops(count: int) -> bool:
	var taken := 0
	while taken < count:
		var found := false
		for slot: Variant in inventory.slots:
			if not (slot is Dictionary):
				continue
			if str(slot.get("category", "")) != "crop":
				continue
			if int(slot.get("count", 0)) <= 0:
				continue
			var item_id := str(slot.get("item_id", ""))
			inventory.remove_item(item_id, 1, "crop")
			taken += 1
			found = true
			break
		if not found:
			return false
	return true


func collect_machine(machine: ProcessingMachine) -> void:
	if machine == null or not machine.is_ready():
		ui.toast("还没有加工完成", "bad")
		return
	var output: Dictionary = machine.output.duplicate(true)
	if output.is_empty():
		machine.clear_product()
		return
	if not inventory.can_add(output):
		ui.toast("背包空间不够", "bad")
		return
	var item_name := DB.get_item_name(str(output.get("item_id", "")), "processed")
	inventory.add_item(output)
	_spawn_pickup(str(output.get("item_id", "")), "processed", machine.position + Vector2(0, -8))
	machine.clear_product()
	ui.refresh_hud()
	ui.refresh_inventory()
	save_game(true)
	if ui.get_modal() == "machine":
		ui.refresh_machine()
	ui.toast("取出了%s" % item_name, "good")


func _duration_text(minutes: int) -> String:
	if minutes >= 1440:
		return "%d 天" % ceili(float(minutes) / 1440.0)
	if minutes >= 60:
		return "%d 小时" % ceili(float(minutes) / 60.0)
	return "%d 分钟" % minutes


# ============================================================
# NPC / 好感 / 节日
# ============================================================

func _build_npcs() -> void:
	npcs.clear()
	for definition: Dictionary in DB.get_all_npcs():
		var npc := NPCScript.new()
		add_child(npc)
		npc.setup(definition)
		var birthday: Dictionary = definition.get("birthday", {})
		var desc := "%s · 生日 %s %d 日" % [
			str(definition.get("role", "")),
			DB.season_name(str(birthday.get("season", ""))),
			int(birthday.get("day", 1)),
		]
		var entity := _add_map_entity(
			"NPC", npc.display_name, desc, "npc", npc.position, Vector2(7, -8)
		)
		entity.show_label = false
		npc.map_entity = entity
		npcs.append(npc)
	_update_npc_schedule()


func _update_npc_schedule() -> void:
	if time == null or npcs.is_empty():
		return
	var hour := time.get_hour()
	var weather := str(time.weather)
	var festival := get_active_festival()
	var schedule: Dictionary = DB.get_npc_config().get("schedule", {})
	var hours: Dictionary = schedule.get("hours", {})
	var start_hour := int(hours.get("start", 6))
	var sleep_hour := int(hours.get("sleep", 22))
	var walk_speed := float(schedule.get("walk_speed", 26.0))
	for index in npcs.size():
		var npc: VillageNPC = npcs[index]
		npc.set_birthday(_is_npc_birthday(npc))
		if not spouse_id.is_empty() and npc.npc_id == spouse_id:
			npc.set_active(false)
			continue
		var active := false
		if indoor or in_mine:
			active = false
		elif not festival.is_empty():
			active = hour >= 9 and hour < 18
		elif _is_npc_birthday(npc):
			active = hour >= start_hour and hour < 21
		elif weather in ["rain", "storm", "snow", "blizzard"]:
			active = false
		else:
			active = hour >= start_hour and hour < sleep_hour
		npc.set_festival_mode(active and not festival.is_empty())
		# 工作时间段内播放工作姿态（8:00-12:00 / 14:00-22:00）
		var working := false
		if active and festival.is_empty():
			var work_hour := int(hours.get("work", 8))
			var lunch_hour := int(hours.get("lunch", 12))
			var work_end_hour := int(hours.get("work_end", 14))
			var home_hour := int(hours.get("home", 20))
			working = (hour >= work_hour and hour < lunch_hour) \
				or (hour >= work_end_hour and hour < home_hour)
		npc.set_working(working)
		if active:
			npc.set_schedule_target(
				_npc_schedule_point(npc, index, hour, schedule, festival),
				walk_speed)
		npc.set_active(active)


## 当前时段 NPC 应走到的位置。
func _npc_schedule_point(
	npc: VillageNPC, index: int, hour: int,
	schedule: Dictionary, festival: Dictionary
) -> Vector2:
	if not festival.is_empty():
		return npc.spot_position
	var hours: Dictionary = schedule.get("hours", {})
	var lunch_hour := int(hours.get("lunch", 12))
	var work_end_hour := int(hours.get("work_end", 14))
	var evening_hour := int(hours.get("evening", 18))
	var home_hour := int(hours.get("home", 20))
	if hour < lunch_hour:
		return _npc_work_point(npc, index)
	if hour < work_end_hour:
		return npc.spot_position
	if hour < evening_hour:
		return _npc_work_point(npc, index)
	if hour < home_hour:
		return npc.spot_position
	return _npc_home_point(index, schedule)


## 工作点：按身份去铁匠铺 / 杂货铺 / 博物馆 / 池塘，其余在广场外圈。
func _npc_work_point(npc: VillageNPC, index: int) -> Vector2:
	var role := npc.role
	if role.contains("铁匠") or role.contains("矿"):
		return MINE_ENTRANCE_POINT + Vector2(26.0, 16.0)
	if role.contains("杂货") or role.contains("商") or role.contains("店"):
		return SHOP_POINT + Vector2(-22.0, 16.0)
	if role.contains("博物") or role.contains("馆"):
		return MUSEUM_POINT + Vector2(20.0, 10.0)
	if role.contains("渔"):
		return Vector2(50.0 * TILE, 30.0 * TILE)
	var offset := Vector2(float(index % 5 - 2) * 18.0, float(index % 3 - 1) * 10.0)
	return npc.spot_position + offset


func _npc_home_point(index: int, schedule: Dictionary) -> Vector2:
	var left := index % 2 == 0
	var x := float(schedule.get("home_left_x", 3.5)) if left \
		else float(schedule.get("home_right_x", 60.5))
	var y := float(schedule.get("home_y", 22.0))
	return Vector2(x * TILE, y * TILE)


func _is_npc_birthday(npc: VillageNPC) -> bool:
	var birthday: Dictionary = npc.data.get("birthday", {})
	return str(birthday.get("season", "")) == time.season \
		and int(birthday.get("day", 0)) == time.day


func get_today_festival() -> Dictionary:
	if time == null:
		return {}
	return DB.get_festival_for_date(time.season, time.day)


func get_active_festival() -> Dictionary:
	var festival := get_today_festival()
	if festival.is_empty():
		return {}
	var hour := time.get_hour()
	if hour < int(festival.get("start_hour", 9)) or hour >= int(festival.get("end_hour", 18)):
		return {}
	return festival


func _reset_npc_day() -> void:
	for npc: VillageNPC in npcs:
		npc.talked_today = false
		npc.gifted_today = false


func _reset_npcs() -> void:
	for npc: VillageNPC in npcs:
		npc.friendship = 0
		npc.talked_today = false
		npc.gifted_today = false
		npc.set_birthday(false)
	festivals_done.clear()
	_update_npc_schedule()


func _npcs_to_save() -> Dictionary:
	var states := {}
	for npc: VillageNPC in npcs:
		states[npc.npc_id] = {
			"friendship": npc.friendship,
			"talked_today": npc.talked_today,
			"gifted_today": npc.gifted_today,
		}
	return states


func _apply_npc_states(states: Variant, done: Variant) -> void:
	if states is Dictionary:
		for npc: VillageNPC in npcs:
			var state: Variant = states.get(npc.npc_id, {})
			if state is Dictionary:
				npc.friendship = clampi(int(state.get("friendship", 0)), 0, 250)
				npc.talked_today = bool(state.get("talked_today", false))
				npc.gifted_today = bool(state.get("gifted_today", false))
			else:
				npc.friendship = 0
	festivals_done = done.duplicate() if done is Array else []
	_update_npc_schedule()


func _nearest_visible_npc() -> VillageNPC:
	var best: VillageNPC = null
	var best_distance := INF
	for npc: VillageNPC in npcs:
		if not npc.visible:
			continue
		var distance := player.position.distance_to(npc.position)
		if distance <= 48.0 and distance < best_distance:
			best_distance = distance
			best = npc
	return best


func talk_to_npc(npc: VillageNPC) -> void:
	if npc == null or not npc.visible:
		ui.toast("附近没有村民", "bad")
		return
	var text := str(npc.data.get("line", "今天天气不错。"))
	var festival := get_active_festival()
	if _is_npc_birthday(npc):
		text = "今天是我的生日，你来了真好！"
	elif not festival.is_empty():
		text = "今天是%s，一起去广场吧！" % str(festival.get("name", "节日"))
	var gained := false
	if not npc.talked_today:
		npc.talked_today = true
		npc.add_friendship(1)
		gained = true
		save_game(true)
	ui.show_dialogue(npc.display_name, text, 3.6, npc.look)
	if gained:
		ui.toast("好感 +1 · %d（%s）" % [npc.friendship, npc.friendship_level()], "good")


func _gift_nearby_npc() -> void:
	var npc := _nearest_visible_npc()
	if npc == null:
		ui.toast("附近没有村民", "bad")
		return
	gift_npc(npc)


func gift_npc(npc: VillageNPC) -> void:
	if npc == null:
		return
	if npc.gifted_today:
		ui.toast("今天已经送过礼物了", "bad")
		return
	var held := get_selected_item()
	if held.is_empty():
		ui.toast("先选中要送的物品", "bad")
		return
	var category := str(held.get("category", ""))
	if category in ["tool", "weapon", "rod", "machine"]:
		ui.toast("这个不能送人", "bad")
		return
	var item_id := str(held.get("item_id", ""))
	inventory.remove_item(item_id, 1, category)
	var delta := 3
	var reaction := "谢谢你的礼物。"
	if item_id in npc.data.get("likes", []):
		delta = 8
		reaction = "这正是我喜欢的！谢谢你。"
	elif item_id in npc.data.get("dislikes", []):
		delta = -5
		reaction = "这个……不太合我的口味。"
	if _is_npc_birthday(npc):
		delta *= 3
		reaction += "（生日礼物！）"
	npc.gifted_today = true
	npc.add_friendship(delta)
	ui.refresh_hotbar()
	ui.refresh_inventory()
	ui.show_dialogue(npc.display_name, reaction, 3.2, npc.look)
	ui.toast("好感 %+d · %d（%s）" % [delta, npc.friendship, npc.friendship_level()],
		"good" if delta >= 0 else "bad")
	save_game(true)


func _festival_key(festival: Dictionary) -> String:
	return "%d:%s" % [time.year, str(festival.get("id", ""))]


func is_festival_done(festival: Dictionary) -> bool:
	return _festival_key(festival) in festivals_done


func participate_festival(festival: Dictionary) -> Dictionary:
	if festival.is_empty():
		return {"ok": false, "reason": "没有节日"}
	if str(get_active_festival().get("id", "")) != str(festival.get("id", "")):
		return {"ok": false, "reason": "现在不是节日时间"}
	if is_festival_done(festival):
		return {"ok": false, "reason": "今年已经参加过了"}

	var festival_type := str(festival.get("type", "simple"))
	var scored := {"score": 0.0, "label": "参与"}
	if festival_type in ["flower", "cooking", "animal", "harvest"]:
		scored = _festival_score(festival_type)
	var rank := 0
	if bool(festival.get("competition", false)):
		rank = _festival_rank(float(scored.get("score", 0.0)))
	var coins := 0
	var friendship_gain := 0
	if rank > 0:
		var rewards: Dictionary = festival.get("rewards", {})
		var reward: Dictionary = rewards.get(str(rank), {})
		coins = int(reward.get("coins", 0))
		friendship_gain = int(reward.get("friendship", 0))
	else:
		var simple: Dictionary = festival.get("simple_reward", {})
		coins = int(simple.get("coins", 50))
		friendship_gain = int(simple.get("friendship", 0))

	money += coins
	total_earned += coins
	if friendship_gain > 0:
		for npc: VillageNPC in npcs:
			npc.add_friendship(friendship_gain)
	festivals_done.append(_festival_key(festival))
	_achievements_check()
	ui.refresh_hud()
	save_game(true)

	var rank_names := ["参与奖", "第一名", "第二名", "第三名"]
	var festival_name := str(festival.get("name", "节日"))
	ui.show_banner("%s · %s" % [festival_name, rank_names[rank]], 2.2)
	# 节日场景特效：彩带、烟花、聚光灯、奖杯
	var fx := FestivalFxScript.new()
	add_child(fx)
	fx.setup(FESTIVAL_POINT + Vector2(0, -8))
	AudioManager.play_sfx("coin")
	return {
		"ok": true,
		"rank": rank,
		"rank_name": rank_names[rank],
		"score": snappedf(float(scored.get("score", 0.0)), 0.01),
		"label": str(scored.get("label", "")),
		"coins": coins,
		"friendship": friendship_gain,
	}


func _festival_rank(score: float) -> int:
	if score >= 3.5:
		return 1
	if score >= 2.5:
		return 2
	if score >= 1.5:
		return 3
	return 0


func _festival_score(festival_type: String) -> Dictionary:
	match festival_type:
		"flower":
			return _best_crop_festival_score(true)
		"harvest":
			return _best_crop_festival_score(false)
		"cooking":
			return _best_food_festival_score()
		"animal":
			return _best_animal_festival_score()
	return {"score": 0.0, "label": "参与"}


func _best_crop_festival_score(flower_only: bool) -> Dictionary:
	var best_score := 0.0
	var best_label := "背包里没有合适的作物"
	for slot: Variant in inventory.slots:
		if not (slot is Dictionary):
			continue
		if str(slot.get("category", "")) != "crop":
			continue
		var item_id := str(slot.get("item_id", ""))
		var definition := DB.get_crop(item_id)
		if definition.is_empty():
			continue
		if flower_only and not bool(definition.get("is_flower", false)):
			continue
		var quality := float(QualityUtil.quality_index(str(slot.get("quality", "normal"))) + 1)
		var rare := 2.0 if bool(slot.get("is_rare", false)) else 1.0
		var variety := clampf(1.0 + float(definition.get("base_price", 0)) / 50.0, 1.0, 3.0)
		var score := quality * 0.4 + rare * 0.3 + variety * 0.3
		if not flower_only:
			score = quality * 0.5 + rare * 0.3 \
				+ clampf(float(slot.get("count", 1)), 1.0, 5.0) * 0.2
		if score > best_score:
			best_score = score
			best_label = str(definition.get("name", item_id))
	return {"score": best_score, "label": best_label}


func _best_food_festival_score() -> Dictionary:
	var best_score := 0.0
	var best_label := "背包里没有做好的料理"
	for slot: Variant in inventory.slots:
		if not (slot is Dictionary) or str(slot.get("category", "")) != "food":
			continue
		var item_name := DB.get_item_name(str(slot.get("item_id", "")), "food")
		var quality := float(QualityUtil.quality_index(str(slot.get("quality", "normal"))) + 1)
		var difficulty := clampf(1.0 + float(slot.get("price", 0)) / 200.0, 1.0, 4.0)
		var rare := 2.0 if bool(slot.get("is_rare", false)) else 1.0
		var score := difficulty * 0.4 + quality * 0.4 + rare * 0.2
		if score > best_score:
			best_score = score
			best_label = item_name
	return {"score": best_score, "label": best_label}


func _best_animal_festival_score() -> Dictionary:
	var best_score := 0.0
	var best_label := "还没有可以参赛的动物"
	for animal: FarmAnimal in animals:
		var friendship_score := clampf(animal.friendship / 25.0, 0.0, 4.0)
		var rare := 2.0 if animal.is_rare else 1.0
		var weight_score := clampf(animal.friendship / 25.0, 0.0, 4.0)
		var score := friendship_score * 0.5 + rare * 0.3 + weight_score * 0.2 + 0.2
		if score > best_score:
			best_score = score
			best_label = animal.get_display_name()
	return {"score": best_score, "label": best_label}


func _spawn_hive_from_save(data: Dictionary) -> void:
	var hive: BeeHive = BeeHiveScript.new()
	add_child(hive)
	hive.from_save(data)
	beehives.append(hive)


# ============================================================
# 果树
# ============================================================

func buy_sapling(tree_id: String) -> void:
	var definition := DB.get_fruit_tree(tree_id)
	if definition.is_empty():
		return
	var price := DB.get_sapling_price(tree_id)
	if price <= 0:
		ui.toast("这个树苗暂时没有定价", "bad")
		return
	if money < price:
		ui.toast("钱不够", "bad")
		return
	if not inventory.can_add({"item_id": tree_id, "category": "sapling", "count": 1}):
		ui.toast("背包空间不够", "bad")
		return
	money -= price
	inventory.add_item({"item_id": tree_id, "category": "sapling", "count": 1})
	ui.refresh_hud()
	ui.refresh_shop()
	AudioManager.play_sfx("coin")
	ui.toast("买了%s树苗，选它后点草地种下" % str(definition.get("name", tree_id)), "good")


func can_plant_tree_at(origin: Vector2i) -> Dictionary:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var cell := origin + Vector2i(dx, dy)
			if cell.x < 0 or cell.y < 0 or cell.x >= WORLD_W or cell.y >= WORLD_H:
				return {"ok": false, "reason": "太靠近地图边缘了"}
			if int(_terrain[cell.y * WORLD_W + cell.x]) != GroundTileMap.GRASS:
				return {"ok": false, "reason": "果树只能种在草地上"}
			if _tree_at(cell) != null:
				return {"ok": false, "reason": "这里已经有果树了"}
			if farm_tiles.has(cell):
				return {"ok": false, "reason": "果树占 3×3，不能和农田重叠"}
			for prop in props:
				if Vector2(cell) * TILE == prop.position:
					return {"ok": false, "reason": "这里被建筑占用了"}
	return {"ok": true, "reason": ""}


func _tree_at(cell: Vector2i) -> Variant:
	for tree: FruitTree in fruit_trees:
		if cell in tree.get_footprint():
			return tree
	return null


func plant_fruit_tree(tree_id: String, cell: Vector2i) -> void:
	var definition := DB.get_fruit_tree(tree_id)
	if definition.is_empty():
		return
	var check := can_plant_tree_at(cell)
	if not bool(check.get("ok", false)):
		ui.toast(str(check.get("reason", "这里不能种树")), "bad")
		return
	var tree: FruitTree = FruitTreeScript.new()
	add_child(tree)
	tree.setup(tree_id, cell, time.year, false)
	fruit_trees.append(tree)
	# 树的碰撞：只挡树干 1 格
	_add_wall(Rect2(cell.x * TILE + 10, (cell.y + 1) * TILE - 12, 12, 12))
	Anim.grow_pop(tree, 1.15, 0.3)
	AudioManager.play_sfx("plant")
	ui.toast("种下了%s，第 %d 年成年" % [tree.get_tree_name(), time.year + tree.get_mature_year() - 1], "good")
	save_game()


func _harvest_fruit_tree(tree: Variant) -> void:
	if not (tree is FruitTree):
		return
	var target: FruitTree = tree
	var result := target.harvest()
	if not bool(result.get("ok", false)):
		ui.toast(str(result.get("reason", "现在不能摘")), "bad")
		return
	var item: Dictionary = result.get("item", {})
	if not inventory.can_add(item):
		ui.toast("背包满了", "bad")
		target.ripe = true
		return
	inventory.add_item(item)
	_unlock("fruit", str(item.get("item_id", "")))
	# 摇树：果实从树冠落下，再飞向玩家
	var drop := FruitDropScript.new()
	add_child(drop)
	drop.setup(
		target.position + Vector2(0, -44),
		target.position + Vector2(4, 0),
		player.position,
		Color("#d05a5a") if not bool(item.get("is_rare", false)) else Color("#e8b45a")
	)
	if bool(item.get("is_rare", false)):
		_unlock("fruit", str(item.get("item_id", "")) + "_giant")
		Anim.rare_flash(target, 0.5)
		ui.toast("✨ 摘到了硕大的%s！" % str(item.get("name", "")), "good")
	else:
		ui.toast("摘到了%s（%d G）" % [str(item.get("name", "")), int(item.get("price", 0))], "good")
	AudioManager.play_sfx("harvest")


func chop_fruit_tree(tree: Variant) -> void:
	if not (tree is FruitTree):
		return
	var target: FruitTree = tree
	if bool(target.get_definition().get("chopable", true)) == false:
		return
	if not player.spend_stamina(4.0):
		ui.toast("体力不足，砍不动了", "bad")
		return
	AudioManager.play_sfx("till")
	Anim.shake_camera(camera, 2.5, 0.18)
	# 木屑粒子
	var chips := WoodChipsScript.new()
	add_child(chips)
	chips.setup(target.position)
	# 砍倒：整棵树旋转倒下 90° 并淡出，然后再移除
	fruit_trees.erase(target)
	_rebuild_tree_walls()
	var tree_name := target.get_tree_name()
	var tween := create_tween()
	tween.tween_property(target, "rotation", PI * 0.5, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(target, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		remove_child(target)
		target.queue_free()
	)
	ui.toast("砍倒了%s" % tree_name, "good")
	save_game()


func _advance_fruit_trees(season: String) -> void:
	for tree: FruitTree in fruit_trees:
		tree.update_maturity(time.year)
		tree.advance_day(season)


func _trees_to_save() -> Array:
	var result: Array = []
	for tree: FruitTree in fruit_trees:
		result.append(tree.to_save())
	return result


func _clear_fruit_trees() -> void:
	for tree: FruitTree in fruit_trees:
		remove_child(tree)
		tree.queue_free()
	fruit_trees.clear()
	_rebuild_tree_walls()


func _rebuild_tree_walls() -> void:
	# 树的碰撞合并进 _walls，简单起见重建一次静态墙体
	if _walls == null:
		return
	remove_child(_walls)
	_walls.queue_free()
	_walls = null
	_build_walls()
	for tree: FruitTree in fruit_trees:
		var cell := tree.grid_pos
		_add_wall(Rect2(cell.x * TILE + 10, (cell.y + 1) * TILE - 12, 12, 12))


func _spawn_tree_from_save(data: Dictionary) -> void:
	var tree: FruitTree = FruitTreeScript.new()
	add_child(tree)
	tree.from_save(data)
	fruit_trees.append(tree)


# ============================================================
# 宠物
# ============================================================

func get_pet_config() -> Dictionary:
	return DB.get_pet_config()


func get_pet_limit() -> int:
	return _pet_limit_for_houses(pet_houses.size() + 1)


func _adult_pet_count() -> int:
	var count := 0
	for pet: FarmPet in pets:
		if not pet.is_young_livestock():
			count += 1
	return count


func _young_livestock_building(breed_id: String) -> String:
	if "duckling" in breed_id or "gosling" in breed_id:
		return "coop"
	return "barn"


func _livestock_occupancy(building: String) -> int:
	var count := _animals_in(building).size()
	for pet: FarmPet in pets:
		if pet.is_young_livestock() and _young_livestock_building(pet.breed) == building:
			count += 1
	return count


func _pet_limit_for_houses(house_count: int) -> int:
	var tiers: Array[int] = [1, 1, 3, 5, 8, 12]
	var index := clampi(house_count, 0, tiers.size() - 1)
	return mini(int(DB.get_pet_config().get("max_pets", 12)), tiers[index])


func _pet_house_anchor(house_type: String) -> Vector2:
	var anchors := {
		"dog_house": Vector2(45.8, 16.8),
		"cat_bed": Vector2(54.4, 16.6),
		"cat_tree": Vector2(56.6, 18.6),
		"bird_cage": Vector2(46.2, 18.6),
		"red_panda_den": Vector2(58.2, 14.8),
		"fish_tank": Vector2(50.0, 20.2),
		"turtle_tank": Vector2(52.6, 20.2),
		"turtle_pond": Vector2(56.2, 21.2),
		"rabbit_hutch": Vector2(42.4, 18.6),
		"hamster_cage": Vector2(47.2, 20.6),
		"guinea_pig_cage": Vector2(53.8, 22.2),
		"young_animal_pen": Vector2(18.0, 23.5),
		"duck_pond": Vector2(14.0, 33.8),
		"reptile_tank": Vector2(48.8, 22.4),
		"amphibian_tank": Vector2(51.4, 22.4),
		"insect_box": Vector2(44.8, 21.2),
		"aviary": Vector2(60.0, 19.5),
		"fox_den": Vector2(41.8, 21.8),
		"deer_pen": Vector2(14.5, 21.5),
		"otter_pool": Vector2(44.0, 29.6),
		"penguin_pool": Vector2(50.0, 29.6),
		"seal_pool": Vector2(56.0, 29.6),
		"dragon_den": Vector2(36.0, 21.0),
		"saltwater_tank": Vector2(47.4, 23.6),
		"jellyfish_tank": Vector2(49.8, 23.6),
		"planted_tank": Vector2(52.2, 23.6),
		"hedgehog_den": Vector2(45.6, 19.6),
		"squirrel_house": Vector2(40.8, 19.8),
		"ferret_cage": Vector2(40.8, 23.2),
		"chinchilla_cage": Vector2(43.2, 23.2),
		"butterfly_house": Vector2(58.0, 23.8),
		"crab_tank": Vector2(55.4, 23.6),
	}
	var tile_position: Vector2 = anchors.get(house_type, Vector2(50.0, 19.0))
	return tile_position * TILE


func _new_pet_id(pet_type: String) -> String:
	var index := pets.size() + 1
	while _find_pet("%s_%d" % [pet_type, index]) != null:
		index += 1
	return "%s_%d" % [pet_type, index]


func _find_pet(pet_id: String) -> FarmPet:
	for pet: FarmPet in pets:
		if pet.pet_id == pet_id:
			return pet
	return null


func _find_house_data(house_id: String) -> Dictionary:
	for entry: Dictionary in pet_houses:
		if str(entry.get("id", "")) == house_id:
			return entry
	return {}


func _find_house_node(house_id: String) -> PetHouse:
	var node: PetHouse = _pet_house_nodes.get(house_id)
	return node if node != null and is_instance_valid(node) else null


func _find_free_pet_house(type_definition: Dictionary) -> Dictionary:
	var house_types: Array = type_definition.get("house_types", [])
	for house_type: String in house_types:
		for entry: Dictionary in pet_houses:
			if str(entry.get("type", "")) != house_type:
				continue
			var node := _find_house_node(str(entry.get("id", "")))
			if node != null and not node.is_full():
				return entry
	return {}


func _create_pet_house(house_type: String, pet_name: String) -> Dictionary:
	var definition := DB.get_pet_house_def(house_type)
	if definition.is_empty():
		return {}
	_pet_house_serial += 1
	var house_id := "%s_%d" % [house_type, _pet_house_serial]
	var base := _pet_house_anchor(house_type)
	var siblings := 0
	for entry: Dictionary in pet_houses:
		if str(entry.get("type", "")) == house_type:
			siblings += 1
	var world_position := base + Vector2(float(siblings) * 26.0, 0.0)
	var locations: Array = definition.get("location", ["outdoor"])
	var placement := str(locations[0]) if not locations.is_empty() else "outdoor"
	var data := {
		"id": house_id,
		"type": house_type,
		"x": world_position.x,
		"y": world_position.y,
		"location": placement,
		"level": 1,
		"name": ("%s之家" % pet_name) if not pet_name.is_empty() \
			else str(definition.get("name", house_type)),
		"occupants": [],
		"cleanliness": 80.0,
		"decorations": [],
	}
	pet_houses.append(data)
	_spawn_pet_house_node(data)
	return data


func _spawn_pet_house_node(data: Dictionary) -> PetHouse:
	var node := PetHouseScript.new()
	add_child(node)
	var world_position := Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	node.setup(str(data.get("type", "dog_house")), str(data.get("id", "")),
		world_position, str(data.get("location", "outdoor")))
	node.house_name = str(data.get("name", node.house_name))
	node.level = int(data.get("level", 1))
	node.cleanliness = float(data.get("cleanliness", 80.0))
	node.occupancy.clear()
	node.decorations.clear()
	var saved_occupants: Variant = data.get("occupants", [])
	if saved_occupants is Array:
		for occupant: Variant in saved_occupants:
			node.occupancy.append(str(occupant))
	var saved_decorations: Variant = data.get("decorations", [])
	if saved_decorations is Array:
		for decoration: Variant in saved_decorations:
			node.decorations.append(str(decoration))
	_pet_house_nodes[str(data.get("id", ""))] = node
	_update_house_missing(node)
	return node


## 领养检查：返回 {ok, reason, house_type, house_cost, total}。
func can_buy_pet(breed_id: String) -> Dictionary:
	var definition := DB.get_pet_breed(breed_id)
	if definition.is_empty():
		return {"ok": false, "reason": "未知品种"}
	var type_id := str(definition.get("type_id", ""))
	var type_definition := DB.get_pet_type(type_id)
	var house_types: Array = (type_definition.get("house_types", []) as Array).duplicate()
	if type_id == "young_livestock" \
			and ("duckling" in str(definition.get("id", "")) \
				or "gosling" in str(definition.get("id", ""))):
		house_types = ["duck_pond", "young_animal_pen"]
	var type_for_house: Dictionary = type_definition.duplicate(true)
	type_for_house["house_types"] = house_types
	var free_house := _find_free_pet_house(type_for_house)
	var needs_house := free_house.is_empty()
	if needs_house and house_types.is_empty():
		return {"ok": false, "reason": "该宠物没有可用栖息地"}
	var prospective_houses := pet_houses.size() + (1 if needs_house else 0)
	if type_id == "young_livestock":
		var building := _young_livestock_building(str(definition.get("id", "")))
		if _livestock_occupancy(building) >= get_building_capacity(building):
			return {"ok": false, "reason": "畜棚 / 鸡舍容量不足"}
	elif _adult_pet_count() >= _pet_limit_for_houses(prospective_houses):
		return {"ok": false, "reason": "宠物上限已满，先扩建栖息地"}
	var house_cost := 0
	var house_type := str(house_types[0]) if not house_types.is_empty() else ""
	if needs_house:
		var house_definition := DB.get_pet_house_def(house_type)
		house_cost = int(house_definition.get("price", 0))
		# 开局第一只狗 / 猫自带基础栖息地
		if pet_houses.is_empty() and type_id in ["dog", "cat"]:
			house_cost = 0
	var total := int(definition.get("price", 0)) + house_cost
	if money < total:
		return {"ok": false, "reason": "金币不足", "house_type": house_type,
			"house_cost": house_cost, "total": total}
	return {"ok": true, "reason": "", "house_type": house_type,
		"house_cost": house_cost, "total": total}


func buy_pet(breed_id: String) -> String:
	var check := can_buy_pet(breed_id)
	if not bool(check.get("ok", false)):
		ui.toast(str(check.get("reason", "无法领养")), "bad")
		return ""
	var definition := DB.get_pet_breed(breed_id)
	var type_id := str(definition.get("type_id", ""))
	var type_definition := DB.get_pet_type(type_id)
	var house_types: Array = (type_definition.get("house_types", []) as Array).duplicate()
	if type_id == "young_livestock" \
			and ("duckling" in breed_id or "gosling" in breed_id):
		house_types = ["duck_pond", "young_animal_pen"]
	var type_for_house: Dictionary = type_definition.duplicate(true)
	type_for_house["house_types"] = house_types
	var house := _find_free_pet_house(type_for_house)
	if house.is_empty():
		house = _create_pet_house(str(check.get("house_type", "")),
			str(definition.get("name", breed_id)))
	if house.is_empty():
		ui.toast("栖息地创建失败", "bad")
		return ""
	money -= int(check.get("total", 0))
	var pet: FarmPet = PetScript.new()
	add_child(pet)
	pet.pet_id = _new_pet_id(type_id)
	pet.setup(breed_id, _pet_house_anchor(str(house.get("type", ""))))
	pet.roll_adoption_traits()
	pet.house_id = str(house.get("id", ""))
	pet.adopted_day = time.get_absolute_day()
	pet.in_house = not pet.is_companion()
	pet.following = pet.is_companion()
	var node := _find_house_node(pet.house_id)
	if node != null:
		node.add_occupant(pet.pet_id)
		pet.position = node.get_anchor()
	var occupants: Array = house.get("occupants", [])
	occupants.append(pet.pet_id)
	house["occupants"] = occupants
	pets.append(pet)
	_unlock("pet", breed_id)
	if pet.is_rare:
		_unlock("pet_rare", "%s_%s" % [breed_id, pet.rare_color])
	_refresh_pet_houses()
	ui.refresh_hud()
	ui.refresh_shop()
	AudioManager.play_sfx("coin")
	if pet.is_rare:
		ui.toast("✨ 领养了%s色的%s！" % [pet.rare_color_name, pet.get_breed_name()], "good")
	else:
		ui.toast("领养了%s（%s）" % [pet.get_breed_name(),
			str(DB.get_pet_house_def(str(house.get("type", ""))).get("name", "栖息地"))], "good")
	save_game()
	return pet.pet_id


func _interact_pet(pet: Variant) -> void:
	if not (pet is FarmPet):
		return
	var target: FarmPet = pet
	if target.gift_ready:
		var item := target.collect_gift()
		if not item.is_empty():
			if inventory.can_add(item):
				inventory.add_item(item)
				ui.toast("%s带回了%s" % [target.get_display_name(),
					str(item.get("name", ""))], "good")
			else:
				target.gift_ready = true
				target.gift = item
				ui.toast("背包满了，先腾出空间", "bad")
	ui.open_pet_panel(target.pet_id)


## 宠物面板动作：feed / pet / play / clean / heal / recover。
func pet_action(pet_id: String, action: String) -> bool:
	var pet := _find_pet(pet_id)
	if pet == null:
		return false
	var success := false
	match action:
		"feed":
			var food_id := str(DB.get_pet_type(pet.pet_type).get("food_id", ""))
			if inventory.count_item(food_id, "pet_food") <= 0:
				ui.toast("背包里没有%s" % str(DB.get_pet_food(food_id).get("name", "宠物食物")), "bad")
				return false
			success = pet.feed(food_id)
			if success:
				inventory.remove_item(food_id, 1, "pet_food")
		"pet":
			success = pet.pet()
			if success:
				Anim.bounce(pet, 5.0, 0.26)
		"play":
			success = pet.play()
		"clean":
			success = pet.clean()
			if success:
				var house := _find_house_node(pet.house_id)
				if house != null:
					house.cleanliness = minf(100.0, house.cleanliness + 40.0)
		"walk":
			if not pet.is_young_livestock() or pet.walked_today or pet.missing:
				return false
			pet.walked_today = true
			pet.add_friendship(2.0)
			pet.age_days += 1
			success = true
		"release":
			var type_definition := DB.get_pet_type(pet.pet_type)
			if not bool(type_definition.get("can_release", false)) \
					or pet.missing or pet.released:
				return false
			if pet.friendship < float(type_definition.get("release_friendship", 50)):
				ui.toast("好感不足，暂时不能放出", "bad")
				return false
			pet.start_release(float(DB.get_pet_config().get("release_seconds", 20)))
			AudioManager.play_sfx("footstep")
			success = true
		"battle":
			if pet.pet_type != "insect" or pet.battled_today or pet.missing:
				return false
			pet.battled_today = true
			pet.add_friendship(2.0)
			var reward := int(DB.get_pet_config().get("insect_battle_reward", 100))
			money += reward
			total_earned += reward
			AudioManager.play_sfx("coin")
			ui.refresh_hud()
			success = true
		"heal":
			if not pet.sick:
				return false
			if inventory.count_item("pet_medicine", "pet_food") > 0:
				inventory.remove_item("pet_medicine", 1, "pet_food")
				success = pet.heal()
			elif money >= 200:
				money -= 200
				success = pet.heal()
			else:
				ui.toast("需要宠物药或 200G", "bad")
				return false
		"recover":
			if not pet.missing:
				return false
			var runaway: Dictionary = DB.get_pet_config().get("status", {}).get("runaway", {})
			if pet.missing_days > int(runaway.get("missing_days", 3)):
				ui.toast("已经错过找回时间了", "bad")
				return false
			pet.recover_missing()
			house_refresh(pet)
			success = true
	if not success:
		ui.toast("现在不能这样做", "bad")
		return false
	match action:
		"feed":
			AudioManager.play_sfx("feed")
		"pet", "play":
			AudioManager.play_sfx("click")
		"clean":
			AudioManager.play_sfx("water")
	ui.refresh_pet_panel()
	ui.refresh_hud()
	save_game()
	return true


## 每只宠物可改名一次（领养后的首次命名也计为这一次）。
func get_next_pet_decoration(house_id: String) -> Dictionary:
	var node := _find_house_node(house_id)
	if node == null or node.decorations.size() >= 3:
		return {}
	var decorations := DB.get_all_pet_decorations()
	for decoration_id: Variant in decorations.keys():
		var key := str(decoration_id)
		if key in node.decorations:
			continue
		var definition: Variant = decorations[decoration_id]
		if definition is Dictionary:
			return {
				"id": key,
				"name": str((definition as Dictionary).get("name", key)),
				"price": int((definition as Dictionary).get("price", 0)),
			}
	return {}


func add_pet_house_decoration(house_id: String) -> bool:
	var node := _find_house_node(house_id)
	if node == null:
		return false
	if node.decorations.size() >= 3:
		ui.toast("这个栖息地的装饰位已满", "bad")
		return false
	var next := get_next_pet_decoration(house_id)
	if next.is_empty():
		ui.toast("已经没有可摆放的装饰了", "bad")
		return false
	var price := int(next.get("price", 0))
	if money < price:
		ui.toast("金币不足（需要 %dG）" % price, "bad")
		return false
	money -= price
	node.decorations.append(str(next.get("id", "")))
	var house := _find_house_data(house_id)
	house["decorations"] = node.decorations.duplicate()
	ui.refresh_hud()
	save_game()
	ui.toast("摆放了%s" % str(next.get("name", "装饰")), "good")
	return true


func _house_capacity(house_id: String) -> int:
	var node := _find_house_node(house_id)
	return node.get_capacity() if node != null else 0


func _house_max_level(house_id: String) -> int:
	var node := _find_house_node(house_id)
	return node.get_max_level() if node != null else 1


func _house_upgrade_cost(house_id: String) -> int:
	var node := _find_house_node(house_id)
	return node.get_upgrade_cost() if node != null else 0


func upgrade_pet_house(house_id: String) -> bool:
	var house := _find_house_data(house_id)
	var node := _find_house_node(house_id)
	if house.is_empty() or node == null:
		return false
	if node.level >= node.get_max_level():
		ui.toast("栖息地已经是最高级", "bad")
		return false
	var cost := node.get_upgrade_cost()
	if money < cost:
		ui.toast("金币不足（需要 %dG）" % cost, "bad")
		return false
	money -= cost
	node.level += 1
	house["level"] = node.level
	ui.refresh_hud()
	ui.refresh_pet_panel()
	save_game()
	ui.toast("%s升级到 Lv.%d，容量 %d" % [
		str(house.get("name", "栖息地")), node.level, node.get_capacity(),
	], "good")
	return true


## 进入栖息地搬迁模式：下一次左键把房屋放到目标格。
func begin_move_pet_house(house_id: String) -> void:
	var house := _find_house_data(house_id)
	if house.is_empty():
		return
	_placing_pet_house_id = house_id
	ui.set_prompt("点击草地放置%s · Esc 取消" % str(house.get("name", "栖息地")))
	ui.toast("选择新的栖息地位置", "good")


func cancel_move_pet_house() -> void:
	if _placing_pet_house_id.is_empty():
		return
	_placing_pet_house_id = ""
	ui.set_prompt("")
	ui.toast("取消搬迁")


func _pet_house_size(house_type: String) -> Vector2i:
	var definition := DB.get_pet_house_def(house_type)
	var size: Array = definition.get("size", [2, 2])
	return Vector2i(maxi(1, int(size[0])), maxi(1, int(size[1])))


func _pet_house_footprint(house_type: String, tile: Vector2i) -> Rect2i:
	var size := _pet_house_size(house_type)
	return Rect2i(tile.x, tile.y, size.x, size.y)


func _can_place_pet_house(house_type: String, tile: Vector2i, ignore_id: String) -> bool:
	var rect := _pet_house_footprint(house_type, tile)
	if rect.position.x < 1 or rect.position.y < 1 \
			or rect.end.x >= WORLD_W or rect.end.y >= WORLD_H:
		return false
	# 水域 / 沙地不可放置
	for ty in range(rect.position.y, rect.end.y):
		for tx in range(rect.position.x, rect.end.x):
			var terrain := int(_terrain[ty * WORLD_W + tx])
			if terrain == GroundTileMapScript.WATER:
				return false
	# 农田与已放置栖息地不可重叠
	for ty in range(rect.position.y, rect.end.y):
		for tx in range(rect.position.x, rect.end.x):
			if farm_tiles.has(Vector2i(tx, ty)):
				return false
	for entry: Dictionary in pet_houses:
		if str(entry.get("id", "")) == ignore_id:
			continue
		var other_type := str(entry.get("type", ""))
		var other_size := _pet_house_size(other_type)
		var other_origin := Vector2i(
			floori(float(entry.get("x", 0.0)) / TILE - float(other_size.x) * 0.5),
			floori(float(entry.get("y", 0.0)) / TILE - float(other_size.y)))
		var other := _pet_house_footprint(other_type, other_origin)
		if rect.intersects(other):
			return false
	# 固定建筑 / 坐骑建筑附近保留空间
	var blocked := [
		Rect2i(44, 8, 10, 8),    # 主屋 / 商店
		Rect2i(42, 13, 14, 8),   # 宠物活动区（旧狗屋/猫屋一带）
		Rect2i(45, 24, 16, 6),   # 马厩 / 鸵鸟舍 / 自行车棚
		Rect2i(21, 26, 22, 15),  # 牧场
	]
	for block: Rect2i in blocked:
		if rect.intersects(block):
			return false
	return true


## 专属动画状态：鸟秋千 / 鱼躲藏 / 龟缩壳。
func _update_pet_visual_flags(pet: FarmPet, house_node: PetHouse) -> void:
	pet.swung = false
	pet.hiding = false
	pet.shell = false
	if house_node != null:
		if pet.pet_type == "bird" and "swing" in house_node.decorations:
			pet.swung = true
		if pet.pet_type in ["fish", "aquatic_extended"] \
				and (pet.cleanliness < 30.0 or house_node.cleanliness < 30.0):
			pet.hiding = true
	if pet.pet_type in ["turtle", "reptile"] \
			and player.position.distance_to(pet.position) <= 28.0:
		pet.shell = true


func _update_wild_critters(delta: float) -> void:
	for index in range(wild_critters.size() - 1, -1, -1):
		if not is_instance_valid(wild_critters[index]):
			wild_critters.remove_at(index)
	if indoor or in_mine or _transitioning or _started == false:
		return
	_wild_spawn_timer -= delta
	if _wild_spawn_timer > 0.0 or wild_critters.size() >= 2:
		return
	_wild_spawn_timer = 22.0 + randf() * 18.0
	_spawn_wild_critter()


func _spawn_wild_critter() -> void:
	var critter := WildCritterScript.new()
	add_child(critter)
	var spawn := Vector2(
		randf_range(14.0, 44.0) * TILE,
		randf_range(19.0, 25.0) * TILE)
	critter.setup(self, spawn)
	wild_critters.append(critter)


func _clear_wild_critters() -> void:
	for critter: WildCritter in wild_critters:
		if is_instance_valid(critter):
			remove_child(critter)
			critter.queue_free()
	wild_critters.clear()
	_wild_spawn_timer = 12.0


func _place_pet_house_at(tile: Vector2i) -> void:
	var house := _find_house_data(_placing_pet_house_id)
	if house.is_empty():
		cancel_move_pet_house()
		return
	var house_type := str(house.get("type", ""))
	if not _can_place_pet_house(house_type, tile, _placing_pet_house_id):
		ui.toast("这里放不下栖息地", "bad")
		return
	var size := _pet_house_size(house_type)
	var world_position := Vector2(
		(float(tile.x) + float(size.x) * 0.5) * TILE,
		(float(tile.y) + float(size.y)) * TILE)
	var node := _find_house_node(_placing_pet_house_id)
	if node != null:
		node.position = world_position
		node.get_parent().move_child(node, node.get_parent().get_child_count() - 1)
	house["x"] = world_position.x
	house["y"] = world_position.y
	_placing_pet_house_id = ""
	ui.set_prompt("")
	ui.refresh_pet_panel()
	save_game()
	ui.toast("栖息地已搬迁到新位置", "good")


func rename_pet(pet_id: String, new_name: String) -> bool:
	var pet := _find_pet(pet_id)
	if pet == null:
		return false
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty():
		ui.toast("名字不能为空", "bad")
		return false
	if trimmed.length() > 8:
		trimmed = trimmed.substr(0, 8)
	if pet.name_changed:
		ui.toast("每只宠物只能改名一次", "bad")
		return false
	pet.pet_name = trimmed
	pet.name_changed = true
	save_game()
	return true


func house_refresh(pet: FarmPet) -> void:
	var house := _find_house_node(pet.house_id)
	if house != null:
		if not house.has_occupant(pet.pet_id):
			house.add_occupant(pet.pet_id)
		_update_house_missing(house)


func get_pet_panel_data(pet_id: String) -> Dictionary:
	var pet := _find_pet(pet_id)
	if pet == null:
		return {}
	var house := _find_house_data(pet.house_id)
	return {
		"id": pet.pet_id,
		"name": pet.get_display_name(),
		"base_name": pet.pet_name,
		"breed": pet.get_breed_name(),
		"type": pet.pet_type,
		"friendship": pet.friendship,
		"hunger": pet.hunger,
		"mood": pet.mood,
		"cleanliness": pet.cleanliness,
		"health": pet.health,
		"sick": pet.sick,
		"missing": pet.missing,
		"missing_days": pet.missing_days,
		"fed_today": pet.fed_today,
		"petted_today": pet.petted_today,
		"played_today": pet.played_today,
		"cleaned_today": pet.cleaned_today,
		"house_id": pet.house_id,
		"house_name": str(house.get("name", "无")),
		"house_cleanliness": float(house.get("cleanliness", 0.0)),
		"house_level": int(house.get("level", 1)),
		"house_capacity": _house_capacity(pet.house_id),
		"house_max_level": _house_max_level(pet.house_id),
		"house_upgrade_cost": _house_upgrade_cost(pet.house_id),
		"can_pet": pet.can_pet(),
		"can_play": pet.can_play(),
		"can_follow": pet.can_follow(),
		"food_id": str(DB.get_pet_type(pet.pet_type).get("food_id", "")),
		"young": pet.is_young_livestock(),
		"age_days": pet.age_days,
		"growth_days": int(DB.get_pet_config().get("young_growth_days", 5)),
		"walked_today": pet.walked_today,
		"name_changed": pet.name_changed,
		"released": pet.released,
		"release_timer": pet.release_timer,
		"battled_today": pet.battled_today,
		"basking": pet.basking,
		"sleeping": pet.sleeping,
		"can_release": bool(DB.get_pet_type(pet.pet_type).get("can_release", false)),
		"release_friendship": int(DB.get_pet_type(pet.pet_type).get(
			"release_friendship", 50)),
		"next_decoration": get_next_pet_decoration(pet.house_id),
	}


func get_pet_ids() -> Array:
	var result: Array = []
	for pet: FarmPet in pets:
		result.append(pet.pet_id)
	return result


func buy_pet_food(food_id: String, count := 1) -> void:
	var definition := DB.get_pet_food(food_id)
	if definition.is_empty():
		return
	var total := int(definition.get("price", 0)) * count
	if money < total:
		ui.toast("钱不够", "bad")
		return
	var item := {"item_id": food_id, "category": "pet_food", "count": count,
		"price": int(definition.get("price", 0))}
	if not inventory.can_add(item):
		ui.toast("背包空间不够", "bad")
		return
	money -= total
	inventory.add_item(item)
	ui.refresh_hud()
	ui.refresh_shop()
	ui.toast("买了%s ×%d" % [str(definition.get("name", food_id)), count], "good")


func _advance_pets() -> void:
	for pet: FarmPet in pets.duplicate():
		pet.advance_day()
		if pet.missing:
			if pet.tick_missing_day():
				_remove_pet_permanently(pet)
				continue
		if pet.is_young_livestock() and not pet.missing:
			if pet.age_days >= int(DB.get_pet_config().get("young_growth_days", 5)):
				_grow_young_livestock(pet)
				continue
		if pet.gift_ready:
			ui.toast("%s带了个小礼物回来" % pet.get_display_name(), "good")
	for entry: Dictionary in pet_houses:
		var node := _find_house_node(str(entry.get("id", "")))
		if node == null:
			continue
		node.advance_day()
		entry["cleanliness"] = node.cleanliness
		_update_house_missing(node)


func _adult_for_young(breed_id: String) -> String:
	if "foal" in breed_id:
		return "horse"
	if "lamb" in breed_id:
		return "sheep"
	if "calf" in breed_id:
		return "cow"
	if "duckling" in breed_id:
		return "duck"
	if "gosling" in breed_id:
		return "goose"
	if "piglet" in breed_id:
		return "miniature_pig"
	return ""


## 幼年畜牧长大后转为坐骑 / 畜牧动物；空间不足时保持幼年状态，次日再试。
func _grow_young_livestock(pet: FarmPet) -> bool:
	var adult_type := _adult_for_young(pet.breed)
	if adult_type.is_empty():
		return false
	if adult_type == "horse":
		if get_building_level("stable") < 1:
			return false
		if _mounts_in("stable").size() >= get_building_capacity("stable"):
			return false
		var mount_data := {
			"id": _new_mount_id("horse"),
			"type": "horse",
			"name": pet.pet_name,
			"friendship": pet.friendship,
			"stamina": 100.0,
			"max_stamina": 100.0,
			"stored_in": "stable",
			"position": {},
			"cargo": {"capacity": 0, "items": []},
			"fed_day": -1,
		}
		mounts.append(mount_data)
		var park := _park_position_for_mount(mount_data)
		mount_data["position"] = {"x": park.x, "y": park.y}
		_spawn_mount_node(mount_data)
		var grown_name := pet.pet_name
		_remove_grown_pet(pet)
		ui.toast("%s长大了，住进了马厩！" % grown_name, "good")
		return true

	var building := "coop" if adult_type in ["duck", "goose"] else "barn"
	if _animals_in(building).size() >= get_building_capacity(building):
		return false
	var origin := COOP_BASE if building == "coop" else BARN_BASE
	var animal: FarmAnimal = AnimalScript.new()
	add_child(animal)
	animal.setup(adult_type,
		origin + Vector2(randf_range(-30.0, 30.0), randf_range(0.0, 20.0)), building)
	animal.animal_name = pet.pet_name
	animal.friendship = pet.friendship
	animal.age_days = int(DB.get_animal_rules().get("purchased_age_days", 30))
	animals.append(animal)
	var grown_name := pet.pet_name
	_remove_grown_pet(pet)
	ui.toast("%s长大了，现在是%s！" % [grown_name, animal.get_display_name()], "good")
	return true


func _remove_grown_pet(pet: FarmPet) -> void:
	var house := _find_house_node(pet.house_id)
	if house != null:
		house.remove_occupant(pet.pet_id)
	pets.erase(pet)
	remove_child(pet)
	pet.queue_free()


func _remove_pet_permanently(pet: FarmPet) -> void:
	var house := _find_house_node(pet.house_id)
	if house != null:
		house.remove_occupant(pet.pet_id)
	pets.erase(pet)
	ui.toast("%s已经离开农场了……" % pet.get_display_name(), "bad")
	remove_child(pet)
	pet.queue_free()


## 自宅室内：好感 ≥60 的猫到床边睡觉（只在家里显示）。
func _place_indoor_pets() -> void:
	_indoor_pet_positions.clear()
	if _interior == null:
		return
	for pet: FarmPet in pets:
		if pet.pet_type == "cat" and pet.friendship >= 60.0 and not pet.missing:
			_indoor_pet_positions[pet.pet_id] = pet.position
			pet.position = _interior.origin + Vector2(2.6 * TILE, 2.9 * TILE)
			pet.visible = true
			pet.sleeping = true
			pet.released = false


func _restore_indoor_pets() -> void:
	for pet_id: Variant in _indoor_pet_positions.keys():
		var pet := _find_pet(str(pet_id))
		if pet != null:
			pet.position = _indoor_pet_positions[pet_id]
			pet.sleeping = false
	_indoor_pet_positions.clear()


func _update_house_missing(node: PetHouse) -> void:
	var missing := false
	for pet_id: String in node.occupancy:
		var pet := _find_pet(pet_id)
		if pet != null and pet.missing:
			missing = true
			break
	node.has_missing = missing


func _clear_pets() -> void:
	for pet: FarmPet in pets:
		remove_child(pet)
		pet.queue_free()
	pets.clear()
	for house_id: Variant in _pet_house_nodes.keys():
		var node: PetHouse = _pet_house_nodes[house_id]
		if node != null and is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_pet_house_nodes.clear()
	pet_houses.clear()
	_refresh_pet_houses()


## 同步旧狗屋/猫屋的隐藏状态与栖息地提示。
func _refresh_pet_houses() -> void:
	if _dog_house_prop != null:
		_dog_house_prop.visible = false
	if _cat_house_prop != null:
		_cat_house_prop.visible = false
	for house_id: Variant in _pet_house_nodes.keys():
		var node: PetHouse = _pet_house_nodes[house_id]
		if node != null and is_instance_valid(node):
			_update_house_missing(node)


func _sync_pet_house_data() -> void:
	for entry: Dictionary in pet_houses:
		var node := _find_house_node(str(entry.get("id", "")))
		if node == null:
			continue
		entry["occupants"] = node.occupancy.duplicate()
		entry["decorations"] = node.decorations.duplicate()
		entry["cleanliness"] = node.cleanliness
		entry["x"] = node.position.x
		entry["y"] = node.position.y


func _pets_to_save() -> Array:
	var result: Array = []
	for pet: FarmPet in pets:
		result.append(pet.to_save())
	return result


func _spawn_pet_from_save(data: Dictionary) -> void:
	var pet: FarmPet = PetScript.new()
	add_child(pet)
	pet.from_save(data)
	if pet.pet_id.is_empty():
		pet.pet_id = _new_pet_id(pet.pet_type)
	var house := _find_house_data(pet.house_id)
	if house.is_empty():
		var type_definition := DB.get_pet_type(pet.pet_type)
		house = _find_free_pet_house(type_definition)
		if house.is_empty():
			var house_types: Array = type_definition.get("house_types", [])
			house = _create_pet_house(str(house_types[0]) if not house_types.is_empty() else "dog_house",
				pet.get_breed_name())
		if not house.is_empty():
			pet.house_id = str(house.get("id", ""))
	var node := _find_house_node(pet.house_id)
	if node != null:
		if not node.has_occupant(pet.pet_id):
			node.add_occupant(pet.pet_id)
		pet.position = node.get_anchor()
		var occupants: Array = house.get("occupants", [])
		if not pet.pet_id in occupants:
			occupants.append(pet.pet_id)
		house["occupants"] = occupants
	pets.append(pet)
	_refresh_pet_houses()


# ============================================================
# 牧场
# ============================================================

func _feed_prompt(building: String) -> String:
	var count := _animals_in(building).size()
	if count == 0:
		return "食槽空着 · 去商店买动物吧"
	if bool(building_fed.get(building, false)):
		return "动物们今天已经吃饱了"
	var feed := inventory.count_item(str(DB.get_animal_rules().get("feed_item_id", "feed")), "feed")
	return "按 E 喂食（%d 只 · 需要 %d 份饲料，现有 %d 份）" % [count, count, feed]


func _animals_in(building: String) -> Array:
	var result: Array = []
	for animal: FarmAnimal in animals:
		if animal.building == building:
			result.append(animal)
	return result


func get_shop_animal_ids() -> Array:
	var result: Array = []
	for definition: Dictionary in DB.get_all_animals():
		var category := str(definition.get("category", ""))
		# 特殊箱养（蜂箱 / 蚕房等）后续版本再开放
		if category == "special":
			continue
		var barn_type := str(definition.get("barn_type", "coop"))
		if barn_type != "coop" and barn_type != "barn":
			continue
		if _animals_in(barn_type).size() >= get_building_capacity(barn_type):
			continue
		result.append(str(definition.get("id", "")))
	return result


func can_buy_animal(animal_id: String) -> bool:
	var definition := DB.get_animal(animal_id)
	if definition.is_empty():
		return false
	var barn_type := str(definition.get("barn_type", "coop"))
	if barn_type != "coop" and barn_type != "barn":
		return false
	return _livestock_occupancy(barn_type) < get_building_capacity(barn_type)


func buy_animal(animal_id: String) -> void:
	var definition := DB.get_animal(animal_id)
	if definition.is_empty():
		return
	if not can_buy_animal(animal_id):
		ui.toast("栏位满了，先扩建再说", "bad")
		return
	var price := int(definition.get("buy_price", 0))
	if money < price:
		ui.toast("钱不够", "bad")
		return

	money -= price
	var barn_type := str(definition.get("barn_type", "coop"))
	var origin := COOP_BASE if barn_type == "coop" else BARN_BASE
	var animal: FarmAnimal = AnimalScript.new()
	add_child(animal)
	animal.setup(
		animal_id,
		origin + Vector2(randf_range(-40.0, 40.0), randf_range(-6.0, 26.0)),
		barn_type
	)
	var rules := DB.get_animal_rules()
	animal.age_days = int(rules.get("purchased_age_days", 30))
	animals.append(animal)

	ui.refresh_hud()
	ui.refresh_shop()
	ui.toast("买了一只%s，记得每天喂食" % str(definition.get("name", animal_id)), "good")


## 购买（未拥有）或穿戴（已拥有）饰品。
func buy_or_wear_accessory(accessory_id: String) -> void:
	var definition := DB.get_accessory(accessory_id)
	if definition.is_empty():
		return
	var slot := str(definition.get("slot", "head"))

	if accessory_id in accessories_owned:
		# 已拥有：切换穿戴（同部位只能一件）
		accessories_equipped[slot] = "" if str(accessories_equipped.get(slot, "")) == accessory_id else accessory_id
		_apply_appearance(_look_with_accessories())
		save_game()
		ui.refresh_shop()
		ui.toast("已更换饰品", "good")
		return

	var price := int(definition.get("price", 0))
	if money < price:
		ui.toast("钱不够", "bad")
		return
	money -= price
	accessories_owned.append(accessory_id)
	accessories_equipped[slot] = accessory_id
	_apply_appearance(_look_with_accessories())
	ui.refresh_hud()
	ui.refresh_shop()
	AudioManager.play_sfx("coin")
	ui.toast("买了 %s 并戴上" % str(definition.get("name", accessory_id)), "good")


func _look_with_accessories() -> Dictionary:
	var look: Dictionary = player.look.duplicate(true)
	look["accessories"] = accessories_equipped.duplicate(true)
	return look


func _open_shop_if_open() -> void:
	var festival := get_today_festival()
	if not festival.is_empty():
		ui.toast("今天是%s，杂货铺休息" % str(festival.get("name", "节日")), "bad")
		return
	var status := DB.is_shop_open("general_store", time.get_display_minutes())
	if not bool(status.get("open", true)):
		ui.toast(str(status.get("reason", "现在还没开门")), "bad")
		return
	ui.open_shop()


func get_feed_price() -> int:
	return int(DB.get_animal_rules().get("feed_price", 0))


func buy_feed(quantity: int) -> void:
	var price := get_feed_price()
	if price <= 0:
		return
	var total := price * quantity
	if money < total:
		ui.toast("钱不够", "bad")
		return
	var feed_id := str(DB.get_animal_rules().get("feed_item_id", "feed"))
	if not inventory.can_add({"item_id": feed_id, "category": "feed", "count": quantity}):
		ui.toast("背包空间不够", "bad")
		return
	money -= total
	inventory.add_item({"item_id": feed_id, "category": "feed", "count": quantity})
	ui.refresh_hud()
	ui.refresh_shop()
	ui.toast("买了饲料 ×%d" % quantity, "good")


## 在食槽旁喂食某个栏舍里的所有动物。
func feed_building(building: String) -> void:
	var group := _animals_in(building)
	if group.is_empty():
		ui.toast("这里还没有动物", "bad")
		return
	if bool(building_fed.get(building, false)):
		ui.toast("今天已经喂过了", "bad")
		return

	var feed_id := str(DB.get_animal_rules().get("feed_item_id", "feed"))
	var need := group.size()
	var have := inventory.count_item(feed_id, "feed")
	if have < need:
		ui.toast("饲料不够：需要 %d 份，现有 %d 份" % [need, have], "bad")
		return

	inventory.remove_item(feed_id, need, "feed")
	building_fed[building] = true
	for animal: FarmAnimal in group:
		animal.feed()
	AudioManager.play_sfx("feed")
	ui.toast("喂饱了 %d 只动物，明天就会有产出" % need, "good")


func _interact_animal(animal: Variant) -> void:
	if not (animal is FarmAnimal):
		return
	var target: FarmAnimal = animal

	if target.produce_ready:
		var product := target.collect_product()
		if not product.is_empty():
			if not inventory.can_add(product):
				ui.toast("背包满了，先卖点东西", "bad")
				target.produce_ready = true
				return
			inventory.add_item(product)
			_play_animal_product_effect(target, str(product.get("item_id", "")))
			_unlock("animal", str(product.get("item_id", "")))
			ui.toast(
				"收取了%s的%s" % [target.get_display_name(), str(product.get("name", ""))],
				"good"
			)
		return

	if target.pet():
		var rules := DB.get_animal_rules()
		ui.toast(
			"摸了摸%s，好感 +%d（%d/%d）" % [
				target.get_display_name(),
				int(rules.get("friendship_per_pet", 5)),
				int(target.friendship),
				int(target.friendship_max),
			],
			"good"
		)
	else:
		ui.toast("今天已经摸过了，明天再来吧")


# ============================================================
# 骑乘
# ============================================================

func _mount_data(mount_id: String) -> Dictionary:
	for entry: Dictionary in mounts:
		if str(entry.get("id", "")) == mount_id:
			return entry
	return {}


func _mounts_in(stored_in: String) -> Array:
	var result: Array = []
	for entry: Dictionary in mounts:
		if str(entry.get("stored_in", "")) == stored_in:
			result.append(entry)
	return result


## 供 UI 使用：附带“今天是否喂过”。
func get_mounts_in(stored_in: String) -> Array:
	var result: Array = []
	var today := time.get_absolute_day()
	for entry: Dictionary in _mounts_in(stored_in):
		var copy: Dictionary = entry.duplicate(true)
		copy["fed_today"] = int(entry.get("fed_day", -1)) == today
		copy["petted_today"] = int(entry.get("petted_day", -1)) == today
		var cargo: Variant = entry.get("cargo", {})
		copy["cargo_capacity"] = int((cargo as Dictionary).get("capacity", 0)) \
			if cargo is Dictionary else 0
		copy["cargo_used"] = _cargo_used(entry)
		result.append(copy)
	return result


func _default_park_position(mount_type: String) -> Vector2:
	match mount_type:
		"bicycle":
			return BIKE_SHED_PARK
		"ostrich":
			return OSTRICH_HOUSE_PARK
		"cow", "alpaca":
			return BARN_PARK
		_:
			return STABLE_PARK


## 同栏位的多匹坐骑在停放点横向错开，避免完全重叠。
func _park_position_for_mount(data: Dictionary) -> Vector2:
	var base := _default_park_position(str(data.get("type", "horse")))
	var stored_in := str(data.get("stored_in", ""))
	if stored_in.is_empty():
		return base
	var siblings := _mounts_in(stored_in)
	if siblings.is_empty():
		return base
	var index := siblings.find(data)
	if index < 0:
		index = 0
	var offset := (float(index) - float(siblings.size() - 1) * 0.5) * 38.0
	return base + Vector2(offset, 0.0)


func _mount_park_from_data(data: Dictionary) -> Vector2:
	var stored: Variant = data.get("position", {})
	if stored is Dictionary and (stored as Dictionary).has("x"):
		return Vector2(
			float((stored as Dictionary).get("x", 0.0)),
			float((stored as Dictionary).get("y", 0.0)))
	return _park_position_for_mount(data)


func _normalize_mount_data(data: Dictionary) -> void:
	var type_id := str(data.get("type", "horse"))
	var definition := DB.get_mount(type_id)
	if str(data.get("id", "")).is_empty():
		data["id"] = _new_mount_id(type_id)
	if not data.has("max_stamina"):
		data["max_stamina"] = float(definition.get("max_stamina", 0.0))
	if not data.has("stamina"):
		data["stamina"] = float(data.get("max_stamina", 0.0))
	if not data.has("friendship"):
		data["friendship"] = 50.0
	var cargo: Variant = data.get("cargo", {})
	var capacity := int(definition.get("cargo_capacity", 0))
	if cargo is Dictionary:
		(cargo as Dictionary)["capacity"] = int(
			(cargo as Dictionary).get("capacity", capacity))
		if not ((cargo as Dictionary).get("items", null) is Array):
			(cargo as Dictionary)["items"] = []
		data["cargo"] = cargo
	else:
		data["cargo"] = {"capacity": capacity, "items": []}


func _new_mount_id(mount_type: String) -> String:
	var index := 1
	while not _mount_data("%s_%d" % [mount_type, index]).is_empty():
		index += 1
	return "%s_%d" % [mount_type, index]


func _build_mount_nodes() -> void:
	for mount_id: Variant in mount_nodes.keys():
		var old: RideMount = mount_nodes[mount_id]
		if old != null and is_instance_valid(old):
			remove_child(old)
			old.queue_free()
	mount_nodes.clear()
	for entry: Dictionary in mounts:
		_spawn_mount_node(entry)


func _spawn_mount_node(data: Dictionary) -> RideMount:
	_normalize_mount_data(data)
	var type_id := str(data.get("type", "horse"))
	var definition := DB.get_mount(type_id)
	var node := MountScript.new()
	node.mount_name = str(data.get("name", definition.get("name", type_id)))
	node.max_stamina = float(data.get("max_stamina", definition.get("max_stamina", 0.0)))
	node.stamina = clampf(float(data.get("stamina", node.max_stamina)),
		0.0, maxf(0.0, node.max_stamina))
	node.fatigue = node.max_stamina > 0.0 and node.stamina < node.max_stamina * 0.2
	var cargo: Dictionary = data.get("cargo", {})
	node.cargo_capacity = int(cargo.get("capacity", 0))
	node.cargo_used = _cargo_used(data)
	add_child(node)
	node.setup(type_id, _mount_park_from_data(data))
	mount_nodes[str(data.get("id", ""))] = node
	return node


func _mount_node_id(node: RideMount) -> String:
	for mount_id: Variant in mount_nodes.keys():
		if mount_nodes[mount_id] == node:
			return str(mount_id)
	return ""


func _nearest_parked_mount() -> RideMount:
	var best: RideMount = null
	var best_distance := 52.0
	for mount_id: Variant in mount_nodes.keys():
		var node: RideMount = mount_nodes[mount_id]
		if node == null or not is_instance_valid(node) or node.ridden:
			continue
		var distance := player.position.distance_to(node.position)
		if distance <= best_distance:
			best_distance = distance
			best = node
	return best


func _nearest_rideable_cow() -> FarmAnimal:
	var best: FarmAnimal = null
	var best_distance := 58.0
	for animal: FarmAnimal in animals:
		if not can_ride_animal(animal):
			continue
		var distance := player.position.distance_to(animal.position)
		if distance <= best_distance:
			best_distance = distance
			best = animal
	return best


func can_ride_animal(animal: FarmAnimal) -> bool:
	if animal == null or animal.type_id != "cow":
		return false
	var definition := DB.get_mount("cow")
	return animal.age_days >= int(definition.get("min_age_days", 3)) \
		and animal.friendship >= float(definition.get("min_friendship", 60.0)) \
		and not animal.sick


func can_buy_mount(mount_type: String) -> Dictionary:
	var definition := DB.get_mount(mount_type)
	if definition.is_empty():
		return {"ok": false, "reason": "未知坐骑"}
	if mount_type == "cow":
		return {"ok": false, "reason": "牛不需要购买"}
	var stored_in := str(definition.get("stored_in", ""))
	var building_name := str(DB.get_building_def(stored_in).get("name", stored_in))
	var min_level := int(definition.get("min_building_level", 1))
	if get_building_level(stored_in) < min_level:
		if min_level <= 1:
			return {"ok": false, "reason": "需要先建造%s" % building_name}
		return {"ok": false, "reason": "%s需要 %d 级" % [building_name, min_level]}
	if _building_days_left(stored_in) > 0:
		return {"ok": false, "reason": "%s正在建造中" % building_name}
	# 羊驼与普通畜牧共用畜棚容量；自行车与三轮车共用自行车棚容量。
	var used := _mounts_in(stored_in).size()
	if stored_in == "barn":
		used += _animals_in("barn").size()
	if used >= get_building_capacity(stored_in):
		return {"ok": false, "reason": "%s栏位已满" % building_name}
	if money < int(definition.get("price", 0)):
		return {"ok": false, "reason": "金币不足"}
	return {"ok": true}


func get_mount_shop_goods() -> Array:
	var result: Array = []
	for mount_type: String in [
		"horse", "donkey", "camel", "ostrich", "alpaca", "bicycle", "tricycle",
	]:
		var definition := DB.get_mount(mount_type)
		if definition.is_empty():
			continue
		var check := can_buy_mount(mount_type)
		var stored_in := str(definition.get("stored_in", ""))
		var building_name := str(DB.get_building_def(stored_in).get("name", stored_in))
		var desc := "%s · 速度 %d" % [building_name, int(definition.get("speed", 0))]
		var reason := str(check.get("reason", ""))
		if not reason.is_empty():
			desc = reason
		result.append({
			"type": mount_type,
			"name": str(definition.get("name", mount_type)),
			"price": int(definition.get("price", 0)),
			"desc": desc,
			"can_buy": bool(check.get("ok", false)),
		})
	return result


func buy_mount(mount_type: String) -> void:
	var check := can_buy_mount(mount_type)
	if not bool(check.get("ok", false)):
		ui.toast(str(check.get("reason", "无法购买")), "bad")
		return
	var definition := DB.get_mount(mount_type)
	var stored_in := str(definition.get("stored_in", ""))
	var names: Array = definition.get("default_names", [])
	var display := str(definition.get("name", mount_type))
	if not names.is_empty():
		display = str(names[_mounts_in(stored_in).size() % names.size()])
	var data := {
		"id": _new_mount_id(mount_type),
		"type": mount_type,
		"name": display,
		"friendship": 50.0,
		"stamina": float(definition.get("max_stamina", 0.0)),
		"max_stamina": float(definition.get("max_stamina", 0.0)),
		"stored_in": stored_in,
		"position": {},
		"cargo": {
			"capacity": int(definition.get("cargo_capacity", 0)),
			"items": [],
		},
		"fed_day": -1,
	}
	money -= int(definition.get("price", 0))
	mounts.append(data)
	var park := _park_position_for_mount(data)
	data["position"] = {"x": park.x, "y": park.y}
	_spawn_mount_node(data)
	ui.refresh_hud()
	ui.refresh_shop()
	AudioManager.play_sfx("coin")
	ui.toast("买下了%s，停在%s" % [
		display, str(DB.get_building_def(stored_in).get("name", stored_in)),
	], "good")
	save_game()


func feed_mount(mount_id: String) -> bool:
	var data := _mount_data(mount_id)
	if data.is_empty():
		return false
	if str(data.get("type", "")) == "bicycle":
		ui.toast("自行车不需要喂食", "bad")
		return false
	var today := time.get_absolute_day()
	if int(data.get("fed_day", -1)) == today:
		ui.toast("今天已经喂过了", "bad")
		return false
	var feed_id := str(DB.get_animal_rules().get("feed_item_id", "feed"))
	if inventory.count_item(feed_id, "feed") < 1:
		ui.toast("没有饲料，先去杂货铺买", "bad")
		return false
	inventory.remove_item(feed_id, 1, "feed")
	var definition := DB.get_mount(str(data.get("type", "")))
	var gain := float(definition.get("friendship_gain_feed", 5.0))
	data["fed_day"] = today
	data["friendship"] = minf(100.0, float(data.get("friendship", 0.0)) + gain)
	save_game()
	ui.toast("%s吃得很开心（好感 +%d）" % [
		str(data.get("name", "")), int(gain),
	], "good")
	return true


## 抚摸坐骑：羊驼等配置了更高好感收益。
func pet_mount(mount_id: String) -> bool:
	var data := _mount_data(mount_id)
	if data.is_empty():
		return false
	var definition := DB.get_mount(str(data.get("type", "")))
	var gain := float(definition.get("friendship_gain_pet", 5.0))
	var today := time.get_absolute_day()
	if int(data.get("petted_day", -1)) == today:
		ui.toast("今天已经摸过了", "bad")
		return false
	data["petted_day"] = today
	data["friendship"] = minf(100.0, float(data.get("friendship", 0.0)) + gain)
	save_game()
	ui.toast("摸了摸%s（好感 +%d）" % [str(data.get("name", "")), int(gain)], "good")
	return true


## 畜棚可骑乘列表：牛（动物本体）+ 羊驼（坐骑数据由 UI 另取）。
func get_barn_mount_entries() -> Array:
	var result: Array = []
	for index in animals.size():
		var animal: FarmAnimal = animals[index]
		if animal.type_id != "cow":
			continue
		var rideable := can_ride_animal(animal)
		result.append({
			"kind": "cow",
			"index": index,
			"name": animal.get_display_name(),
			"friendship": animal.friendship,
			"stamina": animal.ride_stamina,
			"max_stamina": animal.ride_stamina_max,
			"rideable": rideable,
			"reason": "" if rideable else "需成年且好感≥60 且未生病",
		})
	return result


func mount_barn_animal(index: int) -> void:
	if index < 0 or index >= animals.size():
		return
	mount_cow(animals[index])


## 天气影响：骆驼免疫暴雨/暴雪；鸵鸟羽毛怕湿，减速 30%；其余 -20%。
func _ride_weather_multiplier(definition: Dictionary) -> float:
	var weather := str(time.weather)
	var immune: Array = definition.get("weather_immune", [])
	if weather in immune:
		return 1.0
	if weather in ["storm", "blizzard"]:
		return maxf(0.0, 1.0 - float(definition.get("weather_penalty_ratio", 0.0)))
	return 1.0


## 地形特性：羊驼草地 +5%、鸵鸟沙地/草地 +10%、三轮车石板路 +10%。
func _ride_terrain_multiplier(definition: Dictionary) -> float:
	var tile := player.get_tile_position()
	if tile.x < 0 or tile.y < 0 or tile.x >= WORLD_W or tile.y >= WORLD_H:
		return 1.0
	var ratio := float(definition.get("terrain_bonus_ratio", 0.0))
	if ratio <= 0.0:
		return 1.0
	var terrain := int(_terrain[tile.y * WORLD_W + tile.x])
	var bonus: Array = definition.get("terrain_bonus", [])
	if terrain == GroundTileMapScript.GRASS and "grassland" in bonus:
		return 1.0 + ratio
	if terrain == GroundTileMapScript.SAND and "sand" in bonus:
		return 1.0 + ratio
	if terrain == GroundTileMapScript.PATH and "stone_path" in bonus:
		return 1.0 + ratio
	return 1.0


func _ride_speeds(definition: Dictionary) -> Vector2:
	var multiplier := _ride_weather_multiplier(definition) * _ride_terrain_multiplier(definition)
	return Vector2(
		float(definition.get("speed", 140.0)) * multiplier,
		float(definition.get("sprint_speed", 200.0)) * multiplier)


## R 键：骑乘 / 下坐骑。优先骑乘附近的停放坐骑，其次骑符合条件的牛。
func toggle_ride() -> void:
	if player.riding:
		dismount_mount()
		return
	if indoor or in_mine or _transitioning:
		ui.toast("这里不能骑乘", "bad")
		return
	var parked := _nearest_parked_mount()
	if parked != null:
		mount_mount(_mount_node_id(parked))
		return
	var cow := _nearest_rideable_cow()
	if cow != null:
		mount_cow(cow)
		return
	for animal: FarmAnimal in animals:
		if animal.type_id == "cow" and player.position.distance_to(animal.position) <= 58.0:
			ui.toast("牛需要成年、好感≥60 且未生病", "bad")
			return
	# 畜棚门口：打开牛 / 羊驼选择面板
	if player.position.distance_to(BARN_DOOR_POINT) <= 64.0 \
			or player.position.distance_to(BARN_POINT) <= 64.0:
		ui.open_mount_panel("barn")
		return
	ui.toast("附近没有可骑乘的坐骑", "bad")


func mount_mount(mount_id: String, instant := false) -> void:
	if player.riding or _transitioning or indoor or in_mine or ui.is_modal_open():
		return
	var data := _mount_data(mount_id)
	var node: RideMount = mount_nodes.get(mount_id)
	if data.is_empty() or node == null or not is_instance_valid(node):
		ui.toast("这匹坐骑不在附近", "bad")
		return
	var definition := DB.get_mount(str(data.get("type", "horse")))
	var min_friendship := float(definition.get("min_friendship", 0.0))
	if float(data.get("friendship", 0.0)) < min_friendship:
		ui.toast("%s需要好感 %d 才能骑乘" % [
			str(data.get("name", "坐骑")), int(min_friendship),
		], "bad")
		return
	var speeds := _ride_speeds(definition)
	_transitioning = true
	player.input_locked = true
	player.set_sitting(false)
	player.set_riding(true, speeds.x, speeds.y,
		float(definition.get("rider_offset", -13.5)))
	if not instant:
		# 上坐骑动画期间锁定移动
		await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or not is_instance_valid(node):
		return
	riding_mount = node
	riding_mount_id = mount_id
	riding_animal = null
	_bike_sprint_cd = 0.0
	_bike_sprint_used = false
	node.set_ridden(true)
	node.follow_target = player
	node.position = player.position + Vector2(0, 2)
	var cargo: Dictionary = data.get("cargo", {})
	node.cargo_capacity = int(cargo.get("capacity", 0))
	node.cargo_used = _cargo_used(data)
	player.z_index = 0
	_transitioning = false
	player.input_locked = false
	ui.toast("骑上了%s · Shift 冲刺" % str(data.get("name", "")), "good")


func mount_cow(animal: FarmAnimal, instant := false) -> void:
	if player.riding or _transitioning or indoor or in_mine or ui.is_modal_open():
		return
	if not can_ride_animal(animal):
		ui.toast("牛需要成年、好感≥60 且未生病", "bad")
		return
	var definition := DB.get_mount("cow")
	var speeds := _ride_speeds(definition)
	_transitioning = true
	player.input_locked = true
	player.set_sitting(false)
	player.set_riding(true, speeds.x, speeds.y,
		float(definition.get("rider_offset", -11.5)))
	if not instant:
		await get_tree().create_timer(0.5).timeout
	if not is_inside_tree() or not is_instance_valid(animal):
		return
	var visual := MountScript.new()
	add_child(visual)
	visual.setup("cow", player.position + Vector2(0, 2))
	visual.mount_name = animal.get_display_name()
	visual.max_stamina = maxf(1.0, animal.ride_stamina_max)
	visual.stamina = animal.ride_stamina
	visual.fatigue = visual.stamina < visual.max_stamina * 0.2
	visual.set_ridden(true)
	visual.follow_target = player
	riding_mount = visual
	riding_animal = animal
	riding_mount_id = ""
	animal.visible = false
	animal.set_process(false)
	_transitioning = false
	player.input_locked = false
	ui.toast("骑上了%s · Shift 冲刺" % animal.get_display_name(), "good")


func dismount_mount(instant := false) -> void:
	if riding_mount == null or not is_instance_valid(riding_mount):
		return
	_transitioning = true
	player.input_locked = true
	if not instant:
		await get_tree().create_timer(0.5).timeout
	var node := riding_mount
	var data := _mount_data(riding_mount_id)
	var is_cow := riding_animal != null
	var dismount_position := node.position
	var player_drop := dismount_position
	if is_cow:
		var cow: FarmAnimal = riding_animal
		cow.position = dismount_position
		cow.visible = true
		cow.set_process(true)
		cow.ride_stamina = node.stamina
		riding_animal = null
		remove_child(node)
		node.queue_free()
	else:
		node.set_ridden(false)
		node.follow_target = null
		var park := _park_position_for_mount(data)
		node.position = park
		player_drop = park
		if not data.is_empty():
			data["position"] = {"x": park.x, "y": park.y}
			data["stamina"] = node.stamina
	player.set_riding(false)
	player.position = player_drop + Vector2(0, 24)
	player.facing = "down"
	player.z_index = 0
	riding_mount = null
	riding_mount_id = ""
	_transitioning = false
	player.input_locked = false
	if not instant:
		save_game()
		ui.toast("下坐骑了")


func _update_riding(delta: float) -> void:
	_bike_sprint_cd = maxf(0.0, _bike_sprint_cd - delta)
	if riding_mount == null or not is_instance_valid(riding_mount):
		player.ride_sprint_blocked = false
		_regen_mount_stamina(delta)
		return
	var mount_type := "horse"
	var max_stamina := 0.0
	if riding_animal != null:
		mount_type = "cow"
		max_stamina = riding_animal.ride_stamina_max
	else:
		var data := _mount_data(riding_mount_id)
		mount_type = str(data.get("type", "horse"))
		max_stamina = float(data.get("max_stamina", 0.0))
	var definition := DB.get_mount(mount_type)
	var speeds := _ride_speeds(definition)
	player.ride_speed = speeds.x
	player.ride_sprint_speed = speeds.y
	if riding_animal == null:
		var mounted := _mount_data(riding_mount_id)
		var cargo: Dictionary = mounted.get("cargo", {})
		riding_mount.cargo_capacity = int(cargo.get("capacity", 0))
		riding_mount.cargo_used = _cargo_used(mounted)

	if max_stamina <= 0.0:
		# 自行车：无耐力，冲刺后冷却 2 秒
		player.ride_sprint_blocked = _bike_sprint_cd > 0.0
		if player.ride_sprinting:
			_bike_sprint_used = true
		elif _bike_sprint_used:
			_bike_sprint_used = false
			_bike_sprint_cd = float(definition.get("sprint_cooldown", 2.0))
		return

	var current := _active_ride_stamina()
	player.ride_sprint_blocked = current <= 0.0
	if player.ride_sprinting and player.is_moving() and not player.ride_sprint_blocked:
		current = maxf(0.0,
			current - float(definition.get("sprint_cost_per_sec", 10.0)) * delta)
		_set_active_ride_stamina(current)
	riding_mount.stamina = current
	riding_mount.fatigue = current < max_stamina * 0.2


func _active_ride_stamina() -> float:
	if riding_animal != null:
		return riding_animal.ride_stamina
	var data := _mount_data(riding_mount_id)
	return float(data.get("stamina", 0.0))


func _set_active_ride_stamina(value: float) -> void:
	if riding_animal != null:
		riding_animal.ride_stamina = value
		return
	var data := _mount_data(riding_mount_id)
	if not data.is_empty():
		data["stamina"] = value


func _regen_mount_stamina(delta: float) -> void:
	for entry: Dictionary in mounts:
		var definition := DB.get_mount(str(entry.get("type", "horse")))
		var max_stamina := float(definition.get("max_stamina", 0.0))
		if max_stamina <= 0.0:
			continue
		var regen := float(definition.get("stamina_regen_per_min", 0.0))
		var current := minf(max_stamina,
			float(entry.get("stamina", max_stamina)) + regen * delta / 60.0)
		entry["stamina"] = current
		var node: RideMount = mount_nodes.get(str(entry.get("id", "")))
		if node != null and is_instance_valid(node):
			node.stamina = current
			node.fatigue = current < max_stamina * 0.2
	var cow_definition := DB.get_mount("cow")
	var cow_regen := float(cow_definition.get("stamina_regen_per_min", 4.0))
	for animal: FarmAnimal in animals:
		if animal.type_id != "cow":
			continue
		animal.ride_stamina = minf(animal.ride_stamina_max,
			animal.ride_stamina + cow_regen * delta / 60.0)


# ---------- 载货 ----------

func _cargo_used(data: Dictionary) -> int:
	var used := 0
	var cargo: Variant = data.get("cargo", {})
	if cargo is Dictionary:
		for stack: Variant in (cargo as Dictionary).get("items", []):
			if stack is Dictionary:
				used += int((stack as Dictionary).get("count", 0))
	return used


func get_mount_cargo(mount_id: String) -> Dictionary:
	var data := _mount_data(mount_id)
	if data.is_empty():
		return {}
	var cargo: Variant = data.get("cargo", {})
	if not (cargo is Dictionary):
		return {}
	var items: Variant = (cargo as Dictionary).get("items", [])
	return {
		"id": mount_id,
		"name": str(data.get("name", "")),
		"capacity": int((cargo as Dictionary).get("capacity", 0)),
		"used": _cargo_used(data),
		"items": (items as Array).duplicate(true) if items is Array else [],
	}


## 把当前手持（或指定槽位）的整叠物品存入坐骑货袋。
func store_held_to_cargo(mount_id: String, slot_index := -1) -> bool:
	var data := _mount_data(mount_id)
	if data.is_empty():
		return false
	var cargo: Variant = data.get("cargo", {})
	if not (cargo is Dictionary):
		ui.toast("这个坐骑没有载货槽", "bad")
		return false
	var capacity := int((cargo as Dictionary).get("capacity", 0))
	if capacity <= 0:
		ui.toast("这个坐骑没有载货槽", "bad")
		return false
	var index := slot_index if slot_index >= 0 else selected_index
	var slot := inventory.get_slot(index)
	if slot.is_empty():
		ui.toast("手上没有可以存放的物品", "bad")
		return false
	var category := str(slot.get("category", ""))
	if category in ["tool", "quest"]:
		ui.toast("工具和任务物品不能放进货袋", "bad")
		return false
	var count := int(slot.get("count", 1))
	if _cargo_used(data) + count > capacity:
		ui.toast("货袋空间不够（%d/%d）" % [_cargo_used(data), capacity], "bad")
		return false
	var items: Array = (cargo as Dictionary).get("items", [])
	var merged := false
	for stack: Dictionary in items:
		if str(stack.get("item_id", "")) == str(slot.get("item_id", "")) \
				and str(stack.get("category", "")) == category \
				and str(stack.get("quality", "")) == str(slot.get("quality", "")):
			stack["count"] = int(stack.get("count", 0)) + count
			merged = true
			break
	if not merged:
		items.append(slot.duplicate(true))
	(cargo as Dictionary)["items"] = items
	data["cargo"] = cargo
	inventory.remove_slot(index)
	_refresh_mount_cargo_nodes()
	ui.refresh_inventory()
	ui.refresh_hud()
	save_game()
	ui.toast("放进了%s的货袋" % str(data.get("name", "坐骑")), "good")
	return true


## 取回货袋里的全部物品；背包放不下的部分留在货袋里。
func take_all_cargo(mount_id: String) -> bool:
	var data := _mount_data(mount_id)
	if data.is_empty():
		return false
	var cargo: Variant = data.get("cargo", {})
	if not (cargo is Dictionary):
		return false
	var items: Array = (cargo as Dictionary).get("items", [])
	if items.is_empty():
		ui.toast("货袋是空的")
		return false
	var remaining: Array = []
	for stack: Dictionary in items:
		var item := {
			"item_id": str(stack.get("item_id", "")),
			"category": str(stack.get("category", "")),
			"count": int(stack.get("count", 1)),
			"price": int(stack.get("price", 0)),
		}
		if stack.has("quality"):
			item["quality"] = stack["quality"]
		if not inventory.can_add(item):
			remaining.append(stack.duplicate(true))
			continue
		inventory.add_item(item)
	(cargo as Dictionary)["items"] = remaining
	data["cargo"] = cargo
	_refresh_mount_cargo_nodes()
	ui.refresh_inventory()
	ui.refresh_hud()
	save_game()
	if remaining.is_empty():
		ui.toast("取出了货袋里的全部物品", "good")
	else:
		ui.toast("背包空间不够，还有物品留在货袋里", "bad")
	return true


func _refresh_mount_cargo_nodes() -> void:
	for mount_id: Variant in mount_nodes.keys():
		var node: RideMount = mount_nodes[mount_id]
		if node == null or not is_instance_valid(node):
			continue
		var data := _mount_data(str(mount_id))
		var cargo: Dictionary = data.get("cargo", {})
		node.cargo_capacity = int(cargo.get("capacity", 0))
		node.cargo_used = _cargo_used(data)


## K 键：骑乘中打开当前坐骑的货袋。
func open_ride_cargo() -> void:
	if not player.riding:
		ui.toast("骑乘中才能打开货袋", "bad")
		return
	if riding_animal != null:
		ui.toast("牛没有载货槽", "bad")
		return
	var data := _mount_data(riding_mount_id)
	var cargo: Dictionary = data.get("cargo", {})
	if int(cargo.get("capacity", 0)) <= 0:
		ui.toast("这个坐骑没有载货槽", "bad")
		return
	ui.open_mount_cargo(riding_mount_id)


## 建筑状态变化后刷新马厩 / 鸵鸟舍 / 自行车棚的外观与碰撞。
func _refresh_mount_buildings() -> void:
	if _stable_prop == null:
		return
	var stable_ready := get_building_level("stable") >= 1
	var ostrich_ready := get_building_level("ostrich_house") >= 1
	var shed_ready := get_building_level("bike_shed") >= 1
	_stable_prop.visible = stable_ready
	_ostrich_house_prop.visible = ostrich_ready
	_bike_shed_prop.visible = shed_ready
	_stable_scaffold_prop.visible = get_building_level("stable") == 0 \
		and _building_days_left("stable") > 0
	_ostrich_house_scaffold_prop.visible = get_building_level("ostrich_house") == 0 \
		and _building_days_left("ostrich_house") > 0
	_bike_shed_scaffold_prop.visible = get_building_level("bike_shed") == 0 \
		and _building_days_left("bike_shed") > 0
	_rebuild_mount_walls(stable_ready, ostrich_ready, shed_ready)


func _rebuild_mount_walls(stable_ready: bool, ostrich_ready: bool, shed_ready: bool) -> void:
	if _mount_walls != null:
		remove_child(_mount_walls)
		_mount_walls.queue_free()
		_mount_walls = null
	if not stable_ready and not ostrich_ready and not shed_ready:
		return
	_mount_walls = StaticBody2D.new()
	_mount_walls.name = "MountWalls"
	add_child(_mount_walls)
	if stable_ready:
		_add_dynamic_wall(_mount_walls,
			Rect2(STABLE_BASE.x - 60.0, STABLE_BASE.y - 44.0, 120.0, 44.0))
	if ostrich_ready:
		_add_dynamic_wall(_mount_walls,
			Rect2(OSTRICH_HOUSE_BASE.x - 60.0, OSTRICH_HOUSE_BASE.y - 44.0, 120.0, 44.0))
	if shed_ready:
		_add_dynamic_wall(_mount_walls,
			Rect2(BIKE_SHED_BASE.x - 42.0, BIKE_SHED_BASE.y - 28.0, 84.0, 28.0))


func _add_dynamic_wall(body: StaticBody2D, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.position + rect.size * 0.5
	body.add_child(shape)


## 每天结算：好感、产物、繁殖。
func _advance_animals() -> void:
	for animal: FarmAnimal in animals:
		var was_fed := bool(building_fed.get(animal.building, false))
		animal.advance_day(was_fed)
	for building: String in building_fed.keys():
		building_fed[building] = false
	_try_breed()


func _try_breed() -> void:
	var rules := DB.get_animal_rules()
	var chance := float(rules.get("breeding_chance", 0.0))
	var min_friendship := float(rules.get("breeding_friendship_min", 50))
	if chance <= 0.0:
		return

	for building: String in ["coop", "barn"]:
		var group := _animals_in(building)
		if group.size() >= get_building_capacity(building) or group.size() < 2:
			continue

		# 同种类、且都达到好感阈值的两只才能繁殖。
		var by_type: Dictionary = {}
		for animal: FarmAnimal in group:
			if animal.friendship < min_friendship:
				continue
			if not by_type.has(animal.type_id):
				by_type[animal.type_id] = []
			(by_type[animal.type_id] as Array).append(animal)

		for type_id: String in by_type.keys():
			var candidates: Array = by_type[type_id]
			if candidates.size() < 2:
				continue
			if _animals_in(building).size() >= get_building_capacity(building):
				break

			# 每次判定新建 RNG，不与其他系统共用。
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			if rng.randf() >= chance:
				continue

			var parent_a: FarmAnimal = candidates[0]
			var parent_b: FarmAnimal = candidates[1]
			var baby: FarmAnimal = AnimalScript.new()
			add_child(baby)
			baby.setup(
				type_id,
				parent_a.position + Vector2(randf_range(-18.0, 18.0), randf_range(0.0, 14.0)),
				building
			)
			baby.friendship = float(rules.get("baby_friendship", 20))
			baby.age_days = 0
			baby.roll_birth_traits(parent_a.is_rare, parent_b.is_rare)
			animals.append(baby)

			if baby.is_rare:
				ui.toast(
					"✨ %s 生下了%s%s！" % [
						parent_a.get_display_name(),
						str(baby.rare_color_name),
						str(baby.get_definition().get("name", type_id)),
					],
					"good"
				)
			else:
				ui.toast(
					"%s 生下了小%s" % [
						parent_a.get_display_name(),
						str(baby.get_definition().get("name", type_id)),
					],
					"good"
				)
			break


# ============================================================
# 角色外观
# ============================================================

func _apply_appearance(look: Dictionary) -> void:
	var normalized := Art.normalize_look(look)
	player.set_look(normalized)
	if ui != null:
		ui.set_portrait_look(normalized)


func _update_farm_sign() -> void:
	if _farm_sign != null and is_instance_valid(_farm_sign):
		_farm_sign.set_farm_name(farm_name)
	if ui != null and ui.farm_sign_label != null:
		ui.farm_sign_label.text = farm_name


## 名牌文字用屏幕空间 Label 绘制，避免相机缩放压碎像素字。
func _update_farm_sign_label() -> void:
	if ui == null or ui.farm_sign_label == null:
		return
	var show := not indoor and not in_mine and _farm_sign != null \
		and _farm_sign.visible
	if show:
		var screen: Vector2 = get_viewport().get_canvas_transform() \
			* (_farm_sign.position + Vector2(0, -74))
		show = screen.x > -120.0 and screen.x < 600.0 \
			and screen.y > -20.0 and screen.y < 290.0
		if show:
			ui.farm_sign_label.position = Vector2(screen.x - 80.0, screen.y - 7.0)
	ui.farm_sign_label.visible = show


func _open_creator(edit_mode: bool) -> void:
	if _transitioning:
		return
	var previous_look: Dictionary = player.look.duplicate(true)
	_transitioning = true
	player.input_locked = true

	var creator := CharacterCreatorScript.new()
	add_child(creator)
	ui.set_compass_visible(false)
	creator.setup(previous_look, edit_mode)
	creator.confirmed.connect(func(look: Dictionary) -> void:
		_apply_appearance(look)
		if not edit_mode:
			player_name = creator.player_name_value
			farm_name = creator.farm_name_value
			_update_farm_sign()
			ui.toast("牧场「%s」已创建" % farm_name, "good")
		else:
			ui.toast("外观已保存", "good")
		save_game()
	)
	creator.cancelled.connect(func() -> void:
		_apply_appearance(previous_look)
	)
	# 无论确定、取消还是被其它原因移除，都要解除输入锁，避免卡住。
	creator.tree_exiting.connect(func() -> void:
		_transitioning = false
		player.input_locked = false
		ui.set_compass_visible(true)
	)


# ============================================================
# 进入 / 离开室内
# ============================================================

func enter_house() -> void:
	if indoor or _transitioning:
		return
	if player.riding:
		ui.toast("请先下坐骑再进屋", "bad")
		return
	_transitioning = true
	player.input_locked = true
	ui.fade_out(0.3)
	await get_tree().create_timer(0.32).timeout

	_outdoor_position = player.position
	indoor = true
	time.enter_location("house")

	# 隐藏室外世界，只留室内
	_set_outdoor_visible(false)
	_interior.visible = true
	_add_indoor_walls()
	_refresh_house_props()
	_place_indoor_pets()

	player.position = _interior.origin + Vector2(6.0 * TILE, 6.8 * TILE)
	player.facing = "up"
	player.z_index = 0

	# 相机切到室内
	_saved_camera_limits = Rect2i(camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom)
	var bounds := _interior.get_bounds()
	camera.zoom = Vector2(1.0, 1.0)
	camera.limit_left = int(bounds.position.x) - 8
	camera.limit_top = int(bounds.position.y) - 8
	camera.limit_right = int(bounds.end.x) + 8
	camera.limit_bottom = int(bounds.end.y) + 8
	camera.position = bounds.get_center()
	camera.reset_smoothing()

	ui.refresh_hud()
	ui.fade_in(0.3)
	ui.show_banner("自宅", 1.2)
	time.set_context("cutscene", false)
	player.input_locked = false
	_transitioning = false


func exit_house() -> void:
	if not indoor or _transitioning:
		return
	_transitioning = true
	player.input_locked = true
	ui.fade_out(0.3)
	await get_tree().create_timer(0.32).timeout

	indoor = false
	time.leave_location()
	_interior.visible = false
	_clear_house_props()
	_restore_indoor_pets()
	_set_outdoor_visible(true)
	_remove_indoor_walls()

	player.position = _outdoor_position
	player.facing = "down"
	player.z_index = 0

	_apply_camera_zoom()
	camera.limit_left = _saved_camera_limits.position.x
	camera.limit_top = _saved_camera_limits.position.y
	camera.limit_right = _saved_camera_limits.end.x
	camera.limit_bottom = _saved_camera_limits.end.y
	camera.position = player.position
	camera.reset_smoothing()

	_update_day_light()
	ui.refresh_hud()
	ui.fade_in(0.3)
	player.input_locked = false
	_transitioning = false


func _set_outdoor_visible(value: bool) -> void:
	if _ground != null:
		_ground.visible = value
	for prop in props:
		prop.visible = value
	for npc: VillageNPC in npcs:
		npc.visible = value
	if value:
		_update_npc_schedule()
	if _farm_sign != null and is_instance_valid(_farm_sign):
		_farm_sign.visible = value
	for tile: FarmTile in farm_tiles.values():
		tile.visible = value
	for animal: FarmAnimal in animals:
		animal.visible = value
	for pet: FarmPet in pets:
		pet.visible = value and not pet.missing
	for critter: WildCritter in wild_critters:
		if is_instance_valid(critter):
			critter.visible = value
	for house_id: Variant in _pet_house_nodes.keys():
		var house: PetHouse = _pet_house_nodes[house_id]
		if house != null and is_instance_valid(house):
			house.visible = value
	visible = true
	if value:
		_refresh_pet_houses()
	queue_redraw()


var _indoor_walls: StaticBody2D


func _add_indoor_walls(rects: Array = []) -> void:
	if _indoor_walls != null:
		return
	_indoor_walls = StaticBody2D.new()
	_indoor_walls.name = "IndoorWalls"
	add_child(_indoor_walls)
	var wall_rects: Array = rects
	if wall_rects.is_empty() and _interior != null:
		wall_rects = _interior.get_wall_rects()
	for rect: Rect2 in wall_rects:
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		shape.position = rect.position + rect.size * 0.5
		_indoor_walls.add_child(shape)


func _remove_indoor_walls() -> void:
	if _indoor_walls == null:
		return
	remove_child(_indoor_walls)
	_indoor_walls.queue_free()
	_indoor_walls = null


# ============================================================
# 委托 / 建造 / 结婚
# ============================================================

func _setup_buildings() -> void:
	if buildings_state.is_empty():
		buildings_state = {
			"coop": {"level": 1, "days_left": 0},
			"barn": {"level": 1, "days_left": 0},
			"greenhouse": {"level": 0, "days_left": 0},
			"stable": {"level": 0, "days_left": 0},
			"ostrich_house": {"level": 0, "days_left": 0},
			"bike_shed": {"level": 0, "days_left": 0},
		}


func _reset_quests_buildings() -> void:
	quests_active.clear()
	quests_completed.clear()
	quest_last_day = -1
	_quest_serial = 0
	buildings_state.clear()
	_setup_buildings()
	_refresh_mount_buildings()
	spouse_id = ""
	if _interior != null:
		_interior.clear_spouse()
	_update_npc_schedule()
	_refresh_daily_quests(true)


func _apply_quests_buildings(quest_data: Variant, building_data: Variant) -> void:
	if quest_data is Dictionary:
		var active: Variant = quest_data.get("active", [])
		quests_active = active.duplicate(true) if active is Array else []
		var completed: Variant = quest_data.get("completed", [])
		quests_completed = completed.duplicate() if completed is Array else []
		quest_last_day = int(quest_data.get("daily_refreshed_day", -1))
	if building_data is Dictionary and not building_data.is_empty():
		buildings_state = building_data.duplicate(true)
	_setup_buildings()
	_refresh_daily_quests()
	_refresh_mount_buildings()


func _refresh_daily_quests(force := false) -> void:
	if time == null:
		return
	var today := time.get_absolute_day()
	for quest: Dictionary in quests_active.duplicate():
		if int(quest.get("expire_day", 0)) < today:
			quests_active.erase(quest)
	if not force and quest_last_day == today:
		return
	quest_last_day = today
	quests_active.clear()
	var config := DB.get_quest_config()
	var count := int(config.get("daily_count", 3))
	var types: Array = config.get("types", [])
	if types.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	_quest_serial += 1
	rng.seed = today * 7919 + _quest_serial * 104729
	for index in count:
		var type: Dictionary = types[rng.randi_range(0, types.size() - 1)]
		var type_id := str(type.get("id", "crop"))
		var pool := _quest_pool(type_id)
		if pool.is_empty():
			continue
		var item: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
		var amount := rng.randi_range(int(type.get("min", 1)), int(type.get("max", 5)))
		var difficulty := _roll_quest_difficulty(config, rng)
		var price := int(item.get("base_price", 10))
		var reward := maxi(
			50,
			roundi(float(price) * amount * float(difficulty.get("multiplier", 1.0)) / 10.0) * 10
		)
		var giver_id := ""
		var giver_name := "村民"
		if not npcs.is_empty():
			var giver: VillageNPC = npcs[rng.randi_range(0, npcs.size() - 1)]
			giver_id = giver.npc_id
			giver_name = giver.display_name
		quests_active.append({
			"id": "q_%d_%d" % [today, index],
			"type": type_id,
			"item_id": str(item.get("id", "")),
			"item_name": str(item.get("name", "")),
			"category": type_id,
			"count": amount,
			"reward_coins": reward,
			"reward_friendship": int(type.get("friendship", 2)),
			"difficulty": str(difficulty.get("id", "easy")),
			"giver": giver_name,
			"giver_id": giver_id,
			"expire_day": today + int(config.get("expire_days", 3)),
		})
	if ui != null and ui.has_method("refresh_notice_board"):
		ui.refresh_notice_board()


func _quest_pool(type_id: String) -> Array:
	var result: Array = []
	if type_id == "crop":
		for definition: Dictionary in DB.get_all_crops():
			result.append({
				"id": str(definition.get("id", "")),
				"name": str(definition.get("name", "")),
				"base_price": int(definition.get("base_price", 10)),
			})
	elif type_id == "fish":
		for definition: Dictionary in DB.get_all_fishes():
			result.append({
				"id": str(definition.get("id", "")),
				"name": str(definition.get("name", "")),
				"base_price": int(definition.get("base_price", 10)),
			})
	elif type_id == "mineral":
		result = [
			{"id": "stone", "name": "石头", "base_price": 2},
			{"id": "copper", "name": "铜矿石", "base_price": 15},
			{"id": "iron", "name": "铁矿石", "base_price": 40},
			{"id": "gold", "name": "金矿石", "base_price": 80},
			{"id": "amethyst", "name": "紫水晶", "base_price": 80},
			{"id": "emerald", "name": "翡翠", "base_price": 200},
		]
	return result


func _roll_quest_difficulty(config: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var difficulties: Array = config.get("difficulties", [])
	if difficulties.is_empty():
		return {"id": "easy", "multiplier": 1.0}
	var roll := rng.randf()
	for difficulty: Dictionary in difficulties:
		roll -= float(difficulty.get("chance", 0.0))
		if roll <= 0.0:
			return difficulty
	return difficulties[difficulties.size() - 1]


func complete_quest(index: int) -> void:
	if index < 0 or index >= quests_active.size():
		return
	var quest: Dictionary = quests_active[index]
	var item_id := str(quest.get("item_id", ""))
	var category := str(quest.get("category", ""))
	if inventory.count_item(item_id, category) < int(quest.get("count", 1)):
		ui.toast("物品数量不足", "bad")
		return
	inventory.remove_item(item_id, int(quest.get("count", 1)), category)
	money += int(quest.get("reward_coins", 0))
	total_earned += int(quest.get("reward_coins", 0))
	var giver := _find_npc(str(quest.get("giver_id", "")))
	if giver != null:
		giver.add_friendship(int(quest.get("reward_friendship", 2)))
	quests_completed.append(str(quest.get("id", "")))
	_achievements_check()
	quests_active.remove_at(index)
	ui.refresh_hud()
	ui.refresh_inventory()
	ui.refresh_notice_board()
	save_game(true)
	ui.toast("委托完成，获得 %d G" % int(quest.get("reward_coins", 0)), "good")


func abandon_quest(index: int) -> void:
	if index < 0 or index >= quests_active.size():
		return
	quests_active.remove_at(index)
	ui.refresh_notice_board()
	save_game(true)


func manual_refresh_quests() -> void:
	var cost := int(DB.get_quest_config().get("manual_refresh_cost", 100))
	if money < cost:
		ui.toast("金币不足", "bad")
		return
	money -= cost
	_refresh_daily_quests(true)
	ui.refresh_hud()
	ui.refresh_notice_board()
	save_game(true)
	ui.toast("已刷新委托", "good")


func get_building_level(building_id: String) -> int:
	var state: Dictionary = buildings_state.get(building_id, {})
	return int(state.get("level", 0))


func _building_days_left(building_id: String) -> int:
	var state: Dictionary = buildings_state.get(building_id, {})
	return int(state.get("days_left", 0))


func get_building_capacity(building_type: String) -> int:
	var level := get_building_level(building_type)
	var definition := DB.get_building_def(building_type)
	for level_def: Dictionary in definition.get("levels", []):
		if int(level_def.get("level", 0)) == level and level_def.has("capacity"):
			return int(level_def.get("capacity", 4))
	if level >= 1:
		return int(DB.get_animal_rules().get("max_per_building", 4))
	return 0


func can_start_building(building_id: String) -> Dictionary:
	var definition := DB.get_building_def(building_id)
	if definition.is_empty():
		return {"ok": false, "reason": "未知建筑"}
	var current := get_building_level(building_id)
	if current >= int(definition.get("max_level", 1)):
		return {"ok": false, "reason": "已经是最高级"}
	if _building_days_left(building_id) > 0:
		return {"ok": false, "reason": "正在建造中"}
	var next := DB.get_building_next_level(building_id, current)
	if next.is_empty():
		return {"ok": false, "reason": "没有下一等级"}
	var materials: Dictionary = next.get("materials", {})
	for item_id: Variant in materials.keys():
		if inventory.count_item(str(item_id)) < int(materials[item_id]):
			return {
				"ok": false,
				"reason": "材料不足：%s" % DB.get_item_name(str(item_id)),
			}
	if money < int(next.get("coins", 0)):
		return {"ok": false, "reason": "金币不足"}
	return {"ok": true, "next": next}


func start_building(building_id: String) -> void:
	var check := can_start_building(building_id)
	if not bool(check.get("ok", false)):
		ui.toast(str(check.get("reason", "无法建造")), "bad")
		return
	var next: Dictionary = check.get("next", {})
	var materials: Dictionary = next.get("materials", {})
	for item_id: Variant in materials.keys():
		inventory.remove_item(str(item_id), int(materials[item_id]))
	money -= int(next.get("coins", 0))
	buildings_state[building_id] = {
		"level": get_building_level(building_id),
		"days_left": int(next.get("days", 1)),
	}
	_refresh_mount_buildings()
	ui.refresh_hud()
	ui.refresh_inventory()
	ui.refresh_notice_board()
	save_game(true)
	ui.toast("开始建造，%d 天后完成" % int(next.get("days", 1)), "good")


func _advance_buildings() -> void:
	for building_id: Variant in buildings_state.keys():
		var state: Dictionary = buildings_state[building_id]
		var days := int(state.get("days_left", 0))
		if days <= 0:
			continue
		days -= 1
		if days <= 0:
			state["level"] = int(state.get("level", 0)) + 1
			state["days_left"] = 0
			var definition := DB.get_building_def(str(building_id))
			ui.toast("%s建造/升级完成" % str(definition.get("name", building_id)), "good")
		else:
			state["days_left"] = days
	_refresh_mount_buildings()


func _find_npc(npc_id: String) -> VillageNPC:
	if npc_id.is_empty():
		return null
	for npc: VillageNPC in npcs:
		if npc.npc_id == npc_id:
			return npc
	return null


func can_propose(npc: VillageNPC) -> bool:
	return npc != null \
		and bool(npc.data.get("marriageable", false)) \
		and npc.friendship >= 200 \
		and home_level >= 2 \
		and spouse_id.is_empty() \
		and inventory.count_item("blue_feather") >= 1


func propose_to_npc(npc: VillageNPC) -> void:
	if not can_propose(npc):
		ui.toast("还不能求婚：需要好感 200、中级自宅与蓝色羽毛", "bad")
		return
	inventory.remove_item("blue_feather", 1)
	spouse_id = npc.npc_id
	npc.add_friendship(20)
	if _interior != null:
		_interior.set_spouse(npc.display_name, npc.look)
	ui.refresh_hotbar()
	ui.refresh_inventory()
	ui.show_dialogue(npc.display_name, "……我愿意。以后请多指教。", 3.6, npc.look)
	ui.show_banner("与 %s 结为伴侣" % npc.display_name, 2.5)
	save_game(true)
	_update_npc_schedule()


func _on_spouse_talked() -> void:
	var spouse := _find_npc(spouse_id)
	if spouse == null:
		return
	spouse.add_friendship(1)
	ui.show_dialogue(spouse.display_name, "今天也要一起加油。", 3.0, spouse.look)
	save_game(true)


func _use_hot_spring() -> void:
	if hot_spring_used_today:
		ui.toast("今天已经泡过温泉了", "bad")
		return
	hot_spring_used_today = true
	player.stamina = player.stamina_max
	player.stamina_changed.emit(player.stamina, player.stamina_max)
	player.restore_health(1.0)
	# 泡澡特效：水汽、气泡、爱心与闪光
	var effect := BathEffectScript.new()
	add_child(effect)
	effect.setup(HOT_SPRING_POINT + Vector2(0, -8))
	AudioManager.play_sfx("water")
	ui.refresh_hud()
	ui.toast("泡了温泉，体力与生命完全恢复", "good")
	save_game()


# ============================================================
# 图书馆 / 诊所
# ============================================================

func get_library_books() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var today := time.get_absolute_day() if time != null else 0
	for book: Dictionary in DB.get_all_books():
		var book_id := str(book.get("id", ""))
		result.append({
			"book": book,
			"read": book_id in books_read,
			"can_read": not (book_id in books_read) and last_book_day != today,
		})
	return result


## 每天只能读一本；读完立刻发放奖励并记录。
func read_book(book_id: String) -> bool:
	if time == null:
		return false
	var book := DB.get_book(book_id)
	if book.is_empty():
		return false
	if book_id in books_read:
		ui.toast("这本书已经读过了", "bad")
		return false
	var today := time.get_absolute_day()
	if last_book_day == today:
		ui.toast("今天已经读过书了，明天再来", "bad")
		return false
	books_read.append(book_id)
	last_book_day = today
	money += int(book.get("money", 0))
	var gifts: Variant = book.get("items", [])
	if gifts is Array:
		for raw: Variant in gifts:
			if not (raw is Dictionary):
				continue
			var item: Dictionary = (raw as Dictionary).duplicate(true)
			item["count"] = int(item.get("count", 1))
			if inventory.can_add(item):
				inventory.add_item(item)
			else:
				_spawn_ground_item(item, LIBRARY_POINT)
	player.restore_stamina(0.1)
	ui.refresh_hud()
	ui.toast("读完《%s》，收获一些研究心得" % str(book.get("name", "")), "good")
	save_game()
	return true


func clinic_prices() -> Dictionary:
	return DB.get_services_config().get("hospital", {})


## 玩家治疗：付费恢复体力与生命。
func treat_player_at_clinic() -> bool:
	var price := int(clinic_prices().get("treatment_price", 200))
	if money < price:
		ui.toast("治疗需要 %d G" % price, "bad")
		return false
	money -= price
	player.stamina = player.stamina_max
	player.stamina_changed.emit(player.stamina, player.stamina_max)
	player.restore_health(1.0)
	ui.refresh_hud()
	ui.toast("治疗完成，体力与生命完全恢复", "good")
	save_game()
	return true


## 雇佣 / 解雇浇水工。工钱在每天开始时结算。
func _toggle_worker() -> void:
	if hired_worker:
		hired_worker = false
		ui.toast("已解雇浇水工", "good")
		save_game()
		return
	var worker := DB.get_worker("waterer")
	var wage := int(worker.get("wage_per_day", 100))
	if money < wage:
		ui.toast("雇佣需要预付一天工钱 %d G" % wage, "bad")
		return
	hired_worker = true
	ui.toast("已雇佣%s，每天 %d G，明天开始自动浇水" % [
		str(worker.get("name", "浇水工")), wage,
	], "good")
	save_game()


## 每天开始：浇水工自动给所有作物浇水，并扣当日工钱。
func _run_worker() -> void:
	if not hired_worker:
		return
	var worker := DB.get_worker("waterer")
	var wage := int(worker.get("wage_per_day", 100))
	if money < wage:
		hired_worker = false
		ui.toast("付不起工钱，浇水工离开了", "bad")
		return
	money -= wage
	var watered := 0
	for tile: FarmTile in farm_tiles.values():
		if tile.tilled and not tile.watered:
			tile.water()
			watered += 1
	ui.toast("浇水工浇了 %d 块地（-%d G）" % [watered, wage], "good")


# ============================================================
# 家具
# ============================================================

func buy_furniture(furniture_id: String) -> void:
	var definition := DB.get_furniture(furniture_id)
	if definition.is_empty():
		return
	var price := int(definition.get("price", 0))
	if money < price:
		ui.toast("钱不够", "bad")
		return
	var item := {
		"item_id": furniture_id, "category": "furniture",
		"count": 1, "price": price,
	}
	if not inventory.can_add(item):
		ui.toast("背包空间不够", "bad")
		return
	money -= price
	inventory.add_item(item)
	AudioManager.play_sfx("coin")
	ui.refresh_hud()
	ui.refresh_shop()
	ui.toast("买下了%s" % str(definition.get("name", furniture_id)), "good")


## 在室内把选中的家具摆到玩家所在格附近；放不下时给予提示。
func place_furniture_from_inventory(index: int) -> bool:
	if not indoor or _interior == null:
		ui.toast("只能在自宅室内摆放家具", "bad")
		return false
	var slot := inventory.get_slot(index)
	var furniture_id := str(slot.get("item_id", ""))
	if slot.is_empty() or str(slot.get("category", "")) != "furniture":
		return false
	var origin := _interior.origin
	var gx := int((player.position.x - origin.x) / TILE)
	var gy := int((player.position.y - origin.y) / TILE)
	gx = clampi(gx, 1, HouseInteriorScript.ROOM_W - 2)
	gy = clampi(gy, 2, HouseInteriorScript.ROOM_H - 2)
	if _interior.is_furniture_blocked(gx, gy):
		ui.toast("这里放不下家具", "bad")
		return false
	placed_furniture.append({"id": furniture_id, "gx": gx, "gy": gy})
	inventory.remove_slot(index)
	_interior.set_furniture(placed_furniture)
	_refresh_house_props()
	ui.toast("摆放了%s" % DB.get_furniture(furniture_id).get("name", furniture_id), "good")
	save_game()
	return true


## 收回玩家脚边的家具。
func pick_up_nearby_furniture() -> bool:
	if not indoor or _interior == null or placed_furniture.is_empty():
		return false
	var origin := _interior.origin
	var gx := int((player.position.x - origin.x) / TILE)
	var gy := int((player.position.y - origin.y) / TILE)
	for index in range(placed_furniture.size() - 1, -1, -1):
		var entry: Dictionary = placed_furniture[index]
		if absi(int(entry.get("gx", 0)) - gx) > 1 or absi(int(entry.get("gy", 0)) - gy) > 1:
			continue
		var furniture_id := str(entry.get("id", ""))
		var item := {
			"item_id": furniture_id, "category": "furniture", "count": 1,
			"price": int(DB.get_furniture(furniture_id).get("price", 0)),
		}
		if not inventory.can_add(item):
			ui.toast("背包已满，收不下了", "bad")
			return false
		inventory.add_item(item)
		placed_furniture.remove_at(index)
		_interior.set_furniture(placed_furniture)
		_refresh_house_props()
		ui.toast("收起了%s" % DB.get_item_name(furniture_id, "furniture"), "good")
		save_game()
		return true
	return false


## 靠近已摆放的椅子时坐下（2 帧坐姿）。
func _try_sit_on_nearby_chair() -> bool:
	if _interior == null or placed_furniture.is_empty():
		return false
	var origin := _interior.origin
	for entry: Dictionary in placed_furniture:
		var definition := DB.get_furniture(str(entry.get("id", "")))
		if str(definition.get("icon", "")) != "chair":
			continue
		var chair_world := origin + Vector2(
			int(entry.get("gx", 0)) * TILE + TILE * 0.5,
			int(entry.get("gy", 0)) * TILE + TILE * 0.5)
		if player.position.distance_to(chair_world) <= 34.0:
			player.position = chair_world + Vector2(0, 2)
			player.set_sitting(true)
			ui.toast("在椅子上坐下休息（按 E 起身）")
			return true
	return false


## 挤奶 / 剪毛：动物播放产出动作，产物从动物身上弹出。
func _play_animal_product_effect(animal: FarmAnimal, item_id: String) -> void:
	animal.play_produce_pose()
	var fx := PickupBurstScript.new()
	add_child(fx)
	fx.setup(item_id, "animal_product",
		animal.position + Vector2(0, -16), player.position + Vector2(0, -20))


func sick_animal_count() -> int:
	var count := 0
	for animal: FarmAnimal in animals:
		if animal.sick:
			count += 1
	return count


## 治疗全部生病动物，按只计费。
func treat_sick_animals() -> int:
	var sick_list: Array[FarmAnimal] = []
	for animal: FarmAnimal in animals:
		if animal.sick:
			sick_list.append(animal)
	if sick_list.is_empty():
		ui.toast("没有需要治疗的动物", "bad")
		return 0
	var price_each := int(clinic_prices().get("animal_treatment_price", 100))
	var total := price_each * sick_list.size()
	if money < total:
		ui.toast("需要 %d G（%d 只）" % [total, sick_list.size()], "bad")
		return 0
	money -= total
	for animal: FarmAnimal in sick_list:
		animal.set_sick(false)
	ui.refresh_hud()
	ui.toast("治好了 %d 只动物，花费 %d G" % [sick_list.size(), total], "good")
	save_game()
	return sick_list.size()


func _open_home_storage(kind: String) -> void:
	ui.open_storage(kind)


# ============================================================
# 储物箱 / 冰箱
# ============================================================

func storage_slots(kind: String) -> Array:
	return fridge_storage if kind == "fridge" else home_storage


func storage_capacity(kind: String) -> int:
	if kind == "fridge":
		return 60 if home_level >= 3 else 30
	return 30


## 把一件物品并入储物格：同 id / 分类 / 品质优先合并，最多 99。
func _add_to_storage(kind: String, item: Dictionary) -> bool:
	var stacks := storage_slots(kind)
	# 先在副本上模拟，确认能完整放入后再提交，避免部分转移导致复制物品。
	var working: Array = stacks.duplicate(true)
	var item_id := str(item.get("item_id", ""))
	var category := str(item.get("category", ""))
	var quality := str(item.get("quality", "normal"))
	var remaining := int(item.get("count", 1))
	for stack: Dictionary in working:
		if remaining <= 0:
			break
		if str(stack.get("item_id", "")) != item_id \
				or str(stack.get("category", "")) != category \
				or str(stack.get("quality", "normal")) != quality:
			continue
		var space := 99 - int(stack.get("count", 0))
		if space <= 0:
			continue
		var moved: int = mini(space, remaining)
		stack["count"] = int(stack.get("count", 0)) + moved
		remaining -= moved
	while remaining > 0:
		if working.size() >= storage_capacity(kind):
			return false
		var moved: int = mini(99, remaining)
		var stack: Dictionary = item.duplicate(true)
		stack["count"] = moved
		working.append(stack)
		remaining -= moved
	stacks.clear()
	for stack: Dictionary in working:
		stacks.append(stack)
	return true


func transfer_inventory_to_storage(kind: String, index: int) -> bool:
	var slot := inventory.get_slot(index)
	if slot.is_empty():
		return false
	var item: Dictionary = slot.duplicate(true)
	if not _add_to_storage(kind, item):
		ui.toast("储物空间满了", "bad")
		return false
	inventory.remove_slot(index)
	ui.refresh_storage()
	return true


# ============================================================
# 邮箱
# ============================================================

## 按日期把新信件放入邮箱（每封只发一次）。
func _refresh_mail() -> void:
	if time == null:
		return
	# get_absolute_day() 从 0 开始；信件配置使用「第 N 天」，因此 +1。
	var today := time.get_absolute_day() + 1
	for letter: Dictionary in DB.get_all_mail():
		var letter_id := str(letter.get("id", ""))
		if letter_id.is_empty() or letter_id in mail_pending or letter_id in mail_read:
			continue
		if int(letter.get("day", 1)) <= today:
			mail_pending.append(letter_id)
	_update_mailbox_flag()


func _update_mailbox_flag() -> void:
	if _mailbox_prop != null:
		_mailbox_prop.set_mail(not mail_pending.is_empty())


func get_mail_letters() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for letter_id: String in mail_pending:
		var letter := DB.get_mail(letter_id)
		if not letter.is_empty():
			result.append(letter)
	return result


## 阅读并领取一封信的奖励。
func read_mail(letter_id: String) -> Dictionary:
	var index := mail_pending.find(letter_id)
	if index < 0:
		return {}
	var letter := DB.get_mail(letter_id)
	if letter.is_empty():
		return {}
	mail_pending.remove_at(index)
	mail_read.append(letter_id)
	money += int(letter.get("money", 0))
	var gifts: Variant = letter.get("items", [])
	if gifts is Array:
		for raw: Variant in gifts:
			if not (raw is Dictionary):
				continue
			var item: Dictionary = (raw as Dictionary).duplicate(true)
			item["count"] = int(item.get("count", 1))
			if inventory.can_add(item):
				inventory.add_item(item)
			else:
				_spawn_ground_item(item, MAILBOX_POINT)
	_update_mailbox_flag()
	ui.refresh_hud()
	save_game()
	return letter


# ============================================================
# 地窖（加工品熟成）
# ============================================================

func _open_cellar() -> void:
	if home_level < 3:
		ui.toast("升级自宅后才能使用地窖", "bad")
		return
	ui.open_cellar()


func cellar_capacity() -> int:
	return int(DB.get_cellar_config().get("max_slots", 12))


## 地窖每过一天：熟成进度 +1，满 7 天提升一档品质。
func _advance_cellar() -> void:
	var config := DB.get_cellar_config()
	var step_days := maxi(1, int(config.get("days_per_step", 7)))
	var order: Array = config.get("quality_order", ["normal", "silver", "gold", "star"])
	for stack: Dictionary in cellar_items:
		stack["age_days"] = int(stack.get("age_days", 0)) + 1
		if int(stack["age_days"]) < step_days:
			continue
		stack["age_days"] = int(stack["age_days"]) - step_days
		var quality := str(stack.get("quality", "normal"))
		var index := order.find(quality)
		if index >= 0 and index < order.size() - 1:
			stack["quality"] = str(order[index + 1])


func cellar_put(index: int) -> bool:
	var slot := inventory.get_slot(index)
	if slot.is_empty():
		return false
	if str(slot.get("category", "")) != str(DB.get_cellar_config().get(
			"eligible_category", "processed")):
		ui.toast("只有加工品可以放进地窖熟成", "bad")
		return false
	var item: Dictionary = slot.duplicate(true)
	var quality := str(item.get("quality", "normal"))
	# 同物品、同品质优先合并
	for stack: Dictionary in cellar_items:
		if str(stack.get("item_id", "")) != str(item.get("item_id", "")) \
				or str(stack.get("quality", "normal")) != quality:
			continue
		var space := 99 - int(stack.get("count", 0))
		if space <= 0:
			continue
		var moved: int = mini(space, int(item.get("count", 1)))
		stack["count"] = int(stack.get("count", 0)) + moved
		inventory.remove_slot(index, moved)
		ui.refresh_cellar()
		return true
	if cellar_items.size() >= cellar_capacity():
		ui.toast("地窖已经放满了", "bad")
		return false
	item["age_days"] = 0
	cellar_items.append(item)
	inventory.remove_slot(index)
	ui.refresh_cellar()
	return true


func cellar_take(index: int) -> bool:
	if index < 0 or index >= cellar_items.size():
		return false
	var item: Dictionary = cellar_items[index]
	if not inventory.can_add(item):
		ui.toast("背包已满", "bad")
		return false
	inventory.add_item(item)
	cellar_items.remove_at(index)
	ui.refresh_cellar()
	return true


func transfer_storage_to_inventory(kind: String, index: int) -> bool:
	var stacks := storage_slots(kind)
	if index < 0 or index >= stacks.size():
		return false
	var item: Dictionary = stacks[index]
	if not inventory.can_add(item):
		ui.toast("背包已满", "bad")
		return false
	inventory.add_item(item)
	stacks.remove_at(index)
	ui.refresh_storage()
	return true


func _on_tv_requested() -> void:
	var weather := DB.weather_name(time.weather)
	ui.show_dialogue(
		"电视",
		"天气预报：今天%s。\n雨天作物会自动浇水，记得安排好农活。" % weather,
		3.2
	)


func _on_bathroom_requested() -> void:
	if bath_used_today:
		ui.toast("今天已经泡过澡了", "bad")
		return
	bath_used_today = true
	player.stamina = minf(player.stamina_max, player.stamina + player.stamina_max * 0.2)
	player.stamina_changed.emit(player.stamina, player.stamina_max)
	ui.refresh_hud()
	save_game()
	ui.toast("泡了个热水澡，恢复了 20% 体力", "good")


func _try_upgrade_home() -> void:
	if not indoor:
		return
	if home_level >= 3:
		ui.toast("自宅已经是最高级了", "bad")
		return
	var cost := 10000 if home_level == 1 else 100000
	var wood_needed := 450 if home_level == 1 else 1200
	if money < cost:
		ui.toast("升级自宅需要 %d G" % cost, "bad")
		return
	if inventory.count_item("branch", "forage") < wood_needed:
		ui.toast("升级自宅还需要木材 ×%d" % wood_needed, "bad")
		return
	money -= cost
	inventory.remove_item("branch", wood_needed, "forage")
	home_level += 1
	bath_used_today = false
	if _interior != null:
		_interior.set_level(home_level)
	ui.refresh_hud()
	ui.show_banner("自宅升级到 %d 级" % home_level, 2.2)
	save_game()


func _sleep() -> void:
	if _transitioning:
		return
	_transitioning = true
	player.input_locked = true
	time.set_context("cutscene", true)
	AudioManager.play_sfx("sleep")
	ui.fade_out(0.45)
	await get_tree().create_timer(0.5).timeout
	time.sleep()
	player.position = SPAWN
	player.facing = "down"
	ui.fade_in(0.45)
	await get_tree().create_timer(0.55).timeout
	time.set_context("cutscene", false)
	player.input_locked = false
	_transitioning = false


func _on_late_night() -> void:
	_collapse("late_night")


func _on_player_exhausted() -> void:
	_collapse("exhausted")


func _collapse(reason: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	player.input_locked = true
	time.set_context("cutscene", true)
	ui.toast("你累倒了，被送回了家。", "bad")
	ui.fade_out(0.7)
	await get_tree().create_timer(0.75).timeout
	time.collapse(reason)
	player.position = SPAWN
	player.facing = "down"
	ui.fade_in(0.5)
	await get_tree().create_timer(0.6).timeout
	time.set_context("cutscene", false)
	player.input_locked = false
	_transitioning = false


func _on_day_started(info: Dictionary) -> void:
	var season := str(info.get("season", "spring"))
	var weather := str(info.get("weather", "sunny"))
	_refresh_mail()
	_advance_cellar()
	days_played += 1
	hot_spring_used_today = false
	last_book_day = -1
	clinic_treated_today = false
	_run_worker()
	_achievements_check()

	if _ground != null:
		_ground.paint(_terrain, WORLD_W, WORLD_H, season)
		queue_redraw()

	_sync_prop_season(season)

	for tile: FarmTile in farm_tiles.values():
		tile.advance_day(season, weather)

	_advance_animals()
	_advance_pets()
	_advance_fruit_trees(season)
	_advance_beehives(season)

	if bool(info.get("season_changed", false)):
		_roll_beehive_diseases()

	if time != null:
		queue_redraw()

	if tutorial != null:
		tutorial.notify("sleep")
	player.restore_stamina(float(info.get("stamina_ratio", 1.0)))
	player.restore_health(1.0)
	time.set_context("inventory", false)
	time.set_context("menu", false)

	_reset_npc_day()
	_update_npc_schedule()
	_advance_buildings()
	_refresh_daily_quests()
	bath_used_today = false

	ui.refresh_hud()
	save_game()

	var message := "第 %d 年 · %s季 · %d 日\n天气：%s" % [
		int(info.get("year", 1)),
		DB.season_name(season),
		int(info.get("day", 1)),
		DB.weather_name(weather),
	]
	var speaker := "清晨"
	if bool(info.get("was_collapse", false)):
		speaker = "……"
		message += "\n昨夜晕倒了，今天起得晚，体力也没有完全恢复。"
	elif bool(info.get("raining", false)):
		message += "\n下雨了，作物会自动浇水。"
	elif int(info.get("wake_minutes", 360)) > 360:
		message += "\n你今天起得比平时晚。"
	var festival := get_today_festival()
	if not festival.is_empty():
		message += "\n今天是%s，广场上见！" % str(festival.get("name", "节日"))
	ui.show_dialogue(speaker, message, 3.0)


func _on_stamina_changed(_current: float, _maximum: float) -> void:
	if ui != null:
		ui.refresh_hud()


func _on_inventory_changed() -> void:
	if ui == null:
		return
	ui.refresh_hotbar()
	if ui.get_modal() == "inventory":
		ui.refresh_inventory()


# ============================================================
# 弹窗回调
# ============================================================

func on_modal_opened(modal: String) -> void:
	player.input_locked = true
	if modal == "minigame":
		time.set_context("fishing_minigame", true)
	else:
		time.set_context("menu", true)


func on_modal_closed() -> void:
	player.input_locked = false
	time.set_context("menu", false)
	time.set_context("fishing_minigame", false)
	time.set_context("inventory", false)


func on_shop_closed() -> void:
	ui.refresh_hud()
	save_game()


# ============================================================
# 使用地块
# ============================================================

func _use_tile(tile_position: Vector2i) -> void:
	if _transitioning or ui.is_modal_open():
		return
	if not _placing_pet_house_id.is_empty():
		return
	if player.riding:
		ui.toast("骑乘时不能使用工具，先按 E 下坐骑", "bad")
		return
	if in_mine:
		if str(get_selected_item().get("category", "")) == "weapon":
			_attack_in_mine(
				Vector2(tile_position) * TILE + Vector2(TILE * 0.5, TILE * 0.5)
			)
		else:
			ui.toast("选中剑后点击攻击", "bad")
		return
	if indoor:
		ui.toast("室内不能使用工具", "bad")
		return
	if not _tile_in_reach(tile_position):
		ui.toast("太远了，靠近一点", "bad")
		return
	var tile: Variant = farm_tiles.get(tile_position)
	if tile == null and _tree_at(tile_position) != null:
		var tree_here: Variant = _tree_at(tile_position)
		var held := get_selected_item()
		if str(held.get("kind", "")) == "tool" and str(held.get("item_id", "")) == "hoe":
			chop_fruit_tree(tree_here)
		else:
			ui.toast("%s · 用锄头可以砍倒" % (tree_here as FruitTree).get_tree_name())
		return
	if tile == null:
		# 空草地可以种树苗 / 放置加工机器
		var held := get_selected_item()
		if str(held.get("category", "")) == "machine":
			_place_machine_from_held(held, tile_position)
			return
		if str(held.get("kind", "")) == "sapling":
			_plant_sapling(held, tile_position)
			return
		ui.toast("这里不能耕种（只有围起来的农场地可以）")
		return

	# 成熟作物优先收获，不管手里拿的是什么。
	if tile.has_crop() and tile.is_crop_ripe():
		_harvest(tile)
		return

	# 对着果树用锄头 = 砍树
	var tree_here: Variant = _tree_at(tile_position)
	if tree_here != null:
		var item_here := get_selected_item()
		if str(item_here.get("kind", "")) == "tool" and str(item_here.get("item_id", "")) == "hoe":
			chop_fruit_tree(tree_here)
		else:
			ui.toast("%s · 用锄头可以砍倒" % (tree_here as FruitTree).get_tree_name())
		return

	var item := get_selected_item()
	if item.is_empty():
		ui.toast("先选择一个工具或种子")
		return

	var category := str(item.get("category", ""))
	var item_id := str(item.get("item_id", ""))

	match category:
		"tool":
			if item_id == "hoe":
				if tile.has_crop() and tile.is_withered:
					_clear_withered(tile)
				elif tile.can_till():
					_till(tile)
				else:
					ui.toast("这块地不能锄（已经翻过或种了作物）")
			elif item_id == "can":
				_water(tile)
			else:
				ui.toast("这个工具暂时用不了")
		"seed":
			_plant(tile, item)
		"fertilizer":
			_fertilize(tile)
		"crop", "fish", "fruit", "animal_product", "bee_product":
			ui.toast("成熟后点击作物就能收获；鱼和农产品去出货箱卖")
		"sapling":
			_plant_sapling(item, tile_position)
		"bee_goods":
			if item_id == "beehive":
				if place_beehive(tile_position):
					inventory.remove_item("beehive", 1, "bee_goods")
			else:
				ui.toast("蜂王 / 糖水 / 药物要在蜂箱旁按 E 使用")
		"rod":
			ui.toast("走到池塘边按 F 钓鱼")
		_:
			ui.toast("这个物品不能对地块使用")


func _plant_sapling(item: Dictionary, cell: Vector2i) -> void:
	var tree_id := str(item.get("item_id", ""))
	var check := can_plant_tree_at(cell)
	if not bool(check.get("ok", false)):
		ui.toast(str(check.get("reason", "这里不能种树")), "bad")
		return
	plant_fruit_tree(tree_id, cell)
	inventory.remove_item(tree_id, 1, "sapling")


func _tile_in_reach(tile_position: Vector2i) -> bool:
	var reach := float(DB.get_player_config().get("interact_reach_tiles", 2.4)) * TILE
	var center := Vector2(tile_position) * TILE + Vector2(TILE * 0.5, TILE * 0.5)
	return player.position.distance_to(center) <= reach


func _spend(action: String) -> bool:
	var cost := float(DB.get_stamina_costs().get(action, 0))
	if not player.spend_stamina(cost):
		AudioManager.play_sfx("error")
		ui.toast("体力不足，回家睡觉吧", "bad")
		return false
	ui.refresh_hud()
	return true


func _till(tile: FarmTile) -> void:
	if not _spend("till"):
		return
	player.play_tool_action("hoe", player.get_facing_vector())
	tile.till()
	if tutorial != null:
		tutorial.notify("till")
	AudioManager.play_sfx("till")
	ui.toast("翻地成功")


func _water(tile: FarmTile) -> void:
	if not tile.has_crop():
		ui.toast("先用锄头翻地，再播种")
		return
	if tile.is_withered:
		ui.toast("作物已经枯萎了，用锄头清理", "bad")
		return
	if tile.watered:
		ui.toast("已经浇过水了")
		return
	if not _spend("water"):
		return
	player.play_tool_action("water", player.get_facing_vector(), 0.3)
	tile.water()
	tile.play_water_fx()
	if tutorial != null:
		tutorial.notify("water")
	AudioManager.play_sfx("water")
	ui.toast("浇水成功")


func _fertilize(tile: FarmTile) -> void:
	if not tile.has_crop():
		ui.toast("先用锄头翻地，再播种")
		return
	if tile.fertilized:
		ui.toast("这块地已经施过肥了")
		return
	if not _spend("fertilize"):
		return
	player.play_tool_action("seed", player.get_facing_vector(), 0.2)
	tile.fertilize()
	tile.play_fertilize_fx()
	inventory.remove_item("fertilizer", 1, "fertilizer")
	ui.toast("施肥成功：收获稀有概率 5% → 12%", "good")


func _plant(tile: FarmTile, seed_item: Dictionary) -> void:
	var crop_id := str(seed_item.get("item_id", ""))
	var check := tile.can_plant(crop_id, time.season)
	if not bool(check.get("ok", false)):
		ui.toast(str(check.get("reason", "不能播种")), "bad")
		return
	if not _spend("plant"):
		return
	player.play_tool_action("seed", player.get_facing_vector(), 0.2)
	var result := tile.plant(crop_id, time.season, time.year)
	if not bool(result.get("ok", false)):
		ui.toast(str(result.get("reason", "不能播种")), "bad")
		return
	inventory.remove_item(crop_id, 1, "seed")
	if tutorial != null:
		tutorial.notify("plant")
	AudioManager.play_sfx("plant")
	ui.toast("种下了 %s" % DB.get_crop(crop_id).get("name", crop_id))


func _harvest(tile: FarmTile) -> void:
	var crop_id := tile.seed_id
	var item_preview := {
		"item_id": crop_id,
		"category": "crop",
		"count": 1,
	}
	if not inventory.can_add(item_preview):
		ui.toast("背包满了，先去卖点东西", "bad")
		return
	if not _spend("harvest"):
		return

	var result := tile.harvest()
	if not bool(result.get("ok", false)):
		ui.toast(str(result.get("reason", "不能收获")), "bad")
		return

	var item: Dictionary = result.get("item", {})
	item["count"] = 1
	inventory.add_item(item)
	_spawn_pickup(str(item.get("item_id", "")), str(item.get("category", "crop")),
		tile.position + Vector2(16, 10))
	crops_harvested += 1
	_achievements_check()

	_unlock("crop", crop_id)
	if tutorial != null:
		tutorial.notify("harvest")
	Anim.bounce(tile, 8.0)
	if bool(item.get("is_rare", false)):
		var rare_type := str(item.get("rare_type", ""))
		_unlock("crop", "%s_%s" % [crop_id, rare_type])
		Anim.rare_flash(tile, 0.5)
		AudioManager.play_sfx("harvest")
		ui.toast("✨ 收获了%s%s！" % [str(item.get("rare_name", "")), str(item.get("name", ""))], "good")
	else:
		AudioManager.play_sfx("harvest")
		ui.toast("收获 %s（%d G）" % [str(item.get("name", "")), int(item.get("price", 0))], "good")
	ui.refresh_hud()


func _clear_withered(tile: FarmTile) -> void:
	if not _spend("clear"):
		return
	tile.clear_crop(true)
	ui.toast("清理了枯萎的作物")


# ============================================================
# 钓鱼
# ============================================================

func _fish_weather() -> String:
	match time.weather:
		"storm":
			return "rain"
		"snow", "blizzard":
			return "sunny"
		_:
			return time.weather


func _try_fishing() -> void:
	if _transitioning or _fishing_cast or ui.is_modal_open():
		return
	if player.riding:
		ui.toast("骑乘时不能钓鱼，先按 E 下坐骑", "bad")
		return
	if indoor:
		ui.toast("室内不能钓鱼", "bad")
		return
	if _distance_to_water() > 1.6 * TILE:
		ui.toast("需要站到池塘边才能钓鱼", "bad")
		return

	var rod_id := inventory.find_rod()
	var rod := DB.get_rod(rod_id)
	var tier := int(rod.get("tier", 0))
	var candidates := DB.get_fish_candidates(
		"river",
		time.season,
		time.get_time_of_day(),
		_fish_weather(),
		tier
	)
	if candidates.is_empty():
		ui.toast("这个季节 / 时段 / 天气没有鱼咬钩", "bad")
		return
	if not _spend("fish"):
		return

	# 每次抽取新建 RNG。
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var fish: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]

	# 抛竿动画：玩家面向水面，浮漂落水后再弹出张力界面。
	_fishing_cast = true
	var water_point := _nearest_water_point()
	player.start_fishing_animation(water_point)
	player.input_locked = true
	await get_tree().create_timer(fishing_cast_time).timeout
	player.input_locked = false
	_fishing_cast = false
	if ui.is_modal_open() or in_mine or indoor:
		player.stop_fishing_animation()
		return

	ui.start_fishing(fish, {
		"rod_id": rod_id,
		"bait_id": "",
		"tackle_id": "",
		"is_rain": time.is_raining(),
		"is_dusk": time.get_time_of_day() == "dawn_dusk",
	})


## 主池塘离玩家最近的水面点（再向水中心推一点，保证浮漂落水）。
func _nearest_water_point() -> Vector2:
	var rect := Rect2(
		POND_RECT.position.x * TILE, POND_RECT.position.y * TILE,
		POND_RECT.size.x * TILE, POND_RECT.size.y * TILE
	)
	var closest := Vector2(
		clampf(player.position.x, rect.position.x, rect.end.x),
		clampf(player.position.y, rect.position.y, rect.end.y)
	)
	var direction := (rect.get_center() - closest).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.DOWN
	return closest + direction * 18.0


func on_fishing_finished(success: bool, result: Dictionary) -> void:
	player.stop_fishing_animation()
	var minigame := ui.get_minigame()
	if not success:
		ui.toast(minigame.get_result_text(), "bad")
		return

	var item := {
		"item_id": str(result.get("item_id", "")),
		"category": "fish",
		"count": 1,
		"name": str(result.get("name", "")),
		"weight": float(result.get("weight", 0.0)),
		"is_rare_color": bool(result.get("is_rare_color", false)),
		"is_giant": bool(result.get("is_giant", false)),
		"is_heavy": bool(result.get("is_heavy", false)),
		"rare_name": str(result.get("rare_name", "")),
		"price": int(result.get("price", 0)),
	}
	if not inventory.can_add(item):
		_spawn_ground_item(item, player.fishing_target)
		ui.toast("背包满了，鱼掉在岸边", "bad")
		return
	inventory.add_item(item)
	_spawn_pickup(str(result.get("item_id", "")), "fish", player.fishing_target)
	fish_caught += 1
	_achievements_check()

	var fish_id := str(result.get("item_id", ""))
	_unlock("fish", fish_id)
	if bool(result.get("is_rare_color", false)):
		_unlock("fish", fish_id + "_color")
	if bool(result.get("is_giant", false)):
		_unlock("fish", fish_id + "_giant")
	if bool(result.get("is_heavy", false)):
		_unlock("fish", fish_id + "_heavy")

	player.play_fish_catch_effect(player.fishing_target)
	if camera != null:
		Anim.shake_camera(camera, 2.5, 0.18)
	AudioManager.play_sfx("fish_catch")
	ui.toast("🎣 " + minigame.get_result_text(), "good")
	ui.refresh_hud()


# ============================================================
# 商店 / 出货
# ============================================================

func buy_seed(crop_id: String, quantity: int) -> void:
	var definition := DB.get_crop(crop_id)
	if definition.is_empty():
		return
	if str(definition.get("season", "")) != time.season:
		ui.toast("当前季节不能种%s" % str(definition.get("name", crop_id)), "bad")
		return
	var price := DB.get_seed_price(crop_id)
	var total := price * quantity
	if price <= 0:
		ui.toast("这个种子暂时没有定价", "bad")
		return
	if money < total:
		ui.toast("钱不够", "bad")
		return
	if not inventory.can_add({"item_id": crop_id, "category": "seed", "count": quantity}):
		ui.toast("背包空间不够", "bad")
		return
	money -= total
	inventory.add_item({"item_id": crop_id, "category": "seed", "count": quantity})
	ui.refresh_hud()
	ui.refresh_shop()
	ui.toast("买了 %s种子 ×%d" % [str(definition.get("name", crop_id)), quantity], "good")


func buy_good(good_id: String, quantity: int) -> void:
	var good := DB.get_shop_good(good_id)
	if good.is_empty():
		return
	var price := int(good.get("price", 0))
	var total := price * quantity
	if money < total:
		ui.toast("钱不够", "bad")
		return
	var category := str(good.get("category", "goods"))
	if not inventory.can_add({"item_id": good_id, "category": category, "count": quantity}):
		ui.toast("背包空间不够", "bad")
		return
	money -= total
	inventory.add_item({"item_id": good_id, "category": category, "count": quantity})
	ui.refresh_hud()
	ui.refresh_shop()
	ui.toast("买了 %s ×%d" % [str(good.get("name", good_id)), quantity], "good")


func sell_stack(index: int, quantity: int) -> void:
	var gained := inventory.sell_slot(index, quantity)
	if gained <= 0:
		return
	money += gained
	total_earned += gained
	_achievements_check()
	AudioManager.play_sfx("coin")
	ui.refresh_hud()
	ui.refresh_shop()
	ui.toast("卖出 %d G" % gained, "good")


func sell_all(from_bin := false) -> void:
	var result := inventory.sell_all()
	if int(result.get("count", 0)) <= 0:
		ui.toast("背包里没有可以卖的东西", "bad")
		return
	money += int(result.get("money", 0))
	total_earned += int(result.get("money", 0))
	_achievements_check()
	AudioManager.play_sfx("coin")
	ui.refresh_hud()
	if ui.get_modal() == "shop":
		ui.refresh_shop()
	ui.toast(
		"%s收购了 %d 件物品，+%d G" % [
			"出货箱" if from_bin else "商店",
			int(result.get("count", 0)),
			int(result.get("money", 0)),
		],
		"good"
	)
	if tutorial != null:
		tutorial.notify("ship")
	if from_bin:
		save_game()


# ============================================================
# 图鉴
# ============================================================

func _unlock(category: String, entry_id: String) -> void:
	if not unlock_book.has(category) or not (unlock_book[category] is Array):
		unlock_book[category] = []
	var entries: Array = unlock_book[category]
	if not (entry_id in entries):
		entries.append(entry_id)


# ============================================================
# 博物馆（古物 / 矿石 / 鱼类捐赠与陈列）
# ============================================================

func museum_items(category: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match category:
		"artifact":
			for artifact: Dictionary in DB.get_all_artifacts():
				result.append(_museum_entry(
					artifact, "artifact", int(artifact.get("price", 0)),
					str(artifact.get("desc", ""))))
		"mineral":
			for ore: Dictionary in MineFloorScript.ORES:
				result.append(_museum_entry(
					ore, "mineral", int(ore.get("price", 0)),
					"矿洞出产的矿物与宝石，按层数分布。"))
		"fish":
			for fish: Dictionary in DB.get_all_fishes():
				result.append(_museum_entry(
					fish, "fish", int(fish.get("base_price", 0)),
					"在河流、湖泊或海边钓到的鱼。"))
	return result


func _museum_entry(
	definition: Dictionary, category: String, price: int, desc: String
) -> Dictionary:
	var item_id := str(definition.get("id", ""))
	return {
		"id": item_id,
		"name": str(definition.get("name", item_id)),
		"price": price,
		"desc": desc,
		"category": category,
		"donated": museum_donations.has(item_id),
		"owned": inventory.count_item(item_id, category),
	}


## 捐赠一件展品：从背包扣除、记入博物馆并解锁图鉴。
func donate_to_museum(item_id: String, category: String) -> bool:
	if item_id.is_empty() or museum_donations.has(item_id):
		ui.toast("这件展品已经在博物馆了", "bad")
		return false
	if inventory.remove_item(item_id, 1, category) <= 0:
		ui.toast("背包里没有可捐赠的展品", "bad")
		return false
	museum_donations.append(item_id)
	_achievements_check()
	if category == "artifact":
		_unlock("artifact", item_id)
	else:
		_unlock(category, item_id)
	ui.toast("已捐赠：%s" % DB.get_item_name(item_id, category), "good")
	save_game()
	return true


# ============================================================
# 地块 / 存档辅助
# ============================================================

func _reset_tiles() -> void:
	for tile: FarmTile in farm_tiles.values():
		remove_child(tile)
		tile.queue_free()
	farm_tiles.clear()
	_build_farm_tiles()


func _tiles_to_save() -> Array:
	var result: Array = []
	for tile: FarmTile in farm_tiles.values():
		var data := tile.to_save()
		if bool(data.get("tilled", false)) or not str(data.get("seed", "")).is_empty():
			result.append(data)
	return result


func _animals_to_save() -> Array:
	var result: Array = []
	for animal: FarmAnimal in animals:
		result.append(animal.to_save())
	return result


func _clear_animals() -> void:
	for animal: FarmAnimal in animals:
		remove_child(animal)
		animal.queue_free()
	animals.clear()


func _spawn_animal_from_save(data: Dictionary) -> void:
	var animal: FarmAnimal = AnimalScript.new()
	add_child(animal)
	animal.from_save(data)

	# 坏档保护：数量超上限时跳过多余动物。
	if _animals_in(animal.building).size() >= get_building_capacity(animal.building) \
			and animal.building in ["coop", "barn"]:
		remove_child(animal)
		animal.queue_free()
		return
	animals.append(animal)


# ============================================================
# 地面绘制（占位美术，正式版换成 TileMapLayer）
# ============================================================

func _draw() -> void:
	# 地面由 GroundTileMap 绘制；这里只画农田边界与牧场。
	var farm_rect := Rect2(
		FARM_ORIGIN.x * TILE, FARM_ORIGIN.y * TILE,
		FARM_SIZE.x * TILE, FARM_SIZE.y * TILE
	)
	# 农田：不画边框和网格线，只用不规则土色斑块提示这是一片可开垦的空地。
	_draw_farmland_hint(farm_rect)

	_draw_pasture()
	_draw_debug_collision()

	# 栖息地搬迁预览
	if not _placing_pet_house_id.is_empty():
		var house := _find_house_data(_placing_pet_house_id)
		if not house.is_empty():
			var house_type := str(house.get("type", ""))
			var tile := _mouse_tile()
			var size := _pet_house_size(house_type)
			var valid := _can_place_pet_house(house_type, tile, _placing_pet_house_id)
			var rect := Rect2(Vector2(tile) * TILE, Vector2(size) * TILE)
			var fill := Color(0.35, 0.65, 0.35, 0.28) if valid \
				else Color(0.78, 0.28, 0.28, 0.28)
			var edge := Color(0.25, 0.50, 0.25, 0.90) if valid \
				else Color(0.72, 0.20, 0.20, 0.90)
			draw_rect(rect, fill, true)
			draw_rect(rect, edge, false, 2.0)


## 牧场草地 + 栅栏（视觉层；碰撞在 _build_pasture_fence）。
## 农田提示：不规则土色小斑块，避免出现规整网格。
func _draw_farmland_hint(rect: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022
	var count := 46
	for index in count:
		var x := rect.position.x + rng.randf() * rect.size.x
		var y := rect.position.y + rng.randf() * rect.size.y
		var w := 3.0 + rng.randf() * 7.0
		var h := 2.0 + rng.randf() * 3.0
		draw_rect(Rect2(roundf(x), roundf(y), w, h), Color(0.62, 0.52, 0.36, 0.10), true)
	# 四角小石块/草点缀，让边界自然
	for index in 10:
		var x := rect.position.x + rng.randf() * rect.size.x
		var y := rect.position.y + rng.randf() * rect.size.y
		draw_rect(Rect2(roundf(x), roundf(y), 2, 2), Color(0.42, 0.52, 0.30, 0.22), true)


func _draw_pasture() -> void:
	# 牧场草地略深，和农田区分开
	draw_rect(PASTURE, Color(0.45, 0.60, 0.34, 0.08), true)

	var rail := Art.WOOD
	var rail_dark := Art.WOOD_DARK
	var post := Art.WOOD_DARK
	var post_light := Art.WOOD_LIGHT

	var left := int(PASTURE.position.x)
	var right := int(PASTURE.end.x)
	var top := int(PASTURE.position.y)
	var bottom := int(PASTURE.end.y)
	var gate_left := int(PASTURE.position.x + 2.5 * TILE)
	var gate_right := int(PASTURE.position.x + 4.5 * TILE)

	for side in ["top", "bottom"]:
		var y: int = top if side == "top" else bottom
		var segments: Array = []
		if side == "top":
			segments = [[left, gate_left - 6], [gate_right + 6, right]]
		else:
			segments = [[left, right]]
		for segment: Array in segments:
			var from_x := int(segment[0])
			var to_x := int(segment[1])
			# 两道横栏 + 底部柔和阴影线
			draw_rect(Rect2(from_x, y - 20, to_x - from_x, 3), rail, true)
			draw_rect(Rect2(from_x, y - 12, to_x - from_x, 3), rail, true)
			draw_rect(Rect2(from_x, y - 9, to_x - from_x, 2), rail_dark, true)
			for x in range(from_x, to_x, 32):
				draw_rect(Rect2(x, y - 26, 5, 26), post, true)
				draw_rect(Rect2(x + 1, y - 26, 2, 24), post_light, true)

	for side in ["left", "right"]:
		var x: int = left if side == "left" else right
		draw_rect(Rect2(x, top, 4, bottom - top), rail_dark, true)
		for y in range(top, bottom, 32):
			draw_rect(Rect2(x - 1, y - 24, 7, 26), post, true)
			draw_rect(Rect2(x, y - 24, 2, 24), post_light, true)


func _draw_debug_collision() -> void:
	if not debug_draw_collision or _walls == null:
		return
	for child in _walls.get_children():
		if child is CollisionShape2D:
			var shape: CollisionShape2D = child
			if shape.shape is RectangleShape2D:
				var box: RectangleShape2D = shape.shape
				var rect := Rect2(shape.position - box.size * 0.5, box.size)
				draw_rect(rect, Color(1, 0.3, 0.3, 0.35), true)
				draw_rect(rect, Color(1, 0.2, 0.2, 0.8), false, 1.0)
	# 交互范围
	for point: Dictionary in [
		{"p": BED_POINT, "r": 62.0}, {"p": SHOP_POINT, "r": 78.0},
		{"p": BIN_POINT, "r": 58.0}, {"p": COOP_POINT, "r": 64.0},
		{"p": BARN_POINT, "r": 64.0}, {"p": MIRROR_POINT, "r": 54.0},
	]:
		draw_circle(point["p"], point["r"], Color(0.3, 0.7, 1.0, 0.14))
	draw_line(BED_POINT + Vector2(-200, 0), BED_POINT + Vector2(200, 0), Color(1, 1, 0, 0.5), 1.0)


# ============================================================
# 天气特效（屏幕空间，画在 UI 层下面）
# ============================================================
