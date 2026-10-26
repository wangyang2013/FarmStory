class_name WorldProp
extends Node2D
## 场景建筑 / 装饰（16px 柔和像素，无粗黑描边，预绘制软阴影）。
##
## 视角：3/4 Top-Down（四分之三俯视）。建筑与树木同时给出正面与顶面，
## 地面保持规整网格，不做菱形等轴测。
##
## 建筑阴影使用贴合底边的窄条；玩家走到建筑后方时自动半透明（FadeWhenBehind）。

const Art := preload("res://scripts/art/PixelArt.gd")
const BUILDING_KINDS := [
	"house", "shop", "coop", "barn", "museum", "library", "clinic",
	"stable", "ostrich_house", "bike_shed",
]

var kind := "tree"
var night := false
var season := "spring"
var has_mail := false
var trample_timer := 0.0
var is_night := false
var _phase := 0.0


func setup(p_kind: String, world_position: Vector2) -> void:
	kind = p_kind
	position = world_position
	# 每棵树随机相位，避免整体同步摆动
	_phase = randf() * TAU
	if kind in ["tree", "blossom_tree", "pine", "bush", "reeds", "lily", "house"]:
		set_process(true)
	if kind in BUILDING_KINDS:
		_build_fade_area()
	queue_redraw()


func set_night(value: bool) -> void:
	if night == value:
		return
	night = value
	queue_redraw()


## 玩家走过草丛：触发 0.3 秒抖动（规范：草丛走过 0.3 秒抖动）。
func trample() -> void:
	trample_timer = 0.3
	queue_redraw()


func set_season(value: String) -> void:
	if season == value:
		return
	season = value
	queue_redraw()


func set_mail(value: bool) -> void:
	if has_mail == value:
		return
	has_mail = value
	queue_redraw()


func _build_fade_area() -> void:
	if get_node_or_null("FadeWhenBehind") != null:
		return
	var area := Area2D.new()
	area.name = "FadeWhenBehind"
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	var areas := {
		"house": Rect2(-48, -144, 96, 114),
		"shop": Rect2(-40, -64, 80, 38),
		"coop": Rect2(-48, -48, 96, 22),
		"barn": Rect2(-56, -64, 112, 36),
		"museum": Rect2(-112, -152, 224, 152),
		"library": Rect2(-64, -96, 128, 96),
		"clinic": Rect2(-64, -92, 128, 92),
		"stable": Rect2(-62, -58, 124, 34),
		"ostrich_house": Rect2(-62, -58, 124, 34),
		"bike_shed": Rect2(-44, -40, 88, 22),
	}
	var area_rect: Rect2 = areas.get(kind, Rect2(-20, -40, 40, 24))
	rect.size = area_rect.size
	shape.shape = rect
	shape.position = area_rect.position + area_rect.size * 0.5
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(_on_fade_body_entered)
	area.body_exited.connect(_on_fade_body_exited)


