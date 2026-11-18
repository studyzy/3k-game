extends "../clEnvBase.gd"

const SCHEME_CHANCE_EFFECT_ID = 20121

class_name SkillEffectInfo



var actorId: int = - 1

var skill_name: String = ""

var effect_Id: int = - 1

var effect_type: String = ""

var trigger_Id: int = - 1;

var skill_actorId: int = - 1

var costs: Array = []

var results: Array = []

var logs: Array = []

var targetId: int = - 1

var ext_flags: Dictionary = {}


var recorded: int = 0


func output_data() -> Dictionary:
	var dic = {
		"actorId": actorId, 
		"skill_name": skill_name, 
		"effect_Id": effect_Id, 
		"effect_type": effect_type, 
		"trigger_Id": trigger_Id, 
		"skill_actorId": skill_actorId, 
		"targetId": targetId, 
		"costs": [], 
		"results": [], 
		"logs": logs, 
		"ext_flags": ext_flags, 
	}
	for cost in costs:
		dic["costs"].append(cost.output_data())
	for result in results:
		dic["results"].append(result.output_data())
	return dic


func input_data(dic: Dictionary) -> void :
	if dic.empty():
		return
	actorId = int(dic["actorId"])
	skill_name = str(dic["skill_name"])
	effect_Id = int(dic["effect_Id"])
	trigger_Id = int(dic["trigger_Id"])
	effect_type = str(dic["effect_type"])
	skill_actorId = int(dic["skill_actorId"])
	targetId = Global.dic_val_int(dic, "targetId")
	costs = []
	if dic.has("costs") and typeof(dic["costs"]) == TYPE_ARRAY:
		for c in dic["costs"]:
			var cost = SkillResult.new()
			if cost.input_data(c):
				costs.append(cost)
	results = []
	if dic.has("results") and typeof(dic["results"]) == TYPE_ARRAY:
		for r in dic["results"]:
			var result = SkillResult.new()
			if result.input_data(r):
				results.append(result)
	logs = []
	if dic.has("logs") and typeof(dic["logs"]) == TYPE_ARRAY:
		for l in dic["logs"]:
			logs.append(str(l))
	ext_flags = {}
	if dic.has("ext_flags") and typeof(dic["ext_flags"]) == TYPE_DICTIONARY:
		ext_flags = Dictionary(dic["ext_flags"]).duplicate(true)
	return

func skill():
	return StaticManager.get_skill(skill_name)

func effect():
	var skill = skill()
	if skill == null:
		return null
	return skill.get_effect(effect_Id)

func skill_effect_path() -> String:
	var effect = effect()
	return "" if effect == null else effect.path


func actor() -> ActorHelper.ActorInfo:
	return ActorHelper.actor(skill_actorId)


func actioner() -> ActorHelper.ActorInfo:
	return ActorHelper.actor(actorId)

func get_skill_val(sceneId: int = - 1, effectId: int = - 1, targetId: int = - 1):
	if effectId < 0:
		effectId = effect_Id
	if sceneId < 0:
		sceneId = effectId - effectId % 10000
	if targetId == - 1:
		targetId = skill_actorId
	var skv = SkillHelper.get_skill_variable(sceneId, effectId, targetId)
	if skv["turn"] <= 0:
		return null
	return skv["value"]

func set_skill_val(val, turns: int = 99999, effectId: int = - 1, sceneId: int = - 1, targetId: int = - 1) -> void :
	if effectId < 0:
		effectId = effect_Id
	if targetId == - 1:
		targetId = skill_actorId
	if sceneId < 0:
		sceneId = effectId - effectId % 10000
	SkillHelper.set_skill_variable(sceneId, effectId, targetId, val, turns)
	return





func change_actor_equip(cityId: int, equip: clEquip.EquipInfo) -> clEquip.EquipInfo:
	var city = clCity.city(cityId)
	
	var actor = ActorHelper.actor(actorId)
	var current = actor.get_equip(equip.type)
	city.vstate().add_stored_equipment(current)
	
	actor.set_equip(equip)
	
	return current

func affair_cd(turns: int) -> void :
	if turns <= 0:
		return
	SkillHelper.set_skill_cd(10000, effect_Id, skill_actorId, turns, skill_name)
	return


func affair_cost_limited_times(limit: int, turns: int = 1) -> bool:
	var times = affair_get_skill_val_int( - 1, - 1, 0)
	if times >= limit:
		affair_cd(turns)
		SkillHelper.set_skill_variable(10000, effect_Id, skill_actorId, 0, 0)
		return false
	times = times + 1
	if times >= limit:
		
		
		affair_cd(turns)
		SkillHelper.set_skill_variable(10000, effect_Id, skill_actorId, 0, 0)
	else:
		SkillHelper.set_skill_variable(10000, effect_Id, skill_actorId, times, turns)
		var r = SkillResult.new()
		r.fromId = skill_actorId
		r.actorId = skill_actorId
		r.type = "次数"
		r.initial = limit
		r.change = times
		results.append(r)
	return true

func affair_get_skill_val(effectId: int = - 1, targetId: int = - 1):
	return get_skill_val(10000, effectId, targetId)

func affair_get_skill_val_str(effectId: int = - 1, targetId: int = - 1) -> String:
	return Global.strval(get_skill_val(10000, effectId, targetId))

func affair_get_skill_val_int(effectId: int = - 1, targetId: int = - 1, defVal: int = - 1) -> int:
	return Global.intval(get_skill_val(10000, effectId, targetId), defVal)

func affair_get_skill_val_int_array(effectId: int = - 1, targetId: int = - 1) -> Array:
	return Global.intarrval(get_skill_val(10000, effectId, targetId))

func affair_get_skill_val_array(effectId: int = - 1, targetId: int = - 1) -> Array:
	return Global.arrval(get_skill_val(10000, effectId, targetId))

func affair_get_skill_val_dic(effectId: int = - 1, targetId: int = - 1) -> Dictionary:
	return Global.dicval(get_skill_val(10000, effectId, targetId))

func affair_set_skill_val(val, turns: int = 99999, effectId: int = - 1, targetId: int = - 1) -> void :
	set_skill_val(val, turns, effectId, 10000, targetId)
	return


func affair_add_skill(targetId: int, skill: String, turns: int) -> void :
	SkillHelper.remove_scene_actor_skill(10000, targetId, skill)
	SkillHelper.add_actor_scene_skill(10000, targetId, skill, turns, skill_actorId, skill_name)
	SkillHelper.update_all_skill_buff("AFFAIR_ADD_SKILL")
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "技能|【{0}】".format([skill])
	r.initial = 0
	r.change = turns
	results.append(r)
	
	
	
	
	
	SkillHelper.save_skill_effectinfo(self)
	return


func affair_remove_skill(targetId: int, skill: String) -> void :
	SkillHelper.remove_scene_actor_skill(10000, targetId, skill)
	SkillHelper.update_all_skill_buff("AFFAIR_REMOVE_SKILL")
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "技能|【{0}】".format([skill])
	r.initial = 0
	r.change = - 1
	results.append(r)
	
	
	
	
	
	SkillHelper.save_skill_effectinfo(self)
	return


func ban_affair_skill(targetId: int, skillName: String, turns: int) -> bool:
	if SkillHelper.actor_has_skills(targetId, ["贞烈"]):
		return false
	var skill = StaticManager.get_skill(skillName)
	if skill == null:
		return false
	if not skill.can_be_banned():
		return false
	SkillHelper.ban_actor_skill(10000, targetId, skillName, turns, skill_actorId, skill_name)
	SkillHelper.update_all_skill_buff("BAN_AFFAIR_SKILL")
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "技能|【{0}】".format([skillName])
	r.initial = 0
	r.change = - turns
	results.append(r)
	
	
	
	
	
	SkillHelper.save_skill_effectinfo(self)
	return true

func get_war_cd() -> int:
	return SkillHelper.get_skill_cd(20000, effect_Id, skill_actorId, skill_name)


func cost_war_cd(turns: int) -> void :
	if turns <= 0:
		return
	SkillHelper.set_skill_cd(20000, effect_Id, skill_actorId, turns, skill_name)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = skill_actorId
	r.type = "CD|【{0}】".format([skill_name])
	r.initial = 20000
	r.change = turns
	costs.append(r)
	return


