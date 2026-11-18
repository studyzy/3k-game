extends Node



const PLAYER_VSTATEID = 0
const AI_vstateId = 1
const third_vstateId = 2


const PASS_DURATION_LIMIT = 3600


const PLAYER_RESOURCES = [5000, 3000, 1000, 500, 1000]

const SOLDIERS_RECOVER = [1000, 700, 500, 500, 500]


const ACTOR_PENALTY = {
	"赵云": - 10, "姜维": - 10, "文鸯": - 10, "张辽": - 10, "诸葛亮": - 10, 
	"马超": - 10, "甘宁": - 10, "吕布": - 10, "张飞": - 10, "周瑜": - 10, 
	"关羽": - 8, "曹操": - 8, "黄忠": - 8, "孙坚": - 8, "司马懿": - 8, 
	"颜良": - 8, "魏延": - 8, "庞德": - 8, "董卓": - 8, "吕蒙": - 8, 
	"文丑": - 6, "张梁": - 6, "张宝": - 6, "郝昭": - 6, "太史慈": - 6, 
	"孙策": - 6, "曹仁": - 6, "张绣": - 6, "曹彰": - 6, "罗宪": - 6, 
	"陆逊": - 5, "潘凤": - 5, "曹昂": - 5, "刘备": - 5, "夏侯恩": - 5, 
	"张任": - 5, "华佗": - 5, "乐进": - 5, "麹义": - 5, "孟获": - 5, 
	"丁原": - 4, "孔融": - 4, "鲁肃": - 4, "贾诩": - 4, "邢道荣": - 4, 
	"徐庶": - 4, "邓艾": - 4, "孙峻": - 4, "张角": - 4, "臧霸": - 4, 
}


func get_actor_penalty(actorName: String) -> int:
	if not DataManager.is_challange_game():
		return 0
	if actorName in ACTOR_PENALTY:
		return ACTOR_PENALTY[actorName]
	return 0


func get_chosen_penalty_per_pass(actors: Array) -> int:
	if not DataManager.is_challange_game():
		return 0
	var total = 0
	for actor_val in actors:
		if actor_val == null:
			continue
		var actorId = int(str(actor_val).split("|")[0])
		if actorId < 0:
			continue
		var actor = ActorHelper.actor(actorId)
		total += get_actor_penalty(actor.get_name())
	return total



var chosen_actors = []

var player_actors = []

var init_player_actors = []

var AI_actors = []

var pass_no: int = 0

var targetCityIds = []

var war_vstate_no_player = 0;

var war_vstate_no_ai = 1;


var stats = {}

func get_data() -> Dictionary:
	return {
		"chosen_actors": chosen_actors, 
		"player_actors": player_actors, 
		"init_player_actors": init_player_actors, 
		"pass_no": pass_no, 
		"AI_actors": AI_actors, 
		"war_vstate_no_player": war_vstate_no_player, 
		"war_vstate_no_ai": war_vstate_no_ai, 
		"stats": stats, 
		"targetCityIds": targetCityIds, 
	};

func set_data(dic: Dictionary):
	for attr in ["chosen_actors"]:
		set(attr, [])
		if attr in dic:
			set(attr, Global.arrval(dic[attr]))
	for attr in ["player_actors", "init_player_actors", 
		"AI_actors", "targetCityIds"]:
		set(attr, [])
		if attr in dic:
			set(attr, Global.intarrval(dic[attr]))
	for attr in [
		"pass_no", "war_vstate_no_player", 
		"war_vstate_no_ai"
		]:
		set(attr, 0)
		if attr in dic:
			set(attr, Global.intval(dic[attr]))
	for attr in ["stats", ]:
		set(attr, {})
		if attr in dic:
			set(attr, Global.dicval(dic[attr]))
	return

func load_endless(_init_player_actors: PoolIntArray) -> bool:
	init_player_actors = []
	init_player_actors.append_array(_init_player_actors)
	player_actors = []
	player_actors.append_array(init_player_actors)

	for vs in clVState.all_vstates():
		vs.set_lord( - 1)
		vs.set_perished()

	go_to_pass(0)

	fix_all_actor_data()
	return true

