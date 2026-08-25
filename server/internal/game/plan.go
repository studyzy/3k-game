package game

import "3k-server/internal/game/entities"

// PlanDef 计策定义（对应 scripts/data/plan.gd 16 种计策）
type PlanDef struct {
	ID            int
	Name          string
	Cost          int
	Distance      int
	BeTerrain     []int
	DoTerrain     []int
	FriendMinimum int // -1 表示无要求
}

// 16 种计策静态定义
var planDefs = []PlanDef{
	{ID: 0, Name: "火攻", Cost: 6, Distance: 5, BeTerrain: []int{1, 2, 3, 4, 10, 11}, FriendMinimum: -1},
	{ID: 1, Name: "陷阱", Cost: 5, Distance: 5, BeTerrain: []int{10, 12}, FriendMinimum: -1},
	{ID: 2, Name: "虚兵", Cost: 4, Distance: 5, BeTerrain: []int{10, 12}, FriendMinimum: -1},
	{ID: 3, Name: "要击", Cost: 6, Distance: 5, BeTerrain: []int{10, 12}, FriendMinimum: -1},
	{ID: 4, Name: "乱水", Cost: 6, Distance: 5, BeTerrain: []int{9}, FriendMinimum: -1},
	{ID: 5, Name: "劫粮", Cost: 8, Distance: 2, BeTerrain: []int{1, 2, 3, 4, 5, 6, 7, 10, 11, 12}, FriendMinimum: -1},
	{ID: 6, Name: "共杀", Cost: 8, Distance: 2, BeTerrain: []int{12}, FriendMinimum: 1},
	{ID: 7, Name: "伪击转杀", Cost: 8, Distance: 1, BeTerrain: []int{8}, FriendMinimum: -1},
	{ID: 8, Name: "烧粮", Cost: 10, Distance: 2, BeTerrain: []int{10, 11}, FriendMinimum: -1},
	{ID: 9, Name: "落石", Cost: 9, Distance: 2, DoTerrain: []int{8, 12}, BeTerrain: []int{1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12}, FriendMinimum: -1},
	{ID: 10, Name: "连环", Cost: 10, Distance: 5, BeTerrain: []int{9}, FriendMinimum: 1},
	{ID: 11, Name: "伏兵", Cost: 10, Distance: 5, DoTerrain: []int{11, 12}, BeTerrain: []int{1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12}, FriendMinimum: -1},
	{ID: 12, Name: "水攻", Cost: 12, Distance: 3, BeTerrain: []int{9}, FriendMinimum: 1},
	{ID: 13, Name: "箭雨", Cost: 10, Distance: 2, DoTerrain: []int{8, 12}, BeTerrain: []int{1, 2, 3, 4, 5, 6, 7, 9, 10, 11, 12}, FriendMinimum: -1},
	{ID: 14, Name: "劫火", Cost: 12, Distance: 3, BeTerrain: []int{10, 11}, FriendMinimum: 2},
	{ID: 15, Name: "奇门遁甲", Cost: 10, Distance: 9, BeTerrain: []int{10, 11, 12}, FriendMinimum: -1},
}

// PlanRef 根据 id 获取计策定义
func PlanRef(planID int) *PlanDef {
	if planID >= 0 && planID < len(planDefs) {
		return &planDefs[planID]
	}
	return nil
}

// ---- 通用公式（对应 plan.gd 基础方法） ----

// BaseRate 通用成功率（对应 _base_rate）
func (w *World) BaseRate(doGen, beGen *entities.General, d float64, extraIQ, extraStat, extraLead1 float64) int {
	iq1 := float64(doGen.Wisdom)
	iq2 := float64(beGen.Wisdom)
	stat2 := float64(beGen.Lead)
	lead1 := float64(doGen.Lead)
	r1 := int(iq1*0.3 + iq1*extraIQ + 70 - stat2*extraStat + lead1*extraLead1)
	r2 := int(iq1*iq1*(100-iq2*0.9)*100/(iq1*iq1+iq2*iq2)/d - (100.0-iq1)*0.1 - stat2*extraStat + lead1*extraLead1)
	if iq1 < iq2 {
		r2 -= int((iq2 - iq1) * 0.6)
	}
	if r1 < r2 {
		return r1
	}
	return r2
}

