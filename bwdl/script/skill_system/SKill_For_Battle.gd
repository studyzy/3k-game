extends Resource
class_name SKill_For_Battle


class Skill_Battle_Property:
	
	var leader: int = 0;
	
	var courage: int = 0;
	
	var power: int = 0;
	
	var tp: int = 0;
	
	var alternative_wisdom_for_tp: int = 0
	
	func output() -> Dictionary:
		var dic = {
			"leader": leader, 
			"courage": courage, 
			"power": power, 
			"tp": tp, 
			"alternative_wisdom_for_tp": alternative_wisdom_for_tp, 
		}
		return dic;
		
	func input(dic):
		if (dic == null or dic.empty()):
			return ;
		if (dic.has("leader")):
			leader = int(dic["leader"]);
		if (dic.has("courage")):
			courage = int(dic["courage"]);
		if (dic.has("power")):
			power = int(dic["power"]);
		if (dic.has("tp")):
			tp = int(dic["tp"]);
		if (dic.has("alternative_wisdom_for_tp")):
			alternative_wisdom_for_tp = int(dic["alternative_wisdom_for_tp"])
