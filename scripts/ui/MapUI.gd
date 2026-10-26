extends CanvasLayer
## 全局大地图（规范《全局地图系统规范.md》节点树 MapUI）。
## 节点在 _ready 中按规范命名构建；底图/图标使用 TextureRect + IconContainer。

const UITheme := preload("res://scripts/ui/PixelTheme.gd")
const MapBakerScript := preload("res://scripts/map/MapBaker.gd")

const ICON_SIZE := 16.0
const DEFAULT_MAP_SIZE := Vector2(262, 185)

var farm

var screen_mask: ColorRect
var map_panel: PanelContainer
var map_area: Control
var map_scroll: ScrollContainer
var map_content: Control
var map_background: TextureRect
var fog_of_war: TextureRect
var icon_container: Control
var info_panel: PanelContainer
var info_label: RichTextLabel

var map_reference := DEFAULT_MAP_SIZE
var world_size := Vector2.ONE
var region_origin := Vector2.ZERO
var region_id := "farm"
var title_label: Label
var zoom := 1.0
var _open := false
var _dragging := false
var _drag_moved := false
var _press_global := Vector2.ZERO
var _pressed_entity: Dictionary = {}
var _refresh_token := 0
var _items: Array[Dictionary] = []
var _player_icon: TextureRect
var _player_anchor := Vector2.ZERO
var _fog_image: Image
var _fog_texture: ImageTexture
var _fog_timer := 0.0
var _last_fog_pos := Vector2(-99999, -99999)
var _clear_fog_texture: ImageTexture


func _ready() -> void:
	layer = 20
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()


func setup(p_farm) -> void:
	farm = p_farm
	_ensure_fog()
	_reset_info()


func _process(delta: float) -> void:
	if farm == null or farm.player == null:
		return
	_fog_timer += delta
	if _fog_timer < 0.2:
		return
	_fog_timer = 0.0
	_ensure_fog()
	_reveal_around_player()
	if _open and region_id == "farm":
		if fog_of_war != null and fog_of_war.texture != _fog_texture:
			fog_of_war.texture = _fog_texture
		_apply_fog_visibility()


# ============================================================
# 节点树（对应规范 2.1）
# ============================================================

func _build() -> void:
	screen_mask = ColorRect.new()
	screen_mask.name = "ScreenMask"
	screen_mask.color = Color(0, 0, 0, 0.6)
	screen_mask.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(screen_mask)
	screen_mask.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	map_panel = PanelContainer.new()
	map_panel.name = "MapPanel"
	map_panel.custom_minimum_size = Vector2(384, 256)
	map_panel.add_theme_stylebox_override("panel", UITheme.map_panel_style())
	add_child(map_panel)
	map_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	map_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	map_panel.grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 8)
	map_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "农场地图"
	UITheme.apply_label(title_label, 14, UITheme.C_INK)
	vbox.add_child(title_label)

	map_area = Control.new()
	map_area.name = "MapArea"
	map_area.custom_minimum_size = map_reference
	map_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	map_area.clip_contents = true
	map_area.mouse_filter = Control.MOUSE_FILTER_STOP
	vbox.add_child(map_area)
	map_area.gui_input.connect(_on_map_area_gui_input)
	map_area.mouse_exited.connect(func() -> void:
		_dragging = false
		_pressed_entity = {}
	)

	map_scroll = ScrollContainer.new()
	map_scroll.name = "MapScroll"
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	map_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_scroll.clip_contents = true
	map_area.add_child(map_scroll)
	map_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	map_content = Control.new()
	map_content.name = "MapContent"
	map_content.custom_minimum_size = map_reference
	map_content.size = map_reference
	map_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_scroll.add_child(map_content)

	map_background = TextureRect.new()
	map_background.name = "MapBackground"
	map_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_background.stretch_mode = TextureRect.STRETCH_SCALE
	map_background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.add_child(map_background)
	map_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	fog_of_war = TextureRect.new()
	fog_of_war.name = "FogOfWar"
	fog_of_war.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fog_of_war.stretch_mode = TextureRect.STRETCH_SCALE
	fog_of_war.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fog_of_war.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.add_child(fog_of_war)
	fog_of_war.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	icon_container = Control.new()
	icon_container.name = "IconContainer"
	icon_container.clip_contents = true
	icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.add_child(icon_container)
	icon_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	info_panel = PanelContainer.new()
	info_panel.name = "InfoPanel"
	var info_style := StyleBoxFlat.new()
	info_style.bg_color = Color("#fdf5e6")
	info_style.border_color = Color("#8b6d52")
	info_style.set_border_width_all(1)
	info_style.content_margin_left = 5
	info_style.content_margin_right = 5
	info_style.content_margin_top = 2
	info_style.content_margin_bottom = 2
	info_panel.add_theme_stylebox_override("panel", info_style)
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(info_panel)

	info_label = RichTextLabel.new()
	info_label.name = "InfoLabel"
	info_label.bbcode_enabled = true
	info_label.fit_content = false
	info_label.scroll_active = false
	info_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_label.custom_minimum_size = Vector2(0, 18)
	info_label.add_theme_font_override("normal_font", UITheme.font())
	info_label.add_theme_font_size_override("normal_font_size", 12)
	info_label.add_theme_color_override("default_color", UITheme.C_INK_SOFT)
	info_panel.add_child(info_label)


