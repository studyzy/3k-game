extends Control

var save_item_name: String = "0";
var save_item_desc: String = "0";
var is_save = false;
var save_path = "";
var common_save_path = "";

var parent: Control

func _ready() -> void :
	set_is_cursor(false)
	return
	
func set_is_cursor(b: bool):
	$ColorRect.visible = b
	return

func init_data(_save_item_name: String, _common_save_path: String, _is_save: bool, _save_item_desc: String = "", _parent: Control = null):
	if _save_item_desc == "":
		_save_item_desc = "#" + _save_item_name
	is_save = _is_save;
	common_save_path = _common_save_path;
	save_item_name = _save_item_name
	save_item_desc = _save_item_desc
	parent = _parent
	refresh_data()
	return

func refresh_data() -> void :
	var text = ""
	var save_info = {}
	save_path = common_save_path + save_item_name + ".sav"
	save_info = StaticManager.saveIdx.get_save_info(save_path)

	var head_point = "[color=yellow]存档点:{0} [/color]".format([
		save_item_desc
	])
	
	var point_msg = "[center]空存档点[/center]";

	var compability = 1
	if "COMPABILITY" in save_info:
		compability = Global.intval(save_info["COMPABILITY"])
	if compability > DataManager.COMPABILITY:
		point_msg = "[center]无法读取的新版存档[/center]\n[center]请使用{0}或更新版本[/center]".format([
			save_info["VERSION"]
		])
	elif not save_info.empty():
		point_msg = "[color=#66ccff]未选择君主\n{0}[/color]".format([save_info["存档时间"]])
		var mod_path = save_info["mod_path"];
		var sceneCN = SceneManager.get_scene_nameCN(save_info["current_scene_path"]);
		if mod_path != "" and sceneCN != "":
			point_msg = "[color=#66ccff]{0}[/color]".format([save_info["存档时间"]])
			var mod = StaticManager.get_mod_info(mod_path)
			if mod != null:
				var mod_name_CN = str(mod["名称"])
				var lordName = save_info["lordName"]
				var gameMode = save_info["gameMode"]
					
				var current_scene_path = str(save_info["current_scene_path"]).to_lower();
				if "scene_affiars" in current_scene_path:
					current_scene_path = "内政";
				elif "scene_war" in current_scene_path:
					current_scene_path = "大战场";
				elif "scene_battle" in current_scene_path:
					current_scene_path = "小战场";
				elif "scene_solo" in current_scene_path:
					current_scene_path = "单挑";
				
				point_msg += "\n{0}{1} {2}".format([
					gameMode, StaticManager.DIFFICULTY_NAMES[save_info["diffculities"]], lordName, 
				])
				point_msg += "\n{0}年{1}月[{2}]".format([
					save_info["year"], save_info["month"], current_scene_path
				])
	
	$RichTextLabel.bbcode_text = head_point + "\n" + point_msg;
	return

func _on_Control_pressed() -> void :
	if SceneManager.popuped:
		return
	set_is_cursor(true)
	get_parent().emit_signal("selected")
	OS.request_permissions();
	StaticManager.saveIdx.page = parent.page_no
	StaticManager.saveIdx.dump()

	if is_save:
		var current = StaticManager.saveIdx.get_save_info(save_path)
		if current.empty():
			save_data_confirmed()
			return
		
		var saveSlot = DataManager.get_env_str("saveSlot")
		if Global.dic_val(current, "saveSlot", "") == saveSlot:
			save_data_confirmed()
			return
		var msg = "\n存档 #{0}已有内容，确定覆盖吗？\n存档信息：{1} {2} {3}年{4}月".format([
			save_item_name, save_item_desc, 
			current["lordName"], current["year"], current["month"], 
		])
		SceneManager.confirm(
			msg, self, "save_data_confirmed", 
			Vector2(350, 220), "存！", "再想想")
		return

	SceneManager.Quit._on_btnBackToGame_pressed()
	var text = DataManager.read_game_data_str(save_path)
	if text == "":
		return ;
	var data = parse_json(text)
	
	Global.reset();
	SoundManager.reset();
	SceneManager.clear_stage();
	FlowManager.clear();
	LoadControl.end_script()
	DataManager.set_env("saveSlot", save_item_desc)
	FlowManager.add_flow("load_game_data|" + save_path)
	SceneManager.show_system_notice("读取了存档 " + save_item_desc)
	return


func save_data_confirmed() -> void :
	DataManager.set_env("saveSlot", save_item_desc)
	save_path = DataManager.save_game_data(save_item_name)
	refresh_data()
	get_parent().emit_signal("saved")
	return
