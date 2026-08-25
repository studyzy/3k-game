# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/menu/pnlOthers.gd
# 说明：其他设置面板 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Panel

onready var gv = get_node("gv")

var buttons = []
var cursorIndex = 0

func _ready() -> void :
	buttons = []
	for child in gv.get_children():
		if not child is Button:
			continue
		buttons.append(child)
	return

func init():
	
	cursorIndex = 1
	update_cursor()
	return

func move_up():
	var y = cursorIndex / gv.columns
	var x = cursorIndex % gv.columns
	var rows = buttons.size() / gv.columns
	y = (y + rows - 1) % rows
	cursorIndex = y * gv.columns + x
	if cursorIndex == 0:
		
		cursorIndex = (rows - 1) * gv.columns
	return

func move_down():
	var y = cursorIndex / gv.columns
	var x = cursorIndex % gv.columns
	var rows = buttons.size() / gv.columns
	y = (y + 1) % rows
	cursorIndex = y * gv.columns + x
	if cursorIndex == 0:
		
		cursorIndex = gv.columns
	return

func move_left():
	var y = cursorIndex / gv.columns
	var x = cursorIndex % gv.columns
	var cols = gv.columns
	x = (x + cols - 1) % cols
	cursorIndex = y * gv.columns + x
	if cursorIndex == 0:
		
		cursorIndex = gv.columns - 1
	return

func move_right():
	var y = cursorIndex / gv.columns
	var x = cursorIndex % gv.columns
	var cols = gv.columns
	x = (x + 1) % cols
	cursorIndex = y * gv.columns + x
	if cursorIndex == 0:
		
		cursorIndex = 1
	return

func _process(delta: float) -> void :
	if not visible:
		return
	if SceneManager.process_popuped():
		return
	if Input.is_action_just_pressed("ANALOG_UP"):
		move_up()
		update_cursor()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		move_down()
		update_cursor()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		move_left()
		update_cursor()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		move_right()
		update_cursor()
	if Input.is_action_just_pressed("EMU_A"):
		Input.action_release("EMU_A")
		var btn: Button = buttons[cursorIndex]
		btn.emit_signal("pressed")
	if Input.is_action_just_pressed("EMU_B"):
		_on_btnBack_pressed()
	return

func update_cursor():
	for i in buttons.size():
		var btn: Button = buttons[i]
		if i == cursorIndex:
			btn.self_modulate = Color("#00FF22")
		else:
			btn.self_modulate = Color("#FFFFFF")
	return


func _on_btnBack_pressed() -> void :
	hide()
	return

func _on_btnFlowFix_pressed() -> void :
	SceneManager.confirm("""
		　　如果当前场景已经卡死，尝试恢复
		　　如果修复成功，游戏可以继续
		　　但可能损失一些技能和指令效果
		　　（死马当活马医…… 没卡死别试！）
		　　请对可能的意外做好心理预期
		
		　　修复后，自动存档于 kale.sav
		　　如有兴趣帮助我们定位问题
		　　您可以群上传此存档确认卡死问题
		""", self, "flowFix_confirmed", 
		Vector2(500, 250), "试试！", "算了……")
	return

func _on_btnData_pressed():
	hide()
	get_parent()._on_btnBackToGame_pressed()
	SceneManager.info_start()
	return

func _on_btnCheater_pressed():
	var info = DataManager.cheater_disabled()
	if info != "":
		SceneManager.notice(info)
		return
	hide()
	get_parent()._on_btnBackToGame_pressed()
	SceneManager.cheater_start()
	return

func _on_btnChallange_pressed() -> void :
	if DataManager.is_challange_game():
		var dic = DataManager.get_env_dict("挑战赛")
		var current = int(Time.get_unix_time_from_system())
		var time = max(0, 5400 - int(current - dic["start"]))
		
		if time == 0 and DataManager.get_current_scene_id() >= 20000:
			SceneManager.confirm("""
			　　挑战赛模式正在进行中
			　　且倒计时已结束
			　　是否快速结束当前战争？
			""", self, "war_quick_end")
			return
		SceneManager.notice("""
			　　挑战赛模式正在进行中
			　　如果要重新开启
			　　请先结束游戏
			　　回到初始画面
			""")
		return
	SceneManager.confirm("""
		　　注意！
		　　即将结束当前游戏！
		　　开启新的骉哥挑战赛

		　　请确保你知道你在干什么
		　　如有问题请咨询骉哥
		""", self, "challange_confirmed", 
		Vector2(500, 280))
	return


func challange_confirmed() -> void :
	hide()
	get_parent()._on_btnBackToGame_pressed()
	FlowManager.clear()
	LoadControl.end_script()
	SceneManager.restart_challange_game()
	return



func war_quick_end() -> void :
	if DataManager.get_current_scene_id() < 20000:
		return
	var wf = DataManager.get_current_war_fight()
	wf.date = 30
	SceneManager.notice("当前战争日期已经被设定为 30 日")
	return


func flowFix_confirmed():
	if DataManager.get_current_scene_id() != - 1:
		DataManager.auto_save("kale")
	hide()
	get_parent()._on_btnBackToGame_pressed()
	
	DataManager.fix_data(true)
	match SceneManager.current_scene_path:
		"res://scene/scene_affiars/scene_affiars.tscn":
			FlowManager.clear()
			LoadControl.end_script()
			if DataManager.is_autoplay_mode():
				FlowManager.add_flow("load_script|affiars/auto_events/affiars_auto_run.gd")
				FlowManager.add_flow("turn_control_start")
			else:
				FlowManager.add_flow("load_script|affiars/player_control.gd")
				
				FlowManager.add_flow("player_start")
		"res://scene/scene_war/scene_war.tscn":
			FlowManager.clear()
			LoadControl.end_script()
			FlowManager.force_change_controlNo(0)
			DataManager.war_control_sort = [0]
			DataManager.war_control_sort_no = 0
			var wf = DataManager.get_current_war_fight()
			if wf == null:
				return
			var wvs = wf.war_vstates()
			for i in wvs.size():
				if wvs[i].get_main_controlNo() >= 0:
					wf.current = i
			FlowManager.add_flow("load_script|war/war_auto_run.gd")
			
			FlowManager.add_flow("player_before_ready")
		"res://scene/scene_battle/scene_battle.tscn":
			FlowManager.clear()
			LoadControl.end_script()
			var path = DataManager.mod_path + "sgz_script/battle/Battle_Auto_Run.gd"
			SceneManager.current_scene().battle_run = Global.load_script(path)
			
			FlowManager.add_flow("battle_set_state")
		"res://scene/scene_solo/scene_solo.tscn":
			FlowManager.clear()
			LoadControl.end_script()
			FlowManager.add_flow("load_script|solo/solo_auto_run.gd")
			
			FlowManager.add_flow("solo_run_start")
	return

func reset_layout_landscape() -> void :
	rect_position = Vector2(243, 92)
	rect_scale = Vector2(1, 1)
	return

func reset_layout_portrait() -> void :
	rect_position = Vector2(53, 330)
	rect_scale = Vector2(1.7066, 1.6)
	return
