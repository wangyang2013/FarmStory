class_name PixelArt
extends RefCounted
## 16px 像素美术工具。
##
## 风格约定（来自 美术要求.txt）：
## - 以 16px 为美术单位绘制，内部 ×2 放大到 32px 屏幕格，像素放大不模糊。
## - 不使用粗黑描边；边缘用同色系加深色过渡。
## - 暖调、低饱和度田园配色；阴影是预绘制的软阴影，不做实时光影与强高光。
## - 矩形地块 + 斜 45° 伪俯视：建筑与树木有正面和顶面，地面保持矩形网格。
##
## 用法：
##     PixelArt.rect(self, 0, 0, 16, 16, PixelArt.GRASS_SPRING[0])
##     PixelArt.shadow(self, 0, 0, 6, 2)
##     PixelArt.draw_character(self, look, "down", 0.0, false)

const U := 2

# ============================================================
# 基础色（暖调 / 低饱和）
# ============================================================

const INK := Color("#5a4a38")
const INK_SOFT := Color("#8a7862")
const CREAM := Color("#f6efdd")
const CREAM_DARK := Color("#e9dcc2")

# 60% 基础色：低饱和暖调草绿（避免大面积高饱和亮绿）
const GRASS_SPRING := [Color("#8fae74"), Color("#8dac72"), Color("#90af75")]
const GRASS_SUMMER := [Color("#83a566"), Color("#81a364"), Color("#84a667")]
const GRASS_AUTUMN := [Color("#b3a06c"), Color("#b19e6a"), Color("#b4a16e")]
const GRASS_WINTER := [Color("#dfe5e0"), Color("#dde3de"), Color("#e0e6e1")]
const GRASS_DETAIL := Color("#a9bf82")

const SOIL_DRY := Color("#b58f68")
const SOIL_WET := Color("#8f6f50")
const SOIL_EDGE := Color("#9c7a57")
const SOIL_DARK_EDGE := Color("#7d6047")

# 暖金色土路（参考牧场图：金黄泥土 + 碎石边缘）
const PATH_COLORS := [Color("#d3a86b"), Color("#cba063")]
const PATH_DETAIL := Color("#b98b52")
const PATH_PEBBLE := Color("#a87f4e")
const SAND := Color("#ddcbab")
const SAND_DETAIL := Color("#d2bf9e")

# 水岸 4 层：沙/湿泥 → 浅水 → 过渡 → 深水（色相偏青蓝）
const WATER := Color("#5f97b0")
const WATER_LIGHT := Color("#8fc6d4")
const WATER_DARK := Color("#47798f")
const WATER_EDGE := Color("#6fa5b0")
const WATER_SHALLOW := Color("#7fb3b0")

const WOOD := Color("#a9825c")
const WOOD_DARK := Color("#8c6a4a")
const WOOD_LIGHT := Color("#c9a276")
const ROOF := Color("#b0604e")
const ROOF_DARK := Color("#8a4a4f")
const ROOF_LIGHT := Color("#c4775f")
const WALL := Color("#e6d2ab")
const WALL_LIGHT := Color("#f0e0bd")
const WALL_DARK := Color("#d3bd92")

# 树冠三阶：受光嫩黄绿 / 中绿 / 背光蓝绿（色相偏移）
const LEAF := Color("#6f9a60")
const LEAF_LIGHT := Color("#a9c46f")
const LEAF_DARK := Color("#4f7663")
const TRUNK := Color("#8c6a4a")
const TRUNK_LIGHT := Color("#b08a62")

const ROCK := Color("#a3a39c")
const ROCK_LIGHT := Color("#c9c5b8")
const ROCK_DARK := Color("#7f8792")

const SCREEN := Color("#cbb692")

# ============================================================
# 角色调色板
# ============================================================

const SKIN_TONES := {
	"fair": Color("#f2d7bd"),
	"natural": Color("#e8c6a4"),
	"wheat": Color("#d6a87e"),
	"healthy": Color("#c08d62"),
	"deep": Color("#9a6a49"),
}

