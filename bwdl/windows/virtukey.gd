extends Control

const CHALLANGE_RULES = """第七届霸王的大陆GD杯直播挑战赛细则

比赛玩法
在挑战赛模式中自选5名武将（含主将）+3名随机武将（共8人）开局
胜利条件：过两关即胜利，过关后会有自动积分系统显示成绩

注意事项：
★只要不作弊，允许挑战者使用任何玩法
★每小关限时1小时（3600秒倒计时），练习中时间到了游戏继续，正式比赛中算翻车
★请挑战者出全力认真对待初赛，初赛分数能决定复赛的优先选择权，能带来很大的优势
★比赛的版本和最终积分规则以最终正式比赛的版本为准（预计2026年4月份开赛）

复赛规则：
复赛难度会有所提升，详细规则等初赛全部比完就会出炉，报名者先用2.510版本练习即可

参与直播挑战的具体活动规则，请联系骉哥。
报名免费！联系人：骉哥
（VX：biaoge7547，QQ:677805）
报名后，具体比赛时间骉哥会和挑战者商量安排

自动积分规则
基础分 ：每过一关+100分；
每死亡1名武将扣-11分；
挑战者方每投降1名武将扣-50分（允许负分）；
每过一关的分数 =基础分 - 死亡扣分 - 投降扣分
初赛过2关的满分为200分

挑战赛模式中自选以下50名武将会自动扣分，如是随机来的则不扣分
扣分理由：都是曾在前六届挑战赛中大放异彩的武将，玩法已被大家熟知，
这个规则也是为了让更多新的武将组合和新的技能配合涌现，让比赛更精彩。
扣十分/关：赵云、姜维、文鸯、张辽、诸葛亮、马超、甘宁、吕布、张飞、周瑜
扣八分/关：关羽、曹操、黄忠、孙坚、司马懿、颜良、魏延、庞德、董卓、吕蒙
扣六分/关：文丑、张梁、张宝、郝昭、太史慈、孙策、曹仁、张绣、曹彰、罗宪
扣五分/关：陆逊、潘凤、曹昂、刘备、夏侯恩、张任、华佗、乐进、麹义、孟获
扣四分/关：丁原、孔融、鲁肃、贾诩、邢道荣、徐庶、邓艾、孙峻、张角、臧霸
"""

onready var pnlJoySet = get_node("set/pnlJoySet");
onready var analog = get_node("VirtualKey/con_analog/analog");
onready var analog_up = get_node("VirtualKey/con_analog/analog_up");
onready var analog_down = get_node("VirtualKey/con_analog/analog_down");
onready var analog_left = get_node("VirtualKey/con_analog/analog_left");
onready var analog_right = get_node("VirtualKey/con_analog/analog_right");

onready var btnemu_A = get_node("VirtualKey/con_btnemu_A/btnemu_A");
onready var btnemu_B = get_node("VirtualKey/con_btnemu_B/btnemu_B");
onready var btnemu_X = get_node("VirtualKey/con_btnemu_X/btnemu_X");
onready var btnemu_Y = get_node("VirtualKey/con_btnemu_Y/btnemu_Y");
onready var btnemu_select = get_node("VirtualKey/con_btnemu_select/btnemu_select");
onready var btnemu_start = get_node("VirtualKey/con_btnemu_start/btnemu_start");

onready var btnemu_array = [
	get_node("VirtualKey/con_analog"), 
	get_node("VirtualKey/con_btnemu_A"), 
	get_node("VirtualKey/con_btnemu_B"), 
	get_node("VirtualKey/con_btnemu_X"), 
	get_node("VirtualKey/con_btnemu_Y"), 
	get_node("VirtualKey/con_btnemu_select"), 
	get_node("VirtualKey/con_btnemu_start"), 
]

onready var btnSetting = get_node("btnSetting")
onready var btnSpeedUp = get_node("btnSpeed_up")
onready var btnSpeedDown = get_node("btnSpeed_down")
onready var btnShowSkill = get_node("btnShowSkill")
onready var lblDebug = get_node("lblDebug")
onready var lblSpeed = get_node("lblspeed")

