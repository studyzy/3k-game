# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/objects/clEquip.gd
# 说明：装备对象。描述武器/铠甲/宝物等装备的属性与效果。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Resource
class_name clEquip

class EquipInfo:
	
	var id: int
	var type: String
	
	var disabled: bool = false
	
	var disabledEquipOnly: bool = false
	
	var battleTemporary: bool = false
	
	func _init(_id: int, _type: String) -> void :
		id = _id
		type = _type
		disabled = false
		disabledEquipOnly = false
		battleTemporary = false
		return

	
	func get_data_static(evenDisabled: bool = false) -> Dictionary:
		if id < 0:
			return {}
		if disabled and not evenDisabled:
			return {}
		return StaticManager.get_equip_data(id, type)

	
	func get_data_runtime(evenDisabled: bool = false) -> Dictionary:
		if id < 0:
			return {}
		if disabled and not evenDisabled:
			return {}
		var data = []
		match type:
			"武器":
				data = DataManager.weapons
			"防具":
				data = DataManager.suits
			"道具":
				data = DataManager.jewelrys
			"坐骑":
				data = DataManager.steeds
		if id >= data.size():
			return {}
		return data[id].duplicate(true)

	func get_property_static(prop: String, evenDisabled: bool = false):
		var data = get_data_static(evenDisabled)
		if not data.has(prop):
			return null
		return data[prop]

	func get_property(prop: String):
		var data = get_data_runtime()
		if not data.has(prop):
			return null
		return data[prop]

	func set_property(prop: String, val) -> void :
		if id < 0:
			return
		var data = []
		match type:
			"武器":
				data = DataManager.weapons
			"防具":
				data = DataManager.suits
			"道具":
				data = DataManager.jewelrys
			"坐骑":
				data = DataManager.steeds
		if id >= data.size():
			return
		data[id][prop] = val
		return

	
	func dec_count(cnt: int = 1) -> void :
		var current = Global.intval(get_property("数量"), - 1)
		if current < 0:
			return
		current = max(0, current - cnt)
		set_property("数量", current)
		return

	
	func get_all_types() -> PoolStringArray:
		var ret = [subtype()]
		for setting in features():
			if "额外类型刀" in setting:
				ret.append("刀")
			if "额外类型剑" in setting:
				ret.append("剑")
		return ret

	
	func level(evenDisabled: bool = false) -> String:
		return Global.strval(get_property_static("品质", evenDisabled), "")

	
	func level_score(evenDisabled: bool = false) -> int:
		var level = level(evenDisabled)
		match level:
			"":
				return - 1
			"S":
				return 9
		return int(level)

	func name() -> String:
		return Global.strval(get_property_static("名称", true), "禁用")

	func image_setting():
		var imgPath = get_attr_str("图像资源", true)
		if imgPath != "":
			var img = Global.load_pic_with_cache("res://" + imgPath)
			return {
				"img": img, 
				"x": 0, 
				"y": 0, 
				"w": img.get_width(), 
				"h": img.get_height(), 
			}
		var imgIds = get_attr_array("图像", true)
		var imgId: int = - 1
		if imgIds.size() > 1:
			var timing = int(Time.get_ticks_msec() / 1000)
			imgId = int(imgIds[timing % imgIds.size()])
		else:
			imgId = get_attr_int("图像", true)
		return {
			"img": StaticManager.equipment_image, 
			"x": imgId % 8 * 32, 
			"y": int(imgId / 8) * 32, 
			"w": 32, 
			"h": 32, 
		}

	
	func display_name() -> String:
		var name = Global.strval(get_property_static("显示名"))
		if name == "":
			name = name()
		if name == "禁用":
			return "\n[color=gray]禁用[/color]"
		if name.length() >= 4 and not "\n" in name:
			name = name.substr(0, 2) + "\n" + name.substr(2)
		if not "\n" in name:
			name = "\n" + name
		return name

	func price() -> int:
		return Global.intval(get_property_static("价格"), 0)

	
	func get_steed_power() -> int:
		return Global.intval(get_property_static("马力"), 0)

	
	func equals(another) -> bool:
		return id == another.id and type == another.type

	
	func remaining() -> int:
		return Global.intval(get_property("数量"), - 1)

	
	func get_attr_str(prop: String, evenDisabled: bool = false) -> String:
		return Global.strval(get_property_static(prop, evenDisabled), "")

	
	func get_attr_array(prop: String, evenDisabled: bool = false) -> Array:
		return Global.arrval(get_property_static(prop, evenDisabled))

	
	func get_attr_dic(prop: String) -> Dictionary:
		return Global.dicval(get_property_static(prop))

	
	func get_attr_float(prop: String) -> float:
		return Global.floatval(get_property_static(prop), 0.0)

	
	func get_attr_int(prop: String, evenDisabled: bool = false) -> int:
		return Global.intval(get_property_static(prop, evenDisabled), 0)

	
	func subtype(evenDisabled: bool = false) -> String:
		return get_attr_str("类型", evenDisabled)

	
	func weight(evenDisabled: bool = false) -> int:
		return get_attr_int("重量", evenDisabled)

	
	func features() -> Array:
		return get_attr_array("特性")

	
	func as_dict() -> Dictionary:
		var ret = {}
		var data = get_data_static(true)
		for key in data:
			ret[key] = data[key]
		data = get_data_runtime(true)
		
		if "数量" in data:
			ret["数量"] = data["数量"]
		
		return ret

	
	func actor_can_use(actorId: int) -> bool:
		var condition = get_attr_str("购买条件")
		if condition == "":
			return true
		return Global.count_formula_bool(condition, actorId)

	
	func get_description() -> String:
		var ret = name() + "\n"
		var attrs = ["品质", "类型", "攻击力", "防御力", "重量", "机动力恢复", "马力", "投掷距离"];
		for attr in attrs:
			var val = get_attr_str(attr)
			if val == "":
				continue
			if val == "0":
				continue
			if attr == "类型":
				val = type + "(" + val + ")"
			ret += "【{0}】{1}".format([attr, val])
		var condition = get_attr_str("购买条件")
		if condition != "":
			var replaces = {
				"||": "或", 
				"&&": "且", 
				">=": "≥", 
				"<=": "≤", 
				"a.": "", 
			}
			for old_str in replaces:
				condition = condition.replacen(old_str, replaces[old_str])
			ret += "\n【要求】" + condition
		var memo = get_attr_str("描述")
		if memo != "":
			for m in memo.split("\n"):
				ret += "\n[color=blue]" + m + "[/color]"
		for desc in get_features_description():
			ret += "\n效果：" + desc
		return ret

	
	func get_attrs_brief() -> String:
		match type:
			"武器":
				return "{0}，攻：{1}，重：{2}".format([
					subtype(), get_attr_int("攻击力"), weight(), 
				])
			"防具":
				return "防：{0}，重：{1}".format([
					get_attr_int("防御力"), weight(), 
				])
			"道具":
				return subtype()
			"坐骑":
				return "马力：{0}，机动：{1}".format([
					get_attr_int("马力"), get_attr_int("机动力恢复"), 
				])
		return ""

	func describe_unlock_condition(condition: Dictionary) -> String:
		if "killStreak" in condition:
			return "{0}一场战斗中击败{1}武将".format([
				ActorHelper.actor(condition["actorId"]).get_name(), 
				condition["killStreak"]
			])
		return Global.dic_val(condition, "描述", "未知")

	
	func type_disabled() -> bool:
		return disabled and not disabledEquipOnly

	
	func equip_disabled() -> bool:
		return disabled and disabledEquipOnly

	func get_feature_description(setting: Dictionary) -> String:
		var condition = ""
		var desc = ""
		for key in setting:
			if key == "条件":
				condition = "若" + explain_expr(setting[key]) + "："
				continue
			if not key in StaticManager.EQUIP_TAG_MAPPING:
				continue
			var data = [0, 0, 0]
			data[0] = Global.intval(setting[key])
			data[1] = data[0] * 100
			data[2] = data[0] * 50
			if "公式" in setting:
				data[0] = explain_expr(setting["公式"])
			
			if key == "五行":
				data[0] = War_Character.get_five_phases_string(data[0])
			if key == "视为装备道具":
				data[1] = EquipInfo.new(data[0], "道具").name()
			desc = StaticManager.EQUIP_TAG_MAPPING[key].format(data)
		return condition + desc

	
	func explain_expr(expr: String) -> String:
		
		
		
		if expr.begins_with("min(") and expr.ends_with(")"):
			var piece = expr.trim_prefix("min(")
			piece = piece.substr(0, piece.length() - 1)
			var pieces = piece.split(",")
			if pieces.size() == 2:
				var maxVal = Global.intval(pieces[0].trim_suffix(" "))
				if maxVal > 0:
					return explain_expr(pieces[1].trim_prefix(" ")) + "，最大为" + str(maxVal)
		if expr.begins_with("max(") and expr.ends_with(")"):
			var piece = expr.trim_prefix("max(")
			piece = piece.substr(0, piece.length() - 1)
			var pieces = piece.split(",")
			if pieces.size() == 2:
				var minVal = Global.intval(pieces[0].trim_suffix(" "))
				if minVal > 0:
					return explain_expr(pieces[1].trim_prefix(" ")) + "，最小为" + str(minVal)
		if expr.begins_with("int("):
			expr = "[" + expr.trim_prefix("int(")
			
			var from = 0
			var pairCount = 1
			while from < expr.length():
				var posA = expr.find("(", from)
				var posB = expr.find(")", from)
				if posA > 0 and posA < posB:
					pairCount += 1
					from = posA + 1
				elif posB > 0:
					from = posB + 1
					pairCount -= 1
					if pairCount == 0:
						expr = expr.substr(0, posB) + "]" + expr.substr(posB + 1)
						break
				else:
					break
		var pieces = expr.split("and")
		var msgs = []
		for piece in pieces:
			if piece.begins_with("get_id()"):
				var parts = piece.split("==")
				if parts.size() == 2:
					var actorId = Global.intval(parts[1])
					if actorId >= 0:
						msgs.append("装备者为" + ActorHelper.actor(actorId).get_name())
						continue
			piece = piece.replace("get_soldiers()", "士兵数")
			piece = piece.replace("get_courage()", "胆")
			piece = piece.replace("get_power()", "武")
			piece = piece.replace("get_wisdom()", "知")
			piece = piece.replace("get_politics()", "政")
			piece = piece.replace("get_battle_courage()", "白刃战胆")
			piece = piece.replace("get_weapon()", "武器")
			piece = piece.replace("get_war_ap()", "[机动力]")
			piece = piece.replace("get_battle_tp()", "[战术值]")
			piece = piece.replace("get_suit()", "防具")
			piece = piece.replace(".get_attr_str(\"持法\")", "持法")
			piece = piece.replace(".equip_disabled()", "被禁用")
			piece = piece.replace(".type_disabled()", "栏被禁用")
			piece = piece.replace(".get_attr_int(\"防御力\", true)", "防御力")
			piece = piece.replace("equip_total_weight()", "[装备重量]")
			piece = piece.replace("is_celestial_skilled()", "装备道书，或具备仙技能")
			piece = piece.replace("get_hp()", "[体力]")
			piece = piece.replace("get_terrian_cn()", "所在地形")
			piece = piece.replace("get_gender()", "性别")
			piece = piece.replace("continuous_tactic_on()", "持续性战术开启")
			piece = piece.replace("is_battle_attacker()", "为战斗攻方")
			piece = piece.replace("is_battle_defender()", "为战斗守方")
			piece = piece.replace("is_battle_winner()", "战斗胜利")
			piece = piece.replace("get_buff(\"", "")
			piece = piece.replace("\")", "")
			piece = piece.replace("[\"", "")
			piece = piece.replace("\"]", "")
			piece = piece.replace("==", "为")
			piece = piece.replace("\"", "")
			piece = piece.replace(" ", "")
			msgs.append(piece)
		return "且".join(msgs)

	func get_features_description() -> PoolStringArray:
		var ret = []
		for feature in get_attr_array("特性"):
			var desc = get_feature_description(feature)
			if desc == "":
				continue
			ret.append(desc)
		return ret

	
	func is_moded() -> bool:
		return id >= StaticManager.CUSTOM_EQUIP_MIN_ID

	
	func get_name_color() -> Color:
		if is_moded():
			return StaticManager.COLOR_MODED_EQUIP
		if level() == "S":
			return StaticManager.COLOR_SPECIAL_EQUIP
		return Color.black

	
	func get_name_color_code() -> String:
		if is_moded():
			return StaticManager.COLOR_CODE_MODED_EQUIP
		if level() == "S":
			return StaticManager.COLOR_CODE_SPECIAL_EQUIP
		return ""

	func price_for(cityId: int) -> int:
		var price = price()
		if type == "道具" and subtype() == "书":
			
			var priceOff = SkillRangeBuff.max_val_for_city("书籍折扣", cityId)
			if priceOff > 0:
				price = int(price * priceOff / 100)
		return price