func set_war_common_cd(allSides: bool = false) -> void :
	var wf = DataManager.get_current_war_fight()
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return
	var wvIds = [wa.vstate().id]
	if allSides:
		for wv in wf.war_vstates():
			wvIds.append(wv.id)
	for wvId in wvIds:
		var key = "COMMONCD.{0}.{1}.{2}".format([
			skill_name, wf.date, wvId
		])
		wf.set_env(key, 1)
	return


func is_war_common_cd() -> bool:
	var wf = DataManager.get_current_war_fight()
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return false

	var key = "COMMONCD.{0}.{1}.{2}".format([
		skill_name, wf.date, wa.vstate().id
	])
	return wf.get_env_int(key) > 0


func reset_for_redo() -> void :
	costs = []
	results = []
	recorded = 0
	return



func cost_wv_resource(cost: int, resourceType: String) -> int:
	if cost == 0:
		return 0
	var resourceTypes = ["金", "米"]
	if not resourceType in resourceTypes:
		return 0
	var resourceIndex = resourceTypes.find(resourceType)
	var me = DataManager.get_war_actor(skill_actorId)
	if me == null:
		return 0
	var wv = me.war_vstate()
	if wv == null:
		return 0
	var resourceValues = [wv.money, wv.rice]
	var current = resourceValues[resourceIndex]
	cost = min(current, cost)
	resourceValues[resourceIndex] = current - cost
	wv.money = resourceValues[0]
	wv.rice = resourceValues[1]
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = skill_actorId
	r.type = resourceType
	r.initial = current
	r.change = - cost
	costs.append(r)
	return cost

func cost_wv_gold(cost: int) -> int:
	return cost_wv_resource(cost, "金")

func cost_wv_rice(cost: int) -> int:
	return cost_wv_resource(cost, "米")



func cost_ap(cost: int, isActiveSkill: bool = false) -> int:
	if cost == 0:
		return 0
	var me = DataManager.get_war_actor(skill_actorId)
	if me == null:
		return 0
	var current = me.action_point
	cost = min(current, cost)
	me.action_point = current - cost
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = skill_actorId
	r.type = "机动力"
	r.initial = current
	r.change = - cost
	costs.append(r)

	
	var skill = skill()
	if cost > 0\
	and DataManager.game_set["技能系统"] == "是"\
	and skill != null and skill.has_feature("道术"):
		var wf = DataManager.get_current_war_fight()
		for item in me.actor().get_equip_feature_all("首次道术返还机动力"):
			var equip = item[0]
			var val = item[1]
			
			var key = "CD.{0}.{1}.{2}".format([
				equip.name(), me.actorId, wf.date, 
			])
			if wf.get_env_int(key) > 0:
				continue
			wf.set_env(key, 1)
			if val <= 0:
				continue
			var recover = int(cost * val / 100.0)
			if recover <= 0:
				continue
			change_actor_ap(me.actorId, recover)
			var msg = "[{0}] 令机动力回复 {1}".format([
				equip.name(), recover, 
			])
			me.attach_free_dialog(msg, 1)

	
	if isActiveSkill:
		set_env("战争.技能消耗机动力", cost)
		
		SkillHelper.auto_trigger_skill(skill_actorId, 20032, "")
		unset_env("战争.技能消耗机动力")

	return cost



func cost_hp(cost: int) -> int:
	if cost == 0:
		return 0
	var me = get_war_actor()
	if me == null:
		return 0
	var actor = ActorHelper.actor(me.actorId)
	var current = int(actor.get_hp())
	actor.set_hp(current - cost)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = skill_actorId
	r.type = "体力"
	r.initial = current
	r.change = - cost
	costs.append(r)
	return cost



func cost_exp(cost: int) -> int:
	if cost <= 0:
		return 0
	var me = get_war_actor()
	if me == null:
		return 0
	var current = int(me.actor().get_exp())
	if current < cost:
		cost = current
	me.actor().set_exp(current - cost)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = skill_actorId
	r.type = "经验"
	r.initial = current
	r.change = - cost
	costs.append(r)
	return cost



func cost_skill_flags(sceneId: int, effectId: int, flagName: String, cost: int) -> int:
	if effectId < 0:
		effectId = effect_Id
	if cost == 0:
		return 0
	var current = get_skill_flags(sceneId, effectId, flagName)
	cost = min(current, cost)
	SkillHelper.set_skill_flags(sceneId, effectId, skill_actorId, flagName, current - cost)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = skill_actorId
	r.type = "[{0}]".format([flagName])
	r.initial = current
	r.change = - cost
	costs.append(r)
	return cost


func clear_skill_flags(sceneId: int, effectId: int, flagName: String) -> void :
	SkillHelper.set_skill_flags(sceneId, effectId, skill_actorId, flagName, 0)
	return


func get_skill_flags(sceneId: int, effectId: int, flagName: String) -> int:
	if effectId < 0:
		effectId = effect_Id
	return SkillHelper.get_skill_flags_number(sceneId, effectId, skill_actorId, flagName)



func add_skill_flags(sceneId: int, effectId: int, flagName: String, flags: int, limit: int = - 1) -> int:
	if effectId < 0:
		effectId = effect_Id
	if flags == 0:
		return 0
	var current = get_skill_flags(sceneId, effectId, flagName)
	if limit >= 0:
		flags = min(limit - current, flags)
	if flags == 0:
		return 0
	SkillHelper.set_skill_flags(sceneId, effectId, skill_actorId, flagName, current + flags)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = skill_actorId
	r.type = "[{0}]".format([flagName])
	r.initial = current
	r.change = flags
	results.append(r)
	return flags



func cost_self_soldiers(cost: int) -> int:
	var actor = ActorHelper.actor(skill_actorId)
	var current = actor.get_soldiers()
	cost = min(cost, current)
	if cost <= 0:
		return 0
	actor.set_soldiers(current - cost)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = skill_actorId
	r.type = "兵力"
	r.initial = current
	r.change = - cost
	costs.append(r)
	return cost


func get_war_limited_times() -> int:
	return get_war_skill_val_int()




func cost_war_limited_times(limit: int, turns: int = 1) -> bool:
	var times = get_war_limited_times()
	if times >= limit:
		cost_war_cd(turns)
		set_war_skill_val(0, 0)
		return false
	times = times + 1
	if times >= limit:
		
		
		cost_war_cd(turns)
		set_war_skill_val(0, 0)
	else:
		set_war_skill_val(times, turns)
		var r = SkillResult.new()
		r.fromId = skill_actorId
		r.actorId = skill_actorId
		r.type = "次数"
		r.initial = limit
		r.change = times
		results.append(r)
	return true



func change_wv_resource(change: int, resourceType: String, wv: War_Vstate = null) -> int:
	if change == 0:
		return 0
	if wv == null:
		var wa = DataManager.get_war_actor(actorId)
		if wa == null:
			return 0
		wv = wa.war_vstate()
		if wv == null:
			return 0
	var resourceTypes = ["金", "米"]
	var resourceIndex = resourceTypes.find(resourceType)
	if resourceIndex < 0:
		return 0
	var resourceValues = [wv.money, wv.rice]
	var current = resourceValues[resourceIndex]
	
	change = max( - current, change)
	
	change = min(9999 - current, change)
	resourceValues[resourceIndex] = current + change
	wv.money = resourceValues[0]
	wv.rice = resourceValues[1]
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = wv.main_actorId
	r.type = resourceType
	r.initial = current
	r.change = change
	results.append(r)
	return change


func war_execute(fromId: int, targetId: int) -> void :
	var wa = DataManager.get_war_actor(targetId)
	wa.dead("斩首")
	wa.actor().set_status_dead()
	var r = SkillResult.new()
	r.fromId = fromId
	r.actorId = targetId
	r.type = "斩首"
	results.append(r)
	return

func change_wv_gold(change: int, wv: War_Vstate = null) -> int:
	return change_wv_resource(change, "金", wv)

func change_wv_rice(change: int, wv: War_Vstate = null) -> int:
	return change_wv_resource(change, "米", wv)



func add_actor_soldiers(actorId: int, change: int, limit: int = - 1) -> int:
	return change_actor_soldiers(actorId, change, limit, 1)




func sub_actor_soldiers(actorId: int, change: int) -> int:
	return - change_actor_soldiers(actorId, - change, - 1, - 1)






