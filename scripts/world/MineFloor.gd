class_name MineFloor
extends Node2D
## 矿洞单层（按《代码架构规范》第十一章与设计文档第十章）。
##
## 规则：
##   - 每层 40×30 tile，入口在顶部中间
##   - 用「当天种子 + 层号」生成，同一天同一层可复现
##   - 每层 30–60 块石头，越深矿石越好
##   - 楼梯随机位置，距入口至少 10 格
##   - 矿洞内时间静止，体力照常消耗
##
## 当前版本实现：石头 + 楼梯 + 矿石掉落。
## 怪物、陷阱、宝箱留在后续版本。

const DB := preload("res://scripts/core/ConfigDB.gd")
const Art := preload("res://scripts/art/PixelArt.gd")

const TILE := 32
const FLOOR_W := 40
const FLOOR_H := 30
const SPAWN_TILE := Vector2i(20, 3)

signal stairs_found
signal stone_broken(drops: Array)

# 矿石表：按层数决定权重
const ORES := [
	{"id": "stone", "name": "石头", "color": "#a3a39c", "min_floor": 1, "price": 2},
	{"id": "copper", "name": "铜矿石", "color": "#d98b4a", "min_floor": 1, "price": 15},
	{"id": "iron", "name": "铁矿石", "color": "#7d8a99", "min_floor": 11, "price": 40},
	{"id": "gold", "name": "金矿石", "color": "#e8c24a", "min_floor": 26, "price": 80},
	{"id": "mythril", "name": "秘银矿石", "color": "#7fb8c8", "min_floor": 41, "price": 150},
	{"id": "iridium", "name": "铱矿石", "color": "#5f4a6e", "min_floor": 61, "price": 300},
	{"id": "amethyst", "name": "紫水晶", "color": "#a07ac4", "min_floor": 11, "price": 80},
	{"id": "emerald", "name": "翡翠", "color": "#4fa06a", "min_floor": 41, "price": 200},
	{"id": "ruby", "name": "红宝石", "color": "#c94a5a", "min_floor": 41, "price": 250},
	{"id": "diamond", "name": "钻石", "color": "#d8ecf0", "min_floor": 81, "price": 500},
]

var floor_num := 1
var floor_seed := 0
var rocks: Array = []
var stairs_pos := Vector2i.ZERO
var spawn_position := Vector2.ZERO

var _rock_layer: Node2D
var _stairs: Node2D


func generate(p_floor_num: int, p_seed: int) -> void:
	floor_num = maxi(1, p_floor_num)
	floor_seed = p_seed
	for child in get_children():
		child.queue_free()
	rocks.clear()

	var rng := RandomNumberGenerator.new()
	# 同一天同一层用同一种子，可复现
	rng.seed = p_seed + floor_num * 7919

	spawn_position = Vector2(SPAWN_TILE) * TILE + Vector2(TILE * 0.5, TILE * 0.5)

	_rock_layer = Node2D.new()
	_rock_layer.name = "Rocks"
	_rock_layer.y_sort_enabled = true
	add_child(_rock_layer)

	# 石头数量随层数增加
	var rock_count := 30 + int(float(floor_num) / 100.0 * 30.0)
	rock_count = clampi(rock_count, 30, 60)

	var occupied: Dictionary = {}
	occupied[SPAWN_TILE] = true

	# 楼梯：距入口至少 10 格
	while true:
		var candidate := Vector2i(
			rng.randi_range(2, FLOOR_W - 3),
			rng.randi_range(4, FLOOR_H - 3)
		)
		if Vector2(candidate - SPAWN_TILE).length() >= 10.0:
			stairs_pos = candidate
			occupied[candidate] = true
			break

	for index in rock_count:
		var cell := Vector2i(
			rng.randi_range(1, FLOOR_W - 2),
			rng.randi_range(1, FLOOR_H - 2)
		)
		if occupied.has(cell):
			continue
		# 入口附近 2 格内不放石头
		if Vector2(cell - SPAWN_TILE).length() < 2.5:
			continue
		occupied[cell] = true
		_create_rock(cell, rng)

	_create_stairs()
	queue_redraw()


func _create_rock(cell: Vector2i, rng: RandomNumberGenerator) -> void:
	var rock := MineRock.new()
	rock.mine = self
	rock.cell = cell
	rock.ore = _pick_ore(rng)
	rock.position = Vector2(cell) * TILE + Vector2(TILE * 0.5, TILE)
	# 深层矿石更硬：1 / 2 / 3 击，配合三段裂纹
	var max_hits := 1
	if floor_num > 60:
		max_hits = 3
	elif floor_num > 30:
		max_hits = 2
	rock.max_hp = max_hits
	rock.hp = max_hits
	_rock_layer.add_child(rock)
	rocks.append(rock)


