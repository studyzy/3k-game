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
