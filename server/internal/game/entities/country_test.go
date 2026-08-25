package entities

import "testing"

// fakeWorldRef 测试用 WorldRef，只实现 city 查询
type fakeWorldRef struct {
	cities map[int]*City
}

func (f *fakeWorldRef) General(id int) *General { return nil }
func (f *fakeWorldRef) City(id int) *City {
	if f.cities == nil {
		return nil
	}
	return f.cities[id]
}
func (f *fakeWorldRef) Weapon(id int) *Weapon { return nil }
func (f *fakeWorldRef) CountryByKingId(kingId int) *Country {
	return nil
}
func (f *fakeWorldRef) RemoveCityFromCountry(ownerKingID, cityID int) {}
func (f *fakeWorldRef) GeneralDie(gid int)                           {}
func (f *fakeWorldRef) CountryCount() int                            { return 0 }

// TestCountryCityCount 验证城池数判断
func TestCountryCityCount(t *testing.T) {
	c := &Country{CityIDs: []int{1, 2, 3}}
	if c.GetHaveCityNum() != 3 {
		t.Errorf("城池数应3，实际 %d", c.GetHaveCityNum())
	}
	if c.IsDestroyed() {
		t.Error("3城不应灭亡")
	}
	if c.IsEndangered() {
		t.Error("3城不应危急")
	}
	c2 := &Country{CityIDs: []int{1}}
	if !c2.IsEndangered() {
		t.Error("1城应危急")
	}
	if c2.IsDestroyed() {
		t.Error("1城不应灭亡")
	}
	c3 := &Country{}
	if !c3.IsDestroyed() {
		t.Error("0城应灭亡")
	}
}

// TestCountryAddRemoveCity 验证城池增减
func TestCountryAddRemoveCity(t *testing.T) {
	fw := &fakeWorldRef{cities: map[int]*City{
		1: {CityID: 1, OwnerID: 0, PrefectID: 0},
		2: {CityID: 2, OwnerID: 0, PrefectID: 0},
	}}
	c := &Country{CountryKingId: 100}
	if !c.AddCity(fw, 1) {
		t.Error("AddCity 应成功")
	}
	if fw.cities[1].OwnerID != 100 {
		t.Errorf("添加后城池归属应为君主100，实际 %d", fw.cities[1].OwnerID)
	}
	// 重复添加：返回 true 但不重复
	if !c.AddCity(fw, 1) {
		t.Error("重复添加应返回 true")
	}
	if c.GetHaveCityNum() != 1 {
		t.Errorf("重复添加不应增加城池数，实际 %d", c.GetHaveCityNum())
	}
	// cityID=0 拒绝
	if c.AddCity(fw, 0) {
		t.Error("cityID=0 应拒绝")
	}
	// 移除
	if !c.RemoveCity(fw, 1) {
		t.Error("RemoveCity 应成功")
	}
	if c.GetHaveCityNum() != 0 {
		t.Errorf("移除后城池数应0，实际 %d", c.GetHaveCityNum())
	}
	if fw.cities[1].OwnerID != 0 || fw.cities[1].PrefectID != 0 {
		t.Error("移除后城池归属应清空")
	}
	// 移除不存在的城
	if c.RemoveCity(fw, 999) {
		t.Error("移除不存在城池应返回 false")
	}
}

// TestCountryRemoveAlliance 验证同盟移除
func TestCountryRemoveAlliance(t *testing.T) {
	c := &Country{AllianceList: []*Alliance{
		{CountryId: 2, Months: 3},
		{CountryId: 3, Months: 2},
	}}
	c.RemoveAlliance(2)
	if len(c.AllianceList) != 1 || c.AllianceList[0].CountryId != 3 {
		t.Errorf("移除同盟2后应剩同盟3，实际 %v", c.AllianceList)
	}
	// 移除不存在的同盟不影响
	c.RemoveAlliance(99)
	if len(c.AllianceList) != 1 {
		t.Errorf("移除不存在同盟不应改变列表，实际 %d", len(c.AllianceList))
	}
}

// TestCountryFindKingCity 验证君主城查找
func TestCountryFindKingCity(t *testing.T) {
	fw := &fakeWorldRef{cities: map[int]*City{
		1: {CityID: 1, PrefectID: 100},
		2: {CityID: 2, PrefectID: 200},
	}}
	c := &Country{CountryKingId: 200, CityIDs: []int{1, 2}}
	if v := c.FindKingCity(fw); v != 2 {
		t.Errorf("君主城应为2，实际 %d", v)
	}
	// 无君主城返回0
	c2 := &Country{CountryKingId: 999, CityIDs: []int{1}}
	if v := c2.FindKingCity(fw); v != 0 {
		t.Errorf("无君主城应返回0，实际 %d", v)
	}
}

// TestAlliance 验证同盟结构
func TestAlliance(t *testing.T) {
	a := &Alliance{CountryId: 5, Months: 2}
	if a.CountryId != 5 || a.Months != 2 {
		t.Error("同盟字段不一致")
	}
}
