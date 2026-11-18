extends Control

var _name_array: PoolStringArray;
var _max_array: PoolIntArray;
var _min_position: PoolIntArray;
var _max_position: PoolIntArray;

onready var gv = get_node("CenterContainer/gv")
onready var rtlMessage = get_node("rtlMessage")
onready var rtlMessage2 = get_node("rtlMessage2")
onready var conOrderbook = get_node("conOrderbook")
onready var conActor = get_node("conActor")
var input_index = 0;


func _ready() -> void :
	rtlMessage.percent_visible = 0
	
	
	return

func init_data(name_array: PoolStringArray, max_array: PoolIntArray = [0, 0, 0, 0], min_position: PoolIntArray = [0, 0, 0, 0], max_position = [4, 4, 4, 4]):
	show_orderbook(name_array.size() == 1)
	conActor.hide()
	speak2("")
	while max_array.size() < name_array.size():
		max_array.append(0)
	
	while min_position.size() < name_array.size():
		min_position.append(0);
	
	while max_position.size() < name_array.size():
		max_position.append(4)

	
	for i in range(max_array.size()):
		var val: int = max_array[i]
		var p: int = 0
		while val > 0:
			val = val / 10
			p += 1
		if max_position[i] > p - 1:
			max_position[i] = p - 1

	_name_array = PoolStringArray(name_array);
	_max_array = PoolIntArray(max_array);
	_min_position = PoolIntArray(min_position);
	_max_position = PoolIntArray(max_position);

	for node_input in gv.get_children():
		node_input.twinkle = false;
		node_input.hide();
	
	for i in min(4, name_array.size()):
		var input = gv.get_node_or_null("input" + str(i));
		if ( not is_instance_valid(input)):
			continue;
		input.input_name = str(name_array[i]);
		input.max_number = int(max_array[i]);
		input.min_number_position = input.array_position[int(min_position[i])];
		input.current_cursor_position = input.array_position[int(min_position[i])];
		input.max_number_position = input.array_position[int(max_position[i])];
		input.init_data(self);
		input.set_process(true)
		input.show();
	set_current_input_index(0);
	return

func speak2(text: String):
	rtlMessage2.bbcode_text = "[center]" + text + "[/center]";

func speak(text: String):
	rtlMessage.text = text;
	
	var total_time = text.length() * SceneManager.word_unittime;
	$Tween.interpolate_property(rtlMessage, "percent_visible", 0, 1, total_time, Tween.TRANS_LINEAR, Tween.EASE_OUT);
	$Tween.start();

func show_orderbook(b: bool):
	conOrderbook.visible = b
	conOrderbook.update_orderbook()

func show_actor(actorId: int):
	show_orderbook(false)
	var actor = ActorHelper.actor(actorId)
	conActor.get_node("lblName").text = actor.get_name()
	conActor.get_node("nprFace").set_actor(actorId)
	conActor.show()
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

func get_current_input_node():
	return gv.get_node("input" + str(input_index));

func set_current_input_index(index: int) -> bool:
	if index >= min(4, _name_array.size()):
		return false;
	if index < 0:
		return false;
	input_index = index;
	for i in min(4, _name_array.size()):
		var input = gv.get_node_or_null("input" + str(i));
		input.twinkle = (i == input_index);
	
	return true;

func next_input_index() -> bool:
	return set_current_input_index(input_index + 1);

func pre_input_index() -> bool:
	return set_current_input_index(input_index - 1);

func is_last_input() -> bool:
	if _name_array.size() == 1:
		return true
	return input_index > 0 and input_index == _name_array.size() - 1

func _on_Control_hide():
	for child in gv.get_children():
		child.set_process(false)
	return

func get_numbers() -> PoolIntArray:
	var ret = []
	for i in min(4, _name_array.size()):
		var node = gv.get_node_or_null("input" + str(i))
		if node == null:
			break
		ret.append(node.get_number())
	return ret
