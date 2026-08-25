# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/objects/clBattleFight.gd
# 说明：战斗结算对象（核心战斗逻辑）。计算白兵战中的伤害、回合、胜负判定。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Resource

class_name BattleFight

# 动态加载的战争攻击接口脚本（mod 可覆盖）
var iwa = Global.load_script(DataManager.mod_path + "sgz_script/war/IWar_Attack.gd")

# 战斗结果枚举：未败 / 失去斗志 / 阵亡 / 撤退 / 投降
enum ResultEnum{
	
	NotLose, 
	
	NoMind, 
	
	ActorDead, 
	
	ActorRetreat, 
	
	ActorSurrend, 
}


# 进攻方 ID / 防守方 ID
var fromId: int = - 1

var targetId: int = - 1

# 进攻方地形 / 当前地形
var fromTerrian: String = ""

var terrian: String = ""

# 战斗发生位置（地图坐标）
var locationX: int = - 1

var locationY: int = - 1

# 攻击者 / 防御者 / 胜者 / 败者
var attackerId: int = - 1

var defenderId: int = - 1

var winnerId: int = - 1

var loserId: int = - 1

# 败因
var lostType: int = ResultEnum.NotLose

# 撤退损失：米 / 士兵 / 体力
var lostRice: int = 0

var retreatLostSoldier: int = 0

var retreatLostHP: int = 0

# 双方初始兵力
var attackerSoldiers: int = 0

var defenderSoldiers: int = 0

# 双方剩余兵力
var attackerRemaining: int = 9999

var defenderRemaining: int = 9999

# 行动点
var ap: int = 0

# 战斗状态：0=未开始 1=进行中
var status: int = 0

var battle_log: Array = []

# 双方兵种类型 / 状态
var attacker_unit_types = []

var defender_unit_types = []

var attacker_state = {}

var defender_state = {}

# 阵型（-1 表示未设置）
var presetAttackerFormation: int = - 1
var attacker_formation: int = - 1

var presetDefenderFormation: int = - 1
var defender_formation: int = - 1

var source: String = ""

# 战斗临时环境变量
var env: Dictionary = {}

func _init(_fromId: int):
	fromId = _fromId
	return

func set_target(_targetId: int):
	targetId = _targetId
	get_terrian()
	get_position()
	var map = SceneManager.current_scene().war_map
	var blockCN = map.get_blockCN_by_position(get_attacker().position)
	fromTerrian = map.get_blockEN_by_CN(blockCN)
	return


func get_save_data() -> Dictionary:
	var ret = {}
	ret["fromId"] = fromId
	ret["targetId"] = targetId
	ret["fromTerrian"] = fromTerrian
	ret["terrian"] = terrian
	ret["locationX"] = locationX
	ret["locationY"] = locationY
	ret["attackerId"] = attackerId
	ret["defenderId"] = defenderId
	ret["winnerId"] = winnerId
	ret["loserId"] = loserId
	ret["lostType"] = lostType
	ret["lostRice"] = lostRice
	ret["retreatLostSoldier"] = retreatLostSoldier
	ret["retreatLostHP"] = retreatLostHP
	ret["attackerSoldiers"] = attackerSoldiers
	ret["defenderSoldiers"] = defenderSoldiers
	ret["attackerRemaining"] = attackerRemaining
	ret["defenderRemaining"] = defenderRemaining
	ret["ap"] = ap
	ret["status"] = status
	ret["battle_log"] = battle_log
	ret["attacker_unit_types"] = attacker_unit_types
	ret["defender_unit_types"] = defender_unit_types
	ret["attacker_state"] = attacker_state
	ret["defender_state"] = defender_state
	ret["presetAttackerFormation"] = presetAttackerFormation
	ret["attacker_formation"] = attacker_formation
	ret["presetDefenderFormation"] = presetDefenderFormation
	ret["defender_formation"] = defender_formation
	ret["source"] = source
	ret["env"] = env
	return ret


func load_from_save_data(dic: Dictionary) -> void :
	if "fromId" in dic:
		fromId = int(dic["fromId"])
	if "targetId" in dic:
		targetId = int(dic["targetId"])
	if "fromTerrian" in dic:
		fromTerrian = str(dic["fromTerrian"])
	if "terrian" in dic:
		terrian = str(dic["terrian"])
	if "locationX" in dic:
		locationX = int(dic["locationX"])
	if "locationY" in dic:
		locationY = int(dic["locationY"])
	if "attackerId" in dic:
		attackerId = int(dic["attackerId"])
	if "defenderId" in dic:
		defenderId = int(dic["defenderId"])
	if "winnerId" in dic:
		winnerId = int(dic["winnerId"])
	if "defenderId" in dic:
		defenderId = int(dic["defenderId"])
	if "loserId" in dic:
		loserId = int(dic["loserId"])
	if "lostType" in dic:
		lostType = int(dic["lostType"])
	if "lostRice" in dic:
		lostRice = int(dic["lostRice"])
	if "retreatLostSoldier" in dic:
		retreatLostSoldier = int(dic["retreatLostSoldier"])
	if "retreatLostHP" in dic:
		retreatLostHP = int(dic["retreatLostHP"])
	if "attackerSoldiers" in dic:
		attackerSoldiers = int(dic["attackerSoldiers"])
	if "defenderSoldiers" in dic:
		defenderSoldiers = int(dic["defenderSoldiers"])
	if "attackerRemaining" in dic:
		attackerRemaining = int(dic["attackerRemaining"])
	if "defenderRemaining" in dic:
		defenderRemaining = int(dic["defenderRemaining"])
	if "ap" in dic:
		ap = int(dic["ap"])
	if "status" in dic:
		status = int(dic["status"])
	if "battle_log" in dic:
		battle_log = Array(dic["battle_log"])
	if "attacker_unit_types" in dic:
		attacker_unit_types = Array(dic["attacker_unit_types"])
	if "defender_unit_types" in dic:
		defender_unit_types = Array(dic["defender_unit_types"])
	if "attacker_state" in dic:
		attacker_state = Dictionary(dic["attacker_state"])
	if "defender_state" in dic:
		defender_state = Dictionary(dic["defender_state"])
	if "attacker_formation" in dic:
		attacker_formation = int(dic["attacker_formation"])
	if "presetAttackerFormation" in dic:
		presetAttackerFormation = int(dic["presetAttackerFormation"])
	if "defender_formation" in dic:
		defender_formation = int(dic["defender_formation"])
	if "presetDefenderFormation" in dic:
		presetDefenderFormation = int(dic["presetDefenderFormation"])
	if "source" in dic:
		source = Global.strval(dic["source"])
	env = {}
	if "env" in dic:
		env = Global.dicval(dic["env"])
	return


