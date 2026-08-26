# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/Static_Manager.gd
# 说明：静态数据表（自动加载，体量最大）。集中加载兵种、技能、地形、城市等静态配置数据，供全局查询。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Node

const EFFECT_PATH_ROOTS = [
	"effects/10000-affiars/", 
	"effects/20000-war/", 
	"effects/30000-battle/", 
	"effects/40000-solo/", 
]


const CURRENT_CHALLANGE_VERSION = 202603

const MAX_AVATAR_IMAGE_SIZE = 1024 * 1024

const GAME_SETTINGS = [
	{
		"name": "技能系统", 
		"options": {
			"default": ["否", "是"], 
		}, 
		"memo": {
			"default": "[color=yellow]是否开启武将技能系统？[/color]\n（武将技能已开始陆续更新）"
		}
	}, 
	{
		"name": "人物大限", 
		"options": {
			"default": ["有大限", "无大限"], 
		}, 
		"memo": {
			"default": "[color=yellow]武将是否会自然老死？[/color]\n有大限：到达大限时间有概率会老死。\n无大限：武将不会老死。"
		}
	}, 
	{
		"name": "出仕时间", 
		"options": {
			"default": ["正常", "快出", "提前5年", "提前10年", "提前15年", "提前20年", "提前30年"], 
			"stars": ["正常", "关闭"], 
		}, 
		"memo": {
			"default": "[color=yellow]武将的出仕时间如何？[/color]\n正常：按照正常出仕时间进行出仕。\n快出：全部在野/跟随武将都在游戏第一年出仕。", 
			"stars": "[color=yellow]武将的出仕时间如何？[/color]\n正常：星耀剧本，每月会有随机武将投奔。\n关闭：星耀剧本，选择关闭，不会有人投奔"
		}
	}, 
	{
		"name": "出仕地点", 
		"options": {
			"default": ["正常", "随机"], 
			"stars": ["随机"], 
		}, 
		"memo": {
			"default": "[color=yellow]武将的出仕地点在何处？[/color]\n正常：按照正常出仕地点。\n随机：武将出仕地点完全随机。", 
			"stars": "[color=yellow]武将的出仕地点在何处？[/color]\n星耀剧本：出仕地点只有「随机」选项"
		}
	}, 
	{
		"name": "监狱系统", 
		"options": {
			"default": ["无", "非君主", "全武将", "仅君主"], 
		}, 
		"memo": {
			"default": "[color=yellow]击杀武将时，将其收入监狱？[/color]\n无：不使用监狱系统。\n非君主：非君主被击杀时免疫死亡并收入监狱。\n全武将：击杀任何武将都会收入监狱。\n仅君主:只在击杀君主时将其收入监狱。"
		}
	}, 
	{
		"name": "自动复活", 
		"options": {
			"default": ["无", "全年", "1月", "2月", "3月", "4月", "5月", "6月", "7月", "8月", "9月", "10月", "11月", "12月"], 
		}, 
		"memo": {
			"default": "[color=yellow]武将死亡后在哪个月份自动复活？[/color]\n无：不会自动复活。\n全年：每个月初都会自动复活。"
		}
	}, 
	{
		"name": "武将成长", 
		"options": {
			"default": ["正常", "升级不加", "禁读书", "就不加"], 
		}, 
		"memo": {
			"default": "[color=yellow]武将属性将如何成长？[/color]\n正常：升级和读书都会加属性\n升级不加：只升级，属性不动\n禁读书：不能读书加属性，且开发不加德\n就不加：怎么都不加"
		}
	}, 
	{
		"name": "开局方式", 
		"options": {
			"default": ["默认", "全武将满级"], 
		}, 
		"fixed": true, 
		"memo": {
			"default": "[color=yellow]开局时的特殊设定？[/color]\n默认：无事发生\n全武将满级：所有武将开局8级，经验清零，属性是否成长，则与「武将成长」的设定有关"
		}
	}
]


func get_default_game_setting(drama: String = "", changeMode: bool = false) -> Dictionary:
	var ret = {}
	if changeMode:
		for setting in GAME_SETTINGS:
			var key = setting["name"]
			ret[key] = DataManager.get_game_setting(key)
	else:
		for setting in GAME_SETTINGS:
			var key = setting["name"]
			var options = setting["options"]["default"]
			if drama in setting["options"]:
				options = setting["options"][drama]
			ret[key] = options[0]
	return ret


func get_all_game_setting(drama: String = "", changeMode: bool = false) -> Array:
	var ret = []
	for setting in GAME_SETTINGS:
		var key = setting["name"]
		var options = setting["options"]["default"]
		if drama in setting["options"]:
			options = setting["options"][drama]
		var memo = setting["memo"]["default"]
		if drama in setting["memo"]:
			memo = setting["memo"][drama]
		var settingInfo = {
			"name": key, 
			"options": options, 
			"memo": memo, 
		}
		if changeMode and "fixed" in setting and setting["fixed"]:
			settingInfo["options"] = [DataManager.get_game_setting(key)]
		ret.append(settingInfo)
	return ret

const PATCH_ATTRS = [
	"体", "武", "知", "统", 
	"政", "德", "胆", 
]

const EQUIP_TAG_MAPPING = {
	"附加胆": "胆 +{0}", 
	"附加德": "德 +{0}", 
	"白兵免伤": "白刃战，武将免伤：+{0}%", 
	"攻击距离": "攻击距离至少为{0}", 
	"附加体上限": "体力上限 +{0}", 
	"白刃战动态胆": "白刃战，胆 +{0}", 
	"白刃战回体": "白刃战初始，体力回复 {0}", 
	"战术附加回合": "白刃战，战术回合 +{0}", 
	"白兵附加统": "白刃战，统 +{0}", 
	"白兵附加战术": "白刃战，战术值 +{0}", 
	"白兵减敌战术": "白刃战，敌方战术值 -{0}", 
	"单挑暴击率": "单挑暴击率 +{0}%", 
	"白兵全骑兵": "白刃战，非城地形，初始兵种为全骑（优先级：{0}）", 
	"白兵全步兵": "白刃战，初始兵种为全步（优先级：{0}）", 
	"白兵全弓兵": "白刃战，初始兵种为全弓（优先级：{0}）", 
	"白兵降统": "白刃战，敌将统 -{0}", 
	"白兵降胆": "白刃战，敌将胆 -{0}", 
	"团队经验加成": "团队经验 +{0}%", 
	"斜角攻击距离": "白刃战，武将可攻击斜角", 
	"白刃C按满体": "白刃战，武将减体不影响攻击力", 
	"白兵攻击力": "白刃战，武将攻击力 +{0}", 
	"五行": "大战场，五行固定为「{0}」", 
	"苦肉增强": "【苦肉】效果增强 {0}%", 
	"斩杀线": "白刃战，武将行动结束后，秒杀血量<={0}的一个相邻士兵", 
	"单挑格挡": "单挑可招架超过 {0} 的伤害", 
	"计策火抗": "大战场，计策火伤抗性 +{0}%", 
	"重量加成": "装备重量视为 +{0}", 
	"飞剑伤害": "大战场，每回合造成随机飞剑伤害。\n伤害：（我[德] - 敌[德]） * 2。\n最小30，最大 150。", 
	"全计策": "可发动所有计策", 
	"每日回体": "大战场，每日体力回复 +{0}", 
	"白兵动态胆": "白刃战，武将胆为 {0}", 
	"单挑免死": "战争中可抵御 {0} 次单挑致命伤害", 
	"开发提升": "开发土地产业 +{0}；开发人口 +{2}", 
	"开发附加人口": "开发土地产业时，人口 +{0}", 
	"计策消耗减少": "计策需机动力 -{0}", 
	"计策附加智力": "计策附加智力 +{0}", 
	"白兵射程": "白刃战，武将射程至少为 {0}", 
	"允许射武将": "白刃战，武将可以对体>={0}的敌将射箭", 
	"全队射程提升": "白刃战，全体射程 +{0}", 
	"射箭攻击回血": "白刃战，武将射箭回血 {0}%", 
	"近身攻击回血": "白刃战，武将近身回血 {0}%", 
	"距离增加倍率": "白刃战，武将射箭伤害倍率 +距离*{0}%", 
	"计视距离": "对{0}格外目标用计，按{0}格计算命中率", 
	"强制统系": "升级时若统<90，优先 +统", 
	"学习折扣": "读书所需经验为 {0}%", 
	"近身倍率加成": "白刃战，武将近身伤害 +{0}%", 
	"投掷距离": "白刃战，武将可对{0}格内单位投掷攻击", 
	"步兵嘲讽": "白刃战，对方士兵优先攻击我方步兵", 
	"影响全城征兵": "若为太守，同城武将可依据你的[统]计算士兵上限", 
	"咒缚成功率加成": "咒缚成功率 +[{0}]%", 
	"避免升级": "佩戴者战场不会触发升级", 
	"道术附加": "战场每日随机获得或提前解锁道术技能", 
	"兵力上限": "兵力上限至少 {0}", 
	"格挡率加成": "白刃战，武将额外格挡率至少为 {0}%", 
	"对步兵格挡率加成": "白刃战，武将对步兵有 {0}% 额外格挡率", 
	"重伤概率": "白刃战，武将攻击 {0}% 概率造成重伤", 
	"低德搜刮": "大战场，攻击获胜搜刮 [{0}-德] 两金", 
	"格返": "白刃战，武将格挡时触发反击", 
	"豁免敌将": "大战场为主将时，我方击败敌将可选择释放。战场首次发动，德 +1", 
	"二爷春秋": "战场可豁免敌将的效果，可无视主将身份；发动<义绝>时，无视拼点结果，自选效果。", 
	"神策附加": "战场每日随机获得上古神策", 
	"重量降低": "装备总重量 -{0}", 
	"战场跃马": "白刃战战败后，有[德/2]%概率跃马位移", 
	"额外后退": "白刃战，武将后退时可多退{0}步", 
	"单挑命中率加成": "单挑命中率 +{0}%", 
	"刚胆": "白刃战，0兵时不会降胆", 
	"阴阳归道": "大战场初始，可选择阴阳面四个技能", 
	"道书": "道家典籍，蕴藏未名的力量", 
	"移动机动力恢复": "大战场每次消耗机动力移动，次日机动力恢复 +{0}", 
	"动态马力": "马力视为 {0}", 
	"大战场缩地": "每日{0}次，无视贴身攻击并摈退敌将", 
	"避免白刃战": "武将不会出现在白刃战，无士兵被攻击则直接视为击败", 
	"疾驰": "白刃战，武将每回合第一动若为移动，可多一动", 
	"单挑MISS回体": "单挑，攻击未命中，体力 +{0}", 
	"菜市口经验": "大战场，有武将被击杀时，你的经验 +{0}", 
	"战斗获得机动力": "白刃战结束，机动力 +{0}", 
	"额外类型刀": "武器同时具备「刀」的特性", 
	"额外类型剑": "武器同时具备「剑」的特性", 
	"步兵伤停": "白刃战，敌兵对你的步兵单位造成伤害时，当轮行动次数归零", 
	"白刃战初始护甲": "白刃战初始，获得 X 点护甲，大战场每回合限 2 次。X = {0}", 
	"平军移动": "大战场移动时，机动力消耗不大于「平」军", 
	"水军移动": "大战场移动时，机动力消耗不大于「水」军", 
	"山军移动": "大战场移动时，机动力消耗不大于「山」军", 
	"白刃战最大受伤": "白刃战，武将受到攻击伤害最大值为 {0}", 
	"太守开发经验督导": "为太守时，城内武将开发经验 +{0}", 
	"恢复禁用技能": "大战场回合开始时，若你存在被禁用的技能，自动解除其中1个的禁用，大战场限1次", 
	"白兵免伤叠加": "白刃战回合内，武将每受到一次攻击，免伤倍率临时+{0}%，次回合归零", 
	"射箭抑制行动": "白刃战，被你射中的敌兵，其下一次行动次数-1。（每轮至多{0}个敌方士兵触发）", 
	"天遁": "天遁，你使用范围型道术时，无视城墙障碍", 
	"地遁": "地遁，大战场，五行固定为「土」", 
	"人遁": "人遁，白刃战，你无视地形阻碍", 
	"点数判定倍率": "你的点数作判定时，以 {0} 倍计", 
	"音律赋予机动力": "大战场，每日初始，有音律天赋的队友，机动力 +{0}", 
	"仙术无效": "大战场、白刃战，所有他人的仙属性技能，对你及你的士兵无效", 
	"技能无视等级限制": "无视等级限制，解锁未习得的技能", 
	"视为装备道具": "视为装备道具{1}", 
	"首次道术返还机动力": "每日首次发动道术，返还 {0}% 机动力", 
	"神策体力消耗减半": "发动上古神策，所需体力减半"
}


const RANDOM_VSTATE_LORD = 100
const RANDOM_VSTATE_COMMON = 101

