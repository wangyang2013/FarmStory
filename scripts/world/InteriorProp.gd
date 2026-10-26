class_name InteriorProp
extends Node2D
## 室内家具：作为 Farm 的直接子节点参与 Y-sort（按脚底位置排序）。
## 全部按 3/4 Top-Down 绘制：顶面受光 + 正面背光 + 贴地软阴影，避免平面色块。

const Art := preload("res://scripts/art/PixelArt.gd")

var kind := "crate"
## 横向跨度（格）：0 表示按各家具默认宽度绘制
var span := 0.0


func setup(p_kind: String, world_position: Vector2, p_span := 0.0) -> void:
	kind = p_kind
	position = world_position
	span = maxf(0.0, p_span)
	queue_redraw()


## 横向宽度（Art 单位，1 格 = 16 单位）；span 为 0 时用默认值。
func _width(default_units: float) -> float:
	if span <= 0.0:
		return default_units
	return span * 16.0


func _draw() -> void:
	match kind:
		"counter", "desk":
			_draw_counter(kind == "desk")
		"shelf":
			_draw_shelf()
		"bookshelf":
			_draw_bookshelf()
		"crate":
			_draw_crate()
		"plant":
			_draw_plant()
		"clinic_bed", "bed":
			_draw_bed()
		"cabinet":
			_draw_cabinet()
		"pedestal":
			_draw_pedestal()
		"display_case":
			_draw_display_case()
		"nest_box":
			_draw_nest_box()
		"feed_trough":
			_draw_feed_trough()
		"incubator":
			_draw_incubator()
		"straw_pile", "hay_pile":
			_draw_straw(kind == "hay_pile")
		"milking_station":
			_draw_milking_station()
		"tool_rack":
			_draw_tool_rack()
		"bucket":
			_draw_bucket()
		"rug":
			_draw_rug()
		"table":
			_draw_table()
		"chair":
			_draw_chair()
		"fishtank":
			_draw_fishtank()
		"gramophone":
			_draw_gramophone()
		"calendar":
			_draw_calendar()
		_:
			_draw_crate()


## 柜台 / 书桌：顶面亮、正面暗、底部踢脚线，带木纹与抽屉。
func _draw_counter(is_desk: bool) -> void:
	var w := _width(16.0 if is_desk else 22.0)
	var h := 7.0
	Art.shadow(self, 0, -0.4, w * 0.55, 2.2)
	# 正面（背光）
	Art.rect(self, -w * 0.5, -h, w, h, Art.WOOD_DARK)
	Art.rect(self, -w * 0.5, -h, w, 1.0, Art.WOOD)
	# 顶面（受光，略向内缩，形成厚度）
	Art.rect(self, -w * 0.5 + 0.5, -h - 1.6, w - 1.0, 1.8, Art.WOOD_LIGHT)
	Art.rect(self, -w * 0.5 + 0.5, -h - 1.6, w - 1.0, 0.6, Color(0.93, 0.86, 0.70))
	# 抽屉 / 抽屉把手
	var draws := 2 if is_desk else 3
	for index in draws:
		var dx := -w * 0.5 + 2.0 + float(index) * (w - 4.0) / float(draws)
		Art.rect(self, dx, -h + 1.4, (w - 4.0) / float(draws) - 1.2, 1.0,
			Art.WOOD_DARK.darkened(0.10))
		Art.rect(self, dx + 1.2, -h + 2.8, 0.8, 0.8, Color("#e3c98c"))
	# 台面上的小物
	if not is_desk:
		Art.rect(self, -w * 0.5 + 2.0, -h - 3.6, 2.0, 2.0, Color("#eee3c8"))
		Art.rect(self, w * 0.5 - 5.0, -h - 3.2, 2.4, 1.6, Color("#b5735f"))


