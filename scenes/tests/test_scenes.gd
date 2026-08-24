extends Control
## UI 场景构建测试

func _ready() -> void:
	DataManager.load_all_configs()
	GameInfo.playerCountryId = 1
	GameInfo.doCityId = CountryListCache.get_country_by_country_id(1).cityIDs[0]
	CountryListCache.turn_sort()

	var scenes := [
		"res://scenes/ui/select_king.tscn",
		"res://scenes/ui/global_map.tscn",
		"res://scenes/ui/city_scene.tscn",
		"res://scenes/ui/select_general.tscn",
		"res://scenes/ui/executive_panel.tscn",
		"res://scenes/ui/war_scene.tscn",
		"res://scenes/ui/self_build.tscn",
		"res://scenes/ui/ui_end.tscn",
	]
	for path in scenes:
		var scene: PackedScene = load(path)
		if scene == null:
			print("[SceneTest] 加载失败: %s" % path)
			continue
		var inst := scene.instantiate()
		add_child(inst)
		await get_tree().process_frame
		print("[SceneTest] 构建成功: %s" % path)
		inst.queue_free()
		await get_tree().process_frame
	print("[SceneTest] 全部场景构建测试完成")
	get_tree().quit()
