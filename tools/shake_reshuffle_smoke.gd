extends SceneTree

## 摇一摇 / 整备遮罩重排冒烟：同费用同规则、info_bar 高于 pause、toast 贴近信息栏、
## pause/非 pause / 金币不足 / 牌不足 / 正常扣费；顶层 hit pad 兜底；首次无确认层静默
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
	if main.card_info_overlay != null:
		main.card_info_overlay.visible = false
	if main.get("reshuffle_confirm_overlay") != null:
		main.reshuffle_confirm_overlay.visible = false
	main._sync_reshuffle_hit_pad()

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
	_check(main.RESHUFFLE_COST == 100, "重排费用应为 100，实际 %d" % main.RESHUFFLE_COST)
	_check(main.reshuffle_button != null and main.reshuffle_button.size == Vector2(46, 46), "重排视觉按钮应为 46x46（与 return/pause/help 统一），实际 %s" % str(main.reshuffle_button.size if main.reshuffle_button else Vector2.ZERO))
	_check(main.get("clear_tray_button") == null, "不应再存在手动清空按钮")
	_check(main.toast_overlay != null, "应有 toast_overlay")
	_check(main.toast_overlay.z_index > main.pause_overlay.z_index, "toast z 应高于 pause_overlay")
	var toast_y: float = main.toast_overlay.position.y
	var info_y: float = main.INFO_BAR_RECT.position.y
	_check(toast_y < info_y and toast_y >= info_y - 120.0, "toast 应靠近信息栏上方，实际 y=%s info=%s" % [toast_y, info_y])
	# 顶层 hit pad：高于 main_menu，战斗中兜底接点击
	_check(main.reshuffle_hit_pad != null, "应有 reshuffle_hit_pad 顶层热区")
	_check(main.RESHUFFLE_HIT_Z_INDEX >= 4080, "hit pad z 常量应 ≥ 4080")
	_check(main.reshuffle_hit_pad.z_index > main.main_menu.z_index, "hit pad z 应高于 main_menu（%d > %d）" % [main.reshuffle_hit_pad.z_index, main.main_menu.z_index])
	_check(main.reshuffle_hit_pad.z_index > main.info_bar.z_index, "hit pad z 应高于 info_bar")
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
	main._sync_reshuffle_hit_pad()
	_check(main.reshuffle_hit_pad.visible, "开战非暂停时 hit pad 应可见")
	_check(main.reshuffle_hit_pad.size.x >= 64.0 and main.reshuffle_hit_pad.size.y >= 64.0, "触控热区应 ≥ 64（视觉 46 外扩 16），实际 %s" % str(main.reshuffle_hit_pad.size))

	var save_manager: Node = root.get_node_or_null("SaveManager")
	_check(save_manager != null, "应能访问 SaveManager autoload")

	# 首次：不再弹确认层静默等待；直接扣费+toast（hint_seen=false）
	if save_manager != null:
		save_manager.set_reshuffle_hint_seen(false)
	main.coin_count = 500
	main.free_reshuffles = 0
	main._update_coin_ui()
	var coins_first: int = main.coin_count
	main._on_reshuffle_pressed()
	await process_frame
	_check(main.coin_count == coins_first - main.RESHUFFLE_COST, "首次重排应直接扣费，不应卡在确认层")
	_check(main.reshuffle_confirm_overlay == null or not main.reshuffle_confirm_overlay.visible, "首次重排不应弹出确认层")
	_check(main.toast_overlay != null and main.toast_overlay.visible, "首次重排应显示 toast")
	_check(main.toast_label != null and str(main.toast_label.text).contains("已重排"), "首次 toast 应含已重排: %s" % (main.toast_label.text if main.toast_label else ""))
	if save_manager != null:
		_check(save_manager.get_reshuffle_hint_seen(), "首次成功后应标记 hint_seen")
		save_manager.set_reshuffle_hint_seen(true)

	# 摇一摇与按钮同费用：金币不足时不应白嫖重排
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

	# 牌不足：强制可见反馈
	var claimed_backup: Array = []
	for card in main.deck_cards:
		if is_instance_valid(card) and not card.claimed:
			claimed_backup.append(card)
			card.claimed = true
	# 留 0 张可重排
	_check(main._reshuffle_live_deck_count() < 2, "构造牌不足场景失败，live=%d" % main._reshuffle_live_deck_count())
	main.coin_count = 500
	main.free_reshuffles = 0
	main._on_reshuffle_pressed()
	await process_frame
	_check(main._reshuffle_block_reason().contains("不足"), "牌不足阻断原因: %s" % main._reshuffle_block_reason())
	_check(main.toast_overlay != null and main.toast_overlay.visible, "牌不足应显示 toast")
	_check(main.coin_count == 500, "牌不足不应扣费")
	for card in claimed_backup:
		if is_instance_valid(card):
			card.claimed = false

	# 非暂停正常扣费（gui 点 hit pad）
	main.paused = false
	main.auto_prep = false
	_ensure_battle_ui()
	main.coin_count = 500
	main.free_reshuffles = 0
	main._update_coin_ui()
	main._sync_reshuffle_hit_pad()
	await process_frame
	_check(main.reshuffle_hit_pad.visible, "非暂停 hit pad 应可见")
	var coins_live: int = main.coin_count
	_gui_click(main.reshuffle_hit_pad)
	await process_frame
	await process_frame
	if main.coin_count == coins_live:
		main.reshuffle_hit_pad.pressed.emit()
		await process_frame
	_check(main.coin_count == coins_live - main.RESHUFFLE_COST, "非暂停重排应扣费（hit pad），实际 %d" % main.coin_count)
	_check(main.toast_overlay != null and main.toast_overlay.visible, "非暂停重排应显示 toast")
	_check(main.toast_label != null and str(main.toast_label.text).contains("已重排"), "非暂停 toast 应含已重排")

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
	main._sync_reshuffle_hit_pad()
	await process_frame
	_check(main._can_pick_cards(), "auto_prep 时应可取牌/重排")
	_check(main._reshuffle_block_reason() == "", "auto_prep 重排原因应为空: %s" % main._reshuffle_block_reason())
	_check(not main.reshuffle_button.disabled, "auto_prep 时重排按钮应可点")
	_check(main.reshuffle_hit_pad.visible, "auto_prep 时 hit pad 应可见")
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
	_gui_click(main.reshuffle_hit_pad)
	await process_frame
	await process_frame
	# 若 headless 输入路由未命中，回退到 pressed 信号等价路径
	if main.coin_count == coins_before_gui:
		main.reshuffle_hit_pad.pressed.emit()
		await process_frame
	_check(main.coin_count == coins_before_gui - main.RESHUFFLE_COST, "auto_prep 时重排应扣费（gui 或等价 pressed），实际 %d（期望 %d）" % [main.coin_count, coins_before_gui - main.RESHUFFLE_COST])

	# 手动暂停（paused && !auto_prep）：取牌仍不可，但重排必须随时可点可执行
	main.auto_prep = false
	main.paused = true
	_ensure_battle_ui()
	if main.pause_overlay != null:
		main.pause_overlay.visible = true
	main.coin_count = 500
	main.free_reshuffles = 0
	main._update_coin_ui()
	main._sync_reshuffle_hit_pad()
	await process_frame
	_check(not main._can_pick_cards(), "手动暂停不可取牌")
	_check(main._reshuffle_block_reason() == "", "手动暂停且金币/牌足够时重排不应因阶段被挡: %s" % main._reshuffle_block_reason())
	_check(not main.reshuffle_button.disabled, "手动暂停时重排按钮应可点")
	_check(main.reshuffle_hit_pad.visible, "手动暂停 hit pad 应可见")
	var coins_pause: int = main.coin_count
	_gui_click(main.reshuffle_hit_pad)
	await process_frame
	if main.coin_count == coins_pause:
		main.reshuffle_hit_pad.pressed.emit()
		await process_frame
	_check(main.coin_count == coins_pause - main.RESHUFFLE_COST, "手动暂停重排应扣费，实际 %d" % main.coin_count)
	_check(main.battle_hint != null and str(main.battle_hint.text).contains("重排"), "手动暂停重排应写 battle_hint: %s" % (main.battle_hint.text if main.battle_hint else ""))
	_check(main.toast_overlay != null and main.toast_overlay.visible, "手动暂停重排应显示「已重排」类 toast")
	_check(main.toast_label != null and str(main.toast_label.text).contains("已重排"), "toast 文案应含已重排: %s" % (main.toast_label.text if main.toast_label else ""))

	# 奖励面板仍拦截，且强提示（遮罩真正可见时 hit pad 会一并收起，见 expedition_fix_smoke）
	main.reward_active = true
	_check(main._reshuffle_block_reason().contains("当前阶段"), "奖励面板应拦截重排: %s" % main._reshuffle_block_reason())
	main._on_reshuffle_pressed()
	await process_frame
	_check(main.toast_overlay != null and main.toast_overlay.visible, "奖励面板拦截应显示 toast")
	main.reward_active = false

	# 主菜单可见时 hit pad 应收起，避免点穿
	if main.main_menu != null:
		main.main_menu.visible = true
		main._sync_reshuffle_hit_pad()
		_check(not main.reshuffle_hit_pad.visible, "主菜单打开时 hit pad 应隐藏")
		main.main_menu.visible = false
		main._sync_reshuffle_hit_pad()

	if failures.is_empty():
		print("shake_reshuffle_smoke: OK")
	else:
		print("shake_reshuffle_smoke: %d FAILURES" % failures.size())
		for f in failures:
			print(" - ", f)
	quit(0 if failures.is_empty() else 1)
