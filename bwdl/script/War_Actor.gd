# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/War_Actor.gd
# 说明：战争武将对象（继承 War_Character）。代表战争地图上的武将单位。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends War_Character

class_name War_Actor



var actorId: int = - 1;


var wait_dialogs = [];


func _init(_vstateId: int, _wvId: int) -> void :
	vstateId = _vstateId
	init_vstateId = _vstateId
	wvId = _wvId
	initWvId = _wvId
	return


func init_AI():
	AI = AI_Enum.None
	
	if get_controlNo() >= 0:
		return
	if is_attacker():
		init_AI_attacker()
	if is_defender():
		init_AI_defender()
	return

func init_AI_defender() -> void :
	var wf = DataManager.get_current_war_fight()
	if is_reinforcement():
		
		if get_main_actor_id() == actorId and get_teammates(false).size() > 0:
			AI = AI_Enum.MainCity
		else:
			AI = AI_Enum.AttackMain
		return
	var wv = war_vstate()
	if wv == null:
		return
	if wv.delegated > 0:
		
		AI = AI_Enum.MainCity
		return
	
	if get_main_actor_id() == actorId:
		AI = AI_Enum.MainCity
		return
	if actor().get_wisdom() >= 70:
		
		AI = AI_Enum.DefenceMain
		return
	
	AI = AI_Enum.AttackNear
	if Global.get_rate_result(50):
		
		AI = AI_Enum.AttackMain
	return

func init_AI_attacker() -> void :
	var wf = DataManager.get_current_war_fight()
	
	if get_main_actor_id() == actorId:
		AI = AI_Enum.MainCity
		return
	
	AI = AI_Enum.AttackNear
	if Global.get_rate_result(50):
		
		AI = AI_Enum.AttackMain
	return






func set_buff(buffName: String, turns: int, fromId: int, fromSkill: String = "", setOnly: bool = false) -> int:
	if buffName == "沉默" and SkillRangeBuff.max_val_for_actor("防止沉默", actorId) > 0:
		return 0
	var buffInfo = StaticManager.get_buff(buffName)
	if buffInfo == null:
		return 0
	if buffInfo.is_negative() and turns > 0:
		if get_buff_label_turn(["神佑"]) > 0:
			return 0
	if "禁止移动" in buffInfo.get_label().split("、") and get_buff_label_turn(["免疫定止"]) > 0:
		return 0
	var buffKey = "BUFF.{0}".format([actorId])
	var buffDecKey = "BUFF.DEC.{0}".format([actorId])
	DataManager.set_env(buffKey, buffName)
	DataManager.set_env(buffDecKey, 0)
	if turns <= 0:
		DataManager.set_env(buffDecKey, 1)
		dic_buffs.erase(buffName)
		if fromId >= 0 and not setOnly:
			SkillHelper.auto_trigger_skill(actorId, 30010)
		return 0
	if not setOnly and buffName in StaticManager.CONTINUOUS_TACTICS:
		var addTurns = actor().get_equip_feature_total("战术附加回合")
		turns += addTurns
	var dic = {
		"回合数": turns, 
		"来源武将": fromId, 
		"经验武将": fromId, 
		"来源技能": fromSkill, 
	}
	var decreased = false
	if dic_buffs.has(buffName):
		var originalTurns = dic_buffs[buffName]["回合数"]
		if originalTurns > turns:
			decreased = true
	dic_buffs[buffName] = dic
	if setOnly:
		return turns
	if decreased:
		DataManager.set_env(buffDecKey, 1)
	match buffInfo.get_scene():
		"大战场":
			SkillHelper.auto_trigger_skill(actorId, 20022, "")
		"小战场":
			SkillHelper.auto_trigger_skill(actorId, 30010)
			
			var enemy = get_battle_enemy_war_actor()
			if enemy != null and not enemy.disabled:
				SkillHelper.auto_trigger_skill(enemy.actorId, 30020, "")
	
	if not buffName in dic_buffs:
		turns = 0
	else:
		turns = int(dic_buffs[buffName]["回合数"])
	DataManager.unset_env(buffKey)
	DataManager.unset_env(buffDecKey)
	return turns

func set_areas(tag: String, buffName: String, fromId: int, turns: int, position: Vector2):
	if turns <= 0:
		dic_areas.erase(tag)
		return
	var dic = {
		"回合数": turns, 
		"BUFF": buffName, 
		"影响坐标": {
			"x": position.x, 
			"y": position.y
		}
	}
	dic_areas[tag] = dic
	return


func check_has_areas_by_labels(label_names: PoolStringArray, use: bool = true) -> Dictionary:
	var wf = DataManager.get_current_war_fight()
	var war_map = SceneManager.current_scene().war_map;
	var num = 0;
	for wa in wf.get_war_actors():
		for key in wa.dic_areas:
			var area = wa.dic_areas[key]
			if area["回合数"] <= 0:
				continue
			if not "影响坐标" in area:
				continue
			var buffName = key
			if "BUFF" in area:
				buffName = area["BUFF"]
			var buffInfo = StaticManager.get_buff(buffName)
			if buffInfo == null or not buffInfo.is_area_effect():
				continue
			
			var centerInfo = area["影响坐标"]
			var center = Vector2(int(centerInfo["x"]), int(centerInfo["y"]))
			var centerTerrian = war_map.get_blockCN_by_position(center)
			var currentTerrian = war_map.get_blockCN_by_position(position)
			if currentTerrian != centerTerrian:
				continue
			var targetType = buffInfo.get_area_target()
			if targetType == "敌方" and not is_enemy(wa):
				continue
			if targetType == "己方" and is_enemy(wa):
				continue
			var label = buffInfo.get_label()
			var has_label = false;
			for label_name in label_names:
				if label_name in label:
					has_label = true
					break
			if not has_label:
				continue
			
			var radius = buffInfo.get_area_radius()
			var distance = max(abs(center.x - position.x), abs(center.y - position.y))
			if distance > radius:
				continue
			if buffInfo.get_area_type() == "十字":
				if center.x != position.x and center.y != position.y:
					continue
			if use:
				wa.dic_areas[key]["回合数"] = 0
			return {"from_actorId": wa.actorId, "pos": center, "source": key}
	return {}

func get_buff(buff_name: String) -> Dictionary:
	if (dic_buffs.has(buff_name)):
		return dic_buffs[buff_name];
	return {"回合数": 0, "来源武将": - 1, "经验武将": - 1};

