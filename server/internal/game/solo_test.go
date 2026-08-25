package game

import (
	"testing"

	"3k-server/internal/game/entities"
)

// newGeneral 构造一个指定武力的测试武将
func newGeneral(force int) *entities.General {
	return &entities.General{GeneralId: 1, Force: force, Level: 1, Health: 100, MaxHealth: 100, Arm: 1, Armor: 1}
}

// TestGeneralAtkValue 验证单挑攻值公式与钳制
func TestGeneralAtkValue(t *testing.T) {
	// 普通：Force=100, atkPower=100, defPower=100 -> 100*100/100=100, 不超上下限, +20% = 120
	g := newGeneral(100)
	if v := GeneralAtkValue(g, 100, 100); v != 120 {
		t.Errorf("GeneralAtkValue(100,100,100) 应得 120，实际 %d", v)
	}
	// atkPower 极大：应被钳制到 2*Force, 再 +20% = 240
	if v := GeneralAtkValue(g, 10000, 1); v != 240 {
		t.Errorf("atkPower 极大应钳制到 240，实际 %d", v)
	}
	// defPower=0 防除零：defPower 提升为 1
	if v := GeneralAtkValue(g, 100, 0); v <= 0 {
		t.Errorf("defPower=0 不应除零崩溃，实际 %d", v)
	}
	// atkPower 极小：应钳制到 Force/3, 再 +20%
	g2 := newGeneral(90)
	if v := GeneralAtkValue(g2, 1, 1000); v != 90/3+90/3/5 {
		t.Errorf("atkPower 极小应钳制到 Force/3，实际 %d", v)
	}
}

// TestGetAtkDea 验证单次攻击伤害（下限1）
func TestGetAtkDea(t *testing.T) {
	g := newGeneral(100)
	if v := GetAtkDea(g, 100, 100); v != GeneralAtkValue(g, 100, 100)/8 {
		t.Errorf("GetAtkDea 应等于 攻值/8，实际 %d", v)
	}
	// 极小攻值 -> 伤害下限 1
	g2 := newGeneral(3)
	if v := GetAtkDea(g2, 1, 10000); v < 1 {
		t.Errorf("GetAtkDea 下限应为 1，实际 %d", v)
	}
}

// TestGetAllAtkDea 验证全力攻击伤害
func TestGetAllAtkDea(t *testing.T) {
	g := newGeneral(100)
	if v := GetAllAtkDea(g, 100, 100); v != GeneralAtkValue(g, 100, 100)/2 {
		t.Errorf("GetAllAtkDea 应等于 攻值/2，实际 %d", v)
	}
	// 下限 1
	g2 := newGeneral(3)
	if v := GetAllAtkDea(g2, 1, 10000); v < 1 {
		t.Errorf("GetAllAtkDea 下限应为 1，实际 %d", v)
	}
}

// TestWeaponEffect 验证武器效果修正
func TestWeaponEffect(t *testing.T) {
	atk := newGeneral(50)
	def := newGeneral(50)

	cases := []struct {
		name      string
		atkArm    int
		defArmor  int
		sc        int
		whack     bool
		expect    int
	}{
		{"无特武无修正", 1, 1, 50, false, 50},
		{"a==5 且 whack +20", 5, 1, 50, true, 70},
		{"a==6 非 whack +15", 6, 1, 50, false, 65},
		{"a==7 非 whack +15", 7, 1, 50, false, 65},
		{"a==14 非 whack +15", 14, 1, 50, false, 65},
		{"b==30 非 whack -15", 1, 30, 50, false, 35},
		{"b==31 非 whack -20", 1, 31, 50, false, 30},
		{"b==31 whack 归0", 1, 31, 50, true, 0},
		{"a==5 whack 但 b==31 归0", 5, 31, 50, true, 0}, // whack 时 a==5 先 +20，再 b==31 置 0
	}
	for _, tc := range cases {
		atk.Arm = tc.atkArm
		def.Armor = tc.defArmor
		if v := WeaponEffect(atk, def, tc.sc, tc.whack); v != tc.expect {
			t.Errorf("%s: 应得 %d，实际 %d", tc.name, tc.expect, v)
		}
	}
}

// TestGetPercentage 验证武器命中率（构造武器字典，避免数据武器带额外效果）
func TestGetPercentage(t *testing.T) {
	w := newTestWorld(t)
	// 手工注入三种 kind 的武器（Arm ID 避开 WeaponEffect 特武 5/6/7/14，Armor 避开 30/31）
	w.Weapons[100] = &entities.Weapon{WeaponID: 100, Kind: 0}
	w.Weapons[101] = &entities.Weapon{WeaponID: 101, Kind: 1}
	w.Weapons[102] = &entities.Weapon{WeaponID: 102, Kind: 2}

	atk := newGeneral(70)
	def := newGeneral(70)
	// kind0 vs kind0 -> 70
	atk.Arm = 100
	def.Arm = 100
	if v := w.GetPercentage(atk, def, false, false); v != 70 {
		t.Errorf("kind0 vs kind0 命中率应 70，实际 %d", v)
	}
	// kind0 vs kind1 -> 75
	atk.Arm = 100
	def.Arm = 101
	if v := w.GetPercentage(atk, def, false, false); v != 75 {
		t.Errorf("kind0 vs kind1 命中率应 75，实际 %d", v)
	}
	// kind1 vs kind0 -> 55
	atk.Arm = 101
	def.Arm = 100
	if v := w.GetPercentage(atk, def, false, false); v != 55 {
		t.Errorf("kind1 vs kind0 命中率应 55，实际 %d", v)
	}
	// kind2 vs kind0 -> 80
	atk.Arm = 102
	def.Arm = 100
	if v := w.GetPercentage(atk, def, false, false); v != 80 {
		t.Errorf("kind2 vs kind0 命中率应 80，实际 %d", v)
	}
	// whack=true 时命中率减半且被钳制到 [0,100]
	atk.Arm = 100
	def.Arm = 101
	if v := w.GetPercentage(atk, def, true, false); v < 0 || v > 100 {
		t.Errorf("whack 命中率应在 [0,100]，实际 %d", v)
	}
	// hmAtk 时命中率 -20
	atk.Arm = 100
	def.Arm = 100
	if v := w.GetPercentage(atk, def, false, true); v != 50 {
		t.Errorf("hmAtk 时 kind0 vs kind0 命中率应 50，实际 %d", v)
	}
}

// TestPersuadeBoundary 验证招降边界（忠诚>99 直接失败）
func TestPersuadeBoundary(t *testing.T) {
	w := newTestWorld(t)
	doGen := newGeneral(80)
	doGen.Charm = 90
	doGen.Wisdom = 90
	beGen := newGeneral(80)
	beGen.Loyalty = 100
	if w.Persuade(doGen, beGen) {
		t.Error("忠诚>99 时不应招降成功")
	}
	if w.AiPersuade(doGen, beGen) {
		t.Error("忠诚>99 时不应招降成功")
	}
}

// TestSingleAtk 验证单挑攻击返回非负伤害
func TestSingleAtk(t *testing.T) {
	w := newTestWorld(t)
	atk := newGeneral(90)
	def := newGeneral(80)
	// 固定多跑几次，伤害应为非负
	for i := 0; i < 50; i++ {
		d := w.SingleAtk(atk, def, 100, 100, true)
		if d < 0 {
			t.Fatalf("单挑伤害不应为负，实际 %d", d)
		}
	}
}
