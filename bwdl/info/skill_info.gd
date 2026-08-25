# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/skill_info.gd
# 说明：信息面板-技能信息（自动加载）。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Node



const APPENDED_SKILLS = {
	"机变": ["势威", "魂智", "智神"], 
	"父魂": ["神武", "咆哮"], 
	"文武": ["看破", "勇突"], 
	"虎豹": ["虎骑", "豹骑"], 
	"据守": ["坚守", "溃围"], 
	"增矛": ["长矛"], 
	"增弓": ["飞羽"], 
	"增劲": ["连劲"], 
	"枪神": ["百鸟", "朝凤"], 
	"雄骑": ["骑神"], 
	"酩酊": ["增援"], 
	"咆哮": ["巨喝", "长啸"], 
	"震塞": ["弓骑"], 
	"助燃": ["引火"], 
	"增甲": ["轻甲"], 
	"无双": ["神勇", "无前"], 
}

class SkillRecord extends Resource:

	var name: String
	var skill: StaticManager.Skill = null
	var id: int = 0
	var lv: int
	var actorId: int = - 1
	var positive: bool = false
	var negative: bool = false
	var actorName: String = ""
	var description: String = ""
	var background: String = ""
	var scene: String = ""
	var category: String = ""
	var source: String = ""
	var fullName: String = ""

	func _init(_name: String, _actorId: int = - 1):
		name = _name
		actorId = _actorId
		skill = StaticManager.get_skill(name)
		if skill == null:
			return
		fullName = name
		if not skill._gendersOnly.empty():
			fullName += "（" + "、".join(skill._gendersOnly) + "）"
		if not skill._exclusiveActorIds.empty():
			fullName = name + "（专）"
		scene = skill.scene
		category = skill.category
		description = skill.get_runtime_description(actorId)
		var x = "。"
		var pos = description.find(x)
		if pos > 0:
			description = description.substr(pos + x.length())
		description = description.replace("☆制作组", "\n☆制作组")
		background = skill.background
		background = background.replace("☆制作组", "\n☆制作组")
		return

	func actor_name() -> String:
		if actorName == "":
			if actorId < 0:
				actorName = "-"
			else:
				actorName = ActorHelper.actor(actorId).get_name()
		return actorName

	func scene() -> String:
		var ret = scene
		if "&" in scene:
			var pieces = scene.split("&")
			var abbreved = []
			for piece in pieces:
				abbreved.append(piece.left(1))
			ret = "、".join(abbreved)
		return ret

	
	func scene_score() -> int:
		var score = 0
		if "内政" in scene:
			score = 10000
		if "大战场" in scene:
			if score >= 10000:
				score += 2000
			else:
				score = 20000
		if "小战场" in scene:
			if score >= 10000:
				score += 300
			else:
				score = 30000
		if "单挑" in scene:
			if score >= 10000:
				score += 40
			else:
				score = 40000
		return score

	func category() -> String:
		return category.replace("技", "")

	func assignment() -> String:
		var memo = ""
		if actorId < 0 and source != "":
			return "{0} 附加".format([source])
		if positive and actorId != StaticManager.ACTOR_ID_PANGTONG:
			memo = ":阳"
		elif negative:
			memo = ":阴"
			if actorId == StaticManager.ACTOR_ID_PANGTONG:
				memo = ":醉"
		return "{0}{2} Lv{1}".format([
			actor_name(), lv, 
			memo
		])

	func full_description() -> String:
		var desc = description
		var result = find_special_pieces(desc, "[", "]")
		var ret = result[0]
		var found = result[1]
		result = find_special_pieces(ret, "<", ">")
		ret = result[0]
		found.append_array(result[1])
		result = find_special_pieces(ret, "{", "}")
		ret = result[0]
		found.append_array(result[1])
		var appended = [name]
		var noteIdx = 1
		for piece in found:
			if piece in appended:
				continue
			appended.append(piece)
			var more = translate_special_piece(piece, noteIdx)
			if more == "":
				continue
			ret += more
			noteIdx += 1
		return ret

	func full_background() -> String:
		var bg = background
		var result = find_special_pieces(bg, "[", "]")
		var ret = result[0]
		if ret == "":
			ret = "[color=#CCCCCC]暂无[/color]"
		
		for i in range(1, 10):
			var piece = str(i) + "."
			var pos = ret.find(piece)
			if pos < 0:
				break
			ret = ret.substr(0, pos) + "\n\n" + ret.substr(pos)
		if ret.begins_with("\n\n"):
			ret = ret.substr(2)
		return ret

	func find_special_pieces(desc: String, prefix: String, suffix: String) -> Array:
		var ret = ""
		var last = 0
		var to = 0
		var from = desc.find(prefix, last)
		var found = []
		while from >= last:
			to = desc.find(suffix, from)
			
			var nextFrom = desc.find(prefix, from + 1)
			if nextFrom > from and nextFrom < to:
				from = nextFrom
			if to < 0:
				break
			var piece = desc.substr(from + 1, to - from - 1)
			found.append(piece + "$$$" + prefix)
			ret += desc.substr(last, from - last) + " [color=yellow]" + piece + "[/color]"
			last = to + 1
			from = desc.find(prefix, last)
		ret += desc.substr(last)
		return [ret, found]

	func translate_special_piece(piece: String, idx: int) -> String:
		var splited = piece.split("$$$")
		piece = splited[0]
		var type = splited[1]
		match type:
			"<":
				var sr = SkillRecord.new(piece)
				if sr.skill != null:
					return "\n\n[{0}] {1}：[color=#CCCCCC]{2}[/color]".format([
						idx, piece, sr.description
					])
			"{":
				var buff = StaticManager.get_buff(piece)
				if buff != null:
					var desc = buff.get_description()
					if desc != "":
						return "\n\n[{0}] {1}：[color=#CCCCCC]{2}[/color]".format([
							idx, piece, desc, 
						])
				var wiki = StaticManager.get_wiki_description(piece)
				if wiki != "":
					return "\n\n[{0}] {1}：[color=#CCCCCC]{2}[/color]".format([
						idx, piece, wiki, 
					])
			"[":
				if not piece in StaticManager.TACTICS:
					return ""
				return "\n\n[{0}] {1}：[color=#CCCCCC]小战场战术。\n{2}[/color]".format([
					idx, piece, StaticManager.TACTICS[piece]["描述"], 
				])
		return ""


