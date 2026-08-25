# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/War_Communique.gd
# 说明：战争战报 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control


onready var atk_node = get_node("Window2/Atk");
onready var def_node = get_node("Window2/Def");
onready var lblEndless = get_node("Window2/lblEndless");


func _ready() -> void :
	return

func init_data():
	var wf = DataManager.get_current_war_fight()
	if DataManager.endless_mode:
		var type = "【守城战】"
		if EndlessGame.war_vstate_no_player == 1:
			type = "【攻城战】"
			EndlessGame.update_stats_data(wf.attackerWV, wf.defenderWV)
		else:
			EndlessGame.update_stats_data(wf.defenderWV, wf.attackerWV)
		lblEndless.text = "【{0}】无尽第{1}关{2}".format([
			StaticManager.DIFFICULTY_NAMES[DataManager.diffculities], 
			EndlessGame.pass_no + 1, type])
		lblEndless.show()
	else:
		lblEndless.hide()
	for setting in [
		[wf.defenderWV, def_node, ["防卫", "败战"]], 
		[wf.attackerWV, atk_node, ["胜利", "败战"]]
		]:
		var wv = setting[0]
		var node = setting[1]
		var memo = setting[2]
		var lbllord: Label = node.get_node("lord/lblName")
		var lblresult: Label = node.get_node("result/lblName")
		var lbllose_sodiers: Label = node.get_node("lose_sodiers/lblName")
		var lbllose_actors: Label = node.get_node("lose_actors/lblName")
		var lbladd_actors: Label = node.get_node("add_actors/lblName")
		lbllord.text = wv.vstate().get_lord_name() + "  军"
		if wv.lost():
			lblresult.text = memo[1]
		else:
			lblresult.text = memo[0]
		
		lbllose_actors.text = str(wv.get_lose_actors().size());
		
		lbllose_sodiers.text = str(int(wv.get_lose_sodiers()));
		if DataManager.endless_mode:
			var stats = EndlessGame.get_stats_data()
			var key = "ai"
			if wv.get_main_controlNo() >= 0:
				key = "player"
			lbllose_sodiers.text = str(int(stats[key]["soldiers"]))
		
		lbladd_actors.text = str(wv.get_add_actors_num())
	return
