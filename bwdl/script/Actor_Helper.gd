extends Node
class_name Actor_Helper

const AVATAR_GROUP_SIZE = 75

var status_change_ghistory = []



class ActorInfo:
	const EXP_MAX = 99999
	
	
	const LEARNING_ATTRS = [
		"体", "知", "武", "政", "统", "胆", 
	]

	
	const LEVELUP_ATTRS = ["武", "统", "知", "政"]

	const ATTR_DICT = {
		"登场年": {"min": - 1, "max": 99999}, 
		"开发经验": {"min": 0, "max": 99}, 
		"原体力": {"min": 1, "max": 99}, 
		"体": {"min": - 1, "max": 999}, 
		"知": {"min": 1, "max": 99}, 
		"武": {"min": 1, "max": 99}, 
		"德": {"min": 1, "max": 99}, 
		"政": {"min": 1, "max": 99}, 
		"统": {"min": 1, "max": 99}, 
		"胆": {"min": 1, "max": 99}, 
		"忠": {"min": 0, "max": 100}, 
		"大限": {"min": 0, "max": 99999}, 
		"体上限": {"min": 0, "max": 99}, 
		"等级": {"min": 1, "max": 8}, 
		"经验值": {"min": 0, "max": 99999}, 
		"武器": {"min": 0, "max": 99999}, 
		"防具": {"min": 0, "max": 99999}, 
		"道具": {"min": 0, "max": 99999}, 
		"坐骑": {"min": 0, "max": 99999}, 
		"临时兵力": {"min": 0, "max": 10000}, 
		"基础兵力": {"min": 0, "max": 10000}, 
		"厌恶势力": {"min": - 999, "max": 999}, 
		"流放地": {"min": 0, "max": 999}, 
		"原势力": {"min": 0, "max": 999}, 
		"初势力": {"min": - 999, "max": 999}, 
		"原等级": {"min": 1, "max": 8}, 
		"兵力": {"min": 0, "max": 10000}, 
		"头像切换": {"min": 0, "max": 999}, 
	}

	
	var id: int
	var actorId: int
	var faked: bool = false

	func _init(_actorId: int):
		if _actorId >= StaticManager.ACTOR_ID_RENOU:
			_actorId -= StaticManager.ACTOR_ID_RENOU
			faked = true
		if _actorId < 0 or _actorId >= DataManager.actors.size():
			if _actorId != StaticManager.ACTOR_ID_SLIME_GOD:
				actorId = - 1
				return
		actorId = _actorId
		id = actorId
		return

	func _has_attr(key: String) -> bool:
		if actorId < 0:
			return false
		return DataManager.actors[actorId].has(key)

	func _remove_attr(key: String) -> void :
		if actorId < 0:
			return
		DataManager.actors[actorId].erase(key)
		return

	
	func _get_attr(key: String):
		if actorId < 0:
			return null
		if key in ATTR_DICT:
			return _get_attr_int(key)
		if not DataManager.actors[actorId].has(key):
			return null
		return DataManager.actors[actorId][key]

	
	func _set_attr(key: String, val) -> void :
		if actorId < 0:
			return
		DataManager.actors[actorId][key] = val
		return

	func _get_attr_str(key: String) -> String:
		if actorId < 0:
			return ""
		if not DataManager.actors[actorId].has(key):
			return ""
		return str(DataManager.actors[actorId][key])

	func _get_attr_float(key: String) -> float:
		if actorId < 0:
			return - 1.0
		if not DataManager.actors[actorId].has(key):
			return - 1.0
		if str(DataManager.actors[actorId][key]) == "":
			return - 1.0
		var ret = float(DataManager.actors[actorId][key])
		return ret

	func _get_attr_int_original(key: String) -> int:
		if actorId < 0:
			return - 1
		if not DataManager.actors[actorId].has(key):
			return - 1
		if str(DataManager.actors[actorId][key]) == "":
			return - 1
		return Global.intval(DataManager.actors[actorId][key])

	
	func _get_attr_max(attr: String, current: int) -> int:
		if not attr in ATTR_DICT:
			return 99999
		if not "max" in ATTR_DICT[attr]:
			return 99999
		var ret = Global.intval(ATTR_DICT[attr]["max"])
		
		if attr == "忠" and current < 100:
			var extra = _get_attr_str("额外忠上限")
			if extra != "":
				
				
				ret = 99 + Global.intval(extra, 0)
		return ret

	func _get_attr_int(key: String) -> int:
		var val = _get_attr_int_original(key)
		if val < 0:
			return val
		var limit = _get_attr_max(key, val)
		if limit > 0:
			val = min(val, limit)
		if key in ["武", "知", "统", "胆", "政"]:
			var sceneId = DataManager.get_current_scene_id()
			if sceneId >= 10000:
				if val < 90 and _has_attr("附" + key):
					val = val + int(_get_attr("附" + key))
					val = min(90, val)
				if val < 99 and _has_attr("临" + key):
					val = val + int(_get_attr("临" + key))
					val = min(99, val)
			if sceneId >= 20000:
				var wa = DataManager.get_war_actor(actorId)
				if wa != null:
					if wa.get_buff_label_turn(["中毒"]) > 0:
						val = int(val * 0.9)
					if val < 90:
						val = min(90, val + wa.get_ext_variable("附" + key, 0))
					val = val + wa.get_ext_variable("临" + key, 0)
					var formula = str(wa.get_ext_variable("临" + key + "公式", ""))
					if formula != "":
						
						
						var wf = DataManager.get_current_war_fight()
						formula = formula.replace("<WARDAY>", wf.date)
						formula = formula.replace("<SOLDIERS>", get_soldiers())
						val = val + int(Global.execute_expression(formula))
					if sceneId == 20000:
						
						val = min(99, val)
		if key in ["武", "知", "统", "胆", "德"]:
			val += get_equip_feature_total("附加" + key)
		if key == "兵力":
			val = max(0, val)
			val = min(3000, val)
		return val

	func _set_attr_float(key: String, val: float) -> void :
		if actorId < 0:
			return
		if not key in ATTR_DICT:
			return
		val = max(float(ATTR_DICT[key]["min"]), val)
		val = min(_get_attr_max(key, val), val)
		DataManager.actors[actorId][key] = val
		return

	func _set_attr_int(key: String, val: int) -> void :
		if actorId < 0:
			return
		if not key in ATTR_DICT:
			return
		val = max(int(ATTR_DICT[key]["min"]), val)
		var limit = _get_attr_max(key, val)
		val = min(limit, val)
		DataManager.actors[actorId][key] = val
		return

	
	func _set_attr_str(key: String, val: String) -> void :
		if actorId < 0:
			return
		DataManager.actors[actorId][key] = val
		return
	
	
	func set_diy_skills(dic: Dictionary):
		if actorId != StaticManager.ACTOR_ID_DIY:
			return ;
		var skills = {
			"LV1": "", 
			"LV2": "", 
			"LV3": "", 
			"LV4": "", 
			"LV5": "", 
			"LV6": "", 
			"LV7": "", 
			"LV8": "", 
		}
		for key in skills:
			if dic.has(key):
				skills[key] = str(dic[key])
		
		var skillsData = JSON.print(skills).to_utf8()
		var encrypted = clAes.ECB_Encrypted(skillsData).hex_encode().to_ascii()
		
		var signed = StaticManager.crypto_sign_short(encrypted)
		encrypted.append_array(signed)
		encrypted.append(signed.size())
		encrypted.append(2)
		_set_attr_str("diy_skills", encrypted.hex_encode())
		return ;
	
	
	func get_diy_skills() -> Dictionary:
		if actorId != StaticManager.ACTOR_ID_DIY:
			
			return {}
		var skills = _get_attr_str("diy_skills")
		if skills == "":
			return {}
		
		var oldversion = false
		
		var priorVersion = false
		var decrypted: PoolByteArray = []
		if skills.begins_with("Pool"):
			var saved = str2var(skills)
			if typeof(saved) == TYPE_RAW_ARRAY:
				
				decrypted = clAes.ECB_Decrypted(saved)
				oldversion = true
		else:
			
			var encrypted = PoolByteArray(Global.hex_decode(skills))
			var sign_version = encrypted[encrypted.size() - 1]
			var signed_len = encrypted[encrypted.size() - 2]
			var signed = encrypted.subarray(encrypted.size() - signed_len - 2, encrypted.size() - 3)
			encrypted = encrypted.subarray(0, encrypted.size() - signed_len - 3)
			if not StaticManager.crypto_verify_short(encrypted, signed):
				return {}
			if sign_version == 1:
				decrypted = clAes.ECB_Decrypted(encrypted)
				priorVersion = true
			elif sign_version == 2:
				encrypted = Global.hex_decode(encrypted.get_string_from_ascii())
				decrypted = clAes.ECB_Decrypted(encrypted)
			else:
				return {}
		if decrypted.empty():
			return {}
		var dic = parse_json(decrypted.get_string_from_utf8())
		if dic == null:
			dic = {}
		if oldversion:
			for k in dic:
				if dic[k] != "" and not dic[k] in StaticManager.old_skills:
					dic[k] = ""
			set_diy_skills(dic)
		elif priorVersion:
			set_diy_skills(dic)
		return dic

	
	func get_exp() -> int:
		var ret = 0
		if _has_attr("经验值"):
			ret = _get_attr_int("经验值")
		else:
			ret = int(_get_attr_float("经验") * 100)
			_set_attr_int("经验值", ret)
		return ret

	
	
	func add_exp(val: int) -> int:
		var current = get_exp()
		set_exp(current + val)
		var ret = get_exp() - current
		if ret > 0 and DataManager.get_current_scene_id() >= 20000:
			SkillHelper.auto_trigger_skill(actorId, 20043)
		return ret

	
	
	func check_levelup() -> Array:
		var levelUpSettings = StaticManager.get_levelup_setting()
		var requirements = PoolIntArray(levelUpSettings["所需经验"])
		
		var ret = []
		while true:
			var level = get_level()
			var current = get_exp()
			if level >= requirements.size():
				break
			
			if requirements[level] * 100 > current:
				break
			ret.append(levelup())
		if DataManager.get_current_scene_id() >= 20000:
			append_levelup_trackings(ret)
		return ret

	
	
	func levelup(dataOnly: bool = false) -> Dictionary:
		var ret = {}
		var level = get_level()
		ret["level"] = level + 1
		ret["attrs"] = {}
		ret["skills"] = []
		if not dataOnly:
			var loyalty = get_loyalty()
			if loyalty < 70:
				set_loyalty(get_loyalty() + 5)
				var current = get_loyalty()
				ret["attrs"]["忠"] = [current - loyalty, current]
		var specifiedAttr = ""
		if get_equip_feature_max("强制统系") > 0:
			specifiedAttr = "统"
		var props = {}
		for prop in LEVELUP_ATTRS:
			props[prop] = _get_attr_int_original(prop)
		var lvlups = _check_levelup_props(props, specifiedAttr)
		for lvlup in lvlups:
			var prop = str(lvlup[0])
			var val = int(lvlup[1])
			if val <= 0:
				continue
			if lvlup.size() >= 2:
				var prev = _get_attr_int_original(prop)
				_set_attr_int(prop, prev + val)
				var current = _get_attr_int_original(prop)
				ret["attrs"][prop] = [current - prev, current]
			if not dataOnly\
			and lvlup.size() == 4:
				var wa = DataManager.get_war_actor(actorId)
				if wa != null:
					var msg = "{0}\n（升至{1}级，触发【{2}】\n（{3}额外+{4}，现为{5}".format([
						lvlup[3], level + 1, lvlup[2], prop, val, _get_attr_int_original(prop), 
					])
					wa.attach_free_dialog(msg, 1)
		var prevUnlocked = SkillHelper.get_actor_unlocked_skill_names(actorId)
		set_level(level + 1)
		var currentUnlocked = SkillHelper.get_actor_unlocked_skill_names(actorId)
		for key in currentUnlocked:
			if key in prevUnlocked:
				continue
			ret["skills"].append(currentUnlocked[key])
		if not dataOnly:
			var msg = "- <y{0}>升至<r{1}>级".format([get_name(), get_level()])
			for attr in ret["attrs"]:
				msg += "\n  - <r{0}>升至<r{1}>".format([attr, ret["attrs"][attr][1]])
			for skill in ret["skills"]:
				msg += "\n  - 解锁新技能【<r{0}>】".format([skill])
			DataManager.record_war_log(msg)
		return ret

	
	
	
	
	func _check_levelup_props(props: Dictionary, specifiedAttr: String = "", considerSkill: bool = true) -> Array:
		if DataManager.get_game_setting("武将成长") in ["升级不加", "就不加"]:
			return []
		
		props = props.duplicate(true)
		var ret = []
		var levelUpSettings = StaticManager.get_levelup_setting()
		
		var sortedAttrs = []
		
		for i in LEVELUP_ATTRS.size():
			var attr = LEVELUP_ATTRS[i]
			var current = props[attr]
			for j in sortedAttrs.size():
				var attrs = sortedAttrs[j]
				if props[sortedAttrs[j]] < current:
					sortedAttrs.insert(j, attr)
					break
			if not sortedAttrs.has(attr):
				sortedAttrs.append(attr)
		
		if sortedAttrs.has(specifiedAttr):
			sortedAttrs.erase(specifiedAttr);
			sortedAttrs.insert(0, specifiedAttr)

		var levelups = Array(levelUpSettings["提升档位"])
		var limits = [90, 85, 80, 75, 70, 65]
		
		for i in sortedAttrs.size():
			var attr = sortedAttrs[i]
			if props[attr] > limits[i]:
				continue
			
			var upValue = 0
			for levelup in levelups:
				if props[attr] > levelup[0]:
					continue
				upValue = levelup[1]
				break
			if upValue > 0:
				
				
				props[attr] += upValue
				ret.append([attr, upValue])
				break
		
		if considerSkill:
			var skillSpecials = [
				["知", "知略", "拨云见日，茅塞顿开！"], 
				["统", "统略", "百战不殆，方得明悟！"], 
				["武", "练锁", "百炼千锤，真金始见！"], 
			]
			for setting in skillSpecials:
				var prop = setting[0]
				var skill = setting[1]
				var notice = setting[2]
				if not SkillHelper.actor_has_skills(actorId, [skill]):
					continue
				var current = props[prop]
				if current >= 90:
					continue
				var specialProps = {"知": 0, "武": 0, "统": 0, "政": 0}
				specialProps[prop] = current
				var specialLvlups = _check_levelup_props(specialProps, prop, false)
				if specialLvlups.empty():
					continue
				ret.append([
					specialLvlups[0][0], specialLvlups[0][1], 
					skill, notice, 
				])
		return ret

	
	func get_dev_exp() -> int:
		return int(max(0, _get_attr_int("开发经验")))

	
	func inc_dev_exp() -> void :
		var val = get_dev_exp()
		_set_attr_int("开发经验", val + 1)
		return

	
	func clear_dev_exp() -> void :
		_set_attr_int("开发经验", 0)
		return

	func set_exp(val: int) -> void :
		_set_attr_int("经验值", val)
		_remove_attr("经验")
		return

	func get_level() -> int:
		return _get_attr_int("等级")

	func set_level(lv: int) -> void :
		_set_attr_int("等级", lv)
		return

	func is_exp_full() -> bool:
		return get_exp() >= EXP_MAX

	func get_hp() -> float:
		return _get_attr_float("体")

	
	
	func get_max_hp(simulatedLevel: int = - 1, simulatedExtra: int = - 1, originalValue: bool = false) -> int:
		var original = _get_attr_int("原体力")
		if original <= 0:
			original = int(StaticManager.actors[actorId]["体"])
		var level = get_level()
		if simulatedLevel > 0:
			level = simulatedLevel
		var calculated = 0
		if DataManager.diffculities < 3:
			
			calculated = level * 10 + int(original / 10)
		var max_hp = max(original, calculated)
		var extra = _get_attr_int("体上限")
		if simulatedExtra >= 0:
			extra = simulatedExtra
		if extra > 0:
			max_hp += extra
		max_hp = max(10, max_hp)
		max_hp = min(99, max_hp)
		if originalValue:
			return max_hp
		if DataManager.get_current_scene_id() >= 20000:
			var wa = DataManager.get_war_actor(actorId)
			if wa != null:
				var extraDic = Global.dicval(wa.get_ext_variable("附加体力上限"))
				for key in extraDic:
					var val = Global.intval(extraDic[key])
					max_hp += val
		
		
		if DataManager.get_current_scene_id() == 10000:
			if get_loyalty() == 100:
				var city = DataManager.get_office_city_by_actor(actorId)
				if city != null:
					var buffed = SkillRangeBuff.max_val_for_city("内政附加体上限", city.ID)
					if buffed > 0:
						max_hp += buffed
		
		max_hp += get_equip_feature_total("附加体上限")
		return max_hp

	
	func is_injured() -> bool:
		return get_max_hp() > int(get_hp())

	func set_hp(val: float) -> void :
		_set_attr_float("体", val)
		return

	
	
	
	func recover_hp(val: int, forceLimited: bool = false) -> int:
		var current = int(ceil(get_hp()))
		var hp = current + val
		hp = min(get_max_hp(), hp)
		
		if val > 0 and hp < current and not forceLimited:
			return 0
		set_hp(hp)
		return hp - current

	func set_equip(equip: clEquip.EquipInfo) -> bool:
		if faked:
			return false
		if not equip.type in StaticManager.EQUIPMENT_TYPES:
			return false
		_set_attr_int(equip.type, equip.id)
		if equip.equip_disabled():
			
			
			
			
			DataManager.disable_actor_equip(20000, actorId, equip)
		return true

	func get_equip(type: String) -> clEquip.EquipInfo:
		if not type in StaticManager.EQUIPMENT_TYPES:
			return clEquip.equip( - 999, type)
		var equipId = _get_attr_int(type)
		
		var battleEquipId = - 1
		var sceneId = DataManager.get_current_scene_id()
		if sceneId >= 30000:
			var bf = DataManager.get_current_battle_fight()
			var key = "临时{0}.{1}".format([type, actorId])
			battleEquipId = bf.get_env_int(key)
			if battleEquipId >= 0:
				equipId = battleEquipId
		var ret = clEquip.equip(equipId, type)
		if battleEquipId == equipId:
			ret.battleTemporary = true
		var disabled = get_disabled_equip_types()
		if type in disabled:
			ret.disabled = true
			ret.disabledEquipOnly = false
		elif type + "|" + str(ret.id) in disabled:
			ret.disabled = true
			ret.disabledEquipOnly = true
		return ret

	func get_weapon() -> clEquip.EquipInfo:
		return get_equip("武器")

	func get_weapon_types() -> PoolStringArray:
		return get_weapon().get_all_types()

	func get_suit() -> clEquip.EquipInfo:
		return get_equip("防具")

	func get_jewelry() -> clEquip.EquipInfo:
		return get_equip("道具")

	func get_steed() -> clEquip.EquipInfo:
		return get_equip("坐骑")

	
	func set_battle_equip(type: String, equipId: int) -> void :
		var key = "临时{0}.{1}".format([type, actorId])
		var bf = DataManager.get_current_battle_fight()
		if equipId < 0:
			bf.unset_env(key)
		else:
			bf.set_env(key, equipId)
		return

	
	func get_steed_power() -> int:
		var val = get_steed().get_steed_power()
		var dynamicVal = get_equip_feature_max("动态马力")
		if dynamicVal > 0:
			val = dynamicVal
		if DataManager.get_current_scene_id() < 20000:
			return val
		var wa = DataManager.get_war_actor(actorId)
		if wa == null or wa.disabled or not wa.has_position():
			return val
		if wa.dic_other_variable.has("额外马力"):
			val += int(wa.dic_other_variable["额外马力"])
		return val

	
	
	func equip_total_weight() -> int:
		var total = weapon_weight() + suit_weight() + jewelry_weight() + steed_weight()
		total -= get_equip_feature_total("重量降低")
		return total

	
	func weapon_weight() -> int:
		var weapon = get_weapon()
		var ret = weapon.weight()
		for setting in weapon.features():
			ret += get_equip_feature_int(setting, "重量加成")
		return ret

	
	func suit_weight() -> int:
		return get_suit().weight()

	
	func jewelry_weight() -> int:
		return get_jewelry().weight()

	
	func steed_weight() -> int:
		return get_steed().weight()

	func set_loyalty(val: int) -> void :
		_set_attr_int("忠", val)
		return

	func get_loyalty() -> int:
		return _get_attr_int("忠")

	
	
	func add_loyalty(val: int) -> int:
		var current = get_loyalty()
		val = min(val, 99 - current)
		set_loyalty(current + val)
		return val

	
	func surrend_loyalty(targetVstateId: int) -> int:
		var ret = max(10, 79 - get_loyalty())
		var targetVS = clVState.vstate(targetVstateId)
		ret = max(ret, SkillRangeBuff.max_val_for_actor("加入最低忠诚度", targetVS.get_lord_id()))
		return ret

	func get_courage() -> int:
		return _get_attr_int("胆")

	func get_leadership() -> int:
		return _get_attr_int("统")

	func get_politics() -> int:
		return _get_attr_int("政")

	func get_power() -> int:
		
		
		
		
		
		var val = _get_attr_int("武")
		if DataManager.get_current_scene_id() < 20000:
			return val
		var wa = DataManager.get_war_actor(actorId)
		if wa == null or wa.disabled or not wa.has_position():
			return val
		if wa.dic_other_variable.has("武环"):
			val = max(val, int(wa.dic_other_variable["武环"]))
		return val

	func get_wisdom() -> int:
		
		
		
		
		
		var val = _get_attr_int("知")
		if DataManager.get_current_scene_id() < 20000:
			return val
		var wa = DataManager.get_war_actor(actorId)
		if wa == null or wa.disabled or not wa.has_position():
			return val
		if wa.dic_other_variable.has("知环"):
			val = max(val, int(wa.dic_other_variable["知环"]))
		return val

	func set_soldiers(val: int) -> void :
		_set_attr_int("兵力", val)
		return

	func get_soldiers() -> int:
		var ret = _get_attr_int("兵力")
		return ret

	func get_id() -> int:
		return actorId

	func get_first_name() -> String:
		var fn = _get_attr_str("姓")
		
		if fn == "自" and actorId == StaticManager.ACTOR_ID_DIY:
			fn = get_name().left(1)
		if fn == "":
			fn = get_name().left(1)
		return fn

	func set_first_name(fn: String) -> void :
		_set_attr_str("姓", fn)
		return

	func get_full_name() -> String:
		if actorId == StaticManager.ACTOR_ID_SLIME_GOD:
			return "史莱姆神"
		return _get_attr_str("姓名")

	func get_name() -> String:
		return get_full_name().split("#")[0]

	func get_short_name() -> String:
		var name = get_name()
		var fn = get_first_name()
		if name.begins_with(fn):
			return name.substr(fn.length())
		return "吾"

	
	func display_name() -> String:
		var name = get_name()
		if name.length() >= 4 and not "\n" in name:
			name = name.substr(0, 2) + "\n" + name.substr(2)
		return name

	func set_name(val: String) -> void :
		_set_attr_str("姓名", val)
		return

	
	func get_name_only() -> String:
		var fn = get_first_name()
		var name = get_name()
		if fn == "" or fn.length() >= name.length():
			return name
		return name.substr(fn.length())

	func get_nick() -> String:
		var ret = _get_attr_str("字").trim_prefix(" ").trim_suffix(" ")
		if ret == "0":
			_set_attr_str("字", "")
			ret = ""
		return ret

	func set_nick(val: String) -> void :
		_set_attr_str("字", val)
		return

	func set_life_limit(val: int) -> void :
		_set_attr_int("大限", val)
		return

	func get_life_limit() -> int:
		
		if "无大限" == DataManager.get_game_setting("人物大限"):
			return 99999
		return _get_attr_int("大限")

	func get_initial_vstate_id() -> int:
		return _get_attr_int("初势力")

	
	func set_initial_vstate_id(val: int) -> void :
		if get_initial_vstate_id() >= 0:
			return
		_set_attr_int("初势力", val)
		return

	func get_prev_vstate_id() -> int:
		return _get_attr_int("原势力")

	func set_prev_vstate_id(val: int) -> void :
		_set_attr_int("原势力", val)
		return

	func set_status_hidden() -> void :
		clCity.move_out(actorId)
		_set_attr_str("状态", "隐藏")
		return

	func set_status_secluded(cityId: int) -> void :
		clCity.move_out(actorId)
		_set_attr_str("状态", "隐居")
		if cityId >= 0:
			set_exile_city(cityId)
		return

	func set_status_disabled() -> void :
		clCity.move_out(actorId)
		_set_attr_str("状态", "禁用")
		return

	func set_status_officed(vstateId: int = - 1) -> void :
		_set_attr_str("状态", "出仕")
		set_hp(max(1, get_hp()))
		
		var timing = DataManager.year * 12 + DataManager.month
		var first = Global.intval(_get_attr("出仕"))
		if first < 0:
			_set_attr("出仕", timing)
		if vstateId < 0:
			return
		set_prev_vstate_id(vstateId)
		
		if StaticManager.actors[actorId].has("初势力"):
			set_initial_vstate_id(vstateId)
		return

	
	func set_status_captured(currentVstateId: int = - 1) -> void :
		_set_attr_str("状态", "俘虏")
		set_loyalty(min(99, get_loyalty()))
		if currentVstateId >= 0:
			set_prev_vstate_id(currentVstateId)
		return

	func set_status_dead(currentVstateId: int = - 1) -> void :
		clCity.move_out(actorId)
		set_hp( - 1)
		_set_attr_str("状态", "死亡")
		if currentVstateId >= 0:
			set_prev_vstate_id(currentVstateId)
		return

	
	
	func set_status_exiled(fromVstateId: int, toCityId: int) -> bool:
		var success = true
		clCity.move_out(actorId)
		if fromVstateId >= 0:
			set_prev_vstate_id(fromVstateId)
		if toCityId >= 0:
			set_exile_city(toCityId)
		
		if DataManager.is_stars_drama():
			_set_attr("星耀", DataManager.year * 12 + DataManager.month)
			
			set_status_disabled()
			success = false
		else:
			_set_attr_str("状态", "流放")
			set_loyalty(min(99, get_loyalty()))
		
		SkillHelper.auto_trigger_skill(actorId, 10009)
		return success

	func is_status_exiled() -> bool:
		return _get_attr_str("状态") == "流放"

	func is_status_disabled() -> bool:
		return _get_attr_str("状态") == "禁用"

	func is_status_hidden() -> bool:
		return _get_attr_str("状态") == "隐藏"

	func is_status_secluded() -> bool:
		return _get_attr_str("状态") == "隐居"

	func is_status_dead() -> bool:
		return _get_attr_str("状态") == "死亡"

	func is_status_officed() -> bool:
		return _get_attr_str("状态") == "出仕"

	func is_status_captured() -> bool:
		return _get_attr_str("状态") == "俘虏"

	func is_status_unofficed() -> bool:
		return _get_attr_str("状态") == "在野"

	func get_status() -> String:
		return _get_attr_str("状态")

	
	func get_tmp_soldiers() -> int:
		var ret = _get_attr_int("临时兵力")
		ret = max(0, ret)
		return ret

	
	
	
	func add_tmp_soldiers(soldiers: int) -> int:
		if not _has_attr("临时兵力"):
			_set_attr_int("临时兵力", 0)
		var current = get_soldiers()
		if not _has_attr("基础兵力"):
			
			_set_attr_int("基础兵力", current)
		_set_attr_int("临时兵力", get_tmp_soldiers() + soldiers)
		set_soldiers(current + soldiers)
		return soldiers

	
	
	func remove_tmp_soldiers() -> int:
		var current = get_soldiers()
		var tmp = get_tmp_soldiers()
		var left = current - tmp
		left = max(0, left)
		var basics = _get_attr_int("基础兵力")
		_remove_attr("临时兵力")
		_remove_attr("基础兵力")
		if basics < left:
			
			set_soldiers(left)
			return current - left
		
		set_soldiers(min(basics, current))
		return current - get_soldiers()

	
	
	
	
	func remove_extra_soldiers() -> int:
		remove_tmp_soldiers()
		
		var maxSoldiers: int = DataManager.get_actor_max_soldiers(actorId)
		var exceeded = get_soldiers() - maxSoldiers
		if exceeded > 0:
			set_soldiers(maxSoldiers)
			return exceeded
		return 0

	
	func get_dislike_vstate_id() -> int:
		if not _has_attr("厌恶势力"):
			return - 1;
		return _get_attr_int("厌恶势力")

	func set_dislike_vstate_id(val: int) -> void :
		_set_attr_int("厌恶势力", val)
		return

	func get_exiled_city_id() -> int:
		return _get_attr_int("流放地")

	
	func set_exile_city(cityId: int) -> void :
		_set_attr_int("流放地", cityId)
		return

	
	
	
	func is_side_positive() -> bool:
		return not has_side() or get_side() == "阳"

	
	func get_side(original: bool = false) -> String:
		var side = _get_attr_str("面")
		if original:
			return side
		var sceneId = DataManager.get_current_scene_id()
		if sceneId < 20000:
			return side
		var wa = DataManager.get_war_actor(actorId)
		if wa == null:
			return side
		var warSide = wa.get_war_side()
		if warSide != "":
			return warSide
		return side

	
	func set_side(side: String) -> void :
		_set_attr_str("面", side)
		return

	
	func has_side() -> bool:
		if actorId < 0 or actorId >= StaticManager.actors.size():
			return false
		return StaticManager.actors[actorId].has("面")

	func get_moral() -> int:
		return _get_attr_int("德")

	func set_moral(val: int) -> void :
		_set_attr_int("德", val)
		return

	
	func get_items() -> Dictionary:
		var items = _get_attr("items")
		if items == null or typeof(items) != TYPE_DICTIONARY:
			return {}
		return items

	
	func set_item_count(id: int, cnt: int) -> void :
		var items = get_items()
		items[str(id)] = cnt
		_set_attr("items", items)
		return

	
	func reset_levelup_trackings() -> void :
		_remove_attr("升级记录")
		return

	
	func append_levelup_trackings(records: Array) -> void :
		var history = get_levelup_trackings()
		history.append_array(records)
		_set_attr("升级记录", history)
		return

	
	func get_levelup_trackings() -> Array:
		return Global.arrval(_get_attr("升级记录"))

	func get_gender() -> String:
		return _get_attr_str("性别")

	func is_male() -> bool:
		var gender = get_gender()
		if gender != "男":
			return false
		if SkillRangeBuff.max_val_for_actor("空巢", actorId) > 0:
			return false
		return true

	func set_gender(val: String) -> void :
		_set_attr_str("性别", val)
		return

	func get_avatar() -> String:
		return _get_attr_str("头像")

	func set_avatar(val: String) -> void :
		_set_attr_str("头像", val)
		return

	func switch_avatar() -> void :
		var current = _get_attr_int("头像切换")
		var setting = get_avatar_setting()
		var maxOptional = setting[3]
		if current < 0:
			current = setting[2]
		if current < 0 or maxOptional < 1:
			
			return
		current = (current + 1) % maxOptional
		_set_attr_int("头像切换", current)
		return

	
	
	
	
	
	
	func get_avatar_setting() -> Array:
		var ret = [0, null, - 1, - 1]
		var options = get_avatar_options()
		if options.empty():
			return ret
		var decided = options[0]
		var selected = _get_attr_int("头像切换")
		if selected >= 0 and selected < options.size():
			decided = options[selected]
		else:
			selected = 0
		ret[0] = decided["sort"]
		ret[1] = decided["img"]
		ret[2] = selected
		ret[3] = options.size()
		return ret

	func get_avatar_options() -> Array:
		var options = []
		
		var page = int(actorId / AVATAR_GROUP_SIZE)
		var defaultOption = {
			"sort": actorId % AVATAR_GROUP_SIZE, 
			"img": StaticManager.basic_avatars[page], 
		}
		
		var specified = _get_attr_str("头像")
		if specified != "":
			var img = null
			var idx = 0
			if specified.begins_with("自定义/"):
				specified = specified.trim_prefix("自定义/")
				if specified in StaticManager.extra_avatars:
					img = StaticManager.extra_avatars[specified]
			elif specified.begins_with("原版/"):
				idx = Global.intval(specified.trim_prefix("原版/"))
				var perImage = int(StaticManager.ORIGINAL_AVATAR_PER_HEIGHT)
				if not StaticManager.original_avatars.empty():
					var firstTex = StaticManager.original_avatars[0]
					perImage = int(firstTex.get_height() / StaticManager.ORIGINAL_AVATAR_PER_HEIGHT)
				var imgIdx = int(idx / perImage)
				var localIdx = idx % perImage
				if imgIdx < StaticManager.original_avatars.size():
					img = StaticManager.original_avatars[imgIdx]
					idx = localIdx
			else:
				var path = "res://resource/images/actor/face/{0}.png".format([specified])
				if specified.begins_with("mod/"):
					specified = specified.replace("mod/", "mod/avatars/")
					specified = specified.replace("mod/avatars/avatars/", "mod/avatars/")
					var filename = specified.get_file()
					var extname = filename.get_extension()
					if extname == "":
						specified += ".png"
					path = "{0}{1}".format([DataManager.get_common_path(), specified])
				img = Global.load_pic_with_cache(path)
			if img != null:
				defaultOption["img"] = img
				defaultOption["sort"] = idx
		options.append(defaultOption)

		
		var multiSetting = []
		if str(actorId) in StaticManager.multi_face:
			multiSetting = StaticManager.multi_face[str(actorId)]
		for setting in multiSetting:
			var matched = true
			for condition in setting["if"]:
				
				if not _check_condition(condition):
					matched = false
					break
			if not matched:
				continue
			var option = setting["then"].duplicate()
			option["img"] = StaticManager.basic_avatars[int(option["picture"])]
			if not "optional" in option:
				
				option["id"] = 0
				options = [option]
				break
			
			options.append(option)

		
		options.invert()
		var idx = 0
		for option in options:
			option["id"] = idx
			idx += 1

		
		var extraOptions = []
		var name = get_full_name()
		var sideOption = {}
		if has_side() or not get_side() in ["", "阳"]:
			
			for extname in ["", ".png", ".jpg", ".jpeg", ".webp"]:
				var key = name + "#" + get_side() + extname
				var option = _probe_external_avatar_option(key)
				if option.empty():
					continue
				sideOption = option
				break
		if not sideOption.empty():
			extraOptions = [sideOption]
		else:
			for extname in ["", ".png", ".jpg", ".jpeg", ".webp"]:
				var key = name + extname
				var option = _probe_external_avatar_option(key)
				if option.empty():
					continue
				extraOptions.append(option)
		for option in extraOptions:
			if SoundManager.custom_avatar_prefered:
				for op in options:
					op["id"] = op["id"] + 1
				option["id"] = 0
				options.insert(0, option)
			else:
				option["id"] = options.size()
				options.append(option)
		return options

	func _probe_external_avatar_option(key: String) -> Dictionary:
		if not key in StaticManager.extra_avatars:
			return {}
		return {
			"img": StaticManager.extra_avatars[key], 
			"sort": 0, 
			"id": 0, 
			"external": 1, 
		}

	
	func _check_condition(condition) -> bool:
		var prevActorId = actorId
		if "ID" in condition:
			
			actorId = int(condition["ID"])
		var val = null
		var prop = condition["name"]
		if prop == "yearmonth":
			val = DataManager.year * 100 + DataManager.month
		elif prop.begins_with("game_set|"):
			val = DataManager.get_game_setting(prop.split("|")[1])
		elif prop == "面":
			val = get_side()
		else:
			val = _get_attr(prop)
		actorId = prevActorId
		var expected = condition["value"]
		if condition.has("expr"):
			
			var expr = expected.replace("{VAL}", str(val))
			var ret = Global.execute_expression(expr)
			return ret.to_lower() == "true"
		
		return str(val) == expected

	func get_troops_type() -> String:
		if SkillRangeBuff.max_val_for_actor("仙兵种", actorId) > 0:
			return "仙"
		return _get_attr_str("军种")

	func get_troops_type_color() -> Color:
		match get_troops_type():
			"山":
				return Color(160.0 / 255.0, 82.0 / 255.0, 45.0 / 255.0)
			"水":
				return Color(30 / 255.0, 69 / 255.0, 205.0 / 255.0)
			"仙":
				return Color(222.0 / 255.0, 19.0 / 255.0, 19.0 / 255.0)
		return Color(19 / 255.0, 19 / 255.0, 19 / 255.0)

	func set_troops_type(val: String) -> void :
		_set_attr_str("军种", val)
		return
	
	
	
	func get_appear_year(configuredYear: int) -> int:
		var appearYear = _get_attr_int("登场年")
		if appearYear > 0:
			return appearYear
		var decreaseYear = 0
		var setting = DataManager.get_game_setting("出仕时间")
		if "快出" == setting:
			decreaseYear = 65535
		elif setting.begins_with("提前"):
			setting = setting.replace("提前", "")
			setting = setting.replace("年", "")
			decreaseYear = int(setting)
		return configuredYear - decreaseYear

	
	func set_new_appear_year(year: int):
		_set_attr_int("登场年", year)
		return

	
	
	func fix_data() -> void :
		if actorId < 0 or actorId >= StaticManager.actors.size():
			return
		if not _has_attr("面") and has_side():
			_set_attr_str("面", StaticManager.actors[actorId]["面"])
		if not _has_attr("姓") and StaticManager.actors[actorId].has("姓"):
			_set_attr_str("姓", StaticManager.actors[actorId]["姓"])
		return

	
	func get_disabled_equip_types() -> Array:
		return DataManager.get_actor_disabled_equip_types(actorId)

	
	func all_equips(basicOnly: bool = false) -> Array:
		var ret = []
		for type in StaticManager.EQUIPMENT_TYPES:
			ret.append(get_equip(type))
		if basicOnly:
			return ret
		for feature in get_equip_feature_all("视为装备道具", true):
			var eq = feature[0]
			var val = int(feature[1])
			var appended = clEquip.equip(val, "道具")
			ret.append(appended)
		var unlocked = SkillHelper.get_actor_unlocked_skill_names(actorId).values()
		for skillName in ["强记", "藏卷"]:
			if not skillName in unlocked:
				continue
			var skill = StaticManager.get_skill(skillName)
			for effect in SkillHelper.get_skill_effects(actorId, skill):
				var extra = effect.get_related_equip(actorId)
				if extra == null:
					continue
				if get_equip(extra.type).id == extra.id:
					continue
				ret.append(extra)
		return ret

	
	func get_equip_attr_array(attr: String) -> Array:
		var ret = []
		for equip in all_equips():
			var arrval = equip.get_attr_array(attr)
			if not arrval.empty():
				ret.append_array(arrval)
			else:
				var strval = equip.get_attr_str(attr)
				if strval != "":
					ret.append(strval)
		return ret

	
	func get_equip_feature_int(setting: Dictionary, key: String, defVal: int = 0) -> int:
		if DataManager.get_current_scene_id() >= 20000:
			var wa = DataManager.get_war_actor(actorId)
			if wa != null and key in wa.get_ext_variable("装备词条禁用", []):
				return defVal
		if not key in setting:
			return defVal
		if "条件" in setting:
			if Global.execute_expression(setting["条件"], self).to_lower() != "true":
				return defVal
		var ret = Global.intval(setting[key])
		if "公式" in setting:
			ret = Global.intval(Global.execute_expression(setting["公式"], self))
		return ret

	
	
	func get_equip_feature_all(key: String, basicOnly: bool = false) -> Array:
		var ret = []
		for equip in all_equips(basicOnly):
			for feature in equip.features():
				var val = get_equip_feature_int(feature, key)
				if val > 0:
					ret.append([equip, val])
		return ret

	
	func get_equip_feature_total(key: String) -> int:
		var ret = 0
		for found in get_equip_feature_all(key):
			ret += found[1]
		return ret

	
	func get_equip_feature_max(key: String, ignoreSkills: bool = false) -> int:
		var ret = 0
		for found in get_equip_feature_all(key, ignoreSkills):
			if found[1] > ret:
				ret = found[1]
		return ret

	
	func get_equip_feature_min(key: String) -> int:
		var ret = 0
		for found in get_equip_feature_all(key):
			if found[1] <= 0:
				continue
			if found[1] > ret:
				ret = found[1]
			if ret == 0 or found[1] < ret:
				ret = found[1]
		return ret

	
	func get_equip_attr_total(attr: String) -> float:
		var total = 0.0
		for equip in all_equips():
			total += equip.get_attr_float(attr)
		return total

	
	func get_equip_attr_first(attr: String):
		for equip in all_equips():
			if equip.get_attr_str(attr) != "":
				return equip.get_property_static(attr)
		return null

	
	func get_equip_attr_max(attr: String) -> float:
		var max_value = 0.0
		for equip in all_equips():
			var val = equip.get_attr_float(attr)
			max_value = max(max_value, val)
		return max_value

	
	
	func get_learning_exp_rate() -> int:
		var discount = get_equip_feature_min("学习折扣")
		if discount <= 0:
			return 100
		return discount

	
	func get_power_score() -> int:
		
		var score = int(get_power() / 10) * int(get_leadership() / 10)
		score += int(get_wisdom() / 10)
		return score

	
	func get_total_score() -> int:
		return get_power() + get_wisdom() + get_leadership() + get_politics()

	
	func is_top_actor() -> bool:
		var wisdom = get_wisdom()
		if wisdom >= 90:
			return true
		var power = get_power()
		if power >= 90:
			return true
		var leadership = get_leadership()
		if leadership >= 90:
			return true
		var sum = power + leadership + wisdom
		for v in [power, leadership, wisdom]:
			if sum - v > 170:
				return true
		return false

	
	
	func get_personality() -> int:
		if StaticManager.actors[actorId].has("相性"):
			return Global.intval(StaticManager.actors[actorId]["相性"])
		return - 1

	
	
	func get_natures() -> PoolStringArray:
		var ret = []
		if not StaticManager.actors[actorId].has("标签"):
			return ret
		for nature in Global.arrval(StaticManager.actors[actorId]["标签"]):
			ret.append(Global.strval(nature))
		return ret

	
	
	func personality_distance(another: ActorInfo) -> int:
		var mine = get_personality()
		if mine < 0:
			
			return 35
		var his = another.get_personality()
		if his < 0:
			
			return 35
		
		var distance = abs(mine - his)
		return int(min(distance, abs(150 - distance)))

	
	
	func is_celestial_skilled() -> bool:
		if get_equip_feature_max("道书") > 0:
			return true
		for skill in SkillHelper.get_actor_skills(actorId, - 1, true):
			if skill.has_feature("仙"):
				return true
		return false

	
	func get_terrian_cn() -> String:
		var wa = DataManager.get_war_actor(actorId)
		if wa == null:
			return "未知"
		return wa.get_terrian_cn()

	
	func get_buff(buff: String) -> Dictionary:
		var wa = DataManager.get_war_actor(actorId)
		if wa == null:
			return {}
		return wa.get_buff(buff)

	
	func get_war_ap() -> int:
		var wa = DataManager.get_war_actor(actorId)
		if wa == null or wa.disabled:
			return 0
		return wa.action_point

	
	func get_battle_tp() -> int:
		var wa = DataManager.get_war_actor(actorId)
		if wa == null or wa.disabled:
			return 0
		return wa.battle_tactic_point

	
	func continuous_tactic_on() -> bool:
		var wa = DataManager.get_war_actor(actorId)
		if wa == null:
			return false
		return wa.continuous_tactic_on()

	
	func get_battle_courage() -> int:
		var wa = DataManager.get_war_actor(actorId)
		if wa == null:
			return 0
		return wa.battle_courage

	
	func is_battle_attacker() -> bool:
		var sceneId = DataManager.get_current_scene_id()
		
		if sceneId < 20000:
			return false
		var bf = DataManager.get_current_battle_fight()
		return actorId == bf.get_attacker_id()

	
	func is_battle_defender() -> bool:
		var sceneId = DataManager.get_current_scene_id()
		
		if sceneId < 20000:
			return false
		var bf = DataManager.get_current_battle_fight()
		return actorId == bf.get_defender_id()

	
	func is_battle_winner() -> bool:
		var sceneId = DataManager.get_current_scene_id()
		
		if sceneId < 20000:
			return false
		var bf = DataManager.get_current_battle_fight()
		var winner = bf.get_winner()
		if winner == null:
			return false
		return actorId == winner.actorId

	
	func get_war_skill_val_int(effectId: int) -> int:
		return SkillHelper.get_skill_variable_int(20000, effectId, actorId)

	
	func get_skill_flags_int(sceneId: int, effectId: int, flagName: String) -> int:
		return SkillHelper.get_skill_flags_number(sceneId, effectId, actorId, flagName)

