class_name BuildingInterior
extends Node2D
## 通用室内场景：所有建筑共用同一套渲染，数据来自 config/interiors.json。
##
## 美术要点（修订美术规范 / 室内系统设计）：
##   - 3/4 Top-Down：后墙画出竖直墙面高度，不是平面色块
##   - 墙面有墙裙、装饰线、挂画与窗光；地面按材质分区（木地板 / 瓷砖 / 石板 / 干草）
##   - 墙脚有环境遮蔽阴影，家具由 InteriorProp 单独节点绘制以参与 Y-sort
##   - 室内不绘制天气；暖色由 Farm 的 CanvasModulate 统一处理

const Art := preload("res://scripts/art/PixelArt.gd")
const DB := preload("res://scripts/core/ConfigDB.gd")

const TILE := 32
const WALL_H := 2.2          # 后墙高度（格）
const SIDE_W := 0.42         # 侧墙厚度（格）
const FLOOR_Y := WALL_H + 0.2
const DOOR_W := 1.6

var building_id := ""
var display_name := ""
var room_w := 12
var room_h := 8
var origin := Vector2.ZERO
var floor_style := "wood"
var wall_color := Color("#e8d9bb")
var wall_dark := Color("#d9c9a8")
var props: Array[Dictionary] = []
var door_point := Vector2.ZERO

var _t := 0.0


func setup(p_building_id: String, p_origin: Vector2) -> void:
	building_id = p_building_id
	origin = p_origin
	position = origin
	var data := DB.get_interior(building_id)
	display_name = str(data.get("name", building_id))
	room_w = maxi(6, int(data.get("width", 12)))
	room_h = maxi(5, int(data.get("height", 8)))
	floor_style = str(data.get("floor", "wood"))
	wall_color = Color(str(data.get("wall", "#e8d9bb")))
	wall_dark = Color(str(data.get("wall_dark", "#d9c9a8")))
	props.clear()
	var raw_props: Variant = data.get("props", [])
	if raw_props is Array:
		for entry: Variant in raw_props:
			if entry is Dictionary:
				props.append((entry as Dictionary).duplicate(true))
	door_point = origin + Vector2(float(room_w) * 0.5, float(room_h) - 0.6) * TILE
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	queue_redraw()


func get_bounds() -> Rect2:
	return Rect2(origin, Vector2(room_w, room_h) * TILE)


func get_wall_rects() -> Array:
	var left := origin.x
	var top := origin.y
	var right := origin.x + float(room_w) * TILE
	var bottom := origin.y + float(room_h) * TILE
	var door_half := DOOR_W * TILE * 0.5
	var door_x := origin.x + float(room_w) * 0.5 * TILE
	return [
		# 后墙（含纵深墙体）
		Rect2(left - 48, top - 96, float(room_w) * TILE + 96, WALL_H * TILE + 12),
		# 左右侧墙
		Rect2(left - 48, top, 48, float(room_h) * TILE),
		Rect2(right, top, 48, float(room_h) * TILE),
		# 底墙（中间留门）
		Rect2(left, bottom, door_x - door_half - left, 48),
		Rect2(door_x + door_half, bottom, right - (door_x + door_half), 48),
	]


