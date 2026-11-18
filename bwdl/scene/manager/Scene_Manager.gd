# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/manager/Scene_Manager.gd
# 说明：场景管理器（自动加载）。负责场景切换、加载进度、运行时 UI 更新。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

onready var aboveAll = $aboveAll
onready var confirmation = $system_layer / confirmation
onready var notice = $system_layer / notice

onready var cheaterScene = preload("res://cheat/cheater.tscn")
onready var infoScene = preload("res://info/info.tscn")
onready var black = get_node("Virtukey/black");
onready var war_intro = get_node("Virtukey/WarIntro");

const word_unittime = 0.05

onready var bottom = get_node("tool_layer/bottom")
onready var Quit = get_node("Virtukey/Quit");
onready var scene_layer = get_node("scene_layer");
onready var dialog = get_node("set_menu_layer/dialog");
onready var VirtualKey = get_node("Virtukey/VirtualKey");
onready var actor_dialog = get_node("tool_layer/actor_dialog");
onready var solo_dialog = get_node("tool_layer/solo_dialog");
onready var actor_info = get_node("tool_layer/actor_info");
onready var actorlist = get_node("tool_layer/actorlist");
onready var lsc_menu = get_node("tool_layer/lsc_menu");
onready var lsc_menu_top = get_node("tool_layer/lsc_menu_top");
onready var image_menu = get_node("tool_layer/image_menu");
onready var cityInfo = get_node("tool_layer/cityinfo");
onready var input_numbers = get_node("tool_layer/input_numbers");
onready var actor_addpoint = get_node("tool_layer/actor_addpoint");

onready var con_affiars_animations = get_node("tool_layer/con_affiars_animations");
onready var con_war_animations = get_node("tool_layer/con_war_animations");
onready var over_animation = get_node("set_menu_layer/over_animation");
onready var conEquipInfo = get_node("tool_layer/conEquipInfo");

onready var affairs_menu = preload("res://windows/affiars_bottom/affiars_menu.tscn")

onready var tips = get_node("tool_layer/lblTips")

onready var lblSystem = get_node("Virtukey/VirtualKey/lblspeed")


var popuped: bool = false

var cityId: int = - 1

const scene_name = "current-scene"
var load_scene_complete = true

var next_scene_path: String = ""
var current_scene_path: String = ""


var cursor_speed = 18

var public_detla = 0

var lastCtrl = 0
var lastTipsTime = - 1

var portrait_mode_enabled = false
var portrait_mode = false
var reverse_mode = false

var skip_tips: bool = false


var is_test_running = false

func _init():
	portrait_mode_enabled = false
	if DataManager.is_developer() or OS.has_feature("Android"):
		portrait_mode_enabled = true
	portrait_mode = false
	var hkSetting = StaticManager.get_hide_key_setting()
	if "光标速度" in hkSetting:
		cursor_speed = Global.intval(hkSetting["光标速度"], 18)
	return


func _ready() -> void :
	if DataManager.is_developer_at_work():
		get_node("aboveAll/grayscale").show()
	else:
		get_node("aboveAll/grayscale").hide()
	var lblmessage = get_node("Virtukey/lblmessage");
	lblmessage.hide();
	black.hide();
	dialog.hide();
	hide_all_tool();
	reset_labels()
	confirmation.hide()
	notice.hide()
	return

func switch_layout():
	if not portrait_mode_enabled:
		return
	set_process(false)
	if portrait_mode:
		portrait_mode = false
		reset_layout_landscape(true)
	else:
		portrait_mode = true
		reset_layout_portrait()
	Global.save_user_preference()
	set_process(true)
	return

func reset_labels():
	VirtualKey.reset_labels()
	return

func clear_stage():
	reset_labels()
	SceneManager.over_animation.stop();
	rpc_clear_stge();
	SceneManager.hide_all_tool();
	if (AutoLoad.check_is_multigame()):
		rpc("rpc_clear_stge")

remote func rpc_clear_stge():
	Global.clearNode(scene_layer);

func go_to_scene(path: String):
	load_scene_complete = false
	Global.clearNode(scene_layer)
	clear_bottom()
	next_scene_path = path
	call_deferred("_defered_go_to_scene", path)
	return

func update_playerNo():
	var lblPlayerNo: Label = get_node("Virtukey/VirtualKey/lblPlayerNo");
	lblPlayerNo.text = str(AutoLoad.playerNo + 1) + "P";
	lblPlayerNo.show();


func _is_menu_scene(path: String) -> bool:
	# 菜单/标题/剧本选择这类场景不依赖资源包，不用挡
	for key in ["scene_open", "scene_title", "scene_pick", "scene_net", "scene_set", "scene_mod", "scene_demo"]:
		if path.find(key) >= 0:
			return true
	return false


func _defered_go_to_scene(path: String):
	Global.clearNode(scene_layer);
	# 网页版渐进加载：战斗/战争大图还没下载完时，先挡在这里（菜单场景不受影响）
	if WebAssets != null and not WebAssets.is_ready() and not _is_menu_scene(path):
		WebAssets.show_waiting_overlay()
		while not WebAssets.is_ready():
			yield(WebAssets, "assets_ready")
		WebAssets.hide_waiting_overlay()
	
	var scene_node: Node = load(next_scene_path).instance();
	scene_node.name = scene_name;
	scene_node.set_process(false);
	scene_layer.add_child(scene_node);
	current_scene_path = path;
	if portrait_mode:
		if scene_node.has_method("reset_layout_portrait"):
			scene_node.reset_layout_portrait()
	else:
		if scene_node.has_method("reset_layout_landscape"):
			scene_node.reset_layout_landscape()
	return

func current_scene():
	if scene_layer == null:
		return null
	return scene_layer.get_node_or_null(scene_name)