func rebuild_from_env() -> void :
	
	if DataManager.battle_actors.size() == 2:
		fromId = DataManager.battle_actors[0]
		targetId = DataManager.battle_actors[1]
	var battleActors = DataManager.get_env_int_array("白兵.武将")
	if battleActors.size() == 2:
		fromId = battleActors[0]
		targetId = battleActors[1]
	var _terrian = DataManager.get_env_str("地形EN")
	if _terrian in StaticManager.BLOCKS_EN_CN:
		terrian = _terrian
	var location = DataManager.get_env_dict("白兵.战斗坐标")
	if location.has("x") and location.has("y"):
		locationX = int(location["x"])
		locationY = int(location["y"])
	var _lostType = DataManager.get_env_int("白兵.结束原因")
	if _lostType > 0:
		lostType = _lostType
	var _loserId = DataManager.get_env_int("白兵.失败武将")
	if _loserId > 0:
		_loserId = _loserId
	var _lostRice = DataManager.get_env_int("白兵.撤退损米")
	if _lostRice > 0:
		lostRice = _lostRice
	var _retreatLostSoldier = DataManager.get_env_int("白兵.撤退损兵")
	if _retreatLostSoldier > 0:
		retreatLostSoldier = _retreatLostSoldier
	var _ap = DataManager.get_env_int("战争.白兵机动力")
	if _ap > 0:
		ap = _ap
	return


func get_attacker_id() -> int:
	if attackerId >= 0:
		return attackerId
	return fromId


func get_defender_id() -> int:
	if defenderId >= 0:
		return defenderId
	return targetId


func get_attacker() -> War_Actor:
	return DataManager.get_war_actor(get_attacker_id())


func get_defender() -> War_Actor:
	return DataManager.get_war_actor(get_defender_id())



func cost_ap() -> bool:
	var wa = DataManager.get_war_actor(fromId)
	if wa == null:
		return false
	var cost = iwa.get_attack_ap(fromId, targetId)
	set_env("机动力扣减", cost)
	SkillHelper.auto_trigger_skill(fromId, 20035)
	cost = get_env_int("机动力扣减")
	
	cost = min(wa.action_point, cost)
	wa.action_point -= cost
	ap = cost
	return true


func get_from_terrian() -> String:
	if fromTerrian == "":
		fromTerrian = "land"
	return fromTerrian


func get_terrian() -> String:
	if terrian != "":
		return terrian
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return ""
	var map = SceneManager.current_scene().war_map
	var blockCN = map.get_blockCN_by_position(wa.position)
	terrian = map.get_blockEN_by_CN(blockCN)
	if not terrian in StaticManager.BLOCKS_EN_CN:
		terrian = "land"
	elif terrian in ["rice", "hospital", "equip"]:
		terrian = "land"
	return terrian

func get_terrian_cn() -> String:
	return StaticManager.BLOCKS_EN_CN[get_terrian()]


func get_position() -> Vector2:
	if locationX < 0 or locationY < 0:
		var wa = DataManager.get_war_actor(targetId)
		if wa == null:
			return Vector2( - 1, - 1)
		locationX = wa.position.x
		locationY = wa.position.y
	return Vector2(locationX, locationY)


func get_from() -> War_Actor:
	return DataManager.get_war_actor(fromId)


func get_target() -> War_Actor:
	return DataManager.get_war_actor(targetId)

func check_battle_should_over() -> bool:
	
	if loserId >= 0 and lostType == ResultEnum.NoMind:
		return true
	var ret = _check_battle_should_over()
	if ret:
		var attacker = get_attacker()
		var defender = get_defender()
		attackerRemaining = get_battle_sodiers(attacker.actorId, true, false)
		attacker.actor().set_soldiers(attackerRemaining)
		defenderRemaining = get_battle_sodiers(defender.actorId, true, false)
		defender.actor().set_soldiers(defenderRemaining)
		status = 1
	return ret

# 检查战斗是否结束：
# 主将单位阵亡/被俘/投降/HP归零、或主将单位越出战场边界（撤退）均判负；
# 双方均无主将单位时判「失去斗志」。
func _check_battle_should_over() -> bool:
	var scene_battle = SceneManager.current_scene()
	
	scene_battle.unit_updated = false
	set_loser( - 1, ResultEnum.NotLose)

	var heroUnits = []
	for wa in [get_attacker(), get_defender()]:
		if wa == null:
			continue
		var bu = wa.battle_actor_unit()
		heroUnits.append(bu)
		if bu == null:
			
			
			if get_battle_sodiers(wa.actorId) > 0:
				continue
			set_loser(wa.actorId, ResultEnum.ActorRetreat)
			retreat_cost_rice(wa)
			return true
		var actor = wa.actor()
		if bu.get_hp() <= 0 or actor.is_status_captured() or actor.is_status_dead():
			
			set_loser(wa.actorId, ResultEnum.ActorDead)
			return true
		if bu.unit_position.x < 0 or bu.unit_position.x >= 16:
			
			set_loser(wa.actorId, ResultEnum.ActorRetreat)
			retreat_cost_rice(wa)
			return true
		if bu.is_surrend:
			set_loser(wa.actorId, ResultEnum.ActorSurrend)
			return true
	if heroUnits.size() == 2\
	and heroUnits[0] == null\
	and heroUnits[1] == null:
		
		set_loser( - 1, ResultEnum.NoMind)
		return true
	return false


