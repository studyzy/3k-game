extends Resource


class_name PolicyCommand


var cityId: int = - 1


var actionId: int = - 1


var type: String = ""


var actionPolitics: int = 0


var actionMoral: int = 0


var targetCityId: int = - 1


var targetActorId: int = - 1


var targetVstateId: int = - 1


var basicRate: int = 0


var rate: int = 0


var costGold: int = 0


var costRice: int = 0


var result: int = 0


var status: int = 0


var extraEffects: Dictionary = {}


var changes: Dictionary = {}


var extraMessages: Array = []


var dialogs: Array = []


func _init(_type: String, _actionId: int, fromCityId: int = - 1):
	if fromCityId < 0:
		fromCityId = DataManager.player_choose_city
	cityId = fromCityId
	type = _type
	set_actioner(_actionId)
	return

func set_actioner(actorId: int) -> void :
	actionId = actorId
	if actorId >= 0:
		actionPolitics = actioner().get_politics()
		actionMoral = actioner().get_moral()
	return

func set_target(_targetActorId: int, _targetCityId: int) -> void :
	targetActorId = _targetActorId
	targetCityId = _targetCityId
	targetVstateId = target_city().get_vstate_id()
	return

func vstate() -> clVState.VStateInfo:
	return clVState.vstate(city().get_vstate_id())

func city() -> clCity.CityInfo:
	return clCity.city(cityId)

func actioner() -> ActorHelper.ActorInfo:
	return ActorHelper.actor(actionId)


func _target_vstate_id() -> int:
	if targetVstateId < 0:
		return target_city().get_vstate_id()
	return targetVstateId

func target_vstate() -> clVState.VStateInfo:
	return clVState.vstate(_target_vstate_id())

func target_city() -> clCity.CityInfo:
	return clCity.city(targetCityId)

func target_actor() -> ActorHelper.ActorInfo:
	return ActorHelper.actor(targetActorId)


func get_save_data() -> Dictionary:
	var ret = {}
	ret["cityId"] = cityId
	ret["actionId"] = actionId
	ret["type"] = type
	ret["actionPolitics"] = actionPolitics
	ret["actionMoral"] = actionMoral
	ret["targetCityId"] = targetCityId
	ret["targetActorId"] = targetActorId
	ret["targetVstateId"] = targetVstateId
	ret["basicRate"] = basicRate
	ret["rate"] = rate
	ret["costRice"] = costRice
	ret["costGold"] = costGold
	ret["result"] = result
	ret["status"] = status
	ret["extraEffects"] = extraEffects
	ret["changes"] = changes
	ret["extraMessages"] = extraMessages
	var dialogData = []
	for d in dialogs:
		dialogData.append(d.output())
	ret["dialogs"] = dialogData
	return ret


func load_from_save_data(dic: Dictionary) -> void :
	for prop in get_property_list():
		if prop.name in dic:
			if "dialogs" == prop.name:
				dialogs = []
				for dialogData in dic["dialogs"]:
					var d = clCity.CityInfo.DialogInfo.new()
					d.input(dialogData)
					dialogs.append(d)
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


func prepare() -> void :
	basicRate = 0
	rate = 0
	match type:
		"离间":
			wedge_rate()
		"招揽":
			canvass_rate()
		"策反":
			incite_rate()
		"同盟":
			ally_rate()
		"亲善":
			pass
		"交涉":
			rescue_rate()
	return


func execute() -> void :
	if status > 0:
		
		return
	result = 0
	match type:
		"离间":
			wedge_effect()
		"招揽":
			canvass_effect()
		"策反":
			incite_effect()
		"同盟":
			ally_effect()
		"亲善":
			envoy_effect()
		"交涉":
			rescue_effect()
	status = 1
	DataManager.set_env("内政.命令", "策略")
	SkillHelper.auto_trigger_skill(actionId, 10012)
	if result == 0:
		var srb = SkillRangeBuff.max_for_city("策略失败惩罚", target_city().ID)
		if srb != null:
			var fine = srb.effectTagVal
			var got = target_city().add_gold(fine)
			var fined = city().add_gold( - fine)
			var msgs = []
			if got > 0:
				msgs.append("{0}金 +{1}，现为 {2}".format([
					target_city().get_name(), got, target_city().get_gold(), 
				]))
			if fined < 0:
				msgs.append("{0}金 {1}，现为 {2}".format([
					city().get_name(), fined, city().get_gold(), 
				]))
			if not msgs.empty():
				msgs.insert(0, "因{0}【{1}】效果".format([
					ActorHelper.actor(srb.actorId).get_name(), srb.skillName, 
				]))
				append_result_messages(msgs, 2, - 2)
	return