class SkillEffect extends Resource:
	var skill: Skill
	var id: int
	var sceneId: int
	var type: String
	var triggerId: int
	var triggerType: String
	var triggerExceptional: bool
	
	var triggerTag: String
	
	var triggerTagVal: int
	
	var triggerEval: String
	
	var triggerTagValId: int
	
	var triggerCondition: String
	
	var appendSkill: bool
	
	var _appendedSkills: Array
	
	var _appendedSkillForActorId: int
	
	var terrianSpecified: PoolStringArray
	
	var terrianExcluded: PoolStringArray
	
	var role: String
	
	var dates: String
	
	var side: String
	
	var path: String
	
	var data: Dictionary

	func _init(_skill: Skill, effectData: Dictionary):
		skill = _skill
		data = effectData.duplicate(true)
		id = - 1
		sceneId = - 1
		
		path = ""
		if "ID" in effectData:
			id = Global.intval(effectData["ID"])
			sceneId = id - id % 10000
			var rootIdx = int(sceneId / 10000) - 1
			if rootIdx >= 0 and rootIdx <= EFFECT_PATH_ROOTS.size():
				path = "{0}effect_{1}.gd".format([
					EFFECT_PATH_ROOTS[rootIdx], id
				])
		type = ""
		if "类型" in effectData:
			type = Global.strval(effectData["类型"])
		if type == "光环" and "场景ID" in effectData:
			sceneId = Global.intval(effectData["场景ID"])
		triggerId = - 1
		if "触发ID" in effectData:
			triggerId = Global.intval(effectData["触发ID"])
		triggerType = ""
		if "触发范围" in effectData:
			triggerType = Global.strval(effectData["触发范围"])
		triggerExceptional = false
		if "异常发动" in effectData:
			triggerExceptional = true
		triggerTag = ""
		if "触发标签" in effectData:
			triggerTag = Global.strval(effectData["触发标签"])
		triggerTagVal = - 1
		if "标签值" in effectData:
			triggerTagVal = Global.intval(effectData["标签值"])
		triggerEval = ""
		if "动态标签值" in effectData:
			triggerEval = Global.strval(effectData["动态标签值"])
		triggerTagValId = 0
		if "标签变量" in effectData:
			triggerTagValId = Global.intval(effectData["标签变量"])
		triggerCondition = ""
		if "触发条件" in effectData:
			triggerCondition = Global.strval(effectData["触发条件"])
		appendSkill = false
		_appendedSkills = []
		_appendedSkillForActorId = - 1
		if "技能附加" in effectData:
			if Global.intval(effectData["技能附加"]) == 1:
				appendSkill = true
			else:
				var appendInfo = Global.dicval(effectData["技能附加"])
				if "skills" in appendInfo:
					_appendedSkills = Global.arrval(appendInfo["skills"])
				if "actorId" in appendInfo:
					_appendedSkillForActorId = Global.intval(appendInfo["actorId"])
		terrianSpecified = []
		if "地形要求" in effectData:
			terrianSpecified = Global.arrval(effectData["地形要求"])
		terrianExcluded = []
		if "地形排除" in effectData:
			terrianExcluded = Global.arrval(effectData["地形排除"])
		role = ""
		if "身份限定" in effectData:
			role = Global.strval(effectData["身份限定"])
		dates = ""
		if "战争天数" in effectData:
			dates = Global.strval(effectData["战争天数"])
		side = ""
		if "攻守限定" in effectData:
			side = Global.strval(effectData["攻守限定"])
		return

	
	func accept_terrian(terrian: String) -> bool:
		if not terrianSpecified.empty():
			if not terrian in terrianSpecified:
				return false
		if not terrianExcluded.empty():
			if terrian in terrianExcluded:
				return false
		return true

	
	func accept_battle_status(bf: BattleFight, actorId: int) -> bool:
		if bf == null:
			return false
		var wa = DataManager.get_war_actor(actorId)
		if wa == null:
			return false
		if not valid_for_war_side(wa):
			return false
		match role:
			"守方":
				if bf.get_defender_id() != actorId:
					return false
			"攻方":
				if bf.get_attacker_id() != actorId:
					return false
			"主将":
				if wa.get_main_actor_id() != actorId:
					if wa.get_buff_label_turn(["主将授权"]) <= 0:
						return false
		
		if not accept_terrian(bf.get_terrian()):
			return false
		return true

	func valid_for_date(wf: WarFight) -> bool:
		if wf == null:
			return false
		match dates:
			"奇":
				if wf.date % 2 == 0:
					return false
			"偶":
				if wf.date % 2 == 1:
					return false
		return true

	
	func valid_for_war_side(wa: War_Actor) -> bool:
		if wa == null:
			return false
		if side != "" and wa.side() != side:
			return false
		return true

	
	func valid_for_war_role(wa: War_Actor) -> bool:
		if wa == null:
			return false
		match role:
			"主将":
				if wa.get_main_actor_id() != wa.actorId:
					if wa.get_buff_label_turn(["主将授权"]) <= 0:
						return false
			"非主将":
				if wa.get_main_actor_id() == wa.actorId:
					return false
			"君主":
				if wa.get_main_actor_id() != wa.actorId:
					return false
				if wa.actor().get_loyalty() != 100:
					return false
			"攻方":
				if wa.war_vstate().is_reinforcement():
					return false
				if not wa.is_attacker():
					return false
			"守方":
				if wa.war_vstate().is_reinforcement():
					return false
				if not wa.is_defender():
					return false
		return true

	
	func get_basic_status(actorId: int) -> String:
		if "标记" in data:
			var flagName = Global.strval(data["标记"])
			var flagId = int(Global.dic_val(data, "标记ID", id))
			var flagSceneId = int(Global.dic_val(data, "标记场景ID", flagId - flagId % 10000))
			if flagSceneId <= DataManager.get_current_scene_id():
				var flags = SkillHelper.get_skill_flags_number(flagSceneId, flagId, actorId, flagName)
				return "已有标记 [color=blue][{0}][/color]： {1}".format([flagName, flags])
		if "关联装备" in data:
			var equip = get_related_equip(actorId)
			if equip != null:
				return "关联装备：[color=blue]" + equip.name() + "[/color]"
		if "附加信息" in data:
			var script = Global.load_script(path)
			script.actorId = actorId
			if script.has_method("get_ext_info"):
				var extInfo = script.get_ext_info()
				if extInfo != "":
					return "（" + extInfo + "）。"
		return ""

	
	
	
	func get_war_status(wf: WarFight, actorId: int) -> Array:
		
		var ret = [false, ""]
		var wa = DataManager.get_war_actor(actorId)
		if wa == null:
			ret[1] = "武将状态异常"
			return ret
		if "目标锁定" in data:
			var targetEffectId = int(Global.dic_val(data["目标锁定"], "ID", id))
			var targetSceneId = targetEffectId - targetEffectId % 10000
			var targetId = SkillHelper.get_skill_variable_int(targetSceneId, targetEffectId, wa.actorId)
			var targetName = Global.dic_val(data["目标锁定"], "默认表述", "默认")
			if targetId >= 0:
				var targetWA = DataManager.get_war_actor(targetId)
				if targetWA != null and not targetWA.disabled:
					targetName = targetWA.get_name()
			ret[1] = "当前关联武将：{0}".format([targetName])
		var cd = SkillHelper.get_skill_cd(20000, id, actorId, skill.name)
		if cd > 90000:
			if ret[1] == "":
				ret[1] = "限定技冷却中"
			return ret
		elif cd > 100:
			if ret[1] == "":
				ret[1] = "本场战争冷却"
			return ret
		elif cd > 0:
			if ret[1] == "":
				ret[1] = "冷却时间: {0}回合".format([cd])
			return ret
		if "动态解锁" in data:
			var unlockEffectId = Global.intval(data["动态解锁"])
			if unlockEffectId < 0:
				unlockEffectId = id
			if SkillHelper.get_skill_variable_int(20000, unlockEffectId, actorId) <= 0:
				ret[1] = "待解锁"
				return ret
		if not valid_for_date(wf):
			ret[1] = "今日不可发动"
			return ret
		
		var terrian = "unknown"
		if wa.has_position():
			var map = SceneManager.current_scene().get_node_or_null("war_map")
			if map != null:
				var blockCN = map.get_blockCN_by_position(wa.position)
				terrian = map.get_blockEN_by_CN(blockCN)
		if not accept_terrian(terrian):
			ret[1] = "不满足地形要求"
			return ret
		if not valid_for_war_side(wa):
			ret[1] = "仅限" + side
			return ret
		if not valid_for_war_role(wa):
			ret[1] = "仅限" + role
			return ret
		if "BUFF限定" in data:
			var valid = false
			var names = []
			for buff in Global.arrval(data["BUFF限定"]):
				buff = str(buff)
				names.append("[" + buff + "]")
				if wa.get_buff(buff)["回合数"] > 0:
					valid = true
					break
				if names.size() > 0 and not valid:
					if names.size() > 1:
						names[names.size() - 1] += "等"
				ret[1] = "未处于{0}状态，不可用".format(["/".join(names)])
				return ret
		ret[0] = true
		var ap = get_ap_cost(wa)
		if ap > 0:
			ret[0] = ap <= wa.action_point
			ret[1] = "需机动力：{0}/{1}".format([ap, wa.action_point])
			return ret
		var times = get_times_limit(wa)
		if times > 0:
			var used = SkillHelper.get_skill_variable_int(20000, id, wa.actorId, 0)
			ret[0] = used < times
			ret[1] = "限定次数：{0}/{1}".format([times - used, times])
			return ret
		if "经验消耗" in data:
			var cost = Global.intval(data["经验消耗"])
			if cost > 0 and "一次性消耗" in data:
				if SkillHelper.get_skill_variable_int(10000, id, wa.actorId) > 0:
					cost = 0
			if cost > 0:
				ret[0] = cost <= wa.actor().get_exp()
				ret[1] = "需经验：{0}/{1}".format([cost, wa.actor().get_exp()])
				return ret
		if "后备兵消耗" in data:
			var cost = Global.intval(data["后备兵消耗"])
			var fromCity = wa.war_vstate().from_city()
			var troops = fromCity.get_backup_soldiers()
			if cost == - 2:
				ret[0] = true
				ret[1] = "后备兵：{0}".format([troops])
				return ret
			elif cost > 0:
				ret[0] = cost <= troops
				ret[1] = "需后备兵：{0}/{1}".format([cost, troops])
				return ret
			elif cost < 0:
				ret[0] = troops > 0
				ret[1] = "至多需后备兵：{0}/{1}".format([abs(cost), troops])
				return ret
		if "关联装备" in data:
			var equip = get_related_equip(wa.actorId)
			if equip != null:
				ret[1] = "关联装备：" + equip.name()
				return ret
		if "变量标记" in data:
			var varId = int(Global.dic_val(data, "变量ID", id))
			var val = SkillHelper.get_skill_variable_int(sceneId, varId, wa.actorId, - 1)
			if val < 0:
				val = 0
				var vals = SkillHelper.get_skill_variable_int_array(sceneId, varId, wa.actorId)
				if not vals.empty():
					val = vals[0]
			ret[1] = "{0}：{1}".format([data["变量标记"], val])
			return ret
		if appendSkill or _appendedSkills.size() > 0:
			ret[1] = "技能附加"
			return ret
		if "标记" in data:
			var flagName = Global.strval(data["标记"])
			var flagId = int(Global.dic_val(data, "标记ID", id))
			var flagSceneId = int(Global.dic_val(data, "标记场景ID", flagId - flagId % 10000))
			var flags = SkillHelper.get_skill_flags_number(flagSceneId, flagId, wa.actorId, flagName)
			if "标记消耗" in data:
				var cost = Global.intval(data["标记消耗"])
				if cost == - 2:
					cost = int(max(flags, 1))
				ret[0] = cost <= flags
				ret[1] = "[{0}]: {1}/{2}".format([flagName, cost, flags])
			else:
				ret[1] = "[{0}]: {1}".format([flagName, flags])
		return ret

	func create_ske_for(actorId: int) -> SkillEffectInfo:
		var ske = SkillEffectInfo.new()
		ske.actorId = actorId
		ske.skill_name = skill.name
		ske.trigger_Id = triggerId
		ske.effect_type = type
		ske.effect_Id = id
		ske.skill_actorId = actorId
		return ske

	
	func get_ap_cost(wa: War_Actor) -> int:
		var cost = Global.dic_val(data, "机动力消耗", - 99)
		if cost == - 2:
			return int(max(wa.action_point, 1))
		if cost == - 1:
			var prevSke = SkillHelper.read_skill_effectinfo()
			var ske = create_ske_for(wa.actorId)
			SkillHelper.save_skill_effectinfo(ske)
			var script = Global.load_script(path)
			if script.has_method("get_cost_ap"):
				script._init()
				cost = int(script.call("get_cost_ap"))
			SkillHelper.save_skill_effectinfo(prevSke)
			script._init()
		if cost > 0:
			return cost
		return 0

	
	func get_times_limit(wa: War_Actor) -> int:
		var limit = Global.dic_val(data, "次数", 0)
		if limit > 0:
			return limit
		if limit == - 1:
			var prevSke = SkillHelper.read_skill_effectinfo()
			var ske = create_ske_for(wa.actorId)
			SkillHelper.save_skill_effectinfo(ske)
			var script = Global.load_script(path)
			if script.has_method("get_times_limit"):
				script._init()
				limit = int(script.call("get_times_limit"))
			SkillHelper.save_skill_effectinfo(prevSke)
			script._init()
		return limit

	
	func get_related_equip(actorId: int) -> clEquip.EquipInfo:
		if not "关联装备" in data:
			return null
		var type = Global.strval(data["关联装备"])
		var related = - 1
		var had = SkillHelper.get_skill_variable_int_array(10000, id, actorId)
		if not had.empty():
			related = had[0]
		else:
			related = SkillHelper.get_skill_variable_int(10000, id, actorId)
		if related < 0:
			return null
		var equip = clEquip.equip(related, type)
		if equip.name() == "":
			return null
		if equip.type in DataManager.get_actor_disabled_equip_types(actorId):
			equip.disabled = true
		return equip

	
	func accept_war_status(wf: WarFight, actorId: int) -> bool:
		return get_war_status(wf, actorId)[0]

	
	func accept_affair_status(actorId: int) -> bool:
		if role == "":
			return true
		var city = DataManager.get_office_city_by_actor(actorId)
		match role:
			"太守":
				if city == null or city.get_leader_id() != actorId:
					return false
			"君主":
				if city == null or city.get_lord_id() != actorId:
					return false
			"非君主":
				if city == null or city.get_lord_id() == actorId:
					return false
			"非太守":
				if city == null or city.get_lord_id() == actorId or city.get_leader_id() == actorId:
					return false
		return true

	
	func get_appended_skill_names(actorId: int) -> PoolStringArray:
		var ret = []
		if _appendedSkillForActorId >= 0 and _appendedSkillForActorId != actorId:
			return ret
		for appended in _appendedSkills:
			appended = str(appended)
			if appended.empty():
				continue
			ret.append(appended)
		return ret

	
	func get_specified_target_id(actorId: int):
		var targetEffectId = Global.dic_val_int(data, "指定目标")
		if targetEffectId <= 0:
			targetEffectId = id
		var targetSceneId = targetEffectId - targetEffectId % 10000
		return SkillHelper.get_skill_variable_int(targetSceneId, targetEffectId, actorId)


class Skill extends Resource:
	var name: String
	var type: String
	var scene: String
	var category: String
	var effects: Array
	var _exclusiveActorIds: PoolIntArray
	var _gendersOnly: PoolStringArray
	var _tags: PoolStringArray
	var raw_description: String
	var description: String
	var background: String
	var _extraData: Dictionary
	
	var upgradings: Array
	
	func _init(_name: String, effectData: Dictionary, infoData: Dictionary, extraData: Dictionary):
		name = _name
		type = effectData["类型"]
		scene = Global.dic_val(infoData, "scene", "")
		category = Global.dic_val(infoData, "category", "")
		_exclusiveActorIds = Global.intarrval(Global.dic_val(effectData, "专属", []))
		_gendersOnly = []
		if "性别" in effectData:
			
			_gendersOnly = [Global.strval(effectData["性别"])]
		_tags = Global.arrval(Global.dic_val(effectData, "标签", []))
		
		effects = []
		for effect in Global.arrval(effectData["效果"]):
			effects.append(SkillEffect.new(self, effect))
		
		raw_description = Global.dic_val(infoData, "desc", "")
		if not raw_description.ends_with("。"):
			raw_description += "。"
		description = "【{0}】{1}，{2}。{3}".format([
			name, scene, category, raw_description, 
		])
		
		background = Global.dic_val(infoData, "memo", "")
		for serial in ["①", "②", "③", "④", "⑤", "⑥", "⑦", "⑧", "⑨"]:
			background = background.replace(serial, "\n\n" + serial)
			background = background.replace("“\n\n" + serial, "“" + serial)
		while background.begins_with("\n"):
			background = background.trim_prefix("\n")
		
		_extraData = extraData.duplicate()
		
		upgradings = Global.arrval(Global.dic_val(effectData, "升级", []))
		return

	func get_runtime_description(actorId: int = - 1, bbcode: bool = false) -> String:
		var ret = description
		var prefix = "<" if not bbcode else "[color=blue]"
		var suffix = ">" if not bbcode else "[/color]"
		
		for effect in effects:
			var vars = Global.dic_val_int_array(effect.data, "动态变量")
			if vars.empty():
				continue
			var vals = vars.duplicate()
			if actorId >= 0:
				var sceneId = effect.id - effect.id % 10000
				vals = SkillHelper.get_skill_variable_int_array(sceneId, effect.id, actorId)
				if vals.empty() and vars.size() == 1:
					vals = [SkillHelper.get_skill_variable_int(sceneId, effect.id, actorId)]
					if vals[0] < 0:
						vals = vars
				elif vals.size() != vars.size():
					vals = vars
			for i in vars.size():
				if true:
					var original = "<var:{0}:{1}>".format([i, vars[i]])
					var replacement = prefix + str(vals[i]) + suffix
					if vals[i] < 0:
						replacement = ""
					ret = ret.replace(original, replacement)
				if true:
					var original = "<varname:{0}:{1}>".format([i, vars[i]])
					var replacement = "未分配"
					if vals[i] >= 0:
						replacement = prefix + ActorHelper.actor(vals[i]).get_name() + suffix
					ret = ret.replace(original, replacement)
				if true:
					var original = "<varself:{0}:{1}>".format([i, vars[i]])
					var replacement = "你"
					if vals[i] >= 0:
						replacement = prefix + ActorHelper.actor(vals[i]).get_name() + suffix
					ret = ret.replace(original, replacement)
		if actorId < 0:
			return ret
		
		for targetName in ["你", "未指定"]:
			var targetPiece = "<" + targetName + ">"
			if ret.find(targetPiece) >= 0:
				var target = targetName
				for effect in effects:
					var targetId = effect.get_specified_target_id(actorId)
					if targetId >= 0:
						target = ActorHelper.actor(targetId).get_name()
						break
				ret = ret.replace(targetPiece, prefix + target + suffix)
		
		for serial in ["①", "②"]:
			if serial in ret:
				ret = ret.replace(serial, "\n" + serial)
		return ret

	
	func valid_for_actor(actorId: int) -> bool:
		if not gender_valid_for_actor(actorId):
			return false
		if not exclusive_valid_for_actor(actorId):
			return false
		return true

	func gender_valid_for_actor(actorId: int) -> bool:
		if _gendersOnly.empty():
			return true
		var actor = ActorHelper.actor(actorId)
		return actor.get_gender() in _gendersOnly

	func exclusive_valid_for_actor(actorId: int) -> bool:
		if _exclusiveActorIds.empty():
			return true
		return actorId in _exclusiveActorIds

	
	func has_feature(tag: String) -> bool:
		return tag in _tags

	
	func background_for(actorId: int) -> String:
		if actorId < 0:
			return background
		var lastPos = background.find("1.")
		if lastPos < 0:
			return background
		var intro = background.left(lastPos)
		var segments = []
		for i in range(2, 99):
			var prefix = str(i) + "."
			var pos = background.find(prefix, lastPos)
			var length = pos - lastPos - 2
			if pos < 0:
				length = background.length() - lastPos - 2
			segments.append(background.substr(lastPos + 2, length))
			if pos < 0:
				break
			lastPos = pos
		var actor = ActorHelper.actor(actorId)
		var name = actor.get_name()
		for segment in segments:
			if segment.find("[" + name + "]") >= 0:
				segment = segment.replace("[" + name + "]", "[color=blue]" + name + "[/color]")
				if intro == "":
					return segment
				return intro + "\n" + segment
			if segment.find(name) >= 0:
				segment = segment.replace(name, "[color=blue]" + name + "[/color]")
				if intro == "":
					return segment
				return intro + "\n" + segment
		return intro

	
	func get_extended_info(actorId: int) -> Dictionary:
		var ret = {}
		var actor = ActorHelper.actor(actorId)
		for key in _extraData:
			match _extraData[key]:
				"势力名":
					var vstateId = - 1
					if key == "势力":
						var city = DataManager.get_office_city_by_actor(actorId)
						if city != null:
							vstateId = city.get_vstate_id()
					else:
						vstateId = actor._get_attr_int(key)
					if vstateId < 0:
						ret[key] = "--"
					else:
						ret[key] = clVState.vstate(vstateId).get_lord_name() + "#" + str(vstateId)
				"指定势力名":
					var vstateId = int(str(key).split("#")[1])
					if vstateId < 0:
						ret[key] = "--"
					else:
						ret[key] = clVState.vstate(vstateId).get_lord_name()
		return ret

	
	func get_effect(id: int) -> SkillEffect:
		for effect in effects:
			if effect.id == id:
				return effect
		return null

	
	func visible() -> bool:
		
		return scene != ""

	
	func upgraded_for_actor(actorId: int) -> String:
		for upd in upgradings:
			var id = Global.dic_val(upd, "ID", - 1)
			if id < 0:
				continue
			if SkillHelper.get_skill_variable_int(10000, id, actorId) <= 0:
				continue
			return Global.dic_val(upd, "技能", "")
		return ""

	
	func can_be_banned() -> bool:
		if has_feature("规则"):
			return false
		return true


var RE_ALPHA: RegEx = RegEx.new()


const YISHI_COST = 4999

const COLOR_CODE_SPECIAL_EQUIP = "#E11F1F"
const COLOR_SPECIAL_EQUIP = Color(COLOR_CODE_SPECIAL_EQUIP)
const COLOR_CODE_MODED_EQUIP = "#1F6FC1"
const COLOR_MODED_EQUIP = Color(COLOR_CODE_MODED_EQUIP)
const COLOR_HIGHLIGHTED = Color("#1E45CD")
const COLOR_CAPTURED = Color("#808080")
const COLOR_EXCEEDED = Color("#4169E1")
const COLOR_LOW = Color.red

const TACTICS = {
	"咒缚": {"消耗": 3, "描述": "有{咒缚成功率}%的概率使敌将不能移动。"}, 
	"挑衅": {"消耗": 5, "描述": "向敌将提出一对一单挑。若对方拒绝，敌人士气还会下降一定值。"}, 
	"强弩": {"消耗": 7, "描述": "使己方射箭距离增加2格。"}, 
	"士气向上": {"消耗": 8, "描述": "振奋士气，提高武将和所有士兵单位的攻击力、防御力。"}, 
	"火矢": {"消耗": 10, "描述": "箭矢点火，提高己方弓箭伤害，并无视对方士兵1/3防御力。"}
}

const ACTOR_ID_SLIME_GOD = - 5
const ACTOR_ID_CAOCAO = 2
const ACTOR_ID_CAOREN = 4
const ACTOR_ID_DONGZHUO = 15
const ACTOR_ID_GAOLAN = 20
const ACTOR_ID_GUANYU = 25
const ACTOR_ID_LIUBEI = 46
const ACTOR_ID_LIUXIE = 49
const ACTOR_ID_LVBU = 53
const ACTOR_ID_SUNCE = 64
const ACTOR_ID_SUNJIAN = 65
const ACTOR_ID_WENCHOU = 72
const ACTOR_ID_WUYI = 73
const ACTOR_ID_XIAHOUYUAN = 75
const ACTOR_ID_YANLIANG = 81
const ACTOR_ID_YUANSHU = 87
const ACTOR_ID_ZHANGFEI = 94
const ACTOR_ID_CAOCHUN = 109
const ACTOR_ID_PANFENG = 119
const ACTOR_ID_GAOSHUN = 150
const ACTOR_ID_CHENGYU = 170
const ACTOR_ID_ZHANGHE = 206
const ACTOR_ID_ZHOUYU = 208
const ACTOR_ID_ZHAOYUN = 227
const ACTOR_ID_ZHANGJIAO = 255
const ACTOR_ID_ZHANGBAO_HJ = 257
const ACTOR_ID_MACHAO = 273
const ACTOR_ID_WANGCAN = 283
const ACTOR_ID_SUNQUAN = 293
const ACTOR_ID_CAOPI = 344
const ACTOR_ID_XUSHU = 346
const ACTOR_ID_PANGTONG = 361
const ACTOR_ID_CAOZHI = 363
const ACTOR_ID_ZHUGELIANG = 364
const ACTOR_ID_MENGHUO = 432
const ACTOR_ID_JIANGWEI = 435
const ACTOR_ID_LIUSHAN = 450
const ACTOR_ID_ZHONGHUI = 487
const ACTOR_ID_DIY = 546
const ACTOR_ID_LIUBIAN = 552
const ACTOR_ID_LVLINGQI = 558
const ACTOR_ID_RENOU = 999999

