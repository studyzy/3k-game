package game

import "3k-server/internal/game/entities"

// ---- 武将缓存逻辑（对应 GeneralListCache.gd 的判定函数） ----

// GetOfficeGenBelongKing 返回某武将所属君主的武将ID（对应 _get_office_gen_belong_king）
func (w *World) GetOfficeGenBelongKing(gid int) int {
	g := w.General(gid)
	if g == nil {
		return 0
	}
	// 先看其 debutCity 是否在职
	city := w.City(g.DebutCity)
	if city != nil {
		for _, oid := range city.GetOfficerIds() {
			if oid == gid {
				return city.OwnerID
			}
		}
	}
	// 遍历所有城找
	for _, c := range w.Cities {
		for _, oid := range c.GetOfficerIds() {
			if oid == gid {
				return c.OwnerID
			}
		}
	}
	return 0
}

// IsAlienate 离间判定（对应 is_alienate）
func (w *World) IsAlienate(doGenID, beGenID int) bool {
	doGeneral := w.General(doGenID)
	beGeneral := w.General(beGenID)
	if doGeneral == nil || beGeneral == nil {
		return false
	}
	i := 0
	if beGeneral.GetLoyalty() > 95 {
		return false
	}
	if beGeneral.GetLoyalty() > 87 {
		if w.Rng.IntRange(0, 99) > (95-beGeneral.GetLoyalty())*2 {
			return false
		}
	} else {
		i = (95 - beGeneral.GetLoyalty()) * (95 - beGeneral.GetLoyalty()) / 4
		if i > 90 {
			i = 90
		}
		if w.Rng.IntRange(0, 99) > i {
			return false
		}
	}
	beKing := w.General(w.GetOfficeGenBelongKing(beGenID))
	doKing := w.General(w.GetOfficeGenBelongKing(doGenID))
	var d1, d2, d3 int
	if beKing != nil {
		d1 = w.PhaseDiff(beKing, beGeneral)
	}
	if doKing != nil {
		d2 = w.PhaseDiff(doKing, beGeneral)
	}
	d3 = w.PhaseDiff(doGeneral, beGeneral)
	if d1 == 0 {
		return false
	}
	if d2 == 0 {
		i = 10 + w.Rng.IntRange(0, 14)
	}
	if d3 > d1+10 {
		return false
	}
	val := d1 - d2*4/3 - d3*2 + 110 - beGeneral.GetLoyalty()
	if val > 0 {
		if w.Rng.IntRange(0, val-1) > 5 {
			i = 5 + w.Rng.IntRange(0, 9)
		}
		if w.Rng.IntRange(0, 39) < 100-beGeneral.GetLoyalty() {
			i = 2 + w.Rng.IntRange(0, 4)
		} else {
			i = 1 + w.Rng.IntRange(0, 2)
		}
	}
	if w.Rng.IntRange(0, 119) < doGeneral.Wisdom-beGeneral.Wisdom {
		i = 1 + w.Rng.IntRange(0, 2)
	} else {
		return false
	}
	if i > 0 {
		beGeneral.SubLoyalty(i)
		doGeneral.AddMoralExp(w.Rng.IntRange(5, 14))
		doGeneral.AddIqExp(w.Rng.IntRange(2, 9))
		return true
	}
	return false
}

// CanBribe 招揽前提（对应 _can_bribe）
func (w *World) CanBribe(doGeneral, beGeneral *entities.General) bool {
	if beGeneral.GetLoyalty() >= 95 {
		return false
	}
	doKing := w.General(w.GetOfficeGenBelongKing(doGeneral.GeneralId))
	beKing := w.General(w.GetOfficeGenBelongKing(beGeneral.GeneralId))
	var d1, d2, d3 int
	if doKing != nil {
		d1 = w.PhaseDiff(doKing, beGeneral)
	}
	if beKing != nil {
		d2 = w.PhaseDiff(beKing, beGeneral)
	}
	d3 = w.PhaseDiff(doGeneral, beGeneral)
	if d2 == 0 {
		return false
	}
	var val int
	if d2 < 5 {
		val = d2 - d1*2 - d3*2 + (100-beGeneral.GetLoyalty())/2
	} else if d2 <= 10 {
		val = d2 - d1*3/2 - d3*2 + (100-beGeneral.GetLoyalty())/2
	} else if d2 <= 20 {
		val = d2 - d1 - d3*2 + (100-beGeneral.GetLoyalty())/2
	} else {
		val = d2 - d1 - d3*2 + (100-beGeneral.GetLoyalty())/3
	}
	return val > 0
}

