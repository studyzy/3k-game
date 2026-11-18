extends Resource

const DEV_COST_BASE = [22, 18, 14]
const DEFENCE_COST_SET = [
	[14, 16, 18], 
	[18, 20, 22], 
	[22, 24, 26], 
]


class_name DevelopCommand


var cityId: int = - 1


var lastActionId: int = - 1


var actionId: int = - 1



var actorId: int = - 1


var type: String = ""


var actionAttr: int = 0


var devRnd: int = 0


var devLevel: int = 0


var cost: int = 0


var realCost: int = 0


var effectRate: float = 1.0


var costRate: float = 1.0


var land: int = 0
var landResult: int = 0
var comm: int = 0
var commResult: int = 0
var pop: int = 0
var popResult: int = 0
var defence: int = 0
var defenceResult: int = 0
var loyalty: int = 0
var loyaltyResult: int = 0


var experience: int = 0
var moralLeft: int = 0
var moralUp: int = 0


var randomMax: int = 0


var extraMessages: Array = []


var source: String = ""


var reported: int = 0


var delegated: int = 0


var anim: String = ""


var dialog: String = ""

func _init(_type: String, _actionId: int, _cityId: int = - 1):
	cityId = _cityId
	type = _type
	actionId = _actionId
	actorId = actionId
	if actionId >= 0:
		actionAttr = actioner().get_politics()
		for srb in SkillRangeBuff.find_for_vstate("武簿", city().get_vstate_id()):
			if srb.effectTagVal > 0:
				var msg = "因{0}【{1}】，以武力开发".format([
					ActorHelper.actor(srb.actorId).get_name(), 
					srb.skillName, 
				])
				append_extra_message(msg)
				actionAttr = actioner().get_power()
				break
	return

func city() -> clCity.CityInfo:
	return clCity.city(cityId)

func actioner() -> ActorHelper.ActorInfo:
	return ActorHelper.actor(actionId)

func actor() -> ActorHelper.ActorInfo:
	return ActorHelper.actor(actorId)


func get_save_data() -> Dictionary:
	var ret = {}
	for prop in get_property_list():
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
	for prop in get_property_list():
		if prop.name in dic:
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
	type = DataManager.get_env_str("内政-玩家-开发")
	cityId = DataManager.get_env_int("内政.开发城市")
	lastActionId = DataManager.get_env_int("内政.上次开发武将")
	actionId = DataManager.get_env_int("内政.开发武将")
	actorId = DataManager.get_env_int("内政.功德武将")
	effectRate = DataManager.get_env_float("内政.效果倍率")
	costRate = DataManager.get_env_float("内政.费用倍率")
	actionAttr = DataManager.get_env_int("内政.开发属性")
	return


func decide_cost() -> void :
	SkillHelper.auto_trigger_skill(actionId, 10002)

	
	
	var srb = SkillRangeBuff.max_for_city("开发能力加成", cityId)
	if srb != null:
		var fromActor = ActorHelper.actor(srb.actorId)
		var extra = int(fromActor.get_politics() * srb.effectTagVal / 100.0)
		if extra > 0:
			actionAttr += extra
			append_extra_message("{0}【{1}】提供{2}点政治加成".format([
				fromActor.get_name(), srb.skillName, extra, 
			]))

	
	anim = "Town_Develop_Farm_00"

	if type == "防灾":
		
		var idx = int(actionAttr / 40)
		idx = min(max(0, idx), DEFENCE_COST_SET.size() - 1)
		var costs = DEFENCE_COST_SET[idx].duplicate()
		costs.shuffle()
		cost = costs[0]
		dialog = "为预防灾害\n需{0}两金".format([get_real_cost()])
		return

	lastActionId = actionId

	devLevel = 2
	if actionAttr >= 80:
		devLevel = 0
	elif actionAttr >= 40:
		devLevel = 1
	var lo = 0
	var hi = 3
	if randomMax:
		
		hi = lo
	devRnd = Global.get_random(lo, hi)
	cost = int(DEV_COST_BASE[devLevel] + (2 - devRnd) * 2)

	
	var developSetting = StaticManager.get_develop_setting()
	var develop_gif_groups = developSetting["develop_gif_groups"]
	var develop_ask_dialog = developSetting["develop_ask_dialog"]
	var animation_name = developSetting["animation_name"]
	var dialogId = develop_gif_groups[type][devLevel][devRnd]
	while dialogId == - 1:
		var r = Global.get_random(0, 4)
		dialogId = develop_gif_groups[type][devLevel][r]
	anim = animation_name[type][dialogId]
	dialog = develop_ask_dialog[type][dialogId]
	dialog = dialog.replace("@cost", str(get_real_cost()))

	return

func get_real_cost() -> int:
	realCost = int(cost * costRate)
	return realCost


