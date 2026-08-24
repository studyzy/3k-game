extends Control
## 任务执行面板（对应 Unity UIExecutivePanel）

var _result_label: Label
var _input_panel: Panel
var _current_input_callback: Callable


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UIFactory.make_label("执行指令", 36, Color(0.95, 0.85, 0.4))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-100, 20)
	title.size = Vector2(200, 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_result_label = UIFactory.make_label("", 22, Color.WHITE)
	_result_label.position = Vector2(100, 100)
	_result_label.size = Vector2(700, 300)
	_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_result_label)

	var next := UIFactory.make_button("继 续", Vector2(180, 56), 24)
	next.position = Vector2(360, 640)
	next.pressed.connect(_on_next)
	add_child(next)

	_execute()


func _task_name() -> String:
	var names := {
		GameInfo.TaskType.SEARCH: "搜索", GameInfo.TaskType.EMPLOY: "登用",
		GameInfo.TaskType.REWARD: "奖赏", GameInfo.TaskType.APPOINT: "任命",
		GameInfo.TaskType.RECLAIM: "开垦", GameInfo.TaskType.MERCANTILE: "劝商",
		GameInfo.TaskType.TAME: "治水", GameInfo.TaskType.PATROL: "巡查",
		GameInfo.TaskType.CONSCRIPT: "征兵", GameInfo.TaskType.SHOP: "金粮",
		GameInfo.TaskType.SMITHY: "武器", GameInfo.TaskType.SCHOOL: "学院",
		GameInfo.TaskType.HOSPITAL: "医馆", GameInfo.TaskType.MOVE: "移动",
		GameInfo.TaskType.ATTACK: "攻城", GameInfo.TaskType.TRANSPORT: "输送",
		GameInfo.TaskType.TRUCE: "同盟", GameInfo.TaskType.ALIENATE: "离间",
		GameInfo.TaskType.BRIBE: "招揽",
	}
	return names.get(GameInfo.task, "任务")


