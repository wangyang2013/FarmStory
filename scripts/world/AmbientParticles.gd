class_name AmbientParticles
extends Node2D
## 环境粒子：春夏花瓣/花粉、秋季落叶、夜晚萤火虫。
## 跟随相机视野循环，不参与 Y-sort；雨雪天气交给 WeatherSystem。

const COUNT := 20

var farm
var _t := 0.0
var _seeds: Array[float] = []


func _ready() -> void:
	z_index = 12
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for index in COUNT:
		_seeds.append(rng.randf())


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if farm == null or farm.player == null or farm.camera == null:
		return
	var weather: String = str(farm.time.weather)
	if weather in ["rain", "storm", "snow", "blizzard"]:
		return
	var season: String = str(farm.time.season)
	if season == "winter":
		return
	var display: int = int(farm.time.get_display_minutes())
	var is_night: bool = display >= 20 * 60 or display < 6 * 60
	if is_night:
		_draw_stars()
		_draw_fireflies()
		return
	# 清晨薄雾（5:00-7:00）
	if display >= 300 and display < 420:
		_draw_morning_mist()

	var zoom: Vector2 = farm.camera.zoom
	var view: Vector2 = get_viewport_rect().size / zoom + Vector2(80.0, 80.0)
	var center: Vector2 = farm.player.position
	var half: Vector2 = view * 0.5
	var color: Color = Color("#f2c4d6")  # 春季花瓣
	var fall: float = 14.0
	var size := Vector2(2.0, 1.0)
	if season == "summer":
		color = Color("#e8e0b0")  # 花粉
		fall = 7.0
		size = Vector2(1.0, 1.0)
	elif season == "autumn":
		color = Color("#d9a05e")  # 落叶
		fall = 24.0
		size = Vector2(2.0, 2.0)

	for index in COUNT:
		var seed := _seeds[index]
		var x: float = fposmod(seed * view.x + _t * 9.0 + float(index) * 37.0,
			view.x) - half.x + center.x
		var y: float = fposmod(seed * view.y + _t * fall + float(index) * 53.0,
			view.y) - half.y + center.y
		x += sin(_t * 1.1 + float(index)) * 3.0
		var alpha: float = 0.35 + 0.25 * sin(_t * 1.7 + float(index))
		draw_rect(Rect2(roundf(x), roundf(y), size.x, size.y),
			Color(color.r, color.g, color.b, alpha))


## 夜晚星空：屏幕上的稀疏星点，亮度呼吸（规范：夜晚天空有星星）。
func _draw_stars() -> void:
	var view := get_viewport_rect().size
	for index in 18:
		var seed := _seeds[index % _seeds.size()]
		var x := fmod(seed * 977.0 + float(index) * 53.0, view.x)
		var y := fmod(seed * 613.0 + float(index) * 37.0, view.y * 0.55)
		var twinkle := 0.35 + 0.5 * absf(sin(_t * 1.2 + float(index) * 1.9))
		draw_rect(Rect2(roundf(x), roundf(y), 1.0, 1.0),
			Color(0.95, 0.96, 1.0, twinkle))


## 清晨薄雾：屏幕底部一层极淡的暖白雾气。
func _draw_morning_mist() -> void:
	var view := get_viewport_rect().size
	for index in 4:
		var y := view.y * (0.5 + float(index) * 0.12)
		var drift := sin(_t * 0.25 + float(index)) * 30.0
		draw_rect(Rect2(drift - 40.0, y, view.x + 80.0, view.y * 0.12),
			Color(0.96, 0.97, 0.99, 0.05))


## 夜晚萤火虫：缓慢漂浮的暖黄像素点，亮度呼吸。
func _draw_fireflies() -> void:
	var zoom: Vector2 = farm.camera.zoom
	var view: Vector2 = get_viewport_rect().size / zoom + Vector2(60.0, 60.0)
	var center: Vector2 = farm.player.position
	var half: Vector2 = view * 0.5
	for index in 12:
		var seed := _seeds[index]
		var x: float = fposmod(seed * view.x + sin(_t * 0.4 + float(index)) * 12.0,
			view.x) - half.x + center.x
		var y: float = fposmod(seed * view.y + cos(_t * 0.5 + float(index)) * 10.0,
			view.y) - half.y + center.y
		var pulse: float = 0.35 + 0.55 * absf(sin(_t * 1.4 + float(index) * 1.7))
		draw_rect(Rect2(roundf(x), roundf(y), 1.0, 1.0),
			Color(0.96, 0.84, 0.42, pulse))
