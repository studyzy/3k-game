# ==============================================================================
# 新增：AI Agent 接入（战争场景）
# 文件：packed/sgz_script/war/AI/StratagemProjection.gd
# 说明：用计预估——命中概率 + 命中后的结果，供 LLM 判断「值不值得放这个计」。
#
# 口径（全部照搬引擎，不另立公式）：
#   命中率    StratagemInfo.get_rate()：读 stratagem.json 的 data.formula，代入
#             距离 / a.知 / b.知 / a.等级 / b.等级（含装备「计视距离」「计策附加智力」、
#             状态「伤神」），与玩家界面显示的「计策命中率」同源。
#             每个目标单独判定（clStratagemExecution._perform_to_target 就是这么做的），
#             综合命中率 = 1 - Π(1 - 单目标命中率)。
#   作用对象  StratagemExecution.get_affected_actors()：范围计策取覆盖范围内
#             同阵营、地形合法的武将，与执行时 targets 完全一致。
#   伤害量    count_formula_string(impact.soldier/hp/rice/heal)：random() 取整后取均值
#             （即 (lo+hi)/2），兵力系数、施术者兵力按当前状态逐个目标重算。
#             不触发技能（20002/20011/20029）与装备的追加修正，所以是基准估算。
#   后续连锁  StratagemInfo._get_extended_targets()：共杀/劫火/乱水的邻接蔓延、
#             铁索传导后的完整受害名单。
#
# 不改任何游戏状态：连 DataManager.stratagem_execution（当前计策执行对象）都不换，
# 只读 StaticManager 的计策表，自己用 StratagemExecution 的只读方法算。
# ==============================================================================
extends Resource


# 入口：fromId 对 targetId 使用 name 计策的预估。name 为空时取 env「计策名」。
# 注意：Global.load_script 返回的是脚本实例，因此入口方法不是 static，
# 内部所有 base 方法都是 static（实例与非 static 同名时以实例方法为准）。
func estimate(fromId: int, targetId: int, name: String = "") -> Dictionary:
	if name == "":
		name = DataManager.get_env_str("计策名")
	var fromWA = DataManager.get_war_actor(fromId)
	var targetWA = DataManager.get_war_actor(targetId)
	var res = {"from": fromId, "target": targetId, "stratagem": name}
	if fromWA == null or targetWA == null:
		res["ok"] = false
		res["reason"] = "武将不存在"
		return res
	var info = StaticManager.get_stratagem(name)
	if info == null:
		res["ok"] = false
		res["reason"] = "没有名为「{0}」的计策".format([name])
		return res

	var reason = _unavailable_reason(info, fromWA, targetWA)
	if reason != "":
		res["ok"] = false
		res["reason"] = reason
		res["targets"] = []
		return res

	# 临时执行对象只用来调引擎的只读方法；用完还原判断，不覆盖正在进行的计策流程
	var se = StratagemExecution.new(fromId, name)
	var targets = se.get_affected_actors(targetWA.position)
	if targets.empty():
		res["ok"] = false
		res["reason"] = "没有可作用的对象"
		res["targets"] = []
		return res

	# 逐个目标算命中率（含装备与战斗状态修正，与界面口径一致）
	var rates = []
	var rawRates = []
	var defenders = []
	var failRate = 1.0
	for tid in targets:
		var did = se.get_defender_id(tid)
		var rate = info.get_rate(fromId, did)
		defenders.append({"id": tid, "defender": did})
		rates.append({"id": tid, "value": rate})
		rawRates.append({"id": tid, "value": info.get_raw_rate(fromId, did)})
		failRate *= (1.0 - float(rate) / 100.0)

	res["ok"] = true
	res["targets"] = targets
	res["rate"] = int((1.0 - failRate) * 100)
	res["raw_rate"] = se.get_raw_rate(targets)
	res["rate_by_target"] = rates
	res["raw_rate_by_target"] = rawRates
	res["defenders"] = defenders
	res["cost_ap"] = info.get_cost_ap(fromId)
	res["is_stratagem"] = info.is_stratagem()

	# 命中后的结果：每个作用对象一份（含被波及的连锁对象）
	var impacts = {}
	var officer = {"soldier": [], "hp": [], "rice": [], "heal": [], "buff": [], "special": []}
	for tid in targets:
		var rows = _target_impacts(se, info, fromWA, targetWA, tid)
		impacts[str(tid)] = rows
		for key in officer:
			for row in rows["target"].get(key, []):
				officer[key].append(row)
	res["impacts"] = impacts
	res["officer_impacts"] = officer
	if info.impact.has("area"):
		var area = info.impact["area"]
		res["area"] = {"tag": str(area.get("tag", "")), "round": int(area.get("round", 0))}
	if info.has_range_impact():
		res["terrain_effects"] = _range_effects(info, se, targetWA.position)
	# 给 LLM 的一句话结论：中计概率 + 中计后会怎样（明细 JSON 仍保留，人看的）
	res["summary"] = _summary(res, fromWA, targetWA)
	return res


