# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/scene_endless/scene_endless.gd
# 说明：无尽模式场景脚本。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const SCENE_ID = 0


var all_actors = {}
var cur_index = ""
var actors = [ - 2, - 2, - 2, - 2, - 2, - 2, - 2, - 2, - 2, - 2]

onready var gc_top: GridContainer = get_node("top")
onready var pick_area = get_node("pick_area")
var current_page = 0
var current_sub_page = 0
var total_page = 1
var total_sub_page = 1
const one_page_num = 22
const one_sub_page_num = 15

var control_model = 0

var select_pnl_actor_index = 0

const INIT_MSG = "请玩家1\n调整出战的武将\n「开始」键决定阵容"
var init_msg: String = INIT_MSG

func _ready() -> void :
	SceneManager.load_scene_complete = true
	actors = EndlessGame.chosen_actors
	$title.text = "无尽模式"
	if DataManager.is_challange_game():
		
		$title.text = "无尽模式 - 挑战赛"
		actors = [ - 2, - 2, - 2, - 2, - 2, - 2, - 2, - 1, - 1, - 1]

	EndlessGame.fix_all_actor_data()
	update_actors()
	var lblpage = pick_area.get_node("lblpage")
	all_actors = {}
	ActorHelper.reload()
	var m = ActorHelper.nameMap.duplicate(true)
	for actor in ActorHelper.all_actors():
		var fn = actor.get_first_name()
		var name = actor.get_full_name()
		if "#" in name:
			name = name.replace("#", "(") + ")"
		if not all_actors.has(fn):
			all_actors[fn] = {}
		if not actor.has_side():
			all_actors[fn][name] = str(actor.actorId)
			continue
		all_actors[fn][name + "·阴"] = "{0}|阴".format([actor.actorId])
		all_actors[fn][name + "·阳"] = "{0}|阳".format([actor.actorId])
	total_page = int(ceil(all_actors.keys().size() / float(one_page_num)))
	
	update_pick_page(false)

	go_to_model(0, true)
	model_select_update()

	SoundManager.play_bgm("res://resource/sounds/bgm/Scene_Choose.ogg")
	return

func update_pick_page(show_cursor: bool):
	var items = []
	var lblpage = pick_area.get_node("lblpage")
	var lsc = pick_area.get_node("lsc")

	var options = all_actors.keys()
	options.sort_custom(self, "_sort_alpha")
	options.insert(0, "随机")
	for i in options.size():
		if items.size() >= one_page_num:
			break
		if i < current_page * one_page_num:
			continue
		var item_text = options[i]
		
		items.append(item_text)
	for i in range(items.size() % 6, 4):
		items.append("")
	items.append("上页")
	items.append("下页")
	
	lsc.columns = 6
	lsc.h_separation = 90
	lsc.items = items
	lsc._set_data()
	if not show_cursor:
		lsc.cursor_index = - 1
	else:
		lsc.cursor_index = Array(lsc.items).find(cur_index)
	lblpage.text = "{0}/{1}".format([current_page + 1, total_page])
	return
	
func update_actors():
	EndlessGame.chosen_actors = actors
	_update_actors_side(gc_top, actors)
	return

func _update_actors_side(con: GridContainer, actors: Array):
	actors.resize(10)
	for i in 10:
		var id = actors[i]
		var pnl = con.get_node("pnlActorHide" + str(i))
		var val = str(id) + "|"
		var actorId = int(val.split("|")[0])
		var side = str(val).split("|")[1]
		if side != "":
			side = "·" + side
		if id == null:
			pnl.get_node("name").text = "(空位)"
		elif actorId >= 0:
			var actor = ActorHelper.actor(actorId)
			var display = actor.display_name() + side
			pnl.get_node("name").text = display
		elif actorId != - 1:
			pnl.get_node("name").text = "(空位)"
		else:
			pnl.get_node("name").text = "随机"
	return

func model_select_update(backcolor = Color.black):
	for j in gc_top.get_child_count():
		var child: Panel = gc_top.get_child(j)
		var color_rect: ColorRect = child.get_node("ColorRect")
		color_rect.color = backcolor
		var lblname: Label = child.get_node("name")
		if select_pnl_actor_index == j:
			lblname.set("custom_colors/font_color", Color.white)
			color_rect.show()
		else:
			lblname.set("custom_colors/font_color", Color.black)
			color_rect.hide()
	return

