extends Resource

const TRACE = false

const SAVED_ATTRS = [
	"fromId", "actionId", "hiddenActionId", 
	"targetId", "name", "defenderId", 
	"defenderSource", "rangeRadius", 
	"message", "cost", "costed", 
	"rate", "rate_flag", "succeeded", 
	"status", "logs", "skill", "results", 
	"work_as_skill", "goback_disabled", "skip_redo", 
	"induce_disabled", "env", 
]

class_name StratagemExecution



func trace(info: String):
	if not TRACE:
		return
	print(info)
	print_stack()
	return




var fromId: int = - 1

var actionId: int = - 1

var hiddenActionId: int = - 1

var targetId: int = - 1

var name: String = ""

var defenderId: int = - 1

var defenderSource: String = ""

var rangeRadius: int = 0

var message: String = ""

var cost: int = 0

var costed: int = - 1

var rate: int = - 1

var rate_flag: int = 0

var succeeded: int = 0

var status: int = 0

var logs: Array = []

var skill: String = ""

var results: Dictionary = {}

var work_as_skill: int = 0

var goback_disabled: int = 0

var skip_redo: int = 0

var induce_disabled: int = 0

var env: Dictionary = {}



var stratagem: StratagemInfo

var actionSource: String = ""

var message_once_keys: Array = []

var reporter_mood = 2

func _init(_fromId: int, _name: String, _skill: String = ""):
	trace("{0} inited {1} for {2}".format([self, _name, _fromId]))
	fromId = _fromId
	set_actioner(fromId)
	name = _name
	if name in ["十面埋伏"]:
		skip_redo = 1
	stratagem = StaticManager.get_stratagem(name)
	skill = _skill
	return


func get_save_data() -> Dictionary:
	var ret = {}
	for attr in SAVED_ATTRS:
		ret[attr] = get(attr)
	return ret


func load_from_save_data(dic: Dictionary) -> void :
	for prop in get_property_list():
		if not prop.name in SAVED_ATTRS:
			continue
		if not prop.name in dic:
			continue
		var val = dic[prop.name]
		match prop.type:
			TYPE_DICTIONARY:
				val = Global.dicval(val)
			TYPE_INT:
				val = Global.intval(val)
			TYPE_STRING:
				val = Global.strval(val)
			TYPE_ARRAY:
				val = Global.arrval(val)
			TYPE_DICTIONARY:
				val = Global.dicval(val)
			_:
				print_debug("unexpected prop for ", prop, self)
		set(prop.name, val)
	if actionId < 0:
		set_actioner(fromId)
	stratagem = StaticManager.get_stratagem(name)
	return


func rebuild_from_env() -> void :
	
	fromId = DataManager.get_env_int("计策发动者")
	if fromId < 0:
		fromId = DataManager.player_choose_actor
	
	set_actioner(fromId)
	
	name = DataManager.get_env_str("计策名")
	
	stratagem = StaticManager.get_stratagem(name)
	
	targetId = DataManager.get_env_int("被用计者")
	if targetId < 0:
		targetId = DataManager.get_env_int("武将")
	if targetId < 0:
		targetId = DataManager.get_env_int("目标")
	
	succeeded = DataManager.get_env_int("结果")
	
	results = DataManager.get_env_dict("计策执行结果")
	return

func is_area_targeting() -> bool:
	if stratagem == null:
		return false
	return stratagem.is_area_targeting()


func get_available_targets() -> Array:
	return stratagem.get_available_targets(fromId)

func get_error_message() -> String:
	return stratagem.get_error_message()



func set_actioner(_actionId: int, hidden: bool = false) -> void :
	if hidden:
		actionId = - 1
		hiddenActionId = _actionId
	else:
		actionId = _actionId
	return


func set_target(_targetId: int) -> void :
	targetId = _targetId
	return



