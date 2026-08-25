# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/War_Vstate.gd
# 说明：战争状态对象。维护一场战争中各势力/单位的实时状态。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Resource
class_name War_Vstate

enum Lose_ReasonEnum{
	NotLose = 0, 
	NoMind, 
	LoseCity, 
	OverDay, 
	MainActorLose, 
	FoodExhaustion, 
}


var id: int = 0

var side: String = "";

var vstateId: int = - 1;

var from_cityId: int = - 1;

var init_actors: Array = [];

var money: int = 0;

var rice: int = 0;

var main_actorId: int = - 1;

var lose_reason: int = 0;

var capture_actors: Array = [];

var _lose_sodiers = 0;

var camp_actors: Array = [];

var following_actors: Array = []

var settled = 0

var pendingDates: int = 0

var embattled: int = 0

var embattleReported: int = 0

var warActors: Array = []

var delegated: int = 0




var fromCityActorIds: Array = []



var env: Env = Env.new()

func _init(_vstateId: int, isReinforcement: bool = false, isAttacker: bool = true) -> void :
	vstateId = _vstateId
	id = _vstateId
	if isReinforcement:
		
		
		id = (_vstateId + 1) * 100 + 1
	side = "攻击方" if isAttacker else "防守方"
	return

func get_save_dit():
	var dit = {
		"id": id, 
		"side": side, 
		"vstateId": vstateId, 
		"from_cityId": from_cityId, 
		"init_actors": PoolIntArray(init_actors), 
		"money": money, 
		"rice": rice, 
		"main_actorId": main_actorId, 
		"lose_reason": lose_reason, 
		"capture_actors": PoolIntArray(capture_actors), 
		"_lose_sodiers": _lose_sodiers, 
		"camp_actors": camp_actors, 
		"following_actors": following_actors, 
		"settled": settled, 
		"pendingDates": pendingDates, 
		"embattled": embattled, 
		"embattleReported": embattleReported, 
		"warActors": [], 
		"delegated": delegated, 
		"fromCityActorIds": fromCityActorIds, 
		"env": env.to_save_data(), 
	}
	for wa in warActors:
		dit["warActors"].append(wa.get_save_dit())
	return dit

func set_save_data(data: Dictionary):
	for key in ["side"]:
		if key in data:
			set(key, Global.strval(data[key]))
	
	id = - 1
	
	embattleReported = 1
	for key in [
		"vstateId", "id", "from_cityId", 
		"money", "rice", "main_actorId", 
		"lose_reason", "_lose_sodiers", 
		"settled", "pendingDates", "embattled", 
		"embattleReported", "delegated", 
		]:
		if key in data:
			set(key, Global.intval(data[key]))
	
	if id < 0:
		id = vstateId
	for key in [
		"init_actors", "capture_actors", "camp_actors", 
		"following_actors", "fromCityActorIds", 
		]:
		set(key, [])
		if key in data:
			set(key, Global.intarrval(data[key], true))
	warActors = []
	if "warActors" in data:
		for waData in Global.arrval(data["warActors"]):
			var wa = War_Actor.new(vstateId, id)
			wa.set_save_dit(waData)
			warActors.append(wa)
			
			camp_actors.erase(wa.actorId)
	env = Env.new()
	if "env" in data:
		env.from_save_data(data["env"])
	return


func get_main_controlNo() -> int:
	if delegated > 0:
		if Input.is_action_pressed("EMU_START"):
			delegate(false)
		else:
			return - 1
	if DataManager.endless_mode:
		
		if vstateId == EndlessGame.PLAYER_VSTATEID:
			return 0
		else:
			return - 1
	var vs = clVState.vstate(vstateId)
	for playerNo in DataManager.players.size():
		var player: Player = DataManager.players[playerNo];
		if (player.actorId < 0):
			continue;
		if (player.actorId == main_actorId):
			return int(playerNo);
		if vs.get_lord_id() == player.actorId:
			return int(playerNo);
	return - 1;


