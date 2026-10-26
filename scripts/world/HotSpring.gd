class_name HotSpring
extends Node2D
## 露天温泉。
##
## 分层：
##   - 池体（石沿 + 水面）放在 z=-7 的地面层，永远不会盖住角色；
##   - 蒸汽单独一层 z=18，画在角色之上。
## 注意：Art.* 绘制函数以 2px 为一个单位，这里的坐标/半径都按「单位」写。

const Art := preload("res://scripts/art/PixelArt.gd")

## 池体（单位）：中心在 y=-18，横向半径 36、纵向 18 → 实际 144×72 px。
const POOL_CX := 0.0
const POOL_CY := -18.0
const POOL_RX := 36.0
const POOL_RY := 18.0

var _t := 0.0
var _steam: Node2D


func _ready() -> void:
	z_as_relative = false
	z_index = -7
	_steam = Node2D.new()
	_steam.name = "Steam"
	_steam.z_as_relative = false
	_steam.z_index = 18
	_steam.draw.connect(_draw_steam)
	add_child(_steam)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	if _steam != null:
		_steam.queue_redraw()


func _draw() -> void:
	# 池体投在地面的软阴影（偏左上报光，阴影右下）
	Art.ellipse(self, POOL_CX + 1.0, POOL_CY + 4.0, POOL_RX, POOL_RY, Color(0.24, 0.21, 0.34, 0.16))
	# 石沿：冷灰外圈 + 暖灰内圈
	Art.ellipse(self, POOL_CX, POOL_CY, POOL_RX, POOL_RY, Color("#7f8792"))
	Art.ellipse(self, POOL_CX - 0.5, POOL_CY - 1.0, POOL_RX - 3.0, POOL_RY - 2.0,
		Color("#a9a294"))
	# 水面：深 → 浅
	Art.ellipse(self, POOL_CX, POOL_CY - 1.0, POOL_RX - 6.0, POOL_RY - 4.0,
		Color("#5f97b0"))
	Art.ellipse(self, POOL_CX - 1.0, POOL_CY - 2.0, POOL_RX - 11.0, POOL_RY - 6.0,
		Color("#6fa3ad"))
	# 水面反光（三段，缓慢漂移）
	for index in 4:
		var x := -14.0 + float(index) * 9.0 + sin(_t * 0.8 + float(index)) * 2.0
		var y := POOL_CY - 4.0 + float(index % 2) * 5.0
		Art.rect(self, x, y, 6.0, 0.5, Color(0.86, 0.95, 0.93, 0.5))
	# 池沿石块（8 颗，绕椭圆均匀分布）
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var sx := POOL_CX + cos(angle) * (POOL_RX - 1.0)
		var sy := POOL_CY + sin(angle) * (POOL_RY - 0.5)
		Art.ellipse(self, sx, sy, 3.6, 2.4, Color("#8f959c"))
		Art.ellipse(self, sx - 0.5, sy - 0.8, 2.2, 1.3, Color("#b4b8b8"))
	# 池边苔藓
	Art.ellipse(self, POOL_CX - 30.0, POOL_CY + 10.0, 3.0, 1.6, Color("#6f8f58"))


## 蒸汽画在独立子节点上（z=18），保证在角色之上。
func _draw_steam() -> void:
	for index in 6:
		var rise := fmod(_t * 0.28 + float(index) * 0.17, 1.0)
		var sx := POOL_CX + sin(_t * 0.7 + float(index) * 1.9) * 16.0
		var sy := POOL_CY - 6.0 - rise * 24.0
		var alpha := (1.0 - rise) * 0.26
		Art.ellipse(_steam, sx, sy, 5.0 - rise * 1.8, 1.8,
			Color(0.94, 0.97, 0.96, alpha))
