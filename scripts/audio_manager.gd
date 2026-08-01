extends Node

const SFX := {
	"click": "click",
	"place": "place",
	"merge": "merge",
	"hit": "hit",
	"tower": "tower",
	"victory": "victory",
	"defeat": "defeat",
	"era": "era",
	"button": "button",
	"card_locked": "card_locked",
	"card_jam": "card_jam",
	"tower_alarm": "tower_alarm",
	"unit_death": "unit_death",
	"ui_denied": "ui_denied",
}

const SFX_PRIORITIES := {
	"victory": 0,
	"defeat": 0,
	"card_jam": 0,
	"tower_alarm": 0,
	"merge": 1,
	"era": 1,
	"tower": 1,
	"unit_death": 1,
	"click": 2,
	"place": 2,
	"button": 2,
	"hit": 2,
	"card_locked": 2,
	"ui_denied": 2,
}

const SFX_BUSES := {
	"click": "SfxUI",
	"place": "SfxUI",
	"button": "SfxUI",
	"card_locked": "SfxUI",
	"ui_denied": "SfxUI",
}

const P0_CHANNELS := 2
const CHANNEL_COUNT := 16
const MERGE_WINDOW_MS := 50

var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}
var _channel_priorities: Array[int] = []
var _channel_started_ms: Array[int] = []
var _channel_durations: Array[float] = []
var _channel_names: Array[String] = []
var _channel_base_volumes: Array[float] = []
var _sfx_index := P0_CHANNELS
var _recent_requests: Dictionary = {}
var _duck_tween: Tween
var _duck_amount := 0.0
var _music_user_db := 0.0
var _sfx_user_db := 0.0
var _master_user_db := 0.0
var _music_filtered := false

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	bgm_player.stream = _loop_stream(load("res://assets/audio/bgm_loop.wav"))
	add_child(bgm_player)
	for name in SFX:
		var base_name: String = SFX[name]
		var variants: Array[AudioStream] = []
		var index := 1
		while ResourceLoader.exists("res://assets/audio/sfx_%s_%d.wav" % [base_name, index]):
			var variant := load("res://assets/audio/sfx_%s_%d.wav" % [base_name, index]) as AudioStream
			if variant != null:
				variants.append(variant)
			index += 1
		var stream := load("res://assets/audio/sfx_%s.wav" % base_name) as AudioStream
		if stream != null:
			variants.push_front(stream)
		if variants.size() == 1:
			sfx_streams[name] = variants[0]
		elif not variants.is_empty():
			sfx_streams[name] = variants
	for _index in range(CHANNEL_COUNT):
		var player := AudioStreamPlayer.new()
		player.bus = "SfxGame"
		add_child(player)
		sfx_players.append(player)
		_channel_priorities.append(99)
		_channel_started_ms.append(0)
		_channel_durations.append(0.0)
		_channel_names.append("")
		_channel_base_volumes.append(0.0)
	apply_volume("Master", SaveManager.get_volume("Master"))
	apply_volume("Music", SaveManager.get_volume("Music"))
	apply_volume("SFX", SaveManager.get_volume("SFX"))
	play_bgm()

func _loop_stream(stream: AudioStream) -> AudioStream:
	var looped := stream.duplicate() as AudioStreamWAV
	if looped != null:
		looped.loop_mode = AudioStreamWAV.LOOP_FORWARD
		looped.loop_begin = 0
		looped.loop_end = int(round(looped.get_length() * 22050.0))
	return looped

func play_bgm() -> void:
	if bgm_player != null and not bgm_player.playing:
		bgm_player.play()

func stop_bgm() -> void:
	if bgm_player != null:
		bgm_player.stop()

