# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/scene_title/scene_title.gd
# 说明：标题场景脚本。主菜单/标题界面逻辑。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const SCENE_ID = 0

onready var animationPlayer = get_node("AnimationPlayer");
onready var lsc_players_items = get_node("3/lsc_players_items");
onready var diffcult = get_node("3/diffcult");
onready var model = get_node("3/game_model");
onready var game_model2 = get_node("3/game_model2");
onready var diy_actor = $diy_actor_skill

var scene_view_mode = 0;

var cursor_select_index = 0;


var time_scale = 1.0


const DIFFICULTIES_INFO = [
	"简单上手的难度", 
	"AI 稍微活跃，其实还是很简单", 
	"AI 稍微活跃，其实还是很简单", 
	"AI 会稍微动动脑子，规则相对稳定", 
	"AI 规则的实验室，会不断调整和尝试", 
]

# 修改：AI Agent 接入（战争场景）
# 「大模型」是额外的难度选项，但不新增 diffculities 数值档位——
# 该值被大量规则数组按下标取值（内政/白兵战/单挑等），新增档位会越界。
# 因此复用「挑战」档(4)的规则参数，仅用 ai_agent_mode 标记把战争层决策换成远程 Agent。
const AI_AGENT_DIFFICULTY_NAME = "大模型"
const AI_AGENT_DIFFICULTY_LEVEL = 4
const AI_AGENT_DIFFICULTY_INFO = "由大模型指挥敌军（仅战争场景），需连接 Agent 服务；服务不可用时自动回退规则 AI"


func _ready() -> void :
	Global.change_speed(1.0, true)
	diy_actor.hide()
	
	var today = Global.get_datetime_now();
	if today.to_str("{1}{2}") == "0101":
		get_node("0/lblbwddl1").text = "元旦快乐!";
		get_node("3/lblbwddl").text = "元旦快乐!";
	
	if SceneManager.portrait_mode:
		diy_actor.reset_layout_portrait()
	else:
		diy_actor.reset_layout_landscape()
	
	SceneManager.set_virtukey_show(true)
	DataManager.unset_env("DIY")
	if DataManager.get_env_bool("DIY_Show"):
		diy_actor.init_show()
	DataManager.set_env("DIY_Show", false)
	SceneManager.load_scene_complete = true

	DataManager.players.clear()
	var player_nums = AutoLoad.other_players.size() + 1
	for i in player_nums:
		DataManager.players.append(Player.new())
	
	SceneManager.VirtualKey.show()
	lsc_players_items.visible = true
	diffcult.visible = false
	model.visible = false
	game_model2.visible = false

	if (Global.get_file_text("user://unify_times.txt") == ""):
		var lsc_diffcult_items = diffcult.get_node("lsc_diffcult_items")
		
		lsc_diffcult_items.items.erase("究极")
		lsc_diffcult_items.items.erase("挑战")
		# 修改：AI Agent 接入——「大模型」不参与解锁裁剪，新玩家也能选
		lsc_diffcult_items._set_data()
	
	get_node("3").visible = false;
	
	FlowManager.clear_bind_method();
	FlowManager.bind_signal_method("_show_select_item_1", self, "_show_select_item_1");
	FlowManager.bind_signal_method("_show_select_item_2", self, "_show_select_item_2");
	FlowManager.bind_signal_method("_show_select_item_3", self, "_show_select_item_3");
	FlowManager.bind_signal_method("_show_select_item_4", self, "_show_select_item_4");
	FlowManager.bind_signal_method("_show_select_item_5", self, "_show_select_item_5");
	
	var contact = DataManager.DEFAULT_CONTACT
	if DataManager.cloudVersion.has("contact"):
		contact = DataManager.cloudVersion["contact"]
	var msg = "玩家交流 [{0}]\n本游戏永久免费，禁止倒卖，违者必纠".format([contact]);
	
	get_node("2/lblMaker").text = msg
	get_node("3/lblMaker").text = msg
	return


func _process(delta: float) -> void :
	if (FlowManager.has_task()):
		return ;
	if (AutoLoad.playerNo == FlowManager.controlNo):
		_on_key_event(scene_view_mode);
	return