func fix_all_actor_data() -> void :
	SkillHelper.update_all_skill_buff("INF-FIX", 10000)
	for actor in ActorHelper.all_actors():
		if actor.actorId == StaticManager.ACTOR_ID_DONGZHUO:
			pass
		var limit = DataManager.get_actor_max_soldiers(actor.actorId)
		actor.set_soldiers(limit)
		actor.set_hp(actor.get_max_hp())
	return

func create_actors():
	
	var pre_actors = player_actors.duplicate();
	player_actors = [];
	for actorId in init_player_actors:
		if actorId == - 1:
			actorId = _get_free_actorId();
		elif actorId < 0:
			continue;
		player_actors.append(actorId);
		fix_actor_data(actorId, true);
	
	
	while pre_actors.size() > player_actors.size():
		var new_actorId = pre_actors.pop_back();
		if new_actorId in player_actors:
			continue;
		player_actors.append(new_actorId)
		fix_actor_data(new_actorId, true);

	var wf = DataManager.get_current_war_fight()
	var playerWV = wf.defenderWV
	if war_vstate_no_player != 0:
		playerWV = wf.attackerWV
	playerWV.init_actors = Array(PoolIntArray(player_actors))
	playerWV.main_actorId = int(player_actors[0])
	var vs = clVState.vstate(PLAYER_VSTATEID)
	vs.set_lord(player_actors[0])
	vs.set_alive()

	AI_actors = []
	
	var diff = [
		max(3, init_player_actors.size()), 
		max(5, init_player_actors.size() + 2), 
		max(8, init_player_actors.size() + 4), 
		10, 
		10
	]

	var AIActorsCount = min(20, diff[DataManager.diffculities] + pass_no)
	var thirdpartyActorsCount = max(3, int(AIActorsCount / 3))
	for wv in wf.war_vstates():
		if wv.id == playerWV.id:
			continue
		if wv.id == AI_vstateId:
			create_actors_for_AI(wv, AIActorsCount)
		else:
			create_actors_for_AI(wv, thirdpartyActorsCount)
	return

func create_actors_for_AI(wv: War_Vstate, actorsCount: int) -> void :
	var members = []
	
	var leaderId = _get_AI_leaderId(wv)
	fix_actor_data(leaderId, false)
	AI_actors.append(leaderId)
	members.append(leaderId)
	for i in actorsCount - 1:
		var memberId = _get_free_actorId()
		fix_actor_data(memberId, false)
		AI_actors.append(memberId)
		members.append(memberId)

	wv.init_actors = members
	wv.main_actorId = members[0]
	var vs = wv.vstate()
	vs.set_lord(members[0])
	vs.set_alive()
	var AIKing = ActorHelper.actor(members[0])
	AIKing.set_loyalty(100)
	AIKing.set_soldiers(max(2500, AIKing.get_soldiers()))
	return


func _get_AI_leaderId(wv: War_Vstate) -> int:
	if DataManager.diffculities < 4:
		return _get_free_actorId()
	if DataManager.get_game_setting("技能系统") != "是":
		return _get_free_actorId()

	var ret = - 1
	
	if EndlessGame.pass_no == 39\
	and not wv.is_reinforcement()\
	and Global.get_rate_result(40):
		ret = StaticManager.ACTOR_ID_ZHOUYU
	
	if ret < 0:
		var leaderSkills = []
		for skill in StaticManager.skillDict.values():
			if skill.has_feature("主将") and skill.type == "锁定":
				leaderSkills.append(skill.name)
		var leaders = []
		for item in StaticManager.actor_skills:
			for skill in item.values():
				if skill in leaderSkills:
					leaders.append(int(item["ID"]))
		if leaders.empty():
			return _get_free_actorId()
		leaders.shuffle()
		ret = leaders[0]
	if ret in player_actors:
		return _get_free_actorId()
	if ret in init_player_actors:
		return _get_free_actorId()
	if ret in AI_actors:
		return _get_free_actorId()
	return ret