func get_affected_positions(pos: Vector2) -> PoolVector2Array:
	var radius = stratagem.get_targeting_range_radius()
	
	if stratagem.match_skill_mode() and rangeRadius > 0:
		radius = rangeRadius
	var width = radius
	var height = radius
	if stratagem.get_targeting_val("rangeWidth", "0") != "0":
		width = int(stratagem.get_targeting_val("rangeWidth"))
	if stratagem.get_targeting_val("rangeHeight", "0") != "0":
		height = int(stratagem.get_targeting_val("rangeHeight"))
	var rangeType = stratagem.get_targeting_range_type()
	var ret = [pos]
	var xFrom = pos.x - width
	var xTo = pos.x + width + 1
	var yFrom = pos.y - height
	var yTo = pos.y + height + 1
	if stratagem.get_targeting_val("rangeDirection") == "1":
		var me = DataManager.get_war_actor(fromId)
		if me == null:
			return ret
		match pos - me.position:
			Vector2.LEFT:
				xFrom = pos.x - height + 1
				xTo = pos.x + 1
				yFrom = pos.y - width
				yTo = pos.y + width + 1
			Vector2.RIGHT:
				xFrom = pos.x
				xTo = pos.x + height
				yFrom = pos.y - width
				yTo = pos.y + width + 1
			Vector2.UP:
				xFrom = pos.x - width
				xTo = pos.x + width + 1
				yFrom = pos.y - height
				yTo = pos.y + 1
			Vector2.DOWN:
				xFrom = pos.x - width
				xTo = pos.x + width + 1
				yFrom = pos.y
				yTo = pos.y + height + 1
			_:
				return ret
	var map = SceneManager.current_scene().war_map
	for x in range(xFrom, xTo):
		if x < 0:
			continue
		for y in range(yFrom, yTo):
			if y < 0:
				continue
			var p = Vector2(x, y)
			if not map.is_valid_position(p):
				continue
			if p in ret:
				continue
			match rangeType:
				"十字":
					if x == pos.x or y == pos.y:
						ret.append(p)
				"矩形":
					ret.append(p)
	return ret



func get_affected_actors(pos: Vector2) -> PoolIntArray:
	var ret = []
	var positions = [pos]
	if stratagem.get_targeting_val("rangeIncluded") == "1":
		positions = get_affected_positions(pos)

	var fromWA = DataManager.get_war_actor(fromId)
	for pos in positions:
		var wa = DataManager.get_war_actor_by_position(pos)
		if wa == null or wa.disabled:
			continue
		if not stratagem._side_available(fromWA, wa):
			continue
		if not stratagem._role_available(fromWA, wa):
			continue
		if not stratagem._terrian_available(fromWA, wa):
			continue
		if not wa.actorId in ret:
			ret.append(wa.actorId)
	return ret


func get_message() -> String:
	if message == "":
		return stratagem.get_message()
	return message


func performable() -> bool:
	return stratagem.performable(fromId)


func perform_cost() -> void :
	trace("{0} perform_cost".format([self]))
	if cost < 0:
		return

	cost = 0

	
	
	var wf = DataManager.get_current_war_fight()
	var wa = DataManager.get_war_actor(fromId)
	if wa == null or wa.disabled:
		stratagem.status = StratagemInfo.SchemeStatus.UNKNOWN
		return

	var info = stratagem.get_cost_info(wa.actorId)
	var toCost = info[0]
	var current = info[1]
	var hp = info[2]
	if toCost < 0 and current < 0:
		stratagem.status = StratagemInfo.SchemeStatus.CD
		return
	if current < toCost and hp <= 0:
		stratagem.status = StratagemInfo.SchemeStatus.AP_COST
		return

	if current >= toCost:
		wa.action_point = max(0, current - toCost)
	else:
		wa.action_point = 0
		for item in wa.actor().get_equip_feature_all("计策用体"):
			var equip = item[0]
			var val = item[1]
			var key = "CD.{0}.{1}.{2}".format([
				equip.name(), wa.actorId, wf.date, 
			])
			var triggered = wf.get_env_int(key, 0)
			if val <= triggered:
				continue
			wf.set_env(key, triggered + 1)
			var costHP = toCost - current
			wa.actor().set_hp(wa.actor().get_hp() - costHP)
			var seMsg = "<y{0}>效果，体力扣减<r{1}>".format([
				equip.name(), costHP, 
			])
			append_message(seMsg)
			if wa.actor().get_hp() >= 0:
				var msg = "鞠躬尽瘁，死而后已\n（{0}强行发动计策\n（「{1}」效果，体力扣减{2}".format([
					wa.get_name(), equip.name(), costHP
				])
				wa.attach_free_dialog(msg, 2)
			else:
				var leader = wa.get_leader()
				if leader.actorId == wa.actorId:
					
					var msg = "{0}强行发动计策\n竟致身亡，何苦来哉\n（「{1}」效果，体力扣减{2}".format([
						wa.get_name(), equip.name(), costHP
					])
					wa.get_enemy_leader().attach_free_dialog(msg, 1)
				else:
					
					var msg = "{0}强行发动计策\n竟致身亡，吾之过也！\n（「{1}」效果，体力扣减{2}".format([
						wa.get_name(), equip.name(), costHP
					])
					leader.attach_free_dialog(msg, 3)
				wa.dead("计策", wa.actorId)
			break
	DataManager.set_env("计策.扣减", [toCost, current, wa.action_point])
	SkillHelper.auto_trigger_skill(wa.actorId, 20006)
	var changed = DataManager.get_env_int_array("计策.扣减")
	toCost = changed[0]
	current = changed[1]
	wa.action_point = changed[2]
	DataManager.unset_env("计策.扣减")

	var cd = stratagem.get_cd_round()
	if cd > 0:
		wa.dic_skill_cd[stratagem.name] = cd
	stratagem.status = StratagemInfo.SchemeStatus.OK
	cost = toCost
	costed = wa.action_point
	return


