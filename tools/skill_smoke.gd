extends SceneTree

## 临时冒烟测试：沙盒里让工业/现代/未来 15 个英雄双方对轰，
## 每帧把能量灌满以强制触发全部技能，检查是否有运行时报错。
## 用法：godot --headless --path . --script tools/skill_smoke.gd

const HERO_IDS := [
	"ind_tank", "ind_warrior", "ind_assassin", "ind_ranged", "ind_boss",
	"mod_tank", "mod_warrior", "mod_assassin", "mod_ranged", "mod_boss",
	"fut_tank", "fut_warrior", "fut_assassin", "fut_ranged", "fut_boss",
]

var main: Node
var frames := 0
var casts: Dictionary = {}

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	main = scene.instantiate()
	root.add_child(main)
	await process_frame
	for hero_id in HERO_IDS:
		main.sandbox_ally_counts[hero_id] = 2
		main.sandbox_enemy_counts[hero_id] = 2
	main._start_sandbox_battle()

func _process(_delta: float) -> bool:
	frames += 1
	if main != null and main.battle_units != null:
		for unit in main.battle_units:
			if is_instance_valid(unit) and unit.alive and unit.skill_cost > 0:
				if unit.energy < float(unit.skill_cost):
					unit.energy = float(unit.skill_cost)
					var skill_type: String = str(unit.stats.get("skill", {}).get("type", ""))
					casts[skill_type] = int(casts.get(skill_type, 0)) + 1
	if frames >= 1800:
		print("frames=%d casts=%s" % [frames, str(casts)])
		var missing: Array[String] = []
		for hero_id in HERO_IDS:
			var skill_type := str(GameData.HEROES[hero_id].get("skill", {}).get("type", ""))
			if int(casts.get(skill_type, 0)) <= 0:
				missing.append(skill_type)
		print("never_cast=%s" % str(missing))
		return true
	return false
