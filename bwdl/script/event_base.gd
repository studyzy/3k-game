extends Resource

var name: String = ""
var timing: PoolIntArray = []
var players: PoolIntArray = []
var excludedPlayers: PoolIntArray = []
var vstates: Dictionary = {}
var cities: Dictionary = {}
var actors: Dictionary = {}
var prevEvents: Array = []
var returnFlow: String = "player_drama_events"
var dialogs: Array = []

func _input_key(delta: float) -> void :
	var viewModel = LoadControl.get_view_model()
	var method = "on_view_model_{0}".format([viewModel])
	if has_method(method):
		call(method)
	return

func basic_conditions_meet() -> bool:
	
	if is_event_processed(name):
		return false
	
	for ev in prevEvents:
		if not is_event_processed(ev):
			return false
	
	if not timing():
		return false
	
	if not players_ok():
		return false
	
	if not vstates_alive():
		return false
	
	if not city_status_ok():
		return false
	
	if not actors_status_ok():
		return false
	return true

func timing() -> bool:
	var now = DataManager.year * 100 + DataManager.month
	return now in timing

func players_ok() -> bool:
	
	if players.empty() and excludedPlayers.size() > 0:
		for player in excludedPlayers:
			for p in DataManager.players:
				if p.actorId == player:
					return false
		return true
	
	for player in players:
		for p in DataManager.players:
			if player >= 0 and p.actorId == player:
				return true
	return false

func vstates_alive() -> bool:
	for vstateId in vstates:
		var vs = clVState.vstate(vstateId)
		if not vs.is_alive():
			return false
		var lordId = vstates[vstateId]
		if lordId >= 0 and vs.get_lord_id() != lordId:
			return false
	return true

func city_status_ok() -> bool:
	for cityId in cities:
		var city = clCity.city(cityId)
		if cities[cityId] != city.get_vstate_id():
			return false
	return true

func actors_status_ok() -> bool:
	for actorId in actors:
		var cityId = actors[actorId]
		match cityId:
			- 3:
				if not ActorHelper.actor(actorId).is_status_disabled():
					return false
			- 2:
				if not ActorHelper.actor(actorId).is_status_unofficed():
					return false
			- 1:
				for city in clCity.all_cities():
					if actorId in city.get_actor_ids():
						actors[actorId] = city.ID
						break
				if actors[actorId] < 0:
					return false
			_:
				var city = clCity.city(cityId)
				if not actorId in city.get_actor_ids():
					return false
	return true

func mark_event_processed():
	DataManager.drama_events_process[name] = 1
	return

func is_event_processed(name: String) -> bool:
	if not name in DataManager.drama_events_process:
		return false
	return Global.intval(DataManager.drama_events_process[name]) == 1

func event_finish() -> void :
	LoadControl.set_view_model( - 1)
	mark_event_processed()
	LoadControl.end_script()
	FlowManager.add_flow(returnFlow)
	return

func get_dialog_progress() -> int:
	return DataManager.get_env_int(name + ".对话")

func set_dialog_progress(val: int) -> void :
	DataManager.set_env(name + ".对话", val)
	return


func event_start() -> bool:
	if not basic_conditions_meet():
		return false
	
	DataManager.game_saving_enabled = false
	set_dialog_progress(0)
	event_go()
	return true


func event_go() -> void :
	event_dialog()
	return


func event_dialog() -> void :
	SceneManager.black.hide()
	var dialogProgress = get_dialog_progress()
	if dialogProgress < 0 or dialogProgress >= dialogs.size():
		event_settle()
		return
	var dialog = dialogs[dialogProgress]
	set_dialog_progress(dialogProgress + 1)
	if dialog.size() == 1:
		match dialog[0]:
			"BLACK":
				SceneManager.black.show()
				Global.wait(Engine.time_scale, self, "event_go")
				return
	var cityId = dialog[0]
	var playerId = DataManager.players[0].actorId
	if typeof(cityId) == TYPE_ARRAY:
		DataManager.twinkle_citys = Array(cityId)
	elif int(cityId) > 0:
		DataManager.twinkle_citys = [int(cityId)]
	elif int(cityId) == - 99:
		var city = DataManager.get_office_city_by_actor(playerId)
		if city != null:
			cityId = city.ID
			DataManager.twinkle_citys = [city.ID]
	else:
		DataManager.twinkle_citys.clear()
	var actorId = dialog[1]
	if actorId == - 99:
		actorId = DataManager.players[0].actorId
	elif actorId == - 90:
		var playerCity = DataManager.get_office_city_by_actor(playerId)
		if playerCity != null:
			actorId = DataManager.get_max_property_actorId("政", playerCity.get_vstate_id(), [playerId])
	var msg = dialog[2]
	var mood = dialog[3]
	SceneManager.hide_all_tool()
	SceneManager.show_confirm_dialog(msg, actorId, mood, actorId == - 1)
	LoadControl.set_view_model(2000)
	return

func on_view_model_2000() -> void :
	if not SceneManager.dialog_msg_complete(true):
		return
	if Input.is_action_just_pressed("EMU_START"):
		
		LoadControl.set_view_model( - 1)
		event_settle()
		return
	if not Global.is_action_pressed_AX():
		return
	LoadControl.set_view_model( - 1)
	event_dialog()
	return


func event_settle() -> void :
	return

func on_view_model_2999() -> void :
	if not Global.is_action_pressed_AX():
		return
	if not SceneManager.dialog_msg_complete(true):
		return
	LoadControl.set_view_model( - 1)
	event_finish()
	return