static func actor(id: int) -> ActorInfo:
	return ActorInfo.new(id)

static func actors_count() -> int:
	return DataManager.actors.size()

static func all_actors() -> Array:
	var ret = []
	for i in range(DataManager.actors.size()):
		var actor = ActorInfo.new(i)
		ret.append(actor)
	return ret

static func all_available_actors() -> Array:
	var ret = []
	for i in range(DataManager.actors.size()):
		var actor = ActorInfo.new(i)
		if actor.is_status_disabled():
			continue
		ret.append(actor)
	return ret

static func all_exiled_actors() -> Array:
	var ret = []
	for i in range(DataManager.actors.size()):
		var actor = ActorInfo.new(i)
		if not actor.is_status_exiled():
			continue
		ret.append(actor)
	return ret

static func all_officed_actors() -> Array:
	var ret = []
	for i in range(DataManager.actors.size()):
		var actor = ActorInfo.new(i)
		if not actor.is_status_officed():
			continue
		ret.append(actor)
	return ret

static func all_unofficed_actors() -> Array:
	var ret = []
	for i in range(DataManager.actors.size()):
		var actor = ActorInfo.new(i)
		if not actor.is_status_unofficed():
			continue
		ret.append(actor)
	return ret

static func all_dead_actors() -> Array:
	var ret = []
	for i in range(DataManager.actors.size()):
		var actor = ActorInfo.new(i)
		if actor.is_status_disabled():
			continue
		if not actor.is_status_dead():
			continue
		ret.append(actor)
	return ret