func play_sfx(name: String, opts := {}) -> void:
	if not sfx_streams.has(name):
		if OS.is_debug_build():
			push_warning("Unregistered SFX: %s" % name)
		return
	var priority := int(opts.get("priority", SFX_PRIORITIES.get(name, 2)))
	var now := Time.get_ticks_msec()
	var throttle_ms := maxi(0, int(opts.get("throttle_ms", MERGE_WINDOW_MS)))
	if _merge_recent_request(name, now, throttle_ms):
		return
	var channel := _find_channel(priority, now)
	if channel < 0:
		return
	var stream_value = sfx_streams[name]
	var stream: AudioStream
	if stream_value is Array:
		var variants: Array = stream_value
		var variant_index := int(opts.get("variant", -1))
		if variant_index < 0:
			variant_index = randi_range(0, variants.size() - 1)
		stream = variants[clampi(variant_index, 0, variants.size() - 1)]
	else:
		stream = stream_value
	var player := sfx_players[channel]
	player.stop()
	player.stream = stream
	player.bus = str(opts.get("bus", SFX_BUSES.get(name, "SfxGame")))
	var explicit_pitch := opts.has("pitch")
	player.pitch_scale = float(opts.pitch) if explicit_pitch else (
		randf_range(0.94, 1.06) if priority >= 2 else 1.0
	)
	var volume_db := float(opts.get("volume_db", 0.0))
	player.volume_db = volume_db
	player.play()
	_channel_priorities[channel] = priority
	_channel_started_ms[channel] = now
	_channel_durations[channel] = stream.get_length() / maxf(player.pitch_scale, 0.01)
	_channel_names[channel] = name
	_channel_base_volumes[channel] = volume_db
	_sfx_index = (channel + 1) % CHANNEL_COUNT
	_recent_requests[name] = {"time": now, "channel": channel, "count": 0}
	if priority == 0:
		_duck_p0(_channel_durations[channel] + 0.3)

func _merge_recent_request(name: String, now: int, throttle_ms: int) -> bool:
	if not _recent_requests.has(name):
		return false
	var recent: Dictionary = _recent_requests[name]
	if now - int(recent.time) > throttle_ms:
		return false
	var channel := int(recent.channel)
	if channel < 0 or channel >= sfx_players.size() or not sfx_players[channel].playing:
		return false
	recent.count = int(recent.count) + 1
	recent.time = now
	_recent_requests[name] = recent
	var boost := minf(2.0, float(recent.count) * 0.5)
	sfx_players[channel].volume_db = _channel_base_volumes[channel] + boost
	return true

func _find_channel(priority: int, now: int) -> int:
	var free_start := P0_CHANNELS if priority > 0 else 0
	for offset in range(CHANNEL_COUNT):
		var index := (free_start + _sfx_index + offset) % CHANNEL_COUNT
		if priority > 0 and index < P0_CHANNELS:
			continue
		if not sfx_players[index].playing:
			return index
	var victim := -1
	var victim_priority := priority
	for index in range(CHANNEL_COUNT):
		if priority > 0 and index < P0_CHANNELS:
			continue
		var duration := _channel_durations[index]
		var elapsed := float(now - _channel_started_ms[index]) / 1000.0
		if duration <= 0.0 or elapsed < duration * 0.5:
			continue
		if _channel_priorities[index] > victim_priority:
			victim = index
			victim_priority = _channel_priorities[index]
	return victim

func _duck_p0(duration: float) -> void:
	_duck_amount = 1.0
	_apply_mix_levels()
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_interval(duration)
	_duck_tween.tween_method(_set_duck_amount, 1.0, 0.0, 0.25)

func _set_duck_amount(value: float) -> void:
	_duck_amount = value
	_apply_mix_levels()

func _apply_mix_levels() -> void:
	var music_index := AudioServer.get_bus_index("Music")
	if music_index >= 0:
		var filtered_offset := -8.0 if _music_filtered else 0.0
		AudioServer.set_bus_volume_db(music_index, _music_user_db + filtered_offset - 6.0 * _duck_amount)
	var game_index := AudioServer.get_bus_index("SfxGame")
	if game_index >= 0:
		AudioServer.set_bus_volume_db(game_index, _sfx_user_db - 3.0 * _duck_amount)
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_volume_db(master_index, _master_user_db)

func set_music_filtered(filtered: bool) -> void:
	_music_filtered = filtered
	var bus_index := AudioServer.get_bus_index("Music")
	if bus_index >= 0 and AudioServer.get_bus_effect_count(bus_index) > 0:
		AudioServer.set_bus_effect_enabled(bus_index, 0, not filtered)
	_apply_mix_levels()

func apply_volume(bus_name: String, value_0_100: float) -> void:
	var value := clampf(value_0_100, 0.0, 100.0)
	var db := -80.0 if value <= 0.0 else linear_to_db(value / 100.0)
	match bus_name:
		"Master":
			_master_user_db = db
		"Music":
			_music_user_db = db
		"SFX":
			_sfx_user_db = db
		"SfxGame":
			_sfx_user_db = db
		"SfxUI":
			var ui_index := AudioServer.get_bus_index("SfxUI")
			if ui_index >= 0:
				AudioServer.set_bus_volume_db(ui_index, db)
	_apply_mix_levels()
	SaveManager.set_volume(bus_name, value)
