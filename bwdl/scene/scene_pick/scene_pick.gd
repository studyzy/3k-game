# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/scene_pick/scene_pick.gd
# 说明：君主选择场景脚本。选择初始势力/君主。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const SCENE_ID = 0

var view_mode: int = 0;

var all_page_actors = [];
var current_page = [];

var page_actors_count;

var max_page;

var page_no: int = 0;

onready var lsc = get_node("Window4/lsc");
onready var lblpage = get_node("Window4/lblpage");

var current_playerNo = 0;

var actorId = - 1;

func _ready() -> void :
	DataManager.secret_mood = - 1;
	DataManager.players.clear();
	var player_nums = AutoLoad.other_players.size() + 1;
	for i in player_nums:
		DataManager.players.append(Player.new());
	SceneManager.load_scene_complete = true;
	
	page_actors_count = lsc.columns * 8 - 2;
	max_page = ceil(ActorHelper.actors_count() / float(page_actors_count)) - 1;
	_init_all_pages();
	
	FlowManager.clear_bind_method();
	FlowManager.bind_signal_method("ask_next_player_choose", self, "ask_next_player_choose");
	FlowManager.bind_signal_method("view_mode_1", self, "view_mode_1");
	FlowManager.bind_signal_method("view_mode_2", self, "view_mode_2");
	FlowManager.bind_signal_method("view_mode_2_none", self, "view_mode_2_none");
	FlowManager.bind_signal_method("view_mode_3", self, "view_mode_3");
	
	FlowManager.clear_pre_history = [
		"ask_next_player_choose", "view_mode_1", "view_mode_2", "view_mode_2_none", "view_mode_3"
	]
	FlowManager.add_flow("ask_next_player_choose");
	SoundManager.play_bgm("res://resource/sounds/bgm/Scene_Choose.ogg");
	

func ask_next_player_choose():
	view_mode = 0;
	var pid = AutoLoad.get_pid_by_playerNo(current_playerNo);
	FlowManager.set_current_control_playerNo(current_playerNo);
	lsc.cursor_index = 0;
	lsc.cursor.hide();
	SceneManager.show_confirm_dialog("请玩家" + str(current_playerNo + 1) + "\n选择扮演之武将");
	page_no = 0;
	_update_page();

func _init_all_pages():
	
	all_page_actors = [];
	var all_actors = [];
	var array: Array = [];
	for vs in clVState.all_vstates():
		var lordId = vs.get_lord_id()
		if lordId < 0:
			continue
		array.append(lordId);
		all_actors.append(lordId)
	all_page_actors.append(array);
	
	page_no = 0;
	var actor_id = - 1;
	while (true):
		actor_id += 1;
		
		if (actor_id >= ActorHelper.actors_count()):
			break;
		if (actor_id in all_actors):
			continue;
		
		var page: Array = all_page_actors[page_no];
		while (page.size() >= page_actors_count):
			page_no += 1;
			if (all_page_actors.size() >= page_no):
				all_page_actors.append([]);
				page = all_page_actors[page_no];
			
		if (page.has(actor_id)):
			continue;
		page.append(actor_id);
		all_actors.append(actor_id);
		all_page_actors[page_no] = page;
	page_no = 0;
	pass


func _update_page():
	_rpc_update_page();
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_update_page");
	pass
	
remote func _rpc_update_page():
	current_page = [];
	lblpage.text = str(page_no + 1) + "/" + str(max_page + 1);
	lsc.cursor_index = 0;
	lsc.items = [];
	
	for actor_id in all_page_actors[page_no]:
		var actor = ActorHelper.actor(actor_id);
		lsc.items.append(actor.get_name());
		current_page.append(actor_id);
	lsc.items.append("下一页");
	lsc.items.append("上一页");
	current_page.append( - 1);
	current_page.append( - 2);
	lsc._set_data();
	if (view_mode == 1):
		_show_actor_info();

func _process(delta: float) -> void :
	if (FlowManager.has_task()):
		return ;
	if (view_mode == 0):
		if (Global.is_action_pressed_AX()):
			if ( not SceneManager.dialog_msg_complete(true)):
				return ;
			FlowManager.add_flow("view_mode_1");
	elif (view_mode == 1):
		var is_emu_select_pressed = Input.is_action_pressed("EMU_SELECT");
		var is_emu_start_pressed = Input.is_action_pressed("EMU_START");
		if (Global.is_action_pressed_AX()):
			actorId = get_cursor_point_actor();
			if (actorId == - 1):
				_next_page();
				return ;
			if (actorId == - 2):
				_pre_page();
				return ;
			if (is_emu_select_pressed or is_emu_start_pressed):
				FlowManager.add_flow("view_mode_2_none");
			else:
				FlowManager.add_flow("view_mode_2");
			return ;
		if (Input.is_action_just_pressed("ANALOG_DOWN")):
			lsc.move_down();
			_show_actor_info();
		if (Input.is_action_just_pressed("ANALOG_UP")):
			lsc.move_up();
			_show_actor_info();
		if (Input.is_action_just_pressed("ANALOG_LEFT")):
			lsc.move_left();
			_show_actor_info();
		if (Input.is_action_just_pressed("ANALOG_RIGHT")):
			lsc.move_right();
			_show_actor_info();
		if (Input.is_action_just_pressed("EMU_START")):
			_next_page();
		if (Input.is_action_just_pressed("EMU_SELECT")):
			_pre_page();
		pass

func get_cursor_point_actor():
	var actorId = current_page[lsc.cursor_index];
	var page_actors = lsc.gv.get_child_count() - 2;

	return actorId;

func _show_actor_info():
	
	_rpc_show_actor_info();
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_show_actor_info");
	pass

remote func _rpc_show_actor_info():
	actorId = get_cursor_point_actor();
	if (actorId < 0):
		SceneManager.hide_all_tool();
		return ;
	SceneManager.show_actor_info(actorId);
	pass


func _next_page():
	page_no += 1;
	if (page_no > max_page):
		page_no = 0;
	_update_page();

func _pre_page():
	page_no -= 1;
	if (page_no < 0):
		page_no = max_page;
	_update_page();

func view_mode_1():
	view_mode = 1;
	lsc.cursor.show();
	SceneManager.hide_all_tool();
	_show_actor_info();



func view_mode_2():
	view_mode = 2;
	
	
	for playerno in DataManager.players.size():
		if (playerno == current_playerNo):
			continue;
		if (DataManager.players[playerno] == null):
			continue;
		var op: Player = DataManager.players[playerno];
		if (op.actorId == actorId):
			view_mode = 0;
			lsc.cursor_index = 0;
			lsc.cursor.hide();
			SceneManager.show_confirm_dialog("吾已被选过\n请选其他武将", actorId);
			return ;
	
	var p: Player = DataManager.players[current_playerNo];
	p.actorId = actorId;
	
	var actor = ActorHelper.actor(actorId)
	if not actor.is_status_officed():
		p.power_value = 0
		actor.set_status_secluded(DataManager.get_actor_at_cityId(actorId))
	
	next_player_choose()
	return
	
func view_mode_2_none():
	view_mode = 2;
	var p: Player = DataManager.players[current_playerNo];
	p.actorId = - 1;
	next_player_choose();
	
func view_mode_3():
	FlowManager.add_flow("go_to_scene|res://scene/scene_affiars/scene_affiars.tscn");


func next_player_choose():
	var next_playerNo = current_playerNo + 1;
	if (next_playerNo < DataManager.players.size()):
		current_playerNo = next_playerNo;
		FlowManager.add_flow("ask_next_player_choose");
		return ;
	FlowManager.add_flow("view_mode_3");
