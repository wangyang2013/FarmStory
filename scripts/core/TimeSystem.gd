class_name TimeSystem
extends Node
## 游戏时间 / 季节 / 天气。
##
## 规则全部来自 config/environment.json（见 游戏时间.txt 最新版）：
##   - 06:00 开始新一天，一天 24 小时（到次日 06:00）
##   - 1 游戏分钟 = 0.7 现实秒
##   - 每季 30 天，四季循环
##   - 室内（房屋/鸡舍/畜棚/商店/矿洞/温泉）时间完全停止
##   - 背包/对话/钓鱼小游戏/剧情/菜单/挖矿时暂停
##   - 24:00 后睡觉体力恢复减少；熬夜太晚或体力耗尽会晕倒，次日起床延后
##
## 用法：
##     var time := TimeSystem.new()
##     add_child(time)
##     time.day_started.connect(_on_day_started)
##     time.enter_location("mine")   # 时间停止
##     time.leave_location()         # 恢复
##     time.set_context("fishing_minigame", true)

signal ticked(time_text: String, time_minutes: int)
signal hour_changed(hour: int)
signal day_started(info: Dictionary)
signal weather_changed(weather: String)
signal collapsed(reason: String)
## 时间走到次日 06:00（还没睡）。由场景决定播放晕倒流程，再调用 collapse()。
signal late_night

const DB := preload("res://scripts/core/ConfigDB.gd")

const SEASONS := ["spring", "summer", "autumn", "winter"]

var day := 1
var season := "spring"
var year := 1
var weather := "sunny"
## 当天已过的绝对分钟数：360 = 06:00，1440 = 次日 00:00，1800 = 次日 06:00。
var minutes := 360.0
var paused := false
var location_id := "farm"
## slow / normal / fast，对应 environment.json 的 speed_presets。
var speed_id := "normal"

var _start_minutes := 360
var _day_end_minutes := 1800
var _seconds_per_minute := 0.7
var _days_per_season := 30
var _contexts: Dictionary = {}
var _last_hour := -1
var _configured := false
var _transitioning := false
var _late_night_emitted := false
var _forced_collapse_emitted := false
var _forced_collapse_at := 1560
var _forced_collapse_enabled := false
var _collapse_reason := ""


func _ready() -> void:
	if not _configured:
		setup()
	set_process(true)


## 读取配置。可以重复调用（改完 JSON 后热重载）。
func setup() -> void:
	var cycle := DB.get_day_cycle()
	_start_minutes = int(cycle.get("start_minutes", 360))
	_day_end_minutes = DB.get_day_end_minutes()
	_seconds_per_minute = maxf(0.01, DB.get_real_seconds_per_game_minute(speed_id))
	_days_per_season = DB.get_days_per_season()
	_forced_collapse_at = DB.get_very_late_sleep_minutes() + 1440
	_forced_collapse_enabled = DB.is_forced_collapse_enabled()
	minutes = float(_start_minutes)
	_last_hour = get_hour()
	_configured = true


func _process(delta: float) -> void:
	advance(delta)


# ============================================================
# 时间推进
# ============================================================

## 推进游戏时间。delta 是现实秒。暂停时不做任何事。
func advance(delta: float) -> void:
	if is_time_paused() or _transitioning:
		return
	if delta <= 0.0:
		return

	minutes += delta / _seconds_per_minute

	# 02:00 强制晕倒默认关闭（新版时间表：熬夜只减少体力恢复，不打断游戏）。
	if _forced_collapse_enabled and not _forced_collapse_emitted \
			and minutes >= float(_forced_collapse_at):
		_forced_collapse_emitted = true
		_collapse_reason = "late_night"
		collapsed.emit("late_night")
		late_night.emit()
		return

	if minutes >= float(_day_end_minutes):
		minutes = float(_day_end_minutes)
		if not _late_night_emitted:
			_late_night_emitted = true
			late_night.emit()
		return

	var hour := get_hour()
	if hour != _last_hour:
		_last_hour = hour
		hour_changed.emit(hour)
	ticked.emit(get_clock_text(), int(minutes))


