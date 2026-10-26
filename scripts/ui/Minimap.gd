extends Control
## 常驻小地图（规范《全局地图系统规范.md》节点树 Minimap）。
## 静态图标只生成一次；玩家箭头逐帧更新；NPC 每 0.2s 更新位置。

const UITheme := preload("res://scripts/ui/PixelTheme.gd")
const MapBakerScript := preload("res://scripts/map/MapBaker.gd")

const ICON_SIZE := 8.0
const NPC_UPDATE_RATE := 0.2
const DEFAULT_SIZE := Vector2(96, 68)

var farm
var map_background: TextureRect
var icon_container: Control

var map_reference := DEFAULT_SIZE
var world_size := Vector2.ONE
var region_origin := Vector2.ZERO
var region_id := ""
var _region: Dictionary = {}
var player_icon: TextureRect
var npc_icons: Dictionary = {}
var _update_timer := 0.0
var _entity_count := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func setup(p_farm) -> void:
	farm = p_farm
	_build_map()


func _build() -> void:
	map_background = TextureRect.new()
	map_background.name = "MapBackground"
	map_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_background.stretch_mode = TextureRect.STRETCH_SCALE
	map_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(map_background)
	map_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	icon_container = Control.new()
	icon_container.name = "IconContainer"
	icon_container.clip_contents = true
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icon_container)
	icon_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_map() -> void:
	if farm == null:
		return
	var ref := size
	if ref.x < 8.0 or ref.y < 8.0:
		ref = DEFAULT_SIZE
	map_reference = ref
	_region = farm.get_map_region()
	region_id = str(_region.get("id", "farm"))
	region_origin = _region.get("origin", Vector2.ZERO)
	world_size = _region.get("world_size", Vector2.ONE)
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return

	var target := Vector2i(roundi(ref.x), roundi(ref.y))
	if region_id == "farm":
		var info: Dictionary = _region.get("info", {})
		map_background.texture = MapBakerScript.bake_base(info, target, true)
	else:
		var floor_color: Color = _region.get("floor_color", Color("#b7cc8f"))
		var rock_points: PackedVector2Array = _region.get(
			"rock_points", PackedVector2Array()
		)
		map_background.texture = MapBakerScript.bake_room(
			world_size, target, region_id, floor_color, rock_points
		)
	_entity_count = farm.get_map_entities().size()
	_generate_static_icons()
	_spawn_player()


func _generate_static_icons() -> void:
	for child in icon_container.get_children():
		child.queue_free()
	npc_icons.clear()
	player_icon = null
	if region_id == "farm":
		for entity: MapEntity in farm.get_map_entities():
			if not entity.show_on_minimap:
				continue
			if entity.entity_type == "Resource":
				continue
			var icon := _spawn_icon(entity.map_icon, entity.position,
				2 if entity.entity_type == "NPC" else 1)
			icon.visible = entity.is_active
			if entity.entity_type == "NPC":
				npc_icons[entity] = icon
	else:
		var markers: Array = _region.get("markers", [])
		for marker: Dictionary in markers:
			var world_pos: Vector2 = marker.get("pos", Vector2.ZERO)
			_spawn_icon(UITheme.map_icon(str(marker.get("icon", ""))), world_pos, 1)


func _spawn_icon(texture: Texture2D, world_pos: Vector2, z: int) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.z_index = z
	icon.position = _world_to_ui(world_pos) - Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)
	icon_container.add_child(icon)
	return icon


func _spawn_player() -> void:
	if farm == null or farm.player == null:
		return
	player_icon = TextureRect.new()
	player_icon.texture = UITheme.player_marker_icon(8)
	player_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	player_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	player_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_icon.pivot_offset = Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)
	player_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_icon.z_index = 3
	icon_container.add_child(player_icon)
	_update_player_icon()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or farm == null:
		return
	if farm.get_map_region_id() != region_id:
		_build_map()
	elif region_id == "farm" and farm.get_map_entities().size() != _entity_count:
		_build_map()
	_update_player_icon()
	_update_timer += delta
	if _update_timer >= NPC_UPDATE_RATE:
		_update_timer = 0.0
		for entity in npc_icons.keys():
			if is_instance_valid(entity) and is_instance_valid(npc_icons[entity]):
				npc_icons[entity].position = (
					_world_to_ui(entity.position) - Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)
				)
				npc_icons[entity].visible = entity.is_active


func _update_player_icon() -> void:
	if player_icon == null or farm.player == null:
		return
	var point := _world_to_ui(farm.player.position)
	player_icon.position = point - Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)
	player_icon.rotation = farm.player.get_facing_angle()


func _world_to_ui(world_pos: Vector2) -> Vector2:
	var p := Vector2(
		(world_pos.x - region_origin.x) / world_size.x * map_reference.x,
		(world_pos.y - region_origin.y) / world_size.y * map_reference.y
	)
	return p.clamp(Vector2.ZERO, map_reference)