## 返回离玩家最近的可交互家具；没有则返回空字典。
func get_interact(player_position: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance := 99999.0
	for entry: Dictionary in props:
		var action := str(entry.get("interact", ""))
		if action.is_empty():
			continue
		var world := origin + Vector2(
			float(entry.get("x", 0)) * TILE,
			float(entry.get("y", 0)) * TILE + TILE * 0.5)
		var distance := player_position.distance_to(world)
		if distance <= 52.0 and distance < best_distance:
			best_distance = distance
			best = {
				"id": action,
				"position": world,
				"radius": 52.0,
				"text": str(entry.get("text", "按 E 互动")),
			}
	# 门
	if player_position.distance_to(door_point) <= 54.0 and best.is_empty():
		best = {
			"id": "exit_building",
			"position": door_point,
			"radius": 54.0,
			"text": "按 E 离开",
		}
	return best


## 家具列表（Farm 用它们创建可 Y-sort 的独立节点）。
func get_props() -> Array[Dictionary]:
	return props


# ============================================================
# 绘制：地面 + 墙体（家具由 InteriorProp 单独绘制）
# ============================================================

func _draw() -> void:
	var w := float(room_w) * TILE
	var h := float(room_h) * TILE
	var floor_y := FLOOR_Y * TILE
	_draw_floor(w, h, floor_y)
	_draw_back_wall(w, floor_y)
	_draw_side_walls(h, floor_y)
	_draw_wall_ao(w, h, floor_y)
	_draw_ceiling_shadow(w, floor_y)


func _draw_floor(w: float, h: float, floor_y: float) -> void:
	var floor_rect := Rect2(0, floor_y, w, h - floor_y)
	match floor_style:
		"tile":
			Art.rect(self, 0, floor_y, w, h - floor_y, Color("#e6e2d6"))
			var ty := floor_y
			var row := 0
			while ty < h:
				var tx := 0.0
				var offset := 0.0 if row % 2 == 0 else TILE * 0.5
				while tx < w:
					Art.rect(self, tx + offset + 1, ty + 1, TILE - 2, TILE - 2,
						Color("#efeade") if (row + int(tx / TILE)) % 3 != 0 else Color("#e8e3d5"))
					Art.rect(self, tx + offset, ty, 1, TILE, Color("#c9c2b2"))
					tx += TILE
				Art.rect(self, 0, ty, w, 1, Color("#c9c2b2"))
				ty += TILE
				row += 1
		"stone":
			Art.rect(self, 0, floor_y, w, h - floor_y, Color("#b9b3a6"))
			var sy := floor_y
			var srow := 0
			while sy < h:
				var sx := 0.0
				var off: float = 0.0 if srow % 2 == 0 else float(TILE)
				while sx < w:
					var tone := Color("#c4beb1") if (srow + int(sx / TILE)) % 2 == 0 \
						else Color("#b3ada0")
					Art.rect(self, sx + off + 2, sy + 2, TILE - 4, TILE - 4, tone)
					Art.rect(self, sx + off + 2, sy + 2, TILE - 4, 1, tone.lightened(0.10))
					sx += TILE * 2
				sy += TILE
				srow += 1
		"straw":
			Art.rect(self, 0, floor_y, w, h - floor_y, Color("#c9ae72"))
			for index in int(w / 8):
				var px := fmod(float(index) * 37.0, w)
				var py := floor_y + fmod(float(index) * 53.0, h - floor_y)
				Art.rect(self, px, py, 4, 1, Color("#b89a5e"))
				Art.rect(self, px + 2, py + 6, 3, 1, Color("#d8c08a"))
		_:
			# 木地板：横向长板 + 错缝
			Art.rect(self, 0, floor_y, w, h - floor_y, Color("#cf9a5c"))
			var py := floor_y
			var prow := 0
			while py < h:
				var tone: Color = Color("#c28b4e") if prow % 2 == 0 else Color("#ca975a")
				Art.rect(self, 0, py, w, TILE * 0.5, tone)
				Art.rect(self, 0, py, w, 1, Color(0.42, 0.27, 0.14, 0.22))
				var jx: float = 0.0 if prow % 2 == 0 else float(TILE * 2)
				while jx < w:
					Art.rect(self, jx, py, 1, TILE * 0.5, Color(0.42, 0.27, 0.14, 0.14))
					jx += TILE * 4
				py += TILE * 0.5
				prow += 1
	# 地面在墙脚处的环境遮蔽（暖灰）
	Art.rect(self, 0, floor_y, w, 6, Color(0.35, 0.24, 0.14, 0.16))
	Art.rect(self, 0, floor_y + 6, w, 4, Color(0.35, 0.24, 0.14, 0.08))


func _draw_back_wall(w: float, floor_y: float) -> void:
	# 墙体正面：上深下浅的竖向渐变分档（不做平滑渐变）
	var bands := 6
	for index in bands:
		var t := float(index) / float(bands)
		var color := wall_color.lerp(wall_dark, t * 0.55)
		Art.rect(self, 0, float(index) * floor_y / float(bands),
			w, floor_y / float(bands) + 1.0, color)
	# 竖向木板拼缝
	var sx := 0.0
	while sx < w:
		Art.rect(self, sx, 0, 1, floor_y, Color(0.42, 0.30, 0.18, 0.10))
		sx += TILE
	# 顶部装饰线（檐口）与底部墙裙
	Art.rect(self, 0, 0, w, 4, wall_dark.darkened(0.18))
	Art.rect(self, 0, 4, w, 2, wall_color.lightened(0.06))
	Art.rect(self, 0, floor_y - TILE * 0.55, w, TILE * 0.55, wall_dark)
	Art.rect(self, 0, floor_y - TILE * 0.55, w, 2, wall_dark.lightened(0.10))
	# 窗（两扇），透出冷暖光
	for offset: float in [w * 0.22, w * 0.72]:
		var wx := offset - TILE * 0.85
		var wy := TILE * 0.85
		Art.rect(self, wx - 2, wy - 2, TILE * 1.7 + 4, TILE * 1.25 + 4,
			wall_dark.darkened(0.15))
		Art.rect(self, wx, wy, TILE * 1.7, TILE * 1.25, Color("#b9d2dc"))
		Art.rect(self, wx, wy, TILE * 1.7, TILE * 0.55, Color("#cfe2e8"))
		Art.rect(self, wx + TILE * 0.82, wy, 2, TILE * 1.25, wall_dark)
		Art.rect(self, wx, wy + TILE * 0.6, TILE * 1.7, 2, wall_dark)
		# 窗台
		Art.rect(self, wx - 3, wy + TILE * 1.25, TILE * 1.7 + 6, 3, wall_dark.darkened(0.10))
	# 挂画
	Art.rect(self, w * 0.5 - TILE * 0.55, TILE * 0.75, TILE * 1.1, TILE * 0.8,
		Color("#6f4328"))
	Art.rect(self, w * 0.5 - TILE * 0.45, TILE * 0.85, TILE * 0.9, TILE * 0.6,
		Color("#3f6070"))
	Art.rect(self, w * 0.5 - TILE * 0.45, TILE * 1.2, TILE * 0.9, TILE * 0.25,
		Color("#6f8f58"))


func _draw_side_walls(h: float, floor_y: float) -> void:
	# 侧墙：窄立面 + 冷色暗面，体现纵深
	for side in [0, 1]:
		var x := 0.0 if side == 0 else float(room_w) * TILE - SIDE_W * TILE
		var shade := wall_dark.darkened(0.06) if side == 0 else wall_dark.darkened(0.16)
		Art.rect(self, x, 0, SIDE_W * TILE, h, shade)
		Art.rect(self, x, 0, 2, h, shade.darkened(0.10))
		Art.rect(self, x, floor_y - 4, SIDE_W * TILE, 4, shade.lightened(0.08))


func _draw_wall_ao(w: float, h: float, floor_y: float) -> void:
	# 左右墙脚遮蔽
	Art.rect(self, SIDE_W * TILE, floor_y, 8, h - floor_y, Color(0.30, 0.22, 0.14, 0.10))
	Art.rect(self, w - SIDE_W * TILE - 8, floor_y, 8, h - floor_y,
		Color(0.30, 0.22, 0.14, 0.10))


func _draw_ceiling_shadow(w: float, floor_y: float) -> void:
	# 天花板阴影：顶部两档压暗
	Art.rect(self, 0, 0, w, 8, Color(0.16, 0.12, 0.10, 0.16))
	Art.rect(self, 0, 8, w, 6, Color(0.16, 0.12, 0.10, 0.08))
