extends Control

const SCENE_ID = 0

onready var lsc = get_node("lsc")
onready var description = get_node("windows/bottom_text")

var dramas = []

func _init():
	return

func _ready():
	dramas.clear()
	var items = []
	for drama in StaticManager.all_drama_info():
		dramas.append(drama)
		drama["month"] = str(drama["fromMonth"])
		if drama["fromMonth"] < 10:
			drama["month"] = "0" + drama["month"]
		items.append("{name}（{fromYear}-{month}）".format(drama))
	lsc.items = items
	lsc._set_data()
	SceneManager.load_scene_complete = true
	return

func _process(delta: float) -> void :
	if Input.is_action_just_pressed("ANALOG_UP"):
		lsc.move_up()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		lsc.move_down()
	var drama = dramas[lsc.cursor_index]
	description.text = drama["description"] + "\n\n" + "上下选择时期，A键确认"
	if not Global.is_action_pressed_AX():
		return
	DataManager.loading_version_resource(DataManager.mod_path, drama["path"])
	if "alliances" in drama:
		DataManager.vstates_alliance.clear()
		DataManager.vstates_alliance = drama["alliances"].duplicate()
	FlowManager.add_flow("go_to_scene|res://scene/scene_set/scene_set.tscn")
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.6, 1.6)
	return

func reset_layout_landscape():
	rect_position = Vector2(192, 0)
	rect_scale = Vector2(1, 1)
	return
