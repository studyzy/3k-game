# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：scene/scene_battle/scene_battle.gd
# 说明：战斗场景主脚本。白兵战（战场）的整体流程控制。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const SCENE_ID = 30000

const cell_columns = 16;
const cell_rows = 10;
const block_size = 40;

onready var cursor = get_node("cursor")
onready var battle_state = get_node("battle_state");
onready var battle_unit_status = get_node("battle_unit_status")
onready var main_bottom = get_node("main_bottom");
onready var battle_tactic = get_node("battle_tactic");

onready var effects_layer = get_node("battle_map/effects_layer");
onready var map_layer = get_node("battle_map/map_layer");
onready var units_layer = get_node("battle_map/units_layer");
onready var mark_layer = get_node("battle_map/mark_layer")

onready var focusMask = get_node("battle_map/focus_mask")

onready var lblStatus = $status / lbl
onready var twStatus = $status / tw


onready var notice = get_node("battle_map/lblNotice")
var noticeTimer: SceneTreeTimer = null
var noticeTween: Tween = null

onready var battle_log = get_node("battle_log");

const ROCK = preload("res://scene/scene_battle/rock.tscn")

var block_type = "";
var battle_run;
var unit_created = false;
var unit_updated = false;

var buff_textures = []


var bgm = true;


var marked_positions: PoolVector2Array = []


var cursor_position: Vector2 = Vector2( - 10, - 10)


func _ready() -> void :
	notice.hide()
	cursor.hide()
	battle_run = Global.load_script(DataManager.mod_path + "sgz_script/battle/Battle_Auto_Run.gd")
	init_map()

	battle_tactic.hide();
	if ( not DataManager.battle_actors.empty() and not DataManager.battle_units.empty()):
		main_bottom.update_data();
		main_bottom.show();
	else:
		main_bottom.hide();
	show_units_hp(DataManager.get_env_int("显示白兵血量") > 0)
	
	battle_state.hide()
	battle_unit_status.hide()
	SceneManager.load_scene_complete = true
	
	if DataManager.battle_run:
		
		SoundManager.play_bgm()
	unit_created = false

	
	for i in range(2):
		var texture = Global.load_pic("res://resource/images/battle_character/buffs_" + str(i) + ".png")
		buff_textures.append(texture)
	get_node("battle_map/lblRoleLeft").hide()
	get_node("battle_map/lblRoleRight").hide()
	battle_log.visible = false
	lblStatus.visible = false
	return

func _process(delta: float) -> void :
	if process_battle_log():
		return
	check_role_status()
	if not DataManager.battle_run:
		return
	
	process_status_tween()
	if is_instance_valid(battle_run):
		battle_run._process(delta)
	return

