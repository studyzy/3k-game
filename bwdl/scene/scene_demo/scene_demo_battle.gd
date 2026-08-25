# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/scene_demo/scene_demo_battle.gd
# 说明：演示战斗场景脚本。用于播放演示/教学战斗。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const SCENE_ID = 0


var all_actors = {};
var cur_index = "";

var chosenActors = [
	[ - 1, - 1, - 1], 
	[ - 1, - 1, - 1], 
]

onready var conAttack: GridContainer = get_node("attack")
onready var conDefend: GridContainer = get_node("defend")
onready var optSide: OptionButton = get_node("pnlGo/optSide")
onready var optTerrian: OptionButton = get_node("pnlGo/optTerrian")
onready var pick_area = get_node("pick_area");

var current_page = 0;
var current_sub_page = 0;
var total_page = 1;
var total_sub_page = 1;
const one_page_num = 21;
const one_sub_page_num = 14;

var control_model = 0;

var sideCursor = 0;
var actorCursor = 0;


onready var war_map = self


var data = {}

func _ready() -> void :
	if DataManager.common_variable.has("demo_battle"):
		data = Dictionary(DataManager.common_variable["demo_battle"])
		if "chosen" in data:
			chosenActors = data["chosen"]
	SceneManager.load_scene_complete = true;
	optSide.items.clear()
	optSide.add_item("攻方")
	optSide.add_item("守方")
	var defaultSide = 0
	if data.has("side"):
		defaultSide = int(data["side"])
	optSide.select(defaultSide)
	optSide.get_popup().set("custom_colors/font_color", Color.white)
	optSide.get_popup().add_font_override("font", Global.get_font(25))
	optTerrian.items.clear()
	optTerrian.add_item("墙->墙")
	optTerrian.add_item("平->墙")
	for terrian in StaticManager.BLOCKS_EN_CN.values():
		if terrian in ["装备店", "米屋", "医馆", "城墙"]:
			continue
		optTerrian.add_item(terrian)
	var defaultTerrain = 0
	if data.has("terrian"):
		var terrian = str(data["terrian"])
		for i in optTerrian.get_item_count():
			if optTerrian.get_item_text(i) == terrian:
				defaultTerrain = i
				break
	optTerrian.select(defaultTerrain)
	optTerrian.get_popup().set("custom_colors/font_color", Color.white)
	optTerrian.get_popup().add_font_override("font", Global.get_font(25))

	update_actors()
	var lblpage = pick_area.get_node("lblpage");
	all_actors = {}
	ActorHelper.reload()
	var m = ActorHelper.nameMap.duplicate(true)
	for actor in ActorHelper.all_actors():
		var fn = actor.get_first_name()
		var name = actor.get_full_name()
		if not all_actors.has(fn):
			all_actors[fn] = {}
		if not actor.has_side():
			all_actors[fn][name] = str(actor.actorId)
			continue
		all_actors[fn][name + "·阴"] = "{0}|阴".format([actor.actorId])
		all_actors[fn][name + "·阳"] = "{0}|阳".format([actor.actorId])
	total_page = int(ceil(all_actors.keys().size() / float(one_page_num)))
	
	update_pick_page(false)

	go_to_model(0, true);
	model_select_update()
	
	SoundManager.play_bgm("res://resource/sounds/bgm/Scene_Choose.ogg");
	return

func update_pick_page(show_cursor: bool):
	var items = [];
	var lblpage = pick_area.get_node("lblpage");
	var lsc = pick_area.get_node("lsc");

	var options = all_actors.keys()
	options.sort_custom(self, "_sort_alpha")
	for i in options.size():
		if items.size() >= one_page_num:
			break;
		if i < current_page * one_page_num:
			continue;
		var item_text = options[i];
		
		items.append(item_text)
	items.append("上页")
	items.append("下页")
	
	lsc.columns = 6
	lsc.h_separation = 90
	lsc.items = items;
	lsc._set_data()
	if not show_cursor:
		lsc.cursor_index = - 1;
	else:
		lsc.cursor_index = Array(lsc.items).find(cur_index)
	lblpage.text = "{0}/{1}".format([current_page + 1, total_page])
	return
	
func update_actors():
	_update_actors_side(conAttack, chosenActors[0])
	_update_actors_side(conDefend, chosenActors[1])
	return