const CITY_ID_XIANGPING = 0
const CITY_ID_WUWEI = 16
const CITY_ID_XIANGYANG = 22
const CITY_ID_XINYE = 40

const VSTATEID_CAOCAO = 2
const VSTATEID_SUNJIAN = 3
const VSTATEID_LIUBEI = 4
const VSTATEID_RANDOM = 17

const WEAPON_ID_YITIAN = 6
const WEAPON_ID_GUDING = 13
const WEAPON_ID_LONGYA = 14
const WEAPON_ID_YANYUE = 15
const WEAPON_ID_HUAJI = 21
const WEAPON_ID_LANGYA = 22
const WEAPON_ID_SHEMAO = 23
const WEAPON_ID_YAJIAO = 25
const WEAPON_ID_YINQIANG = 26
const WEAPON_ID_TIEJILI = 28
const WEAPON_ID_FANGTIANJI = 29
const WEAPON_ID_GUANSHI = 36
const WEAPON_ID_RIYUESHUANGDAO = 45

const SUIT_ID_JIAZHOU = 4
const SUIT_ID_SHENGZHE = 6
const SUIT_ID_SHIKUI = 9
const SUIT_ID_SHIKUI_BROKEN = 10
const SUIT_ID_YANXINJING = 14

const JEWELRY_ID_BINGSHU = 0
const JEWELRY_ID_WANDANGONG = 9
const JEWELRY_ID_JIANGYIN = 11
const JEWELRY_ID_JIEZISHU = 12
const JEWELRY_ID_QINGGANGJIAN = 13
const JEWELRY_ID_CHAOFENGLING = 16
const JEWELRY_ID_TONGBENMA = 18
const JEWELRY_ID_HANFEIZI = 20
const JEWELRY_ID_YIJING = 23
const JEWELRY_ID_CHUSHOUFA = 26
const JEWELRY_ID_WUZHU = 27
const JEWELRY_ID_GUYINGFA = 28

const STEED_BAIJU = 2
const STEED_HANXUE = 3
const STEED_DILU = 4
const STEED_SILUNCHE = 8
const STEED_LIFEISHA = 11

const HEBEI_4_BACKBONES = [
	ACTOR_ID_ZHANGHE, 
	ACTOR_ID_GAOLAN, 
	ACTOR_ID_YANLIANG, 
	ACTOR_ID_WENCHOU, 
]

const AI_ORDERBOOK_COUNT = [5, 7, 10, 10, 10]


const DAOSHU_SKILLS = [
	"呼风", "唤雨", "雷击", "撒豆", 
	"飞砂", "走石", "离火", "符水", 
]


const SHENCE_SKILLS = [
	"落雷", "火神", "激石", "水龙", 
]


const EVENT_WAIT_SECONDS = 2.3


const NO_SE_WAIT_TIME = 1

const DIFFICULTY_NAMES = ["简单", "普通", "困难", "究极", "挑战"]
const NEARBY_DIRECTIONS = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
const NEARBY_DIRECTION_NAMES = {
	Vector2.UP: "上", 
	Vector2.DOWN: "下", 
	Vector2.LEFT: "左", 
	Vector2.RIGHT: "右", 
}
const ALL_DIRECTIONS = [
	Vector2( - 1, - 1), Vector2.UP, Vector2(1, - 1), 
	Vector2.LEFT, Vector2.ZERO, Vector2.RIGHT, 
	Vector2( - 1, 1), Vector2.DOWN, Vector2(1, 1), 
]
const ALL_DIRECTION_NAMES = [
	"西北", "正北", "东北", 
	"正西", "", "正东", 
	"西南", "正南", "东南", 
]

const CITY_BLOCKS_CN = ["城门", "城墙", "太守府"]
const CITY_BLOCKS_EN = ["walldoor", "wall", "wallcity"]
const BASIC_TACTICS = ["咒缚", "强弩", "士气向上", "火矢"]
const CONTINUOUS_TACTICS = ["咒缚", "强弩", "士气向上", "火矢", "传教", "连弩", "骁果", "枪阵", "刺骑", "神威"]
const EQUIPMENT_TYPES = ["武器", "防具", "道具", "坐骑"]
const WAR_BUFF_STATUSES = {
	"八阵": "石", 
	"八阵*": "石", 
	"定止": "止", 
	"迟滞": "滞", 
	"围困": "困", 
	"疲兵": "疲", 
	"伤神": "伤", 
	"中毒": "毒", 
	"愈合": "愈", 
	"禁止攻击移动": "禁", 
	"诱敌": "诱", 
	"禁止攻击用计": "禁", 
	"神佑": "佑", 
	"禁策": "禁", 
	"禁技": "禁", 
	"禁诱": "禁", 
	"禁兵": "禁", 
	"罢兵": "罢", 
	"潜行": "潜", 
	"沉默": "默", 
	"主将授权": "权", 
	"恶评": "恶", 
	"探明": "明", 
	"激励": "励", 
	"借露": "露", 
}

const BLOCKS_EN_CN = {
	"wall": "城墙", 
	"walldoor": "城门", 
	"desert": "沙漠", 
	"forest": "树林", 
	"hill": "山地", 
	"land": "平原", 
	"equip": "装备店", 
	"rice": "米屋", 
	"hospital": "医馆", 
	"village": "村庄", 
	"river": "河流", 
	"swamp": "沼泽", 
	"wallcity": "太守府", 
}

const KEY_SETTING_PATH = "user://keyboard_set.json"
const HIDE_KEY_SETTING_PATH = "user://hide_key.json"
const JOY_BUTTON_PREFIX = "JoyButton_"

const TIPS = [
	"“策略-祈祷”可以召唤异士，异士虽贵，却未必强", 
	"有些技能可以打乱敌人的阵型，配合计策起到奇效", 
	
	"“久居山野”表示武将对你不感冒，【荐才】可破", 
	"“策略-访隐”可以探查出仕情况、寻找失踪人口", 
	"“任命-防御出阵”可以设置防守出战的前十人", 
	"白兵时，武将行动选择“包围”，就不会射箭", 
	"武将当前的最高属性，决定了升级加点的路线", 
	"“士气向上”不加士气，而是直接影响攻防", 
	"士气是小兵的基础攻击力，由武将的统、武决定", 
	"白兵战武将的攻击力，由武和胆共同决定", 
	"白兵战武将有几率格挡攻击，胆越高几率越大", 
	"游戏月更，请到群文件获取最新版", 
	"武将的技能会逐步设计和更新，一起耐心等待吧", 
	"武将读书可以用经验换取能力成长", 
	"发展内政也可以获得经验，但只有上战场才会升级", 
	"战斗中，队友也可以获得 1/8 的组队经验", 
	"白兵战和计策伤兵获得的经验数都等于伤兵数", 
	"内政指令，看的是武将的“政”，而不是“知”", 
	"传闻武威、襄平、夷州、永昌战场，有卖强力装备", 
	"大多数强力装备只有一件存货，物以稀为贵", 
	"“易招揽武将”加入特定势力的概率是13/15", 
	"“易招揽武将”加入非特定势力的概率是2/15", 
	"单将进入白兵战，胆会降低，对面统会提升", 
	"狼牙枪不是象拔蚌，没有全象兵这种说法", 
	"按\"选择\"键，装备可以批量购买，注意看提示", 
	"单挑俘虏或杀死对手，可以夺取他的部分经验", 
	"单挑胜利可以夺取对手装备，但需要类型相同", 
	"武将死亡，等级、经验、装备都不会消失", 
	"战场上，武将的五行和点数每天随机刷新", 
	"五行和点数与一些技能的效果相关，比如蔡琰", 
	"一些武将有<阴><阳>两面，大概是不同的人生吧", 
	"卡死不要着急，菜单-卡死修复可解，记得报BUG", 
	"有些后期武将很值得祈祷提前招募，比如杜预", 
	"技能产生的“额外回合”，只有特定的武将能行动", 
	"士兵变金色？别担心，是因为有良性buff", 
	"除非特别说明，游戏更新不会影响旧档继续", 
	"手机版如果无法存档，请给应用授予读写权限", 
	"存档文件的位置，在存档时会在下方显示", 
	"被你流放的武将会怀恨在心，拒绝你的招募", 
	"在武将列表界面，[选择]键可以切换排序", 
	"在内政地图，[开始]键可以快速切换浏览城市", 
	"在战场地图，[开始]键可以快速切换浏览部队", 
	"分配兵力时，[X]键一键满配，[Y]键一键清零", 
	"输入数字时，按[选择]/[开始]分别是最小/最大", 
	"单挑击杀对方君主，可抢夺对方势力的装备库", 
	"计策“要击”、“落石”的伤害，由用计者武力决定", 
	"在计算忠诚度时，君主的忠\"--\"视为100", 
	"武将八级并不都是四弓六骑，还需要统80以上", 
	"大战场[选择]键可以查看战争状态，注意粮草", 
	"战争状态界面，按[开始]键可以查看技能日志", 
	"象兵不是骑兵，但被打疼的大象会暴走，很可怕", 
	"大城市有一些特殊优待，比如全部普通道具有售", 
	"开局时按住「开始」键选君主，可进入观海模式", 
	"内政-寺庙-归隐山林，可进入观海模式", 
	"观海模式下，按住「开始」键不放，过月可接管", 
	"小战场战术界面，「开始」键可同时调整全兵种", 
]


var lastPath: String = "UNKNOWN"
var lastDrama: String = "UNKNOWN"


var dramas = []


var game_init_done: bool = false

var citys


var actors = []


var actor_patches: Dictionary = {}


var custom_equips: Array = []
const CUSTOM_EQUIP_MIN_ID = 10000


var old_skills

var actor_skills


var stratagems = []

var stratagemDic = {}

var buffDic = {}

var areaEffectsDic = {}

var citys_unoffice
var actor_follower
var vstates_static

var animations
var animation_detail_data

var animationImageCache: Dictionary = {}


var equipment_image
var weapons_static
var suits_static
var jewelrys_static
var steeds_static

var items_static


var actor_special_titles: Dictionary = {}

var multi_face: Dictionary = {}


var temp_data


var attribute_set: Dictionary = {}


var war_actor_location_system: Dictionary = {}


var war_map_blocks_img: Texture = null
var war_map_blocks_info: Array = []


var battle_map_data: Dictionary = {}


var story_data: Dictionary = {}


var qa_data: Array = []


var war_map_data: Dictionary = {}


var mod_info_cache: Dictionary = {}


var wiki_items: Dictionary = {}


var face_x_sheet = null


var special_avatars: Dictionary = {}


const ORIGINAL_AVATAR_COUNT = 4
const ORIGINAL_AVATAR_PER_HEIGHT = 40
var original_avatars: Array = []


var extra_avatars: Dictionary = {}


var skillDict: Dictionary = {}


var saveIdx: SaveDataIndex

func _ready():
	RE_ALPHA.compile("^[a-zA-Z]+$")
	saveIdx = SaveDataIndex.new()
	return

var packed = false
func repack_resources() -> void :
	if not DataManager.is_developer():
		return
	DataManager.game_trace("")
	print("-- REPACK BEGIN --")
	if packed:
		return
	var packer = PCKPacker.new()
	var packfile = "resource/bwdl.pck.json"
	packer.pck_start(packfile)
	packer.add_file("res://packed/mod.json", "resource/mod.json")
	for f in Global.scan_all_files("resource/data"):
		if not f.ends_with(".json"):
			continue
		var packed_path = f.replace("resource/data/", "res://packed/data/")
		packer.add_file(packed_path, f)
	for f in Global.scan_all_files("resource/sgz_script/"):
		if not f.ends_with(".gd"):
			continue
		var packed_path = f.replace("resource/sgz_script/", "res://packed/sgz_script/")
		packer.add_file(packed_path, f)
	for f in Global.scan_all_files("resource/images"):
		var packed_path = f.replace("resource/images/", "res://packed/images/")
		packer.add_file(packed_path, f)
	packer.flush()
	var f = File.new()
	f.open(packfile, File.READ)
	var data = f.get_buffer(f.get_len())
	f.close()
	var d = Directory.new()
	d.remove(packfile)
	var signature = crypto_sign(data)
	packfile = packfile.replace(".json", "")
	f.open(packfile, File.WRITE)
	f.store_64(signature.size())
	f.store_buffer(signature)
	f.store_buffer(data)
	f.close()
	packed = true
	DataManager.game_trace("REPACK")
	return

var reloaded = false
# 原版：加载并验签 res://resource/bwdl.pck（RSA 签名包裹的标准 PCK）。
# 反编译版：已把 pck 内容解包为 res://packed/ 下的真实文件（data / images / sgz_script），
# 因此这里直接跳过 pck 加载，游戏后续通过 res://packed/ 路径直接读取文件。
func reload_packed_resources() -> void :
	if reloaded:
		return
	DataManager.grouped_trace("")
	DataManager.grouped_trace("REPACK")
	reloaded = true
	return




func reload(mod_path: String, drama_name: String = ""):
	if mod_path == lastPath and drama_name == lastDrama:
		return
	lastPath = mod_path
	lastDrama = drama_name
	DataManager.grouped_trace("")
	reload_packed_resources()
	DataManager.grouped_trace("LD-PCK")
	mod_path = mod_path.replace("res://resource", "res://packed")
	dramas = parse_json(_get_file_content(mod_path, "", "drama/drama.json"))
	attribute_set = parse_json(_get_file_content(mod_path, drama_name, "attribute_set.json"));
	citys = parse_json(_get_file_content(mod_path, drama_name, "citys.json"));
	actors = parse_json(_get_file_content(mod_path, drama_name, "actors.json"))

	reload_and_apply_actor_patches()

	
	var actors_extra = {}
	for row in parse_json(_get_file_content(mod_path, drama_name, "actors_extra.json")):
		if not "ID" in row:
			continue
		var key = str(row["ID"])
		row.erase("ID")
		actors_extra[key] = row
	for actor in actors:
		var key = str(actor["ID"])
		if not key in actors_extra:
			continue
		for attr in actors_extra[key]:
			actor[attr] = actors_extra[key][attr]
	old_skills = parse_json(_get_file_content(mod_path, drama_name, "old_skills.json"));
	
	
	actor_skills = parse_json(_get_file_content(mod_path, drama_name, "actor_skills.json"))
	if DataManager.is_beta_version():
		actor_skills = parse_json(_get_file_content(mod_path, drama_name, "actor_skills_full.json"))

	stratagems = _load_stratagems(_get_file_content(mod_path, "", "skill_system/stratagem.json"))
	stratagemDic = {}
	for s in stratagems:
		stratagemDic[s.name] = s
	buffDic = {}
	for buff in _load_buffs(_get_file_content(mod_path, "", "skill_system/buff.json")):
		buffDic[buff.name] = buff

	citys_unoffice = parse_json(_get_file_content(mod_path, drama_name, "citys_unoffice.json"));
	actor_follower = parse_json(_get_file_content(mod_path, drama_name, "actor_follower.json"));
	vstates_static = parse_json(_get_file_content(mod_path, drama_name, "vstates.json"));
	animations = parse_json(_get_file_content(mod_path, drama_name, "animation.json"));
	
	equipment_image = Global.load_pic_with_cache("res://resource/images/equipment.png")
	weapons_static = parse_json(_get_file_content(mod_path, drama_name, "equip/weapons.json"))
	suits_static = parse_json(_get_file_content(mod_path, drama_name, "equip/suits.json"))
	jewelrys_static = parse_json(_get_file_content(mod_path, drama_name, "equip/jewelrys.json"))
	steeds_static = parse_json(_get_file_content(mod_path, drama_name, "equip/steeds.json"))
	
	
	
	reload_and_apply_equip_patches()

	items_static = parse_json(_get_file_content(mod_path, drama_name, "items.json"));
	
	multi_face = parse_json(_get_file_content(mod_path, drama_name, "multi_face.json"))
	actor_special_titles = {}
	var titles = parse_json(_get_file_content(mod_path, drama_name, "actor_special_titles.json"))
	for item in titles:
		var key = ""
		if item.has("面"):
			if item["面"] == "阳":
				key += "+"
			elif item["面"] == "阴":
				key += "-"
		if item.has("NICK"):
			key += "N"
			var nicks = item["NICK"].split(",")
			if nicks.size() > 0:
				actor_special_titles[key + ".{FROM}.{TO}".format(item)] = nicks[0]
			if nicks.size() > 1:
				actor_special_titles[key + ".{TO}.{FROM}".format(item)] = nicks[1]
		if item.has("DISS"):
			key += "D"
			var disses = item["DISS"].split(",")
			if disses.size() > 0:
				actor_special_titles[key + ".{FROM}.{TO}".format(item)] = disses[0]
			if disses.size() > 1:
				actor_special_titles[key + ".{TO}.{FROM}".format(item)] = disses[1]

	var skill_effects = parse_json(_get_file_content(mod_path, drama_name, "skill_system/skill.json"))
	var skills_text = parse_json(_get_file_content(mod_path, drama_name, "description/skills.json"))
	var skills_info = parse_json(_get_file_content(mod_path, drama_name, "description/skills_info.json"))
	skillDict.clear()
	for skill in skill_effects:
		var texts = {}
		if skill in skills_text:
			texts = skills_text[skill]
		var info = {}
		if skill in skills_info:
			info = skills_info[skill]
		var si = Skill.new(skill, skill_effects[skill], texts, info)
		skillDict[si.name] = si
	war_actor_location_system = parse_json(_get_file_content(mod_path, drama_name, "war_actorlocation_system.json"))

	
	war_map_blocks_img = Global.load_pic_with_cache("res://resource/images/war_mapblock/blocks.png")
	war_map_blocks_info = parse_json(_get_file_content(mod_path, "", "../images/war_mapblock/blocks.json"))

	
	battle_map_data = parse_json(_get_file_content(mod_path, drama_name, "battle_map.json"))

	
	
	story_data = parse_json(_get_file_content(mod_path, drama_name, "story.json"))
	
	war_map_data = parse_json(_get_file_content(mod_path, drama_name, "war_map.json"))
	
	qa_data = parse_json(_get_file_content(mod_path, drama_name, "description/QA.json"))
	
	animation_detail_data = parse_json(_get_file_content(mod_path, drama_name, "animation_detail.json"))
	
	wiki_items = parse_json(_get_file_content(mod_path, drama_name, "wiki_items.json"))
	
	mod_info_cache = {}
	get_mod_info(mod_path)

	
	if face_x_sheet == null:
		face_x_sheet = Global.load_pic_with_cache("res://resource/images/actor/face/face-X.png")
	
	if special_avatars.empty():
		special_avatars = preload_special_avatars()
	
	if original_avatars.empty():
		original_avatars = preload_original_avatars()
	
	if extra_avatars.empty():
		extra_avatars = preload_extra_avatars()
	return


