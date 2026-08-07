extends SceneTree

## 自动清台冒烟测试：满台无合成 → 免费次数优先 / 付费自动清 / 金币不足判负
## 用法：godot --headless --path . --script tools/clear_tray_smoke.gd

var main: Node
var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL: ", label)

func _fill_stuck_tray() -> void:
	# 7 格：最多 2 张同名单位卡 → 无三连、无效果二连，触发软锁清台
	# 例：图腾1 + 兽皮2 + 骨刃2 + 木棒2
	var ids: Array = GameData.cards_for_era(main.current_era)
	_check(ids.size() >= 4, "当前时代至少应有 4 种单位卡: %d" % ids.size())
	main.tray_cards.clear()
	main.tray_cards.append(ids[0])
	main.tray_cards.append(ids[1])
	main.tray_cards.append(ids[1])
	main.tray_cards.append(ids[2])
	main.tray_cards.append(ids[2])
	main.tray_cards.append(ids[3])
	main.tray_cards.append(ids[3])
	main.tray_incoming = 0
	main._rebuild_tray_visuals()

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	_check(main.CLEAR_TRAY_COST == 100, "费用应为 100")
	_check(main.get("clear_tray_button") == null, "不应再存在手动清空按钮")
	_check(not ResourceLoader.exists("res://assets/ui/clear_tray_icon.png"), "清空图标资源应已移除")
	# U8 信息栏抬升仍应保留（重排可点）
	_check(main.info_bar != null and main.info_bar.z_index >= 4005, "信息栏 z 应 ≥ 4005")
	main._start_round(0)
	await process_frame
	main._close_tutorial() if main.has_method("_close_tutorial") else null
	main.paused = false
	await process_frame

	# 免费次数优先：满台自动清台不扣金币
	_fill_stuck_tray()
	main.coin_count = 50
	main.free_clear_tokens = 1
	main._update_coin_ui()
	var deck_before: int = main.deck_cards.size()
	main._check_stuck()
	await process_frame
	_check(main.tray_cards.is_empty(), "自动清台后合成台应为空")
	_check(main.free_clear_tokens == 0, "应消耗免费清台次数")
	_check(main.coin_count == 50, "免费自动清台不应扣金币，实际 %d" % main.coin_count)
	_check(main.deck_cards.size() == deck_before + 7, "卡应补回牌堆，%d -> %d" % [deck_before, main.deck_cards.size()])
	_check(not main.battle_ended, "有免费次数时不应判负")

	# 付费自动清台
	_fill_stuck_tray()
	main.coin_count = 130
	main.free_clear_tokens = 0
	main._update_coin_ui()
	await process_frame
	main._check_stuck()
	await process_frame
	_check(main.tray_cards.is_empty(), "付费自动清台后合成台应为空")
	_check(main.coin_count == 30, "付费自动清台应扣 100，实际 %d" % main.coin_count)
	_check(not main.battle_ended, "金币足够时不应判负")

	# 金币与免费次数均不足 → 判负
	_fill_stuck_tray()
	main.coin_count = 50
	main.free_clear_tokens = 0
	main._update_coin_ui()
	await process_frame
	main._check_stuck()
	await process_frame
	_check(main.battle_ended, "金币不足且满台无合成应判负")

	if failures.is_empty():
		print("clear_tray_smoke: OK")
	else:
		print("clear_tray_smoke: %d FAILURES" % failures.size())
	quit(0 if failures.is_empty() else 1)