func change_actor_soldiers(actorId: int, change: int, limit: int = - 1, changeFlag: int = 0) -> int:
	if change == 0:
		return 0
	var actor = ActorHelper.actor(actorId)
	var current = actor.get_soldiers()
	
	actor.set_soldiers(current)
	
	change = max(change, - current)
	
	if limit > 0:
		change = min(change, limit - current)
	
	if changeFlag > 0 and change <= 0:
		return 0
	if changeFlag < 0 and change >= 0:
		return 0
	actor.set_soldiers(current + change)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = actorId
	r.type = "兵力"
	r.initial = current
	r.change = change
	results.append(r)
	return change



func change_actor_ap(targetId: int, change: int, updateBuff: bool = true) -> int:
	if change == 0:
		return 0
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return 0
	var current = wa.action_point
	
	change = max( - current, change)
	wa.action_point = current + change
	if updateBuff:
		SkillHelper.update_all_skill_buff(skill_name)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "机动力"
	r.initial = current
	r.change = change
	results.append(r)
	if change > 0 and trigger_Id == 20013:
		
		if SkillHelper.actor_has_skills(targetId, ["燕歌"]):
			change_actor_exp(targetId, change * 100)
	return change




func change_actor_five_phases(targetId: int, phase: int, point: int) -> void :
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return
	if point < 0:
		point = Global.get_random(0, 9)
	point = max(0, point)
	point = min(9, point)
	if phase < 0:
		
		var currentPhase = wa.five_phases
		var currentPoint = wa.poker_point
		
		wa.refresh_poker_random()
		phase = wa.five_phases
		
		wa.five_phases = currentPhase
		wa.set_poker_point(currentPoint)
	if wa.five_phases != phase:
		var current = wa.five_phases
		wa.five_phases = phase
		var r = SkillResult.new()
		r.fromId = skill_actorId
		r.actorId = targetId
		r.type = "五行"
		r.initial = current
		r.change = phase
		results.append(r)
	if wa.poker_point != point:
		var current = wa.poker_point
		wa.set_poker_point(point)
		var r = SkillResult.new()
		r.fromId = skill_actorId
		r.actorId = targetId
		r.type = "点数"
		r.initial = current
		r.change = point
		results.append(r)
	return




func change_actor_exp(actorId: int, change: int) -> int:
	if change == 0:
		return 0
	var actor = ActorHelper.actor(actorId)
	var current = actor.get_exp()
	change = actor.add_exp(change)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = actorId
	r.type = "经验"
	r.initial = current
	r.change = change
	results.append(r)
	return change


func clear_actor_ap(actorId: int) -> int:
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return 0
	return change_actor_ap(actorId, - wa.action_point)



func change_actor_rice(targetId: int, change: int) -> int:
	if change == 0:
		return 0
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return 0
	var wv = wa.war_vstate()
	if wv == null:
		return 0
	var current = wv.rice
	
	change = max( - current, change)
	
	change = min(9999 - current, change)
	wv.rice = current + change
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "米"
	r.initial = current
	r.change = change
	results.append(r)
	return change



func change_actor_hp(targetId: int, change: int, low: int = - 1, high: int = - 1) -> int:
	if change == 0:
		return 0
	var actor = ActorHelper.actor(targetId)
	var current = int(actor.get_hp())
	if high >= 0:
		change = min(high - current, change)
	if low >= 0:
		change = max(low - current, change)
	change = actor.recover_hp(change)
	if change == 0:
		return 0
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "体力"
	r.initial = current
	r.change = change
	results.append(r)
	return change


func change_actor_scheme_chance(targetId: int, buff: int, damageSoldiersOnly: bool = true) -> void :
	var dic = get_war_skill_val_dic(SCHEME_CHANCE_EFFECT_ID, targetId)
	var key = "{0}|{1}".format([skill_name, skill_actorId])
	dic[key] = [buff, 1 if damageSoldiersOnly else 0]
	set_war_skill_val(dic, 1, SCHEME_CHANCE_EFFECT_ID, targetId)
	var info = "本回合计策命中+{0}".format([buff])
	add_custom_result(info, targetId)
	return

func get_scheme_chance_enhancement(targetId: int) -> int:
	var dic = get_war_skill_val_dic(SCHEME_CHANCE_EFFECT_ID, targetId)
	var key = "{0}|{1}".format([skill_name, skill_actorId])
	if not key in dic:
		return 0
	var buffed = Global.intarrval(dic[key])
	if buffed.size() != 2:
		return 0
	if buffed[1] == 1:
		var se = DataManager.get_current_stratagem_execution()
		if not se.damage_soldier():
			return 0
	return buffed[0]


func change_war_attr(targetId: int, attr: String, change: int) -> void :
	match attr:
		"武":
			change_war_power(targetId, change)
		"统":
			change_war_leadership(targetId, change)
		"知":
			change_war_wisdom(targetId, change)
		"政":
			change_war_politics(targetId, change)
		"胆":
			change_war_courage(targetId, change)
	return


func change_war_power(targetId: int, change: int, juniorLevel: bool = false) -> void :
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return
	var tag = "临武"
	if juniorLevel:
		tag = "附武"
	var current = Global.intval(wa.get_ext_variable(tag), 0)
	wa.set_ext_variable(tag, current + change)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "附加武力"
	r.initial = current
	r.change = change
	results.append(r)
	return


func change_war_wisdom(targetId: int, change: int, juniorLevel: bool = false) -> void :
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return
	var tag = "临知"
	if juniorLevel:
		tag = "附知"
	var current = Global.intval(wa.get_ext_variable(tag), 0)
	wa.set_ext_variable(tag, current + change)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "附加智力"
	r.initial = current
	r.change = change
	results.append(r)
	return


func change_war_leadership(targetId: int, change: int, juniorLevel: bool = false) -> void :
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return
	var tag = "临统"
	if juniorLevel:
		tag = "附统"
	var current = Global.intval(wa.get_ext_variable(tag), 0)
	wa.set_ext_variable(tag, current + change)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "附加统率"
	r.initial = current
	r.change = change
	results.append(r)
	return


func change_war_politics(targetId: int, change: int, juniorLevel: bool = false) -> void :
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return
	var tag = "临政"
	if juniorLevel:
		tag = "附政"
	var current = Global.intval(wa.get_ext_variable(tag), 0)
	wa.set_ext_variable(tag, current + change)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "附加政治"
	r.initial = current
	r.change = change
	results.append(r)
	return


func change_war_courage(targetId: int, change: int, juniorLevel: bool = false) -> void :
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return
	var tag = "临胆"
	if juniorLevel:
		tag = "附胆"
	var current = Global.intval(wa.get_ext_variable(tag), 0)
	wa.set_ext_variable(tag, current + change)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "附加胆"
	r.initial = current
	r.change = change
	results.append(r)
	return


func change_actor_attack_range(targetId: int, distance: int, days: int = 1, once: bool = true) -> void :
	var wa = DataManager.get_war_actor(targetId)
	var wf = DataManager.get_current_war_fight()
	wa.dic_other_variable["额外攻击距离"] = [wf.date + days - 1, distance, skill_name, int(once)]
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "攻击距离"
	r.initial = 1
	r.change = distance
	results.append(r)
	return



func add_war_skill(targetId: int, skill: String, turns: int, oppositeCD: bool = false, once: bool = false) -> void :
	SkillHelper.remove_scene_actor_skill(20000, targetId, skill)
	SkillHelper.add_actor_scene_skill(20000, targetId, skill, turns, skill_actorId, skill_name, oppositeCD, once)
	SkillHelper.update_all_skill_buff("ADD_WAR_SKILL")
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "技能|【{0}】".format([skill])
	r.initial = 0
	r.change = turns
	results.append(r)
	
	
	
	
	
	SkillHelper.save_skill_effectinfo(self)
	return


func remove_war_skill(targetId: int, skill: String) -> void :
	if not SkillHelper.remove_scene_actor_skill(20000, targetId, skill):
		return
	SkillHelper.update_all_skill_buff("REMOVE_WAR_SKILL")
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "技能|【{0}】".format([skill])
	r.initial = 0
	r.change = - 1
	results.append(r)
	
	
	
	
	
	SkillHelper.save_skill_effectinfo(self)
	return






