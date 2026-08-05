extends SceneTree

## 一键清空合成台冒烟测试：费用 100 / 免费次数优先 / 阻断原因 / 卡补回牌堆
## 用法：godot --headless --path . --script tools/clear_tray_smoke.gd

var main: Node
var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL: ", label)

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	_check(main.CLEAR_TRAY_COST == 100, "费用应为 100")
	# 战斗未开始：按钮禁用 + 原因
	_check(main.clear_tray_button != null, "应存在清空按钮")
	_check(main.clear_tray_button.disabled, "战斗未开始时按钮应禁用")
	main._start_round(0)
	await process_frame
	main._close_tutorial() if main.has_method("_close_tutorial") else null
	main.paused = false
	await process_frame
	main.tray_cards.clear()
	main._rebuild_tray_visuals()
	await process_frame
	_check(main._clear_tray_block_reason().contains("不足 3 张"), "空台原因: %s" % main._clear_tray_block_reason())
	_check(not main.clear_tray_button.disabled, "战斗中按钮应可点")
	# 放 4 张不同名卡（不会触发合成）
	var ids: Array = GameData.cards_for_era(main.current_era)
	for id in [ids[0], ids[1], ids[2], ids[3]]:
		main.tray_cards.append(id)
	main._rebuild_tray_visuals()
	await process_frame
	main.coin_count = 50
	main.free_clear_tokens = 0
	main._update_coin_ui()
	_check(main._clear_tray_block_reason().contains("金币不足"), "金币不足原因: %s" % main._clear_tray_block_reason())
	_check(main.clear_tray_button.text == "清空（100）", "按钮文案: %s" % main.clear_tray_button.text)
	# 免费次数优先
	main.free_clear_tokens = 1
	main._update_coin_ui()
	_check(main.clear_tray_button.text == "免费清空", "免费按钮文案: %s" % main.clear_tray_button.text)
	_check(main._clear_tray_block_reason() == "", "有免费次数应可清空")
	var deck_before: int = main.deck_cards.size()
	main._do_clear_tray(true)
	await process_frame
	_check(main.tray_cards.is_empty(), "清空后合成台应为空")
	_check(main.free_clear_tokens == 0, "应消耗免费次数")
	_check(main.coin_count == 50, "免费清空不应扣金币，实际 %d" % main.coin_count)
	_check(main.deck_cards.size() == deck_before + 4, "卡应补回牌堆，%d -> %d" % [deck_before, main.deck_cards.size()])
	# 付费清空
	for id2 in [ids[0], ids[1], ids[2]]:
		main.tray_cards.append(id2)
	main._rebuild_tray_visuals()
	main.coin_count = 130
	main._update_coin_ui()
	await process_frame
	main._do_clear_tray(true)
	await process_frame
	_check(main.coin_count == 30, "付费清空应扣 100，实际 %d" % main.coin_count)
	# 奖励面板打开时禁用
	main.reward_active = true
	main._update_clear_tray_button()
	_check(main.clear_tray_button.disabled, "奖励面板打开时应禁用")
	main.reward_active = false
	main.battle_ended = true
	main._update_clear_tray_button()
	_check(main.clear_tray_button.disabled, "战斗结束时应禁用")
	if failures.is_empty():
		print("clear_tray_smoke: OK")
	else:
		print("clear_tray_smoke: %d FAILURES" % failures.size())
	quit(0 if failures.is_empty() else 1)
