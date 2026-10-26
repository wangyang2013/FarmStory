class_name GroundTileMap
extends TileMapLayer
## 地面层：16px 图块 + TileMap 搭建的矩形网格（斜 45° 伪俯视，不是菱形等轴测）。
##
## 图集在运行时用 Image 生成，纹理过滤为 Nearest、无 Mipmap；
## 每个 16px 图块通过 TileMapLayer.scale = (2,2) 放大成 32px 屏幕格。
##
## 地形类型：
##   0 草地（按季节换图块）
##   1 水域
##   2 沙地
##   3 小路

const TILE_SIZE := 16
const ATLAS_COLS := 12
const ATLAS_ROWS := 3

const GRASS := 0
const WATER := 1
const SAND := 2
const PATH := 3

const SEASONS := ["spring", "summer", "autumn", "winter"]

var _source_id := -1
var _season := "spring"
var _atlas_coords: Dictionary = {}


func setup(map_width: int, map_height: int) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	scale = Vector2(2, 2)
	_build_atlas()
	_build_tileset()


func paint(terrain: PackedByteArray, map_width: int, map_height: int, season: String) -> void:
	clear()
	_season = season if season in SEASONS else "spring"
	for ty in map_height:
		for tx in map_width:
			var index := ty * map_width + tx
			if index >= terrain.size():
				continue
			var kind := int(terrain[index])
			set_cell(Vector2i(tx, ty), _source_id, _tile_for(kind, tx, ty, terrain, map_width, map_height))


## 换季重绘（图集本身已包含四季）。
func repaint(terrain: PackedByteArray, map_width: int, map_height: int, season: String) -> void:
	paint(terrain, map_width, map_height, season)


# ============================================================
# 图集
# ============================================================

