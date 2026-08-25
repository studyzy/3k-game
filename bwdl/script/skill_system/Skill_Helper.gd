# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/skill_system/Skill_Helper.gd
# 说明：技能辅助（自动加载，核心）。负责技能触发判定、Buff 更新等技能系统调度。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Node



func new_ske_from_range_buff(actorId: int, srb: SkillRangeBuff) -> SkillEffectInfo:
	var ske = SkillEffectInfo.new()
	ske.actorId = actorId
	ske.trigger_Id = srb.triggerId
	ske.effect_Id = srb.effectId
	ske.effect_type = srb.effectType
	ske.skill_name = srb.skillName
	ske.skill_actorId = srb.actorId
	return ske

func new_ske_from_cheater() -> SkillEffectInfo:
	var ske = SkillEffectInfo.new()
	var player = null
	for p in DataManager.players:
		player = p
		break
	ske.actorId = player.actorId
	ske.trigger_Id = - 1
	ske.effect_Id = - 1
	ske.effect_type = "作弊"
	ske.skill_name = "天降正义"
	ske.skill_actorId = player.actorId
	return ske

func new_ske_from_equip_simulation(actorId: int, equip: clEquip.EquipInfo) -> SkillEffectInfo:
	var ske = SkillEffectInfo.new()
	ske.actorId = actorId
	ske.trigger_Id = - 1
	ske.effect_Id = - 1
	ske.effect_type = "锁定"
	ske.skill_name = equip.name() + "效果"
	ske.skill_actorId = actorId
	return ske

func save_skill_effectinfo(ske: SkillEffectInfo):
	DataManager.ske = ske

func read_skill_effectinfo() -> SkillEffectInfo:
	return DataManager.ske

func add_skill_triggerinfo(st: SkillTriggerInfo):
	var st_array = DataManager.cur_skill_triggers;
	st_array.append(st);
	
func get_skill_trigger_list() -> Array:
	if (DataManager.cur_skill_triggers.empty()):
		return [];
	return DataManager.cur_skill_triggers;

func get_current_skill_trigger() -> SkillTriggerInfo:
	var array = get_skill_trigger_list();
	if (array.empty()):
		return null;
	return array[0];

func remove_current_skill_trigger():
	var array = get_skill_trigger_list();
	if (array.empty()):
		return ;
	var st: SkillTriggerInfo = array.pop_front();
	st.call_deferred("free");

func remove_all_skill_trigger():
	while (get_current_skill_trigger() != null):
		remove_current_skill_trigger();











func get_actor_default_skill_names(actorId: int, specifiedSide: String = "") -> Dictionary:
	
	
	if actorId == StaticManager.ACTOR_ID_LIUXIE:
		var liubian = ActorHelper.actor(StaticManager.ACTOR_ID_LIUBIAN)
		if not liubian.is_status_officed():
			SkillHelper.clear_ban_actor_skill(10000, [StaticManager.ACTOR_ID_LIUXIE], [], [StaticManager.ACTOR_ID_LIUBIAN])
	
	var ret = {}
	for lv in range(1, 9):
		ret["LV" + str(lv)] = ""
	if actorId < 0 or actorId >= StaticManager.actor_skills.size():
		return ret
	var actor = ActorHelper.actor(actorId)
	if specifiedSide == "":
		specifiedSide = actor.get_side()
	var actorSkillData = StaticManager.actor_skills[actorId].duplicate()
	
	
	if actorId == StaticManager.ACTOR_ID_DIY:
		actorSkillData = actor.get_diy_skills()

	for key in ret:
		if not key in actorSkillData:
			continue
		var skillData = Global.strval(actorSkillData[key])
		if skillData == "":
			continue
		var skillDataArray = skillData.split("/")
		var sideIdx = 0
		if specifiedSide in ["阴", "醉", "魂"]:
			sideIdx = 1
		elif not specifiedSide in ["", "阳"]:
			
			continue
		if sideIdx >= skillDataArray.size():
			sideIdx = 0
		ret[key] = skillDataArray[sideIdx]

	
	for key in ret:
		if ret[key] == "":
			continue
		
		var skill = StaticManager.get_skill(ret[key])
		if skill == null:
			continue
		var upgraded = skill.upgraded_for_actor(actorId)
		if upgraded != "":
			ret[key] = upgraded
	return ret





func get_actor_unlocked_skill_names(actorId: int, specifiedSide: String = "") -> Dictionary:
	var ret = {}
	var defaults = get_actor_default_skill_names(actorId, specifiedSide)
	var actor = ActorHelper.actor(actorId)
	var level = actor.get_level()
	if actor.get_equip_feature_max("技能无视等级限制", true) > 0:
		level = 8
	for lv in range(1, level + 1):
		var key = "LV{0}".format([lv])
		if not key in defaults:
			continue
		if defaults[key] == "":
			continue
		ret[key] = defaults[key]
	return ret




func get_actor_locked_skill_names(actorId: int, specifiedSide: String = "") -> Dictionary:
	var ret = {}
	var defaults = get_actor_default_skill_names(actorId, specifiedSide)
	var actor = ActorHelper.actor(actorId)
	var level = actor.get_level()
	if actor.get_equip_feature_max("技能无视等级限制", true) > 0:
		level = 8
	for lv in range(level + 1, 9):
		var key = "LV{0}".format([lv])
		if not key in defaults:
			continue
		if defaults[key] == "":
			continue
		ret[key] = defaults[key]
	return ret









func get_actor_scene_skills(actorId: int, sceneId: int = - 1) -> Array:
	var ret = []
	var key = str(actorId)
	if not key in DataManager.actor_scene_skill:
		return ret
	for dic in DataManager.actor_scene_skill[key]:
		if sceneId != - 1 and int(dic["sceneId"]) > sceneId:
			continue
		if not dic.has("turn") or int(dic["turn"]) <= 0:
			continue
		
		var skill = StaticManager.get_skill(dic["skill_name"])
		if skill == null:
			continue
		var upgraded = skill.upgraded_for_actor(actorId)
		if upgraded != "":
			dic = dic.duplicate(true)
			dic["skill_name"] = upgraded
		ret.append(dic)
	return ret