func _draw_shelf() -> void:
	var w := _width(20.0)
	var h := 11.0
	Art.shadow(self, 0, -0.4, w * 0.55, 2.0)
	Art.rect(self, -w * 0.5, -h, w, h, Art.WOOD_DARK)
	Art.rect(self, -w * 0.5 + 1.0, -h + 1.0, w - 2.0, h - 2.0, Color("#6f5438"))
	for row in 3:
		var y := -h + 2.0 + float(row) * 3.0
		Art.rect(self, -w * 0.5 + 1.0, y, w - 2.0, 1.4, Art.WOOD_LIGHT)
		var colors := [Color("#b5735f"), Color("#5fae7a"), Color("#e8b45a"),
			Color("#7a8fc9"), Color("#c47b9c")]
		# 书本按货架宽度铺满
		var cols := maxi(2, int((w - 2.0) / 2.2))
		for col in cols:
			var x := -w * 0.5 + 1.6 + float(col) * (w - 3.2) / float(cols)
			Art.rect(self, x, y - 2.2, 1.4, 2.2, colors[(row + col) % colors.size()])
	Art.rect(self, -w * 0.5, -h, w, 0.8, Art.WOOD_LIGHT)


func _draw_bookshelf() -> void:
	var w := _width(16.0)
	var h := 13.0
	Art.shadow(self, 0, -0.4, w * 0.55, 2.2)
	Art.rect(self, -w * 0.5, -h, w, h, Color("#8c6a4a"))
	for row in 4:
		var y := -h + 1.4 + float(row) * 3.0
		Art.rect(self, -w * 0.5 + 0.8, y, w - 1.6, 2.4, Color("#b89268"))
		var colors := [Color("#b5735f"), Color("#5fae7a"), Color("#7a8fc9"), Color("#e8b45a")]
		var cols := maxi(2, int((w - 3.0) / 2.0))
		for col in cols:
			var bx := -w * 0.5 + 1.4 + float(col) * (w - 3.0) / float(cols)
			Art.rect(self, bx, y - 0.6, 1.2, 1.8, colors[(row + col) % colors.size()])
	Art.rect(self, -w * 0.5, -h, w, 0.8, Color("#a9825c"))


func _draw_crate() -> void:
	Art.shadow(self, 0, -0.4, 5.5, 1.8)
	Art.rect(self, -4.0, -6.4, 8.0, 6.4, Art.WOOD_DARK)
	Art.rect(self, -3.4, -7.4, 7.4, 1.6, Art.WOOD_LIGHT)
	Art.rect(self, -3.4, -7.4, 7.4, 0.5, Color(0.94, 0.88, 0.72))
	Art.rect(self, -4.0, -3.4, 8.0, 0.8, Art.WOOD)
	Art.rect(self, -4.0, -1.4, 8.0, 0.8, Art.WOOD)


func _draw_plant() -> void:
	Art.shadow(self, 0, -0.3, 4.0, 1.4)
	# 花盆（上宽下窄）
	Art.poly(self, PackedVector2Array([
		Vector2(-3.4, -3.6), Vector2(3.4, -3.6), Vector2(2.6, 0), Vector2(-2.6, 0),
	]), Color("#a9713f"))
	Art.rect(self, -3.4, -4.4, 6.8, 1.0, Color("#bd8752"))
	Art.rect(self, -3.4, -4.4, 6.8, 0.4, Color("#cf9a63"))
	# 叶片（多层，受光偏上）
	Art.ellipse(self, 0, -6.4, 4.2, 2.6, Color("#5f8a52"))
	Art.ellipse(self, -1.4, -7.4, 3.0, 2.0, Color("#7e9971"))
	Art.ellipse(self, 1.4, -8.2, 2.4, 1.6, Color("#93b083"))
	Art.rect(self, -0.4, -8.8, 0.8, 2.2, Color("#6f8f58"))


func _draw_bed() -> void:
	Art.shadow(self, 0, -0.4, 7.5, 2.2)
	# 床架
	Art.rect(self, -7.0, -5.0, 14.0, 5.0, Color("#7d4f30"))
	# 床垫顶面
	Art.rect(self, -6.2, -6.6, 12.4, 2.2, Color("#f2e8d4"))
	Art.rect(self, -6.2, -6.6, 12.4, 0.6, Color("#fbf6ea"))
	# 被子
	Art.rect(self, -6.2, -4.6, 12.4, 2.2, Color("#b5534f"))
	Art.rect(self, -6.2, -4.6, 12.4, 0.6, Color("#c96b5c"))
	# 枕头
	Art.rect(self, -5.4, -7.4, 4.0, 1.8, Color("#f7f0dd"))
	Art.rect(self, -5.4, -7.4, 4.0, 0.5, Color.WHITE if false else Color("#fdf8ef"))
	# 床头板
	Art.rect(self, -7.4, -8.6, 1.6, 8.6, Color("#6f4328"))


