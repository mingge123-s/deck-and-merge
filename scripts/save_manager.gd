extends Node

const SAVE_PATH := "user://save.cfg"
const DEFAULTS := {
	"coins": 300,
	"vol_master": 80.0,
	"vol_music": 80.0,
	"vol_sfx": 80.0,
	"best_score": 0,
	"unlocked_era_index": 0,
	"tutorial_seen": false,
	"reshuffle_hint_seen": false,
}

var _data: Dictionary = DEFAULTS.duplicate(true)

func _ready() -> void:
	call("load")

func load() -> void:
	_data = DEFAULTS.duplicate(true)
	var config := ConfigFile.new()
	var error := config.load(SAVE_PATH)
	if error != OK:
		return
	for key in DEFAULTS:
		if config.has_section_key("save", key):
			_data[key] = config.get_value("save", key, DEFAULTS[key])
	_data["coins"] = maxi(0, int(_data["coins"]))
	_data["vol_master"] = clampf(float(_data["vol_master"]), 0.0, 100.0)
	_data["vol_music"] = clampf(float(_data["vol_music"]), 0.0, 100.0)
	_data["vol_sfx"] = clampf(float(_data["vol_sfx"]), 0.0, 100.0)
	_data["best_score"] = maxi(0, int(_data["best_score"]))
	_data["unlocked_era_index"] = maxi(0, int(_data["unlocked_era_index"]))
	_data["tutorial_seen"] = bool(_data["tutorial_seen"])
	_data["reshuffle_hint_seen"] = bool(_data["reshuffle_hint_seen"])

func save() -> void:
	var config := ConfigFile.new()
	for key in _data:
		config.set_value("save", key, _data[key])
	config.save(SAVE_PATH)

func get_coins() -> int:
	return int(_data["coins"])

func set_coins(value: int) -> void:
	_data["coins"] = maxi(0, value)
	save()

func add_coins(amount: int) -> int:
	_data["coins"] = maxi(0, get_coins() + amount)
	save()
	return get_coins()

func get_volume(bus_name: String) -> float:
	var key := "vol_%s" % bus_name.to_lower()
	return float(_data.get(key, 80.0))

func set_volume(bus_name: String, value: float) -> void:
	var key := "vol_%s" % bus_name.to_lower()
	if not _data.has(key):
		return
	_data[key] = clampf(value, 0.0, 100.0)
	save()

func get_best_score() -> int:
	return int(_data["best_score"])

func set_best_score(value: int) -> void:
	_data["best_score"] = maxi(0, value)
	save()

func get_unlocked_era_index() -> int:
	return int(_data["unlocked_era_index"])

func unlock_era(index: int) -> void:
	_data["unlocked_era_index"] = maxi(get_unlocked_era_index(), index)
	save()

func get_tutorial_seen() -> bool:
	return bool(_data["tutorial_seen"])

func set_tutorial_seen(value: bool) -> void:
	_data["tutorial_seen"] = value
	save()

func get_reshuffle_hint_seen() -> bool:
	return bool(_data["reshuffle_hint_seen"])

func set_reshuffle_hint_seen(value: bool) -> void:
	_data["reshuffle_hint_seen"] = value
	save()