func add_war_tmp_soldier(targetId: int, soldiers: int, limit: int = - 1) -> int:
	if limit < 0:
		limit = DataManager.get_actor_max_soldiers(targetId)
	var actor = ActorHelper.actor(targetId)
	var current = actor.get_soldiers()
	soldiers = min(limit - current, soldiers)
	if soldiers <= 0:
		return 0
	actor.add_tmp_soldiers(soldiers)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "兵力临时"
	r.initial = current
	r.change = soldiers
	results.append(r)
	return soldiers


func ban_war_skill(targetId: int, skillName: String, turns: int) -> bool:
	if SkillHelper.actor_has_skills(targetId, ["贞烈"]):
		return false
	var skill = StaticManager.get_skill(skillName)
	if skill == null:
		return false
	if not skill.can_be_banned():
		return false
	SkillHelper.ban_actor_skill(20000, targetId, skillName, turns, skill_actorId, skill_name)
	SkillHelper.update_all_skill_buff("BAN_WAR_SKILL")
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "技能|【{0}】".format([skillName])
	r.initial = 0
	r.change = - turns
	results.append(r)
	
	
	
	
	
	SkillHelper.save_skill_effectinfo(self)
	return true


func remove_war_buff(targetId: int, buff: String) -> bool:
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return false
	if wa.get_buff(buff)["回合数"] <= 0:
		return false
	
	wa.set_buff(buff, 0, skill_actorId, skill_name, true)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "状态|「{0}」".format([buff])
	r.initial = 0
	r.change = - 1
	results.append(r)
	return true


func set_war_buff(targetId: int, buff: String, turns: int, setOnly: bool = false) -> int:
	if turns <= 0:
		return 0
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return 0
	turns = wa.set_buff(buff, turns, skill_actorId, skill_name, setOnly)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "状态|「{0}」".format([buff])
	r.initial = 0
	r.change = turns
	results.append(r)
	
	
	
	
	
	SkillHelper.save_skill_effectinfo(self)
	return turns


func set_battle_buff(targetId: int, buff: String, turns: int) -> int:
	
	return set_war_buff(targetId, buff, turns)


func remove_battle_buff(targetId: int, buff: String) -> bool:
	return remove_war_buff(targetId, buff)


func swap_war_actor_positions(oneId: int, anotherId: int) -> bool:
	var one = DataManager.get_war_actor(oneId)
	var another = DataManager.get_war_actor(anotherId)
	if one == null or another == null:
		return false
	if not one.has_position() or not another.has_position():
		return false
	var pos = one.position
	one.position = another.position
	another.position = pos
	var r = SkillResult.new()
	r.fromId = oneId
	r.actorId = anotherId
	r.type = "互换位置"
	r.initial = 0
	r.change = 0
	results.append(r)
	return true


func change_war_actor_position(targetId: int, pos: Vector2) -> bool:
	var wa = DataManager.get_war_actor(targetId)
	if wa == null or wa.disabled:
		return false
	var current = wa.position
	if current == pos:
		return false
	wa.position = pos
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "移动"
	r.initial = current.x * 100 + current.y
	r.change = pos.x * 100 + pos.y
	results.append(r)
	return true



func replace_battle_defender(targetId: int, withId: int = - 1) -> bool:
	if withId < 0:
		withId = skill_actorId
	var bf = DataManager.get_current_battle_fight()
	if targetId != bf.targetId:
		return false
	bf.defenderId = withId
	
	if bf.terrian in StaticManager.CITY_BLOCKS_EN:
		bf.terrian = "land"
	var r = SkillResult.new()
	r.fromId = withId
	r.actorId = targetId
	r.type = "替代防御"
	r.initial = 0
	r.change = 0
	results.append(r)
	return true


func war_camp_in(targetId: int) -> bool:
	var wa = DataManager.get_war_actor(targetId)
	if wa == null or wa.disabled:
		return false
	wa.camp_in()
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "回营"
	r.initial = 0
	r.change = 0
	results.append(r)
	
	
	
	
	
	SkillHelper.save_skill_effectinfo(self)
	return true


func war_camp_out(targetId: int) -> bool:
	var me = DataManager.get_war_actor(skill_actorId)
	if me == null or me.disabled:
		return false
	var wv = me.war_vstate()
	if wv == null:
		return false
	wv.camp_out(targetId)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "出营"
	r.initial = 0
	r.change = 0
	results.append(r)
	
	
	
	
	
	SkillHelper.save_skill_effectinfo(self)
	return true





func add_team_exp_rate(rate: float, wv: War_Vstate = null) -> float:
	if wv == null:
		var wa = DataManager.get_war_actor(actorId)
		if wa == null:
			return 0.0
		wv = wa.war_vstate()
		if wv == null:
			return 0.0
	var leader = wv.get_leader()
	if leader == null:
		return 0.0
	var current = leader.get_ext_variable("团队经验加成", 0.0)
	leader.set_ext_variable("团队经验加成", current + rate)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = leader.actorId
	r.type = "团队经验加成"
	r.initial = int(current * 100)
	r.change = int(rate * 100)
	results.append(r)
	return leader.get_ext_variable("团队经验加成", 0.0)


func set_actor_ap_limit(targetId: int, val: int) -> void :
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return
	var current = wa.get_max_action_ap()
	var dic = Global.dicval(wa.get_ext_variable("机动力上限"))
	dic[skill_name] = val
	wa.set_ext_variable("机动力上限", dic)
	var changed = wa.get_max_action_ap()
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "机动力上限"
	r.initial = current
	r.change = changed - current
	results.append(r)
	return


func set_actor_extra_ap_limit(targetId: int, val: int) -> void :
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return
	var current = wa.get_max_action_ap()
	var dic = Global.dicval(wa.get_ext_variable("附加机动力上限"))
	dic[skill_name] = val
	wa.set_ext_variable("附加机动力上限", dic)
	var changed = wa.get_max_action_ap()
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "机动力上限"
	r.initial = current
	r.change = changed - current
	results.append(r)
	return


func set_actor_extra_max_hp(targetId: int, val: int, minVal: int = 10, accumulative: bool = false) -> void :
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return
	var current = wa.actor().get_max_hp()
	if current + val < minVal:
		if val < 0:
			val = 0
		else:
			val = minVal - current
	var dic = Global.dicval(wa.get_ext_variable("附加体力上限"))
	if accumulative and skill_name in dic:
		dic[skill_name] += val
	else:
		dic[skill_name] = val
	wa.set_ext_variable("附加体力上限", dic)
	var changed = wa.actor().get_max_hp()
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "体力上限"
	r.initial = current
	r.change = changed - current
	results.append(r)
	return

func set_war_skill_val(val, turns: int = 99999, effectId: int = - 1, targetId: int = - 1) -> void :
	set_skill_val(val, turns, effectId, 20000, targetId)
	return

func get_war_skill_val(effectId: int = - 1, targetId: int = - 1):
	return get_skill_val(20000, effectId, targetId)

func get_war_skill_val_int(effectId: int = - 1, targetId: int = - 1, defVal: int = 0) -> int:
	var val = get_war_skill_val(effectId, targetId)
	return Global.intval(val, defVal)

func get_war_skill_val_str(effectId: int = - 1, targetId: int = - 1, defVal: String = "") -> String:
	var val = get_war_skill_val(effectId, targetId)
	return Global.strval(val, defVal)

func get_war_skill_val_array(effectId: int = - 1, targetId: int = - 1) -> Array:
	var val = get_war_skill_val(effectId, targetId)
	return Global.arrval(val)

func get_war_skill_val_int_array(effectId: int = - 1, targetId: int = - 1) -> Array:
	var val = get_war_skill_val(effectId, targetId)
	return Global.intarrval(val)

func get_war_skill_val_dic(effectId: int = - 1, targetId: int = - 1) -> Dictionary:
	var dic = get_war_skill_val(effectId, targetId)
	if typeof(dic) != TYPE_DICTIONARY:
		return {}
	return Dictionary(dic)

func get_war_skill_val_vector(effectId: int = - 1, targetId: int = - 1, defVal = Vector2( - 1, - 1)) -> Vector2:
	var dic = get_war_skill_val_dic(effectId, targetId)
	if dic.empty():
		return defVal
	if not "x" in dic or not "y" in dic:
		return defVal
	return Vector2(Global.intval(dic["x"]), Global.intval(dic["y"]))


