# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/dialog_top.gd
# 说明：对话框顶部 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends ColorRect

onready var lsc = get_node("lsc");
onready var label = get_node("Label");

var om_list = {
	"yes": null, 
	"no": null
};


func _ready() -> void :
	pass

func init_data(text: String):
	label.text = text;
	show();
	pass
	
func bind_yes(_obj, _method):
	var om = ObjMethod.new();
	om.obj = _obj;
	om.method = _method;
	om_list["yes"] = om;

func bind_no(_obj, _method):
	var om = ObjMethod.new();
	om.obj = _obj;
	om.method = _method;
	om_list["no"] = om;

	
func _process(delta: float) -> void :
	if not visible:
		return
	if (Input.is_action_just_pressed("ANALOG_LEFT")):
		lsc.move_left();
	if (Input.is_action_just_pressed("ANALOG_RIGHT")):
		lsc.move_right();
	if (Input.is_action_just_pressed("EMU_A")):
		match lsc.cursor_index:
			0:
				var om: ObjMethod = om_list["yes"];
				if (om == null):
					return ;
				om.excute()
			1:
				var om: ObjMethod = om_list["no"];
				if (om == null):
					return ;
				om.excute()
		hide();
	if (Input.is_action_just_pressed("EMU_B")):
		hide();
	pass
