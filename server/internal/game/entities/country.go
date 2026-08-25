package entities

// Country 势力，对应 scripts/data/country.gd
type Country struct {
	CountryId     int        `json:"countryId"`
	CountryKingId int        `json:"countryKingId"`
	CountryColor  string     `json:"countryColor"`
	CanBeChoose   bool       `json:"canBeChoose"`
	Inheritors    []int      `json:"inheritors"`
	CityIDs       []int      `json:"cityIDs"`
	AllianceList  []*Alliance `json:"allianceList"` // 已补齐：原 GDScript 未序列化

	rand Rander // 会话随机源（World 注入，不序列化）
}

// KingName 返回君主名
func (c *Country) KingName(w WorldRef) string {
	if g := w.General(c.CountryKingId); g != nil {
		return g.GeneralName
	}
	return ""
}

// GetHaveCityNum 势力拥有城池数
func (c *Country) GetHaveCityNum() int { return len(c.CityIDs) }

// FindKingCity 返回君主所在城池（对应 find_king_city）
func (c *Country) FindKingCity(w WorldRef) int {
	for _, cityID := range c.CityIDs {
		if city := w.City(cityID); city != nil && city.PrefectID == c.CountryKingId {
			return cityID
		}
	}
	return 0
}

// IsEndangered 势力是否危急（≤1城）
func (c *Country) IsEndangered() bool { return len(c.CityIDs) <= 1 }

// IsDestroyed 势力是否灭亡（0城）
func (c *Country) IsDestroyed() bool { return len(c.CityIDs) <= 0 }

// RemoveAlliance 移除同盟（对应 remove_alliance，单侧移除）
func (c *Country) RemoveAlliance(countryID int) {
	for i, a := range c.AllianceList {
		if a.CountryId == countryID {
			c.AllianceList = append(c.AllianceList[:i], c.AllianceList[i+1:]...)
			return
		}
	}
}

// randRange 使用注入的随机源取 [min,max]，未注入则返回 min
func (c *Country) randRange(min, max int) int {
	if c.rand != nil {
		return c.rand.IntRange(min, max)
	}
	return min
}

// AddCity 增加城池
func (c *Country) AddCity(w WorldRef, cityID int) bool {
	if cityID == 0 {
		return false
	}
	for _, id := range c.CityIDs {
		if id == cityID {
			return true
		}
	}
	if city := w.City(cityID); city != nil {
		city.OwnerID = c.CountryKingId
	}
	c.CityIDs = append(c.CityIDs, cityID)
	return true
}

// RemoveCity 移除城池
func (c *Country) RemoveCity(w WorldRef, cityID int) bool {
	if cityID == 0 {
		return false
	}
	idx := -1
	for i, id := range c.CityIDs {
		if id == cityID {
			idx = i
			break
		}
	}
	if idx == -1 {
		return false
	}
	if city := w.City(cityID); city != nil {
		city.PrefectID = 0
		city.OwnerID = 0
	}
	c.CityIDs = append(c.CityIDs[:idx], c.CityIDs[idx+1:]...)
	return true
}