func _on_fade_body_entered(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		_fade_to(0.5)


func _on_fade_body_exited(body: Node) -> void:
	if body != null and body.is_in_group("player"):
		_fade_to(1.0)


func _fade_to(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", alpha, 0.18)


## 建筑底边阴影条（规范：不使用单独手绘椭圆阴影）。
## 光影基准：光源右上，阴影左移 1px、下移 2px，深紫蓝色。
func _base_shadow(width: float) -> void:
	Art.rect(self, -width * 0.5 - 1.0, 0.5, width, 2.5, Color(0.24, 0.21, 0.34, 0.20))
	Art.rect(self, -width * 0.4 - 1.0, 0.5, width * 0.8, 1.5, Color(0.22, 0.19, 0.32, 0.16))
	# 地面反光（Bounce Light）：草地反弹的微弱暖绿光
	Art.rect(self, -width * 0.42, 0.15, width * 0.84, 0.7, Color(0.42, 0.52, 0.30, 0.10))


func _process(delta: float) -> void:
	_phase += delta
	if trample_timer > 0.0:
		trample_timer = maxf(0.0, trample_timer - delta)
	queue_redraw()


## 冬季屋顶积雪：屋檐 + 屋脊两档冷白色阶，边缘带不规则积雪垂块。
func _draw_roof_snow(width: float, y: float, thickness: float) -> void:
	if season != "winter":
		return
	var snow := Color("#eef3f4")
	var shade := Color("#cfdadc")
	var x0 := -width * 0.5
	Art.rect(self, x0, y, width, thickness, shade)
	Art.rect(self, x0 + 1.0, y, width - 2.0, maxf(1.0, thickness - 1.0), snow)
	for index in 4:
		var drop_x := x0 + 2.0 + float(index) * (width - 8.0) / 3.0
		var drop_w := 3.0 + float(index % 2) * 2.0
		Art.rect(self, drop_x, y + thickness, drop_w, 1.0, snow)


func _draw() -> void:
	match kind:
		"house":
			_draw_house()
		"shop":
			_draw_shop()
		"bin":
			_draw_bin()
		"coop":
			_draw_coop()
		"barn":
			_draw_barn()
		"trough":
			_draw_trough()
		"museum":
			_draw_museum()
		"library":
			_draw_library()
		"clinic":
			_draw_clinic()
		"worker_hut":
			_draw_worker_hut()
		"tree":
			_draw_tree()
		"blossom_tree":
			_draw_blossom_tree()
		"pine":
			_draw_pine()
		"bush":
			_draw_bush()
		"reeds":
			_draw_reeds()
		"pond_stone":
			_draw_pond_stone()
		"lily":
			_draw_lily()
		"rock":
			_draw_rock()
		"sign":
			_draw_sign()
		"mirror":
			_draw_mirror()
		"mailbox":
			_draw_mailbox()
		"dog_house":
			_draw_dog_house()
		"cat_house":
			_draw_cat_house()
		"stable":
			_draw_stable()
		"ostrich_house":
			_draw_ostrich_house()
		"bike_shed":
			_draw_bike_shed()
		"scaffold":
			_draw_scaffold(false)
		"scaffold_small":
			_draw_scaffold(true)
		_:
			Art.rrect(self, -4, -8, 8, 8, 1.0, Art.WOOD)


# ============================================================
# 房屋
# ============================================================

func _draw_house() -> void:
	_base_shadow(92.0)

	# 墙体：6×9 个 16px 逻辑格 = 96×144
	Art.rect(self, -44, -100, 88, 100, Art.WALL)
	Art.rect(self, 36, -100, 8, 100, Color("#cbb896"))
	Art.rect(self, 44, -100, 3, 100, Color("#b8a381"))
	Art.rect(self, -44, -4, 88, 4, Art.WALL_DARK)
	for row in 8:
		Art.hline(self, -43, -92.0 + float(row) * 11.0, 86, Color(0.72, 0.64, 0.50, 0.14))

	# 木构架（深棕梁柱）：木墙 + 石基的材质混合
	var beam := Color("#8c6a4a")
	Art.rect(self, -44, -100, 4, 100, beam)
	Art.rect(self, 40, -100, 4, 100, beam)
	Art.rect(self, -44, -60, 88, 2.5, beam)

	# 石砌墙基（材质混合：石基 + 木墙）
	Art.rect(self, -44, -14, 88, 14, Color("#a9a294"))
	Art.rect(self, -44, -14, 88, 2, Color("#bcb5a6"))
	for index in 5:
		var bx := -42.0 + float(index) * 18.0
		Art.rect(self, bx, -10, 16, 1, Color("#968f82"))
		Art.rect(self, bx + 8, -5, 1, 5, Color("#968f82"))

	# 屋顶：下沿 -100，上沿 -144；梯形 + 右侧厚度
	Art.poly(self, PackedVector2Array([
		Vector2(-48, -100), Vector2(-30, -144), Vector2(30, -144), Vector2(48, -100),
	]), Art.ROOF)
	Art.poly(self, PackedVector2Array([
		Vector2(30, -144), Vector2(48, -100), Vector2(55, -102), Vector2(37, -146),
	]), Art.ROOF_DARK)
	Art.poly(self, PackedVector2Array([
		Vector2(-30, -144), Vector2(30, -144), Vector2(37, -146), Vector2(-23, -146),
	]), Art.ROOF_LIGHT)
	for row in 5:
		var y := -104.0 - float(row) * 8.0
		var inset := 3.0 + float(row) * 4.0
		Art.hline(self, -46 + inset, y, 92 - inset * 2.0, Art.ROOF_DARK)
	Art.rect(self, -48, -101, 96, 2, Art.ROOF_DARK)

	# 烟囱（顶部熏黑 + 袅袅像素烟）
	Art.rect(self, 20, -138, 9, 20, Color("#b3a08d"))
	Art.rect(self, 19, -139, 11, 2.5, Color("#9c8b7a"))
	Art.rect(self, 21, -138, 7, 2, Color("#6b5f55"))
	if season == "winter":
		# 冬季烟囱顶积雪
		Art.rect(self, 19, -140.5, 11, 1.5, Color("#eef3f4"))
		Art.rect(self, 23, -141.5, 5, 1.0, Color("#eef3f4"))
	for puff in 3:
		var rise := fmod(_phase * 0.35 + float(puff) * 0.33, 1.0)
		var sx := 24.0 + sin((_phase + float(puff)) * 1.7) * 2.0
		var sy := -144.0 - rise * 20.0
		var smoke_alpha := 0.32 * (1.0 - rise)
		if season == "winter":
			# 冬季烟囱冒烟更明显
			smoke_alpha = minf(0.62, smoke_alpha * 1.5)
		draw_rect(Rect2(sx, sy, 3.0, 2.0), Color(0.96, 0.94, 0.90, smoke_alpha))

	# 屋顶修补瓦片（不同颜色）
	Art.rect(self, -18, -132, 9, 3, Color("#a06a4c"))
	Art.rect(self, 8, -120, 7, 3, Color("#c0805c"))
	Art.rect(self, -6, -112, 5, 2, Color("#8f5c44"))

	# 冬季：屋脊与屋檐积雪 + 坡面残雪
	_draw_roof_snow(62.0, -145.0, 2.5)
	_draw_roof_snow(94.0, -100.5, 3.0)
	if season == "winter":
		Art.rect(self, -34, -134, 12, 2, Color("#eef3f4"))
		Art.rect(self, 4, -127, 10, 2, Color("#eef3f4"))

	# 屋檐垂藤（生活痕迹，随季节轻微摆动）
	for index in 4:
		var vx := -44.0 + float(index) * 26.0
		var vine_len := 4.0 + float(index % 3) * 2.0 + sin(_phase * 0.8 + float(index)) * 1.0
		Art.rect(self, vx, -100, 2.0, vine_len, Color("#6f8f58"))
		Art.rect(self, vx, -100, 1.0, vine_len - 1.0, Color("#7fa066"))

	# 墙根木柴堆 + 苔藓
	Art.rect(self, -54, -10, 12, 3, Color("#8a5a3f"))
	Art.rect(self, -52, -13, 10, 3, Color("#a9713f"))
	Art.rect(self, -50, -16, 8, 3, Color("#8a5a3f"))
	Art.ellipse(self, -54, -10, 2.0, 1.4, Color("#c9a878"))
	Art.ellipse(self, -52, -13, 1.6, 1.2, Color("#e2c9a1"))
	Art.rect(self, -44, -2, 7, 2, Color("#6f8f58"))
	Art.rect(self, 38, -3, 5, 2, Color("#6f8f58"))

	# 门（24×40）+ 门阶
	Art.rrect(self, -12, -40, 24, 40, 2.0, Art.WOOD)
	Art.rect(self, -10, -38, 20, 38, Art.WOOD_LIGHT)
	Art.rect(self, 6, -20, 2, 2, Color("#e3c98c"))
	Art.rrect(self, -14, -1, 28, 3, 1.0, Color("#c3b191"))

	# 窗户（两扇；夜晚暖黄）
	var glass := Color("#e8c47a") if night else Color("#a9c2cd")
	for offset: float in [-34.0, 14.0]:
		Art.rrect(self, offset, -80, 20, 18, 2.0, Color("#e9dfc8"))
		Art.rrect(self, offset + 2, -78, 16, 14, 1.0, glass)
		Art.vline(self, offset + 10, -78, 14, Color("#e9dfc8"))
		Art.hline(self, offset + 2, -71, 16, Color("#e9dfc8"))
		Art.rect(self, offset - 2, -62, 24, 2, Art.WOOD_LIGHT)

	# 门牌
	Art.rrect(self, -8, -48, 16, 6, 1.0, Color("#eee3c8"))


# ============================================================
# 杂货铺
# ============================================================

func _draw_shop() -> void:
	_base_shadow(82.0)

	# 5×4 个 16px 逻辑格 = 80×64：开放式摊位
	Art.rect(self, -38, -64, 5, 64, Art.WOOD_DARK)
	Art.rect(self, 33, -64, 5, 64, Art.WOOD_DARK)
	Art.rect(self, -37.2, -62, 2, 60, Art.WOOD)

	# 后柜
	Art.rrect(self, -36, -40, 72, 24, 2.0, Art.WOOD)
	Art.rect(self, -34, -38, 68, 20, Art.WOOD_LIGHT)
	var jar_colors := [Color("#c9a6a0"), Color("#a9bfa0"), Color("#d8c48e"), Color("#a6b6c4")]
	for index in 5:
		Art.rrect(self, -31.0 + float(index) * 13.0, -35, 9, 14, 2.0, jar_colors[index % 4])

	# 柜台
	Art.rrect(self, -40, -16, 80, 16, 2.0, Art.WOOD_DARK)
	Art.rect(self, -38, -14, 76, 12, Art.WOOD)
	Art.rect(self, -38, -14, 76, 2, Art.WOOD_LIGHT)

	# 遮阳棚：柔和条纹 + 波浪边
	for index in 8:
		var color := Color("#eee3cb") if index % 2 == 0 else Color("#c49286")
		Art.rect(self, -40.0 + float(index) * 10.0, -64, 10, 14, color)
		Art.ellipse(self, -35.0 + float(index) * 10.0, -50, 5.0, 3.0, color)
	Art.rect(self, -40, -65, 80, 2, Color("#8c6a4a"))
	_draw_roof_snow(80.0, -66.5, 2.5)

	# 招牌（压在棚檐上）
	Art.rrect(self, -18, -63, 36, 11, 1.5, Color("#eee3c8"))
	Art.rect(self, -13, -59, 26, 1.5, Color("#b3a08d"))


# ============================================================
# 出货箱
# ============================================================

func _draw_bin() -> void:
	Art.shadow(self, 0, -0.5, 11, 2.4)
	Art.rrect(self, -10, -18, 20, 18, 1.0, Art.WOOD)
	Art.rect(self, -9, -17, 18, 16, Art.WOOD_LIGHT)
	Art.rect(self, -9, -14, 18, 1.0, Art.WOOD_DARK)
	Art.rect(self, -9, -9, 18, 1.0, Art.WOOD_DARK)
	# 盖
	Art.rrect(self, -11, -21, 22, 4, 0.8, Art.WOOD_DARK)
	Art.rect(self, -11, -21, 22, 1.4, Art.WOOD_LIGHT)
	# 投递口
	Art.rect(self, -5, -19.5, 10, 1.2, Color("#6f5a45"))


# ============================================================
# 鸡舍 / 畜棚
# ============================================================

func _draw_coop() -> void:
	_base_shadow(90.0)

	# 6×3 个 16px 逻辑格 = 96×48
	Art.rect(self, -44, -26, 88, 26, Color("#c9a273"))
	Art.rect(self, 35, -26, 9, 26, Color("#ad9576"))
	for row in 5:
		Art.hline(self, -43, -23.0 + float(row) * 4.5, 84, Color(0.55, 0.43, 0.32, 0.18))
	Art.rect(self, -44, -3, 88, 3, Color("#b3987a"))

	Art.poly(self, PackedVector2Array([
		Vector2(-48, -26), Vector2(-32, -48), Vector2(32, -48), Vector2(48, -26),
	]), Color("#b0836e"))
	Art.poly(self, PackedVector2Array([
		Vector2(-32, -48), Vector2(32, -48), Vector2(27, -52), Vector2(-27, -52),
	]), Color("#c1937c"))
	Art.poly(self, PackedVector2Array([
		Vector2(32, -48), Vector2(48, -26), Vector2(54, -28), Vector2(38, -50),
	]), Color("#8f6753"))
	_draw_roof_snow(60.0, -49.5, 2.0)
	_draw_roof_snow(92.0, -27.5, 2.5)

	Art.rrect(self, -11, -22, 22, 22, 2.0, Color("#8a6f55"))
	Art.rect(self, -9, -20, 18, 20, Color("#a28566"))
	Art.rect(self, 5, -11, 2, 2, Color("#e3c98c"))

	var coop_glass := Color("#e8c47a") if night else Color("#a9c2cd")
	for offset: float in [-36.0, 20.0]:
		Art.rrect(self, offset, -22, 16, 12, 1.5, Color("#eee3c8"))
		Art.rect(self, offset + 2, -20, 12, 8, coop_glass)

	Art.rect(self, 36, -2, 9, 2, Color("#d8c294"))


func _draw_barn() -> void:
	_base_shadow(104.0)

	# 7×4 个 16px 逻辑格 = 112×64
	Art.rect(self, -52, -42, 104, 42, Color("#a8615c"))
	Art.rect(self, 42, -42, 10, 42, Color("#9a6d63"))
	for row in 6:
		Art.hline(self, -51, -37.0 + float(row) * 6.5, 100, Color(0.48, 0.33, 0.28, 0.18))
	Art.rect(self, -52, -3, 104, 3, Color("#9c6f65"))

	Art.poly(self, PackedVector2Array([
		Vector2(-56, -42), Vector2(-38, -64), Vector2(38, -64), Vector2(56, -42),
	]), Color("#8f6a5e"))
	Art.poly(self, PackedVector2Array([
		Vector2(-38, -64), Vector2(38, -64), Vector2(32, -69), Vector2(-32, -69),
	]), Color("#a37b6d"))
	Art.poly(self, PackedVector2Array([
		Vector2(38, -64), Vector2(56, -42), Vector2(62, -44), Vector2(44, -66),
	]), Color("#7a594e"))
	_draw_roof_snow(72.0, -65.5, 2.0)
	_draw_roof_snow(108.0, -43.5, 2.5)

	Art.rrect(self, -16, -36, 32, 36, 2.0, Color("#8a604f"))
	Art.rect(self, -14, -34, 28, 34, Color("#a3765f"))
	Art.rect(self, -1.5, -36, 3, 36, Color("#e9dfc8"))
	Art.rect(self, -16, -20, 32, 2.4, Color("#e9dfc8"))
	Art.rect(self, 11, -14, 2, 2, Color("#e3c98c"))

	var barn_glass := Color("#e8c47a") if night else Color("#a9c2cd")
	for offset: float in [-46.0, 32.0]:
		Art.rrect(self, offset, -36, 14, 12, 1.5, Color("#eee3c8"))
		Art.rect(self, offset + 2, -34, 10, 8, barn_glass)

	Art.rrect(self, 36, -4, 10, 4, 1.0, Color("#d8c294"))


# ============================================================
# 图书馆（5×4：石基 + 暖木墙 + 大窗 + 书本招牌）
# ============================================================

func _draw_library() -> void:
	_base_shadow(124.0)

	# 台阶
	Art.rect(self, -18, 0.5, 36, 3, Color("#bcb5a6"))

	# 石基 + 木墙
	Art.rect(self, -40, -12, 80, 12, Color("#8d959e"))
	for index in 5:
		Art.vline(self, -34.0 + float(index) * 16.0, -10, 10, Color(0.35, 0.38, 0.42, 0.20))
	Art.rect(self, -38, -64, 76, 52, Color("#d8ad6a"))
	Art.rect(self, 32, -64, 6, 52, Color("#bc8f51"))
	for row in 7:
		Art.hline(self, -37, -60.0 + float(row) * 7.0, 74, Color(0.42, 0.27, 0.14, 0.14))

	# 大窗（夜晚暖黄）
	var glass := Color("#e8c47a") if night else Color("#a9c2cd")
	for offset: float in [-31.0, 7.0]:
		Art.rrect(self, offset, -56, 24, 20, 1.5, Color("#eee3c8"))
		Art.rect(self, offset + 2, -54, 20, 16, glass)
		Art.vline(self, offset + 12, -54, 16, Color("#eee3c8"))
		Art.hline(self, offset + 2, -46, 20, Color("#eee3c8"))

	# 门
	Art.rrect(self, -9, -30, 18, 30, 2.0, Color("#7f5c3e"))
	Art.rect(self, -7, -28, 14, 28, Color("#a97e52"))
	Art.rect(self, 3, -15, 2, 2, Color("#e3c98c"))

	# 招牌：书本图形
	Art.rrect(self, -20, -78, 40, 12, 1.5, Color("#eee3c8"))
	Art.rect(self, -14, -74, 6, 5, Color("#8c6a4a"))
	Art.rect(self, -13, -73, 4, 3, Color("#c9a276"))
	Art.rect(self, -6, -74, 6, 5, Color("#b5735f"))
	Art.rect(self, -5, -73, 4, 3, Color("#d99c86"))
	Art.hline(self, 3, -72, 12, Color("#b3a08d"))

	# 屋顶：深灰紫瓦 + 厚度
	Art.poly(self, PackedVector2Array([
		Vector2(-44, -64), Vector2(-30, -84), Vector2(30, -84), Vector2(44, -64),
	]), Color("#7d7488"))
	Art.poly(self, PackedVector2Array([
		Vector2(30, -84), Vector2(44, -64), Vector2(50, -66), Vector2(36, -86),
	]), Color("#655d70"))
	Art.poly(self, PackedVector2Array([
		Vector2(-30, -84), Vector2(30, -84), Vector2(36, -86), Vector2(-24, -86),
	]), Color("#958ba0"))
	Art.rect(self, -45, -65, 90, 2, Color("#5c5566"))

	# 墙根花盆
	Art.rect(self, -36, -6, 8, 4, Color("#a9713f"))
	Art.ellipse(self, -32, -8, 3.0, 2.2, Color("#7e9971"))
	Art.rect(self, 28, -6, 8, 4, Color("#a9713f"))
	Art.ellipse(self, 32, -8, 3.0, 2.2, Color("#93b083"))

	_draw_roof_snow(88.0, -65.5, 2.0)


# ============================================================
# 诊所（5×4：白墙 + 红瓦 + 十字标）
# ============================================================

func _draw_clinic() -> void:
	_base_shadow(124.0)
	Art.rect(self, -18, 0.5, 36, 3, Color("#bcb5a6"))

	# 白墙 + 木框
	Art.rect(self, -40, -8, 80, 8, Color("#b9b4a8"))
	Art.rect(self, -38, -60, 76, 52, Color("#f2ecdd"))
	Art.rect(self, 32, -60, 6, 52, Color("#d8cfbb"))
	for row in 6:
		Art.hline(self, -37, -56.0 + float(row) * 8.0, 74, Color(0.60, 0.55, 0.45, 0.10))

	# 窗户
	var glass := Color("#e8c47a") if night else Color("#b9d2dc")
	for offset: float in [-31.0, 7.0]:
		Art.rrect(self, offset, -52, 24, 18, 1.5, Color("#ffffff"))
		Art.rect(self, offset + 2, -50, 20, 14, glass)
		Art.vline(self, offset + 12, -50, 14, Color("#ffffff"))

	# 门 + 门廊
	Art.rrect(self, -9, -30, 18, 30, 2.0, Color("#8a6a4a"))
	Art.rect(self, -7, -28, 14, 28, Color("#c09a6c"))
	Art.rect(self, 3, -15, 2, 2, Color("#e3c98c"))
	Art.rect(self, -12, -31, 24, 2.4, Color("#e8d9bb"))

	# 红十字招牌
	Art.rrect(self, -18, -76, 36, 12, 1.5, Color("#fbf6ea"))
	Art.rect(self, -3, -73, 6, 6, Color("#c4553f"))
	Art.rect(self, -1, -75, 2, 10, Color("#c4553f"))
	Art.rect(self, -6, -71, 12, 2, Color("#c4553f"))

	# 红瓦屋顶
	Art.poly(self, PackedVector2Array([
		Vector2(-44, -60), Vector2(-30, -80), Vector2(30, -80), Vector2(44, -60),
	]), Color("#b0604e"))
	Art.poly(self, PackedVector2Array([
		Vector2(30, -80), Vector2(44, -60), Vector2(50, -62), Vector2(36, -82),
	]), Color("#8a4a4f"))
	Art.poly(self, PackedVector2Array([
		Vector2(-30, -80), Vector2(30, -80), Vector2(36, -82), Vector2(-24, -82),
	]), Color("#c4775f"))
	Art.rect(self, -45, -61, 90, 2, Color("#7d3f44"))
	# 烟囱
	Art.rect(self, 20, -80, 7, 12, Color("#a9a294"))
	Art.rect(self, 19, -81, 9, 2, Color("#bcb5a6"))

	_draw_roof_snow(88.0, -61.5, 2.0)


# ============================================================
# 工人小屋（2×2：原木小屋 + 水桶）
# ============================================================

func _draw_worker_hut() -> void:
	_base_shadow(62.0)

	# 木墙
	Art.rect(self, -22, -30, 44, 30, Color("#b58b5c"))
	Art.rect(self, 16, -30, 6, 30, Color("#9c7449"))
	for row in 5:
		Art.hline(self, -21, -26.0 + float(row) * 6.0, 42, Color(0.42, 0.30, 0.18, 0.16))
	# 屋顶
	Art.poly(self, PackedVector2Array([
		Vector2(-26, -30), Vector2(-14, -46), Vector2(14, -46), Vector2(26, -30),
	]), Color("#8a6a4a"))
	Art.poly(self, PackedVector2Array([
		Vector2(14, -46), Vector2(26, -30), Vector2(31, -32), Vector2(19, -48),
	]), Color("#6f5438"))
	Art.rect(self, -28, -31, 56, 2, Color("#5f4326"))
	# 门与窗
	Art.rrect(self, -6, -20, 12, 20, 1.5, Color("#7f5c3e"))
	Art.rect(self, 5, -10, 1.5, 1.5, Color("#e3c98c"))
	Art.rect(self, -18, -24, 8, 7, Color("#eee3c8"))
	Art.rect(self, -17, -23, 6, 5, Color("#a9c2cd"))
	# 水桶
	Art.rect(self, 12, -8, 8, 8, Color("#8a6a4a"))
	Art.rect(self, 12, -8, 8, 1.5, Color("#a9825c"))
	Art.rect(self, 13.5, -6.5, 5, 1.5, Color("#6fa3ad"))

	_draw_roof_snow(54.0, -31.5, 2.0)


# ============================================================
# 博物馆（7×5 逻辑格：石基 + 暖米色墙 + 三角楣 + 石柱）
# ============================================================

func _draw_museum() -> void:
	_base_shadow(210.0)

	# 台阶
	Art.rect(self, -22, 0.5, 44, 3, Color("#bcb5a6"))
	Art.rect(self, -26, 3.5, 52, 2, Color("#a9a294"))

	# 石基（冷灰蓝） + 主墙（暖米色）
	Art.rect(self, -58, -18, 116, 18, Color("#8d959e"))
	Art.rect(self, -58, -18, 116, 2, Color("#aab2b9"))
	for index in 6:
		Art.vline(self, -50.0 + float(index) * 20.0, -16, 16, Color(0.35, 0.38, 0.42, 0.22))
	Art.rect(self, -54, -48, 108, 30, Color("#d9ccb4"))
	Art.rect(self, 46, -48, 8, 30, Color("#bcae95"))
	for row in 4:
		Art.hline(self, -53, -44.0 + float(row) * 7.0, 106, Color(0.55, 0.47, 0.36, 0.12))

	# 石柱（受光面暖、暗面冷）
	for offset: float in [-46.0, -36.0, 36.0, 46.0]:
		Art.rect(self, offset - 2.5, -50, 5, 34, Color("#b7bec6"))
		Art.vline(self, offset - 0.5, -48, 30, Color("#d3d8dd"))
		Art.rect(self, offset - 3.5, -51, 7, 2.5, Color("#9aa2ab"))

	# 门（夜间门廊灯暖黄）
	Art.rrect(self, -11, -42, 22, 42, 2, Color("#7f5c3e"))
	Art.rect(self, -9, -40, 18, 38, Color("#a97e52"))
	Art.rect(self, -1, -40, 2, 38, Color("#7f5c3e"))
	Art.rect(self, 6, -24, 2, 2, Color("#e3c98c"))
	if night:
		Art.rect(self, -8, -43, 16, 2, Color("#e8c47a"))

	# 窗户
	var glass := Color("#e8c47a") if night else Color("#a9c2cd")
	for offset: float in [-30.0, 18.0]:
		Art.rrect(self, offset, -40, 12, 14, 1.5, Color("#eee3c8"))
		Art.rect(self, offset + 1.5, -38.5, 9, 11, glass)
		Art.vline(self, offset + 5, -38.5, 11, Color("#eee3c8"))

	# 三角楣（暖灰屋顶 + 冷色厚度）
	Art.poly(self, PackedVector2Array([
		Vector2(-62, -48), Vector2(0, -70), Vector2(62, -48),
	]), Color("#9d8f8f"))
	Art.poly(self, PackedVector2Array([
		Vector2(62, -48), Vector2(0, -70), Vector2(72, -52), Vector2(62, -48),
	]), Color("#7f7276"))
	# 顶部圆饰
	Art.ellipse(self, 0, -72, 7.0, 2.6, Color("#b0a6a4"))
	Art.ellipse(self, 0, -73, 4.5, 1.8, Color("#c9bfb8"))
	# 檐口
	Art.rect(self, -63, -49, 126, 2.5, Color("#867a7c"))

	# 招牌
	Art.rrect(self, -24, -62, 48, 7, 1.0, Color("#eee3c8"))
	Art.hline(self, -18, -59, 36, Color("#b3a08d"))

	# 冬季积雪
	_draw_roof_snow(124.0, -49.5, 2.0)


# ============================================================
# 食槽
# ============================================================

func _draw_trough() -> void:
	Art.shadow(self, 0, -0.4, 11, 2.2)
	Art.rrect(self, -11, -8, 22, 8, 1.0, Art.WOOD_DARK)
	Art.rrect(self, -10, -7, 20, 6, 0.8, Art.WOOD)
	# 内槽
	Art.rect(self, -8, -6.5, 16, 3, Color("#8a6f55"))
	# 干草
	Art.rect(self, -7, -7.5, 5, 2, Color("#d8c294"))
	Art.rect(self, 2, -7.5, 6, 2, Color("#cdb488"))


# ============================================================
# 树 / 石头 / 牌子 / 镜子
# ============================================================

func _draw_tree() -> void:
	Art.shadow(self, 1, -0.5, 11, 3.0)

	# 树干：底部加宽，根部有变化（树干不摆动）
	Art.rrect(self, -3, -16, 6, 16, 1.0, Art.TRUNK)
	Art.rect(self, -2, -16, 2.4, 15, Art.TRUNK_LIGHT)
	Art.rect(self, -4.5, -2.5, 9, 2.5, Art.TRUNK)
	Art.rect(self, 3.4, -3.2, 2.2, 3.2, Art.TRUNK.darkened(0.10))

	# 树冠随风轻摆：根部不动，顶部偏移（每棵树 _phase 不同，禁止整屏同步）
	var sway := sin(_phase * 1.3) * 1.2
	draw_set_transform(Vector2(roundf(sway), 0), 0.0, Vector2.ONE)
	if season == "winter":
		_draw_bare_canopy()
		_draw_snow_canopy()
	else:
		var palette := _tree_palette()
		_draw_leaf_canopy(palette[0], palette[1], palette[2])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 季节点缀
	if season == "spring":
		_draw_blossoms()
	elif season == "fall":
		_draw_falling_leaves()


## 四季树冠色阶：春嫩绿 / 夏深绿 / 秋橙红（冬走枯枝路径）。
func _tree_palette() -> Array[Color]:
	# 色相偏移：暗部偏蓝绿 / 紫红，亮部偏嫩黄
	match season:
		"summer":
			return [Color("#3f6b58"), Color("#5c8a55"), Color("#9cbf68")]
		"fall":
			return [Color("#7d4550"), Color("#c07a4a"), Color("#e2ac5c")]
		_:
			return [Art.LEAF_DARK, Art.LEAF, Art.LEAF_LIGHT]


## 三层色阶树冠 + 边缘碎块，避免完美圆形。
func _draw_leaf_canopy(dark: Color, base: Color, light: Color) -> void:
	Art.ellipse(self, 0, -24, 11.5, 10.0, dark)
	Art.ellipse(self, -0.5, -25.5, 10.2, 8.8, base)
	Art.ellipse(self, -1.5, -27.5, 7.6, 6.4, light)
	Art.ellipse(self, 4.5, -24.5, 5.8, 4.6, base)
	Art.ellipse(self, -5.5, -21.5, 4.8, 3.6, dark)
	# 边缘碎块，避免完美圆形
	Art.ellipse(self, 8.5, -21.0, 3.2, 2.4, light)
	Art.ellipse(self, -8.5, -26.5, 3.0, 2.2, base)
	Art.ellipse(self, 2.0, -31.5, 4.2, 2.8, light)
	Art.ellipse(self, -4.0, -17.5, 3.4, 2.2, dark)
	# 轻微的高光块（低对比，不是强高光；高光偏暖黄绿）
	Art.ellipse(self, -3, -30, 3.2, 2.0, Color(0.82, 0.86, 0.55, 0.58))


## 冬季枯枝：保留枝干剪影，树冠位置不再画叶片。
func _draw_bare_canopy() -> void:
	var branch := Art.TRUNK.darkened(0.12)
	Art.rect(self, -1, -28, 2, 13, branch)
	draw_line(Vector2(0, -21), Vector2(-9, -29), branch, 2.0)
	draw_line(Vector2(0, -24), Vector2(9, -30), branch, 2.0)
	draw_line(Vector2(-1, -18), Vector2(-8, -21), branch, 1.5)
	draw_line(Vector2(1, -18), Vector2(8, -20), branch, 1.5)
	draw_line(Vector2(0, -27), Vector2(-4, -32), branch, 1.5)
	draw_line(Vector2(0, -27), Vector2(4, -32), branch, 1.5)


## 冬季枝头积雪：冷白两档色阶，贴着枝梢不规则堆叠。
func _draw_snow_canopy() -> void:
	var snow := Color("#eef4f5")
	var shade := Color("#cfdadd")
	Art.ellipse(self, -8, -29.5, 3.6, 2.0, shade)
	Art.ellipse(self, 8, -30.0, 3.4, 1.9, shade)
	Art.ellipse(self, 0, -32.0, 3.4, 1.6, snow)
	Art.ellipse(self, -8, -30.5, 2.8, 1.5, snow)
	Art.ellipse(self, 8, -31.0, 2.6, 1.4, snow)
	Art.ellipse(self, -3, -33.0, 2.2, 1.2, snow)
	Art.ellipse(self, 3, -33.0, 2.2, 1.2, snow)
	Art.ellipse(self, 0, -27.5, 2.3, 1.1, snow)


## 春季樱花：树冠外缘点缀粉色花簇（不做发光）。
func _draw_blossoms() -> void:
	var pink := Color("#e7b7c6")
	var pink_light := Color("#f2cfd9")
	Art.ellipse(self, -9, -29, 2.6, 2.0, pink)
	Art.ellipse(self, 5, -33, 2.2, 1.7, pink_light)
	Art.ellipse(self, 9, -25, 2.4, 1.8, pink)
	Art.ellipse(self, -6, -19, 1.8, 1.4, pink_light)


## 花树：春夏季粉色树冠，秋季转橙红，冬季只留枝干积雪。
func _draw_blossom_tree() -> void:
	Art.shadow(self, 1, -0.5, 11, 3.0)
	Art.rrect(self, -3, -16, 6, 16, 1.0, Art.TRUNK)
	Art.rect(self, -2, -16, 2.4, 15, Art.TRUNK_LIGHT)
	Art.rect(self, -4.5, -2.5, 9, 2.5, Art.TRUNK)
	Art.rect(self, 3.4, -3.2, 2.2, 3.2, Art.TRUNK.darkened(0.10))

	var sway := sin(_phase * 1.1 + 1.7) * 1.4
	draw_set_transform(Vector2(roundf(sway), 0), 0.0, Vector2.ONE)
	if season == "winter":
		_draw_bare_canopy()
		_draw_snow_canopy()
	else:
		var palette := _blossom_palette()
		_draw_leaf_canopy(palette[0], palette[1], palette[2])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if season == "spring" or season == "summer":
		_draw_petals()
	elif season == "fall":
		_draw_falling_leaves()


func _blossom_palette() -> Array[Color]:
	match season:
		"summer":
			return [Color("#7b5a78"), Color("#c47b9c"), Color("#e6a9c2")]
		"fall":
			return [Color("#7d4550"), Color("#c07a6a"), Color("#e2ac7c")]
		_:
			return [Color("#8a5f80"), Color("#d98fb0"), Color("#f2c4d6")]


## 花瓣飘落：与落叶同构，但更轻更慢。
func _draw_petals() -> void:
	for index in 4:
		var t := fmod(_phase * 0.16 + float(index) * 0.29, 1.0)
		var px := sin(_phase * 0.8 + float(index) * 1.9) * 10.0 + float(index - 2) * 3.0
		var py := -18.0 + t * 18.0
		Art.rect(self, px, py, 0.75, 0.5, Color("#f2c4d6"))


## 灌木：低矮绿丛 + 季节花点，不参与碰撞。
func _draw_bush() -> void:
	Art.shadow(self, 0.5, -0.2, 6.0, 1.6)
	var sway := sin(_phase * 1.7 + position.x * 0.05) * 0.4
	# 被踩到：短促左右抖动
	if trample_timer > 0.0:
		sway += sin(trample_timer * 60.0) * 1.4
	draw_set_transform(Vector2(roundf(sway), 0), 0.0, Vector2.ONE)

	var dark := Art.LEAF_DARK
	var base := Art.LEAF
	var light := Art.LEAF_LIGHT
	match season:
		"summer":
			dark = Color("#3f6b58")
			base = Color("#5c8a55")
			light = Color("#9cbf68")
		"fall":
			dark = Color("#7d4550")
			base = Color("#c07a4a")
			light = Color("#e2ac5c")
		"winter":
			Art.rect(self, -0.5, -3, 1, 3, Art.TRUNK)
			Art.ellipse(self, -1.5, -4.5, 3.6, 1.8, Color("#eef4f5"))
			Art.ellipse(self, 2.0, -3.8, 2.8, 1.5, Color("#cfdadd"))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return

	Art.ellipse(self, 0, -4.0, 6.2, 3.8, dark)
	Art.ellipse(self, -0.5, -5.0, 5.4, 3.2, base)
	Art.ellipse(self, 1.6, -6.0, 3.0, 2.0, light)
	if season == "spring" or season == "summer":
		var flowers := [Color("#e07a8a"), Color("#e8c85a"), Color("#f2ead8")]
		# 花的昼夜开合：夜晚闭合（缩小成色点）
		var open := 1.0
		if is_night:
			open = 0.55
		for index in 3:
			var fx := -4.0 + float(index) * 3.8
			var fy := -6.0 + float(index % 2) * 1.6
			Art.rect(self, fx + (1.0 - open) * 0.5, fy + (1.0 - open) * 0.5,
				1.0 * open, 1.0 * open, flowers[index])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 池塘边的芦苇（纯装饰，随风摆动）。
func _draw_reeds() -> void:
	Art.shadow(self, 0, -0.2, 4.0, 1.0)
	var sway := sin(_phase * 1.9) * 0.8
	for index in 4:
		var x := -3.0 + float(index) * 2.0
		var h := 9.0 + float(index % 3) * 2.5
		draw_line(Vector2(x, 0), Vector2(x + sway, -h), Color("#6f8f58"), 1.0)
		if index % 2 == 0:
			draw_rect(Rect2(x + sway - 0.5, -h - 1.5, 1.5, 2.0), Color("#8a6a4a"))


## 针叶树：参考图中的深绿松杉，三层三角树冠 + 冬季积雪。
func _draw_pine() -> void:
	Art.shadow(self, 1, -0.5, 8.5, 2.4)
	Art.rect(self, -1.5, -10, 3, 10, Art.TRUNK)
	Art.rect(self, 3.0, -2.0, 2.0, 2.0, Art.TRUNK.darkened(0.12))

	var dark := Color("#2f5a4a")
	var base := Color("#3f6f55")
	var light := Color("#5f9166")
	var sway := sin(_phase * 1.2 + position.x * 0.03) * 0.6
	draw_set_transform(Vector2(roundf(sway), 0), 0.0, Vector2.ONE)
	Art.poly(self, PackedVector2Array([
		Vector2(-11, -8), Vector2(0, -18), Vector2(11, -8),
	]), dark)
	Art.poly(self, PackedVector2Array([
		Vector2(-9, -14), Vector2(0, -24), Vector2(9, -14),
	]), base)
	Art.poly(self, PackedVector2Array([
		Vector2(-7, -20), Vector2(0, -30), Vector2(7, -20),
	]), light)
	# 受光面（右上）
	Art.poly(self, PackedVector2Array([
		Vector2(1, -24), Vector2(9, -14), Vector2(3, -15),
	]), Art.tint_warm(base, 0.18))
	if season == "winter":
		Art.ellipse(self, 0, -30, 5.0, 1.6, Color("#eef4f5"))
		Art.ellipse(self, -5.0, -20, 3.0, 1.2, Color("#eef4f5"))
		Art.ellipse(self, 5.0, -20, 3.0, 1.2, Color("#cfdadd"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 池塘石岸：冷灰蓝石头 + 苔藓。
func _draw_pond_stone() -> void:
	Art.shadow(self, 0, -0.2, 5.0, 1.4)
	Art.ellipse(self, 0, -2.2, 4.5, 2.6, Color("#7f8792"))
	Art.ellipse(self, -0.6, -2.8, 3.6, 1.9, Color("#a3a8ad"))
	Art.ellipse(self, 1.0, -3.4, 2.0, 1.0, Color("#c6c9c4"))
	Art.ellipse(self, -2.5, -1.6, 1.6, 0.9, Color("#6f8f58"))
	if season == "winter":
		Art.ellipse(self, 0, -3.8, 3.4, 1.1, Color("#eef4f5"))


## 睡莲：水面圆叶 + 缺口 + 春夏粉花。
func _draw_lily() -> void:
	var bob := sin(_phase * 1.4) * 0.2
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 1))
	Art.ellipse(self, 0, -1.5 + bob, 4.2, 2.0, Color("#3f7a4c"))
	Art.ellipse(self, -0.8, -1.9 + bob, 3.0, 1.3, Color("#5f9e5f"))
	# 缺口（露出水色）
	Art.poly(self, PackedVector2Array([
		Vector2(1.6, -1.2 + bob), Vector2(4.4, -2.0 + bob), Vector2(3.0, -0.6 + bob),
	]), Color("#6fa3ad"))
	if season == "spring" or season == "summer":
		Art.ellipse(self, 1.0, -3.0 + bob, 1.2, 0.9, Color("#e8a8be"))
		Art.rect(self, 0.8, -3.4 + bob, 0.8, 0.8, Color("#f6dce4"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 秋季落叶：每片独立相位飘落，落地即循环。
func _draw_falling_leaves() -> void:
	var colors := [Color("#c07a4a"), Color("#9c5638"), Color("#d9a05e")]
	for index in 3:
		var t := fmod(_phase * 0.22 + float(index) * 0.37, 1.0)
		var fx := sin(_phase * 0.9 + float(index) * 2.1) * 9.0 + float(index - 1) * 5.0
		var fy := -20.0 + t * 20.0
		draw_rect(Rect2(roundf(fx), roundf(fy), 2.0, 1.0), colors[index])


func _draw_rock() -> void:
	Art.shadow(self, 0.5, -0.4, 8.5, 2.2)
	Art.ellipse(self, 0, -4.5, 8.0, 4.8, Art.ROCK_DARK)
	Art.ellipse(self, -0.6, -5.4, 7.0, 4.0, Art.ROCK)
	Art.ellipse(self, -2, -6.4, 4.0, 2.2, Art.ROCK_LIGHT)
	Art.ellipse(self, 3.5, -4.0, 2.6, 1.6, Art.ROCK_DARK)


func _draw_sign() -> void:
	Art.shadow(self, 0, -0.3, 8, 1.8)
	Art.rect(self, -1, -12, 2, 12, Art.WOOD_DARK)
	Art.rrect(self, -9, -22, 18, 10, 1.0, Color("#eee3c8"))
	Art.rect(self, -7, -19.5, 14, 1.2, Color("#b3a08d"))
	Art.rect(self, -7, -16.5, 10, 1.2, Color("#c3b191"))


## 邮箱：木柱 + 暖色信箱；有未读信件时红色小旗竖起。
func _draw_mailbox() -> void:
	Art.shadow(self, 0, -0.2, 5.0, 1.6)
	# 木柱
	Art.rect(self, -1.0, -12.0, 2.0, 12.0, Art.TRUNK)
	Art.rect(self, -1.0, -12.0, 0.8, 12.0, Art.TRUNK_LIGHT)
	# 箱体
	Art.rrect(self, -6.0, -20.0, 12.0, 8.0, 1.2, Color("#b06a5e"))
	Art.rect(self, -5.0, -19.0, 10.0, 2.0, Color("#c98272"))
	Art.rect(self, -4.0, -16.0, 8.0, 1.2, Color("#6b4436"))
	# 未读小旗
	var flag_color := Color("#d9534f") if has_mail else Color("#8a6a4a")
	Art.rect(self, 5.0, -21.0, 1.0, 6.0, Art.WOOD_DARK)
	Art.rect(self, 5.0, -21.0, 4.0, 2.5, flag_color)
	# 冬季顶面积雪
	if season == "winter":
		Art.rect(self, -6.0, -21.0, 12.0, 1.5, Color("#eef4f5"))


## 狗屋：红瓦斜顶 + 圆拱门洞 + 食盆（买狗后出现在屋旁）。
func _draw_dog_house() -> void:
	Art.shadow(self, 0.5, -0.6, 12.0, 3.0)
	# 木墙体
	Art.rect(self, -11, -18, 22, 18, Color("#b58b5c"))
	for row in 3:
		Art.hline(self, -10, -15.0 + float(row) * 6.0, 20, Color(0.42, 0.30, 0.18, 0.16))
	Art.rect(self, -11, -2, 22, 2, Color("#9c7449"))
	# 圆拱门
	Art.rrect(self, -5, -13, 10, 13, 3.0, Color("#5f4326"))
	Art.rrect(self, -4, -12, 8, 12, 2.4, Color("#3f2f22"))
	# 红瓦斜顶
	Art.poly(self, PackedVector2Array([
		Vector2(-14, -18), Vector2(0, -28), Vector2(14, -18),
	]), Color("#b0604e"))
	Art.poly(self, PackedVector2Array([
		Vector2(0, -28), Vector2(14, -18), Vector2(18, -19), Vector2(4, -29),
	]), Color("#8a4a4f"))
	Art.rect(self, -15, -19, 30, 2, Color("#7d3f44"))
	# 食盆
	Art.ellipse(self, 0, -1.0, 4.0, 1.6, Color("#8f959c"))
	Art.ellipse(self, 0, -1.6, 3.0, 1.1, Color("#6fa3ad"))
	# 冬季积雪
	if season == "winter":
		Art.poly(self, PackedVector2Array([
			Vector2(-12, -20), Vector2(0, -29), Vector2(12, -20), Vector2(9, -19),
			Vector2(0, -26), Vector2(-9, -19),
		]), Color("#eef3f4"))


## 猫屋：蓝灰瓦顶 + 圆形猫洞 + 小木台（买猫后出现在屋旁）。
func _draw_cat_house() -> void:
	Art.shadow(self, 0.5, -0.6, 12.0, 3.0)
	Art.rect(self, -10, -20, 20, 20, Color("#d8ad6a"))
	for row in 4:
		Art.hline(self, -9, -17.0 + float(row) * 5.0, 18, Color(0.42, 0.27, 0.14, 0.16))
	Art.rect(self, -10, -2, 20, 2, Color("#bc8f51"))
	# 猫洞（圆形）
	Art.ellipse(self, 0, -8.0, 3.6, 4.2, Color("#5f4326"))
	Art.ellipse(self, 0, -7.6, 2.8, 3.4, Color("#3f2f22"))
	# 蓝灰瓦顶
	Art.poly(self, PackedVector2Array([
		Vector2(-13, -20), Vector2(0, -30), Vector2(13, -20),
	]), Color("#7d8fa8"))
	Art.poly(self, PackedVector2Array([
		Vector2(0, -30), Vector2(13, -20), Vector2(17, -21), Vector2(4, -31),
	]), Color("#5f7088"))
	Art.rect(self, -14, -21, 28, 2, Color("#4e5d72"))
	# 小木台与毛线球
	Art.rect(self, -12, -1.0, 24, 2.0, Color("#a9825c"))
	Art.ellipse(self, 8.0, -2.4, 2.0, 1.6, Color("#c47b9c"))
	if season == "winter":
		Art.poly(self, PackedVector2Array([
			Vector2(-11, -22), Vector2(0, -31), Vector2(11, -22), Vector2(8, -21),
			Vector2(0, -28), Vector2(-8, -21),
		]), Color("#eef3f4"))


func _draw_mirror() -> void:
	Art.shadow(self, 0, -0.3, 7, 1.8)
	Art.rect(self, -6, -26, 12, 26, Art.WOOD_DARK)
	Art.rect(self, -4.8, -24.8, 9.6, 20, Color("#b7cbd2"))
	Art.rect(self, -4.0, -24.0, 3.0, 12.0, Color(1.0, 0.97, 0.90, 0.35))
	Art.rect(self, -6.5, -27, 13, 2, Art.WOOD)
	Art.rrect(self, -7, -19, 14, 2.5, 0.6, Art.WOOD)
	Art.rect(self, -6.5, -1, 13, 1.5, Art.WOOD_DARK)


## 马厩：4×3 木墙 + 深棕屋顶 + 马蹄铁门饰。
func _draw_stable() -> void:
	_base_shadow(62.0)

	# 墙体（错缝木板）
	Art.rect(self, -30.0, -46.0, 60.0, 46.0, Color("#b8865a"))
	for row in 7:
		var y := -44.0 + float(row) * 6.0
		Art.rect(self, -30.0, y, 60.0, 0.8, Color(0.36, 0.24, 0.14, 0.20))
	Art.rect(self, -30.0, -46.0, 3.0, 46.0, Color("#9c6d45"))
	Art.rect(self, 27.0, -46.0, 3.0, 46.0, Color("#9c6d45"))
	Art.rect(self, -32.0, -2.0, 64.0, 2.0, Color("#7d5a3c"))

	# 屋顶（深棕，带屋脊与冬季积雪）
	Art.poly(self, PackedVector2Array([
		Vector2(-36.0, -44.0), Vector2(36.0, -44.0),
		Vector2(30.0, -57.0), Vector2(-30.0, -57.0),
	]), Color("#5f4534"))
	Art.poly(self, PackedVector2Array([
		Vector2(-30.0, -57.0), Vector2(30.0, -57.0),
		Vector2(26.0, -60.0), Vector2(-26.0, -60.0),
	]), Color("#4a3528"))
	Art.rect(self, -36.0, -45.2, 72.0, 1.4, Color("#7a5a42"))
	_draw_roof_snow(64.0, -57.0, 2.2)
	# 通风口
	Art.rect(self, -2.5, -60.0, 5.0, 2.5, Color("#8a6a4a"))
	Art.rect(self, -1.5, -59.4, 3.0, 1.2, Color("#3f3026"))

	# 大门 + 马蹄铁
	Art.rect(self, -9.0, -25.0, 18.0, 25.0, Color("#6f4328"))
	Art.rect(self, -8.0, -24.0, 16.0, 23.0, Color("#8c5a36"))
	for row in 3:
		Art.rect(self, -8.0, -20.0 + float(row) * 7.0, 16.0, 0.8,
			Color(0.30, 0.18, 0.10, 0.30))
	Art.rect(self, -1.0, -22.0, 2.0, 2.0, Color("#e3c98c"))
	# 马蹄铁（U 形）
	Art.rect(self, -3.0, -36.0, 6.0, 1.4, Color("#c9b48e"))
	Art.rect(self, -3.0, -36.0, 1.2, 4.0, Color("#c9b48e"))
	Art.rect(self, 1.8, -36.0, 1.2, 4.0, Color("#c9b48e"))

	# 侧窗（窗口可见干草）
	for wx: float in [-23.0, 16.0]:
		Art.rect(self, wx, -37.0, 8.0, 7.0, Color("#6f4328"))
		Art.rect(self, wx + 1.0, -36.0, 6.0, 5.0,
			Color("#f2e6cd") if night else Color("#b9d2dc"))
		Art.rect(self, wx + 1.0, -33.0, 6.0, 2.0, Color("#d8c08a"))
		if night:
			Art.rect(self, wx + 1.0, -36.0, 6.0, 1.0, Color(1.0, 0.86, 0.55, 0.55))

	# 门口干草堆与水桶
	Art.ellipse(self, -22.0, -2.0, 6.0, 3.0, Color("#d8c08a"))
	Art.ellipse(self, -24.0, -3.4, 3.2, 2.0, Color("#e3d0a4"))
	Art.rect(self, 18.0, -7.0, 6.0, 7.0, Color("#8a6a4a"))
	Art.rect(self, 18.0, -7.0, 6.0, 1.2, Color("#a9825c"))
	Art.rect(self, 18.8, -6.0, 4.4, 2.0, Color("#6fa3ad"))


## 鸵鸟舍：4×3 浅色木墙 + 浅色屋顶 + 高窗 + 羽毛门饰。
func _draw_ostrich_house() -> void:
	_base_shadow(62.0)

	# 墙体（浅色木板）
	Art.rect(self, -30.0, -46.0, 60.0, 46.0, Color("#d8c39a"))
	for row in 7:
		var y := -44.0 + float(row) * 6.0
		Art.rect(self, -30.0, y, 60.0, 0.8, Color(0.42, 0.32, 0.18, 0.18))
	Art.rect(self, -30.0, -46.0, 3.0, 46.0, Color("#b8a381"))
	Art.rect(self, 27.0, -46.0, 3.0, 46.0, Color("#b8a381"))

	# 浅色屋顶
	Art.poly(self, PackedVector2Array([
		Vector2(-36.0, -44.0), Vector2(36.0, -44.0),
		Vector2(30.0, -57.0), Vector2(-30.0, -57.0),
	]), Color("#c9b48e"))
	Art.poly(self, PackedVector2Array([
		Vector2(-30.0, -57.0), Vector2(30.0, -57.0),
		Vector2(26.0, -60.0), Vector2(-26.0, -60.0),
	]), Color("#a8926c"))
	Art.rect(self, -36.0, -45.2, 72.0, 1.4, Color("#dccaa4"))
	_draw_roof_snow(64.0, -57.0, 2.2)
	# 通风口
	Art.rect(self, -2.5, -60.0, 5.0, 2.5, Color("#a8926c"))
	Art.rect(self, -1.5, -59.4, 3.0, 1.2, Color("#6f5a48"))

	# 大门 + 羽毛装饰
	Art.rect(self, -9.0, -25.0, 18.0, 25.0, Color("#8c6a4a"))
	Art.rect(self, -8.0, -24.0, 16.0, 23.0, Color("#b08a62"))
	Art.rect(self, -1.0, -22.0, 2.0, 2.0, Color("#e3c98c"))
	for index in 3:
		var x := -4.2 + float(index) * 3.2
		Art.rect(self, x, -37.0 + float(index % 2) * 0.8, 1.6, 6.0,
			Color("#efe9dc"))
		Art.rect(self, x + 0.4, -36.0, 0.8, 4.0, Color("#c9b48e"))

	# 高窗（鸵鸟个子高）
	for wx: float in [-24.0, 16.0]:
		Art.rect(self, wx, -40.0, 8.0, 13.0, Color("#8c6a4a"))
		Art.rect(self, wx + 1.0, -39.0, 6.0, 11.0,
			Color("#f2e6cd") if night else Color("#b9d2dc"))
		Art.rect(self, wx + 4.0, -39.0, 1.0, 11.0, Color("#8c6a4a"))
		if night:
			Art.rect(self, wx + 1.0, -39.0, 6.0, 2.0, Color(1.0, 0.86, 0.55, 0.55))

	# 门口沙地、水盆、干草
	Art.ellipse(self, -20.0, -2.0, 8.0, 3.0, Color("#ddcbab"))
	Art.ellipse(self, 19.0, -2.5, 5.0, 2.4, Color("#c9b48e"))
	Art.ellipse(self, 19.0, -3.2, 3.6, 1.6, Color("#8fc6d4"))
	Art.ellipse(self, -26.0, -5.0, 4.0, 2.2, Color("#d8c08a"))


## 自行车棚：3×2 开放式木架 + 斜顶 + 停车位。
func _draw_bike_shed() -> void:
	_base_shadow(44.0)

	# 地面石板
	Art.rect(self, -22.0, -1.5, 44.0, 1.5, Color("#b8b0a2"))

	# 斜顶（前高后低）
	Art.poly(self, PackedVector2Array([
		Vector2(-26.0, -25.0), Vector2(26.0, -31.0),
		Vector2(24.0, -37.0), Vector2(-24.0, -31.0),
	]), Color("#8a6a4a"))
	Art.poly(self, PackedVector2Array([
		Vector2(-24.0, -31.0), Vector2(24.0, -37.0),
		Vector2(23.0, -39.0), Vector2(-23.0, -33.0),
	]), Color("#6f5438"))
	for index in 7:
		var t := float(index) / 6.0
		var x := lerpf(-25.0, 25.0, t)
		var y := lerpf(-25.6, -30.4, t)
		Art.rect(self, x, y, 0.8, 5.0, Color(0.32, 0.22, 0.14, 0.30))
	_draw_roof_snow(48.0, -35.0, 2.0)

	# 四根木柱
	for px: float in [-22.0, 18.0]:
		Art.rect(self, px, -28.0, 3.0, 28.0, Art.WOOD_DARK)
		Art.rect(self, px, -28.0, 1.0, 28.0, Art.WOOD)
	Art.rect(self, -22.0, -28.0, 43.0, 2.0, Art.WOOD)

	# 棚内自行车剪影
	var tire := Color("#4a4440")
	var frame := Color("#b5534f")
	for wheel_x: float in [-8.0, 7.0]:
		Art.ellipse(self, wheel_x, -5.0, 4.0, 4.0, tire)
		Art.ellipse(self, wheel_x, -5.0, 2.3, 2.3, Color("#c9d0d2"))
	Art.rect(self, -8.0, -5.4, 15.0, 1.2, frame)
	Art.rect(self, -2.0, -12.0, 1.4, 7.0, frame)
	Art.rect(self, 5.0, -12.0, 1.4, 7.0, Color("#9aa4a8"))
	Art.rect(self, -4.0, -12.6, 4.0, 1.2, Color("#5a4a38"))
	Art.rect(self, 4.0, -13.0, 4.0, 1.0, Color("#9aa4a8"))


## 建造中的脚手架（stable 4×3 / bike_shed 3×2）。
func _draw_scaffold(small: bool) -> void:
	var width := 44.0 if small else 60.0
	var height := 34.0 if small else 46.0
	_base_shadow(width + 4.0)
	var wood := Color("#b08a62")
	var dark := Color("#8c6a4a")
	Art.rect(self, -width * 0.5, -2.0, width, 2.0, Color(0.36, 0.27, 0.18, 0.22))
	# 立柱
	for px: float in [-width * 0.5, width * 0.5 - 2.0]:
		Art.rect(self, px, -height, 2.4, height, dark)
		Art.rect(self, px, -height, 0.8, height, wood)
	# 横梁（两层）
	for level in 2:
		var y := -height * (0.35 + 0.3 * float(level))
		Art.rect(self, -width * 0.5, y, width, 2.0, wood)
		Art.rect(self, -width * 0.5, y + 2.0, width, 0.6, dark)
		# 斜撑
		Art.stepped_line(self, Vector2(-width * 0.5, y),
			Vector2(-width * 0.5 + 12.0, y - 10.0), dark)
		Art.stepped_line(self, Vector2(width * 0.5, y),
			Vector2(width * 0.5 - 12.0, y - 10.0), dark)
	# 草绳与木料堆
	Art.rect(self, -10.0, -3.0, 20.0, 2.0, Color("#c9a276"))
	Art.rect(self, -7.0, -5.0, 14.0, 2.0, Color("#d8b48a"))