func pop_result_dialog() -> clCity.CityInfo.DialogInfo:
	return dialogs.pop_front()

func append_extra_message(msg: String) -> void :
	extraMessages.append_array(msg.split("\n"))
	return

func append_result_messages(msgs: Array, mood: int, _actorId: int = - 1, _cityId: int = - 1) -> void :
	if _actorId == - 1:
		_actorId = actioner().actorId
	if _cityId < 0:
		_cityId = city().ID
	while not msgs.empty():
		var d = clCity.CityInfo.DialogInfo.new()
		d.cityId = _cityId
		d.actorId = _actorId
		if msgs.size() > 3:
			d.msg = "\n".join(msgs.slice(0, 2))
			msgs = msgs.slice(3, msgs.size() - 1)
		else:
			d.msg = "\n".join(msgs)
			msgs = []
		d.mood = mood
		dialogs.append(d)
	return


func wedge_rate() -> void :
	var actioner = actioner()
	var target = target_actor()
	
	SkillHelper.auto_trigger_skill(actioner.actorId, 10004, "")
	SkillHelper.auto_trigger_skill(target.actorId, 10014, "")

	
	var loyalty = target_actor().get_loyalty()
	
	var distance = target.personality_distance(actioner)
	loyalty -= int((35 - distance) / 4)
	basicRate = int((actionPolitics + actionMoral) * max(0, 98 - loyalty) / 200)
	rate = basicRate
	return


func wedge_effect() -> void :
	result = 0
	changes = {}
	var targetControlNO = DataManager.get_actor_controlNo(target_city().get_lord_id())
	var reporter = actioner().actorId
	var mood = 1
	if targetControlNO >= 0:
		
		reporter = DataManager.get_max_property_actorId("知", target_vstate().id, [target_actor().actorId])
		
		if reporter == - 1:
			reporter = target_vstate().get_lord_id()
		mood = 3
	
	var ta = target_actor()
	if targetControlNO < 0\
	and ta.actorId == StaticManager.ACTOR_ID_XUSHU\
	and ta.get_side() == "阴"\
	and city().get_vstate_id() == StaticManager.VSTATEID_LIUBEI:
		var msg = "吾感{0}厚恩，未尝忘报\n誓不为{1}设一谋\n然不可反覆无行，徒惹人笑".format([
			DataManager.get_actor_honored_title(city().get_lord_id(), ta.actorId), 
			ActorHelper.actor(target_city().get_lord_id()).get_name(), 
		])
		append_result_messages(msg.split("\n"), 2, ta.actorId, target_city().ID)
		msg = "{0}自有苦衷\n未可说也".format([ta.get_name()])
		append_result_messages(msg.split("\n"), 3)
		return

	
	if Global.get_rate_result(rate):
		result = 1
	SkillHelper.auto_trigger_skill(targetActorId, 10016, "")
	if result <= 0:
		var msg = "{0}闭门谢客\n离间未能成功".format([
			target_actor().get_name()
		])
		mood = 4 - mood
		if targetControlNO >= 0:
			
			msg = "{1}军之离间策略未奏效\n\n"
			if reporter == - 1:
				msg += "\n"
			else:
				msg = "{0}大人\n" + msg
			msg += "{2}闭门谢客\n{3}无功而返"
			msg = msg.format([
				target_vstate().get_lord_name(), 
				vstate().get_dynasty_title_or_lord_name(), 
				target_actor().get_name(), actioner().get_name(), 
			])
		var msgs = msg.split("\n")
		msgs.append_array(extraMessages)
		append_result_messages(msgs, mood, reporter)
		return
	
	var val = int(actionPolitics / 20) + Global.get_random(0, 3)
	for source in extraEffects:
		for k in extraEffects[source]:
			var extra = int(extraEffects[source][k])
			var msg = "因{0}【{1}】忠额外 -{2}"
			if int(k) == actioner().actorId:
				msg = "因【{1}】忠额外 -{2}"
			msg = msg.format([
				ActorHelper.actor(int(k)).get_name(), 
				source, extra
			])
			append_extra_message(msg)
			val += extra
	changes[str(ta.actorId)] = val
	ta.set_loyalty(ta.get_loyalty() - val)
	var msg = "妙哉!\n{0}已对君主产生猜疑\n忠诚度-{1}，现为{2}".format([
		ta.get_name(), val, ta.get_loyalty()
	])
	if targetControlNO >= 0:
		
		msg = "{0}大人\n{1}军之离间策略已成功\n"
		msg += "\n{2}与{3}秘密交谈\n不知所言何事\n"
		msg = msg.format([
			target_vstate().get_lord_name(), 
			vstate().get_dynasty_title_or_lord_name(), 
			target_actor().get_name(), actioner().get_name(), 
		])
	var msgs = msg.split("\n")
	msgs.append_array(extraMessages)
	append_result_messages(msgs, mood, reporter)
	return


