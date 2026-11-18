extends Node
var _script_object: Dictionary = {}

var pre_dic_method = {};
var pre_array_clear_method = [];
var view_model_name = "";


func _ready() -> void :
	return


func _affiars_error(msg: String, actorId = - 1, mood: int = 2, is_show_cityinfo = true):
	SceneManager.clear_bottom()
	var flow = "show_confirm_dialog|{0}|{1}|{2}|{3}".format([
		msg, actorId, mood, is_show_cityinfo
	])
	FlowManager.add_flow(flow)
	SceneManager.show_cityInfo(is_show_cityinfo)
	LoadControl.set_view_model(999)
	return


func _error(msg: String, actorId = - 1, mood: int = 2):
	LoadControl.set_view_model(0)
	if DataManager.war_control_sort.size() > DataManager.war_control_sort_no:
		if DataManager.war_control_sort[DataManager.war_control_sort_no] < 0:
			
			DataManager.set_env("战争-AI-步骤", 3)
		else:
			
			DataManager.set_env("战争-玩家-步骤", 0)
	SceneManager.clear_bottom()
	var flow = "show_confirm_dialog|{0}|{1}|{2}|false".format([
		msg, actorId, mood
	])
	FlowManager.add_flow(flow)
	return


func confirm_to_ready():
	LoadControl.set_view_model(0);
	SceneManager.show_confirm_dialog(DataManager.common_variable["对话"]);
	SceneManager.dialog_msg_complete(true);
	if ("内政" in view_model_name):
		SceneManager.show_cityInfo(true);
	return

func get_view_model() -> int:
	return DataManager.get_env_int(view_model_name)

func set_view_model(view_model: int):
	DataManager.set_env(view_model_name, view_model)
	return

func load_script(script_path: String) -> Resource:
	var paths = DataManager.get_env_array("自定义步骤路径")
	if paths.has(script_path):
		return null
	paths.append(script_path)
	DataManager.set_env("自定义步骤路径", paths)
	if pre_dic_method.empty():
		pre_dic_method = FlowManager.dic_method.duplicate()
	if pre_array_clear_method.empty():
		pre_array_clear_method = FlowManager.clear_pre_history.duplicate()
	create()
	var path_key = script_path.replace("res://packed/sgz_script/", "")
	path_key = path_key.replace("res://resource/sgz_script/", "")
	if path_key in _script_object:
		return _script_object[path_key]
	return null

func create() -> Array:
	var ret = []
	for path in DataManager.get_env_array("自定义步骤路径"):
		path = str(path)
		if path == "":
			continue
		var script = load_or_reuse_script(path)
		ret.append(script)
	set_process(true)
	return ret

func load_or_reuse_script(path: String) -> Resource:
	var ret = null
	var path_key = path.replace("res://packed/sgz_script/", "")
	path_key = path_key.replace("res://resource/sgz_script/", "")
	if path_key in _script_object:
		
		
		
		ret = _script_object[path_key]
		ret._init()
		return ret
	
	if path in _script_object:
		
		ret = _script_object[path]
		_script_object.erase(path)
		_script_object[path_key] = ret
		ret._init()
		return ret
	var real_path = path
	if not real_path.begins_with("res://"):
		real_path = DataManager.mod_path + "sgz_script/" + path
	ret = Global.load_script(real_path)
	if null == ret:
		return null
	_script_object[path_key] = ret
	return ret

func end_script():
	view_model_name = "";
	DataManager.set_env("自定义步骤路径", [])
	_script_object.clear();
	if not pre_dic_method.empty():
		FlowManager.dic_method = pre_dic_method.duplicate()
		pre_dic_method.clear()
	if not pre_array_clear_method.empty():
		FlowManager.clear_pre_history = pre_array_clear_method.duplicate()
		pre_array_clear_method.clear()
	return

func _process(delta: float) -> void :
	if AutoLoad.playerNo != FlowManager.controlNo:
		return ;
	if _script_object.empty():
		return ;
	if FlowManager.has_task():
		return ;
	for so in _script_object.values():
		if not is_instance_valid(so):
			continue
		if so.has_method("skip_load_control") and so.call("skip_load_control"):
			continue
		if so.has_method("_input_key"):
			so.call("_input_key", delta)
			
		
	return

func all_controllers_done() -> bool:
	for so in _script_object.values():
		if so.has_method("_input_key"):
			return false
	return true

func no_effect_script_objects() -> bool:
	for so in _script_object.values():
		if "/effects/" in so.get_script().get_path():
			return false
	return true
