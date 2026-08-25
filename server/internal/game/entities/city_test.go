package entities

import "testing"

// TestCityMoney 验证金钱钳制与增减
func TestCityMoney(t *testing.T) {
	c := &City{}
	c.SetMoney(5000)
	if c.GetMoney() != 5000 {
		t.Errorf("金钱应5000，实际 %d", c.GetMoney())
	}
	c.SetMoney(-100)
	if c.Money != MaxMoney {
		t.Errorf("负数 SetMoney 应钳制到 MaxMoney，实际 %d", c.Money)
	}
	c.SetMoney(1000)
	if delta := c.AddGold(500); delta != 500 {
		t.Errorf("AddGold 增量应500，实际 %d", delta)
	}
	if c.Money != 1500 {
		t.Errorf("AddGold 后应1500，实际 %d", c.Money)
	}
	// 超上限：AddGold 只加到 MaxMoney
	c.SetMoney(MaxMoney - 100)
	if delta := c.AddGold(1000); delta != 100 {
		t.Errorf("超上限 AddGold 实际增量应100，实际 %d", delta)
	}
	if c.Money != MaxMoney {
		t.Errorf("超上限 AddGold 应钳制到 MaxMoney，实际 %d", c.Money)
	}
	// SubGold 不跌穿0
	c.SetMoney(100)
	if v := c.SubGold(500); v != 100 {
		t.Errorf("SubGold 超量应只扣100，实际 %d", v)
	}
	if c.Money != 0 {
		t.Errorf("SubGold 后应0，实际 %d", c.Money)
	}
}

// TestCityFood 验证粮食钳制与增减
func TestCityFood(t *testing.T) {
	c := &City{}
	c.SetFood(3000)
	if c.GetFood() != 3000 {
		t.Errorf("粮食应3000，实际 %d", c.GetFood())
	}
	c.SetFood(50000)
	if c.Grain != MaxGrain {
		t.Errorf("超限 SetFood 应钳制到 MaxGrain，实际 %d", c.Grain)
	}
	c.SetFood(1000)
	if delta := c.AddFood(300); delta != 300 {
		t.Errorf("AddFood 增量应300，实际 %d", delta)
	}
	// 超上限
	c.SetFood(MaxGrain - 10)
	if delta := c.AddFood(500); delta != 10 {
		t.Errorf("超上限 AddFood 实际增量应10，实际 %d", delta)
	}
}

// TestCityTreasure 验证宝物钳制
func TestCityTreasure(t *testing.T) {
	c := &City{}
	c.SetTreasureNum(50)
	if delta := c.AddTreasureNum(60); delta != 50 {
		t.Errorf("宝物超限 Add 应只加50，实际 %d", delta)
	}
	if c.Treasures != 100 {
		t.Errorf("宝物应钳制到100，实际 %d", c.Treasures)
	}
	c.SetTreasureNum(20)
	if v := c.SubTreasureNum(50); v != 20 {
		t.Errorf("宝物超量 Sub 应只扣20，实际 %d", v)
	}
	if c.Treasures != 0 {
		t.Errorf("宝物应钳制到0，实际 %d", c.Treasures)
	}
}

// TestCityAttributes 验证属性钳制（0-99）
func TestCityAttributes(t *testing.T) {
	c := &City{}
	c.SetRule(150)
	if c.Rule != MaxRule {
		t.Errorf("统治度应钳制到 %d，实际 %d", MaxRule, c.Rule)
	}
	c.SetRule(50)
	c.AddRule(100)
	if c.Rule != MaxRule {
		t.Errorf("AddRule 超限应钳制到 %d，实际 %d", MaxRule, c.Rule)
	}
	c.SubRule(1000)
	if c.Rule != 0 {
		t.Errorf("SubRule 应钳制到0，实际 %d", c.Rule)
	}
	// 农业/商业/防灾
	c.SetAgro(-5)
	if c.Agriculture != 0 {
		t.Errorf("负农业应钳制到0，实际 %d", c.Agriculture)
	}
	c.SetTrade(50000)
	if c.Commerce != MaxTrade {
		t.Errorf("超限商业应钳制到 MaxTrade，实际 %d", c.Commerce)
	}
	c.SetFloodControl(200)
	if c.Prevention != MaxRule {
		t.Errorf("超限防灾应钳制到 %d，实际 %d", MaxRule, c.Prevention)
	}
}

// TestCityPopulation 验证人口钳制
func TestCityPopulation(t *testing.T) {
	c := &City{}
	c.SetPopulation(-100)
	if c.Population != 0 {
		t.Errorf("负人口应钳制到0，实际 %d", c.Population)
	}
	c.SetPopulation(1000000)
	if c.Population != MaxPop {
		t.Errorf("超限人口应钳制到 MaxPop，实际 %d", c.Population)
	}
	c.SetPopulation(10000)
	if delta := c.AddPopulation(500); delta != 500 {
		t.Errorf("AddPopulation 增量应500，实际 %d", delta)
	}
}

// TestCityOfficerLists 验证武将数组过滤
func TestCityOfficerLists(t *testing.T) {
	c := &City{
		OfficeGeneralId:   []int{1, 0, 3, -1},
		ReservedGeneralId: []int{0, 5, 6},
		NotFoundGeneralId: []int{7, 0, 8},
		JailGeneralId:     []int{9, 10},
	}
	if v := c.GetOfficerIds(); len(v) != 2 || v[0] != 1 || v[1] != 3 {
		t.Errorf("在职武将应过滤非正 id，实际 %v", v)
	}
	if v := c.GetCityOfficerNum(); v != 2 {
		t.Errorf("在职武将数应2，实际 %d", v)
	}
	if v := c.GetTalentIds(); len(v) != 2 || v[0] != 5 {
		t.Errorf("在野武将应过滤非正 id，实际 %v", v)
	}
	if v := c.GetRecluseIds(); len(v) != 2 {
		t.Errorf("隐居武将应过滤非正 id，实际 %v", v)
	}
	if v := c.GetCaptureList(); len(v) != 2 {
		t.Errorf("监狱武将应2，实际 %v", v)
	}
}

// TestCityConscript 验证征兵（纯字段操作）
func TestCityConscript(t *testing.T) {
	c := &City{Money: 1000, Rule: 90, Population: 10000}
	c.Conscript(100)
	if c.ReserveSoldiers != 100 {
		t.Errorf("预备兵应100，实际 %d", c.ReserveSoldiers)
	}
	// 扣钱 (100+4)/5=20，扣统治度 100/500=0，人口减 100*3/2=150
	if c.Money != 980 {
		t.Errorf("征兵应扣20金，实际 %d", c.Money)
	}
	if c.Population != 9850 {
		t.Errorf("征兵应减150人口，实际 %d", c.Population)
	}
}

// TestCityIncome 验证收入公式
func TestCityIncome(t *testing.T) {
	// 高商业/农业 + 高统治度，收入应为正
	c := &City{Population: 50000, Commerce: 500, Agriculture: 500, Rule: 95}
	if v := c.MoneyIncome(); v <= 0 {
		t.Errorf("金钱收入应为正，实际 %d", v)
	}
	if v := c.FoodIncome(); v <= 0 {
		t.Errorf("粮食收入应为正，实际 %d", v)
	}
}