const HAIR_COLORS := {
	"black": Color("#4a3b32"),
	"brown": Color("#8a6a4c"),
	"blonde": Color("#d2b276"),
	"red": Color("#a86b51"),
	"blue": Color("#7289a6"),
	"pink": Color("#c8929d"),
	"white": Color("#e7e1d5"),
	"gray": Color("#9a978f"),
	"green": Color("#7e9971"),
	"purple": Color("#8c7e99"),
	"orange": Color("#bf8a58"),
	"silver": Color("#c1c4c1"),
}

const OUTFIT_COLORS := {
	"blue": Color("#7f9cb8"),
	"red": Color("#b57f74"),
	"green": Color("#87a077"),
	"yellow": Color("#c9ac74"),
	"purple": Color("#93849f"),
	"teal": Color("#7fa39c"),
	"pink": Color("#c6959d"),
	"gray": Color("#8d8b86"),
}

const HAIR_STYLE_NAMES := {
	"short": "短发",
	"long": "长发",
	"ponytail": "马尾",
	"curly": "卷发",
	"bun": "丸子头",
	"buzz": "寸头",
	"side_part": "侧分",
	"twin_tails": "双马尾",
}

const FACE_SHAPE_NAMES := {
	"round": "圆脸",
	"square": "方脸",
	"long": "长脸",
	"oval": "瓜子脸",
}

const OUTFIT_NAMES := {
	"casual": "休闲",
	"work": "工装",
	"dress": "裙装",
	"sport": "运动",
	"retro": "复古",
	"plain": "朴素",
}

const SKIN_NAMES := {
	"fair": "白皙",
	"natural": "自然",
	"wheat": "小麦",
	"healthy": "健康",
	"deep": "深色",
}

const HAIR_COLOR_NAMES := {
	"black": "黑",
	"brown": "棕",
	"blonde": "金",
	"red": "红",
	"blue": "蓝",
	"pink": "粉",
	"white": "白",
	"gray": "灰",
	"green": "绿",
	"purple": "紫",
	"orange": "橙",
	"silver": "银",
}

const OUTFIT_COLOR_NAMES := {
	"blue": "蓝",
	"red": "红",
	"green": "绿",
	"yellow": "黄",
	"purple": "紫",
	"teal": "青",
	"pink": "粉",
	"gray": "灰",
}

const GENDER_NAMES := {
	"female": "女",
	"male": "男",
}

## 作物的柔和果实色（低饱和暖调），用于地块与图标着色。
const CROP_COLORS := {
	"turnip": Color("#e0c6cc"),
	"potato": Color("#c8a97e"),
	"cucumber": Color("#9fbc84"),
	"strawberry": Color("#cf8c8c"),
	"cabbage": Color("#b6c9a3"),
	"asparagus": Color("#a8bf8b"),
	"tulip": Color("#d29aa6"),
	"pea": Color("#a6c187"),
	"lettuce": Color("#b2c995"),
	"runner_bean": Color("#a3bd87"),
	"kailan": Color("#94b37d"),
	"tomato": Color("#c47d72"),
	"corn": Color("#dcc287"),
	"onion": Color("#cfa9a0"),
	"watermelon": Color("#94b47c"),
	"pineapple": Color("#d6c07c"),
	"chili": Color("#c47f6f"),
	"eggplant": Color("#8f7f9e"),
	"sunflower": Color("#dcc07e"),
	"muskmelon": Color("#c9c08a"),
	"okra": Color("#9fb87e"),
	"lotus_seed": Color("#c7bda0"),
	"sweetpotato": Color("#c49b78"),
	"pumpkin": Color("#cf9a6b"),
	"carrot": Color("#cc9670"),
	"spinach": Color("#8fae75"),
	"grape": Color("#9a8aa6"),
	"farm_mushroom": Color("#c3ac95"),
	"chinese_cabbage": Color("#b6c9a3"),
	"wheat": Color("#d6c08c"),
	"chrysanthemum": Color("#dec58b"),
	"yam": Color("#bfa98c"),
	"buckwheat": Color("#c3ab88"),
	"leek": Color("#9fb87e"),
	"kale": Color("#8faa78"),
	"winter_flower": Color("#c2ccd0"),
	"garlic": Color("#e0d8c6"),
	"sugarcane": Color("#b4bd83"),
	"blueberry": Color("#8b93b0"),
	"ginseng": Color("#cdb894"),
}


