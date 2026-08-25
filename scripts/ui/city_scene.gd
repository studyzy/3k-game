extends Control
## 城市内政（对应 Unity UICityScene）

var _city_id: int = 0
var _info_label: Label
var _interior_panel: Panel
var _save_panel: Panel


func _ready() -> void:
	DataManager.ensure_loaded()
	_city_id = GameInfo.doCityId
	if _city_id == 0:
		_city_id = 1
	_build_ui()
	_show_info_tip()
	_refresh()


func _build_ui() -> void:
	# 全屏背景（sanguo 迁移资源 bg3.jpg）
	add_child(UIFactory.make_bg("res://assets/bg/bg3.jpg"))

	_info_label = UIFactory.make_label("", 22, Color.WHITE)
	_info_label.position = Vector2(40, 60)
	_info_label.size = Vector2(420, 360)
	add_child(_info_label)

	# 右侧任务按钮
	var box := VBoxContainer.new()
	box.position = Vector2(520, 40)
	box.size = Vector2(300, 620)
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var tasks := {
		"征 兵": GameInfo.TaskType.CONSCRIPT,
		"移 动": GameInfo.TaskType.MOVE,
		"攻 城": GameInfo.TaskType.ATTACK,
		"输 送": GameInfo.TaskType.TRANSPORT,
		"搜 索": GameInfo.TaskType.SEARCH,
		"登 用": GameInfo.TaskType.EMPLOY,
		"奖 赏": GameInfo.TaskType.REWARD,
		"任 命": GameInfo.TaskType.APPOINT,
		"内 政": 100,
		"同 盟": GameInfo.TaskType.TRUCE,
		"离 间": GameInfo.TaskType.ALIENATE,
		"招 揽": GameInfo.TaskType.BRIBE,
		"情 报": GameInfo.TaskType.INTELLIGENCE,
		"金 粮": GameInfo.TaskType.SHOP,
		"武 器": GameInfo.TaskType.SMITHY,
		"学 院": GameInfo.TaskType.SCHOOL,
		"医 馆": GameInfo.TaskType.HOSPITAL,
		"存取档": 101,
		"结束回合": -1,
	}
	for name in tasks.keys():
		var b := UIFactory.make_button(name, Vector2(300, 46), 22)
		var task: int = tasks[name]
		b.pressed.connect(_on_task.bind(task))
		box.add_child(b)

	# 返回大地图
	var back := UIFactory.make_button("返回大地图", Vector2(180, 46), 22)
	back.position = Vector2(40, 700)
	back.pressed.connect(func(): GameInfo.task = GameInfo.TaskType.NONE; SceneRouter.change_scene("res://scenes/ui/global_map.tscn"))
	add_child(back)


func _refresh() -> void:
	var city: City = CityListCache.get_city_by_city_id(_city_id)
	if city == null:
		return
	var king := CountryListCache.get_country_by_king_id(city.ownerID)
	var officer_ids := city.get_officer_ids()
	var general_names := ""
	for i in mini(officer_ids.size(), 6):
		var g := GeneralListCache.get_general(officer_ids[i])
		general_names += ("%s   " % g.generalName) if g != null else ""
	var info := "【%s】\n\n所属势力：%s\n太守：%s\n\n金钱：%d    粮食：%d\n农业：%d    商业：%d\n人口：%d    统治：%d\n防灾：%d    宝物：%d\n预备兵：%d\n\n在职武将：\n%s" % [
		city.cityName,
		king.king_name() if king != null else "无",
		(GeneralListCache.get_general(city.prefectID).generalName if GeneralListCache.get_general(city.prefectID) != null else "无"),
		city.get_money(), city.get_food(), city.agriculture, city.commerce,
		city.population, city.rule, city.prevention, city.treasures, city.reserveSoldiers,
		general_names]
	_info_label.text = info


