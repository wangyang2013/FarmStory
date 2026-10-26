class_name HouseInterior
extends Node2D
## 自宅室内（按《室内系统设计》第二章实现的最小可用版本）。
##
## 规则：
##   - 进入室内：时间停止（TimeSystem.enter_location("house")）
##   - 室内禁用锄头 / 水壶 / 鱼竿等工具，只允许交互
##   - 不显示天气粒子
##   - 与室外共用同一个 Player / Inventory / UI，通过传送切换，不重载场景
##
## 绘制坐标以「格子」为单位（1 格 = 32px），内部统一乘 TILE，
## 保证和室外同样的像素密度。

const Art := preload("res://scripts/art/PixelArt.gd")
const DB := preload("res://scripts/core/ConfigDB.gd")

const TILE := 32
const ROOM_W := 12
const ROOM_H := 9

signal sleep_requested
signal exit_requested
signal mirror_requested
signal storage_requested(kind: String)
signal cellar_requested
signal kitchen_requested
signal tv_requested
signal bathroom_requested
signal spouse_talked

var origin := Vector2(0, -1200.0)
var level := 1
var spouse_active := false
var spouse_name := ""
var spouse_look: Dictionary = {}
var spouse_point := Vector2.ZERO

var bed_point := Vector2.ZERO
var mirror_point := Vector2.ZERO
var storage_point := Vector2.ZERO
var cellar_point := Vector2.ZERO
var kitchen_point := Vector2.ZERO
var door_point := Vector2.ZERO
var tv_point := Vector2.ZERO
var bathroom_point := Vector2.ZERO
var fridge_point := Vector2.ZERO
## 已摆放家具：[{"id": "furn_rug", "gx": 3, "gy": 5}]
var furniture: Array = []

var _ember_t := 0.0


func setup(p_origin: Vector2, p_level := 1) -> void:
	origin = p_origin
	level = p_level
	position = origin
	bed_point = origin + Vector2(2.6, 2.5) * TILE
	mirror_point = origin + Vector2(9.2, 2.6) * TILE
	storage_point = origin + Vector2(9.4, 6.4) * TILE
	cellar_point = origin + Vector2(8.2, 7.25) * TILE
	kitchen_point = origin + Vector2(2.4, 5.4) * TILE
	door_point = origin + Vector2(6.0, 8.3) * TILE
	tv_point = origin + Vector2(7.2, 2.3) * TILE
	bathroom_point = origin + Vector2(9.8, 4.5) * TILE
	fridge_point = origin + Vector2(10.6, 3.0) * TILE
	spouse_point = origin + Vector2(7.4, 4.4) * TILE
	queue_redraw()


func set_spouse(p_name: String, p_look: Dictionary) -> void:
	spouse_active = not p_name.is_empty()
	spouse_name = p_name
	spouse_look = p_look.duplicate(true)
	queue_redraw()


func clear_spouse() -> void:
	spouse_active = false
	spouse_name = ""
	spouse_look.clear()
	queue_redraw()


func set_level(value: int) -> void:
	level = clampi(value, 1, 3)
	queue_redraw()


## 更新家具列表并重绘（数据由 Farm 持有，室内只负责显示与碰撞判定）。
func set_furniture(entries: Array) -> void:
	furniture = entries
	queue_redraw()


## 该格是否已被家具占用（按家具尺寸计算）。
func is_furniture_blocked(gx: int, gy: int) -> bool:
	for entry: Dictionary in furniture:
		var definition := DB.get_furniture(str(entry.get("id", "")))
		var size: Array = definition.get("size", [1, 1])
		var w := maxi(1, int(size[0]))
		var h := maxi(1, int(size[1]))
		var fx := int(entry.get("gx", 0))
		var fy := int(entry.get("gy", 0))
		if gx >= fx and gx < fx + w and gy >= fy and gy < fy + h:
			return true
	return false


func get_bounds() -> Rect2:
	return Rect2(origin, Vector2(ROOM_W * TILE, ROOM_H * TILE))