# ---------------- 给模型看的文字结论 ----------------
# 只输出「中计概率」与「中计后的结果」，避免把逐目标的原始行堆给模型。
func _summary(res: Dictionary, fromWA, targetWA) -> String:
	if res.get("ok", false) != true:
		return "不可用：%s" % [str(res.get("reason", ""))]
	var parts = ["命中率 %d%%" % [int(res["rate"])]]
	parts.append("耗机动力 %d" % [int(res.get("cost_ap", 0))])
	parts.append("命中后：" + _summary_effect(res, fromWA, targetWA))
	return "，".join(parts)


func _summary_effect(res: Dictionary, fromWA, targetWA) -> String:
	var officer = res.get("officer_impacts", {})
	var items = []
	items.append_array(_summary_soldier(officer.get("soldier", [])))
	items.append_array(_summary_hp(officer.get("hp", [])))
	items.append_array(_summary_rice(officer.get("rice", [])))
	items.append_array(_summary_heal(officer.get("heal", [])))
	items.append_array(_summary_buff(officer.get("buff", [])))
	items.append_array(_summary_special(officer.get("special", [])))
	if res.has("area"):
		var area = res["area"]
		if int(area.get("round", 0)) > 0:
			items.append("布下【%s】持续 %d 回合" % [str(area.get("tag", "")), int(area["round"])])
		else:
			items.append("布下【%s】" % [str(area.get("tag", ""))])
	for eff in res.get("terrain_effects", []):
		var note = str(eff.get("note", ""))
		if str(eff.get("effect", "")) == "flame_over":
			items.append(note + "（持续燃烧）")
		elif str(eff.get("effect", "")) == "rain":
			items.append(note)
	if items.empty():
		return "按当前兵力与属性算不出兵力/体力/粮草损失，也无状态效果"
	return "；".join(items)


func _who(id: int) -> String:
	var wa = DataManager.get_war_actor(id)
	if wa == null:
		return "#%d" % [id]
	return "%s#%d" % [wa.get_name(), id]


func _summary_soldier(rows: Array) -> Array:
	var ret = []
	for row in rows:
		if int(row.get("damage", 0)) <= 0:
			continue
		ret.append("%s 损兵 %d（%d→%d）" % [
			_who(int(row["id"])), int(row["damage"]), int(row["soldiers"]), int(row["soldiers_after"]),
		])
	return ret


func _summary_hp(rows: Array) -> Array:
	var ret = []
	for row in rows:
		var text = "%s 伤体 %d（%d→%d）" % [
			_who(int(row["id"])), int(row["damage"]), int(row["hp"]), int(row["hp_after"]),
		]
		if row.get("captured", false):
			text += "，体力归零将被俘"
		ret.append(text)
	return ret


func _summary_rice(rows: Array) -> Array:
	var ret = []
	for row in rows:
		if int(row.get("damage", 0)) <= 0:
			continue
		ret.append("敌方粮草 -%d（剩 %d）" % [int(row["damage"]), max(0, int(row.get("rice", 0)) - int(row["damage"]))])
	return ret


