package game

import (
	"testing"
)

// setupWar 设置玩家势力并准备一场玩家攻城战争，返回 (World, 目标城ID)
func setupWar(t *testing.T, w *World) (int, int) {
	t.Helper()
	var pc int
	for _, c := range w.Countries {
		if c.CanBeChoose {
			pc = c.CountryId
			break
		}
	}
	if pc == 0 {
		t.Fatal("无可选君主势力")
	}
	w.GameInfo.PlayerCountryId = pc
	// 找一个相邻敌城
	enemies := w.GetEnemyAdjacentCityIDArray(pc)
	if len(enemies) == 0 {
		t.Skip("无邻敌城")
	}
	targetID := enemies[0]
	from := w.City(w.Country(pc).CityIDs[0])
	attackerIDs := from.GetOfficerIds()
	if len(attackerIDs) == 0 {
		t.Skip("玩家主城无武将")
	}
	w.WarPrepare(false, targetID, from.CityID, attackerIDs, 500, 300, pc)
	if w.War == nil {
		t.Fatal("WarPrepare 未创建战争")
	}
	return pc, targetID
}

// TestWarPrepareInit 验证战争初始化
func TestWarPrepareInit(t *testing.T) {
	w := newTestWorld(t)
	pc, targetID := setupWar(t, w)
	if w.War.CurWarCityId != targetID {
		t.Errorf("目标城应为 %d，实际 %d", targetID, w.War.CurWarCityId)
	}
	if len(w.War.HmUnits) == 0 {
		t.Error("我方应至少一个单位")
	}
	if len(w.War.AiUnits) == 0 {
		t.Error("敌方应至少一个单位")
	}
	if w.War.AttackerCountryId != pc {
		t.Errorf("攻击方势力应为 %d，实际 %d", pc, w.War.AttackerCountryId)
	}
	if w.War.Day != 1 {
		t.Errorf("起始天数应为1，实际 %d", w.War.Day)
	}
	// 攻防方向：玩家攻城 => IsHmDef=false
	if w.War.IsHmDef {
		t.Error("玩家攻城时 IsHmDef 应为 false")
	}
}

// TestFindCommander 验证主将识别（君主优先，否则首将）
func TestFindCommander(t *testing.T) {
	w := newTestWorld(t)
	// 构造两个 id：一个君主一个非君主
	var kingID, normalID int
	for _, c := range w.Countries {
		if c.CanBeChoose {
			kingID = c.CountryKingId
			break
		}
	}
	for id := range w.Generals {
		if id != kingID {
			normalID = id
			break
		}
	}
	// 含君主时主将为君主
	if v := findCommander(w, []int{normalID, kingID}); v != kingID {
		t.Errorf("含君主时主将应为 %d，实际 %d", kingID, v)
	}
	// 无君主时主将为首个
	if v := findCommander(w, []int{normalID}); v != normalID {
		t.Errorf("无君主时主将应为首个 %d，实际 %d", normalID, v)
	}
	// 空列表返回0
	if v := findCommander(w, nil); v != 0 {
		t.Errorf("空列表应返回0，实际 %d", v)
	}
}

// TestAssignStartPositions 验证初始站位（玩家左 AI 右）
func TestAssignStartPositions(t *testing.T) {
	w := newTestWorld(t)
	_, _ = setupWar(t, w)
	for _, u := range w.War.HmUnits {
		if u.ArrayPosX != 1 {
			t.Errorf("玩家单位 X 应为1，实际 %d", u.ArrayPosX)
		}
		if u.IsMoved {
			t.Error("初始不应已移动")
		}
	}
	for _, u := range w.War.AiUnits {
		if u.ArrayPosX != 30 {
			t.Errorf("AI 单位 X 应为30，实际 %d", u.ArrayPosX)
		}
	}
}

// TestCreateUnits 验证单位创建
func TestCreateUnits(t *testing.T) {
	w := newTestWorld(t)
	_, _ = setupWar(t, w)
	units := w.CreateUnits([]int{w.War.HmUnits[0].GenID}, true)
	if len(units) != 1 {
		t.Fatalf("应创建1个单位，实际 %d", len(units))
	}
	if units[0].IsPlayer != true {
		t.Error("玩家单位 IsPlayer 应为 true")
	}
	if units[0].MoveBonus <= 0 {
		t.Errorf("单位机动力应为正，实际 %d", units[0].MoveBonus)
	}
}

// TestSetMoveBonus 验证机动力按兵力设定
func TestSetMoveBonus(t *testing.T) {
	w := newTestWorld(t)
	_, _ = setupWar(t, w)
	u := w.War.HmUnits[0]
	before := u.MoveBonus
	w.SetMoveBonus(w.War.HmUnits)
	if u.MoveBonus < 7 || u.MoveBonus > 24 {
		t.Errorf("机动力应在 [7,24]，实际 %d", u.MoveBonus)
	}
	_ = before
}

