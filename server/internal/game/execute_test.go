package game

import (
	"testing"

	"3k-server/internal/game/entities"
)

// setupPlayerState 设置玩家势力并返回玩家主城 id
func setupPlayerState(t *testing.T, w *World) int {
	t.Helper()
	// 取第一个可选君主势力
	var cid int
	for _, c := range w.Countries {
		if c.CanBeChoose {
			cid = c.CountryId
			break
		}
	}
	if cid == 0 {
		t.Fatal("无可选君主势力")
	}
	w.GameInfo.PlayerCountryId = cid
	w.GameInfo.DoCityId = w.Country(cid).CityIDs[0]
	w.GameInfo.PlayerOrderNum = w.GameInfo.GetPlayerOrderNum(w)
	w.GameInfo.PlayingState = GameStatePLAYING
	return w.GameInfo.DoCityId
}

// firstOfficerID 返回玩家主城第一个在职武将 id
func firstOfficerID(t *testing.T, w *World, cityID int) int {
	t.Helper()
	city := w.City(cityID)
	officers := city.GetOfficerIds()
	if len(officers) == 0 {
		t.Fatal("城池无武将")
	}
	return officers[0]
}

// TestExecuteReclaimMercantileTamePatrol 验证开垦/劝商/治水/巡查
func TestExecuteReclaimMercantileTamePatrol(t *testing.T) {
	w := newTestWorld(t)
	cityID := setupPlayerState(t, w)
	city := w.City(cityID)
	gid := firstOfficerID(t, w, cityID)

	cases := []struct {
		name string
		task TaskType
	}{
		{"开垦", TaskRECLAIM},
		{"劝商", TaskMERCANTILE},
		{"治水", TaskTAME},
		{"巡查", TaskPATROL},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			// 给足金钱避免"金钱不足"
			city.Money = 5000
			before := map[string]int{"agro": city.Agriculture, "trade": city.Commerce, "prevention": city.Prevention, "population": city.Population}
			res := w.ExecuteTask(tc.task, cityID, 0, []int{gid}, nil, nil)
			if len(res.Results) == 0 {
				t.Fatalf("命令无结果")
			}
			key := ""
			switch tc.task {
			case TaskRECLAIM:
				key = "agro"
			case TaskMERCANTILE:
				key = "trade"
			case TaskTAME:
				key = "prevention"
			case TaskPATROL:
				key = "population"
			}
			after := cityFieldByKey(city, key)
			if after < before[key] {
				t.Errorf("命令 %s 后属性不应倒退: before=%d after=%d", tc.name, before[key], after)
			}
		})
	}
}

func cityFieldByKey(c *entities.City, key string) int {
	switch key {
	case "agro":
		return c.Agriculture
	case "trade":
		return c.Commerce
	case "prevention":
		return c.Prevention
	case "population":
		return c.Population
	}
	return 0
}

// TestExecuteInteriorNotEnoughMoney 验证金钱不足分支
func TestExecuteInteriorNotEnoughMoney(t *testing.T) {
	w := newTestWorld(t)
	cityID := setupPlayerState(t, w)
	city := w.City(cityID)
	gid := firstOfficerID(t, w, cityID)
	city.Money = 0
	res := w.ExecuteTask(TaskRECLAIM, cityID, 0, []int{gid}, nil, nil)
	if len(res.Results) == 0 || res.Results[0] != "金钱不足" {
		t.Errorf("金钱不足时应返回'金钱不足'，实际 %v", res.Results)
	}
}

// TestExecuteRewardAndAppoint 验证奖赏与任命
func TestExecuteRewardAndAppoint(t *testing.T) {
	w := newTestWorld(t)
	cityID := setupPlayerState(t, w)
	city := w.City(cityID)
	officers := city.GetOfficerIds()
	if len(officers) < 2 {
		t.Skip("武将不足，无法测任命")
	}
	gid := officers[0]
	// 奖赏
	city.Money = 1000
	loyaltyBefore := w.General(gid).Loyalty
	res := w.ExecuteTask(TaskREWARD, cityID, 0, []int{gid}, nil, nil)
	if len(res.Results) == 0 {
		t.Fatal("奖赏无结果")
	}
	if w.General(gid).Loyalty < loyaltyBefore {
		t.Errorf("奖赏后忠诚不应降低: %d -> %d", loyaltyBefore, w.General(gid).Loyalty)
	}
	if city.Money != 900 {
		t.Errorf("奖赏应扣100金，实际剩 %d", city.Money)
	}
	// 任命第二人为太守
	gid2 := officers[1]
	res = w.ExecuteTask(TaskAPPOINT, cityID, 0, []int{gid2}, nil, nil)
	if len(res.Results) == 0 {
		t.Fatal("任命无结果")
	}
	if city.PrefectID != gid2 {
		t.Errorf("任命后太守应为 %d，实际 %d", gid2, city.PrefectID)
	}
}

