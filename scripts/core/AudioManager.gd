extends Node
## 音频管理（Autoload：AudioManager）。
##
## 按《个人单机开发要求》第 6 章与《音乐BGM要求》实现：
##   - 音频总线：Master / BGM / SFX / UI / Ambient
##   - BGM 按场景键名播放，切换时淡出淡入（默认 0.8 秒）
##   - 同一首 BGM 不重复从头播放
##   - SFX 按名字播放，短时间重复会节流
##   - 音量设置存 settings.json，与存档分开
##   - 对话时 BGM 自动降低音量（ducking）
##   - 新增音频只需在 BGM_KEY / SFX_KEY 里登记键名，不改播放逻辑
##
## 注意：当前工程还没有音频素材。所有播放接口在资源缺失时安全退化为静默，
## 放入 res://audio/ 下的对应文件后会自动生效。

const SETTINGS_PATH := "user://settings.json"
const BGM_DIR := "res://audio/bgm/"
const SFX_DIR := "res://audio/sfx/"
const FADE_TIME := 0.8
const DUCK_DB := -6.0

## BGM 场景键名 → 文件名（不含扩展名）。
const BGM_KEYS := {
	"spring": "bgm_spring",
	"summer": "bgm_summer",
	"autumn": "bgm_autumn",
	"winter": "bgm_winter",
	"town": "bgm_town",
	"farm": "bgm_farm",
	"mine": "bgm_mine",
	# 夜晚复用冬季的安静曲，室内复用春季的舒缓曲，避免重复下载同一风格素材。
	"night": "bgm_winter",
	"festival": "bgm_festival",
	"indoor": "bgm_spring",
}

## SFX 键名 → 文件名（不含扩展名）。
const SFX_KEYS := {
	"till": "sfx_till",
	"water": "sfx_water",
	"plant": "sfx_plant",
	"harvest": "sfx_harvest",
	"coin": "sfx_coin",
	"error": "sfx_error",
	"click": "sfx_ui_click",
	"feed": "sfx_feed",
	"sleep": "sfx_sleep",
	"fish_bite": "sfx_fish_bite",
	"fish_catch": "sfx_fish_catch",
	"footstep": "sfx_footstep",
	"storm_thunder": "sfx_thunder",
}

const DEFAULT_SETTINGS := {
	"master_volume": 1.0,
	"bgm_volume": 0.8,
	"sfx_volume": 1.0,
	"ui_volume": 0.8,
	"ambient_volume": 0.6,
	"time_speed": "normal",
	"window_mode": "windowed",
	"reduce_effects": false,
}

var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)

var _bgm_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _current_bgm := ""
var _bgm_tween: Tween
var _sfx_cooldown: Dictionary = {}
var _cache: Dictionary = {}
var _bus_ready := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_setup_players()
	load_settings()
	apply_volumes()


# ============================================================
# 总线 / 播放器
# ============================================================

func _setup_buses() -> void:
	for bus_name: String in ["BGM", "SFX", "UI", "Ambient"]:
		if AudioServer.get_bus_index(bus_name) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, "Master")
	_bus_ready = true


func _setup_players() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "BGM"
	add_child(_bgm_player)

	# 一组复用的 SFX 播放器，避免频繁创建节点
	for index in 8:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)


# ============================================================
# BGM
# ============================================================

## 播放 BGM。key 见 BGM_KEYS。同一首不会重复播放。
func play_bgm(key: String, fade_time := FADE_TIME) -> void:
	if key == _current_bgm:
		return
	var stream := _load_bgm(key)
	_current_bgm = key
	if stream == null:
		# 没有素材时静默跳过，但记录当前键名
		if _bgm_tween != null and _bgm_tween.is_valid():
			_bgm_tween.kill()
		_bgm_player.stop()
		return

	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()

	var target_db := _bus_target_db("BGM")
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", -40.0, fade_time * 0.5)
	_bgm_tween.tween_callback(func() -> void:
		_bgm_player.stream = stream
		_bgm_player.volume_db = -40.0
		_bgm_player.play()
	)
	_bgm_tween.tween_property(_bgm_player, "volume_db", target_db, fade_time * 0.5)


func stop_bgm(fade_time := FADE_TIME) -> void:
	_current_bgm = ""
	if _bgm_tween != null and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", -40.0, fade_time)
	_bgm_tween.tween_callback(func() -> void: _bgm_player.stop())


func get_current_bgm() -> String:
	return _current_bgm


