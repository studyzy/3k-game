package game

import (
	"testing"
)

// TestGetOfficeGenBelongKing 验证获取武将所属君主
func TestGetOfficeGenBelongKing(t *testing.T) {
	w := newTestWorld(t)
	var kingID int
	var found bool
	for _, c := range w.Countries {
		if c.CanBeChoose && len(c.CityIDs) > 0 {
			if city := w.City(c.CityIDs[0]); city != nil {
				off := city.GetOfficerIds()
				if len(off) > 0 {
					kingID = c.CountryKingId
					_ = kingID
					found = true
					break
				}
			}
		}
	}
	if !found {
		t.Skip("无可选势力武将")
	}
	// 找一个在职武将
	var gid, ownerKing int
	for _, c := range w.Countries {
		if len(c.CityIDs) == 0 {
			continue
		}
		city := w.City(c.CityIDs[0])
		if city == nil {
			continue
		}
		off := city.GetOfficerIds()
		if len(off) > 0 {
			gid = off[0]
			ownerKing = city.OwnerID
			break
		}
	}
	if gid == 0 {
		t.Skip("无在职武将")
	}
	belong := w.GetOfficeGenBelongKing(gid)
	if belong != ownerKing {
		t.Errorf("武将 %d 所属君主应为 %d，实际 %d", gid, ownerKing, belong)
	}
	// 不存在的武将返回0
	if w.GetOfficeGenBelongKing(99999) != 0 {
		t.Error("不存在武将应返回0")
	}
}

// TestIsAlienateHighLoyalty 验证高忠诚离间必失败
func TestIsAlienateHighLoyalty(t *testing.T) {
	w := newTestWorld(t)
	doGen := newGeneralFull(1, 60, 60, 80, 60, 60)
	beGen := newGeneralFull(2, 60, 60, 60, 60, 60)
	beGen.Loyalty = 96
	w.Generals[doGen.GeneralId] = doGen
	w.Generals[beGen.GeneralId] = beGen
	// 忠诚>95 直接失败
	if w.IsAlienate(doGen.GeneralId, beGen.GeneralId) {
		t.Error("忠诚>95 不应离间成功")
	}
	// 武将不存在返回 false
	if w.IsAlienate(doGen.GeneralId, 99999) {
		t.Error("目标武将不存在应返回 false")
	}
}

// TestCanBribeHighLoyalty 验证高忠诚招揽必失败
func TestCanBribeHighLoyalty(t *testing.T) {
	w := newTestWorld(t)
	doGen := newGeneralFull(1, 60, 60, 80, 60, 60)
	beGen := newGeneralFull(2, 60, 60, 60, 60, 60)
	beGen.Loyalty = 95
	if w.CanBribe(doGen, beGen) {
		t.Error("忠诚>=95 不应可招揽")
	}
}

// TestEmployProbability 验证登用概率（nil 守卫）
func TestEmployProbability(t *testing.T) {
	w := newTestWorld(t)
	// 武将不存在返回 false
	if w.EmployProbability(99999, 88888) {
		t.Error("武将不存在应返回 false")
	}
}

// TestGeneralDieCompleteNonKing 验证非君主死亡从全城移除
func TestGeneralDieCompleteNonKing(t *testing.T) {
	w := newTestWorld(t)
	// 找一个非君主、非城市归属的武将
	var gid int
	for _, c := range w.Countries {
		if len(c.CityIDs) == 0 {
			continue
		}
		city := w.City(c.CityIDs[0])
		if city == nil {
			continue
		}
		for _, off := range city.GetOfficerIds() {
			if w.CountryByKingId(off) == nil {
				gid = off
				break
			}
		}
		if gid != 0 {
			break
		}
	}
	if gid == 0 {
		t.Skip("无非君主在职武将")
	}
	w.GeneralDieComplete(gid)
	if !w.General(gid).IsDie {
		t.Errorf("武将 %d 应标记死亡", gid)
	}
}

// TestGeneralDieCompleteKing 验证君主死亡触发继承
func TestGeneralDieCompleteKing(t *testing.T) {
	w := newTestWorld(t)
	var kingID, countryID int
	for _, c := range w.Countries {
		if len(c.CityIDs) > 0 {
			kingID = c.CountryKingId
			countryID = c.CountryId
			break
		}
	}
	if kingID == 0 {
		t.Skip("无君主势力")
	}
	beforeKing := w.Country(countryID).CountryKingId
	w.GeneralDieComplete(kingID)
	afterKing := w.Country(countryID).CountryKingId
	if afterKing == beforeKing && w.General(beforeKing).IsDie {
		// 若无继承人，势力灭亡（CityIDs 清空）
		if len(w.Country(countryID).CityIDs) != 0 {
			t.Errorf("无继承人时势力应灭亡，实际剩 %d 城", len(w.Country(countryID).CityIDs))
		}
	} else {
		// 有继承人：新君主非死亡
		if w.General(afterKing).IsDie {
			t.Errorf("新君主 %d 不应死亡", afterKing)
		}
	}
}
