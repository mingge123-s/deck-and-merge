extends SceneTree

## 摇一摇 / 整备遮罩重排冒烟：同费用同规则、遮罩镂空 INFO_BAR、toast 贴近信息栏
## 用法：godot --headless --path . --script tools/shake_reshuffle_smoke.gd

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
	_check(main.SHAKE_JERK_THRESHOLD == 12.0, "摇动阈值应为 12")
	_check(main.has_method("_try_shake_deck"), "应有 _try_shake_deck")
	_check(main.has_method("_poll_shake_input"), "应有 _poll_shake_input")
	_check(main.pause_overlay != null, "应有 pause_overlay")
	_check(main.pause_overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "pause_overlay 根节点应 IGNORE 以镂空信息栏")
	_check(main.toast_overlay != null, "应有 toast_overlay")
	_check(main.toast_overlay.z_index > main.pause_overlay.z_index, "toast z 应高于 pause_overlay")
	var toast_y: float = main.toast_overlay.position.y
	var info_y: float = main.INFO_BAR_RECT.position.y
	_check(toast_y < info_y and toast_y >= info_y - 120.0, "toast 应靠近信息栏上方，实际 y=%s info=%s" % [toast_y, info_y])
	# 遮罩应覆盖牌堆区，且 INFO_BAR 区域无 STOP 子控件
	var info: Rect2 = main.INFO_BAR_RECT
	var info_center: Vector2 = info.position + info.size * 0.5
	var board_center: Vector2 = main.BOARD_RECT.position + main.BOARD_RECT.size * 0.5
	var has_info_hole := true
	var covers_board := false
	for child in main.pause_overlay.get_children():
		if child is Control:
			var c: Control = child
			var r := Rect2(c.position, c.size)
			if r.has_point(info_center) and c.mouse_filter == Control.MOUSE_FILTER_STOP:
				has_info_hole = false
			if r.has_point(board_center) and c.mouse_filter == Control.MOUSE_FILTER_STOP:
				covers_board = true
	_check(has_info_hole, "INFO_BAR 中心不应被 STOP 遮罩挡住")
	_check(covers_board, "BOARD 中心应被 STOP 遮罩挡住以防偷看")

	main._start_round(0)
	await process_frame
	if main.has_method("_hide_tutorial"):
		main._hide_tutorial()
	main.paused = false
	main.auto_prep = false
	await process_frame

	# 摇一摇与按钮同费用：金币不足时不应白嫖重排
	var save_manager: Node = root.get_node_or_null("SaveManager")
	_check(save_manager != null, "应能访问 SaveManager autoload")
	if save_manager != null:
		save_manager.set_reshuffle_hint_seen(true)
	main.coin_count = 0
	main.free_reshuffles = 0
	main._update_coin_ui()
	var live_before := 0
	for card in main.deck_cards:
		if is_instance_valid(card) and not card.claimed:
			live_before += 1
	_check(live_before >= 2, "开局牌堆应可重排，实际 %d" % live_before)
	main.shake_cooldown = 0.0
	main._try_shake_deck()
	await process_frame
	_check(main.coin_count == 0, "金币不足时摇一摇不应扣费/改变金币")
	_check(main._reshuffle_block_reason().contains("金币不足"), "阻断原因应提示金币不足: %s" % main._reshuffle_block_reason())

	# 付费路径：摇一摇走 _on_reshuffle_pressed -> _do_reshuffle
	main.coin_count = 500
	main.free_reshuffles = 0
	main.shake_cooldown = 0.0
	main._update_coin_ui()
	var order_before: Array[String] = []
	for card2 in main.deck_cards:
		if is_instance_valid(card2) and not card2.claimed:
			order_before.append("%s@%s" % [card2.card_id, str(card2.position)])
	main._try_shake_deck()
	await process_frame
	_check(main.coin_count == 500 - main.RESHUFFLE_COST, "摇一摇应付费 %d，实际金币 %d" % [main.RESHUFFLE_COST, main.coin_count])

	# 免费次数优先（与按钮一致）
	main.coin_count = 500
	main.free_reshuffles = 2
	main.shake_cooldown = 0.0
	main._update_coin_ui()
	main._try_shake_deck()
	await process_frame
	_check(main.free_reshuffles == 1, "摇一摇应优先消耗免费次数，剩 %d" % main.free_reshuffles)
	_check(main.coin_count == 500, "有免费次数时摇一摇不应扣金币")

	# auto_prep 时应可重排
	main.auto_prep = true
	main.paused = true
	main.coin_count = 500
	main.free_reshuffles = 0
	main.shake_cooldown = 0.0
	_check(main._can_pick_cards(), "auto_prep 时应可取牌/重排")
	_check(main._reshuffle_block_reason() == "", "auto_prep 重排原因应为空: %s" % main._reshuffle_block_reason())
	main._try_shake_deck()
	await process_frame
	_check(main.coin_count == 500 - main.RESHUFFLE_COST, "auto_prep 摇一摇应扣费，实际 %d" % main.coin_count)

	# 手动暂停（非 auto_prep）不可重排
	main.auto_prep = false
	main.paused = true
	_check(not main._can_pick_cards(), "手动暂停不可取牌")
	_check(main._reshuffle_block_reason().contains("当前阶段"), "手动暂停应拦截重排: %s" % main._reshuffle_block_reason())

	if failures.is_empty():
		print("shake_reshuffle_smoke: OK")
	else:
		print("shake_reshuffle_smoke: %d FAILURES" % failures.size())
		for f in failures:
			print(" - ", f)
	quit(0 if failures.is_empty() else 1)
