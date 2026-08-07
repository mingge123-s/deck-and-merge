extends SceneTree

## 方案甲 冒烟：开局金 / 击杀金归零 / 过关速度金与积分 / 悬赏令改版
## 用法：godot --headless --path . --script tools/economy_a_smoke.gd

var main: Node
var failures: Array[String] = []

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main._start_round(0)
	await process_frame

	_check(int(main.STARTING_COINS) == 400, "开局金币常量应为 400")
	_check(int(main.coin_count) == 400, "开局金币应为 400，实际 %d" % int(main.coin_count))
	_check(int(main.PLAYER_KILL_GOLD) == 0, "玩家击杀金币应归零")
	_check(float(main.KILL_SCORE_MULT) <= 0.25 + 0.0001, "击杀积分应弱化至 ≤0.25")

	# 击杀敌兵不给金币；非塔击杀给弱化积分
	var coins_before: int = int(main.coin_count)
	var score_before: int = int(main.kill_score)
	var enemy: Node = _spawn_test_enemy()
	_check(enemy != null, "应能生成测试敌兵")
	if enemy != null:
		enemy.last_damage_source = "ally"
		enemy.score_awarded = false
		var raw_score: int = int(enemy.stats.get("kill_score", 0))
		main._on_unit_expired(enemy)
		_check(int(main.coin_count) == coins_before, "击杀敌兵不应增加金币")
		var expected_score: int = score_before + maxi(0, int(round(float(raw_score) * float(main.KILL_SCORE_MULT))))
		_check(int(main.kill_score) == expected_score, "击杀积分应按弱化系数累加，期望 %d 实际 %d" % [expected_score, int(main.kill_score)])

	# 塔击杀：无金币、无击杀分
	coins_before = int(main.coin_count)
	score_before = int(main.kill_score)
	var tower_kill: Node = _spawn_test_enemy()
	if tower_kill != null:
		tower_kill.last_damage_source = "tower"
		tower_kill.score_awarded = false
		main._on_unit_expired(tower_kill)
		_check(int(main.coin_count) == coins_before, "塔击杀不应增加金币")
		_check(int(main.kill_score) == score_before, "塔击杀不应增加击杀积分")

	# 速度公式：elapsed=target → 倍率 1.0；更快 → >1；更慢 → <1
	main.stage_time_limit = 180.0
	main.stage_elapsed = 180.0
	_check(is_equal_approx(float(main._stage_speed_mult()), 1.0), "用时=目标时速度倍率应为 1")
	main.stage_elapsed = 90.0
	_check(float(main._stage_speed_mult()) > 1.0, "更快通关速度倍率应 >1")
	_check(float(main._stage_speed_mult()) <= float(main.CLEAR_GOLD_SPEED_MAX) + 0.0001, "速度倍率不应超过上限")
	main.stage_elapsed = 900.0
	_check(float(main._stage_speed_mult()) >= float(main.CLEAR_GOLD_SPEED_MIN) - 0.0001, "极慢通关速度倍率应夹在下限")

	# 过关发放金币 + 关卡分 + 速度分
	main._start_round(0)
	await process_frame
	main.stage_elapsed = 90.0
	main.stage_time_left = maxf(0.0, float(main.stage_time_limit) - 90.0)
	main.stage_clear_economy_awarded = false
	coins_before = int(main.coin_count)
	score_before = int(main.kill_score)
	var expected_gold: int = int(main._compute_clear_gold())
	var scores: Dictionary = main._compute_stage_clear_scores()
	var award: Dictionary = main._award_stage_clear_economy()
	_check(int(award.gold) == expected_gold, "过关金币应等于公式结果")
	_check(int(main.coin_count) == coins_before + expected_gold, "过关后金币应增加公式值")
	_check(int(award.stage_pts) == int(scores.stage), "应发放关卡分")
	_check(int(award.speed_pts) == int(scores.speed), "应发放速度分")
	_check(
		int(main.kill_score) == score_before + int(scores.stage) + int(scores.speed),
		"本局总分应累加关卡分+速度分"
	)
	# 幂等：同关不重复发
	var mid_coins: int = int(main.coin_count)
	var mid_score: int = int(main.kill_score)
	var again: Dictionary = main._award_stage_clear_economy()
	_check(int(again.gold) == 0, "同关重复过关结算不应再发金币")
	_check(int(main.coin_count) == mid_coins and int(main.kill_score) == mid_score, "幂等后金币/积分不变")

	# 悬赏令：立即金币 + 过关倍率，不再按击杀给金
	main._start_round(0)
	await process_frame
	coins_before = int(main.coin_count)
	var bounty := {"id": "bounty", "name": "疾战悬赏", "duration": 30.0}
	main._apply_random_effect(bounty, "ally")
	_check(int(main.coin_count) > coins_before, "悬赏令应立即发放金币")
	_check(bool(main._buff_active("bounty")), "悬赏令应进入 buff 计时")
	main.stage_elapsed = 180.0
	main.stage_time_limit = 180.0
	main.round_coin_mult = 1.0
	main.stage_clear_economy_awarded = false
	var with_bounty: int = int(main._compute_clear_gold())
	main.buff_timers.erase("bounty")
	var without_bounty: int = int(main._compute_clear_gold())
	_check(with_bounty > without_bounty, "悬赏令激活时应提升过关金币")

	# loot_boost 作用于过关金
	main.round_coin_mult = 1.3
	var boosted: int = int(main._compute_clear_gold())
	main.round_coin_mult = 1.0
	var normal: int = int(main._compute_clear_gold())
	_check(boosted > normal, "疾战赏金（loot_boost）应提升过关金币")

	# 教程文案去超时失败 / 击杀磨兵
	var tutorial_blob := ""
	for step in main.TUTORIAL_STEPS:
		tutorial_blob += str(step.get("text", ""))
	_check(not tutorial_blob.contains("超时失败"), "教程不应再提超时失败")
	_check(not tutorial_blob.contains("击杀敌人获得金币"), "教程不应再提击杀得金币")
	_check(tutorial_blob.contains("速度评级") or tutorial_blob.contains("用时越短"), "教程应说明速度奖励")

	if failures.is_empty():
		print("economy_a_smoke: OK")
	else:
		print("economy_a_smoke: %d 项失败" % failures.size())
		for message in failures:
			print("  - %s" % message)
	quit(0 if failures.is_empty() else 1)

func _spawn_test_enemy() -> Node:
	var hero_ids: Array = GameData.heroes_for_era(main.enemy_era)
	if hero_ids.is_empty():
		return null
	main._spawn_enemy(str(hero_ids[0]), 0, 1)
	for unit in main.battle_units:
		if is_instance_valid(unit) and unit.faction == "enemy":
			return unit
	return null

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