func _pick_ore(rng: RandomNumberGenerator) -> Dictionary:
	# 先筛出当前层可出的矿，再按深度加权
	var available: Array = []
	for ore: Dictionary in ORES:
		if int(ore.get("min_floor", 1)) <= floor_num:
			available.append(ore)
	if available.is_empty():
		return ORES[0]

	# 越深的矿权重越高（深度系数）
	var weights: Array = []
	var total := 0.0
	for ore: Dictionary in available:
		var min_floor := int(ore.get("min_floor", 1))
		var depth_bonus := 1.0 + float(floor_num - min_floor) * 0.02
		# 贵重矿在浅层权重更低
		var value := float(ore.get("price", 2))
		var weight := depth_bonus / maxf(1.0, value / 30.0)
		weights.append(weight)
		total += weight

	var pick := rng.randf() * total
	for index in available.size():
		pick -= float(weights[index])
		if pick <= 0.0:
			return available[index]
	return available[0]


func _create_stairs() -> void:
	_stairs = MineStairs.new()
	_stairs.mine = self
	_stairs.position = Vector2(stairs_pos) * TILE + Vector2(TILE * 0.5, TILE)
	add_child(_stairs)


## 玩家敲碎石头。
func break_rock(rock: MineRock) -> Array:
	var drops: Array = []
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	var ore: Dictionary = rock.ore
	var amount := 1
	if ore.get("id", "") == "stone":
		amount = rng.randi_range(1, 3)

	drops.append({
		"item_id": str(ore.get("id", "stone")),
		"name": str(ore.get("name", "石头")),
		"category": "mineral",
		"count": amount,
		"price": int(ore.get("price", 2)),
	})

	# 古物：按当前层数筛选可出的条目，再按各自概率判定
	var candidates: Array = []
	for artifact: Dictionary in DB.get_all_artifacts():
		if floor_num >= int(artifact.get("min_floor", 1)) \
				and floor_num <= int(artifact.get("max_floor", 100)):
			candidates.append(artifact)
	if not candidates.is_empty():
		var artifact: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
		if rng.randf() < float(artifact.get("chance", 0.03)):
			drops.append({
				"item_id": str(artifact.get("id", "")),
				"name": str(artifact.get("name", "")),
				"category": "artifact",
				"count": 1,
				"price": int(artifact.get("price", 0)),
			})

	rocks.erase(rock)
	rock.queue_free()
	stone_broken.emit(drops)
	queue_redraw()
	return drops


func get_stairs_cell() -> Vector2i:
	return stairs_pos


# ============================================================
# 绘制：矿洞地面
# ============================================================

func _draw() -> void:
	var w := FLOOR_W * TILE
	var h := FLOOR_H * TILE

	# 矿洞地面：偏冷的深灰蓝，带碎点
	for y in FLOOR_H:
		for x in FLOOR_W:
			var base := Color("#a8a296") if (x + y) % 2 == 0 else Color("#a09a8e")
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), base, true)
			for index in 2:
				var rx := x * TILE + int(fmod(float(x * 37 + y * 17 + index * 13), 28.0))
				var ry := y * TILE + int(fmod(float(x * 11 + y * 29 + index * 7), 28.0))
				draw_rect(Rect2(rx, ry, 2, 2), Color(0.52, 0.49, 0.45, 0.35), true)

	# 四周岩壁
	draw_rect(Rect2(0, 0, w, TILE), Color("#6b655c"), true)
	draw_rect(Rect2(0, h - TILE, w, TILE), Color("#6b655c"), true)
	draw_rect(Rect2(0, 0, TILE, h), Color("#6b655c"), true)
	draw_rect(Rect2(w - TILE, 0, TILE, h), Color("#6b655c"), true)

	# 返回入口：向上的矿洞梯井 + 天光（出生点，靠近按 E 返回农场）
	# 注意：Art 系列按 2px 单元绘制，世界坐标需先减半。
	var ex := float(SPAWN_TILE.x * TILE + TILE / 2) * 0.5
	var ey := float(SPAWN_TILE.y * TILE + int(float(TILE) * 0.95)) * 0.5
	# 天光光柱
	Art.poly(self, PackedVector2Array([
		Vector2(ex - 4, ey - 43), Vector2(ex + 4, ey - 43),
		Vector2(ex + 7, ey), Vector2(ex - 7, ey),
	]), Color(0.98, 0.93, 0.68, 0.10))
	# 竖井：一直通到顶部岩壁
	Art.rect(self, ex - 4, ey - 43, 8, 43, Color("#5a554d"))
	Art.rect(self, ex - 3, ey - 42, 6, 42, Color("#403b35"))
	# 井口
	Art.ellipse(self, ex, ey, 6.5, 2.2, Color("#8d8577"))
	Art.ellipse(self, ex, ey - 0.5, 5.0, 1.8, Color("#4a443b"))
	Art.ellipse(self, ex, ey - 0.8, 4.0, 1.4, Color("#2c2925"))
	# 木梯：双轨 + 横档
	Art.rect(self, ex - 3.5, ey - 41, 1, 40, Color("#8a5a3f"))
	Art.rect(self, ex + 2.5, ey - 41, 1, 40, Color("#8a5a3f"))
	for rung in 10:
		Art.rect(self, ex - 3.5, ey - 40.0 + float(rung) * 4.0, 7, 0.75, Color("#a9713f"))
	# 井口顶部亮光
	Art.rect(self, ex - 2.5, ey - 43, 5, 1.5, Color(0.98, 0.94, 0.72, 0.55))

	# 层数提示
	var font := PixelTheme.font()
	draw_string(font, Vector2(12, 22), "矿洞 第 %d 层" % floor_num,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("#e8dfc8"))


