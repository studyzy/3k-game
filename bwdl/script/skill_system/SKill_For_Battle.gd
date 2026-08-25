# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：script/skill_system/SKill_For_Battle.gd
# 说明：战斗技能对象。把技能应用到具体战斗场景。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

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