func get_actors_count(includingCamp: bool = false):
	var actorIds = []
	var ret = 0
	for wa in get_war_actors(false):
		ret += 1
		actorIds.append(wa.actorId)
	if not includingCamp:
		return ret
	for actorId in camp_actors:
		if actorId in actorIds:
			continue
		ret += 1
	return ret


func get_all_soldiers(includingCamp: bool = false) -> int:
	var soldiers = 0
	var actorIds = []
	for wa in get_war_actors(false):
		soldiers += wa.get_soldiers()
		actorIds.append(wa.actorId)
	if not includingCamp:
		return soldiers
	for actorId in camp_actors:
		
		if actorId in actorIds:
			continue
		var actor = ActorHelper.actor(actorId)
		soldiers += actor.get_soldiers()
	return soldiers



func turn_begin_event(actorIds: PoolIntArray = []):
	
	var msgs = []
	msgs.append_array(decrease_scene_skill(actorIds, true))
	if not msgs.empty():
		DataManager.record_war_log("\n".join(msgs))
	return


func turn_end_event(actorIds: PoolIntArray = []):
	
	embattled = 0
	var wf = DataManager.get_current_war_fight()

	var msgs = ["==== <y{0}>军行动结束 ====".format([
		get_leader_name(), 
	])]

	
	msgs.append_array(decrease_scene_skill(actorIds))

	var pendingActorIds = []
	for wa in get_war_actors(false):
		pendingActorIds.append(wa.actorId)
	
	SkillHelper.decrease_ban_actor_skill(20000, pendingActorIds)

	for wa in wf.get_war_actors():
		if not actorIds.empty() and not wa.actorId in actorIds:
			continue
		
		wa.clear_tmp_variables()
		var current_turn_name = ["任意"]
		if wa.wvId == id:
			current_turn_name.append("己方")
		elif wa.vstateId != vstateId and not is_reinforcement():
			
			
			current_turn_name.append("敌方")
		
		for key in wa.dic_skill_cd.keys():
			var turn = int(wa.dic_skill_cd[key])
			var skillInfo = StaticManager.get_stratagem(key)
			if not skillInfo.get_cd_type() in current_turn_name:
				continue
			if turn > 0:
				wa.dic_skill_cd[key] = turn - 1
			
			if int(wa.dic_skill_cd[key]) <= 0:
				wa.dic_skill_cd.erase(key)
			
		
		
		for key in wa.dic_buffs.keys():
			
			if not key in wa.dic_buffs:
				continue
			var dic_buff: Dictionary = wa.dic_buffs[key]
			var buffInfo = StaticManager.get_buff(key)
			if buffInfo == null:
				continue
			if buffInfo.get_scene() != "大战场":
				continue
			if not buffInfo.get_settlement() in current_turn_name:
				continue
			
			var turn = int(dic_buff["回合数"])
			if turn > 0:
				turn -= 1
				dic_buff["回合数"] = turn
			
			if turn <= 0:
				wa.dic_buffs.erase(key)
			buffInfo.perform_to_target(int(dic_buff["经验武将"]), wa.actorId)

		
		for key in wa.dic_areas.keys():
			var area = wa.dic_areas[key]
			var buffName = key
			if "BUFF" in area:
				buffName = area["BUFF"]
			var buff = StaticManager.get_buff(buffName)
			if not buff.get_settlement() in current_turn_name:
				continue
			var turn = int(area["回合数"])
			if turn > 0:
				turn -= 1
				wa.dic_areas[key]["回合数"] = turn
			
			if turn <= 0:
				wa.dic_areas.erase(key)
				if area.has("影响坐标"):
					var pos = Vector2(int(area["影响坐标"]["x"]), int(area["影响坐标"]["y"]))
					SceneManager.current_scene().war_map.mark_area_trapped(false, pos, 2)

	DataManager.record_war_log("\n".join(msgs))
	return