func get_buffs_with_label(labelNames: PoolStringArray) -> Array:
	var ret = []
	for buffName in dic_buffs:
		var buff = dic_buffs[buffName]
		if buff["回合数"] <= 0:
			continue
		var buffInfo = StaticManager.get_buff(buffName)
		if buffInfo == null:
			continue
		var label = buffInfo.get_label()
		for labelName in labelNames:
			if labelName in label:
				var info = buff.duplicate()
				info["name"] = buffName
				ret.append(info)
	return ret


func get_buff_label_turn(labelNames: PoolStringArray) -> int:
	var ret = 0
	for buff in get_buffs_with_label(labelNames):
		ret = max(buff["回合数"], ret)
	return ret


func retreat_to(cityId: int):
	var wv = war_vstate()
	
	if is_puppet():
		if wv != null:
			wv.remove_war_actor(actorId)
		return
	var city = clCity.city(cityId)
	if city.get_vstate_id() == - 1:
		city.set_vstate_id(vstateId)
	mark_disabled("撤退")
	var keptActorIds = []
	
	
	if wv != null and wv.from_cityId == city.ID and actorId in wv.fromCityActorIds:
		keptActorIds = wv.fromCityActorIds
	clCity.move_to(actorId, city.ID, keptActorIds)
	SkillHelper.update_all_skill_buff("RETREAT")
	return

func banish_to(cityId: int):
	
	if is_puppet():
		war_vstate().remove_war_actor(actorId)
		return
	var actor = actor()
	actor.set_status_exiled(init_vstateId, cityId)
	actor.set_loyalty(30)
	actor.set_hp(max(1, actor.get_hp()))
	init_war_vstate()._lose_sodiers += actor.get_soldiers()
	mark_disabled("流放")
	SkillHelper.update_all_skill_buff("BANISHED")
	return

func dead(source: String = "", fromId: int = - 1) -> String:
	
	if is_puppet():
		disabled = true
		return "灵力消散"
	var actor = actor()
	actor().set_status_dead(init_vstateId)
	init_war_vstate()._lose_sodiers += actor.get_soldiers()
	mark_disabled("阵亡", source, fromId)
	position = Vector2( - 1, - 1)
	SkillHelper.update_all_skill_buff("DEAD")
	return "力竭战败"


func camp_in() -> bool:
	var wv = war_vstate()
	if wv == null:
		return false
	return wv.camp_in(self)




func actor_surrend_to(toWvId: int, specifiedLoyalty: int = - 1) -> bool:
	
	if is_puppet():
		disabled = true
		return false
	if SkillRangeBuff.max_val_for_actor("决忠", actorId) > 0:
		actor().set_loyalty(90)
		var msg = "{0}不背主也！".format([
			actor().get_short_name()
		])
		attach_free_dialog(msg, 0)
		return false
	var wf = DataManager.get_current_war_fight()
	var toWv = wf.get_war_vstate(toWvId)
	if toWv == null:
		return false
	toWv.add_war_actor(self)
	dic_buffs.clear()
	dic_areas.clear()
	
	action_point = 10
	if toWv.id == initWvId:
		init_war_vstate()._lose_sodiers -= get_soldiers()
	else:
		init_war_vstate()._lose_sodiers += get_soldiers()
	var actor = actor()
	actor.set_hp(max(1, actor.get_hp()))
	
	if DataManager.diffculities >= 3:
		var lose = Global.get_random(10, 30)
		var lose_rate: float = 1 - lose / 100.0
		for unit in DataManager.battle_units:
			if unit == null or unit.get_unit_type() == "将":
				continue
			if unit.leaderId == actorId:
				unit.set_hp(unit.get_hp() * lose_rate)
		actor.set_soldiers(int(actor.get_soldiers() * lose_rate))
	if specifiedLoyalty > 0:
		actor.set_loyalty(specifiedLoyalty)
	else:
		actor.set_loyalty(actor.surrend_loyalty(toWv.vstateId))
	init_AI()
	SkillHelper.update_all_skill_buff("SURREND")
	SkillHelper.auto_trigger_skill(actorId, 20051)
	return true


func actor_capture_to(wvId: int, source: String = "", fromId: int = - 1) -> String:
	
	if is_puppet():
		disabled = true
		return "灵力消散"
	var ceilSetting = DataManager.get_game_setting("监狱系统")
	var actor = actor()
	
	match ceilSetting:
		"无":
			return dead(source, fromId)
		"非君主":
			if actor.get_loyalty() == 100:
				return dead(source, fromId)
		"仅君主":
			if actor.get_loyalty() != 100:
				return dead(source, fromId)
	actor.set_status_captured(init_vstateId)
	var wf = DataManager.get_current_war_fight()
	var newWV = wf.get_war_vstate(wvId)
	if newWV == null:
		return ""
	mark_disabled("俘虏", source, fromId)
	if newWV.id == initWvId:
		init_war_vstate()._lose_sodiers -= actor.get_soldiers()
	else:
		init_war_vstate()._lose_sodiers += actor.get_soldiers()
	actor.set_hp(max(1, actor.get_hp()))
	newWV.capture_actors.erase(actorId)
	newWV.capture_actors.append(actorId)
	position = Vector2( - 1, - 1)
	init_AI()
	SkillHelper.update_all_skill_buff("CAPTURED")
	return "被俘虏了"

func get_save_dit():
	var wait_dialogs_json = [];
	for d in wait_dialogs:
		wait_dialogs_json.append(d.output());
	
	var dit = {
		"actorId": actorId, 
		"init_vstateId": init_vstateId, 
		"vstateId": vstateId, 
		"initWvId": initWvId, 
		"wvId": wvId, 
		"dic_buffs": dic_buffs, 
		"dic_areas": dic_areas, 
		"dic_skill_cd": dic_skill_cd, 
		"action_point": action_point, 
		"position": {"x": position.x, "y": position.y}, 
		"battle_morale": battle_morale, 
		"battle_morale_patched": battle_morale_patched, 
		"battle_morale_rnd": battle_morale_rnd, 
		"battle_morale_extra": battle_morale_extra, 
		"battle_lead": battle_lead, 
		"battle_power": battle_power, 
		"battle_courage": battle_courage, 
		"extra_battle_courage": extra_battle_courage, 
		"battle_tactic_point": battle_tactic_point, 
		"disabled": disabled, 
		"dic_other_variable": dic_other_variable, 
		"AI": AI, 
		"five_phases": five_phases, 
		"poker_point": poker_point, 
		"days_battle_actors": days_battle_actors, 
		"days_defended_actors": days_defended_actors, 
		"wait_dialogs": wait_dialogs_json, 
		"is_concealed": is_concealed, 
	}
	return dit