func get_actor_skill_disabled_reason(sceneId: int, actorId: int, skillName: String) -> Array:
	var skill = StaticManager.get_skill(skillName)
	if skill == null:
		return ["无效技能", ""]
	var actor = ActorHelper.actor(actorId)
	
	if not skill.exclusive_valid_for_actor(actorId):
		return ["专属技能", ""]
	
	if not skill.gender_valid_for_actor(actorId):
		return ["、".join(skill._gendersOnly) + "性限定", ""]
	
	if not skill.can_be_banned():
		return []
	
	if sceneId >= 20000:
		var wa = DataManager.get_war_actor(actorId)
		if wa != null:
			
			for buff in wa.get_buffs_with_label(["沉默"]):
				
				if buff["name"] == "战斗沉默" and sceneId < 30000:
					continue
				var fromId = int(buff["来源武将"])
				var fromName = ""
				if fromId >= 0:
					fromName = ActorHelper.actor(fromId).get_name()
				var msg = "已被{0}沉默".format([fromName])
				return [msg, ""]
		if wa == null or wa.disabled:
			var evenDisabled = false
			for eff in skill.effects:
				
				if eff.type == "特殊" or eff.triggerExceptional:
					evenDisabled = true
					break
			if not evenDisabled:
				return ["状态异常", ""]
	
	for checkSceneId in [10000, 20000, 30000, 40000]:
		if checkSceneId > sceneId:
			continue
		var key = "{0}/{1}/{2}".format([checkSceneId, actorId, skillName])
		for k in DataManager.actor_ban_scene_skill:
			if not k.begins_with(key):
				continue
			var turn = 99999
			var pieces = k.split("/")
			
			if pieces[2] != skillName:
				continue
			if pieces.size() > 3:
				turn = Global.intval(pieces[3])
			if turn <= 0:
				continue
			if pieces.size() > 5:
				var fromId = Global.intval(pieces[4])
				var fromSource = pieces[5]
				var msg = "因{0}<{1}>被禁用".format([
					ActorHelper.actor(fromId).get_name(), fromSource
				])
				return [msg, fromSource]
	return []






func actor_skill_disabled(sceneId: int, actorId: int, skillName: String) -> bool:
	var reason = get_actor_skill_disabled_reason(sceneId, actorId, skillName)
	return not reason.empty()






func get_actor_basic_skills(actorId: int, specifiedSceneId: int = - 1, specifiedSide: String = "") -> Array:
	if DataManager.get_game_setting("技能系统") != "是":
		return []

	var sceneId = specifiedSceneId
	if sceneId <= 0:
		sceneId = DataManager.get_current_scene_id()

	var actor = ActorHelper.actor(actorId)

	var found = []
	
	for unlocked in get_actor_unlocked_skill_names(actorId, specifiedSide).values():
		if unlocked in found:
			continue
		found.append(unlocked)

	
	for dic in get_actor_scene_skills(actorId, sceneId):
		var skillName = dic["skill_name"]
		if skillName in found:
			continue
		found.append(skillName)

	
	found = skill_testing_inject_before(actor, found)

	
	var ret = []
	for skillName in found:
		if actor_skill_disabled(sceneId, actorId, skillName):
			continue
		
		var skill = StaticManager.get_skill(skillName)
		ret.append(skill)

	return ret






func get_actor_appended_skills(actorId: int, skill: StaticManager.Skill, limitedSceneId: int = - 1) -> Array:
	var ret = []
	for effect in get_skill_effects(actorId, skill):
		
		for appendedName in effect.get_appended_skill_names(actorId):
			var appended = StaticManager.get_skill(appendedName)
			if appended == null:
				continue
			
			var upgraded = appended.upgraded_for_actor(actorId)
			if upgraded != "":
				appended = StaticManager.get_skill(upgraded)
			ret.append(appended)
		if not effect.appendSkill:
			continue
		if limitedSceneId >= 0 and effect.sceneId > limitedSceneId:
			continue
		var gd = Global.load_script(effect.path)
		gd.actorId = actorId
		for name in gd.appended_skill_list():
			var appended = StaticManager.get_skill(name)
			if appended == null:
				continue
			
			var upgraded = appended.upgraded_for_actor(actorId)
			if upgraded != "":
				appended = StaticManager.get_skill(upgraded)
			ret.append(appended)
	return ret







func get_actor_all_skills(actorId: int, specifiedSceneId: int = - 1, skipAppendedSkills: bool = false) -> Array:
	
	if actorId >= StaticManager.ACTOR_ID_RENOU:
		return []
	var sceneId = specifiedSceneId
	if specifiedSceneId < 0:
		sceneId = DataManager.get_current_scene_id()
	var basics = get_actor_basic_skills(actorId, sceneId)
	if skipAppendedSkills:
		var ret = []
		for skill in basics:
			ret.append([skill, null])
		return ret
	
	var ret = []
	
	var added = []
	var checking = basics.duplicate()
	var checked = []
	while not checking.empty():
		var skill = checking.pop_front()
		if skill in checked:
			continue
		checked.append(skill)
		if not skill in added:
			ret.append([skill, null])
			added.append(skill)
		for appended in get_actor_appended_skills(actorId, skill, sceneId):
			if not appended in added:
				ret.append([appended, skill])
				added.append(appended)
			checking.append(appended)
	return ret


var SKILLS_LIST_CACHE = {}
var SKILLS_LIST_CACHE_ENABLED = false

func reset_skills_list_cache(enabled: bool = false):
	SKILLS_LIST_CACHE.clear()
	SKILLS_LIST_CACHE_ENABLED = enabled
	return






func get_actor_skills(actorId: int, specifiedSceneId: int = - 1, skipAppendedSkills: bool = false) -> Array:
	var cacheKey = "{0}.{1}.{2}".format([actorId, specifiedSceneId, 1 if skipAppendedSkills else 0])
	if SKILLS_LIST_CACHE_ENABLED and SKILLS_LIST_CACHE.has(cacheKey):
		return SKILLS_LIST_CACHE[cacheKey]
	var ret = []
	for item in get_actor_all_skills(actorId, specifiedSceneId, skipAppendedSkills):
		ret.append(item[0])
	SKILLS_LIST_CACHE[cacheKey] = ret
	return ret