# ============================================================
# 开关 / 暂停 / 输入
# ============================================================

func _input(event: InputEvent) -> void:
	if farm == null:
		return
	if event.is_action_pressed("open_map"):
		if _open:
			close_map()
		elif not farm.ui.is_modal_open() and not bool(farm._transitioning):
			open_map()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _open:
		close_map()
		get_viewport().set_input_as_handled()


func toggle_map() -> void:
	if _open:
		close_map()
	else:
		open_map()


func open_map() -> void:
	if _open or farm == null:
		return
	_open = true
	visible = true
	get_tree().paused = true
	farm.ui.set_compass_visible(false)
	refresh_map()


func close_map() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false
	if farm != null:
		farm.ui.set_compass_visible(true)


func is_open() -> bool:
	return _open


# ============================================================
# 刷新 / 实体
# ============================================================

func refresh_map() -> void:
	if farm == null:
		return
	_refresh_token += 1
	var token := _refresh_token
	for child in icon_container.get_children():
		child.queue_free()
	_items.clear()
	_player_icon = null
	await get_tree().process_frame
	if token != _refresh_token or not _open or not is_inside_tree():
		return

	var region: Dictionary = farm.get_map_region()
	region_id = str(region.get("id", "farm"))
	region_origin = region.get("origin", Vector2.ZERO)
	world_size = region.get("world_size", Vector2.ONE)
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return
	var view := map_area.size
	if view.x < 16.0 or view.y < 16.0:
		view = DEFAULT_MAP_SIZE
	map_reference = view
	zoom = 1.0
	title_label.text = str(region.get("title", "农场地图"))

	if region_id == "farm":
		var info: Dictionary = region.get("info", {})
		map_background.texture = MapBakerScript.bake_base(
			info, Vector2i(roundi(view.x), roundi(view.y)), false
		)
		_ensure_fog()
		fog_of_war.texture = _fog_texture
	else:
		var floor_color: Color = region.get("floor_color", Color("#b7cc8f"))
		var rock_points: PackedVector2Array = region.get("rock_points", PackedVector2Array())
		map_background.texture = MapBakerScript.bake_room(
			world_size, Vector2i(roundi(view.x), roundi(view.y)),
			region_id, floor_color, rock_points
		)
		fog_of_war.texture = _ensure_clear_fog()

	_apply_content_size(false)
	if region_id == "farm":
		_spawn_entities()
	else:
		var markers: Array = region.get("markers", [])
		_spawn_region_markers(markers)
	var player_pos: Vector2 = region.get("player_pos", Vector2.ZERO)
	_spawn_player(player_pos, str(region.get("player_facing", "down")))
	if region_id == "farm":
		_apply_fog_visibility()
	_reset_info()


