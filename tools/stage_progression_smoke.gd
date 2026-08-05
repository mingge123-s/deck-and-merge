extends SceneTree

## 关卡制冒烟测试：打爆敌塔=过关 → 下一关满血重建 / 清场 / 丢牌 / 保留金币与永久加成
## 用法：godot --headless --path . --script tools/stage_progression_smoke.gd

var main: Node
var failures: Array[String] = []

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main._start_round(0)
	await process_frame
	_check(main.enemy_era_index == 0, "起始关卡应为第 1 关")
	_check(main.era_index == 0, "起始玩家时代应锁定第 1 关（石器）")
	_check(main.round_number == 1, "起始应为本关第 1 轮，实际 %d" % main.round_number)

	# 同关内抽空牌堆 → 只推进轮次，不跨关
	var stage_before: int = main.enemy_era_index
	_take_reward(main._show_round_reward)
	await process_frame
	_check(main.round_number == 2, "同关抽空牌堆应进入第 2 轮，实际 %d" % main.round_number)
	_check(main.enemy_era_index == stage_before, "同关抽空牌堆不得跨关")
	_check(main.era_index >= 1, "第 1 关第 2 轮牌池时代应升到铁器，实际 %d" % main.era_index)
	_check(_deck_has_era_card("iron"), "第 1 关第 2 轮牌堆应混入铁器时代卡")
	_check(_deck_has_era_card("stone"), "第 1 关第 2 轮牌堆应仍保留石器时代卡")

	# 逐关过关
	main.run_atk_mult = 1.5
	main.free_reshuffles = 2
	main.free_clear_tokens = 1
	while main.enemy_era_index < GameData.ERAS.size() - 1:
		await _clear_stage()
		if main.enemy_era_index == 1:
			await _test_stage_two_rewards()
	# 最后一关打爆敌塔 → 胜利
	_check(main.enemy_era_index == GameData.ERAS.size() - 1, "应已抵达最后一关")
	main.enemy_tower_hp = 0.0
	main._on_enemy_tower_destroyed()
	await process_frame
	_check(main.tower_destruction_started, "最后一关打爆敌塔应触发终局")
	_check(not main.reward_active, "最后一关不应再弹过关奖励")

	if failures.is_empty():
		print("stage_progression_smoke: OK")
	else:
		print("stage_progression_smoke: %d 项失败" % failures.size())
		for message in failures:
			print("  - %s" % message)
	quit(0 if failures.is_empty() else 1)

func _clear_stage() -> void:
	var stage_before: int = main.enemy_era_index
	var coin_before: int = main.coin_count
	var atk_before: float = main.run_atk_mult
	var reshuffles_before: int = main.free_reshuffles
	var clears_before: int = main.free_clear_tokens
	main.tray_cards.append(GameData.cards_for_era(main.current_era)[0])
	main._summon_reinforcement(false)
	main.ally_tower_hp = main.ally_tower_max_hp * 0.3
	main.enemy_tower_hp = 0.0
	main._on_enemy_tower_destroyed()
	await process_frame
	_check(main.reward_active, "第 %d 关过关应弹出奖励面板" % (stage_before + 1))
	_take_reward(Callable())
	await process_frame
	var stage: int = main.enemy_era_index
	var label := "第 %d 关" % (stage + 1)
	_check(stage == stage_before + 1, "%s：过关后关卡应 +1" % label)
	_check(main.era_index >= stage, "%s：玩家牌池时代不得低于本关下限" % label)
	_check(main.base_era_index >= stage, "%s：牌池时代下限应提到本关" % label)
	_check(main.round_number == 1, "%s：过关后应从第 1 轮开始，实际 %d" % [label, main.round_number])
	_check(not main.deck_cards.is_empty(), "%s：过关后应发出本关第 1 轮牌" % label)
	_check(main.tray_cards.is_empty(), "%s：过关应丢弃合成台剩牌" % label)
	_check(main.battle_units.is_empty(), "%s：过关应清空双方所有小兵" % label)
	_check(
		is_equal_approx(main.enemy_tower_hp, main.enemy_tower_max_hp),
		"%s：敌塔应按本关满血重建" % label
	)
	_check(
		is_equal_approx(main.ally_tower_hp, main.ally_tower_max_hp),
		"%s：己方塔应满血开新关" % label
	)
	_check(
		is_equal_approx(main.enemy_tower_max_hp, GameData.tower_hp(main.enemy_era)),
		"%s：敌塔血量应取本关时代值" % label
	)
	_check(main.coin_count >= coin_before, "%s：过关应保留金币" % label)
	_check(main.run_atk_mult >= atk_before, "%s：过关应保留 run_* 永久加成" % label)
	_check(main.free_reshuffles >= reshuffles_before, "%s：过关应保留免费重排次数" % label)
	_check(main.free_clear_tokens >= clears_before, "%s：过关应保留免费清台次数" % label)

func _deck_has_era_card(era: String) -> bool:
	var era_cards := GameData.cards_for_era(era)
	for card in main.deck_cards:
		if era_cards.has(card.card_id):
			return true
	return false

func _test_stage_two_rewards() -> void:
	# 第 2 关抽空牌堆只推进轮次，不应误触发过关。
	main._show_round_reward()
	_check(main.reward_active, "第 2 关抽空牌堆应弹出轮次奖励")
	_check(main.reward_context == "round", "第 2 关抽空牌堆奖励上下文应为 round")
	_take_reward(Callable())
	await process_frame
	_check(main.round_number == 2, "第 2 关抽空牌堆后应进入第 2 轮，实际 %d" % main.round_number)
	_check(main.enemy_era_index == 1, "第 2 关抽空牌堆不得跨关")

	# 轮次奖励展示期间摧毁敌塔，过关奖励应排队并在确认轮次奖励后弹出。
	main._show_round_reward()
	_check(main.reward_active, "第 2 关应可再次打开轮次奖励")
	main.enemy_tower_hp = 0.0
	main._on_enemy_tower_destroyed()
	_check(main.stage_clear_pending, "轮次奖励期间摧毁敌塔应排队过关奖励")
	_take_reward(Callable())
	await process_frame
	_check(main.reward_active, "确认轮次奖励后应弹出排队的过关奖励")
	_check(main.reward_context == "stage_clear", "排队奖励上下文应为 stage_clear")
	_take_reward(Callable())
	await process_frame
	_check(main.enemy_era_index == 2, "确认排队过关奖励后应进入第 3 关")
	_check(not main.reward_active, "确认排队过关奖励后不应卡在奖励状态")

## 打开（可选）奖励面板并确认第一个选项
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