func is_time_paused() -> bool:
	if paused:
		return true
	for key: Variant in _contexts.keys():
		if bool(_contexts[key]):
			return true
	return DB.is_time_stopped_location(location_id)


func set_paused(value: bool) -> void:
	paused = value


## 切换时间流速：slow / normal / fast。
func set_speed_id(new_speed_id: String) -> void:
	var presets := DB.get_day_speed_presets()
	if presets.is_empty():
		return
	if not presets.has(new_speed_id):
		return
	speed_id = new_speed_id
	_seconds_per_minute = maxf(0.01, float(presets[new_speed_id]))


## 例如 set_context("fishing_minigame", true) / set_context("inventory", true)。
func set_context(context_id: String, active: bool) -> void:
	_contexts[context_id] = active


func clear_contexts() -> void:
	_contexts.clear()


## 进入室内地点（house / coop / barn / shop / mine / hot_spring）时间停止。
func enter_location(new_location_id: String) -> void:
	location_id = new_location_id


func leave_location() -> void:
	location_id = "farm"


func is_indoor() -> bool:
	return DB.is_time_stopped_location(location_id)


# ============================================================
# 显示
# ============================================================

## 0..1439，用于显示时钟（次日 00:00 显示为 00:00）。
func get_display_minutes() -> int:
	var value := int(floor(minutes))
	return posmod(value, 1440)


## 从第 1 年春季 1 日开始的绝对天数（0 起），用于委托有效期/建造天数。
func get_absolute_day() -> int:
	var seasons := ["spring", "summer", "autumn", "winter"]
	var season_index := maxi(0, seasons.find(season))
	return (year - 1) * 4 * _days_per_season + season_index * _days_per_season + (day - 1)


## 从第 1 年春季 1 日 06:00 起的绝对游戏分钟，用于加工机器计时。
func get_absolute_minutes() -> int:
	var seasons := ["spring", "summer", "autumn", "winter"]
	var season_index := maxi(0, seasons.find(season))
	return (((year - 1) * 4 + season_index) * _days_per_season + (day - 1)) * 1440 \
		+ int(floor(minutes))


func get_hour() -> int:
	return get_display_minutes() / 60


func get_clock_text() -> String:
	var display := get_display_minutes()
	return "%02d:%02d" % [display / 60, display % 60]


## 返回 "day" / "night" / "dawn_dusk"，供钓鱼等系统判断时段。
## 钓鱼时段（游戏时间对照表 9.1）：
##   晨昏 06:00–08:00 / 16:00–18:00
##   白天 08:00–16:00
##   夜晚 18:00–06:00
func get_time_of_day() -> String:
	var windows: Dictionary = DB.get_environment().get("time_of_day_windows", {})
	var display := get_display_minutes()
	if _in_window(display, windows.get("dawn", ["06:00", "08:00"])) 			or _in_window(display, windows.get("dusk", ["16:00", "18:00"])):
		return "dawn_dusk"
	if _in_window(display, windows.get("day", ["08:00", "16:00"])):
		return "day"
	return "night"


func get_season_name() -> String:
	return DB.season_name(season)


func get_weather_name() -> String:
	return DB.weather_name(weather)


func is_raining() -> bool:
	return weather == "rain" or weather == "storm"


func get_day_text() -> String:
	return "第 %d 年 · %s季 · %d 日" % [year, get_season_name(), day]


# ============================================================
# 睡觉 / 晕倒 / 换日
# ============================================================

## 回家睡觉。返回本次恢复体力的比例（18-24 点 100%，24-2 点 70%，2-6 点 40%）。
func sleep() -> float:
	if _transitioning:
		return 1.0
	var ratio := DB.get_sleep_stamina_ratio(minutes)
	_start_next_day(0, ratio, false, "sleep")
	return ratio


