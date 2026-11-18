extends Control

export var defaultFontSize = 35

onready var lsc = get_node("lsc");
onready var rtlMessage = get_node("rtlMessage");
onready var conOrderbook = get_node("conOrderbook");
onready var conActor = get_node("conActor");
onready var nprFace = get_node("conActor/nprFace");
onready var lblName = get_node("conActor/lblName");
onready var txtDescription = get_node("txtDescription")


var mood: int = 2;
var mouth: bool = false;
var face_animation = false;
var _actorId = - 1;

func _ready() -> void :
	return

func show_msg(text: String, offset: Vector2 = Vector2.ZERO, fontSize: int = - 1):
	if fontSize < 0:
		fontSize = defaultFontSize
	var location = Vector2(158, 13) + offset
	rtlMessage.text = text;
	rtlMessage.percent_visible = 0;
	rtlMessage.rect_position = location;
	rtlMessage.set("custom_fonts/normal_font", Global.get_font(fontSize))
	var total_time = text.length() * SceneManager.word_unittime;
	
	face_animation = true;
	txtDescription.hide();
	$Tween.interpolate_property(rtlMessage, "percent_visible", 0, 1, total_time, Tween.TRANS_LINEAR, Tween.EASE_OUT);
	$Tween.start();
	return

func show_orderbook(b: bool):
	conOrderbook.update_orderbook();
	conOrderbook.visible = b
	return


func set_lsc(offset: Vector2 = Vector2.ZERO, separation: Vector2 = Vector2(210, 40)):
	var position = Vector2(173, 55) + offset
	lsc.rect_position = position
	lsc.h_separation = separation.x
	lsc.v_separation = separation.y
	conActor.visible = false
	return


func set_actor_lsc(actorId: int, offset: Vector2 = Vector2.ZERO, separation: Vector2 = Vector2(210, 40)):
	show_orderbook(false);
	set_lsc(offset, separation)
	mouth = false;
	_actorId = actorId;
	conActor.visible = true;
	nprFace.set_actor(actorId);
	lblName.text = ActorHelper.actor(actorId).get_name()
	return


func show_all_msg() -> void :
	_rpc_show_all_msg();
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_show_all_msg");

remote func _rpc_show_all_msg():
	var tween: Tween = get_node("Tween");
	if (tween.is_active()):
		tween.seek(tween.get_runtime());


func is_msg_complete():
	var tween: Tween = get_node("Tween");
	if (tween.is_active()):
		return false;
	return true;
	
func _on_Tween_tween_all_completed() -> void :
	face_animation = false;
	nprFace.mouth = false;
	return

var _process_d = 0
func _process(delta: float) -> void :
	
	if (_actorId >= 0):
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

func show_top_description(description: String):
	txtDescription.show();
	txtDescription.bbcode_text = description;