onready var lblPlayerNo = get_node("lblPlayerNo")
onready var lblVersion = get_node("lblVersion")

export var allow_tilting: bool = true;

var emu_enable = true
var emu_set = false


export (float) var release_alpha = 0.6;
export (float) var press_alpha = 0.2;

var lblspeed_show_time: float = 0

const game_speed_array = [5, 10, 20, 50, 100, 150, 200, 300, 400, 800, 1600];

const DEFAULT_KEYBOARD: Dictionary = {
	"ANALOG_UP": KEY_W, 
	"ANALOG_DOWN": KEY_S, 
	"ANALOG_LEFT": KEY_A, 
	"ANALOG_RIGHT": KEY_D, 
	"EMU_A": KEY_J, 
	"EMU_B": KEY_K, 
	"EMU_X": KEY_U, 
	"EMU_Y": KEY_I, 
	"EMU_START": KEY_ENTER, 
	"EMU_SELECT": KEY_APOSTROPHE, 
	"EMU_MENU": KEY_ESCAPE, 
	"EMU_LAYOUT": KEY_TAB, 
	"EMU_SPEED_UP": KEY_KP_ADD, 
	"EMU_SPEED_DOWN": KEY_KP_SUBTRACT
}

signal IGNORED_INPUT

var keyboard: Dictionary = DEFAULT_KEYBOARD.duplicate(true)

var last_quick_save = - 1

func _ready():
	btnShowSkill.hide()
	lblDebug.hide()
	lblSpeed.hide()
	
	var key_set_path = "user://keyboard_set.json";
	var keyoard_set: String = Global.get_file_text(key_set_path);
	if keyoard_set == "":
		keyboard = get_key_default()
		Global.save_file_text(key_set_path, to_json(keyboard))
	else:
		keyboard = parse_json(keyoard_set);
	
	var hkSetting = StaticManager.get_hide_key_setting()
	if "隐藏虚拟键" in hkSetting:
		get_node("VirtualKey").visible = not Global.boolval(hkSetting["隐藏虚拟键"])
	
	analog.self_modulate.a = release_alpha;
	analog_up.self_modulate.a = release_alpha;
	analog_left.self_modulate.a = release_alpha;
	analog_down.self_modulate.a = release_alpha;
	analog_right.self_modulate.a = release_alpha;
	
	get_node("lblspeed").hide()
	
	pnlJoySet.connect("joy_set_quit", self, "_on_joy_set_quit");
	change_set_mode(false)
	read_vkey_set()
	return

func read_vkey_set():
	var setting = "user://vkey_set.json"
	if SceneManager.portrait_mode:
		setting = "user://vkey_set_p.json"
	var dic_str = Global.get_file_text(setting)
	if dic_str == "":
		return {}
	var dic = parse_json(dic_str)
	for d_btn_name in dic:
		var con_btn: Control = get_node("VirtualKey").get_node(d_btn_name)
		var d_btn = dic[d_btn_name]
		con_btn.rect_scale.x = d_btn["rect_scale:x"]
		con_btn.rect_scale.y = d_btn["rect_scale:x"]
		con_btn.modulate.a = d_btn["modulate:a"]
		con_btn.rect_position.x = d_btn["rect_position:x"]
		con_btn.rect_position.y = d_btn["rect_position:y"]
	return

func write_vkey_set(from_con: Control = null):
	var dic = {}
	for con_btn in btnemu_array:
		if from_con != null:
			con_btn = from_con.get_node(con_btn.name)
		var d_btn = {}
		d_btn["rect_scale:x"] = con_btn.rect_scale.x
		d_btn["modulate:a"] = con_btn.modulate.a
		d_btn["rect_position:x"] = con_btn.rect_position.x
		d_btn["rect_position:y"] = con_btn.rect_position.y
		dic[con_btn.name] = d_btn
	var setting = "user://vkey_set.json"
	if SceneManager.portrait_mode:
		setting = "user://vkey_set_p.json"
	Global.save_file_text(setting, to_json(dic))
	return

