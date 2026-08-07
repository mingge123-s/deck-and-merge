extends SceneTree

## 时间轴时代冒烟：时间推进时代 / 毁塔加金币且不进 stage_clear / 超时不再失败
## 用法：godot --headless --path . --script tools/time_era_smoke.gd

var main: Node
var failures: Array[String] = []

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main._start_round(0)
	await process_frame

	_check(main.enemy_era_index == 0, "起始敌方时代应为石器")
	_check(main.era_index == 0, "起始玩家时代应为石器")
	_check(main.round_number == 1, "起始应为第 1 轮，实际 %d" % main.round_number)
	_check(is_equal_approx(main.era_elapsed, 0.0), "开局 era_elapsed 应为 0")
	_check(is_equal_approx(main.battle_elapsed, 0.0), "开局 battle_elapsed 应为 0")
	_check(main.ERA_DURATION_SEC.size() == 5, "时代时长表应为 5 项")
	_check(
		main.ERA_DURATION_SEC == AiSpawnConfig.ERA_DURATION_SEC,
		"main 与 AiSpawnConfig 时代时长表应一致"
	)
	var expected_durations := [300.0, 480.0, 900.0, 1200.0, 1800.0]
	_check(
		main.ERA_DURATION_SEC == expected_durations,
		"时代时长表应为 [300,480,900,1200,1800]，实际 %s" % str(main.ERA_DURATION_SEC)
	)
	_check(is_equal_approx(main._era_duration_for(0), 300.0), "石器时长应为 300s")
	_check(is_equal_approx(main._era_duration_for(1), 480.0), "铁器时长应为 480s")
	_check(is_equal_approx(main._era_duration_for(2), 900.0), "工业时长应为 900s")
	_check(is_equal_approx(main._era_duration_for(3), 1200.0), "现代时长应为 1200s")
	_check(is_equal_approx(main._era_duration_for(4), 1800.0), "未来时长应为 1800s")

	# 同局抽空牌堆 → 只推进轮次，不跨时代
	var era_before: int = main.enemy_era_index
	_take_reward(main._show_round_reward)
	await process_frame
	_check(main.round_number == 2, "抽空牌堆应进入第 2 轮，实际 %d" % main.round_number)
	_check(main.enemy_era_index == era_before, "抽空牌堆不得推进敌方时代")
	_check(main.era_index >= 1, "第 2 轮牌池时代应升到铁器，实际 %d" % main.era_index)
	_check(_deck_has_era_card("iron"), "第 2 轮牌堆应混入铁器时代卡")
	_check(_deck_has_era_card("stone"), "第 2 轮牌堆应仍保留石器时代卡")

	# 奖励/暂停冻结时代计时
	main.era_elapsed = 10.0
	main.battle_elapsed = 10.0
	main.reward_active = true
	main._process(1.0)
	main.reward_active = false
	_check(is_equal_approx(main.era_elapsed, 10.0), "奖励面板打开时 era_elapsed 应冻结")
	_check(is_equal_approx(main.battle_elapsed, 10.0), "奖励面板打开时 battle_elapsed 应冻结")
	main.paused = true
	main._process(1.0)
	main.paused = false
	_check(is_equal_approx(main.era_elapsed, 10.0), "暂停时 era_elapsed 应冻结")

	# 正常战斗累计，且到期不失败
	main.battle_ended = false
	main.battle_active = true
	main.era_elapsed = 10.0
	main.battle_elapsed = 10.0
	main._process(1.0)
	_check(main.era_elapsed > 10.0, "正常战斗时 era_elapsed 应递增")
	_check(not main.battle_ended, "时代计时不应导致失败")

	# 到期推进时代（不丢牌、不清己方单位）
	main.run_atk_mult = 1.5
	main.free_reshuffles = 2
	var coin_before_time: int = main.coin_count
	var deck_before: int = main.deck_cards.size()
	main._summon_reinforcement(false)
	var ally_before: int = main._living_units("ally").size()
	main.era_elapsed = main._era_duration_for(0)
	main.enemy_era_index = 0
	main.enemy_era = "stone"
	main._advance_enemy_era_by_time()
	_check(main.enemy_era_index == 1, "时间推进后应进入铁器时代")
	_check(main.enemy_era == "iron", "敌方时代应为 iron")
	_check(is_equal_approx(main.era_elapsed, 0.0), "推进后 era_elapsed 应重置为 0")
	_check(main.era_index >= 1, "玩家牌池下限应跟上敌方时代")
	_check(main.deck_cards.size() == deck_before, "时间推进不得丢弃牌堆")
	_check(main._living_units("ally").size() == ally_before, "时间推进应保留己方单位")
	_check(main.coin_count == coin_before_time, "时间推进不应发放毁塔金币")
	_check(
		is_equal_approx(main.enemy_tower_hp, main.enemy_tower_max_hp),
		"新时代敌塔应满血"
	)
	_check(
		is_equal_approx(main.enemy_tower_max_hp, GameData.tower_hp("iron")),
		"新时代敌塔血量应取铁器值"
	)

	# 毁塔：加金币 + 加塔分 + 重建 + 不清牌堆 / 不弹奖励面板 / 不推进时代
	var destroy_era: int = main.enemy_era_index
	var coin_before: int = main.coin_count
	var score_before: int = main.kill_score
	var expected_gold: int = main._tower_destroy_gold()
	var expected_score: int = main._tower_destroy_score()
	_check(expected_score == main.TOWER_DESTROY_SCORE_BASE or expected_score >= main.TOWER_DESTROY_SCORE_BASE,
		"塔分应按时代放大，基准 %d 实际 %d" % [main.TOWER_DESTROY_SCORE_BASE, expected_score])
	main.tray_cards.append(GameData.cards_for_era(main.current_era)[0])
	var tray_before: int = main.tray_cards.size()
	main._summon_reinforcement(false)
	main.enemy_tower_hp = 0.0
	main._on_enemy_tower_destroyed()
	await process_frame
	_check(not main.reward_active, "毁塔不得打开任何奖励面板（reward_active）")
	_check(
		main.reward_overlay == null or not main.reward_overlay.visible,
		"毁塔后奖励 overlay 必须不可见"
	)
	_check(main.reward_context != "stage_clear", "毁塔不得进入 stage_clear 上下文")
	# 废止路径硬拒绝：即便误调也不应弹板
	main._show_reward("stage_clear")
	_check(not main.reward_active, "stage_clear 路径必须被拒绝")
	_check(
		main.reward_overlay == null or not main.reward_overlay.visible,
		"误调 stage_clear 后 overlay 仍须不可见"
	)
	_check(main.enemy_era_index == destroy_era, "毁塔不得推进敌方时代")
	_check(main.coin_count == coin_before + expected_gold, "毁塔应发放大量金币，期望 +%d 实际 %+d" % [
		expected_gold, main.coin_count - coin_before
	])
	_check(main.kill_score == score_before + expected_score, "毁塔应计入塔分，期望 +%d 实际 %+d" % [
		expected_score, main.kill_score - score_before
	])
	_check(main.tray_cards.size() == tray_before, "毁塔应保留合成台")
	_check(not main.deck_cards.is_empty(), "毁塔应保留牌堆")
	_check(
		is_equal_approx(main.enemy_tower_hp, main.enemy_tower_max_hp),
		"毁塔后敌塔应按当前时代满血重建"
	)
	_check(main._living_units("enemy").is_empty(), "毁塔后应清除敌方单位")
	_check(not main.battle_ended, "毁塔不应结束战斗")
	_check(not main.tower_destruction_started, "毁塔不应触发终局胜利动画")

	# 未来时代毁塔也不强制胜利
	main.enemy_era_index = GameData.ERAS.size() - 1
	main.enemy_era = GameData.ERAS[main.enemy_era_index]
	main._rebuild_enemy_tower()
	main.enemy_tower_hp = 0.0
	main._on_enemy_tower_destroyed()
	await process_frame
	_check(not main.battle_ended, "未来时代毁塔也不应强制胜利结束")
	_check(not main.tower_destruction_started, "未来时代毁塔不应触发终局")
	_check(
		is_equal_approx(main.enemy_tower_hp, main.enemy_tower_max_hp),
		"未来时代毁塔后仍应重建敌塔"
	)

	# 到期推进封顶：已在未来时代时不再增加 index
	main.era_elapsed = main._era_duration_for(main.enemy_era_index)
	main._advance_enemy_era_by_time()
	_check(main.enemy_era_index == GameData.ERAS.size() - 1, "最后时代不得再推进")

	# UI 去关卡化
	main._update_progress_ui()
	_check(
		main.era_label != null and str(main.era_label.text).begins_with("时代："),
		"信息栏应以「时代：」开头，实际「%s」" % (main.era_label.text if main.era_label else "<null>")
	)
	_check(not str(main.era_label.text).contains("关"), "信息栏不应再含关卡语义")

	if failures.is_empty():
		print("time_era_smoke: OK")
	else:
		print("time_era_smoke: %d 项失败" % failures.size())
		for message in failures:
			print("  - %s" % message)
	quit(0 if failures.is_empty() else 1)

func _deck_has_era_card(era: String) -> bool:
	var era_cards := GameData.cards_for_era(era)
	for card in main.deck_cards:
		if era_cards.has(card.card_id):
			return true
	return false

func _take_reward(opener: Callable) -> void:
	if opener.is_valid():
		opener.call()
	if not main.reward_active:
		failures.append("奖励面板未打开")
		return
	main._on_reward_button_pressed(0)
	main._on_reward_confirm_pressed()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