func perform_to_area(pos: Vector2) -> bool:
	succeeded = 0
	var fromActorId = get_action_id(hiddenActionId)
	var onceRate = stratagem.get_rate(fromActorId, - 1, false, true)
	if not Global.get_rate_result(onceRate):
		DataManager.clear_common_variable(["计策.ONCE"])
		status = 1
		return false

	var wa = DataManager.get_war_actor(fromActorId)

	for key in stratagem.impact:
		var impact = stratagem.impact[key]
		match key:
			"area":
				var tag = str(impact["tag"])
				var turns = int(impact["round"])
				if turns <= 0:
					continue
				var buffInfo = StaticManager.get_buff(tag)
				if buffInfo == null:
					continue
				wa.set_areas(name, tag, fromId, turns, pos)
				match buffInfo.get_label():
					"伏兵":
						var msg = "军中士兵已埋伏起来"
						append_result(key, msg, 0)
						var map = SceneManager.current_scene().war_map
						map.mark_area_trapped(true, pos, buffInfo.get_area_radius())
	DataManager.clear_common_variable(["计策.ONCE"])
	succeeded = 1
	status = 1
	return succeeded > 0



func perform_to_targets(targets: PoolIntArray, skipRating: bool = false) -> bool:
	trace("{0} perform_to_targets: {1}, skipRating: {2}".format([self, targets, skipRating]))
	succeeded = 0
	if targets.empty():
		status = 1
		trace("{0} targets empty".format([self]))
		return false
	
	
	

	
	SkillHelper.reset_skills_list_cache(true)

	var fromActorId = get_action_id(hiddenActionId)
	var from = DataManager.get_war_actor(fromActorId)

	
	DataManager.set_env("计策.ONCE.目标数", targets.size())
	var target = DataManager.get_war_actor(targetId)
	if target != null:
		DataManager.set_env("计策.ONCE.目标位置", {"x": target.position.x, "y": target.position.y})
		DataManager.set_env("计策.ONCE.覆盖位置", get_affected_positions(target.position))
		DataManager.set_env("计策.ONCE.所有目标", targets)
		if stratagem.has_range_impact():
			_perform_to_positions(from)

	succeeded = 0
	for tid in targets:
		if _perform_to_target(tid, skipRating):
			succeeded = 1

		var targetWA = DataManager.get_war_actor(tid)
		if targetWA == null:
			continue
		
		var history = {};
		if targetWA.dic_other_variable.has("被用计策"):
			history = targetWA.dic_other_variable["被用计策"]
		history[name] = fromActorId
		targetWA.dic_other_variable["被用计策"] = history

	DataManager.clear_common_variable(["计策.ONCE"])

	
	if from != null and cost > 1\
	and DataManager.game_set["技能系统"] == "否"\
	and "道术" in stratagem.get_feature():
		var wf = DataManager.get_current_war_fight()
		for item in from.actor().get_equip_feature_all("首次道术返还机动力"):
			var equip = item[0]
			var val = item[1]
			
			var key = "CD.{0}.{1}.{2}".format([
				equip.name(), from.actorId, wf.date, 
			])
			if wf.get_env_int(key) > 0:
				continue
			wf.set_env(key, 1)
			if val <= 0:
				continue
			var recover = int(cost * val / 100.0)
			if recover <= 0:
				continue
			var ske = SkillHelper.new_ske_from_equip_simulation(from.actorId, equip)
			ske.change_actor_ap(from.actorId, recover)
			var msg = "[{0}] 令机动力回复 {1}".format([
				equip.name(), recover, 
			])
			append_result(equip.name(), msg, recover)
			ske.war_report()

	
	SkillHelper.reset_skills_list_cache(false)

	status = 1
	return succeeded > 0