func _process(delta: float) -> void :
	match control_model:
		0:
			model_select_update()
			if Input.is_action_just_pressed("ANALOG_DOWN") or Input.is_action_just_pressed("ANALOG_UP"):
				select_pnl_actor_index = (select_pnl_actor_index + 5) % 10
			if Input.is_action_just_pressed("ANALOG_LEFT"):
				select_pnl_actor_index = (select_pnl_actor_index + 9) % 10
			if Input.is_action_just_pressed("ANALOG_RIGHT"):
				select_pnl_actor_index = (select_pnl_actor_index + 1) % 10
			if Global.is_action_pressed_AX():
				if not SceneManager.dialog_msg_complete(true):
					return
				if start_select_actor():
					return
			if Global.is_action_pressed_BY():
				if not SceneManager.dialog_msg_complete(true):
					return
				_clear_actor()
			if Input.is_action_just_pressed("EMU_START"):
				if not SceneManager.dialog_msg_complete(true):
					return
				var exists = false
				var strs = "".join(actors)
				if strs.replace("-2", "").empty():
					SceneManager.show_unconfirm_dialog("阵容中无任何武将！")
					return
				go_to_model(2)
		1:
			var lsc = pick_area.get_node("lsc")
			if Input.is_action_just_pressed("ANALOG_DOWN"):
				lsc.move_down()
				update_cursor_actor()
			if Input.is_action_just_pressed("ANALOG_UP"):
				lsc.move_up()
				update_cursor_actor()
			if Input.is_action_just_pressed("ANALOG_LEFT"):
				lsc.move_left()
				update_cursor_actor()
			if Input.is_action_just_pressed("ANALOG_RIGHT"):
				lsc.move_right()
				update_cursor_actor()
			if Global.is_action_pressed_AX():
				if not SceneManager.dialog_msg_complete(true):
					return
				if _select_actor():
					go_to_model(0)
			if Global.is_action_pressed_BY():
				if not SceneManager.dialog_msg_complete(false):
					return
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
					return
				match SceneManager.actor_dialog.lsc.cursor_index:
					0:
						go_to_model(3)
					1:
						go_to_model(0)
		10:
			var lsc = pick_area.get_node("lsc")
			if Input.is_action_just_pressed("ANALOG_DOWN"):
				lsc.move_down()
			if Input.is_action_just_pressed("ANALOG_UP"):
				lsc.move_up()
			if Input.is_action_just_pressed("ANALOG_LEFT"):
				lsc.move_left()
			if Input.is_action_just_pressed("ANALOG_RIGHT"):
				lsc.move_right()
			if Global.is_action_pressed_AX():
				if not SceneManager.dialog_msg_complete(true):
					return
				if _select_index():
					go_to_model(0)
			if Global.is_action_pressed_BY():
				if not SceneManager.dialog_msg_complete(false):
					return
				go_to_model(0)
		100:
			if not Global.is_action_pressed_AX():
				return
			if not SceneManager.dialog_msg_complete(true):
				return
			go_to_model(0)
	return

func go_to_model(_control_model: int, is_init = false):
	var lsc = pick_area.get_node("lsc")
	control_model = _control_model
	match control_model:
		0:
			lsc.cursor_index = - 1
			SceneManager.show_unconfirm_dialog(init_msg)
			if not is_init:
				SceneManager.dialog_msg_complete(true)
		1:
			init_msg = INIT_MSG
			model_select_update(Color.red)
			lsc.cursor_index = 0
			update_cursor_actor()
		2:
			var selected = actors.duplicate()
			while not selected.empty() and (selected[0] == null or str(selected[0]) == "-2"):
				selected.pop_front()
			if selected.empty():
				init_msg = "请至少选择一个武将"
				go_to_model(0)
				return
			lsc.cursor_index = - 1
			var confirm_msg = "确定以此阵容\n进入无尽模式吗？"
			if DataManager.is_challange_game():
				var penalty = EndlessGame.get_chosen_penalty_per_pass(actors)
				confirm_msg = "确定以此阵容进入挑战赛吗？"
				if penalty < 0:
					confirm_msg += "\n自选武将扣分：%d/关" % penalty
			SceneManager.show_yn_dialog(confirm_msg)
		3:
			var new_actors = []
			var all = actors.duplicate()
			for actorId_str in all:
				if actorId_str == null:
					continue
				actorId_str = str(actorId_str) + "|"
				var actorId = int(str(actorId_str).split("|")[0])
				if actorId == - 2:
					continue;
				var side = str(actorId_str).split("|")[1]
				var actor = ActorHelper.actor(actorId)
				if side != "" and actor.has_side():
					actor._set_attr("面", side)
				new_actors.append(actorId)
			game_start(PoolIntArray(new_actors))
		10:
			lsc.cursor_index = 0
			model_select_update(Color.red)
			var loc = Array(lsc.items).find(cur_index)
			if loc >= 0:
				lsc.cursor_index = loc
			show_actor_info( - 1)
		100:
			lsc.cursor_index = - 1
			SceneManager.show_confirm_dialog("根据挑战赛规则\n不可调整此位置的武将")
	return

