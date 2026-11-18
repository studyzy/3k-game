extends Control

const SCENE_ID = 20000

onready var bottom_scene_color = get_node("bottom_scene_color")
onready var war_map = get_node("war_map")
onready var war_communique = get_node("War_Communique")
onready var war_status = get_node("war_status")
onready var war_log = get_node("war_log")

var war_auto_run


func _ready() -> void :
	war_auto_run = Global.load_script(DataManager.mod_path + "sgz_script/war/war_auto_run.gd")
	SceneManager.load_scene_complete = true
	war_communique.hide()
	war_status.hide()
	war_log.hide()
	return


func _process(delta: float) -> void :
	if war_auto_run == null:
		return
	var wf = DataManager.get_current_war_fight()
	if wf == null or wf.status != 1:
		return
	war_auto_run._process(delta)
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.70666, 1.6)
	return

func reset_layout_landscape():
	rect_position = Vector2(212, 0)
	rect_scale = Vector2(1, 1)
	return