func _get_file_path(mod_path: String, drama_name: String, file_name: String) -> String:
	var path = mod_path + "data/" + file_name
	var default_path = path
	if drama_name != "":
		path = mod_path + "data/drama/" + drama_name + "/" + file_name
		if not Global.file_exists(path):
			path = default_path
	path = path.replace("data/../", "")
	return path


func _get_file_content(mod_path: String, drama_name: String, file_name: String) -> String:
	DataManager.grouped_trace("")
	var path = _get_file_path(mod_path, drama_name, file_name)
	var ret = Global.get_file_text(path)
	DataManager.grouped_trace("FILE")
	return ret

func all_drama_info() -> Dictionary:
	var ret = []
	for drama in dramas:
		if not bool(drama["enabled"]):
			if not bool(drama["testing"]):
				continue
			if not DataManager.is_test_player():
				continue
		ret.append(drama)
	return ret

func get_drama_info(drama_path: String) -> Dictionary:
	var dramas = all_drama_info()
	for drama in dramas:
		if drama["path"] == drama_path:
			return drama
	return dramas[0]

func get_drama_events(drama_path: String) -> Array:
	var drama = get_drama_info(drama_path)
	var ret = []
	if not "events" in drama:
		return ret
	for event in drama["events"]:
		var dic = {
			"name": event, 
			"script": DataManager.mod_path + "sgz_script/events/event_" + event + ".gd", 
		}
		ret.append(dic)
	return ret

func get_starting_year(drama_path: String) -> int:
	return int(get_drama_info(drama_path)["fromYear"])

func get_starting_month(drama_path: String) -> int:
	return int(get_drama_info(drama_path)["fromMonth"])

func get_levelup_setting() -> Dictionary:
	return Dictionary(attribute_set["其他"]["升级设置"]).duplicate(true)

func get_solo_rate_setting() -> Array:
	return Array(attribute_set["单挑"]["单挑命中率"]).duplicate(true)

func get_vstate_easy_actor_setting() -> Dictionary:
	return Dictionary(attribute_set["内政"]["势力易招武将"]).duplicate(true)

func get_move_ap_setting() -> Dictionary:
	return Dictionary(attribute_set["大战场"]["行军消耗机动力"]).duplicate(true)

func get_battle_troops_setting() -> Dictionary:
	return Dictionary(attribute_set["小战场"]["兵种设定"]).duplicate(true)

func get_battle_soldiers_setting() -> Dictionary:
	return Dictionary(attribute_set["小战场"]["兵种数量"]).duplicate(true)

func get_battle_action_seq_setting() -> PoolStringArray:
	return PoolStringArray(Array(attribute_set["小战场"]["行动顺序"]).duplicate(true))

func get_battle_ignore_block_setting() -> Dictionary:
	return Dictionary(attribute_set["小战场"]["军种-无视地形"]).duplicate(true)

func get_equip_shop_setting() -> Dictionary:
	return Dictionary(attribute_set["其他"]["装备店种类"]).duplicate(true)

func get_develop_setting() -> Dictionary:
	return Dictionary(attribute_set["内政"]["城镇开发"]).duplicate(true)

func get_search_setting() -> Array:
	return Array(attribute_set["内政"]["搜索结果"]).duplicate(true)

func get_orderbook_setting() -> Array:
	return Array(attribute_set["内政"]["命令书"]).duplicate(true)

func get_formation_setting(formation: int) -> Dictionary:
	var formationSettings = Array(attribute_set["小战场"]["布阵"])
	if formation < 0 or formation >= formationSettings.size():
		formation = 0
	return formationSettings[formation].duplicate(true)

func get_pick_lord_setting() -> Dictionary:
	return Dictionary(attribute_set["其他"]["君主选择画面"]).duplicate(true)

func get_battle_blocks_setting() -> Dictionary:
	return Dictionary(attribute_set["小战场"]["障碍"]).duplicate(true)

func get_actor_self_title(actorId: int) -> String:
	var keys = ["N.{0}.{0}"]
	var actor = ActorHelper.actor(actorId)
	if actor.has_side():
		if actor.is_side_positive():
			keys.insert(0, "+N.{0}.{0}")
		else:
			keys.insert(0, "-N.{0}.{0}")
	for key in keys:
		key = key.format([actorId])
		if actor_special_titles.has(key):
			return actor_special_titles[key]
	return ""

func get_actor_honored_title(actorId: int, fromId: int) -> String:
	var keys = ["N.{0}.{1}"]
	var fromActor = ActorHelper.actor(fromId)
	var targetActor = ActorHelper.actor(actorId)
	if fromActor.has_side():
		if fromActor.is_side_positive():
			keys.insert(0, "+N.{0}.{1}")
		else:
			keys.insert(0, "-N.{0}.{1}")
	if targetActor.has_side():
		if targetActor.is_side_positive():
			keys.insert(0, "+N.{0}.{1}")
		else:
			keys.insert(0, "-N.{0}.{1}")
	for key in keys:
		key = key.format([fromId, actorId])
		if actor_special_titles.has(key):
			return actor_special_titles[key]
	return ""

func get_actor_naughty_title(actorId: int, fromId: int) -> String:
	var keys = ["D.{0}.{1}"]
	var actor = ActorHelper.actor(actorId)
	if actor.has_side():
		if actor.is_side_positive():
			keys.insert(0, "+D.{0}.{1}")
		else:
			keys.insert(0, "-D.{0}.{1}")
	for key in keys:
		key = key.format([fromId, actorId])
		if actor_special_titles.has(key):
			return actor_special_titles[key]
	return ""

func get_citys_unoffice():
	return self.citys_unoffice.duplicate(true)

func get_actor_follower():
	return self.actor_follower.duplicate(true)

func random_tips():
	if Global.get_rate_result(30):
		return "更新公告附有详细的游戏资料，记得去看看"
	return TIPS[randi() % TIPS.size()]


func get_city_static(cityId: int):
	return citys[cityId].duplicate(true)


func _load_stratagems(rawData: String) -> Array:
	var ret = []
	for item in parse_json(rawData):
		ret.append(StratagemInfo.new(item))
	return ret

func get_stratagem(name: String) -> StratagemInfo:
	if not stratagemDic.has(name):
		return null
	return stratagemDic[name]


func _load_buffs(rawData: String) -> Array:
	var ret = []
	for item in parse_json(rawData):
		ret.append(BuffInfo.new(item))
	return ret

func get_buff(name: String) -> BuffInfo:
	if not buffDic.has(name):
		return null
	return buffDic[name]

func get_wiki_description(name: String) -> String:
	if name in wiki_items:
		return wiki_items[name]
	return ""



func get_animation_data(animation_json) -> Dictionary:
	var key = str(animation_json["data"])
	key = key.replace(".json", "")
	if key in animation_detail_data:
		return animation_detail_data[key]
	return {}

func load_animation_texture(animation_json) -> Texture:
	var key = animation_json["gif"]
	if key in animationImageCache:
		return animationImageCache[key]
	var loaded: Texture = load("res://resource/images/animationPNG/" + key)
	animationImageCache[key] = loaded
	return loaded

func load_battle_map(blockType: String, fromBlockType: String = ""):
	var blockTypeFiles = [blockType]
	if fromBlockType != "":
		blockTypeFiles.insert(0, "{0}_{1}".format([blockType, fromBlockType]))
	if DataManager.diffculities >= 3:
		for t in blockTypeFiles.duplicate():
			blockTypeFiles.insert(0, t + "_hard")
	for t in blockTypeFiles:
		if t in battle_map_data:
			return battle_map_data[t]
	return battle_map_data["land"]

func load_story_data(vstateId: int, storyNo: int) -> Dictionary:
	if vstateId != 4:
		return {}
	var key = str(storyNo)
	if not key in story_data:
		return {}
	return story_data[key]

func get_war_map_data(cityId: int) -> Array:
	if war_map_data.has(str(cityId)):
		return war_map_data[str(cityId)]
	return []

func get_mod_info(mod_path: String) -> Dictionary:
	reload_packed_resources()
	mod_path = mod_path.replace("res://resource", "res://packed")
	if mod_info_cache.has(mod_path):
		return mod_info_cache[mod_path]
	var mod_info = parse_json(Global.get_file_text(mod_path + "mod.json"))
	if not mod_info.empty():
		mod_info_cache[mod_path] = mod_info
	return mod_info




var crypto = Crypto.new()
var signer = CryptoKey.new()
var prikey = CryptoKey.new()
var pubkey = CryptoKey.new()
var crypto_inited = false

func crypto_init() -> void :
	if crypto_inited:
		return
	if DataManager.is_developer():
		prikey.load("resource/data/bwdl.key.json", false)
	pubkey.load("res://resource/data/pub.pck", true)
	signer.load("res://resource/data/signer.pck", false)
	crypto_inited = true
	return

func crypto_sign(data: PoolByteArray) -> PoolByteArray:
	crypto_init()
	var hashed = data.get_string_from_utf8().sha256_buffer()
	return crypto.sign(HashingContext.HASH_SHA256, hashed, prikey)

func crypto_verify(data: PoolByteArray, signature: PoolByteArray) -> bool:
	crypto_init()
	var hashed = data.get_string_from_utf8().sha256_buffer()
	return crypto.verify(HashingContext.HASH_SHA256, hashed, signature, pubkey)

func crypto_sign_short(data: PoolByteArray) -> PoolByteArray:
	crypto_init()
	var hashed = data.get_string_from_utf8().md5_buffer()
	return crypto.sign(HashingContext.HASH_MD5, hashed, signer)

func crypto_verify_short(data: PoolByteArray, signature: PoolByteArray) -> bool:
	crypto_init()
	var hashed = data.get_string_from_utf8().md5_buffer()
	return crypto.verify(HashingContext.HASH_MD5, hashed, signature, signer)

func get_hide_key_setting() -> Dictionary:
	var ret = []
	var data = Global.get_file_text(StaticManager.HIDE_KEY_SETTING_PATH)
	if data != "":
		ret = parse_json(data)
	return ret