func execute() -> void :
	
	var lo = 6
	var hi = 10
	if type != "防灾":
		
		lo = 10
		hi = 17
	if randomMax:
		lo = hi
	var rnd = Global.get_random(lo, hi)
	land = 0
	comm = 0
	pop = 0
	defence = 0
	loyalty = 1
	var equipAdded = actioner().get_equip_feature_total("开发提升")
	var popAdded = actioner().get_equip_feature_total("开发附加人口")
	match type:
		"土地":
			land = int(cost * effectRate * actionAttr / 100.0 * rnd / 10)
			land += equipAdded
			if land >= 32:
				loyalty = 2
			pop = popAdded
		"产业":
			comm = int(cost * effectRate * actionAttr / 100.0 * rnd / 10)
			comm += equipAdded
			if comm >= 32:
				loyalty = 2
			pop = popAdded
		"人口":
			pop = int(cost * effectRate * actionAttr / 100.0 * rnd / 10) * 100
			pop += equipAdded * 50
			if pop >= 2500:
				loyalty = 2
		"防灾":
			defence = int(cost * effectRate * actionAttr / 100.0 * rnd / 10)

	var experience = land * 10 + comm * 10 + int(pop / 10) + defence * 10

	SkillHelper.auto_trigger_skill(actorId, 10018, "")

	var city = city()
	city.add_city_property("金", - get_real_cost())
	land = city.add_city_property("土地", land)
	landResult = city.get_land()
	comm = city.add_city_property("产业", comm)
	commResult = city.get_eco()
	pop = city.add_city_property("人口", pop)
	popResult = city.get_pop()
	defence = city.add_city_property("防灾", defence)
	defenceResult = city.get_defence()
	loyalty = city.add_loyalty(loyalty)
	loyaltyResult = city.get_loyalty()

	
	var rate = SkillRangeBuff.max_val_for_city("开发经验倍率", cityId)
	if rate > 0:
		experience = int(experience * rate / 100.0)
	experience = actioner().add_exp(experience)
	var leader = city.get_leader()
	var extraExp = 0
	var extraExpSource = null
	for item in leader.get_equip_feature_all("太守开发经验督导"):
		var equip = item[0]
		var val = item[1]
		if val > extraExp:
			extraExp = val
			extraExpSource = equip
	if extraExp > 0 and extraExpSource != null:
		experience += actioner().add_exp(extraExp)
		var msg = "{0}「{1}」督导".format([
			leader.get_name(), extraExpSource.name(), 
		])
		append_extra_message(msg)
		msg = "{0}获得额外开发经验{1}".format([
			actioner().get_name(), extraExp, 
		])
		append_extra_message(msg)

	check_actor_develop_exp()
	SkillHelper.auto_trigger_skill(actorId, 10019)
	return


func check_actor_develop_exp() -> void :
	moralLeft = 0
	moralUp = 0
	if DataManager.get_game_setting("武将成长") in ["禁读书", "就不加"]:
		return

	
	var actor = actor()
	actor.inc_dev_exp()
	var moral = actor._get_attr_int_original("德")
	if moral >= 99:
		return
	var expRequired = 10
	moralUp = 1
	if moral < 40:
		expRequired = 3
		moralUp = 4
	elif moral < 70:
		expRequired = 5
		moralUp = 3
	elif moral < 90:
		expRequired = 7
		moralUp = 2

	
	var devExp = actor.get_dev_exp()
	if devExp >= expRequired:
		actor.set_moral(min(99, moral + moralUp))
		moralUp = actor._get_attr_int_original("德") - moral
		actor.clear_dev_exp()
	else:
		moralUp = 0
		moralLeft = expRequired - devExp
	return

func append_extra_message(msg: String) -> void :
	extraMessages.append_array(msg.split("\n"))
	return

func get_notice() -> String:
	var msgs = get_result_messages()
	if msgs.size() > 3:
		msgs = msgs.slice(0, 2)
	return "\n".join(msgs)

func get_result_messages() -> PoolStringArray:
	var ret = []
	ret.append_array(extraMessages)
	if land > 0:
		ret.append("土地值上升{0}".format([land]))
	if comm > 0:
		ret.append("产业值上升{0}".format([comm]))
	if pop > 0:
		ret.append("人口增加{0}".format([pop]))
	if defence > 0:
		ret.append("防灾值上升{0}".format([defence]))
	if loyalty > 0:
		ret.append("统治度上升{0}".format([loyalty]))
	if loyalty < 0:
		ret.append("统治度下降{0}".format([ - loyalty]))

	if actorId != actionId:
		var msg = "民众感念{0}的恩泽".format([
			DataManager.get_actor_honored_title(actorId, actionId)
		])
		ret.append(msg)
	if moralUp > 0:
		var msg = "{0}德(+{1})上升至{2}".format([
			actor().get_name(), moralUp, actor().get_moral()
		])
		ret.append(msg)
	elif moralLeft > 0:
		var msg = "（距离涨德还需开发{0}次".format([moralLeft])
		ret.append(msg)
	return ret

func affair_report() -> void :
	if reported > 0:
		return
	var logs = []
	var city = city()
	logs.append("  - <r{0}>为<y{1}>执行<y{2}>开发".format([
		actioner().get_name(), city.get_name(), type, 
	]))
	if land > 0:
		logs.append("  - 土地值上升<y{0}> -> {1}".format([
			land, landResult, 
		]))
	if comm > 0:
		logs.append("  - 产业值上升<y{0}> -> {1}".format([
			comm, commResult, 
		]))
	if pop > 0:
		logs.append("  - 人口增加<y{0}> -> {1}".format([
			pop, popResult, 
		]))
	if defence > 0:
		logs.append("  - 防灾值上升<y{0}> -> {1}".format([
			defence, defenceResult, 
		]))
	if loyalty > 0:
		logs.append("  - 统治度上升<y{0}> -> {1}".format([
			loyalty, loyaltyResult, 
		]))

	if moralUp > 0:
		logs.append("  - <r{0}>德上升 <y{1}> -> {2}".format([
			actor().get_name(), moralUp, actor().get_moral(), 
		]))
	elif moralLeft > 0:
		logs.append("  - 距离涨德还需开发{0}次".format([moralLeft]))

	DataManager.record_affair_log("\n".join(logs), true)
	reported = 1
	return