func _spawn_entities() -> void:
	for entity: MapEntity in farm.get_map_entities():
		if not entity.is_active or not entity.show_on_bigmap:
			continue
		var anchor: Vector2 = _world_to_ui(entity.position)
		if entity.entity_type == "Resource":
			_spawn_label(entity.display_name, anchor + entity.label_offset)
			continue
		var icon_size := 8.0 if entity.entity_type == "NPC" else ICON_SIZE
		var icon := TextureRect.new()
		icon.texture = entity.map_icon
		icon.custom_minimum_size = Vector2(icon_size, icon_size)
		icon.size = Vector2(icon_size, icon_size)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon.z_index = 1
		icon.position = anchor - Vector2(icon_size * 0.5, icon_size)
		icon.set_meta("entity_name", entity.display_name)
		icon.mouse_entered.connect(func() -> void: _show_info(entity))
		icon.mouse_exited.connect(_reset_info)
		icon_container.add_child(icon)
		_items.append({
			"node": icon, "anchor": anchor, "kind": "icon",
			"entity": entity, "size": icon_size,
			"world_pos": entity.position, "name": entity.display_name,
		})
		if entity.show_label:
			_spawn_label(entity.display_name, anchor + entity.label_offset)


func _spawn_label(text: String, anchor: Vector2) -> void:
	if text.is_empty():
		return
	var holder := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.99, 0.96, 0.90, 0.92)
	style.border_color = Color("#cbb692")
	style.set_border_width_all(1)
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	holder.add_theme_stylebox_override("panel", style)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.z_index = 2
	var label := Label.new()
	label.text = text
	UITheme.apply_label(label, 12, UITheme.C_INK)
	holder.add_child(label)
	var text_width := float(text.length()) * 12.0 + 6.0
	var pos := anchor + Vector2(-1, -14)
	pos.x = clampf(pos.x, 2.0, maxf(2.0, map_reference.x - text_width - 2.0))
	pos.y = clampf(pos.y, 2.0, maxf(2.0, map_reference.y - 18.0))
	holder.position = pos
	icon_container.add_child(holder)
	_items.append({"node": holder, "anchor": pos, "kind": "label"})


func _spawn_player(world_pos: Vector2, facing: String) -> void:
	_player_anchor = _world_to_ui(world_pos)
	_player_icon = TextureRect.new()
	_player_icon.texture = UITheme.player_marker_icon(16)
	_player_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_player_icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	_player_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_player_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_player_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_player_icon.pivot_offset = Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)
	_player_icon.rotation = _facing_angle(facing)
	_player_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_player_icon.z_index = 3
	_player_icon.position = _player_anchor - Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)
	icon_container.add_child(_player_icon)


func _facing_angle(facing: String) -> float:
	match facing:
		"right":
			return PI * 0.5
		"down":
			return PI
		"left":
			return -PI * 0.5
		_:
			return 0.0


func _spawn_region_markers(markers: Array) -> void:
	for marker: Dictionary in markers:
		var marker_name := str(marker.get("name", ""))
		var desc := str(marker.get("desc", ""))
		var icon_kind := str(marker.get("icon", ""))
		var world_pos: Vector2 = marker.get("pos", Vector2.ZERO)
		var offset: Vector2 = marker.get("offset", Vector2(7, 3))
		var anchor := _world_to_ui(world_pos)
		var icon := TextureRect.new()
		icon.texture = UITheme.map_icon(icon_kind)
		icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon.z_index = 1
		icon.position = anchor - Vector2(ICON_SIZE * 0.5, ICON_SIZE)
		icon.set_meta("entity_name", marker_name)
		icon.mouse_entered.connect(func() -> void:
			info_label.text = "[b]%s[/b]　%s" % [marker_name, desc]
		)
		icon.mouse_exited.connect(_reset_info)
		icon_container.add_child(icon)
		_items.append({
			"node": icon, "anchor": anchor, "kind": "icon",
			"world_pos": world_pos, "name": marker_name,
		})
		_spawn_label(marker_name, anchor + offset)