func set_save_dit(dit: Dictionary):
	actorId = int(dit["actorId"]);
	init_vstateId = int(dit["init_vstateId"]);
	vstateId = int(dit["vstateId"]);
	
	initWvId = init_vstateId
	wvId = vstateId
	if "initWvId" in dit:
		initWvId = Global.intval(dit["initWvId"])
	if "wvId" in dit:
		wvId = Global.intval(dit["wvId"])
	dic_buffs = Dictionary(dit["dic_buffs"]);
	dic_areas = Dictionary(dit["dic_areas"]);
	dic_skill_cd = dit["dic_skill_cd"];
	action_point = int(dit["action_point"]);
	disabled = dit["disabled"];
	var x = int(dit["position"]["x"]);
	var y = int(dit["position"]["y"]);
	position = Vector2(x, y);
	battle_morale = int(dit["battle_morale"]);
	
	battle_morale_patched = 0
	if dit.has("battle_morale_patched"):
		battle_morale_patched = int(dit["battle_morale_patched"])
	battle_morale_rnd = 0
	if dit.has("battle_morale_rnd"):
		battle_morale_rnd = Global.intval(dit["battle_morale_rnd"])
	battle_morale_extra = 0
	if dit.has("battle_morale_extra"):
		battle_morale_extra = Global.intval(dit["battle_morale_extra"])

	battle_lead = int(dit["battle_lead"]);
	
	battle_power = - 1
	if dit.has("battle_power"):
		battle_power = int(dit["battle_power"])
	battle_courage = int(dit["battle_courage"]);
	extra_battle_courage = 0
	if "extra_battle_courage" in dit:
		extra_battle_courage = Global.intval(dit["extra_battle_courage"])
	battle_tactic_point = int(dit["battle_tactic_point"]);
	dic_other_variable = Dictionary(dit["dic_other_variable"]);

	AI = Global.intval(Global.dic_val(dit, "AI", 0))
	five_phases = Global.intval(Global.dic_val(dit, "five_phases", 0))
	poker_point = Global.intval(Global.dic_val(dit, "poker_point", 0))

	days_battle_actors = {}
	if dit.has("days_battle_actors"):
		days_battle_actors = dit["days_battle_actors"]
	days_defended_actors = {}
	if dit.has("days_defended_actors"):
		days_defended_actors = dit["days_defended_actors"]
	if dit.has("wait_dialogs"):
		wait_dialogs = [];
		var wait_dialogs_jarray = dit["wait_dialogs"];
		for wd_json in wait_dialogs_jarray:
			var d = DialogInfo.new();
			d.input(wd_json);
			wait_dialogs.append(d);
	if dit.has("is_concealed"):
		is_concealed = dit["is_concealed"];
	return


func recharge_action_point(updateNow: bool = true) -> int:
	var exceededKey = "战争.机动力溢出.{0}".format([actorId])
	DataManager.set_env(exceededKey, 0)
	var actor = actor()
	var limit = get_max_action_ap()
	var steed = actor.get_steed()
	var recover = steed.get_attr_int("机动力恢复")
	if action_point == 0 and recover < limit and SkillRangeBuff.max_val_for_actor("朔望", actorId) > 0:
		recover = limit
	if updateNow:
		
		recover += get_ext_variable("次日机动力恢复", 0)
		set_ext_variable("次日机动力恢复", 0)
		
		
		var exceeded = action_point + recover - limit
		if exceeded > 0:
			DataManager.set_env(exceededKey, exceeded)
		action_point = min(limit, action_point + recover)
		
		if "乐" in actor().get_natures():
			var source = null
			var natureAP = 0
			for item in actor().get_equip_feature_all("音律赋予机动力"):
				if item[1] > natureAP:
					natureAP = item[1]
					source = item[0]
			for teammate in get_teammates(false, true):
				for item in teammate.actor().get_equip_feature_all("音律赋予机动力"):
					if item[1] > natureAP:
						natureAP = item[1]
						source = item[0]
			if natureAP > 0:
				var ske = SkillHelper.new_ske_from_equip_simulation(actorId, source)
				
				ske.trigger_Id = 20013
				ske.change_actor_ap(actorId, natureAP)
				ske.war_report()
	return recover


func refresh_poker_random(dayStart: bool = false):
	var pointMin = 0
	var pointMax = 9
	var phases = [
		FivePhases_Enum.Fire, 
		FivePhases_Enum.Wood, 
		FivePhases_Enum.Metal, 
		FivePhases_Enum.Water, 
	]
	if dayStart:
		if SkillRangeBuff.max_val_for_actor("汉恩", actorId) > 0:
			var wv = war_vstate()
			if wv != null:
				for wa in wv.get_war_actors(false):
					if wa.actorId in [StaticManager.ACTOR_ID_LIUBIAN, StaticManager.ACTOR_ID_LIUXIE]:
						pointMin = 9
						pointMax = 9
						break
		if SkillRangeBuff.max_val_for_actor("仙兵种", actorId) > 0:
			pointMin = max(3, pointMin)
			pointMax = 9
			phases = [FivePhases_Enum.Earth]
	var point = Global.get_random(pointMin, pointMax)
	set_poker_point(point)
	if actor().get_equip_feature_max("地遁"):
		phases = [FivePhases_Enum.Earth]
	if phases.size() > 1:
		var specified = actor().get_equip_feature_max("五行")
		if specified > 0:
			phases = [specified]
		elif not SkillRangeBuff.find_for_war_vstate("五行含土", wvId).empty():
			phases.append(FivePhases_Enum.Earth)
	phases.shuffle()
	five_phases = phases[0]
	return poker_point


func get_max_action_ap() -> int:
	var actor = actor()
	
	var base = max(actor.get_power(), actor.get_wisdom())
	base += min(1000, actor.get_soldiers()) / 5
	
	var limit = int((base + actor.get_steed_power()) / 16)
	
	limit = int(max(13, min(25, limit)))
	
	var setting = Global.dicval(get_ext_variable("机动力上限"))
	for key in setting:
		var val = Global.intval(setting[key])
		limit = int(max(limit, val))
	var extra = Global.dicval(get_ext_variable("附加机动力上限"))
	for key in extra:
		var val = Global.intval(extra[key])
		limit += val
	return limit