func _perform_to_target(targetId: int, skipRating: bool = false) -> bool:
	trace("{0} perform to {1}, skipRating: {2}".format([self, targetId, skipRating]))
	var fromActorId = get_action_id(hiddenActionId)
	var defenderId = get_defender_id(targetId)
	var fromWA = DataManager.get_war_actor(fromActorId)
	if fromWA == null:
		trace("{0} from null".format([self]))
		return false
	var targetWA = DataManager.get_war_actor(targetId)
	if targetWA == null:
		trace("{0} target null".format([self]))
		return false

	
	var stopBuff = targetWA.get_buff("定止")
	if stopBuff["回合数"] > 0:
		var stopTurn = max(0, stopBuff["回合数"] - 1)
		targetWA.set_buff("定止", stopTurn, fromActorId, "", true)

	
	var onceRate = stratagem.get_rate(fromActorId, defenderId, false, true)
	var v_name = "战争.{0}用计{1}命中".format([fromActorId, name])
	if onceRate < 100 and fromWA.get_controlNo() >= 0:
		onceRate = DataManager.get_fix_v_rate(onceRate, v_name)

	if not skipRating:
		DataManager.set_env("战争.计策概率", onceRate)
		SkillHelper.auto_trigger_skill(fromActorId, 20010, "")
		SkillHelper.auto_trigger_skill(defenderId, 20010, "")
		onceRate = DataManager.get_env_int("战争.计策概率")
		DataManager.common_variable.erase("战争.计策概率")

		match rate_flag:
			0:
				if not Global.get_rate_result(onceRate):
					trace("{0} rate {1} chanced to fail".format([self, onceRate]))
					append_result("失败", "计策失败", 0, fromActorId)
					return false
			- 1:
				trace("{0} previously set to fail".format([self]))
				append_result("失败", "计策失败", 0, fromActorId)
				return false

	var targets = stratagem._get_extended_targets(fromWA, targetWA)
	
	var chainedTargets = DataManager.get_env_array("计策.ONCE.CHAINED")
	var confirmedList = []
	for targetId in targets:
		if targetId in chainedTargets:
			continue
		confirmedList.append(targetId)
		chainedTargets.append(targetId)
	DataManager.set_env("计策.ONCE.CHAINED", chainedTargets)
	_impact_for_actor(fromWA, targetId, confirmedList)
	return true



func _impact_for_actor(fromWA: War_Actor, mainTargetId: int, allTargets: Array = []) -> void :
	trace("{0} impact for actor, target {1}, all targets {2}".format([self, mainTargetId, ".".join(allTargets)]))
	allTargets.erase(mainTargetId)
	allTargets.insert(0, mainTargetId)

	for key in stratagem.impact:
		var impact = stratagem.impact[key]
		match key:
			"soldier":
				var ret = stratagem._impact_for_soldier_damage(fromWA, allTargets, impact, is_stratagem())
				for targetId in ret:
					var damage = int(ret[targetId])
					append_result("伤兵量", "", damage, targetId)
					var targetWA = DataManager.get_war_actor(targetId)
					var ta = ActorHelper.actor(targetId)
					if damage > 0 and targetWA != null:
						
						
						if targetWA.get_buff_label_turn(["铁索"]) > 0:
							var rate = int((ta.get_wisdom() * ta.get_wisdom() * ta.get_leadership()) / 12500)
							var chained = int(targetWA.get_tmp_variable("铁索命中", 0))
							rate = min(80, rate + chained * 15)
							if Global.get_rate_result(rate):
								targetWA.set_buff("铁索连环", 0, - 1, "", true)
								var msg = "{0}挣脱 [铁索连环]".format([ta.get_name()])
								append_result("铁索", msg, 0, targetId)
								targetWA.set_tmp_variable("铁索命中", 0)
							else:
								targetWA.set_tmp_variable("铁索命中", chained + 1)
			"rice":
				var ret = stratagem._impact_for_rice_damage(fromWA, allTargets, impact)
				for targetId in ret:
					var damage = int(ret[targetId])
					append_result("扣米量", "", damage, targetId)
			"hp":
				var ret = stratagem._impact_for_hp_damage(fromWA, allTargets, impact)
				for targetId in ret:
					var damage = int(ret[targetId])
					append_result("伤体量", "", damage, targetId)
					var targetWA = DataManager.get_war_actor(targetId)
					var targetActor = ActorHelper.actor(targetId)
					if targetActor.get_hp() <= 0:
						var msg = targetActor.get_name() + targetWA.actor_capture_to(fromWA.wvId, "计策", fromWA.actorId)
						append_result("捕获", msg, 1, targetId)
			"heal":
				var ret = stratagem._impact_for_hp_heal(fromWA, allTargets, impact)
				for targetId in ret:
					var heal = int(ret[targetId])
					var targetActor = ActorHelper.actor(targetId)
					var msg = "{0}体力回复{1}".format([targetActor.get_name(), heal])
					append_result("治疗", msg, heal, targetId)
			"buff":
				var ret = stratagem._impact_for_buff(fromWA, allTargets, impact)
				for targetId in ret:
					var turns = int(ret[targetId][1])
					var msg = str(ret[targetId][2])
					append_result("状态", msg, turns, targetId)
			"specialEffect":
				var ret = stratagem._impact_for_special_effect(fromWA, allTargets, impact, self)
				for targetId in ret:
					var tag = str(ret[targetId][0])
					var msg = str(ret[targetId][1])
					var val = int(ret[targetId][2])
					var unique = false
					if ret[targetId].size() > 3 and ret[targetId][3]:
						unique = true
					append_result(tag, msg, val, targetId, unique)
	return