func _summary_heal(rows: Array) -> Array:
	var ret = []
	for row in rows:
		ret.append("%s 回复体力 %d（%d→%d）" % [
			_who(int(row["id"])), int(row["heal"]), int(row["hp"]), int(row["hp_after"]),
		])
	return ret


func _summary_buff(rows: Array) -> Array:
	var ret = []
	for row in rows:
		var text = "%s 【%s】%d 回合" % [_who(int(row["id"])), str(row.get("buff", "")), int(row.get("turns", 0))]
		var daily = row.get("daily_effect", {})
		if typeof(daily) == TYPE_DICTIONARY and not daily.empty():
			var bits = []
			if daily.has("soldier"):
				bits.append("每日损兵 %d" % [int(daily["soldier"])])
			if daily.has("hp"):
				bits.append("每日伤体 %d" % [int(daily["hp"])])
			if not bits.empty():
				text += "（" + "、".join(bits) + "）"
		ret.append(text)
	return ret


func _summary_special(rows: Array) -> Array:
	var ret = []
	for row in rows:
		var eff = str(row.get("effect", ""))
		var who = _who(int(row.get("id", - 1)))
		match eff:
			"笼络":
				if row.get("defect", false):
					ret.append("%s 有被招降的风险" % [who])
				else:
					ret.append("%s 不会被招降（%s）" % [who, str(row.get("note", ""))])
			"撤退":
				if row.get("no_retreat", false):
					ret.append("%s 无可退城池，撤退无效" % [who])
				else:
					ret.append("%s 被强制撤回 %s" % [who, str(row.get("to_city_name", ""))])
			"机动力回复":
				ret.append("自身回复 1 点机动力")
			"随机位移":
				ret.append("%s 被随机移走" % [who])
			_:
				ret.append("%s %s" % [who, eff])
	return ret


# ---------------- 可用性 ----------------

func _unavailable_reason(info, fromWA, targetWA) -> String:
	if fromWA.disabled or not fromWA.has_position():
		return "施术者当前无法行动"
	if fromWA.get_buff_label_turn(["禁用计策"]) > 0:
		return "施术者处于「禁用计策」状态"
	if targetWA.disabled or not targetWA.has_position():
		return "目标当前无法行动"
	if not info.match_skill_mode():
		return "本局游戏设置下无法使用「{0}」".format([info.name])

	var cd = 0
	if fromWA.dic_skill_cd.has(info.name):
		cd = int(fromWA.dic_skill_cd[info.name])
	if cd > 0:
		return "「{0}」冷却中，还需 {1} 回合".format([info.name, cd])

	var apCost = info.get_cost_ap(fromWA.actorId)
	if fromWA.action_point < apCost:
		# 机动力不够：只有「计策用体」装备当天次数还没用完，才能强行发动
		var canPayByHp = false
		var wf = DataManager.get_current_war_fight()
		for item in fromWA.actor().get_equip_feature_all("计策用体"):
			var equip = item[0]
			var val = item[1]
			var key = "CD.{0}.{1}.{2}".format([equip.name(), fromWA.actorId, wf.date])
			if val <= wf.get_env_int(key):
				continue
			canPayByHp = true
			break
		if not canPayByHp:
			return "机动力不足：需要 {0} 点，当前 {1} 点".format([apCost, fromWA.action_point])

	# 引擎在选目标阶段就会自动排除的规则（千追、毅重、守关、驻山、恃远……）
	var disabled = info.get_available_targets(fromWA.actorId)[1]
	if str(targetWA.actorId) in disabled:
		var why = disabled[str(targetWA.actorId)]
		return "因{0}【{1}】效果，不可对{2}发动{3}".format([
			ActorHelper.actor(why[0]).get_name(), why[1],
			targetWA.get_name(), info.name,
		])
	return ""


# ---------------- 命中后的结果 ----------------