func _clear_actor():
	if DataManager.is_challange_game():
		
		if select_pnl_actor_index > 6:
			go_to_model(100)
			return true
	actors[select_pnl_actor_index] = - 2
	update_actors()
	return

func _select_index() -> bool:
	var lsc = pick_area.get_node("lsc")
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
		"随机":
			return _select_actor()
		_:
			_update_index(item)
	return false

func update_pick_sub_page(show_cursor: bool):
	var items = []
	var lblpage = pick_area.get_node("lblpage")
	var lsc = pick_area.get_node("lsc")
	
	var options = all_actors[cur_index]
	var actorNames = options.keys()
	actorNames.sort()
	for i in actorNames.size():
		if items.size() >= one_sub_page_num:
			break
		if i < current_sub_page * one_sub_page_num:
			continue
		items.append(actorNames[i])
	for i in range(items.size() % 4, 3):
		items.append("")
	if options.size() >= one_sub_page_num:
		items.append("下页")
	total_sub_page = int(ceil(options.size() / float(one_sub_page_num)))

	lsc.columns = 4
	lsc.h_separation = 140
	lsc.items = items
	lsc._set_data()
	lsc.cursor_index = 0
	if not show_cursor:
		lsc.cursor_index = - 1
	lblpage.text = "{0}/{1}".format([current_sub_page + 1, total_sub_page])
	return

func _update_index(idx: String):
	cur_index = idx
	current_sub_page = 0
	update_pick_sub_page(true)
	go_to_model(1)
	return

func _select_actor() -> bool:
	var lsc = pick_area.get_node("lsc")
	var item = lsc.items[lsc.cursor_index]
	match item:
		"随机":
			actors[select_pnl_actor_index] = "-1"
			update_actors()
			return true
		"下页":
			current_sub_page = (current_sub_page + 1) % total_sub_page
			update_pick_sub_page(true)
			lsc.cursor_index = Array(lsc.items).find(item)
			return false
	var value = str(all_actors[cur_index][item]) + "|"
	var actorId = int(value.split("|")[0])
	var side = value.split("|")[1]
	
	var new_value = "{0}|{1}".format([actorId, side])
	for check_value in actors:
		if check_value == null:
			continue
		var check_actorId = int(str(check_value).split("|")[0])
		if check_actorId == actorId:
			SceneManager.show_unconfirm_dialog("吾已被选过！", check_actorId)
			return false
	actors[select_pnl_actor_index] = new_value
	update_actors()
	return true

func show_actor_info(actorId: int, side: String = ""):
	if actorId >= 0 and side != "":
		var actor = ActorHelper.actor(actorId)
		actor._set_attr("面", side)
	SceneManager.show_actor_info(actorId)
	return

func update_cursor_actor():
	var lsc = pick_area.get_node("lsc")
	var item = lsc.items[lsc.cursor_index]
	if not (item in all_actors[cur_index]):
		SceneManager.hide_all_tool()
		return
	var value = str(all_actors[cur_index][item]) + "|"
	var actorId = int(value.split("|")[0])
	var side = value.split("|")[1]
	show_actor_info(actorId, side)
	return

func _sort_alpha(a: String, b: String) -> bool:
	var ai = ""
	var bi = ""
	for k in ActorHelper.ALPHA_SORTING:
		if a.left(1) in k[1]:
			ai = k[0]
		if b.left(1) in k[1]:
			bi = k[0]
	return ai < bi

func reset_layout_landscape():
	rect_position = Vector2(192, 0)
	rect_scale = Vector2(1, 1)
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.6, 1.6)
	return

func start_select_actor() -> bool:
	if DataManager.is_challange_game():
		
		if select_pnl_actor_index > 6:
			go_to_model(100)
			return true
	update_pick_page(true)
	go_to_model(10)
	return true


func game_start(selected: PoolIntArray) -> void :
	var title = "正在设置全武将满级"
	if DataManager.diffculities >= 4 and DataManager.get_game_setting("开局方式") != "全武将满级":
		DataManager.game_set["开局方式"] = "全武将满级"
		title = "无尽挑战，全武将自动满级"
	
	if "全武将满级" == DataManager.get_game_setting("开局方式"):
		if is_instance_valid(SceneManager.war_intro):
			SceneManager.war_intro.show_basic_info(title, "请稍后……")
			
			yield(SceneManager.get_tree(), "idle_frame")
		yield(SceneManager.all_actors_max_level(), "completed")
		if is_instance_valid(SceneManager.war_intro):
			SceneManager.war_intro.cleanup()
	EndlessGame.load_endless(selected)
	return