func decrease_scene_skill(actorIds: PoolIntArray = [], oppositeCD: bool = false) -> PoolStringArray:
	var msgs = []
	for actorIdKey in DataManager.actor_scene_skill.keys():
		var actorId = int(actorIdKey)
		var wa = DataManager.get_war_actor(actorId)
		if wa == null:
			continue
		var current = DataManager.actor_scene_skill[actorIdKey]
		var updated = []
		for dic in current:
			if not "sceneId" in dic:
				continue
			
			if int(dic["sceneId"]) < 20000:
				updated.append(dic)
				continue
			if not dic.has("turn"):
				continue
			if int(dic["turn"]) >= 99999:
				updated.append(dic)
				continue
			
			if wa.wvId != id:
				updated.append(dic)
				continue
			
			if actorIds.size() > 0 and not int(actorIdKey) in actorIds:
				updated.append(dic)
				continue
			if oppositeCD and Global.dic_val(dic, "cd") != "敌方":
				updated.append(dic)
				continue
			if not oppositeCD and Global.dic_val(dic, "cd") == "敌方":
				updated.append(dic)
				continue
			dic["turn"] = int(dic["turn"]) - 1
			if dic["turn"] <= 0:
				var msg = "  - <y{0}>失去临时技能【<r{1}>】".format([
					wa.get_name(), dic["skill_name"], 
				])
				msgs.append(msg)
				continue
			updated.append(dic)
		if updated.empty():
			DataManager.actor_scene_skill.erase(actorIdKey)
		else:
			DataManager.actor_scene_skill[actorIdKey] = updated
	return msgs

func get_lose_sodiers() -> int:
	return _lose_sodiers


func get_lose_actors() -> Array:
	var lose_actors = [];
	for actorId in init_actors:
		var is_lose = false;
		var wa = DataManager.get_war_actor(actorId)
		if wa != null and not wa.disabled:
			
			if wa.wvId == id:
				continue
			
			lose_actors.append(actorId)
		else:
			
			if actorId in PoolIntArray(capture_actors):
				continue
			
			if actorId in PoolIntArray(camp_actors):
				continue
			
			var actor = ActorHelper.actor(actorId)
			if not actor.is_status_officed():
				lose_actors.append(actorId)
				continue
			
			var inCity = DataManager.get_office_city_by_actor(actorId)
			if inCity != null and inCity.get_vstate_id() != vstateId:
				lose_actors.append(actorId)
	return lose_actors


func get_add_actors_num():
	var num = 0
	for wa in get_war_actors(false):
		if wa.initWvId == id:
			continue
		num += 1
	var enemy_wv = get_enemy_vstate()
	for actorId in enemy_wv.get_lose_actors():
		var actor = ActorHelper.actor(actorId)
		if actor.is_status_officed():
			var inCity = DataManager.get_office_city_by_actor(actorId)
			if inCity != null and inCity.get_vstate_id() == vstateId:
				num += 1
		elif actor.is_status_captured():
			num += 1
	return num


func set_lost_reason(reason: int) -> void :
	lose_reason = reason
	return


func check_lose() -> bool:
	if lose_reason != Lose_ReasonEnum.NotLose:
		return true
	
	if not ready():
		return false

	var leader = get_leader()
	
	if leader == null or leader.disabled:
		set_lost_reason(Lose_ReasonEnum.MainActorLose)
		return true
	
	if leader.wvId != id:
		set_lost_reason(Lose_ReasonEnum.MainActorLose)
		return true
	var enemy = get_enemy_vstate()
	if enemy == null:
		return false
	
	if is_defender():
		var map = SceneManager.current_scene().war_map
		for wa in enemy.get_war_actors(false, true):
			var terrian = map.get_buildCN_by_position(wa.position)
			if terrian == "太守府":
				set_lost_reason(Lose_ReasonEnum.LoseCity)
				return true
	return false


func get_enemy_vstate():
	var wf = DataManager.get_current_war_fight()
	for wv in [wf.defenderWV, wf.attackerWV]:
		if wv.side == side:
			continue
		return wv
	return null