// RateEnhance 成功率增强（对应 _rate_enhance，神算）
func (w *World) RateEnhance(doGen *entities.General, rate int) int {
	if doGen.HasSkill1(5) { // 神算
		if doGen.GeneralName == "诸葛亮" {
			add := rate / 4
			if add < 15 {
				add = 15
			}
			rate += add
		} else {
			rate += rate / 5
		}
	}
	return rate
}

// RateWeaken 成功率削弱（对应 _rate_weaken，冷静/神算）
func (w *World) RateWeaken(beGen *entities.General, rate int) int {
	if beGen.HasSkill1(0) { // 冷静
		rate -= rate / 2
	} else if beGen.HasSkill1(5) { // 神算
		if beGen.GeneralName == "诸葛亮" {
			sub := rate / 4
			if sub < 15 {
				sub = 15
			}
			rate -= sub
		} else {
			rate -= rate / 5
		}
	}
	return rate
}

// ResultEnhance 效果增强（对应 _result_enhance，军师1.5倍）
func (w *World) ResultEnhance(doGen *entities.General, loss int) int {
	if doGen.HasSkill1(3) { // 军师
		loss += loss / 2
	}
	return loss
}

// AddPlanExp 计策经验（对应 _add_plan_exp）
func (w *World) AddPlanExp(doGen *entities.General, exp int) {
	doGen.AddExperience(exp / 3)
	doGen.AddIqExp(exp / 100)
}

// IqDamage 智力差伤害（对应 _iq_damage）
func (w *World) IqDamage(doGen, beGen *entities.General, base, iqMult int) int {
	loss := base
	diff := doGen.Wisdom - beGen.Wisdom
	if diff >= 0 {
		loss += w.Rng.IntRange(0, diff*iqMult+1)
	} else {
		loss += w.Rng.IntRange(diff*iqMult-2, -1)
	}
	return loss
}

// IsExecute 计策是否成功（对应 is_execute，含反计）
func (w *World) IsExecute(doGen, beGen *entities.General, plan *PlanDef) int {
	// 返回 0=失败 1=反计反弹 2=成功
	if beGen.HasSkill1(6) { // 反计
		if w.Rng.IntRange(0, 70) <= w.PlanRate(plan, beGen, doGen) {
			return 1
		}
	}
	if w.Rng.IntRange(0, 70) <= w.PlanRate(plan, doGen, beGen) {
		return 2
	}
	return 0
}

