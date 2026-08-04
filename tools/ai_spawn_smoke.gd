extends SceneTree

## 概率出兵冒烟测试：godot --headless --path . -s tools/ai_spawn_smoke.gd

func _init() -> void:
	GameData.initialize()
	for key in ["easy", "normal", "hard"]:
		_run(key)
	quit()

func _run(difficulty_key: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	# GDScript lambda 按值捕获局部变量，用字典（引用类型）共享状态
	var state := {"alive": 0, "total": 0, "boss": 0}
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
		60
	)
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
