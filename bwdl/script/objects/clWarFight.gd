# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/objects/clWarFight.gd
# 说明：战争结算对象（核心战争逻辑）。计算攻城/野战的整体流程与胜负。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Resource

var KILL_STREAK_MESSAGES = [
	"土鸡瓦犬，何其多也！", 
	"螳臂当车，插标卖首尔！", 
	"许久不曾如此尽兴！", 
	"既知吾名，安敢触犯！", 
	"小试牛刀耳，还有谁来？", 
]

class_name WarFight





var fromVstateId: int = - 1
var fromCityId: int = - 1

var targetVstateId: int = - 1
var targetCityId: int = - 1

var sendActors: Array = []

var attackerWV: War_Vstate = null

var defenderWV: War_Vstate = null

var extraWV: War_Vstate = null

var date: int = 0

var current: int = 0

var warDirection: int = - 1

var warDirections: Dictionary = {}




var status: int = - 1




var result: int = 0

var source: String = ""


var env: Env = Env.new()

func _init(_fromCityId: int, _targetCityId: int):
	fromCityId = _fromCityId
	fromVstateId = from_city().get_vstate_id()
	targetCityId = _targetCityId
	targetVstateId = target_city().get_vstate_id()
	return

func from_city() -> clCity.CityInfo:
	return clCity.city(fromCityId)

func from_vstate() -> clVState.VStateInfo:
	return clVState.vstate(fromVstateId)

func target_city() -> clCity.CityInfo:
	return clCity.city(targetCityId)

func target_vstate() -> clVState.VStateInfo:
	return clVState.vstate(targetVstateId)


func get_save_data() -> Dictionary:
	var ret = {}
	for prop in get_property_list():
		if prop.name == "attackerWV":
			if attackerWV != null:
				ret["attackerWV"] = attackerWV.get_save_dit()
			continue
		if prop.name == "defenderWV":
			if defenderWV != null:
				ret["defenderWV"] = defenderWV.get_save_dit()
			continue
		if prop.name == "extraWV":
			if extraWV != null:
				ret["extraWV"] = extraWV.get_save_dit()
			continue
		if prop.name == "env":
			ret["env"] = env.to_save_data()
			continue
		match prop.type:
			TYPE_ARRAY:
				ret[prop.name] = get(prop.name)
			TYPE_INT:
				ret[prop.name] = get(prop.name)
			TYPE_REAL:
				ret[prop.name] = get(prop.name)
			TYPE_STRING:
				ret[prop.name] = get(prop.name)
			TYPE_DICTIONARY:
				ret[prop.name] = get(prop.name)
			_:
				pass
				
	return ret


func load_from_save_data(dic: Dictionary) -> void :
	env = Env.new()
	for prop in get_property_list():
		if not prop.name in dic:
			continue
		if prop.name == "attackerWV":
			var data = Global.dicval(dic[prop.name])
			attackerWV = War_Vstate.from_saved_data(data)
			continue
		if prop.name == "defenderWV":
			var data = Global.dicval(dic[prop.name])
			defenderWV = War_Vstate.from_saved_data(data)
			continue
		if prop.name == "extraWV":
			extraWV = null
			var data = Global.dicval(dic[prop.name])
			if not data.empty():
				extraWV = War_Vstate.from_saved_data(data)
			continue
		if prop.name == "env":
			env.from_save_data(dic["env"])
			continue
		
		if prop.name == "sendActors":
			sendActors = []
			for _actorId in Global.intarrval(Global.dic_val(dic, "sendActors", [])):
				sendActors.append(_actorId)
			continue
		match prop.type:
			TYPE_ARRAY:
				set(prop.name, Global.arrval(dic[prop.name]))
			TYPE_INT:
				set(prop.name, Global.intval(dic[prop.name]))
			TYPE_REAL:
				set(prop.name, Global.floatval(dic[prop.name]))
			TYPE_STRING:
				set(prop.name, Global.strval(dic[prop.name]))
			TYPE_DICTIONARY:
				set(prop.name, Global.dicval(dic[prop.name]))
			_:
				print_debug("unexpected prop: ", prop)
	return