func _build_atlas() -> void:
	var image := Image.create(ATLAS_COLS * TILE_SIZE, ATLAS_ROWS * TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	_atlas_coords.clear()

	# 四季草地：每种 3 个细微变体
	var season_index := 0
	for season: String in SEASONS:
		var colors: Array = _grass_colors(season)
		for variant in 3:
			var coord := Vector2i(season_index * 3 + variant, 0)
			_paint_grass(image, coord, colors, variant)
			_atlas_coords["%s_%d" % [season, variant]] = coord
		season_index += 1

	# 小路（row 1, col 4~5）
	_paint_path(image, Vector2i(4, 1), 0)
	_paint_path(image, Vector2i(5, 1), 1)
	_atlas_coords["path_0"] = Vector2i(4, 1)
	_atlas_coords["path_1"] = Vector2i(5, 1)

	# 沙地 (6,1)
	_paint_sand(image, Vector2i(6, 1))
	_atlas_coords["sand"] = Vector2i(6, 1)

	# 水：中心 + 四边 (7,1), (0..3,2)
	_paint_water(image, Vector2i(7, 1), "")
	_atlas_coords["water"] = Vector2i(7, 1)
	var edges := ["top", "bottom", "left", "right"]
	for index in edges.size():
		var coord := Vector2i(index, 2)
		_paint_water(image, coord, str(edges[index]))
		_atlas_coords["water_" + str(edges[index])] = coord

	var texture := ImageTexture.create_from_image(image)

	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for key: String in _atlas_coords.keys():
		source.create_tile(_atlas_coords[key])
	_source_id = tileset.add_source(source)
	tile_set = tileset


func _build_tileset() -> void:
	pass


func _grass_colors(season: String) -> Array:
	match season:
		"summer":
			return PixelArt.GRASS_SUMMER
		"autumn":
			return PixelArt.GRASS_AUTUMN
		"winter":
			return PixelArt.GRASS_WINTER
		_:
			return PixelArt.GRASS_SPRING


func _put(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height():
		image.set_pixel(x, y, color)


func _paint_grass(image: Image, coord: Vector2i, colors: Array, variant: int) -> void:
	var ox := coord.x * TILE_SIZE
	var oy := coord.y * TILE_SIZE
	var base: Color = colors[variant % colors.size()]
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			_put(image, ox + x, oy + y, base)

	# 草丛：3 像素高的小簇，颜色比底色略深（整改规范要求）
	var blade_dark: Color = base.darkened(0.10)
	var blade_mid: Color = base.darkened(0.05)
	var blade_light: Color = base.lightened(0.06)
	for index in 4:
		var bx := (index * 4 + variant * 2 + 1) % TILE_SIZE
		var by := (index * 5 + variant * 3 + 2) % TILE_SIZE
		_put(image, ox + bx, oy + by, blade_dark)
		_put(image, ox + bx, oy + by - 1, blade_dark)
		_put(image, ox + bx + 1, oy + by, blade_mid)
		_put(image, ox + bx + 2, oy + by - 1, blade_light)

	# 零星小花 / 石子：少量 10% 强调色，避免整片草地过于花哨
	if variant == 0:
		_put(image, ox + 5, oy + 12, Color("#e8c85a"))
		_put(image, ox + 6, oy + 12, Color("#f0d87a"))
	if variant == 1:
		_put(image, ox + 11, oy + 4, Color("#b9b3a4"))
		_put(image, ox + 12, oy + 4, Color("#a8a294"))
	if variant == 2:
		_put(image, ox + 3, oy + 9, Color("#d05a5a"))
		_put(image, ox + 4, oy + 9, Color("#e07a6a"))


func _paint_path(image: Image, coord: Vector2i, variant: int) -> void:
	var ox := coord.x * TILE_SIZE
	var oy := coord.y * TILE_SIZE
	var base: Color = PixelArt.PATH_COLORS[variant % PixelArt.PATH_COLORS.size()]
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			_put(image, ox + x, oy + y, base)
	var light := base.lightened(0.05)
	var dark := base.darkened(0.08)
	var spots := [[2, 3], [9, 6], [5, 12], [12, 11]]
	for spot: Array in spots:
		var x := (int(spot[0]) + variant * 2) % TILE_SIZE
		var y := int(spot[1])
		_put(image, ox + x, oy + y, light)
		_put(image, ox + x + 1, oy + y, dark)

	# 碎石：路面上的小石粒（参考图的金色土路颗粒感）
	for index in 3:
		var px := (index * 7 + variant * 5 + 3) % TILE_SIZE
		var py := (index * 11 + variant * 3 + 6) % TILE_SIZE
		_put(image, ox + px, oy + py, PixelArt.PATH_PEBBLE)
		_put(image, ox + px + 1, oy + py, dark)

	# 小路边缘不规则毛边：在四边随机啃掉几个像素，用更暗的土色过渡
	var fringe := base.darkened(0.12)
	for index in 5:
		var fx := (index * 3 + variant) % TILE_SIZE
		_put(image, ox + fx, oy, fringe)
		_put(image, ox + fx, oy + TILE_SIZE - 1, fringe)
		var fy := (index * 5 + variant * 2) % TILE_SIZE
		_put(image, ox, oy + fy, fringe)
		_put(image, ox + TILE_SIZE - 1, oy + fy, fringe)

	# 边缘草须：让土路自然过渡回草地（相对的两条边各一撮）
	var grass_fringe := Color("#7f9a5e")
	for index in 3:
		var gx := (index * 9 + variant * 4 + 2) % TILE_SIZE
		_put(image, ox + gx, oy, grass_fringe)
		var gy := (index * 7 + variant * 6 + 5) % TILE_SIZE
		_put(image, ox, oy + gy, grass_fringe)


func _paint_sand(image: Image, coord: Vector2i) -> void:
	var ox := coord.x * TILE_SIZE
	var oy := coord.y * TILE_SIZE
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			_put(image, ox + x, oy + y, PixelArt.SAND)
	var detail := PixelArt.SAND_DETAIL
	for spot: Array in [[3, 4], [10, 9], [6, 13]]:
		_put(image, ox + int(spot[0]), oy + int(spot[1]), detail)
		_put(image, ox + int(spot[0]) + 1, oy + int(spot[1]), detail)


func _paint_water(image: Image, coord: Vector2i, edge: String) -> void:
	var ox := coord.x * TILE_SIZE
	var oy := coord.y * TILE_SIZE
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			_put(image, ox + x, oy + y, PixelArt.WATER)

	# 柔和的水面反光（低对比，浅青/暖白）
	for ripple: Array in [[3, 5, 5], [9, 10, 4], [4, 12, 3]]:
		var start_x := int(ripple[0])
		var start_y := int(ripple[1])
		var length := int(ripple[2])
		for i in length:
			_put(image, ox + start_x + i, oy + start_y, PixelArt.WATER_LIGHT)
	_put(image, ox + 12, oy + 7, Color(0.92, 0.98, 0.95))
	_put(image, ox + 20, oy + 16, Color(0.92, 0.98, 0.95))

	# 水岸 4 层：浅水 → 抖动过渡 → 深水；边缘做锯齿毛边（禁止直线）
	if edge.is_empty():
		return
	for axis in TILE_SIZE:
		# 每格边缘深浅 1~2px 随机，形成细碎岸线
		var depth := 1 + _hash(axis, coord.x * 3 + coord.y * 7, 11) % 2
		for d in depth:
			var p := _edge_pixel(ox, oy, edge, axis, d)
			_put(image, p.x, p.y, PixelArt.WATER_EDGE)
		# 零星浅水像素，避免 1px 棋盘形成“栅栏”条纹
		for d in range(depth, depth + 3):
			if (axis * 7 + d * 13) % 5 == 0:
				var q := _edge_pixel(ox, oy, edge, axis, d)
				_put(image, q.x, q.y, PixelArt.WATER_SHALLOW)


## 水岸边缘像素坐标：i 为沿岸方向，depth 为从岸边向水内的距离。
func _edge_pixel(ox: int, oy: int, edge: String, i: int, depth: int) -> Vector2i:
	match edge:
		"top":
			return Vector2i(ox + i, oy + depth)
		"bottom":
			return Vector2i(ox + i, oy + TILE_SIZE - 1 - depth)
		"left":
			return Vector2i(ox + depth, oy + i)
		_:
			return Vector2i(ox + TILE_SIZE - 1 - depth, oy + i)


# ============================================================
# 选图块
# ============================================================

func _tile_for(
	kind: int,
	tx: int,
	ty: int,
	terrain: PackedByteArray,
	map_width: int,
	map_height: int
) -> Vector2i:
	match kind:
		WATER:
			var above := _terrain_at(terrain, tx, ty - 1, map_width, map_height)
			var below := _terrain_at(terrain, tx, ty + 1, map_width, map_height)
			var left := _terrain_at(terrain, tx - 1, ty, map_width, map_height)
			var right := _terrain_at(terrain, tx + 1, ty, map_width, map_height)
			if above != WATER:
				return _atlas_coords["water_top"]
			if below != WATER:
				return _atlas_coords["water_bottom"]
			if left != WATER:
				return _atlas_coords["water_left"]
			if right != WATER:
				return _atlas_coords["water_right"]
			return _atlas_coords["water"]
		SAND:
			return _atlas_coords["sand"]
		PATH:
			var variant := _hash(tx, ty, 7) % 2
			return _atlas_coords["path_%d" % variant]
		_:
			var grass_variant := _hash(tx, ty, 3) % 3
			return _atlas_coords["%s_%d" % [_season, grass_variant]]


## 稳定的整数散列：让图块变体不规则分布，避免出现棋盘格。
func _hash(tx: int, ty: int, salt: int) -> int:
	var h := tx * 374761393 + ty * 668265263 + salt * 1442695041
	h = (h ^ (h >> 13)) * 1274126177
	return absi(h ^ (h >> 16))


func _terrain_at(terrain: PackedByteArray, tx: int, ty: int, map_width: int, map_height: int) -> int:
	if tx < 0 or ty < 0 or tx >= map_width or ty >= map_height:
		return -1
	var index := ty * map_width + tx
	if index >= terrain.size():
		return -1
	return int(terrain[index])
