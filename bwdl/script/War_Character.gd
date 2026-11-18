extends "clEnvBase.gd"

class_name War_Character

class DialogInfo:
	var text = "";
	var mood = 2;
	var actorId: int = - 1;
	var callback_script = "";
	var callback_method = "";
	var se = ""
	var sceneId = 20000
	
	func output():
		var dic = {
			"text": text, 
			"mood": mood, 
			"actorId": actorId, 
			"cbs": callback_script, 
			"cmb": callback_method, 
			"se": se, 
			"sceneId": sceneId, 
		}
		return dic;
		
	func input(dic: Dictionary):
		text = str(dic["text"]);
		mood = int(dic["mood"]);
		actorId = int(dic["actorId"]);
		callback_script = str(dic["cbs"]);
		callback_method = str(dic["cmb"]);
		se = ""
		if dic.has("se"):
			se = str(dic["se"])
		sceneId = 20000
		if dic.has("sceneId"):
			sceneId = int(dic["sceneId"])
		return

enum FivePhases_Enum{
	Metal = 1, 
	Wood = 2, 
	Fire = 3, 
	Water = 4, 
	Earth = 5, 
}

enum AI_Enum{
	None = - 1, 
	MainCity = 0, 
	AttackMain = 1, 
	AttackNear = 2, 
	DefenceMain = 3, 
	GotoHospital = 4, 
	GotoRiceshop = 5, 

	
	
	ATTACK_PUSH = 10, 
	
	LEADER_HOLD = 11, 
}


var init_vstateId: int = - 1

var vstateId: int = - 1

var initWvId: int = - 1

var wvId: int = - 1



var dic_skill_cd: Dictionary = {};

var dic_buffs: Dictionary = {};

var dic_areas: Dictionary = {};

var dic_other_variable: Dictionary = {};


var is_concealed = false

var AI: int = AI_Enum.None


var action_point: int = 0;

var position: Vector2 = Vector2( - 1, - 1);

var disabled = false;


var battle_morale: int = 0




var battle_morale_patched: int = 0

var battle_morale_extra: int = 0

var battle_morale_rnd: int = 0

var battle_lead: int = 0;

var battle_power: int = 0;

var battle_tactic_point: int = 0;

var battle_courage: int = 0;

var extra_battle_courage: int = 0

var poker_point: int = 0

var five_phases: int = FivePhases_Enum.Wood;

var days_battle_actors = {};

var days_defended_actors = {};


func side() -> String:
	if wvId == - 1:
		return "中立"
	var wf = DataManager.get_current_war_fight()
	var wv = wf.get_war_vstate(wvId)
	if wv == null:
		return "中立"
	return wv.side


func has_position():
	return position.x >= 0 and position.y >= 0;
	
func battle_init(simulation = false):
	return

func cleanup() -> void :
	dic_skill_cd = {}
	dic_buffs = {}
	dic_areas = {}
	dic_other_variable = {}
	return


static func get_five_phases_string(phase: int) -> String:
	match phase:
		FivePhases_Enum.Fire:
			return "火"
		FivePhases_Enum.Metal:
			return "金"
		FivePhases_Enum.Wood:
			return "木"
		FivePhases_Enum.Water:
			return "水"
		FivePhases_Enum.Earth:
			return "土"
	return ""

static func get_AI_string(AI: int) -> String:
	match AI:
		AI_Enum.None:
			return "无"
		AI_Enum.MainCity:
			return "守主城"
		AI_Enum.AttackMain:
			return "扑主将"
		AI_Enum.AttackNear:
			return "扑最近"
		AI_Enum.DefenceMain:
			return "守主将"
		AI_Enum.GotoHospital:
			return "去医馆"
		AI_Enum.GotoRiceshop:
			return "去米屋"
	return ""

static func get_five_phases_color(five_phases: int) -> String:
	match five_phases:
		FivePhases_Enum.Metal:
			return "#ffff00"
		FivePhases_Enum.Wood:
			return "#00ff00"
		FivePhases_Enum.Fire:
			return "#FF4500"
		FivePhases_Enum.Water:
			return "#00BFFF"
		FivePhases_Enum.Earth:
			return "#696969"
	return "#FFFFFF"