func _draw_cabinet() -> void:
	Art.shadow(self, 0, -0.4, 5.0, 1.8)
	Art.rect(self, -4.4, -10.0, 8.8, 10.0, Color("#d9d6cd"))
	Art.rect(self, -4.4, -10.0, 8.8, 0.8, Color("#e9e6dd"))
	for row in 3:
		var y := -9.0 + float(row) * 3.0
		Art.rect(self, -3.8, y, 7.6, 2.2, Color("#c9c6bd"))
		Art.rect(self, -0.8, y + 0.8, 1.6, 0.5, Color("#8d8b86"))


func _draw_pedestal() -> void:
	Art.shadow(self, 0, -0.4, 5.0, 2.0)
	# 石座：上下两段 + 受光顶面
	Art.rect(self, -4.0, -2.0, 8.0, 2.0, Color("#8f959c"))
	Art.rect(self, -3.2, -7.0, 6.4, 5.0, Color("#b3b8bd"))
	Art.rect(self, -3.2, -7.4, 6.4, 1.2, Color("#d3d8dd"))
	Art.rect(self, -2.4, -9.6, 4.8, 2.4, Color("#c4c9cc"))
	# 展品：金色古物
	Art.rect(self, -1.6, -12.2, 3.2, 2.6, Color("#c9a46a"))
	Art.rect(self, -1.6, -12.2, 3.2, 0.8, Color("#e8c98a"))
	Art.rect(self, -0.6, -11.4, 1.2, 1.2, Color("#8c6a4a"))


func _draw_display_case() -> void:
	Art.shadow(self, 0, -0.4, 9.0, 2.2)
	# 木底座
	var cw := _width(18.0)
	Art.rect(self, -cw * 0.5, -4.0, cw, 4.0, Color("#8c6a4a"))
	Art.rect(self, -cw * 0.5, -4.0, cw, 0.8, Color("#a9825c"))
	# 玻璃罩（半透明）
	var gw := _width(16.8)
	Art.rect(self, -gw * 0.5, -11.0, gw, 7.0, Color(0.72, 0.85, 0.90, 0.30))
	Art.rect(self, -gw * 0.5, -11.0, gw, 1.0, Color(0.80, 0.90, 0.94, 0.55))
	Art.rect(self, -gw * 0.5, -11.0, 1.0, 7.0, Color(0.80, 0.90, 0.94, 0.45))
	# 内部矿石
	Art.rect(self, -3.0, -7.0, 3.0, 3.0, Color("#7fb3b0"))
	Art.rect(self, 1.0, -8.0, 2.6, 4.0, Color("#c9a46a"))


func _draw_nest_box() -> void:
	Art.shadow(self, 0, -0.4, 10.0, 2.4)
	var nw := _width(20.0)
	Art.rect(self, -nw * 0.5, -5.0, nw, 5.0, Art.WOOD_DARK)
	Art.rect(self, -nw * 0.5, -5.0, nw, 0.8, Art.WOOD_LIGHT)
	# 三个巢位（干草 + 蛋）
	for index in 3:
		var x := -6.6 + float(index) * 6.6
		Art.ellipse(self, x, -4.0, 2.6, 1.4, Color("#d8c08a"))
		Art.ellipse(self, x, -4.6, 1.7, 1.0, Color("#f2e9d6"))
		Art.ellipse(self, x - 0.4, -5.0, 0.7, 0.4, Color("#fdf8ef"))


func _draw_feed_trough() -> void:
	Art.shadow(self, 0, -0.4, 9.0, 2.0)
	# 食槽：木质外框 + 内凹
	var tw := _width(18.0)
	Art.rect(self, -tw * 0.5, -3.6, tw, 3.6, Art.WOOD_DARK)
	Art.rect(self, -tw * 0.5 + 0.8, -4.6, tw - 1.6, 1.4, Art.WOOD_LIGHT)
	Art.rect(self, -tw * 0.5 + 1.6, -3.8, tw - 3.2, 2.2, Color("#8a6f55"))
	# 饲料
	Art.rect(self, -6.6, -3.6, 12.8, 1.2, Color("#d8c294"))
	Art.rect(self, -5.0, -4.0, 3.0, 0.8, Color("#e3d0a4"))