func get_actor_skill_names(actorId: int, specifiedSceneId: int = - 1, skipAppendedSkills: bool = false) -> PoolStringArray:
	var ret = []
	for skill in get_actor_skills(actorId, specifiedSceneId, skipAppendedSkills):
		ret.append(skill.name)
	return ret






func actor_has_skills(actorId: int, skillNames: PoolStringArray, skipAppendedSkills: bool = false) -> bool:
	for skill in get_actor_skills(actorId, - 1, skipAppendedSkills):
		if skill.name in skillNames:
			return true
	return false





func get_actor_war_skills(actorId: int) -> Array:
	var wf = DataManager.get_current_war_fight()
	if wf == null:
		return []
	var wa = DataManager.get_war_actor(actorId)
	if wa == null or wa.disabled:
		return []
	var actives = []
	var others = []
	for skill in get_actor_skills(actorId):
		var status = get_actor_war_skill_status(wf, wa, skill)
		if status.empty():
			continue
		if skill.type == "主动":
			actives.append(status)
		else:
			others.append(status)
	actives.append_array(others)
	return actives




func get_actor_war_skill_status(wf: WarFight, wa: War_Actor, skill: StaticManager.Skill) -> Dictionary:
	if wf == null or wa == null:
		return {}
	var ret = {
		"名称": skill.name, 
		"主动": skill.type == "主动", 
		"可用": false, 
		"说明": "", 
	}
	if wa.get_buff("罢兵")["回合数"] > 0\
	and ret["主动"]\
	and skill.name != "藏祸":
		ret["可用"] = false
		ret["说明"] = "不可用"
		return ret

	var isWarSkill = false
	if not "大战场" in skill.scene:
		return {}
	for effect in skill.effects:
		if effect.sceneId != 20000:
			continue
		isWarSkill = true
		break
	if not isWarSkill:
		return {}
	var reason = get_actor_skill_disabled_reason(20000, wa.actorId, skill.name)
	if not reason.empty():
		ret["说明"] = reason[0] + "，不可用"
		if ret["主动"]:
			ret["说明"] = reason[0] + "，不可发动"
		return ret
	for effect in skill.effects:
		if effect.sceneId != 20000:
			continue
		var status = effect.get_war_status(wf, wa.actorId)
		if status[1] != "":
			ret["说明"] = status[1]
		if effect.type == "主动":
			
			ret["可用"] = status[0]
			return ret
	
	if not ret["主动"] and ret["说明"] == "":
		ret["说明"] = skill.category
	return ret



func player_choose_skill(
	actorId: int, 
	skillName: String, 
	endBeforeSkill: bool = false, 
	presetFlags: Dictionary = {}
	) -> bool:

	var skill = StaticManager.get_skill(skillName)
	if skill == null:
		return false
	if skill.type != "主动":
		return false
	var sceneId = DataManager.get_current_scene_id()
	var effects = get_skill_effects(actorId, skill, ["主动"])
	var effect = null
	
	for eff in effects:
		if eff.id <= 0:
			continue
		effect = eff
		if effect.sceneId == sceneId:
			break

	if effect == null:
		return false

	
	if sceneId == 30000\
	and skill.has_feature("仙")\
	and skill.has_feature("对敌"):
		var wa = DataManager.get_war_actor(actorId)
		var enemy = null if wa == null else wa.get_battle_enemy_war_actor()
		if enemy != null and enemy.actor().get_equip_feature_max("仙术无效") > 0:
			var msg = "旁门左道，于我皆为虚妄！\n（{0}发动【{1}】失败".format([
				wa.get_name(), skill.name, 
			])
			enemy.attach_free_dialog(msg, 0, 30000)
			SkillHelper.set_skill_cd(30000, effect.id, actorId, 99999, skill.name)
			return false
	var ske = effect.create_ske_for(actorId)
	save_skill_effectinfo(ske)

	DataManager.player_choose_skill = skill.name
	if endBeforeSkill:
		LoadControl.end_script()
	
	mark_actor_once_senario_skill_used(ske)
	if not presetFlags.empty():
		ske.ext_flags = presetFlags.duplicate(true)
	LoadControl.load_script(effect.path)
	FlowManager.add_flow("effect_{0}_start".format([effect.id]))
	return true

func active_skill_available(actorId: int, skillName: String) -> bool:
	var skill = StaticManager.get_skill(skillName)
	if skill == null:
		return false
	if skill.type != "主动":
		return false
	
	var currentSke = read_skill_effectinfo()
	var ret = false
	var sceneId = DataManager.get_current_scene_id()
	for effect in get_skill_effects(actorId, skill, ["主动"]):
		if effect.id <= 0:
			continue
		ret = true
		break
	
	save_skill_effectinfo(currentSke)
	return ret






