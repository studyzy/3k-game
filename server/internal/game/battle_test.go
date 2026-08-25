package game

import (
	"testing"

	"3k-server/internal/game/entities"
)

// TestTerrainIndex 验证地形分类
func TestTerrainIndex(t *testing.T) {
	cases := []struct {
		terrain int
		expect  int
	}{
		{8, 3},  // 城战
		{9, 2},  // 水域
		{15, 2}, // 水域
		{10, 1}, // 山地
		{14, 1}, // 山地
		{2, 0},  // 平原
		{0, 0},  // 默认平原
	}
	for _, tc := range cases {
		if v := TerrainIndex(tc.terrain); v != tc.expect {
			t.Errorf("TerrainIndex(%d) 应得 %d，实际 %d", tc.terrain, tc.expect, v)
		}
	}
}

// TestGetTroopsNum 验证部队数公式
func TestGetTroopsNum(t *testing.T) {
	cases := []struct {
		soldiers int
		expect   int
	}{
		{0, 2},     // (0-1)/300+2 = 0+2 = 2
		{300, 2},   // (299)/300+2 = 0+2 = 2
		{600, 3},   // (599)/300+2 = 1+2 = 3
		{900, 4},   // (899)/300+2 = 2+2 = 4
		{3000, 11}, // (2999)/300+2 = 9+2 = 11
	}
	for _, tc := range cases {
		g := &entities.General{Soldiers: tc.soldiers}
		w := &World{}
		if v := w.GetTroopsNum(g); v != tc.expect {
			t.Errorf("GetTroopsNum(%d) 应得 %d，实际 %d", tc.soldiers, tc.expect, v)
		}
	}
}

// TestCreateTurnOrder 验证兵种序列
func TestCreateTurnOrder(t *testing.T) {
	w := newTestWorld(t)
	g := &entities.General{GeneralId: 1, Wisdom: 80, Soldiers: 900, Army: []int{0, 0, 0}}
	order := w.CreateTurnOrder(g, true)
	if len(order) == 0 {
		t.Fatal("兵种序列为空")
	}
	// 首元素为主将
	if order[0] != entities.TroopCaptain {
		t.Errorf("首元素应为主将 %d，实际 %d", entities.TroopCaptain, order[0])
	}
	// 非主将数应小于等于 GetTroopsNum-1（cai 比例可能舍入）
	if len(order) > w.GetTroopsNum(g) {
		t.Errorf("序列长度不应超过部队数 %d，实际 %d", w.GetTroopsNum(g), len(order))
	}
	// 士兵增多时序列不应变短
	g2 := &entities.General{GeneralId: 1, Wisdom: 80, Soldiers: 3000, Army: []int{0, 0, 0}}
	order2 := w.CreateTurnOrder(g2, true)
	if len(order2) < len(order) {
		t.Errorf("士兵增多后序列不应变短: %d -> %d", len(order), len(order2))
	}
}

// TestSidePower 验证单侧战力为正
func TestSidePower(t *testing.T) {
	w := newTestWorld(t)
	g := &entities.General{GeneralId: 1, Lead: 80, Force: 80, Wisdom: 80, Level: 5, Soldiers: 1000, Army: []int{0, 0, 0}}
	order := w.CreateTurnOrder(g, true)
	power := w.SidePower(g, order, 10, true)
	if power < 0 {
		t.Errorf("战力不应为负，实际 %d", power)
	}
}

// TestSimulatedBattle 验证自动战斗
func TestSimulatedBattle(t *testing.T) {
	w := newTestWorld(t)
	hm := &entities.General{GeneralId: 1, Lead: 90, Force: 90, Wisdom: 90, Level: 8, Soldiers: 3000, Army: []int{3, 3, 3}}
	ai := &entities.General{GeneralId: 2, Lead: 50, Force: 50, Wisdom: 50, Level: 1, Soldiers: 100, Army: []int{0, 0, 0}}
	hmWin := w.SimulatedBattle(hm, ai)
	if !hmWin {
		t.Error("战力悬殊时玩家应获胜")
	}
	if hm.Soldiers < 0 || hm.Soldiers > 3000 {
		t.Errorf("胜方余兵应在 [0,3000]，实际 %d", hm.Soldiers)
	}
	if ai.Soldiers != 0 {
		t.Errorf("败方士兵应归0，实际 %d", ai.Soldiers)
	}
}

// TestApplyTactic 验证应用战术
func TestApplyTactic(t *testing.T) {
	w := newTestWorld(t)
	hm := &entities.General{GeneralId: 1, Wisdom: 80}
	ai := &entities.General{GeneralId: 2, Wisdom: 80}
	w.InitBattle(hm, ai, 8, false)
	if w.Battle == nil {
		t.Fatal("InitBattle 未创建战斗")
	}
	if w.Battle.HmTacticPoint != 80*13/100 {
		t.Errorf("玩家计策点应 %d，实际 %d", 80*13/100, w.Battle.HmTacticPoint)
	}
	w.ApplyTactic("呐喊", true, 4)
	if len(w.Battle.ActiveTactics) != 1 {
		t.Errorf("战术列表应有1项，实际 %d", len(w.Battle.ActiveTactics))
	}
}

// TestMaxClampInt 验证工具函数
func TestMaxClampInt(t *testing.T) {
	if maxInt(3, 5) != 5 {
		t.Error("maxInt 应返回较大者")
	}
	if clampInt(5, 0, 10) != 5 {
		t.Error("clampInt 区间内应原样返回")
	}
	if clampInt(-1, 0, 10) != 0 {
		t.Error("clampInt 下限钳制失败")
	}
	if clampInt(11, 0, 10) != 10 {
		t.Error("clampInt 上限钳制失败")
	}
}