func _update_actors_side(con: GridContainer, actors: Array):
	var pnls = con.get_children()
	var offset = 1
	for item in actors:
		var vals = "{0}|".format([item]).split("|")
		var actorId = int(vals[0])
		var side = str(vals[1])
		var name = "<随机>"
		if actorId >= 0:
			name = ActorHelper.actor(actorId).get_name()
			if side != "":
				name += "·" + side
		var pnl = pnls[offset]
		offset += 1
		pnl.get_node("name").text = name
	return

func model_select_update(backcolor = Color.black):
	var grids = [conAttack, conDefend]
	for sideIdx in range(2):
		var grid = grids[sideIdx]
		for actorIdx in range(3):
			var pnl = grid.get_child(actorIdx + 1)
			var colorRect = pnl.get_node("ColorRect")
			colorRect.color = backcolor;
			var lbl = pnl.get_node("name")
			if sideIdx == sideCursor and actorIdx == actorCursor:
				lbl.set("custom_colors/font_color", Color.white)
				colorRect.show()
			else:
				lbl.set("custom_colors/font_color", Color.black)
				colorRect.hide()
	return

func _process(delta: float) -> void :
	match control_model:
		0:
			model_select_update()
			if Input.is_action_just_pressed("ANALOG_DOWN"):
				sideCursor = (sideCursor + 1) % 2
			if Input.is_action_just_pressed("ANALOG_UP"):
				sideCursor = (sideCursor + 1) % 2
			if Input.is_action_just_pressed("ANALOG_LEFT"):
				actorCursor = (actorCursor + 2) % 3
			if Input.is_action_just_pressed("ANALOG_RIGHT"):
				actorCursor = (actorCursor + 1) % 3
			if Global.is_action_pressed_AX():
				if not SceneManager.dialog_msg_complete(true):
					return ;
				update_pick_page(true)
				go_to_model(10)
			if Global.is_action_pressed_BY():
				if not SceneManager.dialog_msg_complete(true):
					return ;
				_clear_actor()
			if Input.is_action_just_pressed("EMU_START"):
				if not SceneManager.dialog_msg_complete(true):
					return ;
				go_to_model(2);
		1:
			var lsc = pick_area.get_node("lsc");
			if Input.is_action_just_pressed("ANALOG_DOWN"):
				lsc.move_down();
				update_cursor_actor()
			if Input.is_action_just_pressed("ANALOG_UP"):
				lsc.move_up();
				update_cursor_actor()
			if Input.is_action_just_pressed("ANALOG_LEFT"):
				lsc.move_left();
				update_cursor_actor()
			if Input.is_action_just_pressed("ANALOG_RIGHT"):
				lsc.move_right();
				update_cursor_actor()
			if Global.is_action_pressed_AX():
				if not SceneManager.dialog_msg_complete(true):
					return ;
				if _select_actor():
					go_to_model(0)
			if Global.is_action_pressed_BY():
				if not SceneManager.dialog_msg_complete(false):
					return ;
				update_pick_page(true)
				go_to_model(10)
		2:
			if Input.is_action_just_pressed("ANALOG_LEFT"):
				SceneManager.actor_dialog.move_left()
			if Input.is_action_just_pressed("ANALOG_RIGHT"):
				SceneManager.actor_dialog.move_right()
			if Input.is_action_just_pressed("ANALOG_UP"):
				SceneManager.actor_dialog.move_up()
			if Input.is_action_just_pressed("ANALOG_DOWN"):
				SceneManager.actor_dialog.move_down()
			if (Global.is_action_pressed_AX()):
				if ( not SceneManager.dialog_msg_complete(true)):
					return ;
				match SceneManager.actor_dialog.lsc.cursor_index:
					0:
						go_to_model(3);
					1:
						go_to_model(0)
		10:
			var lsc = pick_area.get_node("lsc");
			if Input.is_action_just_pressed("ANALOG_DOWN"):
				lsc.move_down();
			if Input.is_action_just_pressed("ANALOG_UP"):
				lsc.move_up();
			if Input.is_action_just_pressed("ANALOG_LEFT"):
				lsc.move_left();
			if Input.is_action_just_pressed("ANALOG_RIGHT"):
				lsc.move_right();
			if Global.is_action_pressed_AX():
				if not SceneManager.dialog_msg_complete(true):
					return ;
				if _select_index():
					go_to_model(0)
			if Global.is_action_pressed_BY():
				if not SceneManager.dialog_msg_complete(false):
					return ;
				go_to_model(0)
	return