func get_wall_rects() -> Array:
	var left := origin.x
	var top := origin.y
	var right := origin.x + ROOM_W * TILE
	var bottom := origin.y + ROOM_H * TILE
	return [
		Rect2(left - 64, top - 64, ROOM_W * TILE + 128, 64),
		Rect2(left - 64, top, 64, ROOM_H * TILE),
		Rect2(right, top, 64, ROOM_H * TILE),
		Rect2(left, bottom, 5.4 * TILE, 64),
		Rect2(left + 7.0 * TILE, bottom, 5.0 * TILE, 64),
	]


func get_interact(player_position: Vector2) -> Dictionary:
	var points := [
		{"id": "bed", "position": bed_point, "radius": 56.0, "text": "按 E 睡觉（跳到次日 6:00 并保存）"},
		{"id": "mirror", "position": mirror_point, "radius": 52.0, "text": "按 E 照镜子（修改外观）"},
		{"id": "storage", "position": storage_point, "radius": 52.0, "text": "按 E 打开储物箱"},
		{"id": "tv", "position": tv_point, "radius": 48.0, "text": "按 E 看电视（天气预报）"},
		{"id": "door", "position": door_point, "radius": 58.0, "text": "按 E 出门"},
	]
	if level >= 2:
		points.append({
			"id": "kitchen", "position": kitchen_point, "radius": 52.0,
			"text": "按 E 打开厨房",
		})
		points.append({
			"id": "bathroom", "position": bathroom_point, "radius": 52.0,
			"text": "按 E 泡澡（每天一次，恢复 20% 体力）",
		})
		points.append({
			"id": "fridge", "position": fridge_point, "radius": 48.0,
			"text": "按 E 打开冰箱",
		})
	if level >= 3:
		points.append({
			"id": "cellar", "position": cellar_point, "radius": 52.0,
			"text": "按 E 进入地窖（熟成加工品）",
		})
	if spouse_active:
		points.append({
			"id": "spouse", "position": spouse_point, "radius": 52.0,
			"text": "按 E 与%s聊天" % spouse_name,
		})
	var best := {}
	var best_distance := INF
	for point: Dictionary in points:
		var distance := player_position.distance_to(point["position"])
		if distance <= float(point["radius"]) and distance < best_distance:
			best_distance = distance
			best = point
	return best


func interact(interact_id: String) -> void:
	match interact_id:
		"bed":
			sleep_requested.emit()
		"mirror":
			mirror_requested.emit()
		"storage":
			storage_requested.emit("storage")
		"fridge":
			storage_requested.emit("fridge")
		"cellar":
			cellar_requested.emit()
		"kitchen":
			kitchen_requested.emit()
		"tv":
			tv_requested.emit()
		"bathroom":
			bathroom_requested.emit()
		"spouse":
			spouse_talked.emit()
		"door":
			exit_requested.emit()


# ============================================================
# 绘制（坐标单位：格）
# ============================================================

func _box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x * TILE, y * TILE, w * TILE, h * TILE), color, true)


func _round_box(x: float, y: float, w: float, h: float, radius_px: float, color: Color) -> void:
	var px := x * TILE
	var py := y * TILE
	var pw := w * TILE
	var ph := h * TILE
	var radius := minf(radius_px, minf(pw, ph) * 0.5)
	# 逐行绘制圆角，避免抗锯齿
	var rows := int(round(ph))
	for row in rows:
		var yy := float(row) + 0.5
		var d := minf(yy, ph - yy)
		var inset := 0.0
		if d < radius:
			var t := radius - d
			inset = radius - sqrt(maxf(0.0, radius * radius - t * t))
		draw_rect(
			Rect2(px + inset, py + float(row), pw - inset * 2.0, 1.0),
			color,
			true
		)


func _line(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x * TILE, y * TILE, w * TILE, h * TILE), color, true)


func _draw_soft_light(cx: float, cy: float, rx: float, ry: float) -> void:
	for layer in 3:
		var scale := 1.0 - float(layer) * 0.28
		var alpha := 0.035 + float(layer) * 0.012
		var points := PackedVector2Array()
		for index in 24:
			var angle := TAU * float(index) / 24.0
			points.append(Vector2(cx + cos(angle) * rx * scale, cy + sin(angle) * ry * scale))
		draw_colored_polygon(points, Color(0.98, 0.88, 0.66, alpha))