func _execute() -> void:
	var city := CityListCache.get_city_by_city_id(GameInfo.doCityId)
	var results: Array[String] = []
	match GameInfo.task:
		GameInfo.TaskType.SEARCH:
			for gid in GameInfo.doGeneralIds:
				var g := GeneralListCache.get_general(gid)
				var r := city.search(gid)
				results.append("%s：%s" % [g.generalName, r])
		GameInfo.TaskType.REWARD:
			for gid in GameInfo.doGeneralIds:
				var g := GeneralListCache.get_general(gid)
				var delta := g.reward_add_loyalty(true)
				city.sub_gold(100)
				results.append("%s 忠诚 +%d" % [g.generalName, delta])
		GameInfo.TaskType.APPOINT:
			var gid: int = GameInfo.doGeneralIds[0] if not GameInfo.doGeneralIds.is_empty() else 0
			if gid != 0:
				city.appoint_prefect(gid)
				results.append("任命 %s 为太守" % GeneralListCache.get_general(gid).generalName)
		GameInfo.TaskType.RECLAIM:
			var gid: int = GameInfo.doGeneralIds[0] if not GameInfo.doGeneralIds.is_empty() else 0
			if gid != 0:
				var g := GeneralListCache.get_general(gid)
				var money := g.get_need_money_of_interior(GameInfo.TaskType.RECLAIM)
				if city.money >= money:
					var val := city.reclaim(g, money)
					results.append("%s 开垦，农业 +%d" % [g.generalName, val])
				else:
					results.append("金钱不足")
		GameInfo.TaskType.MERCANTILE:
			var gid: int = GameInfo.doGeneralIds[0] if not GameInfo.doGeneralIds.is_empty() else 0
			if gid != 0:
				var g := GeneralListCache.get_general(gid)
				var money := g.get_need_money_of_interior(GameInfo.TaskType.MERCANTILE)
				if city.money >= money:
					var val := city.mercantile(g, money)
					results.append("%s 劝商，商业 +%d" % [g.generalName, val])
				else:
					results.append("金钱不足")
		GameInfo.TaskType.TAME:
			var gid: int = GameInfo.doGeneralIds[0] if not GameInfo.doGeneralIds.is_empty() else 0
			if gid != 0:
				var g := GeneralListCache.get_general(gid)
				var money := g.get_need_money_of_interior(GameInfo.TaskType.TAME)
				if city.money >= money:
					var val := city.tame(g, money)
					results.append("%s 治水，防洪 +%d" % [g.generalName, val])
				else:
					results.append("金钱不足")
		GameInfo.TaskType.PATROL:
			var gid: int = GameInfo.doGeneralIds[0] if not GameInfo.doGeneralIds.is_empty() else 0
			if gid != 0:
				var g := GeneralListCache.get_general(gid)
				var money := g.get_need_money_of_interior(GameInfo.TaskType.PATROL)
				if city.money >= money:
					var val := city.patrol(g, money)
					results.append("%s 巡查，人口 +%d" % [g.generalName, val])
				else:
					results.append("金钱不足")
		GameInfo.TaskType.SCHOOL:
			var gid: int = GameInfo.doGeneralIds[0] if not GameInfo.doGeneralIds.is_empty() else 0
			if gid != 0:
				var g := GeneralListCache.get_general(gid)
				if g.wisdom < 120 and g.experience >= g.get_school_need_exp():
					g.study_up()
					results.append("%s 智力+1" % g.generalName)
				else:
					results.append("经验不足，无法学习")
		GameInfo.TaskType.HOSPITAL:
			var healed := false
			for gid in GameInfo.doGeneralIds:
				var g := GeneralListCache.get_general(gid)
				if g.health < g.maxHealth and city.money >= 100:
					city.sub_gold(100)
					g.add_hp(randi_range(20, 34))
					results.append("%s 体力恢复" % g.generalName)
					healed = true
			if not healed:
				results.append("无需治疗或金钱不足")
		GameInfo.TaskType.EMPLOY:
			_show_employ()
			return
		GameInfo.TaskType.CONSCRIPT:
			_show_conscript()
			return
		GameInfo.TaskType.SHOP:
			_show_shop()
			return
		GameInfo.TaskType.SMITHY:
			_show_smithy()
			return
		GameInfo.TaskType.MOVE:
			var target := CityListCache.get_city_by_city_id(GameInfo.targetCityId)
			var is_king := CityListCache.move_task(GameInfo.doCityId, GameInfo.targetCityId, GameInfo.doGeneralIds)
			results.append("移动完成" + ("（君主移动）" if is_king else ""))
		GameInfo.TaskType.TRANSPORT:
			results.append("输送：请选择输送内容")
			_show_transport()
			return
		GameInfo.TaskType.ATTACK:
			results.append("攻城：请选择出兵武将")
			_show_attack()
			return
		GameInfo.TaskType.ALIENATE:
			for gid in GameInfo.doGeneralIds:
				var success := GeneralListCache.is_alienate(gid, GameInfo.targetGeneralIds[0] if not GameInfo.targetGeneralIds.is_empty() else 0)
				results.append("离间%s" % ("成功" if success else "失败"))
		GameInfo.TaskType.BRIBE:
			var success := GeneralListCache.is_bribe(GameInfo.doCityId, GameInfo.targetCityId,
				GameInfo.doGeneralIds[0] if not GameInfo.doGeneralIds.is_empty() else 0,
				GameInfo.targetGeneralIds[0] if not GameInfo.targetGeneralIds.is_empty() else 0)
			results.append("招揽%s" % ("成功" if success else "失败"))
		_:
			results.append("%s 执行完成" % _task_name())
	_result_label.text = "\n".join(results)


func _show_employ() -> void:
	var city := CityListCache.get_city_by_city_id(GameInfo.doCityId)
	var talents := city.get_talent_ids()
	if talents.is_empty():
		_result_label.text = "城中无在野武将可登用"
		return
	var chosen: int = talents[0]
	var do_gid: int = GameInfo.doGeneralIds[0] if not GameInfo.doGeneralIds.is_empty() else 0
	if city.is_employ(do_gid, chosen):
		_result_label.text = "成功登用 %s" % GeneralListCache.get_general(chosen).generalName
	else:
		_result_label.text = "登用失败"
	GameInfo.doGeneralIds = [chosen]