func auto_trigger_skill(actorId: int, triggerId: int, next_flow: String = "", dialog: String = "") -> bool:
	var currentSke = read_skill_effectinfo()
	
	
	
	
	
	var sceneId = DataManager.get_current_scene_id()
	var lock_effects = []
	var induce_effects = []

	var checked = []
	var toTrigger = []

	
	var disabledTypes = []
	
	if triggerId == 20015:
		var bf = DataManager.get_current_battle_fight()
		if not bf.get_env_array("禁止守方诱发").empty():
			if actorId == bf.get_defender_id():
				disabledTypes.append("己方|诱发")
	
	
	
	if triggerId in [
		20009, 20010, 20011, 20012, 20017, 
		20018, 20025, 20029, 20037, 20038, 
	]:
		var se = DataManager.get_current_stratagem_execution()
		var wa = DataManager.get_war_actor(actorId)
		var actioner = DataManager.get_war_actor(se.get_action_id(se.hiddenActionId))
		if se.induce_disabled & 1:
			if wa.is_teammate(actioner):
				disabledTypes.append("敌方|诱发")
			elif wa.is_enemy(actioner):
				disabledTypes.append("自己|诱发")
				disabledTypes.append("己方|诱发")
		if se.induce_disabled & 2:
			if wa.is_teammate(actioner):
				disabledTypes.append("自己|诱发")
				disabledTypes.append("己方|诱发")
			elif wa.is_enemy(actioner):
				disabledTypes.append("敌方|诱发")
		if se.work_as_skill > 0:
			disabledTypes.append("己方|诱发")
			disabledTypes.append("敌方|诱发")
			disabledTypes.append("己方|锁定")
			disabledTypes.append("敌方|锁定")

	
	for effect in get_actor_self_triggred_skill_effects(actorId, triggerId, disabledTypes):
		var ske = effect.create_ske_for(actorId)
		var dic = _check_and_trigger_skill_effect(ske)
		checked.append(ske)
		if dic == null or dic.empty():
			continue
		toTrigger.append([ske, dic])

	
	for ske in checked:
		disabledTypes.append_array(ske.disabled_skill_buff_types())

	
	for srb in get_actor_ranged_skill_buffs(actorId, triggerId, disabledTypes):
		var ske = new_ske_from_range_buff(actorId, srb)
		var dic = _check_and_trigger_skill_effect(ske)
		checked.append(ske)
		if dic == null or dic.empty():
			continue
		toTrigger.append([ske, dic])

	for item in toTrigger:
		var ske = item[0]
		var dic = item[1]
		if ske.effect_type == "锁定":
			lock_effects.append(dic)
		else:
			induce_effects.append(dic)

	
	save_skill_effectinfo(currentSke)
	
	var has_effect = lock_effects.size() + induce_effects.size() > 0;
	
	if ( not has_effect):
		return false;
	
	if next_flow == "":
		print_debug("auto_trigger_skill错误：未传入next_flow参数，但是check时却需要调用技能flow, ENV: actorId: {0}, triggerId: {1}".format(
			[actorId, triggerId]
		));
		print_stack()
	
	var st_info = SkillTriggerInfo.new();
	st_info.induce_dialog = dialog;
	st_info.actorId = actorId;
	st_info.triggerId = triggerId;
	st_info.lock_effects = lock_effects;
	st_info.induce_effects = induce_effects;
	st_info.next_flow = next_flow;
	if (DataManager.common_variable.has("自定义步骤路径")):
		st_info.temp_code_gd = Array(DataManager.common_variable["自定义步骤路径"]).duplicate();
	
	if (FlowManager.dic_method.has(next_flow)):
		var dic_flow: Dictionary = FlowManager.dic_method[next_flow];
		if (dic_flow.has("gdpath") and dic_flow["gdpath"] != ""):
			st_info.temp_code_gd.append(dic_flow["gdpath"])
	
	add_skill_triggerinfo(st_info)
	
	return true




func get_skill_effects(actorId: int, skill: StaticManager.Skill, specifiedTypes: PoolStringArray = [], triggerId: int = - 1, specifiedSceneId: int = - 1) -> Array:
	var sceneId = specifiedSceneId
	if sceneId < 0:
		sceneId = DataManager.get_current_scene_id()
	if actor_skill_disabled(sceneId, actorId, skill.name):
		
		return []
	var ret = []
	for effect in skill.effects:
		
		if not specifiedTypes.empty() and not effect.type in specifiedTypes:
			continue
		
		if triggerId > 0 and effect.triggerId != triggerId:
			continue
		if effect.sceneId > sceneId:
			
			continue
		if effect.id > 0:
			if get_skill_cd(sceneId, effect.id, actorId, skill.name) > 0:
				
				continue
		if sceneId >= 30000:
			var bf = DataManager.get_current_battle_fight()
			
			if not effect.accept_battle_status(bf, actorId):
				continue
		elif sceneId >= 20000:
			var wf = DataManager.get_current_war_fight()
			
			if not effect.accept_war_status(wf, actorId):
				continue
		elif sceneId == 10000:
			
			if not effect.accept_affair_status(actorId):
				continue
		ret.append(effect)
	return ret



func set_skill_cd(sceneId: int, effectId: int, actorId: int, turn: int, skillName: String) -> void :
	var key = "{0}/{1}/{2}".format([sceneId, effectId, actorId])
	
	while key in DataManager.skill_cd:
		DataManager.skill_cd.erase(key)
	key += "/" + skillName
	if turn <= 0:
		DataManager.skill_cd.erase(key)
	else:
		DataManager.skill_cd[key] = turn
	return


func get_skill_cd(sceneId: int, effectId: int, actorId: int, skillName: String) -> int:
	var checkScenes = [10000, 20000, 30000, 40000]
	for checkScene in checkScenes:
		if checkScene > sceneId:
			continue
		
		var key = "{0}/{1}/{2}".format([checkScene, effectId, actorId])
		if DataManager.skill_cd.has(key):
			var cd = int(DataManager.skill_cd[key])
			if cd > 0:
				return cd
		
		key += "/" + skillName
		if DataManager.skill_cd.has(key):
			var cd = int(DataManager.skill_cd[key])
			if cd > 0:
				return cd
	return 0


func decrease_skill_cd(d_sceneId: int):
	for key in DataManager.skill_cd.keys():
		var sceneId = int(str(key).split("/")[0]);
		if sceneId != d_sceneId:
			continue
		_decrease_or_erase_skill_cd(key)
	return

func decrease_actor_skill_cd(sceneId: int, actorId: int):
	for key in DataManager.skill_cd.keys():
		var pieces = str(key).split("/")
		if sceneId != int(pieces[0]) or actorId != int(pieces[2]):
			continue
		_decrease_or_erase_skill_cd(key)
	return

func _decrease_or_erase_skill_cd(key: String):
	DataManager.skill_cd[key] -= 1
	if DataManager.skill_cd[key] <= 0:
		DataManager.skill_cd.erase(key)
	return


func clear_skill_cd(clear_sceneId: int):
	for key in DataManager.skill_cd.keys():
		var sceneId = int(str(key).split("/")[0]);
		if (clear_sceneId <= sceneId):
			DataManager.skill_cd.erase(key);
	return



func set_skill_flags(sceneId: int, effectId: int, actorId: int, flag_name: String, number: int):
	var skv = Global.dicval(get_skill_variable(sceneId, effectId, actorId)["value"])
	if not skv.has("flags"):
		skv["flags"] = {}
	skv["flags"][flag_name] = number
	set_skill_variable(sceneId, effectId, actorId, skv, 99999)
	return

func get_skill_flags_number(sceneId: int, effectId: int, actorId: int, flag_name: String) -> int:
	var skv = get_skill_variable(sceneId, effectId, actorId)["value"];
	if (skv == null or not skv.has("flags")):
		return 0;
	var flags: Dictionary = skv["flags"];
	if (flags.has(flag_name)):
		return int(flags[flag_name]);
	return 0;


