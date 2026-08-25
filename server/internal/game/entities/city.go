package entities

// City 城池，对应 scripts/data/city.gd
type City struct {
	CityID   int    `json:"cityID"`
	CityName string `json:"cityName"`
	OwnerID  int    `json:"ownerID"`  // 所属君主ID
	PrefectID int   `json:"prefectID"` // 太守ID
	Rule     int    `json:"rule"`     // 统治度 0-99
	Money    int    `json:"money"`
	Grain    int    `json:"grain"`
	Treasures int   `json:"treasures"`
	Prevention int  `json:"prevention"` // 防灾 0-99
	Agriculture int `json:"agriculture"`
	Commerce int    `json:"commerce"`
	Population int  `json:"population"`
	ReserveSoldiers int `json:"reserveSoldiers"`

	CitySchool     bool `json:"citySchool"`
	CityGrainShop  bool `json:"cityGrainShop"`
	CityHospital   bool `json:"cityHospital"`
	CityWeaponShop int  `json:"cityWeaponShop"`
	WarWeaponShop  int  `json:"warWeaponShop"`

	// 已补齐：原 GDScript 未序列化的 4 个武将数组
	OfficeGeneralId   []int `json:"officeGeneralId"`   // 官职（在职）
	ReservedGeneralId []int `json:"reservedGeneralId"` // 在野
	NotFoundGeneralId []int `json:"notFoundGeneralId"` // 隐居（上限10）
	JailGeneralId     []int `json:"jailGeneralId"`     // 监狱

	ConnectCityId []int `json:"connectCityId"`
	MapPosition   []int `json:"mapPosition"`

	rand Rander // 会话随机源（World 注入，不序列化）
}

const (
	MaxRule    = 99
	MaxMoney   = 30000
	MaxGrain   = 30000
	MaxAgro    = 30000
	MaxTrade   = 30000
	MaxPop     = 999999
	MaxOfficer = 10
)

// ---- 基础访问器 ----

func (c *City) GetRule() int { return c.Rule }
func (c *City) SetRule(v int) { c.Rule = clamp(v, 0, MaxRule) }
func (c *City) AddRule(v int) { c.SetRule(c.Rule + v) }
func (c *City) SubRule(v int) { c.SetRule(c.Rule - v) }

func (c *City) SetMoney(v int) {
	if v > MaxMoney || v < 0 {
		c.Money = MaxMoney
	} else {
		c.Money = v
	}
}
func (c *City) GetMoney() int { return c.Money }

func (c *City) AddGold(v int) int {
	if c.Money+v > MaxMoney || c.Money+v < 0 {
		v = MaxMoney - c.Money
		c.Money = MaxMoney
	} else {
		c.Money += v
	}
	return v
}
func (c *City) SubGold(v int) int {
	if c.Money-v > MaxMoney || c.Money-v < 0 {
		v = c.Money
		c.Money = 0
	} else {
		c.Money -= v
	}
	return v
}

func (c *City) SetFood(v int) {
	if v > MaxGrain || v < 0 {
		c.Grain = MaxGrain
	} else {
		c.Grain = v
	}
}
func (c *City) GetFood() int { return c.Grain }
func (c *City) AddFood(v int) int {
	if c.Grain+v > MaxGrain || c.Grain+v < 0 {
		v = MaxGrain - c.Grain
		c.Grain = MaxGrain
	} else {
		c.Grain += v
	}
	return v
}
func (c *City) SubFood(v int) int {
	if c.Grain-v > MaxGrain || c.Grain-v < 0 {
		v = c.Grain
		c.Grain = 0
	} else {
		c.Grain -= v
	}
	return v
}

func (c *City) GetTreasureNum() int { return c.Treasures }
func (c *City) SetTreasureNum(v int) { c.Treasures = clamp(v, 0, 100) }
func (c *City) AddTreasureNum(v int) int {
	if c.Treasures+v > 100 || c.Treasures+v < 0 {
		v = 100 - c.Treasures
		c.Treasures = 100
	} else {
		c.Treasures += v
	}
	return v
}
func (c *City) SubTreasureNum(v int) int {
	if c.Treasures-v > 100 || c.Treasures-v < 0 {
		v = c.Treasures
		c.Treasures = 0
	} else {
		c.Treasures -= v
	}
	return v
}

