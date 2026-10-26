class_name WeatherSystem
extends Control
## 天气视觉（云、风、雨涟漪、闪电、积雪）。
##
## 按《角色NPC动植物物品饰品矿石化石天气设计要求》第九章：
##   - 云朵在背景层横向循环移动，不参与 Y-sort
##   - 天气切换时云朵 modulate 渐变
##   - 雨滴跟随相机，地面随机涟漪
##   - 暴雨时随机闪电，全屏闪白 0.1 秒，雷声延迟播放
##   - 雪天雪花跟随相机，地面积雪用色调表现
##   - 所有效果提供「减弱特效」选项（AudioManager.settings.reduce_effects）
##
## 本节点挂在 Farm 的天气层下，只负责绘制，不改玩法状态。

signal lightning_struck

const Art := preload("res://scripts/art/PixelArt.gd")

const CLOUD_COUNT := 6
const RAIN_DROPS := 110
const SNOW_FLAKES := 90
const RIPPLE_COUNT := 8

var farm

var _time := 0.0
var _wind_direction := 1.0      # -1 左，1 右
var _wind_strength := 1.0       # 0.5 弱 / 1.0 中 / 1.6 强
var _cloud_seed: Array[float] = []
var _rain_seed: Array[float] = []
var _snow_seed: Array[float] = []
var _ripples: Array = []
var _flash := 0.0
var _next_lightning := 12.0
var _thunder_timer := -1.0
var _footprints: Array = []
var _last_foot_pos := Vector2.INF


func setup(p_farm: Node) -> void:
	farm = p_farm
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for index in CLOUD_COUNT:
		_cloud_seed.append(rng.randf())
	for index in RAIN_DROPS:
		_rain_seed.append(rng.randf())
	for index in SNOW_FLAKES:
		_snow_seed.append(rng.randf())
	for index in RIPPLE_COUNT:
		_ripples.append({"x": 0.0, "y": 0.0, "life": 0.0, "max": 1.0})


func _process(delta: float) -> void:
	_time += delta
	_update_wind()
	_update_ripples(delta)
	_update_lightning(delta)
	_update_thunder(delta)
	_update_footprints(delta)
	queue_redraw()


func _update_wind() -> void:
	if farm == null or farm.time == null:
		return
	# 风向 / 风力来自天气本身：暴雨暴雪更强
	match str(farm.time.weather):
		"storm":
			_wind_strength = 1.7
		"blizzard":
			_wind_strength = 2.2
		"snow":
			_wind_strength = 1.1
		"rain":
			_wind_strength = 1.2
		_:
			_wind_strength = 0.8
	_wind_direction = 1.0


func _update_ripples(delta: float) -> void:
	if farm == null or farm.time == null:
		return
	var raining: bool = str(farm.time.weather) in ["rain", "storm"]
	if not raining:
		return
	var bounds := get_viewport_rect().size
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for ripple: Dictionary in _ripples:
		ripple["life"] = maxf(0.0, float(ripple["life"]) - delta)
		if float(ripple["life"]) <= 0.0:
			ripple["x"] = rng.randf() * bounds.x
			ripple["y"] = rng.randf() * bounds.y
			ripple["max"] = 0.35 + rng.randf() * 0.3
			ripple["life"] = ripple["max"]


func _update_lightning(delta: float) -> void:
	if farm == null or farm.time == null:
		return
	if str(farm.time.weather) != "storm":
		return
	if _effects_reduced():
		return
	_next_lightning -= delta
	if _next_lightning <= 0.0:
		_next_lightning = 10.0 + randf() * 20.0
		_flash = 1.0
		_thunder_timer = 0.5 + randf() * 0.5
		lightning_struck.emit()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta / 0.1)


func _update_thunder(delta: float) -> void:
	if _thunder_timer < 0.0:
		return
	_thunder_timer -= delta
	if _thunder_timer <= 0.0:
		_thunder_timer = -1.0
		if AudioManager != null:
			AudioManager.play_sfx("storm_thunder")


