extends Control
## 计策/战术系统测试

func _ready() -> void:
	DataManager.load_all_configs()
	# 测试 16 种计策构造
	var names := []
	for pid in 16:
		var plan := Plan.get_plan(pid)
		if plan == null:
			print("[Plan] 计策%d 构造失败！" % pid)
			continue
		names.append(plan.get_plan_name())
	print("[Plan] 16种计策: %s" % str(names))
	# 测试计策效果
	var do_gen := GeneralListCache.get_general(61)  # 曹芳
	var be_gen := GeneralListCache.get_general(69)  # 刘禅
	do_gen.soldiers = 1000
	be_gen.soldiers = 1500
	# 火攻
	var huoji := Plan.get_plan(0)
	var rate := huoji.rate(do_gen, be_gen)
	var result := huoji.result(do_gen, be_gen, true)
	print("[Plan] 火攻 成功率=%d 结果: %s" % [rate, result])
	print("[Plan] 火攻后敌人兵力=%d" % be_gen.soldiers)
	# 陷阱
	var xianjing := Plan.get_plan(1)
	var result2 := xianjing.result(do_gen, be_gen, true)
	print("[Plan] 陷阱 结果: %s 敌人HP=%d" % [result2, be_gen.health])
	# 奇门遁甲
	var qimen := Plan.get_plan(15)
	print("[Plan] 奇门遁甲 成功率=%d" % qimen.rate(do_gen, be_gen))
	# 战术
	for tid in [1, 2, 3, 4, 5, 6]:
		var tactic := Tactic.get_tactic(tid)
		if tactic == null:
			print("[Tactic] 战术%d 构造失败" % tid)
			continue
		print("[Tactic] %s 消耗%d 持续%d" % [tactic.get_name(), tactic.get_cost(), tactic.get_duration()])
	# 单挑攻防
	var atk := do_gen.get_attack_power()
	var def := be_gen.get_defend_power()
	var dea := SoloManager.get_atk_dea(do_gen, atk, def)
	var pct := SoloManager.get_percentage(do_gen, be_gen, false, false)
	print("[Solo] 单挑 攻=%d 防=%d 伤害=%d 命中=%d" % [atk, def, dea, pct])
	print("[Plan] 计策/战术/单挑系统测试完成")
	get_tree().quit()
