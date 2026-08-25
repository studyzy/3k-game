package game

import "testing"

// TestDeserializeInvalid 验证无效数据反序列化报错
func TestDeserializeInvalid(t *testing.T) {
	w := newTestWorld(t)
	if err := w.Deserialize([]byte("not json")); err == nil {
		t.Error("无效 JSON 应返回错误")
	}
	if err := w.Deserialize(nil); err == nil {
		t.Error("nil 数据应返回错误")
	}
}

// TestSerializeRoundTripFull 验证存档全字段往返一致
func TestSerializeRoundTripFull(t *testing.T) {
	w := newTestWorld(t)
	// 选势力1，改一批状态
	for _, c := range w.Countries {
		if c.CanBeChoose {
			w.GameInfo.PlayerCountryId = c.CountryId
			w.GameInfo.DoCityId = c.CityIDs[0]
			break
		}
	}
	w.GameInfo.Years = 260
	w.GameInfo.Month = 7
	w.GameInfo.PlayerOrderNum = 6
	// 修改一个武将
	var gid int
	for _, g := range w.Generals {
		gid = g.GeneralId
		break
	}
	w.General(gid).Force = 99
	w.General(gid).Loyalty = 88
	w.General(gid).Soldiers = 1500
	// 修改一个城池
	city := w.City(w.GameInfo.DoCityId)
	city.Money = 12345
	city.Grain = 6789
	city.PrefectID = gid

	// 序列化-反序列化
	data, err := w.Serialize()
	if err != nil {
		t.Fatalf("序列化失败: %v", err)
	}
	w2 := newTestWorld(t)
	if err := w2.Deserialize(data); err != nil {
		t.Fatalf("反序列化失败: %v", err)
	}
	// 验证 GameInfo
	if w2.GameInfo.Years != 260 || w2.GameInfo.Month != 7 {
		t.Errorf("GameInfo 年月不一致: %d/%d", w2.GameInfo.Years, w2.GameInfo.Month)
	}
	if w2.GameInfo.PlayerOrderNum != 6 {
		t.Errorf("命令数不一致: %d", w2.GameInfo.PlayerOrderNum)
	}
	// 验证武将
	g2 := w2.General(gid)
	if g2.Force != 99 || g2.Loyalty != 88 || g2.Soldiers != 1500 {
		t.Errorf("武将字段往返不一致: force=%d loyalty=%d soldiers=%d",
			g2.Force, g2.Loyalty, g2.Soldiers)
	}
	// 验证城池
	city2 := w2.City(w.GameInfo.DoCityId)
	if city2.Money != 12345 || city2.Grain != 6789 {
		t.Errorf("城池钱粮往返不一致: money=%d grain=%d", city2.Money, city2.Grain)
	}
	if city2.PrefectID != gid {
		t.Errorf("太守往返不一致: %d", city2.PrefectID)
	}
}