func get_scene_nameCN(sceneNameEN: String = ""):
	if (sceneNameEN == ""):
		sceneNameEN = current_scene_path;
	sceneNameEN = sceneNameEN.to_lower();
	if ("scene_affiars" in sceneNameEN):
		return "内政";
	if ("scene_war" in sceneNameEN):
		return "大战场";
	if ("scene_battle" in sceneNameEN):
		return "小战场";
	if ("scene_solo" in sceneNameEN):
		return "单挑";
	return "";


func restart():
	FlowManager.force_change_controlNo(0);
	_restart();
	if (AutoLoad.check_is_multigame()):
		rpc("_restart");
	return

remote func _restart():
	Global.reset()
	LoadControl.end_script()
	SoundManager.reset()
	SceneManager.clear_stage()
	FlowManager.clear()
	LoadControl.end_script()
	FlowManager.add_flow("go_to_scene|res://scene/scene_open/scene_open.tscn")
	return

func restart_challange_game() -> void :
	Global.reset()
	LoadControl.end_script()
	SoundManager.reset()
	SceneManager.clear_stage()
	FlowManager.clear()
	LoadControl.end_script()
	FlowManager.add_flow("go_to_scene|res://scene/scene_challange/scene_challange.tscn")
	return

func pause(b: bool):
	if (AutoLoad.check_is_multigame()):
		
		if ( not get_tree().is_network_server()):
			return ;
		else:
			rpc("_pause", b)
	_pause(b)
	return

var lblmessage_show_time: float = 0;
remote func _pause(b: bool):
	var lblmessage = get_node("Virtukey/lblmessage");
	if (b):
		if (AutoLoad.get_local_id() != 1):
			lblmessage.text = "1P暂停中";
		else:
			lblmessage.text = "暂停中";
	lblmessage.visible = b;
	get_tree().paused = b;
	SoundManager.pause(b);
	return



func show_input_numbers(speak: String, name_array: PoolStringArray, max_array: PoolIntArray = [0, 0, 0, 0], min_position: PoolIntArray = [0, 0, 0, 0], max_position = [4, 4, 4, 4]):
	hide_all_tool()
	input_numbers.init_data(name_array, max_array, min_position, max_position)
	input_numbers.speak(speak)
	input_numbers.show()
	return

func show_solo_dialog(msg: String, actorId: int, mood: int):
	hide_all_tool();
	solo_dialog.load_dialog(msg, actorId, mood);
	solo_dialog.show();


func show_confirm_dialog(msg: String, actorId: int = - 1, mood: int = 2, show_avatar_anyway: bool = false):
	hide_all_tool();
	actor_dialog.load_confirm_dialog(msg, actorId, mood, show_avatar_anyway);
	actor_dialog.show();


func show_confirm_dialogs(msg: PoolStringArray, actorId: int = - 1, mood: int = 2):
	hide_all_tool();
	actor_dialog.load_confirm_dialogs(Array(msg), actorId, mood);
	actor_dialog.show();

func show_yn_dialog(msg: String, actorId: int = - 1, mood: int = 2, options: PoolStringArray = ["是", "否"]):
	hide_all_tool();
	actor_dialog.load_confirm_yn(msg, actorId, mood, options);
	actor_dialog.show();
	return


func show_unconfirm_dialog(msg: String, actorId: int = - 1, mood: int = 2):
	hide_all_tool();
	actor_dialog.load_unconfirm_dialog(msg, actorId, mood);
	actor_dialog.show();

func show_vstate_dialog(msg: String = ""):
	actor_dialog.load_affiars_vstateshow(msg);
	dialog_msg_complete(true);
	actor_dialog.show();


func dialog_msg_complete(need_complete: bool = false) -> bool:
	var d = actor_dialog;
	if (solo_dialog.visible):
		d = solo_dialog;
	
	var result: bool = d.is_msg_complete();
	if (need_complete):
		d.show_all_msg();
	return result;



func hide_all_tool():
	show_cityInfo(false);
	actor_dialog.load_unconfirm_dialog("");
	for child in get_node("tool_layer").get_children():
		if child.name == "lblTips":
			continue
		child.hide();



func wait(sec: float, flow: String) -> Timer:
	var node_name = str(OS.get_ticks_msec());
	var timer = Timer.new();
	timer.one_shot = true;
	timer.name = node_name;
	timer.connect("timeout", self, "_on_wait_to", [timer, flow]);
	get_node("conTime").add_child(timer);
	timer.wait_time = sec;
	timer.start();
	return timer;

func _on_wait_to(timer: Timer, next_flow: String):
	timer.queue_free();
	FlowManager.flows_history_list.clear();
	if (FlowManager.controlNo == AutoLoad.playerNo):
		FlowManager.add_flow(next_flow);



func dialog_use_orderbook_animation(flow: String, use_orderbooks: int = 1):
	DataManager.orderbook -= use_orderbooks;
	if (DataManager.orderbook < 0):
		DataManager.orderbook = 0;

	actor_dialog.conOrderbook.order_book_play(flow);
	return


func _animation_skipping_allowed() -> bool:
	
	
	
	
	
	
	var lastFlow: String = ""
	if not FlowManager.flows_history_list.empty():
		lastFlow = FlowManager.flows_history_list[FlowManager.flows_history_list.size() - 1]
	if lastFlow.find("play_affiars_animation") == 0:
		var animeName = lastFlow.split("|")[1]
		if animeName == "AI_Attack" or animeName == "Town_Save":
			return false
	return true

func _on_animation_timer_timeout() -> void :
	if not is_animation_playing():
		return
	if not Global.is_action_pressed_AX():
		return
	if not _animation_skipping_allowed():
		return
	if SoundManager.is_se_playing():
		SoundManager.stop();
	_on_affiars_animation_finish();
	return


func is_animation_playing() -> bool:
	if (con_affiars_animations.visible or con_war_animations.visible):
		return true
	return false