func try_move(target: Vector2, ignoreWall: bool = false, ignoreTeammates: bool = false) -> bool:
	var map = SceneManager.current_scene().war_map
	target.x = max(0, target.x)
	target.x = min(map.cell_columns - 1, target.x)
	target.y = max(0, target.y)
	target.y = min(map.cell_rows - 2, target.y)

	if target == position:
		return false

	if not map.is_valid_position(target):
		return false

	
	if not can_move_to_position(target, ignoreTeammates):
		return false
	
	if get_troops_type() == "仙":
		ignoreWall = true
	elif is_defender():
		if SkillRangeBuff.max_val_for_actor("逾墙", actorId) > 0:
			ignoreWall = true
	
	if not ignoreWall:
		var currentBlock = map.get_blockCN_by_position(position)
		var targetBlock = map.get_blockCN_by_position(target)
		if targetBlock == "城墙" and not currentBlock in ["城墙", "城门"]:
			return false
	return true




func after_move(forward: bool = true) -> bool:
	var rechargeNextDay = actor().get_equip_feature_max("移动机动力恢复")
	if rechargeNextDay > 0:
		var cost = DataManager.get_env_dict("移动消耗")
		if "机" in cost and Global.intval(cost["机"]) > 0:
			var current = get_ext_variable("次日机动力恢复", 0)
			if not forward:
				
				rechargeNextDay = - rechargeNextDay
			current += rechargeNextDay
			set_ext_variable("次日机动力恢复", current)

	var map = SceneManager.current_scene().war_map
	
	var nextFlow = "actor_move_stop"
	if get_controlNo() < 0:
		nextFlow = "AI_before_ready"
	if map.check_trap_trigger(self, nextFlow):
		return true

	
	var damages = map.check_trap_damage(self)
	if damages[1] > 0:
		var info = "{0}在此设下陷阱\n兵力下降{1}".format([
			damages[2].get_name(), damages[1]
		])
		LoadControl._error(info, actorId, 3)
		return true
	elif damages[0] > 0:
		var info = "{0}在此设下陷阱\n【破伏】免伤".format([
			damages[2].get_name()
		])
		LoadControl._error(info, actorId, 1)
		return true

	
	var eventFlow = map.check_special_events(self)
	if eventFlow != "":
		FlowManager.add_flow(eventFlow)
		return true
	return false







func move(target: Vector2, updateCamera: bool = true, ignoreWall: bool = false, ignoreTeammates: bool = false) -> bool:
	if not try_move(target, ignoreWall, ignoreTeammates):
		return false

	var map = SceneManager.current_scene().war_map
	if map == null:
		
		position = target
		return true

	position = target

	if updateCamera and map.require_camer_move(self):
		map.set_cursor_location(position, true)

	return true


func may_move_failed(from: Vector2, to: Vector2) -> bool:
	var map = SceneManager.current_scene().war_map
	var troopsType = actor().get_troops_type()
	if troopsType != "仙":
		return false
	var terrianFrom = map.get_blockCN_by_position(from)
	if terrianFrom in StaticManager.CITY_BLOCKS_CN:
		return false
	var terrianTo = map.get_blockCN_by_position(to)
	if terrianTo != "城墙":
		return false
	var rate = actor().get_moral()
	return not Global.get_rate_result(rate)


func get_controlNo():
	var vstate_controlNo = war_vstate().get_main_controlNo();
	if vstate_controlNo >= 0:
		return vstate_controlNo
	return - 1