func camp_out(actorId: int, updateBuff: bool = true) -> War_Actor:
	var actor = ActorHelper.actor(actorId)
	actor.reset_levelup_trackings()
	var wa = DataManager.get_war_actor(actorId)
	if wa == null:
		wa = War_Actor.new(vstateId, id)
		wa.actorId = actorId
		wa.action_point = 0
		
		warActors.append(wa)
	else:
		var prevWV = wa.war_vstate()
		if prevWV != null:
			prevWV.remove_war_actor(actorId)
		wa.vstateId = vstateId
		wa.wvId = id
		warActors.append(wa)

	wa.position = Vector2( - 1, - 1)
	wa.disabled = false
	wa.init_AI()
	
	wa.wait_dialogs.clear()
	
	wa.refresh_poker_random()

	
	camp_actors.erase(actorId)

	
	if wa.actorId == main_actorId:
		for srb in SkillRangeBuff.find_for_vstate("主将自矜", vstateId):
			if srb.effectTagVal > 0:
				var wf = DataManager.get_current_war_fight()
				var appendedSkills = wf.get_env_array("战前附加技能")
				appendedSkills.append([
					wa.actorId, "自矜", 99999, 
					srb.actorId, srb.skillName, 
				])
				wf.set_env("战前附加技能", appendedSkills)

				SkillHelper.add_actor_scene_skill(20000, wa.actorId, "自矜", 99999, srb.actorId, srb.skillName)
				var msg = "{0}！\n鼠辈也敢犯我虎威！\n（因拒绝{1}【{2}】\n（附加【自矜】".format([
					DataManager.get_actor_naughty_title(get_enemy_leader().actorId, wa.actorId), 
					ActorHelper.actor(srb.actorId).get_name(), srb.skillName, 
				])
				wa.attach_free_dialog(msg, 0)
				break

	if updateBuff:
		SkillHelper.update_all_skill_buff("CAMP_OUT")
	return wa

func vstate():
	return clVState.vstate(vstateId)


func get_lord_id() -> int:
	return vstate().get_lord_id()


func get_lord() -> ActorHelper.ActorInfo:
	return ActorHelper.actor(get_lord_id())


func get_lord_name() -> String:
	return get_lord().get_name()

func set_camp_in_time(actorId: int):
	var wf = DataManager.get_current_war_fight()
	var record = wf.get_env_dict("回营时间")
	record[str(actorId)] = wf.date
	wf.set_env("回营时间", record)
	return

func check_camp_out(actorId: int) -> String:
	var wf = DataManager.get_current_war_fight()
	var record = wf.get_env_dict("回营时间")
	if not str(actorId) in record:
		return ""
	if Global.intval(record[str(actorId)]) < wf.date:
		return ""
	return "今日不可再出营"

func from_city() -> clCity.CityInfo:
	return clCity.city(from_cityId)

func get_leader() -> War_Actor:
	return get_war_actor(main_actorId)

func get_leader_name() -> String:
	var leader = get_leader()
	if leader != null:
		return leader.get_name()
	return ActorHelper.actor(main_actorId).get_name()

func get_war_actor(actorId: int) -> War_Actor:
	for wa in warActors:
		if wa.actorId == actorId:
			return wa
	return null




func get_war_actors(includeDisabled: bool = true, checkPosition: bool = false) -> Array:
	var ret = []
	for wa in warActors:
		if wa == null:
			continue
		if wa.wvId != id:
			continue
		if wa.disabled and not includeDisabled:
			continue
		if checkPosition and not wa.has_position():
			continue
		if wa.actorId == main_actorId:
			ret.insert(0, wa)
		else:
			ret.append(wa)
	return ret


func get_enemy_war_actors(checkPosition: bool = false) -> Array:
	var enemy = get_enemy_vstate()
	if enemy == null:
		return []
	var ret = []
	for wa in enemy.get_war_actors(false, checkPosition):
		ret.append(wa)
	return ret


func get_enemy_leader() -> War_Actor:
	var enemy = get_enemy_vstate()
	if enemy == null:
		return null
	return enemy.get_leader()

func lost() -> bool:
	match lose_reason:
		Lose_ReasonEnum.NotLose:
			return false
	return true