func _effects_reduced() -> bool:
	if AudioManager == null:
		return false
	return bool(AudioManager.get_setting("reduce_effects", false))


# ============================================================
# 绘制
# ============================================================

func _draw() -> void:
	if farm == null or farm.time == null:
		return
	if farm.indoor or farm.in_mine:
		return

	var bounds := get_viewport_rect().size
	var weather := str(farm.time.weather)
	var reduced := _effects_reduced()

	# 云影：晴天/多云也有缓慢横移的半透明云影（规范：云朵横移 + 地面云影）
	if not reduced and weather in ["sunny", "rain", "storm"]:
		_draw_cloud_shadows(bounds, weather)

	# 云朵：晴天少量白云，阴雨/暴雨更密更低。
	if not reduced:
		_draw_clouds(bounds, weather)

	# 雨 / 雪
	if weather in ["rain", "storm"]:
		_draw_rain(bounds, weather == "storm")
		_draw_ripples()
		if not reduced:
			_draw_eave_drips(bounds)
	elif weather in ["snow", "blizzard"]:
		var blizzard := weather == "blizzard"
		_draw_snow(bounds, blizzard)
		_draw_footprints()
		if not reduced:
			# 雪天薄雾 / 暴雪浓白雾层（纯色半透明，不做发光）
			var fog_alpha := 0.16 if blizzard else 0.06
			draw_rect(Rect2(Vector2.ZERO, bounds),
				Color(0.94, 0.97, 1.0, fog_alpha), true)
			if blizzard:
				_draw_blizzard_streaks(bounds)

	# 闪电闪白
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, bounds), Color(1, 1, 0.96, _flash * 0.55), true)

	# 暴雨暗角
	if weather == "storm" and not reduced:
		_draw_vignette(bounds, 0.28)


func _draw_clouds(bounds: Vector2, weather: String) -> void:
	var is_gloomy := weather in ["rain", "storm"]
	var count := CLOUD_COUNT if not is_gloomy else CLOUD_COUNT + 2
	var base_color := Color(0.96, 0.96, 0.94, 0.55) if not is_gloomy \
		else Color(0.72, 0.75, 0.78, 0.62)
	# 晴天只保留少量淡云，避免"白斑"感
	if weather == "sunny":
		count = 3
		base_color = Color(0.98, 0.98, 0.96, 0.34)

	for index in count:
		var seed := _cloud_seed[index % _cloud_seed.size()]
		var width := 22.0 + seed * 26.0
		var speed := 4.5 * _wind_strength * (0.6 + seed * 0.8)
		var x := fmod(seed * bounds.x + _time * speed + float(index) * 137.0, bounds.x + width * 2.0) - width
		# 云只出现在屏幕顶部 1/3，避免看起来像地上的白斑
		# 只压在屏幕最上方 26px 的窄带，像低垂的雨云
		var y := 2.0 + fmod(seed * 311.0 + float(index) * 47.0, 24.0)

		# 云朵：3~4 个柔和圆团拼成，无描边
		_draw_cloud(x, y, width, base_color)