func set_skill_variable(sceneId: int, effectId: int, actorId: int, value, turn: int):
	var key = "{0}/{1}/{2}".format([sceneId, effectId, actorId]);
	DataManager.skill_variable[key] = {"value": value, "turn": turn};
	return


func get_skill_variable(sceneId: int, effectId: int, actorId: int) -> Dictionary:
	var check_scenes: PoolIntArray = PoolIntArray([10000, 20000, 30000, 40000])
	for check_scene_id in check_scenes:
		if (check_scene_id > sceneId):
			continue;
		var key = "{0}/{1}/{2}".format([sceneId, effectId, actorId]);
		if (DataManager.skill_variable.has(key)):
			var dic = DataManager.skill_variable[key];
			if (dic["turn"] > 0):
				return dic;
	return {"turn": 0, "value": null};

func get_skill_variable_int(sceneId: int, effectId: int, actorId: int, defVal: int = - 1) -> int:
	var skv = Global.dicval(get_skill_variable(sceneId, effectId, actorId))
	if not "turn" in skv or Global.intval(skv["turn"]) <= 0:
		return defVal
	if not "value" in skv:
		return defVal
	return Global.intval(skv["value"], defVal)

func get_skill_variable_int_array(sceneId: int, effectId: int, actorId: int) -> Array:
	var skv = Global.dicval(get_skill_variable(sceneId, effectId, actorId))
	if not "turn" in skv or Global.intval(skv["turn"]) <= 0:
		return []
	if not "value" in skv:
		return []
	return Global.intarrval(skv["value"])

func get_skill_variable_array(sceneId: int, effectId: int, actorId: int) -> Array:
	var skv = Global.dicval(get_skill_variable(sceneId, effectId, actorId))
	if not "turn" in skv or Global.intval(skv["turn"]) <= 0:
		return []
	if not "value" in skv:
		return []
	return Global.arrval(skv["value"])

func get_skill_variable_str(sceneId: int, effectId: int, actorId: int) -> String:
	var skv = Global.dicval(get_skill_variable(sceneId, effectId, actorId))
	if not "turn" in skv or Global.intval(skv["turn"]) <= 0:
		return ""
	if not "value" in skv:
		return ""
	return Global.strval(skv["value"])


func decrease_skill_variable(d_sceneId: int):
	for key in DataManager.skill_variable.keys():
		var sceneId = int(str(key).split("/")[0]);
		if sceneId != d_sceneId:
			continue
		_decrease_or_erase_skill_variable(key)
	return


func decrease_actor_skill_variable(sceneId: int, actorId: int):
	for key in DataManager.skill_variable.keys():
		var pieces = str(key).split("/")
		if sceneId != int(pieces[0]) or actorId != int(pieces[2]):
			continue
		_decrease_or_erase_skill_variable(key)
	return

func _decrease_or_erase_skill_variable(key: String):
	var dic = DataManager.skill_variable[key]
	dic["turn"] -= 1
	if dic["turn"] <= 0:
		DataManager.skill_variable.erase(key)
	return


func clear_skill_variable(clear_sceneId: int):
	for key in DataManager.skill_variable.keys():
		var sceneId = int(str(key).split("/")[0]);
		if (clear_sceneId <= sceneId):
			DataManager.skill_variable.erase(key);








func get_actor_active_skills(actorId: int) -> Array:
	var sceneId = DataManager.get_current_scene_id()
	var ret = []
	var skills = get_actor_skills(actorId, sceneId)

	
	for skill in skills:
		if skill.type != "主动":
			continue
		
		
		for effect in get_skill_effects(actorId, skill, ["主动"]):
			if effect.sceneId == sceneId:
				ret.append(skill)
				break
	return ret








func get_range_buff_skill_effects(actorId: int, specifiedSceneId: int = - 1) -> Dictionary:
	var ret = {}
	var skills = get_actor_skills(actorId, specifiedSceneId)

	for skill in skills:
		var buffEffects = []
		for effect in get_skill_effects(actorId, skill, ["光环", "锁定", "诱发"], - 1, specifiedSceneId):
			if effect.type == "光环":
				buffEffects.append(effect)
			elif effect.type in ["锁定", "诱发"]:
				if effect.triggerType in ["城市", "势力", "己方", "敌方", "指定目标"]:
					buffEffects.append(effect)
		if buffEffects.empty():
			continue
		ret[skill] = buffEffects
	return ret






func get_actor_self_triggred_skill_effects(actorId: int, triggerId: int, disabledTypes: PoolStringArray = []) -> Array:
	var sceneId = DataManager.get_current_scene_id()
	var ret = []

	var skills = get_actor_skills(actorId, sceneId)
	DataManager.grouped_trace("SKILLS|" + str(triggerId))

	for skill in skills:
		for effect in get_skill_effects(actorId, skill, ["锁定", "诱发"], triggerId):
			if effect.triggerType != "自己":
				continue
			if not disabledTypes.empty():
				if "{0}|{1}".format([effect.triggerType, effect.type]) in disabledTypes:
					continue
			ret.append(effect)
	return ret






func get_actor_ranged_skill_buffs(actorId: int, triggerId: int, disabledTypes: PoolStringArray) -> Array:
	DataManager.grouped_trace("")
	var ret = []
	var sceneId = DataManager.get_current_scene_id()
	for srb in DataManager.skill_range_buff:
		if srb.triggerId != triggerId:
			continue
		var triggerType = "|" + srb.effectType
		if srb.targetType == SkillRangeBuff.BuffTargetType.CITY:
			var city = DataManager.get_office_city_by_actor(actorId)
			if city == null or srb.targetId != city.ID:
				continue
		elif srb.targetType == SkillRangeBuff.BuffTargetType.VSTATE:
			var city = DataManager.get_office_city_by_actor(actorId)
			if city == null or srb.targetId != city.get_vstate_id():
				continue
		elif srb.targetType == SkillRangeBuff.BuffTargetType.WAR_VSTATE\
		or srb.targetType == SkillRangeBuff.BuffTargetType.WAR_ENEMY_VSTATE:
			if srb.targetType == SkillRangeBuff.BuffTargetType.WAR_ENEMY_VSTATE:
				triggerType = "敌方" + triggerType
			else:
				triggerType = "己方" + triggerType
			if triggerType in disabledTypes:
				continue
			
			var wa = DataManager.get_war_actor(actorId)
			if wa == null:
				continue
			var wv = wa.war_vstate()
			if wv == null:
				continue
			if srb.targetId != wv.id:
				continue
		elif srb.targetType == SkillRangeBuff.BuffTargetType.ACTOR:
			if srb.targetId != actorId:
				continue
		if actor_skill_disabled(sceneId, srb.actorId, srb.skillName):
			
			continue
		if get_skill_cd(sceneId, srb.effectId, srb.actorId, srb.skillName) > 0:
			
			continue
		ret.append(srb)
	DataManager.grouped_trace("BUFFS")
	return ret