static func all_hidden_actors() -> Array:
	var ret = []
	for i in range(DataManager.actors.size()):
		var actor = ActorInfo.new(i)
		if actor.is_status_disabled():
			continue
		if not actor.is_status_hidden():
			continue
		ret.append(actor)
	return ret

static func all_disabled_actors(excepted: PoolIntArray = []) -> Array:
	var ret = []
	for i in range(DataManager.actors.size()):
		if i in excepted:
			continue
		var actor = ActorInfo.new(i)
		if not actor.is_status_disabled():
			continue
		ret.append(actor)
	return ret

static func all_captured_actors(excepted: PoolIntArray = []) -> Array:
	var ret = []
	for i in range(DataManager.actors.size()):
		if i in excepted:
			continue
		var actor = ActorInfo.new(i)
		if not actor.is_status_captured():
			continue
		ret.append(actor)
	return ret

static func search_actors(keyword: String) -> Array:
	keyword = keyword.replace("【", "[")
	keyword = keyword.replace("】", "]")
	var ret = []
	var searchId = - 1
	if str(Global.intval(keyword)) == keyword:
		searchId = Global.intval(keyword)
	for i in range(DataManager.actors.size()):
		var actor = ActorInfo.new(i)
		if keyword == "":
			ret.append(actor)
			continue
		if searchId == actor.actorId:
			ret.append(actor)
			continue
		if keyword.begins_with("[") and keyword.ends_with("]"):
			var natures = keyword.replace("[", "").replace("]", "").split(",")
			for nature in natures:
				if nature in actor.get_natures():
					ret.append(actor)
					break
			continue
		if StaticManager.RE_ALPHA.search(keyword) != null:
			var found = false
			for r in StaticManager.pinyin(actor.get_name()):
				if keyword in r:
					found = true
					ret.append(actor)
					break
			if found:
				continue
			for r in StaticManager.pinyin(actor.get_nick()):
				if keyword in r:
					found = true
					ret.append(actor)
					break
			if found:
				continue
		if keyword in actor.get_name():
			ret.append(actor)
			continue
		if keyword in actor.get_nick():
			ret.append(actor)
			continue
	return ret