func play_affiars_animation(
	ani_name: String, next_flow: String, bgm_auto_play: bool = true, 
	withMessage: String = "", withSpeaker: int = - 1, withMood: int = 2, 
	change_obj = null, change_method: String = ""):
	if ani_name == "":
		return
	FlowManager.flows_history_list = [
		"play_affiars_animation|{0}|{1}|{2}|{3}|{4}|{5}".format([
			ani_name, next_flow, bgm_auto_play, 
			withMessage, withSpeaker, withMood, 
		])
	];
	_next_flow = next_flow;
	if withMessage != "":
		if withSpeaker >= 0 or withSpeaker == StaticManager.ACTOR_ID_SLIME_GOD:
			show_confirm_dialog(withMessage, withSpeaker, withMood)
		else:
			show_vstate_dialog(withMessage)
	show_cityInfo(false)
	con_affiars_animations.show();
	Global.clearNode(con_affiars_animations);
	var animation_json = StaticManager.animations[ani_name];
	
	var asp: AnimatedSprite = AnimatedSprite.new();
	asp.connect("frame_changed", self, "affiars_animation_frame_changed", [asp, change_obj, change_method]);
	var frames: SpriteFrames = SpriteFrames.new();
	asp.frames = frames;
	frames.add_animation("animation");
	frames.set_animation_loop("animation", animation_json["loops"]);
	frames.set_animation_speed("animation", 3);
	asp.animation = "animation";

	update_cityinfo_position()

	var datas = StaticManager.get_animation_data(animation_json)
	var texture = StaticManager.load_animation_texture(animation_json)
	var json_res_array = datas["res"];
	for json_frames in datas["frames"]:
		var json_res = json_res_array[str(json_frames["res"])];
		var at: AtlasTexture = AtlasTexture.new();
		at.atlas = texture;
		var position = Vector2(int(json_res["x"]), int(json_res["y"]));
		var size = Vector2(int(json_res["w"]), int(json_res["h"]));
		
		var region = Rect2(position, size);
		animation_json["width"] = con_affiars_animations.rect_size.x;
		animation_json["height"] = con_affiars_animations.rect_size.y;
		
		at.region = region;
		asp.global_position = Vector2(animation_json["width"] / 2, animation_json["height"] / 2);
		asp.scale = Vector2(animation_json["width"] / region.size.x, animation_json["height"] / region.size.y);
		asp.frames.add_frame("animation", at);
	asp.frame = 0;
	con_affiars_animations.add_child(asp);
	asp.connect("animation_finished", self, "_on_affiars_animation_finish")
	asp.play();
	_bgm_auto_play = bgm_auto_play;
	var se_bgm = str(animation_json["se"]);
	if (se_bgm != ""):
		SoundManager.play_anim_bgm("res://resource/sounds/se/" + se_bgm);
	$animation_timer.start();
	return
	

func play_war_animation(
	ani_name: String, target_actorId: int, next_flow: String, 
	withMessage: String = "", withSpeaker: int = - 1, withMood: int = 2):
	_next_flow = next_flow;
	if (ani_name == ""):
		_bgm_auto_play = false;
		_on_war_animation_finish();
		return ;
	FlowManager.flows_history_list = [
		"play_war_animation|{0}|{1}|{2}|{3}|{4}|{5}".format([
			ani_name, target_actorId, next_flow, 
			withMessage, withSpeaker, withMood
		])
	];
	if withMessage != "":
		show_confirm_dialog(withMessage, withSpeaker, withMood)
	var node_info: Control = con_war_animations.get_node("info");
	if (target_actorId != - 1):
		var target_actor = ActorHelper.actor(target_actorId);
		node_info.get_node("lblName").text = target_actor.get_name()
		node_info.get_node("HP/lblValue").text = str(ceil(target_actor.get_hp()));
		node_info.get_node("INT/lblValue").text = str(target_actor.get_wisdom());
		if target_actor.get_loyalty() == 100:
			node_info.get_node("LOY/Loy100").visible = true;
			node_info.get_node("LOY/lblValue").visible = false;
		else:
			node_info.get_node("LOY/Loy100").visible = false;
			node_info.get_node("LOY/lblValue").visible = true;
			node_info.get_node("LOY/lblValue").text = str(target_actor.get_loyalty());
		node_info.get_node("Sodiers/lblValue").text = str(target_actor.get_soldiers());
	else:
		node_info.get_node("LOY/Loy100").visible = false;
		node_info.get_node("LOY/lblValue").visible = true;
		node_info.get_node("lblName").text = "?";
		node_info.get_node("HP/lblValue").text = "?";
		node_info.get_node("INT/lblValue").text = "?";
		node_info.get_node("LOY/lblValue").text = "?";
		node_info.get_node("Sodiers/lblValue").text = "?";
		
	con_war_animations.show();
	var con_conmation = con_war_animations.get_node("con_conmation");
	Global.clearNode(con_conmation);
	
	var animation_json = StaticManager.animations[ani_name];
	
	var asp: AnimatedSprite = AnimatedSprite.new();
	
	var frames: SpriteFrames = SpriteFrames.new();
	asp.frames = frames;
	frames.add_animation("animation");
	frames.set_animation_loop("animation", animation_json["loops"]);
	frames.set_animation_speed("animation", 3);
	asp.animation = "animation";
	
	var datas = StaticManager.get_animation_data(animation_json)
	var texture = StaticManager.load_animation_texture(animation_json)
	var json_res_array = datas["res"];
	for json_frames in datas["frames"]:
		var json_res = json_res_array[str(json_frames["res"])];
		var at: AtlasTexture = AtlasTexture.new();
		at.atlas = texture;
		var position = Vector2(int(json_res["x"]), int(json_res["y"]));
		var size = Vector2(int(json_res["w"]), int(json_res["h"]));
		
		var region = Rect2(position, size);
		animation_json["width"] = con_conmation.rect_size.x;
		animation_json["height"] = con_conmation.rect_size.y;
		
		at.region = region;
		asp.global_position = Vector2(animation_json["width"] / 2, animation_json["height"] / 2);
		asp.scale = Vector2(animation_json["width"] / region.size.x, animation_json["height"] / region.size.y);
		asp.frames.add_frame("animation", at);
	asp.frame = 0;
	con_conmation.add_child(asp);
	asp.connect("animation_finished", self, "_on_war_animation_finish")
	asp.play();
	_bgm_auto_play = true;

	var se_bgm = str(animation_json["se"]);
	if (se_bgm != ""):
		SoundManager.play_anim_bgm("res://resource/sounds/se/" + se_bgm);
	$animation_timer.start();
	return

