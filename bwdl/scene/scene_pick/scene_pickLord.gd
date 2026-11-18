extends Control

const SCENE_ID = 0

const VIEW_MODEL_NAME = "选人画面-步骤"

var vstate_array = [];
var name_array = [];
var node_scale = 1;
var cursor_index: int = 0;
var vseparation: float = 0;
var hseparation: float = 0;

var init_vect2: Vector2;

onready var gv = get_node("Window4/GridContainer");
onready var cursor = get_node("Window4/cursor");
onready var ding = get_node("ding");

var secret_input: Dictionary = {
	secret_full_1p = 0, 
	secret_laugh = 0, 
	secret_cry = 0, 
}

var conVstate = load("res://windows/children/conLordNode.tscn");

var current_playerNo = 0;


func _ready() -> void :
	cursor.hide();
	SceneManager.load_scene_complete = true;
	DataManager.secret_mood = - 1;
	if DataManager.common_variable.has("ding"):
		secret_input.secret_full_1p = 8
	ding.stop();
	SoundManager.play_bgm("res://resource/sounds/bgm/Scene_Choose.ogg");
	
	FlowManager.clear_bind_method();
	FlowManager.bind_signal_method("ask_next_player_choose", self)
	FlowManager.bind_signal_method("ask_same_choose", self)
	FlowManager.bind_signal_method("view_mode_1", self)
	FlowManager.bind_signal_method("view_mode_2", self)
	FlowManager.bind_signal_method("view_mode_2_none", self)
	FlowManager.bind_signal_method("view_mode_3", self)
	
	FlowManager.clear_pre_history.append("ask_next_player_choose")
	
	_init_items();
	return

func _init_items():

	var settings = StaticManager.get_pick_lord_setting()
	vstate_array = []
	name_array = []
	
	
	if DataManager.is_stars_drama():
		for vsData in StaticManager.vstates_static:
			var vsId = Global.intval(Global.dic_val(vsData, "ID"))
			if vsId >= 0 and Global.dic_val(vsData, "状态") == "正常":
				_random_init_vstate(vsId)
	
	for vs in clVState.all_vstates(true):
		vstate_array.append(vs.id)
		name_array.append(vs.get_lord_name())
	
	vstate_array.append(StaticManager.VSTATEID_RANDOM)
	name_array.append("随机")
	init_vect2 = Vector2(float(settings["光标初始x坐标"]), float(settings["光标初始y坐标"]));
	vseparation = float(settings["行间距"]);
	hseparation = float(settings["列间距"])
	gv.set("custom_constants/vseparation", vseparation);
	gv.set("custom_constants/hseparation", hseparation);
	gv.columns = int(settings["列数"]);
	node_scale = float(settings["君主选项缩放"]);
	gv.rect_position.x = float(settings["整体x偏移"]);
	gv.rect_position.y = float(settings["整体y偏移"]);

	Global.clearNode(gv);
	for i in vstate_array.size():
		var vstateId = vstate_array[i];
		var vstate_name = "";
		if (i < name_array.size()):
			vstate_name = name_array[i];
		if (vstate_name == ""):
			vstate_name = clVState.vstate(vstateId).get_lord_name()
		if vstateId == StaticManager.VSTATEID_RANDOM:
			pass
		var node = conVstate.instance();
		node.name = str(vstateId);
		node.vstateId = vstateId;
		node.vstate_name = vstate_name;
		node.scale = node_scale;
		gv.add_child(node);
	cursor_index = 0;
	
	update_cursor();
	FlowManager.add_flow("ask_next_player_choose");
	return

func set_view_model(vm: int) -> void :
	DataManager.set_env(VIEW_MODEL_NAME, vm)
	return

func get_view_model() -> int:
	return DataManager.get_env_int(VIEW_MODEL_NAME)

func ask_next_player_choose():
	set_view_model(0)
	var pid = AutoLoad.get_pid_by_playerNo(current_playerNo);
	FlowManager.set_current_control_playerNo(current_playerNo);
	cursor_index = DataManager.get_env_int("选人画面.光标", 0)
	update_cursor();
	cursor.hide();
	SceneManager.show_confirm_dialog("请玩家" + str(current_playerNo + 1) + "\n选择扮演之君主");
	return

func ask_same_choose():
	set_view_model(0)
	
	var vstateId = vstate_array[cursor_index];
	var actorId = clVState.vstate(vstateId).get_lord_id()
	for playerno in DataManager.players.size():
		if (playerno == current_playerNo):
			continue;
		var op: Player = DataManager.players[playerno];
		if (op.actorId == actorId):
			SceneManager.show_confirm_dialog("吾已被选过\n请选其他君主", actorId);
	
	var pid = AutoLoad.get_pid_by_playerNo(current_playerNo);
	FlowManager.set_current_control_playerNo(current_playerNo);
	cursor_index = 0;
	if ("选人画面.光标" in DataManager.common_variable):
		cursor_index = int(DataManager.common_variable["选人画面.光标"]);
	update_cursor();
	cursor.hide();
	