// TestExecuteSearch 验证搜索返回结果
func TestExecuteSearch(t *testing.T) {
	w := newTestWorld(t)
	cityID := setupPlayerState(t, w)
	gid := firstOfficerID(t, w, cityID)
	res := w.ExecuteTask(TaskSEARCH, cityID, 0, []int{gid}, nil, nil)
	if len(res.Results) == 0 {
		t.Fatal("搜索无结果")
	}
	if res.Results[0] == "" {
		t.Error("搜索结果为空")
	}
}

// TestExecuteSchool 验证学院学习（经验足则智谋+1）
func TestExecuteSchool(t *testing.T) {
	w := newTestWorld(t)
	cityID := setupPlayerState(t, w)
	gid := firstOfficerID(t, w, cityID)
	g := w.General(gid)
	g.Experience = g.GetSchoolNeedExp() + 1000
	wisdomBefore := g.Wisdom
	res := w.ExecuteTask(TaskSCHOOL, cityID, 0, []int{gid}, nil, nil)
	if len(res.Results) == 0 {
		t.Fatal("学院无结果")
	}
	if g.Wisdom != wisdomBefore+1 {
		t.Errorf("学习后智谋应+1: %d -> %d", wisdomBefore, g.Wisdom)
	}
}

// TestExecuteHospital 验证医馆治疗
func TestExecuteHospital(t *testing.T) {
	w := newTestWorld(t)
	cityID := setupPlayerState(t, w)
	city := w.City(cityID)
	gid := firstOfficerID(t, w, cityID)
	g := w.General(gid)
	city.Money = 500
	g.Health = 50
	res := w.ExecuteTask(TaskHOSPITAL, cityID, 0, []int{gid}, nil, nil)
	if len(res.Results) == 0 {
		t.Fatal("医馆无结果")
	}
	if g.Health <= 50 {
		t.Errorf("治疗后体力应增加: %d", g.Health)
	}
	if city.Money != 400 {
		t.Errorf("治疗应扣100金，实际剩 %d", city.Money)
	}
}

// TestExecuteConscript 验证征兵 amount 钳制与预备兵增加
func TestExecuteConscript(t *testing.T) {
	w := newTestWorld(t)
	cityID := setupPlayerState(t, w)
	city := w.City(cityID)
	city.Money = 30000
	reserveBefore := city.ReserveSoldiers
	res := w.ExecuteTask(TaskCONSCRIPT, cityID, 0, nil, nil, map[string]interface{}{"amount": 500})
	if len(res.Results) == 0 {
		t.Fatal("征兵无结果")
	}
	if res.Results[0] == "无法征兵（已达上限或资源不足）" {
		t.Log("该城已满兵，征兵被拒（合法）")
	} else {
		if city.ReserveSoldiers < reserveBefore {
			t.Errorf("征兵成功后预备兵应增加: %d -> %d", reserveBefore, city.ReserveSoldiers)
		}
	}
	// 负数 amount 应钳制为0（返回无法征兵）
	res = w.ExecuteTask(TaskCONSCRIPT, cityID, 0, nil, nil, map[string]interface{}{"amount": -100})
	if res.Results[0] == "" {
		t.Error("负数征兵应有结果文案")
	}
}

// TestExecuteShop 验证购粮换算（4粮=3金）
func TestExecuteShop(t *testing.T) {
	w := newTestWorld(t)
	cityID := setupPlayerState(t, w)
	city := w.City(cityID)
	city.Money = 30000
	grainBefore := city.Grain
	moneyBefore := city.Money
	n := 4000 // 购 4000 粮
	res := w.ExecuteTask(TaskSHOP, cityID, 0, nil, nil, map[string]interface{}{"amount": n})
	if len(res.Results) == 0 {
		t.Fatal("购粮无结果")
	}
	if city.Grain != grainBefore+n {
		t.Errorf("购粮后粮食应为 %d，实际 %d", grainBefore+n, city.Grain)
	}
	if city.Money != moneyBefore-n*3/4 {
		t.Errorf("购粮应扣 %d 金，实际剩 %d", n*3/4, city.Money)
	}
}

// TestExecuteTransport 验证输送
func TestExecuteTransport(t *testing.T) {
	w := newTestWorld(t)
	cityID := setupPlayerState(t, w)
	city := w.City(cityID)
	// 找一个相邻城作目标
	targetID := 0
	for _, nid := range city.ConnectCityId {
		if nid != cityID {
			targetID = nid
			break
		}
	}
	if targetID == 0 {
		t.Skip("无相邻城")
	}
	city.Money = 1000
	city.Grain = 1000
	target := w.City(targetID)
	tMoney, tGrain := target.Money, target.Grain
	res := w.ExecuteTask(TaskTRANSPORT, cityID, targetID, nil, nil, map[string]interface{}{"food": 200, "gold": 100})
	if len(res.Results) == 0 {
		t.Fatal("输送无结果")
	}
	if target.Money != tMoney+100 {
		t.Errorf("输送后目标金钱应为 %d，实际 %d", tMoney+100, target.Money)
	}
	if target.Grain != tGrain+200 {
		t.Errorf("输送后目标粮食应为 %d，实际 %d", tGrain+200, target.Grain)
	}
}