func affiars_animation_frame_changed(asp: AnimatedSprite, change_obj, change_method: String):
	if ( not con_affiars_animations.visible):
		return ;
	if (is_instance_valid(change_obj)):
		change_obj.call(change_method, asp.frame);
	return

var _bgm_auto_play: bool = true;
var _next_flow = "";

func _on_affiars_animation_finish():
	if _next_flow == "":
		return
	if SoundManager.is_se_playing():
		SoundManager.stop()
	if "scene_affiars.tscn" in current_scene_path:
		SceneManager.show_cityInfo(DataManager.show_orderbook)
	con_affiars_animations.hide()
	if _bgm_auto_play:
		SoundManager.play_bgm()
	con_affiars_animations.hide()
	FlowManager.flows_history_list.clear()
	FlowManager.add_flow(_next_flow)
	_next_flow = ""
	return

func _on_war_animation_finish():
	if _next_flow == "":
		
		return
	if (_bgm_auto_play):
		SoundManager.stop()
		SoundManager.play_bgm();
	var con_conmation = con_war_animations.get_node("con_conmation");
	Global.clearNode(con_conmation);
	con_war_animations.hide();
	FlowManager.flows_history_list.clear();
	if (FlowManager.controlNo == AutoLoad.playerNo):
		FlowManager.add_flow(_next_flow);
	_next_flow = "";
	return


func show_cityInfo(b: bool, _cityId: int = - 1, cityInfoType: int = - 1):
	cityId = _cityId
	if cityId == - 1:
		cityId = DataManager.player_choose_city
		if cityId == - 1:
			b = false
	cityInfo.visible = b
	if not cityInfo.visible:
		return
	
	if cityInfoType >= 0:
		DataManager.cityInfo_type = cityInfoType
	
	cityInfo.get_node("0").visible = DataManager.cityInfo_type == 0;
	cityInfo.get_node("1").visible = DataManager.cityInfo_type == 1;
	cityInfo.get_node("2").visible = DataManager.cityInfo_type == 2;
	cityInfo.get_node("3").visible = DataManager.cityInfo_type == 3;
	update_cityinfo_position()
	var city = clCity.city(cityId)
	if city.is_delegated():
		cityInfo.get_node("0/CityName/delegated").show()
	else:
		cityInfo.get_node("0/CityName/delegated").hide()
	
	var lord = ActorHelper.actor(city.get_lord_id())
	var unoffices = clCity.get_unoffice_actors(int(cityId));
	var unoffice_num = unoffices.size();
	cityInfo.get_node("0/Bob").visible = unoffice_num > 0;
	cityInfo.get_node("0/Bob").text = "在野:{0}人".format([unoffice_num]);
	
	cityInfo.get_node("0/CityName").text = city.get_name()
	if city.get_vstate_id() != - 1 and city.get_actors_count() > 0:
		var vs = clVState.vstate(city.get_vstate_id())
		var title = vs.get_dynasty_title()
		if title == "":
			cityInfo.get_node("0/LordLabel").text = "君主"
			cityInfo.get_node("0/LordName").text = vs.get_lord_name()
		else:
			cityInfo.get_node("0/LordLabel").text = "国号"
			cityInfo.get_node("0/LordName").text = title
		var satrap = ActorHelper.actor(city.get_actor_ids()[0])
		cityInfo.get_node("0/SatrapName").text = satrap.get_name();
	else:
		cityInfo.get_node("0/LordName").text = "";
		cityInfo.get_node("0/SatrapName").text = "";
	cityInfo.get_node("0/Dominance").text = str(city.get_loyalty())
	
	
	cityInfo.get_node("1/Money").text = str(city.get_gold())
	cityInfo.get_node("1/Rice").text = str(city.get_rice());
	cityInfo.get_node("1/Farm").text = str(city.get_land());
	cityInfo.get_node("1/Bussiness").text = str(city.get_eco());
	cityInfo.get_node("1/Population").text = str(city.get_pop());
	cityInfo.get_node("1/Defence").text = str(city.get_defence());
	cityInfo.get_node("1/Actors").text = str(city.get_actors_count());
	var total_sodiers = 0;
	for actorId in city.get_actor_ids():
		var actor = ActorHelper.actor(actorId);
		total_sodiers += actor.get_soldiers();
	cityInfo.get_node("1/Sodiers").text = str(total_sodiers)
	
	cityInfo.get_node("2/Money").text = str(city.get_gold())
	cityInfo.get_node("2/Rice").text = str(city.get_rice())
	cityInfo.get_node("2/Population").text = str(city.get_pop())
	cityInfo.get_node("2/Actors").text = str(city.get_actors_count())
	cityInfo.get_node("2/Sodiers").text = str(total_sodiers)
	cityInfo.get_node("2/BackupSodiers").text = str(city.get_backup_soldiers())
	
	cityInfo.get_node("3/Money").text = str(city.get_gold())
	cityInfo.get_node("3/Rice").text = str(city.get_rice())
	cityInfo.get_node("3/Treasure").text = str(city.get_treasures())
	cityInfo.get_node("3/Sodiers").text = str(city.get_backup_soldiers())
	return






func show_simply_actor_info(actorId: int, msg: String = "", hideSkillButton: bool = false) -> void :
	actor_info.actors = [actorId]
	if msg == "":
		actor_info._init_actors(false, "", false, hideSkillButton)
	else:
		actor_info._init_actors(true, msg, false, hideSkillButton)
	actor_info.show()
	return