const HANZI = {
	"氏": [
		"shi"
	], 
	"梅": [
		"mei"
	], 
	"眠": [
		"mian"
	], 
	"电": [
		"dian"
	], 
	"可": [
		"ke"
	], 
	"騄": [
		"lu"
	], 
	"冢": [
		"zhong"
	], 
	"爛": [
		"lan"
	], 
	"姿": [
		"zi"
	], 
	"鲍": [
		"bao"
	], 
	"信": [
		"xin", 
		"shen"
	], 
	"蔡": [
		"cai", 
		"sa", 
		"ca"
	], 
	"瑁": [
		"mao"
	], 
	"德": [
		"de"
	], 
	"珪": [
		"gui"
	], 
	"曹": [
		"cao"
	], 
	"操": [
		"cao"
	], 
	"孟": [
		"meng"
	], 
	"洪": [
		"hong"
	], 
	"子": [
		"zi", 
		"zi"
	], 
	"廉": [
		"lian"
	], 
	"仁": [
		"ren"
	], 
	"孝": [
		"xiao"
	], 
	"陈": [
		"chen"
	], 
	"登": [
		"deng", 
		"de"
	], 
	"元": [
		"yuan"
	], 
	"龙": [
		"long"
	], 
	"宫": [
		"gong"
	], 
	"公": [
		"gong"
	], 
	"台": [
		"tai", 
		"tai", 
		"yi", 
		"si"
	], 
	"汉": [
		"han"
	], 
	"瑜": [
		"yu"
	], 
	"纪": [
		"ji", 
		"ji"
	], 
	"成": [
		"cheng"
	], 
	"宜": [
		"yi"
	], 
	"程": [
		"cheng"
	], 
	"普": [
		"pu"
	], 
	"谋": [
		"mou"
	], 
	"银": [
		"yin"
	], 
	"董": [
		
		
		"dong"
	], 
	"和": [
		"he", 
		"he", 
		"hu", 
		"huo", 
		"huo", 
		"huo"
	], 
	"幼": [
		"you", 
		"yao"
	], 
	"宰": [
		"zai"
	], 
	"璜": [
		"huang"
	], 
	"旻": [
		"min"
	], 
	"叔": [
		"shu"
	], 
	"颖": [
		"ying"
	], 
	"卓": [
		"zhuo", 
		"zhuo"
	], 
	"仲": [
		"zhong"
	], 
	"樊": [
		"fan", 
		"fan"
	], 
	"稠": [
		"chou", 
		"tiao", 
		"diao"
	], 
	"能": [
		"neng", 
		"tai", 
		"nai", 
		"nai", 
		"xiong"
	], 
	"逄": [
		"pang", 
		"feng"
	], 
	"图": [
		"tu"
	], 
	"高": [
		"gao", 
		"gao"
	], 
	"干": [
		"gan", 
		"gan", 
		"an"
	], 
	"才": [
		"cai", 
		"zai"
	], 
	"览": [
		"lan"
	], 
	"伯": [
		"bo", 
		"bai", 
		"mo", 
		"ba"
	], 
	"孙": [
		"sun"
	], 
	"度": [
		"du", 
		"duo", 
		"zhai"
	], 
	"升": [
		"sheng"
	], 
	"济": [
		"ji", 
		"ji"
	], 
	"范": [
		"fan"
	], 
	"越": [
		"yue", 
		"huo"
	], 
	"瓒": [
		"zan"
	], 
	"关": [
		"guan"
	], 
	"羽": [
		"yu", 
		"hu"
	], 
	"云": [
		"yun"
	], 
	"长": [
		"zhang", 
		"chang"
	], 
	"郭": [
		"guo", 
		"guo"
	], 
	"汜": [
		"si"
	], 
	"则": [
		"ze"
	], 
	"韩": [
		"han"
	], 
	"当": [
		"dang", 
		"dang"
	], 
	"义": [
		"yi"
	], 
	"馥": [
		"fu", 
		"bi"
	], 
	"文": [
		"wen"
	], 
	"节": [
		"jie", 
		"jie"
	], 
	"遂": [
		"sui", 
		"sui"
	], 
	"约": [
		"yue", 
		"yao"
	], 
	"胡": [
		"hu"
	], 
	"轸": [
		"zhen"
	], 
	"华": [
		"hua", 
		"hua", 
		"hua"
	], 
	"雄": [
		"xiong"
	], 
	"皇": [
		"huang", 
		"wang"
	], 
	"甫": [
		"fu", 
		"fu", 
		"pu"
	], 
	"嵩": [
		"song"
	], 
	"真": [
		"zhen"
	], 
	"黄": [
		"huang"
	], 
	"盖": [
		"gai", 
		"ge"
	], 
	"覆": [
		"fu"
	], 
	"权": [
		"quan"
	], 
	"衡": [
		"heng"
	], 
	"祖": [
		"zu", 
		"jie"
	], 
	"灵": [
		"ling"
	], 
	"贾": [
		"jia", 
		"gu"
	], 
	"诩": [
		"xu"
	], 
	"沮": [
		"ju", 
		"ju", 
		"ju", 
		"jian", 
		"zu"
	], 
	"授": [
		"shou"
	], 
	"孔": [
		"kong"
	], 
	"融": [
		"rong"
	], 
	"举": [
		"ju"
	], 
	"伷": [
		"zhou"
	], 
	"绪": [
		"xu"
	], 
	"乐": [
		"le", 
		"yue"
	], 
	"就": [
		"jiu"
	], 
	"李": [
		"li"
	], 
	"傕": [
		"jue", 
		"que"
	], 
	"稚": [
		"zhi"
	], 
	"然": [
		"ran"
	], 
	"儒": [
		"ru"
	], 
	"优": [
		"you", 
		"you"
	], 
	"肃": [
		"su"
	], 
	"刘": [
		"liu"
	], 
	"备": [
		"bei"
	], 
	"玄": [
		"xuan", 
		"xuan"
	], 
	"表": [
		"biao"
	], 
	"景": [
		"jing", 
		"ying"
	], 
	"岱": [
		"dai"
	], 
	"山": [
		"shan"
	], 
	"协": [
		"xie"
	], 
	"焉": [
		"yan", 
		"yi"
	], 
	"君": [
		"jun"
	], 
	"郎": [
		"lang", 
		"lang"
	], 
	"繇": [
		"yao", 
		"you", 
		"zhou"
	], 
	"正": [
		"zheng", 
		"zheng"
	], 
	"礼": [
		"li"
	], 
	"卢": [
		"lu"
	], 
	"植": [
		"zhi"
	], 
	"吕": [
		"lv"
	], 
	"布": [
		"bu"
	], 
	"奉": [
		"feng"
	], 
	"先": [
		"xian"
	], 
	"马": [
		"ma"
	], 
	"腾": [
		"teng"
	], 
	"寿": [
		"shou"
	], 
	"麋": [
		"mi"
	], 
	"竺": [
		"zhu", 
		"du"
	], 
	"牛": [
		"niu"
	], 
	"辅": [
		"fu"
	], 
	"桥": [
		"qiao"
	], 
	"伟": [
		"wei"
	], 
	"审": [
		"shen"
	], 
	"配": [
		"pei"
	], 
	"南": [
		"nan", 
		"na"
	], 
	"士": [
		"shi"
	], 
	"武": [
		"wu"
	], 
	"燮": [
		"xie"
	], 
	"威": [
		"wei"
	], 
	"彦": [
		"yan", 
		"pan"
	], 
	"壹": [
		"yi", 
		"yin"
	], 
	"苏": [
		"su"
	], 
	"飞": [
		"fei"
	], 
	"策": [
		"ce"
	], 
	"符": [
		"fu"
	], 
	"坚": [
		"jian"
	], 
	"静": [
		"jing"
	], 
	"陶": [
		"tao", 
		"yao", 
		"dao"
	], 
	"谦": [
		"qian"
	], 
	"恭": [
		"gong"
	], 
	"田": [
		"tian"
	], 
	"丰": [
		"feng"
	], 
	"皓": [
		"hao", 
		"hui"
	], 
	"王": [
		"wang", 
		"yu"
	], 
	"匡": [
		"kuang"
	], 
	"朗": [
		"lang"
	], 
	"兴": [
		"xing"
	], 
	"允": [
		"yun"
	], 
	"师": [
		"shi"
	], 
	"丑": [
		"chou"
	], 
	"吴": [
		"wu"
	], 
	"懿": [
		"yi"
	], 
	"远": [
		"yuan"
	], 
	"夏": [
		"xia", 
		"jia"
	], 
	"侯": [
		"hou"
	], 
	"惇": [
		"dun"
	], 
	"让": [
		"rang"
	], 
	"渊": [
		"yuan"
	], 
	"妙": [
		"miao"
	], 
	"徐": [
		"xu"
	], 
	"荣": [
		"rong"
	], 
	"薛": [
		"xue"
	], 
	"荀": [
		"xun"
	], 
	"谌": [
		"chen"
	], 
	"友": [
		"you"
	], 
	"若": [
		"ruo", 
		"re"
	], 
	"严": [
		"yan"
	], 
	"颜": [
		"yan"
	], 
	"阎": [
		"yan"
	], 
	"圃": [
		"pu"
	], 
	"良": [
		"liang"
	], 
	"杨": [
		"yang"
	], 
	"弘": [
		"hong"
	], 
	"于": [
		"yu"
	], 
	"糜": [
		"mi"
	], 
	"俞": [
		"yu"
	], 
	"涉": [
		"she", 
		"die"
	], 
	"袁": [
		"yuan"
	], 
	"尚": [
		"shang", 
		"chang"
	], 
	"显": [
		"xian"
	], 
	"绍": [
		"shao"
	], 
	"本": [
		"ben", 
		"ben"
	], 
	"初": [
		"chu"
	], 
	"术": [
		"shu", 
		"zhu", 
		"shu"
	], 
	"路": [
		"lu", 
		"luo"
	], 
	"谭": [
		"tan"
	], 
	"思": [
		"si", 
		"sai"
	], 
	"熙": [
		"xi", 
		"yi"
	], 
	"奕": [
		"yi"
	], 
	"遗": [
		"yi", 
		"wei"
	], 
	"业": [
		"ye"
	], 
	"胤": [
		"yin"
	], 
	"笮": [
		"ze", 
		"zuo", 
		"zha"
	], 
	"张": [
		"zhang"
	], 
	"超": [
		"chao", 
		"chao", 
		"chao", 
		"tiao"
	], 
	"翼": [
		"yi"
	], 
	"鲁": [
		"lu"
	], 
	"祺": [
		"qi"
	], 
	"邈": [
		"miao", 
		"miao"
	], 
	"任": [
		"ren", 
		"ren", 
		"lin"
	], 
	"松": [
		"song"
	], 
	"永": [
		"yong"
	], 
	"年": [
		"nian", 
		"ning"
	], 
	"矫": [
		"jiao", 
		"jiao"
	], 
	"卫": [
		"wei"
	], 
	"勋": [
		"xun"
	], 
	"英": [
		"ying", 
		"yang"
	], 
	"朱": [
		"zhu", 
		"shu"
	], 
	"儁": [
		"jun"
	], 
	"治": [
		"zhi", 
		"chi"
	], 
	"理": [
		"li"
	], 
	"茂": [
		"mao"
	], 
	"大": [
		"da", 
		"dai", 
		"tai"
	], 
	"纯": [
		"chun"
	], 
	"兰": [
		"lan"
	], 
	"甘": [
		"gan", 
		"han"
	], 
	"宁": [
		"ning", 
		"ning", 
		"zhu"
	], 
	"霸": [
		"ba", 
		"po"
	], 
	"暹": [
		"xian"
	], 
	"简": [
		"jian"
	], 
	"雍": [
		"yong"
	], 
	"宪": [
		"xian", 
		"xiong"
	], 
	"蒯": [
		"kuai", 
		"kuai"
	], 
	"柔": [
		"rou"
	], 
	"梁": [
		"liang"
	], 
	"凌": [
		"ling", 
		"ling"
	], 
	"潘": [
		"pan", 
		"pan", 
		"bo", 
		"pan", 
		"fan"
	], 
	"凤": [
		"feng"
	], 
	"乾": [
		"qian", 
		"gan"
	], 
	"佑": [
		"you"
	], 
	"安": [
		"an"
	], 
	"国": [
		"guo"
	], 
	"璆": [
		"qiu"
	], 
	"玉": [
		"yu"
	], 
	"纲": [
		"gang"
	], 
	"禁": [
		"jin", 
		"jin"
	], 
	"豹": [
		"bao"
	], 
	"琳": [
		"lin"
	], 
	"璋": [
		"zhang"
	], 
	"管": [
		"guan"
	], 
	"亥": [
		"hai", 
		"jie"
	], 
	"郝": [
		"hao", 
		"shi"
	], 
	"萌": [
		"meng", 
		"ming"
	], 
	"歆": [
		"xin"
	], 
	"鱼": [
		"yu"
	], 
	"桓": [
		"huan"
	], 
	"阶": [
		"jie"
	], 
	"蒋": [
		"jiang"
	], 
	"渠": [
		"qu", 
		"ju"
	], 
	"#": [], 
	"虞": [
		"yu"
	], 
	"玩": [
		"wan"
	], 
	"达": [
		"da", 
		"ti", 
		"ta"
	], 
	"蕤": [
		"rui"
	], 
	"麹": [
		"qu"
	], 
	"史": [
		"shi"
	], 
	"涣": [
		"huan", 
		"hui"
	], 
	"戏": [
		"xi", 
		"hu"
	], 
	"志": [
		"zhi"
	], 
	"许": [
		"xu", 
		"hu"
	], 
	"靖": [
		"jing"
	], 
	"休": [
		"xiu", 
		"xu"
	], 
	"彧": [
		"yu"
	], 
	"吉": [
		"ji"
	], 
	"邹": [
		"zou"
	], 
	"典": [
		"dian", 
		"tian"
	], 
	"韦": [
		"wei"
	], 
	"顺": [
		"shun"
	], 
	"车": [
		"che", 
		"ju"
	], 
	"儿": [
		"er", 
		"er", 
		"ren"
	], 
	"金": [
		"jin", 
		"jin"
	], 
	"旋": [
		"xuan", 
		"xuan"
	], 
	"机": [
		"ji", 
		"wei"
	], 
	"异": [
		"yi", 
		"yi"
	], 
	"进": [
		"jin"
	], 
	"刚": [
		"gang"
	], 
	"辟": [
		"pi", 
		"bi", 
		"mi", 
		"pi"
	], 
	"庞": [
		"pang"
	], 
	"累": [
		"lei", 
		"lei", 
		"lei", 
		"lv", 
		"lie"
	], 
	"柏": [
		"bai", 
		"bo", 
		"bo"
	], 
	"秋": [
		"qiu"
	], 
	"纮": [
		"hong"
	], 
	"闿": [
		"kai"
	], 
	"燕": [
		"yan", 
		"yan"
	], 
	"赵": [
		"zhao"
	], 
	"周": [
		"zhou"
	], 
	"善": [
		"shan"
	], 
	"泰": [
		"tai"
	], 
	"平": [
		"ping", 
		"pian", 
		"bing", 
		"beng"
	], 
	"性": [
		"xing"
	], 
	"昱": [
		"yu"
	], 
	"淳": [
		"chun", 
		"zhun", 
		"zhun"
	], 
	"琼": [
		"qiong"
	], 
	"法": [
		"fa"
	], 
	"直": [
		"zhi"
	], 
	"惠": [
		"hui"
	], 
	"龚": [
		"gong"
	], 
	"都": [
		"dou", 
		"du"
	], 
	"选": [
		"xuan"
	], 
	"焦": [
		"jiao", 
		"qiao"
	], 
	"触": [
		"chu"
	], 
	"曼": [
		"man"
	], 
	"旷": [
		"kuang"
	], 
	"裴": [
		"pei", 
		"fei"
	], 
	"太": [
		"tai", 
		"ta"
	], 
	"慈": [
		"ci"
	], 
	"象": [
		"xiang"
	], 
	"季": [
		"ji"
	], 
	"翻": [
		"fan"
	], 
	"翔": [
		"xiang"
	], 
	"昭": [
		"zhao", 
		"zhao"
	], 
	"烈": [
		"lie"
	], 
	"应": [
		"ying", 
		"ying"
	], 
	"承": [
		"cheng", 
		"zheng", 
		"zheng"
	], 
	"巩": [
		"gong"
	], 
	"嘉": [
		"jia"
	], 
	"浩": [
		"hao", 
		"gao", 
		"ge"
	], 
	"嗣": [
		"si"
	], 
	"猛": [
		"meng"
	], 
	"雷": [
		"lei", 
		"lei"
	], 
	"薄": [
		"bao", 
		"bo", 
		"bo", 
		"bu"
	], 
	"铜": [
		"tong"
	], 
	"堪": [
		"kan", 
		"chen"
	], 
	"定": [
		"ding"
	], 
	"芳": [
		"fang"
	], 
	"方": [
		"fang", 
		"fang", 
		"fang", 
		"pang", 
		"wang", 
		"feng"
	], 
	"令": [
		"ling", 
		"ling", 
		"ling", 
		"lian"
	], 
	"明": [
		"ming", 
		"meng"
	], 
	"峻": [
		"jun"
	], 
	"畴": [
		"chou"
	], 
	"邢": [
		"xing", 
		"geng"
	], 
	"道": [
		"dao", 
		"dao"
	], 
	"攸": [
		"you"
	], 
	"郃": [
		"he", 
		"xia"
	], 
	"乂": [
		"yi", 
		"ai"
	], 
	"辽": [
		"liao"
	], 
	"瑾": [
		"jin", 
		"jin"
	], 
	"诸": [
		"zhu"
	], 
	"葛": [
		"ge", 
		"ge"
	], 
	"隆": [
		"long", 
		"long"
	], 
	"中": [
		"zhong", 
		"zhong"
	], 
	"群": [
		"qun"
	], 
	"震": [
		"zhen", 
		"shen"
	], 
	"起": [
		"qi"
	], 
	"秉": [
		"bing"
	], 
	"枢": [
		"shu"
	], 
	"袭": [
		"xi"
	], 
	"代": [
		"dai"
	], 
	"忠": [
		"zhong"
	], 
	"通": [
		"tong", 
		"tong"
	], 
	"宋": [
		"song"
	], 
	"晃": [
		"huang", 
		"huang"
	], 
	"褚": [
		"chu", 
		"zhe", 
		"zhu"
	], 
	"康": [
		"kang", 
		"kang"
	], 
	"行": [
		"xing", 
		"hang", 
		"heng", 
		"xing", 
		"hang"
	], 
	"横": [
		"heng", 
		"heng", 
		"guang", 
		"guang", 
		"huang", 
		"huang"
	], 
	"仓": [
		"cang"
	], 
	"福": [
		"fu", 
		"fu"
	], 
	"胄": [
		"zhou"
	], 
	"钦": [
		"qin"
	], 
	"恢": [
		"hui"
	], 
	"昂": [
		"ang", 
		"yang"
	], 
	"廖": [
		"liao", 
		"liao"
	], 
	"化": [
		"hua", 
		"hua", 
		"huo"
	], 
	"俭": [
		"jian"
	], 
	"毛": [
		"mao", 
		"mao"
	], 
	"玠": [
		"jie"
	], 
	"牵": [
		"qian"
	], 
	"招": [
		"zhao", 
		"qiao", 
		"shao"
	], 
	"经": [
		"jing", 
		"jing"
	], 
	"辛": [
		"xin"
	], 
	"评": [
		"ping"
	], 
	"综": [
		"zong", 
		"zeng"
	], 
	"敬": [
		"jing"
	], 
	"畯": [
		"jun"
	], 
	"伊": [
		"yi"
	], 
	"籍": [
		"ji", 
		"jie"
	], 
	"绣": [
		"xiu"
	], 
	"虔": [
		"qian"
	], 
	"恪": [
		"ke"
	], 
	"延": [
		"yan"
	], 
	"魏": [
		"wei", 
		"wei", 
		"wei"
	], 
	"续": [
		"xu"
	], 
	"臧": [
		"zang", 
		"cang", 
		"zang"
	], 
	"宣": [
		"xuan"
	], 
	"封": [
		"feng", 
		"bian"
	], 
	"角": [
		"jiao", 
		"jue", 
		"lu", 
		"gu"
	], 
	"何": [
		"he", 
		"he"
	], 
	"宝": [
		"bao"
	], 
	"丁": [
		"ding", 
		"zheng"
	], 
	"原": [
		"yuan"
	], 
	"建": [
		"jian"
	], 
	"阳": [
		"yang"
	], 
	"脩": [
		"xiu", 
		"you", 
		"tiao", 
		"xiao"
	], 
	"徽": [
		"hui"
	], 
	"祗": [
		"zhi"
	], 
	"貂": [
		"diao"
	], 
	"蝉": [
		"chan"
	], 
	"琦": [
		"qi"
	], 
	"颂": [
		"song"
	], 
	"耀": [
		"yao"
	], 
	"满": [
		"man"
	], 
	"铁": [
		"tie"
	], 
	"妫": [
		"gui"
	], 
	"怀": [
		"huai", 
		"fu"
	], 
	"璝": [
		"gui"
	], 
	"司": [
		"si", 
		"ci", 
		"si"
	], 
	"粲": [
		"can"
	], 
	"修": [
		"xiu"
	], 
	"贺": [
		"he"
	], 
	"齐": [
		"qi", 
		"ji"
	], 
	"苗": [
		"miao"
	], 
	"钟": [
		"zhong"
	], 
	"常": [
		"chang"
	], 
	"盛": [
		"sheng", 
		"cheng"
	], 
	"向": [
		"xiang"
	], 
	"博": [
		"bo"
	], 
	"洽": [
		"qia", 
		"he"
	], 
	"聘": [
		"pin", 
		"ping"
	], 
	"毗": [
		"pi"
	], 
	"佐": [
		"zuo"
	], 
	"顾": [
		"gu"
	], 
	"叹": [
		"tan", 
		"yi", 
		"you"
	], 
	"豫": [
		"yu", 
		"xie", 
		"shu"
	], 
	"蹋": [
		"ta"
	], 
	"顿": [
		"dun", 
		"du"
	], 
	"沛": [
		"pei"
	], 
	"将": [
		"jiang", 
		"jiang", 
		"qiang"
	], 
	"霍": [
		"huo", 
		"he", 
		"suo"
	], 
	"蒙": [
		"meng", 
		"meng", 
		"meng"
	], 
	"既": [
		"ji", 
		"xi"
	], 
	"容": [
		"rong", 
		"yong"
	], 
	"逵": [
		"kui", 
		"kui"
	], 
	"晔": [
		"ye"
	], 
	"扬": [
		"yang"
	], 
	"到": [
		"dao"
	], 
	"至": [
		"zhi", 
		"die"
	], 
	"穆": [
		"mu"
	], 
	"宠": [
		"chong"
	], 
	"巨": [
		"ju", 
		"qu"
	], 
	"翊": [
		"yi"
	], 
	"弼": [
		"bi"
	], 
	"章": [
		"zhang", 
		"zhang"
	], 
	"谢": [
		"xie"
	], 
	"旌": [
		"jing"
	], 
	"杜": [
		"du", 
		"du", 
		"tu"
	], 
	"畿": [
		"ji"
	], 
	"班": [
		"ban"
	], 
	"濬": [
		"jun", 
		"xun"
	], 
	"步": [
		"bu"
	], 
	"骘": [
		"zhi"
	], 
	"恩": [
		"en"
	], 
	"杰": [
		"jie"
	], 
	"冯": [
		"feng", 
		"ping"
	], 
	"习": [
		"xi"
	], 
	"轲": [
		"ke", 
		"ke"
	], 
	"比": [
		"bi", 
		"bi", 
		"pi", 
		"pi"
	], 
	"邓": [
		"deng", 
		"shan"
	], 
	"芝": [
		"zhi"
	], 
	"傅": [
		"fu", 
		"fu"
	], 
	"阚": [
		"han", 
		"kan"
	], 
	"泽": [
		"ze"
	], 
	"润": [
		"run"
	], 
	"全": [
		"quan"
	], 
	"琮": [
		"cong"
	], 
	"孚": [
		"fu"
	], 
	"丹": [
		"dan"
	], 
	"统": [
		"tong"
	], 
	"绩": [
		"ji", 
		"ji"
	], 
	"阜": [
		"fu"
	], 
	"陆": [
		"lu", 
		"liu"
	], 
	"逊": [
		"xun"
	], 
	"言": [
		"yan", 
		"yan", 
		"yin"
	], 
	"立": [
		"li", 
		"wei"
	], 
	"留": [
		"liu", 
		"liu", 
		"liu"
	], 
	"赞": [
		"zan"
	], 
	"泠": [
		"ling", 
		"ling"
	], 
	"苞": [
		"bao", 
		"pao", 
		"biao"
	], 
	"佗": [
		"tuo", 
		"tuo", 
		"tuo", 
		"yi"
	], 
	"巴": [
		"ba"
	], 
	"丕": [
		"pi"
	], 
	"庶": [
		"shu", 
		"zhu", 
		"zhe"
	], 
	"吾": [
		"wu", 
		"yu", 
		"ya"
	], 
	"蜀": [
		"shu"
	], 
	"淮": [
		"huai"
	], 
	"彤": [
		"tong"
	], 
	"沙": [
		"sha", 
		"sha", 
		"suo"
	], 
	"摩": [
		"mo", 
		"ma", 
		"mi"
	], 
	"柯": [
		"ke"
	], 
	"彰": [
		"zhang"
	], 
	"骆": [
		"luo"
	], 
	"韶": [
		"shao"
	], 
	"琬": [
		"wan"
	], 
	"琰": [
		"yan"
	], 
	"申": [
		"shen"
	], 
	"耽": [
		"dan"
	], 
	"昶": [
		"chang"
	], 
	"舒": [
		"shu", 
		"yu"
	], 
	"亮": [
		"liang", 
		"liang"
	], 
	"享": [
		"xiang"
	], 
	"复": [
		"fu"
	], 
	"贤": [
		"xian"
	], 
	"嶷": [
		"yi", 
		"ni"
	], 
	"岐": [
		"qi"
	], 
	"月": [
		"yue", 
		"ru"
	], 
	"仪": [
		"yi"
	], 
	"据": [
		"ju", 
		"ju"
	], 
	"褒": [
		"bao"
	], 
	"谡": [
		"su"
	], 
	"式": [
		"shi", 
		"te"
	], 
	"熊": [
		"xiong"
	], 
	"凯": [
		"kai"
	], 
	"温": [
		"wen", 
		"yun"
	], 
	"恕": [
		"shu"
	], 
	"均": [
		"jun", 
		"yun"
	], 
	"虎": [
		"hu", 
		"hu"
	], 
	"费": [
		"fei"
	], 
	"祎": [
		"yi"
	], 
	"世": [
		"shi"
	], 
	"议": [
		"yi"
	], 
	"崔": [
		"cui"
	], 
	"谅": [
		"liang"
	], 
	"句": [
		"ju", 
		"gou", 
		"gou", 
		"qu"
	], 
	"扶": [
		"fu", 
		"pu"
	], 
	"綝": [
		"chen", 
		"shen"
	], 
	"鄂": [
		"e"
	], 
	"焕": [
		"huan"
	], 
	"遵": [
		"zun"
	], 
	"艾": [
		"ai", 
		"yi"
	], 
	"载": [
		"zai", 
		"zai"
	], 
	"瑛": [
		"ying"
	], 
	"双": [
		"shuang"
	], 
	"宇": [
		"yu"
	], 
	"彭": [
		"peng", 
		"pang", 
		"bang", 
		"peng"
	], 
	"瑶": [
		"yao"
	], 
	"索": [
		"suo"
	], 
	"维": [
		"wei"
	], 
	"之": [
		"zhi", 
		"zhu", 
		"zhi"
	], 
	"鲂": [
		"fang"
	], 
	"戴": [
		"dai"
	], 
	"陵": [
		"ling"
	], 
	"楙": [
		"mao"
	], 
	"林": [
		"lin"
	], 
	"基": [
		"ji"
	], 
	"舆": [
		"yu"
	], 
	"琪": [
		"qi"
	], 
	"毌": [
		"guan"
	], 
	"丘": [
		"qiu"
	], 
	"乔": [
		"qiao"
	], 
	"滕": [
		"teng"
	], 
	"端": [
		"duan"
	], 
	"会": [
		"hui", 
		"kuai"
	], 
	"获": [
		"huo"
	], 
	"宗": [
		"zong"
	], 
	"诠": [
		"quan"
	], 
	"姜": [
		"jiang"
	], 
	"厥": [
		"jue"
	], 
	"望": [
		"wang"
	], 
	"彻": [
		"che"
	], 
	"里": [
		"li", 
		"li"
	], 
	"叡": [
		"rui"
	], 
	"诞": [
		"dan"
	], 
	"略": [
		"lve"
	], 
	"雅": [
		"ya", 
		"ya", 
		"ya"
	], 
	"祝": [
		"zhu", 
		"zhou", 
		"chu"
	], 
	"爽": [
		"shuang", 
		"shuang"
	], 
	"唐": [
		"tang"
	], 
	"咨": [
		"zi"
	], 
	"弋": [
		"yi"
	], 
	"禅": [
		"chan", 
		"shan"
	], 
	"兀": [
		"wu", 
		"wu"
	], 
	"突": [
		"tu"
	], 
	"骨": [
		"gu", 
		"gu", 
		"gu"
	], 
	"质": [
		"zhi"
	], 
	"嘏": [
		"gu", 
		"jia"
	], 
	"石": [
		"shi", 
		"dan"
	], 
	"广": [
		"guang", 
		"yan", 
		"an"
	], 
	"特": [
		"te"
	], 
	"产": [
		"chan"
	], 
	"怿": [
		"yi"
	], 
	"霖": [
		"lin"
	], 
	"佥": [
		"qian"
	], 
	"斌": [
		"bin"
	], 
	"充": [
		"chong"
	], 
	"闾": [
		"lv"
	], 
	"骞": [
		"qian"
	], 
	"纂": [
		"zuan"
	], 
	"瞻": [
		"zhan"
	], 
	"罗": [
		"luo", 
		"luo"
	], 
	"阐": [
		"chan"
	], 
	"鸯": [
		"yang"
	], 
	"次": [
		"ci", 
		"zi", 
		"ci"
	], 
	"奋": [
		"fen", 
		"kang"
	], 
	"毓": [
		"yu"
	], 
	"瓘": [
		"guan"
	], 
	"浑": [
		"hun"
	], 
	"冲": [
		"chong", 
		"chong"
	], 
	"卿": [
		"qing"
	], 
	"抗": [
		"kang", 
		"gang"
	], 
	"羊": [
		"yang"
	], 
	"祜": [
		"hu"
	], 
	"沈": [
		"shen", 
		"chen", 
		"tan"
	], 
	"莹": [
		"ying"
	], 
	"预": [
		"yu"
	], 
	"勖": [
		"xu", 
		"mao"
	], 
	"曾": [
		"ceng", 
		"zeng"
	], 
	"万": [
		"wan", 
		"mo"
	], 
	"悌": [
		"ti"
	], 
	"旨": [
		"zhi"
	], 
	"炎": [
		"yan", 
		"yan", 
		"tan"
	], 
	"髦": [
		"mao"
	], 
	"奂": [
		"huan"
	], 
	"阿": [
		"a", 
		"e", 
		"e", 
		"a", 
		"a", 
		"a"
	], 
	"喃": [
		"nan", 
		"nan"
	], 
	"尹": [
		"yin", 
		"yun"
	], 
	"楷": [
		"kai", 
		"jie", 
		"jie"
	], 
	"赏": [
		"shang"
	], 
	"环": [
		"huan"
	], 
	"三": [
		"san"
	], 
	"结": [
		"jie", 
		"jie"
	], 
	"荼": [
		"tu", 
		"cha", 
		"ye", 
		"shu"
	], 
	"那": [
		"na", 
		"na", 
		"nuo", 
		"nuo", 
		"nei", 
		"na", 
		"nei", 
		"ne", 
		"nai", 
		"ne"
	], 
	"婴": [
		"ying"
	], 
	"木": [
		"mu"
	], 
	"鹿": [
		"lu", 
		"lv"
	], 
	"星": [
		"xing"
	], 
	"彩": [
		"cai"
	], 
	"小": [
		"xiao"
	], 
	"香": [
		"xiang"
	], 
	"甄": [
		"zhen", 
		"zhen", 
		"juan"
	], 
	"宓": [
		"mi", 
		"fu"
	], 
	"带": [
		"dai"
	], 
	"来": [
		"lai"
	], 
	"洞": [
		"dong", 
		"tong"
	], 
	"主": [
		"zhu", 
		"zhu"
	], 
	"祢": [
		"mi", 
		"ni"
	], 
	"邵": [
		"shao"
	], 
	"秦": [
		"qin"
	], 
	"敕": [
		"chi", 
		"sou"
	], 
	"姬": [
		"ji", 
		"yi"
	], 
	"邕": [
		"yong", 
		"yong"
	], 
	"喈": [
		"jie", 
		"xie"
	], 
	"疆": [
		"jiang", 
		"jiang"
	], 
	"骉": [
		"biao"
	], 
	"皎": [
		"jiao"
	], 
	"贲": [
		"ben", 
		"bi"
	], 
	"自": [
		"zi"
	], 
	"演": [
		"yan", 
		"yan"
	], 
	"朵": [
		"duo"
	], 
	"左": [
		"zuo"
	], 
	"放": [
		"fang", 
		"fang", 
		"fang"
	], 
	"辩": [
		"bian"
	], 
	"球": [
		"qiu"
	], 
	"崇": [
		"chong"
	], 
	"涓": [
		"juan", 
		"yuan", 
		"xuan"
	], 
	"襄": [
		"xiang"
	], 
	"北": [
		"bei", 
		"bei"
	], 
	"蓟": [
		"ji"
	], 
	"邺": [
		"ye", 
		"qiu"
	], 
	"海": [
		"hai"
	], 
	"皮": [
		"pi"
	], 
	"濮": [
		"pu"
	], 
	"昌": [
		"chang", 
		"chang"
	], 
	"谯": [
		"qiao", 
		"qiao"
	], 
	"下": [
		"xia"
	], 
	"邳": [
		"pi"
	], 
	"汝": [
		"ru"
	], 
	"洛": [
		"luo"
	], 
	"上": [
		"shang", 
		"shang"
	], 
	"庸": [
		"yong", 
		"yong"
	], 
	"江": [
		"jiang"
	], 
	"天": [
		"tian"
	], 
	"水": [
		"shui"
	], 
	"晋": [
		"jin"
	], 
	"梓": [
		"zi"
	], 
	"潼": [
		"tong"
	], 
	"郡": [
		"jun"
	], 
	"零": [
		"ling"
	], 
	"交": [
		"jiao"
	], 
	"趾": [
		"zhi"
	], 
	"桂": [
		"gui"
	], 
	"春": [
		"chun"
	], 
	"柴": [
		"chai", 
		"zhai"
	], 
	"桑": [
		"sang"
	], 
	"稽": [
		"ji", 
		"qi"
	], 
	"夷": [
		"yi"
	], 
	"洲": [
		"zhou"
	], 
	"新": [
		"xin"
	], 
	"野": [
		"ye"
	], 
	"庐": [
		"lu"
	], 
	"毅": [
		"yi"
	], 
	"观": [
		"guan"
	], 
	"照": [
		"zhao"
	], 
	"镇": [
		"zhen"
	], 
	"围": [
		"wei"
	], 
	"训": [
		"xun"
	], 
	"宴": [
		"yan"
	], 
	"害": [
		"hai"
	], 
	"战": [
		"zhan"
	], 
	"攻": [
		"gong"
	], 
	"督": [
		"du"
	], 
	"奸": [
		"jian"
	], 
	"集": [
		"ji"
	], 
	"盟": [
		"meng"
	], 
	"赋": [
		"fu"
	], 
	"诗": [
		"shi"
	], 
	"献": [
		"xian"
	], 
	"刀": [
		"dao"
	], 
	"征": [
		"zheng"
	], 
	"西": [
		"xi"
	], 
	"援": [
		"yuan"
	], 
	"护": [
		"hu"
	], 
	"弃": [
		"qi"
	], 
	"破": [
		"po"
	], 
	"骑": [
		"qi", 
		"ji"
	], 
	"守": [
		"shou"
	], 
	"冷": [
		"leng"
	], 
	"箭": [
		"jian"
	], 
	"伪": [
		"wei"
	], 
	"溃": [
		"kui"
	], 
	"增": [
		"zeng"
	], 
	"矛": [
		"mao"
	], 
	"引": [
		"yin"
	], 
	"斗": [
		"dou"
	], 
	"智": [
		"zhi"
	], 
	"迟": [
		"chi"
	], 
	"忌": [
		"ji"
	], 
	"犄": [
		"ji", 
		"yi"
	], 
	"互": [
		"hu"
	], 
	"事": [
		"shi"
	], 
	"半": [
		"ban"
	], 
	"反": [
		"fan"
	], 
	"卜": [
		"bo", 
		"bu", 
		"pu"
	], 
	"旗": [
		"qi"
	], 
	"巧": [
		"qiao"
	], 
	"缚": [
		"fu"
	], 
	"耐": [
		"nai"
	], 
	"疾": [
		"ji"
	], 
	"连": [
		"lian"
	], 
	"岭": [
		"ling"
	], 
	"精": [
		"jing"
	], 
	"整": [
		"zheng"
	], 
	"疠": [
		"li"
	], 
	"火": [
		"huo"
	], 
	"临": [
		"lin"
	], 
	"驰": [
		"chi"
	], 
	"压": [
		"ya"
	], 
	"胆": [
		"dan"
	], 
	"甲": [
		"jia"
	], 
	"清": [
		"qing"
	], 
	"鲠": [
		"geng"
	], 
	"毒": [
		"du"
	], 
	"杀": [
		"sha"
	], 
	"绝": [
		"jue"
	], 
	"盾": [
		"dun"
	], 
	"随": [
		"sui"
	], 
	"医": [
		"yi"
	], 
	"前": [
		"qian"
	], 
	"非": [
		"fei"
	], 
	"暴": [
		"bao", 
		"pu"
	], 
	"蛮": [
		"man"
	], 
	"名": [
		"ming"
	], 
	"服": [
		"fu", 
		"bi", 
		"bo"
	], 
	"侠": [
		"xia"
	], 
	"乱": [
		"luan"
	], 
	"莽": [
		"mang"
	], 
	"伏": [
		"fu"
	], 
	"怯": [
		"qie"
	], 
	"势": [
		"shi"
	], 
	"扰": [
		"rao"
	], 
	"负": [
		"fu"
	], 
	"假": [
		"jia", 
		"jie", 
		"xia"
	], 
	"屡": [
		"lv"
	], 
	"强": [
		"qiang", 
		"jiang"
	], 
	"河": [
		"he"
	], 
	"愈": [
		"yu"
	], 
	"勇": [
		"yong"
	], 
	"截": [
		"jie"
	], 
	"血": [
		"xue", 
		"xie"
	], 
	"牲": [
		"sheng"
	], 
	"鼓": [
		"gu"
	], 
	"舞": [
		"wu"
	], 
	"驹": [
		"ju"
	], 
	"要": [
		"yao"
	], 
	"速": [
		"su"
	], 
	"趫": [
		"qiao", 
		"jiao", 
		"chao"
	], 
	"从": [
		"cong", 
		"zong"
	], 
	"塞": [
		"sai", 
		"se"
	], 
	"穷": [
		"qiong"
	], 
	"追": [
		"zhui", 
		"dui", 
		"tui"
	], 
	"弓": [
		"gong"
	], 
	"怒": [
		"nu"
	], 
	"斩": [
		"zhan"
	], 
	"神": [
		"shen", 
		"shen"
	], 
	"淹": [
		"yan", 
		"yan"
	], 
	"钺": [
		"yue"
	], 
	"冠": [
		"guan", 
		"guan"
	], 
	"念": [
		"nian"
	], 
	"除": [
		"chu", 
		"zhu", 
		"shu"
	], 
	"恶": [
		"e", 
		"e", 
		"wu", 
		"wu"
	], 
	"贫": [
		"pin"
	], 
	"劫": [
		"jie"
	], 
	"民": [
		"min"
	], 
	"兵": [
		"bing"
	], 
	"制": [
		"zhi"
	], 
	"饰": [
		"shi"
	], 
	"急": [
		"ji"
	], 
	"敌": [
		"di", 
		"hua"
	], 
	"利": [
		"li"
	], 
	"御": [
		"yu", 
		"ya"
	], 
	"解": [
		"jie", 
		"jie", 
		"xie"
	], 
	"烦": [
		"fan"
	], 
	"教": [
		"jiao", 
		"jiao"
	], 
	"骁": [
		"xiao"
	], 
	"傲": [
		"ao", 
		"ao"
	], 
	"逆": [
		"ni"
	], 
	"违": [
		"wei"
	], 
	"忤": [
		"wu", 
		"wu"
	], 
	"枕": [
		"zhen", 
		"chen"
	], 
	"戈": [
		"ge"
	], 
	"游": [
		"you", 
		"liu"
	], 
	"弩": [
		"nu"
	], 
	"剑": [
		"jian"
	], 
	"探": [
		"tan", 
		"xian"
	], 
	"激": [
		"ji", 
		"jiao", 
		"jiao"
	], 
	"励": [
		"li"
	], 
	"孤": [
		"gu"
	], 
	"苦": [
		"ku", 
		"gu", 
		"hu"
	], 
	"肉": [
		"rou", 
		"ru"
	], 
	"改": [
		"gai"
	], 
	"计": [
		"ji"
	], 
	"趋": [
		"qu"
	], 
	"舟": [
		"zhou"
	], 
	"功": [
		"gong"
	], 
	"倍": [
		"bei", 
		"pei"
	], 
	"谏": [
		"jian"
	], 
	"避": [
		"bi"
	], 
	"祸": [
		"huo"
	], 
	"射": [
		"she", 
		"ye", 
		"yi"
	], 
	"发": [
		"fa", 
		"fa"
	], 
	"恃": [
		"shi", 
		"zhi"
	], 
	"锋": [
		"feng"
	], 
	"决": [
		"jue"
	], 
	"幕": [
		"mu", 
		"man"
	], 
	"后": [
		"hou"
	], 
	"缓": [
		"huan"
	], 
	"沉": [
		"chen"
	], 
	"替": [
		"ti"
	], 
	"嘘": [
		"xu", 
		"shi"
	], 
	"枯": [
		"ku", 
		"gu"
	], 
	"旅": [
		"lv"
	], 
	"军": [
		"jun"
	], 
	"催": [
		"cui"
	], 
	"城": [
		"cheng"
	], 
	"巡": [
		"xun", 
		"yan", 
		"shun"
	], 
	"滞": [
		"zhi"
	], 
	"锁": [
		"suo"
	], 
	"焚": [
		"fen", 
		"fen"
	], 
	"拉": [
		"la", 
		"la", 
		"la", 
		"la", 
		"la"
	], 
	"拢": [
		"long"
	], 
	"熏": [
		"xun", 
		"xun"
	], 
	"勉": [
		"mian"
	], 
	"扎": [
		"zha", 
		"za", 
		"zha", 
		"zha"
	], 
	"继": [
		"ji"
	], 
	"施": [
		"shi", 
		"yi", 
		"shi"
	], 
	"营": [
		"ying"
	], 
	"桃": [
		"tao", 
		"tiao", 
		"zhao"
	], 
	"园": [
		"yuan", 
		"wan"
	], 
	"遍": [
		"bian"
	], 
	"惊": [
		"jing", 
		"liang"
	], 
	"固": [
		"gu"
	], 
	"请": [
		"qing"
	], 
	"祚": [
		"zuo"
	], 
	"怠": [
		"dai", 
		"yi"
	], 
	"力": [
		"li"
	], 
	"困": [
		"kun"
	], 
	"密": [
		"mi"
	], 
	"诏": [
		"zhao"
	], 
	"浅": [
		"qian", 
		"jian"
	], 
	"运": [
		"yun", 
		"yun"
	], 
	"室": [
		"shi"
	], 
	"命": [
		"ming"
	], 
	"爵": [
		"jue"
	], 
	"人": [
		"ren"
	], 
	"牧": [
		"mu"
	], 
	"戡": [
		"kan", 
		"zhen"
	], 
	"难": [
		"nan", 
		"nan"
	], 
	"商": [
		"shang"
	], 
	"诚": [
		"cheng"
	], 
	"笃": [
		"du"
	], 
	"谕": [
		"yu"
	], 
	"迅": [
		"xun"
	], 
	"戟": [
		"ji"
	], 
	"无": [
		"wu", 
		"mo"
	], 
	"矢": [
		"shi"
	], 
	"慧": [
		"hui"
	], 
	"居": [
		"ju", 
		"ji"
	], 
	"奇": [
		"qi", 
		"ji", 
		"ai", 
		"yi"
	], 
	"联": [
		"lian"
	], 
	"转": [
		"zhuan", 
		"zhuan", 
		"zhuai"
	], 
	"久": [
		"jiu"
	], 
	"掘": [
		"jue", 
		"ku"
	], 
	"借": [
		"jie"
	], 
	"政": [
		"zheng", 
		"zheng"
	], 
	"仇": [
		"chou", 
		"qiu", 
		"ju"
	], 
	"疏": [
		"shu"
	], 
	"财": [
		"cai"
	], 
	"振": [
		"zhen", 
		"zhen", 
		"zhen"
	], 
	"纳": [
		"na"
	], 
	"数": [
		"shu", 
		"shu", 
		"shuo"
	], 
	"荐": [
		"jian"
	], 
	"翩": [
		"pian"
	], 
	"背": [
		"bei", 
		"bei"
	], 
	"摔": [
		"shuai"
	], 
	"身": [
		"shen", 
		"juan"
	], 
	"族": [
		"zu", 
		"sou", 
		"cou", 
		"zou"
	], 
	"轻": [
		"qing"
	], 
	"幸": [
		"xing", 
		"nie"
	], 
	"宽": [
		"kuan"
	], 
	"退": [
		"tui"
	], 
	"·": [], 
	"2": [], 
	"伐": [
		"fa"
	], 
	"撩": [
		"liao", 
		"liao", 
		"liao", 
		"lao", 
		"liao"
	], 
	"熟": [
		"shu", 
		"shou"
	], 
	"锐": [
		"rui"
	], 
	"拔": [
		"ba", 
		"bo", 
		"bie", 
		"fa", 
		"bei"
	], 
	"创": [
		"chuang", 
		"chuang"
	], 
	"赶": [
		"gan", 
		"qian"
	], 
	"尽": [
		"jin", 
		"jin"
	], 
	"栖": [
		"qi", 
		"xi"
	], 
	"槊": [
		"shuo"
	], 
	"出": [
		"chu"
	], 
	"束": [
		"shu"
	], 
	"邂": [
		"xie"
	], 
	"豪": [
		"hao"
	], 
	"筹": [
		"chou"
	], 
	"击": [
		"ji"
	], 
	"穿": [
		"chuan", 
		"chuan", 
		"yuan"
	], 
	"传": [
		"chuan", 
		"zhuan"
	], 
	"缠": [
		"chan"
	], 
	"裹": [
		"guo"
	], 
	"取": [
		"qu", 
		"qu"
	], 
	"暗": [
		"an"
	], 
	"挺": [
		"ting", 
		"ting"
	], 
	"刺": [
		"ci", 
		"ci", 
		"qi"
	], 
	"狂": [
		"kuang", 
		"jue"
	], 
	"搦": [
		"nuo"
	], 
	"头": [
		"tou", 
		"tou"
	], 
	"阵": [
		"zhen"
	], 
	"歇": [
		"xie", 
		"ya"
	], 
	"试": [
		"shi"
	], 
	"壮": [
		"zhuang"
	], 
	"肆": [
		"si", 
		"ti"
	], 
	"妄": [
		"wang", 
		"wang"
	], 
	"尊": [
		"zun"
	], 
	"*": [], 
	"峭": [
		"qiao"
	], 
	"得": [
		"de", 
		"de", 
		"dei"
	], 
	"堑": [
		"qian"
	], 
	"忍": [
		"ren", 
		"ren"
	], 
	"佛": [
		"fu", 
		"fo", 
		"bo", 
		"bi"
	], 
	"魂": [
		"hun"
	], 
	"开": [
		"kai"
	], 
	"寺": [
		"si", 
		"shi"
	], 
	"咆": [
		"pao"
	], 
	"哮": [
		"xiao", 
		"xiao", 
		"xue"
	], 
	"尘": [
		"chen"
	], 
	"酒": [
		"jiu"
	], 
	"厉": [
		"li"
	], 
	"喝": [
		"he", 
		"he", 
		"ye", 
		"kai"
	], 
	"啸": [
		"xiao"
	], 
	"家": [
		"jia", 
		"jia", 
		"jia", 
		"jie", 
		"gu"
	], 
	"资": [
		"zi"
	], 
	"嫉": [
		"ji"
	], 
	"慎": [
		"shen", 
		"zhen"
	], 
	"米": [
		"mi"
	], 
	"系": [
		"xi", 
		"ji"
	], 
	"离": [
		"li", 
		"chi"
	], 
	"撒": [
		"sa", 
		"sa"
	], 
	"豆": [
		"dou"
	], 
	"乡": [
		"xiang"
	], 
	"枪": [
		"qiang"
	], 
	"百": [
		"bai", 
		"bo", 
		"mo"
	], 
	"鸟": [
		"niao", 
		"diao"
	], 
	"朝": [
		"chao", 
		"zhao", 
		"zhu"
	], 
	"记": [
		"ji"
	], 
	"谍": [
		"die"
	], 
	"网": [
		"wang"
	], 
	"晓": [
		"xiao"
	], 
	"亲": [
		"qin", 
		"qing"
	], 
	"掩": [
		"yan", 
		"yan"
	], 
	"胜": [
		"sheng", 
		"xing", 
		"qing", 
		"sheng"
	], 
	"气": [
		"qi", 
		"qi"
	], 
	"驻": [
		"zhu"
	], 
	"防": [
		"fang"
	], 
	"尉": [
		"wei", 
		"yu", 
		"yun"
	], 
	"寻": [
		"xun", 
		"xin"
	], 
	"阙": [
		"que", 
		"que"
	], 
	"换": [
		"huan"
	], 
	"帻": [
		"ze"
	], 
	"缮": [
		"shan"
	], 
	"识": [
		"shi", 
		"shi", 
		"zhi"
	], 
	"叫": [
		"jiao"
	], 
	"私": [
		"si"
	], 
	"掠": [
		"lve", 
		"lve"
	], 
	"憩": [
		"qi"
	], 
	"合": [
		"he", 
		"ge"
	], 
	"健": [
		"jian"
	], 
	"锦": [
		"jin"
	], 
	"帆": [
		"fan", 
		"fan", 
		"fan"
	], 
	"说": [
		"shuo", 
		"shui", 
		"yue"
	], 
	"纵": [
		"zong"
	], 
	"抚": [
		"fu"
	], 
	"风": [
		"feng"
	], 
	"恣": [
		"zi"
	], 
	"斧": [
		"fu"
	], 
	"体": [
		"ti", 
		"ti", 
		"ben", 
		"cui"
	], 
	"架": [
		"jia"
	], 
	"重": [
		"zhong", 
		"chong", 
		"tong"
	], 
	"锤": [
		"chui"
	], 
	"咒": [
		"zhou"
	], 
	"敛": [
		"lian"
	], 
	"猪": [
		"zhu"
	], 
	"贿": [
		"hui"
	], 
	"收": [
		"shou"
	], 
	"待": [
		"dai", 
		"dai"
	], 
	"戒": [
		"jie"
	], 
	"檄": [
		"xi"
	], 
	"词": [
		"ci"
	], 
	"息": [
		"xi"
	], 
	"托": [
		"tuo"
	], 
	"归": [
		"gui"
	], 
	"殇": [
		"shang"
	], 
	"助": [
		"zhu", 
		"chu"
	], 
	"付": [
		"fu"
	], 
	"虚": [
		"xu"
	], 
	"诱": [
		"you"
	], 
	"粮": [
		"liang"
	], 
	"藏": [
		"cang", 
		"zang", 
		"zang"
	], 
	"夺": [
		"duo"
	], 
	"二": [
		"er"
	], 
	"五": [
		"wu"
	], 
	"仔": [
		"zai", 
		"zi", 
		"zi"
	], 
	"技": [
		"ji", 
		"qi"
	], 
	"组": [
		"zu"
	], 
	"狭": [
		"xia"
	], 
	"一": [
		"yi", 
		"yi", 
		"yi"
	], 
	"案": [
		"an"
	], 
	"〇": [
		"ling", 
		"yuan", 
		"xing"
	], 
	"勤": [
		"qin", 
		"qi"
	], 
	"共": [
		"gong", 
		"gong", 
		"gong", 
		"hong"
	], 
	"患": [
		"huan"
	], 
	"妒": [
		"du"
	], 
	"局": [
		"ju"
	], 
	"逾": [
		"yu", 
		"dou"
	], 
	"墙": [
		"qiang"
	], 
	"瑕": [
		"xia"
	], 
	"惧": [
		"ju"
	], 
	"驱": [
		"qu"
	], 
	"怨": [
		"yuan", 
		"yun"
	], 
	"驾": [
		"jia"
	], 
	"鹤": [
		"he"
	], 
	"影": [
		"ying"
	], 
	"唤": [
		"huan"
	], 
	"雨": [
		"yu", 
		"yu"
	], 
	"蛊": [
		"gu"
	], 
	"惑": [
		"huo"
	], 
	"旧": [
		"jiu"
	], 
	"冒": [
		"mao", 
		"mo"
	], 
	"陷": [
		"xian"
	], 
	"迫": [
		"po", 
		"pai"
	], 
	"盗": [
		"dao"
	], 
	"责": [
		"ze"
	], 
	"罚": [
		"fa"
	], 
	"警": [
		"jing"
	], 
	"讯": [
		"xun"
	], 
	"揩": [
		"kai", 
		"jia"
	], 
	"油": [
		"you", 
		"you"
	], 
	"诡": [
		"gui"
	], 
	"果": [
		"guo", 
		"luo", 
		"guan"
	], 
	"接": [
		"jie", 
		"xie", 
		"sha", 
		"cha"
	], 
	"监": [
		"jian", 
		"jian"
	], 
	"使": [
		"shi"
	], 
	"迎": [
		"ying", 
		"ying"
	], 
	"叛": [
		"pan"
	], 
	"铸": [
		"zhu"
	], 
	"克": [
		"ke"
	], 
	"韧": [
		"ren"
	], 
	"凶": [
		"xiong"
	], 
	"设": [
		"she"
	], 
	"逃": [
		"tao"
	], 
	"险": [
		"xian"
	], 
	"磐": [
		"pan"
	], 
	"仿": [
		"fang", 
		"pang"
	], 
	"笔": [
		"bi"
	], 
	"炫": [
		"xuan"
	], 
	"虑": [
		"lv", 
		"bi"
	], 
	"残": [
		"can"
	], 
	"秘": [
		"mi", 
		"bi", 
		"bie"
	], 
	"丸": [
		"wan"
	], 
	"讨": [
		"tao"
	], 
	"挽": [
		"wan"
	], 
	"忘": [
		"wang", 
		"wang"
	], 
	"隙": [
		"xi"
	], 
	"寇": [
		"kou"
	], 
	"酣": [
		"han", 
		"han"
	], 
	"漫": [
		"man"
	], 
	"睿": [
		"rui"
	], 
	"咎": [
		"jiu", 
		"gao"
	], 
	"稳": [
		"wen"
	], 
	"工": [
		"gong"
	], 
	"坊": [
		"fang", 
		"fang"
	], 
	"市": [
		"shi", 
		"fu"
	], 
	"拦": [
		"lan"
	], 
	"断": [
		"duan"
	], 
	"论": [
		"lun", 
		"lun"
	], 
	"知": [
		"zhi", 
		"zhi"
	], 
	"衰": [
		"shuai", 
		"suo", 
		"cui"
	], 
	"奔": [
		"ben", 
		"ben", 
		"fen"
	], 
	"霜": [
		"shuang"
	], 
	"熬": [
		"ao", 
		"ao"
	], 
	"寒": [
		"han"
	], 
	"贸": [
		"mao"
	], 
	"懈": [
		"xie"
	], 
	"抬": [
		"tai", 
		"chi"
	], 
	"棺": [
		"guan", 
		"guan"
	], 
	"屯": [
		"tun", 
		"zhun"
	], 
	"亢": [
		"kang", 
		"gang", 
		"geng"
	], 
	"佯": [
		"yang"
	], 
	"诈": [
		"zha"
	], 
	"愚": [
		"yu"
	], 
	"变": [
		"bian"
	], 
	"劝": [
		"quan"
	], 
	"止": [
		"zhi"
	], 
	"啼": [
		"ti"
	], 
	"同": [
		"tong", 
		"tong"
	], 
	"心": [
		"xin"
	], 
	"曲": [
		"qu", 
		"qu"
	], 
	"推": [
		"tui"
	], 
	"州": [
		"zhou"
	], 
	"衿": [
		"jin", 
		"qin"
	], 
	"深": [
		"shen"
	], 
	"救": [
		"jiu", 
		"jiu"
	], 
	"潜": [
		"qian"
	], 
	"品": [
		"pin"
	], 
	"著": [
		"zhu", 
		"zhe", 
		"zhuo", 
		"chu", 
		"zhao", 
		"zhao"
	], 
	"败": [
		"bai"
	], 
	"裂": [
		"lie", 
		"lie"
	], 
	"穹": [
		"qiong", 
		"qiong", 
		"kong"
	], 
	"不": [
		"bu", 
		"fou", 
		"fou", 
		"fu", 
		"bu"
	], 
	"挠": [
		"nao"
	], 
	"问": [
		"wen"
	], 
	"卦": [
		"gua"
	], 
	"入": [
		"ru"
	], 
	"爪": [
		"zhao", 
		"zhua"
	], 
	"境": [
		"jing"
	], 
	"如": [
		"ru"
	], 
	"扛": [
		"kang", 
		"gang"
	], 
	"泅": [
		"qiu", 
		"you"
	], 
	"夜": [
		"ye"
	], 
	"辨": [
		"bian", 
		"bian", 
		"ban", 
		"pian"
	], 
	"翁": [
		"weng", 
		"weng"
	], 
	"手": [
		"shou"
	], 
	"厚": [
		"hou"
	], 
	"积": [
		"ji", 
		"zhi"
	], 
	"骥": [
		"ji"
	], 
	"劲": [
		"jin", 
		"jing"
	], 
	"绊": [
		"ban"
	], 
	"绳": [
		"sheng"
	], 
	"涌": [
		"yong", 
		"chong"
	], 
	"调": [
		"diao", 
		"tiao"
	], 
	"注": [
		"zhu", 
		"zhou"
	], 
	"书": [
		"shu"
	], 
	"好": [
		"hao", 
		"hao"
	], 
	"恐": [
		"kong"
	], 
	"吞": [
		"tun", 
		"tian"
	], 
	"燃": [
		"ran"
	], 
	"呼": [
		"hu", 
		"xiao", 
		"xu", 
		"he", 
		"xia"
	], 
	"纸": [
		"zhi"
	], 
	"偶": [
		"ou"
	], 
	"诛": [
		"zhu"
	], 
	"砂": [
		"sha"
	], 
	"地": [
		"di", 
		"de"
	], 
	"走": [
		"zou"
	], 
	"饲": [
		"si"
	], 
	"簿": [
		"bu", 
		"bo"
	], 
	"幻": [
		"huan"
	], 
	"移": [
		"yi", 
		"chi", 
		"yi"
	], 
	"爱": [
		"ai"
	], 
	"邀": [
		"yao"
	], 
	"朔": [
		"shuo"
	], 
	"垫": [
		"dian"
	], 
	"闭": [
		"bi"
	], 
	"间": [
		"jian", 
		"jian"
	], 
	"鸿": [
		"hong"
	], 
	"求": [
		"qiu"
	], 
	"千": [
		"qian"
	], 
	"跃": [
		"yue"
	], 
	"底": [
		"di", 
		"de"
	], 
	"色": [
		"se", 
		"shai"
	], 
	"降": [
		"jiang", 
		"xiang", 
		"xiang"
	], 
	"盒": [
		"he", 
		"an"
	], 
	"酥": [
		"su"
	], 
	"绮": [
		"qi"
	], 
	"羌": [
		"qiang"
	], 
	"壁": [
		"bi"
	], 
	"泣": [
		"qi", 
		"li", 
		"se"
	], 
	"摄": [
		"she"
	], 
	"槌": [
		"chui", 
		"zhui", 
		"dui"
	], 
	"刃": [
		"ren"
	], 
	"阻": [
		"zu", 
		"zhu"
	], 
	"学": [
		"xue"
	], 
	"众": [
		"zhong", 
		"yin"
	], 
	"用": [
		"yong"
	], 
	"猎": [
		"lie", 
		"xi", 
		"que"
	], 
	"白": [
		"bai", 
		"bo"
	], 
	"衣": [
		"yi", 
		"yi"
	], 
	"投": [
		"tou", 
		"dou"
	], 
	"霹": [
		"pi"
	], 
	"雳": [
		"li"
	], 
	"拿": [
		"na"
	], 
	"毦": [
		"er"
	], 
	"赫": [
		"he", 
		"shi"
	], 
	"吏": [
		"li"
	], 
	"补": [
		"bu"
	], 
	"牢": [
		"lao", 
		"lao", 
		"lou"
	], 
	"吟": [
		"yin", 
		"yin", 
		"jin"
	], 
	"夙": [
		"su"
	], 
	"召": [
		"zhao", 
		"shao"
	], 
	"枭": [
		"xiao"
	], 
	"俘": [
		"fu"
	], 
	"槽": [
		"cao", 
		"zao"
	], 
	"狼": [
		"lang", 
		"lang", 
		"lang", 
		"hang"
	], 
	"鹰": [
		"ying"
	], 
	"视": [
		"shi"
	], 
	"（": [], 
	"p": [], 
	"l": [], 
	"u": [], 
	"s": [], 
	"）": [], 
	"-": [], 
	"回": [
		"hui"
	], 
	"炽": [
		"chi"
	], 
	"贞": [
		"zhen"
	], 
	"状": [
		"zhuang"
	], 
	"格": [
		"ge", 
		"luo", 
		"he", 
		"ge"
	], 
	"返": [
		"fan"
	], 
	"倾": [
		"qing"
	], 
	"摧": [
		"cui", 
		"zui", 
		"cuo"
	], 
	"绽": [
		"zhan"
	], 
	"睥": [
		"pi"
	], 
	"睨": [
		"ni"
	], 
	"歌": [
		"ge"
	], 
	"青": [
		"qing", 
		"jing"
	], 
	"囊": [
		"nang", 
		"nang"
	], 
	"刮": [
		"gua"
	], 
	"篡": [
		"cuan"
	], 
	"逐": [
		"zhu", 
		"di", 
		"zhou", 
		"tun"
	], 
	"帝": [
		"di"
	], 
	"侍": [
		"shi"
	], 
	"误": [
		"wu"
	], 
	"始": [
		"shi"
	], 
	"终": [
		"zhong"
	], 
	"舍": [
		"she", 
		"she", 
		"shi"
	], 
	"恋": [
		"lian"
	], 
	"土": [
		"tu", 
		"du", 
		"cha", 
		"tu"
	], 
	"悯": [
		"min"
	], 
	"务": [
		"wu"
	], 
	"跋": [
		"ba", 
		"bei"
	], 
	"卷": [
		"juan", 
		"juan", 
		"quan", 
		"quan", 
		"gun", 
		"jun"
	], 
	"过": [
		"guo", 
		"guo"
	], 
	"醉": [
		"zui"
	], 
	"卧": [
		"wo"
	], 
	"看": [
		"kan", 
		"kan"
	], 
	"微": [
		"wei"
	], 
	"醺": [
		"xun"
	], 
	"酩": [
		"ming"
	], 
	"酊": [
		"ding", 
		"ding"
	], 
	"醒": [
		"xing", 
		"cheng", 
		"jing"
	], 
	"启": [
		"qi"
	], 
	"羁": [
		"ji"
	], 
	"骄": [
		"jiao"
	], 
	"黠": [
		"xia"
	], 
	"遇": [
		"yu", 
		"yong", 
		"ou"
	], 
	"躬": [
		"gong"
	], 
	"八": [
		"ba", 
		"ba"
	], 
	"钉": [
		"ding", 
		"ding"
	], 
	"硬": [
		"ying", 
		"geng"
	], 
	"猝": [
		"cu"
	], 
	"散": [
		"san", 
		"san", 
		"san"
	], 
	"谣": [
		"yao"
	], 
	"嫡": [
		"di"
	], 
	"默": [
		"mo"
	], 
	"罪": [
		"zui"
	], 
	"拥": [
		"yong"
	], 
	"劈": [
		"pi", 
		"pi"
	], 
	"器": [
		"qi"
	], 
	"遣": [
		"qian", 
		"qian"
	], 
	"荡": [
		"dang"
	], 
	"徒": [
		"tu"
	], 
	"逸": [
		"yi"
	], 
	"父": [
		"fu", 
		"fu"
	], 
	"魄": [
		"po", 
		"bo", 
		"tuo"
	], 
	"耕": [
		"geng"
	], 
	"撤": [
		"che"
	], 
	"疑": [
		"yi", 
		"ning"
	], 
	"凿": [
		"zao", 
		"zuo"
	], 
	"骧": [
		"xiang"
	], 
	"钧": [
		"jun"
	], 
	"孛": [
		"bei", 
		"bo"
	], 
	"谲": [
		"jue"
	], 
	"骤": [
		"zhou"
	], 
	"贵": [
		"gui"
	], 
	"历": [
		"li"
	], 
	"嫌": [
		"xian"
	], 
	"睢": [
		"sui", 
		"hui", 
		"wei"
	], 
	"裔": [
		"yi"
	], 
	"再": [
		"zai"
	], 
	"挑": [
		"tiao", 
		"tiao", 
		"tao", 
		"diao", 
		"tiao", 
		"tiao"
	], 
	"衅": [
		"xin"
	], 
	"逢": [
		"feng", 
		"peng", 
		"pang"
	], 
	"凉": [
		"liang", 
		"liang"
	], 
	"侧": [
		"ce", 
		"ze", 
		"zhai"
	], 
	"养": [
		"yang"
	], 
	"渐": [
		"jian", 
		"jian"
	], 
	"轧": [
		"ya", 
		"zha", 
		"ga"
	], 
	"极": [
		"ji"
	], 
	"专": [
		"zhuan"
	], 
	"闲": [
		"xian"
	], 
	"聚": [
		"ju"
	], 
	"藤": [
		"teng"
	], 
	"筏": [
		"fa"
	], 
	"障": [
		"zhang", 
		"zhang"
	], 
	"阴": [
		"yin"
	], 
	"谶": [
		"chen"
	], 
	"独": [
		"du"
	], 
	"揽": [
		"lan"
	], 
	"棋": [
		"qi", 
		"ji"
	], 
	"限": [
		"xian", 
		"wen"
	], 
	"虐": [
		"nve"
	], 
	"悖": [
		"bei", 
		"bei"
	], 
	"肤": [
		"fu"
	], 
	"存": [
		"cun"
	], 
	"披": [
		"pi"
	], 
	"弈": [
		"yi"
	], 
	"瞬": [
		"shun"
	], 
	"畏": [
		"wei", 
		"wei", 
		"wei"
	], 
	"摸": [
		"mo", 
		"mo"
	], 
	"迁": [
		"qian"
	], 
	"祭": [
		"ji", 
		"zhai"
	], 
	"臣": [
		"chen"
	], 
	"争": [
		"zheng"
	], 
	"排": [
		"pai", 
		"pai", 
		"bai"
	], 
	"签": [
		"qian"
	], 
	"察": [
		"cha", 
		"cui"
	], 
	"践": [
		"jian"
	], 
	"帅": [
		"shuai"
	], 
	"竹": [
		"zhu"
	], 
	"讲": [
		"jiang"
	], 
	"撑": [
		"cheng"
	], 
	"觋": [
		"xi"
	], 
	"谬": [
		"miu"
	], 
	"伤": [
		"shang"
	], 
	"流": [
		"liu"
	], 
	"光": [
		"guang", 
		"guang"
	], 
	"忿": [
		"fen"
	], 
	"烛": [
		"zhu", 
		"chong"
	], 
	"棒": [
		"bang"
	], 
	"傀": [
		"gui", 
		"kui", 
		"kuai"
	], 
	"跬": [
		"kui", 
		"xie"
	], 
	"趣": [
		"qu", 
		"cu", 
		"qu", 
		"cou", 
		"zou"
	], 
	"芒": [
		"mang", 
		"huang", 
		"huang", 
		"wang"
	], 
	"伺": [
		"ci", 
		"si"
	], 
	"动": [
		"dong"
	], 
	"瞰": [
		"kan"
	], 
	"卸": [
		"xie"
	], 
	"读": [
		"du", 
		"dou"
	], 
	"驽": [
		"nu"
	], 
	"哀": [
		"ai"
	], 
	"诤": [
		"zheng", 
		"zheng"
	], 
	"碎": [
		"sui"
	], 
	"兽": [
		"shou"
	], 
	"笛": [
		"di"
	], 
	"玲": [
		"ling"
	], 
	"珑": [
		"long"
	], 
	"姻": [
		"yin"
	], 
	"婢": [
		"bi"
	], 
	"娇": [
		"jiao"
	], 
	"妹": [
		"mei"
	], 
	"缥": [
		"piao", 
		"piao"
	], 
	"缈": [
		"miao"
	], 
	"废": [
		"fei"
	], 
	"闻": [
		"wen"
	], 
	"买": [
		"mai"
	], 
	"琴": [
		"qin"
	], 
	"音": [
		"yin"
	], 
	"悲": [
		"bei"
	], 
	"肠": [
		"chang"
	], 
	"窃": [
		"qie"
	], 
	"线": [
		"xian"
	], 
	"姓": [
		"xing", 
		"sheng"
	], 
	"犁": [
		"li"
	], 
	"持": [
		"chi"
	], 
	"多": [
		"duo"
	], 
	"携": [
		"xie"
	], 
	"户": [
		"hu"
	], 
	"裨": [
		"bi", 
		"pi"
	], 
	"闪": [
		"shan"
	], 
	"泉": [
		"quan"
	], 
	"谷": [
		"gu", 
		"lu", 
		"yu"
	], 
	"掷": [
		"zhi", 
		"zhi"
	], 
	"杯": [
		"bei"
	], 
	"感": [
		"gan", 
		"han"
	], 
	"逝": [
		"shi"
	], 
	"做": [
		"zuo"
	], 
	"播": [
		"bo", 
		"bo"
	], 
	"胁": [
		"xie"
	], 
	"停": [
		"ting"
	], 
	"窥": [
		"kui"
	], 
	"圣": [
		"sheng", 
		"ku"
	], 
	"语": [
		"yu", 
		"yu"
	], 
	"闺": [
		"gui"
	], 
	"秀": [
		"xiu"
	], 
	"死": [
		"si"
	], 
	"母": [
		"mu", 
		"mu", 
		"wu", 
		"wu"
	], 
	"枝": [
		"zhi", 
		"qi"
	], 
	"食": [
		"shi", 
		"si", 
		"yi"
	], 
	"弑": [
		"shi"
	], 
	"奴": [
		"nu"
	], 
	"匪": [
		"fei", 
		"fei", 
		"fen"
	], 
	"梦": [
		"meng"
	], 
	"装": [
		"zhuang"
	], 
	"裳": [
		"shang", 
		"chang"
	], 
	"乘": [
		"cheng", 
		"sheng"
	], 
	"舰": [
		"jian"
	], 
	"楼": [
		"lou"
	], 
	"侵": [
		"qin", 
		"qin"
	], 
	"岸": [
		"an"
	], 
	"告": [
		"gao", 
		"ju", 
		"gu"
	], 
	"短": [
		"duan"
	], 
	"倚": [
		"yi", 
		"ji", 
		"yi"
	], 
	"七": [
		"qi", 
		"qi"
	], 
	"薤": [
		"xie"
	], 
	"眉": [
		"mei"
	], 
	"尖": [
		"jian"
	], 
	"钩": [
		"gou"
	], 
	"镰": [
		"lian"
	], 
	"嘴": [
		"zui"
	], 
	"古": [
		"gu", 
		"gu", 
		"ku"
	], 
	"锭": [
		"ding"
	], 
	"牙": [
		"ya", 
		"ya"
	], 
	"偃": [
		"yan"
	], 
	"单": [
		"dan", 
		"chan", 
		"shan"
	], 
	"画": [
		"hua"
	], 
	"丈": [
		"zhang"
	], 
	"蛇": [
		"she", 
		"yi", 
		"tuo", 
		"chi"
	], 
	"雌": [
		"ci"
	], 
	"股": [
		"gu"
	], 
	"涯": [
		"ya"
	], 
	"蒺": [
		"ji"
	], 
	"藜": [
		"li"
	], 
	"板": [
		"ban"
	], 
	"贯": [
		"guan"
	], 
	"两": [
		"liang"
	], 
	"虏": [
		"lu"
	], 
	"纶": [
		"lun", 
		"guan"
	], 
	"巾": [
		"jin"
	], 
	"兜": [
		"dou"
	], 
	"鍪": [
		"mou"
	], 
	"氅": [
		"chang"
	], 
	"者": [
		"zhe"
	], 
	"鳞": [
		"lin"
	], 
	"铠": [
		"kai"
	], 
	"面": [
		"mian"
	], 
	"狮": [
		"shi"
	], 
	"盔": [
		"kui"
	], 
	"损": [
		"sun"
	], 
	"的": [
		"de", 
		"di", 
		"di", 
		"di"
	], 
	"六": [
		"liu", 
		"lu"
	], 
	"韬": [
		"tao"
	], 
	"鹊": [
		"que"
	], 
	"麒": [
		"qi"
	], 
	"麟": [
		"lin"
	], 
	"廿": [
		"nian"
	], 
	"四": [
		"si"
	], 
	"篇": [
		"pian"
	], 
	"印": [
		"yin", 
		"yi"
	], 
	"诫": [
		"jie"
	], 
	"釭": [
		"gang", 
		"gong"
	], 
	"嘲": [
		"chao", 
		"zhao"
	], 
	"讽": [
		"feng", 
		"feng"
	], 
	"雕": [
		"diao"
	], 
	"匕": [
		"bi", 
		"pin"
	], 
	"首": [
		"shou"
	], 
	"易": [
		"yi"
	], 
	"鬃": [
		"zong"
	], 
	"黑": [
		"hei"
	], 
	"汗": [
		"han", 
		"han", 
		"gan"
	], 
	"赤": [
		"chi"
	], 
	"兔": [
		"tu", 
		"tu", 
		"chan"
	], 
	"鞭": [
		"bian"
	], 
	"脊": [
		"ji"
	], 
	"薙": [
		"ti"
	]
}