func process_status_tween() -> void :
	var bf = DataManager.get_current_battle_fight()
	if twStatus.is_active():
		return
	var status = bf.next_status_effect()
	if status.empty():
		return
	var bu = status[0]
	var msg = status[1]
	if bu == null or bu.disabled:
		return
	if msg == "":
		return
	if "#" in msg:
		var color = msg.split("#")[1]
		lblStatus.set("custom_colors/font_color", Color(color))
		msg = msg.split("#")[0]
	else:
		lblStatus.set("custom_colors/font_color", Color("00B3FF"))
	lblStatus.text = msg
	lblStatus.rect_position = bu.unit_position * block_size - Vector2(block_size, 0)
	var targetPosition = lblStatus.rect_position - Vector2(0, block_size * 1.5)
	var duration: float = 0.3 * float(Engine.time_scale)
	twStatus.stop_all()
	twStatus.interpolate_property(
		lblStatus, "rect_position", 
		lblStatus.rect_position, targetPosition, 
		duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	twStatus.interpolate_property(
		lblStatus, "visible", 
		1, 0, 
		duration, Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	twStatus.start()
	return

func check_role_status():
	var lblRoles = [
		get_node("battle_map/lblRoleLeft"), 
		get_node("battle_map/lblRoleRight"), 
	]
	for i in lblRoles.size():
		if DataManager.battle_actors.size() <= i:
			continue
		var actorId = DataManager.battle_actors[i]
		var wa = DataManager.get_war_actor(actorId)
		if wa == null or wa.disabled:
			continue
		lblRoles[i].text = "AI"
		if wa.get_controlNo() >= 0:
			lblRoles[i].text = "1P"
		lblRoles[i].show()
	return

func init_map():
	Global.clearNode(map_layer);
	var bf = DataManager.get_current_battle_fight()
	var terrian = bf.get_terrian()
	var fromTerrian = bf.get_from_terrian()
	var map_array = StaticManager.load_battle_map(terrian, fromTerrian)
	var i = 0;
	for blockNo in map_array:
		var x = i % cell_columns;
		var y = (i / cell_columns);
		var position = Vector2(x, y);
		var block_rect = create_block_image_tect(terrian, blockNo);
		var rect_name = "(" + str(x) + "," + str(y) + ")";
		block_rect.name = rect_name;
		block_rect.rect_size = Vector2(1, 1) * block_size;
		block_rect.rect_position = position * block_size;
		block_rect.editor_description = blockNo;
		map_layer.add_child(block_rect);
		i += 1;
	return


func get_position_image_name(position: Vector2) -> String:
	var rect_name = "(" + str(position.x) + "," + str(position.y) + ")";
	var node: TextureRect = map_layer.get_node_or_null(rect_name);
	return node.editor_description;

func clear_units():
	Global.clearNode(units_layer)
	unit_created = false
	return

func init_units():
	clear_units()
	update_units()
	unit_created = true
	return
	
func update_units():
	var battle_actors = Array(DataManager.battle_actors).duplicate();
	for unit in DataManager.battle_units:
		create_or_update_unit(unit);
	show_units_hp(DataManager.get_env_int("显示白兵血量") > 0)
	unit_updated = true
	return

func get_unit_node(unitId: int):
	return units_layer.get_node_or_null(str(unitId))

func create_or_update_unit(unit: Battle_Unit):
	var unit_node: Control = get_unit_node(unit.unitId)
	if unit_node == null:
		var unit_packscen: PackedScene = load("res://windows/children/Battle_Unit.tscn");
		unit_node = unit_packscen.instance();
		unit_node.name = str(unit.unitId);
		unit_node.unitId = unit.unitId;
		units_layer.add_child(unit_node);
	
	unit_node.visible = not unit.disabled
	return unit_node


func create_block_image_tect(block_type: String, block_no: String) -> TextureRect:
	var path = "res://resource/images/battle_mapblock/" + str(block_type) + "/" + str(block_no) + ".png";
	var texture = Global.load_pic(path);
	var text_rect: TextureRect = TextureRect.new();
	text_rect.texture = texture;
	text_rect.texture.set_flags(1);
	text_rect.expand = true;
	return text_rect;


func get_position_is_roadblock(position: Vector2):
	var rect_name = "(" + str(position.x) + "," + str(position.y) + ")";
	var block_rect: TextureRect = map_layer.get_node_or_null(rect_name);
	if (block_rect == null):
		return false;
	var blocks = StaticManager.get_battle_blocks_setting()
	if (block_rect.editor_description in blocks["通行障碍"]):
		return true;
	return false;
	

func get_position_is_arrowblock(position: Vector2):
	var rect_name = "(" + str(position.x) + "," + str(position.y) + ")";
	var block_rect: TextureRect = map_layer.get_node_or_null(rect_name);
	if (block_rect == null):
		return false;
	var blocks = StaticManager.get_battle_blocks_setting()
	if (block_rect.editor_description in blocks["射击障碍"]):
		return true;
	return false;


func create_bomb(from: Vector2, to: Vector2, end_obj: Object, end_method: String):
	Global.clearNode(effects_layer);
	var bomb_packscene: PackedScene = load("res://windows/children/Battle_Unit_Bomb.tscn");
	var bomb = bomb_packscene.instance();
	effects_layer.add_child(bomb);
	bomb.init_data(from, to, end_obj, end_method);
	return


func player_call_pause(controlNo: int):
	_rpc_player_call_pause(controlNo)
	if AutoLoad.check_is_multigame() and AutoLoad.playerNo != 0:
		rpc_id(1, "_rpc_player_call_pause", controlNo)
	return

remote func _rpc_player_call_pause(controlNo: int):
	var pause_list = DataManager.get_env_int_array("白兵.呼叫暂停")
	if not pause_list.has(controlNo):
		pause_list.append(controlNo);
	DataManager.set_env("白兵.呼叫暂停", pause_list)
	return

func toggle_units_hp():
	var show = DataManager.get_env_int("显示白兵血量") > 0
	show_units_hp( not show)
	return


func show_units_hp(b: bool, updateFlag: bool = true):
	if updateFlag:
		DataManager.set_env("显示白兵血量", 1 if b else 0)
	for unit_node in units_layer.get_children():
		unit_node.hp_show = b
	return
	
func update_status_bar():
	var bf = DataManager.get_current_battle_fight()
	if bf == null:
		return
	var sign_char: String
	var buffs = ["混乱", "全军死战"]
	var wa
	var sp: Sprite

	
	var lblRound = get_node("top_scene_color2/lblRound")
	lblRound.text = str(bf.turns())
	lblRound.show()
	
	sign_char = "+"
	wa = bf.get_attacker()
	if wa.battle_morale_patched < 0: sign_char = ""
	else: sign_char = "+"
	get_node("top_scene_color2/lblLeft").text = "士气: {0} ({1}{2})".format([
		wa.battle_morale - wa.battle_morale_patched, sign_char, wa.battle_morale_patched
	])
	sp = get_node("top_scene_color2/spLeft")
	sp.hide()
	for i in range(buffs.size()):
		var buff = wa.get_buff(buffs[i])
		if buff["回合数"] <= 0: continue
		sp.texture = self.buff_textures[i]
		sp.show()
		break

	
	sign_char = "+"
	wa = bf.get_defender()
	if wa.battle_morale_patched < 0: sign_char = ""
	else: sign_char = "+"
	get_node("top_scene_color2/lblRight").text = "士气: {0} ({1}{2})".format([
		wa.battle_morale - wa.battle_morale_patched, sign_char, wa.battle_morale_patched
	])
	sp = get_node("top_scene_color2/spRight")
	sp.hide()
	for i in range(buffs.size()):
		var buff = wa.get_buff(buffs[i])
		if buff["回合数"] <= 0: continue
		sp.texture = self.buff_textures[i]
		sp.show()
	return

func _on_Timer_timeout() -> void :
	if not unit_created:
		init_units()
	if not unit_updated:
		update_units()
	update_status_bar()
	return

func show_battle_log() -> void :
	battle_log.prepare()
	battle_log.show()
	return

func process_battle_log() -> bool:
	if not battle_log.visible:
		if Input.is_action_just_pressed("EMU_SELECT"):
			show_battle_log()
			return true
		return false
	if Input.is_action_just_pressed("EMU_SELECT"):
		show_battle_skill()
		return true
	if Global.is_action_pressed_BY():
		close_battle_log()
		return true
	if Global.is_action_pressed_Left():
		battle_log.scroll_page_up()
	if Global.is_action_pressed_Right():
		battle_log.scroll_page_down()
	if Global.is_action_pressed_Up():
		battle_log.scroll_up()
	if Global.is_action_pressed_Down():
		battle_log.scroll_down()
	return true

func close_battle_log() -> void :
	battle_log.close_all()
	return

func show_battle_skill() -> void :
	battle_log.show_skill()
	return

func valid_unit_position(pos: Vector2) -> bool:
	if pos.x < 0 or pos.x >= cell_columns:
		return false
	if pos.y < 0 or pos.y >= cell_rows:
		return false
	return true

func move_cursor_to(pos: Vector2) -> void :
	cursor_position = pos
	cursor.rect_position = $battle_map.rect_position + map_layer.rect_position + pos * block_size * map_layer.rect_scale
	cursor.show()
	return

func hide_cursor() -> void :
	cursor.hide()
	return

func mark_selectable_positions(positions: PoolVector2Array) -> void :
	marked_positions = positions
	update_selectable_positions()
	return

func update_selectable_positions() -> void :
	Global.clearNode(mark_layer)
	mark_layer.visible = not marked_positions.empty()
	for pos in marked_positions:
		var rect = get_node("example_choose").duplicate()
		rect.color = "#60F00000"
		rect.rect_position = pos * block_size
		rect.visible = true
		mark_layer.add_child(rect)
	return

func reset_layout_landscape():
	rect_position = Vector2(212, 0)
	rect_scale = Vector2(1, 1)
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.70666, 1.6)
	return

func clear_prev_notice() -> void :
	if noticeTimer != null:
		if noticeTimer.time_left > 0:
			noticeTimer.disconnect("timeout", self, "notice_timeout")
		noticeTimer = null
	if noticeTween != null:
		if noticeTween.is_active():
			noticeTween.stop_all()
		noticeTween.queue_free()
		noticeTween = null
	return

func notice(msg: String) -> void :
	clear_prev_notice()

	notice.bbcode_enabled = true
	notice.bbcode_text = "[center]" + msg + "[/center]"
	notice.modulate = Color(1, 1, 1, 1)
	notice.show()

	var duration = 2.0 * Engine.time_scale
	noticeTimer = get_tree().create_timer(duration)
	noticeTimer.connect("timeout", self, "notice_timeout")
	return

func notice_timeout() -> void :
	noticeTween = Tween.new()
	add_child(noticeTween)
	var duration = 0.5 * Engine.time_scale
	noticeTween.interpolate_property(
		notice, "modulate", 
		Color(1, 1, 1, 1), Color(1, 1, 1, 0), 
		duration, Tween.TRANS_LINEAR, Tween.EASE_IN_OUT
	)
	noticeTween.start()
	noticeTween.connect("tween_completed", self, "notice_fadeout")
	return

func notice_fadeout(obj, key):
	notice.hide()
	clear_prev_notice()
	return

func notice_tactic(wa: War_Actor, tactic: String) -> void :
	var notice = "[color=yellow]{0}[/color]发动「[color=yellow]{1}[/color]」".format([
		wa.get_name(), tactic, 
	])
	notice(notice)
	return


func play_flood(unit: Battle_Unit, targets: Array, damage: int) -> void :
	if targets.empty():
		return
	set_process(false)
	var se = "res://resource/sounds/se/flood.ogg"
	SoundManager.play_se2(se, 0.0)
	Global.wait(1.0 * Engine.time_scale, self, "flood_done", [unit, targets, damage])
	var node = get_unit_node(unit.unitId)
	node.animation_hurt.playback_speed = 1.0 / Engine.time_scale
	node.animation_hurt.play("flood")
	return

func flood_done(unit: Battle_Unit, targets: Array, damage: int) -> void :
	var node = get_unit_node(unit.unitId)
	node.animation_hurt.playback_speed = 1.0
	for bu in targets:
		bu.add_status_effect("水龙 -{0}#FF0000".format([damage]))
		bu.set_hp(bu.get_hp() - damage)
		DataManager.damage_sodiers(unit.leaderId, bu.leaderId, damage)
	update_units()
	set_process(true)
	return


func play_fire(actorId: int, targets: Array, damage: int) -> void :
	if targets.empty():
		return
	set_process(false)
	var bu = targets.pop_front()
	if bu == null:
		return
	var node = get_unit_node(bu.unitId)
	if node == null:
		return
	var se = "res://resource/sounds/se/fire.ogg"
	SoundManager.play_se2(se, 0.0)
	Global.wait(0.8 * Engine.time_scale, self, "fire_done", [actorId, bu, targets, damage])
	node.animation_hurt.playback_speed = 1.0 / Engine.time_scale
	node.animation_hurt.play("fire")
	return

func fire_done(actorId: int, bu: Battle_Unit, targets: Array, damage: int) -> void :
	var node = get_unit_node(bu.unitId)
	node.animation_hurt.play("hurt")
	node.animation_hurt.playback_speed = 1.0
	bu.add_status_effect("火神 -{0}#FF0000".format([damage]))
	bu.set_hp(bu.get_hp() - damage, true)
	DataManager.damage_sodiers(actorId, bu.leaderId, damage)
	if targets.empty():
		update_units()
		set_process(true)
		return
	play_fire(actorId, targets, damage)
	return


func play_thunder(actorId: int, targets: Array, damage: int) -> void :
	if targets.empty():
		return
	set_process(false)
	var bu = targets.pop_front()
	if bu == null:
		return
	var node = get_unit_node(bu.unitId)
	if node == null:
		return
	var se = "res://resource/sounds/se/lightning.ogg"
	SoundManager.play_se2(se, 0.0)
	Global.wait(0.8 * Engine.time_scale, self, "thunder_done", [actorId, bu, targets, damage])
	node.animation_hurt.playback_speed = 1.0 / Engine.time_scale
	node.animation_hurt.play("lightning")
	return

func thunder_done(actorId: int, bu: Battle_Unit, targets: Array, damage: int) -> void :
	var node = get_unit_node(bu.unitId)
	node.animation_hurt.play("hurt")
	node.animation_hurt.playback_speed = 1.0
	bu.add_status_effect("落雷 -{0}#FF0000".format([damage]))
	bu.set_hp(bu.get_hp() - damage, true)
	update_units()
	DataManager.damage_sodiers(actorId, bu.leaderId, damage)
	if targets.empty():
		set_process(true)
		return
	if not Global.get_rate_result(75):
		set_process(true)
		return
	damage = int(ceil(damage * 0.75))
	if damage <= 0:
		set_process(true)
		return
	play_thunder(actorId, targets, damage)
	return


func play_rock(bu: Battle_Unit) -> void :
	SoundManager.play_se2("res://resource/sounds/se/rock.ogg", 0.0)
	var damage = DataManager.get_env_int("战斗.激石.伤害")
	var heroDamage = int(ceil(damage / 5))
	var offsets = DataManager.get_env_int_array("战斗.激石.位置")
	var results = []
	var rocks = 0
	for off in offsets:
		var x = off * block_size - block_size / 4 * 3
		for y in [0, 400]:
			var rock = ROCK.instance()
			rock.from = Vector2(x, y)
			if y > 0:
				rock.direction = Vector2.UP
			rock.distance = 180
			
			var checkings = range(0, 5)
			if y > 0:
				checkings = range(9, 4, - 1)
			for i in checkings.size():
				var pos = Vector2(off, checkings[i])
				var hit = DataManager.get_battle_unit_by_position(pos)
				if hit == null or hit.disabled or hit.leaderId == bu.unitId:
					continue
				var unitType = hit.get_unit_type()
				if unitType in ["城门"]:
					continue
				
				rock.distance -= 40 * (5 - i)
				if unitType == "将":
					if heroDamage > 0:
						results.append([hit.unitId, heroDamage])
				else:
					results.append([hit.unitId, damage])
					DataManager.damage_sodiers(bu.leaderId, hit.leaderId, damage)
				break
			add_child(rock)
			rock.connect("done", self, "rock_done")
			rocks += 1
			rock.play()
	DataManager.set_env("战斗.激石.数量", rocks)
	DataManager.set_env("战斗.激石.结果", results)
	set_process(false)
	return

func rock_done() -> void :
	var rocks = DataManager.get_env_int("战斗.激石.数量")
	rocks -= 1
	DataManager.set_env("战斗.激石.数量", rocks)
	if rocks > 0:
		return
	var bf = DataManager.get_current_battle_fight()
	for r in DataManager.get_env_array("战斗.激石.结果"):
		var bu = bf.battle_unit(r[0])
		if bu == null or bu.disabled:
			continue
		var damage = int(r[1])
		bu.add_status_effect("激石-{0}#FF0000".format([damage]))
		bu.set_hp(bu.get_hp() - damage, true)
	set_process(true)
	return

func highlight_unit(unitId: int = - 1) -> void :
	var bf = DataManager.get_current_battle_fight()
	var currentId = bf.get_env_int("当前状态单位")
	if unitId == currentId:
		return
	bf.set_env("当前状态单位", unitId)
	var bu = null
	if unitId >= 0:
		bu = bf.battle_unit(unitId)

	if bu == null or bu.disabled:
		focusMask.hide_mask()
		battle_unit_status.show_status(null)
		battle_state.show()
		return

	var pos = bu.unit_position * block_size + Vector2(0, block_size * 0.25)
	var region = Vector2(block_size, block_size) * 1.1
	battle_state.hide()
	battle_unit_status.show_status(bu)
	focusMask.show_mask(pos, region)
	return
