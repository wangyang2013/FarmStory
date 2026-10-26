class_name MapBaker
extends RefCounted
## 把农场地形烘焙成一张底图纹理，供 MapUI / Minimap 的 MapBackground 使用。
## 只画地形与静态装饰；建筑/设施图标与文字标签由节点负责。

const TILE_PX := 32.0
const C_GRASS := Color("#b7cc8f")
const C_GRASS_DARK := Color("#a6bd7f")
const C_WATER := Color("#8db4cc")
const C_WATER_LINE := Color(0.84, 0.94, 0.90, 0.30)
const C_FARM := Color("#a87c53")
const C_FARM_ROW := Color("#8d6543")
const C_PASTURE := Color("#a9c584")
const C_FENCE := Color("#8a7350")
const C_PATH := Color("#c9ae83")
const C_SAND := Color("#d9c69a")
const C_TREE := Color("#4f7a44")
const C_ROCK := Color("#8a8578")
const C_BORDER := Color("#8b6d52")


static func bake_base(info: Dictionary, size: Vector2i, compact: bool) -> Texture2D:
	if size.x <= 0 or size.y <= 0:
		return null
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(C_GRASS)
	var world: Vector2 = info.get("world_size", Vector2.ONE)
	if world.x <= 0.0 or world.y <= 0.0:
		return ImageTexture.create_from_image(img)
	var sx := float(size.x) / world.x
	var sy := float(size.y) / world.y

	if not compact:
		for index in 26:
			var px := 6 + (index * 41) % maxi(1, size.x - 12)
			var py := 6 + (index * 67) % maxi(1, size.y - 12)
			_fill(img, Rect2i(px, py, 1, 1), C_GRASS_DARK)

	# 道路 / 沙地
	var cell_w := maxi(1, roundi(TILE_PX * sx))
	var cell_h := maxi(1, roundi(TILE_PX * sy))
	for point in _points(info, "sand_cells"):
		_fill(img, Rect2i(roundi(point.x * sx), roundi(point.y * sy), cell_w, cell_h), C_SAND)
	for point in _points(info, "path_cells"):
		_fill(img, Rect2i(roundi(point.x * sx), roundi(point.y * sy), cell_w, cell_h), C_PATH)

	# 农田
	var farm_rect: Rect2 = info.get("farm_rect", Rect2())
	var fr := _map_rect(farm_rect, sx, sy)
	_fill(img, fr, C_FARM)
	if not compact:
		var row_y := fr.position.y + 3
		while row_y < fr.end.y - 2:
			_fill(img, Rect2i(fr.position.x + 2, row_y, maxi(1, fr.size.x - 4), 1), C_FARM_ROW)
			row_y += 5

	# 牧场
	var pasture: Rect2 = info.get("pasture_rect", Rect2())
	var pa := _map_rect(pasture, sx, sy)
	_fill(img, pa, C_PASTURE)
	_border(img, pa, C_FENCE)

	# 池塘：大地图用椭圆，小地图保持矩形（像素太小）
	var pond: Rect2 = info.get("pond_rect", Rect2())
	var pr := _map_rect(pond, sx, sy)
	if compact:
		_fill(img, pr, C_WATER)
	else:
		_fill_ellipse(img, pr.grow(1), C_WATER.darkened(0.18))
		_fill_ellipse(img, pr, C_WATER)
		for index in 3:
			var line_y := pr.position.y + 5 + index * 6
			_fill(img, Rect2i(pr.position.x + pr.size.x / 3, line_y,
				maxi(1, pr.size.x / 3), 1), C_WATER_LINE)
		var small_pond: Rect2 = info.get("small_pond_rect", Rect2())
		if small_pond.size.x > 0.0:
			var spr := _map_rect(small_pond, sx, sy)
			_fill_ellipse(img, spr.grow(1), C_WATER.darkened(0.18))
			_fill_ellipse(img, spr, C_WATER)
		# 河流（左侧纵向 + 底部横向）
		var river_rects: Variant = info.get("river_rects", [])
		if river_rects is Array:
			for raw_river: Variant in river_rects:
				if raw_river is Rect2:
					var river_rect: Rect2 = raw_river
					var rr := _map_rect(river_rect, sx, sy)
					_fill(img, rr, C_WATER)
					_border(img, rr, C_WATER.darkened(0.18))

	# 资源点
	if not compact:
		for point in _points(info, "tree_points"):
			_dot(img, point, sx, sy, 3, C_TREE)
		for point in _points(info, "hive_points"):
			_dot(img, point, sx, sy, 2, Color("#d9b45c"))
		for point in _points(info, "tree_prop_points"):
			_dot(img, point, sx, sy, 2, C_TREE)
		for point in _points(info, "rock_prop_points"):
			_dot(img, point, sx, sy, 1, C_ROCK)
	else:
		for point in _points(info, "tree_prop_points"):
			_dot(img, point, sx, sy, 1, C_TREE)

	_border(img, Rect2i(Vector2i.ZERO, size), C_BORDER)
	return ImageTexture.create_from_image(img)