func get_lost_message() -> String:
	match lose_reason:
		Lose_ReasonEnum.FoodExhaustion:
			return "粮草已尽"
		Lose_ReasonEnum.MainActorLose:
			return "主将战败"
		Lose_ReasonEnum.LoseCity:
			return "主城失守"
		Lose_ReasonEnum.OverDay:
			return "旷日未克"
	return "败退"


func requires_lost_settlement() -> bool:
	if not lost():
		return false
	if settled > 0:
		return false
	return true



func settle_generals_after_war() -> bool:
	var controlNo = get_main_controlNo()
	if not is_reinforcement()\
	and controlNo >= 0\
	and get_war_actors(false).size() > 0\
	and not DataManager.endless_mode:
		
		
		
		
		
		
		delegate(false)
		return false
	
	send_all_actors_to_city(get_retreat_city())
	
	settled = 1
	return true



func settle_resources_after_war() -> void :
	
	var goldVal = money
	var riceVal = rice
	if goldVal == 0 and riceVal == 0:
		return
	
	var wf = DataManager.get_current_war_fight()
	var settleInfo = wf.get_env_dict("资源结算")
	var vsKey = "vs." + str(vstateId)
	var wvKey = "wv." + str(id)
	for key in [vsKey, wvKey]:
		if not key in settleInfo:
			settleInfo[key] = {}
		for subkey in ["money", "rice"]:
			if not subkey in settleInfo[key]:
				settleInfo[key][subkey] = 0
	wf.set_env("资源结算", settleInfo)

	
	money = 0
	rice = 0

	
	
	var leaderActor = ActorHelper.actor(main_actorId)
	var officeCity = DataManager.get_office_city_by_actor(main_actorId)
	if leaderActor.is_status_officed()\
	and officeCity != null\
	and officeCity.get_vstate_id() == vstateId:
		
		officeCity.add_gold(goldVal)
		officeCity.add_rice(riceVal)
		return

	if DataManager.endless_mode:
		
		return

	
	var enemyWV = get_enemy_vstate()
	if enemyWV == null:
		return

	var riceToGoldRate = SkillRangeBuff.max_val_for_vstate("战争夺米转金", enemyWV.vstateId)
	if riceToGoldRate > 0:
		var exchangeVal = int(riceVal * riceToGoldRate / 100.0)
		exchangeVal = min(exchangeVal, 9999 - enemyWV.money - goldVal)
		if exchangeVal > 0:
			goldVal += exchangeVal
			riceVal -= int(exchangeVal * 100.0 / riceToGoldRate)
			
			if riceVal < 0 or riceVal == 1:
				riceVal = 0

	enemyWV.change_gold(goldVal)
	enemyWV.change_rice(riceVal)
	for key in [vsKey, wvKey]:
		settleInfo[key]["money"] += goldVal
		settleInfo[key]["rice"] += riceVal
	wf.set_env("资源结算", settleInfo)
	return




func send_all_actors_to_city(targetCity: clCity.CityInfo) -> bool:
	var wf = DataManager.get_current_war_fight()
	var warCity = wf.target_city()
	var exileCityIds = []
	if targetCity == null:
		
		exileCityIds = warCity.get_connected_city_ids()
		exileCityIds.append(warCity.ID)
	var keptActorIds = []
	
	
	if targetCity != null and from_cityId == targetCity.ID:
		keptActorIds = fromCityActorIds
	var sent = 0
	var warActors = get_war_actors(false)
	
	var surrended = []
	for wa in warActors:
		if wa.init_vstateId != vstateId:
			
			surrended.append(wa)
			continue
		if targetCity != null:
			wa.retreat_to(targetCity.ID)
			sent += 1
		else:
			
			exileCityIds.shuffle()
			wa.banish_to(exileCityIds[0])
	
	var others = []
	others.append_array(camp_actors)
	others.append_array(following_actors)
	for otherId in others:
		if targetCity != null:
			if otherId in keptActorIds:
				clCity.move_to(otherId, targetCity.ID, keptActorIds)
			else:
				clCity.move_to(otherId, targetCity.ID)
			sent += 1
		else:
			
			exileCityIds.shuffle()
			var actor = ActorHelper.actor(otherId)
			actor.set_status_exiled( - 1, exileCityIds[0])
	camp_actors.clear()
	following_actors.clear()

	
	for wa in surrended:
		if targetCity != null:
			wa.retreat_to(targetCity.ID)
			sent += 1
		else:
			
			exileCityIds.shuffle()
			wa.banish_to(exileCityIds[0])
	
	for capturedActorId in capture_actors:
		if targetCity != null and targetCity.get_vstate_id() == vstateId:
			
			clCity.move_to_ceil(capturedActorId, targetCity.ID)
		else:
			
			clCity.move_to_ceil(capturedActorId, warCity.ID)
	capture_actors.clear()
	
	if targetCity != null and sent > 0:
		targetCity.set_vstate_id(vstateId)
	return sent > 0

