extends Control

onready var lblCity = get_node("Window2/lblCity")
onready var lblEndless = get_node("Window2/lblEndless")
onready var atk = get_node("Window2/Atk")
onready var def = get_node("Window2/Def")

func update_data():
	var wf = DataManager.get_current_war_fight()
	var warCity = wf.target_city()
	lblCity.text = "{0}之战 - {2}月{1}日".format([
		warCity.get_name(), wf.date, DataManager.month, 
	])
	_update_data(wf.defenderWV, def, "守方")
	_update_data(wf.attackerWV, atk, "攻方")
	lblEndless.hide()
	if DataManager.endless_mode:
		var type = "【守城战】"
		if EndlessGame.war_vstate_no_player == 1:
			type = "【攻城战】"
		lblEndless.text = "【{0}】无尽第{1}关{2}".format([
			StaticManager.DIFFICULTY_NAMES[DataManager.diffculities], 
			EndlessGame.pass_no + 1, type
		]);
		lblEndless.show()
	return

func _update_data(wv: War_Vstate, ctrl: Control, side: String):
	ctrl.get_node("lord/lblName").text = "{0}：{1}".format([side, wv.get_lord_name()])
	ctrl.get_node("stats/valActors").text = str(wv.get_actors_count(true))
	var soldiers = wv.get_all_soldiers(true)
	var riceCostSetting = wv.daily_rice_cost()
	ctrl.get_node("stats/valSoldiers").text = str(soldiers)
	ctrl.get_node("stats/valGold").text = str(wv.money)
	if riceCostSetting[0] == riceCostSetting[1]:
		ctrl.get_node("stats/valRice").text = "{0}/{1}".format([
			abs(riceCostSetting[1]), wv.rice, 
		])
	else:
		ctrl.get_node("stats/valRice").text = "{0}(-{1})/{2}".format([
			abs(riceCostSetting[1]), 
			abs(riceCostSetting[0]) - abs(riceCostSetting[1]), wv.rice, 
		])
	return