func _target_impacts(se, info, fromWA, mainWA, mainTargetId: int) -> Dictionary:
	# 引擎的实际受害名单：主目标 + 连锁/范围波及（主目标排首位，与执行顺序一致）
	var allTargets = info._get_extended_targets(fromWA, mainWA)
	allTargets.erase(mainTargetId)
	allTargets.insert(0, mainTargetId)
	var isStratagem = info.is_stratagem()
	var target = {}
	for key in info.impact:
		var impact = info.impact[key]
		match key:
			"soldier":
				target["soldier"] = _soldier_rows(info, fromWA, allTargets, str(impact), isStratagem)
			"hp":
				target["hp"] = _hp_rows(info, fromWA, allTargets, str(impact), isStratagem)
			"rice":
				target["rice"] = _rice_rows(fromWA, allTargets, str(impact))
			"heal":
				target["heal"] = _heal_rows(fromWA, allTargets, str(impact))
			"buff":
				target["buff"] = _buff_rows(info, fromWA, allTargets, impact)
			"specialEffect":
				target["special"] = _special_rows(fromWA, allTargets, str(impact))
			_:
				pass
	var chained = []
	for tid in allTargets:
		if tid == mainTargetId:
			continue
		var wa = DataManager.get_war_actor(tid)
		if wa == null:
			continue
		chained.append({
			"id": tid,
			"soldiers": wa.get_soldiers(),
			"terrain": _terrain_of(tid),
		})
	return {
		"target": target,
		"chained": chained,
	}


func _soldier_rows(info, fromWA, targets: PoolIntArray, formula: String, isStratagem: bool) -> Array:
	var ret = []
	# 引擎的兵力系数读的是「施术者当前兵力」（clStratagem.gd _impact_for_soldier_damage），
	# 且每打掉一个目标就减少，后续目标的系数跟着变
	var fromSoldiers = fromWA.get_soldiers()
	var feature = info.get_feature()
	for tid in targets:
		var targetWA = DataManager.get_war_actor(tid)
		if targetWA == null or targetWA.disabled or not targetWA.has_position():
			continue
		# 道术（仙术）对「仙术无效」的目标无效
		if "道术" in feature and tid != fromWA.actorId:
			if targetWA.actor().get_equip_feature_max("仙术无效") > 0:
				continue

		var f = formula.replace("命中人数", str(targets.size()))
		f = f.replace("a.兵力", str(fromSoldiers))
		var dic = {}
		if isStratagem and info.is_stratagem():
			dic["a.知"] = fromWA.actor().get_equip_feature_total("计策附加智力")
		var damage = _avg_formula(f, fromWA.actorId, tid, dic)
		# 伤神：施术者带「伤神」时计策伤害减半
		if fromWA.get_buff_label_turn(["伤神"]) > 0:
			damage = int(damage / 2)
		# 城墙等地形减伤
		var weakened = info.get_targeting_weakened_terrian()
		if weakened != "" and _terrain_of(tid) in weakened:
			damage = int(damage / 2)

		var soldiers = targetWA.get_soldiers()
		damage = min(soldiers, damage)
		if damage > 0:
			fromSoldiers = max(0, fromSoldiers - damage)
		ret.append({
			"id": tid,
			"soldiers": soldiers,
			"damage": damage,
			"soldiers_after": max(0, soldiers - damage),
		})
	return ret


func _hp_rows(info, fromWA, targets: PoolIntArray, formula: String, isStratagem: bool) -> Array:
	var ret = []
	var feature = info.get_feature()
	for tid in targets:
		var targetWA = DataManager.get_war_actor(tid)
		if targetWA == null or targetWA.disabled:
			continue
		if "道术" in feature and tid != fromWA.actorId:
			if targetWA.actor().get_equip_feature_max("仙术无效") > 0:
				continue
		var damage = _avg_formula(formula, fromWA.actorId, tid, {})
		if fromWA.get_buff_label_turn(["伤神"]) > 0:
			damage = int(damage / 2)
		if damage <= 0:
			continue
		var hp = int(targetWA.actor().get_hp())
		ret.append({
			"id": tid,
			"hp": hp,
			"damage": damage,
			"hp_after": max(0, hp - damage),
			"captured": hp - damage <= 0,
		})
	return ret