var allSkills: Array = []
var skillNameDic: Dictionary = {}
var appendedFound: Array = []


func reload_all_skills() -> void :
	allSkills.clear()
	skillNameDic.clear()
	appendedFound.clear()
	for assignment in StaticManager.actor_skills:
		var actorId = int(assignment["ID"])
		for lv in range(1, 9):
			var key = "LV{0}".format([lv])
			if not key in assignment:
				continue
			for sr in parse_from_assignment(actorId, lv, assignment[key]):
				if sr.name in skillNameDic:
					sr.id = skillNameDic[sr.name][0].id
					skillNameDic[sr.name].append(sr)
				else:
					sr.id = skillNameDic.size()
					skillNameDic[sr.name] = [sr]
				allSkills.append(sr)
	
	for skillName in StaticManager.skillDict:
		if skillName in skillNameDic:
			continue
		var skill = StaticManager.get_skill(skillName)
		if skill == null:
			continue
		var sr = SkillRecord.new(skillName)
		sr.id = 0
		sr.actorId = - 1
		sr.lv = 0
		skillNameDic[sr.name] = [sr]
		allSkills.append(sr)
	return

func parse_from_assignment(actorId: int, lv: int, assignment: String) -> Array:
	var ret = []
	assignment = assignment.strip_edges()
	if assignment == "":
		return []
	if not "/" in assignment:
		var sr = SkillRecord.new(assignment)
		sr.id = 0
		sr.actorId = actorId
		sr.lv = lv
		ret.append(sr)
	else:
		var names = assignment.split("/")
		if names.size() == 2:
			if names[0] != "":
				var sr = SkillRecord.new(names[0])
				sr.id = 0
				sr.actorId = actorId
				sr.positive = true
				sr.lv = lv
				ret.append(sr)
			if names[1] != "":
				var sr = SkillRecord.new(names[1])
				sr.id = 0
				sr.actorId = actorId
				sr.negative = true
				sr.lv = lv
				ret.append(sr)
	
	for sr in ret:
		if sr.name in APPENDED_SKILLS:
			for skill in APPENDED_SKILLS[sr.name]:
				if skill in appendedFound:
					continue
				appendedFound.append(skill)
				var asr = SkillRecord.new(skill)
				asr.id = 0
				asr.actorId = - 1
				asr.lv = 0
				asr.source = sr.name
				ret.append(asr)
	return ret

func records_by_name(name: String) -> Array:
	if not name in skillNameDic:
		return []
	return skillNameDic[name].duplicate(true)