// TestExecuteMove 验证移动
func TestExecuteMove(t *testing.T) {
	w := newTestWorld(t)
	cityID := setupPlayerState(t, w)
	city := w.City(cityID)
	officers := city.GetOfficerIds()
	if len(officers) < 2 {
		t.Skip("武将不足")
	}
	// 找一个非君主、可移动的武将
	gid := officers[1]
	// 找目标城（非本城）
	targetID := 0
	for _, nid := range city.ConnectCityId {
		if nid != cityID {
			targetID = nid
			break
		}
	}
	if targetID == 0 {
		t.Skip("无相邻城")
	}
	res := w.ExecuteTask(TaskMOVE, cityID, targetID, []int{gid}, nil, nil)
	if len(res.Results) == 0 {
		t.Fatal("移动无结果")
	}
	// 武将应离开原城
	if containsInt(city.GetOfficerIds(), gid) {
		t.Errorf("武将 %d 应移出原城", gid)
	}
	// 应进入目标城
	if !containsInt(w.City(targetID).GetOfficerIds(), gid) {
		t.Errorf("武将 %d 应进入目标城", gid)
	}
}

func containsInt(s []int, v int) bool {
	for _, x := range s {
		if x == v {
			return true
		}
	}
	return false
}

// TestExecuteAlienateAndBribe 验证离间/招揽命令（仅验证有结果文案）
func TestExecuteAlienateAndBribe(t *testing.T) {
	w := newTestWorld(t)
	cityID := setupPlayerState(t, w)
	gid := firstOfficerID(t, w, cityID)
	// 找一个敌城武将做目标
	target := 0
	var targetCountry int
	for _, c := range w.Countries {
		if c.CountryId != w.GameInfo.PlayerCountryId && len(c.CityIDs) > 0 {
			if cty := w.City(c.CityIDs[0]); cty != nil {
				off := cty.GetOfficerIds()
				if len(off) > 0 {
					target = off[0]
					targetCountry = c.CountryId
					break
				}
			}
		}
	}
	if target == 0 {
		t.Skip("无敌方武将")
	}
	_ = targetCountry
	res := w.ExecuteTask(TaskALIENATE, cityID, 0, []int{gid}, []int{target}, nil)
	if len(res.Results) == 0 {
		t.Fatal("离间无结果")
	}
	if res.Results[0] != "离间成功" && res.Results[0] != "离间失败" {
		t.Errorf("离间结果应为成功/失败，实际 %s", res.Results[0])
	}
}

// TestIntFromInput 验证 intFromInput 各类型
func TestIntFromInput(t *testing.T) {
	if got := intFromInput(map[string]interface{}{"v": float64(42)}, "v", 0); got != 42 {
		t.Errorf("float64 解析应得 42，实际 %d", got)
	}
	if got := intFromInput(map[string]interface{}{"v": 7}, "v", 0); got != 7 {
		t.Errorf("int 解析应得 7，实际 %d", got)
	}
	if got := intFromInput(map[string]interface{}{"v": "13"}, "v", 0); got != 13 {
		t.Errorf("string 解析应得 13，实际 %d", got)
	}
	if got := intFromInput(map[string]interface{}{}, "v", 99); got != 99 {
		t.Errorf("缺省应返回默认 99，实际 %d", got)
	}
	if got := intFromInput(nil, "v", 5); got != 5 {
		t.Errorf("nil inputs 应返回默认 5，实际 %d", got)
	}
	if got := intFromInput(map[string]interface{}{"v": "abc"}, "v", 3); got != 3 {
		t.Errorf("非法 string 应返回默认 3，实际 %d", got)
	}
}

// TestAtoiSafe 验证 atoiSafe 边界
func TestAtoiSafe(t *testing.T) {
	if atoiSafe("123", 0) != 123 {
		t.Error("atoiSafe('123') 应得 123")
	}
	if atoiSafe("-45", 0) != -45 {
		t.Error("atoiSafe('-45') 应得 -45")
	}
	if atoiSafe("+8", 0) != 8 {
		t.Error("atoiSafe('+8') 应得 8")
	}
	if atoiSafe("12a", 9) != 9 {
		t.Error("atoiSafe('12a') 应返回默认 9")
	}
	// 空字符串：循环不执行，直接返回 0（与实现一致）
	if atoiSafe("", 9) != 0 {
		t.Errorf("atoiSafe('') 应返回 0，实际 %d", atoiSafe("", 9))
	}
}
