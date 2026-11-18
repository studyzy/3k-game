extends Control

const SCENE_ID = 0

onready var lastUpdate: int = Time.get_ticks_msec()

onready var lastPauseSaved: int = - 1

const AUTO_SAVING_INTERVAL_MS = 10000

func _ready() -> void :
	
	SceneManager.load_scene_complete = true
	DataManager.game_trace("")
	SceneManager.restart()
	Global.apply_user_preference()

	var d: Directory = Directory.new()
	var defaultPaths = [
		"save/", 
		"mod/patches/", 
		"mod/avatars/diy/female/", 
		"mod/avatars/diy/male/", 
		"mod/avatars/diy/genderless/", 
		"mod/avatars/custom/", 
	]
	for p in defaultPaths:
		p = DataManager.get_common_path() + p
		if not d.dir_exists(p):
			d.make_dir_recursive(p)
	hide()
	return

func _process(delta):
	var current = Time.get_ticks_msec()
	if current > lastUpdate + 500:
		lastUpdate = current
		Global.save_user_preference()
		SceneManager.update_runtime_info({})
	return

func _notification(what):
	if what == NOTIFICATION_APP_PAUSED:
		if DataManager.get_current_scene_id() >= 10000:
			var current = Time.get_ticks_msec()
			if current - lastPauseSaved >= AUTO_SAVING_INTERVAL_MS:
				DataManager.save_game_data("paused")
				lastPauseSaved = current
		get_tree().paused = true
	elif what == NOTIFICATION_APP_RESUMED:
		get_tree().paused = false
	return