func _rice_rows(fromWA, targets: PoolIntArray, formula: String) -> Array:
	var ret = []
	for tid in targets:
		var targetWA = DataManager.get_war_actor(tid)
		if targetWA == null or targetWA.disabled:
			continue
		var wv = targetWA.war_vstate()
		var f = formula
		var rice = 0
		if wv != null:
			rice = wv.rice
			f = f.replace("b.米", str(rice))
		else:
			f = f.replace("b.米", "0")
		ret.append({
			"id": tid,
			"rice": rice,
			"damage": min(rice, _avg_formula(f, fromWA.actorId, tid, {})),
		})
	return ret


func _heal_rows(fromWA, targets: PoolIntArray, formula: String) -> Array:
	var ret = []
	for tid in targets:
		var targetWA = DataManager.get_war_actor(tid)
		if targetWA == null or targetWA.disabled:
			continue
		# 引擎只治疗友军
		if targetWA.is_enemy(fromWA):
			continue
		var hp = int(targetWA.actor().get_hp())
		var maxHp = int(targetWA.actor().get_max_hp())
		var heal = min(_avg_formula(formula, fromWA.actorId, tid, {}), max(0, maxHp - hp))
		if heal <= 0:
			continue
		ret.append({
			"id": tid,
			"hp": hp,
			"hp_max": maxHp,
			"heal": heal,
			"hp_after": hp + heal,
		})
	return ret


func _buff_rows(info, fromWA, targets: PoolIntArray, impact: Dictionary) -> Array:
	var ret = []
	var buff = str(impact["name"])
	var feature = info.get_feature()
	for tid in targets:
		var targetWA = DataManager.get_war_actor(tid)
		if targetWA == null or targetWA.disabled:
			continue
		# 引擎只给敌方附加状态
		if not targetWA.is_enemy(fromWA):
			continue
		if "道术" in feature and tid != fromWA.actorId:
			if targetWA.actor().get_equip_feature_max("仙术无效") > 0:
				continue
		var turns = 0
		if "round" in impact:
			turns = int(impact["round"])
		if turns <= 0 and "formula" in impact:
			turns = _avg_formula(str(impact["formula"]), fromWA.actorId, tid, {})
		if turns <= 0:
			continue
		var row = {"id": tid, "buff": buff, "turns": turns}
		# 状态自身的每日效果（如八阵每天 random(80,150) 兵力）
		var buffInfo = StaticManager.get_buff(buff)
		if buffInfo != null and typeof(buffInfo.impact) == TYPE_DICTIONARY:
			var effect = {}
			for key in ["soldier", "hp"]:
				if not buffInfo.impact.has(key):
					continue
				effect[key] = _avg_formula(str(buffInfo.impact[key]), tid, - 1, {})
			if not effect.empty():
				row["daily_effect"] = effect
		ret.append(row)
	return ret


func _special_rows(fromWA, targets: PoolIntArray, effect: String) -> Array:
	var ret = []
	for tid in targets:
		var targetWA = DataManager.get_war_actor(tid)
		if targetWA == null or targetWA.disabled:
			continue
		match effect:
			"笼络":
				if not targetWA.is_enemy(fromWA):
					continue
				# 判定细节见 War_Actor.actor_surrend_to
				var row = {"id": tid, "effect": "笼络", "defect": true}
				if SkillRangeBuff.max_val_for_actor("决忠", tid) > 0:
					row["defect"] = false
					row["note"] = "因【决忠】不受招降"
				elif targetWA.is_puppet():
					row["defect"] = false
					row["note"] = "人偶会被击破，不会加入"
				ret.append(row)
			"撤退":
				var wv = targetWA.war_vstate()
				var toCityId = - 1
				if wv != null and wv.from_cityId >= 0:
					var fromCity = clCity.city(wv.from_cityId)
					if fromCity != null and fromCity.get_vstate_id() == wv.vstate().id:
						toCityId = fromCity.ID
				var row = {"id": tid, "effect": "撤退", "to_city": toCityId}
				if toCityId >= 0:
					row["to_city_name"] = clCity.city(toCityId).get_full_name()
				else:
					row["no_retreat"] = true
					row["note"] = "无可退城池，计策对其无效"
				ret.append(row)
			"机动力回复":
				ret.append({"id": fromWA.actorId, "effect": effect, "value": 1})
			"随机位移":
				ret.append({"id": tid, "effect": effect, "note": "会被移到覆盖范围内随机空位"})
			_:
				ret.append({"id": tid, "effect": effect})
	return ret