## 晕倒。reason: "late_night" / "exhausted"。
func collapse(reason := "late_night") -> void:
	if _transitioning:
		return
	var rules := DB.get_sleep_rules()
	if reason == "late_night" and not bool(rules.get("collapse_on_late_night", true)):
		return
	if reason == "exhausted" and not bool(rules.get("collapse_on_exhaustion", true)):
		return

	var delay := int(rules.get("collapse_wake_delay_minutes", 120)) \
		if bool(rules.get("delayed_wake_on_collapse", true)) else 0
	var ratio := float(rules.get("collapse_stamina_ratio", 0.5))

	collapsed.emit(reason)
	_start_next_day(delay, ratio, true, reason)


func _start_next_day(wake_delay_minutes: int, stamina_ratio: float, was_collapse: bool, reason: String) -> void:
	_transitioning = true

	day += 1
	var season_changed := false
	if day > _days_per_season:
		day = 1
		var index := SEASONS.find(season)
		index = (index + 1) % SEASONS.size()
		season = SEASONS[index]
		season_changed = true
		if index == 0:
			year += 1

	var previous_weather := weather
	weather = _roll_weather()
	minutes = float(_start_minutes + maxi(0, wake_delay_minutes))
	_last_hour = get_hour()
	_late_night_emitted = false
	_forced_collapse_emitted = false

	day_started.emit({
		"day": day,
		"season": season,
		"year": year,
		"weather": weather,
		"stamina_ratio": stamina_ratio,
		"was_collapse": was_collapse,
		"reason": reason,
		"wake_minutes": int(minutes),
		"raining": is_raining(),
		"season_changed": season_changed,
	})
	if weather != previous_weather:
		weather_changed.emit(weather)

	_transitioning = false


## 每次天气 roll 都新建 RNG，不与其他系统共用随机序列。
func _roll_weather() -> String:
	var weights := DB.get_weather_weights(season)
	if weights.is_empty():
		return "sunny"

	var total := 0
	for value: Variant in weights.values():
		total += maxi(0, int(value))
	if total <= 0:
		return "sunny"

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var roll := rng.randi_range(1, total)
	for key: Variant in weights.keys():
		roll -= maxi(0, int(weights[key]))
		if roll <= 0:
			return str(key)
	return "sunny"


# ============================================================
# 存档
# ============================================================

func to_save() -> Dictionary:
	return {
		"day": day,
		"season": season,
		"year": year,
		"weather": weather,
		"time_minutes": int(minutes),
		"location": location_id,
		"speed": speed_id,
	}


func from_save(data: Dictionary) -> void:
	day = clampi(int(data.get("day", 1)), 1, _days_per_season)
	year = maxi(1, int(data.get("year", 1)))
	var saved_season := str(data.get("season", "spring"))
	season = saved_season if saved_season in SEASONS else "spring"
	var saved_weather := str(data.get("weather", "sunny"))
	weather = saved_weather if saved_weather in ["sunny", "rain", "storm", "snow", "blizzard"] else "sunny"
	minutes = clampf(
		float(data.get("time_minutes", _start_minutes)),
		float(_start_minutes),
		float(_day_end_minutes - 1)
	)
	location_id = str(data.get("location", "farm"))
	speed_id = str(data.get("speed", "normal"))
	if not DB.get_day_speed_presets().has(speed_id):
		speed_id = "normal"
	_seconds_per_minute = maxf(0.01, DB.get_real_seconds_per_game_minute(speed_id))
	_forced_collapse_emitted = minutes >= float(_forced_collapse_at)
	_last_hour = get_hour()


# ============================================================
# 内部
# ============================================================

func _time_to_minutes(text: String) -> float:
	var parts := text.split(":")
	if parts.size() != 2:
		return 0.0
	var hour := int(parts[0].to_int())
	var minute := int(parts[1].to_int())
	return float(hour * 60 + minute)


func _in_window(value: int, window: Variant) -> bool:
	if not (window is Array) or (window as Array).size() != 2:
		return false
	var start := int(_time_to_minutes(str(window[0])))
	var end := int(_time_to_minutes(str(window[1])))
	if start <= end:
		return value >= start and value < end
	# 跨午夜，例如 20:00–05:00
	return value >= start or value < end