# 撤退损失米粮：按当前米粮的 10% 扣除（夹在 10~500 之间）
func retreat_cost_rice(wa: War_Actor) -> void :
	if DataManager.diffculities >= 3:
		if get_terrian_cn() in StaticManager.CITY_BLOCKS_CN and wa.actorId == get_attacker_id():
			return
	var wv = wa.war_vstate()
	if wv == null:
		return
	var current = wv.rice
	var cost = max(10, min(500, int(current / 10)))
	wv.rice = max(0, current - cost)
	lostRice = current - wv.rice
	return


# 撤退损失士兵：按败方各兵种的撤退损失率，对所有存活单位扣除对应兵力
func retreat_cost_soldiers() -> void :
	var loser = get_loser()
	if loser == null:
		return
	if DataManager.diffculities >= 3:
		if get_terrian_cn() in StaticManager.CITY_BLOCKS_CN and loser.actorId == get_attacker_id():
			return
	if retreatLostSoldier > 0:
		return
	var current = loser.get_soldiers()
	var rate = loser.get_retreat_lost_rate()
	if rate <= 0:
		return
	retreatLostSoldier = 0
	var total = 0
	for bu in DataManager.battle_units:
		if bu == null or bu.disabled:
			continue
		if bu.leaderId != loser.actorId or bu.get_unit_type() in ["城门", "将"]:
			continue
		var hp = bu.get_hp()
		if hp <= 0.01:
			continue
		var lost = int(hp * rate / 100)
		total += lost
		bu.set_hp(hp - lost, true)
	retreatLostSoldier = total
	return


func retreat_lost_hp() -> int:
	retreatLostHP = 0
	var loser = get_loser()
	if loser == null:
		return 0
	if DataManager.diffculities >= 3:
		if get_terrian_cn() in StaticManager.CITY_BLOCKS_CN and loser.actorId == get_attacker_id():
			return 0
	var srb = SkillRangeBuff.max_for_actor("撤退不减体力", loser.actorId)
	if srb != null and srb.effectTagVal > 0:
		return 0
	
	if not Global.get_rate_result(68):
		return 0
	
	var cost = Global.get_random(4, 14)
	var actor = ActorHelper.actor(loser.actorId)
	var current = int(ceil(actor.get_hp()))
	actor.set_hp(current - cost)
	if actor.get_hp() <= 0:
		lostType = ResultEnum.ActorDead
	retreatLostHP = cost
	return cost


func get_loser() -> War_Actor:
	return DataManager.get_war_actor(loserId)


func get_winner() -> War_Actor:
	var loser = get_loser()
	if loser == null:
		return null
	var winnerId = get_attacker_id()
	if loser.actorId == get_attacker_id():
		winnerId = get_defender_id()
	return DataManager.get_war_actor(winnerId)


func pending_start() -> bool:
	if status != 0:
		return false
	for wa in [get_from(), get_target(), get_attacker(), get_defender()]:
		if wa == null:
			return false
	return true

func ready_to_start() -> void :
	var attacker = get_attacker()
	
	attacker.reset_attack_distance()
	var defender = get_defender()
	set_loser( - 1, ResultEnum.NotLose)
	attackerSoldiers = attacker.get_soldiers()
	defenderSoldiers = defender.get_soldiers()
	
	
	for wa in [attacker, defender]:
		var recover = wa.actor().get_equip_feature_total("白刃战回体")
		if recover > 0:
			wa.actor().recover_hp(recover)

	
	DataManager.clear_actor_disabled_equip_types(30000)

	DataManager.battle_actors = [attacker.actorId, defender.actorId]
	DataManager.clear_common_variable(["白兵"])

	SkillHelper.clear_ban_actor_skill(30000);
	SkillHelper.clear_scene_actor_skill(30000);
	SkillHelper.clear_skill_cd(30000);
	SkillHelper.clear_skill_variable(30000);
	SkillHelper.update_all_skill_buff("BATTLE_INIT")

	DataManager.set_env("白兵.行动单位", - 1)
	DataManager.set_env("白兵.行动方", 0)
	DataManager.set_env("白兵.呼叫暂停", [])
	DataManager.battle_first_sort.clear();
	set_turns(1)
	DataManager.battle_type_no = 0;
	DataManager.battle_type_sort = StaticManager.get_battle_action_seq_setting()

	DataManager.battle_units = [];

	
	attacker.clear_buff_by_where("小战场")
	defender.clear_buff_by_where("小战场")

	battle_log.clear()
	battle_log.append("==== <y{0}> VS. <y{1}> 战斗开始 ====".format([
		attacker.get_name(), 
		defender.get_name(), 
	]))

	if get_terrian() != "walldoor":
		return
	
	var wf = DataManager.get_current_war_fight()
	var positon = get_position()
	var doorHP = wf.target_city().get_door_hp(positon)
	if doorHP <= 0:
		battle_log.append("- 城门血量为 0")
		return
	
	for y in [5, 4, 6]:
		var unit_info = Battle_Unit.new(defender.actorId)
		unit_info.unitId = DataManager.battle_units.size()
		
		unit_info.disabled = false
		DataManager.battle_units.append(unit_info)
		unit_info.formation_init("城门")
		unit_info.direction = 1
		unit_info._private_hp = doorHP
		unit_info.unit_position = Vector2(9, y)
	battle_log.append("- 已附加城门单位，血量为 {0}".format([doorHP]))

	attacker_unit_types = ["将", "骑", "弓", "步"]
	defender_unit_types = ["将", "骑", "弓", "步"]
	for ut in attacker_unit_types:
		attacker_state[ut] = "前进"
	for ut in defender_unit_types:
		defender_state[ut] = "前进"
	return