func ban_actor_skill(sceneId: int, actorId: int, skill_name: String, turn: int, fromId: int = - 1, fromSource: String = ""):
	var vals = [
		sceneId, actorId, skill_name, 
		turn, fromId, fromSource
	]
	var key = "{0}/{1}/{2}/{3}/{4}/{5}".format(vals);
	DataManager.actor_ban_scene_skill.append(key);
	return

func get_actor_banned_skill_names(sceneId: int, actorId: int) -> PoolStringArray:
	var ret = []
	for key in DataManager.actor_ban_scene_skill:
		var pieces = key.split("/")
		if pieces.size() < 6:
			continue
		if Global.intval(pieces[0]) < sceneId:
			continue
		if Global.intval(pieces[1]) != actorId:
			continue
		ret.append(pieces[2])
	return ret


func recover_banned_actor_skill(actorId: int, skillName: String) -> bool:
	var ret = false
	for key in DataManager.actor_ban_scene_skill.duplicate():
		var pieces = str(key).split("/")
		if Global.intval(pieces[1]) != actorId:
			continue
		if pieces[2] != skillName:
			continue
		DataManager.actor_ban_scene_skill.erase(key)
		ret = true
	return ret


func decrease_ban_actor_skill(sceneId: int, actorIds: PoolIntArray = []):
	for key in DataManager.actor_ban_scene_skill.duplicate():
		var pieces = str(key).split("/")
		if Global.intval(pieces[0]) != sceneId:
			continue
		var actorId = int(pieces[1])
		if actorIds.size() > 0 and not actorId in actorIds:
			continue
		var skill = str(pieces[2])
		var turn = 99999;
		if pieces.size() > 3:
			turn = int(pieces[3])
		
		DataManager.actor_ban_scene_skill.erase(key)
		if turn < 99999:
			turn -= 1;
		if turn <= 0:
			continue
		var vals = [sceneId, actorId, skill, turn, - 1, ""]
		
		if pieces.size() >= 5:
			vals[4] = int(pieces[4])
		if pieces.size() >= 6:
			vals[5] = str(pieces[5])
		var new_key = "{0}/{1}/{2}/{3}/{4}/{5}".format(vals)
		DataManager.actor_ban_scene_skill.append(new_key)
	return


func clear_ban_actor_skill(clearSceneId: int, actorIds: PoolIntArray = [], skillNames: PoolStringArray = [], fromActorIds: PoolIntArray = [], clearSource: String = ""):
	
	for key in DataManager.actor_ban_scene_skill.duplicate():
		var pieces = str(key).split("/")
		var sceneId = int(pieces[0])
		if clearSceneId > sceneId:
			continue
		var actorId = int(pieces[1])
		if actorIds.size() > 0 and not actorId in actorIds:
			continue
		var skillName = str(pieces[2])
		if skillNames.size() > 0 and not skillName in skillNames:
			continue
		if fromActorIds.size() > 0\
		and pieces.size() > 4:
			var fromId = int(pieces[4])
			if not fromId in fromActorIds:
				continue
		if clearSource != ""\
		and pieces.size() > 5\
		and pieces[5] != clearSource:
				continue
		DataManager.actor_ban_scene_skill.erase(key)
	return




func add_actor_scene_skill(
	sceneId: int, actorId: int, skill_name: String, turn: int, 
	fromActorId: int = - 1, fromSource: String = "", 
	oppositeCD: bool = false, once: bool = false) -> bool:
	
	if actorId >= StaticManager.ACTOR_ID_RENOU:
		return false
	var dic = {
		"sceneId": sceneId, 
		"skill_name": skill_name, 
		"turn": turn, 
		"from": fromActorId, 
		"source": fromSource, 
	}
	if oppositeCD:
		dic["cd"] = "敌方"
	if once:
		dic["once"] = 1
	var key = str(actorId)
	if not DataManager.actor_scene_skill.has(key):
		DataManager.actor_scene_skill[key] = []
	var current = DataManager.actor_scene_skill[key].duplicate(true)
	var updated = []
	for saved in current:
		if str(saved["skill_name"]) == skill_name and int(saved["sceneId"]) == sceneId:
			continue
		updated.append(saved)
	updated.append(dic)
	DataManager.actor_scene_skill[key] = updated
	return true


func decrease_actor_scene_skill(sceneId: int, actorIds: PoolIntArray = []):
	for actorIdKey in DataManager.actor_scene_skill.keys():
		if actorIds.size() > 0 and not int(actorIdKey) in actorIds:
			continue
		var current = DataManager.actor_scene_skill[actorIdKey]
		var updated = []
		for dic in current:
			if not "sceneId" in dic:
				continue
			if int(dic["sceneId"]) != sceneId:
				updated.append(dic)
				continue
			if not dic.has("turn"):
				continue
			if int(dic["turn"]) >= 99999:
				updated.append(dic)
				continue
			dic["turn"] = int(dic["turn"]) - 1
			if dic["turn"] <= 0:
				continue
			updated.append(dic)
		if updated.empty():
			DataManager.actor_scene_skill.erase(actorIdKey)
		else:
			DataManager.actor_scene_skill[actorIdKey] = updated
	return