func _process(delta: float) -> void:
	_ember_t += delta
	if visible:
		queue_redraw()


func _draw() -> void:
	# 木地板：暖琥珀色横向木板（参考室内图的金黄色木地板）
	_box(0, 0, ROOM_W, ROOM_H, Color("#cf9a5c"))
	for row in ROOM_H * 2:
		var y := float(row) * 0.5
		var tone := Color("#c28b4e") if row % 2 == 0 else Color("#ca975a")
		_box(0, y, ROOM_W, 0.5, tone)
		draw_rect(Rect2(0, y * TILE, ROOM_W * TILE, 1.0), Color(0.42, 0.27, 0.14, 0.22), true)
		var x := 1.6 if row % 2 == 0 else 3.4
		while x < ROOM_W:
			draw_rect(Rect2(x * TILE, y * TILE, 1.0, 0.5 * TILE), Color(0.42, 0.27, 0.14, 0.14), true)
			x += 4.2

	# 上方墙 + 墙裙（暖黄木墙 + 深棕压条）
	_box(0, 0, ROOM_W, 1.2, Color("#d8ad6a"))
	for index in 15:
		draw_rect(Rect2(float(index) * 0.8 * TILE, 0, 1.0, 1.2 * TILE),
			Color(0.42, 0.27, 0.14, 0.10), true)
	_box(0, 1.2, ROOM_W, 0.15, Color("#b8823f"))
	draw_rect(Rect2(0, 1.35 * TILE, ROOM_W * TILE, 2.0), Color(0.36, 0.22, 0.11, 0.28), true)

	# 墙上挂画（深木框 + 蓝绿风景）
	draw_rect(Rect2(7.1 * TILE, 0.28 * TILE, 1.1 * TILE, 0.62 * TILE), Color("#6f4328"), true)
	draw_rect(Rect2(7.2 * TILE, 0.36 * TILE, 0.9 * TILE, 0.46 * TILE), Color("#3f6070"), true)
	draw_rect(Rect2(7.2 * TILE, 0.68 * TILE, 0.9 * TILE, 0.14 * TILE), Color("#6f8f58"), true)

	# 窗户（透光）
	_round_box(4.2, 0.25, 2.4, 0.75, 1.0, Color("#f2e6cd"))
	_round_box(4.35, 0.32, 2.1, 0.6, 0.8, Color("#b9d2dc"))
	draw_rect(Rect2(5.4 * TILE, 0.32 * TILE, 2.0, 0.6 * TILE), Color("#f2e6cd"), true)
	draw_rect(Rect2(4.35 * TILE, 0.62 * TILE, 2.1 * TILE, 2.0), Color("#f2e6cd"), true)

	# 白天阳光透过窗户落在地板上的暖色光斑（硬边 + 棋盘格抖动边缘）
	Art.dither_band(
		self, 4.2 * TILE * 0.5, 1.5 * TILE * 0.5, 2.7 * TILE * 0.5, 1.9 * TILE * 0.5,
		Color(1.0, 0.90, 0.66, 0.06), Color(1.0, 0.90, 0.66, 0.20), 0.5)
	Art.rect(
		self, 4.5 * TILE * 0.5, 1.7 * TILE * 0.5, 2.0 * TILE * 0.5, 1.3 * TILE * 0.5,
		Color(1.0, 0.93, 0.72, 0.14))

	# 床（左上）：深木床架 + 奶白枕头 + 红色拼布被
	_round_box(1.2, 1.6, 3.2, 2.0, 2.0, Color("#7d4f30"))
	_round_box(1.35, 1.75, 2.9, 0.9, 1.5, Color("#f2e8d4"))
	_round_box(1.5, 1.85, 2.6, 0.6, 1.0, Color("#e2d3bb"))
	_round_box(1.35, 2.7, 2.9, 0.75, 1.2, Color("#b5534f"))
	_round_box(1.45, 2.78, 2.7, 0.45, 0.8, Color("#c96b5c"))
	_round_box(1.15, 1.5, 3.3, 0.28, 0.5, Color("#6f4328"))

	# 镜子（右上）
	_round_box(8.6, 1.5, 1.2, 2.0, 1.0, Color("#8c6a4a"))
	_round_box(8.75, 1.62, 0.9, 1.55, 0.8, Color("#bcd0d6"))
	_round_box(8.85, 1.72, 0.28, 0.75, 0.6, Color(1.0, 0.97, 0.90, 0.45))
	_round_box(8.5, 1.35, 1.4, 0.25, 0.5, Color("#a9825c"))

	# 储物箱（右下）：暖木 + 深色铁箍
	_round_box(8.2, 5.6, 2.4, 1.3, 1.0, Color("#8a5a34"))
	_round_box(8.3, 5.85, 2.2, 0.2, 0.4, Color("#5f4326"))
	_round_box(8.3, 5.6, 2.2, 0.4, 0.6, Color("#b07a45"))
	_round_box(9.1, 6.0, 0.5, 0.35, 0.3, Color("#e3c98c"))

	# 地毯：绿色主毯 + 流苏边
	_round_box(3.4, 4.6, 4.6, 2.0, 2.0, Color("#4f6f44"))
	_round_box(3.6, 4.8, 4.2, 1.6, 1.6, Color("#6f8a58"))
	_round_box(3.9, 5.0, 3.6, 1.2, 1.2, Color("#8aa06c"))
	for index in 6:
		var fx := (3.55 + float(index) * 0.7) * TILE
		draw_rect(Rect2(fx, 4.55 * TILE, 2.0, 3.0), Color("#d8c39a"), true)
		draw_rect(Rect2(fx, 6.62 * TILE, 2.0, 3.0), Color("#d8c39a"), true)

	# 壁炉（初始自宅）：石砌 + 深色炉膛 + 木壁炉架
	_round_box(1.5, 0.42, 2.0, 0.98, 1.0, Color("#8d8f8a"))
	for row in 3:
		draw_rect(Rect2(1.55 * TILE, (0.5 + float(row) * 0.22) * TILE,
			1.9 * TILE, 1.5), Color(0.30, 0.30, 0.28, 0.20), true)
	_round_box(1.35, 0.32, 2.3, 0.22, 0.4, Color("#6b4423"))
	_round_box(1.7, 0.62, 1.6, 0.65, 0.8, Art.shade_cool(Color("#4a3f38"), 0.20))
	Art.rect(self, 2.15 * TILE, 0.72 * TILE, 0.7 * TILE, 0.45 * TILE, Color("#d98a4a"))
	Art.rect(self, 2.35 * TILE, 0.82 * TILE, 0.3 * TILE, 0.25 * TILE, Color("#e8b45a"))
	# 火星粒子：从炉火升起后熄灭
	for index in 3:
		var rise := fmod(_ember_t * 0.7 + float(index) * 0.33, 1.0)
		var ember_x := (2.2 + sin(_ember_t * 2.0 + float(index)) * 0.15) * TILE
		var ember_y := (0.80 - rise * 0.5) * TILE
		draw_rect(Rect2(ember_x, ember_y, 2.0, 2.0),
			Color(1.0, 0.72, 0.35, (1.0 - rise) * 0.8))
	# 壁炉环境光反射：床沿暖橙反光
	Art.rect(self, 1.5 * TILE * 0.5, 1.55 * TILE * 0.5, 2.6 * TILE * 0.5, 0.5 * TILE * 0.5,
		Color(1.0, 0.58, 0.30, 0.10))

	# 老式电视 + 电视柜
	_round_box(6.5, 1.62, 1.5, 0.75, 0.8, Color("#7d6a55"))
	_round_box(6.6, 1.38, 1.3, 0.86, 0.8, Color("#4f4a44"))
	_round_box(6.72, 1.48, 1.06, 0.62, 0.5, Color("#b9cfd4"))
	Art.rect(self, 7.34 * TILE, 1.55 * TILE, 0.16 * TILE, 0.5 * TILE, Color("#d9e5e8"))

	# 桌椅
	_round_box(4.9, 4.75, 1.8, 0.95, 0.8, Color("#a9825c"))
	_round_box(5.0, 4.9, 1.6, 0.65, 0.6, Color("#c9a878"))
	_round_box(4.55, 5.55, 0.55, 0.6, 0.5, Color("#8c6a4a"))
	_round_box(6.5, 5.55, 0.55, 0.6, 0.5, Color("#8c6a4a"))

	# 盆栽
	_round_box(10.45, 1.35, 0.7, 0.55, 0.5, Color("#a9713f"))
	Art.ellipse(self, 10.8 * TILE, 1.25 * TILE, 0.5 * TILE, 0.35 * TILE, Color("#7e9971"))
	Art.ellipse(self, 10.6 * TILE, 1.1 * TILE, 0.28 * TILE, 0.2 * TILE, Color("#93b083"))

	if level >= 2:
		# 灶台 / 简易厨房（首次升级解锁）
		_round_box(1.4, 4.4, 2.2, 2.4, 1.2, Color("#8c6a4a"))
		_round_box(1.6, 4.6, 1.8, 1.0, 0.8, Color("#a9825c"))
		_round_box(1.8, 5.6, 1.4, 0.9, 0.6, Color("#4a3520"))
		Art.rect(self, 11.0, 43.0, 2.0, 3.0, Color("#d98a4a"))
		Art.rect(self, 12.5, 41.0, 1.6, 2.4, Color("#e8b45a"))
		Art.ellipse(self, 24.0, 44.0, 3.4, 2.2, Color("#6f6a63"))
		Art.rect(self, 20.5, 41.0, 7.0, 2.0, Color("#5a554d"))
		# 冰箱
		_round_box(10.15, 1.95, 1.1, 2.1, 0.7, Color("#d9d6cd"))
		_round_box(10.25, 2.05, 0.9, 0.9, 0.5, Color("#e9e6dd"))
		Art.rect(self, 10.55 * TILE, 2.2 * TILE, 0.5 * TILE, 0.1 * TILE, Color("#8d8b86"))
		# 浴室浴缸
		_round_box(8.7, 3.55, 1.9, 1.5, 1.2, Color("#e9e6dd"))
		_round_box(8.9, 3.75, 1.5, 1.1, 1.0, Color("#b9d2dc"))
		_round_box(9.0, 3.85, 1.3, 0.85, 0.8, Color("#9fc2cf"))

	if level >= 3:
		# 地窖入口
		_round_box(7.4, 6.85, 1.6, 0.7, 0.4, Color("#6b4423"))
		for row in 3:
			Art.rect(self, 7.55 * TILE, (6.95 + float(row) * 0.18) * TILE,
				1.3 * TILE, 0.08 * TILE, Color("#4a3b28"))

	# 已摆放的家具由 Farm 生成 InteriorProp 节点（参与 Y-sort）

	# 配偶（婚后住在自宅）
	if spouse_active and not spouse_look.is_empty():
		Art.draw_character(
			self, spouse_look, "down", 0.0, false, Vector2(7.4, 4.4) * TILE
		)

	# 门（底部中间）
	_box(5.4, 7.4, 1.3, 1.6, Color("#7c5231"))
	_box(5.5, 7.5, 1.1, 1.5, Color("#9a6a3f"))
	_box(6.35, 8.1, 0.16, 0.16, Color("#e3c98c"))

	# 暖光（预绘制柔光，不用实时光）
	for center: Vector2 in [Vector2(2.6, 3.0), Vector2(9.0, 2.6), Vector2(9.2, 6.2)]:
		_draw_soft_light(center.x * TILE, center.y * TILE, 44.0, 26.0)

	# 提示文字
	var font := PixelTheme.font()
	draw_string(
		font,
		Vector2(12, -10),
		"自宅 · 室内时间停止 · 工具不可用",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		Color("#5a4a38")
	)
