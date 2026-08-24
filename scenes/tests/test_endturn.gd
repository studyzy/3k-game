extends Control
## 结束回合场景切换测试

func _ready() -> void:
	DataManager.load_all_configs()
	GameInfo.playerCountryId = 1
	CountryListCache.turn_sort()
	print("[EndTurn] 结束前月份=%d 命令=%d" % [GameInfo.month, GameInfo.get_player_order_num()])
	TurnManager.end_player_turn()
	await get_tree().process_frame
	await get_tree().process_frame
	print("[EndTurn] 结束后月份=%d 命令=%d 当前场景=%s" % [
		GameInfo.month, GameInfo.get_player_order_num(), get_tree().current_scene.scene_file_path])
	if get_tree().current_scene.scene_file_path == "res://scenes/ui/city_scene.tscn":
		print("[EndTurn] 场景切换正确")
	else:
		print("[EndTurn] 场景切换异常！")
	get_tree().quit()
