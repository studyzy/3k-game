tool
extends Control


export (String, "个", "十", "百", "千", "万") var min_number_position = "个";

export (String, "个", "十", "百", "千", "万") var max_number_position = "万";
export (String) var input_unit = "";
export (String) var input_name = "";

export (String, "个", "十", "百", "千", "万") var current_cursor_position = "个";

export (bool) var twinkle = true;

const array_position = ["个", "十", "百", "千", "万"];
onready var dic_label = {
	"个": get_node("HFlowContainer/number1"), 
	"十": get_node("HFlowContainer/number10"), 
	"百": get_node("HFlowContainer/number100"), 
	"千": get_node("HFlowContainer/number1000"), 
	"万": get_node("HFlowContainer/number10000"), 
}

export var max_number = 99999;
export var min_number = 0;

var parent: Control = null


func _ready() -> void :
	set_process(false)
	return

func init_data(_parent: Control):
	parent = _parent
	
	set_number(0, true);
	get_node("lblName").text = input_name;
	get_node("lblUnit").text = input_unit;
	return


func cursor_move_left() -> bool:
	var index: int = array_position.find(current_cursor_position);
	var max_index: int = array_position.find(max_number_position);
	index += 1;
	if (index > max_index):
		set_number(max_number);
		return false;
	current_cursor_position = array_position[index];
	if (AutoLoad.check_is_multigame()):
		rpc("_fpc_set_cursor_position", current_cursor_position);
	return true;
	

func cursor_move_right() -> bool:
	var index: int = array_position.find(current_cursor_position);
	var min_index: int = array_position.find(min_number_position);
	index -= 1;
	if (index < min_index):
		set_number(min_number);
		return false;
	current_cursor_position = array_position[index];
	if (AutoLoad.check_is_multigame()):
		rpc("_fpc_set_cursor_position", current_cursor_position);
	return true;

remote func _fpc_set_cursor_position(position):
	current_cursor_position = position;


func set_number(number: int, reposition_to_min = false):
	var min_index: int = array_position.find(min_number_position);
	var fix = pow(10, min_index);
	
	number = int(int(number / fix) * fix);
	
	_rpc_set_number(number, reposition_to_min);
	if (AutoLoad.check_is_multigame()):
		rpc("_rpc_set_number", number, reposition_to_min);

remote func _rpc_set_number(number: int, reposition_to_min):
	var str_number = str(number);
	while (true):
		if (len(str_number) < array_position.size()):
			str_number = "0" + str_number;
		else:
			break;
			
	for i in array_position.size():
		
		var self_number = str_number.substr(len(str_number) - 1 - i, 1);
		var key = array_position[i];
		dic_label[key].text = self_number;
	
	if (reposition_to_min):
		current_cursor_position = min_number_position;


func get_number() -> int:
	var result = 0;
	for i in array_position.size():
		var label: Label = dic_label[array_position[i]];
		var number: int = int(dic_label[array_position[i]].text);
		result += number * int(label.name.replace("number", ""));
	return result;
	

func cursor_number_up():

	var index: int = array_position.find(current_cursor_position);
	var label: Label = dic_label[array_position[index]];
	var p = int(label.name.replace("number", ""));
	var new_number = get_number() + p;
	
	if (new_number <= max_number):
		set_number(new_number);


func cursor_number_down():

	var index: int = array_position.find(current_cursor_position);
	var label: Label = dic_label[array_position[index]];
	var p = int(label.name.replace("number", ""));
	var new_number = get_number() - p;
	
	if (new_number >= min_number):
		set_number(new_number);

var cursor_twink_num = 0;
func _process(delta: float) -> void :
	if parent == null or not parent.visible:
		return

	if Engine.editor_hint:
		return

	cursor_twink_num += 1
	var total_number = get_number();
	
	var index: int = array_position.find(current_cursor_position);
	var index2: int = array_position.find(min_number_position);

	for i in array_position.size():
		
		var temp_label: Label = dic_label[array_position[i]];
		if (twinkle):
			if (i == index):
				if (cursor_twink_num > 20):
					cursor_twink_num = 0;
					temp_label.visible = not temp_label.visible;
			elif (i < index or i < index2):
				temp_label.visible = true;
			else:
				if (len(str(total_number)) - 1 < i):
					temp_label.visible = false;
				else:
					temp_label.visible = true;
		else:
			temp_label.visible = len(str(int(total_number))) - 1 >= i;
	return