func show_actor_info(actorId: int, update_msg: bool = true, msg: String = ""):
	show_actor_info_list([actorId], update_msg, msg);


func show_actor_info_list(actors: Array, update_msg: bool = true, msg: String = "", switchMode: bool = true) -> bool:
	if actors.empty():
		return false
	hide_all_tool()
	actor_info.actors = actors.duplicate()
	actor_info._init_actors(update_msg, msg, switchMode);
	actor_info.show()
	return true


func show_actorlist_develop(actorId_list: Array, need_end_button: bool, text: String):
	hide_all_tool();
	actorlist.set_actors(actorId_list, need_end_button, text, false, ["体", "武", "政", "忠", "德", "经验"]);
	actorlist.show();
	return


func show_actorlist_army(actorId_list: Array, need_end_button: bool, text: String, change_sodiers: bool):
	hide_all_tool();
	actorlist.set_actors(actorId_list, need_end_button, text, change_sodiers, ["体", "武", "知", "忠", "统", "兵力"]);
	actorlist.show();
	return


func show_actorlist_equip(actorId_list: Array, need_end_button: bool, text: String, equip: clEquip.EquipInfo):
	hide_all_tool();
	var attrs = ["体", "武", "知", "统", "", equip.type]
	match equip.type:
		"武器":
			pass
		"防具":
			if equip.id == StaticManager.SUIT_ID_SHENGZHE:
				attrs = ["体", "武", "知", "德", "", equip.type]
		"道具":
			pass
		"坐骑":
			pass
	actorlist.set_actors(actorId_list, need_end_button, text, false, attrs)
	actorlist.show();
	return


func show_actorlist_learning(actorId_list: Array, need_end_button: bool, text: String):
	hide_all_tool();
	actorlist.set_actors(actorId_list, need_end_button, text, false, ["武", "知", "统", "政", "等级", "经验"]);
	actorlist.show();
	return


func show_actorlist(actorIdList: Array, needEndButton: bool, text: String, changeSoldiers: bool, properties: PoolStringArray):
	hide_all_tool()
	actorlist.set_actors(actorIdList, needEndButton, text, changeSoldiers, properties)
	actorlist.show()
	return

func show_affairs_menu(operation: bool = true):
	hide_all_tool()
	Global.clearNode(bottom)
	var menu = affairs_menu.instance()
	menu.name = "bottom_scene"
	bottom.add_child(menu)
	menu.init_data(operation)
	if portrait_mode:
		menu.reset_layout_portrait()
	bottom.show()
	return

func change_bottom(bottom_path: String):
	call_deferred("_defered_change_bottom", bottom_path)
	return

func _defered_change_bottom(bottom_path: String):
	var packed_scene: PackedScene = load(bottom_path);
	if (packed_scene == null):
		return ;
	hide_all_tool();
	Global.clearNode(bottom);
	var ps_instance = packed_scene.instance();
	ps_instance.name = "bottom_scene";
	bottom.add_child(ps_instance);
	if portrait_mode and ps_instance.has_method("reset_layout_portrait"):
		ps_instance.reset_layout_portrait()
	bottom.show()
	return

func change_bottom_byNode(bottom_node: Node):
	call_deferred("_defered_change_bottom_Node", bottom_node)
	return

func _defered_change_bottom_Node(ps_instance: Node):
	hide_all_tool()
	Global.clearNode(bottom)
	ps_instance.name = "bottom_scene"
	bottom.add_child(ps_instance)
	bottom.show()
	return

func clear_bottom():
	Global.clearNode(bottom)
	return

func get_bottom() -> Node:
	return bottom.get_node_or_null("bottom_scene")

func _process(delta: float) -> void :
	if process_popuped():
		return

	if Input.is_action_just_pressed("EMU_LAYOUT"):
		switch_layout()
		return
	_process_tips(delta)
	public_detla = delta
	return


func save_current_scene(no: int) -> String:
	var path = _rpc_save_current_scene(no);
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_save_current_scene", no);
	return path;

remote func _rpc_save_current_scene(no: int) -> String:
	var packed_scene = PackedScene.new();
	packed_scene.pack(current_scene());
	var save_path = "user://save_scene/";
	var dir: = Directory.new();
	if ( not dir.dir_exists(save_path)):
		dir.make_dir_recursive(save_path);
	var scene_file_name = "{0}.tscn".format([no]);
	ResourceSaver.save(save_path + scene_file_name, packed_scene);
	return save_path + scene_file_name;
	

func _on_skill_timer_timeout() -> void :
	if FlowManager.has_task():
		return

	
	var st_info = SkillHelper.get_current_skill_trigger()
	if st_info == null:
		return

	if st_info.wait:
		var paths = DataManager.get_env_array("自定义步骤路径")
		if not paths.empty():
			
			
			
			return
		st_info.wait = false
	if not st_info.induce_effects.empty():
		st_info.wait = true
		LoadControl.end_script()
		var induce_effects = Array(st_info.induce_effects)
		LoadControl.load_script("res://resource/sgz_script/war/player_skill_induce.gd")
		FlowManager.add_flow("induce_start")
		return
	if not st_info.lock_effects.empty():
		var lock_effects = Array(st_info.lock_effects)
		LoadControl.end_script()
		st_info.wait = true
		var dic = lock_effects.pop_front()
		var skillName = str(dic["skill_name"])
		var skillActorId = int(dic["skill_actor"])
		var effectId = int(dic["effect_id"])
		var skill = StaticManager.get_skill(skillName)
		var effect = skill.get_effect(effectId)

		var gd = Global.load_script(effect.path)
		var effectMethod = "effect_{0}_start".format([effect.id])
		if DataManager.get_scene_actor_control(skillActorId) < 0:
			effectMethod = "effect_{0}_AI_start".format([effect.id])
		if gd.has_method(effectMethod):
			var ske = effect.create_ske_for(skillActorId)
			ske.actorId = int(dic["current_actor"])
			SkillHelper.save_skill_effectinfo(ske)
			DataManager.player_choose_skill = ske.skill_name;
			SceneManager.hide_all_tool()
			LoadControl.load_script(effect.path)
			FlowManager.add_flow(effectMethod)
		else:
			st_info.wait = false
			LoadControl.end_script()
		return

	LoadControl.end_script();
	if ( not st_info.temp_code_gd.empty()):
		DataManager.set_env("自定义步骤路径", st_info.temp_code_gd.duplicate())
		LoadControl.create();
	if (st_info.next_flow != ""):
		FlowManager.add_flow(st_info.next_flow)
	SkillHelper.remove_current_skill_trigger()
	return