func battle_init(simulation = false):
	var bf = DataManager.get_current_battle_fight()
	var actor = actor()
	var enemy = get_battle_enemy_war_actor()
	
	battle_courage = actor.get_courage()
	extra_battle_courage = 0
	battle_lead = actor.get_leadership()
	battle_power = actor.get_power()
	
	for found in actor.get_equip_feature_all("白兵动态胆"):
		if found[1] > battle_courage:
			battle_courage = found[1]
			bf.battle_log.append("- <y{0}><g{1}>效果，胆提升为 <y{2}>".format([
				actor.get_name(), found[0].name(), battle_courage, 
			]))
	
	
	var sbp = SKill_For_Battle.Skill_Battle_Property.new()
	if not simulation:
		
		
		
		
		DataManager.set_env("技能白兵附加", sbp.output())
		SkillHelper.auto_trigger_skill(actorId, 30006, "")
		sbp.input(DataManager.get_env_dict("技能白兵附加"))

	
	if actor.get_soldiers() == 0:
		var courageLoss = true
		for found in actor.get_equip_feature_all("刚胆"):
			if found[1] > 0:
				courageLoss = false
				bf.battle_log.append("- <y{0}><g{1}>效果，单将出击不降胆".format([
					actor.get_name(), found[0].name(), 
				]))
				break
		if courageLoss:
			var srb = SkillRangeBuff.max_for_actor("刚胆", actor.actorId)
			if srb != null and srb.effectTagVal > 0:
				courageLoss = false
				bf.battle_log.append("- <y{0}>【<g{1}>】效果，单将出击不降胆".format([
					actor.get_name(), srb.skillName, 
				]))
		if courageLoss:
			battle_courage = int(battle_courage * 0.8)
			bf.battle_log.append("- <y{0}>单将出击，胆降低 20%-><r{1}>".format([
				actor.get_name(), battle_courage, 
			]))
	
	elif enemy != null:
		if enemy.actor().get_soldiers() == 0:
			battle_lead = int(battle_lead * 1.2)
			bf.battle_log.append("- <y{0}>单将出击，<y{1}>统提高 20%-><r{2}>".format([
				enemy.get_name(), actor.get_name(), battle_lead, 
			]))

	
	battle_lead += sbp.leader
	for found in actor.get_equip_feature_all("白兵附加统"):
		if found[1] > 0:
			battle_lead += found[1]
			bf.battle_log.append("- <y{0}><g{1}>效果，统 +<y{2}> -> <y{3}>".format([
				actor.get_name(), found[0].name(), found[1], battle_lead, 
			]))
	if enemy != null:
		
		for found in enemy.actor().get_equip_feature_all("白兵降统"):
			if found[1] > 0:
				battle_lead -= found[1]
				bf.battle_log.append("- <y{0}><g{1}>效果，<y{2}>统 -<r{3}> -> <y{4}>".format([
					enemy.get_name(), found[0].name(), actor.get_name(), found[1], battle_lead, 
				]))
	battle_lead = max(0, battle_lead)
	
	
	battle_power = max(0, battle_power + sbp.power)

	battle_courage += sbp.courage
	if enemy != null:
		
		for found in enemy.actor().get_equip_feature_all("白兵降胆"):
			if found[1] > 0:
				battle_courage -= found[1]
				bf.battle_log.append("- <y{0}><g{1}>效果，<y{2}>胆 -<r{3}> -> <y{4}>".format([
					enemy.get_name(), found[0].name(), actor.get_name(), found[1], battle_courage, 
				]))
	battle_courage = max(0, battle_courage)
	update_buff_attrs()

	
	var wisdom = actor.get_wisdom()
	if sbp.alternative_wisdom_for_tp > 0:
		wisdom = sbp.alternative_wisdom_for_tp
	battle_tactic_point = int(wisdom * 13 / 100)
	for found in actor.get_equip_feature_all("白兵附加战术"):
		if found[1] > 0:
			battle_tactic_point += found[1]
			bf.battle_log.append("- <y{0}><g{1}>效果，战术值 +<y{2}> -> <y{3}>".format([
				actor.get_name(), found[0].name(), found[1], battle_tactic_point, 
			]))
	battle_tactic_point = max(0, battle_tactic_point)
	battle_tactic_point = max(0, battle_tactic_point + sbp.tp)
	if get_buff_label_turn(["疲兵"]) > 0:
		battle_tactic_point = int(battle_tactic_point / 2)
	if enemy != null:
		for found in enemy.actor().get_equip_feature_all("白兵减敌战术"):
			if found[1] > 0:
				battle_tactic_point = max(0, battle_tactic_point - found[1])
				bf.battle_log.append("- <y{0}><g{1}>效果，<y{2}>战术值 -<y{3}> -> <y{4}>".format([
					enemy.get_name(), found[0].name(), actor.get_name(), found[1], battle_tactic_point, 
				]))

	
	battle_morale_rnd = actor.get_leadership() / 7 - Global.get_random(0, 9)
	var battle_morale_min = calculate_battle_morale(actor.get_power(), actor.get_leadership())
	
	
	
	battle_morale_rnd = max( - battle_morale_min, battle_morale_rnd)

	
	battle_morale_patched = 0
	battle_morale = calculate_battle_morale(actor.get_power(), actor.get_leadership())

	battle_morale_extra = 0
	var ENCOURAGE_MORALE_UP = 5
	for buff in get_buffs_with_label(["激励"]):
		if buff["回合数"] <= 0:
			continue
		var source = Global.dic_val(buff, "来源技能", "激励")
		var fromId = Global.dic_val(buff, "来源武将", - 1)
		battle_morale_extra += ENCOURAGE_MORALE_UP
		bf.battle_log.append("- <y{0}><g{1}>效果，士气提升 <y{2}>".format([
			ActorHelper.actor(fromId).get_name() if fromId >= 0 else "", 
			source, ENCOURAGE_MORALE_UP, 
		]))
		break

	
	recalculate_morale()
	return

func get_battle_enemy_war_actor():
	var bf = DataManager.get_current_battle_fight()
	if bf.get_attacker_id() == actorId:
		return bf.get_defender()
	if bf.get_defender_id() == actorId:
		return bf.get_attacker()
	return null


func can_use_tactic() -> bool:
	DataManager.set_env("战斗.战术禁用原因", "")
	if get_buff_label_turn(["战术禁用"]) > 0:
		for buff in dic_buffs:
			var buffInfo = StaticManager.get_buff(buff)
			if "战术禁用" in buffInfo.get_label():
				var source = "正处于战术禁用状态"
				var fromId = int(dic_buffs[buff]["来源武将"])
				if fromId >= 0 and fromId != actorId:
					var fromSkill = str(dic_buffs[buff]["来源技能"])
					if fromSkill != "":
						source = "因{0}【{1}】\n战术被禁用".format([
							ActorHelper.actor(fromId).get_name(), fromSkill
						])
					else:
						source = "已被{0}禁用战术".format([
							ActorHelper.actor(fromId).get_name()
						])
				DataManager.set_env("战斗.战术禁用原因", source)
				return false
	return true


func continuous_tactic_on(basicOnly: bool = false) -> bool:
	var tactics = StaticManager.CONTINUOUS_TACTICS
	if basicOnly:
		tactics = StaticManager.BASIC_TACTICS
	for tactic in tactics:
		if get_buff(tactic)["回合数"] > 0:
			return true
	return false


func get_solo_dex():
	var actor = actor()
	var dex = (actor.get_hp() + actor.get_power()) / 10
	dex += 20
	dex -= actor.equip_total_weight()
	dex += Global.get_random(0, 11)
	return dex


func get_solo_base_damege() -> int:
	var a = actor()
	var b = get_battle_enemy_war_actor().actor()
	var attack = a.get_equip_attr_total("攻击力")
	var defence = b.get_equip_attr_total("防御力")
	var damage = int((a.get_power() * 0.7 + attack) / 2)
	damage -= defence
	damage += Global.get_random( - 5, 5)
	damage = max(0, damage)
	
	
	if get_buff("恫吓")["回合数"] > 0:
		damage += Global.get_random(2, 7)
	
	DataManager.set_env("单挑.是否暴击", 0)
	
	var criticalChance = a.get_equip_feature_total("单挑暴击率")
	DataManager.set_env("单挑.暴击率", criticalChance)
	
	SkillHelper.auto_trigger_skill(a.actorId, 40005)
	SkillHelper.auto_trigger_skill(b.actorId, 40007)
	
	criticalChance = DataManager.get_env_int("单挑.暴击率")
	if Global.get_rate_result(criticalChance):
		damage *= 2
		DataManager.set_env("单挑.是否暴击", 1)
	return damage


