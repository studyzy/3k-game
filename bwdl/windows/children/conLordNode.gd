# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/children/conLordNode.gd
# 说明：君主节点子控件。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

tool
extends Control

export (int) var vstateId = - 1;
export (float) var scale = 1;
export (String) var vstate_name = "";

onready var lbllordName = get_node("LordName");
onready var lblcityNums = get_node("cityNums");
onready var Big = get_node("Big");


func _ready() -> void :
	rect_scale.x = scale;
	rect_scale.y = scale;
	if (vstateId == - 1):
		Big.visible = false;
		set_lord_name(vstate_name);
		lblcityNums.visible = false;
		return ;
	var vstate = clVState.vstate(vstateId)
	if (vstate_name == ""):
		vstate_name = vstate.get_lord_name()

	set_lord_name(vstate_name);
	var citys = DataManager.get_city_num_by_vstate(vstateId)
	citys = max(citys, 1)
	lblcityNums.text = "×{0}".format([citys])
	Big.texture = Global.load_pic("res://resource/images/vassalIcon/{0}_BIG.png".format([vstateId]));
	return

# 名字超过 4 个字时按总宽度不超过 4 字（120px）等比缩小字号，字越多字号越小
func set_lord_name(text: String) -> void :
	lbllordName.text = text;
	var length = text.length();
	if (length > 4):
		var font: DynamicFont = lbllordName.get_font("font").duplicate();
		font.size = max(15, int(120.0 / length));
		lbllordName.add_font_override("font", font);
	return