func _on_task(task: int) -> void:
	if task == -1:
		# 结束回合：通知服务器（AI 回合 + 月度推进）
		NetClient.send(NetClient.C2S_END_TURN, {})
		return
	if task == 100:
		_show_interior()
		return
	if task == 101:
		_show_save_load()
		return
	GameInfo.task = task
	GameInfo.doCityId = _city_id
	# 多数任务需要选择武将
	if task in [GameInfo.TaskType.SEARCH, GameInfo.TaskType.EMPLOY, GameInfo.TaskType.REWARD,
			GameInfo.TaskType.APPOINT, GameInfo.TaskType.TRUCE, GameInfo.TaskType.ALIENATE,
			GameInfo.TaskType.BRIBE, GameInfo.TaskType.SHOP, GameInfo.TaskType.SMITHY,
			GameInfo.TaskType.SCHOOL, GameInfo.TaskType.HOSPITAL]:
		var city: City = CityListCache.get_city_by_city_id(_city_id)
		GameInfo.set_general_option(city.get_officer_ids())
		SceneRouter.change_scene("res://scenes/ui/select_general.tscn")
		return
	if task == GameInfo.TaskType.CONSCRIPT:
		GameInfo.set_general_option([])
		SceneRouter.change_scene("res://scenes/ui/executive_panel.tscn")
		return
	if task == GameInfo.TaskType.MOVE or task == GameInfo.TaskType.ATTACK:
		GameInfo.task = GameInfo.TaskType.NONE
		GameInfo.task = task
		SceneRouter.change_scene("res://scenes/ui/global_map.tscn")
		return
	# 其它
	SceneRouter.change_scene("res://scenes/ui/executive_panel.tscn")


func _show_interior() -> void:
	if _interior_panel != null:
		_interior_panel.queue_free()
	_interior_panel = Panel.new()
	_interior_panel.set_anchors_preset(Control.PRESET_CENTER)
	_interior_panel.position = Vector2(-200, -160)
	_interior_panel.size = Vector2(400, 320)
	add_child(_interior_panel)
	UIFactory.add_label(_interior_panel, "选择内政", Vector2(110, 15), 28)
	var box := VBoxContainer.new()
	box.position = Vector2(50, 60)
	box.size = Vector2(300, 220)
	box.add_theme_constant_override("separation", 10)
	_interior_panel.add_child(box)
	var interior := {
		"开垦": GameInfo.TaskType.RECLAIM,
		"劝商": GameInfo.TaskType.MERCANTILE,
		"治水": GameInfo.TaskType.TAME,
		"巡查": GameInfo.TaskType.PATROL,
	}
	for name in interior.keys():
		var b := UIFactory.make_button(name, Vector2(300, 44), 22)
		var t: int = interior[name]
		b.pressed.connect(func():
			_interior_panel.queue_free()
			GameInfo.task = t
			var city: City = CityListCache.get_city_by_city_id(_city_id)
			GameInfo.set_general_option(city.get_officer_ids())
			SceneRouter.change_scene("res://scenes/ui/select_general.tscn"))
		box.add_child(b)


func _show_save_load() -> void:
	if _save_panel != null:
		_save_panel.queue_free()
	_save_panel = Panel.new()
	_save_panel.set_anchors_preset(Control.PRESET_CENTER)
	_save_panel.position = Vector2(-220, -180)
	_save_panel.size = Vector2(440, 360)
	add_child(_save_panel)
	UIFactory.add_label(_save_panel, "存取档", Vector2(160, 15), 28)
	var box := VBoxContainer.new()
	box.position = Vector2(40, 60)
	box.size = Vector2(360, 260)
	box.add_theme_constant_override("separation", 8)
	_save_panel.add_child(box)
	for i in 4:
		var hbox := HBoxContainer.new()
		box.add_child(hbox)
		var info: String = GameInfo.recordInfo[i]
		var save_b := UIFactory.make_button("保存 %d" % (i + 1), Vector2(150, 42), 20)
		var load_b := UIFactory.make_button("读取 %d" % (i + 1), Vector2(150, 42), 20)
		var idx := i
		save_b.pressed.connect(func(): NetClient.save_game("slot%d" % (idx + 1)))
		load_b.pressed.connect(func():
			NetClient.load_game("slot%d" % (idx + 1))
			_save_panel.queue_free())
		hbox.add_child(save_b)
		hbox.add_child(load_b)
	var close := UIFactory.make_button("关闭", Vector2(120, 42), 20)
	close.pressed.connect(func(): _save_panel.queue_free())
	_save_panel.add_child(close)
	close.position = Vector2(160, 310)


func _show_info_tip() -> void:
	if GameInfo.show_info.is_empty():
		return
	var tip := UIFactory.make_label(GameInfo.show_info, 24, Color.YELLOW)
	tip.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tip.position = Vector2(-400, 90)
	tip.size = Vector2(800, 40)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tip)
	get_tree().create_timer(3.0).timeout.connect(tip.queue_free)
	GameInfo.show_info = ""