func war_report() -> void :
	
	battle_log.clear()
	if status > 1 or status == 0:
		return
	if get_attacker() == null or get_defender() == null:
		status = 2
		return
	var msg = "- <y{0}>向<y{1}>发起<r白刃战>，消耗机动<r{2}>".format([
		ActorHelper.actor(fromId).get_name(), 
		ActorHelper.actor(targetId).get_name(), 
		ap, 
	])
	if get_attacker_id() != fromId:
		msg += "\n  - 实际攻方为：<y{0}>".format([
			get_attacker().get_name(), 
		])
	if get_defender_id() != targetId:
		msg += "\n  - 实际守方为：<y{0}>".format([
			get_defender().get_name(), 
		])
	if attackerRemaining <= attackerSoldiers:
		msg += "\n  - <y{0}>战损兵力<r{1}> -> {2}".format([
			get_attacker().get_name(), attackerSoldiers - attackerRemaining, 
			attackerRemaining, 
		])
	if defenderRemaining <= defenderSoldiers:
		msg += "\n  - <y{0}>战损兵力<r{1}> -> {2}".format([
			get_defender().get_name(), defenderSoldiers - defenderRemaining, 
			defenderRemaining
		])
	var loss = {"兵力": retreatLostSoldier, "粮草": lostRice, "体力": retreatLostHP}
	var losses = []
	for k in loss:
		if loss[k] > 0:
			losses.append("{0}<r{1}>".format([k, loss[k]]))
	if losses.size() > 0:
		msg += "\n  - <y{0}>撤退损失{1}".format([
			get_loser().get_name(), "、".join(losses)
		])
	if loserId >= 0:
		var action = "战败"
		match lostType:
			ResultEnum.ActorDead:
				action = "力竭战败"
			ResultEnum.ActorRetreat:
				action = "撤出战斗"
			ResultEnum.ActorSurrend:
				action = "战败投降"
		msg += "\n  - <y{0}>{1}".format([
			ActorHelper.actor(loserId).get_name(), action
		])
	for extra in get_env_array("附加信息"):
		msg += "\n" + extra
	DataManager.record_war_log(msg)
	status = 2
	return

func get_attacker_unit_types() -> PoolStringArray:
	if attacker_unit_types.empty():
		attacker_unit_types = ["将", "骑", "弓", "步"]
		if DataManager.battle_unit_type_hp(get_attacker_id(), "象") > 0:
			attacker_unit_types = ["将", "象", "弓", "步"]
	return PoolStringArray(attacker_unit_types.duplicate(true))

func get_defender_unit_types() -> PoolStringArray:
	if defender_unit_types.empty():
		defender_unit_types = ["将", "骑", "弓", "步"]
		if DataManager.battle_unit_type_hp(get_defender_id(), "象") > 0:
			defender_unit_types = ["将", "象", "弓", "步"]
	return PoolStringArray(defender_unit_types.duplicate(true))

func update_unit_types(actorId: int) -> void :
	var defaults = ["骑", "象", "弓", "步"]
	var updated = ["将"]
	for k in defaults:
		if DataManager.battle_unit_type_hp(actorId, k) > 0:
			updated.append(k)
	if actorId == get_attacker_id():
		attacker_unit_types = updated
	elif actorId == get_defender_id():
		defender_unit_types = updated
	return

func get_attacker_state() -> Dictionary:
	if attacker_state.empty():
		
		var unit_types = DataManager.get_env_array("白兵.攻方兵种")
		var states = DataManager.get_env_array("白兵.攻方状态")
		for i in unit_types.size():
			if i >= states.size():
				break
			attacker_state[unit_types[i]] = states[i]
	return attacker_state.duplicate(true)

func get_defender_state() -> Dictionary:
	if defender_state.empty():
		
		var unit_types = DataManager.get_env_array("白兵.守方兵种")
		var states = DataManager.get_env_array("白兵.守方状态")
		for i in unit_types.size():
			if i >= states.size():
				break
			defender_state[unit_types[i]] = states[i]
	return defender_state.duplicate(true)


func get_units_state(actorId: int, type: String) -> String:
	var setting = {}
	if actorId == get_attacker_id():
		setting = get_attacker_state()
	elif actorId == get_defender_id():
		setting = get_defender_state()
	if setting.has(type):
		return setting[type]
	return "前进"


func get_units_states(actorId: int) -> Dictionary:
	if actorId == get_defender_id():
		return get_defender_state()
	elif actorId == get_attacker_id():
		return get_attacker_state()
	return {}


func get_unit_state(bu: Battle_Unit) -> String:
	var state_array = [];
	var type_index = - 1;
	var states = {}
	if bu.get_side() == Vector2.LEFT:
		states = get_attacker_state()
	else:
		states = get_defender_state()
	var ut = bu.get_unit_type()
	if states.has(ut):
		return states[ut]
	return "前进"

func set_unit_state(actorId: int, setting: Dictionary) -> void :
	var current = {}
	if actorId == get_attacker_id():
		current = get_attacker_state()
	elif actorId == get_defender_id():
		current = get_defender_state()
	for k in setting:
		current[k] = setting[k]
	if actorId == get_attacker_id():
		set_attacker_state(current)
	elif actorId == get_defender_id():
		set_defender_state(current)
	return

func set_attacker_state(setting: Dictionary) -> void :
	if not _dict_diff(attacker_state, setting):
		return
	attacker_state = setting.duplicate(true)
	var msgs = ["- <y{0}>改变策略".format([get_attacker().get_name()])]
	var states = []
	for ut in get_attacker_unit_types():
		states.append("<r{0}>:{1}".format([ut, get_units_state(get_attacker_id(), ut)]))
	var msg = "  - " + "，".join(states)
	msgs.append(msg)
	msgs.invert()
	battle_log.append_array(msgs)
	return