func canvass_rate() -> void :
	SkillHelper.auto_trigger_skill(actioner().actorId, 10004, "")
	SkillHelper.auto_trigger_skill(target_actor().actorId, 10014, "")
	basicRate = get_canvass_rate(
		actioner().actorId, 
		target_actor().actorId, 
		actioner().get_politics(), 
		actioner().get_moral(), 
		actioner().get_level()
	)
	rate = get_canvass_rate(
		actioner().actorId, 
		target_actor().actorId, 
		actionPolitics, 
		actionMoral, 
		actioner().get_level()
	)
	return


func canvass_effect() -> void :
	result = 0
	changes = {}
	var targetControlNO = DataManager.get_actor_controlNo(target_city().get_lord_id())
	var reporter = actioner().actorId
	var mood = 1
	if targetControlNO >= 0:
		
		reporter = DataManager.get_max_property_actorId("知", target_vstate().id, [target_actor().actorId])
		
		if reporter == - 1:
			reporter = target_vstate().get_lord_id()
		mood = 3
	
	var ta = target_actor()
	if targetControlNO < 0\
	and ta.actorId == StaticManager.ACTOR_ID_XUSHU\
	and ta.get_side() == "阴"\
	and city().get_vstate_id() == StaticManager.VSTATEID_LIUBEI:
		var msg = "吾感{0}厚恩，未尝忘报\n誓不为{1}设一谋\n然不可反覆无行，徒惹人笑".format([
			DataManager.get_actor_honored_title(city().get_lord_id(), ta.actorId), 
			ActorHelper.actor(target_city().get_lord_id()).get_name(), 
		])
		append_result_messages(msg.split("\n"), 2, ta.actorId, target_city().ID)
		msg = "{0}自有苦衷\n未可说也".format([ta.get_name()])
		append_result_messages(msg.split("\n"), 3)
		return
	
	if Global.get_rate_result(rate):
		result = 1
	var originalResult = result
	
	
	if SkillHelper.auto_trigger_skill(targetActorId, 10016, "AI_next"):
		return
	if originalResult > 0 and result <= 0:
		
		return
	if result <= 0:
		var msg = "{0}闭门谢客\n招揽未能成功".format([
			target_actor().get_name()
		])
		mood = 4 - mood
		if targetControlNO >= 0:
			
			msg = "{1}军之招揽策略未奏效\n\n"
			if reporter == - 1:
				msg += "\n"
			else:
				msg = "{0}大人\n" + msg
			msg += "{2}闭门谢客\n{3}无功而返"
			msg = msg.format([
				target_vstate().get_lord_name(), 
				vstate().get_dynasty_title_or_lord_name(), 
				target_actor().get_name(), actioner().get_name(), 
			])
		var msgs = msg.split("\n")
		msgs.append_array(extraMessages)
		append_result_messages(msgs, mood, reporter)
		return
	
	canvass_result()
	var msg = "可喜可贺!\n{0}加入我军".format([ta.get_name()])
	if targetControlNO >= 0:
		msg = "{0}大人\n{1}军之招揽策略已成功\n"
		msg += "\n{2}背叛我方\n成为{1}军部下\n"
		msg = msg.format([
			target_vstate().get_lord_name(), 
			vstate().get_dynasty_title_or_lord_name(), 
			target_actor().get_name(), 
		])
	var msgs = msg.split("\n")
	msgs.append_array(extraMessages)
	append_result_messages(msgs, mood, reporter)
	return