func _show_conscript() -> void:
	_show_input("输入征兵数量", "1000", func(text: String):
		var city := CityListCache.get_city_by_city_id(GameInfo.doCityId)
		var n := clampi(int(text), 0, city.get_max_conscript_soldier_num())
		city.conscript(n)
		_result_label.text = "征兵 %d，预备兵 %d" % [n, city.reserveSoldiers])


func _show_shop() -> void:
	_show_input("输入购买粮食数量（4粮=3金）", "100", func(text: String):
		var city := CityListCache.get_city_by_city_id(GameInfo.doCityId)
		var n := clampi(int(text), 0, 30000)
		var gold_needed := n * 3 / 4
		if city.money >= gold_needed:
			city.sub_gold(gold_needed)
			city.add_food(n)
			_result_label.text = "购粮 %d，花费 %d 金" % [n, gold_needed]
		else:
			_result_label.text = "金钱不足")


func _show_smithy() -> void:
	var city := CityListCache.get_city_by_city_id(GameInfo.doCityId)
	var weapons := WeaponListCache.get_weapons_by_smithy(city.cityWeaponShop)
	if weapons.is_empty():
		_result_label.text = "城中无武器店"
		return
	var weapon: Weapon = weapons[0]
	var gid: int = GameInfo.doGeneralIds[0] if not GameInfo.doGeneralIds.is_empty() else 0
	var g := GeneralListCache.get_general(gid)
	if city.money >= weapon.price:
		if g.buy_new_weapon(weapon.weaponID, GameInfo.doCityId):
			city.sub_gold(weapon.price)
			_result_label.text = "%s 购得 %s" % [g.generalName, weapon.weaponName]
		else:
			_result_label.text = "无法使用该武器"
	else:
		_result_label.text = "金钱不足"


func _show_transport() -> void:
	var city := CityListCache.get_city_by_city_id(GameInfo.doCityId)
	var target := CityListCache.get_city_by_city_id(GameInfo.targetCityId)
	_show_input("输入输送粮食数量（目标 %s）" % target.cityName, "100", func(text: String):
		var n := clampi(int(text), 0, city.get_food())
		CityListCache.transport_between_citys(GameInfo.doCityId, GameInfo.targetCityId, n, 0, 0)
		_result_label.text = "向 %s 输送粮食 %d" % [target.cityName, n])


func _show_attack() -> void:
	var atk_ids: Array = GameInfo.doGeneralIds
	if atk_ids.is_empty():
		_result_label.text = "未选择出兵武将"
		return
	var departure := GameInfo.doCityId
	var target := GameInfo.targetCityId
	if target == 0:
		_result_label.text = "未选择目标城池"
		return
	WarManager.war_prepare(false, target, departure, atk_ids, 500, 300)
	SceneRouter.change_scene("res://scenes/ui/war_scene.tscn")


func _show_input(title_text: String, default_text: String, callback: Callable) -> void:
	if _input_panel != null:
		_input_panel.queue_free()
	_input_panel = Panel.new()
	_input_panel.set_anchors_preset(Control.PRESET_CENTER)
	_input_panel.position = Vector2(-200, -100)
	_input_panel.size = Vector2(400, 200)
	add_child(_input_panel)
	UIFactory.add_label(_input_panel, title_text, Vector2(30, 20), 24)
	var line_edit := LineEdit.new()
	line_edit.text = default_text
	line_edit.position = Vector2(30, 70)
	line_edit.size = Vector2(340, 40)
	_input_panel.add_child(line_edit)
	var ok := UIFactory.make_button("确 定", Vector2(120, 44), 22)
	ok.pressed.connect(func():
		callback.call(line_edit.text)
		_input_panel.queue_free())
	_input_panel.add_child(ok)
	ok.position = Vector2(140, 130)
	_current_input_callback = callback


func _on_next() -> void:
	# 扣命令并返回
	GameInfo.sub_player_order()
	GameInfo.task = GameInfo.TaskType.NONE
	SceneRouter.change_scene("res://scenes/ui/city_scene.tscn")