func set_defender_state(setting: Dictionary) -> void :
	if not _dict_diff(defender_state, setting):
		return
	defender_state = setting.duplicate(true)
	var msgs = ["- <y{0}>改变策略".format([get_defender().get_name()])]
	var states = []
	for ut in get_defender_unit_types():
		states.append("<r{0}>:{1}".format([ut, get_units_state(get_defender_id(), ut)]))
	var msg = "  - " + "，".join(states)
	msgs.append(msg)
	msgs.invert()
	battle_log.append_array(msgs)
	return


func is_terrian_city() -> bool:
	return get_terrian() in StaticManager.CITY_BLOCKS_EN



func init_formation() -> bool:
	if attacker_formation < 0:
		attacker_formation = _init_formation_for(get_attacker_id())
		if attacker_formation < 0:
			return true
		var states = get_attacker_state()
		for ut in get_attacker_unit_types():
			states[ut] = "前进"
		states["将"] = "待机"
		set_unit_state(get_attacker_id(), states)
	if defender_formation < 0:
		defender_formation = _init_formation_for(get_defender_id())
		if defender_formation < 0:
			return true
		var states = get_defender_state()
		for ut in get_defender_unit_types():
			states[ut] = "前进"
		states["将"] = "待机"
		set_unit_state(get_defender_id(), states)
		if is_terrian_city():
			set_unit_state(get_defender_id(), {"弓": "待机"})
	return false

func _init_formation_for(targetId: int) -> int:
	var wa = DataManager.get_war_actor(targetId)
	var wv = wa.war_vstate()
	var controlNo = wv.get_main_controlNo()
	if controlNo >= 0:
		
		DataManager.set_env("当前武将", wa.actorId)
		FlowManager.force_change_controlNo(controlNo)
		FlowManager.add_flow("battle_set_formation")
		return - 1
	
	var iFormation = Global.load_script("res://resource/sgz_script/battle/IFormation.gd")
	var formation = iFormation._get_random_auto_formation(wa.actorId)
	set_formation(wa.actorId, formation)
	return formation


func set_formation(targetId: int, formation: int) -> int:
	if targetId == get_defender_id():
		defender_formation = formation
	elif targetId == get_attacker_id():
		attacker_formation = formation
	else:
		return - 1
	var iFormation = Global.load_script("res://resource/sgz_script/battle/IFormation.gd")
	iFormation.set_formation(targetId, formation)
	var msg = "- <y{0}>设定阵型：{1}".format([
		ActorHelper.actor(targetId).get_name(), formation
	])
	battle_log.append(msg)
	return formation



func decide_attacker_formation() -> bool:
	var wa = get_attacker()
	if _decide_formation_for(wa):
		return true
	return false

func decide_defender_formation() -> bool:
	var wa = get_defender()
	if _decide_formation_for(wa):
		return true
	return false

func _decide_formation_for(wa: War_Actor) -> bool:
	if get_env_int("阵型决策.{0}".format([wa.actorId])) > 0:
		return true
	var actor = wa.actor()
	var soldiersSetting = StaticManager.get_battle_soldiers_setting()
	var proname = str(soldiersSetting["属性"])
	var sorting = PoolStringArray(soldiersSetting["分配顺序"])
	var numSetting = Dictionary(soldiersSetting["设定"])

	var unitTypes = StaticManager.get_battle_troops_setting()

	
	for nums in numSetting[str(actor.get_level()) + "级"]:
		if actor._get_attr_int(proname) < int(nums["最低属性"]):
			continue
		set_env("兵种数量.{0}".format([wa.actorId]), nums)
		break
	set_env("分配顺序.{0}".format([wa.actorId]), sorting)
	
	SkillHelper.auto_trigger_skill(wa.actorId, 30003)
	
	SkillHelper.auto_trigger_skill(wa.actorId, 30033)
	
	return _merge_extra_formation_setting(wa)


func init_units() -> void :
	_init_units_for(get_attacker())
	_init_units_for(get_defender())
	return


func _init_units_for(wa: War_Actor):
	var direction = 2
	if wa.actorId == get_defender_id():
		direction = 1
	var actor = wa.actor()

	
	var nums = get_env_dict("兵种数量.{0}".format([wa.actorId]))
	var sorting = get_env_array("分配顺序.{0}".format([wa.actorId]))

	
	var soldiers = float(actor.get_soldiers())
	var troopsType = actor.get_troops_type()

	
	var actorUnit = Battle_Unit.new(wa.actorId)
	actorUnit.unitId = DataManager.battle_units.size()
	actorUnit.disabled = false
	DataManager.battle_units.append(actorUnit)
	actorUnit.formation_init("将")
	actorUnit.direction = direction
	actorUnit._private_hp = actor.get_hp()
	if troopsType == "仙" or actor.get_equip_feature_max("人遁") > 0:
		
		actorUnit.set_combat_val("仙兵", 1, "默认")

	
	var soldierUnits = []

	
	for unitType in sorting:
		if soldiers <= 0:
			
			break
		
		for i in nums[unitType]:
			if soldiers <= 0:
				break
			
			var hp = min(100, soldiers)
			soldiers -= hp
			var bu = Battle_Unit.new(wa.actorId)
			bu.unitId = DataManager.battle_units.size()
			bu.disabled = false
			DataManager.battle_units.append(bu)
			bu.formation_init(unitType)
			bu.direction = direction
			bu._private_hp = hp
			soldierUnits.append(bu)
			if get_env_int("布阵锁定兵种.{0}".format([wa.actorId])) > 0:
				bu.dic_combat["兵种锁定"] = 1

	
	var count = soldierUnits.size()
	for bu in soldierUnits:
		if soldiers <= 0 or count <= 0:
			break
		var hp = int(ceil(soldiers / count))
		soldiers -= hp
		count -= 1
		bu._private_hp += hp

	if troopsType == "仙":
		
		var x = int(wa.actor().get_moral() / 20)
		soldierUnits.shuffle()
		for i in min(x, soldierUnits.size()):
			soldierUnits[i].set_combat_val("仙兵", 1, "默认")

	var iFormation = Global.load_script("res://resource/sgz_script/battle/IFormation.gd")
	iFormation.clear_formation(wa.actorId)
	_check_for_special_units(wa.actorId)
	return


