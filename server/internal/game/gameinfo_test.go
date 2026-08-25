package game

import "testing"

// TestGameInfoReset 验证状态重置
func TestGameInfoReset(t *testing.T) {
	g := &GameInfoState{
		Years: 999, Month: 12, PlayerCountryId: 5, PlayerOrderNum: 8,
		PlayingState: GameStatePLAYING, DoCityId: 3,
	}
	g.Reset()
	if g.Years != 251 || g.Month != 1 {
		t.Errorf("重置后应为 251/1，实际 %d/%d", g.Years, g.Month)
	}
	if g.PlayerCountryId != 0 || g.PlayerOrderNum != 0 {
		t.Error("重置后玩家势力与命令数应为0")
	}
	if g.PlayingState != GameStateNONE {
		t.Errorf("重置后状态应为 NONE，实际 %d", g.PlayingState)
	}
	if g.DoCityId != 0 || g.Task != TaskNONE {
		t.Error("重置后 DoCityId 与 Task 应归零")
	}
}

// TestGetPlayerOrderNum 验证按城数分档
func TestGetPlayerOrderNum(t *testing.T) {
	w := newTestWorld(t)
	// 取一个真实势力并设置城数
	for _, c := range w.Countries {
		w.GameInfo.PlayerCountryId = c.CountryId
		// 城数 <3
		c.CityIDs = []int{1}
		if v := w.GameInfo.GetPlayerOrderNum(w); v != 3 {
			t.Errorf("城数<3 应得3，实际 %d", v)
		}
		// 城数4
		c.CityIDs = []int{1, 2, 3, 4}
		if v := w.GameInfo.GetPlayerOrderNum(w); v != 4 {
			t.Errorf("城数4 应得4，实际 %d", v)
		}
		// 城数7
		c.CityIDs = []int{1, 2, 3, 4, 5, 6, 7}
		if v := w.GameInfo.GetPlayerOrderNum(w); v != 6 {
			t.Errorf("城数7 应得6，实际 %d", v)
		}
		// 城数10
		c.CityIDs = []int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
		if v := w.GameInfo.GetPlayerOrderNum(w); v != 7 {
			t.Errorf("城数10 应得7，实际 %d", v)
		}
		// 城数11
		c.CityIDs = []int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}
		if v := w.GameInfo.GetPlayerOrderNum(w); v != 8 {
			t.Errorf("城数>10 应得8，实际 %d", v)
		}
		// 无势力（PlayerCountryId 无效）返回3
		w.GameInfo.PlayerCountryId = 99999
		if v := w.GameInfo.GetPlayerOrderNum(w); v != 3 {
			t.Errorf("无势力应返回3，实际 %d", v)
		}
		break
	}
}

// TestSubPlayerOrder 验证命令数递减
func TestSubPlayerOrder(t *testing.T) {
	g := &GameInfoState{PlayerOrderNum: 3}
	// 3 -> 2 不返回true
	if g.SubPlayerOrder() {
		t.Error("3->2 不应返回true")
	}
	if g.PlayerOrderNum != 2 {
		t.Errorf("命令数应为2，实际 %d", g.PlayerOrderNum)
	}
	// 2 -> 1
	g.SubPlayerOrder()
	// 1 -> 0 返回true
	if !g.SubPlayerOrder() {
		t.Error("1->0 应返回true")
	}
	// 已是0：不再递减
	if g.SubPlayerOrder() {
		t.Error("命令数为0后不应返回true")
	}
	// 越界值归0
	g2 := &GameInfoState{PlayerOrderNum: 99}
	g2.SubPlayerOrder()
	if g2.PlayerOrderNum != 0 {
		t.Errorf("越界命令数应归0，实际 %d", g2.PlayerOrderNum)
	}
}