// PlanRate 计算指定计策成功率（对应各 Plan.rate）
func (w *World) PlanRate(plan *PlanDef, doGen, beGen *entities.General) int {
	r := 0
	switch plan.ID {
	case 0: // 火攻
		r = w.BaseRate(doGen, beGen, 40.0, -0.2, -0.05, 0)
		if doGen.HasSkill1(5) { // 神算
			if doGen.GeneralName == "诸葛亮" {
				add := r / 4
				if add < 15 {
					add = 15
				}
				r += add
			} else {
				r += r / 5
			}
		} else if doGen.HasSkill1(4) { // 火攻
			if doGen.GeneralName == "周瑜" {
				r += r / 2
			} else {
				r += r / 3
			}
		}
		r = w.RateWeaken(beGen, r)
	case 1: // 陷阱
		r = w.BaseRate(doGen, beGen, 40.0, -0.2, -0.05, 0)
		r = w.RateWeaken(beGen, r)
	case 2, 3: // 虚兵/要击
		r = xuBingRate(w, doGen, beGen)
	case 4: // 乱水
		iq1 := float64(doGen.Wisdom)
		iq2 := float64(beGen.Wisdom)
		lead2 := float64(beGen.Lead)
		typeA := armyAdapt(beGen, 2)
		r1 := int(iq1*0.3 - iq2*0.2 + 70 - lead2*0.05)
		r2 := int(iq1*iq1*(100-iq2*0.9)*100/(iq1*iq1+iq2*iq2)/40 - (100.0-iq1)*0.1 - lead2*0.05)
		if iq1 < iq2 {
			r2 -= int((iq2 - iq1) * 0.6)
		}
		if typeA > 0 {
			r1 -= typeA * 3
			r2 -= typeA * 2
		}
		r = r1
		if r2 < r {
			r = r2
		}
		r = w.RateEnhance(doGen, r)
		r = w.RateWeaken(beGen, r)
	case 5: // 劫粮
		r = w.BaseRate(doGen, beGen, 60.0, -0.2, -0.05, 0)
		if doGen.HasSkill1(5) {
			r = w.RateEnhance(doGen, r)
		} else if beGen.HasSkill1(8) { // 袭粮
			r += r / 3
		}
		r = w.RateWeaken(beGen, r)
	case 6, 12: // 共杀/水攻
		r = gongShaRate(w, doGen, beGen)
	case 7: // 伪击转杀
		if beGen.Soldiers <= 1800+w.Rng.IntRange(0, 299) {
			return 0
		}
		iq1 := float64(doGen.Wisdom)
		iq2 := float64(beGen.Wisdom)
		moral2 := float64(beGen.Charm)
		r1 := int(iq1*0.3 - iq2*0.2 + 70 - moral2*0.05)
		r2 := int(iq1*iq1*(100-iq2*0.9)*100/(iq1*iq1+iq2*iq2)/60 - (100.0-iq1)*0.1 - moral2*0.05)
		if iq1 < iq2 {
			r2 -= int((iq2 - iq1) * 0.6)
		}
		r = r1
		if r2 < r {
			r = r2
		}
		r = w.RateEnhance(doGen, r)
		r = w.RateEnhance(beGen, r)
	case 8: // 烧粮
		r = w.BaseRate(doGen, beGen, 70.0, -0.2, -0.05, 0)
		if doGen.HasSkill1(5) {
			r = w.RateEnhance(doGen, r)
		} else if beGen.HasSkill1(8) {
			r += r / 3
		}
		r = w.RateWeaken(beGen, r)
	case 9: // 落石
		r = luoShiRate(w, doGen, beGen)
	case 10: // 连环
		r = lianHuanRate(w, doGen, beGen)
	case 11, 13: // 伏兵/箭雨
		r = fuBingRate(w, doGen, beGen)
	case 14: // 劫火
		r = fuBingRate(w, doGen, beGen)
	case 15: // 奇门遁甲
		return 99
	}
	return clampInt(r, 0, 99)
}

// xuBingRate 虚兵/要击成功率
func xuBingRate(w *World, doGen, beGen *entities.General) int {
	iq1 := float64(doGen.Wisdom)
	iq2 := float64(beGen.Wisdom)
	force2 := float64(beGen.Force)
	r1 := int(iq1*0.3 - iq2*0.2 + 70 - force2*0.08)
	r2 := int(iq1*iq1*(100-iq2*0.9)*100/(iq1*iq1+iq2*iq2)/45 - (100.0-iq1)*0.1 - force2*0.08)
	if iq1 < iq2 {
		r2 -= int((iq2 - iq1) * 0.6)
	}
	r := r1
	if r2 < r {
		r = r2
	}
	r = w.RateEnhance(doGen, r)
	r = w.RateWeaken(beGen, r)
	return r
}

// gongShaRate 共杀/水攻成功率
func gongShaRate(w *World, doGen, beGen *entities.General) int {
	iq1 := float64(doGen.Wisdom)
	iq2 := float64(beGen.Wisdom)
	moral2 := float64(beGen.Charm)
	r1 := int(iq1*0.3 - iq2*0.2 + 70 - moral2*0.05)
	r2 := int(iq1*iq1*(100-iq2*0.9)*100/(iq1*iq1+iq2*iq2)/60 - (100.0-iq1)*0.1 - moral2*0.05)
	if iq1 < iq2 {
		r2 -= int((iq2 - iq1) * 0.6)
	}
	r := r1
	if r2 < r {
		r = r2
	}
	if doGen.HasSkill1(5) {
		r = w.RateEnhance(doGen, r)
	} else if beGen.HasSkill1(9) { // 内讧
		r += r / 3
	}
	r = w.RateWeaken(beGen, r)
	return r
}

