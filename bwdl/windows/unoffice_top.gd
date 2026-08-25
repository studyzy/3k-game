# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/unoffice_top.gd
# 说明：在野武将顶部 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

onready var con = get_node("con");
onready var gc = get_node("GridContainer");


var words = [];

func _ready() -> void :

	pass
	
func _load_gridview():
	Global.clearNode(gc);
	for word in words:
		var c = con.duplicate();
		var lbltext: Label = c.get_node("Label");
		lbltext.text = str(word);
		c.show();
		gc.add_child(c);
	pass

func set_title(text: String):
	get_node("Label").text = text;
