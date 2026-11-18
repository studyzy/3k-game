extends Control

onready var cursor = get_node("cursor");
onready var container = get_node("container");
onready var rtlMessage = get_node("rtlMessage");
onready var BobCeil = get_node("container/conBarrack/BobCeil");
onready var BobHorse = get_node("container/conFair/BobHorse");
onready var BobSkill = get_node("container/conBarrack/BobSkill")

export (int) var cursor_index = 0;
var current_info: int = 0;
var items: Array = []

var containerPosition = Vector2(338, 462)



func _ready() -> void :
	init_rpg_actor_info();
	var city = clCity.city(DataManager.player_choose_city)
	
	cursor_index = 0
	BobCeil.visible = not city.get_ceil_actor_ids().empty()

	
	BobSkill.visible = false
	if not BobCeil.visible:
		var sc = Global.load_script("res://resource/sgz_script/affiars/barrack_skills.gd")
		if not sc.get_skills(true).empty():
			BobSkill.visible = true
	
	BobHorse.visible = city.selling_special_horse()
	
	show_cityInfo(0)
	return

func init_data(operation: bool) -> void :
	if operation:
		$rtlMessage.text = "往何处去？"
		var total_time = $rtlMessage.text.length() * SceneManager.word_unittime;
		$Tween.interpolate_property(rtlMessage, "percent_visible", 0, 1, total_time, Tween.TRANS_LINEAR, Tween.EASE_OUT);
		$Tween.start();
		items = ["", "", "", "", ""]
		DataManager.recover_lsc_index(self)
		$cursor.show()
	else:
		var city = clCity.city(DataManager.player_choose_city)
		$rtlMessage.text = "此处为" + city.get_name()
		$cursor.hide()
	return

func _process(delta: float) -> void :
	UpdateCursor()


func UpdateCursor():
	var children = container.get_children()
	if children.empty():
		return
	if cursor_index < 0 or cursor_index >= children.size():
		cursor_index = 0
	var child = children[cursor_index]
	cursor.rect_position.x = container.rect_position.x + child.rect_position.x + 37
	return

remote func rpc_set_cursor_index(index: int):
	cursor_index = index;
	return

func move_up():
	var columns = container.get_child_count();
	var y = cursor_index / columns;
	var x = cursor_index % columns;
	y -= 1;
	if (y < 0):
		cursor_index = columns - 1;
		while (true):
			var y1 = cursor_index / columns;
			var x1 = cursor_index % columns;
			if (x == x1):
				break;
			cursor_index -= 1;
	else:
		cursor_index = y * columns + x;
	if (AutoLoad.check_is_multigame()):
		rpc("rpc_set_cursor_index", cursor_index);
	return

func move_down():
	var columns = container.get_child_count();
	var y = cursor_index / columns;
	var x = cursor_index % columns;
	y += 1;
	var newindex = y * columns + x;
	if (newindex >= columns):
		y = 0;
	cursor_index = y * columns + x;
	if (AutoLoad.check_is_multigame()):
		rpc("rpc_set_cursor_index", cursor_index);
	return

func move_left():
	var columns = container.get_child_count();
	var y = cursor_index / columns;
	var x = cursor_index % columns;
	x -= 1;
	if (x < 0):
		x = columns - 1;
	cursor_index = y * columns + x;
	while (cursor_index >= columns):
		x -= 1;
		cursor_index = y * columns + x;
	if (AutoLoad.check_is_multigame()):
		rpc("rpc_set_cursor_index", cursor_index);
	return

func move_right():
	var columns = container.get_child_count();
	var y = cursor_index / columns;
	var x = cursor_index % columns;
	x += 1;
	if (x >= columns):
		x = 0;
	var newindex = y * columns + x;
	if (newindex >= columns):
		x = 0;
	cursor_index = y * columns + x;
	if (AutoLoad.check_is_multigame()):
		rpc("rpc_set_cursor_index", cursor_index);
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

func show_cityInfo(type: int):
	current_info = type;
	DataManager.cityInfo_type = type;
	SceneManager.show_cityInfo(true);
	return

func init_rpg_actor_info():
	var controlNo = DataManager.get_current_control_sort()
	var p: Player = DataManager.players[controlNo];
	if (p != null and DataManager.game_mode == 1):
		rtlMessage.text = "职位:" + p.get_place() + "|权力:" + str(p.power_value);
	return

func reset_layout_portrait() -> void :
	return

func reset_layout_landscape() -> void :
	return
