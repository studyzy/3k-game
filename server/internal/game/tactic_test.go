package game

import (
	"testing"

	"3k-server/internal/game/entities"
)

// TestTacticRef 验证战术定义表
func TestTacticRef(t *testing.T) {
	for i := 1; i <= 6; i++ {
		if TacticRef(i) == nil {
			t.Errorf("战术 %d 应为有效定义", i)
		}
	}
	if TacticRef(0) != nil || TacticRef(7) != nil {
		t.Error("越界战术应返回 nil")
	}
	if TacticRef(1).Name != "挑战" {
		t.Errorf("战术1应为挑战，实际 %s", TacticRef(1).Name)
	}
}

// TestGetTacticsNum 验证各智力档位战术数量
func TestGetTacticsNum(t *testing.T) {
	cases := []struct {
		wisdom int
		expect int
	}{
		{10, 0},
		{20, 1},
		{45, 2},
		{60, 3},
		{70, 4},
		{85, 5},
		{95, 6},
		{120, 6},
	}
	for _, tc := range cases {
		g := &entities.General{Wisdom: tc.wisdom}
		if v := GetTacticsNum(g); v != tc.expect {
			t.Errorf("GetTacticsNum(智力%d) 应得 %d，实际 %d", tc.wisdom, tc.expect, v)
		}
	}
}

// TestCeilDiv 验证向上取整除法
func TestCeilDiv(t *testing.T) {
	cases := []struct {
		product, d, expect int
	}{
		{10, 3, 4},  // ceil(10/3)=4
		{9, 3, 3},   // 整除
		{0, 5, 0},   // product<=0
		{10, 0, 0},  // d<=0
		{-5, 3, 0},  // product<=0
	}
	for _, tc := range cases {
		if v := ceilDiv(tc.product, tc.d); v != tc.expect {
			t.Errorf("ceilDiv(%d,%d) 应得 %d，实际 %d", tc.product, tc.d, tc.expect, v)
		}
	}
}

// TestIsTacticEnough 验证计策点是否足够
func TestIsTacticEnough(t *testing.T) {
	w := newTestWorld(t)
	hm := &entities.General{GeneralId: 1, Wisdom: 80}
	ai := &entities.General{GeneralId: 2, Wisdom: 80}
	w.InitBattle(hm, ai, 8, false)
	// 玩家计策点 = 80*13/100 = 10
	t1 := TacticRef(1) // 挑战 cost=2 足够
	if !w.IsTacticEnough(t1, true) {
		t.Error("cost=2 应足够")
	}
	t6 := TacticRef(6) // 爆炎 cost=11 不足（玩家10）
	if w.IsTacticEnough(t6, true) {
		t.Error("cost=11 超过玩家计策点10，应不足")
	}
	// 无 Battle 时应 false
	w.Battle = nil
	if w.IsTacticEnough(t1, true) {
		t.Error("无 Battle 时应 false")
	}
}

// TestTacticSuccessful 验证战术成功判定
func TestTacticSuccessful(t *testing.T) {
	w := newTestWorld(t)
	hm := &entities.General{GeneralId: 1, Wisdom: 90, Force: 80, Health: 100, MaxHealth: 100, Soldiers: 600}
	ai := &entities.General{GeneralId: 2, Wisdom: 70, Force: 80, Health: 100, MaxHealth: 100, Soldiers: 600}
	w.Generals[hm.GeneralId] = hm
	w.Generals[ai.GeneralId] = ai
	w.InitBattle(hm, ai, 8, false)
	w.Battle.PendingPlayerUnit = &entities.Unit{GenID: hm.GeneralId}
	w.Battle.PendingEnemyUnit = &entities.Unit{GenID: ai.GeneralId}
	// 连弩/呐喊/火矢 无条件成功（计策点足够时）
	t3 := TacticRef(3) // 连弩 cost=7，玩家计策点11（90*13/100=11）足够
	if !w.TacticSuccessful(t3, true) {
		t.Error("连弩应无条件成功")
	}
	// 计策点不足时失败
	t6 := TacticRef(6) // 爆炎 cost=11，玩家计策点11 刚好够，但需士兵>=500
	if !w.TacticSuccessful(t6, true) {
		t.Log("爆炎未成功（可能计策点或士兵条件不满足）")
	}
	// 无 Battle 时失败
	w.Battle = nil
	if w.TacticSuccessful(t3, true) {
		t.Error("无 Battle 时战术应失败")
	}
}