## 椭圆填充（像素地图上的池塘）。
static func _fill_ellipse(img: Image, rect: Rect2i, color: Color) -> void:
	var cx := float(rect.position.x) + float(rect.size.x) * 0.5
	var cy := float(rect.position.y) + float(rect.size.y) * 0.5
	var rx := maxf(1.0, float(rect.size.x) * 0.5)
	var ry := maxf(1.0, float(rect.size.y) * 0.5)
	for y in range(maxi(0, rect.position.y), mini(img.get_height(), rect.end.y)):
		for x in range(maxi(0, rect.position.x), mini(img.get_width(), rect.end.x)):
			var nx := (float(x) + 0.5 - cx) / rx
			var ny := (float(y) + 0.5 - cy) / ry
			if nx * nx + ny * ny <= 1.0:
				img.set_pixel(x, y, color)


## 室内 / 矿洞等小区域底图：地板 + 边框；矿洞额外烘焙石头点位。
static func bake_room(
	world_size: Vector2,
	size: Vector2i,
	kind: String,
	floor_color: Color,
	rock_points: PackedVector2Array
) -> Texture2D:
	if size.x <= 0 or size.y <= 0:
		return null
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(floor_color)
	var sx := float(size.x) / maxf(1.0, world_size.x)
	var sy := float(size.y) / maxf(1.0, world_size.y)

	if kind == "house":
		var line_y := 6
		while line_y < size.y - 4:
			_fill(img, Rect2i(3, line_y, maxi(1, size.x - 6), 1), floor_color.darkened(0.08))
			line_y += 6
	elif kind == "mine":
		for index in 24:
			var px := 4 + (index * 37) % maxi(1, size.x - 8)
			var py := 4 + (index * 53) % maxi(1, size.y - 8)
			_fill(img, Rect2i(px, py, 2, 1), floor_color.darkened(0.18))
		for point in rock_points:
			_dot(img, point, sx, sy, 3, Color("#8a8578"))
			_dot(img, point, sx, sy, 1, Color("#b9b3a6"))

	_border(img, Rect2i(Vector2i.ZERO, size), C_BORDER)
	return ImageTexture.create_from_image(img)


static func _points(info: Dictionary, key: String) -> PackedVector2Array:
	return info.get(key, PackedVector2Array())


static func _map_rect(rect: Rect2, sx: float, sy: float) -> Rect2i:
	return Rect2i(
		roundi(rect.position.x * sx), roundi(rect.position.y * sy),
		maxi(1, roundi(rect.size.x * sx)), maxi(1, roundi(rect.size.y * sy))
	)


static func _fill(img: Image, rect: Rect2i, color: Color) -> void:
	var x0 := maxi(0, rect.position.x)
	var y0 := maxi(0, rect.position.y)
	var x1 := mini(img.get_width(), rect.end.x)
	var y1 := mini(img.get_height(), rect.end.y)
	if x1 > x0 and y1 > y0:
		img.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), color)


static func _border(img: Image, rect: Rect2i, color: Color) -> void:
	_fill(img, Rect2i(rect.position.x, rect.position.y, rect.size.x, 1), color)
	_fill(img, Rect2i(rect.position.x, rect.end.y - 1, rect.size.x, 1), color)
	_fill(img, Rect2i(rect.position.x, rect.position.y, 1, rect.size.y), color)
	_fill(img, Rect2i(rect.end.x - 1, rect.position.y, 1, rect.size.y), color)


static func _dot(img: Image, point: Vector2, sx: float, sy: float, dot_size: int, color: Color) -> void:
	_fill(img, Rect2i(
		roundi(point.x * sx) - dot_size / 2,
		roundi(point.y * sy) - dot_size / 2,
		dot_size, dot_size
	), color)