func _get_free_actorId() -> int:
	while true:
		var rand_actorId = ActorHelper.random_actor_id()
		if rand_actorId == StaticManager.ACTOR_ID_DIY:
			continue
		if rand_actorId in player_actors:
			continue;
		if rand_actorId in init_player_actors:
			continue;
		if rand_actorId in AI_actors:
			continue;
		var rand_actor = ActorHelper.actor(rand_actorId)
		if rand_actor.is_status_disabled():
			
			if not DataManager.is_stars_drama():
				continue
		if rand_actor.has_side():
			if Global.get_rate_result(50):
				rand_actor.set_side("阴")
			else:
				rand_actor.set_side("阳")
		return rand_actorId;
	return - 1


func fix_actor_data(actorId: int, is_player: bool):
	var actor = ActorHelper.actor(actorId)
	match actor.get_name():
		"董卓":
			if actor.is_side_positive():
				actor.set_moral(89)
			else:
				actor.set_moral(11)
		"姜维":
			SkillHelper.set_skill_variable(10000, 20213, actorId, "奋困", 99999)
		"徐庶":
			
			
			if not actor.is_side_positive():
				var flag = actor._get_attr_str("无尽转换")
				if flag != "1":
					actor._set_attr_str("无尽转换", "1")
					var wisdom = actor._get_attr_int_original("知")
					var power = actor._get_attr_int_original("武")
					actor._set_attr_int("知", power)
					actor._set_attr_int("武", wisdom)
	actor.set_hp(actor.get_max_hp())
	actor.set_status_officed()
	if is_player:
		if actorId == init_player_actors[0]:
			actor.set_loyalty(100)
		else:
			actor.set_loyalty(99)
		var soldiers = DataManager.get_actor_max_soldiers(actorId)
		soldiers = min(soldiers, actor.get_soldiers() + SOLDIERS_RECOVER[DataManager.diffculities])
		actor.set_soldiers(soldiers)
	else:
		actor.set_loyalty(99)
		var level = min(8, pass_no * 2 + 1)
		actor.set_level(max(level, actor.get_level()))
		actor.set_soldiers(DataManager.get_actor_max_soldiers(actorId))
	return