// luoShiRate 落石成功率
func luoShiRate(w *World, doGen, beGen *entities.General) int {
	iq1 := float64(doGen.Wisdom)
	iq2 := float64(beGen.Wisdom)
	lead1 := float64(doGen.Lead)
	lead2 := float64(beGen.Lead)
	typeA := armyAdapt(beGen, 1)
	r1 := int(iq1*0.3 - iq2*0.2 + 70 - lead2*0.05 + lead1*0.05)
	r2 := int(iq1*iq1*(100-iq2*0.9)*100/(iq1*iq1+iq2*iq2)/40 - (100.0-iq1)*0.1 - lead2*0.05 + lead1*0.05)
	if iq1 < iq2 {
		r2 -= int((iq2 - iq1) * 0.6)
	}
	if typeA == 3 {
		r1 -= 6
		r2 -= 3
	}
	r := r1
	if r2 < r {
		r = r2
	}
	r = w.RateEnhance(doGen, r)
	r = w.RateWeaken(beGen, r)
	return r
}

// lianHuanRate 连环成功率
func lianHuanRate(w *World, doGen, beGen *entities.General) int {
	iq1 := float64(doGen.Wisdom)
	iq2 := float64(beGen.Wisdom)
	lead1 := float64(doGen.Lead)
	lead2 := float64(beGen.Lead)
	typeA := armyAdapt(beGen, 2)
	r1 := int(iq1*0.3 - iq2*0.33 + 80 - lead2*0.1 + lead1*0.1)
	r2 := int(iq1*iq1*(100-iq2*0.9)*100/(iq1*iq1+iq2*iq2)/50 - (100.0-iq1)*0.1 - lead2*0.1 + lead1*0.1)
	if iq1 < iq2 {
		r2 -= int((iq2 - iq1) * 0.6)
	}
	if typeA == 3 {
		r1 -= 6
		r2 -= 3
	}
	r := r1
	if r2 < r {
		r = r2
	}
	if doGen.HasSkill1(5) {
		r = w.RateEnhance(doGen, r)
	} else if beGen.HasSkill1(9) {
		r += r / 3
	}
	r = w.RateWeaken(beGen, r)
	return r
}

// fuBingRate 伏兵/箭雨/劫火成功率
func fuBingRate(w *World, doGen, beGen *entities.General) int {
	iq1 := float64(doGen.Wisdom)
	iq2 := float64(beGen.Wisdom)
	lead1 := float64(doGen.Lead)
	lead2 := float64(beGen.Lead)
	r1 := int(iq1*0.3 - iq2*0.2 + 70 - lead2*0.05 + lead1*0.08)
	r2 := int(iq1*iq1*(100-iq2*0.9)*100/(iq1*iq1+iq2*iq2)/60 - (100.0-iq1)*0.1 - lead2*0.05 + lead1*0.08)
	if iq1 < iq2 {
		r2 -= int((iq2 - iq1) * 0.6)
	}
	r := r1
	if r2 < r {
		r = r2
	}
	if doGen.HasSkill1(5) {
		r = w.RateEnhance(doGen, r)
	} else if beGen.HasSkill1(7) { // 待伏
		r += r / 3
	}
	r = w.RateWeaken(beGen, r)
	return r
}

// armyAdapt 获取武将某地形适性
func armyAdapt(g *entities.General, idx int) int {
	if idx < len(g.Army) {
		return g.Army[idx]
	}
	return 0
}