## 作物的果实 / 花朵颜色。
static func crop_color(crop_id: String, is_flower := false) -> Color:
	if CROP_COLORS.has(crop_id):
		return CROP_COLORS[crop_id]
	return soft_color(crop_id, 0.30 if is_flower else 0.34, 0.78)


## 同一字符串稳定映射到一种柔和低饱和颜色。
static func soft_color(text: String, saturation := 0.32, value := 0.76) -> Color:
	var h := 0
	for index in text.length():
		h = (h * 31 + text.unicode_at(index)) % 360
	var hue := float((h % 300) + 20) / 360.0
	return Color.from_hsv(hue, saturation, value)


static func default_look() -> Dictionary:
	return {
		"gender": "female",
		"hair": "ponytail",
		"hair_color": "brown",
		"skin": "natural",
		"face": "oval",
		"outfit": "casual",
		"outfit_color": "blue",
		"accessories": {"head": "", "face": "", "neck": "", "hand": "", "back": ""},
	}


## 淡入淡出动画用不到，这里保证 look 字段完整可用。
static func normalize_look(look: Dictionary) -> Dictionary:
	var result := default_look()
	for key: Variant in look.keys():
		if result.has(str(key)):
			result[str(key)] = look[key]
	if not HAIR_STYLE_NAMES.has(str(result["hair"])):
		result["hair"] = "short"
	if not HAIR_COLORS.has(str(result["hair_color"])):
		result["hair_color"] = "brown"
	if not SKIN_TONES.has(str(result["skin"])):
		result["skin"] = "natural"
	if not FACE_SHAPE_NAMES.has(str(result["face"])):
		result["face"] = "oval"
	if not OUTFIT_NAMES.has(str(result["outfit"])):
		result["outfit"] = "casual"
	if not OUTFIT_COLORS.has(str(result["outfit_color"])):
		result["outfit_color"] = "blue"
	var accessories: Variant = result.get("accessories", {})
	if not (accessories is Dictionary):
		result["accessories"] = {"head": "", "face": "", "neck": "", "hand": "", "back": ""}
	return result


# ============================================================
# 基础绘制（坐标单位为 16px 像素格）
# ============================================================

static func rect(g: CanvasItem, x: float, y: float, w: float, h: float, color: Color) -> void:
	g.draw_rect(Rect2(x * U, y * U, w * U, h * U), color, true)


static func rrect(g: CanvasItem, x: float, y: float, w: float, h: float, r: float, color: Color) -> void:
	var rr := minf(r, minf(w, h) * 0.5)
	var rows := int(round(h))
	for row in rows:
		var yy := float(row) + 0.5
		var d := minf(yy, h - yy)
		var inset := 0.0
		if d < rr:
			var t := rr - d
			inset = rr - sqrt(maxf(0.0, rr * rr - t * t))
		var x0 := int(round(x + inset))
		var x1 := int(round(x + w - inset))
		if x1 > x0:
			g.draw_rect(Rect2(x0 * U, (y + row) * U, float(x1 - x0) * U, U), color, true)


