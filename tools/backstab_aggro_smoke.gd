extends SceneTree

## 身后近战还击仇恨验收冒烟：身后近战打中 → 短时优先还击；phase_execute untargetable 结束后仇恨仍生效
## 用法：godot --headless --path . --script tools/backstab_aggro_smoke.gd

var main: Node
var failures: Array[String] = []

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	main.sandbox_mode = true
	main._remove_battle_units()
	await process_frame

	_test_backstab_registers_and_prioritizes()
	_test_front_hit_does_not_register()
	_test_ranged_behind_does_not_register()
	_test_tower_damage_does_not_register()
	_test_phase_execute_window_survives_untargetable()
	_test_front_priority_still_default()

	if failures.is_empty():
		print("backstab_aggro_smoke: OK")
	else:
		print("backstab_aggro_smoke: %d 项失败" % failures.size())
		for message in failures:
			print("  - %s" % message)
	quit(0 if failures.is_empty() else 1)

func _check(cond: bool, message: String) -> void:
	if not cond:
		failures.append(message)

func _living(side: String) -> Array[BattleUnit]:
	var out: Array[BattleUnit] = []
	for unit in main.battle_units:
		if is_instance_valid(unit) and unit.alive and unit.faction == side:
			out.append(unit)
	return out

func _test_backstab_registers_and_prioritizes() -> void:
	main._remove_battle_units()
	var victim: BattleUnit = main._spawn_ally("stone_warrior")
	var front_decoy: BattleUnit = main._spawn_enemy("stone_ranged", 0, 2, false)
	var backstabber: BattleUnit = main._spawn_enemy("stone_assassin", 1, 2, false)
	_check(victim != null and front_decoy != null and backstabber != null, "用例1：单位生成失败")
	if victim == null:
		return
	# 己方朝右：前方 decoy 在右，刺客在身后（左）
	victim.position = Vector2(600, main.BATTLE_GROUND_Y)
	front_decoy.position = Vector2(720, main.BATTLE_GROUND_Y)
	backstabber.position = Vector2(540, main.BATTLE_GROUND_Y)
	# 无仇恨时仍前方优先
	var before: BattleUnit = main._find_target(victim, _living("ally"), _living("enemy"))
	_check(before == front_decoy, "用例1：无背后仇恨时应前方优先选 decoy")
	main._deal_damage(victim, 1.0, "hero", backstabber)
	_check(victim.backstab_retaliate_time >= main.BACKSTAB_RETALIATE_DURATION - 0.01, "用例1：身后近战应注册还击窗口")
	_check(victim.backstab_retaliate_by == backstabber, "用例1：还击目标应为身后攻击者")
	var after: BattleUnit = main._find_target(victim, _living("ally"), _living("enemy"))
	_check(after == backstabber, "用例1：仇恨窗口内应优先还击身后攻击者（即使前方有 decoy）")

func _test_front_hit_does_not_register() -> void:
	main._remove_battle_units()
	var victim: BattleUnit = main._spawn_ally("stone_warrior")
	var front_attacker: BattleUnit = main._spawn_enemy("stone_assassin", 0, 1, false)
	victim.position = Vector2(600, main.BATTLE_GROUND_Y)
	front_attacker.position = Vector2(660, main.BATTLE_GROUND_Y)
	main._deal_damage(victim, 1.0, "hero", front_attacker)
	_check(victim.backstab_retaliate_time <= 0.0, "用例2：前方近战打中不应注册背后还击")

func _test_ranged_behind_does_not_register() -> void:
	main._remove_battle_units()
	var victim: BattleUnit = main._spawn_ally("stone_warrior")
	var ranged: BattleUnit = main._spawn_enemy("stone_ranged", 0, 1, false)
	victim.position = Vector2(600, main.BATTLE_GROUND_Y)
	ranged.position = Vector2(400, main.BATTLE_GROUND_Y)
	main._deal_damage(victim, 1.0, "hero", ranged)
	_check(victim.backstab_retaliate_time <= 0.0, "用例3：身后远程英雄伤害不应注册近战还击窗口")

func _test_tower_damage_does_not_register() -> void:
	main._remove_battle_units()
	var victim: BattleUnit = main._spawn_ally("stone_warrior")
	var dummy: BattleUnit = main._spawn_enemy("stone_assassin", 0, 1, false)
	victim.position = Vector2(600, main.BATTLE_GROUND_Y)
	dummy.position = Vector2(540, main.BATTLE_GROUND_Y)
	main._deal_damage(victim, 1.0, "tower", dummy)
	_check(victim.backstab_retaliate_time <= 0.0, "用例4：塔伤害不应注册背后还击")

func _test_phase_execute_window_survives_untargetable() -> void:
	main._remove_battle_units()
	var victim: BattleUnit = main._spawn_enemy("stone_warrior", 0, 1, false)
	var assassin: BattleUnit = main._spawn_ally("fut_assassin")
	var front_decoy: BattleUnit = main._spawn_ally("stone_ranged")
	_check(victim != null and assassin != null and front_decoy != null, "用例5：单位生成失败")
	if victim == null or assassin == null:
		return
	# 敌方朝左：己方刺客 phase_execute 会瞬到 victim.x + facing(+1)*44 = 身后（更大 x）
	victim.position = Vector2(900, main.BATTLE_GROUND_Y)
	assassin.position = Vector2(820, main.BATTLE_GROUND_Y)
	front_decoy.position = Vector2(760, main.BATTLE_GROUND_Y) # 敌方前方（更小 x）的诱饵
	assassin.energy = float(assassin.skill_cost)
	main._cast_phase_execute(assassin, victim)
	_check(assassin.untargetable_time >= 1.4, "用例5：phase_execute 应保留 untargetable≈1.5s")
	_check(assassin.position.x > victim.position.x, "用例5：刺客应瞬到敌方身后")
	_check(victim.backstab_retaliate_by == assassin, "用例5：相位斩命中应注册背后仇恨")
	_check(
		victim.backstab_retaliate_time >= assassin.untargetable_time + main.BACKSTAB_RETALIATE_DURATION - 0.05,
		"用例5：窗口应覆盖 untargetable + 还击时长（实际 %.2f）" % victim.backstab_retaliate_time
	)
	# untargetable 期间刺客不可被选中 → 回落前方 decoy
	var during: BattleUnit = main._find_target(victim, _living("ally"), _living("enemy"))
	_check(during == front_decoy, "用例5：untargetable 期间应回落前方优先（decoy）")
	# 模拟 untargetable 结束
	assassin.untargetable_time = 0.0
	var after: BattleUnit = main._find_target(victim, _living("ally"), _living("enemy"))
	_check(after == assassin, "用例5：untargetable 结束后应优先还击背后刺客")

func _test_front_priority_still_default() -> void:
	main._remove_battle_units()
	var unit: BattleUnit = main._spawn_ally("stone_warrior")
	var front: BattleUnit = main._spawn_enemy("stone_assassin", 0, 2, false)
	var behind: BattleUnit = main._spawn_enemy("stone_warrior", 1, 2, false)
	unit.position = Vector2(600, main.BATTLE_GROUND_Y)
	front.position = Vector2(680, main.BATTLE_GROUND_Y)
	behind.position = Vector2(520, main.BATTLE_GROUND_Y)
	unit.backstab_retaliate_time = 0.0
	unit.backstab_retaliate_by = null
	var picked: BattleUnit = main._find_target(unit, _living("ally"), _living("enemy"))
	_check(picked == front, "用例6：无背后仇恨时前方优先仍生效")