# ============================================================
# 石头 / 楼梯节点
# ============================================================

class MineRock:
	extends Node2D

	var mine: MineFloor
	var cell := Vector2i.ZERO
	var ore: Dictionary = {}
	var hp := 1
	var max_hp := 1
	var _shake := 0.0


	func _draw() -> void:
		var color: Color = ore.get("color", "#a9a49a")
		var px := roundf(sin(_shake * 40.0) * 2.0)

		Art.shadow(self, 0, 0, 9.0, 2.8)
		# 石块：多边形，不用圆；冷灰阴影 + 暖米色受光面
		Art.poly(self, PackedVector2Array([
			Vector2(px - 8, 0), Vector2(px - 8, -7), Vector2(px - 3, -11),
			Vector2(px + 5, -10), Vector2(px + 9, -5), Vector2(px + 8, 0),
		]), Art.ROCK)
		Art.poly(self, PackedVector2Array([
			Vector2(px - 6, -6), Vector2(px - 2, -9), Vector2(px + 3, -8), Vector2(px - 1, -4),
		]), Art.ROCK_LIGHT)
		Art.poly(self, PackedVector2Array([
			Vector2(px + 1, -6), Vector2(px + 7, -4), Vector2(px + 6, -1), Vector2(px, -2),
		]), Art.shade_cool(Art.ROCK, 0.30))

		# 矿脉：按矿石颜色点几颗（亮面 + 暗边，靠色阶不发光）
		var vein: Color = color
		var vein_light := Art.tint_warm(vein, 0.30)
		var vein_dark := Art.shade_cool(vein, 0.45)
		Art.rect(self, px - 4, -6, 2, 2, vein)
		Art.rect(self, px - 4.5, -6.5, 1, 1, vein_light)
		Art.rect(self, px - 4.5, -4.5, 1, 1, vein_dark)
		Art.rect(self, px + 2, -7, 2, 2, vein)
		Art.rect(self, px + 2.5, -7.5, 1, 1, vein_light)
		Art.rect(self, px - 1, -3, 2, 2, vein)
		Art.rect(self, px - 0.5, -3.5, 1, 1, vein_light)
		# 三段裂纹：随敲击次数增加
		var damage := maxi(0, max_hp - hp)
		var crack := Color(0.25, 0.24, 0.22, 0.55)
		if damage >= 1:
			Art.rect(self, px + 3, -6, 1, 3, crack)
		if damage >= 2:
			Art.rect(self, px - 3, -8, 1, 2, crack)
			Art.rect(self, px - 2, -6, 1, 2, crack)
			Art.rect(self, px + 1, -4, 3, 1, crack)
		if damage >= 3:
			Art.rect(self, px - 5, -4, 2, 1, crack)


	func hit() -> bool:
		hp -= 1
		_shake = 1.0
		var tween := create_tween()
		tween.tween_property(self, "_shake", 0.0, 0.2)
		queue_redraw()
		return hp <= 0


class MineStairs:
	extends Node2D

	var mine: MineFloor
	var _t := 0.0


	func _ready() -> void:
		set_process(true)


	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()


	func _draw() -> void:
		Art.shadow(self, 0, 0, 10.0, 3.0)
		# 向下的洞口 + 台阶
		Art.ellipse(self, 0, -5.0, 9.0, 7.0, Color("#2f2c28"))
		Art.ellipse(self, 0, -6.0, 7.0, 5.0, Color("#1d1b18"))
		Art.rect(self, -6.0, -9.0, 12.0, 1.5, Color("#5a554d"))
		Art.rect(self, -4.5, -6.5, 9.0, 1.5, Color("#4a463f"))
		Art.rect(self, -3.0, -4.0, 6.0, 1.5, Color("#3a3732"))
		# 提示微光：每 1.4 秒闪 3 次（规范：楼梯闪 3 次）
		var cycle := fmod(_t, 2.4)
		var blink := 0.0
		if cycle < 1.4:
			blink = 1.0 if int(cycle * 6.0) % 2 == 0 else 0.15
		Art.rect(self, -1.0, -12.0, 2.0, 2.0, Color(0.92, 0.86, 0.66, blink))
