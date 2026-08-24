extends Node
## 场景路由器（autoload: SceneRouter）


func change_scene(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)


func reload_current_scene() -> void:
	get_tree().reload_current_scene()
