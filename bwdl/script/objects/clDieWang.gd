# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/objects/clDieWang.gd
# 说明：帝王信息对象。记录称帝/帝号相关数据。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Resource

class_name DieWangInfo

enum InfoType{
	COMMON = 0, 
	HERO_RECRUIT = 1, 
	LEADER_LOYALTY = 2, 
	HERO_TRANSFER = 3, 
	HEROINE_TRANSFER = 4, 
}


const INFO_TYPES = [
	InfoType.HERO_RECRUIT, 
	InfoType.LEADER_LOYALTY, 
	InfoType.HERO_TRANSFER, 
	InfoType.HEROINE_TRANSFER, 
]

var info: Dictionary = {}
var history: Dictionary = {}

func reset() -> void :
	info = {}
	return

func load_env() -> void :
	var data = DataManager.get_env_dict("DieWang")
	if "info" in data:
		info = Global.dicval(data["info"])
	if "history" in data:
		history = Global.dicval(data["history"])
	return

func save_env() -> void :
	var data = {}
	data["info"] = info
	data["history"] = history
	DataManager.set_env("DieWang", data)
	return


func noticed_recently(type: int, actorId: int, monthPassed: int = 3) -> bool:
	var tk = "T" + str(type)
	if not tk in history:
		return false
	var ak = "A" + str(actorId)
	if not ak in history[tk]:
		return false
	var lastNoticed = int(history[tk][ak])
	var timing = DataManager.year * 12 + DataManager.month
	return timing < lastNoticed + monthPassed



func mark_noticed(type: int, actorId: int) -> void :
	var tk = "T" + str(type)
	if not tk in history:
		history[tk] = {}
	var ak = "A" + str(actorId)
	var timing = DataManager.year * 12 + DataManager.month
	history[tk][ak] = timing
	save_env()
	return


func note_information(type: int, actorId: int) -> bool:
	var tk = "T" + str(type)
	if noticed_recently(type, actorId, 3):
		return false
	if not tk in info:
		info[tk] = []
	info[tk].append(actorId)
	save_env()
	return true


func something_new() -> bool:
	for type in INFO_TYPES:
		var tk = "T" + str(type)
		if not tk in info:
			continue
		if info[tk].empty():
			continue
		return true
	return false






func get_most_valuable(forVstateId: int, ignoreInspection: bool = false, markReported: bool = false) -> Array:
	
	var inspectedCityIds = []
	for c in clCity.all_cities():
		if c.ID in inspectedCityIds:
			continue
		if ignoreInspection or forVstateId < 0:
			
			inspectedCityIds.append(c.ID)
			continue
		if c.inspection_left(forVstateId) > 0:
			inspectedCityIds.append(c.ID)
			for connectedId in c.get_connected_city_ids():
				inspectedCityIds.append(connectedId)
	
	var msgGroup = [
		[InfoType.HERO_RECRUIT, "谍报：{0}{1}，英才也\n现对{2}心怀不满\n有隙可乘，或可招揽"], 
		[InfoType.LEADER_LOYALTY, "谍报：{0}{1}，英才也\n似有脱离{2}自立之意\n推波助澜，利或在我"], 
		[InfoType.HERO_TRANSFER, "谍报：{1}，英才也\n近转投于{0}\n{2}声势大张，不可不察"], 
		[InfoType.HEROINE_TRANSFER, "谍报：\n{1}近仕于{2}军{0}\n主公其有意乎？"], 
	]
	for msgPair in msgGroup:
		var tk = "T" + str(msgPair[0])
		if not tk in info:
			continue
		var msg = msgPair[1]
		var maxScore = 0
		var target = null
		var targetCity = null
		for actorId in info[tk]:
			
			var tc = DataManager.get_office_city_by_actor(actorId)
			if tc == null or not tc.ID in inspectedCityIds:
				continue
			if tc.get_vstate_id() == forVstateId:
				
				continue
			
			var actor = ActorHelper.actor(actorId)
			var score = actor.get_wisdom() + actor.get_power() + actor.get_leadership()
			if score > maxScore:
				maxScore = score
				target = actor
				targetCity = tc
		if target == null:
			continue
		if markReported:
			mark_noticed(msgPair[0], target.actorId)
		msg = msg.format([
			targetCity.get_full_name(), target.get_name(), targetCity.get_lord_name(), 
		])
		return [msg, target.actorId, targetCity.ID, targetCity.get_lord_id()]
	return []


func update_monthly() -> void :
	reset()
	var timing = DataManager.year * 12 + DataManager.month
	
	var playerVstateId = - 1
	for p in DataManager.players:
		if p.actorId >= 0:
			var playerCity = DataManager.get_office_city_by_actor(p.actorId)
			if playerCity != null:
				playerVstateId = playerCity.get_vstate_id()
				break
	
	for a in ActorHelper.all_actors():
		if not a.is_status_officed():
			
			continue
		var c = DataManager.get_office_city_by_actor(a.actorId)
		if c == null:
			continue
		var currentVstateId = c.get_vstate_id()
		if currentVstateId == playerVstateId:
			
			continue
		if a.get_gender() == "女":
			if a.get_prev_vstate_id() != currentVstateId:
				
				note_information(InfoType.HEROINE_TRANSFER, a.actorId)
			else:
				var first = Global.intval(a._get_attr("出仕"))
				if first >= timing - 3:
					note_information(InfoType.HEROINE_TRANSFER, a.actorId)
		if a.is_top_actor():
			if a.get_loyalty() < 50:
				
				note_information(InfoType.HERO_RECRUIT, a.actorId)
			elif a.get_prev_vstate_id() != currentVstateId:
				
				note_information(InfoType.HERO_TRANSFER, a.actorId)
		if a.get_loyalty() < 40:
			var actorIds = c.get_actor_ids()
			if not actorIds.empty() and a.actorId == actorIds[0]:
				
				
				note_information(InfoType.LEADER_LOYALTY, a.actorId)
	return
