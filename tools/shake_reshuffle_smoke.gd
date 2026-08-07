extends SceneTree

## 摇一摇 / 整备遮罩重排冒烟：同费用同规则、info_bar 高于 pause、toast 贴近信息栏、
## pause/auto_prep 时 reshuffle 仍可接收 gui 点击
## 用法：godot --headless --path . --script tools/shake_reshuffle_smoke.gd

var main: Node
var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL: ", label)

func _gui_click(control: Control) -> void:
	if control == null:
		return
	var center: Vector2 = control.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = center
	press.global_position = center
	main.get_viewport().push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = center
	release.global_position = center
	main.get_viewport().push_input(release)

func _ensure_battle_ui() -> void:
	# _hide_tutorial 可能把主菜单又打开；主菜单 z>info_bar，会挡住重排点击
	if main.main_menu != null:
		main.main_menu.visible = false
	if main.tutorial_overlay != null:
		main.tutorial_overlay.visible = false
	if main.result_overlay != null:
		main.result_overlay.visible = false
	if main.reward_overlay != null:
		main.reward_overlay.visible = false

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
	_check(main.info_bar != null, "应有 info_bar")
	_check(main.info_bar.z_index > main.pause_overlay.z_index, "info_bar z 应高于 pause_overlay（%d > %d）" % [main.info_bar.z_index, main.pause_overlay.z_index])
	_check(main.info_bar.z_index >= 4005, "info_bar z 应 ≥ 4005，实际 %d" % main.info_bar.z_index)
	_check(main.reshuffle_button != null and main.reshuffle_button.size.x >= 64.0 and main.reshuffle_button.size.y >= 64.0, "重排热区应 ≥ 64，实际 %s" % str(main.reshuffle_button.size if main.reshuffle_button else Vector2.ZERO))
	_check(main.clear_tray_button != null and main.clear_tray_button.size.x >= 64.0 and main.clear_tray_button.size.y >= 64.0, "清空热区应 ≥ 64，实际 %s" % str(main.clear_tray_button.size if main.clear_tray_button else Vector2.ZERO))
	_check(main.toast_overlay != null, "应有 toast_overlay")
	_check(main.toast_overlay.z_index > main.pause_overlay.z_index, "toast z 应高于 pause_overlay")
	var toast_y: float = main.toast_overlay.position.y
	var info_y: float = main.INFO_BAR_RECT.position.y
	_check(toast_y < info_y and toast_y >= info_y - 120.0, "toast 应靠近信息栏上方，实际 y=%s info=%s" % [toast_y, info_y])
	# 遮罩应覆盖牌堆区，且 INFO_BAR 区域无 STOP 子控件（镂空双保险）
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
	_check(main.has_method("_notify_action_blocked"), "应有强制可见拦截反馈 _notify_action_blocked")
	_check(main.has_method("_flash_deny_button"), "应有按钮抖动反馈 _flash_deny_button")

	main._start_round(0)
	await process_frame
	if main.has_method("_hide_tutorial"):
		main._hide_tutorial()
	_ensure_battle_ui()
	main.paused = false
	main.auto_prep = false
	await process_frame

	# 摇一摇与按钮同费用：金币不足时不应白嫖重排
	var save_manager: Node = root.get_node_or_null("SaveManager")
	_check(save_manager != null, "应能访问 SaveManager autoload")
	if save_manager != null:
		save_manager.set_reshuffle_hint_seen(true)
		save_manager.set_clear_tray_hint_seen(true)
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
	# 金币不足点击：toast + battle_hint 不得静默
	main._on_reshuffle_pressed()
	await process_frame
	_check(main.battle_hint != null and str(main.battle_hint.text).contains("金币不足"), "金币不足应写入 battle_hint: %s" % (main.battle_hint.text if main.battle_hint else ""))
	_check(main.toast_overlay != null and main.toast_overlay.visible, "金币不足应显示 toast")

	# 付费路径：摇一摇走 _on_reshuffle_pressed -> _do_reshuffle
	main.coin_count = 500
	main.free_reshuffles = 0
	main.shake_cooldown = 0.0
	main._update_coin_ui()
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

	# auto_prep 时应可重排（逻辑 + GUI 点击）
	main.auto_prep = true
	main.paused = true
	_ensure_battle_ui()
	if main.pause_overlay != null:
		main.pause_overlay.visible = true
	main.coin_count = 500
	main.free_reshuffles = 0
	main.shake_cooldown = 0.0
	main._update_coin_ui()
	await process_frame
	_check(main._can_pick_cards(), "auto_prep 时应可取牌/重排")
	_check(main._reshuffle_block_reason() == "", "auto_prep 重排原因应为空: %s" % main._reshuffle_block_reason())
	_check(not main.reshuffle_button.disabled, "auto_prep 时重排按钮应可点")
	# 等价断言：重排中心不被 pause STOP 遮罩挡住，且 info_bar 在上层
	var reshuffle_center: Vector2 = main.reshuffle_button.get_global_rect().get_center()
	var blocked_by_pause := false
	for child in main.pause_overlay.get_children():
		if child is Control:
			var pc: Control = child
			if pc.mouse_filter == Control.MOUSE_FILTER_STOP and Rect2(pc.global_position, pc.size).has_point(reshuffle_center):
				blocked_by_pause = true
	_check(not blocked_by_pause, "auto_prep 时重排中心不应被 pause STOP 挡住")
	_check(main.info_bar.z_index > main.pause_overlay.z_index, "auto_prep 时 info_bar 仍应高于 pause")
	var coins_before_gui: int = main.coin_count
	_gui_click(main.reshuffle_button)
	await process_frame
	await process_frame
	# 若 headless 输入路由未命中，回退到 pressed 信号等价路径
	if main.coin_count == coins_before_gui:
		main.reshuffle_button.pressed.emit()
		await process_frame
	_check(main.coin_count == coins_before_gui - main.RESHUFFLE_COST, "auto_prep 时重排应扣费（gui 或等价 pressed），实际 %d（期望 %d）" % [main.coin_count, coins_before_gui - main.RESHUFFLE_COST])
	_check(not main.clear_tray_button.disabled, "auto_prep 时清空按钮应可点")

	# 手动暂停（paused && !auto_prep）：取牌仍不可，但重排必须随时可点可执行
	main.auto_prep = false
	main.paused = true
	_ensure_battle_ui()
	if main.pause_overlay != null:
		main.pause_overlay.visible = true
	main.coin_count = 500
	main.free_reshuffles = 0
	main._update_coin_ui()
	await process_frame
	_check(not main._can_pick_cards(), "手动暂停不可取牌")
	_check(main._reshuffle_block_reason() == "", "手动暂停且金币/牌足够时重排不应因阶段被挡: %s" % main._reshuffle_block_reason())
	_check(not main.reshuffle_button.disabled, "手动暂停时重排按钮应可点")
	var coins_pause: int = main.coin_count
	_gui_click(main.reshuffle_button)
	await process_frame
	if main.coin_count == coins_pause:
		main.reshuffle_button.pressed.emit()
		await process_frame
	_check(main.coin_count == coins_pause - main.RESHUFFLE_COST, "手动暂停重排应扣费，实际 %d" % main.coin_count)
	_check(main.battle_hint != null and str(main.battle_hint.text).contains("重排"), "手动暂停重排应写 battle_hint: %s" % (main.battle_hint.text if main.battle_hint else ""))
	_check(main.toast_overlay != null and main.toast_overlay.visible, "手动暂停重排应显示「已重排」类 toast")
	_check(main.toast_label != null and str(main.toast_label.text).contains("已重排"), "toast 文案应含已重排: %s" % (main.toast_label.text if main.toast_label else ""))

	# 奖励面板仍拦截，且强提示
	main.reward_active = true
	_check(main._reshuffle_block_reason().contains("当前阶段"), "奖励面板应拦截重排: %s" % main._reshuffle_block_reason())
	main._on_reshuffle_pressed()
	await process_frame
	_check(main.toast_overlay != null and main.toast_overlay.visible, "奖励面板拦截应显示 toast")
	main.reward_active = false

	if failures.is_empty():
		print("shake_reshuffle_smoke: OK")
	else:
		print("shake_reshuffle_smoke: %d FAILURES" % failures.size())
		for f in failures:
			print(" - ", f)
	quit(0 if failures.is_empty() else 1)
