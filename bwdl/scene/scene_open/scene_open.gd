extends Control

const SCENE_ID = 0

var model_view = 0;


func _ready():
	
	SceneManager.load_scene_complete = true
	model_view = 0;
	
	DataManager.data_all_clear()
	
	OS.request_permissions()
	
	get_node("top/lblVersion").text = DataManager.DISPLAY_VERSION
	if not StaticManager.game_init_done:
		StaticManager.game_init_done = true
		DataManager.game_trace("RESTART", true)
	DataManager.grouped_trace_output(false, "OPENING")
	$HTTPRequest.request("https://bwdl.fun/gd/version.json")
	return

func _process(delta):
	if AutoLoad.playerNo == FlowManager.controlNo:
		_on_key_event()
	return


func _on_key_event():
	match model_view:
		0:
			
			if Input.is_action_just_pressed("EMU_START"):
				model_view = - 1
				
				FlowManager.add_flow("go_to_scene|res://scene/scene_drama/scene_drama.tscn")
			if Input.is_action_just_pressed("EMU_SELECT"):
				if not DataManager.is_developer():
					return
				model_view = - 1
				FlowManager.add_flow("go_to_scene|res://scene/scene_test/scene_test.tscn")
	return

func _on_HTTPRequest_request_completed(result: int, response_code: int, headers: PoolStringArray, body: PoolByteArray) -> void :
	if result != 0:
		return
	var info = parse_json(body.get_string_from_utf8())
	if typeof(info) == TYPE_DICTIONARY:
		DataManager.cloudVersion = info
	return

func reset_layout_portrait():
	rect_position = Vector2(0, 0)
	rect_scale = Vector2(1.6, 1.6)
	return

func reset_layout_landscape():
	rect_position = Vector2(192, 0)
	rect_scale = Vector2(1, 1)
	return