static func from_saved_data(data: Dictionary) -> War_Vstate:
	var wv = load("res://script/War_Vstate.gd").new( - 1)
	wv.set_save_data(data)
	return wv



func add_war_actor(wa: War_Actor, allowDuplicate: bool = false) -> void :
	if wa == null:
		return
	var wf = DataManager.get_current_war_fight()
	if not allowDuplicate:
		for wv in wf.war_vstates():
			wv.remove_war_actor(wa.actorId)
			wv.camp_actors.erase(wa.actorId)
			wv.following_actors.erase(wa.actorId)
			wv.capture_actors.erase(wa.actorId)
	wa.wvId = id
	wa.vstateId = vstateId
	if wa.actorId == main_actorId:
		warActors.insert(0, wa)
	else:
		warActors.append(wa)
	return


func remove_war_actor(actorId: int) -> void :
	var updated = []
	for wa in warActors:
		if wa != null and wa.actorId == actorId:
			continue
		updated.append(wa)
	warActors = updated
	return


func remove_actor(actorId: int) -> void :
	remove_war_actor(actorId)
	camp_actors.erase(actorId)
	following_actors.erase(actorId)
	capture_actors.erase(actorId)
	return


func add_following_actor(actorId: int) -> void :
	remove_actor(actorId)
	following_actors.append(actorId)
	return


func is_attacker() -> bool:
	return side == "攻击方"


func is_defender() -> bool:
	return side == "防守方"


func is_reinforcement() -> bool:
	return id != vstateId


func get_all_retreat_city_ids() -> PoolIntArray:
	var ret = []
	var wf = DataManager.get_current_war_fight()
	ret.append_array(wf.target_city().get_connected_city_ids([vstate().id, - 1]))
	if is_attacker():
		for extraCityId in wf.get_env_int_array("额外可撤退城市"):
			if extraCityId in ret:
				continue
			var extraCity = clCity.city(extraCityId)
			if not extraCity.get_vstate_id() in [vstateId, - 1]:
				continue
			ret.append(extraCityId)
	
	if from_cityId in ret:
		ret.erase(from_cityId)
		ret.insert(0, from_cityId)
	return ret

func get_retreat_city() -> clCity.CityInfo:
	
	if is_reinforcement():
		var fromCity = from_city()
		if fromCity.get_vstate_id() == vstateId:
			return fromCity
	
	var wf = DataManager.get_current_war_fight()
	var warCity = wf.target_city()
	var minActorsScore = 50000
	var targetCity = null
	for cityId in warCity.get_connected_city_ids([vstateId]):
		var city = clCity.city(cityId)
		if city.get_actors_count() < minActorsScore:
			targetCity = city
			minActorsScore = city.get_actors_count()
	if targetCity == null:
		
		var enemyScore = - 50000
		for cityId in warCity.get_connected_city_ids([ - 1]):
			var city = clCity.city(cityId)
			var score = city.get_connected_city_ids([vstateId]).size()
			score -= city.get_connected_city_ids([], [ - 1, vstateId]).size()
			if score > enemyScore:
				targetCity = city
				enemyScore = score
	return targetCity


func ready() -> bool:
	if pendingDates <= 0:
		return true
	var wf = DataManager.get_current_war_fight()
	return pendingDates < wf.date