func clear_scene_actor_skill(clearSceneId: int):
	for key in DataManager.actor_scene_skill.keys():
		var actorId = int(key)
		var current = DataManager.actor_scene_skill[key]
		var updated = []
		for dic in current:
			if not dic.has("sceneId") or not dic.has("turn"):
				continue
			if clearSceneId <= int(dic["sceneId"]):
				continue
			updated.append(dic)
		if updated.empty():
			DataManager.actor_scene_skill.erase(key)
		else:
			DataManager.actor_scene_skill[key] = updated
	return




func remove_scene_actor_skill(sceneId: int, actorId: int, skillName: String) -> bool:
	var actorKey = str(actorId)
	if not DataManager.actor_scene_skill.has(actorKey):
		return false
	var skillArray = DataManager.actor_scene_skill[actorKey]
	var newSkillArray = []
	for dic in skillArray:
		if sceneId != int(dic["sceneId"]):
			newSkillArray.append(dic)
			continue
		if skillName != dic["skill_name"]:
			newSkillArray.append(dic)
			continue
	DataManager.actor_scene_skill[actorKey] = newSkillArray
	return newSkillArray.size() != skillArray.size()






func _check_and_trigger_skill_effect(ske: SkillEffectInfo) -> Dictionary:
	var effect = ske.effect()
	if effect == null:
		return {}

	var wa = null
	if effect.sceneId == 20000:
		wa = ske.get_war_actor()
		if wa == null:
			return {}

	
	
	if effect.sceneId == 20000:
		
		
		if wa.get_buff_label_turn(["禁用诱发技"]) > 0:
			return {}
		var buffType = "禁用{0}技".format([effect.type])
		for buff in SkillRangeBuff.find_for_war_vstate(buffType, wa.wvId):
			if buff.effectTagVal != effect.triggerId:
				continue
			if effect.skill.type != effect.type:
				continue
			var msg = "因{0}【{1}】效果\n【{2}】无法发动".format([
				ActorHelper.actor(buff.actorId).get_name(), 
				buff.skillName, effect.skill.name, 
			])
			
			
			var wf = DataManager.get_current_war_fight()
			var key = "消息.{0}.{1}".format([wf.date, msg])
			if wf.get_env_int(key) <= 0:
				wf.set_env(key, 1)
				wa.attach_free_dialog(msg, 3)
			return {}

	
	save_skill_effectinfo(ske)
	var gd = Global.load_script(ske.skill_effect_path())
	gd._init()
	var result = gd.check_trigger_correct()
	DataManager.grouped_trace("CHECK")
	if not result:
		return {}

	return {
		"current_actor": ske.actorId, 
		"effect_id": ske.effect_Id, 
		"triggerId": ske.trigger_Id, 
		"skill_name": ske.skill_name, 
		"skill_actor": ske.skill_actorId, 
	}




func _create_war_actor(actorId: int, wv: War_Vstate) -> War_Actor:
	var wa = wv.get_war_actor(actorId)
	if wa != null:
		return wa
	wa = War_Actor.new(wv.vstate().id, wv.id)
	wa.actorId = actorId
	wa.action_point = 0
	wa.init_AI()
	wa.disabled = false
	wa.position = Vector2( - 1, - 1)
	wa.recharge_action_point(true)
	wa.refresh_poker_random()
	wv.add_war_actor(wa)
	if wv.main_actorId < 0:
		wv.main_actorId = actorId
	return wa

func _add_enemy_wa(name: String, me: War_Actor) -> War_Actor:
	var actorId = - 1
	for actor in ActorHelper.all_actors():
		if actor.get_name() == name:
			actorId = actor.actorId
			break
	if actorId < 0:
		return null
	return _create_war_actor(actorId, me.war_vstate().get_enemy_vstate())

func _add_teammate_wa(name: String, me: War_Actor) -> War_Actor:
	var actorId = - 1
	for actor in ActorHelper.all_actors():
		if actor.get_name() == name:
			actorId = actor.actorId
			break
	if actorId < 0:
		return null
	return _create_war_actor(actorId, me.war_vstate())

func _try_move_wa(wa: War_Actor, pos: Vector2) -> void :
	var scene = SceneManager.current_scene()
	if scene == null:
		return
	var map = scene.get_node_or_null("war_map")
	if map == null:
		return
	if scene.war_map == null:
		return
	wa.move(pos)
	return

func _battle_move_to(actorId: int, x: int, y: int) -> void :
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return
	var bu = wa.battle_actor_unit()
	if bu == null:
		return
	bu.unit_position = Vector2(x, y)
	return


func _battle_set_units_hp(hp: int) -> void :
	for bu in DataManager.battle_units:
		bu.set_hp(hp, true)
	return


func _war_ap(actorId: int, ap: int, stopEnemy: bool = true, stopTeammate: bool = false) -> void :
	var me = DataManager.get_war_actor(actorId)
	if me == null:
		return
	if ap > me.action_point:
		me.action_point = ap
	var wf = DataManager.get_current_war_fight()
	for wa in wf.get_war_actors(false):
		if wa.actorId == actorId:
			continue
		if stopEnemy and me.is_enemy(wa):
			wa.action_point = 0
		if stopTeammate and me.is_teammate(wa):
			wa.action_point = 0
	return

func _ensure_flags(actorId: int, flagName: String, cnt: int = 100) -> void :
	var flags = {
		"药": {"effectId": 10003}, 
		"起": {"effectId": 20150}, 
		"备": {"effectId": 10025}, 
		"士": {"effectId": 10068}, 
	}
	if not flagName in flags:
		return
	var effectId = flags[flagName]["effectId"]
	var sceneId = effectId - effectId % 10000
	SkillHelper.set_skill_flags(sceneId, effectId, actorId, flagName, cnt)
	return

func _war_five_phase(actorId: int, phase: int, point: int = 9) -> void :
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return
	wa.five_phases = phase
	wa.set_poker_point(point)
	return

func _win_this_war(actorId: int) -> bool:
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return false
	var enemy = wa.get_war_enemy_leader()
	if enemy == null:
		return false
	enemy.disabled = true
	return true

func _stop_battle_enemy(actorId: int) -> void :
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		return
	wa.set_buff("咒缚", 100, actorId, "", true)
	return