func set_battle_skill_val(val, turns: int = 99999, effectId: int = - 1) -> void :
	if effectId < 0:
		effectId = effect_Id
	SkillHelper.set_skill_variable(30000, effectId, skill_actorId, val, turns)
	return

func get_battle_skill_val(effectId: int = - 1):
	if effectId < 0:
		effectId = effect_Id
	var skv = SkillHelper.get_skill_variable(30000, effectId, skill_actorId)
	if skv["turn"] <= 0 or skv["value"] == null:
		return null
	return skv["value"]

func get_battle_skill_val_str(effectId: int = - 1, defVal: String = "") -> String:
	var val = get_battle_skill_val(effectId)
	if val == null:
		return defVal
	return Global.strval(val, defVal)

func get_battle_skill_val_int(effectId: int = - 1, defVal: int = - 1) -> int:
	var val = get_battle_skill_val(effectId)
	if val == null:
		return defVal
	return Global.intval(val, defVal)

func get_battle_skill_val_float(effectId: int = - 1) -> float:
	var val = get_battle_skill_val(effectId)
	if val == null:
		return 0.0
	return _floatval(val)

func get_battle_skill_val_array(effectId: int = - 1) -> Array:
	var arr = get_battle_skill_val(effectId)
	if typeof(arr) != TYPE_ARRAY:
		return []
	return _arrval(arr)

func get_battle_skill_val_int_array(effectId: int = - 1) -> PoolIntArray:
	var ret = []
	for item in get_battle_skill_val_array(effectId):
		if item == null:
			continue
		ret.append(int(item))
	return ret


func battle_cd(turns: int) -> void :
	if turns <= 0:
		return
	SkillHelper.set_skill_cd(30000, effect_Id, skill_actorId, turns, skill_name)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = skill_actorId
	r.type = "CD|【{0}】".format([skill_name])
	r.initial = 30000
	r.change = turns
	costs.append(r)
	return

func battle_get_skill_val(effectId: int = - 1, targetId: int = - 1):
	return get_skill_val(30000, effectId, targetId)

func battle_get_skill_val_int(effectId: int = - 1, targetId: int = - 1) -> int:
	return Global.intval(battle_get_skill_val(effectId, targetId), 0)

func battle_get_skill_val_int_array(effectId: int = - 1, targetId: int = - 1) -> Array:
	return Global.intarrval(battle_get_skill_val(effectId, targetId))

func battle_get_skill_val_dic(effectId: int = - 1, targetId: int = - 1) -> Dictionary:
	return Global.dicval(battle_get_skill_val(effectId, targetId))

func battle_set_skill_val(val, turns: int = 99999, effectId: int = - 1, targetId: int = - 1) -> void :
	set_skill_val(val, turns, effectId, 30000, targetId)
	return


func battle_enhance_current_unit(dic: Dictionary, requiredTypes: PoolStringArray = [], requiredEquip: String = "", forOthers: bool = false) -> Battle_Unit:
	var unitId = get_env_int("白兵.初始化单位ID")
	var bu = get_battle_unit(unitId)
	if bu == null or bu.disabled:
		return null
	if forOthers:
		if bu.leaderId != actorId:
			return null
	else:
		if bu.leaderId != skill_actorId:
			return null
	if not requiredTypes.empty():
		if "SOLDIERS" in requiredTypes:
			if not bu.is_soldier():
				return null
		elif not bu.get_unit_type() in requiredTypes:
			return null
	if requiredEquip != "" and not requiredEquip in bu.get_unit_equip():
		return null
	return battle_enhance_unit(bu, dic)


func battle_buff_unit(bu: Battle_Unit, buff: Dictionary = {}) -> Battle_Unit:
	if buff.empty():
		bu.dic_combat.erase(skill_name)
	bu.dic_combat[skill_name] = buff
	bu.requires_update = 1
	return bu


func battle_enhance_unit(bu: Battle_Unit, dic: Dictionary) -> Battle_Unit:
	if bu.dic_combat.has(skill_name):
		return null
	bu.dic_combat[skill_name] = 1
	for key in dic:
		if key in ["近战距离", "射击距离", "行动次数", "穿刺距离"]:
			
			var val = int(dic[key])
			var current = 0
			if bu.dic_combat.has(key):
				current = int(bu.dic_combat[key])
			val = max(val, current)
			bu.dic_combat[key] = val
			if key in ["行动次数"]:
				bu.wait_action_times = val
		elif key in ["格挡率"]:
			var val = float(dic[key])
			var current = 0
			if bu.dic_combat.has(key):
				current = float(bu.dic_combat[key])
			val = max(val, current)
			bu.dic_combat[key] = val
		elif key in ["图像", "新图像"]:
			bu.dic_combat[key] = str(dic[key])
		elif key in ["BUFF"]:
			bu.dic_combat[key] = int(dic[key])
		else:
			bu.append_combat_val(key, float(dic[key]))
	bu.requires_update = true
	return bu


func battle_unit_jump_forward(steps: int, bu: Battle_Unit, forced: bool = false) -> bool:
	if bu == null:
		return false
	if bu.dic_combat.has("布阵前突") and not forced:
		return false
	var limit = 9
	var rng = range( - steps, 0)
	var side = bu.get_side()
	if side == Vector2.LEFT:
		limit = 6
		rng = range(steps, 0, - 1)
	for x in rng:
		var pos = bu.unit_position + Vector2(x, 0)
		if not forced and side == Vector2.LEFT and pos.x > limit:
			continue
		if not forced and side == Vector2.RIGHT and pos.x < limit:
			continue
		if bu.can_move_to_position(pos):
			bu.unit_position = pos
			break
	bu.requires_update = true
	if forced:
		bu.dic_combat["布阵前突"] = 1
		var msg = "「{0}」单位#{1}向前跃进".format([bu.get_unit_type(), bu.unitId])
		add_custom_result(msg, bu.leaderId)
		return true
	bu.dic_combat["布阵前突"] = 1
	var msg = "「{0}」单位#{1}前置布阵".format([bu.get_unit_type(), bu.unitId])
	add_custom_result(msg, bu.leaderId)
	return true


func battle_change_courage(val: int, wa: War_Actor = null) -> int:
	if wa == null:
		wa = get_war_actor()
	if wa == null:
		return 0
	var current = wa.battle_courage
	
	val = max(val, - current)
	wa.battle_courage = current + val
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = wa.actorId
	r.type = "胆"
	r.initial = current
	r.change = val
	results.append(r)
	return val


func battle_change_power(val: int, wa: War_Actor = null) -> int:
	if wa == null:
		wa = get_war_actor()
	if wa == null:
		return 0
	var current = wa.get_battle_power()
	
	val = max(val, - current)
	wa.battle_power = current + val
	wa.recalculate_morale()
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = wa.actorId
	r.type = "武力临时"
	r.initial = current
	r.change = val
	results.append(r)
	return val


func battle_change_leadership(val: int, wa: War_Actor = null) -> int:
	if wa == null:
		wa = get_war_actor()
	if wa == null:
		return 0
	var current = wa.battle_lead
	
	val = max(val, - current)
	wa.battle_lead = current + val
	wa.recalculate_morale()
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = wa.actorId
	r.type = "统率临时"
	r.initial = current
	r.change = val
	results.append(r)
	return val


func battle_change_morale(val: int, wa: War_Actor = null) -> int:
	if wa == null:
		wa = get_war_actor()
	if wa == null:
		return 0
	var current = wa.battle_morale
	
	wa.battle_morale_extra += val
	wa.recalculate_morale()
	val = wa.battle_morale - current
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = wa.actorId
	r.type = "士气"
	r.initial = current
	r.change = val
	results.append(r)
	return val


func battle_change_tactic_point(val: int, wa: War_Actor = null) -> int:
	if wa == null:
		wa = get_war_actor()
	if wa == null:
		return 0
	var current = wa.battle_tactic_point
	
	val = max(val, - current)
	wa.battle_tactic_point = current + val
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = wa.actorId
	r.type = "战术"
	r.initial = current
	r.change = val
	results.append(r)
	return val