func go_to_model(_control_model: int, is_init = false):
	var lsc = pick_area.get_node("lsc");
	control_model = _control_model;
	match control_model:
		0:
			lsc.cursor_index = - 1;
			SceneManager.show_unconfirm_dialog("请玩家1\n调整出战的武将\n开始键决定阵容");
			if not is_init:
				SceneManager.dialog_msg_complete(true);
		1:
			model_select_update(Color.red)
			lsc.cursor_index = 0;
			update_cursor_actor()
		2:
			lsc.cursor_index = - 1;
			SceneManager.show_yn_dialog("确定以此阵容\n进入白刃试炼吗？");
		3:
			var decidedActors = [[], []]
			var added = []
			for i in range(2):
				for item in chosenActors[i]:
					var vals = "{0}|".format([item]).split("|")
					var actorId = int(vals[0])
					var side = str(vals[1])
					decidedActors[i].append(actorId)
					if actorId >= 0:
						added.append(actorId)
						var actor = ActorHelper.actor(actorId)
						if side != "" and actor.has_side():
							actor._set_attr("面", side)
			
			for i in range(2):
				for j in decidedActors[i].size():
					if decidedActors[i][j] == - 1:
						var randomActorId = ActorHelper.random_actor_id()
						while randomActorId in added:
							randomActorId = ActorHelper.random_actor_id()
						decidedActors[i][j] = randomActorId
						added.append(randomActorId)
			init_battle(decidedActors)
		10:
			lsc.cursor_index = 0;
			model_select_update(Color.red)
			var loc = Array(lsc.items).find(cur_index)
			if loc >= 0:
				lsc.cursor_index = loc
			show_actor_info( - 1);
	return

func _clear_actor():
	chosenActors[sideCursor][actorCursor] = - 1
	update_actors()
	return

func _select_index() -> bool:
	var lsc = pick_area.get_node("lsc");
	var item = lsc.items[lsc.cursor_index]
	match item:
		"上页":
			current_page = (current_page + total_page - 1) % total_page
			update_pick_page(true)
			lsc.cursor_index = Array(lsc.items).find(item)
			return false
		"下页":
			current_page = (current_page + 1) % total_page
			update_pick_page(true)
			lsc.cursor_index = Array(lsc.items).find(item)
			return false
		_:
			_update_index(item)
	return false

func update_pick_sub_page(show_cursor: bool):
	var items = [];
	var lblpage = pick_area.get_node("lblpage");
	var lsc = pick_area.get_node("lsc");
	
	var options = all_actors[cur_index]
	var actorNames = options.keys()
	actorNames.sort()
	for i in actorNames.size():
		if items.size() >= one_sub_page_num:
			break
		if i < current_sub_page * one_sub_page_num:
			continue;
		items.append(actorNames[i])
	if options.size() >= one_sub_page_num:
		items.append("下页")
	total_sub_page = int(ceil(options.size() / float(one_sub_page_num)))

	lsc.columns = 4
	lsc.h_separation = 140
	lsc.items = items;
	lsc._set_data()
	lsc.cursor_index = 0
	if not show_cursor:
		lsc.cursor_index = - 1;
	lblpage.text = "{0}/{1}".format([current_sub_page + 1, total_sub_page])
	return

func _update_index(idx: String):
	cur_index = idx
	current_sub_page = 0;
	update_pick_sub_page(true)
	go_to_model(1)
	return

func _select_actor() -> bool:
	var lsc = pick_area.get_node("lsc");
	var item = lsc.items[lsc.cursor_index];
	match item:
		"随机":
			chosenActors[sideCursor][actorCursor] = - 1
			update_actors()
			return true
		"下页":
			current_sub_page = (current_sub_page + 1) % total_sub_page
			update_pick_sub_page(true)
			lsc.cursor_index = Array(lsc.items).find(item)
			return false
	var value = str(all_actors[cur_index][item]) + "|";
	var actorId = int(value.split("|")[0]);
	var side = value.split("|")[1];
	
	var new_value = "{0}|{1}".format([actorId, side]);
	chosenActors[sideCursor][actorCursor] = new_value
	update_actors();
	return true;