func canvass_result() -> void :
	var ta = target_actor()
	clCity.transfer_to(ta.actorId, city().ID)
	ta.set_loyalty(ta.surrend_loyalty(city().get_vstate_id()))
	var tc = target_city()
	if tc.get_vstate_id() == - 1:
		var msg = "{0}已为空城".format([tc.get_name()])
		append_extra_message(msg)
	return


func incite_rate() -> void :
	
	canvass_rate()
	return


func incite_effect() -> void :
	result = 0
	changes = {}
	var targetControlNO = DataManager.get_actor_controlNo(target_city().get_lord_id())
	var sourceControlNO = DataManager.get_actor_controlNo(city().get_lord_id())
	var reporter = actioner().actorId
	var mood = 1
	if targetControlNO >= 0:
		
		reporter = DataManager.get_max_property_actorId("知", target_vstate().id, [target_actor().actorId])
		
		if reporter == - 1:
			reporter = target_vstate().get_lord_id()
		mood = 3
	if Global.get_rate_result(rate):
		result = 1
	SkillHelper.auto_trigger_skill(targetActorId, 10016, "")
	if result <= 0:
		if sourceControlNO < 0 and targetControlNO < 0:
			
			return
		var msg = "惭愧\n策略未能成功"
		mood = 4 - mood
		if targetControlNO >= 0:
			
			msg = "{1}军之策反策略未奏效\n\n"
			if reporter == - 1:
				reporter = target_vstate().get_lord_id()
				msg += "\n"
			else:
				msg = "{0}大人\n" + msg
			msg += "{2}闭门谢客\n{3}无功而返"
			msg = msg.format([
				target_vstate().get_lord_name(), 
				vstate().get_dynasty_title_or_lord_name(), 
				target_actor().get_name(), actioner().get_name(), 
			])
		var msgs = msg.split("\n")
		msgs.append_array(extraMessages)
		append_result_messages(msgs, mood, reporter)
		return
	
	var ta = target_actor()
	var newVstateId = clVState.create_new_vstate(ta.actorId)
	ta.set_loyalty(100)
	target_city().change_vstate(newVstateId)
	var msg = "策反成功!\n{0}自立为{1}之主".format([
		ta.get_name(), target_city().get_name(), 
	])
	if targetControlNO >= 0:
		msg = "{0}大人\n{1}军之策反策略已成功\n"
		msg += "\n{2}背信弃义!\n自立为{3}之主！\n"
		msg = msg.format([
			target_vstate().get_lord_name(), 
			vstate().get_dynasty_title_or_lord_name(), 
			target_actor().get_name(), target_city().get_full_name(), 
		])
	elif sourceControlNO < 0:
		
		mood = 2
		msg = "{0}军部下{1}\n宣布自立为{2}之主".format([
			target_vstate().get_lord_name(), 
			target_actor().get_name(), target_city().get_full_name(), 
		])
	var msgs = msg.split("\n")
	msgs.append_array(extraMessages)
	append_result_messages(msgs, mood, reporter, targetCityId)
	
	var names = []
	for targetId in target_city().get_actor_ids():
		if targetId == ta.actorId:
			continue
		var a = ActorHelper.actor(targetId)
		var prevLoy = a.get_loyalty()
		
		var newLoy = int((prevLoy + 100 - abs(ta.get_moral() - a.get_moral())) / 2)
		newLoy = max(1, newLoy)
		a.set_loyalty(newLoy)
		if prevLoy - newLoy > 20:
			var leaveRate = prevLoy - newLoy - 20
			if Global.get_rate_result(leaveRate):
				clCity.move_out(targetId)
				a.set_status_exiled( - 1, - 1)
				a.set_dislike_vstate_id(newVstateId)
				names.append(a.get_name())
	if not names.empty():
		var count = names.size()
		if count > 3:
			names = names.slice(0, 1)
			names[2].append("等{0}人".format([count]))
		var emsg = "{0}心怀不满\n已下野离去".format(["、".join(names)])
		append_result_messages(emsg.split("\n"), mood, reporter, targetCityId)
	return