// TestEatFoodEveryDay 验证每日耗粮
func TestEatFoodEveryDay(t *testing.T) {
	w := newTestWorld(t)
	_, _ = setupWar(t, w)
	// 计算期望耗粮
	total := 0
	for _, u := range w.War.HmUnits {
		if g := w.General(u.GenID); g != nil {
			total += g.Soldiers
		}
	}
	need := total / 250
	foodBefore := w.War.HmFood
	if w.EatFoodEveryDay() {
		if w.War.HmFood != foodBefore-need {
			t.Errorf("耗粮后粮食应为 %d，实际 %d", foodBefore-need, w.War.HmFood)
		}
	} else {
		// 粮食不足：触发撤退结算
		t.Log("粮食不足触发撤退")
	}
	// 极端：设粮食为0应返回 false
	w.War.HmFood = 0
	if w.EatFoodEveryDay() {
		t.Error("粮食为0时应返回 false（粮食不足）")
	}
}

// TestMoveUnitToCell 验证移动单位与地图标记
func TestMoveUnitToCell(t *testing.T) {
	w := newTestWorld(t)
	_, _ = setupWar(t, w)
	u := w.War.HmUnits[0]
	oldX, oldY := u.ArrayPosX, u.ArrayPosY
	// 移动到相邻格
	newPos := Pos{oldX + 1, oldY}
	w.MoveUnitToCell(u, newPos)
	if u.ArrayPosX != newPos.X || u.ArrayPosY != newPos.Y {
		t.Errorf("单位应移动到 %v，实际 (%d,%d)", newPos, u.ArrayPosX, u.ArrayPosY)
	}
	if !u.IsMoved {
		t.Error("移动后 IsMoved 应为 true")
	}
	// 新格地图标记玩家位(0x40)
	if v := w.War.WarMap[newPos.Y][newPos.X] & 0x40; v == 0 {
		t.Error("新格应标记玩家位(0x40)")
	}
	// 旧格标记应被清除
	if v := w.War.WarMap[oldY][oldX] & 0x40; v != 0 {
		t.Error("旧格玩家标记应被清除")
	}
}

// TestNextDay 验证天数推进
func TestNextDay(t *testing.T) {
	w := newTestWorld(t)
	_, _ = setupWar(t, w)
	dayBefore := w.War.Day
	// 给足粮食避免提前结束
	w.War.HmFood = 30000
	w.War.AiFood = 30000
	w.NextDay()
	if w.War.Day != dayBefore+1 {
		t.Errorf("天数应推进到 %d，实际 %d", dayBefore+1, w.War.Day)
	}
}

// TestFindAdjacentBattle 验证相邻交战探测（应不崩溃）
func TestFindAdjacentBattle(t *testing.T) {
	w := newTestWorld(t)
	_, _ = setupWar(t, w)
	// 无相邻单位时返回 nil,nil（玩家在x=1 AI在x=30）
	pu, eu := w.FindAdjacentBattle()
	if pu != nil || eu != nil {
		t.Errorf("玩家与AI不相邻时应返回 nil，实际 %v %v", pu, eu)
	}
	// 把两个单位放相邻位置
	w.War.HmUnits[0].ArrayPosX = 15
	w.War.HmUnits[0].ArrayPosY = 9
	w.War.AiUnits[0].ArrayPosX = 16
	w.War.AiUnits[0].ArrayPosY = 9
	pu, eu = w.FindAdjacentBattle()
	if pu == nil || eu == nil {
		t.Error("相邻时应探测到交战")
	}
}

// TestAfterWarSettlement 验证占领结算
func TestAfterWarSettlement(t *testing.T) {
	w := newTestWorld(t)
	pc, targetID := setupWar(t, w)
	city := w.City(targetID)
	beforeOwner := city.OwnerID
	if beforeOwner == 0 {
		t.Skip("目标城无主")
	}
	// 玩家方获胜（isHmWin=true，且玩家为攻方 IsHmDef=false）
	winUnits := len(w.War.HmUnits)
	_ = winUnits
	w.AfterWarSettlement(true, false)
	if city.OwnerID == beforeOwner {
		t.Errorf("占领后城主应变化：%d -> %d", beforeOwner, city.OwnerID)
	}
	// 玩家势力应拥有该城
	pcCountry := w.Country(pc)
	if !containsInt(pcCountry.CityIDs, targetID) {
		t.Error("玩家势力应拥有被占城")
	}
}

// TestAiUnitsTurn 验证 AI 行动（应不崩溃、不越界）
func TestAiUnitsTurn(t *testing.T) {
	w := newTestWorld(t)
	_, _ = setupWar(t, w)
	w.SetMoveBonus(w.War.AiUnits)
	w.AiUnitsTurn()
	for _, u := range w.War.AiUnits {
		if u.ArrayPosX < 0 || u.ArrayPosX >= 32 || u.ArrayPosY < 0 || u.ArrayPosY >= 19 {
			t.Errorf("AI 单位位置越界: (%d,%d)", u.ArrayPosX, u.ArrayPosY)
		}
	}
}

// TestExecThreaten 验证恐吓（应不崩溃）
func TestExecThreaten(t *testing.T) {
	w := newTestWorld(t)
	_, _ = setupWar(t, w)
	// 执行双方恐吓判定
	w.ExecThreaten(w.War.HmUnits, w.War.AiUnits)
	w.ExecThreaten(w.War.AiUnits, w.War.HmUnits)
	// 恐吓技能会扣减士兵，但不应导致负数（SetSoldiers 钳制）
	for _, u := range w.War.HmUnits {
		if g := w.General(u.GenID); g != nil && g.Soldiers < 0 {
			t.Errorf("恐吓后士兵不应为负: %d", g.Soldiers)
		}
	}
}
