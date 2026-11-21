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
		CloudSave.begin_session(self, "_on_cloud_fetched")
	DataManager.grouped_trace_output(false, "OPENING")
	$HTTPRequest.request("https://bwdl.fun/gd/version.json")
	return

func _process(delta):
	if AutoLoad.playerNo == FlowManager.controlNo:
		_on_key_event()
	return


func _on_key_event():
	if SceneManager.popuped or SceneManager.Quit.visible:
		return
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

func _on_cloud_fetched(result: Dictionary) -> void :
	if not result.get("ok", false):
		return
	var slots = result.get("slots", {})
	if typeof(slots) != TYPE_DICTIONARY or slots.empty():
		return
	if model_view != 0:
		# 玩家已经离开开场：迟到响应不能覆盖刚存的新档，也不弹框盖在新场景上
		return
	var merged = CloudSave.merge_into_local(slots)
	var total = int(merged["total"])
	if total <= 0:
		return
	var msg = "云端发现{0}个网络存档位，已恢复{1}个，保留本地较新{2}个。\n是否打开读档列表？".format([
		total, int(merged["restored"]), int(merged["kept"])
	])
	SceneManager.confirm(msg, self, "_on_cloud_merge_confirmed", Vector2(420, 240), "打开", "取消")
	return

func _on_cloud_merge_confirmed() -> void :
	SceneManager.Quit.show_menu()
	SceneManager.Quit._on_btnLoadGame_pressed()
	return