static func ellipse(g: CanvasItem, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	var rows := int(ceil(ry))
	for row in range(-rows, rows + 1):
		var dy := float(row) + 0.5
		if absf(dy) > ry:
			continue
		var half := rx * sqrt(maxf(0.0, 1.0 - (dy * dy) / maxf(0.001, ry * ry)))
		var x0 := int(round(cx - half))
		var x1 := int(round(cx + half))
		if x1 > x0:
			g.draw_rect(Rect2(x0 * U, (cy + row) * U, float(x1 - x0) * U, U), color, true)


## 预绘制软阴影：两层低透明度椭圆叠加。
## 规范：光源右上，阴影左移 1px、下移 2px；使用深紫/深蓝（40% 不透明度叠层），
## 不用纯黑、不做死黑阴影。
static func shadow(g: CanvasItem, cx: float, cy: float, rx: float, ry: float) -> void:
	ellipse(g, cx - 1.0, cy + 2.0, rx, ry, Color(0.24, 0.21, 0.34, 0.22))
	ellipse(g, cx - 1.0, cy + 2.0, rx * 0.7, ry * 0.7, Color(0.22, 0.19, 0.32, 0.16))


## 冷色阴影（色相偏移）：向深紫蓝靠拢，而不是简单压黑。
static func shade_cool(color: Color, amount: float) -> Color:
	var t := clampf(amount, 0.0, 1.0)
	var tint := Color(0.30, 0.28, 0.46)
	return color.lerp(tint, t * 0.55).darkened(t * 0.30)


## 暖色高光（色相偏移）：向浅米黄靠拢，不直接用纯白。
static func tint_warm(color: Color, amount: float) -> Color:
	var t := clampf(amount, 0.0, 1.0)
	var warm := Color(1.0, 0.93, 0.76)
	return color.lerp(warm, t * 0.5).lightened(t * 0.12)


## 棋盘格抖动过渡：ratio 为 b 的占比，用于水岸 / 光斑等大面积渐变。
static func dither_band(
	g: CanvasItem, x: float, y: float, w: float, h: float,
	a: Color, b: Color, ratio: float
) -> void:
	var cols := int(ceil(w / U))
	var rows := int(ceil(h / U))
	var r := clampf(ratio, 0.0, 1.0)
	for row in rows:
		for col in cols:
			var threshold := float((col % 2) + (row % 2) * 2) / 4.0
			var color := b if r > threshold else a
			g.draw_rect(Rect2(
				x * U + float(col) * U, y * U + float(row) * U,
				float(U), float(U)
			), color, true)


static func hline(g: CanvasItem, x: float, y: float, w: float, color: Color) -> void:
	rect(g, x, y, w, 1.0, color)


static func vline(g: CanvasItem, x: float, y: float, h: float, color: Color) -> void:
	rect(g, x, y, 1.0, h, color)


static func reset_transform(g: CanvasItem) -> void:
	g.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## 16px 单位的多边形（用于屋顶等 45° 斜面）。
static func poly(g: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	var scaled := PackedVector2Array()
	for point: Vector2 in points:
		scaled.append(point * U)
	g.draw_colored_polygon(scaled, color)


## 像素化的斜线：只画水平/垂直台阶，避免抗锯齿。
static func stepped_line(g: CanvasItem, from: Vector2, to: Vector2, color: Color) -> void:
	var steps := int(maxf(absf(to.x - from.x), absf(to.y - from.y)))
	if steps <= 0:
		return
	for index in steps:
		var t := float(index) / float(steps)
		var point := from.lerp(to, t)
		rect(g, roundf(point.x), roundf(point.y), 1.0, 1.0, color)


# ============================================================
# 角色（Q 版小头身，16 单位高）
# ============================================================

static func draw_character(
	g: CanvasItem,
	look: Dictionary,
	facing: String,
	phase: float,
	moving: bool,
	origin := Vector2.ZERO,
	extra_scale := 1.0,
	hide_legs := false
) -> void:
	var n := normalize_look(look)
	var skin: Color = SKIN_TONES[str(n["skin"])]
	var hair: Color = HAIR_COLORS[str(n["hair_color"])]
	var outfit: Color = OUTFIT_COLORS[str(n["outfit_color"])]
	var style := str(n["hair"])
	var outfit_style := str(n["outfit"])
	var face_shape := str(n["face"])
	var female := str(n["gender"]) == "female"

	# 色相偏移：皮肤阴影偏紫、发色阴影偏冷、衣服暗部偏蓝紫
	var skin_dark := shade_cool(skin, 0.24)
	var hair_dark := shade_cool(hair, 0.38)
	var outfit_dark := shade_cool(outfit, 0.34)
	var pants := shade_cool(Color("#8b8076"), 0.18) if outfit_style != "work" else outfit_dark
	var shoe := shade_cool(Color("#7c6a54"), 0.30)

	# 4 帧行走循环 + 2 帧待机呼吸（文档：行走 4 帧、待机 2 帧）
	var frame := int(floor(phase)) % 4
	var walk_swing := [0.0, 0.75, 0.0, -0.75]
	var swing := float(walk_swing[frame]) if moving else 0.0
	var bob := 0.0
	if moving:
		bob = [0.0, 0.45, 0.0, 0.45][frame]
	else:
		# 待机呼吸：约 1px 上下起伏（16px 网格下 0.5 单位 = 1px）
		bob = 0.5 if int(floor(phase * 0.5)) % 2 == 0 else 0.0

	# origin / extra_scale 用于预览与头像放大；所有绘制仍走 16px 网格。
	# hide_legs：骑乘姿势，阴影交给坐骑，隐藏腿部。
	g.draw_set_transform(origin, 0.0, Vector2(extra_scale, extra_scale))
	if not hide_legs:
		shadow(g, 0, -0.4, 4.4, 1.4)
	g.draw_set_transform(
		origin + Vector2(0, -bob * extra_scale),
		0.0,
		Vector2(extra_scale * (-1.0 if facing == "left" else 1.0), extra_scale)
	)

	if not hide_legs:
		# 腿
		var leg_left := -swing
		var leg_right := swing
		rect(g, -2.8, -4.0 - maxf(0, leg_left), 2.2, 4.0 + minf(0, leg_left), pants)
		rect(g, 0.6, -4.0 - maxf(0, leg_right), 2.2, 4.0 + minf(0, leg_right), pants)
		rect(g, -3.1, -1.2 + maxf(0, leg_left), 2.7, 1.2, shoe)
		rect(g, 0.4, -1.2 + maxf(0, leg_right), 2.7, 1.2, shoe)

	# 躯干
	var body_w := 5.6 if female else 6.0
	var body_x := -body_w * 0.5
	var body_y := -9.0
	var body_h := 5.2
	_draw_outfit(g, outfit_style, outfit, outfit_dark, body_x, body_y, body_w, body_h)
	# 受光面（右上）暖色高光 / 背光面冷色，表现衣服体积
	rect(g, body_x + body_w - 0.5, body_y + 0.8, 0.5, body_h - 1.2,
		Color(tint_warm(outfit, 0.30), 0.55))
	rect(g, body_x, body_y + 0.8, 0.5, body_h - 1.2, Color(outfit_dark, 0.55))

	# 手臂
	var arm_swing := swing * 1.2
	rect(g, body_x - 1.5, body_y + 0.8 - arm_swing, 1.5, 3.6, outfit)
	rect(g, body_x + body_w, body_y + 0.8 + arm_swing, 1.5, 3.6, outfit)
	rect(g, body_x - 1.5, body_y + 4.0 - arm_swing, 1.5, 1.1, skin)
	rect(g, body_x + body_w, body_y + 4.0 + arm_swing, 1.5, 1.1, skin)

	# 背部件（背包 / 披风）：在身体后面
	_draw_accessories(g, n, "back", body_x, body_y, body_w, body_h, facing, phase, moving)

	# 脖子
	rect(g, -1.0, -9.4, 2.0, 0.6, skin_dark)

	# 头（按脸型调整）
	var head := _head_shape(face_shape)
	var hx: float = head["x"]
	var hy: float = head["y"]
	var hw: float = head["w"]
	var hh: float = head["h"]
	var hr: float = head["r"]

	rrect(g, hx, hy, hw, hh, hr, skin)
	# 耳朵
	if facing != "up":
		rect(g, hx - 0.9, hy + 3.6, 0.9, 2.0, skin_dark)
		rect(g, hx + hw, hy + 3.6, 0.9, 2.0, skin_dark)

	_draw_hair(g, style, hair, hair_dark, hx, hy, hw, hh, facing)

	# 面部 / 颈部饰品
	_draw_accessories(g, n, "face", hx, hy, hw, hh, facing)
	_draw_accessories(g, n, "neck", body_x, body_y, body_w, body_h, facing, phase, moving)

	if facing == "down":
		# 眼睛（1px 眼神高光）
		rect(g, hx + hw * 0.28, hy + hh * 0.48, 1.0, 1.4, INK)
		rect(g, hx + hw * 0.62, hy + hh * 0.48, 1.0, 1.4, INK)
		rect(g, hx + hw * 0.28 + 0.25, hy + hh * 0.48 + 0.2, 0.45, 0.45,
			Color(1.0, 0.96, 0.86, 0.80))
		rect(g, hx + hw * 0.62 + 0.25, hy + hh * 0.48 + 0.2, 0.45, 0.45,
			Color(1.0, 0.96, 0.86, 0.80))
		# 腮红（微红暖色）
		rect(g, hx + hw * 0.16, hy + hh * 0.66, 1.2, 0.8, Color(0.87, 0.58, 0.55, 0.50))
		rect(g, hx + hw * 0.72, hy + hh * 0.66, 1.2, 0.8, Color(0.87, 0.58, 0.55, 0.50))
		# 嘴
		rect(g, hx + hw * 0.46, hy + hh * 0.78, 1.0, 0.6, Color("#b87f6a"))
	elif facing == "right":
		rect(g, hx + hw * 0.66, hy + hh * 0.46, 1.0, 1.4, INK)
		rect(g, hx + hw * 0.86, hy + hh * 0.62, 0.9, 0.6, Color(0.82, 0.62, 0.55, 0.45))

	# 头部饰品最后画（帽子在最上层）
	_draw_accessories(g, n, "head", hx, hy, hw, hh, facing)

	reset_transform(g)


## 按部位绘制饰品。同部位只能一件，由存档层保证。
static func _draw_accessories(
	g: CanvasItem,
	look: Dictionary,
	slot: String,
	a: float, b: float, c: float, d: float,
	facing: String,
	phase := 0.0,
	moving := false
) -> void:
	var accessories: Dictionary = look.get("accessories", {})
	var item_id := str(accessories.get(slot, ""))
	if item_id.is_empty():
		return

	match item_id:
		"straw_hat":
			# 草帽：帽檐 + 帽顶
			rect(g, a - 1.6, b - 1.2, c + 3.2, 1.0, Color("#e5c065"))
			rect(g, a + 1.0, b - 3.0, c - 2.0, 1.8, Color("#d8ae52"))
			rect(g, a + 1.0, b - 3.0, c - 2.0, 0.5, Color("#f3d98e"))
			rect(g, a + 1.0, b - 1.6, c - 2.0, 0.6, Color("#9c6b3f"))
		"beret":
			rect(g, a + 0.4, b - 2.4, c - 0.8, 1.6, Color("#a97a8a"))
			rect(g, a + 0.4, b - 2.4, c - 0.8, 0.5, Color("#bf90a0"))
			rect(g, a + c * 0.5, b - 3.0, 0.8, 0.8, Color("#8f6474"))
		"flower_crown":
			for index in 4:
				var x := a + 0.6 + float(index) * (c - 1.2) / 3.0
				_disc(g, x, b - 0.6, 0.6, Color("#d29aa6") if index % 2 == 0 else Color("#f0e0a8"))
		"round_glasses":
			rect(g, a + 1.4, b + 2.8, 1.8, 1.2, Color("#8c6a4a"))
			rect(g, a + c - 3.2, b + 2.8, 1.8, 1.2, Color("#8c6a4a"))
			rect(g, a + 3.2, b + 3.2, c - 6.4, 0.4, Color("#8c6a4a"))
		"sunglasses":
			rect(g, a + 1.2, b + 2.8, 2.2, 1.4, Color("#5a5460"))
			rect(g, a + c - 3.4, b + 2.8, 2.2, 1.4, Color("#5a5460"))
		"scarf":
			rect(g, a, b - 0.2, c, 1.0, Color("#b57f74"))
			# 围巾尾端：走路时 2 帧摆动（规范：围巾/披风走路有 2 帧摆动）
			var sway := roundf(sin(phase * 3.0) * 0.7) if moving else 0.0
			rect(g, a + c - 1.2 + sway, b + 0.6, 1.0, 2.0, Color("#a26e63"))
			if moving:
				rect(g, a + c - 1.0 + sway, b + 2.6, 0.9, 1.0, Color("#96635a"))
		"pendant":
			rect(g, a + c * 0.5 - 0.4, b + 0.6, 0.8, 1.4, Color("#d8bd84"))
		"bracelet":
			rect(g, a + c, b + 3.4, 1.4, 0.6, Color("#c9a46a"))
		"gardening_gloves":
			rect(g, a - 1.5, b + 3.8, 1.5, 1.3, Color("#a8bd8a"))
			rect(g, a + c, b + 3.8, 1.5, 1.3, Color("#a8bd8a"))
		"small_backpack":
			rect(g, a - 1.0, b + 0.6, 1.4, c * 0.7, Color("#8c6a4a"))
			rect(g, a - 1.0, b + 0.6, 1.4, 0.6, Color("#a9825c"))
		"cape":
			# 披风：下摆随走路摆动 2 帧
			var hem := roundf(sin(phase * 3.0) * 1.0) if moving else 0.0
			rect(g, a - 1.2, b - 0.4, c + 2.4, d + 1.0, Color("#7a6a8a"))
			rect(g, a - 1.2 + hem, b + d + 0.4, c + 2.4, 0.8, Color("#6a5c7a"))
		_:
			pass


static func _disc(g: CanvasItem, cx: float, cy: float, r: float, color: Color) -> void:
	ellipse(g, cx, cy, r, r, color)


static func _head_shape(face_shape: String) -> Dictionary:
	match face_shape:
		"round":
			return {"x": -4.2, "y": -15.8, "w": 8.4, "h": 6.8, "r": 3.2}
		"square":
			return {"x": -4.1, "y": -16.0, "w": 8.2, "h": 6.6, "r": 2.2}
		"long":
			return {"x": -3.8, "y": -16.4, "w": 7.6, "h": 7.8, "r": 3.4}
		_:
			return {"x": -4.0, "y": -16.0, "w": 8.0, "h": 7.2, "r": 3.6}


static func _draw_hair(
	g: CanvasItem,
	style: String,
	hair: Color,
	hair_dark: Color,
	hx: float,
	hy: float,
	hw: float,
	hh: float,
	facing: String
) -> void:
	# 头顶基础发盖
	rrect(g, hx - 0.2, hy - 0.4, hw + 0.4, 3.0, 2.6, hair)
	# 发丝高光：本色浅色版，略偏暖白（光源右上）
	rect(g, hx + hw * 0.35, hy - 0.25, hw * 0.5, 0.5,
		Color(tint_warm(hair, 0.45), 0.90))

	match style:
		"buzz":
			rrect(g, hx, hy, hw, 1.8, 1.4, hair_dark)
		"long":
			rect(g, hx - 0.8, hy + 1.8, 1.6, hh + 0.5, hair)
			rect(g, hx + hw - 0.8, hy + 1.8, 1.6, hh + 0.5, hair)
			if facing == "up":
				rrect(g, hx - 0.2, hy - 0.4, hw + 0.4, hh + 1.2, 2.6, hair)
		"ponytail":
			rect(g, hx - 0.6, hy + 1.6, 1.4, 4.4, hair)
			rect(g, hx + hw - 0.8, hy + 1.6, 1.4, 4.4, hair)
			ellipse(g, hx + hw + 0.4, hy + 4.4, 1.6, 2.6, hair)
			rect(g, hx + hw - 0.2, hy + 1.8, 0.9, 1.2, hair_dark)
		"curly":
			ellipse(g, hx + 0.2, hy + 2.2, 1.8, 1.8, hair)
			ellipse(g, hx + hw - 0.2, hy + 2.2, 1.8, 1.8, hair)
			ellipse(g, hx - 0.6, hy + 4.0, 1.4, 1.4, hair)
			ellipse(g, hx + hw + 0.6, hy + 4.0, 1.4, 1.4, hair)
			rect(g, hx - 0.4, hy + 4.2, 1.0, 2.0, hair_dark)
			rect(g, hx + hw - 0.6, hy + 4.2, 1.0, 2.0, hair_dark)
		"bun":
			ellipse(g, hx + hw * 0.5, hy - 1.4, 2.0, 2.0, hair)
			rect(g, hx + hw * 0.35, hy - 0.4, 1.6, 1.2, hair_dark)
		"side_part":
			rect(g, hx, hy + 2.4, hw * 0.72, 1.6, hair)
			rect(g, hx + hw * 0.66, hy + 2.4, hw * 0.34, 0.9, hair_dark)
			rect(g, hx - 0.4, hy + 2.0, 1.2, 3.4, hair)
		"twin_tails":
			rect(g, hx - 0.7, hy + 1.8, 1.4, 4.0, hair)
			rect(g, hx + hw - 0.7, hy + 1.8, 1.4, 4.0, hair)
			ellipse(g, hx - 1.2, hy + 5.4, 1.4, 1.8, hair)
			ellipse(g, hx + hw + 1.2, hy + 5.4, 1.4, 1.8, hair)
			rect(g, hx - 1.6, hy + 3.0, 3.2, 0.8, hair_dark)
			rect(g, hx + hw - 1.6, hy + 3.0, 3.2, 0.8, hair_dark)
		_:
			# short
			rect(g, hx - 0.4, hy + 2.0, 1.2, 2.6, hair)
			rect(g, hx + hw - 0.8, hy + 2.0, 1.2, 2.6, hair)
			rect(g, hx + 0.6, hy + 2.2, hw * 0.7, 1.0, hair_dark)


static func _draw_outfit(
	g: CanvasItem,
	style: String,
	outfit: Color,
	outfit_dark: Color,
	x: float,
	y: float,
	w: float,
	h: float
) -> void:
	var light := tint_warm(outfit, 0.28)
	match style:
		"work":
			rrect(g, x, y, w, h, 1.4, Color("#efe6d2"))
			rect(g, x, y + 1.6, w, h - 1.6, outfit)
			rect(g, x + w * 0.24, y, 1.4, 2.4, outfit)
			rect(g, x + w * 0.62, y, 1.4, 2.4, outfit)
			rect(g, x + w * 0.28, y + 2.6, w * 0.44, 1.4, outfit_dark)
		"dress":
			rrect(g, x, y, w, 3.2, 1.4, outfit)
			rrect(g, x - 0.8, y + 2.6, w + 1.6, h - 2.4, 1.2, outfit)
			rect(g, x - 0.8, y + h - 1.4, w + 1.6, 0.8, outfit_dark)
			rect(g, x + w * 0.2, y, w * 0.6, 0.7, Color("#f6efdd"))
		"sport":
			rrect(g, x, y, w, h, 1.4, outfit)
			rect(g, x + w * 0.47, y, 0.7, h, light)
			rect(g, x, y, w, 1.0, outfit_dark)
			rect(g, x, y + h - 1.0, w, 1.0, outfit_dark)
		"retro":
			rrect(g, x, y, w, h, 1.4, Color("#efe6d2"))
			rect(g, x, y + 0.6, w * 0.26, h - 0.6, outfit)
			rect(g, x + w * 0.74, y + 0.6, w * 0.26, h - 0.6, outfit)
			rect(g, x + w * 0.42, y + 1.0, w * 0.16, w * 0.16, outfit_dark)
		"plain":
			rrect(g, x, y, w, h, 1.4, outfit)
			rect(g, x, y, w, 0.9, outfit_dark)
		_:
			# casual
			rrect(g, x, y, w, h, 1.4, outfit)
			rect(g, x + w * 0.32, y, w * 0.36, 0.9, Color("#f6efdd"))
			rect(g, x, y + h - 1.2, w, 1.2, outfit_dark)
			rect(g, x + w * 0.12, y + 2.0, w * 0.22, 1.2, outfit_dark)
