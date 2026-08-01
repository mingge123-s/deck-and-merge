extends Node
## 启动引导：确保补丁包（由 Updater autoload 在更早的 _ready 中挂载）先于主场景加载。
## 主场景通过路径在挂载之后才被加载，因此补丁里的场景/脚本能真正覆盖内置版本。

const MAIN_SCENE := "res://scenes/main.tscn"

func _ready() -> void:
	call_deferred("_enter_main")

func _enter_main() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)
