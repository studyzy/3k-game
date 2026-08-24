extends Control
func _ready() -> void:
	DataManager.load_all_configs()
	GameInfo.playerCountryId = 1
	var scene: PackedScene = load("res://scenes/ui/global_map.tscn")
	var inst := scene.instantiate()
	add_child(inst)
	await get_tree().process_frame
	# 检查按钮位置
	for cid in [1, 2, 3, 4, 5, 6]:
		var city := CityListCache.get_city_by_city_id(cid)
		var btn: Button = inst._city_buttons.get(cid)
		if btn == null:
			print("[Map] %s 无按钮" % city.cityName)
			continue
		var pos := btn.position
		var in_bounds := pos.x >= 0 and pos.x <= 1920 and pos.y >= 0 and pos.y <= 1080
		print("[Map] %s 屏幕位置=(%.0f, %.0f) 在屏内=%s" % [city.cityName, pos.x, pos.y, "是" if in_bounds else "否"])
	get_tree().quit()
