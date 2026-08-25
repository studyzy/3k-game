package entities

import "testing"

// fakeWeaponProvider 测试用武器提供者
type fakeWeaponProvider struct {
	props map[int]int
}

func (f *fakeWeaponProvider) Weapon(id int) *Weapon {
	if p, ok := f.props[id]; ok {
		return &Weapon{WeaponID: id, Property: p}
	}
	return nil
}

// TestGeneralAttackDefend 验证攻防公式
func TestGeneralAttackDefend(t *testing.T) {
	g := &General{Force: 90, Level: 5, Arm: 1, Armor: 2}
	// 无武器：wp=0，攻防 = 90 * (19+5)/20 = 90*24/20 = 108
	if v := g.GetAttackPower(nil); v != 108 {
		t.Errorf("无武器攻击力应 108，实际 %d", v)
	}
	// 有武器：property=50 -> 90*1.5*24/20 = 162
	fp := &fakeWeaponProvider{props: map[int]int{1: 50, 2: 30}}
	if v := g.GetAttackPower(fp); v != 162 {
		t.Errorf("有武器攻击力应 162，实际 %d", v)
	}
	// 防具 property=30 -> 90*1.3*24/20 = 140
	if v := g.GetDefendPower(fp); v != 140 {
		t.Errorf("有防具防御力应 140，实际 %d", v)
	}
}

// TestGetMaxSoldierNum 验证带兵上限
func TestGetMaxSoldierNum(t *testing.T) {
	// 普通公式：1000 + 12*lead + 100*level
	g := &General{Lead: 50, Level: 1}
	if v := g.GetMaxSoldierNum(); v != 1000+12*50+100 {
		t.Errorf("带兵上限应 %d，实际 %d", 1000+600+100, v)
	}
	// 超高 lead：钳制到3000
	g2 := &General{Lead: 200, Level: 10}
	if v := g2.GetMaxSoldierNum(); v != 3000 {
		t.Errorf("超高 lead 应钳制到3000，实际 %d", v)
	}
	// 一骑特技：锁3000
	g3 := &General{Lead: 10, Level: 1, Skills: make([]int, 5)}
	g3.Skills[4] |= 1 << 10 // HasSkill5(0)
	if v := g3.GetMaxSoldierNum(); v != 3000 {
		t.Errorf("一骑应锁3000，实际 %d", v)
	}
}

// TestSetSoldiers 验证带兵钳制
func TestSetSoldiers(t *testing.T) {
	g := &General{Lead: 50, Level: 1}
	max := g.GetMaxSoldierNum()
	g.SetSoldiers(-100)
	if g.Soldiers != 0 {
		t.Errorf("负数应钳制到0，实际 %d", g.Soldiers)
	}
	g.SetSoldiers(max + 1000)
	if g.Soldiers != max {
		t.Errorf("超上限应钳制到 %d，实际 %d", max, g.Soldiers)
	}
	g.SetSoldiers(500)
	if g.Soldiers != 500 {
		t.Errorf("区间内应保留原值，实际 %d", g.Soldiers)
	}
	// SubSoldiers 不跌破0
	g.SetSoldiers(100)
	g.SubSoldiers(500)
	if g.Soldiers != 0 {
		t.Errorf("SubSoldiers 不应低于0，实际 %d", g.Soldiers)
	}
}

// TestGetSalary 验证薪水
func TestGetSalary(t *testing.T) {
	if (&General{Level: 1}).GetSalary() != 3 {
		t.Error("level1 薪水应为3")
	}
	if (&General{Level: 5}).GetSalary() != 11 {
		t.Error("level5 薪水应为11")
	}
}

// TestLoyalty 验证忠诚钳制
func TestLoyalty(t *testing.T) {
	g := &General{GeneralId: 1}
	g.SetLoyalty(-10)
	if g.Loyalty != 0 {
		t.Errorf("负数忠诚应钳制到0，实际 %d", g.Loyalty)
	}
	g.SetLoyalty(150)
	if g.Loyalty != 100 {
		t.Errorf("超限忠诚应钳制到100，实际 %d", g.Loyalty)
	}
	g.SetLoyalty(80)
	g.SubLoyalty(20)
	if g.Loyalty != 60 {
		t.Errorf("忠诚应60，实际 %d", g.Loyalty)
	}
	// AddLoyalty：君主封顶100，其余99
	g.SetLoyalty(95)
	g.AddLoyalty(g.GeneralId, 50) // 是君主 -> 100
	if g.Loyalty != 100 {
		t.Errorf("君主忠诚应封顶100，实际 %d", g.Loyalty)
	}
	g.SetLoyalty(95)
	g.AddLoyalty(999, 50) // 非君主 -> 99
	if g.Loyalty != 99 {
		t.Errorf("非君主忠诚应封顶99，实际 %d", g.Loyalty)
	}
}