func get_rate(targetIds: PoolIntArray) -> int:
	if targetIds.empty():
		rate = 100
	else:
		var failRate: float = 1.0
		for tid in targetIds:
			var aid = get_action_id(hiddenActionId)
			var did = get_defender_id(tid)
			var onceRate = stratagem.get_rate(aid, did)
			failRate = failRate * (1.0 - onceRate / 100.0)
		rate = int((1.0 - failRate) * 100)
	return rate


func set_replaced_actioner(_actionId: int, source: String) -> void :
	set_actioner(_actionId)
	actionSource = source
	return

func set_replaced_defender(id: int, source: String) -> void :
	defenderId = id
	defenderSource = source
	return


func get_raw_rate(targetIds: PoolIntArray) -> int:
	if targetIds.empty():
		return 100
	var failRate: float = 1.0
	for tid in targetIds:
		var aid = get_action_id(hiddenActionId)
		var did = get_defender_id(tid)
		var onceRate = stratagem.get_raw_rate(aid, did)
		failRate = failRate * (1.0 - onceRate / 100.0)
	return int((1.0 - failRate) * 100)


func summary() -> PoolStringArray:
	var msgs = []
	var skillSource = ""
	if skill != "":
		skillSource = "【{0}】".format([skill])
	var hidden = ""
	if get_action_id(hiddenActionId) != actionId:
		hidden = "<r隐身>"
	var msg = "- {0}{3}对{1}{4}发动<r{2}>".format([
		_actor_info(fromId), _actor_info(targetId), 
		name, skillSource, hidden, 
	])
	msgs.append(msg)
	if get_action_id(hiddenActionId) != fromId:
		msg = "  -（由{0}{1}代为发动".format([
			_actor_info(get_action_id(hiddenActionId)), actionSource, 
		])
		msgs.append(msg)
	var did = get_defender_id(targetId)
	if did != targetId:
		msg = "  - {0}【<r{1}>】替代{2}执行计防".format([
			_actor_info(did), defenderSource, _actor_info(targetId)
		])
		msgs.append(msg)
	if cost > 0:
		msg = "  - 消耗<y{0}>机动力".format([cost])
		if costed >= 0:
			msg += " -> {0}".format([costed])
		msgs.append(msg)
	msg = "  - "
	if rate >= 0:
		msg += "成功率<y{0}%>，".format([
			rate
		])
	if succeeded > 0:
		msg += "成功"
	else:
		msg += "失败"
	msgs.append(msg)
	for key in results:
		match key:
			"兵力流失":
				var damages = {}
				for row in results[key]:
					var damage = row[1]
					var idkey = str(row[2])
					if not idkey in damages:
						damages[idkey] = 0
					damages[idkey] += damage
				for idkey in damages:
					var id = int(idkey)
					var damage = int(damages[idkey])
					if damage == 0:
						continue
					var actor = ActorHelper.actor(id)
					var memo = "兵力流失"
					if damage < 0:
						memo = "兵力回复"
					msg = "  - {0}{1}<r{2}>，剩余{3}".format([
						_actor_info(id), memo, abs(damage), 
						actor.get_soldiers(), 
					])
					msgs.append(msg)
			"伤兵量":
				var damages = {}
				for row in results[key]:
					var damage = row[1]
					var idkey = str(row[2])
					if not idkey in damages:
						damages[idkey] = 0
					damages[idkey] += damage
				for idkey in damages:
					var id = int(idkey)
					var damage = int(damages[idkey])
					if damage == 0:
						continue
					var actor = ActorHelper.actor(id)
					var memo = "损兵"
					if damage < 0:
						memo = "兵力回复"
					msg = "  - {0}{1}<r{2}>，剩余{3}".format([
						_actor_info(id), memo, abs(damage), 
						actor.get_soldiers(), 
					])
					msgs.append(msg)
			"伤体量":
				for row in results[key]:
					var damage = row[1]
					var id = row[2]
					var actor = ActorHelper.actor(id)
					msg = "  - {0}体力下降<r{1}>，现为{2}".format([
						_actor_info(id), damage, int(actor.get_hp())
					])
					msgs.append(msg)
			"扣米量":
				for row in results[key]:
					var targetId = int(row[2])
					var damage = int(row[1])
					if damage == 0:
						continue
					msgs.append("  - {0}军米减少{1}".format([
						_actor_info(targetId), damage
					]))
			"减伤":
				for row in results[key]:
					msg = "  - 因{0}【{1}】，减伤{2}".format([
						_actor_info(int(row[2])), row[0], int(row[1]), 
					])
					msgs.append(msg)
			"反伤":
				for row in results[key]:
					msg = "  - 因{0}【{1}】受到反伤{2}".format([
						_actor_info(int(row[2])), row[0], int(row[1]), 
					])
					msgs.append(msg)
			"笼络":
				for row in results[key]:
					var id = int(row[2])
					var m = "  - {0}加入{1}军".format([
						_actor_info(id), DataManager.get_war_actor(fromId).get_lord_name(), 
					])
					msgs.append(m)
			"必中":
				msg = "  - 因<y{0}>【<r{1}>】效果必中"
				for row in results[key]:
					var skill = row[0]
					var fromId = row[2]
					if fromId < 0:
						continue
					if fromId == actionId:
						msg = "  - 因【{1}】效果必中"
					msg = msg.format([
						ActorHelper.actor(fromId).get_name(), skill
					])
					msgs.append(msg)
					break
			"机动力":
				
				var total = 0
				for row in results[key]:
					var skill = str(row[0])
					var change = int(row[1])
					var targetId = int(row[2])
					if change == 0:
						continue
					if skill == "" and targetId == fromId:
						total += change
						continue
					var source = "" if skill == "" else "因<r【{0}】>".format([skill])
					var name = "" if targetId == fromId else _actor_info(targetId)
					var action = "回复" if change > 0 else "扣减"
					var m = "  - {0}{1}机动力{2}<y{3}>".format([
						source, name, action, abs(change), 
					])
					msgs.append(m)
				if total != 0:
					var action = "回复" if total > 0 else "扣减"
					var m = "  - 机动力{0}<y{1}>".format([
						action, abs(total), 
					])
					msgs.append(m)
			"失败":
				pass
			"":
				pass
			_:
				for row in results[key]:
					append_message(str(row[0]))
	for m in logs:
		msgs.append(m)
	return msgs