func update_cursor():
	var y = cursor_index / gv.columns;
	var x = cursor_index % gv.columns;
	cursor.rect_position = init_vect2 + Vector2(x * hseparation, y * vseparation);

func move_up():
	var y = cursor_index / gv.columns;
	var x = cursor_index % gv.columns;
	y -= 1;
	if (y < 0):
		cursor_index = gv.get_child_count() - 1;
		while (true):
			var y1 = cursor_index / gv.columns;
			var x1 = cursor_index % gv.columns;
			if (x == x1):
				break;
			cursor_index -= 1;
	else:
		cursor_index = y * gv.columns + x;
	set_cursor(cursor_index);
	if (AutoLoad.other_players.size() > 0):
		rpc("set_cursor", cursor_index);

func move_down():
	var y = cursor_index / gv.columns;
	var x = cursor_index % gv.columns;
	y += 1;
	var newindex = y * gv.columns + x;
	if (newindex >= gv.get_child_count()):
		y = 0;
	cursor_index = y * gv.columns + x;
	set_cursor(cursor_index);
	if (AutoLoad.other_players.size() > 0):
		rpc("set_cursor", cursor_index);

func move_left():
	var y = cursor_index / gv.columns;
	var x = cursor_index % gv.columns;
	x -= 1;
	if (x < 0):
		x = gv.columns - 1;
	cursor_index = y * gv.columns + x;
	while (cursor_index >= gv.get_child_count()):
		x -= 1;
		cursor_index = y * gv.columns + x;
	set_cursor(cursor_index);
	if (AutoLoad.other_players.size() > 0):
		rpc("set_cursor", cursor_index);

func move_right():
	var y = cursor_index / gv.columns;
	var x = cursor_index % gv.columns;
	x += 1;
	if (x >= gv.columns):
		x = 0;
	var newindex = y * gv.columns + x;
	if (newindex >= gv.get_child_count()):
		x = 0;
	cursor_index = y * gv.columns + x;
	set_cursor(cursor_index);
	if (AutoLoad.other_players.size() > 0):
		rpc("set_cursor", cursor_index);

remote func set_cursor(index: int):
	cursor_index = index;
	DataManager.set_env("选人画面.光标", cursor_index)
	update_cursor();
	_show_actor_info()
	return

func _process(delta: float) -> void :
	if (FlowManager.has_task()):
		return ;
	if (AutoLoad.playerNo == FlowManager.controlNo):
		on_key_input();
	return

func on_key_input():
	if (gv.get_child_count() == 0):
		return ;
	var is_emu_select_pressed = Input.is_action_pressed("EMU_SELECT");
	var is_emu_start_pressed = Input.is_action_pressed("EMU_START");
	var is_just_up_press = Input.is_action_just_pressed("ANALOG_UP");
	var is_just_down_press = Input.is_action_just_pressed("ANALOG_DOWN");
	var is_just_left_press = Input.is_action_just_pressed("ANALOG_LEFT");
	var is_just_right_press = Input.is_action_just_pressed("ANALOG_RIGHT");
	
	var analog_input_list = {
		"上": is_just_up_press, 
		"下": is_just_down_press, 
		"左": is_just_left_press, 
		"右": is_just_right_press, 
	}
	
	if ( not is_emu_start_pressed and not is_emu_select_pressed):
		
		secret_clear()
	else:
		secret_check_full(analog_input_list, is_emu_select_pressed, is_emu_start_pressed)
	match get_view_model():
		0:
			Global.wait_for_confirmation("view_mode_1", VIEW_MODEL_NAME)
		1:
			if is_just_down_press:
				move_down()
			if is_just_up_press:
				move_up()
			if is_just_left_press:
				move_left()
			if is_just_right_press:
				move_right()
			if Global.wait_for_confirmation("", VIEW_MODEL_NAME):
				Input.action_release("EMU_A")
				DataManager.unset_env("ding")
				if is_emu_start_pressed or is_emu_select_pressed:
					FlowManager.add_flow("view_mode_2_none")
				else:
					FlowManager.add_flow("view_mode_2")
	return