// TestHp 验证体力钳制
func TestHp(t *testing.T) {
	g := &General{Health: 50, MaxHealth: 100}
	g.SetHp(-5)
	if g.Health != 0 {
		t.Errorf("负数体力应钳制到0，实际 %d", g.Health)
	}
	g.SetHp(200)
	if g.Health != 100 {
		t.Errorf("超限体力应钳制到100，实际 %d", g.Health)
	}
	g.SetHp(80)
	if delta := g.AddHp(30); delta != 20 {
		t.Errorf("AddHp 实际增量应为20，实际 %d", delta)
	}
	if g.Health != 100 {
		t.Errorf("AddHp 后体力应为100，实际 %d", g.Health)
	}
	// SubHp 归零
	g.SetHp(50)
	if !g.SubHp(100) {
		t.Error("SubHp 大额应返回 true（归零）")
	}
	if g.Health != 0 {
		t.Errorf("SubHp 后体力应为0，实际 %d", g.Health)
	}
}

// TestGetPlanNum 验证计策数档位
func TestGetPlanNum(t *testing.T) {
	cases := []struct {
		wisdom, level, expect int
	}{
		{100, 8, 16},
		{95, 7, 15},
		{93, 5, 14},
		{90, 4, 12},
		{85, 1, 10},
		{80, 1, 8},
		{60, 1, 6},
		{39, 1, 2},
		{30, 1, 2},
		{50, 1, 4},
		{55, 1, 4},
	}
	for _, tc := range cases {
		g := &General{Wisdom: tc.wisdom, Level: tc.level}
		if v := g.GetPlanNum(); v != tc.expect {
			t.Errorf("GetPlanNum(智%d级%d) 应得 %d，实际 %d", tc.wisdom, tc.level, tc.expect, v)
		}
	}
}

// TestGetArmyS 验证适性字符串
func TestGetArmyS(t *testing.T) {
	g := &General{Army: []int{0, 1, 2}}
	if v := g.GetArmyS(); v != "平C山B水A" {
		t.Errorf("适性应得'平C山B水A'，实际 %s", v)
	}
	// 越界钳制：负->C 超->S
	g2 := &General{Army: []int{-1, 99, 1}}
	if v := g2.GetArmyS(); v != "平C山S水B" {
		t.Errorf("越界适性钳制应得'平C山S水B'，实际 %s", v)
	}
}

// TestGetActiveSkills 验证激活技能
func TestGetActiveSkills(t *testing.T) {
	names := []string{"a", "b", "c", "d", "e", "f", "g", "h", "i", "j"}
	g := &General{Skills: []int{0, 0, 0, 0, 0}}
	// 设置第1组的第1位(index1)技能，即 bit 9
	g.Skills[0] |= 1 << (10 - 1)
	active := g.GetActiveSkills(names)
	if len(active) != 1 || active[0] != "b" {
		t.Errorf("应激活技能'b'，实际 %v", active)
	}
	// 空技能返回空
	if v := (&General{Skills: []int{0, 0, 0, 0, 0}}).GetActiveSkills(names); len(v) != 0 {
		t.Errorf("空技能应返回空，实际 %v", v)
	}
}

// TestAddExperience 验证经验升级
func TestAddExperience(t *testing.T) {
	g := &General{Level: 1, Experience: 0, MaxHealth: 100}
	g.Health = 50
	need := g.GetMaxExp() // 6000
	g.AddExperience(need)
	if g.Level != 2 {
		t.Errorf("经验满应升到2级，实际 %d", g.Level)
	}
	if g.Experience != 0 {
		t.Errorf("升到2级后经验应归0，实际 %d", g.Experience)
	}
	// 经验回满（generalUpgrade 设置 Health=MaxHealth）
	if g.Health != g.MaxHealth {
		t.Errorf("升级后体力应回满，实际 %d", g.Health)
	}
	// 负经验无效果
	g2 := &General{Level: 1, Experience: 100}
	g2.AddExperience(-50)
	if g2.Experience != 100 || g2.Level != 1 {
		t.Error("负经验不应改变状态")
	}
}

// TestAllStatus 验证五维总和
func TestAllStatus(t *testing.T) {
	g := &General{Lead: 80, Govern: 70, Force: 60, Charm: 50, Wisdom: 40}
	if v := g.AllStatus(); v != 300 {
		t.Errorf("五维总和应300，实际 %d", v)
	}
}

// TestHasSkill 验证技能位判断
func TestHasSkill(t *testing.T) {
	g := &General{Skills: []int{1 << 8, 0, 0, 0, 0}}
	// 第1组 index2 (1<<8)
	if !g.HasSkill1(2) {
		t.Error("index2 技能应为 true")
	}
	if g.HasSkill1(1) {
		t.Error("index1 技能应为 false")
	}
	if g.HasSkill(0, 0) {
		t.Error("kind=0 应返回 false")
	}
	if g.HasSkill(6, 1) {
		t.Error("kind 越界应返回 false")
	}
}