func _actor_info(actorId: int) -> String:
	if actorId < 0:
		return "--"
	var msg = "<y{0}>".format([
		ActorHelper.actor(actorId).get_name(), 
	])
	
	
	
	return msg


func damage_soldier() -> bool:
	if stratagem == null:
		return false
	return stratagem.may_damage_soldier()


func damage_hp() -> bool:
	if stratagem == null:
		return false
	return stratagem.may_damage_hp()


func get_soldier_damage_for(actorId: int) -> int:
	if not "伤兵量" in results:
		return 0
	for row in results["伤兵量"]:
		var id = row[2]
		if id != actorId:
			continue
		return int(row[1])
	return 0



func get_action_id(observerId: int = - 1) -> int:
	if actionId >= 0:
		return actionId
	if hiddenActionId >= 0 and observerId == hiddenActionId:
		
		return hiddenActionId
	return - 1



func get_defender_id(tid: int) -> int:
	if tid == targetId and defenderId >= 0:
		return defenderId
	return tid


func set_must_success(actorId: int, skill: String) -> void :
	if rate_flag != 0:
		return
	rate = 100
	rate_flag = 1
	
	append_result("必中", skill, 1, actorId)
	return


func set_must_fail(actorId: int, skill: String) -> void :
	if rate_flag != 0:
		return
	rate = 0
	rate_flag = - 1
	var msg = "因{0}【{1}】无功而返".format([
		ActorHelper.actor(actorId).get_name(), skill
	])
	
	append_result(skill, msg, 1, actorId, true)
	return


func skip_execution(actorId: int, skill: String) -> void :
	rate = 0
	succeeded = 0
	status = 1
	var msg = "因{0}【{1}】效果取消".format([
		ActorHelper.actor(actorId).get_name(), skill
	])
	
	
	
	results = {}
	
	append_result(skill, msg, 0, actorId, true)
	return

func report() -> void :
	
	DataManager.common_variable.erase("计策执行结果")
	if status == 0:
		
		trace("{0} report before execution".format([self]))
		return
	elif status == 2:
		
		trace("{0} report after reported".format([self]))
		return
	trace("{0} report".format([self]))
	DataManager.record_war_log("\n".join(summary()))
	status = 2
	return




func append_message(msg: String) -> void :
	var first = true
	for m in msg.split("\n"):
		if first:
			logs.append("  - " + m)
			first = false
		else:
			logs.append("    - " + m)
	return

func append_message_once(msg: String, key: String) -> void :
	if key in message_once_keys:
		return
	append_message(msg)
	message_once_keys.append(key)
	return


func get_total_damage() -> int:
	if not "伤兵量" in results:
		return 0
	var damage = 0
	for row in results["伤兵量"]:
		var d = int(row[1])
		if d <= 0:
			continue
		damage += d
	return damage


func get_all_damaged_targets() -> PoolIntArray:
	var ret = []
	for key in ["伤兵量", "伤体量", "扣米量"]:
		if not key in results:
			continue
		for row in results[key]:
			var d = int(row[1])
			if d <= 0:
				continue
			var targetId = int(row[2])
			if targetId in ret:
				continue
			ret.append(targetId)
	return ret