## 对话等场景：临时压低 BGM。
func duck_bgm(active: bool) -> void:
	if _bgm_player.stream == null:
		return
	var target := _bus_target_db("BGM") + (DUCK_DB if active else 0.0)
	var tween := create_tween()
	tween.tween_property(_bgm_player, "volume_db", target, 0.3)


## 根据季节 / 时间 / 地点挑选 BGM 键名。
func resolve_bgm_key(season: String, is_night: bool, location_id := "farm") -> String:
	if location_id == "mine":
		return "mine"
	if location_id in ["house", "coop", "barn", "shop", "hot_spring"]:
		return "indoor"
	if is_night:
		return "night"
	if season in ["spring", "summer", "autumn", "winter"]:
		return season
	return "farm"


func _load_bgm(key: String) -> AudioStream:
	var file_key := str(BGM_KEYS.get(key, key))
	var cache_key := "bgm:" + file_key
	if _cache.has(cache_key):
		return _cache[cache_key]
	for extension: String in [".ogg", ".wav", ".mp3"]:
		var path := BGM_DIR + file_key + extension
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			if stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
			elif stream is AudioStreamMP3:
				(stream as AudioStreamMP3).loop = true
			_cache[cache_key] = stream
			return stream
	_cache[cache_key] = null
	return null


# ============================================================
# SFX
# ============================================================

## 播放音效。key 见 SFX_KEYS。同一个音效 60ms 内重复会被忽略。
func play_sfx(key: String, pitch_variation := 0.0, bus := "SFX") -> void:
	var now := Time.get_ticks_msec()
	var last := int(_sfx_cooldown.get(key, -1000))
	if now - last < 60:
		return
	_sfx_cooldown[key] = now

	var stream := _load_sfx(key)
	if stream == null:
		return

	var player := _next_sfx_player()
	if player == null:
		return
	player.bus = bus
	player.stream = stream
	var base_pitch := 1.0
	if pitch_variation > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		base_pitch = 1.0 + rng.randf_range(-pitch_variation, pitch_variation)
	player.pitch_scale = base_pitch
	player.play()


func play_ui_click() -> void:
	play_sfx("click", 0.02, "UI")


func _next_sfx_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _sfx_players:
		if not player.playing:
			return player
	return _sfx_players[0] if not _sfx_players.is_empty() else null


func _load_sfx(key: String) -> AudioStream:
	var file_key := str(SFX_KEYS.get(key, key))
	var cache_key := "sfx:" + file_key
	if _cache.has(cache_key):
		return _cache[cache_key]
	for extension: String in [".ogg", ".wav"]:
		var path := SFX_DIR + file_key + extension
		if ResourceLoader.exists(path):
			var stream: AudioStream = load(path)
			_cache[cache_key] = stream
			return stream
	_cache[cache_key] = null
	return null


# ============================================================
# 音量
# ============================================================

func set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(clampf(linear, 0.0, 1.0)))


func get_bus_volume(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(index))


func apply_volumes() -> void:
	set_bus_volume("Master", float(settings.get("master_volume", 1.0)))
	set_bus_volume("BGM", float(settings.get("bgm_volume", 0.8)))
	set_bus_volume("SFX", float(settings.get("sfx_volume", 1.0)))
	set_bus_volume("UI", float(settings.get("ui_volume", 0.8)))
	set_bus_volume("Ambient", float(settings.get("ambient_volume", 0.6)))
	if _bgm_player != null and _bgm_player.playing:
		_bgm_player.volume_db = _bus_target_db("BGM")


func _bus_target_db(bus_name: String) -> float:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return 0.0
	return AudioServer.get_bus_volume_db(index)


func set_volume(kind: String, linear: float) -> void:
	settings[kind + "_volume"] = clampf(linear, 0.0, 1.0)
	apply_volumes()
	save_settings()


# ============================================================
# 设置持久化（与存档分开）
# ============================================================

func load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		push_warning("[AudioManager] settings.json 解析失败，使用默认设置。")
		return
	for key: Variant in json.data.keys():
		if DEFAULT_SETTINGS.has(str(key)):
			settings[str(key)] = json.data[key]


func save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(settings, "\t", false, true))
	file.flush()
	file.close()


func get_setting(key: String, fallback: Variant = null) -> Variant:
	return settings.get(key, fallback)


func set_setting(key: String, value: Variant) -> void:
	settings[key] = value
	save_settings()