func ally_rate() -> void :
	var vs = vstate()
	var tv = target_vstate()
	var myCityCount = clCity.all_cities([vs.id]).size()
	var targetCityCount = clCity.all_cities([tv.id]).size()
	
	basicRate = myCityCount
	basicRate += int((actionPolitics + actionMoral - target_actor().get_politics()) / 3)
	rate = basicRate
	
	costRice = 0
	costGold = 0
	var cost = abs(targetCityCount - myCityCount) * 40 + 200
	if city().get_gold() > city().get_rice():
		costGold = cost
	else:
		costRice = cost
	
	var idx = tv.get_relation_index(vs.id)
	
	if idx < 50:
		rate = 0
	
	
	
	var idxRate = int(10.0 + 70.0 * (idx - 50) / 50.0)
	rate = max(rate, idxRate)
	SkillHelper.auto_trigger_skill(actionId, 10010)
	return


func ally_effect() -> void :
	result = 0
	var reporter = actioner().actorId
	var mood = 1
	if Global.get_rate_result(rate):
		result = 1
	SkillHelper.auto_trigger_skill(targetActorId, 10016, "")
	if result <= 0:
		var msg = "非常遗憾\n两家同盟之提议\n已被{0}拒绝".format([
			target_vstate().get_lord_name()
		])
		mood = 3
		var msgs = msg.split("\n")
		msgs.append_array(extraMessages)
		append_result_messages(msgs, mood, reporter)
		return
	return


func envoy_effect() -> void :
	
	result = 1
	var reporter = actioner().actorId
	var mood = 1
	SkillHelper.auto_trigger_skill(targetActorId, 10016, "")

	
	city().add_gold( - costGold)
	city().add_rice( - costRice)

	
	
	
	
	var effectRate = 100
	var total = costRice + costGold
	if total >= 200:
		effectRate = int(100 * 2.0 * (total - 200) / 1800.0)
	else:
		effectRate = int(100 * 0.5 * (200 - total) / 100.0)
	effectRate = max(50, effectRate)
	effectRate = min(200, effectRate)
	var basicVal = int(10.0 * effectRate / 100.0)
	
	var extraVal = int(5.0 * (actionPolitics + actionMoral) / 200)
	
	var targetLord = target_actor()
	var distance = targetLord.personality_distance(actioner())
	var lord = ActorHelper.actor(vstate().get_lord_id())
	distance = min(distance, targetLord.personality_distance(lord))
	var distanceVal = 0
	if distance <= 10:
		distanceVal = 10
	elif distance <= 30:
		distanceVal = 5
	elif distance >= 50:
		distanceVal = - 5
	var change = basicVal + extraVal + distanceVal
	change = max(1, change)
	change = min(20, change)
	var vs = vstate()
	var tv = target_vstate()
	var prevMemo = tv.get_relation_index_memo(vs.id)
	var current = tv.get_relation_index(vs.id)
	var updated = tv.relation_index_change(vs.id, change)
	var memo = tv.get_relation_index_memo(vs.id)
	change = updated - current
	var msg = "可喜可贺\n两家关系有所改善"
	if change > 10:
		msg = "可喜可贺\n两家关系大幅改善"
	if memo != prevMemo:
		msg += "\n{0}对我军的态度变为：{1}"
	else:
		msg += "\n{0}对我军的态度现为：{1}"
	msg = msg.format([tv.get_lord_name(), memo])
	var msgs = msg.split("\n")
	append_result_messages(msgs, mood, reporter)
	return