func (c *City) GetAgro() int { return c.Agriculture }
func (c *City) SetAgro(v int) { c.Agriculture = clamp(v, 0, MaxAgro) }
func (c *City) AddAgro(v int) { c.SetAgro(c.Agriculture + v) }
func (c *City) SubAgro(v int) { c.SetAgro(c.Agriculture - v) }

func (c *City) GetTrade() int { return c.Commerce }
func (c *City) SetTrade(v int) { c.Commerce = clamp(v, 0, MaxTrade) }
func (c *City) AddTrade(v int) { c.SetTrade(c.Commerce + v) }
func (c *City) SubTrade(v int) { c.SetTrade(c.Commerce - v) }

func (c *City) GetFloodControl() int { return c.Prevention }
func (c *City) SetFloodControl(v int) { c.Prevention = clamp(v, 0, MaxRule) }
func (c *City) AddFloodControl(v int) { c.SetFloodControl(c.Prevention + v) }
func (c *City) SubFloodControl(v int) { c.SetFloodControl(c.Prevention - v) }

func (c *City) GetPopulation() int { return c.Population }
func (c *City) SetPopulation(v int) {
	if v < 0 {
		c.Population = 0
	} else if v > MaxPop {
		c.Population = MaxPop
	} else {
		c.Population = v
	}
}
func (c *City) AddPopulation(v int) int {
	if c.Population+v > MaxPop || c.Population+v < 0 {
		v = MaxPop - c.Population
		c.Population = MaxPop
	} else {
		c.Population += v
	}
	return v
}
func (c *City) SubPopulation(v int) int {
	if c.Population-v > MaxPop || c.Population-v < 0 {
		v = c.Population
		c.Population = 0
	} else {
		c.Population -= v
	}
	return v
}

// GetPrefectId 太守
func (c *City) GetPrefectId() int { return c.PrefectID }

// GetOfficerIds 在职武将（>0）
func (c *City) GetOfficerIds() []int {
	var r []int
	for _, gid := range c.OfficeGeneralId {
		if gid > 0 {
			r = append(r, gid)
		}
	}
	return r
}

// GetCityOfficerNum 在职武将数
func (c *City) GetCityOfficerNum() int {
	n := 0
	for _, gid := range c.OfficeGeneralId {
		if gid > 0 {
			n++
		}
	}
	return n
}

// GetTalentIds 在野武将
func (c *City) GetTalentIds() []int {
	var r []int
	for _, gid := range c.ReservedGeneralId {
		if gid > 0 {
			r = append(r, gid)
		}
	}
	return r
}

// GetRecluseIds 隐居武将
func (c *City) GetRecluseIds() []int {
	var r []int
	for _, gid := range c.NotFoundGeneralId {
		if gid > 0 {
			r = append(r, gid)
		}
	}
	return r
}

// GetCaptureList 监狱武将
func (c *City) GetCaptureList() []int { return c.JailGeneralId }

