extends SceneTree

## 已废止关卡倒计时失败：改为时代计时（冻结 / 累计 / 到期推进 / 不超时失败）
## 用法：godot --headless --path . --script tools/stage_time_limit_smoke.gd

var main: Node
var failures: Array[String] = []

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main._start_round(0)
	_check(is_equal_approx(main.era_elapsed, 0.0), "开局 era_elapsed 应为 0")
	_check(main._era_duration_for(0) > 0.0, "石器时代时长应大于 0")
	await process_frame

	# 奖励面板打开时冻结
	main.era_elapsed = 100.0
	main.battle_elapsed = 100.0
	main.reward_active = true
	main._process(1.0)
	main.reward_active = false
	_check(is_equal_approx(main.era_elapsed, 100.0), "奖励面板打开时计时应冻结")

	# 暂停时冻结
	main.era_elapsed = 100.0
	main.paused = true
	main._process(1.0)
	main.paused = false
	_check(is_equal_approx(main.era_elapsed, 100.0), "暂停时计时应冻结")

	# 正常战斗扣时（累计），且不因「超时」失败
	main.battle_ended = false
	main.battle_active = true
	main.era_elapsed = 50.0
	main.battle_elapsed = 50.0
	main._process(1.0)
	_check(main.era_elapsed > 50.0, "正常战斗时 era_elapsed 应递增")
	_check(not main.battle_ended, "时代计时耗尽前正常扣时不应结束战斗")

	# 到期推进时代，而非失败
	main.enemy_era_index = 0
	main.enemy_era = "stone"
	main.era_elapsed = main._era_duration_for(0) - 0.05
	main._process(0.2)
	_check(main.enemy_era_index == 1, "时代到期应推进到铁器，实际 %d" % main.enemy_era_index)
	_check(not main.battle_ended, "时代到期不得判负")
	_check(is_equal_approx(main.era_elapsed, 0.0) or main.era_elapsed < 1.0, "推进后 era_elapsed 应接近 0")

	if failures.is_empty():
		print("stage_time_limit_smoke: OK (era-timer mode)")
	else:
		print("stage_time_limit_smoke: %d 项失败" % failures.size())
		for message in failures:
			print("  - %s" % message)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
