extends SceneTree

## 远征修复冒烟：重排 100 金币边界 + 「当前/需要」数额提示；奖励遮罩压过信息栏、
## 奖励期热区收起且暂停被锁；四按钮统一 46x46；拆塔后存活己方小兵回撤出生区再出发
## 用法：godot --headless --path . --script tools/expedition_fix_smoke.gd

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
	main.reward_active = false
	main._sync_reshuffle_hit_pad()

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main._start_round(0)
	await process_frame
	if main.has_method("_hide_tutorial"):
		main._hide_tutorial()
	_ensure_battle_ui()
	main.paused = false
	main.auto_prep = false
	await process_frame
	main._sync_reshuffle_hit_pad()

	var save_manager: Node = root.get_node_or_null("SaveManager")
	_check(save_manager != null, "应能访问 SaveManager autoload")
	if save_manager != null:
		save_manager.set_reshuffle_hint_seen(true)

	# —— A. 金币边界（费用 100，仅扣一次；拦截提示带数额）——
	_check(main.RESHUFFLE_COST == 100, "重排费用应为 100，实际 %d" % main.RESHUFFLE_COST)
	main.coin_count = 500
	main.free_reshuffles = 0
	main._update_coin_ui()
	_gui_click(main.reshuffle_hit_pad)
	await process_frame
	await process_frame
	if main.coin_count == 500:
		main._on_reshuffle_pressed()
		await process_frame
	_check(main.coin_count == 400, "coin=500 重排一次应扣 100 且仅扣一次，实际 %d" % main.coin_count)
	_check(main.toast_overlay != null and main.toast_overlay.visible, "扣费重排应显示 toast")
	_check(main.toast_label != null and str(main.toast_label.text).contains("已重排"), "成功 toast 应含已重排: %s" % (main.toast_label.text if main.toast_label else ""))

	main.coin_count = 100
	main.free_reshuffles = 0
	main._update_coin_ui()
	_check(main._reshuffle_block_reason() == "", "coin=100 边界应可重排: %s" % main._reshuffle_block_reason())
	main._on_reshuffle_pressed()
	await process_frame
	_check(main.coin_count == 0, "coin=100 应重排成功且余 0，实际 %d" % main.coin_count)

	main.coin_count = 99
	main.free_reshuffles = 0
	main._update_coin_ui()
	main._on_reshuffle_pressed()
	await process_frame
	_check(main.coin_count == 99, "coin=99 应被拦截且金币不变，实际 %d" % main.coin_count)
	_check(main.toast_overlay != null and main.toast_overlay.visible, "coin=99 拦截应显示 toast")
	var hint_text := str(main.battle_hint.text) if main.battle_hint != null else ""
	var toast_text := str(main.toast_label.text) if main.toast_label != null else ""
	_check(
		main._reshuffle_block_reason().contains("金币不足"),
		"coin=99 阻断原因应为金币不足: %s" % main._reshuffle_block_reason()
	)
	_check(
		hint_text.contains("当前 99 / 需要 100") or toast_text.contains("当前 99 / 需要 100"),
		"拦截提示应含数额「当前 99 / 需要 100」: hint=%s toast=%s" % [hint_text, toast_text]
	)

	# —— B. 层级（奖励遮罩压过信息栏；奖励期热区收起、暂停锁）——
	_check(main.reward_overlay.z_index == 4030, "reward_overlay z 应为 4030，实际 %d" % main.reward_overlay.z_index)
	_check(main.REWARD_OVERLAY_Z_INDEX == 4030, "REWARD_OVERLAY_Z_INDEX 常量应为 4030")
	_check(main.info_bar.z_index == 4005, "info_bar z 应为 4005，实际 %d" % main.info_bar.z_index)
	_check(main.reward_overlay.z_index > main.info_bar.z_index, "奖励遮罩应压过信息栏")
	_check(main.reward_overlay.z_index > main.main_menu.z_index, "奖励遮罩应压过主菜单")
	_check(main.reward_overlay.z_index < main.result_overlay.z_index, "结算层应仍在奖励遮罩之上")
	_check(main.reward_overlay.z_index < main.tutorial_overlay.z_index, "教程层应仍在奖励遮罩之上")
	_check(main.reward_overlay.z_index < main.toast_overlay.z_index, "toast 应仍在奖励遮罩之上")
	main._show_reward("round")
	await process_frame
	_check(main.reward_active, "奖励面板应打开")
	_check(main.reward_overlay.visible, "奖励遮罩应可见")
	main._sync_reshuffle_hit_pad()
	_check(not main.reshuffle_hit_pad.visible, "奖励期重排热区应收起（不得吞点击）")
	main.paused = false
	main._toggle_pause()
	await process_frame
	_check(not main.paused, "奖励期间 _toggle_pause 不应翻转 paused")
	_check(main.pause_overlay == null or not main.pause_overlay.visible, "奖励期间暂停遮罩不应出现")
	main.reward_active = false
	if main.reward_overlay != null:
		main.reward_overlay.visible = false
	main._sync_reshuffle_hit_pad()
	_check(main.reshuffle_hit_pad.visible, "奖励结束后热区应恢复可见")
	main._toggle_pause()
	await process_frame
	_check(main.paused, "奖励结束后 _toggle_pause 应恢复正常")
	main._toggle_pause()
	await process_frame
	_check(not main.paused, "再次 _toggle_pause 应取消暂停")

	# —— C. 尺寸（四按钮统一 46x46；热区 ≥64 且包住视觉按钮）——
	_check(main.reshuffle_button.size == Vector2(46, 46), "重排按钮应为 46x46，实际 %s" % str(main.reshuffle_button.size))
	_check(main.pause_button.size == Vector2(46, 46), "暂停按钮应为 46x46，实际 %s" % str(main.pause_button.size))
	_check(main.help_button.size == Vector2(46, 46), "帮助按钮应为 46x46，实际 %s" % str(main.help_button.size))
	_check(main.return_button.size == Vector2(46, 46), "返回按钮应为 46x46，实际 %s" % str(main.return_button.size))
	_check(main.reshuffle_button.position.y == 9.0, "重排按钮 y 应为 9，实际 %s" % str(main.reshuffle_button.position.y))
	_check(main.reshuffle_button.position.x == 477.0, "重排按钮 x 应为 477（中心 x=500），实际 %s" % str(main.reshuffle_button.position.x))
	_check(main.reshuffle_hit_pad.size.x >= 64.0 and main.reshuffle_hit_pad.size.y >= 64.0, "热区应 ≥ 64x64，实际 %s" % str(main.reshuffle_hit_pad.size))
	_check(
		main.reshuffle_hit_pad.get_global_rect().encloses(main.reshuffle_button.get_global_rect()),
		"热区应完整包住重排视觉按钮"
	)

	# —— D. 拆塔回撤（存活 ally 回出生区、保留属性、随后重新出发）——
	var ids := GameData.heroes_for_era(main.current_era)
	_check(not ids.is_empty(), "当前时代应有可召唤英雄")
	var hero_id: String = str(ids[0]) if not ids.is_empty() else ""
	var occ_before: int = main.occupied_units
	for i in range(3):
		main._spawn_ally(hero_id)
	await process_frame
	var allies := main._living_units("ally")
	var ally_count := allies.size()
	_check(ally_count >= 3, "应构造 ≥3 个 ally，实际 %d" % ally_count)
	var hp_snapshot := {}
	for unit in allies:
		hp_snapshot[unit.get_instance_id()] = unit.hp
		unit.position.x = main.ENEMY_TOWER_X - 120.0
	main.enemy_tower_hp = 0.0
	main._on_enemy_tower_destroyed()
	await process_frame
	var after := main._living_units("ally")
	_check(after.size() == ally_count, "拆塔后存活 ally 数应不变，期望 %d 实际 %d" % [ally_count, after.size()])
	_check(main.occupied_units == occ_before + ally_count, "回撤不应改变 occupied_units，实际 %d" % main.occupied_units)
	var x_min: float = main.ALLY_TOWER_X + 60.0
	var x_max: float = main.ALLY_TOWER_X + 96.0 + 6.0 * 48.0 + 28.0
	for unit in after:
		_check(unit.alive, "回撤 ally 应存活")
		_check(
			is_equal_approx(unit.hp, float(hp_snapshot.get(unit.get_instance_id(), unit.hp))),
			"回撤 ally 血量应保留"
		)
		_check(
			unit.position.x >= x_min and unit.position.x <= x_max,
			"ally 应回到我方塔前出生区（x∈[%s,%s]），实际 %s" % [x_min, x_max, unit.position.x]
		)
		_check(
			absf(unit.position.y - main.BATTLE_GROUND_Y) <= 30.0,
			"ally y 应接近地面线 ±30，实际 %s" % str(unit.position.y)
		)
		_check(unit.taunted_by == null and unit.backstab_retaliate_by == null, "回撤后仇恨引用应清空")
	_check(main._living_units("enemy").is_empty(), "拆塔后敌方单位应清空")
	_check(is_equal_approx(main.enemy_tower_hp, main.enemy_tower_max_hp), "敌塔应满血重建")
	_check(not main.battle_ended, "拆塔不应结束战斗")
	var x_before := {}
	for unit in after:
		x_before[unit.get_instance_id()] = unit.position.x
	for i in range(90):
		main._step_battle(1.0 / 60.0)
	var marched := main._living_units("ally")
	_check(marched.size() == ally_count, "再出发阶段 ally 数应不变，实际 %d" % marched.size())
	for unit in marched:
		var from: float = float(x_before.get(unit.get_instance_id(), unit.position.x))
		_check(unit.position.x > from, "ally 应重新出发（x 递增），%s → %s" % [from, unit.position.x])

	if failures.is_empty():
		print("expedition_fix_smoke: OK")
	else:
		print("expedition_fix_smoke: %d FAILURES" % failures.size())
		for f in failures:
			print(" - ", f)
	quit(0 if failures.is_empty() else 1)