func battle_is_unit_hit_by(fromTypes: PoolStringArray, targetTypes: PoolStringArray, requiredActions: PoolStringArray, fromEnemy: bool = false) -> Battle_Unit:
	var fromUnitId = get_env_int("白兵伤害.来源")
	var fromUnit = get_battle_unit(fromUnitId)
	if fromUnit == null:
		return null
	if "SOLDIERS" in fromTypes:
		if fromUnit.get_unit_type() == "将":
			return null
	elif not "ALL" in fromTypes and not fromUnit.get_unit_type() in fromTypes:
		return null
	if not "ALL" in requiredActions and not fromUnit.last_action_name in requiredActions:
		return null
	var targetUnitId = get_env_int("白兵伤害.单位")
	var targetUnit = get_battle_unit(targetUnitId)
	if targetUnit == null:
		return null
	if fromEnemy:
		if fromUnit.leaderId == actorId or targetUnit.leaderId != actorId:
			return null
	else:
		if fromUnit.leaderId != actorId or targetUnit.leaderId == actorId:
			return null
	if "SOLDIERS" in targetTypes:
		if targetUnit.get_unit_type() == "将":
			return null
	elif not "ALL" in targetTypes and not targetUnit.get_unit_type() in targetTypes:
		return null
	var damage = get_env_float("白兵伤害.伤害")
	if damage < 0:
		return null
	return fromUnit



func battle_extra_damage(val: int, requiredTypes: PoolStringArray, requiredActions: PoolStringArray, targetUnitTypes: PoolStringArray = []) -> Battle_Unit:
	var bu = battle_is_unit_hit_by(requiredTypes, ["ALL"], requiredActions)
	if bu == null:
		return null
	var targetUnitId = get_env_int("白兵伤害.单位")
	var targetUnit = get_battle_unit(targetUnitId)
	if targetUnit == null:
		return null
	if not targetUnitTypes.empty():
		if "SOLDIERS" in targetUnitTypes:
			if targetUnit.get_unit_type() == "将":
				return null
		elif not "ALL" in targetUnitTypes:
			if not targetUnit.get_unit_type() in targetUnitTypes:
				return null
	var targets = get_env_int_array("白兵.刀类影响目标")
	if targets.size() > 1 and targetUnitId != targets[0]:
		
		return null
	targets = get_env_int_array("白兵.枪类影响目标")
	if targetUnitId in targets:
		
		return null
	if check_env(["白兵.剑类影响目标"]):
		
		
		return null
	var damage = get_env_float("白兵伤害.伤害")
	damage += val
	set_env("白兵伤害.伤害", damage)
	return bu


func battle_reduce_damage_rate(rate: float, targetTypes: PoolStringArray, fromTypes: PoolStringArray, requiredActions: PoolStringArray) -> bool:
	var bu = battle_is_unit_hit_by(fromTypes, targetTypes, requiredActions, true)
	if bu == null:
		return false
	var damage = get_env_float("白兵伤害.伤害")
	damage = damage * (1.0 - rate)
	set_env("白兵伤害.伤害", damage)
	return true



func battle_change_unit_hp(bu: Battle_Unit, change: int) -> int:
	if bu == null:
		return 0
	if change == 0:
		return 0
	var current = bu.get_hp()
	if bu.get_unit_type() == "将":
		var maxHP = bu.actor().get_max_hp()
		change = min(change, maxHP - current)
	if change == 0:
		return 0
	bu.set_hp(current + change, true)
	bu.requires_update = true
	
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = bu.unitId
	r.type = "单位体力"
	r.initial = current
	r.change = change
	results.append(r)
	return change



func battle_change_unit_armor(bu: Battle_Unit, change: int) -> int:
	if change == 0:
		return 0
	if bu == null or bu.get_unit_type() != "将":
		return 0
	var current = bu.extra_armor
	bu.extra_armor += change
	bu.requires_update = true
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = bu.leaderId
	r.type = "护甲"
	r.initial = current
	r.change = change
	results.append(r)
	return change

func get_report_messages() -> PoolStringArray:
	var ret = []
	var skill = skill()
	var move = "发动"
	var whose = ""
	if skill == null or skill.type != "主动":
		move = "触发"
	if actorId != skill_actorId:
		move = "触发"
		whose = "<y{0}>的".format([actor().get_name()])
	ret.append("- <y{0}>{1}{2}【<r{3}>】".format([
		actioner().get_name(), move, whose, skill_name, 
	]))
	for c in costs:
		var msg = c.record()
		if msg == "":
			continue
		ret.append("  - " + msg)
	var hpChanged = {}
	for r in results:
		
		if r.type == "单位体力":
			var bu = get_battle_unit(r.actorId)
			if bu == null:
				continue
			var wa = DataManager.get_war_actor(bu.leaderId)
			if wa == null:
				continue
			if bu.get_unit_type() == "将":
				var msg = "  - <y{0}>体力{1}{2} -> {3}".format([
					wa.get_name(), r._get_change_memo(), 
					abs(r.change), r.initial + r.change, 
				])
				ret.append(msg)
				continue
			var key = wa.get_name()
			if not hpChanged.has(key):
				hpChanged[key] = [0, 0]
			hpChanged[key][0] += 1
			hpChanged[key][1] += r.change
			continue
		var msg = r.record()
		if msg == "":
			continue
		ret.append("  - " + msg)
	for k in hpChanged:
		var units = hpChanged[k][0]
		var change = hpChanged[k][1]
		var action = "回复"
		if change < 0:
			action = "下降"
		var msg = "  - <y{0}>{1}单位兵力{2}{3}".format([
			k, units, action, abs(change), 
		])
		ret.append(msg)
	for l in logs:
		ret.append(l)
	return ret


func war_report() -> void :
	if recorded > 0:
		return
	var msgs = get_report_messages()
	if msgs.size() <= 1:
		return
	DataManager.record_war_log("\n".join(msgs))
	recorded = 1
	return


func battle_report() -> void :
	if recorded > 0:
		return
	var bf = DataManager.get_current_battle_fight()
	var msgs = get_report_messages()
	if msgs.size() <= 1:
		return
	bf.battle_log.append("\n".join(msgs))
	recorded = 1
	return


func get_report_message() -> PoolStringArray:
	var ret = []
	for c in costs:
		var msg = c.report()
		if msg == "":
			continue
		ret.append(msg)
	for r in results:
		var msg = r.report()
		if msg == "":
			continue
		ret.append(msg)
	return ret



