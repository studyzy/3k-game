extends Control

const SCENE_ID = 0

onready var lsc = get_node("lsc")
onready var txtDescription = get_node("txtDescription")

var change_mode: bool = false

var OPTIONS: Array = []

var setting: Dictionary = {}

func _ready() -> void :
	if DataManager.get_env_int("修改游戏模式") == 1:
		change_mode = true
	OPTIONS = StaticManager.get_all_game_setting(DataManager.drama_path, change_mode)
	setting = StaticManager.get_default_game_setting(DataManager.drama_path, change_mode)
	SceneManager.load_scene_complete = true
	show_item()
	show_info()
	return

func _process(delta: float) -> void :
	if Input.is_action_just_pressed("ANALOG_UP"):
		lsc.move_up()
		show_info()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		lsc.move_down()
		show_info()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		lsc.move_left()
		show_info()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		lsc.move_right()
		show_info()
	if Input.is_action_just_pressed("EMU_A"):
		move_item_right()
		show_item()
	if Input.is_action_just_pressed("EMU_B"):
		move_item_left()
		show_item()
	if Input.is_action_just_pressed("EMU_START"):
		DataManager.game_set = setting.duplicate(true)
		if change_mode:
			FlowManager.add_flow("go_to_scene|res://scene/scene_affiars/scene_affiars.tscn");
			FlowManager.add_flow("load_script|affiars/temple_hope.gd")
			FlowManager.add_flow("change_mode_3")
		else:
			FlowManager.add_flow("go_to_scene|res://scene/scene_title/scene_title.tscn")
	return

func move_item_left():
	var option = OPTIONS[lsc.cursor_index]
	var item = option["name"]
	var current = setting[item]
	var options = option["options"]
	var optionIdx = options.find(current)
	var total = options.size()
	optionIdx = (optionIdx + total - 1) % total
	setting[item] = options[optionIdx]
	return

func move_item_right():
	var option = OPTIONS[lsc.cursor_index]
	var item = option["name"]
	var current = setting[item]
	var options = option["options"]
	var optionIdx = options.find(current)
	var total = options.size()
	optionIdx = (optionIdx + 1) % total
	setting[item] = options[optionIdx]
	return

func show_item():
	var index = lsc.cursor_index
	lsc.items = []
	var i = 0;
	for option in OPTIONS:
		var key = option["name"]
		var options = option["options"]
		var current = options[0]
		if key in setting:
			if setting[key] in options:
				current = setting[key]
		var item = "{0}：{1}".format([key, current])
		lsc.items.append(item)
		setting[key] = current
	lsc._set_data()
	lsc.cursor_index = index
	return

func show_info():
	var memo = ""
	var idx = lsc.cursor_index
	if idx >= 0 and idx < OPTIONS.size():
		memo = OPTIONS[idx]["memo"]
	txtDescription.bbcode_text = memo
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.6, 1.6)
	return

func reset_layout_landscape():
	rect_position = Vector2(192, 0)
	rect_scale = Vector2(1, 1)
	return
