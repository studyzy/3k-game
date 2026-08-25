# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：test/random.gd
# 说明：测试-随机数。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends "base.gd"

func runAll() -> bool:
	return runRandom()\
	and runRate()\
	and runPersuade()

func runRandom() -> bool:
	trace("【随机数测试】")
	var times = 300000
	randomize()
	var minVal = randi() % 100 - 100
	var maxVal = minVal + randi() % 100 + 1
	trace("范围：[{0}, {1}]，次数：{2}".format([
		minVal, maxVal, times
	]))
	var stats = []
	var overflow = 0
	for i in range(maxVal - minVal + 1):
		stats.append(0)
	for i in times:
		var val = Global.get_random(minVal, maxVal)
		if val < minVal:
			overflow += 1
			continue
		if val > maxVal:
			overflow += 1
			continue
		stats[val - minVal] += 1
	var variance = calculate_variance(stats)
	trace("循环完成，分布标准方差（应接近1）：{0}".format([
		variance
	]))
	if overflow > 0:
		warn("有{0}次溢出范围".format([overflow]))
	if abs(variance - 1.0) > 0.15:
		warn("标准方差异常")
		trace("max: {0}".format([stats.max()]))
		trace("min: {0}".format([stats.min()]))
		trace("stats: {0}".format([",".join(stats)]))
	return true

func runRate() -> bool:
	var msgs = []
	trace("【概率测试】")
	var times = 300000
	randomize()
	var rate = randi() % 100 + 1
	trace("目标概率：{0}%，次数：{1}".format([
		rate, times
	]))
	var successful = 0
	var failed = 0
	for i in times:
		if Global.get_rate_result(rate):
			successful += 1
		else:
			failed += 1
	var actualRate: int = successful * 10000 / times
	trace("循环完成，实际概率：{0}.{1}%".format([
		int(actualRate / 100), actualRate % 100
	]))
	if actualRate - rate * 100 > 100:
		warn("实际概率偏差较大")
	return true

func runPersuade() -> bool:
	var msgs = []
	trace("【单挑说服测试】")
	var times = 300000
	randomize()
	var script = LoadControl.load_or_reuse_script("solo/solo_persuade.gd")
	var fromId = StaticManager.ACTOR_ID_ZHUGELIANG
	var targetId = StaticManager.ACTOR_ID_LVBU
	initWar(0, 1, 0)
	var from = createWarActor(fromId, 0, true)
	var target = createWarActor(targetId, 1, true)
	trace("我方：" + from.get_name())
	trace("敌方：" + target.get_name())
	for val in [99, 80, 60]:
		tryPersuade(from, target, script, val, val, 90, 90)
		tryPersuade(from, target, script, val, val, 90, 70)
		tryPersuade(from, target, script, val, val, 70, 90)
		tryPersuade(from, target, script, val, val, 90, 40)
		tryPersuade(from, target, script, val, val, 40, 90)
		tryPersuade(from, target, script, val, val, 70, 40)
		tryPersuade(from, target, script, val, val, 40, 70)
		tryPersuade(from, target, script, val, val, 40, 40)
	return true

func tryPersuade(fromWA, targetWA, script, wisdom, moral, loyalty, hp) -> Dictionary:
	var from = fromWA.actor()
	var target = targetWA.actor()
	from._set_attr_int("知", wisdom)
	from._set_attr_int("德", moral)
	trace("== 我方：知 + 德 = {0}".format([from.get_wisdom() + from.get_moral()]))
	target._set_attr_int("忠", loyalty)
	target._set_attr_int("体", hp)
	trace("== 敌方：忠 {0} 体 {1}".format([target.get_loyalty(), target.get_hp()]))
	var results = {}
	for i in 10000:
		var result = script.solo_persuade_result(fromWA, targetWA)
		if not result in results:
			results[result] = 0
		results[result] += 1
	var memo = ["", "瞅你咋地", "不可再战", "此等君主", "弃暗投明"]
	for result in results:
		trace("{0}次结果为{1}".format([results[result], memo[result]]))
	return results