func _on_key_event(view_mode: int):
	if diy_actor.visible:
		
		SoundManager.play_bgm("res://resource/sounds/bgm/GameHappy_End.ogg", true)
		return
	if SoundManager.is_bgm_playing():
		
		SoundManager.play_bgm("", true)
	match view_mode:
		0:
			if Input.is_action_just_pressed("EMU_START"):
				scene_view_mode = - 1
				FlowManager.add_flow("_show_select_item_1")
				return
		1:
			var is_emu_b_pressed = Input.is_action_pressed("EMU_B");
			var is_emu_a_pressed = Input.is_action_pressed("EMU_A");
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
		
			if ( not is_emu_b_pressed):
				
				secret_clear();
			else:
				secret_check_full(analog_input_list, is_emu_b_pressed);
			if (Input.is_action_just_pressed("ANALOG_UP")):
				lsc_players_items.move_up();
			if (Input.is_action_just_pressed("ANALOG_DOWN")):
				lsc_players_items.move_down();
			if (Input.is_action_just_pressed("ANALOG_LEFT")):
				lsc_players_items.move_left();
			if (Input.is_action_just_pressed("ANALOG_RIGHT")):
				lsc_players_items.move_right();
			if (Input.is_action_just_pressed("EMU_START")):
				cursor_select_index = lsc_players_items.cursor_index;
				FlowManager.add_flow("_show_select_item_2");
				return
		2:
			if Global.is_action_pressed_BY():
				scene_view_mode = - 1
				FlowManager.add_flow("_show_select_item_1")
				return
			var lsc_diffcult_items = diffcult.get_node("lsc_diffcult_items");
			if Input.is_action_just_pressed("ANALOG_UP"):
				lsc_diffcult_items.move_up()
			if Input.is_action_just_pressed("ANALOG_DOWN"):
				lsc_diffcult_items.move_down()
			if Input.is_action_just_pressed("ANALOG_LEFT"):
				lsc_diffcult_items.move_left()
			if Input.is_action_just_pressed("ANALOG_RIGHT"):
				lsc_diffcult_items.move_right()
			var levelName = lsc_diffcult_items.items[lsc_diffcult_items.cursor_index]
			# 修改：AI Agent 接入——「大模型」复用挑战档(4)规则参数，只切换战争层决策器
			var is_ai_agent = levelName == AI_AGENT_DIFFICULTY_NAME
			var level = StaticManager.DIFFICULTY_NAMES.find(levelName)
			if is_ai_agent:
				level = AI_AGENT_DIFFICULTY_LEVEL
			level = max(0, level)
			if is_ai_agent:
				get_node("3/lblbwddl").text = AI_AGENT_DIFFICULTY_INFO
			else:
				get_node("3/lblbwddl").text = DIFFICULTIES_INFO[level]
			if Input.is_action_just_pressed("EMU_START"):
				cursor_select_index = lsc_diffcult_items.cursor_index
				DataManager.diffculities = level
				DataManager.ai_agent_mode = is_ai_agent
				
				
				
				DataManager.game_mode = 0;
				FlowManager.add_flow("_show_select_item_5");
		3:
			var lsc_model = model.get_node("lsc_model");
			if (Input.is_action_just_pressed("ANALOG_UP")):
				lsc_model.move_up();
			if (Input.is_action_just_pressed("ANALOG_DOWN")):
				lsc_model.move_down();
			if (Input.is_action_just_pressed("ANALOG_LEFT")):
				lsc_model.move_left();
			if (Input.is_action_just_pressed("ANALOG_RIGHT")):
				lsc_model.move_right();
			if (Input.is_action_just_pressed("EMU_START")):
				cursor_select_index = lsc_model.cursor_index;
				DataManager.game_mode = cursor_select_index;
				FlowManager.add_flow("_show_select_item_4");
		5:
			if Global.is_action_pressed_BY():
				scene_view_mode = - 1
				FlowManager.add_flow("_show_select_item_2")
				return
			var lsc_model = game_model2.get_node("lsc_model");
			if (Input.is_action_just_pressed("ANALOG_UP")):
				lsc_model.move_up();
			if (Input.is_action_just_pressed("ANALOG_DOWN")):
				lsc_model.move_down();
			if (Input.is_action_just_pressed("ANALOG_LEFT")):
				lsc_model.move_left();
			if (Input.is_action_just_pressed("ANALOG_RIGHT")):
				lsc_model.move_right();
			if not Input.is_action_just_pressed("EMU_START"):
				return
			
			cursor_select_index = lsc_model.cursor_index;
			DataManager.game_mode2 = cursor_select_index;
			
			match cursor_select_index:
				0:
					DataManager.unset_env("剧情.对白")
					DataManager.unset_env("剧情.类型")
					FlowManager.add_flow("_show_select_item_4");
				1:
					
					var istory = Global.load_script(DataManager.mod_path + "sgz_script/story/IStory.gd")
					if (istory.load_story(4, 1)):
						return ;
				2:
					DataManager.game_mode2 = 0;
					DataManager.common_variable.erase("剧情.对白");
					DataManager.common_variable.erase("剧情.类型");
					FlowManager.add_flow("go_to_scene|res://scene/scene_endless/scene_endless.tscn");
					return ;
				3:
					DataManager.game_mode2 = 0;
					DataManager.common_variable.erase("剧情.对白");
					DataManager.common_variable.erase("剧情.类型");
					FlowManager.add_flow("go_to_scene|res://scene/scene_demo/scene_demo_battle.tscn");
					return ;
	return