func go_to_pass(_pass_no: int):
	DataManager.endless_mode = true
	pass_no = _pass_no

	war_vstate_no_player = pass_no % 2
	war_vstate_no_ai = 1 - war_vstate_no_player

	
	var targetCityId = get_target_city_id()
	var wf = DataManager.new_war_fight( - 1, targetCityId)

	
	var wvSettings = [
		["防守方", PLAYER_VSTATEID, false], 
		["攻击方", AI_vstateId, false], 
	]
	if war_vstate_no_player == 1:
		wvSettings = [
			["防守方", AI_vstateId, false], 
			["攻击方", PLAYER_VSTATEID, false], 
		]
	if DataManager.diffculities >= 4:
		if war_vstate_no_player == 0:
			
			wvSettings.append(["攻击方", third_vstateId, false])
		else:
			
			wvSettings.append(["防守方", third_vstateId, true])
	for setting in wvSettings:
		var side = setting[0]
		var vstateId = setting[1]
		var isReinforcement = setting[2]
		var wv = initWarVstate(side, vstateId, isReinforcement)
		match wv.side:
			"防守方":
				if wf.defenderWV == null:
					wf.defenderWV = wv
				else:
					wf.extraWV = wv
					wv.pendingDates = 3
			"攻击方":
				if wf.attackerWV == null:
					wf.attackerWV = wv
				else:
					wf.extraWV = wv
					wv.pendingDates = 3

	wf.defenderWV.from_cityId = targetCityId
	wf.fromVstateId = wf.attackerWV.vstate().id
	wf.targetVstateId = wf.defenderWV.vstate().id

	
	var directions = [45, 135, 225, 315]
	directions.shuffle()
	var allDirections = {}
	for wv in wf.war_vstates():
		if wv.is_attacker() or wv.is_reinforcement():
			var dir = directions.pop_front()
			allDirections[str(wv.vstate().id)] = dir
	wf.warDirections = allDirections
	wf.warDirection = allDirections[str(wf.attackerWV.vstate().id)]

	
	create_actors()
	
	var p: Player = DataManager.players[0]
	p.actorId = player_actors[0]
	
	var king = ActorHelper.actor(player_actors[0])
	king.set_loyalty(100)
	
	var playerWV = wf.defenderWV
	var AIWV = wf.attackerWV
	if war_vstate_no_player == 1:
		playerWV = wf.attackerWV
		AIWV = wf.defenderWV

	
	AIWV.money = 9999
	AIWV.rice = 9999
	if wf.extraWV != null:
		wf.extraWV.money = 9999
		wf.extraWV.rice = 9999

	
	playerWV.money = PLAYER_RESOURCES[DataManager.diffculities]
	playerWV.rice = PLAYER_RESOURCES[DataManager.diffculities]

	
	
	var vs = clVState.vstate(PLAYER_VSTATEID)
	var yijing = clEquip.equip(StaticManager.JEWELRY_ID_YIJING, "道具")
	var found = false
	for item in vs.get_stored_equipments():
		if item[0].id == yijing.id and item[0].type == yijing.type:
			found = true
			break
	if not found:
		for actorId in player_actors:
			var actor = ActorHelper.actor(actorId)
			if actor.get_jewelry().id == yijing.id:
				found = true
				break
	if not found:
		vs.add_stored_equipment(yijing)

	if DataManager.is_challange_game():
		
		var dic = DataManager.get_env_dict("挑战赛")
		dic["passStart"] = Time.get_unix_time_from_system()
		DataManager.set_env("挑战赛", dic)
		
		var penalty = EndlessGame.get_chosen_penalty_per_pass(init_player_actors)
		DataManager.add_challange_game_score(penalty)

	
	wf.init_war()
	LoadControl.end_script()
	FlowManager.clear_bind_method()
	FlowManager.add_flow("go_to_scene|res://scene/scene_war/scene_war.tscn")
	FlowManager.add_flow("war_run_start")
	return

func initWarVstate(side: String, vstateId: int, isReinforcement: bool = false) -> War_Vstate:
	var wv = War_Vstate.new(vstateId, isReinforcement)
	wv.side = side
	wv.from_cityId = - 1
	wv.init_actors = []
	wv.main_actorId = - 1
	wv.money = 1000
	wv.rice = 1000
	wv.set_lost_reason(War_Vstate.Lose_ReasonEnum.NotLose)
	wv._lose_sodiers = 0
	wv.settled = 0
	return wv

func update_stats_data(playerWV: War_Vstate, aiWV: War_Vstate):
	get_stats_data()
	stats["player"]["soldiers"] += playerWV.get_lose_sodiers()
	stats["player"]["actors"] += playerWV.get_lose_actors().size()
	stats["player"]["recruit"] += playerWV.get_add_actors_num()
	stats["ai"]["soldiers"] += aiWV.get_lose_sodiers()
	stats["ai"]["actors"] += aiWV.get_lose_actors().size()
	stats["ai"]["recruit"] += aiWV.get_add_actors_num()
	return

func get_stats_data():
	for key in ["player", "ai"]:
		if not stats.has(key):
			stats[key] = {}
		for subkey in ["soldiers", "actors", "recruit"]:
			if not stats[key].has(subkey):
				stats[key][subkey] = 0
	return stats

func get_target_city_id() -> int:
	if DataManager.diffculities < 4:
		return pass_no % DataManager.citys.size()
	
	if targetCityIds.empty():
		targetCityIds = range(DataManager.citys.size())
	var ret = targetCityIds[randi() % targetCityIds.size()]
	targetCityIds.erase(ret)
	return ret