// randRange 使用注入的随机源取 [min,max]，未注入则返回 min（幂等降级）
func (c *City) randRange(min, max int) int {
	if c.rand != nil {
		return c.rand.IntRange(min, max)
	}
	return min
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

// ---- 经济收入 ----

// MoneyIncome 金钱收入（对应 money_income）
func (c *City) MoneyIncome() int {
	l1 := c.Population/400 + 1
	i2 := l1 * c.Commerce * 3 / 5 / 125
	l1 += i2
	i2 = 0
	if c.Rule > 90 {
		i2 += l1 * 4 / 5
	} else if c.Rule > 80 {
		i2 += l1 * 3 / 5
	} else if c.Rule > 70 {
		i2 += l1 * 2 / 5
	} else if c.Rule > 50 {
		i2 += l1 / 5
	}
	l1 += i2
	return l1
}

// FoodIncome 粮食收入（对应 food_income）
func (c *City) FoodIncome() int {
	l1 := c.Population / 100
	i2 := l1 * c.Agriculture * 4 / 5 / 125
	l1 += i2
	i2 = 0
	if c.Rule > 90 {
		i2 += l1 * 4 / 5
	} else if c.Rule > 80 {
		i2 += l1 * 3 / 5
	} else if c.Rule > 70 {
		i2 += l1 * 2 / 5
	} else if c.Rule > 50 {
		i2 += l1 / 5
	}
	l1 += i2
	return l1
}

// SoldierEatFood 军队吃粮（对应 soldier_eat_food）
func (c *City) SoldierEatFood(w WorldRef) {
	need := c.GetAlreadySoldierNum(w)/100 + c.ReserveSoldiers/300
	if need > c.Grain {
		c.Grain = 0
		if c.ReserveSoldiers-100 < 0 {
			c.ReserveSoldiers = 0
		} else {
			c.ReserveSoldiers -= 100
		}
		for _, gid := range c.OfficeGeneralId {
			if g := w.General(gid); g != nil && g.Soldiers-100 < 0 {
				g.Soldiers = 0
			} else if g != nil {
				g.Soldiers -= 100
			}
		}
	} else {
		c.Grain -= need
	}
}

// PaySalaries 发薪（对应 pay_salaries）
func (c *City) PaySalaries(w WorldRef) {
	for _, gid := range c.OfficeGeneralId {
		g := w.General(gid)
		if g == nil {
			continue
		}
		if c.Money <= 0 {
			if g.GeneralId != c.OwnerID {
				g.SubLoyalty(c.randRange(0, 3) + 1)
			}
		} else {
			c.SubGold(g.GetSalary())
		}
	}
}

// GetAlreadySoldierNum 已出兵数（对应 get_already_soldier_num）
func (c *City) GetAlreadySoldierNum(w WorldRef) int {
	n := 0
	for _, gid := range c.OfficeGeneralId {
		if gid > 0 {
			if g := w.General(gid); g != nil {
				n += g.Soldiers
			}
		}
	}
	return n
}

// GetMaxSoldierNum 带兵上限和（对应 get_max_soldier_num）
func (c *City) GetMaxSoldierNum(w WorldRef) int {
	n := 0
	for _, gid := range c.OfficeGeneralId {
		if gid > 0 {
			if g := w.General(gid); g != nil {
				n += g.GetMaxSoldierNum()
			}
		}
	}
	return n
}

// GetCityAllSoldierNum 全城兵力和（对应 get_city_all_soldier_num）
func (c *City) GetCityAllSoldierNum(w WorldRef) int {
	return c.GetAlreadySoldierNum(w) + c.ReserveSoldiers
}

// GetMaxConscriptSoldierNum 最大征兵数（对应 get_max_conscript_soldier_num）
func (c *City) GetMaxConscriptSoldierNum(w WorldRef) int {
	gold := c.Money * 5
	rule := c.Rule * 500
	pop := c.Population * 2 / 3
	diff := c.GetMaxSoldierNum(w) - c.GetCityAllSoldierNum(w)
	v := gold
	if rule < v {
		v = rule
	}
	if pop < v {
		v = pop
	}
	if diff < v {
		v = diff
	}
	if 30000 < v {
		v = 30000
	}
	return v
}

// Conscript 征兵（对应 conscript）
func (c *City) Conscript(n int) {
	c.ReserveSoldiers += n
	c.SubGold((n + 4) / 5)
	c.SubRule(n / 500)
	if c.Population*2 < n*3 {
		c.Population = 0
	} else {
		c.Population -= n * 3 / 2
	}
}

// GetMaxAtkPower 最大攻击战力（对应 get_max_atk_power）
func (c *City) GetMaxAtkPower(w WorldRef, playerCountryId int) int {
	officers := c.GetOfficerIds()
	if len(officers) == 0 {
		return 0
	}
	var powers []float64
	for _, gid := range officers {
		if g := w.General(gid); g != nil {
			powers = append(powers, g.GetBattlePower(w))
		}
	}
	total := 0.0
	for _, p := range powers {
		total += p
	}
	if c.OwnerID != 0 {
		if country := w.CountryByKingId(c.OwnerID); country != nil && country.CountryId != playerCountryId {
			minP := powers[0]
			for _, p := range powers {
				if p < minP {
					minP = p
				}
			}
			total -= minP
		} else {
			total *= 1.2
		}
	}
	needFood := c.GetAlreadySoldierNum(w)/8 + 1
	if c.Grain < needFood {
		total = total * float64(c.Grain) / float64(needFood)
	}
	needMoney := c.GetMaxSoldierNum(w) / 10
	if c.Money > needMoney {
		total = total * 5.0 / 3.0
	}
	return int(total)
}

// GetDefenseAbility 防御战力（对应 get_defense_ability）
func (c *City) GetDefenseAbility(w WorldRef, playerCountryId int) int {
	if country := w.CountryByKingId(c.OwnerID); country != nil && country.CountryId == playerCountryId {
		return int(c.GetCityDefPower(w) * 1.2)
	}
	return int(c.GetCityDefPower(w))
}

// GetCityDefPower 城池防御战力（对应 get_city_def_power）
func (c *City) GetCityDefPower(w WorldRef) float64 {
	power := 0.0
	for _, gid := range c.GetOfficerIds() {
		g := w.General(gid)
		if g == nil {
			continue
		}
		if gid == c.PrefectID {
			power += g.GetBattlePower(w) * 1.2
		} else {
			power += g.GetBattlePower(w)
		}
	}
	needFood := len(c.GetOfficerIds())/8 + 1
	if c.Grain < needFood {
		power = power * float64(c.Grain) / float64(needFood)
	}
	return power
}

// ---- 内政指令 ----

// Search 搜索（对应 search），返回结果文本
func (c *City) Search(w WorldRef, generalID int, texts []string) string {
	g := w.General(generalID)
	if g == nil {
		return ""
	}
	g.SubHp(2)
	task := c.determineSearchResult(w, g)
	reward := 0
	var result string
	switch task {
	case 14: // SEARCH_MONEY 金钱
		reward = c.randRange(0, 29) + (g.Wisdom+g.Charm*2)/4
		if g.HasSkill4(4) {
			reward += reward / 2
		}
		c.AddGold(reward)
		result = texts[1] + itoa(reward) + "两"
	case 15: // SEARCH_FOOD 粮食
		reward = c.randRange(0, 39) + (g.Wisdom+g.Charm*3)/4
		if g.HasSkill4(4) {
			reward += reward / 2
		}
		c.AddFood(reward)
		result = texts[2] + itoa(reward) + "石"
	case 17: // SEARCH_GENERAL 发现武将
		notFound := c.GetRecluseIds()
		if len(notFound) > 0 {
			fid := notFound[c.randRange(0, len(notFound)-1)]
			fg := w.General(fid)
			c.RemoveNotFoundGeneralID(fid)
			c.AddReservedGeneralID(w, fid)
			if fg != nil {
				result = texts[3] + fg.GeneralName
			}
		}
	case 16: // SEARCH_TREASURE 宝物
		reward = 2
		if !g.HasSkill4(4) {
			reward = 1
		}
		c.AddTreasureNum(reward)
		result = texts[4] + itoa(reward) + "件"
	default: // SEARCH_NOTHING 一无所获
		result = texts[0]
	}
	return result
}

// DetermineSearchResult 判定搜索结果类型（对应 _determine_search_result）
func (c *City) determineSearchResult(w WorldRef, g *General) int {
	randomValue := c.randRange(0, 99)
	notFoundNum := c.getCityNotFoundGeneralNum()
	if notFoundNum > 0 {
		if g.HasSkill4(4) {
			return 17 // SEARCH_GENERAL
		}
		if g.Wisdom >= 60 && g.Charm >= 70 {
			return 17
		}
		if randomValue >= 60 {
			return 17
		}
	}
	if randomValue > g.Wisdom && !g.HasSkill3(4) {
		return 18 // SEARCH_NOTHING
	}
	if g.HasSkill4(4) {
		if randomValue <= 40 && c.Money < 30000 {
			return 14 // SEARCH_MONEY
		}
		if randomValue <= 80 && c.Grain < 30000 {
			return 15 // SEARCH_FOOD
		}
		return 16 // SEARCH_TREASURE
	}
	if randomValue < 10 {
		return 16
	}
	if randomValue < 50 && c.Money < 30000 {
		return 14
	}
	if randomValue < 90 && c.Grain < 30000 {
		return 15
	}
	return 18
}

// GetCityNotFoundGeneralNum 隐居武将数（>0）
func (c *City) getCityNotFoundGeneralNum() int {
	n := 0
	for _, gid := range c.NotFoundGeneralId {
		if gid > 0 {
			n++
		}
	}
	return n
}

// RemoveNotFoundGeneralID 移除隐居武将
func (c *City) RemoveNotFoundGeneralID(gid int) {
	for i, id := range c.NotFoundGeneralId {
		if id == gid {
			c.NotFoundGeneralId = append(c.NotFoundGeneralId[:i], c.NotFoundGeneralId[i+1:]...)
			return
		}
	}
}

// AddReservedGeneralID 添加在野武将（对应 add_reserved_general_id）
func (c *City) AddReservedGeneralID(w WorldRef, gid int) bool {
	if c.GetReservedGeneralNum() > 9 {
		return false
	}
	for i, id := range c.OfficeGeneralId {
		if id == gid {
			c.OfficeGeneralId = append(c.OfficeGeneralId[:i], c.OfficeGeneralId[i+1:]...)
			break
		}
	}
	g := w.General(gid)
	if g == nil {
		return false
	}
	g.Status = 0
	g.DebutCity = c.CityID
	c.ReservedGeneralId = append(c.ReservedGeneralId, gid)
	return true
}

// GetReservedGeneralNum 在野武将数
func (c *City) GetReservedGeneralNum() int {
	n := 0
	for _, gid := range c.ReservedGeneralId {
		if gid > 0 {
			n++
		}
	}
	return n
}

// RemoveReservedGeneralID 移除在野武将
func (c *City) RemoveReservedGeneralID(gid int) {
	for i, id := range c.ReservedGeneralId {
		if id == gid {
			c.ReservedGeneralId = append(c.ReservedGeneralId[:i], c.ReservedGeneralId[i+1:]...)
			return
		}
	}
}

// IsEmploy 登用（对应 is_employ）
func (c *City) IsEmploy(w WorldRef, doGeneralID, beGeneralID int, phaseDiff func(a, b *General) int) bool {
	doGen := w.General(doGeneralID)
	beGen := w.General(beGeneralID)
	kingGen := w.General(c.OwnerID)
	if beGen == nil {
		return false
	}
	var d1, d2 int
	if kingGen != nil {
		d1 = phaseDiff(kingGen, beGen)
	}
	if doGen != nil {
		d2 = phaseDiff(doGen, beGen)
	}
	i := c.randRange(0, 74)
	if (d1+d2)/2 < i {
		if doGen != nil {
			doGen.AddMoralExp(c.randRange(10, 24))
			doGen.AddIqExp(c.randRange(4, 9))
		}
		c.AddOfficeGeneralID(w, beGeneralID)
		c.RemoveReservedGeneralID(beGeneralID)
		return true
	}
	return false
}
// AddOfficeGeneralID 添加在职武将（对应 add_office_general_id，含太守设定/人数上限处理）
func (c *City) AddOfficeGeneralID(w WorldRef, gid int) bool {
	if gid == 0 {
		return false
	}
	g := w.General(gid)
	if g == nil {
		c.RemoveOfficerID(w, gid)
		return false
	}
	if len(c.OfficeGeneralId) == 0 {
		c.OfficeGeneralId = []int{gid}
		c.PrefectID = gid
		g.Status = 1
		g.DebutCity = c.CityID
		return true
	}
	for _, id := range c.OfficeGeneralId {
		if id == gid {
			return true
		}
	}
	g.Status = 1
	g.DebutCity = c.CityID
	generalNum := c.GetCityOfficerNum()
	if generalNum > 9 {
		minID := c.GetMinBattlePowerGeneralID(w)
		if c.IsKingOf(gid, w) {
			for i, id := range c.OfficeGeneralId {
				if id == minID {
					c.OfficeGeneralId[i] = c.OfficeGeneralId[0]
					c.OfficeGeneralId[0] = gid
					c.PrefectID = gid
					c.AddNotFoundGeneralID(w, minID)
					return true
				}
			}
		} else {
			generalScore := g.AllStatus()
			minGen := w.General(minID)
			if minGen != nil && generalScore > minGen.AllStatus() {
				for i, id := range c.OfficeGeneralId {
					if id == minID {
						c.OfficeGeneralId[i] = gid
						if i == 0 {
							c.PrefectID = gid
						}
						c.AddNotFoundGeneralID(w, minID)
						return true
					}
				}
			} else {
				c.AddNotFoundGeneralID(w, gid)
				return false
			}
		}
	} else {
		if c.IsKingOf(gid, w) {
			if generalNum != 0 {
				temp := c.OfficeGeneralId[0]
				c.OfficeGeneralId = append(c.OfficeGeneralId, temp)
			}
			c.OfficeGeneralId[0] = gid
			c.PrefectID = gid
			return true
		}
		c.OfficeGeneralId = append(c.OfficeGeneralId, gid)
		if len(c.OfficeGeneralId) == 1 {
			c.PrefectID = gid
		}
		return true
	}
	return false
}

// IsKingOf 该武将是否某势力的君主
func (c *City) IsKingOf(gid int, w WorldRef) bool {
	return w.CountryByKingId(gid) != nil
}

// RemoveOfficerID 移除在职武将（对应 remove_officer_id）
func (c *City) RemoveOfficerID(w WorldRef, gid int) bool {
	idx := -1
	for i, id := range c.OfficeGeneralId {
		if id == gid {
			idx = i
			break
		}
	}
	if idx == -1 {
		return false
	}
	c.OfficeGeneralId = append(c.OfficeGeneralId[:idx], c.OfficeGeneralId[idx+1:]...)
	if c.GetCityOfficerNum() < 1 {
		w.RemoveCityFromCountry(c.OwnerID, c.CityID)
		c.PrefectID = 0
	} else if c.PrefectID == gid {
		c.AutoAppointPrefect(w)
	}
	return true
}

// AddNotFoundGeneralID 添加隐居武将（对应 add_not_found_general_id）
func (c *City) AddNotFoundGeneralID(w WorldRef, gid int) bool {
	if gid <= 0 {
		return false
	}
	if len(c.NotFoundGeneralId) >= 10 {
		w.GeneralDie(gid)
		return false
	}
	if g := w.General(gid); g != nil {
		g.Status = 0
		g.DebutCity = c.CityID
		c.NotFoundGeneralId = append(c.NotFoundGeneralId, gid)
	}
	return true
}

// GetMinBattlePowerGeneralID 战力最低武将ID（对应 get_min_battle_power_general_id）
func (c *City) GetMinBattlePowerGeneralID(w WorldRef) int {
	ids := c.GetOfficerIds()
	minID := 0
	minP := 1e18
	for _, gid := range ids {
		if g := w.General(gid); g != nil {
			p := g.GetBattlePower(w)
			if p < minP {
				minP = p
				minID = gid
			}
		}
	}
	return minID
}

// AutoAppointPrefect 自动任命太守（对应 auto_appoint_prefect）
func (c *City) AutoAppointPrefect(w WorldRef) {
	arr := c.GetOfficerIds()
	if len(arr) == 0 {
		return
	}
	if len(arr) == 1 {
		c.PrefectID = arr[0]
		return
	}
	prefectValue := 0
	id := 0
	i1 := 0
	for i, gid := range arr {
		g := w.General(gid)
		if g == nil {
			continue
		}
		if gid == c.OwnerID {
			prefectValue = 1000
			id = gid
			i1 = i
			break
		}
		if g.GetLoyalty() >= 60 && g.GetWarValue() > prefectValue {
			prefectValue = g.GetWarValue()
			id = arr[i]
			i1 = i
		}
	}
	if prefectValue == 0 {
		i1 = 0
		id = arr[0]
		for i := 1; i < len(arr); i++ {
			g0 := w.General(id)
			gi := w.General(arr[i])
			if g0 != nil && gi != nil && g0.GetLoyalty() < gi.GetLoyalty() {
				id = arr[i]
				i1 = i
			}
		}
	}
	c.PrefectID = id
	arr = append(arr[:i1], arr[i1+1:]...)
	arr = append([]int{id}, arr...)
	c.OfficeGeneralId = arr
}

// ---- 开垦/劝商/治水/巡查 ----

// Reclaim 开垦（对应 reclaim），返回实际增加量
func (c *City) Reclaim(w WorldRef, g *General, useMoney int) int {
	contribution := (g.Force + g.Govern*2) / 3
	g.SubHp(2)
	g.AddExperience(c.randRange(0, 49) + 10)
	g.AddPoliticalExp(10)
	val := 1
	if contribution >= 12 {
		val = (contribution * useMoney / 100) / 2
	}
	val += c.randRange(0, val) / 2
	if g.HasSkill4(0) {
		val += val / 4
	} else if g.HasSkill4(2) {
		val += val / 3
	}
	c.SubGold(useMoney)
	actual := val
	if actual > 999-c.Agriculture {
		actual = 999 - c.Agriculture
	}
	if actual < 0 {
		actual = 0
	}
	c.Agriculture += actual
	return actual
}

// Mercantile 劝商（对应 mercantile），返回实际增加量
func (c *City) Mercantile(w WorldRef, g *General, useMoney int) int {
	contribution := (g.Wisdom + g.Govern*2) / 3
	g.SubHp(2)
	g.AddExperience(c.randRange(0, 49) + 10)
	g.AddPoliticalExp(10)
	val := 1
	if contribution >= 12 {
		val = (contribution * useMoney / 100) / 2
	}
	val += c.randRange(0, val) / 2
	if g.HasSkill4(0) {
		val += val / 4
	} else if g.HasSkill4(3) {
		val += val / 3
	}
	c.SubGold(useMoney)
	actual := val
	if actual > 999-c.Commerce {
		actual = 999 - c.Commerce
	}
	if actual < 0 {
		actual = 0
	}
	c.Commerce += actual
	return actual
}

// Tame 治水（对应 tame），返回实际增加量
func (c *City) Tame(w WorldRef, g *General, useMoney int) int {
	contribution := (g.Lead + g.Govern*2) / 4
	g.SubHp(2)
	g.AddExperience(c.randRange(0, 49) + 10)
	g.AddPoliticalExp(10)
	val := 1
	if contribution >= 10 {
		val = (contribution * useMoney / 100) / 2
	}
	val += c.randRange(0, val) / 3
	if g.HasSkill4(0) {
		val += val / 4
	}
	c.SubGold(useMoney)
	actual := val
	if actual > 99-c.Prevention {
		actual = 99 - c.Prevention
	}
	if actual < 0 {
		actual = 0
	}
	if c.Rule < 99 {
		if actual >= 5 {
			c.AddRule(2)
		} else {
			c.AddRule(1)
		}
	}
	c.Prevention += actual
	return actual
}

// Patrol 巡查（对应 patrol），返回实际增加量
func (c *City) Patrol(w WorldRef, g *General, useMoney int) int {
	contribution := (g.Wisdom + g.Charm*2 + g.Govern*2) / 5
	g.SubHp(2)
	g.AddExperience(c.randRange(0, 49) + 10)
	g.AddPoliticalExp(10)
	g.AddMoralExp(10)
	val := 500
	if contribution >= 50 {
		val = contribution * useMoney
	}
	if g.HasSkill4(0) {
		val += val / 4
	} else if g.HasSkill4(1) {
		val += val / 3
	}
	c.SubGold(useMoney)
	actual := val
	if actual > 999999-c.Population {
		actual = 999999 - c.Population
	}
	if actual < 0 {
		actual = 0
	}
	if c.Rule < 99 {
		if actual >= 2500 {
			c.AddRule(3)
		} else if actual >= 1500 {
			c.AddRule(2)
		} else {
			c.AddRule(1)
		}
	}
	c.Population += actual
	return actual
}

// Reward 奖赏（对应 reward）
func (c *City) Reward(w WorldRef, gid int, useTreasure bool) {
	g := w.General(gid)
	if g == nil {
		return
	}
	if useTreasure {
		c.Treasures--
		g.RewardAddLoyalty(false)
	} else {
		c.SubGold(100)
		g.RewardAddLoyalty(true)
	}
}

// ---- 武将选择 ----

// GetDoReclaimMercantileOfficer 选择最优开垦/劝商武将（对应 get_do_reclaim_mercantile_officer）
func (c *City) GetDoReclaimMercantileOfficer(w WorldRef) *General {
	arr := c.GetOfficerIds()
	if len(arr) == 0 {
		return nil
	}
	best := w.General(c.PrefectID)
	if best == nil {
		best = w.General(arr[0])
	}
	if best == nil {
		return nil
	}
	bestScore := best.Wisdom + best.Govern*2
	for i := 1; i < len(arr); i++ {
		g := w.General(arr[i])
		if g == nil {
			continue
		}
		score := g.Wisdom + g.Govern*2
		if g.HasSkill3(2) || g.HasSkill3(3) {
			score = int(float64(score) * 1.33)
		} else if g.HasSkill3(0) {
			score = int(float64(score) * 1.25)
		}
		if score > bestScore {
			bestScore = score
			best = g
		}
	}
	return best
}

// GetDoPatrolOfficer 选择最优巡查武将（对应 get_do_patrol_officer）
func (c *City) GetDoPatrolOfficer(w WorldRef) *General {
	arr := c.GetOfficerIds()
	if len(arr) == 0 {
		return nil
	}
	best := w.General(c.PrefectID)
	if best == nil {
		best = w.General(arr[0])
	}
	if best == nil {
		return nil
	}
	bestScore := best.Wisdom + best.Govern*2 + best.Charm*2
	for i := 1; i < len(arr); i++ {
		g := w.General(arr[i])
		if g == nil {
			continue
		}
		score := g.Wisdom + g.Govern*2 + g.Charm*2
		if g.HasSkill3(1) {
			score = int(float64(score) * 1.33)
		} else if g.HasSkill3(0) {
			score = int(float64(score) * 1.25)
		}
		if score > bestScore {
			bestScore = score
			best = g
		}
	}
	return best
}

// GetDoSearchOfficer 选择最优搜索武将ID（对应 get_do_search_officer）
func (c *City) GetDoSearchOfficer(w WorldRef) int {
	arr := c.GetOfficerIds()
	if len(arr) == 0 {
		return 0
	}
	gid := arr[0]
	best := w.General(gid)
	if best == nil {
		return gid
	}
	bestScore := best.Wisdom + best.Charm/2
	for i := 1; i < len(arr); i++ {
		g := w.General(arr[i])
		if g == nil {
			continue
		}
		score := g.Wisdom + g.Charm/2
		if bestScore < score {
			gid = arr[i]
			bestScore = score
		}
	}
	return gid
}

// RemoveCapture 移除监狱武将（对应 remove_capture）
func (c *City) RemoveCapture(gid int) bool {
	if gid == 0 {
		return false
	}
	for i, id := range c.JailGeneralId {
		if id == gid {
			c.JailGeneralId = append(c.JailGeneralId[:i], c.JailGeneralId[i+1:]...)
			return true
		}
	}
	return false
}

// AddCapture 添加监狱武将（对应 add_capture，忠诚随机45-69）
func (c *City) AddCapture(w WorldRef, gid int) bool {
	if gid == 0 {
		return false
	}
	for _, id := range c.JailGeneralId {
		if id == gid {
			return false
		}
	}
	g := w.General(gid)
	if g == nil {
		return false
	}
	g.SetLoyalty(c.randRange(45, 69))
	c.JailGeneralId = append(c.JailGeneralId, gid)
	return true
}

// IsRebel 是否起义（对应 is_rebel）
func (c *City) IsRebel(w WorldRef) bool {
	if c.OwnerID == 0 || c.PrefectID == 0 {
		return false
	}
	prefect := w.General(c.PrefectID)
	oldCountry := w.CountryByKingId(c.OwnerID)
	if prefect == nil || oldCountry == nil {
		return false
	}
	if prefect.GetLoyalty() > 90 || c.OwnerID == c.PrefectID {
		return false
	}
	loyalty := 100 - prefect.GetLoyalty()
	king := w.General(c.OwnerID)
	if king == nil {
		return false
	}
	phaseDiff := phaseDifference(prefect.Phase, king.Phase)
	if loyalty < 10 || phaseDiff < 5 {
		return false
	}
	threshold := loyalty - 5 + phaseDiff/2 - oldCountry.GetHaveCityNum() - (king.Charm-80)/9 - w.CountryCount()/2
	threshold /= 2
	if threshold <= 0 {
		return false
	}
	randomValue := c.randRange(0, 99) / threshold
	if randomValue > 0 {
		return false
	}
	maxAttackPower := 0
	for _, tempCityID := range c.ConnectCityId {
		if tempCity := w.City(tempCityID); tempCity != nil {
			ap := tempCity.GetMaxAtkPower(w, playerCountryIdOf(w))
			if ap > maxAttackPower {
				maxAttackPower = ap
			}
		}
	}
	if c.GetDefenseAbility(w, playerCountryIdOf(w)) < maxAttackPower*7/10 {
		return false
	}
	return true
}

// phaseDifference 相性差计算（与 game.PhaseDiff 一致）
func phaseDifference(a, b int) int {
	d := a - b
	if d < 0 {
		d = -d
	}
	if d > 74 {
		d = 149 - d
	}
	return d
}

// playerCountryIdOf 获取玩家势力 id（通过 WorldRef 扩展接口）
func playerCountryIdOf(w WorldRef) int {
	if pw, ok := w.(interface{ PlayerCountryId() int }); ok {
		return pw.PlayerCountryId()
	}
	return 0
}

// AppointPrefect 任命太守（对应 appoint_prefect）
func (c *City) AppointPrefect(w WorldRef, gid int) {
	if gid == 0 {
		return
	}
	found := -1
	for i, id := range c.OfficeGeneralId {
		if id == gid {
			found = i
			break
		}
	}
	if found == -1 || found == 0 {
		return
	}
	t := c.OfficeGeneralId[0]
	c.OfficeGeneralId[0] = c.OfficeGeneralId[found]
	c.OfficeGeneralId[found] = t
	c.PrefectID = gid
}