func pinyin(msg: String) -> PoolStringArray:
	var full = [""]
	var brief = [""]
	for ch in msg:
		if ch in HANZI:
			if HANZI[ch].empty():
				continue
			var extended = []
			var extendedBrief = []
			for r in HANZI[ch]:
				for cur in full:
					extended.append(cur + r)
				for cur in brief:
					extendedBrief.append(cur + r[0])
			full = extended
			brief = extendedBrief
	var ret = full
	ret.append_array(brief)
	return ret

func preload_special_avatars() -> Dictionary:
	var ret = {}
	ret["random"] = Global.load_pic_with_cache("res://resource/images/actor/face/random.png")
	ret["god"] = Global.load_pic_with_cache("res://resource/images/actor/face/god2.png")
	return ret

func preload_original_avatars() -> Array:
	var ret = []
	for i in ORIGINAL_AVATAR_COUNT:
		var path = "res://resource/images/actor/face/original_%d.png" % (i + 1)
		var tex = Global.load_pic_with_cache(path)
		if tex != null:
			ret.append(tex)
	return ret

func preload_packed_extra_avatars() -> Dictionary:
	var root = DataManager.get_common_path() + "mod/avatars/custom/"
	var ret = {}
	var data = Global.get_file_text(root + "info.json")
	if data == "":
		return ret
	var info = parse_json(data)
	for k in ["width", "height", "names"]:
		if not k in info:
			return ret
	var width = Global.intval(info["width"])
	var height = Global.intval(info["height"])
	var names = Global.arrval(info["names"])
	for i in names.size():
		var img = Image.new()
		if img.load(root + "merged_{0}.webp".format([i + 1])) != 0:
			break
		for j in names[i].size():
			var name = names[i][j]
			var avatar = Image.new()
			avatar.create(width, height, false, img.get_format())
			var pos = Vector2(0, height * j)
			avatar.blit_rect(img, Rect2(pos, Vector2(width, height)), Vector2.ZERO)
			var texture = ImageTexture.new()
			texture.resource_local_to_scene = true
			texture.create_from_image(avatar)
			ret[name] = texture
	return ret