func show_special_tips(msg: String, offset: int = 0) -> void :
	tips.text = msg
	tips.show()
	if portrait_mode:
		tips.rect_position.y = 608 + offset
	else:
		tips.rect_position.y = 380 + offset
	return

func reset_tips() -> void :
	tips.text = ""
	tips.hide()
	if portrait_mode:
		tips.rect_position.y = 608
	else:
		tips.rect_position.y = 380
	return

func _process_tips(delta: float):
	if DataManager.get_current_scene_id() != 10000:
		tips.hide()
		return
	if skip_tips:
		tips.hide()
		return
	if actorlist.visible:
		tips.hide()
		return
	if lsc_menu_top.visible:
		tips.hide()
		return
	var ctrlNo = DataManager.control_sort_no
	if ctrlNo < 0 or ctrlNo >= DataManager.control_sort.size():
		return
	var ctrl = DataManager.control_sort[ctrlNo]
	if ctrl == lastCtrl and ctrl >= 0:
		return

	lastCtrl = ctrl
	if ctrl < 0:
		var tm = Time.get_ticks_msec()
		if tm - lastTipsTime > 4000:
			tips.text = StaticManager.random_tips()
			lastTipsTime = tm
		if not tips.visible:
			tips.show()
	else:
		if tips.visible:
			tips.hide()
	return

func set_virtukey_show(b: bool):
	get_node("Virtukey").visible = b;

func update_cityinfo_position():
	var leftSide = false
	if cityId == - 1:
		leftSide = true
	else:
		var city = clCity.city(cityId)
		leftSide = city.at_left_part()
	
	if portrait_mode:
		cityInfo.rect_scale = Vector2(1.70666, 1.6)
		con_affiars_animations.rect_scale = Vector2(1.70666, 1.6)
		if leftSide:
			cityInfo.rect_position = Vector2(512, 138)
			con_affiars_animations.rect_position = Vector2(523, 143)
		else:
			cityInfo.rect_position = Vector2(56, 138)
			con_affiars_animations.rect_position = Vector2(68, 143)
	else:
		cityInfo.rect_scale = Vector2(1, 1)
		con_affiars_animations.rect_scale = Vector2(1, 1)
		if leftSide:
			cityInfo.rect_position = Vector2(512, 86)
			con_affiars_animations.rect_position = Vector2(513, 103)
		else:
			cityInfo.rect_position = Vector2(244, 86)
			con_affiars_animations.rect_position = Vector2(245, 103)
	return


func cleanup_animations() -> void :
	_next_flow = ""
	return

func reset_layout_landscape(toggle: bool = false) -> void :
	if toggle:
		reverse_mode = not reverse_mode
	var orientation = OS.SCREEN_ORIENTATION_LANDSCAPE
	if reverse_mode:
		orientation = OS.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
	OS.set_screen_orientation(orientation)
	var vp = get_viewport()
	vp.size = Vector2(1024, 600)
	for scene_node in scene_layer.get_children():
		if scene_node.has_method("reset_layout_landscape"):
			scene_node.reset_layout_landscape()
	for node in [bottom, actor_dialog, lsc_menu, image_menu, input_numbers, solo_dialog]:
		node.rect_position = Vector2(212, 410)
		node.rect_scale = Vector2(1, 1)
	for node in [lsc_menu_top, actorlist, actor_addpoint]:
		node.rect_position = Vector2(212, 0)
		node.rect_scale = Vector2(1, 1)
	tips.rect_scale = Vector2(1, 1)
	tips.rect_position = Vector2(212, 380)
	update_cityinfo_position()
	con_war_animations.rect_scale = Vector2(1, 1)
	con_war_animations.rect_position = Vector2(212, 75)
	over_animation.rect_scale = Vector2(1, 1)
	over_animation.rect_position = Vector2(212, 0)
	actor_info.reset_layout_landscape()
	VirtualKey.reset_layout_landscape()
	black.rect_size = Vector2(1024, 600)
	black.rect_position = Vector2(0, 0)
	black.rect_scale = Vector2(1, 1)
	conEquipInfo.reset_layout_landscape()
	Quit.reset_layout_landscape()
	if SoundManager.layout_landscape_extend:
		get_tree().set_screen_stretch(
			SceneTree.STRETCH_MODE_2D, 
			SceneTree.STRETCH_ASPECT_IGNORE, 
			Vector2(1024, 600))
	else:
		get_tree().set_screen_stretch(
			SceneTree.STRETCH_MODE_2D, 
			SceneTree.STRETCH_ASPECT_KEEP, 
			Vector2(1024, 600))
	return

