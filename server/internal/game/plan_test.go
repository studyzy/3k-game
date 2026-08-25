package game

import (
	"testing"

	"3k-server/internal/game/entities"
)

// newGeneralFull 构造带五维的武将
func newGeneralFull(id, lead, force, wisdom, govern, charm int) *entities.General {
	return &entities.General{
		GeneralId: id, Lead: lead, Force: force, Wisdom: wisdom,
		Govern: govern, Charm: charm, Level: 1, Health: 100, MaxHealth: 100,
		Soldiers: 1000, Loyalty: 90,
	}
}

// setSkill1 设置武将 skill1 组的第 index 位技能（index 1~10）
func setSkill1(g *entities.General, index int) {
	if len(g.Skills) < 1 {
		g.Skills = make([]int, 5)
	}
	g.Skills[0] |= 1 << (10 - index)
}

// TestPlanRef 验证计策定义表
func TestPlanRef(t *testing.T) {
	for i := 0; i < 16; i++ {
		if PlanRef(i) == nil {
			t.Errorf("计策 %d 应为有效定义", i)
		}
	}
	if PlanRef(-1) != nil {
		t.Error("越界计策应返回 nil")
	}
	if PlanRef(16) != nil {
		t.Error("越界计策应返回 nil")
	}
	if PlanRef(0).Name != "火攻" {
		t.Errorf("计策0应为火攻，实际 %s", PlanRef(0).Name)
	}
}

// TestBaseRate 验证基础成功率随智力单调
func TestBaseRate(t *testing.T) {
	w := newTestWorld(t)
	hi := newGeneralFull(1, 60, 60, 95, 60, 60)  // 高智
	lo := newGeneralFull(2, 60, 60, 50, 60, 60)  // 低智
	be := newGeneralFull(3, 60, 60, 70, 60, 60)
	rHi := w.BaseRate(hi, be, 40.0, -0.2, -0.05, 0)
	rLo := w.BaseRate(lo, be, 40.0, -0.2, -0.05, 0)
	if rHi < rLo {
		t.Errorf("高智成功率应高于低智: hi=%d lo=%d", rHi, rLo)
	}
	// 结果应在合理区间
	if rHi < 0 || rHi > 100 {
		t.Errorf("成功率应在 [0,100]，实际 %d", rHi)
	}
}

// TestRateEnhanceWeaken 验证神算/冷静修正
func TestRateEnhanceWeaken(t *testing.T) {
	w := newTestWorld(t)
	// 无技能：不修正
	plain := newGeneralFull(1, 60, 60, 60, 60, 60)
	if w.RateEnhance(plain, 40) != 40 {
		t.Error("无技能不应增强成功率")
	}
	// 神算 +1/5
	shen := newGeneralFull(2, 60, 60, 60, 60, 60)
	setSkill1(shen, 5)
	if v := w.RateEnhance(shen, 100); v != 120 {
		t.Errorf("神算增强 100/5 应得 120，实际 %d", v)
	}
	// 诸葛亮神算 +1/4（最低+15）
	zg := newGeneralFull(3, 60, 60, 60, 60, 60)
	zg.GeneralName = "诸葛亮"
	setSkill1(zg, 5)
	if v := w.RateEnhance(zg, 40); v != 55 {
		t.Errorf("诸葛亮神算 40+15(最低+15) 应得 55，实际 %d", v)
	}
	// 冷静减半
	cool := newGeneralFull(4, 60, 60, 60, 60, 60)
	setSkill1(cool, 0)
	if v := w.RateWeaken(cool, 100); v != 50 {
		t.Errorf("冷静应减半得 50，实际 %d", v)
	}
}

// TestResultEnhance 验证军师 1.5 倍
func TestResultEnhance(t *testing.T) {
	w := newTestWorld(t)
	plain := newGeneralFull(1, 60, 60, 60, 60, 60)
	if w.ResultEnhance(plain, 100) != 100 {
		t.Error("无军师不应增强效果")
	}
	junshi := newGeneralFull(2, 60, 60, 60, 60, 60)
	setSkill1(junshi, 3)
	if v := w.ResultEnhance(junshi, 100); v != 150 {
		t.Errorf("军师 1.5 倍应得 150，实际 %d", v)
	}
}

// TestIqDamage 验证智力差伤害
func TestIqDamage(t *testing.T) {
	w := newTestWorld(t)
	hi := newGeneralFull(1, 60, 60, 95, 60, 60)
	lo := newGeneralFull(2, 60, 60, 50, 60, 60)
	// 智差为正：伤害 >= base
	if v := w.IqDamage(hi, lo, 250, 2); v < 250 {
		t.Errorf("智差为正时伤害应>=base 250，实际 %d", v)
	}
	// 智差为负：伤害可能 < base
	if v := w.IqDamage(lo, hi, 250, 2); v > 250 {
		t.Errorf("智差为负时伤害应<=base 250，实际 %d", v)
	}
}

// TestPlanRate 验证各计策成功率在 [0,99]
func TestPlanRate(t *testing.T) {
	w := newTestWorld(t)
	doGen := newGeneralFull(1, 80, 80, 90, 70, 70)
	beGen := newGeneralFull(2, 80, 80, 70, 70, 70)
	for i := 0; i < 16; i++ {
		plan := PlanRef(i)
		r := w.PlanRate(plan, doGen, beGen)
		if r < 0 || r > 99 {
			t.Errorf("计策 %s 成功率应在 [0,99]，实际 %d", plan.Name, r)
		}
	}
	// 奇门遁甲固定 99
	if v := w.PlanRate(PlanRef(15), doGen, beGen); v != 99 {
		t.Errorf("奇门遁甲成功率应 99，实际 %d", v)
	}
}

// TestExecPlanFire 验证火攻执行（扣士兵）
func TestExecPlanFire(t *testing.T) {
	w := newTestWorld(t)
	doGen := newGeneralFull(1, 80, 80, 90, 70, 70)
	beGen := newGeneralFull(2, 80, 80, 70, 70, 70)
	beGen.Soldiers = 2000
	res := w.ExecPlan(PlanRef(0), doGen, beGen, true)
	if res == "" {
		t.Fatal("火攻无结果文本")
	}
	if beGen.Soldiers >= 2000 {
		t.Errorf("火攻后士兵应减少: %d", beGen.Soldiers)
	}
}

// TestExecPlanTrap 验证陷阱执行（扣体力）
func TestExecPlanTrap(t *testing.T) {
	w := newTestWorld(t)
	doGen := newGeneralFull(1, 80, 80, 90, 70, 70)
	beGen := newGeneralFull(2, 80, 80, 70, 70, 70)
	beGen.Health = 80
	res := w.ExecPlan(PlanRef(1), doGen, beGen, true)
	if res == "" {
		t.Fatal("陷阱无结果文本")
	}
	if beGen.Health >= 80 {
		t.Errorf("陷阱后体力应减少: %d", beGen.Health)
	}
}

// TestExecPlanJieLiang 验证劫粮（需战争状态）
func TestExecPlanJieLiang(t *testing.T) {
	w := newTestWorld(t)
	doGen := newGeneralFull(1, 80, 80, 90, 70, 70)
	beGen := newGeneralFull(2, 80, 80, 70, 70, 70)
	// 无战争时劫粮返回"未在战争中"
	res := w.ExecPlan(PlanRef(5), doGen, beGen, true)
	if res != "未在战争中" {
		t.Errorf("无战争劫粮应返回'未在战争中'，实际 %s", res)
	}
}
