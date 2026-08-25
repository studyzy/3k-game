# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/Dialog.gd
# 说明：通用对话框 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

onready var conOrderbook = get_node("conOrderbook");
onready var conActor = get_node("conActor");
onready var nprFace = get_node("conActor/nprFace");
onready var lblName = get_node("conActor/lblName");
onready var rtlMessage = get_node("rtlMessage");
onready var confirm_curosr = get_node("confirm_curosr");
onready var animationPlayer = get_node("AnimationPlayer");
onready var lsc = get_node("lsc");


var mood: int = 2;
var mouth: bool = false;
var show_confirm_curosr: bool;
var face_animation = false;
var is_yn = false;
var parms: Dictionary
var _actorId = - 1;

var _msg_wait = [];


func _ready() -> void :
	conActor.visible = false;
	rtlMessage.text = ""
	return

func _load_base(msg: String, actorId: int, _mood: int, _show_confirm_curosr: bool, show_avatar_anyway: bool = false):
	mood = _mood;
	msg = msg.replace("\\n", "\n");
	rtlMessage.percent_visible = 0;
	_actorId = actorId;
	rtlMessage.rect_scale = Vector2(1, 1);
	is_yn = false;
	lsc.visible = false;
	conOrderbook.visible = false;
	self.show_confirm_curosr = _show_confirm_curosr;
	animationPlayer.stop();
	confirm_curosr.visible = false;
	rtlMessage.text = msg
	if not show_avatar_anyway and (int(actorId) < 0 and actorId != - 5):
		conActor.visible = false;
		if ("scene_affiars.tscn" in SceneManager.current_scene_path):
			conOrderbook.visible = DataManager.show_orderbook;
			conOrderbook.update_orderbook();
	else:
		conActor.visible = true;
		nprFace.set_actor(actorId, mood)
		lblName.text = ActorHelper.actor(actorId).get_name()
	if (msg == ""):
		rtlMessage.percent_visible = 1
		return

	var total_time = rtlMessage.text.length() * SceneManager.word_unittime
	
	face_animation = true;
	$Tween.interpolate_property(rtlMessage, "percent_visible", 0, 1, total_time, Tween.TRANS_LINEAR, Tween.EASE_OUT);
	$Tween.start();

func load_confirm_dialog(msg: String, actorId: int = - 1, _mood: int = 2, show_avatar_anyway: bool = false):
	_load_base(msg, actorId, _mood, true, show_avatar_anyway);
	pass

func load_confirm_dialogs(msg_array: Array, actorId: int = - 1, _mood: int = 2):
	var msg = msg_array.pop_front();
	_load_base(msg, actorId, _mood, true);
	_msg_wait = msg_array.duplicate();
	return

func load_unconfirm_dialog(msg: String, actorId: int = - 1, _mood: int = 2):
	_load_base(msg, actorId, _mood, false);
	pass

func load_confirm_yn(msg: String, actorId: int = - 1, _mood: int = 2, options: PoolStringArray = ["是", "否"]):
	_load_base(msg, actorId, _mood, false);
	lsc.set_cursor(0);
	lsc.cursor.show();
	lsc.visible = true;
	is_yn = true;
	lsc.columns = 2
	lsc.set_items_text(0, options[0])
	lsc.set_items_text(1, options[1])
	if options[0].length() + options[1].length() > 8:
		lsc.columns = 1
	lsc._set_data()
	if lsc.columns == 1:
		lsc.rect_position = Vector2(193, 100)
	else:
		lsc.rect_position = Vector2(193, 142)
	return

func load_affiars_vstateshow(msg: String):
	_load_base(msg, - 1, 2, false);
	conOrderbook.visible = false;
	rtlMessage.rect_scale = Vector2(1.2, 1.2);

func _on_Tween_tween_all_completed() -> void :
	face_animation = false;
	if (show_confirm_curosr):
		animationPlayer.play("confirm_cursor");
	return


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
	
	if not _msg_wait.empty():
		load_confirm_dialog(_msg_wait.duplicate(), _actorId, mood);
		return false;
	return true;

func move_left():
	lsc.move_left();

func move_right():
	lsc.move_right();

func move_up():
	lsc.move_up();

func move_down():
	lsc.move_down();

func _on_AnimationPlayer_animation_finished(anim_name: String) -> void :
	if (anim_name == "confirm_cursor"):
		pass

var _process_d = 0
func _process(delta: float) -> void :
	
	if _actorId < 0 and _actorId != StaticManager.ACTOR_ID_SLIME_GOD:
		return
	_process_d += 1 * delta;
	if (_process_d >= 0.15):
		_process_d = 0;
		mouth = not mouth;
		if (mouth):
			if ( not face_animation):
				_actorId = - 1;
				return ;
		nprFace.mouth = mouth;
	return

func update_message(msg: String) -> void :
	rtlMessage.text = msg
	return