func preload_extra_avatars() -> Dictionary:
	var root = DataManager.get_common_path() + "mod/avatars/custom/"
	var ret = preload_packed_extra_avatars()
	var found = Global.scan_all_files(root, false)
	DataManager.grouped_trace("AV-SCN")
	for file in found:
		var filename = file.get_file()
		var basename = filename.get_basename()
		var extname = filename.get_extension()
		if not extname in ["jpg", "jpeg", "png", "webp"]:
			continue
		if extname == "webp" and basename.begins_with("merged_"):
			
			continue
		if Global.get_file_size(file) > StaticManager.MAX_AVATAR_IMAGE_SIZE:
			printerr("跳过过大的头像文件：" + file)
			continue
		var img = Global.load_pic_with_cache(file)
		if img == null:
			continue
		ret[filename] = img
		DataManager.grouped_trace("AV-EX")
	return ret

func get_skill(name: String) -> Skill:
	if not name in skillDict:
		return null
	return skillDict[name]



func reload_and_apply_actor_patches() -> void :
	actor_patches = {}
	var loaded = {}
	
	if not DataManager.is_challange_game():
		var actorPatchPath = DataManager.get_common_path() + "mod/patches/actors.json"
		var actorPatchContent = Global.get_file_text(actorPatchPath)
		if actorPatchContent == "":
			return
		var parsed = JSON.parse(actorPatchContent)
		if parsed.error != OK:
			return
		if typeof(parsed.result) != TYPE_DICTIONARY:
			return
		loaded = parsed.result
	for key in loaded:
		var actorId = int(key)
		if actorId < 0 or actorId >= actors.size():
			continue
		var patch = loaded[key]
		if typeof(patch) != TYPE_DICTIONARY:
			continue
		
		var row = {}
		for attr in PATCH_ATTRS:
			if not attr in patch:
				continue
			var val = int(patch[attr])
			if val <= 0 or val > 99:
				continue
			
			
			var originalAttr = "原" + attr
			if not originalAttr in actors[actorId]:
				actors[actorId][originalAttr] = actors[actorId][attr]
			actors[actorId][attr] = val
			row[attr] = val
		actor_patches[key] = row
	return