func _check_for_special_units(targetId: int) -> void :
	var transforms = _get_special_units_transforms(targetId)
	for bu in DataManager.battle_units:
		if bu == null or bu.disabled or bu.leaderId != targetId:
			continue
		if not transforms.has(bu.get_unit_type()):
			continue
		
		
		bu.Type = transforms[bu.get_unit_type()]
		bu.init_combat_info()
	
	var wa = DataManager.get_war_actor(targetId)
	if wa.actor().get_equip_feature_max("避免白刃战") > 0:
		var actorUnit = wa.battle_actor_unit()
		for i in DataManager.battle_units.size():
			var bu = DataManager.battle_units[i]
			if bu == null:
				continue
			if bu.unitId == actorUnit.unitId:
				bu.reset_type("骑(化身)")
				bu.set_hp(0, true)
				bu.disabled = true
				break
	return


func _get_special_units_transforms(targetId: int) -> Dictionary:
	
	if targetId == get_defender_id()\
	and get_terrian() in ["walldoor", "wallcity"]:
		return {
			"步": "弓", 
			"骑": "弓", 
			"象": "弓", 
		}

	
	
	var settingType = get_env_str("阵型决策.类型.{0}".format([targetId]))
	if settingType == "场合":
		return {}

	
	var changingType = ""
	var changingLevel = 0
	var actor = ActorHelper.actor(targetId)
	if not get_terrian() in ["wallcity", "walldoor"]:
		var level = actor.get_equip_feature_max("白兵全骑兵")
		if level > changingLevel:
			changingLevel = level
			changingType = "骑"
	for k in ["弓", "步"]:
		var level = actor.get_equip_feature_max("白兵全" + k + "兵")
		if level > changingLevel:
			changingLevel = level
			changingType = k

	if changingType == "":
		return {}

	return {
		"步": changingType, 
		"骑": changingType, 
		"弓": changingType, 
		"象": changingType, 
	}

