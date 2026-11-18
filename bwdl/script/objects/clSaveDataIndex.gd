extends Resource

const SAVE_IDX_FILE = "user://save_index.json"
const SL_PAGE_FILE = "user://sl_page.txt"

const SAVE_PAGE_TOTAL = 13

class_name SaveDataIndex

var page: int = 0

var indexes: Dictionary = {}

func _init() -> void :
	reload()
	return

func reload() -> void :
	var data = Global.get_file_text(SAVE_IDX_FILE)
	if data == "":
		
		var pageStr = Global.get_file_text(SL_PAGE_FILE)
		if pageStr == "":
			page = 0
		page = int(pageStr)
		return
	
	data = Global.dicval(parse_json(data))
	page = Global.intval(Global.dic_val(data, "page"), 0)
	probe_all()
	return

func dump() -> void :
	var data = {}
	data["page"] = page
	Global.save_file_text(SAVE_IDX_FILE, JSON.print(data, "  "))
	return

func probe_all() -> void :
	indexes.clear()
	DataManager.grouped_trace_reset()
	var path = DataManager.get_common_path() + "save/"
	for file in Global.scan_all_files(path, false):
		if not file.ends_with(".sav"):
			continue
		var idx = file.get_file().get_basename()
		if not expected_save_item(idx):
			continue
		DataManager.grouped_trace("")
		var length = Global.get_file_length(file)
		DataManager.grouped_trace("LEN")
		var data = Global.get_file_text(file)
		DataManager.grouped_trace("IO")
		indexes[idx] = {
			"len": length, 
			"brief": get_save_brief(data)
		}
	DataManager.grouped_trace_output(true, "SL-INDEX")
	return


func expected_save_item(idx: String) -> bool:
	if idx in ["annualy", "defence", "endless", "monthly", "paused"]:
		return true
	var id = int(idx)
	if str(id) != idx:
		return false
	return id >= 0 and id < SAVE_PAGE_TOTAL * 4

func get_save_brief(data: String) -> Dictionary:
	if data == "":
		return {}
	var dic = parse_json(data)
	if typeof(dic) != TYPE_DICTIONARY:
		return {}
	var ret = {}

	for key in [
		"COMPABILITY", "存档时间", "mod_path", 
		"current_scene_path", 
		"diffculities", "year", "month", 
	]:
		if key in dic:
			ret[key] = dic[key]
			if typeof(ret[key]) == TYPE_REAL:
				ret[key] = int(ret[key])
	var saveSlot = Global.dic_val(dic["common_variable"], "saveSlot", "")
	ret["saveSlot"] = saveSlot

	var gameMode = "「标准」"
	if Global.dic_val(dic, "endless_model", false):
		gameMode = "[color=#EE0000]「无尽」[/color]"
	elif Global.intval(Global.dic_val(dic, "game_mode2", 0)) == 1:
		gameMode = "[color=#EEEE00]「剧情」[/color]"
	ret["gameMode"] = gameMode

	var lordName = "演示"
	if "players" in dic and "actors" in dic:
		for p in dic["players"]:
			var actorId = Global.intval(Global.dic_val(p, "actorId"))
			if actorId < 0 or actorId >= dic["actors"].size():
				continue
			var actor = dic["actors"][actorId]
			lordName = actor["姓名"]
			var side = Global.dic_val(actor, "面", "")
			if side != "":
				lordName += "<" + side + ">"
			break
	ret["lordName"] = lordName

	return ret

func get_save_info(file: String) -> Dictionary:
	var idx = file.get_file().get_basename()
	var length = Global.get_file_length(file)
	
	
	if idx in indexes and indexes[idx]["len"] == length:
		return indexes[idx]["brief"]
	var data = Global.get_file_text(file)
	var info = get_save_brief(data)
	indexes[idx] = {
		"len": length, 
		"brief": info
	}
	return info

func update_save_index(idx: String) -> void :
	indexes.erase(idx)
	return