func update_all_skill_buff(source: String = ""):
	DataManager.game_trace("")
	var sceneId = DataManager.get_current_scene_id()
	clear_instant_range_buff()
	if sceneId == 10000:
		for city in clCity.all_cities():
			var actorIds = city.get_actor_ids()
			if actorIds.empty():
				continue
			for actorId in actorIds:
				update_affair_skill_buff(actorId, city)
	if sceneId >= 20000:
		var wf = DataManager.get_current_war_fight()
		for wv in wf.war_vstates():
			for wa in wv.get_war_actors(false):
				
				update_affair_skill_buff(wa.actorId, wv.from_city())
				update_war_skill_buff(wa)
			update_war_vstate_skill_buff(wv)
	var msg = "{0} => UPDATED_BUFF, current: {1} for {2}".format([
		source, DataManager.skill_range_buff.size(), sceneId, 
	])
	DataManager.game_trace(msg)
	return


func clear_instant_range_buff() -> void :
	var updated = []
	for buff in DataManager.skill_range_buff:
		if buff.continuous > 0:
			updated.append(buff)
	DataManager.skill_range_buff = updated
	return


func update_continuous_buff() -> void :
	var updated = []
	for buff in DataManager.skill_range_buff:
		
		if buff.continuous <= 0:
			updated.append(buff)
			continue
		
		buff.continuous -= 1
		if buff.continuous <= 0:
			continue
		updated.append(buff)
	DataManager.skill_range_buff = updated
	return


func update_affair_skill_buff(actorId: int, city):
	var effectsDic = get_range_buff_skill_effects(actorId)
	for skill in effectsDic:
		for effect in effectsDic[skill]:
			if effect.sceneId != 10000:
				continue
			var b = SkillRangeBuff.new()
			b.from_skill_effect(actorId, effect)
			match b.targetType:
				SkillRangeBuff.BuffTargetType.CITY:
					b.targetId = city.ID
				SkillRangeBuff.BuffTargetType.VSTATE:
					b.targetId = city.get_vstate_id()
				SkillRangeBuff.BuffTargetType.ACTOR:
					b.targetId = actorId
			DataManager.skill_range_buff.append(b)
	return


func update_war_skill_buff(fromWA: War_Actor):
	var wf = DataManager.get_current_war_fight()
	var effectsDic = get_range_buff_skill_effects(fromWA.actorId)
	for skill in effectsDic:
		for effect in effectsDic[skill]:
			if effect.sceneId < 20000:
				continue
			var b = SkillRangeBuff.new()
			b.from_skill_effect(fromWA.actorId, effect)
			if b.targetType == SkillRangeBuff.BuffTargetType.ACTOR:
				match effect.triggerType:
					"自己":
						b.targetId = fromWA.actorId
						DataManager.skill_range_buff.append(b)
					"指定目标":
						b.targetId = effect.get_specified_target_id(fromWA.actorId)
						if b.targetId < 0:
							b.targetId = fromWA.actorId
						DataManager.skill_range_buff.append(b)
					"己方女性武将":
						for wa in fromWA.get_teammates(false):
							if wa.actor().get_gender() != "女":
								continue
							var bb = SkillRangeBuff.new()
							bb.from_skill_effect(fromWA.actorId, effect)
							bb.targetId = wa.actorId
							DataManager.skill_range_buff.append(bb)
			elif b.targetType == SkillRangeBuff.BuffTargetType.WAR_VSTATE:
				var wv = fromWA.war_vstate()
				if wv == null:
					continue
				b.targetId = wv.id
				DataManager.skill_range_buff.append(b)
			elif b.targetType == SkillRangeBuff.BuffTargetType.CITY:
				b.targetId = wf.target_city().ID
				DataManager.skill_range_buff.append(b)
			elif b.targetType == SkillRangeBuff.BuffTargetType.WAR_ENEMY_VSTATE:
				
				for wv in wf.war_vstates():
					if wv.vstate().id != fromWA.vstate().id:
						var bb = SkillRangeBuff.new()
						bb.from_skill_effect(fromWA.actorId, effect)
						bb.targetId = wv.id
						DataManager.skill_range_buff.append(bb)
	return



func update_war_vstate_skill_buff(wv: War_Vstate):
	if wv.is_reinforcement():
		return
	var lordId = wv.vstate().get_lord_id()
	var effectsDic = get_range_buff_skill_effects(lordId, 10000)
	for skillName in effectsDic:
		for effect in effectsDic[skillName]:
			var b = SkillRangeBuff.new()
			b.from_skill_effect(lordId, effect)
			if b.targetType == SkillRangeBuff.BuffTargetType.VSTATE:
				b.targetId = wv.vstateId
				DataManager.skill_range_buff.append(b)
			elif b.targetType == SkillRangeBuff.BuffTargetType.ACTOR:
				b.targetId = lordId
				DataManager.skill_range_buff.append(b)
	return





func mark_actor_once_senario_skill_used(ske: SkillEffectInfo) -> bool:
	var key = str(ske.skill_actorId)
	if not key in DataManager.actor_scene_skill:
		return false
	for row in DataManager.actor_scene_skill[key]:
		if row["skill_name"] != ske.skill_name:
			continue
		var once = Global.dic_val(row, "once", 0)
		if once <= 0:
			continue
		row["used"] = 1
		return true
	return false


func check_and_remove_once_skill() -> void :
	for key in DataManager.actor_scene_skill:
		var updated = []
		for row in DataManager.actor_scene_skill[key]:
			if Global.dic_val(row, "once", 0) > 0\
			and Global.dic_val(row, "used", 0) > 0:
				continue
			updated.append(row)
		DataManager.actor_scene_skill[key] = updated
	return


func skill_testing_inject_before(actor: ActorHelper.ActorInfo, found: PoolStringArray) -> PoolStringArray:
	var ret = []
	ret.append_array(found)
	if not DataManager.is_developer():
		return ret
	
	var TESTING_INJECTION = {
		"张角": ["荐书"], 
		"阎圃": ["质盟", "讨州"], 
		"孙峻": ["时乎"], 
	}
	for name in TESTING_INJECTION:
		if name != actor.get_name():
			continue
		
		
		actor.set_moral(99)
		_ensure_flags(actor.actorId, "士", 400)
		actor.set_gender("女")
		
		
		
		actor.set_level(8)
		
		for extra in TESTING_INJECTION[name]:
			if extra.begins_with("-"):
				extra = extra.substr(1)
				ret.erase(extra)
			else:
				ret.append(extra)
	return ret
