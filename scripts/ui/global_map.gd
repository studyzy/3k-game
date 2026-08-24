extends Control
## 大地图（对应 Unity UIGlobe）

var _city_buttons: Dictionary = {}
var _selected_city_id: int = 0
var _info_panel: Panel
var _map_scale := 0.84375   # 960x1280 -> 810x1080 (等比缩放到高度 1080)
var _map_offset := Vector2(555, 0)


func _ready() -> void:
	DataManager.ensure_loaded()
	# 地图背景：原版 960x1280 原生尺寸居中显示
	var map_rect := TextureRect.new()
	map_rect.texture = load("res://assets/ui/global_map.png")
	map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.size = Vector2(960, 1280)
	map_rect.position = Vector2(480, -100)  # (1920-960)/2, (1080-1280)/2
	add_child(map_rect)

	# 标题
	var title := UIFactory.make_label("%d年%d月" % [GameInfo.years, GameInfo.month], 30, Color.WHITE)
	title.position = Vector2(20, 10)
	add_child(title)

	# 任务提示
	if GameInfo.task != GameInfo.TaskType.NONE:
		var tip := UIFactory.make_label(_task_text(GameInfo.task), 22, Color.YELLOW)
		tip.position = Vector2(200, 15)
		add_child(tip)

	# 操作面板（底部）
	_build_action_bar()
	_spawn_city_buttons()


func _task_text(task: int) -> String:
	var names := {
		GameInfo.TaskType.MOVE: "选择要移动的武将",
		GameInfo.TaskType.ATTACK: "选择要进攻的城池",
		GameInfo.TaskType.TRANSPORT: "选择输送目标",
		GameInfo.TaskType.ALIENATE: "选择离间对象城池",
		GameInfo.TaskType.BRIBE: "选择招揽对象城池",
	}
	return names.get(task, "")


func _spawn_city_buttons() -> void:
	for child in get_children():
		if child is Button and child.name.begins_with("City"):
			child.queue_free()
	_city_buttons.clear()
	for cid in CityListCache.city_dictionary.keys():
		var city: City = CityListCache.city_dictionary[cid]
		var pos: Array = city.mapPosition
		if pos.size() < 2:
			continue
		var b := Button.new()
		b.name = "City%d" % cid
		b.text = city.cityName
		b.custom_minimum_size = Vector2(120, 36)
		b.add_theme_font_size_override("font_size", 16)
		# mapPosition 是中心原点坐标系（Y 向上），换算到 1920x1080 屏幕
		b.position = Vector2(960 + int(pos[0]), 540 - int(pos[1]))
		var country := CountryListCache.get_country_by_king_id(city.ownerID)
		if country != null:
			b.modulate = Color(country.countryColor)
		b.pressed.connect(_on_city_pressed.bind(cid))
		add_child(b)
		_city_buttons[cid] = b


func _build_action_bar() -> void:
	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.position = Vector2(-400, -80)
	bar.size = Vector2(800, 70)
	add_child(bar)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(hbox)
	var actions := {
		"移动": GameInfo.TaskType.MOVE,
		"攻城": GameInfo.TaskType.ATTACK,
		"输送": GameInfo.TaskType.TRANSPORT,
		"离间": GameInfo.TaskType.ALIENATE,
		"招揽": GameInfo.TaskType.BRIBE,
		"结束": -1,
	}
	for name in actions.keys():
		var b := UIFactory.make_button(name, Vector2(110, 50), 22)
		var task: int = actions[name]
		b.pressed.connect(_on_action.bind(task))
		hbox.add_child(b)


func _on_action(task: int) -> void:
	if task == -1:
		# 结束回合
		TurnManager.end_player_turn()
		return
	GameInfo.task = task


func _on_city_pressed(city_id: int) -> void:
	_selected_city_id = city_id
	var city: City = CityListCache.get_city_by_city_id(city_id)
	var task: int = GameInfo.task

	if task == GameInfo.TaskType.MOVE or task == GameInfo.TaskType.ATTACK:
		GameInfo.targetCityId = city_id
		# 从玩家自己的出发城池选武将
		var from_city := CityListCache.get_city_by_city_id(GameInfo.doCityId)
		if from_city != null:
			GameInfo.set_general_option(from_city.get_officer_ids())
		SceneRouter.change_scene("res://scenes/ui/select_general.tscn")
		return
	elif task == GameInfo.TaskType.TRANSPORT:
		GameInfo.targetCityId = city_id
		SceneRouter.change_scene("res://scenes/ui/executive_panel.tscn")
		return

	# 默认：只能进入自己城池
	var player_country := CountryListCache.get_country_by_country_id(GameInfo.playerCountryId)
	if city.ownerID != player_country.countryKingId:
		_show_tip("这是 %s 的城池，不能直接进入" % (CountryListCache.get_country_by_king_id(city.ownerID).king_name() if CountryListCache.get_country_by_king_id(city.ownerID) != null else "敌对势力"))
		return
	GameInfo.doCityId = city_id
	SceneRouter.change_scene("res://scenes/ui/city_scene.tscn")


func _show_tip(text: String) -> void:
	var tip := UIFactory.make_label(text, 22, Color.YELLOW)
	tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tip.position = Vector2(-400, -140)
	tip.size = Vector2(800, 40)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tip)
	get_tree().create_timer(2.0).timeout.connect(tip.queue_free)