func _on_joy_set_quit() -> void :
	change_set_mode(false)
	return

func change_set_mode(b: bool):
	for btn in btnemu_array:
		btn.disable_dragging()
		btn.modulate.r = 1.0
		btn.modulate.g = 1.0
		btn.modulate.b = 1.0
	emu_set = b
	emu_enable = not b
	var btn_analog_set = get_node("VirtualKey/con_analog/btn_analog")
	btn_analog_set.visible = b
	btn_analog_set.modulate.a = 0
	pnlJoySet.visible = b
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not b:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	$set.mouse_filter = mouse_filter
	pnlJoySet.mouse_filter = mouse_filter
	return


func change_speed(time_scale: float):
	_rpc_change_speed(time_scale)
	if AutoLoad.check_is_multigame():
		rpc("_rpc_change_speed", time_scale)
	return

remote func _rpc_change_speed(time_scale: float):
	Global.change_speed(time_scale)
	SoundManager.change_speed(time_scale)
	Global.save_user_preference()
	SceneManager.show_system_notice("游戏速度：{0}%".format([time_scale * 100]), 300)
	return

func _process(delta):
	_virtualkey_show()
	
	if not AutoLoad.check_is_multigame():
		if FlowManager.controlNo != 0:
			FlowManager.controlNo = 0
	
	if not SceneManager.black.visible:
		if lblspeed_show_time > 0:
			lblspeed_show_time -= 1
			if lblspeed_show_time <= 0:
				lblspeed_show_time = 0
				get_node("lblspeed").hide()
	return

func _unhandled_input(event: InputEvent) -> void :
	var matchedAction = ""
	var pressed = false
	if event is InputEventJoypadButton:
		var code = StaticManager.JOY_BUTTON_PREFIX + str(event.button_index)
		var codePiece = "|{0}|".format([code])
		for action in keyboard.keys():
			var setting = str(keyboard[action])
			if code == setting or codePiece in setting:
				matchedAction = action
				pressed = event.pressed
				break
	if matchedAction != "":
		if emu_enable:
			if pressed:
				Input.action_press(matchedAction)
			else:
				Input.action_release(matchedAction)
		else:
			
			
			emit_signal("IGNORED_INPUT", matchedAction, pressed)
		return
	
	if not emu_enable:
		return
	if event is InputEventJoypadMotion:
		if event.axis == 0:
			if event.axis_value < - 0.8:
				Input.action_press("ANALOG_LEFT")
			elif event.axis_value > 0.8:
				Input.action_press("ANALOG_RIGHT")
			elif abs(event.axis_value) < 0.01:
				Input.action_release("ANALOG_LEFT")
				Input.action_release("ANALOG_RIGHT")
		elif event.axis == 1:
			if event.axis_value < - 0.8:
				Input.action_press("ANALOG_UP")
			elif event.axis_value > 0.8:
				Input.action_press("ANALOG_DOWN")
			elif abs(event.axis_value) < 0.01:
				Input.action_release("ANALOG_UP")
				Input.action_release("ANALOG_DOWN")
	return

func _unhandled_key_input(event: InputEventKey) -> void :
	var matchedAction = ""
	var pressed = false
	var code = str(event.physical_scancode)
	var codePiece = "|{0}|".format([code])
	for action in keyboard.keys():
		var setting = str(keyboard[action])
		if code == setting or codePiece in setting:
			matchedAction = action
			pressed = event.pressed
			break
	if matchedAction == "":
		
		for action in DEFAULT_KEYBOARD.keys():
			var setting = str(DEFAULT_KEYBOARD[action])
			if code == setting:
				matchedAction = action
				pressed = event.pressed
				break
	if matchedAction != "":
		if emu_enable:
			if pressed:
				Input.action_press(matchedAction)
			else:
				Input.action_release(matchedAction)
		else:
			
			
			emit_signal("IGNORED_INPUT", matchedAction, pressed)
		return
	if DataManager.is_developer() and emu_enable:
		
		var quickSave = "quick"
		if DataManager.endless_mode:
			quickSave = "quick_e"
		elif "scene_endless" in SceneManager.current_scene_path:
			quickSave = "quick_e"
		var tm = Time.get_ticks_msec()
		if tm - last_quick_save > 1000:
			last_quick_save = tm
			if code == str(KEY_Q):
				DataManager.auto_save(quickSave)
				return
			if code == str(KEY_E):
				Global.reset()
				SoundManager.reset()
				SceneManager.clear_stage()
				FlowManager.clear()
				LoadControl.end_script()
				FlowManager.add_flow("load_game_data|" + DataManager.get_common_path() + "save/" + quickSave + ".sav")
				return
	return