func _show_select_item_1():
	get_node("3/lblbwddl").text = "霸王的大陆吧"
	if (DataManager.players.size() == 1):
		lsc_players_items.items[0] = "单人游戏"
		lsc_players_items.items[1] = "多人游戏"
	else:
		lsc_players_items.items[0] = "多人游戏"
	lsc_players_items._set_data();
	scene_view_mode = 1;
	animationPlayer.stop(false);
	animationPlayer.play("p1");
	animationPlayer.seek(50, true);
	get_node("0").visible = false;
	get_node("1").visible = false;
	get_node("2").visible = false;
	get_node("3").visible = true;
	lsc_players_items.visible = true
	diffcult.visible = false
	model.visible = false
	game_model2.visible = false
	return


func _show_select_item_2():
	get_node("3/lblbwddl").text = "霸王的大陆吧"
	scene_view_mode = 2;
	
	match cursor_select_index:
		0:
			
			lsc_players_items.visible = false
			
			diffcult.visible = true
			model.visible = false
			game_model2.visible = false
		1:
			if not DataManager.is_test_player():
				
				scene_view_mode = 1;
				return ;
			if (get_tree().get_network_peer() != null):
				return ;
			FlowManager.add_flow("go_to_scene|res://scene/scene_net/scene_net_p2p.tscn");
		2:
			
			DataManager.set_env("DIY_Show", true)
			lsc_players_items.visible = false
			
			diffcult.visible = true
			model.visible = false
			game_model2.visible = false
			diy_actor.init_show()
	return


func _show_select_item_3():
	get_node("3/lblbwddl").text = "霸王的大陆吧"
	scene_view_mode = 3
	lsc_players_items.visible = false
	diffcult.visible = false
	model.visible = true
	game_model2.visible = false
	return


func _show_select_item_5():
	get_node("3/lblbwddl").text = "霸王的大陆吧"
	scene_view_mode = 5
	lsc_players_items.visible = false
	diffcult.visible = false
	model.visible = false
	game_model2.visible = true
	return

func _show_select_item_4():
	scene_view_mode = 4;
	diffcult.visible = false;
	game_model2.visible = false;
	
	match DataManager.game_mode:
		0:
			FlowManager.add_flow("go_to_scene|res://scene/scene_pick/scene_pickLord.tscn");
		1:
			FlowManager.add_flow("go_to_scene|res://scene/scene_pick/scene_pick.tscn");
	return


func _on_ding_finished() -> void :
	SoundManager.stop()
	SoundManager.play_bgm("", true)
	return

func _on_AnimationPlayer_animation_finished(anim_name: String) -> void :
	if (anim_name == "p0"):
		SoundManager.play_se2("res://resource/sounds/se/ding.ogg", 0, self, "_on_ding_finished")
		animationPlayer.play("p1");
		
		animationPlayer.seek(0.5, true);
	elif (anim_name == "p1"):
		animationPlayer.call_deferred("play", "p0");
	return




var secret_input: Dictionary = {
	secret_unify = 0, 
}

func secret_clear():
	if (secret_input.secret_unify < 8):
		secret_input.secret_unify = 0;
	

func secret_check_full(analog_input_list: Dictionary, b_pressed: bool):
	if (b_pressed):
		
		if (secret_input.secret_unify < 8):
			var secret_full = ["上", "下", "上", "下", "左", "右", "左", "右"];
			var index: int = secret_input.secret_unify;
			if (analog_input_list[secret_full[index]]):
				secret_input.secret_unify += 1;
				if (secret_input.secret_unify >= 8):
					SceneManager.over_animation.title_unify();
					secret_clear();
	else:
		secret_clear();

func reset_layout_portrait():
	rect_position = Vector2( - 128, 0)
	rect_scale = Vector2(1.25, 1.25)
	diy_actor.reset_layout_portrait()
	return

func reset_layout_landscape():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1, 1)
	diy_actor.reset_layout_landscape()
	return