static func random_actor_id() -> int:
	return Global.get_random(0, DataManager.actors.size() - 1)

static func add_new_static_actors() -> void :
	var actorsStatic = StaticManager.actors.duplicate(true)
	var diff = actorsStatic.size() - DataManager.actors.size()
	if diff <= 0:
		return
	var beginId = DataManager.actors.size()
	for i in diff:
		var newActor = actorsStatic[beginId + i]
		if newActor["状态"] == "出仕":
			newActor["状态"] = "隐藏"
		DataManager.actors.append(newActor)
	return




var nameMap = {}

var charTree = {}

var maxLength: int = - 1

var selected: PoolIntArray = []

var charOptions = []

const ALPHA_SORTING = [
	["A", "阿"], 
	["B", "鲍步"], 
	["C", "蔡曹车程成陈彻淳崔"], 
	["D", "戴大带邓典貂丁董杜朵"], 
	["E", "鄂"], 
	["F", "法樊范费冯凤傅"], 
	["G", "甘高巩公龚管关毌妫郭顾"], 
	["H", "韩郝何贺和侯胡黄桓皇华霍"], 
	["J", "纪蒋姜简焦贾金句沮"], 
	["K", "阚科轲孔蒯"], 
	["L", "乐雷李梁廖泠凌刘留陆鲁卢骆罗吕"], 
	["M", "满毛马孟祢麋木"], 
	["N", "牛"], 
	["P", "潘庞逄裴"], 
	["Q", "牵乔桥秦麹全"], 
	["R", "任"], 
	["S", "沙邵沈申审史师石士司宋孙苏"], 
	["T", "太唐谭蹋陶滕田"], 
	["W", "万王卫魏韦文武吴吾兀"], 
	["X", "夏戏向小谢邢辛徐许薛荀"], 
	["Y", "雅颜阎严杨羊伊尹雍虞于俞袁越乐"], 
	["Z", "臧笮张赵甄钟朱诸祝周自邹祖左"], 
]