func get_key_default():
	return DEFAULT_KEYBOARD.duplicate(true)


func _virtualkey_show():
	
	if Input.is_action_pressed("ANALOG_UP"):
		analog_up.visible = true
	else:
		analog_up.visible = false
	if Input.is_action_pressed("ANALOG_DOWN"):
		analog_down.visible = true
	else:
		analog_down.visible = false
	if Input.is_action_pressed("ANALOG_LEFT"):
		analog_left.visible = true
	else:
		analog_left.visible = false
	if Input.is_action_pressed("ANALOG_RIGHT"):
		analog_right.visible = true
	else:
		analog_right.visible = false
	
	analog.visible = ( not analog_down.visible and not analog_up.visible and not analog_left.visible and not analog_right.visible)


	
	if Input.is_action_pressed("EMU_X"):
		btnemu_X.self_modulate.a = press_alpha
	else:
		btnemu_X.self_modulate.a = release_alpha
	if Input.is_action_pressed("EMU_Y"):
		btnemu_Y.self_modulate.a = press_alpha
	else:
		btnemu_Y.self_modulate.a = release_alpha
	if Input.is_action_pressed("EMU_A"):
		btnemu_A.self_modulate.a = press_alpha
	else:
		btnemu_A.self_modulate.a = release_alpha
	if Input.is_action_pressed("EMU_B"):
		btnemu_B.self_modulate.a = press_alpha
	else:
		btnemu_B.self_modulate.a = release_alpha

	if Input.is_action_pressed("EMU_SELECT"):
		btnemu_select.self_modulate.a = press_alpha
	else:
		btnemu_select.self_modulate.a = release_alpha
	if Input.is_action_pressed("EMU_START"):
		btnemu_start.self_modulate.a = press_alpha
	else:
		btnemu_start.self_modulate.a = release_alpha
		
	if Input.is_action_just_pressed("EMU_SPEED_UP"):
		btnSpeedUp.self_modulate.a = press_alpha
		var time_scale = int(Global.get_speed() * 100)
		for t in game_speed_array:
			if t > time_scale:
				time_scale = t
				break
		change_speed(time_scale / 100.0)
	else:
		btnSpeedUp.self_modulate.a = release_alpha

	if Input.is_action_just_pressed("EMU_SPEED_DOWN"):
		btnSpeedDown.self_modulate.a = press_alpha
		var time_scale: int = int(Engine.time_scale * 100);
		for i in game_speed_array.size():
			var new_time_scale: int = game_speed_array[game_speed_array.size() - 1 - i]
			if new_time_scale >= time_scale:
				continue
			time_scale = new_time_scale
			break
		change_speed(time_scale / 100.0)
	else:
		btnSpeedDown.self_modulate.a = release_alpha

	if Input.is_action_just_pressed("EMU_MENU"):
		if SceneManager.get_node("Virtukey/Quit/pnlControl").visible:
			return
		if not SceneManager.Quit.visible:
			if SceneManager.actor_info.actor_description.visible:
				SceneManager.actor_info.actor_description.hide()
			SceneManager.Quit.show_menu()
		else:
			SceneManager.Quit._on_btnBackToGame_pressed()
	return

func _on_btnUp_pressed() -> void :
	if not emu_enable:
		return
	Input.action_press("ANALOG_UP")
	return