func reset_layout_portrait() -> void :
	OS.set_screen_orientation(OS.SCREEN_ORIENTATION_PORTRAIT)
	var vp = get_viewport()
	vp.size = Vector2(1024, 1560)
	for scene_node in scene_layer.get_children():
		if scene_node.has_method("reset_layout_portrait"):
			scene_node.reset_layout_portrait()
	for node in [bottom, actor_dialog, lsc_menu, image_menu, input_numbers, solo_dialog]:
		node.rect_position = Vector2(0, 656)
		node.rect_scale = Vector2(1.70666, 1.6)
	for node in [lsc_menu_top, actorlist, actor_addpoint]:
		node.rect_position = Vector2(0, 0)
		node.rect_scale = Vector2(1.70666, 1.6)
	tips.rect_scale = Vector2(1.70666, 1.6)
	tips.rect_position = Vector2(0, 608)
	update_cityinfo_position()
	con_war_animations.rect_scale = Vector2(1.70666, 1.6)
	con_war_animations.rect_position = Vector2(32, 120)
	over_animation.rect_scale = Vector2(1.70666, 1.6)
	over_animation.rect_position = Vector2(0, 0)
	actor_info.reset_layout_portrait()
	VirtualKey.reset_layout_portrait()
	black.rect_size = Vector2(640, 600)
	black.rect_position = Vector2(0, 0)
	black.rect_scale = Vector2(1.6, 1.6)
	conEquipInfo.reset_layout_portrait()
	Quit.reset_layout_portrait()
	get_tree().set_screen_stretch(1, 1, Vector2(1024, 1560))
	return

func cheater_start() -> void :
	get_tree().paused = true
	VirtualKey.emu_enable = false
	var cheater = cheaterScene.instance()
	aboveAll.add_child(cheater)
	cheater.start()
	cheater.set_process(true)
	return

func info_start() -> void :
	get_tree().paused = true
	VirtualKey.emu_enable = false
	var info = infoScene.instance()
	aboveAll.add_child(info)
	info.start()
	info.set_process(true)
	return

func cheater_finished() -> void :
	Global.clearNode(aboveAll, ["grayscale"])
	VirtualKey.emu_enable = true
	get_tree().paused = false
	Input.action_release("EMU_MENU")
	Input.action_release("EMU_SELECT")
	if DataManager.get_current_scene_id() == 20000:
		var map = SceneManager.current_scene().get_node_or_null("war_map")
		if map != null:
			map.draw_actors()
	SkillHelper.update_all_skill_buff("CHEAT")
	return

func info_finished() -> void :
	Global.clearNode(aboveAll, ["grayscale"])
	VirtualKey.emu_enable = true
	get_tree().paused = false
	Input.action_release("EMU_MENU")
	Input.action_release("EMU_SELECT")
	return

func bind_top_menu(
	items: PoolStringArray, 
	values: Array, 
	columns: int = 2, 
	offset: Vector2 = Vector2.ZERO, 
	separation: Vector2 = Vector2(260, 42), 
	rich: bool = false) -> void :

	DataManager.set_env("列表显示", items)
	DataManager.set_env("列表值", values)
	lsc_menu_top.set_lsc(offset, separation, rich)
	lsc_menu_top.lsc.columns = columns
	lsc_menu_top.lsc.items = items
	lsc_menu_top.lsc._set_data()
	lsc_menu_top.show()
	lsc_menu_top.lsc.cursor_index = 0
	return

func bind_top_menu_paging(
	items: Array, 
	values: Array, 
	columns: int = 2, 
	rich: bool = false, 
	pageSize: int = 7, 
	offset: Vector2 = Vector2.ZERO, 
	separation: Vector2 = Vector2(260, 42)) -> void :

	if columns == 2:
		pageSize = 14
	var page = DataManager.get_env_int("列表页码")
	var total = items.size()
	var maxPage = int((total - 1) / pageSize)
	maxPage = max(0, maxPage)
	if page < 0:
		page = maxPage
	if page > maxPage:
		page = 0
	DataManager.set_env("列表页码", page)
	
	items = items.slice(page * pageSize, min(total - 1, page * pageSize + pageSize - 1))
	values = values.slice(page * pageSize, min(total - 1, page * pageSize + pageSize - 1))
	if total > pageSize:
		while items.size() < pageSize:
			items.append("")
			values.append( - 1)
		items.append("下一页")
		values.append( - 1)

	DataManager.set_env("列表显示", items)
	DataManager.set_env("列表值", values)
	lsc_menu_top.set_lsc(offset, separation, rich)
	lsc_menu_top.lsc.columns = columns
	lsc_menu_top.lsc.items = items
	lsc_menu_top.lsc._set_data()
	lsc_menu_top.show()
	lsc_menu_top.lsc.cursor_index = 0
	lsc_menu_top.lsc.set_pager(page, maxPage)
	return

func bind_bottom_menu(
	msg: String, 
	options: Array, 
	cols: int = 2
) -> void :
	hide_all_tool()
	DataManager.set_env("列表值", options)
	SceneManager.lsc_menu.lsc.items = options
	SceneManager.lsc_menu.lsc.columns = cols
	SceneManager.lsc_menu.set_lsc()
	SceneManager.lsc_menu.lsc._set_data()

	SceneManager.lsc_menu.show_msg(msg);
	SceneManager.lsc_menu.show_orderbook(true)
	DataManager.cityInfo_type = 1
	SceneManager.show_cityInfo(true)
	SceneManager.lsc_menu.show()
	return



var runtimeInfo: Dictionary = {}

func update_runtime_info(info: Dictionary) -> void :
	var dbg = VirtualKey.get_node("lblDebug")
	if DataManager.is_challange_game():
		var dic = DataManager.get_env_dict("挑战赛")
		var lastUpdate = Global.intval(Global.dic_val(dic, "lastUpdate"))
		var current = int(Time.get_unix_time_from_system())
		if lastUpdate < current - 5:
			dic["score"] = DataManager.get_challange_game_score()
			dic["lastUpdate"] = current
			DataManager.set_env("挑战赛", dic)
		elif not "score" in dic:
			dic["score"] = 0
		var start = - 1
		if "passStart" in dic:
			start = Global.intval(dic["passStart"])
		dic["time"] = "--"
		if start > 0:
			dic["time"] = max(0, EndlessGame.PASS_DURATION_LIMIT - current + start)
		dbg.bbcode_text = """挑战赛：{version}
积　分：{score}
倒计时：{time}
[url=rules][color=yellow]点击查看规则明细[/color][/url]
""".format(dic)
		dbg.show()
		return
	if not DataManager.is_developer():
		dbg.hide()
		return
	for key in ["flow", "vm", "pos"]:
		if key in info:
			runtimeInfo[key] = info[key]
	var pos = Global.dic_val(runtimeInfo, "pos", Vector2( - 1, - 1))
	dbg.bbcode_text = "FL:{0}\nVM:{1}\nPOS:<{2},{3}>".format([
		Global.dic_val(runtimeInfo, "flow"), 
		Global.dic_val_int(runtimeInfo, "vm", - 1), 
		pos.x, pos.y
	])
	dbg.show()
	return