func get_solo_accuracy_rate() -> int:
	var rate = 50
	var a = actor()
	var b = ActorHelper.actor(get_battle_enemy_war_actor().actorId)
	var wa = a.get_weapon()
	var wb = b.get_weapon()
	if wa.disabled:
		rate = 50
	elif wb.disabled:
		rate = 70
	var setting = StaticManager.get_solo_rate_setting()
	for set in setting:
		if str(set["a"]) != wa.subtype():
			continue
		if str(set["b"]) != wb.subtype():
			continue
		rate = int(set["rate"])
	
	rate += a.get_equip_feature_total("单挑命中率加成")
	
	var angry_turn = get_buff("恫吓")["回合数"]
	if angry_turn > 0:
		rate -= Global.get_random(2, 7)
	return rate


func clear_buff_by_where(where: String):
	for buff in get_buff_names(where):
		dic_buffs.erase(buff)
	return


func decrease_buff_by_where(where: String):
	for buff in get_buff_names(where):
		if not buff in dic_buffs:
			continue
		var turns = dic_buffs[buff]["回合数"]
		if turns == 999:
			continue
		if turns <= 0:
			continue
		dic_buffs[buff]["回合数"] = turns - 1
	return


func battle_actor_unit() -> Battle_Unit:
	for bu in DataManager.battle_units:
		if bu == null or bu.leaderId != actorId:
			continue
		if bu.get_unit_type() == "将":
			return bu
	return null


func is_AI_use() -> bool:
	return get_controlNo() < 0;

func get_battle_power() -> int:
	if battle_power >= 0:
		return int(battle_power)
	return actor().get_power()




func apply_battle_morale_change(val: int):
	if dic_other_variable.has("固定士气"):
		battle_morale = int(dic_other_variable["固定士气"])
		battle_morale_patched = 0
		return
	var original_morale = battle_morale
	battle_morale = max(0, battle_morale + val)
	battle_morale_patched += battle_morale - original_morale
	return

func recalculate_morale() -> void :
	var changed = calculate_battle_morale(get_battle_power(), battle_lead) + battle_morale_extra
	if get_buff_label_turn(["疲兵"]) > 0:
		changed = int(changed / 2)

	apply_battle_morale_change(changed - battle_morale)
	return






func calculate_battle_morale(power: int, lead: int) -> int:
	var X = 45
	var thresholds = [115, 105, 97, 92, 87, 80, 65]
	var morales = [80, 75, 70, 65, 60, 55, 50]
	for i in thresholds.size():
		if lead >= thresholds[i]:
			X = morales[i]
			break
	
	var morale = power * X / 100 + battle_morale_rnd
	return morale





func consume_tactic_point(cost_tp: int) -> bool:
	if self.battle_tactic_point < cost_tp:
		return false

	self.battle_tactic_point -= cost_tp
	DataManager.common_variable["白兵.战术消耗"] = cost_tp
	return true


func get_troops_type() -> String:
	if self.dic_other_variable.has("临时军种"):
		return str(self.dic_other_variable["临时军种"])
	return actor().get_troops_type()


func get_main_actor_id() -> int:
	if war_vstate() == null:
		return - 1
	return war_vstate().main_actorId


func get_leader():
	if war_vstate() == null:
		return null
	return war_vstate().get_leader()

func get_poker_point_str() -> String:
	var point: String = str(poker_point);
	return point;

func get_five_phases_color_code() -> String:
	return War_Character.get_five_phases_color(five_phases)

func get_five_phases_str() -> String:
	return War_Character.get_five_phases_string(five_phases)

func add_day_attacked_actor(b_actorId: int) -> void :
	var wf = DataManager.get_current_war_fight()
	var key = str(wf.date)
	if not days_battle_actors.has(key):
		days_battle_actors[key] = []
	days_battle_actors[key].append(b_actorId)
	if not days_battle_actors.has("-1"):
		days_battle_actors["-1"] = []
	days_battle_actors["-1"].append(b_actorId)
	return

func get_day_attacked_actors(date: int) -> PoolIntArray:
	var key = str(date)
	if not days_battle_actors.has(key):
		return PoolIntArray([])
	return PoolIntArray(days_battle_actors[key])

func add_day_defended_actor(b_actorId: int) -> void :
	var wf = DataManager.get_current_war_fight()
	var key = str(wf.date)
	if not days_defended_actors.has(key):
		days_defended_actors[key] = []
	days_defended_actors[key].append(b_actorId)
	if not days_defended_actors.has("-1"):
		days_defended_actors["-1"] = []
	days_defended_actors["-1"].append(b_actorId)
	return

func get_day_defended_actors(date: int) -> PoolIntArray:
	var key = str(date)
	if ( not days_defended_actors.has(key)):
		return PoolIntArray([]);
	return PoolIntArray(days_defended_actors[key]);

func get_war_attacked_actors() -> PoolIntArray:
	if not days_battle_actors.has("-1"):
		return PoolIntArray([])
	return PoolIntArray(days_battle_actors["-1"])

func get_war_defended_actors() -> PoolIntArray:
	if not days_defended_actors.has("-1"):
		return PoolIntArray([])
	return PoolIntArray(days_defended_actors["-1"])


func add_dialog_info(d: DialogInfo):
	wait_dialogs.append(d);

func mark_disabled(reason: String = "", source: String = "", fromId: int = - 1):
	set_env("战争.DISABLE.TYPE", reason)
	set_env("战争.DISABLE.SOURCE", source)
	set_env("战争.DISABLE.FROM", fromId)
	
	SkillHelper.auto_trigger_skill(actorId, 20027)
	unset_env("战争.DISABLE.TYPE")
	unset_env("战争.DISABLE.SOURCE")
	unset_env("战争.DISABLE.FROM")
	disabled = true
	return


func can_move() -> bool:
	if dic_other_variable.has("禁止移动"):
		return false
	if get_buff_label_turn(["禁止移动"]) > 0:
		if get_tmp_variable("无视定止", 0) <= 0:
			return false
	return true


func can_move_to_position(targetPos: Vector2, ignoreTeammates: bool = false) -> bool:
	var map = SceneManager.current_scene().war_map
	if not map.is_valid_position(targetPos):
		return false
	var existed = DataManager.get_war_actor_by_position(targetPos, [actorId])
	if existed != null and not existed.disabled and existed.actorId != actorId:
		
		return ignoreTeammates and is_teammate(existed)
	return true