# ---------------- 范围地块影响（火原/树林后续燃烧、浇灭） ----------------

func _range_effects(info, se, pos: Vector2) -> Array:
	var ret = []
	var positions = se.get_affected_positions(pos)
	var map = SceneManager.current_scene().war_map
	for impact in info.get_range_impacts():
		match impact:
			"blow", "flame_over":
				var flame = false
				for p in positions:
					if map.get_blockCN_by_position(p) == "火原":
						flame = true
						break
				if not flame:
					continue
				var blocks = {}
				for p in positions:
					var kind = map.get_blockCN_by_position(p, true)
					if not kind in ["平原", "树林", "山地"]:
						continue
					if not blocks.has(kind):
						blocks[kind] = 0
					blocks[kind] += 1
				if blocks.empty():
					continue
				ret.append({"effect": impact, "note": "附近有火原，会点燃下列地块", "blocks": blocks})
			"rain":
				var fire = 0
				for p in positions:
					if map.get_blockCN_by_position(p) == "火原":
						fire += 1
				if fire > 0:
					ret.append({"effect": impact, "note": "浇灭火原", "blocks": {"火原": fire}})
	return ret


# ---------------- 公式求值 ----------------

func _terrain_of(actorId: int) -> String:
	var wa = DataManager.get_war_actor(actorId)
	if wa == null or not wa.has_position():
		return ""
	var map = SceneManager.current_scene().war_map
	return map.get_blockCN_by_position(wa.position)


# 求公式的期望值：把每个 random(a,b) 换成 (a+b)/2 的数值后交给引擎求值，
# 属性替换、int()/min()/max() 的语义与引擎完全一致。
# random 的参数本身可能是表达式（如 a.等级-1+(a.武+a.知)/10），
# 所以先用引擎把参数算成数字，再取均值。
func _avg_formula(formula: String, aId: int, bId: int, dic: Dictionary) -> int:
	var f = formula
	var pos = f.find("random(")
	while pos >= 0:
		var end = _match_paren(f, pos + 6)
		if end < 0:
			break
		var args = f.substr(pos + 7, end - pos - 7).split(",")
		var avg = "0"
		if args.size() == 2:
			var lo = int(Global.count_formula_number(args[0], aId, bId, dic))
			var hi = int(Global.count_formula_number(args[1], aId, bId, dic))
			avg = str((lo + hi) / 2)
		f = f.substr(0, pos) + avg + f.substr(end + 1)
		pos = f.find("random(", pos + avg.length())
	return int(Global.count_formula_number(f, aId, bId, dic))


# 从 openPos（指向 random 后的 "("）起找到配对的 ")"
# depth 是「当前仍在配对栈里的开括号数」：openPos 处就是第一个 "("，
# 因此要在读到配对的 ")" 时先减到 0 再返回。若按「读到 0 即返回」的写法，
# 会在第一个 ")" 处（depth 已为 1）减到 0 却不返回，继续吞到公式末尾的 ")"，
# 把 random 参数截成 "9,13)/10+..." 导致整条公式解析失败（实测返回 0）。
static func _match_paren(s: String, openPos: int) -> int:
	var depth = 0
	for k in range(openPos, s.length()):
		var c = s[k]
		if c == "(":
			depth += 1
		elif c == ")":
			depth -= 1
			if depth == 0:
				return k
	return - 1