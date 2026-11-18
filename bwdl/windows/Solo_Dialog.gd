extends Control

onready var conleft = get_node("left");
onready var conright = get_node("right");
onready var rtlMessage = get_node("rtlMessage");
onready var confirm_curosr = get_node("confirm_curosr");
onready var animationPlayer = get_node("AnimationPlayer");


var mood: int = 2;
var mouth: bool = false;
var show_confirm_curosr: bool;
var face_animation = false;

var dic_con_actor = {};

var current_speak_actorId = 0;

var parms: Dictionary


func _ready() -> void :
	rtlMessage.text = ""
	get_node("right/nprFace/nprFace").rect_scale.x = - 1
	return

func load_dialog(msg: String, actorId: int, _mood: int) -> void :
	var sf = DataManager.get_current_solo_fight()

	rtlMessage.percent_visible = 0
	current_speak_actorId = actorId
	dic_con_actor = {}
	
	dic_con_actor[sf.leftId] = conleft
	dic_con_actor[sf.rightId] = conright

	current_speak_actorId = actorId
	rtlMessage.rect_scale = Vector2(1, 1)
	show_confirm_curosr = true
	animationPlayer.stop()
	confirm_curosr.visible = false
	rtlMessage.text = msg

	for aid in [sf.leftId, sf.rightId]:
		if current_speak_actorId == aid:
			__load_actor(aid, _mood, false)
		else:
			__load_actor(aid, 2, false)
	mouth = false
	mood = _mood

	if msg == "" or actorId == - 1:
		return

	set_process(true)
	var totalTime = rtlMessage.text.length() * SceneManager.word_unittime
	face_animation = true
	$Tween.interpolate_property(
		rtlMessage, 
		"percent_visible", 
		0, 
		1, 
		totalTime, 
		Tween.TRANS_LINEAR, 
		Tween.EASE_OUT)
	$Tween.start()
	return

func __load_actor(actorId: int, mood: int, mouth: bool) -> void :
	if actorId < 0:
		return

	var conActor: Control = dic_con_actor[actorId]
	var nprFace = conActor.get_node("nprFace")
	var lblName: Label = conActor.get_node("lblName");
	nprFace.set_actor(actorId, mood);
	lblName.text = ActorHelper.actor(actorId).get_name()
	nprFace.mouth = mouth;

func _on_Tween_tween_all_completed() -> void :
	face_animation = false;
	__load_actor(current_speak_actorId, mood, false);
	if (show_confirm_curosr):
		animationPlayer.play("confirm_cursor");
	pass


func _on_Tween_tween_step(object: Object, key: NodePath, elapsed: float, value: Object) -> void :
	
	pass


func show_all_msg() -> void :
	var tween: Tween = get_node("Tween");
	if (tween.is_active()):
		tween.seek(tween.get_runtime());


func is_msg_complete():
	var tween: Tween = get_node("Tween");
	if (tween.is_active()):
		return false;
	return true;


func _on_AnimationPlayer_animation_finished(anim_name: String) -> void :
	if (anim_name == "confirm_cursor"):
		pass

var _process_d = 0
func _process(delta: float) -> void :
	if (dic_con_actor.empty()):
		return ;
	_process_d += 1 * delta;
	if (_process_d >= 0.15):
		_process_d = 0;
		var temp = 0;
		mouth = not mouth;
		if (mouth):
			temp = 1;
		else:
			if ( not face_animation):
				set_process(false);
		__load_actor(current_speak_actorId, mood, mouth);
	return
