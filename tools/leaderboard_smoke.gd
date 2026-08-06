extends SceneTree

## 本机 Top10 排行榜冒烟：入榜排序 / 容量截断 / best_score 派生 / 主菜单面板
## 用法：godot --headless --path . --script tools/leaderboard_smoke.gd

var main: Node
var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		print("FAIL: ", label)

func _initialize() -> void:
	# 隔离存档，避免污染本机真实 save.cfg
	var cfg := ConfigFile.new()
	cfg.set_value("save", "coins", 300)
	cfg.set_value("save", "best_score", 500)
	cfg.set_value("save", "leaderboard", [])
	cfg.save("user://save.cfg")
	SaveManager.call("load")
	_check(SaveManager.get_best_score() == 500, "legacy best_score 应保留: %d" % SaveManager.get_best_score())
	var seeded: Array = SaveManager.get_leaderboard()
	_check(seeded.size() == 1, "legacy best_score 应派生 1 条: %d" % seeded.size())
	if not seeded.is_empty():
		_check(int(seeded[0].get("score", 0)) == 500, "派生分数应为 500")

	# 清空后重新测纯入榜
	cfg = ConfigFile.new()
	cfg.set_value("save", "coins", 300)
	cfg.set_value("save", "best_score", 0)
	cfg.set_value("save", "leaderboard", [])
	cfg.save("user://save.cfg")
	SaveManager.call("load")

	var rank1 := SaveManager.try_submit_score(1200, "hard", 3)
	_check(rank1 == 1, "首条应第 1 名，实际 %d" % rank1)
	_check(SaveManager.get_best_score() == 1200, "best_score 应由榜首派生: %d" % SaveManager.get_best_score())

	var rank2 := SaveManager.try_submit_score(800, "normal", 2)
	_check(rank2 == 2, "较低分应第 2，实际 %d" % rank2)
	var rank_top := SaveManager.try_submit_score(1500, "easy", 1)
	_check(rank_top == 1, "更高分应顶到第 1，实际 %d" % rank_top)

	for i in range(12):
		SaveManager.try_submit_score(100 + i * 10, "normal", 1)
	var board: Array = SaveManager.get_leaderboard()
	_check(board.size() == 10, "最多 10 条，实际 %d" % board.size())
	for i in range(board.size() - 1):
		var a := int(board[i].get("score", 0))
		var b := int(board[i + 1].get("score", 0))
		_check(a >= b, "应降序: [%d]=%d < [%d]=%d" % [i, a, i + 1, b])
	_check(int(board[0].get("score", 0)) == 1500, "榜首应为 1500，实际 %d" % int(board[0].get("score", 0)))
	_check(SaveManager.get_best_score() == 1500, "best_score 同步榜首")

	var miss := SaveManager.try_submit_score(0, "normal", 1)
	_check(miss == 0, "0 分不应入榜")
	miss = SaveManager.try_submit_score(50, "normal", 1)
	_check(miss == 0, "低于第 10 名不应入榜，实际 %d" % miss)

	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	_check(main.leaderboard_panel != null, "应构建排行榜面板")
	_check(main.has_method("_show_leaderboard"), "应有打开排行榜入口")
	main._show_leaderboard()
	await process_frame
	_check(main.leaderboard_panel.visible, "打开后面板应可见")
	_check(main.leaderboard_rows != null and main.leaderboard_rows.get_child_count() > 0, "应渲染榜行")
	main._hide_leaderboard()
	await process_frame
	_check(not main.leaderboard_panel.visible, "关闭后面板应隐藏")

	# 结算路径：写入 kill_score 后走 _finish_round
	main.kill_score = 9999
	main.current_difficulty = "hard"
	main.enemy_era_index = 2
	main._finish_round("测试结算")
	await process_frame
	_check(SaveManager.get_best_score() == 9999, "结算后 best_score 更新: %d" % SaveManager.get_best_score())
	_check(int(SaveManager.get_leaderboard()[0].get("score", 0)) == 9999, "结算入榜榜首")
	_check(str(main.status_label.text).contains("本机榜第"), "结算文案应提示名次: %s" % main.status_label.text)

	if failures.is_empty():
		print("leaderboard_smoke: OK")
	else:
		print("leaderboard_smoke: %d FAILURES" % failures.size())
		for f in failures:
			print(" - ", f)
	quit(0 if failures.is_empty() else 1)
