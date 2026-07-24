extends Node

const SFX_NAMES := [
	"click",
	"place",
	"merge",
	"hit",
	"tower",
	"victory",
	"defeat",
	"era",
	"button",
]

var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_streams: Dictionary = {}
var _sfx_index := 0

func _ready() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	bgm_player.stream = _loop_stream(load("res://assets/audio/bgm_loop.wav"))
	add_child(bgm_player)
	for name in SFX_NAMES:
		sfx_streams[name] = load("res://assets/audio/sfx_%s.wav" % name)
	for _index in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
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

func play_sfx(name: String) -> void:
	if not sfx_streams.has(name):
		return
	for offset in range(sfx_players.size()):
		var index := (_sfx_index + offset) % sfx_players.size()
		var player := sfx_players[index]
		if not player.playing:
			player.stream = sfx_streams[name]
			player.play()
			_sfx_index = (index + 1) % sfx_players.size()
			return

func apply_volume(bus_name: String, value_0_100: float) -> void:
	var value := clampf(value_0_100, 0.0, 100.0)
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, -80.0 if value <= 0.0 else linear_to_db(value / 100.0))
	SaveManager.set_volume(bus_name, value)