func notice(info: String, node: Node = null, okCallback: String = "", size = Vector2(350, 150), title: String = "请注意") -> void :
	if popuped:
		return
	popuped = true
	var scroll = null
	var label = null
	for cld in notice.get_children():
		if cld is ScrollContainer:
			scroll = cld
			break
	if scroll == null:
		scroll = ScrollContainer.new()
		scroll.rect_min_size = size - Vector2(50, 50)
		
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		notice.add_child(scroll)
	for cld in scroll.get_children():
		if cld is Label:
			label = cld
			break
	if label == null:
		label = Label.new()
		label.autowrap = false
		label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.add_child(label)
	label.text = info

	Global.clear_signals(notice, ["about_to_show"])
	notice.connect("about_to_show", scroll, "set", ["scroll_vertical", 0])
	notice.rect_min_size.x = size.x
	notice.rect_size.x = size.x

	notice.window_title = title
	notice.rect_scale = Vector2(1, 1)
	
	if SceneManager.portrait_mode:
		notice.rect_scale = Vector2(2, 2)
	var ok = notice.get_ok()
	ok.text = "知道了"
	
	Global.clear_signals(notice, ["popup_hide"])
	if node != null and okCallback != "":
		notice.connect("popup_hide", node, okCallback)
	notice.popup_exclusive = true
	notice.popup_centered()
	ok.grab_focus()
	return

func confirm(
	info: String, node: Node = null, okCallback: String = "", 
	size: Vector2 = Vector2(350, 200), 
	okText: String = "确认", cancelText: String = "取消") -> void :
	if popuped:
		return
	popuped = true
	confirmation.rect_min_size = size
	confirmation.rect_size = size
	confirmation.rect_scale = Vector2(1, 1)
	
	if SceneManager.portrait_mode:
		confirmation.rect_scale = Vector2(2, 2)
	confirmation.dialog_text = info
	var ok = confirmation.get_ok()
	ok.text = okText
	ok.rect_min_size = Vector2(120, 60)
	var cancel = confirmation.get_cancel()
	cancel.text = cancelText
	cancel.rect_min_size = Vector2(120, 60)
	Global.clear_signals(confirmation, ["confirmed"])
	if node != null and okCallback != "":
		confirmation.connect("confirmed", node, okCallback, [])
	confirmation.popup_exclusive = true
	confirmation.popup_centered()
	cancel.grab_focus()
	return

func switch_confirming_focus() -> void :
	if not confirmation.visible:
		return
	var ok = confirmation.get_ok()
	var cancel = confirmation.get_cancel()
	var buttons = [ok, cancel]
	var total = buttons.size()
	var focused = 0
	for i in total:
		var btn = buttons[i]
		if btn.has_focus():
			focused = (i + 1) % total
		btn.release_focus()
	buttons[focused].grab_focus()
	return

func notice_nav_up() -> void :
	for cld in notice.get_children():
		if cld is ScrollContainer:
			cld.scroll_vertical = max(0, cld.scroll_vertical - 100)
			break
	return

func notice_nav_down() -> void :
	for cld in notice.get_children():
		if cld is ScrollContainer:
			cld.scroll_vertical += 32
			break
	return

func on_confirming_clicked() -> void :
	var ok = confirmation.get_ok()
	if ok.has_focus():
		ok.emit_signal("pressed")
	confirmation.hide()
	return

func on_confirming_cancel() -> void :
	confirmation.hide()
	return

func on_confirmation_hide():
	popuped = false
	return

func on_notice_hide():
	popuped = false
	return


func process_popuped() -> bool:
	if not popuped:
		return false
	if confirmation.visible:
		if Input.is_action_just_pressed("ANALOG_LEFT"):
			Input.action_release("ANALOG_LEFT")
			switch_confirming_focus()
			return true
		if Input.is_action_just_pressed("ANALOG_RIGHT"):
			Input.action_release("ANALOG_RIGHT")
			switch_confirming_focus()
			return true
		if Input.is_action_just_pressed("EMU_A"):
			Input.action_release("EMU_A")
			on_confirming_clicked()
			return true
		if Input.is_action_just_pressed("EMU_B"):
			Input.action_release("EMU_B")
			on_confirming_cancel()
			return true
		return true
	if notice.visible:
		if Input.is_action_just_pressed("ANALOG_UP"):
			Input.action_release("ANALOG_UP")
			notice_nav_up()
			return true
		if Input.is_action_just_pressed("ANALOG_DOWN"):
			Input.action_release("ANALOG_DOWN")
			notice_nav_down()
			return true
		if Input.is_action_just_pressed("EMU_A"):
			Input.action_release("EMU_A")
			notice.emit_signal("confirmed")
			notice.hide()
			return true
		return true
	return false


func show_system_notice(msg: String, time: int = 200) -> void :
	if msg == "":
		lblSystem.hide()
		return

	msg = " " + msg + " "
	lblSystem.rect_min_size = Vector2(180, 36)
	lblSystem.rect_size = Vector2(180, 36)
	VirtualKey.lblspeed_show_time = time
	lblSystem.text = msg
	lblSystem.show()
	return


func all_actors_max_level():
	var count = 0
	for actor in ActorHelper.all_actors():
		for i in range(actor.get_level(), 8):
			actor.levelup(true)
		actor.set_exp(0)
		count += 1
		if count % 20 == 0:
			yield(SceneManager.get_tree(), "idle_frame")
	return
