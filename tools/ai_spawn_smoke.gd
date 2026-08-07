extends SceneTree

## 概率出兵冒烟测试：godot --headless --path . -s tools/ai_spawn_smoke.gd

func _init() -> void:
	GameData.initialize()
	for key in ["easy", "normal", "hard"]:
		_run(key)
	_print_rate_table()
	_check_windows()
	_check_stone_pressure()
	_check_time_in_era_curve()
	quit()

func _run(difficulty_key: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# GDScript lambda 按值捕获局部变量，用字典（引用类型）共享状态
	var state := {"alive": 0, "total": 0, "boss": 0, "time_norm": 0.5}
	var spawner := _make_spawner(rng, state, 0)
	spawner.set_difficulty(difficulty_key)
	spawner.reset()
	# 模拟 10 波 x 30 秒，每波假设玩家清场（alive 归零）；时代内 norm 从 0→1
	for wave in range(1, 11):
		state["time_norm"] = float(wave - 1) / 9.0
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
		func() -> int: return era_index,
		func() -> float: return float(state.get("time_norm", 0.0))
	)
	return spawner

func _print_rate_table() -> void:
	for key in ["easy", "normal", "hard"]:
		var row := "[%s] 期望速率(个/秒) 各时代@末: " % key
		for era_index in range(5):
			row += "%d档=%.2f " % [era_index, AiSpawnConfig.expected_rate(key, 1, era_index, 1.0)]
		row += "| 软顶(初→末) %d→%d" % [
			AiSpawnConfig.field_soft_cap(key, 1, 0, 0.0),
			AiSpawnConfig.field_soft_cap(key, 1, 0, 1.0),
		]
		print(row)

## 时代末（norm=1）验收：石器时代加压仍成立；时代初应明显更稀
func _check_stone_pressure() -> void:
	var stone_rate_end := AiSpawnConfig.expected_rate("normal", 1, 0, 1.0)
	var stone_cap_end := AiSpawnConfig.field_soft_cap("normal", 1, 0, 1.0)
	assert(stone_rate_end >= 0.72, "石器普通档时代末期望速率应 >=0.72/s，实际 %.3f" % stone_rate_end)
	assert(stone_cap_end >= 14, "石器普通档时代末软顶应 >=14，实际 %d" % stone_cap_end)
	# 残血爆兵分档：石器 12 / 铁器 8 / 工业 7 / 现代 6 / 未来 6
	var expected_burst := [12, 8, 7, 6, 6]
	for era_index in range(expected_burst.size()):
		var got := AiSpawnConfig.rally_burst(era_index)
		assert(got == expected_burst[era_index],
			"时代 %d 爆兵应为 %d，实际 %d" % [era_index, expected_burst[era_index], got])
	print("[stone] 普通档石器第1波@末 期望速率=%.3f/s 软顶=%d 爆兵分档=%s" % [
		stone_rate_end, stone_cap_end, str(expected_burst),
	])

func _check_time_in_era_curve() -> void:
	var p0 := AiSpawnConfig.spawn_chance("normal", 1, 0, 1.0, 0.0)
	var p1 := AiSpawnConfig.spawn_chance("normal", 1, 0, 1.0, 1.0)
	var t0 := AiSpawnConfig.tick_interval("normal", 0, 0.0)
	var t1 := AiSpawnConfig.tick_interval("normal", 0, 1.0)
	var c0 := AiSpawnConfig.field_soft_cap("normal", 1, 0, 0.0)
	var c1 := AiSpawnConfig.field_soft_cap("normal", 1, 0, 1.0)
	var r0 := AiSpawnConfig.expected_rate("normal", 1, 0, 0.0)
	var r1 := AiSpawnConfig.expected_rate("normal", 1, 0, 1.0)
	assert(p1 > p0, "时代内 p 应从低到高：%.3f → %.3f" % [p0, p1])
	assert(t1 < t0, "时代内 tick 应从疏到密：%.3f → %.3f" % [t0, t1])
	assert(c1 > c0, "时代内软顶应从低到高：%d → %d" % [c0, c1])
	assert(r1 > r0, "时代内期望速率应从低到高：%.3f → %.3f" % [r0, r1])
	assert(is_equal_approx(AiSpawnConfig.time_stat_mult(0.0), 1.0), "norm=0 属性倍率应为 1.0")
	assert(is_equal_approx(AiSpawnConfig.time_stat_mult(1.0), 1.25), "norm=1 属性倍率应为 1.25")
	print("[time_in_era] p %.3f→%.3f tick %.2f→%.2f cap %d→%d rate %.3f→%.3f stat 1.00→1.25" % [
		p0, p1, t0, t1, c0, c1, r0, r1,
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
