extends War_Character

class_name War_Neutralor


var npcId: int = - 1;

var npc_name: String = "村民";

var troops_type = "山";

var sodiers = 1500


func get_save_dit():
	var dit = {
		"init_vstateId": init_vstateId, 
		"vstateId": vstateId, 
		"dic_buffs": dic_buffs, 
		"dic_areas": dic_areas, 
		"dic_skill_cd": dic_skill_cd, 
		"action_point": action_point, 
		"position": {"x": position.x, "y": position.y}, 
		"battle_morale": battle_morale, 
		"battle_morale_patched": battle_morale_patched, 
		"battle_lead": battle_lead, 
		"battle_power": battle_power, 
		"battle_courage": battle_courage, 
		"battle_tactic_point": battle_tactic_point, 
		"disabled": disabled, 
		"dic_other_variable": dic_other_variable, 
		"AI": AI, 
		"five_phases": five_phases, 
		"poker_point": poker_point, 
		"days_battle_actors": days_battle_actors, 
		"days_defended_actors": days_defended_actors, 
		
		"npcId": npcId, 
		"npc_name": npc_name, 
		"troops_type": troops_type, 
		"sodiers": sodiers, 
	};
	
	
	return dit;

func set_save_dit(dit: Dictionary):
	init_vstateId = int(dit["init_vstateId"]);
	vstateId = int(dit["vstateId"]);
	dic_buffs = Dictionary(dit["dic_buffs"]);
	dic_areas = Dictionary(dit["dic_areas"]);
	dic_skill_cd = dit["dic_skill_cd"];
	action_point = int(dit["action_point"]);
	disabled = dit["disabled"];
	var x = int(dit["position"]["x"]);
	var y = int(dit["position"]["y"]);
	position = Vector2(x, y);
	battle_morale = int(dit["battle_morale"]);
	
	battle_morale_patched = 0
	if dit.has("battle_morale_patched"):
		battle_morale_patched = int(dit["battle_morale_patched"])
	battle_lead = int(dit["battle_lead"]);
	
	battle_power = - 1
	if dit.has("battle_power"):
		battle_power = int(dit["battle_power"])
	battle_courage = int(dit["battle_courage"]);
	battle_tactic_point = int(dit["battle_tactic_point"]);
	dic_other_variable = Dictionary(dit["dic_other_variable"]);
	AI = int(dit["AI"])
	five_phases = int(dit["five_phases"])
	poker_point = int(dit["poker_point"])
	days_battle_actors = dit["days_battle_actors"]
	days_defended_actors = {}
	if dit.has("days_defended_actors"):
		days_defended_actors = dit["days_defended_actors"]
	npcId = int(dit["npcId"])
	npc_name = str(dit["npc_name"]);
	
	return