func _world_to_ui(world_pos: Vector2) -> Vector2:
	var p := Vector2(
		(world_pos.x - region_origin.x) / world_size.x * map_reference.x,
		(world_pos.y - region_origin.y) / world_size.y * map_reference.y
	)
	return p.clamp(Vector2.ZERO, map_reference)


func _apply_content_size(reposition: bool) -> void:
	var content_size := map_reference * zoom
	map_content.custom_minimum_size = content_size
	map_content.size = content_size
	if not reposition:
		return
	for item: Dictionary in _items:
		var node: Control = item["node"]
		var anchor: Vector2 = item["anchor"]
		if str(item["kind"]) == "icon":
			var icon_size: float = item.get("size", ICON_SIZE)
			node.position = anchor * zoom - Vector2(icon_size * 0.5, icon_size)
		else:
			node.position = anchor * zoom
	if _player_icon != null:
		_player_icon.position = _player_anchor * zoom - Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)


# ============================================================
# 缩放 / 拖拽 / 悬停信息
# ============================================================

func _on_map_area_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.2)
			map_area.accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.0 / 1.2)
			map_area.accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging = true
				_drag_moved = false
				_press_global = map_area.get_global_mouse_position()
				_pressed_entity = _entity_at(_press_global)
			else:
				_dragging = false
				var entity := _pressed_entity
				_pressed_entity = {}
				if not _drag_moved and not entity.is_empty():
					_try_navigate(entity)
			map_area.accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if not _drag_moved \
				and map_area.get_global_mouse_position().distance_to(_press_global) > 4.0:
			_drag_moved = true
		if _drag_moved:
			map_scroll.scroll_horizontal -= int(event.relative.x)
			map_scroll.scroll_vertical -= int(event.relative.y)
		map_area.accept_event()


func _entity_at(global_point: Vector2) -> Dictionary:
	for item: Dictionary in _items:
		if str(item.get("kind", "")) != "icon":
			continue
		var node: Control = item["node"]
		if node.get_global_rect().has_point(global_point):
			return item
	return {}


func _try_navigate(item: Dictionary) -> void:
	if farm == null:
		return
	var target: Vector2 = item.get("world_pos", Vector2.ZERO)
	var display_name := str(item.get("name", ""))
	var entity: Variant = item.get("entity")
	if entity is MapEntity:
		target = (entity as MapEntity).position
		display_name = (entity as MapEntity).display_name
	if farm.navigate_to(target):
		close_map()
		farm.ui.toast("正在前往 %s" % display_name, "good")
	else:
		info_label.text = "无法前往：%s" % display_name


func _zoom_by(factor: float) -> void:
	var new_zoom := clampf(zoom * factor, 1.0, 3.0)
	if is_equal_approx(new_zoom, zoom):
		return
	var view := map_area.size
	var center_content := Vector2(
		map_scroll.scroll_horizontal, map_scroll.scroll_vertical
	) + view * 0.5
	var base_point := center_content / zoom
	zoom = new_zoom
	_apply_content_size(true)
	await get_tree().process_frame
	map_scroll.scroll_horizontal = int(base_point.x * zoom - view.x * 0.5)
	map_scroll.scroll_vertical = int(base_point.y * zoom - view.y * 0.5)


func _show_info(entity: MapEntity) -> void:
	if info_label == null:
		return
	info_label.text = "[b]%s[/b]　%s" % [entity.display_name, entity.tooltip_desc]


func _reset_info() -> void:
	if info_label == null or farm == null:
		return
	if region_id != "farm":
		var location := title_label.text if title_label != null else "地图"
		info_label.text = "%s　|　点击图标前往 / 悬停查看详情　|　M / Esc 关闭" % location
		return
	info_label.text = "农场　动物 %d　宠物 %d　果树 %d　蜂箱 %d　|　M / Esc 关闭" % [
		farm.animals.size(), farm.pets.size(),
		farm.fruit_trees.size(), farm.beehives.size(),
	]