func reload():
	var _nameMap = {}
	for actor in all_actors():
		var name = actor.get_full_name()
		if name.empty():
			continue
		var fn = actor.get_first_name()
		if fn.empty():
			continue
		var found = false
		for opt in ALPHA_SORTING:
			if name[0] in opt[1] or fn in opt[1]:
				_nameMap[opt[0] + name] = actor.actorId
				found = true
		if not found:
			_nameMap["_" + name] = actor.actorId
	self.nameMap = _nameMap
	
	self.nameMap["K科大"] = - 1
	self.nameMap["F凤婶"] = - 1

	var _charTree = {}
	var _maxLength = - 1
	for name in self.nameMap:
		var _pointer = _charTree
		if name.length() > _maxLength:
			_maxLength = name.length()
		while name.length() > 0:
			var ch = name[0]
			name = name.right(1)
			if not _pointer.has(ch):
				_pointer[ch] = {}
			_pointer = _pointer[ch]

	self.charTree = _charTree
	self.maxLength = _maxLength
	self.selected = [0]
	self.charOptions = []
	for i in self.maxLength:
		self.selected.append(0)
		self.charOptions.append([])
	self.charOptions.append([])
	
	self.selected.insert(0, 0)
	self.charOptions[0] = self.charTree.keys()
	self.charOptions[0].sort()
	
	self.preload_char_options(0)
	
	reload_equip_names()
	return


