extends SceneTree

## 概率出兵冒烟测试：godot --headless --path . -s tools/ai_spawn_smoke.gd

func _init() -> void:
	GameData.initialize()
	for key in ["easy", "normal", "hard"]:
		_run(key)
	_print_rate_table()
	_check_windows()
	_check_stone_pressure()
	quit()

func _run(difficulty_key: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# GDScript lambda 按值捕获局部变量，用字典（引用类型）共享状态
	var state := {"alive": 0, "total": 0, "boss": 0}
	var spawner := _make_spawner(rng, state, 0)
	spawner.set_difficulty(difficulty_key)
	spawner.reset()
	# 模拟 10 波 x 30 秒，每波假设玩家清场（alive 归零）
	for wave in range(1, 11):
		spawner.begin_wave(wave, 5)
		for _frame in range(int(30.0 / 0.05)):
			spawner.tick(0.05)
		state["alive"] = 0
	# 满员时不再掷骰
	state["alive"] = 999
	var before: int = state["total"]
	spawner.begin_wave(11, 5)
	for _frame in range(200):
		spawner.tick(0.05)
	var capped_ok: bool = state["total"] == before
	print("[%s] tick=%.2fs p=%.2f soft_cap=%d 10波300秒出兵=%d (boss=%d) 满员不出=%s" % [
		difficulty_key,
		spawner.tick_interval(),
		spawner.spawn_chance(),
		spawner.field_soft_cap(),
		state["total"],
		state["boss"],
		str(capped_ok),
	])

func _make_spawner(rng: RandomNumberGenerator, state: Dictionary, era_index: int) -> AiSpawn:
	var spawner := AiSpawn.new()
	spawner.setup(
		rng,
		func() -> String: return "stone",
		func() -> int: return int(state["alive"]),
		func(hero_id: String) -> bool:
			state["total"] += 1
			if str(GameData.HEROES[hero_id].get("role", "")) == "boss":
				state["boss"] += 1
			state["alive"] += 1
			return true,
		60,
		func() -> int: return era_index
	)
	return spawner

func _print_rate_table() -> void:
	for key in ["easy", "normal", "hard"]:
		var row := "[%s] 期望速率(个/秒) 各时代: " % key
		for era_index in range(5):
			row += "%d档=%.2f " % [era_index, AiSpawnConfig.expected_rate(key, 1, era_index)]
		row += "| 软顶 %d→%d" % [
			AiSpawnConfig.field_soft_cap(key, 1, 0),
			AiSpawnConfig.field_soft_cap(key, 1, 4),
		]
		print(row)

## s11「石器时代开局加压」验收断言：普通档、石器、第 1 波（在 s5 基础上再抬）
func _check_stone_pressure() -> void:
	var stone_rate := AiSpawnConfig.expected_rate("normal", 1, 0)
	var stone_cap := AiSpawnConfig.field_soft_cap("normal", 1, 0)
	assert(stone_rate >= 0.72, "石器普通档期望速率应 >=0.72/s（s11 加压），实际 %.3f" % stone_rate)
	assert(stone_cap >= 14, "石器普通档软顶应 >=14，实际 %d" % stone_cap)
	# 残血爆兵分档：石器 12 / 铁器 8 / 工业 7 / 现代 6 / 未来 6
	var expected_burst := [12, 8, 7, 6, 6]
	for era_index in range(expected_burst.size()):
		var got := AiSpawnConfig.rally_burst(era_index)
		assert(got == expected_burst[era_index],
			"时代 %d 爆兵应为 %d，实际 %d" % [era_index, expected_burst[era_index], got])
	print("[stone] 普通档石器第1波 期望速率=%.3f/s 软顶=%d 爆兵分档=%s" % [
		stone_rate, stone_cap, str(expected_burst),
	])

func _check_windows() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var state := {"alive": 0, "total": 0, "boss": 0}
	var spawner := _make_spawner(rng, state, 0)
	spawner.set_difficulty("normal")
	spawner.reset()
	spawner.begin_wave(1, 5)
	var base_p := spawner.spawn_chance()
	spawner.on_rally()
	var rally_p := spawner.spawn_chance()
	spawner.reset()
	spawner.on_phase_start()
	var break_p := spawner.spawn_chance()
	# 窗口到期后回落
	for _frame in range(int(AiSpawnConfig.TOWER_BREAK_DURATION / 0.05) + 4):
		spawner.tick(0.05)
	var after_p := spawner.spawn_chance()
	print("[windows] base=%.3f 反扑=%.3f 拆塔喘息=%.3f 窗口到期回落=%.3f" % [base_p, rally_p, break_p, after_p])
	# boss 最小间隔
	spawner.reset()
	spawner.begin_wave(5, 5)
	var boss_before: int = state["boss"]
	for _frame in range(int(120.0 / 0.05)):
		state["alive"] = 0
		spawner.tick(0.05)
	print("[boss] 普通档 120 秒内 boss 出场=%d 次（最小间隔 %.0fs）" % [
		state["boss"] - boss_before,
		AiSpawnConfig.boss_min_gap("normal"),
	])
