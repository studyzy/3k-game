extends Resource

class_name CustomEquip

const CUSTOM_EQUIP_MIN_ID = 10000

const DEFAULT_ICON = {
	"武器": 106, 
	"防具": 112, 
	"道具": 108, 
	"坐骑": 110, 
}

const DEFAULT_WEAPON_ICON = {
	"锤": 113, 
	"刀": 114, 
	"斧": 115, 
	"剑": 117, 
	"枪": 118, 
}

const DEFAULT_JEWELRY_ICON = {
	"书": 111, 
	"饰品": 116, 
	"印章": 119, 
	"弓": 120, 
	"副武器": 121, 
	"暗器": 122, 
}

const POSSIBLE_FEATURES = {
	"武器": {
		"默认": [
			"白兵免伤", 
			"附加体上限", 
			"战术附加回合", 
			"白兵附加统", 
			"白兵附加战术", 
			"白兵减敌战术", 
			"单挑暴击率", 
			"白兵降统", 
			"白兵降胆", 
			"团队经验加成", 
			"白兵攻击力", 
		], 
		"枪": [
			"斜角攻击距离", 
			"额外类型剑", 
			"额外类型刀", 
		], 
		"刀": [
			"斜角攻击距离", 
			"额外类型剑", 
		], 
		"斧": [
			"斜角攻击距离", 
		], 
		"剑": [
			"斜角攻击距离", 
		], 
	}, 
	"防具": [
		"全计策", 
		"每日回体", 
		"单挑免死", 
		"附加体上限", 
		"白刃战动态胆", 
	], 
	"道具": {
		"书": [
			"白兵附加战术", 
			"计策附加智力", 
			"开发附加人口", 
			"开发提升", 
			"计策消耗减少", 
			"菜市口经验", 
			"道书", 
			"重伤概率", 
		], 
		"弓": [
			"白兵射程", 
			"射箭攻击回血", 
			"允许射武将", 
		], 
		"印章": [
			"白兵附加统", 
			"影响全城征兵", 
			"兵力上限", 
		], 
		"副武器": [
			"近身倍率加成", 
			"近身攻击回血", 
			"格挡率加成", 
			"重伤概率", 
			"格返", 
		], 
		"暗器": [
			"投掷距离", 
			"重伤概率", 
		], 
		"饰品": [
			"附加胆", 
			"附加德", 
		]
	}, 
	"坐骑": [
		"单挑命中率加成", 
		"刚胆", 
		"疾驰", 
		"单挑MISS回体", 
		"重量降低", 
		"平军移动", 
		"山军移动", 
		"水军移动", 
	], 
}

const WEAPON_TYPES = ["枪", "刀", "剑", "斧", "锤"]
const WEAPON_CATES = ["短兵", "长兵", "双持"]
const JEWELRY_TYPES = ["书", "弓", "印章", "饰品", "副武器", "暗器"]


var id: int
var type: String = ""
var name: String = ""
var subtype: String = ""
var attrs: Dictionary = {}
var features: Array = []


func load_data(dic: Dictionary) -> void :
	for requiredKey in ["ID", "装备类型", "名称"]:
		if not requiredKey in dic:
			id = - 1
			return
	id = Global.intval(dic["ID"])
	if id < CUSTOM_EQUIP_MIN_ID:
		id = - 1
		return
	type = Global.strval(dic["装备类型"])
	if not type in StaticManager.EQUIPMENT_TYPES:
		id = - 1
		return
	name = Global.strval(dic["名称"])
	subtype = Global.strval(Global.dic_val(dic, "类型", ""))
	attrs = {}
	set_attrs(dic)
	features = []
	for setting in Global.arrval(Global.dic_val(dic, "特性", [])):
		if features.size() >= 3:
			break
		setting = Global.dicval(setting)
		if setting.empty():
			continue
		var feature = setting.keys()[0]
		if not feature in get_possible_features(type, subtype):
			continue
		var val = Global.intval(setting[feature])
		set_feature(features.size(), feature, val)
	return


func dump_data() -> Dictionary:
	var ret = attrs.duplicate(true)
	ret["ID"] = id
	ret["名称"] = name
	ret["装备类型"] = type
	ret["类型"] = subtype
	ret["特性"] = []
	for feature in features:
		feature = Global.arrval(feature)
		if feature.size() != 2:
			continue
		var dic = {}
		dic[Global.strval(feature[0])] = Global.intval(feature[1])
		ret["特性"].append(dic)
	return ret