func next_char_option(delta: int):
	var idx = self.selected[0]
	if idx < 0 or idx >= self.maxLength:
		idx = 0
		self.selected[0] = idx
	var cur = self.selected[idx + 1]
	var next = cur + delta
	var total = self.get_char_options(idx).size()
	if total == 0:
		self.prev_idx()
		return
	if next >= total:
		next = next % total
	while next < 0:
		next += total
	
	self.selected[idx + 1] = next
	
	for i in self.maxLength:
		if i > idx:
			self.selected[i + 1] = 0
	self.preload_char_options(idx)


func preload_char_options(idx):
	var _pointer = self.charTree
	for i in range(idx + 1):
		var ch = self.get_selected_char(i)
		if not _pointer.has(ch):
			break
		_pointer = _pointer[ch]
	self.charOptions[idx + 1] = _pointer.keys()


func get_char_options(idx):
	if idx < 0 or idx >= self.maxLength:
		return []
	return self.charOptions[idx]


func get_selected_char(idx):
	if idx < 0 or idx >= self.maxLength:
		return ""
	var options = self.get_char_options(idx)
	var sel = self.selected[idx + 1]
	if sel < 0 or sel >= options.size():
		return ""
	return options[sel]

func prev_idx():
	var idx = self.selected[0]
	if idx < 1 or idx >= self.maxLength:
		return
	self.selected[0] = idx - 1

