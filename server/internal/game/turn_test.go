package game

import (
	"testing"
)

// TestCheckGameEnd 验证胜负判定
func TestCheckGameEnd(t *testing.T) {
	w := newTestWorld(t)
	// 正常：多势力存活，玩家有城 -> false
	var pc int
	for _, c := range w.Countries {
		if c.CanBeChoose {
			pc = c.CountryId
			break
		}
	}
	if pc == 0 {
		t.Fatal("无可选势力")
	}
	w.GameInfo.PlayerCountryId = pc
	if w.CheckGameEnd() {
		t.Error("多势力存活时不应游戏结束")
	}
	if w.GameInfo.PlayingState == GameStateGAME_OVER || w.GameInfo.PlayingState == GameStateGAME_WIN {
		t.Error("不应进入结束态")
	}
}

// TestCheckGameEndNoCity 验证玩家无城=失败
func TestCheckGameEndNoCity(t *testing.T) {
	w := newTestWorld(t)
	// 建一个只有玩家一城的势力，清空其他
	for _, c := range w.Countries {
		if c.CanBeChoose {
			w.GameInfo.PlayerCountryId = c.CountryId
			c.CityIDs = nil // 玩家无城
			break
		}
	}
	if !w.CheckGameEnd() {
		t.Error("玩家无城时应游戏结束")
	}
	if w.GameInfo.PlayingState != GameStateGAME_OVER {
		t.Errorf("玩家无城状态应为 GAME_OVER，实际 %d", w.GameInfo.PlayingState)
	}
}

// TestGetEnemyAdjacentCityIDArray 验证邻敌城过滤（应不崩溃）
func TestGetEnemyAdjacentCityIDArray(t *testing.T) {
	w := newTestWorld(t)
	var pc int
	for _, c := range w.Countries {
		if c.CanBeChoose {
			pc = c.CountryId
			break
		}
	}
	enemies := w.GetEnemyAdjacentCityIDArray(pc)
	for _, eid := range enemies {
		if eid == 0 {
			t.Errorf("邻敌城不应为0")
		}
	}
	// 不存在的势力返回 nil
	if v := w.GetEnemyAdjacentCityIDArray(99999); v != nil {
		t.Errorf("不存在势力应返回 nil，实际 %v", v)
	}
}

// TestTransportBetweenCitys 验证输送
func TestTransportBetweenCitys(t *testing.T) {
	w := newTestWorld(t)
	from := w.City(1)
	to := w.City(2)
	if from == nil || to == nil {
		t.Skip("缺城池数据")
	}
	from.Money = 1000
	from.Grain = 1000
	fm, fg := from.Money, from.Grain
	tm, tg := to.Money, to.Grain
	w.TransportBetweenCitys(1, 2, 200, 100)
	if from.Money != fm-100 || from.Grain != fg-200 {
		t.Errorf("输出城资源应减少: money %d->%d grain %d->%d", fm, from.Money, fg, from.Grain)
	}
	if to.Money != tm+100 || to.Grain != tg+200 {
		t.Errorf("目标城资源应增加: money %d->%d grain %d->%d", tm, to.Money, tg, to.Grain)
	}
}

// TestAddMonth 验证月进位
func TestAddMonth(t *testing.T) {
	w := newTestWorld(t)
	w.GameInfo.Month = 12
	w.GameInfo.Years = 251
	w.AddMonth()
	if w.GameInfo.Month != 1 {
		t.Errorf("12月后应进位到1月，实际 %d", w.GameInfo.Month)
	}
	if w.GameInfo.Years != 252 {
		t.Errorf("年份应+1到252，实际 %d", w.GameInfo.Years)
	}
}

// TestDisasterLoss 验证灾损折算
func TestDisasterLoss(t *testing.T) {
	w := newTestWorld(t)
	// param/2 * fc / cap
	if v := w.disasterLoss(100, 50, 100); v != 50*50/100 {
		t.Errorf("disasterLoss(100,50,100) 应得 %d，实际 %d", 50*50/100, v)
	}
	if v := w.disasterLoss(0, 50, 100); v != 0 {
		t.Errorf("param=0 时应得0，实际 %d", v)
	}
}

// TestHandleTurmoil 验证骚乱各档位（应不崩溃且属性不增）
func TestHandleTurmoil(t *testing.T) {
	w := newTestWorld(t)
	for _, rule := range []int{10, 25, 70} {
		city := w.City(1)
		if city == nil {
			t.Skip("缺城池")
		}
		city.Rule = rule
		city.Population = 10000
		city.Money = 10000
		popBefore := city.Population
		w.handleTurmoil(city)
		if city.Population > popBefore {
			t.Errorf("rule=%d 骚乱后人口不应增加: %d -> %d", rule, popBefore, city.Population)
		}
		if city.Population < 0 {
			t.Errorf("rule=%d 骚乱后人口不应为负: %d", rule, city.Population)
		}
	}
}

// TestHandleNaturalDisaster 验证自然灾处理（应不崩溃）
func TestHandleNaturalDisaster(t *testing.T) {
	w := newTestWorld(t)
	city := w.City(1)
	if city == nil {
		t.Skip("缺城池")
	}
	city.Money = 1000
	city.Grain = 1000
	moneyBefore := city.Money
	w.handleNaturalDisaster(city)
	if city.Money > moneyBefore {
		t.Errorf("灾害后金钱不应增加: %d -> %d", moneyBefore, city.Money)
	}
	if city.Money < 0 {
		t.Errorf("灾害后金钱不应为负: %d", city.Money)
	}
}

// TestHandlePlague 验证瘟疫处理（应不崩溃）
func TestHandlePlague(t *testing.T) {
	w := newTestWorld(t)
	city := w.City(1)
	if city == nil {
		t.Skip("缺城池")
	}
	popBefore := city.Population
	w.handlePlague(city)
	if city.Population > popBefore {
		t.Errorf("瘟疫后人口不应增加: %d -> %d", popBefore, city.Population)
	}
	if city.Population < 0 {
		t.Errorf("瘟疫后人口不应为负: %d", city.Population)
	}
}

// TestNaturalDisasterRate 验证自然灾概率函数（应返回 bool 且不崩溃）
func TestNaturalDisasterRate(t *testing.T) {
	w := newTestWorld(t)
	city := w.City(1)
	if city == nil {
		t.Skip("缺城池")
	}
	// 多跑几次验证不崩溃
	for i := 0; i < 20; i++ {
		_ = w.naturalDisasterRate(city)
	}
}
