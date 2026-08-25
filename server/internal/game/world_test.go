package game

import (
	"os"
	"path/filepath"
	"testing"

	"3k-server/internal/game/entities"
)

// loadSeedFile 读取种子 JSON 物理文件（测试 fixture，与 static 内嵌种子同源）。
func loadSeedFile(t *testing.T, name string) []byte {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("..", "static", "seed_data", name))
	if err != nil {
		t.Fatalf("读取种子数据 %s 失败: %v", name, err)
	}
	return data
}

// newTestWorld 用固定 seed 创建测试世界（解析种子 JSON）。
func newTestWorld(t *testing.T) *World {
	t.Helper()
	cfg, err := ParseConfig(
		loadSeedFile(t, "generals.json"),
		loadSeedFile(t, "cities.json"),
		loadSeedFile(t, "countries.json"),
		loadSeedFile(t, "weapons.json"),
		loadSeedFile(t, "maps.json"),
		loadSeedFile(t, "formations.json"),
	)
	if err != nil {
		t.Fatalf("解析静态配置失败: %v", err)
	}
	texts, err := ParseTexts(loadSeedFile(t, "texts.json"))
	if err != nil {
		t.Fatalf("解析文案表失败: %v", err)
	}
	return NewWorld(cfg, texts, 12345)
}

// newTestTexts 返回文案表（用于文案相关测试）。
func newTestTexts(t *testing.T) *Texts {
	t.Helper()
	texts, err := ParseTexts(loadSeedFile(t, "texts.json"))
	if err != nil {
		t.Fatalf("解析文案表失败: %v", err)
	}
	return texts
}

// TestLoadWorld 验证数据加载
func TestLoadWorld(t *testing.T) {
	w := newTestWorld(t)
	if len(w.Generals) != 666 {
		t.Errorf("武将数应为666，实际 %d", len(w.Generals))
	}
	if len(w.Cities) != 48 {
		t.Errorf("城池数应为48，实际 %d", len(w.Cities))
	}
	if len(w.Countries) != 3 {
		t.Errorf("势力数应为3，实际 %d", len(w.Countries))
	}
	if len(w.Weapons) != 32 {
		t.Errorf("武器数应为32，实际 %d", len(w.Weapons))
	}
	// 验证城池-势力归属
	first := w.Countries[1]
	if first == nil || len(first.CityIDs) == 0 {
		t.Error("势力1无城池")
	}
	t.Logf("势力%d 君主%d 城数%d", first.CountryId, first.CountryKingId, len(first.CityIDs))
}

// TestGeneralFormulas 验证武将公式
func TestGeneralFormulas(t *testing.T) {
	w := newTestWorld(t)
	// 找武力较高的武将验证公式
	var g *entities.General
	for _, gg := range w.Generals {
		if gg.Force >= 80 {
			g = gg
			break
		}
	}
	if g == nil {
		t.Fatal("未找到武力≥80的武将")
	}
	atk := g.GetAttackPower(w)
	def := g.GetDefendPower(w)
	if atk <= 0 || def <= 0 {
		t.Errorf("攻防应为正，atk=%d def=%d", atk, def)
	}
	t.Logf("%s 武力%d 攻%d 防%d 带兵上限%d", g.GeneralName, g.Force, atk, def, g.GetMaxSoldierNum())
}

// TestSelectKingAndInterior 验证选君主 + 内政命令
func TestSelectKingAndInterior(t *testing.T) {
	w := newTestWorld(t)
	// 选第一个可选君主
	var king *entities.Country
	for _, c := range w.Countries {
		if c.CanBeChoose {
			king = c
			break
		}
	}
	if king == nil {
		t.Fatal("无可选君主")
	}
	w.GameInfo.PlayerCountryId = king.CountryId
	w.GameInfo.DoCityId = king.CityIDs[0]
	w.GameInfo.PlayerOrderNum = w.GameInfo.GetPlayerOrderNum(w)
	w.GameInfo.PlayingState = GameStatePLAYING

	city := w.City(w.GameInfo.DoCityId)
	officers := city.GetOfficerIds()
	if len(officers) == 0 {
		t.Fatal("君主城无武将")
	}
	gid := officers[0]
	_ = w.General(gid)

	// 执行开垦
	moneyBefore := city.Money
	res := w.ExecuteTask(TaskRECLAIM, city.CityID, 0, []int{gid}, nil, nil)
	if len(res.Results) == 0 {
		t.Fatal("开垦无结果")
	}
	t.Logf("开垦结果: %s (金钱 %d→%d)", res.Results[0], moneyBefore, city.Money)

	// 执行搜索
	res = w.ExecuteTask(TaskSEARCH, city.CityID, 0, []int{gid}, nil, nil)
	t.Logf("搜索结果: %v", res.Results)

	// 征兵（可能因已满员而拒绝，均为合法行为）
	res = w.ExecuteTask(TaskCONSCRIPT, city.CityID, 0, nil, nil, map[string]interface{}{"amount": 500})
	if len(res.Results) == 0 {
		t.Fatal("征兵无结果")
	}
	t.Logf("征兵结果: %v 预备兵=%d", res.Results, city.ReserveSoldiers)
	if city.ReserveSoldiers < 0 {
		t.Errorf("征兵后预备兵不应为负，实际 %d", city.ReserveSoldiers)
	}
}

