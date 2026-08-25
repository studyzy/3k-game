# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：test/war_intro_test.gd
# 说明：测试-战争开场。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends GdUnitTestSuite


func test_war_intro_display():
	
	var wf = WarFight.new(1, 2)
	wf.fromVstateId = 1
	wf.targetVstateId = 2

	
	wf.attackerWV = War_Vstate.new(1, false)
	var attacker_wa = War_Actor.new(1, 1)
	attacker_wa.actorId = 1
	wf.attackerWV.warActors.append(attacker_wa)

	
	wf.defenderWV = War_Vstate.new(2, false)
	var defender_wa = War_Actor.new(2, 2)
	defender_wa.actorId = 2
	wf.defenderWV.warActors.append(defender_wa)

	
	if is_instance_valid(SceneManager.war_intro):
		SceneManager.war_intro.show_war_intro(wf, "test_callback")
		assert_true(SceneManager.war_intro.visible, "战争介绍应该显示")

		
		yield(get_tree().create_timer(0.5), "timeout")
		SceneManager.war_intro.hide_immediately()
		assert_false(SceneManager.war_intro.visible, "战争介绍应该隐藏")

	pass