## 像素云：中间厚、两端薄的一团，底部压平，不用纯矩形。
## 地面云影：3 团半透明暗色椭圆缓慢横移，制造"云从头顶飘过"的层次。
func _draw_cloud_shadows(bounds: Vector2, weather: String) -> void:
	var count := 2
	var alpha := 0.026 if weather == "sunny" else 0.04
	for index in count:
		var seed := _cloud_seed[index % _cloud_seed.size()]
		var width := 46.0 + seed * 52.0
		var x := fmod(seed * bounds.x + _time * 9.0 * _wind_strength
			+ float(index) * 320.0, bounds.x + width * 2.0) - width
		var y := bounds.y * (0.22 + seed * 0.55)
		# 椭圆云影：两团叠加，边缘柔和但不压暗画面
		draw_set_transform(Vector2(x + width * 0.5, y), 0.0, Vector2(1.0, 0.26))
		draw_circle(Vector2.ZERO, width * 0.5, Color(0.16, 0.18, 0.28, alpha))
		draw_circle(Vector2(width * 0.3, 8.0), width * 0.3,
			Color(0.16, 0.18, 0.28, alpha * 0.6))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_cloud(x: float, y: float, width: float, color: Color) -> void:
	var px := roundf(x)
	var py := roundf(y)
	var w := roundf(width)
	# 云体：三行，宽度依次收窄
	var row_h := 3.0
	draw_rect(Rect2(px + w * 0.18, py, w * 0.64, row_h), color, true)
	draw_rect(Rect2(px + w * 0.06, py + row_h, w * 0.88, row_h), color, true)
	draw_rect(Rect2(px, py + row_h * 2.0, w, row_h), color, true)
	# 顶部小凸起
	draw_rect(Rect2(px + w * 0.34, py - row_h * 0.6, w * 0.22, row_h * 0.6), color, true)
	draw_rect(Rect2(px + w * 0.56, py - row_h * 0.3, w * 0.16, row_h * 0.3), color, true)
	# 底部阴影（柔和，不加深太多）
	var shade := color.darkened(0.06)
	draw_rect(Rect2(px + w * 0.10, py + row_h * 3.0, w * 0.78, 1.0), shade, true)


func _draw_rain(bounds: Vector2, heavy: bool) -> void:
	var count := RAIN_DROPS if heavy else int(RAIN_DROPS * 0.6)
	var speed := 900.0 if heavy else 620.0
	var tilt := 4.0 * _wind_strength
	var color := Color(0.75, 0.85, 1.0, 0.42 if heavy else 0.35)

	for index in count:
		var seed := _rain_seed[index]
		var x := fmod(seed * bounds.x + _time * 150.0 * _wind_strength, bounds.x)
		var y := fmod(seed * 733.0 + _time * speed, bounds.y)
		draw_line(Vector2(x, y), Vector2(x - tilt, y + 12.0), color, 1.2)


func _draw_ripples() -> void:
	for ripple: Dictionary in _ripples:
		var life := float(ripple["life"])
		if life <= 0.0:
			continue
		var max_life: float = float(ripple["max"])
		var t := 1.0 - life / max_life
		var radius := 3.0 + t * 9.0
		var alpha := (1.0 - t) * 0.35
		draw_arc(
			Vector2(float(ripple["x"]), float(ripple["y"])),
			radius, 0.0, TAU, 20,
			Color(0.80, 0.88, 0.96, alpha), 1.2
		)


func _draw_snow(bounds: Vector2, heavy := false) -> void:
	var count := SNOW_FLAKES
	if heavy:
		count = int(SNOW_FLAKES * 1.7)
	if _effects_reduced():
		count = int(float(count) * 0.4)
	var speed_base := 58.0 if heavy else 34.0
	var alpha := 0.9 if heavy else 0.78
	for index in count:
		var seed := _snow_seed[index % _snow_seed.size()]
		var drift := sin(_time * 0.8 + float(index)) * 18.0 * _wind_strength
		var x := fmod(seed * bounds.x + drift + bounds.x, bounds.x)
		var y := fmod(seed * 911.0 + _time * (speed_base + seed * 26.0), bounds.y)
		var radius := (1.4 + seed * 1.4) * (1.25 if heavy else 1.0)
		draw_circle(Vector2(x, y), radius, Color(0.96, 0.98, 0.97, alpha))