func _draw_incubator() -> void:
	Art.shadow(self, 0, -0.4, 6.0, 2.0)
	Art.rect(self, -5.4, -9.0, 10.8, 9.0, Color("#c9a273"))
	Art.rect(self, -5.4, -9.0, 10.8, 0.8, Color("#dbb98a"))
	# 玻璃窗 + 鸡蛋
	Art.rect(self, -4.0, -7.6, 8.0, 4.0, Color(0.72, 0.85, 0.90, 0.42))
	Art.ellipse(self, -1.4, -4.4, 1.2, 1.5, Color("#f2e9d6"))
	Art.ellipse(self, 1.4, -4.4, 1.2, 1.5, Color("#f2e9d6"))
	# 指示灯
	Art.rect(self, 3.4, -8.2, 1.2, 1.2, Color("#e8b45a"))
	Art.rect(self, -5.4, -0.4, 10.8, 0.8, Color("#8c6a4a"))


func _draw_straw(big: bool) -> void:
	var w := _width(12.0 if big else 8.0)
	var h := 5.0 if big else 3.4
	Art.shadow(self, 0, -0.3, w * 0.55, 1.8)
	Art.ellipse(self, 0, -h * 0.5, w * 0.5, h * 0.7, Color("#c9ae72"))
	Art.ellipse(self, -w * 0.15, -h * 0.8, w * 0.34, h * 0.5, Color("#d8c08a"))
	for index in 5:
		var x := -w * 0.4 + float(index) * (w * 0.8) / 4.0
		Art.rect(self, x, -h * 0.9, 2.4, 0.6, Color("#b89a5e"))


func _draw_milking_station() -> void:
	Art.shadow(self, 0, -0.4, 6.0, 2.0)
	# 矮凳
	Art.rect(self, -5.0, -3.4, 5.0, 1.2, Art.WOOD_LIGHT)
	Art.rect(self, -4.6, -3.4, 1.0, 3.4, Art.WOOD_DARK)
	Art.rect(self, -1.4, -3.4, 1.0, 3.4, Art.WOOD_DARK)
	# 奶桶
	Art.rect(self, 1.0, -5.0, 4.0, 5.0, Color("#9fb4c0"))
	Art.ellipse(self, 3.0, -5.2, 2.0, 0.8, Color("#c9d6dc"))
	Art.rect(self, 1.0, -5.0, 4.0, 0.8, Color("#b8cbd4"))


func _draw_tool_rack() -> void:
	Art.shadow(self, 0, -0.4, 6.0, 1.8)
	Art.rect(self, -5.4, -10.0, 10.8, 1.2, Art.WOOD_DARK)
	Art.rect(self, -5.4, -10.0, 10.8, 0.4, Art.WOOD_LIGHT)
	# 挂着的工具（锄 / 锤 / 镰）
	Art.rect(self, -3.6, -9.0, 0.9, 7.0, Art.WOOD)
	Art.rect(self, -4.6, -2.4, 2.8, 1.2, Color("#b9c1c4"))
	Art.rect(self, -0.4, -9.0, 0.9, 5.6, Art.WOOD)
	Art.rect(self, -1.6, -10.2, 3.0, 1.6, Color("#8f959c"))
	Art.rect(self, 3.0, -9.0, 0.9, 6.0, Art.WOOD)
	draw_arc(Vector2(3.6, -4.0), 1.8, -0.6, 1.8, 6, Color("#b9c1c4"), 1.0)


func _draw_bucket() -> void:
	Art.shadow(self, 0, -0.3, 3.4, 1.2)
	Art.rect(self, -3.0, -4.4, 6.0, 4.4, Color("#8a6a4a"))
	Art.rect(self, -3.0, -4.4, 6.0, 0.8, Color("#a9825c"))
	Art.rect(self, -2.2, -3.2, 4.4, 1.4, Color("#6fa3ad"))
	Art.rect(self, -3.0, -2.0, 6.0, 0.6, Color("#6f5438"))

func _draw_rug() -> void:
	var w := _width(16.0)
	var h := w
	# 地毯平铺在地上：两层色阶 + 流苏
	Art.rect(self, -w * 0.5, -h + 2.0, w, h - 2.0, Color("#7f9463"))
	Art.rect(self, -w * 0.5 + 2.0, -h + 4.0, w - 4.0, h - 6.0, Color("#93a875"))
	for index in int(w / 4.0):
		var fx := -w * 0.5 + 2.0 + float(index) * 4.0
		Art.rect(self, fx, -h + 1.0, 1.5, 2.0, Color("#d8c39a"))
		Art.rect(self, fx, 0.0, 1.5, 2.0, Color("#d8c39a"))