func _show_actor_info():
	var vstateId = vstate_array[cursor_index];
	var actorId = clVState.vstate(vstateId).get_lord_id()
	if actorId < 0 and vstateId < 0:
		SceneManager.hide_all_tool();
		return
	if vstateId == StaticManager.VSTATEID_RANDOM and actorId < 0:
		var diy = DataManager.get_env_dict("DIY")
		if not "enabled" in diy or not diy["enabled"]:
			diy = {}
		if int(Global.dic_val(diy, "vstateId", - 1)) == StaticManager.RANDOM_VSTATE_LORD:
			actorId = int(Global.dic_val(diy, "actorId", - 1))
	SceneManager.show_actor_info(actorId)
	return

func secret_clear():
	if (secret_input.secret_full_1p < 8):
		secret_input.secret_full_1p = 0;
	if (secret_input.secret_laugh < 8):
		secret_input.secret_laugh = 0;
	if (secret_input.secret_cry < 8):
		secret_input.secret_cry = 0;
	

func secret_check_full(analog_input_list: Dictionary, select_pressed: bool, start_pressed: bool):
	if not start_pressed and not select_pressed:
		secret_clear()
		return

	
	if get_view_model() == 0 and secret_input.secret_full_1p < 8:
		var secret_full = ["上", "下", "上", "下", "左", "右", "左", "右"]
		var index: int = secret_input.secret_full_1p
		if analog_input_list[secret_full[index]]:
			secret_input.secret_full_1p += 1
			if secret_input.secret_full_1p >= 8:
				ding.play()
				DataManager.set_env("ding", 1)
				SceneManager.show_unconfirm_dialog("叮~")
				return

	
	if secret_input.secret_laugh < 8 and secret_input.secret_cry < 8:
		
		if select_pressed:
			var secret_full = ["右", "右", "下", "下", "上", "下", "上", "下"]
			var index: int = secret_input.secret_laugh
			if analog_input_list[secret_full[index]]:
				secret_input.secret_laugh += 1
				if secret_input.secret_laugh >= 8:
					ding.play()
					SceneManager.show_unconfirm_dialog("Duang~")
					DataManager.secret_mood = 1
		
		elif start_pressed:
			var secret_full = ["上", "右", "下", "左", "上", "左", "下", "右"]
			var index: int = secret_input.secret_cry
			if analog_input_list[secret_full[index]]:
				secret_input.secret_cry += 1;
				if secret_input.secret_cry >= 8:
					ding.play()
					SceneManager.show_unconfirm_dialog("Duang~")
					DataManager.secret_mood = 3
	return



func view_mode_1():
	set_view_model(1)
	SceneManager.hide_all_tool()
	_show_actor_info()
	cursor.show()
	return


func view_mode_2():
	set_view_model(2)
	var vstateId = vstate_array[cursor_index]

	var diy = DataManager.get_env_dict("DIY")
	if not "enabled" in diy or not diy["enabled"]:
		diy = {}
	if not diy.empty():
		if int(diy["vstateId"]) < 90:
			var diyVstateId = int(diy["vstateId"])
			var diyVstate = clVState.vstate(diyVstateId)
			var capital = DataManager.get_office_city_by_actor(diyVstate.get_lord_id())
			if capital != null:
				var tempActor = ActorHelper.actor(int(diy["actorId"]))
				tempActor.set_status_officed()
				tempActor.set_loyalty(min(99, tempActor.get_loyalty()))
				tempActor.set_soldiers(1000)
				capital.add_actor(tempActor.actorId)
	else:
		ActorHelper.actor(StaticManager.ACTOR_ID_DIY).set_status_disabled()
	
	var actorId = clVState.vstate(vstateId).get_lord_id()
	if actorId == - 1:
		actorId = _pick_wild_vstate(diy)
	
	
	for playerno in DataManager.players.size():
		if (playerno == current_playerNo):
			continue;
		var op: Player = DataManager.players[playerno];
		if (op.actorId == actorId):
			FlowManager.add_flow("ask_same_choose");
			return ;
	var p: Player = DataManager.players[current_playerNo];
	p.set_actor(actorId)
	if secret_input.secret_full_1p >= 8:
		var city = DataManager.get_office_city_by_actor(actorId);
		if city != null:
			city.set_fully_developed()
	next_player_choose()
	return


func view_mode_2_none():
	set_view_model(2)

	
	
	if DataManager.is_stars_drama():
		for id in vstate_array:
			
			if id == StaticManager.VSTATEID_RANDOM:
				continue
			_random_init_vstate(id)

	var vstateId = vstate_array[cursor_index];
	var actorId = clVState.vstate(vstateId).get_lord_id()
	var p: Player = DataManager.players[current_playerNo];
	p.set_actor( - 1)
	next_player_choose()
	return