## 暴雪白毛风：横向半透明白色风带。
func _draw_blizzard_streaks(bounds: Vector2) -> void:
	for index in 7:
		var seed := _snow_seed[(index * 5) % _snow_seed.size()]
		var y := fmod(seed * bounds.y + _time * 26.0, bounds.y)
		var x := fmod(seed * bounds.x + _time * 140.0, bounds.x)
		var width := 26.0 + seed * 30.0
		draw_rect(Rect2(x, y, width, 1.0), Color(0.96, 0.98, 1.0, 0.22), true)


## 雪地脚印：玩家每走约 14px 留下一只，6 秒内逐渐淡出。
func _update_footprints(delta: float) -> void:
	for fp: Dictionary in _footprints:
		fp["life"] = float(fp["life"]) - delta
	var alive: Array = []
	for fp: Dictionary in _footprints:
		if float(fp["life"]) > 0.0:
			alive.append(fp)
	_footprints = alive

	if farm == null or farm.player == null or farm.time == null:
		return
	var weather := str(farm.time.weather)
	if weather != "snow" and weather != "blizzard":
		_last_foot_pos = farm.player.position
		return
	var pos: Vector2 = farm.player.position
	if _last_foot_pos == Vector2.INF:
		_last_foot_pos = pos
		return
	if pos.distance_to(_last_foot_pos) < 14.0:
		return
	_last_foot_pos = pos
	_footprints.append({
		"x": pos.x, "y": pos.y + 2.0, "life": 6.0, "max": 6.0,
		"left": _footprints.size() % 2 == 0,
	})
	if _footprints.size() > 60:
		_footprints.pop_front()


func _draw_footprints() -> void:
	if farm == null or farm.camera == null:
		return
	var cam_pos: Vector2 = farm.camera.get_screen_center_position()
	var zoom: Vector2 = farm.camera.zoom
	var center: Vector2 = get_viewport_rect().size * 0.5
	for fp: Dictionary in _footprints:
		var life := float(fp["life"]) / float(fp["max"])
		var world := Vector2(float(fp["x"]), float(fp["y"]))
		var screen: Vector2 = (world - cam_pos) * zoom + center
		var side := -1.5 if bool(fp.get("left", false)) else 1.5
		draw_rect(Rect2(screen.x + side, screen.y, 2.0, 1.0),
			Color(0.62, 0.70, 0.76, 0.32 * life))


## 屋檐滴水：雨天时在屏幕上方随机位置落下水滴并留下小水花。
func _draw_eave_drips(bounds: Vector2) -> void:
	for index in 5:
		var seed := _rain_seed[(index * 7) % _rain_seed.size()]
		var cycle := fmod(_time * 0.55 + seed, 1.0)
		var x := seed * bounds.x
		# 只在屏幕上部 1/3 建筑檐口高度附近滴水
		var top := bounds.y * 0.22 + seed * 12.0
		var y := top + cycle * 22.0
		draw_rect(Rect2(roundf(x), roundf(y), 1.0, 2.0),
			Color(0.82, 0.90, 0.98, 0.34))
		if cycle > 0.92:
			draw_arc(Vector2(x, top + 23.0), 1.6, 0.0, TAU, 6,
				Color(0.82, 0.90, 0.98, 0.24), 1.0)


func _draw_vignette(bounds: Vector2, strength: float) -> void:
	# 四边柔和暗角：用四条半透明渐变带，不做大面积渐变
	var band := 70.0
	for index in 6:
		var t := float(index) / 6.0
		var alpha := strength * (1.0 - t) * 0.16
		var offset := band * t
		draw_rect(Rect2(0, offset, bounds.x, 6), Color(0.06, 0.08, 0.12, alpha), true)
		draw_rect(Rect2(0, bounds.y - offset - 6, bounds.x, 6), Color(0.06, 0.08, 0.12, alpha), true)
		draw_rect(Rect2(offset, 0, 6, bounds.y), Color(0.06, 0.08, 0.12, alpha), true)
		draw_rect(Rect2(bounds.x - offset - 6, 0, 6, bounds.y), Color(0.06, 0.08, 0.12, alpha), true)
