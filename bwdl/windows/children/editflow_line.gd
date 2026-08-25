# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/children/editflow_line.gd
# 说明：流程编辑连线子控件。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

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