func rebuild_from_env() -> void :
	
	date = DataManager.get_env_int("war_day")
	DataManager.unset_env("war_day")
	
	targetCityId = DataManager.get_env_int("战争城")
	DataManager.unset_env("战争城")
	targetVstateId = target_city().get_vstate_id()
	
	warDirection = DataManager.get_env_int("战争方向")
	DataManager.unset_env("战争方向")
	
	var wvData = DataManager.get_env_array("war_vstate")
	if wvData.size() >= 2:
		defenderWV = War_Vstate.from_saved_data(wvData[0])
		attackerWV = War_Vstate.from_saved_data(wvData[1])
		
		fromCityId = attackerWV.from_cityId
	DataManager.unset_env("来源城")
	
	if fromVstateId < 0 and attackerWV != null:
		var leader = attackerWV.get_leader()
		if leader != null:
			fromVstateId = leader.init_vstateId
	DataManager.unset_env("来源势力")
	if wvData.size() >= 3:
		extraWV = War_Vstate.from_saved_data(wvData[2])
	
	current = DataManager.get_env_int("war_sort_no", 0)
	DataManager.unset_env("war_sort_no")
	if current < 2:
		current = 1 - current
	
	sendActors = DataManager.get_env_int_array("派遣武将")
	
	
	
	
	if DataManager.get_env_int("war_run") == 1:
		status = 1
	DataManager.unset_env("war_run")
	
	for waData in DataManager.get_env_array("war_actors"):
		var wa = War_Actor.new( - 1, - 1)
		wa.set_save_dit(waData)
		for wv in war_vstates():
			if wv.id == wa.wvId:
				wv.warActors.append(wa)
				break
	return


func war_vstates() -> Array:
	var ret = []
	for wv in [extraWV, attackerWV, defenderWV]:
		if wv != null:
			ret.append(wv)
	return ret

func get_war_vstate(wvId: int) -> War_Vstate:
	for wv in war_vstates():
		if wv.id == wvId:
			return wv
	return null



func get_war_actor(actorId: int) -> War_Actor:
	for wv in war_vstates():
		for wa in wv.warActors:
			if wa.actorId == actorId:
				return wa
	return null


func get_war_actors(includeDisabled: bool = true, checkPosition: bool = false) -> Array:
	var ret = []
	for wv in war_vstates():
		for wa in wv.get_war_actors(includeDisabled, checkPosition):
			ret.append(wa)
	return ret

func init_war() -> void :
	date = 0
	status = 1
	current = 0
	result = 0
	
	for wv in war_vstates():
		wv.warActors.clear()
		wv.camp_actors = wv.init_actors.duplicate()
		wv.prepare_war_actors(true)
	
	DataManager.reset_war_log()
	
	DataManager.clear_actor_disabled_equip_types(20000)
	SkillHelper.clear_ban_actor_skill(20000)
	SkillHelper.clear_scene_actor_skill(20000)
	SkillHelper.clear_skill_cd(20000)
	SkillHelper.clear_skill_variable(20000)
	
	for setting in get_env_array("战前附加技能"):
		var targetId = int(setting[0])
		var skill = str(setting[1])
		var turns = int(setting[2])
		var fromId = int(setting[3])
		var source = str(setting[4])
		SkillHelper.add_actor_scene_skill(20000, targetId, skill, turns, fromId, source)
	for setting in get_env_array("战前技能变量"):
		var targetId = int(setting[0])
		var effectId = int(setting[1])
		var val = setting[2]
		var turns = int(setting[3])
		SkillHelper.set_skill_variable(20000, effectId, targetId, val, turns)
	return



func current_war_vstate() -> War_Vstate:
	var wvs = war_vstates()
	if wvs.empty():
		return null
	if current < 0:
		current = 0
	if current >= wvs.size():
		current = 0
	return wvs[current]



func switch_war_vstate() -> bool:
	var allDone = false
	var prev = current
	current = current + 1
	var wvs = war_vstates()
	if current >= wvs.size():
		current = 0
		allDone = true
	
	var msg = "[WAR] 切换行动方：(#{0}){1} -> (#{2}){3}, {4}".format([
		prev, wvs[prev].get_leader_name(), 
		current, wvs[current].get_leader_name(), 
		"ALL DONE" if allDone else "CONTINUE"
	])
	DataManager.game_trace(msg)
	return allDone