class SkillResult:
	var fromId: int
	var actorId: int
	var type: String
	var initial: int
	var change: int

	func output_data() -> Dictionary:
		return {
			"fromId": fromId, 
			"actorId": actorId, 
			"type": type, 
			"initial": initial, 
			"change": change, 
		}

	func input_data(data) -> bool:
		if typeof(data) != TYPE_DICTIONARY:
			return false
		if data.empty():
			return false
		if "fromId" in data:
			fromId = int(data["fromId"])
		if "actorId" in data:
			actorId = int(data["actorId"])
		if "type" in data:
			type = str(data["type"])
		if "initial" in data:
			initial = int(data["initial"])
		if "change" in data:
			change = int(data["change"])
		return true

	
	func record() -> String:
		var wa = DataManager.get_war_actor(actorId)
		if wa == null:
			return ""
		var from = DataManager.get_war_actor(fromId)
		var pieces = type.split("|")
		var data = [wa.get_name(), type, _get_change_memo(), abs(change), initial + change]
		var msg = "<y{0}>{1}{2}<r{3}> -> {4}"
		match pieces[0]:
			"自定义":
				msg = pieces[1]
				if fromId != actorId:
					msg = "<y{0}>{1}".format([wa.get_name(), pieces[1]])
				return msg
			"变换兵种":
				var source = ""
				if fromId != actorId:
					source = "<y{0}>".format([from.get_name()])
				return "因{5}【<r{4}>】<y{0}>的<y{1}>个<y{2}>变成<y{3}>".format([
					wa.get_name(), change, pieces[1], pieces[2], pieces[3], source
				])
			"CD":
				var skill = pieces[1]
				var suffix = ""
				if DataManager.get_current_scene_id() == 30000 and initial == 20000:
					suffix = "大战场"
				return "<y{0}>的<r{1}>进入{3}<y{2}>回合CD".format([
					wa.get_name(), skill, change, suffix, 
				])
			"斩首":
				return "<y{0}>被<y{1}>斩首".format([
					wa.get_name(), from.get_name(), 
				])
			"次数":
				return "技能发动次数：<y{0}/{1}>".format([change, initial])
			"出营":
				return "已令<y{0}>出营".format([
					ActorHelper.actor(actorId).get_name(), 
				])
			"回营":
				var action = ""
				if actorId != fromId:
					action = "被迫"
				return "<y{0}>{1}回营".format([
					ActorHelper.actor(actorId).get_name(), action, 
				])
			"替代防御":
				return "<y{0}>替代<y{1}>防守白刃战".format([
					ActorHelper.actor(fromId).get_name(), 
					ActorHelper.actor(actorId).get_name(), 
				])
			"互换位置":
				return "<y{0}>和<y{1}>互换位置".format([
					ActorHelper.actor(fromId).get_name(), 
					ActorHelper.actor(actorId).get_name(), 
				])
			"移动":
				var m = "<y{0}>移动到<<r{1},{2}>>".format([
					ActorHelper.actor(actorId).get_name(), int(change / 100), change % 100, 
				])
				if fromId != actorId:
					m = "<y{0}>令{1}".format([ActorHelper.actor(fromId).get_name(), m])
				return m
			"技能":
				data[1] = type.split("|")[1]
				msg = "<y{0}>解锁技能<r{1}>，回合数<y{3}>"
				if change < 0:
					msg = "<y{0}>失去技能<r{1}>"
			"状态":
				data[1] = type.split("|")[1]
				msg = "<y{0}>进入<g{1}>状态，回合数<y{3}>"
				if change < 0:
					msg = "<y{0}>解除<g{1}>状态"
			"五行":
				return "<y{0}>的五行变为<r{1}>".format([
					wa.get_name(), War_Character.get_five_phases_string(change)
				])
			"点数":
				return "<y{0}>的点数变为<r{3}>".format(data)
		if change == 0:
			return ""
		if type in ["金", "米"]:
			data[0] = wa.get_lord_name() + "军"
		return msg.format(data)

	
	func report() -> String:
		if type == "回营":
			var action = ""
			if actorId != fromId:
				action = "被迫"
			return "{0}{1}回营".format([
				ActorHelper.actor(actorId).get_name(), action, 
			])
		var wa = DataManager.get_war_actor(actorId)
		if wa == null:
			return ""
		if type.begins_with("CD"):
			return ""
		if type.begins_with("自定义|"):
			var pieces = type.split("|")
			var msg = pieces[1]
			if fromId != actorId:
				msg = "{0}{1}".format([wa.get_name(), msg])
			var cleared = ""
			
			var last = 0
			var cur = msg.find("<", last)
			while cur >= 0 and cur < msg.length() - 1:
				if not msg[cur + 1] in ["y", "g", "r", "b"]:
					cleared += msg.substr(last, cur + 1)
					last = cur + 1
					cur = msg.find("<", last)
					continue
				var paired = msg.find(">", cur + 2)
				if paired < 0:
					cleared += msg.substr(last, cur + 1)
					last = cur + 1
					cur = msg.find("<", last)
					continue
				cleared += msg.substr(last, cur - last)
				cleared += msg.substr(cur + 2, paired - cur - 2)
				last = paired + 1
				cur = msg.find("<", last)
			cleared += msg.substr(last)
			return cleared
		var data = [wa.get_name(), type, _get_change_memo(), abs(change), initial + change]
		var msg = "{0}{1}{2}{3}"
		if type == "次数":
			return ""
		
		if type == "替代防御":
			return "{0}替代{1}防守白刃战".format([
				ActorHelper.actor(fromId).get_name(), 
				ActorHelper.actor(actorId).get_name(), 
			])
		if type == "互换位置":
			return "{0}和{1}互换位置".format([
				ActorHelper.actor(fromId).get_name(), 
				ActorHelper.actor(actorId).get_name(), 
			])
		if type.begins_with("技能"):
			data[1] = type.split("|")[1]
			msg = "{0}解锁技能{1}"
			if change < 0:
				msg = "{0}失去技能{1}"
		if type.begins_with("状态"):
			data[1] = type.split("|")[1]
			msg = "{0}获得{1}{3}回合"
			if change < 0:
				msg = "{0}解除{1}状态"
			else:
				var brief = "获得{1}{3}回合"
				if change >= 90000:
					brief = "进入持续{1}状态"
				match data[1]:
					"「禁止攻击移动」":
						brief = "无法攻击、移动"
					"「沉默」":
						brief = "无法发动技能"
				if change == 1:
					brief = "本回合内{1}"
				msg = "{0}" + brief
		if type == "五行":
			return "{0}的{1}变为{2}".format([
				wa.get_name(), type, War_Character.get_five_phases_string(change), 
			])
		if type == "点数":
			return "{0}的{1}变为{2}".format([
				wa.get_name(), type, change, 
			])
		if change == 0:
			return ""
		if type in ["金", "米"]:
			data[0] = wa.get_lord_name() + "军"
			msg = "{0}{1}{2}{3}，至{4}"
		return msg.format(data)

	func _get_change_memo() -> String:
		if type.begins_with("替代"):
			return "设为"
		var memos = ["回复", "减少"]
		if type in ["经验", "武力临时", "智力临时", "统率临时", "士气", "体上限", "团队经验加成", "机动力上限"]:
			memos = ["提高", "降低"]
		if type.begins_with("附加"):
			memos = ["提高", "降低"]
		if change < 0:
			return memos[1]
		return memos[0]


func play_war_animation(anim: String, nextViewModel: int, animId: int, msg: String, mood: int = 2) -> void :
	SceneManager.play_war_animation(anim, animId, "", msg, skill_actorId, mood)
	LoadControl.set_view_model(nextViewModel)
	return


func play_se_animation(se, nextViewModel: int, msg: String = "", mood: int = 2) -> void :
	if msg == "":
		msg = se.get_message()
	var wa = DataManager.get_war_actor(se.get_action_id())
	var speaker = wa
	if wa != null and wa.get_controlNo() < 0:
		speaker = DataManager.get_war_actor(se.targetId)
	DataManager.set_env("对话PENDING", se.get_report_message(speaker, wa))
	play_war_animation(se.get_animation(), nextViewModel, se.targetId, msg, mood)
	return

func get_battle_unit(unitId: int) -> Battle_Unit:
	if unitId < 0 or unitId >= DataManager.battle_units.size():
		return null
	return DataManager.battle_units[unitId]

func get_war_actor() -> War_Actor:
	return DataManager.get_war_actor(skill_actorId)


func append_message(msg: String, targetId: int = - 1) -> void :
	var first = true
	for m in msg.split("\n"):
		if first:
			if targetId >= 0:
				m = "<y{0}>{1}".format([
					ActorHelper.actor(targetId).get_name(), m
				])
			logs.append("  - " + m)
			first = false
		else:
			logs.append("    - " + m)
	return


func battle_change_units_type(targetId: int, units: Array, type: String) -> int:
	var changed = {}
	var total = 0
	for unit in units:
		if unit == null or unit.disabled or unit.leaderId != targetId:
			continue
		var ut = unit.get_unit_type()
		if ut == type:
			continue
		if not changed.has(ut):
			changed[ut] = 0
		changed[ut] += 1
		total += 1
		var originalTimes = unit.get_action_times()
		unit.reset_type(type)
	for ut in changed:
		var r = SkillResult.new()
		r.fromId = skill_actorId
		r.actorId = targetId
		r.type = "变换兵种|{0}|{1}|{2}".format([ut, type, skill_name])
		r.initial = 0
		r.change = changed[ut]
		costs.append(r)
	return total


func disable_skill_buff_type(side: String, type: String) -> void :
	var disabled = []
	disabled.append_array(disabled_skill_buff_types())
	disabled.append(side + "|" + type)
	ext_flags["disabled_skill_buff"] = disabled
	append_message("<y{0}>【{1}】禁用{2}的{3}计 #{4}".format([
		ActorHelper.actor(skill_actorId).get_name(), skill_name, side, type, 
		trigger_Id % 10000, 
	]))
	return


func disabled_skill_buff_types() -> PoolStringArray:
	var ret = []
	if not ext_flags.has("disabled_skill_buff"):
		return ret
	var arr = ext_flags["disabled_skill_buff"]
	if typeof(arr) != TYPE_ARRAY:
		return ret
	for item in arr:
		ret.append(str(item))
	return ret