static func equip(id: int, type: String):
	return EquipInfo.new(id, type)

static func all_equips(type: String = "", includingPatched: bool = false) -> Array:
	var ret = []
	if type == "" or type == "武器":
		for item in StaticManager.weapons_static:
			ret.append(equip(int(item["ID"]), "武器"))
	if type == "" or type == "防具":
		for item in StaticManager.suits_static:
			ret.append(equip(int(item["ID"]), "防具"))
	if type == "" or type == "道具":
		for item in StaticManager.jewelrys_static:
			ret.append(equip(int(item["ID"]), "道具"))
	if type == "" or type == "坐骑":
		for item in StaticManager.steeds_static:
			ret.append(equip(int(item["ID"]), "坐骑"))
	if includingPatched:
		for ce in StaticManager.custom_equips:
			if type == "" or type == ce.type:
				ret.append(equip(ce.id, ce.type))
	return ret


static func basic_equip(type: String, subType: String) -> EquipInfo:
	if type == "武器":
		for equip in all_equips():
			if equip.type != type:
				continue
			if equip.subtype() == subType and equip.level_score() == 1:
				return equip
	return equip(0, type)


static func best_normal_equip(type: String, subType: String) -> EquipInfo:
	var score = - 1
	var ret = equip(0, type)
	for equip in all_equips():
		if equip.type != type:
			continue
		if equip.subtype() != subType:
			continue
		var cur = equip.level_score()
		if cur > 5:
			continue
		if cur > score:
			score = cur
			ret = equip
	return ret
