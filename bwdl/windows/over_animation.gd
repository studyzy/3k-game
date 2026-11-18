extends Control

onready var animaion_player = get_node("AnimationPlayer");
onready var lblmessage = get_node("lblmessage");
onready var actor_info_list = get_node("actor_info_list");
onready var thanks = get_node("thanks");

const UNIFY_DIALOGS = [
	"持续{持续年份}年的战乱\n终因英豪的出现而宣告终结", 
	"经历无数次战争\n{君主.姓名} 成为大陆之霸王", 
	"{年}年 {月}月\n{君主.姓名} 终于实现一统中原的梦想\n等级{君主.等级}  统一度{统一度}", 
	"成为大陆之霸王", 
]

func set_model_view(mv: int):
	DataManager.common_variable["结束画面-步骤"] = mv;
	
func get_model_view():
	if ( not DataManager.common_variable.has("结束画面-步骤")):
		return - 1;
	return int(DataManager.common_variable["结束画面-步骤"]);


func _ready() -> void :
	stop()
	return

func stop():
	hide();
	set_model_view( - 1);
	actor_info_list.hide();
	lblmessage.text = "";
	animaion_player.stop()
	return

func _unify_times():
	var times = 0;
	var times_str = Global.get_file_text("user://unify_times.txt");
	if times_str != "":
		times = int(times_str);
	times += 1;
	Global.save_file_text("user://unify_times.txt", str(times))
	return


func title_unify():
	_unify_times();
	load_pic();
	thanks.hide();
	get_node("lblmessage2").hide();
	set_model_view(0);
	actor_info_list.hide();
	show();
	var current_scene = SceneManager.current_scene();
	if (is_instance_valid(current_scene)):
		current_scene.queue_free();
	DataManager.year = 200;
	var actors = [];
	var unify_value = 100;
	var vstateId = 4;
	var vs = clVState.vstate(vstateId)
	var lord = ActorHelper.actor(vs.get_lord_id())
	lord.set_level(3)
	actors.append(lord.actorId)
	for actor in ActorHelper.all_officed_actors():
		if actor.actorId in actors:
			continue
		actors.append(actor.actorId)
	DataManager.common_variable["统一度"] = unify_value;
	DataManager.common_variable["势力"] = vstateId;
	DataManager.common_variable["武将"] = actors;
			
	_unify(1);
	SoundManager.play_bgm("res://resource/sounds/bgm/GameHappy_End.ogg");
	return

func play_unify(vstateId: int):
	DataManager.set_env("统一势力", vstateId)
	var vs = clVState.vstate(vstateId)
	SceneManager.show_vstate_dialog(vs.get_lord_name() + "已统一大陆")
	set_model_view(99)
	return

func play_unify_2(_vstateId: int):
	_unify_times();
	load_pic();
	thanks.hide();
	set_model_view(0);
	get_node("lblmessage2").hide();
	actor_info_list.hide();
	var current_scene = SceneManager.current_scene();
	if (is_instance_valid(current_scene)):
		current_scene.queue_free();
	show();
	var vstateId = _vstateId;
	var actors = [];
	var vs = clVState.vstate(vstateId)
	var lord = ActorHelper.actor(vs.get_lord_id())
	actors.append(lord.actorId)
	
	var unify_value = 0;
	
	var except_lord_actors_num = 0;
	
	var total_population_support = 0;
	
	var city_nums = 0;
	
	var except_lord_total_actors_loy = 0;
	for city in clCity.all_cities([vstateId]):
		city_nums += 1;
		total_population_support += city.get_loyalty()
		for actorId in city.get_actor_ids():
			if actorId in actors:
				continue;
			actors.append(actorId);
			if actorId != lord.actorId:
				except_lord_actors_num += 1;
				except_lord_total_actors_loy += ActorHelper.actor(actorId).get_loyalty()
	
	
	var a = except_lord_total_actors_loy / except_lord_actors_num;
	
	var b = total_population_support / city_nums;
	
	unify_value = int((a + except_lord_actors_num * 100 / 130 + b) / 3);
	DataManager.common_variable["统一度"] = unify_value;
	DataManager.common_variable["势力"] = vstateId;
	DataManager.common_variable["武将"] = actors;
	
	
	if (unify_value < 40):
		_unify(3);
	elif (unify_value < 70):
		_unify(2);
	else:
		_unify(1);
	SoundManager.play_bgm("res://resource/sounds/bgm/GameHappy_End.ogg");
	pass