// IsBribe 招揽判定（对应 is_bribe）
func (w *World) IsBribe(doCityID, beCityID, doGenID, beGenID int) bool {
	doGeneral := w.General(doGenID)
	beGeneral := w.General(beGenID)
	doCity := w.City(doCityID)
	beCity := w.City(beCityID)
	if doGeneral == nil || beGeneral == nil || doCity == nil || beCity == nil {
		return false
	}
	if w.CanBribe(doGeneral, beGeneral) {
		beGeneral.SetLoyalty(w.Rng.IntRange(40, 74))
		doGeneral.AddMoralExp(w.Rng.IntRange(10, 24))
		doGeneral.AddIqExp(w.Rng.IntRange(4, 9))
		beCity.RemoveOfficerID(w, beGenID)
		doCity.AddOfficeGeneralID(w, beGenID)
		return true
	}
	return false
}

// EmployProbability 雇佣判定（对应 employ_probability）
func (w *World) EmployProbability(gohireID, behireID int) bool {
	goGeneral := w.General(gohireID)
	beGeneral := w.General(behireID)
	if beGeneral == nil || goGeneral == nil {
		return false
	}
	city := w.City(goGeneral.DebutCity)
	if city == nil {
		return false
	}
	kingGeneral := w.General(city.OwnerID)
	if kingGeneral == nil {
		return false
	}
	d1 := w.PhaseDiff(kingGeneral, beGeneral)
	d2 := w.PhaseDiff(goGeneral, beGeneral)
	i := w.Rng.IntRange(0, 74)
	return (d1+d2)/2 < i
}

// GeneralDie 武将死亡处理（对应 general_die，含君主继承/势力灭亡）
func (w *World) GeneralDieComplete(gid int) {
	g := w.Generals[gid]
	if g == nil {
		return
	}
	g.IsDie = true
	g.Status = 0

	// 若为君主，势力需继承或灭亡
	country := w.CountryByKingId(gid)
	if country == nil {
		// 从所有城池移除
		w.removeGeneralFromAllCities(gid)
		return
	}
	// 找继承人
	inheritID := w.getInheritGeneralID(country)
	if inheritID == 0 {
		// 无继承人，势力灭亡：其城池归中立
		for _, cityID := range country.CityIDs {
			if city := w.City(cityID); city != nil {
				city.OwnerID = 0
				city.PrefectID = 0
				city.OfficeGeneralId = nil
			}
		}
		country.CityIDs = nil
		return
	}
	// 继承人继位
	country.CountryKingId = inheritID
	if ig := w.General(inheritID); ig != nil {
		ig.SetLoyalty(100)
	}
	for _, cityID := range country.CityIDs {
		if city := w.City(cityID); city != nil {
			city.OwnerID = inheritID
		}
	}
	w.removeGeneralFromAllCities(gid)
}

// removeGeneralFromAllCities 从所有城池的武将数组移除
func (w *World) removeGeneralFromAllCities(gid int) {
	for _, city := range w.Cities {
		city.RemoveOfficerID(w, gid)
		city.RemoveReservedGeneralID(gid)
		city.RemoveNotFoundGeneralID(gid)
		city.RemoveCapture(gid)
	}
}

// getInheritGeneralID 选择继承人（对应 get_inherit_general_id）
func (w *World) getInheritGeneralID(country *entities.Country) int {
	for _, id := range country.Inheritors {
		g := w.General(id)
		if g != nil {
			for _, cityID := range country.CityIDs {
				city := w.City(cityID)
				if city != nil {
					for _, oid := range city.GetOfficerIds() {
						if oid == id {
							return id
						}
					}
				}
			}
		}
	}
	// 在势力武将中选评分最高者
	maxValue := 0
	generalID := 0
	for _, cityID := range country.CityIDs {
		city := w.City(cityID)
		if city == nil {
			continue
		}
		for _, id := range city.GetOfficerIds() {
			if g := w.General(id); g != nil {
				score := g.Wisdom + g.Lead + g.Charm
				if score > maxValue {
					maxValue = score
					generalID = id
				}
			}
		}
	}
	return generalID
}
