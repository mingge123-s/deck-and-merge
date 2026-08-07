extends Node

const SAVE_PATH := "user://save.cfg"
const LEADERBOARD_SIZE := 10
const DEFAULTS := {
	"coins": 300,
	"vol_master": 80.0,
	"vol_music": 80.0,
	"vol_sfx": 80.0,
	"best_score": 0,
	"leaderboard": [],
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
	_normalize_leaderboard()

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

## 本机 Top10：[{score, difficulty, stage_reached, timestamp}, ...]，按 score 降序
## stage_reached 复用为时代进度（1=石器 … 5=未来），UI 显示时代名而非「第N关」
func get_leaderboard() -> Array:
	_normalize_leaderboard()
	return (_data["leaderboard"] as Array).duplicate(true)

## 用本局积分尝试入榜。返回名次 1..10；未入榜返回 0。
func try_submit_score(score: int, difficulty: String, stage_reached: int) -> int:
	var entry_score := maxi(0, score)
	if entry_score <= 0:
		return 0
	_normalize_leaderboard()
	var board: Array = _data["leaderboard"]
	var entry := {
		"score": entry_score,
		"difficulty": difficulty if not difficulty.is_empty() else "normal",
		"stage_reached": maxi(1, stage_reached),
		"timestamp": int(Time.get_unix_time_from_system()),
	}
	board.append(entry)
	board.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	if board.size() > LEADERBOARD_SIZE:
		board = board.slice(0, LEADERBOARD_SIZE)
	_data["leaderboard"] = board
	_sync_best_score_from_leaderboard()
	save()
	for index in range(board.size()):
		if is_same(board[index], entry):
			return index + 1
	return 0

func _normalize_leaderboard() -> void:
	var raw = _data.get("leaderboard", [])
	var cleaned: Array = []
	if raw is Array:
		for item in raw:
			if typeof(item) != TYPE_DICTIONARY:
				continue
			var row: Dictionary = item
			var score := maxi(0, int(row.get("score", 0)))
			if score <= 0:
				continue
			cleaned.append({
				"score": score,
				"difficulty": str(row.get("difficulty", "normal")),
				"stage_reached": maxi(1, int(row.get("stage_reached", 1))),
				"timestamp": maxi(0, int(row.get("timestamp", 0))),
			})
	cleaned.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	if cleaned.size() > LEADERBOARD_SIZE:
		cleaned = cleaned.slice(0, LEADERBOARD_SIZE)
	# 旧存档只有 best_score：派生一条占位记录，保留兼容
	if cleaned.is_empty():
		var legacy_best := maxi(0, int(_data.get("best_score", 0)))
		if legacy_best > 0:
			cleaned.append({
				"score": legacy_best,
				"difficulty": "normal",
				"stage_reached": 1,
				"timestamp": 0,
			})
	_data["leaderboard"] = cleaned
	_sync_best_score_from_leaderboard()

func _sync_best_score_from_leaderboard() -> void:
	var board: Array = _data.get("leaderboard", [])
	var top := 0
	if not board.is_empty():
		top = maxi(0, int((board[0] as Dictionary).get("score", 0)))
	_data["best_score"] = maxi(int(_data.get("best_score", 0)), top)

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
