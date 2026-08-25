# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/skill_system/clSkillTriggerInfo.gd
# 说明：技能触发信息对象。描述技能的触发条件、时机与目标。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Resource


class_name SkillTriggerInfo

var induce_dialog: String = "";
var actorId: int;
var triggerId: int
var next_flow: String = "";
var temp_code_gd = [];

var lock_effects: Array = [];
var induce_effects: Array = [];
var wait = false;

func output_data():
	var dic = {
		"induce_dialog": induce_dialog, 
		"actorId": actorId, 
		"triggerId": triggerId, 
		"next_flow": next_flow, 
		"lock_effects": lock_effects, 
		"induce_effects": induce_effects, 
		"wait": wait, 
		"temp_code_gd": temp_code_gd, 
	}
	return dic;

func input_data(dic: Dictionary):
	induce_dialog = str(dic["induce_dialog"]);
	actorId = int(dic["actorId"]);
	triggerId = int(dic["triggerId"]);
	next_flow = str(dic["next_flow"]);
	lock_effects = dic["lock_effects"];
	induce_effects = dic["induce_effects"];
	wait = dic["wait"];
	if (dic.has("temp_code_gd")):
		temp_code_gd = Array(dic["temp_code_gd"]);