func next_date() -> void :
	date += 1
	current = 0
	
	var city = target_city()
	for pos in city.get_all_door_position():
		var hp = city.get_door_hp(pos)
		var wa = DataManager.get_war_actor_by_position(pos)
		if wa == null or wa.disabled:
			continue
		hp += wa.actor().get_politics() / 3
		city.set_door_hp(pos, hp)
	
	
	for wv in war_vstates():
		wv.embattled = 0
		wv.prepare_war_actors()
	
	SkillHelper.decrease_skill_cd(20000)
	SkillHelper.decrease_skill_variable(20000)
	var map = SceneManager.current_scene().get_node_or_null("war_map")
	if map != null:
		map.next_date()
	return


func date_finished() -> void :
	DataManager.record_war_log("==== Day#{0} 结束 ====".format([date]))
	DataManager.clear_common_variable(["战争.DAILY"])
	
	for wa in get_war_actors(false):
		var recover = wa.actor().get_equip_feature_total("每日回体")
		if wa.get_buff_label_turn(["愈合"]) > 0:
			recover += 5
		if recover > 0:
			recover = wa.actor().recover_hp(recover)
		if recover > 0:
			var msg = "- <y{0}>体力回复<r{1}> -> {2}".format([
				wa.get_name(), recover, wa.actor().get_hp(), 
			])
			DataManager.record_war_log(msg)
	
	for wv in war_vstates():
		
		if wv.lost() or not wv.ready():
			continue
		wv.daily_cost_rice()
	
	
	
	var bf = DataManager.get_current_battle_fight()
	if bf.status == 0:
		bf.status = 2
	return

func cleanup() -> void :
	return

func done() -> void :
	status = 3
	result = 1
	if target_city().get_vstate_id() != defenderWV.vstateId:
		result = 2
	SkillHelper.clear_ban_actor_skill(20000)
	SkillHelper.clear_scene_actor_skill(20000)
	SkillHelper.update_all_skill_buff("WAR_DONE")
	return

func battle_start() -> void :
	status = 2
	return

func battle_over() -> void :
	status = 1
	return



func get_war_direction(vstateId: int) -> int:
	var key = str(vstateId)
	if not key in warDirections:
		return 0
	return int(warDirections[key])

func unset_env(key: String) -> void :
	env.unset_env(key)
	return

func set_env(key: String, val) -> void :
	env.set_env(key, val)
	return

func get_env_int(key: String, defVal: int = - 1) -> int:
	return env.get_int(key, defVal)

func get_env_int_array(key: String) -> Array:
	return env.get_int_array(key)

func get_env_array(key: String) -> Array:
	return env.get_array(key)

func get_env_dict(key: String) -> Dictionary:
	return env.get_dict(key)

func auto_play_mode() -> bool:
	var current = current_war_vstate()
	if current == null:
		return false
	for wv in war_vstates():
		if not wv.ready():
			continue
		if wv.get_main_controlNo() >= 0:
			if wv.is_reinforcement() and current.id != wv.id:
				continue
			return false
	return true


func record_battle_result(bf: BattleFight) -> void :
	if bf == null:
		return
	var loser = bf.get_loser()
	if loser == null:
		return
	var winnerId = bf.get_attacker_id()
	if winnerId == loser.actorId:
		winnerId = bf.get_defender_id()
	
	var victoryHistory = get_env_array("击败部队")
	victoryHistory.append([winnerId, loser.actorId, date])
	set_env("击败部队", victoryHistory)
	if not loser.disabled:
		return
	
	var defeatHistory = get_env_array("击败武将")
	defeatHistory.append([winnerId, loser.actorId, date])
	set_env("击败武将", defeatHistory)
	
	for wa in get_war_actors(false, true):
		if wa.actorId == loser.actorId:
			continue
		var killExp = wa.actor().get_equip_feature_total("菜市口经验")
		if killExp > 0:
			wa.actor().add_exp(killExp)
			var msg = "轻攻伐者，可亡也\n（观敌之败，经验 +{0}"
			var mood = 2
			if wa.vstateId == loser.vstateId:
				msg = "兵者凶器也，不可不审用\n（哀己之殇，经验 +{0}"
				mood = 3
			msg = msg.format([killExp])
			wa.attach_free_dialog(msg, mood)
	return