func _draw_table() -> void:
	var w := _width(16.0)
	Art.shadow(self, 0, -0.4, w * 0.55, 2.0)
	# 桌面（受光） + 桌腿（背光）
	Art.rect(self, -w * 0.5, -7.0, w, 2.4, Color("#c9a276"))
	Art.rect(self, -w * 0.5, -7.0, w, 0.8, Color("#ddbd93"))
	Art.rect(self, -w * 0.5 + 1.0, -4.8, 2.0, 4.8, Color("#7d5a3c"))
	Art.rect(self, w * 0.5 - 3.0, -4.8, 2.0, 4.8, Color("#7d5a3c"))


func _draw_chair() -> void:
	Art.shadow(self, 0, -0.3, 4.0, 1.4)
	# 椅背 + 坐面 + 椅腿
	Art.rect(self, -3.6, -10.0, 7.2, 5.0, Color("#a97e52"))
	Art.rect(self, -2.8, -9.2, 5.6, 3.6, Color("#c9a276"))
	Art.rect(self, -3.6, -5.6, 7.2, 2.0, Color("#b89268"))
	Art.rect(self, -3.2, -3.6, 1.4, 3.6, Color("#7d5a3c"))
	Art.rect(self, 1.8, -3.6, 1.4, 3.6, Color("#7d5a3c"))


func _draw_fishtank() -> void:
	var w := _width(22.0)
	Art.shadow(self, 0, -0.4, w * 0.55, 2.0)
	# 木底座
	Art.rect(self, -w * 0.5, -4.0, w, 4.0, Color("#8c6a4a"))
	Art.rect(self, -w * 0.5, -4.0, w, 0.8, Color("#a9825c"))
	# 玻璃水体 + 水面高光
	Art.rect(self, -w * 0.5 + 1.0, -13.0, w - 2.0, 9.0, Color("#6fa3ad"))
	Art.rect(self, -w * 0.5 + 1.0, -13.0, w - 2.0, 1.4, Color("#8fc6d4"))
	# 小鱼（随时间游动）
	var swim := sin(Time.get_ticks_msec() * 0.0016) * (w * 0.25)
	Art.rect(self, swim - 2.0, -10.0, 4.0, 2.0, Color("#d9a05e"))
	Art.rect(self, swim + 2.0, -9.4, 1.6, 1.2, Color("#c07a4a"))
	# 底砂
	Art.rect(self, -w * 0.5 + 1.0, -5.4, w - 2.0, 1.4, Color("#d8c08a"))


func _draw_gramophone() -> void:
	Art.shadow(self, 0, -0.3, 5.0, 1.6)
	# 木箱（顶面 + 正面）
	Art.rect(self, -4.6, -6.0, 9.2, 6.0, Color("#8c6a4a"))
	Art.rect(self, -4.6, -6.0, 9.2, 1.2, Color("#a9825c"))
	# 唱片盘
	Art.ellipse(self, 0, -7.0, 3.2, 1.4, Color("#3f3a36"))
	Art.ellipse(self, 0, -7.2, 1.4, 0.7, Color("#d8bd84"))
	# 喇叭
	Art.ellipse(self, 3.0, -13.0, 3.4, 3.8, Color("#d8bd84"))
	Art.ellipse(self, 3.0, -13.2, 2.2, 2.6, Color("#e9d3a4"))
	Art.rect(self, 2.4, -9.6, 1.2, 3.0, Color("#a9825c"))


func _draw_calendar() -> void:
	Art.shadow(self, 0, -0.2, 3.0, 1.0)
	# 立在桌上的小日历：顶面 + 正面
	Art.rect(self, -3.6, -8.0, 7.2, 8.0, Color("#eee3c8"))
	Art.rect(self, -3.6, -8.0, 7.2, 1.8, Color("#c4553f"))
	Art.rect(self, -2.6, -5.0, 5.2, 0.8, Color("#8a7862"))
	Art.rect(self, -2.6, -3.4, 2.0, 0.8, Color("#8a7862"))
	Art.rect(self, 0.2, -3.4, 1.6, 0.8, Color("#8a7862"))
	Art.rect(self, -3.6, -0.6, 7.2, 0.6, Color("#c9b48e"))