func _on_btnUp_released() -> void :
	if not emu_enable:
		return
	Input.action_release("ANALOG_UP")
	return


func _on_btnDown_pressed():
	if not emu_enable:
		return
	Input.action_press("ANALOG_DOWN")
	return


func _on_btnDown_released():
	if not emu_enable:
		return
	Input.action_release("ANALOG_DOWN")
	return


func _on_btnLeft_pressed():
	if not emu_enable:
		return
	Input.action_press("ANALOG_LEFT")
	return


func _on_btnLeft_released():
	if not emu_enable:
		return
	Input.action_release("ANALOG_LEFT")
	return


func _on_btnRight_pressed():
	if not emu_enable:
		return
	Input.action_press("ANALOG_RIGHT")
	return


func _on_btnRight_released():
	if not emu_enable:
		return
	Input.action_release("ANALOG_RIGHT")
	return


func _on_btnemu_A_pressed():
	if on_enum_btn_set_pressed(get_node("VirtualKey/con_btnemu_A")):
		return
	if not emu_enable:
		return
	Input.action_press("EMU_A")
	return


func _on_btnemu_A_released():
	if not emu_enable:
		return
	Input.action_release("EMU_A")
	return


func _on_btnemu_B_pressed():
	if on_enum_btn_set_pressed(get_node("VirtualKey/con_btnemu_B")):
		return
	if not emu_enable:
		return
	Input.action_press("EMU_B")
	return


func _on_btnemu_B_released():
	if not emu_enable:
		return
	Input.action_release("EMU_B")
	return


func _on_btnemu_select_pressed():
	if on_enum_btn_set_pressed(get_node("VirtualKey/con_btnemu_select")):
		return
	if not emu_enable:
		return
	Input.action_press("EMU_SELECT")
	return


func _on_btnemu_select_released():
	if not emu_enable:
		return
	Input.action_release("EMU_SELECT")
	return


func _on_btnemu_start_pressed():
	if on_enum_btn_set_pressed(get_node("VirtualKey/con_btnemu_start")):
		return ;
	if not emu_enable:
		return
	Input.action_press("EMU_START")
	return


func _on_btnemu_start_released():
	if not emu_enable:
		return
	Input.action_release("EMU_START")
	return

func _on_btnemu_X_pressed() -> void :
	if on_enum_btn_set_pressed(get_node("VirtualKey/con_btnemu_X")):
		return
	if not emu_enable:
		return
	Input.action_press("EMU_X")
	return

func _on_btnemu_X_released() -> void :
	if not emu_enable:
		return
	Input.action_release("EMU_X")
	return

func _on_btnemu_Y_pressed() -> void :
	if on_enum_btn_set_pressed(get_node("VirtualKey/con_btnemu_Y")):
		return ;
	if not emu_enable:
		return
	Input.action_press("EMU_Y")
	return

func _on_btnemu_Y_released() -> void :
	if not emu_enable:
		return
	Input.action_release("EMU_Y")
	return

func _on_btnLeftUp_pressed() -> void :
	if not emu_enable:
		return
	if allow_tilting:
		Input.action_press("ANALOG_LEFT")
		Input.action_press("ANALOG_UP")
	return

func _on_btnLeftUp_released() -> void :
	if not emu_enable:
		return
	if allow_tilting:
		Input.action_release("ANALOG_LEFT")
		Input.action_release("ANALOG_UP")
	return

func _on_btnLeftDown_pressed() -> void :
	if not emu_enable:
		return
	if allow_tilting:
		Input.action_press("ANALOG_LEFT")
		Input.action_press("ANALOG_DOWN")
	return

func _on_btnLeftDown_released() -> void :
	if not emu_enable:
		return
	if allow_tilting:
		Input.action_release("ANALOG_LEFT")
		Input.action_release("ANALOG_DOWN")
	return

func _on_btnRightUp_pressed() -> void :
	if not emu_enable:
		return
	if allow_tilting:
		Input.action_press("ANALOG_RIGHT")
		Input.action_press("ANALOG_UP")
	return