func save_actor_patches() -> void :
	var actorPatchPath = DataManager.get_common_path() + "mod/patches/actors.json"
	Global.save_file_text(actorPatchPath, JSON.print(actor_patches, "  "))
	reload_and_apply_actor_patches()
	return



func remove_actor_patches(actorId: int) -> void :
	actor_patches.erase(str(actorId))
	if actorId >= 0 or actorId < actors.size():
		
		for attr in PATCH_ATTRS:
			var originalAttr = "原" + attr
			if originalAttr in actors[actorId]:
				actors[actorId][attr] = actors[actorId][originalAttr]
	save_actor_patches()
	return



func get_war_map_rect(blockEN: String, idx: int = 0) -> TextureRect:
	var atlas = AtlasTexture.new()
	atlas.atlas = war_map_blocks_img
	var offset = war_map_blocks_info.find(blockEN)
	if offset < 0:
		offset = 0
	var x = offset % 20
	var y = int(offset / 20) * 2 + idx
	atlas.region = Rect2(16 * x, 16 * y, 16, 16)
	var ret = TextureRect.new()
	ret.texture = atlas
	ret.texture.set_flags(1)
	ret.expand = true
	return ret

func get_equip_data(id: int, type: String) -> Dictionary:
	if id >= CUSTOM_EQUIP_MIN_ID:
		for ce in custom_equips:
			if ce.id == id and ce.type == type:
				return ce.dump_data()
		return {}
	var data = []
	match type:
		"武器":
			data = StaticManager.weapons_static
		"防具":
			data = StaticManager.suits_static
		"道具":
			data = StaticManager.jewelrys_static
		"坐骑":
			data = StaticManager.steeds_static
	if id >= data.size():
		return {}
	return data[id].duplicate(true)



func reload_and_apply_equip_patches() -> void :
	custom_equips = []
	var equipPatchPath = DataManager.get_common_path() + "mod/patches/equips.json"
	var equipPatchContent = Global.get_file_text(equipPatchPath)
	if equipPatchContent == "":
		return
	var parsed = JSON.parse(equipPatchContent)
	if parsed.error != OK:
		return
	if typeof(parsed.result) != TYPE_ARRAY:
		return
	for item in parsed.result:
		var ce = CustomEquip.new()
		ce.load_data(item)
		if ce.id < 0:
			
			continue
		custom_equips.append(ce)
	return



func save_equip_patches() -> void :
	var equipPatchPath = DataManager.get_common_path() + "mod/patches/equips.json"
	var data = []
	for ce in custom_equips:
		data.append(ce.dump_data())
	Global.save_file_text(equipPatchPath, JSON.print(data, "  "))
	reload_and_apply_equip_patches()
	return



func remove_equip_patch(equipId: int, equipType: String) -> void :
	
	var updated = []
	for ce in custom_equips:
		if ce.id == equipId:
			continue
		updated.append(ce)
	custom_equips = updated
	save_equip_patches()
	return



func get_all_possible_skills(actorId: int = - 1) -> Dictionary:
	
	var forActor = null
	if actorId >= 0:
		forActor = ActorHelper.actor(actorId)
	var ret = {}
	for actor in ActorHelper.all_actors():
		var actor_skill_data = Dictionary(StaticManager.actor_skills[actor.actorId])
		for lv in range(1, 9):
			
			
			if lv == 1 and actor.has_side():
				continue
			var level_str = "LV{0}".format([lv])
			if not actor_skill_data.has(level_str):
				continue
			var skill_data = actor_skill_data[level_str];
			var skill_data_array = str(skill_data).split("/")
			for skillName in skill_data_array:
				if skillName == "" or skillName in ret:
					continue
				
				var skill = get_skill(skillName)
				if skill == null or not skill.visible():
					continue
				if forActor == null:
					
					if not skill.exclusive_valid_for_actor(ACTOR_ID_DIY):
						continue
				elif not skill.valid_for_actor(forActor.actorId):
					continue
				ret[skill.name] = skill
	return ret