// ExecPlan 执行计策（对应各 Plan.result），返回结果文本
func (w *World) ExecPlan(plan *PlanDef, doGen, beGen *entities.General, isPlayer bool) string {
	switch plan.ID {
	case 0: // 火攻
		loss := w.IqDamage(doGen, beGen, 250, 2)
		if doGen.HasSkill1(4) { // 火攻
			loss *= 2
		} else if doGen.HasSkill1(3) { // 军师
			loss += loss / 2
		}
		if loss > beGen.Soldiers {
			loss = beGen.Soldiers
		}
		beGen.SubSoldiers(loss)
		w.AddPlanExp(doGen, loss)
		return beGen.GeneralName + "中了" + doGen.GeneralName + "之计！折损：" + itoaStr(loss) + " 兵马"
	case 1: // 陷阱
		hurt := w.Rng.IntRange(10, 20)
		hurt = w.ResultEnhance(doGen, hurt)
		if beGen.GetHp()-1 < hurt {
			hurt = beGen.GetHp() - 1
		}
		beGen.SubHp(hurt)
		w.AddPlanExp(doGen, hurt*15)
		return beGen.GeneralName + "中了" + doGen.GeneralName + "之计！受到：" + itoaStr(hurt) + "伤害"
	case 2: // 虚兵
		days := 1
		if doGen.HasSkill1(3) { // 军师
			days = 2
		}
		w.setTrapped(beGen.GeneralId, isPlayer, days)
		w.AddPlanExp(doGen, days*100)
		return beGen.GeneralName + "中了" + doGen.GeneralName + "之计！动弹不得"
	case 3, 4: // 要击/乱水
		return w.yaoJiResult(doGen, beGen, isPlayer)
	case 5: // 劫粮
		return w.jieLiangResult(doGen, beGen, isPlayer)
	case 6, 12: // 共杀/水攻
		return w.gongShaResult(doGen, beGen, isPlayer)
	case 7: // 伪击转杀
		return w.yaoJiResult(doGen, beGen, isPlayer)
	case 8: // 烧粮
		return w.shaoLiangResult(doGen, beGen, isPlayer)
	case 9: // 落石
		loss := w.IqDamage(doGen, beGen, 350, 3)
		loss = w.ResultEnhance(doGen, loss)
		if loss > beGen.Soldiers {
			loss = beGen.Soldiers
		}
		beGen.SubSoldiers(loss)
		hurt := w.Rng.IntRange(10, 20)
		hurt = w.ResultEnhance(doGen, hurt)
		if beGen.GetHp()-1 < hurt {
			hurt = beGen.GetHp() - 1
		}
		beGen.SubHp(hurt)
		w.AddPlanExp(doGen, loss+hurt*15)
		return beGen.GeneralName + "中了" + doGen.GeneralName + "之计！受到" + itoaStr(hurt) + "伤害,折损" + itoaStr(loss) + " 兵马"
	case 10: // 连环
		w.setTrapped(doGen.GeneralId, isPlayer, 3)
		w.setTrapped(beGen.GeneralId, isPlayer, 3)
		w.AddPlanExp(doGen, 900)
		return beGen.GeneralName + "等中了" + doGen.GeneralName + "之计, 被困三天"
	case 11: // 伏兵
		diff := doGen.Wisdom - beGen.Wisdom
		loss := 600
		if diff >= 0 {
			loss += w.Rng.IntRange(0, diff*3+1)
		} else {
			loss += w.Rng.IntRange(diff*4-2, -1)
		}
		loss = w.ResultEnhance(doGen, loss)
		if loss > beGen.Soldiers {
			loss = beGen.Soldiers
		}
		beGen.SubSoldiers(loss)
		w.setTrapped(beGen.GeneralId, isPlayer, 1)
		w.AddPlanExp(doGen, loss+300)
		return beGen.GeneralName + "中了" + doGen.GeneralName + "之计！折损：" + itoaStr(loss) + " 兵马且动弹不得"
	case 13: // 箭雨
		loss := w.IqDamage(doGen, beGen, 400, 3)
		loss = w.ResultEnhance(doGen, loss)
		if loss > beGen.Soldiers {
			loss = beGen.Soldiers
		}
		beGen.SubSoldiers(loss)
		w.AddPlanExp(doGen, loss)
		return beGen.GeneralName + "中了" + doGen.GeneralName + "之计！折损：" + itoaStr(loss) + " 兵马"
	case 14: // 劫火
		loss := w.IqDamage(doGen, beGen, 550, 3)
		if doGen.HasSkill1(3) { // 军师
			loss += loss / 2
		} else if doGen.HasSkill1(4) { // 火攻
			loss *= 2
		}
		if loss > beGen.Soldiers {
			loss = beGen.Soldiers
		}
		beGen.SubSoldiers(loss)
		total := loss
		total += w.surroundingLoss(beGen, loss, isPlayer)
		w.AddPlanExp(doGen, total)
		return beGen.GeneralName + "等中了" + doGen.GeneralName + "之计！总共折损：" + itoaStr(total) + " 兵马"
	case 15: // 奇门遁甲
		loss := 100 - w.Rng.IntRange(0, 149-beGen.Lead)
		beGen.SubSoldiers(loss)
		w.AddPlanExp(doGen, 6*loss)
		return doGen.GeneralName + "已布下奇门遁甲之阵"
	}
	return ""
}

// yaoJiResult 要击结果
func (w *World) yaoJiResult(doGen, beGen *entities.General, isPlayer bool) string {
	loss := w.IqDamage(doGen, beGen, 250, 2)
	loss = w.ResultEnhance(doGen, loss)
	if loss > beGen.Soldiers {
		loss = beGen.Soldiers
	}
	beGen.SubSoldiers(loss)
	w.AddPlanExp(doGen, loss)
	return beGen.GeneralName + "中了" + doGen.GeneralName + "之计！折损：" + itoaStr(loss) + " 兵马"
}