func next_idx():
	var idx = self.selected[0]
	if idx < 0 or idx >= self.maxLength - 1:
		return
	self.selected[0] = idx + 1
	if idx + 2 <= self.maxLength:
		self.selected[idx + 2] = 0
	self.next_char_option(0)

func get_selected_chars() -> String:
	var ret = []
	for i in self.selected[0] + 1:
		ret.append(self.get_selected_char(i))
	return "".join(ret)


func get_actor_clue(name: String) -> Array:
	var msgs = []
	var actorId = - 999
	for _name in self.nameMap:
		if _name.find(name) == 0:
			name = _name
			actorId = self.nameMap[_name]
			break
	name = name.right(1)
	match name:
		"科大":
			msgs.append("科大正在给你们做游戏")
			msgs.append("别吵，吵就是飞机票")
			return [msgs, - 1]
		"凤婶":
			msgs.append("凤婶正在群里扫盲")
			msgs.append("还欠了1000个技能设计")
			return [msgs, - 1]
	msgs.append("寻访「" + name + "」的消息...")
	if actorId == - 999:
		msgs.append("没有任何线索...")
		return [msgs, - 1]

	var actor = actor(actorId)
	if actor.is_status_dead():
		msgs.append("{0}已阵亡...".format([actor.get_name()]))
		return [msgs, actorId]
	for city in clCity.all_cities():
		if actor.actorId in city.get_actor_ids():
			msgs.append("{0}目前在{1}出仕".format([actor.get_name(), city.get_name()]))
			DataManager.twinkle_citys = [city.ID]
			return [msgs, actorId]
		if actor.actorId in city.get_ceil_actor_ids():
			msgs.append("{0}目前被关押在{1}".format([actor.get_name(), city.get_name()]))
			DataManager.twinkle_citys = [city.ID]
			return [msgs, actorId]
	if actor.is_status_exiled():
		var city = clCity.city(actor.get_exiled_city_id())
		msgs.append("{0}目前在{1}附近出没".format([actor.get_name(), city.get_name()]))
		DataManager.twinkle_citys = [city.ID]
		return [msgs, actorId]
	if actor.is_status_unofficed():
		for dic in DataManager.citys_unoffice:
			if int(dic["武将"]) == actor.actorId:
				msgs.append("{0}尚未出仕".format([actor.get_name()]))
				var city = clCity.city(int(dic["城池"]))
				msgs.append("访隐{0}或有收获".format([city.get_name()]))
				DataManager.twinkle_citys = [city.ID]
				return [msgs, actorId]
		for dic in DataManager.actor_follower:
			if int(dic["子将"]) == actor.actorId:
				msgs.append("{0}尚未成年".format([actor.get_name()]))
				var parent = actor(int(dic["父将"]))
				msgs.append("寻访{0}或有线索".format([parent.get_name()]))
				return [msgs, actorId]
	if actor.is_status_hidden():
		msgs.append("此为异士，不知踪迹...")
		return [msgs, actorId]

	if actor.is_status_disabled():
		msgs.append("此人不存在于这个位面")
		return [msgs, actorId]

	
	var currentStatus = actor.get_status()
	actor.set_status_exiled( - 1, - 1)
	if actor.get_exiled_city_id() < 0:
		clCity.find_new_home(actor.actorId)
	msgs.append("🦔失踪了…… 状态（{0}）\n已强制流放到{1}".format([
		currentStatus, clCity.city(actor.get_exiled_city_id()).get_name()
	]))
	return [msgs, actorId]


