extends SceneTree

## 关卡目标用时冒烟：启动 / 冻结 / 累计已用 / 超时不失败 / 过关重置 / 第2关×2
## 用法：godot --headless --path . --script tools/stage_time_limit_smoke.gd

var main: Node
var failures: Array[String] = []

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	# 同步断言：_start_round 末尾即重置计时，此处不 await 以免正常帧扣时干扰
	main._start_round(0)
	_check(
		main.stage_time_limit == main._stage_time_limit_for(0),
		"开局目标用时应取第 1 关难度表"
	)
	_check(
		is_equal_approx(main.stage_time_left, main.stage_time_limit),
		"开局剩余目标时间应等于本关目标用时"
	)
	_check(is_equal_approx(main.stage_elapsed, 0.0), "开局已用时间应为 0")
	_check(main.stage_time_limit > 0.0, "开局目标用时应大于 0")
	_check(
		is_equal_approx(main._stage_time_limit_for(1), main._stage_time_limit_for(0) * 2.0),
		"第 2 关目标用时应为第 1 关 ×2"
	)
	await process_frame

	# 奖励面板打开时冻结
	main.stage_elapsed = 10.0
	main.stage_time_left = 100.0
	main.reward_active = true
	main._process(1.0)
	main.reward_active = false
	_check(is_equal_approx(main.stage_elapsed, 10.0), "奖励面板打开时已用时间应冻结")
	_check(is_equal_approx(main.stage_time_left, 100.0), "奖励面板打开时目标剩余应冻结")

	# 暂停时冻结
	main.stage_elapsed = 10.0
	main.stage_time_left = 100.0
	main.paused = true
	main._process(1.0)
	main.paused = false
	_check(is_equal_approx(main.stage_elapsed, 10.0), "暂停时已用时间应冻结")
	_check(is_equal_approx(main.stage_time_left, 100.0), "暂停时目标剩余应冻结")

	# 正常战斗累计已用
	main.battle_ended = false
	main.battle_active = true
	main.stage_elapsed = 50.0
	main.stage_time_left = main.stage_time_limit - 50.0
	main._process(1.0)
	_check(main.stage_elapsed > 50.0, "正常战斗时已用时间应递增")
	_check(not main.battle_ended, "正常计时不应结束战斗")

	# 倒计时归零不判负（方案甲）
	main.battle_ended = false
	main.battle_won = false
	main.battle_active = true
	main.stage_elapsed = main.stage_time_limit - 0.05
	main.stage_time_left = 0.05
	main._process(0.2)
	_check(not main.battle_ended, "倒计时归零不应结束战斗")
	_check(main.stage_elapsed > main.stage_time_limit, "超时后已用时间应继续累加")
	_check(is_equal_approx(main.stage_time_left, 0.0), "超时后目标剩余应为 0")

	# 过关进入下一关时重置计时
	main._start_round(0)
	await process_frame
	main.tray_cards.append(GameData.cards_for_era(main.current_era)[0])
	main._summon_reinforcement(false)
	main.enemy_tower_hp = 0.0
	main._on_enemy_tower_destroyed()
	await process_frame
	if not main.reward_active:
		failures.append("过关后奖励面板未打开")
	else:
		# 确认奖励会同步走 _enter_next_stage → _reset_stage_timer，先同步断言再 await
		main._on_reward_button_pressed(0)
		main._on_reward_confirm_pressed()
		_check(main.enemy_era_index == 1, "过关后应进入第 2 关")
		_check(
			main.stage_time_limit == main._stage_time_limit_for(1),
			"进入下一关后应取新关卡目标用时"
		)
		_check(
			is_equal_approx(main.stage_time_left, main.stage_time_limit),
			"进入下一关后目标剩余应重置为完整目标用时"
		)
		_check(is_equal_approx(main.stage_elapsed, 0.0), "进入下一关后已用时间应归零")
		await process_frame

	if failures.is_empty():
		print("stage_time_limit_smoke: OK")
	else:
		print("stage_time_limit_smoke: %d 项失败" % failures.size())
		for message in failures:
			print("  - %s" % message)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