func view_mode_3():
	DataManager.clear_common_variable(["选人画面"])
	FlowManager.add_flow("go_to_scene|res://scene/scene_affiars/scene_affiars.tscn")
	FlowManager.add_flow("game_start")
	return

func next_player_choose():
	var next_playerNo = current_playerNo + 1
	if next_playerNo < DataManager.players.size():
		current_playerNo = next_playerNo
		FlowManager.add_flow("ask_next_player_choose")
		return
	FlowManager.add_flow("view_mode_3")
	return


func _pick_wild_vstate(diy: Dictionary) -> int:
	
	var vacantCities = clCity.all_cities([ - 1])
	if vacantCities.empty():
		return - 1
	var selectedActorId = - 1
	var vs = clVState.vstate(StaticManager.VSTATEID_RANDOM)
	vacantCities.shuffle()
	var vacantCity = vacantCities[0]
	vacantCity.set_vstate_id(vs.id)
	vs.set_alive()

	
	if DataManager.is_stars_drama():
		
		var actor = null
		if not diy.empty():
			var actorId = int(diy["actorId"])
			actor = ActorHelper.actor(actorId)
		else:
			var candidates = ActorHelper.all_disabled_actors([StaticManager.ACTOR_ID_DIY, StaticManager.ACTOR_ID_LIUBIAN])
			candidates.shuffle()
			actor = candidates[0]
		
		clCity.move_out(actor.actorId)
		vacantCity.add_actor(actor.actorId)
		vacantCity.set_property("金", 500)
		vacantCity.set_property("米", 800)
		
		vs.set_lord(actor.actorId)
		
		actor.set_status_officed()
		actor.set_loyalty(100)
		actor.set_soldiers(1000)
		return actor.actorId

	var actors = [ - 1, - 1, - 1]
	var specifiedActors = []
	if DataManager.is_test_player():
		var specifiedActorData = DataManager.get_test_player_content("随机势力武将")
		for actorName in specifiedActorData.split("/"):
			for actor in ActorHelper.all_available_actors():
				if actor.get_name() != actorName:
					continue
				if actor.is_status_unofficed() or actor.is_status_hidden():
					specifiedActors.append(actor.actorId)
					break

	
	if not diy.empty():
		var diyActorId = int(diy["actorId"])
		match int(diy["vstateId"]):
			100:
				vs.set_lord(diyActorId)
				var actor = ActorHelper.actor(diyActorId)
				actor.set_status_officed()
				actor.set_loyalty(100)
				actor.set_soldiers(1000)
				actors[0] = diyActorId
				selectedActorId = diyActorId
			101:
				var actor = ActorHelper.actor(diyActorId)
				actor.set_status_officed()
				actor.set_loyalty(min(90, actor.get_loyalty()))
				actor.set_soldiers(1000)
				actors[2] = diyActorId

	
	for i in actors.size():
		if actors[i] >= 0:
			continue
		while true:
			var actorId = - 1
			if not specifiedActors.empty():
				actorId = specifiedActors.pop_front()
			else:
				actorId = ActorHelper.random_actor_id()
			var actor = ActorHelper.actor(actorId)
			if not actor.is_status_unofficed() and not actor.is_status_hidden():
				continue
			if actor.get_life_limit() < StaticManager.get_starting_year(DataManager.drama_path):
				continue
			actors[i] = actor.actorId
			if i == 0:
				actor.set_loyalty(100)
				DataManager.lord_change(vs.id, actor.actorId)
			else:
				actor.set_loyalty(min(99, actor.get_loyalty()))
			actor.set_status_officed()
			actor.set_soldiers(1000)
			break

	for actorId in actors:
		vacantCity.add_actor(actorId)
	if selectedActorId < 0:
		selectedActorId = actors[0]

	return selectedActorId


func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.70666, 1.6)
	return

func reset_layout_landscape():
	rect_position = Vector2(212, 0)
	rect_scale = Vector2(1, 1)
	return


func _random_init_vstate(vstateId: int) -> void :
	var vs = clVState.vstate(vstateId)
	var lord = ActorHelper.actor(vs.get_lord_id())
	
	lord.set_status_officed()
	clCity.move_out(lord.actorId)
	var cities = clCity.all_cities([vstateId])
	var capital: clCity.CityInfo
	if not cities.empty():
		capital = cities[0]
	else:
		var vacants = clCity.all_cities([ - 1])
		vacants.shuffle()
		capital = vacants[0]
	capital.set_vstate_id(vstateId)
	capital.clear_actors()
	capital.add_actor(lord.actorId)
	capital.set_property("金", 500)
	capital.set_property("米", 800)
	lord.set_loyalty(100)
	vs.set_alive()
	return
