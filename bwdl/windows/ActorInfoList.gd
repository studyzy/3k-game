# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/ActorInfoList.gd
# 说明：武将信息列表 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

export (Array) var actors = [];

onready var con = get_node("con");
onready var vbox: VBoxContainer = get_node("con/VBoxContainer");
onready var rtlMessage = get_node("ColorRect/rtlMessage");
onready var actor_description = get_node("CanvasLayer/actor_description");

var tscn_actor_info = preload("res://windows/ActorInfo.tscn");

onready var btnShowSkill = SceneManager.get_node("Virtukey/VirtualKey/btnShowSkill")
onready var separation = vbox.get("custom_constants/separation")


var current_actor_index = 0;

var next_actor_offset = 0

const speed = 320;

var switchMode: bool = false

var hideSkillButton: bool = false


func _ready() -> void :
	_notification(NOTIFICATION_VISIBILITY_CHANGED)
	actor_description.hide()
	return

func _init_actors(update_msg: bool, msg: String, _switchMode: bool = true, _hideSkillButton: bool = false):
	switchMode = _switchMode
	hideSkillButton = _hideSkillButton
	set_process(false)
	var is_skill_model = DataManager.get_game_setting("技能系统") == "是"
	if not is_skill_model:
		btnShowSkill.text = "查看装备"
	else:
		btnShowSkill.text = "技能/装备"
	btnShowSkill.hide()
	switch_to_actor(actors[0])
	actor_description.reset_layout_landscape()
	if update_msg and get_node("ColorRect/rtlMessage").text != msg:
		speak(msg)
	elif msg != "":
		get_node("ColorRect/rtlMessage").text = msg
	if not hideSkillButton:
		Global.clear_signals(btnShowSkill, ["pressed"])
		btnShowSkill.connect("pressed", self, "show_skill")
		btnShowSkill.show()
	return

func speak(msg: String):
	get_node("ColorRect").visible = not msg.empty();
	get_node("ColorRect/rtlMessage").text = msg;
	if (msg.empty()):
		return ;
	var total_time = rtlMessage.text.length() * SceneManager.word_unittime;
	$Tween.interpolate_property(rtlMessage, "percent_visible", 0, 1, total_time, Tween.TRANS_LINEAR, Tween.EASE_OUT);
	$Tween.start();
	

func show_all_msg() -> void :
	on_show_all_msg();
	if (get_tree().network_peer != null):
		rpc("on_show_all_msg");

remote func on_show_all_msg() -> void :
	var tween: Tween = get_node("Tween");
	if (tween.is_active()):
		tween.seek(tween.get_runtime());


func is_msg_complete():
	var tween: Tween = get_node("Tween");
	if (tween.is_active() or rtlMessage.percent_visible == 0):
		return false;
	return true;

func get_current_actorId():
	if current_actor_index < 0 or current_actor_index >= actors.size():
		return - 1
	return actors[current_actor_index]

func is_rolling() -> bool:
	if next_actor_offset == 0:
		return false
	if actors.size() == 1:
		return false
	return true

func _physics_process(delta: float) -> void :
	if not visible:
		return
	if Input.is_action_just_pressed("EMU_SELECT"):
		if not btnShowSkill.visible:
			return
		Input.action_release("EMU_SELECT")
		show_skill()
	return

func _process(delta: float) -> void :
	if not is_rolling():
		set_process(false);
		if not hideSkillButton:
			btnShowSkill.show()
		return
	btnShowSkill.hide()
	var real_speed = Vector2(0, speed * delta);
	var current_position = vbox.rect_position;
	var target_positinon = current_position
	if next_actor_offset == 1:
		target_positinon = Vector2(0, - separation * 2)
	elif next_actor_offset == - 1:
		target_positinon = Vector2(0, 0)

	if (current_position.y > target_positinon.y):
		current_position -= real_speed;
		
		if (current_position.y < target_positinon.y):
			current_position = target_positinon;
	else:
		current_position += real_speed;
		
		if (current_position.y > target_positinon.y):
			current_position = target_positinon;
	
	if current_position.y == target_positinon.y:
		current_actor_index += next_actor_offset
		if current_actor_index < 0:
			current_actor_index = actors.size() - 1
		elif current_actor_index >= actors.size():
			current_actor_index = 0
		switch_to_actor(actors[current_actor_index])
		current_position = Vector2(0, - separation)
	vbox.rect_position = current_position
	return




func next_actor(recycle: bool = true) -> bool:
	if current_actor_index == actors.size() - 1 and not recycle:
		return false
	next_actor_offset = 1
	set_process(true)
	return true


func prev_actor():
	next_actor_offset = - 1
	set_process(true)
	return

func switch_to_actor(actorId: int, resumeProcess: bool = true) -> void :
	var found = actors.find(actorId)
	if found < 0:
		return
	set_process(false)
	
	var total = actors.size()
	var prev = found - 1
	if prev < 0:
		prev = total - 1
	var current = found
	var next = found + 1
	if next >= total:
		next = 0
	Global.clearNode(vbox)
	for idx in [prev, current, next]:
		var actorInfo = tscn_actor_info.instance()
		actorInfo.name = str(idx)
		actorInfo.pre_actorId = actors[idx]
		actorInfo.switchMode = switchMode
		vbox.add_child(actorInfo)
	current_actor_index = found
	next_actor_offset = 0
	vbox.rect_position.y = - separation
	if resumeProcess:
		set_process(true)
	return

func show_actor_description(actorId: int):
	if (actorId < 0):
		hide_actor_description()
		return ;
	actor_description.init_actor(actorId, actors)

func hide_actor_description():
	get_tree().paused = false;
	actor_description.hide();

func show_skill() -> void :
	var is_description_showing = actor_description.visible;
	if ( not is_description_showing):
		var actorId = get_current_actorId()
		if (actorId < 0):
			return ;
		show_actor_description(actorId);
	else:
		actor_description.back()
	return

func _on_Control_hide() -> void :
	btnShowSkill.hide()
	return

func reset_layout_landscape():
	rect_position = Vector2(212, 370)
	rect_scale = Vector2(1, 1)
	actor_description.reset_layout_landscape()
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 592)
	rect_scale = Vector2(1.70666, 1.6)
	actor_description.reset_layout_portrait()
	return

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_visible_in_tree():
			set_process(true)
			set_physics_process(true)
		else:
			set_process(false)
			set_physics_process(false)
	return
