extends Control

onready var lsc = get_node("lsc");
onready var status = get_node("status")

var portrait_mode: bool = false

func _ready() -> void :
	status.hide()


func set_lsc(offset: Vector2 = Vector2.ZERO, separation: Vector2 = Vector2(260, 42), rich: bool = false):
	lsc.rect_position = Vector2(60, 30) + offset
	lsc.h_separation = separation.x
	lsc.v_separation = separation.y
	lsc.rich = rich
	status.hide()
	set_memo("", false)
	set_TopMsg_visible(false)
	return

func set_memo(bbcode_msg: String, show_enumselect: bool = true):
	get_node("memo").bbcode_text = bbcode_msg
	get_node("EmuSelect").visible = show_enumselect
	return

func set_TopMsg_text(bbcode_msg: String):
	if bbcode_msg != get_node("top/content/msg").bbcode_text:
		get_node("top/content/msg").bbcode_text = bbcode_msg
		get_node("top/content").scroll_horizontal = 0
		get_node("top/content").scroll_vertical = 0
	return

func set_TopMsg_visible(b: bool):
	get_node("top").visible = b;

func get_TopMsg_visible():
	return get_node("top").visible;