func prepare_war_actors(forPlayer: bool = false) -> void :
	if not ready():
		return
	if not forPlayer and get_main_controlNo() >= 0:
		return
	
	var pending = camp_actors.duplicate(true)
	while not pending.empty():
		if get_actors_count() >= 10:
			break
		var actorId = pending.pop_front()
		if check_camp_out(actorId) != "":
			continue
		camp_out(actorId, false)
	return


func delegate(on: bool = true) -> void :
	var prev = delegated
	delegated = 1 if on else 0
	if delegated != prev:
		prepare_controller()
	return


func prepare_controller() -> void :
	DataManager.war_control_sort.clear()
	DataManager.war_control_sort_no = 0
	DataManager.player_choose_actor = main_actorId
	
	DataManager.war_control_sort.append(get_main_controlNo())
	
	for wa in get_war_actors(false):
		if wa.actorId == main_actorId:
			continue
		var actor_controlNo = DataManager.get_actor_controlNo(wa.actorId)
		if actor_controlNo < 0:
			continue
		if actor_controlNo in DataManager.war_control_sort:
			continue
		DataManager.war_control_sort.append(actor_controlNo)
	return

func change_gold(gold: int) -> void :
	money += gold
	money = max(0, money)
	money = min(9999, money)
	return

func change_rice(val: int) -> int:
	var current = rice
	rice += val
	rice = max(0, rice)
	rice = min(9999, rice)
	return rice - current



func daily_rice_cost() -> Array:
	
	var cost = - int(get_all_soldiers() / 250)
	var ret = [cost, cost, []]

	var rate = 100
	var rateDowns = []
	for srb in SkillRangeBuff.find_for_war_vstate("减少粮草消耗", id):
		if srb.effectTagVal <= 0:
			continue
		rateDowns.append([srb.actorId, srb.skillName, srb.effectTagVal])
		rate -= srb.effectTagVal
	if rate == 90 and rateDowns.size() == 1 and rateDowns[0][1] == "辟谷":
		
		rate = 80
		rateDowns[0][2] = 20
	if rate < 0:
		ret[1] = 0
	else:
		ret[1] = cost * rate / 100
	ret[2] = rateDowns
	return ret



func daily_cost_rice() -> int:
	var settings = daily_rice_cost()
	var cost = 0
	if settings[1] < 0:
		cost = abs(change_rice(settings[1]))
	var msg = "- <y{0}>军消耗粮草<r{1}>, 余粮{2}".format([
		get_leader_name(), cost, rice
	])
	for r in settings[2]:
		msg += "\n  - <y{0}>【<r{1}>】减少粮草消耗 <g{2}>%".format([
			ActorHelper.actor(r[0]).get_name(), 
			r[1], r[2]
		])
	DataManager.record_war_log(msg)
	return cost


func has_actor(actorId: int) -> bool:
	if get_war_actor(actorId) != null:
		return true
	if camp_actors.has(actorId):
		return true
	if following_actors.has(actorId):
		return true
	return false


func camp_in(wa: War_Actor) -> bool:
	if wa == null:
		return false
	
	if wa.is_puppet():
		remove_war_actor(wa.actorId)
		return false
	var actor = wa.actor()
	actor.reset_levelup_trackings()
	wa.mark_disabled("回营")
	remove_war_actor(wa.actorId)
	camp_actors.erase(wa.actorId)
	following_actors.erase(wa.actorId)
	camp_actors.append(wa.actorId)
	set_camp_in_time(wa.actorId)
	SkillHelper.update_all_skill_buff("CAMP_IN")
	return true


func back_from_war() -> void :
	
	
	DataManager.set_env("内政.战后.wvId", id)
	for actorId in init_actors:
		SkillHelper.auto_trigger_skill(actorId, 10013)
	
	
	var leaders = [init_actors[0]]
	var lordId = get_lord_id()
	if not lordId in leaders:
		leaders.append(lordId)
	for leaderId in leaders:
		SkillHelper.auto_trigger_skill(leaderId, 10024)
	return