func append_extra_effect(source: String, actorId: int, val: int) -> void :
	if not source in extraEffects:
		extraEffects[source] = {}
	extraEffects[source][str(actorId)] = val
	return


static func get_canvass_rate(fromActorId: int, targetActorId: int, fromActorPolitics: int, fromActorMoral: int, fromActorLevel: int) -> int:
	
	var thresholds = [30, 40, 50, 60, 70]
	var params = [[5000, 250], [4000, 450], [3000, 900], [2000, 1300], [1000, 2000]]
	var rate = 0
	if fromActorPolitics + fromActorMoral == 0:
		return 0
	var ta = ActorHelper.actor(targetActorId)
	var loy = ta.get_loyalty()
	
	var fromActor = ActorHelper.actor(fromActorId)
	var distance = ta.personality_distance(fromActor)
	loy -= int((35 - distance) / 4)
	for i in thresholds.size():
		if loy <= thresholds[i]:
			rate = int((fromActorPolitics * fromActorMoral + params[i][0] + (fromActorLevel - 1) * 100.0) / params[i][1])
			break
	return rate


func rescue_rate() -> void :
	var vs = vstate()
	var tv = target_vstate()
	var targetLord = ActorHelper.actor(tv.get_lord_id())
	if costRice >= 0:
		
		if costRice == 99999:
			
			var captured = null
			var maxScore = - 99999
			for city in clCity.all_cities([vstate().id]):
				for capturedId in city.get_ceil_actor_ids():
					var capturedActor = ActorHelper.actor(capturedId)
					if capturedActor.get_prev_vstate_id() != target_vstate().id:
						continue
					var score = capturedActor.get_power_score()
					if score > maxScore:
						maxScore = score
						captured = capturedActor
			if captured == null:
				
				basicRate = 0
			else:
				
				basicRate = 100
				costGold = captured.actorId
		else:
			
			basicRate = 100
			costGold = costRice
	else:
		
		
		basicRate = int(costGold / 20)
		basicRate += int((actionPolitics + actionMoral - targetLord.get_wisdom()) / 3)
		
		if tv.get_relation_index(vs.id) < 50:
			basicRate -= 10
		else:
			basicRate += 10
		basicRate = max(5, basicRate)
		basicRate = min(90, basicRate)
		
	rate = basicRate
	SkillHelper.auto_trigger_skill(actionId, 10010)
	return


func rescue_effect() -> void :
	var vs = vstate()
	var tv = target_vstate()
	var ta = target_actor()

	result = 0
	var reporter = actioner().actorId
	var mood = 1
	if Global.get_rate_result(rate):
		result = 1
	SkillHelper.auto_trigger_skill(targetActorId, 10016, "")
	if result <= 0:
		var msg = "非常遗憾\n交涉失败了\n{0}拒绝释放{1}".format([
			tv.get_lord_name(), ta.get_name(), 
		])
		mood = 3
		var msgs = msg.split("\n")
		msgs.append_array(extraMessages)
		append_result_messages(msgs, mood, reporter)
		return

	
	clCity.move_out(ta.actorId)
	ta.set_status_officed()
	city().add_actor(ta.actorId)
	var msg = "可喜可贺！\n{0}同意释放{1}\n{2}已返回{3}".format([
		tv.get_lord_name(), ta.get_name(), 
		DataManager.get_actor_honored_title(ta.actorId, reporter), 
		city().get_full_name(), 
	])
	var msgs = msg.split("\n")
	append_result_messages(msgs, mood, reporter)
	if costRice < 0:
		
		city().add_gold( - costGold)
		target_city().add_gold(costGold)
	else:
		
		var captured = ActorHelper.actor(costGold)
		clCity.move_out(captured.actorId)
		captured.set_status_officed()
		target_city().add_actor(captured.actorId)
		msg = "作为交换\n{0}已放归{1}".format([
			captured.get_name(), target_city().get_full_name(), 
		])
		msgs = msg.split("\n")
		append_result_messages(msgs, 2, reporter)
	return