func _on_btnRightUp_released() -> void :
	if not emu_enable:
		return
	if allow_tilting:
		Input.action_release("ANALOG_RIGHT")
		Input.action_release("ANALOG_UP")
	return

func _on_btnRightDown_pressed() -> void :
	if not emu_enable:
		return
	if allow_tilting:
		Input.action_press("ANALOG_RIGHT")
		Input.action_press("ANALOG_DOWN")
	return

func _on_btnRightDown_released() -> void :
	if not emu_enable:
		return
	if allow_tilting:
		Input.action_release("ANALOG_RIGHT")
		Input.action_release("ANALOG_DOWN")
	return

func _on_btnSetting_pressed() -> void :
	if not emu_enable:
		return
	Input.action_press("EMU_MENU")
	return

func _on_btnSetting_released() -> void :
	if not emu_enable:
		return
	Input.action_release("EMU_MENU")
	return


func _on_btnSpeed_up_pressed() -> void :
	if not emu_enable:
		return
	Input.action_press("EMU_SPEED_UP")
	return


func _on_btnSpeed_up_released() -> void :
	if not emu_enable:
		return
	Input.action_release("EMU_SPEED_UP")
	return


func _on_btnSpeed_down_pressed() -> void :
	if not emu_enable:
		return
	Input.action_press("EMU_SPEED_DOWN")
	return


func _on_btnSpeed_down_released() -> void :
	if not emu_enable:
		return
	Input.action_release("EMU_SPEED_DOWN")
	return

func can_drop_data(_position, data):
	return true

func get_drag_data(position):
	return

func drop_data(_position, data):
	if data["type"] == "joyset":
		pnlJoySet.drop_data(_position, data)
	if data["type"] == "key":
		var control = data["self"]
		control.drop_data(_position, data)
		pnlJoySet.set_control_ready(control);
	for btn in btnemu_array:
		btn.disable_dragging()
	return

func _on_btn_analog_pressed() -> void :
	on_enum_btn_set_pressed(get_node("VirtualKey/con_analog"))
	return

func on_enum_btn_set_pressed(btn_con: Control) -> bool:
	if not emu_set:
		return false
	for btn in btnemu_array:
		btn.disable_dragging()
	btn_con.enable_dragging()
	pnlJoySet.set_control_ready(btn_con)
	get_node("set").visible = true
	return true

func show_skill() -> void :
	var actorInfo: Control = SceneManager.get_node("tool_layer/actor_info")
	actorInfo.show_skill()
	return

func reset_labels(reveal: bool = false):
	if DataManager.is_developer():
		lblPlayerNo.text = "开发模式"
	elif DataManager.is_test_player():
		lblPlayerNo.text = "制作组"
	if reveal:
		lblVersion.text = DataManager.VERSION
	else:
		lblVersion.text = DataManager.DISPLAY_VERSION
	return