func update_war_process() -> void :
	var defeatHistory = get_env_array("击败武将")
	var defeatStreak = {}
	for row in defeatHistory:
		var won = int(row[0])
		var lost = int(row[1])
		if not won in defeatStreak:
			defeatStreak[won] = []
		defeatStreak[won].append(lost)
	var tvHistory = get_env_dict("连杀汇报")
	for won in defeatStreak:
		var streak = defeatStreak[won].size()
		if not streak in [5, 10]:
			continue
		if str(won) in tvHistory and tvHistory[str(won)] >= streak:
			continue
		var reporter = get_war_actor(won)
		if reporter == null or reporter.disabled:
			continue
		tvHistory[str(won)] = streak
		set_env("连杀汇报", tvHistory)
		KILL_STREAK_MESSAGES.shuffle()
		var msg = KILL_STREAK_MESSAGES[0]
		if streak == 5:
			msg += "\n（{0}已连败五将，势不可当".format([
				reporter.get_name(), 
			])
		elif streak == 10:
			msg += "\n（{0}已连败十将，闻者色变".format([
				reporter.get_name(), 
			])
		reporter.attach_free_dialog(msg, 0)
		break
	check_kill_streak_equipments()
	return


func check_kill_streak_equipments() -> void :
	var killCheckEquipments = {}
	for setting in DataManager.conditionalEquipments:
		var checkings = []
		for condition in setting[2]:
			if not "killStreak" in condition:
				continue
			var streak = Global.intval(condition["killStreak"])
			if streak <= 0:
				continue
			var actorId = Global.intval(condition["actorId"])
			checkings.append([streak, actorId])
		if checkings.empty():
			continue
		var key = "{0}|{1}".format([setting[0], setting[1]])
		killCheckEquipments[key] = checkings
	if killCheckEquipments.empty():
		return
	var defeatHistory = get_env_array("击败武将")
	var defeatStreak = {}
	for row in defeatHistory:
		var won = int(row[0])
		var lost = int(row[1])
		if not won in defeatStreak:
			defeatStreak[won] = []
		defeatStreak[won].append(lost)
	for key in killCheckEquipments:
		var pieces = key.split("|")
		var equipId = int(pieces[0])
		var equipType = pieces[1]
		for checking in killCheckEquipments[key]:
			var streakLimit = checking[0]
			var actorId = checking[1]
			if not actorId in defeatStreak:
				continue
			if defeatStreak[actorId].size() < streakLimit:
				continue
			
			var updated = []
			for setting in DataManager.conditionalEquipments:
				if setting[0] == equipId and setting[1] == equipType:
					continue
				updated.append(setting)
			DataManager.conditionalEquipments = updated
			
			var wa = DataManager.get_war_actor(actorId)
			if wa == null or wa.disabled:
				return
			var unlocked = clEquip.equip(equipId, equipType)
			if unlocked.remaining() == 0:
				return
			var current = wa.actor().get_equip(unlocked.type)
			if current.id == unlocked.id:
				
				return
			
			var vs = wa.vstate()
			vs.add_stored_equipment(current)
			
			wa.actor().set_equip(unlocked)
			unlocked.dec_count()
			
			var msg = unlocked.get_attr_str("解锁信息")
			msg += "\n（{0}解锁「{1}」".format([wa.get_name(), unlocked.name()])
			msg += "\n（{0}已置入装备库".format([current.name()])
			wa.attach_free_dialog(msg, 0)
			return
	return


func mercy_release(leader: War_Actor, loser: War_Actor) -> void :
	var loserActor = loser.actor()
	var leaderActor = leader.actor()
	var winnerWV = leader.war_vstate()
	var loserWV = leader.get_enemy_war_vstate()
	loserActor.set_status_officed()
	loserActor.set_hp(30)
	loserActor.set_soldiers(0)
	clCity.move_out(loserActor.actorId)
	winnerWV.remove_actor(loserActor.actorId)
	loserWV.add_following_actor(loserActor.actorId)
	var moral = leaderActor.get_moral()
	var msg = "春秋以降，何来义战？\n放归{0}，勿复相抗".format([
		DataManager.get_actor_honored_title(loser.actorId, leader.actorId)
	])
	leader.attach_free_dialog(msg)
	msg = "{0}已被释放".format([loser.get_name()])
	
	var flagKey = "春秋士氏注"
	if get_env_int(flagKey) <= 0:
		leaderActor.set_moral(moral + 1)
		set_env(flagKey, 1)
		if leaderActor.get_moral() > moral:
			msg += "\n{0}德 +1，现为 {1}".format([
				leader.get_name(), leader.actor().get_moral(), 
			])
	leader.attach_free_dialog(msg, 2, 20000, - 2)
	return