func _dict_diff(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return true
	for k in a:
		if not b.has(k):
			return true
		if b[k] != a[k]:
			return true
	return false

func turns() -> int:
	return DataManager.battle_turns + 1

func set_turns(turns: int) -> void :
	DataManager.battle_turns = turns - 1
	return


func next_turn() -> void :
	DataManager.set_env("白兵.行动单位", - 1)
	DataManager.battle_type_no = 0;
	set_turns(turns() + 1)
	for wa in [get_attacker(), get_defender()]:
		SkillHelper.auto_trigger_skill(wa.actorId, 30059, "")
		wa.decrease_buff_by_where("小战场")
		wa.update_buff_attrs()
	battle_log.append("<g== 第 {0} 回合开始>".format([turns()]))
	return


func set_buff(targetId: int, buff: String, turns: int, msg: String = "") -> int:
	var wa = DataManager.get_war_actor(targetId)
	turns = wa.set_buff(buff, turns, wa.actorId)
	battle_log.append("- <y{0}>发动战术[<r{1}>]，回合数{2}".format([
		wa.get_name(), buff, turns, 
	]))
	wa.update_buff_attrs()
	return turns





func reject_solo_request(actorId: int, msg: String = "{0}拒绝单挑\n真鼠辈也！") -> bool:
	var wa = get_attacker()
	var from = get_defender()
	if actorId == get_defender_id():
		wa = get_defender()
		from = get_attacker()
	msg = msg.format([wa.get_name()])
	
	var moraleChange = change_battle_morale(wa.actorId, - 4, "拒绝单挑")
	
	change_battle_courage(wa.actorId, - 10, "拒绝单挑")
	var mood = 0
	DataManager.set_env("对话", msg)
	DataManager.set_env("对话表情", mood)
	DataManager.set_env("对话武将", from.actorId)
	DataManager.set_env("白兵.士气变化", moraleChange)
	
	SkillHelper.auto_trigger_skill(from.actorId, 30012, "")
	var reporter = DataManager.get_env_int("对话武将")
	if wa.get_controlNo() < 0:
		
		DataManager.set_env("白兵.拒绝单挑", wa.actorId)
	msg = DataManager.get_env_str("对话")
	mood = DataManager.get_env_int("对话表情")
	if msg != "":
		SceneManager.show_confirm_dialog(msg, reporter, mood)
		return true
	return false

func change_battle_courage(targetId: int, val: int, source: String) -> int:
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return 0
	var current = wa.battle_courage
	
	val = max( - current, val)
	if val == 0:
		return 0
	wa.battle_courage = current + val
	var change = "增加"
	if val < 0:
		change = "减少"
	battle_log.append("- 因{0}，<y{1}>的胆{2}{3} -> {4}".format([
		source, wa.get_name(), change, abs(val), wa.battle_courage, 
	]))
	return val

func change_battle_morale(targetId: int, val: int, source: String) -> int:
	var wa = DataManager.get_war_actor(targetId)
	if wa == null:
		return 0
	var current = wa.battle_morale
	
	wa.battle_morale_extra += val
	wa.recalculate_morale()
	var change = "增加"
	if val < 0:
		change = "减少"
	battle_log.append("- 因{0}，<y{1}>的士气{2}{3} -> {4}".format([
		source, wa.get_name(), change, abs(val), wa.battle_morale, 
	]))
	return val

func create_abatis_line(xAxis: int) -> void :
	var sceneBattle = SceneManager.current_scene()
	for y in sceneBattle.cell_rows:
		var pos = Vector2(xAxis, y)
		var existed = DataManager.get_battle_unit_by_position(pos)
		if existed != null and not existed.disabled:
			continue
		var unit = Battle_Unit.new( - 1)
		unit.unitId = DataManager.battle_units.size()
		unit.direction = 0
		unit.Type = "拒马"
		unit._private_hp = 999
		unit.disabled = false
		unit.unit_position = pos
		DataManager.battle_units.append(unit)
		unit.formation_init("拒马")
		unit.requires_update = true
	sceneBattle.update_units()
	return

func clear_abatis_line() -> void :
	for unit in DataManager.battle_units:
		if unit.Type != "拒马":
			continue
		unit.disabled = true
		unit.unit_position = Vector2( - 10, - 10)
		unit.requires_update = true
	var sceneBattle = SceneManager.current_scene()
	sceneBattle.update_units()
	return

func set_loser(id: int, reason: int) -> void :
	loserId = id
	winnerId = - 1
	if loserId == get_attacker_id():
		winnerId = get_defender_id()
	elif loserId == get_defender_id():
		winnerId = get_attacker_id()
	lostType = reason
	return


func get_battle_sodiers(actorId: int, includeDisabled: bool = false, includeTemporary: bool = true) -> float:
	var ret = 0.0
	for bu in DataManager.battle_units:
		if bu == null:
			continue
		if bu.disabled and not includeDisabled:
			
			continue
		if bu.leaderId != actorId:
			continue
		if bu.get_unit_type() in ["将", "城门"]:
			continue
		if bu.dic_other_variable.has("临时") and not includeTemporary:
			continue
		ret += bu.get_hp(includeDisabled)
	return ret


func get_door_hp() -> float:
	var ret = 0
	for bu in DataManager.battle_units:
		if bu == null:
			continue
		if bu.get_unit_type() in ["城门"]:
			ret += bu.get_hp(true)
	return ret

func battle_units(actorId: int, includeDisabled: bool = false) -> Array:
	var ret = []
	for bu in DataManager.battle_units:
		if bu == null or bu.leaderId != actorId:
			continue
		if bu.disabled and not includeDisabled:
			continue
		ret.append(bu)
	return ret

func battle_unit(unitId: int) -> Battle_Unit:
	for bu in DataManager.battle_units:
		if bu == null or bu.unitId != unitId:
			continue
		return bu
	return null


func done() -> void :
	SkillHelper.clear_scene_actor_skill(30000)
	
	var wf = DataManager.get_current_war_fight()
	if wf == null:
		return
	wf.record_battle_result(self)
	return


func skip_execution(actorId: int, skill: String) -> void :
	status = 1
	var msg = "  - 因<y{0}>【<r{1}>】效果取消".format([
		ActorHelper.actor(actorId).get_name(), skill
	])
	var extra = get_env_array("附加信息")
	extra.append(msg)
	set_env("附加信息", extra)
	return

func unset_env(key: String) -> void :
	env.erase(key)
	return

func set_env(key: String, val) -> void :
	env[key] = val
	return

func get_env_int(key: String, defVal: int = - 1) -> int:
	if not key in env:
		return defVal
	return Global.intval(env[key], defVal)

func get_env_str(key: String) -> String:
	if not key in env:
		return ""
	return Global.strval(env[key])

func get_env_array(key: String) -> Array:
	if not key in env:
		return []
	return Global.arrval(env[key])

func get_env_int_array(key: String) -> Array:
	if not key in env:
		return []
	return Global.intarrval(env[key])

func get_env_dict(key: String) -> Dictionary:
	if not key in env:
		return {}
	return Global.dicval(env[key])


func clear_pending_actions() -> void :
	DataManager.battle_first_sort.clear()
	DataManager.set_env(Battle_Instant_Action.GENERAL_KEY, [])
	DataManager.set_env("白兵.行动单位", - 1)
	return


func add_status_effect(bu: Battle_Unit, status: String) -> void :
	var statuses = get_env_array("UNIT_STATUSES")
	statuses.append([bu.unitId, status])
	set_env("UNIT_STATUSES", statuses)
	return


func next_status_effect() -> Array:
	var statuses = get_env_array("UNIT_STATUSES")
	while not statuses.empty():
		var popped = Global.arrval(statuses.pop_front())
		if popped.size() != 2:
			continue
		set_env("UNIT_STATUSES", statuses)
		var unitId = int(popped[0])
		var status = str(popped[1])
		if status == "":
			continue
		var bu = battle_unit(unitId)
		if bu == null or bu.disabled:
			continue
		return [bu, status]
	return []


func solo_disabled() -> bool:
	if get_attacker().battle_actor_unit() == null:
		return true
	if get_defender().battle_actor_unit() == null:
		return true
	return false


func mark_auto_finish_turn() -> void :
	set_env("auto_finish_turn", 1)
	return

func will_auto_finish_turn() -> bool:
	return get_env_int("auto_finish_turn") > 0



func get_extra_formation_setting(actorId: int) -> Dictionary:
	var key = "阵型.{0}".format([actorId])
	return get_env_dict(key)







func update_extra_formation_setting(actorId: int, source: String, type: String, setting: Dictionary) -> void :
	var key = "阵型.{0}".format([actorId])
	var dic = get_env_dict(key)
	if not type in dic:
		dic[type] = {}
	dic[type][source] = setting
	set_env(key, dic)
	return





func _merge_extra_formation_setting(wa: War_Actor) -> bool:
	var dic = get_extra_formation_setting(wa.actorId)
	var settings = []
	
	var type = "场合"
	if type in dic:
		for source in dic[type]:
			var setting = dic[type][source]
			setting["type"] = type
			setting["source"] = source
			settings.append(setting)
			break
	
	type = "常规"
	if settings.empty() and type in dic:
		for source in dic[type]:
			var setting = dic[type][source]
			setting["type"] = type
			setting["source"] = source
			settings.append(setting)
	
	type = "特殊"
	if type in dic:
		for source in dic[type]:
			if settings.empty():
				
				var setting = dic[type][source].duplicate(true)
				setting["type"] = type
				setting["source"] = source
				settings.append(setting)
			else:
				
				for setting in settings:
					for key in dic[type][source]:
						if key == "小战场标记ID" and key in setting:
							setting[key].append_array(dic[type][source][key])
						else:
							setting[key] = dic[type][source][key]
	if settings.empty():
		return true
	if settings.size() > 1 and \
	wa.get_controlNo() >= 0 and \
	_get_special_units_transforms(wa.actorId).empty():
		set_env("玩家阵型选择", settings)
		set_env("阵型选择玩家", wa.actorId)
		return false
	apply_extra_formation_setting(wa.actorId, settings[0])
	return true


func apply_extra_formation_setting(actorId: int, setting: Dictionary) -> void :
	var msg = Global.dic_val(setting, "信息", "")
	if msg != "":
		battle_log.append("- <y{0}>{1}".format([
			ActorHelper.actor(actorId).get_name(), msg
		]))
	var effectIds = Global.intarrval(Global.dic_val(setting, "小战场标记ID"))
	for effectId in effectIds:
		SkillHelper.set_skill_variable(30000, effectId, actorId, 1, 99999)
	var nums = Global.dic_val(setting, "兵种数量", {})
	if nums.empty():
		nums = get_env_dict("兵种数量.{0}".format([actorId]))
	var sorting = Global.dic_val(setting, "分配顺序", [])
	if sorting.empty():
		sorting = get_env_array("分配顺序.{0}".format([actorId]))
	if Global.intval(Global.dic_val(setting, "布阵锁定兵种", 0)) > 0:
		set_env("布阵锁定兵种.{0}".format([actorId]), 1)
	else:
		var transforms = Global.dic_val(setting, "兵种强转", {})
		for key in transforms:
			if nums.has(key):
				nums[transforms[key]] = nums[key]
				nums.erase(key)
			var loc = sorting.find(key)
			if loc >= 0:
				sorting[loc] = transforms[key]
	
	set_env("兵种数量.{0}".format([actorId]), nums)
	set_env("分配顺序.{0}".format([actorId]), sorting)
	var attackerFormation = Global.dic_val(setting, "攻方阵型", - 1)
	if attackerFormation >= 0:
		presetAttackerFormation = attackerFormation
	var defenderFormation = Global.dic_val(setting, "守方阵型", - 1)
	if defenderFormation >= 0:
		presetDefenderFormation = defenderFormation
	
	set_env("阵型决策.{0}".format([actorId]), 1)
	set_env("阵型决策.类型.{0}".format([actorId]), Global.dic_val(setting, "type", ""))
	set_env("阵型决策.来源.{0}".format([actorId]), Global.dic_val(setting, "source", ""))
	return


func battle_over() -> void :
	var attacker = get_attacker()
	var defender = get_defender()

	attacker.clear_buff_by_where("小战场")
	defender.clear_buff_by_where("小战场")

	
	SkillHelper.auto_trigger_skill(attacker.actorId, 30099)
	SkillHelper.auto_trigger_skill(defender.actorId, 30099)

	DataManager.battle_run = false
	
	var loser = get_loser()
	if loser != null:
		var winner = loser.get_battle_enemy_war_actor()
		DataManager.unset_env("后退位置")
		
		if not loser.actor().is_status_dead() and loser.wvId != winner.wvId:
			
			if Global.get_distance(loser.position, winner.position) == 1:
				
				var stopped = loser.get_buff("定止")
				if stopped["回合数"] > 0:
					loser.set_buff("定止", stopped["回合数"] - 1, stopped["来源武将"], "", true)
				else:
					var pos = loser.position * 2 - winner.position
					DataManager.set_env("后退位置", {"x": pos.x, "y": pos.y})

	
	attackerRemaining = int(ceil(get_battle_sodiers(attacker.actorId, true, false)))
	defenderRemaining = int(ceil(get_battle_sodiers(defender.actorId, true, false)))
	var recover = get_env_dict("战后兵力")
	if str(attacker.actorId) in recover:
		attackerRemaining = Global.intval(recover[str(attacker.actorId)])
	if str(defender.actorId) in recover:
		defenderRemaining = Global.intval(recover[str(defender.actorId)])
	attacker.actor().set_soldiers(attackerRemaining)
	defender.actor().set_soldiers(defenderRemaining)

	SkillHelper.auto_trigger_skill(attacker.actorId, 30004)
	SkillHelper.auto_trigger_skill(defender.actorId, 30004)

	
	var doorHP = get_door_hp()
	var positon = get_position()
	if positon.x >= 0 and get_terrian() == "walldoor":
		var wf = DataManager.get_current_war_fight()
		wf.target_city().set_door_hp(positon, doorHP / 3.0)

	
	DataManager.battle_units.clear()
	DataManager.battle_first_sort = []
	DataManager.battle_type_sort = []
	return


func get_possible_formations(actorId: int) -> PoolIntArray:
	
	var ret = [0, 1, 2, 3]
	var isAttacker = false
	var wa = null
	if actorId == get_attacker_id():
		isAttacker = true
		wa = get_attacker()
	elif actorId == get_defender_id():
		wa = get_defender()
	else:
		return ret

	if isAttacker and wa.get_controlNo() < 0 and get_terrian() in ["walldoor", "wall"]:
		
		ret = [0, 1]

	if not isAttacker:
		
		match get_terrian():
			"walldoor":
				return PoolIntArray([4])
			"wallcity":
				return PoolIntArray([7])

	
	var specified = - 1
	if isAttacker and presetAttackerFormation >= 0:
		specified = presetAttackerFormation
	if not isAttacker and presetDefenderFormation >= 0:
		specified = presetDefenderFormation

	
	if specified >= 10000:
		ret = []
		
		while specified > 1:
			ret.append(specified % 100)
			specified = int(specified / 100)
		return PoolIntArray(ret)
	elif specified >= 0:
		return PoolIntArray([specified])

	
	return ret