func get_retreat_lost_rate() -> int:
	var ret = 10
	var srb = SkillRangeBuff.min_for_actor("撤退损兵倍率", actorId)
	if srb != null and srb.effectTagVal >= 0:
		var msg = "因【{0}】撤退".format([srb.skillName])
		if srb.effectTagVal > 0:
			msg += "损兵 {0}%".format([srb.effectTagVal])
		else:
			msg += "不损兵"
		var bf = DataManager.get_current_battle_fight()
		bf.set_env("撤退损兵说明.{0}".format([actorId]), msg)
		ret = srb.effectTagVal
	if ret > 0:
		srb = SkillRangeBuff.max_for_war_vstate("范围撤退不损兵", wvId)
		if srb != null and srb.effectTagVal > 0:
			var teammate = DataManager.get_war_actor(srb.actorId)
			if teammate != null and not teammate.disabled\
			and Global.get_range_distance(teammate.position, position) <= srb.effectTagVal:
				var msg = "因{0}【{1}】撤退不损兵"
				if srb.actorId == actorId:
					msg = "因【{1}】撤退不损兵"
				msg = msg.format([ActorHelper.actor(srb.actorId).get_name(), srb.skillName])
				var bf = DataManager.get_current_battle_fight()
				bf.set_env("撤退损兵说明.{0}".format([actorId]), msg)
				ret = 0
	return ret


func get_lord_id() -> int:
	return clVState.vstate(vstateId).get_lord_id()


func get_lord_name() -> String:
	return clVState.vstate(vstateId).get_dynasty_title_or_lord_name()






func get_stratagems(replacedInt: int = - 1, replacedLevel: int = - 1, ignoreCD: bool = false) -> Array:
	var ret = []
	
	for stratagem in StaticManager.stratagems:
		if ret.size() >= 16:
			break
		if not ignoreCD and dic_skill_cd.has(stratagem.name) and dic_skill_cd[stratagem.name] > 0:
			continue
		if not is_defender() and stratagem.name == "空城计":
			continue
		if not stratagem.match_skill_mode():
			continue
		if not stratagem.actor_learned(actorId, replacedInt, replacedLevel):
			continue
		ret.append(stratagem)
	return ret


func is_war_debuffed() -> bool:
	return get_war_debuffs().size() > 0

func get_war_debuffs() -> PoolStringArray:
	return get_buff_names("大战场", - 1)

func get_battle_buffs() -> PoolStringArray:
	return get_buff_names("小战场", 1)


func get_buff_names(scene: String = "", type: int = 0) -> PoolStringArray:
	var ret = []
	for buff in dic_buffs:
		var buffStatus = get_buff(buff)
		if buffStatus["回合数"] <= 0:
			continue
		var buffInfo = StaticManager.get_buff(buff)
		if buffInfo == null:
			continue
		if scene != "" and buffInfo.get_scene() != scene:
			continue
		if type > 0 and buffInfo.is_negative():
			continue
		if type < 0 and not buffInfo.is_negative():
			continue
		ret.append(buff)
	return ret


func get_war_enemy_leader():
	var enemyLeaderId = war_vstate().get_enemy_vstate().main_actorId
	if enemyLeaderId < 0:
		return null
	return DataManager.get_war_actor(enemyLeaderId)

func actor() -> ActorHelper.ActorInfo:
	return ActorHelper.actor(actorId)

func get_name() -> String:
	return actor().get_name()

func get_soldiers() -> int:
	return actor().get_soldiers()



func get_next_dialog(sceneId: int = 20000) -> War_Character.DialogInfo:
	if wait_dialogs.empty():
		return null
	for i in wait_dialogs.size():
		var d = wait_dialogs[i]
		if d.sceneId >= sceneId + 10000:
			
			wait_dialogs.remove(i)
			i = i - 1
			continue
		elif d.sceneId < sceneId:
			
			continue
		
		wait_dialogs.remove(i)
		return d
	return null

func clear_tmp_variables():
	for k in dic_other_variable.keys():
		if k.begins_with("TMP."):
			dic_other_variable.erase(k)
	return

func get_tmp_variable(key: String, defVal = null):
	key = "TMP." + key
	return get_ext_variable(key, defVal)

func set_tmp_variable(key: String, val) -> void :
	key = "TMP." + key
	set_ext_variable(key, val)
	return

func get_ext_variable(key: String, defVal = null):
	if not key in dic_other_variable:
		return defVal
	return dic_other_variable[key]

func set_ext_variable(key: String, val) -> void :
	if val == null:
		dic_other_variable.erase(key)
	else:
		dic_other_variable[key] = val
	return

func attach_free_dialog(msg: String, mood: int = 2, sceneId: int = 20000, reporter: int = - 1, showAvatarAnyway: bool = false) -> War_Character.DialogInfo:
	if reporter == - 1 and not showAvatarAnyway:
		reporter = actorId
	var d = War_Character.DialogInfo.new()
	d.actorId = reporter
	d.text = msg
	d.mood = mood
	d.sceneId = sceneId
	add_dialog_info(d)
	return d

func vstate():
	return clVState.vstate(vstateId)

func changed_vstate() -> bool:
	return vstateId != init_vstateId

func war_vstate():
	var wf = DataManager.get_current_war_fight()
	return wf.get_war_vstate(wvId)

func init_war_vstate():
	var wf = DataManager.get_current_war_fight()
	return wf.get_war_vstate(initWvId)


func five_phases_against(target: War_Actor) -> bool:
	if target == null:
		return false
	match five_phases:
		
		FivePhases_Enum.Wood:
			return target.five_phases == FivePhases_Enum.Earth
		FivePhases_Enum.Earth:
			return target.five_phases == FivePhases_Enum.Water
		FivePhases_Enum.Water:
			return target.five_phases == FivePhases_Enum.Fire
		FivePhases_Enum.Fire:
			return target.five_phases == FivePhases_Enum.Metal
		FivePhases_Enum.Metal:
			return target.five_phases == FivePhases_Enum.Wood
	return false

func get_AI_desc() -> String:
	return War_Character.get_AI_string(AI)

func get_AI_decided_route() -> Array:
	return Global.arrval(get_tmp_variable("AI.计划路线"))

func set_AI_decided_route(route: PoolVector2Array) -> Array:
	var routeInfo = []
	for pos in route:
		routeInfo.append({"x": pos.x, "y": pos.y})
	set_tmp_variable("AI.计划路线", routeInfo)
	return get_AI_decided_route()

func pop_AI_decided_route() -> Vector2:
	var routeInfo = get_AI_decided_route()
	if routeInfo.empty():
		return Vector2( - 1, - 1)
	var node = routeInfo.pop_front()
	set_tmp_variable("AI.计划路线", routeInfo)
	return Vector2(int(node["x"]), int(node["y"]))