// jieLiangResult 劫粮结果
func (w *World) jieLiangResult(doGen, beGen *entities.General, isPlayer bool) string {
	if w.War == nil {
		return "未在战争中"
	}
	var targetFood, gainFood *int
	if isPlayer {
		targetFood = &w.War.AiFood
		gainFood = &w.War.HmFood
	} else {
		targetFood = &w.War.HmFood
		gainFood = &w.War.AiFood
	}
	loss := *targetFood / 4
	loss = w.ResultEnhance(doGen, loss)
	if loss < 200 {
		loss = *targetFood
	}
	*targetFood -= loss
	if *gainFood+loss > 30000 {
		*gainFood = 30000
	} else {
		*gainFood += loss
	}
	w.AddPlanExp(doGen, loss)
	return beGen.GeneralName + "中了" + doGen.GeneralName + "之计！被劫：" + itoaStr(loss) + "军粮"
}

// gongShaResult 共杀/水攻结果
func (w *World) gongShaResult(doGen, beGen *entities.General, isPlayer bool) string {
	loss := w.IqDamage(doGen, beGen, 450, 3)
	loss = w.ResultEnhance(doGen, loss)
	surroundLoss := loss
	if loss > beGen.Soldiers {
		loss = beGen.Soldiers
	}
	beGen.SubSoldiers(loss)
	total := loss + w.surroundingLoss(beGen, surroundLoss, isPlayer)
	w.AddPlanExp(doGen, total)
	return beGen.GeneralName + "等中了" + doGen.GeneralName + "之计！总共折损：" + itoaStr(total) + " 兵马"
}

// shaoLiangResult 烧粮结果
func (w *World) shaoLiangResult(doGen, beGen *entities.General, isPlayer bool) string {
	if w.War == nil {
		return "未在战争中"
	}
	loss := 0
	if isPlayer {
		loss = w.War.AiFood / 2
		loss = w.ResultEnhance(doGen, loss)
		if loss < 500 {
			loss = w.War.AiFood
		}
		w.War.AiFood -= loss
	} else {
		loss = w.War.HmFood / 2
		loss = w.ResultEnhance(doGen, loss)
		if loss < 500 {
			loss = w.War.HmFood
		}
		w.War.HmFood -= loss
	}
	w.AddPlanExp(doGen, loss)
	return beGen.GeneralName + "中了" + doGen.GeneralName + "之计！烧毁了：" + itoaStr(loss) + "军粮"
}

// setTrapped 设置被困
func (w *World) setTrapped(generalID int, isPlayer bool, days int) {
	if w.War == nil {
		return
	}
	units := w.War.AiUnits
	if isPlayer {
		units = w.War.HmUnits
	}
	for _, u := range units {
		if u.GenID == generalID {
			u.TrappedDay = days
			u.UnitState = entities.UnitTrapped
			return
		}
	}
}

// surroundingLoss 围杀损失
func (w *World) surroundingLoss(beGen *entities.General, surroundLoss int, isPlayer bool) int {
	if w.War == nil {
		return 0
	}
	// 找 beGen 所在单位
	var target *entities.Unit
	units := w.War.AiUnits
	if isPlayer {
		units = w.War.HmUnits
	}
	for _, u := range units {
		if u.GenID == beGen.GeneralId {
			target = u
			break
		}
	}
	if target == nil {
		return 0
	}
	adjUnits := w.War.HmUnits
	if isPlayer {
		adjUnits = w.War.AiUnits
	}
	total := 0
	for _, adjacent := range adjUnits {
		if adjacent.UnitState == entities.UnitCaptive {
			continue
		}
		if abs(adjacent.ArrayPosX-target.ArrayPosX)+abs(adjacent.ArrayPosY-target.ArrayPosY) == 1 {
			nearby := w.General(adjacent.GenID)
			if nearby == nil {
				continue
			}
			nearby.SubSoldiers(surroundLoss)
			total += surroundLoss
			if total > total+nearby.Soldiers {
				total = total + nearby.Soldiers
			}
		}
	}
	return total
}