func _ensure_clear_fog() -> Texture2D:
	if _clear_fog_texture == null:
		var img := Image.create(262, 185, false, Image.FORMAT_RGBA8)
		img.fill(Color(0, 0, 0, 0))
		_clear_fog_texture = ImageTexture.create_from_image(img)
	return _clear_fog_texture


func _ensure_fog() -> void:
	if _fog_image == null:
		_fog_image = Image.create(262, 185, false, Image.FORMAT_RGBA8)
		_fog_image.fill(Color(0.06, 0.05, 0.04, 0.82))
		_fog_texture = ImageTexture.create_from_image(_fog_image)
		_last_fog_pos = Vector2(-99999, -99999)
		_reveal_around_player()


## 迷雾写入存档：PNG → Base64，体积远小于逐像素 JSON。
func export_fog() -> String:
	if _fog_image == null:
		return ""
	return Marshalls.raw_to_base64(_fog_image.save_png_to_buffer())


func import_fog(encoded: String) -> void:
	if encoded.is_empty():
		return
	var bytes := Marshalls.base64_to_raw(encoded)
	var image := Image.new()
	if image.load_png_from_buffer(bytes) != OK:
		return
	if image.get_width() != 262 or image.get_height() != 185:
		image.resize(262, 185, Image.INTERPOLATE_NEAREST)
	image.convert(Image.FORMAT_RGBA8)
	_fog_image = image
	_fog_texture = ImageTexture.create_from_image(_fog_image)
	_last_fog_pos = Vector2(-99999, -99999)
	if fog_of_war != null:
		fog_of_war.texture = _fog_texture


## 新游戏时清空探索记录。
func reset_fog() -> void:
	_fog_image = null
	_fog_texture = null
	_last_fog_pos = Vector2(-99999, -99999)
	if fog_of_war != null:
		fog_of_war.texture = null


func _reveal_around_player() -> void:
	if farm == null or farm.player == null or _fog_image == null:
		return
	if farm.indoor or farm.in_mine:
		return
	var world: Vector2 = farm.get_map_info().get("world_size", Vector2.ONE)
	if world.x <= 0.0:
		return
	var pos: Vector2 = farm.player.position
	if pos.distance_to(_last_fog_pos) < 8.0:
		return
	_last_fog_pos = pos
	var w := _fog_image.get_width()
	var h := _fog_image.get_height()
	var cx := int(pos.x / world.x * float(w))
	var cy := int(pos.y / world.y * float(h))
	var radius := 28
	var fog_color := Color(0.06, 0.05, 0.04)
	for y in range(maxi(0, cy - radius), mini(h, cy + radius + 1)):
		for x in range(maxi(0, cx - radius), mini(w, cx + radius + 1)):
			var distance := Vector2(x - cx, y - cy).length()
			if distance > float(radius):
				continue
			var alpha := 0.0
			if distance > float(radius - 4):
				alpha = clampf((distance - float(radius - 4)) / 4.0, 0.0, 1.0) * 0.82
			# 取最小值：已探索区域不会被后续圆环边缘重新压暗，
			# 否则连续移动会在迷雾上留下同心圆环。
			var existing := _fog_image.get_pixel(x, y)
			_fog_image.set_pixel(x, y,
				Color(fog_color.r, fog_color.g, fog_color.b, minf(existing.a, alpha)))
	_fog_texture.update(_fog_image)


func _apply_fog_visibility() -> void:
	if region_id != "farm":
		for item: Dictionary in _items:
			var visible_node: Control = item["node"]
			visible_node.visible = true
		return
	if _fog_image == null:
		return
	var w := _fog_image.get_width()
	var h := _fog_image.get_height()
	for item: Dictionary in _items:
		var node: Control = item["node"]
		var anchor: Vector2 = item["anchor"]
		var fx := int(anchor.x / map_reference.x * float(w))
		var fy := int(anchor.y / map_reference.y * float(h))
		var hidden := false
		if fx >= 0 and fy >= 0 and fx < w and fy < h:
			hidden = _fog_image.get_pixel(fx, fy).a > 0.5
		else:
			hidden = true
		node.visible = not hidden