func set_poker_point(point: int) -> void :
	var fixed = int(get_tmp_variable("固定点数", - 1))
	if fixed >= 0:
		return
	poker_point = point
	return


func get_poker_point_diff(target: War_Actor) -> int:
	if target == null:
		return 0
	var diff = poker_point * max(1, actor().get_equip_feature_max("点数判定倍率"))
	diff -= target.poker_point * max(1, target.actor().get_equip_feature_max("点数判定倍率"))
	return diff


func get_power() -> int:
	return actor().get_power()


func get_power_score() -> int:
	return actor().get_power_score()


func get_teammates(includeDisabled: bool = true, checkPosition: bool = false) -> Array:
	var wv = war_vstate()
	if wv == null:
		return []
	var ret = []
	for wa in wv.get_war_actors(includeDisabled, checkPosition):
		if wa.actorId == actorId:
			continue
		ret.append(wa)
	return ret


func get_enemy_war_vstate():
	var wv = war_vstate()
	if wv == null:
		return null
	return wv.get_enemy_vstate()


func get_enemy_leader() -> War_Actor:
	var wv = war_vstate()
	if wv == null:
		return null
	return wv.get_enemy_leader()


func get_enemy_war_actors(checkPosition: bool = false) -> Array:
	var ret = []
	var wf = DataManager.get_current_war_fight()
	for wv in wf.war_vstates():
		if wv.id == wvId:
			continue
		for wa in wv.get_war_actors(false, checkPosition):
			if not is_enemy(wa):
				continue
			ret.append(wa)
	return ret


func get_nearest_army() -> War_Actor:
	var ret = null
	var minDistance = 10000
	
	for wa in get_enemy_war_actors(true):
		
		var distance = Global.get_distance(position, wa.position)
		if distance > minDistance:
			continue
		minDistance = distance
		ret = wa
	return ret


func is_reinforcement() -> bool:
	return wvId != vstateId


func get_retreat_city_id() -> int:
	
	if DataManager.endless_mode and vstateId > 0:
		return 1

	var wv = war_vstate()
	if wv == null:
		return - 1
	
	if is_reinforcement():
		var fromCity = wv.from_city()
		if fromCity.get_vstate_id() == vstateId:
			return fromCity.ID
	
	var wf = DataManager.get_current_war_fight()
	var warCity = wf.target_city()
	var minActorsScore = 50000
	var targetCityId = - 1
	for cityId in warCity.get_connected_city_ids([vstateId]):
		var city = clCity.city(cityId)
		if city.get_actors_count() < minActorsScore:
			targetCityId = cityId
			minActorsScore = city.get_actors_count()
	if targetCityId < 0:
		
		var enemyScore = - 50000
		for cityId in warCity.get_connected_city_ids([ - 1]):
			var city = clCity.city(cityId)
			var score = city.get_connected_city_ids([vstateId]).size()
			score -= city.get_connected_city_ids([], [ - 1, vstateId]).size()
			if score > enemyScore:
				targetCityId = cityId
				enemyScore = score
	return targetCityId

func is_teammate(wa: War_Actor) -> bool:
	if wa == null or wa.disabled:
		return false
	if wa.actorId == actorId:
		return false
	return wa.wvId == wvId

func is_friendly(wa: War_Actor) -> bool:
	if wa == null or wa.disabled:
		return false
	return wa.wvId != wvId and wa.vstateId == vstateId

func is_enemy(wa: War_Actor) -> bool:
	if wa == null or wa.disabled:
		return false
	return wa.side() != side()


func get_solo_accept_rate(from: War_Actor) -> int:
	var b = actor()
	var a = from.actor()
	
	var oldRate = max(0, a.get_level() - b.get_level()) * 2 + 32 - b.get_wisdom() / 10
	
	var newRate = b.get_hp() * b.get_power() * battle_courage * max(1, 100 - b.get_wisdom()) / 100 / 100 / 100
	return int(min(oldRate, newRate))


func get_attack_distance() -> int:
	
	
	if not dic_other_variable.has("额外攻击距离"):
		return 1
	var setting = Global.arrval(dic_other_variable["额外攻击距离"])
	if setting.size() < 2:
		return 1
	var wf = DataManager.get_current_war_fight()
	if Global.intval(setting[0]) < wf.date:
		return 1
	return Global.intval(setting[1]) + 1


func reset_attack_distance() -> void :
	if not dic_other_variable.has("额外攻击距离"):
		return
	var setting = Global.arrval(dic_other_variable["额外攻击距离"])
	if setting.size() < 4:
		return
	if Global.intval(setting[3]) <= 0:
		return
	dic_other_variable.erase("额外攻击距离")
	return

func get_terrian_cn() -> String:
	if not has_position():
		return "未知"
	var map = SceneManager.current_scene().get_node_or_null("war_map")
	if map == null:
		return "未知"
	return map.get_blockCN_by_position(position)


func update_buff_attrs() -> void :
	var courage = actor().get_equip_feature_total("白刃战动态胆")
	var diff = courage - extra_battle_courage
	extra_battle_courage = courage
	battle_courage += diff
	return


func set_war_side(side: String) -> void :
	dic_other_variable["临面"] = side
	return

func get_war_side() -> String:
	return Global.dic_val(dic_other_variable, "临面", "")


func ambush(pos: Vector2) -> void :
	set_ext_variable("埋伏位置", [pos.x, pos.y])
	set_ext_variable("跳过布阵", 1)
	position = Vector2( - 1, - 1)
	return



func get_ambush_position() -> Vector2:
	var pos = Global.intarrval(get_ext_variable("埋伏位置", null))
	if pos.size() != 2:
		return Vector2( - 1, - 1)
	return Vector2(pos[0], pos[1])


func ambush_out(pos: Vector2) -> void :
	set_ext_variable("埋伏位置", null)
	set_ext_variable("跳过布阵", null)
	position = pos
	return


func is_puppet() -> bool:
	return actorId >= StaticManager.ACTOR_ID_RENOU


func set_AI(ai: int) -> void :
	AI = ai
	return

func is_attacker() -> bool:
	var wv = war_vstate()
	if wv == null:
		return false
	return wv.is_attacker()

func is_defender() -> bool:
	var wv = war_vstate()
	if wv == null:
		return false
	return wv.is_defender()