static func find_next_war_actor(actorIds: PoolIntArray, current: int, direction: Vector2) -> int:
	var wa = DataManager.get_war_actor(actorIds[current])
	if wa == null:
		return current
	var possible = - 1
	var minDistance = 99999
	for i in range(actorIds.size()):
		var ta = DataManager.get_war_actor(actorIds[i])
		if null == ta:
			continue
		if direction.y < 0 and ta.position.y < wa.position.y:
			var diff = ta.position - wa.position
			var distance = abs(diff.x) + abs(diff.y) * 100
			if possible < 0 or distance < minDistance:
				possible = i
				minDistance = distance
				continue
		if direction.y > 0 and ta.position.y > wa.position.y:
			var diff = ta.position - wa.position
			var distance = abs(diff.x) + abs(diff.y) * 100
			if possible < 0 or distance < minDistance:
				possible = i
				minDistance = distance
				continue
		if direction.x > 0 and ta.position.x > wa.position.x:
			var diff = ta.position - wa.position
			var distance = abs(diff.x) + abs(diff.y) * 100
			if possible < 0 or distance < minDistance:
				possible = i
				minDistance = distance
				continue
		if direction.x < 0 and ta.position.x < wa.position.x:
			var diff = ta.position - wa.position
			var distance = abs(diff.x) + abs(diff.y) * 100
			if possible < 0 or distance < minDistance:
				possible = i
				minDistance = distance
				continue
	if possible >= 0:
		return possible
	return current


static func find_next_war_position(positions: Array, current: int, direction: Vector2) -> int:
	if current < 0 or current >= positions.size():
		return current
	var cp = positions[current]
	var possible = - 1
	var minDistance = 999
	for i in range(positions.size()):
		var pos = positions[i]
		if direction.y < 0 and int(pos["y"]) < int(cp["y"]):
			var distance = abs(int(pos["x"]) - int(cp["x"])) + abs(int(pos["y"]) - int(cp["y"])) * 100
			if possible < 0 or distance < minDistance:
				possible = i
				minDistance = distance
				continue
		if direction.y > 0 and int(pos["y"]) > int(cp["y"]):
			var distance = abs(int(pos["x"]) - int(cp["x"])) + abs(int(pos["y"]) - int(cp["y"])) * 100
			if possible < 0 or distance < minDistance:
				possible = i
				minDistance = distance
				continue
		if direction.x > 0 and int(pos["x"]) > int(cp["x"]):
			var distance = abs(int(pos["x"]) - int(cp["x"])) + abs(int(pos["y"]) - int(cp["y"])) * 100
			if possible < 0 or distance < minDistance:
				possible = i
				minDistance = distance
				continue
		if direction.x < 0 and int(pos["x"]) < int(cp["x"]):
			var distance = abs(int(pos["x"]) - int(cp["x"])) + abs(int(pos["y"]) - int(cp["y"])) * 100
			if possible < 0 or distance < minDistance:
				possible = i
				minDistance = distance
				continue
	if possible >= 0:
		return possible
	return current



var equipNames = {}
var equipInfo = {}
var equipIdx = {}
var currentEquipType: String = "武器"

func reload_equip_names():
	equipNames.clear()
	equipInfo.clear()
	for equip in clEquip.all_equips():
		if equip.level() != "S":
			continue
		if not equip.type in equipNames:
			equipNames[equip.type] = []
			equipIdx[equip.type] = 0
		equipNames[equip.type].append(equip.name())
		equipInfo[equip.name()] = [equip.type, equip.id]
	return

func show_equip_message(idx: int = - 1, type: String = "") -> String:
	if type in equipNames:
		currentEquipType = type
	return "稀有" + currentEquipType + "的情报？\n上下键选择：\n" + get_selected_equip_name(idx)

func get_selected_equip_name(idx: int = - 1) -> String:
	if idx < 0 or idx >= equipNames[currentEquipType].size():
		idx = equipIdx[currentEquipType]
	return equipNames[currentEquipType][idx]

func next_equip_option(delta: int) -> void :
	equipIdx[currentEquipType] += delta
	if equipIdx[currentEquipType] < 0:
		equipIdx[currentEquipType] = equipNames[currentEquipType].size() - 1
	if equipIdx[currentEquipType] >= equipNames[currentEquipType].size():
		equipIdx[currentEquipType] = 0
	return

func get_equip_clue(name: String) -> String:
	if not name in equipInfo:
		return "没有任何关于\n【" + name + "】的情报\n……"
	var msg = "寻访【" + name + "】……\n"
	var equipType = str(equipInfo[name][0])
	var equipId = int(equipInfo[name][1])
	var target = clEquip.equip(equipId, equipType)
	
	var sold = SkillHelper.get_skill_variable_array(10000, 10144, StaticManager.ACTOR_ID_SLIME_GOD)
	for item in sold:
		if int(item[0]) == equipId and item[1] == equipType:
			msg += "好像被{0}保管着呢".format([ActorHelper.actor(StaticManager.ACTOR_ID_SLIME_GOD).get_name()])
			return msg
	
	for actor in ActorHelper.all_actors():
		if actor.get_equip(equipType).id == target.id:
			msg += "据传{0}将军持有此物".format([actor.get_name()])
			return msg
	var currentCity = clCity.city(DataManager.player_choose_city)
	var currentVS = clVState.vstate(currentCity.get_vstate_id())
	
	for vs in clVState.all_vstates():
		for row in vs.get_stored_equipments():
			if target.id != row[0].id or target.type != row[0].type:
				continue
			if vs.is_perished():
				
				vs.remove_stored_equipment(target)
				return summon_equip(currentVS, target)
			msg += "据传{0}军已收藏此物".format([vs.get_dynasty_title_or_lord_name()])
			return msg
	
	for city in clCity.all_cities():
		var citySpecialEquips = city.get_special_equips()
		for equip in citySpecialEquips["内"]:
			if target.equals(equip):
				return "寻访【{0}】……\n据传：\n有人在{1}城内见过此物".format([
					name, city.get_full_name(), 
				])
		for equip in citySpecialEquips["外"]:
			if target.equals(equip):
				return "寻访【{0}】……\n据传：\n有人在{1}野外见过此物".format([
					name, city.get_full_name(), 
				])
	
	msg = summon_equip(currentVS, target)
	return msg

func _sort_actor_by_name(a, b) -> bool:
	var ca = a.get_full_name().left(1)
	var cb = b.get_full_name().left(1)
	for pair in ALPHA_SORTING:
		if ca in pair[1]:
			ca = pair[0]
		if cb in pair[1]:
			cb = pair[0]
	return ca < cb

func summon_equip(vs, equip: clEquip.EquipInfo) -> String:
	if equip.get_attr_int("自动解锁") == 1:
		var msg = equip.name() + "的购买条件：\n"
		msg += equip.get_attr_str("购买条件描述")
		return msg
	
	var conditions = equip.get_attr_array("解锁条件")
	if not conditions.empty():
		var msg = equip.name() + "的解锁条件："
		for condition in conditions:
			msg += "\n" + equip.describe_unlock_condition(condition)
		return msg
	vs.add_stored_equipment(equip)
	return "{0}蒙尘已久\n感应了你的召唤！\n（遗落装备已置入仓库".format([
		equip.name()
	])