func play_defeat(_vstateId: int):
	load_pic();
	var vstateId = _vstateId;
	animaion_player.play("player_defeat");
	DataManager.common_variable["势力"] = vstateId;
	SoundManager.play_bgm("res://resource/sounds/bgm/GameDead_End.ogg");
	show();
	

func _on_AnimationPlayer_animation_finished(anim_name: String) -> void :
	var actors = DataManager.common_variable["武将"];
	match anim_name:
		"unify1":
			_unify(2);
		"unify2":
			_unify(3);
		"unify3":
			
			var lordId = actors[0]
			actors.remove(0)
			actors.sort_custom(Global.actorComp, "by_power")
			actors.insert(0, lordId)
			actors.insert(0, - 2)
			actors.append( - 3)
			
			actor_info_list.actors = actors
			actor_info_list._init_actors(true, "")
			actor_info_list.show();
			set_model_view(1);
			get_node("thanks/vbox").rect_position.y = 192;
		"thanks":
			set_model_view(3);
	DataManager.common_variable["武将"] = actors;
	return

func load_pic():
	get_node("PlayerDefeat").texture = Global.load_pic("res://resource/images/animationPNG/player_defeat.png");
	get_node("unify1").texture = Global.load_pic("res://resource/images/animationPNG/unify1.png");
	get_node("unify2").texture = Global.load_pic("res://resource/images/animationPNG/unify2.png");
	get_node("unify3").texture = Global.load_pic("res://resource/images/animationPNG/unify3.png");
	

func formula_text(text: String) -> String:
	var init_year = StaticManager.get_starting_year(DataManager.drama_path)
	var vs = clVState.vstate(DataManager.common_variable["势力"])
	var lord = ActorHelper.actor(vs.get_lord_id())
	var unify_value = int(DataManager.common_variable["统一度"]);
	
	var though_years = DataManager.year - init_year;
	var dic_replace = {
		"持续年份": though_years, 
		"年": DataManager.year, 
		"月": DataManager.month, 
		"统一度": unify_value, 
		"君主.姓名": lord.get_name(), 
		"君主.字": lord.get_nick(), 
	}
	for pro in ActorHelper.ActorInfo.ATTR_DICT:
		var key = "君主." + pro
		if dic_replace.has(key):
			continue
		dic_replace[key] = lord._get_attr_int(pro)
	
	for key in dic_replace:
		text = text.replace("{" + str(key) + "}", str(dic_replace[key]));
	return text;

func _unify(no: int):
	get_node("lblmessage2").text = UNIFY_DIALOGS[3];
	match no:
		1:
			lblmessage.text = formula_text(UNIFY_DIALOGS[0]);
			animaion_player.play("unify1");
		2:
			animaion_player.play("unify2");
			lblmessage.text = formula_text(UNIFY_DIALOGS[1]);
		3:
			animaion_player.play("unify3");
			lblmessage.text = formula_text(UNIFY_DIALOGS[2]);
	

var delay_times = 0;
func _process(delta: float) -> void :
	var model_view = get_model_view();
	match model_view:
		1:
			delay_times += delta;
			if (delay_times < 3):
				return ;
			delay_times = 0;

			if not actor_info_list.next_actor(false):
				
				var lblmaker = get_node("thanks/vbox/1/Label");
				var maker = str(DataManager.mod["作者"]);
				lblmaker.text = "" + str(maker) + "\n";
				animaion_player.play("thanks");
				thanks.show();
				set_model_view(2);
		3:
			if (Input.is_action_just_pressed("EMU_START")):
				stop();
				SceneManager.restart();
		99:
			if not Input.is_action_just_pressed("EMU_A"):
				return
			set_model_view( - 1)
			var vstateId = DataManager.get_env_int("统一势力")
			play_unify_2(vstateId)
	return
