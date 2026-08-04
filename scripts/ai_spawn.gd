class_name AiSpawn
extends RefCounted

## AI 常规出兵核心：定时 tick + 概率出兵（替代旧的「维持场上人数」）。
## main.gd 只做薄接线：注入回调、每帧调 tick()、波次/阶段边界通知。
##
## 规则概览：
## - 每 AiSpawnConfig.tick_interval 秒一次 tick；场上敌人数 < 软顶且 < 硬顶时，
##   以 AiSpawnConfig.spawn_chance 的概率出 1 个普通兵，失败则本 tick 不出。
## - 满员（软顶或硬顶）不掷骰。
## - Boss 只在 boss_pending 时按 boss_tick_chance 稀疏出场，不受「维持人数」影响。
##   boss_pending 来源：① 波号 % boss_wave == 0 的波；② 敌方进入新时代阶段后的首波，
##   以 phase_boss_chance 概率挂上。
## - 事件出兵（拼死反扑/阶段击破爆发）走 spawn_one()，不经过概率与 tick。

## 场上敌人硬顶（由 main.gd 注入 ENEMY_UNIT_CAP）
var hard_cap := 60
var difficulty_key := AiSpawnConfig.DEFAULT_DIFFICULTY
var wave_number := 0
var boss_pending := false

var _rng: RandomNumberGenerator
var _tick_timer := 0.0
var _phase_boss_roll_pending := false

## () -> String，返回敌方当前时代
var era_provider := Callable()
## () -> int，返回场上存活敌人数
var alive_counter := Callable()
## (hero_id: String) -> bool，实际生成一个敌方单位
var spawn_hero := Callable()

func setup(
	rng: RandomNumberGenerator,
	era_provider_cb: Callable,
	alive_counter_cb: Callable,
	spawn_hero_cb: Callable,
	enemy_hard_cap: int
) -> void:
	_rng = rng
	era_provider = era_provider_cb
	alive_counter = alive_counter_cb
	spawn_hero = spawn_hero_cb
	hard_cap = enemy_hard_cap

func set_difficulty(key: String) -> void:
	difficulty_key = key

## 一局/一阶段开始前的状态清零
func reset() -> void:
	wave_number = 0
	boss_pending = false
	_phase_boss_roll_pending = false
	_tick_timer = 0.0

## 新一波开始：决定本波是否安排 boss，并重置 tick 计时
func begin_wave(number: int, boss_wave_interval: int) -> void:
	wave_number = number
	_tick_timer = tick_interval()
	var wants_boss := boss_wave_interval > 0 and number % boss_wave_interval == 0
	if _phase_boss_roll_pending:
		_phase_boss_roll_pending = false
		if _randf() < AiSpawnConfig.phase_boss_chance(difficulty_key):
			wants_boss = true
	if wants_boss:
		boss_pending = true

## 敌塔被打爆、敌方升入新时代阶段时调用
func on_phase_start() -> void:
	boss_pending = false
	_phase_boss_roll_pending = true
	_tick_timer = tick_interval()

func tick_interval() -> float:
	return AiSpawnConfig.tick_interval(difficulty_key)

func spawn_chance() -> float:
	return AiSpawnConfig.spawn_chance(difficulty_key, wave_number)

func field_soft_cap() -> int:
	return mini(hard_cap, AiSpawnConfig.field_soft_cap(difficulty_key, wave_number))

## 每帧调用（仅在本波出兵窗口内）。返回本次 tick 是否出了兵。
func tick(delta: float) -> bool:
	_tick_timer -= delta
	if _tick_timer > 0.0:
		return false
	_tick_timer += tick_interval()
	if _tick_timer <= 0.0:
		_tick_timer = tick_interval()
	if _alive() >= field_soft_cap():
		return false
	if boss_pending and _randf() < AiSpawnConfig.boss_tick_chance(difficulty_key):
		if _spawn_boss():
			return true
	if _randf() >= spawn_chance():
		return false
	return spawn_one(false)

## 立刻出 1 个兵（事件出兵用：拼死反扑、阶段击破爆发等），不掷概率骰
func spawn_one(allow_boss_in_pool := false) -> bool:
	if _alive() >= hard_cap:
		return false
	var hero_id := pick_hero(allow_boss_in_pool)
	if hero_id == "":
		return false
	return _do_spawn(hero_id)

## 按当前敌方时代池加权随机挑一个兵种；allow_boss_in_pool=false 时排除 boss
func pick_hero(allow_boss_in_pool := false) -> String:
	var ids := _era_hero_ids()
	if ids.is_empty():
		return ""
	var weighted: Array[String] = []
	for hero_id in ids:
		if not allow_boss_in_pool and _is_boss(hero_id):
			continue
		var weight := maxi(0, int(GameData.HEROES[hero_id].get("deck_count", 12)))
		for _w in range(weight):
			weighted.append(hero_id)
	if weighted.is_empty():
		return str(ids[_randi(ids.size())])
	return weighted[_randi(weighted.size())]

func _spawn_boss() -> bool:
	if _alive() >= hard_cap:
		return false
	for hero_id in _era_hero_ids():
		if _is_boss(hero_id):
			if _do_spawn(str(hero_id)):
				boss_pending = false
				return true
			return false
	boss_pending = false
	return false

func _do_spawn(hero_id: String) -> bool:
	if not spawn_hero.is_valid():
		return false
	return bool(spawn_hero.call(hero_id))

func _era_hero_ids() -> Array:
	if not era_provider.is_valid():
		return []
	return GameData.heroes_for_era(str(era_provider.call()))

func _is_boss(hero_id: String) -> bool:
	return str(GameData.HEROES.get(hero_id, {}).get("role", "")) == "boss"

func _alive() -> int:
	if not alive_counter.is_valid():
		return 0
	return int(alive_counter.call())

func _randf() -> float:
	if _rng == null:
		return randf()
	return _rng.randf()

func _randi(size: int) -> int:
	if size <= 1:
		return 0
	if _rng == null:
		return randi() % size
	return _rng.randi_range(0, size - 1)