// TestEndTurnAndMonth 验证结束回合 + 月度推进
func TestEndTurnAndMonth(t *testing.T) {
	w := newTestWorld(t)
	var king *entities.Country
	for _, c := range w.Countries {
		if c.CanBeChoose {
			king = c
			break
		}
	}
	if king == nil {
		t.Fatal("无可选君主")
	}
	w.GameInfo.PlayerCountryId = king.CountryId
	w.GameInfo.PlayingState = GameStatePLAYING
	monthBefore := w.GameInfo.Month

	// 结束回合
	w.EndPlayerTurn()
	if w.GameInfo.Month != monthBefore+1 && !(monthBefore == 12 && w.GameInfo.Month == 1) {
		t.Errorf("月度应推进，month %d→%d", monthBefore, w.GameInfo.Month)
	}
	t.Logf("结束回合后：年月=%d/%d 玩家命令数=%d 状态=%d",
		w.GameInfo.Years, w.GameInfo.Month, w.GameInfo.PlayerOrderNum, w.GameInfo.PlayingState)

	// 连续跑几个月验证不崩溃且 AI 行动
	for i := 0; i < 12; i++ {
		w.EndPlayerTurn()
	}
	t.Logf("13个月后：年月=%d/%d 状态=%d", w.GameInfo.Years, w.GameInfo.Month, w.GameInfo.PlayingState)
}

// TestSerialize 验证存档序列化（补齐4缺口）
func TestSerialize(t *testing.T) {
	w := newTestWorld(t)
	data, err := w.Serialize()
	if err != nil {
		t.Fatalf("序列化失败: %v", err)
	}
	if len(data) == 0 {
		t.Fatal("序列化为空")
	}
	t.Logf("序列化大小: %d 字节", len(data))
	// 验证包含4缺口字段
	s := string(data)
	for _, key := range []string{"officeGeneralId", "allianceList", "playingState", "rngSeed"} {
		if !contains(s, key) {
			t.Errorf("序列化缺少字段 %s", key)
		}
	}
}

func contains(s, sub string) bool {
	return len(s) >= len(sub) && (len(sub) == 0 || indexOf(s, sub) >= 0)
}

func indexOf(s, sub string) int {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return i
		}
	}
	return -1
}

// TestWarPrepare 验证战争准备
func TestWarPrepare(t *testing.T) {
	w := newTestWorld(t)
	// 选玩家势力
	for _, c := range w.Countries {
		if c.CanBeChoose {
			w.GameInfo.PlayerCountryId = c.CountryId
			break
		}
	}
	// 玩家攻打第一个邻敌城
	enemies := w.GetEnemyAdjacentCityIDArray(w.GameInfo.PlayerCountryId)
	if len(enemies) == 0 {
		t.Log("无邻敌城，跳过")
		return
	}
	targetID := enemies[0]
	target := w.City(targetID)
	if target == nil {
		t.Fatal("目标城不存在")
	}
	// 玩家出兵武将（从玩家主城取）
	pc := w.Country(w.GameInfo.PlayerCountryId)
	from := w.City(pc.CityIDs[0])
	attackerIDs := from.GetOfficerIds()
	if len(attackerIDs) == 0 {
		t.Log("玩家主城无武将，跳过")
		return
	}
	// 攻城
	w.WarPrepare(false, targetID, pc.CityIDs[0], attackerIDs, 300, 500, w.GameInfo.PlayerCountryId)
	if w.War == nil {
		t.Fatal("WarPrepare 未创建战争")
	}
	t.Logf("战争准备：目标城%d 我方%d单位 敌方%d单位 我方粮%d", targetID, len(w.War.HmUnits), len(w.War.AiUnits), w.War.HmFood)
	// 验证初始位置
	if len(w.War.HmUnits) > 0 {
		u := w.War.HmUnits[0]
		t.Logf("我方首单位 pos=(%d,%d)", u.ArrayPosX, u.ArrayPosY)
	}
	// AI 行动一回合
	w.SetMoveBonus(w.War.AiUnits)
	w.AiUnitsTurn()
	t.Log("AI 回合执行完毕")
	// 结算
	w.HandleWarOver(WarOCCUPY)
	t.Logf("战争结算完成")
}

// TestSelfBuild 验证自建武将
func TestSelfBuild(t *testing.T) {
	w := newTestWorld(t)
	g, err := w.AddCustomGeneral("测试武将")
	if err != nil {
		t.Fatalf("自建武将失败: %v", err)
	}
	if g == nil || g.GeneralId == 0 {
		t.Fatal("自建武将为nil")
	}
	t.Logf("自建武将 %s id=%d 武力%d 智谋%d 特技数%d", g.GeneralName, g.GeneralId, g.Force, g.Wisdom, len(g.GetActiveSkills(w.Texts.SkillNames)))
}

// TestSerializeRoundTrip 验证存档-读档往返一致
func TestSerializeRoundTrip(t *testing.T) {
	w := newTestWorld(t)
	// 选势力1并执行一次内政改变状态
	for _, c := range w.Countries {
		if c.CanBeChoose {
			w.GameInfo.PlayerCountryId = c.CountryId
			w.GameInfo.DoCityId = c.CityIDs[0]
			break
		}
	}
	city := w.City(w.GameInfo.DoCityId)
	officers := city.GetOfficerIds()
	if len(officers) == 0 {
		t.Skip("无武将")
	}
	w.ExecuteTask(TaskSEARCH, city.CityID, 0, []int{officers[0]}, nil, nil)
	grainAfter := city.Grain

	// 序列化
	data, err := w.Serialize()
	if err != nil {
		t.Fatalf("序列化失败: %v", err)
	}
	// 反序列化到新世界
	w2 := newTestWorld(t)
	if err := w2.Deserialize(data); err != nil {
		t.Fatalf("反序列化失败: %v", err)
	}
	city2 := w2.City(w.GameInfo.DoCityId)
	if city2.Grain != grainAfter {
		t.Errorf("读档后粮食不一致：%d vs %d", city2.Grain, grainAfter)
	}
	t.Logf("存档往返一致：粮食 %d", city2.Grain)
}