func append_result(type: String, msg: String, num: int, targetId: int = 0, unique: bool = false) -> void :
	if unique and results.has(type):
		for row in results[type]:
			if row[2] == targetId:
				return
		return
	if not results.has(type):
		results[type] = []
	results[type].append([msg, num, targetId])
	return


func get_report_message(reporterWA: War_Actor = null, fromWA: War_Actor = null) -> PoolStringArray:
	if reporterWA == null:
		reporterWA = DataManager.get_war_actor(get_action_id(hiddenActionId))
	var ret: PoolStringArray = []
	var fromEnemy = false
	if fromWA == null:
		fromWA = reporterWA
	else:
		if fromWA.side() != reporterWA.side():
			fromEnemy = true
	if results.empty():
		if fromEnemy:
			reporter_mood = 1
			return PoolStringArray(["但并未造成伤害"])
		else:
			reporter_mood = 3
			return PoolStringArray(["很遗憾", "并未造成伤害"])
	var hasFailure = false
	var causeDamage = false
	for key in results.keys():
		match key:
			"失败":
				hasFailure = true
			"免伤":
				var reduced = {}
				for res in results[key]:
					var actorId = int(res[2])
					var subkey = "{0}发动{1}".format([ActorHelper.actor(actorId).get_name(), res[0]])
					if not reduced.has(subkey):
						reduced[subkey] = 0
					reduced[subkey] += int(res[1])
				for subkey in reduced:
					ret.append("{0}，免伤{1}".format([subkey, reduced[subkey]]))
			"反伤":
				var reflected = {}
				for row in results[key]:
					
					
					var source = str(row[0])
					if not reflected.has(source):
						reflected[source] = 0
					reflected[source] += int(row[1])
				var reflectName = "我军"
				if fromEnemy:
					reflectName = fromWA.get_name()
				for source in reflected:
					ret.append("受到【{0}】反伤".format([source]))
					ret.append("{0}兵力下降{1}".format([
						reflectName, int(reflected[source])
					]))
			"兵力流失":
				var damages = {}
				for res in results[key]:
					var side = "敌军"
					var targetId = int(res[2])
					var targetWA = DataManager.get_war_actor(targetId)
					if targetWA != null and not targetWA.is_enemy(reporterWA):
						side = "我军"
					if not damages.has(side):
						damages[side] = 0
					damages[side] += int(res[1])
				for side in damages:
					if damages[side] == 0:
						continue
					var type = "增加"
					if damages[side] > 0:
						causeDamage = true
						type = "流失"
					ret.insert(0, "{0}兵力{2}{1}".format([side, abs(damages[side]), type]))
			"伤兵量":
				var damages = {}
				for res in results[key]:
					var side = "敌军"
					var targetId = int(res[2])
					var targetWA = DataManager.get_war_actor(targetId)
					if targetWA != null and not targetWA.is_enemy(reporterWA):
						side = "我军"
					if not damages.has(side):
						damages[side] = 0
					damages[side] += int(res[1])
				for side in damages:
					if damages[side] == 0:
						continue
					var type = "增加"
					if damages[side] > 0:
						causeDamage = true
						type = "下降"
					ret.insert(0, "{0}兵力{2}{1}".format([side, abs(damages[side]), type]))
			"伤体量":
				for res in results[key]:
					var targetId = int(res[2])
					var damage = int(res[1])
					if damage == 0:
						continue
					causeDamage = true
					ret.append("{0}体力下降{1}".format([
						ActorHelper.actor(targetId).get_name(), 
						damage
					]))
			"扣米量":
				for res in results[key]:
					var targetId = int(res[2])
					var damage = int(res[1])
					if damage == 0:
						continue
					causeDamage = true
					var msg = "{0}军米减少{1}"
					if fromEnemy:
						msg = "我军米减少{1}"
					ret.append(msg.format([
						ActorHelper.actor(targetId).get_name(), 
						damage
					]))
			"状态":
				for res in results[key]:
					if res[0] in ret:
						continue;
					ret.append(res[0])
			"战术状态":
				
				var buffs = {}
				for res in results[key]:
					var buff = str(res[0])
					if not buffs.has(buff):
						buffs[buff] = {"names": [], "cnt": 0}
					var actorId = int(res[2])
					var name = ActorHelper.actor(actorId).get_name()
					buffs[buff]["cnt"] += 1
					if not buffs[buff]["names"].has(name) and buffs[buff]["names"].size() < 3:
						buffs[buff]["names"].append(name)
				for buff in buffs:
					var msg = "、".join(buffs[buff]["names"])
					if buffs[buff]["cnt"] > 3:
						msg += "等{0}人".format([buffs[buff]["cnt"]])
					msg += "被附加{0}状态".format([buff])
					ret.append(msg)
			"劝退":
				for res in results[key]:
					var msg = "{0}为计策所惑\n已撤往{1}".format([
						ActorHelper.actor(res[2]).get_name(), 
						clCity.city(res[1]).get_full_name(), 
					])
					ret.append(msg)
			"减伤":
				for res in results[key]:
					var msg = "因{0}【{1}】，减伤{2}".format([
						ActorHelper.actor(res[2]).get_name(), 
						res[0], res[1]
					])
					ret.append(msg)
			"笼络":
				for res in results[key]:
					var msg = "{0}已加入我军"
					if fromEnemy:
						msg = "{0}已加入敌军"
					msg = msg.format([
						ActorHelper.actor(res[2]).get_name(), 
					])
					ret.append(msg)
			"机动力":
				
				var total = 0
				for row in results[key]:
					var skill = str(row[0])
					var change = int(row[1])
					var targetId = int(row[2])
					if change == 0:
						continue
					if skill == "" and targetId == fromId:
						total += change
						continue
					var source = "" if skill == "" else "因【{0}】".format([skill])
					var name = "" if targetId == fromId else _actor_info(targetId)
					var action = "回复" if change > 0 else "扣减"
					var msg = "{0}{1}机动力{2}{3}".format([
						source, name, action, abs(change), 
					])
					ret.append(msg)
				if total != 0:
					var action = "回复" if total > 0 else "扣减"
					var msg = "机动力{0}{1}".format([
						action, abs(total), 
					])
					ret.append(msg)
			"必中":
				var msg = "因{0}【{1}】效果必中"
				for row in results[key]:
					var skill = row[0]
					var fromId = row[2]
					if fromId < 0:
						continue
					if fromId == reporterWA.actorId:
						msg = "因【{1}】效果必中"
					msg = msg.format([
						ActorHelper.actor(fromId).get_name(), skill
					])
					ret.append(msg)
					break
			_:
				for res in results[key]:
					var msgs = str(res[0]).split("\n")
					for msg in msgs:
						ret.append(msg)
	reporter_mood = 1
	if fromEnemy:
		reporter_mood = 3
	
	if hasFailure and not causeDamage:
		if fromEnemy:
			reporter_mood = 1
			ret.insert(0, "但未造成伤害")
		else:
			reporter_mood = 3
			ret.insert(0, "计策未能成功")
			ret.insert(0, "很遗憾")
	else:
		
		if not causeDamage and (damage_soldier() or damage_hp()):
			if fromEnemy:
				reporter_mood = 1
				ret.insert(0, "但未造成伤害")
			else:
				reporter_mood = 2
				ret.insert(0, "敌军未受到伤害")
	return ret