func battle_add_skill(targetId: int, skill: String, turns: int) -> void :
	SkillHelper.remove_scene_actor_skill(30000, targetId, skill)
	SkillHelper.add_actor_scene_skill(30000, targetId, skill, turns, skill_actorId, skill_name)
	SkillHelper.update_all_skill_buff("BATTLE_ADD_SKILL")
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "技能|【{0}】".format([skill])
	r.initial = 0
	r.change = turns
	results.append(r)
	
	
	
	
	
	SkillHelper.save_skill_effectinfo(self)
	return


func battle_remove_skill(targetId: int, skill: String) -> void :
	SkillHelper.remove_scene_actor_skill(30000, targetId, skill)
	SkillHelper.update_all_skill_buff("BATTLE_REMOVE_SKILL")
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "技能|【{0}】".format([skill])
	r.initial = 0
	r.change = - 99999
	results.append(r)
	
	
	
	
	
	SkillHelper.save_skill_effectinfo(self)
	return




func battle_cost_limited_times(limit: int) -> bool:
	var times = get_battle_skill_val_int( - 1, 0)
	if times >= limit:
		battle_cd(99999)
		set_battle_skill_val(0, 0)
		return false
	times = times + 1
	if times >= limit:
		
		battle_cd(99999)
		set_battle_skill_val(0, 0)
	else:
		set_battle_skill_val(times)
		var r = SkillResult.new()
		r.fromId = skill_actorId
		r.actorId = skill_actorId
		r.type = "次数"
		r.initial = limit
		r.change = times
		results.append(r)
	return true


func get_battle_skill_property() -> SKill_For_Battle.Skill_Battle_Property:
	var sbp = SKill_For_Battle.Skill_Battle_Property.new()
	sbp.input(DataManager.get_env_dict("技能白兵附加"))
	return sbp


func apply_battle_skill_property(sbp: SKill_For_Battle.Skill_Battle_Property):
	
	var current = get_battle_skill_property()
	var changes = [
		["附加统", current.leader, sbp.leader], 
		["附加胆", current.courage, sbp.courage], 
		["附加武", current.power, sbp.power], 
		["附加战术值", current.tp, sbp.tp], 
	]
	for change in changes:
		if change[1] != change[2]:
			var r = SkillResult.new()
			r.fromId = skill_actorId
			r.actorId = actorId
			r.type = change[0]
			r.initial = change[1]
			r.change = change[2] - change[1]
			results.append(r)
	if sbp.alternative_wisdom_for_tp > 0:
		var r = SkillResult.new()
		r.fromId = skill_actorId
		r.actorId = skill_actorId
		r.type = "替代战术智力"
		r.initial = 0
		r.change = sbp.alternative_wisdom_for_tp
		results.append(r)
	DataManager.set_env("技能白兵附加", sbp.output())
	return



func clear_actor_skill_cd(targetId: int, sceneIdList: PoolIntArray = [], effectIdList: PoolIntArray = [], minCD: int = - 1, maxCD: int = 90000) -> Dictionary:
	return reduce_actor_skill_cd(targetId, 99999, sceneIdList, effectIdList, minCD, maxCD)



func reduce_actor_skill_cd(targetId: int, reduce: int, sceneIdList: PoolIntArray = [], effectIdList: PoolIntArray = [], minCD: int = - 1, maxCD: int = 90000) -> Dictionary:
	var ret = {}
	for key in DataManager.skill_cd.keys():
		if not DataManager.skill_cd.has(key):
			continue
		var pieces = str(key).split("/")
		var sceneId = int(pieces[0])
		var effectId = int(pieces[1])
		var _actorId = int(pieces[2])
		if _actorId != targetId:
			continue
		if not sceneIdList.empty() and not sceneId in sceneIdList:
			continue
		if not effectIdList.empty() and not effectId in effectIdList:
			continue
		var cd = int(DataManager.skill_cd[key])
		if cd < minCD or cd > maxCD:
			continue
		var cdLeft = cd - reduce
		if cdLeft > 0:
			DataManager.skill_cd[key] = cdLeft
		else:
			DataManager.skill_cd.erase(key)
			cdLeft = 0
		
		if pieces.size() > 3 and pieces[3] != "":
			var skillName = pieces[3]
			ret[skillName] = cdLeft
			var msg = "【<r{0}>】的冷却被清除"
			if cdLeft > 0:
				msg = "【<r{0}>】的冷却减为<y{1}>"
			msg = msg.format([skillName, cdLeft])
			append_message(msg, targetId)
	SkillHelper.update_all_skill_buff("REDUCE_SKILL_CD")
	return ret

func change_city_property(cityId: int, prop: String, change: int) -> int:
	if change == 0:
		return 0
	var city = clCity.city(cityId)
	var current = int(city.get_property(prop))
	
	change = max( - current, change)
	city.add_city_property(prop, change)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = skill_actorId
	r.type = "令{0}{1}".format([city.get_full_name(), prop])
	r.initial = current
	r.change = change
	results.append(r)
	return change

func add_custom_result(msg: String, targetId: int = - 1) -> void :
	if targetId < 0:
		targetId = actorId
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "自定义|" + msg
	r.initial = 0
	r.change = 0
	results.append(r)
	return

func change_war_date(date: int) -> int:
	date = max(1, date)
	date = min(30, date)
	var wf = DataManager.get_current_war_fight()
	if wf == null:
		return - 1
	if wf.date == date:
		return wf.date
	var initial = wf.date
	wf.date = date
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = actorId
	r.type = "自定义|战争日期由<y{0}>变为<y{1}>".format([
		initial, wf.date
	])
	r.initial = initial
	r.change = wf.date
	results.append(r)
	return wf.date


func ban_battle_skill(targetId: int, skillName: String, turns: int) -> bool:
	if SkillHelper.actor_has_skills(targetId, ["贞烈"]):
		return false
	var skill = StaticManager.get_skill(skillName)
	if skill == null:
		return false
	if not skill.can_be_banned():
		return false
	SkillHelper.ban_actor_skill(30000, targetId, skillName, turns, skill_actorId, skill_name)
	SkillHelper.update_all_skill_buff("BAN_BATTLE_SKILL")
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "技能|【{0}】".format([skillName])
	r.initial = 0
	r.change = - turns
	results.append(r)
	
	
	
	
	
	SkillHelper.save_skill_effectinfo(self)
	return true


func mark_auto_finish_turn() -> void :
	ext_flags["auto_finish_turn"] = 1
	return

func will_auto_finish_turn() -> bool:
	if not "auto_finish_turn" in ext_flags:
		return false
	return Global.intval(ext_flags["auto_finish_turn"]) > 0


func disable_scheme(targetId: int, schemeName: String, cd: int) -> bool:
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return false
	var initial = 0
	if schemeName in wa.dic_skill_cd:
		initial = int(wa.dic_skill_cd[schemeName])
	wa.dic_skill_cd[schemeName] = cd
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "自定义|<y{0}>的计策<y{1}>禁用<r{2}>回合".format([
		ActorHelper.actor(targetId).get_name(), 
		schemeName, cd
	])
	if targetId != skill_actorId:
		r.type = "自定义|的计策<y{0}>禁用<r{1}>回合".format([
			schemeName, cd
		])
	r.initial = initial
	r.change = cd
	results.append(r)
	return true


func recover_disabled_scheme(targetId: int, schemeName: String) -> bool:
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return false
	if not schemeName in wa.dic_skill_cd:
		return false
	var initial = int(wa.dic_skill_cd[schemeName])
	wa.dic_skill_cd.erase(schemeName)
	var r = SkillResult.new()
	r.fromId = skill_actorId
	r.actorId = targetId
	r.type = "自定义|<y{0}>的计策<y{1}>解禁".format([
		ActorHelper.actor(targetId).get_name(), 
		schemeName, 
	])
	if targetId != skill_actorId:
		r.type = "自定义|的计策<y{0}>解禁".format([
			schemeName, 
		])
	r.initial = initial
	r.change = - initial
	results.append(r)
	return true

func battle_change_actor_equip(actorId: int, type: String, equipId: int) -> bool:
	var wa = DataManager.get_war_actor(actorId)
	if wa == null or wa.disabled:
		return false
	wa.actor().set_battle_equip(type, equipId)
	var bu = wa.battle_actor_unit()
	if bu != null:
		
		bu.init_combat_info()
	return true

