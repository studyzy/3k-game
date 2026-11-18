extends Control

onready var color_rect = get_node("ColorRect");
onready var tool_button = get_node("ToolButton");

var _picked = false;


func _ready() -> void :
	set_picked(false);
	pass


func set_picked(b: bool):
	_picked = b;
	if (b):
		color_rect.color = Color("c60010ff")
	else:
		color_rect.color = Color("FFFFFFFF");
	pass