func set_fixed_distance(val: int, ske: SkillEffectInfo) -> void :
	var key = "计策.ONCE.距离"
	var setting = DataManager.get_env_dict(key)
	if not name in setting:
		setting[name] = {}
	setting[name]["固定"] = 1
	DataManager.set_env(key, setting)
	var msg = "因【{0}】计策距离视为{1}".format([
		ske.skill_name, val, 
	])
	append_result(ske.skill_name, msg, val, ske.skill_actorId, true)
	return


func get_nature() -> String:
	if stratagem == null:
		return ""
	return stratagem.get_nature()

func get_cost_ap(actorId: int) -> int:
	if stratagem == null:
		return 0
	return stratagem.get_cost_ap(actorId)


func is_stratagem() -> bool:
	if work_as_skill > 0:
		return false
	if stratagem == null:
		return false
	return stratagem.is_stratagem()


func decide_cost() -> void :
	if cost < 0:
		cost = 0
		return
	
	
	
	
	cost = stratagem.get_cost_info(fromId)[0]
	return

func get_animation() -> String:
	if stratagem == null:
		return ""
	return stratagem.get_animation()

func set_env(key: String, val) -> void :
	env[key] = val
	return

func get_env_int(key: String, defVal: int = - 1) -> int:
	if not key in env:
		return defVal
	return Global.intval(env[key], defVal)


func mark_auto_finish_turn() -> void :
	set_env("auto_finish_turn", 1)
	return

func will_auto_finish_turn() -> bool:
	return get_env_int("auto_finish_turn") > 0

func _perform_to_positions(from: War_Actor) -> void :
	var posInfo = DataManager.get_env_dict("计策.ONCE.目标位置")
	if not "x" in posInfo or not "y" in posInfo:
		return
	var center = Vector2(Global.intval(posInfo["x"]), Global.intval(posInfo["y"]))
	var positions = DataManager.get_env_array("计策.ONCE.覆盖位置")
	for impact in stratagem.get_range_impacts():
		var method = "_range_impact_for_" + impact
		if not stratagem.has_method(method):
			continue
		var ret = stratagem.call(method, from, positions)
		if ret != "":
			append_result(impact, ret, 0, - 1, true)
	return
