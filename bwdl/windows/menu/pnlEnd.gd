# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/menu/pnlEnd.gd
# 说明：结束面板 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Panel

var cursor_index = 0;
onready var gv = get_node("gv");


onready var btn_items = [
	get_node("gv/btnBack"), 
	get_node("gv/btnTitle"), 
	get_node("gv/btnQuit"), 
]


func _ready() -> void :
	pass

func init():
	cursor_index = 0;
	update_color();
	

func move_up():
	var y = cursor_index / gv.columns;
	var x = cursor_index % gv.columns;
	y -= 1;
	if (y < 0):
		cursor_index = gv.get_child_count() - 1;
		while (true):

			var x1 = cursor_index % gv.columns;
			if (x == x1):
				break;
			cursor_index -= 1;
	else:
		cursor_index = y * gv.columns + x;

func move_down():
	var y = cursor_index / gv.columns;
	var x = cursor_index % gv.columns;
	y += 1;
	var newindex = y * gv.columns + x;
	if (newindex >= gv.get_child_count()):
		y = 0;
	cursor_index = y * gv.columns + x;

func move_left():
	var y = cursor_index / gv.columns;
	var x = cursor_index % gv.columns;
	x -= 1;
	if (x < 0):
		x = gv.columns - 1;
	cursor_index = y * gv.columns + x;
	while (cursor_index >= gv.get_child_count()):
		x -= 1;
		cursor_index = y * gv.columns + x;

func move_right():
	var y = cursor_index / gv.columns;
	var x = cursor_index % gv.columns;
	x += 1;
	if (x >= gv.columns):
		x = 0;
	var newindex = y * gv.columns + x;
	if (newindex >= gv.get_child_count()):
		x = 0;
	cursor_index = y * gv.columns + x;



func _process(delta: float) -> void :
	if ( not visible):
		return ;
	if (Input.is_action_just_pressed("ANALOG_UP")):
		move_up();
		update_color();
	if (Input.is_action_just_pressed("ANALOG_DOWN")):
		move_down();
		update_color();
	if (Input.is_action_just_pressed("ANALOG_LEFT")):
		move_left();
		update_color();
	if (Input.is_action_just_pressed("ANALOG_RIGHT")):
		move_right();
		update_color();
	if (Input.is_action_just_pressed("EMU_A")):
		Input.action_release("EMU_A");
		var btn: Button = btn_items[cursor_index];
		btn.emit_signal("pressed");
	if (Input.is_action_just_pressed("EMU_B")):
		_on_btnBack_pressed();

func update_color():
	for i in btn_items.size():
		var btn: Button = btn_items[i];
		if (i == cursor_index):
			btn.self_modulate = Color("#00ff22");
		else:
			btn.self_modulate = Color("#ffffff");
		


func _on_btnBack_pressed() -> void :
	hide();
	pass


func _on_btnTitle_pressed() -> void :
	
	if AutoLoad.check_is_multigame():
		return ;
	get_parent()._on_btnBackToGame_pressed();
	SceneManager.restart()
	return
	

func _on_btnQuit_pressed() -> void :
	get_tree().quit(0);
	return

func reset_layout_landscape() -> void :
	rect_position = Vector2(243, 92)
	rect_scale = Vector2(1, 1)
	return

func reset_layout_portrait() -> void :
	rect_position = Vector2(53, 330)
	rect_scale = Vector2(1.7066, 1.6)
	return