func check_war_vstates_status() -> bool:
	for wv in war_vstates():
		
		wv.check_lose()
		
		if wv.requires_lost_settlement():
			return true
	
	return defenderWV.lost() or attackerWV.lost()






const EXTRA_ROUND_FLAG_KEY = "额外回合进行"
const EXTRA_ROUND_ACTORS_KEY = "额外回合武将"


func add_actor_to_extra_round(actorId: int) -> bool:
	var wa = get_war_actor(actorId)
	if wa == null or wa.disabled:
		return false
	var extraActorIds = get_env_int_array(EXTRA_ROUND_ACTORS_KEY)
	extraActorIds.erase(actorId)
	extraActorIds.append(actorId)
	for srb in SkillRangeBuff.find_for_war_vstate("随同进入额外回合", wa.wvId):
		if srb.effectTagVal <= 0 or srb.actorId in extraActorIds:
			continue
		var following = get_war_actor(srb.actorId)
		if following == null or following.disabled:
			continue
		extraActorIds.erase(srb.actorId)
		extraActorIds.append(srb.actorId)
		var msg = "突出奇兵，岂可无我！\n（{0}跟随进入额外回合".format([following.get_name()])
		following.attach_free_dialog(msg, 0, 20000)
	set_env(EXTRA_ROUND_ACTORS_KEY, extraActorIds)
	return true


func get_extra_round_actors() -> PoolIntArray:
	return PoolIntArray(get_env_int_array(EXTRA_ROUND_ACTORS_KEY))


func clear_extra_round() -> void :
	unset_env(EXTRA_ROUND_FLAG_KEY)
	unset_env(EXTRA_ROUND_ACTORS_KEY)
	DataManager.war_control_sort.clear()
	DataManager.war_control_sort_no = 0
	return


func start_extra_round() -> bool:
	var wv = current_war_vstate()
	if wv == null:
		return false

	
	var checked = []
	for actorId in get_extra_round_actors():
		var wa = wv.get_war_actor(actorId)
		if wa == null or wa.disabled:
			continue
		checked.append(wa)
	if checked.empty():
		return false

	DataManager.war_control_sort.clear()
	DataManager.war_control_sort_no = 0
	DataManager.war_control_sort.append(wv.get_main_controlNo())
	DataManager.player_choose_actor = checked[0].actorId
	for wa in checked:
		SkillHelper.decrease_actor_skill_cd(20000, wa.actorId)
		SkillHelper.decrease_actor_skill_variable(20000, wa.actorId)
		wa.refresh_poker_random(true)
		wa.recharge_action_point()
	set_env(EXTRA_ROUND_FLAG_KEY, wv.id)
	return true


func is_extra_round() -> bool:
	var wv = current_war_vstate()
	if get_env_int(EXTRA_ROUND_FLAG_KEY) != wv.id:
		return false
	if get_extra_round_actors().empty():
		return false
	return true


func is_extra_round_over() -> bool:
	var wv = current_war_vstate()
	if wv == null:
		return true
	for actorId in get_extra_round_actors():
		var wa = wv.get_war_actor(actorId)
		if wa == null or wa.disabled:
			continue
		return false
	return true


func get_extra_round_desc() -> String:
	var desc = ""
	if not is_extra_round():
		return desc
	var extraRoundActorIds = get_extra_round_actors()
	var first = ActorHelper.actor(extraRoundActorIds[0])
	desc = first.get_name()
	if extraRoundActorIds.size() > 1:
		if extraRoundActorIds.size() == 2:
			var second = ActorHelper.actor(extraRoundActorIds[1])
			desc += "、" + second.get_name()
		else:
			desc += "等{0}人".format([extraRoundActorIds.size()])
	return desc