func random_attrs():
	attrs = {}
	match type:
		"武器":
			subtype = WEAPON_TYPES[randi() % WEAPON_TYPES.size()]
			attrs["持法"] = WEAPON_CATES[randi() % WEAPON_CATES.size()]
			for attr in ["攻击力", "重量"]:
				var rng = get_equip_attr_range(type, attr)
				attrs[attr] = Global.get_random(rng[0], rng[1])
		"防具":
			for attr in ["防御力", "重量"]:
				var rng = get_equip_attr_range(type, attr)
				attrs[attr] = Global.get_random(rng[0], rng[1])
		"道具":
			subtype = JEWELRY_TYPES[randi() % JEWELRY_TYPES.size()]
		"坐骑":
			for attr in ["马力", "机动力恢复"]:
				var rng = get_equip_attr_range(type, attr)
				attrs[attr] = Global.get_random(rng[0], rng[1])
			attrs["重量"] = 0
	features = []
	var possibles = get_possible_features(type, subtype)
	possibles.shuffle()
	if possibles.size() > 3:
		possibles.resize(3)
	for feature in possibles:
		var rng = get_equip_feature_range(type, feature)
		var val = Global.get_random(rng[0], rng[1])
		features.append([feature, val])
	return

func set_attrs(data: Dictionary) -> void :
	match type:
		"武器":
			for attr in ["攻击力", "重量"]:
				if attr in data:
					set_attr(attr, data[attr])
			if "持法" in data:
				attrs["持法"] = Global.strval(data["持法"])
			if not "持法" in attrs or not attrs["持法"] in WEAPON_CATES:
				attrs["持法"] = "长兵"
			attrs["防御力"] = 0
			attrs["图像"] = DEFAULT_ICON[type]
			if subtype in DEFAULT_WEAPON_ICON:
				attrs["图像"] = DEFAULT_WEAPON_ICON[subtype]
		"防具":
			for attr in ["防御力", "重量"]:
				if attr in data:
					set_attr(attr, data[attr])
			attrs["攻击力"] = 0
			attrs["图像"] = DEFAULT_ICON[type]
		"道具":
			attrs["图像"] = DEFAULT_ICON[type]
			if subtype in DEFAULT_JEWELRY_ICON:
				attrs["图像"] = DEFAULT_JEWELRY_ICON[subtype]
		"坐骑":
			for attr in ["马力", "机动力恢复"]:
				if attr in data:
					set_attr(attr, data[attr])
			attrs["重量"] = 0
			attrs["图像"] = DEFAULT_ICON[type]
	attrs["价格"] = 0
	attrs["品质"] = "S"
	return
	
func set_attr(attr: String, val) -> void :
	val = Global.intval(val)
	var rng = get_equip_attr_range(type, attr)
	val = max(rng[0], val)
	val = min(rng[1], val)
	val = int(val)
	attrs[attr] = val
	return


func get_feature(idx: int) -> Array:
	if idx < 0 or idx >= features.size():
		return ["", 0, "--"]
	if features[idx].size() != 2:
		return ["", 0, "--"]
	var feature = Global.strval(features[idx][0])
	if not feature in get_possible_features(type, subtype):
		return ["", 0, "--"]
	var val = Global.intval(features[idx][1])
	var desc = StaticManager.EQUIP_TAG_MAPPING[feature].format(["X", "X*100", "X*50"])
	return [feature, val, desc]

func set_feature(idx: int, feature: String, val: int) -> void :
	while idx >= features.size():
		features.append([])
	if not feature in get_possible_features(type, subtype):
		features[idx] = []
		return
	var rng = get_equip_feature_range(type, feature)
	val = max(rng[0], val)
	val = min(rng[1], val)
	val = int(val)
	features[idx] = [feature, val]
	return

static func get_possible_features(type: String, subtype: String) -> Array:
	var ret = []
	if not type in POSSIBLE_FEATURES:
		return ret
	var possible = POSSIBLE_FEATURES[type]
	match typeof(possible):
		TYPE_ARRAY:
			ret.append_array(possible)
		TYPE_DICTIONARY:
			if "默认" in possible:
				ret.append_array(possible["默认"])
			if subtype in possible:
				ret.append_array(possible[subtype])
	return ret


static func get_equip_attr_range(type: String, attr: String) -> PoolIntArray:
	var ret = {}
	var minVal = 1
	var maxVal = 1
	for equip in clEquip.all_equips(type):
		var val = equip.get_attr_int(attr)
		if val > maxVal:
			maxVal = val
		if val < minVal:
			minVal = val
	if attr == "防御力":
		
		maxVal = 12
	return PoolIntArray([minVal, maxVal])


static func get_equip_feature_range(type: String, feature: String) -> PoolIntArray:
	var ret = {}
	var minVal = 100
	var maxVal = 1
	for equip in clEquip.all_equips(type):
		for setting in equip.features():
			if not feature in setting:
				continue
			if "公式" in setting:
				
				continue
			var val = Global.intval(setting[feature])
			if val > maxVal:
				maxVal = val
			if val < minVal:
				minVal = val
	
	
	if feature == "允许射武将":
		return PoolIntArray([minVal, 100])
	return PoolIntArray([1, maxVal])