func restore_vkey_default() -> void :
	if SceneManager.portrait_mode:
		$set.rect_scale = Vector2(1.6, 1.6)
		$set.rect_position = Vector2(240, - 500)
		$VirtualKey / con_analog.rect_scale = Vector2(1.1, 1.1)
		$VirtualKey / con_analog.rect_position = Vector2(3, 106)
		$VirtualKey / con_btnemu_A.rect_scale = Vector2(1, 1)
		$VirtualKey / con_btnemu_A.rect_position = Vector2(603, 244)
		$VirtualKey / con_btnemu_B.rect_scale = Vector2(1, 1)
		$VirtualKey / con_btnemu_B.rect_position = Vector2(479, 244)
		$VirtualKey / con_btnemu_X.rect_scale = Vector2(1, 1)
		$VirtualKey / con_btnemu_X.rect_position = Vector2(603, 117)
		$VirtualKey / con_btnemu_Y.rect_scale = Vector2(1, 1)
		$VirtualKey / con_btnemu_Y.rect_position = Vector2(479, 117)
		$VirtualKey / con_btnemu_select.rect_scale = Vector2(1, 1)
		$VirtualKey / con_btnemu_select.rect_position = Vector2(296, 85)
		$VirtualKey / con_btnemu_start.rect_scale = Vector2(1, 1)
		$VirtualKey / con_btnemu_start.rect_position = Vector2(296, 165)
	else:
		$set.rect_scale = Vector2(1, 1)
		$set.rect_position = Vector2(360, 10)
		$VirtualKey / con_analog.rect_scale = Vector2(1, 1)
		$VirtualKey / con_analog.rect_position = Vector2(3, 302)
		$VirtualKey / con_btnemu_A.rect_scale = Vector2(1, 1)
		$VirtualKey / con_btnemu_A.rect_position = Vector2(903, 410)
		$VirtualKey / con_btnemu_B.rect_scale = Vector2(1, 1)
		$VirtualKey / con_btnemu_B.rect_position = Vector2(779, 410)
		$VirtualKey / con_btnemu_X.rect_scale = Vector2(1, 1)
		$VirtualKey / con_btnemu_X.rect_position = Vector2(903, 283)
		$VirtualKey / con_btnemu_Y.rect_scale = Vector2(1, 1)
		$VirtualKey / con_btnemu_Y.rect_position = Vector2(779, 283)
		$VirtualKey / con_btnemu_select.rect_scale = Vector2(1, 1)
		$VirtualKey / con_btnemu_select.rect_position = Vector2(26, 142)
		$VirtualKey / con_btnemu_start.rect_scale = Vector2(1, 1)
		$VirtualKey / con_btnemu_start.rect_position = Vector2(840, 142)
	return

func reset_layout_landscape():
	rect_position = Vector2(0, 0)
	for node in [btnSetting, btnSpeedDown, btnSpeedUp, btnShowSkill, lblPlayerNo, lblVersion]:
		if node is Label or node is Button:
			node.rect_scale = Vector2(1, 1)
		else:
			node.scale = Vector2(1, 1)
	btnSetting.position = Vector2(9, 11)
	btnSpeedDown.position = Vector2(848, 14)
	btnSpeedUp.position = Vector2(936, 14)
	lblPlayerNo.rect_position = Vector2(21, 69)
	lblVersion.rect_position = Vector2(21, 103)
	btnShowSkill.rect_position = Vector2(21, 216)
	lblDebug.rect_position = Vector2(850, 100)
	lblSpeed.rect_position = Vector2(212, 0)
	lblSpeed.rect_scale = Vector2(0.8, 0.8)
	$VirtualKey.rect_scale = Vector2(1, 1)
	restore_vkey_default()
	read_vkey_set()
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 960)
	for node in [btnSetting, btnSpeedDown, btnSpeedUp, btnShowSkill, lblPlayerNo, lblVersion]:
		if node is Label or node is Button:
			node.rect_scale = Vector2(1.4, 1.4)
		else:
			node.scale = Vector2(1.4, 1.4)
	btnSetting.position = Vector2(9, 20)
	btnSpeedDown.position = Vector2(780, 20)
	btnSpeedUp.position = Vector2(900, 20)
	lblPlayerNo.rect_position = Vector2(24, 100)
	lblVersion.rect_position = Vector2(24, 147)
	btnShowSkill.rect_position = Vector2(276, 14)
	lblDebug.rect_position = Vector2(24, 210)
	lblSpeed.rect_position = Vector2(0, - 960)
	lblSpeed.rect_scale = Vector2(1.4, 1.4)
	$VirtualKey.rect_scale = Vector2(1.4, 1.4)
	restore_vkey_default()
	read_vkey_set()
	return

func switch_version_display(event):
	if event is InputEventMouseButton:
		reset_labels(event.pressed)
	if event is InputEventScreenTouch:
		reset_labels(event.pressed)
	return


func _on_lblDebug_meta_clicked(meta):
	match meta:
		"rules":
			get_tree().paused = true
			SceneManager.notice(CHALLANGE_RULES, self, "notice_confirmed", 
				Vector2(600, 300), "本届挑战赛规则明细")
	return

func notice_confirmed() -> void :
	get_tree().paused = false
	return