func show_actor_info(actorId: int, side: String = ""):
	if actorId >= 0 and side != "":
		var actor = ActorHelper.actor(actorId)
		actor._set_attr("面", side)
	SceneManager.show_actor_info(actorId);
	pass

func update_cursor_actor():
	var lsc = pick_area.get_node("lsc");
	var item = lsc.items[lsc.cursor_index];
	if not (item in all_actors[cur_index]):
		SceneManager.hide_all_tool();
		return ;
	var value = str(all_actors[cur_index][item]) + "|";
	var actorId = int(value.split("|")[0]);
	var side = value.split("|")[1];
	show_actor_info(actorId, side);

func _sort_alpha(a: String, b: String) -> bool:
	var ai = ""
	var bi = ""
	for k in ActorHelper.ALPHA_SORTING:
		if a.left(1) in k[1]:
			ai = k[0]
		if b.left(1) in k[1]:
			bi = k[0]
	return ai < bi

func init_battle(decided: Array) -> void :
	DataManager.clear_common_variable(["战争", "白兵", "计策", "单挑"])
	var playerSide = optSide.get_selected_id()
	data["chosen"] = chosenActors
	data["side"] = playerSide
	var terrian = optTerrian.get_item_text(optTerrian.get_selected_id())
	var fromTerrian = terrian
	if terrian == "平->墙":
		terrian = "城墙"
		fromTerrian = "平地"
	elif terrian == "墙->墙":
		terrian = "城墙"
		fromTerrian = "城墙"
	data["terrian"] = terrian
	data["fromTerrian"] = fromTerrian
	DataManager.common_variable["demo_battle"] = data
	DataManager.players.clear()
	DataManager.players.append(_create_player(decided[playerSide][1]))
	var wf = DataManager.new_war_fight( - 1, 0)
	wf.defenderWV = _create_war_vstate(0, decided[1], playerSide == 1)
	wf.attackerWV = _create_war_vstate(1, decided[0], playerSide == 0)

	wf.init_war()
	wf.date = 9527

	
	for wv in wf.war_vstates():
		for actorId in wv.init_actors:
			ActorHelper.actor(actorId).set_level(8)
			wv.camp_out(actorId)
			var wa = DataManager.get_war_actor(actorId)
			wa.action_point = 6

	var from = DataManager.get_war_actor(decided[0][0])
	var target = DataManager.get_war_actor(decided[1][0])
	from.position = Vector2(1, 1)
	target.position = Vector2(0, 0)
	DataManager.player_choose_actor = from.actorId
	DataManager.common_variable["武将"] = target.actorId
	var player_attack = Global.load_script(DataManager.mod_path + "sgz_script/war/player_attack.gd")
	player_attack._go_to_battle(false)
	LoadControl.end_script()
	return

func _create_player(actorId: int) -> Player:
	var p = Player.new()
	p.actorId = actorId
	return p
	
func _create_war_vstate(vstateId: int, actors: PoolIntArray, isPlayer: bool) -> War_Vstate:
	var isAttacker = vstateId == 1
	var wv = War_Vstate.new(vstateId, false, isAttacker)
	wv.rice = 1000
	wv.money = 1000
	wv.init_actors = []
	wv.init_actors.append_array(actors)
	wv.from_cityId = 0
	if wv.is_attacker():
		wv.from_cityId = 1
	wv.main_actorId = actors[1]
	for actorId in actors:
		var actor = ActorHelper.actor(actorId)
		actor.set_status_officed()
		actor.set_level(8)
		actor.reset_levelup_trackings()
		actor.set_soldiers(DataManager.get_actor_max_soldiers(actorId))
		actor.set_hp(actor.get_max_hp())
	return wv

func get_blockCN_by_position(pos: Vector2) -> String:
	if pos.x > 0:
		if "fromTerrian" in data:
			return data["fromTerrian"]
	if "terrian" in data:
		return data["terrian"]
	return "平地"

func get_blockEN_by_CN(blockCN: String) -> String:
	for bEN in StaticManager.BLOCKS_EN_CN.keys():
		if StaticManager.BLOCKS_EN_CN[bEN] == blockCN:
			return bEN
	return "land"

func reset_layout_landscape():
	rect_position = Vector2(192, 0)
	rect_scale = Vector2(1, 1)
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.6, 1.6)
	return
