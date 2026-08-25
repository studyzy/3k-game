package game

import "3k-server/internal/game/entities"

// ---- 回合管理（对应 scripts/turn_manager.gd） ----

// EndPlayerTurn 玩家结束回合（对应 end_player_turn）
// 执行 AI 回合 → 月度推进 → 胜负判定 → 进入玩家下回合
func (w *World) EndPlayerTurn() {
	w.GameInfo.Task = 0 // NONE

	// AI 回合：遍历回合序，跳过玩家
	for _, cid := range w.CountrySequence {
		if cid == w.GameInfo.PlayerCountryId {
			continue
		}
		country := w.Country(cid)
		if country == nil || country.GetHaveCityNum() <= 0 {
			continue
		}
		w.aiTurn(country)
	}

	// 月度推进
	w.AddMonth()

	// 胜负判定
	if w.checkGameEnd() {
		return
	}

	// 开始玩家回合
	w.GameInfo.PlayerOrderNum = w.GameInfo.GetPlayerOrderNum(w)
	w.GameInfo.DoCityId = w.Country(w.GameInfo.PlayerCountryId).FindKingCity(w)
	if w.GameInfo.DoCityId == 0 {
		if c := w.Country(w.GameInfo.PlayerCountryId); c != nil && len(c.CityIDs) > 0 {
			w.GameInfo.DoCityId = c.CityIDs[0]
		}
	}
	w.GameInfo.PlayingState = GameStatePLAYER_TURN
}

// CheckGameEnd 胜负判定（对应 _check_game_end），返回是否游戏结束
func (w *World) CheckGameEnd() bool { return w.checkGameEnd() }

func (w *World) checkGameEnd() bool {
	player := w.Country(w.GameInfo.PlayerCountryId)
	if player == nil || player.GetHaveCityNum() <= 0 {
		w.GameInfo.PlayingState = GameStateGAME_OVER
		return true
	}
	// 判断是否只剩玩家一个势力
	alive := 0
	for _, country := range w.Countries {
		if country.GetHaveCityNum() > 0 {
			alive++
		}
	}
	if alive <= 1 {
		w.GameInfo.PlayingState = GameStateGAME_WIN
		return true
	}
	return false
}

// aiTurn AI 势力回合（对应 _ai_turn）
func (w *World) aiTurn(country *entities.Country) {
	for _, cityID := range country.CityIDs {
		city := w.City(cityID)
		if city == nil {
			continue
		}
		// 收入
		city.AddGold(city.MoneyIncome())
		city.AddFood(city.FoodIncome())
		// 内政：钱多时开垦/劝商/治水/巡查
		if city.Money > 200 {
			g := city.GetDoReclaimMercantileOfficer(w)
			if g != nil {
				money := g.GetNeedMoneyOfInterior(29) // RECLAIM 开垦
				if city.Money >= money {
					city.Reclaim(w, g, money)
				}
				money = g.GetNeedMoneyOfInterior(31) // MERCANTILE 劝商
				if city.Money >= money {
					city.Mercantile(w, g, money)
				}
			}
			if city.Rule < 90 {
				patrolOfficer := city.GetDoPatrolOfficer(w)
				if patrolOfficer != nil {
					patrolMoney := patrolOfficer.GetNeedMoneyOfInterior(35) // PATROL 巡查
					if city.Money >= patrolMoney {
						city.Patrol(w, patrolOfficer, patrolMoney)
					}
				}
			}
		}
		// 搜索在野武将
		if w.Rng.Chance(0.4) {
			searchID := city.GetDoSearchOfficer(w)
			city.Search(w, searchID, w.Texts.SearchResultTexts())
		}
		// 登用在野武将
		if w.Rng.Chance(0.3) && len(city.GetTalentIds()) > 0 {
			talent := city.GetTalentIds()[0]
			officerIDs := city.GetOfficerIds()
			if len(officerIDs) > 0 {
				city.IsEmploy(w, officerIDs[0], talent, w.PhaseDiff)
			}
		}
		// 奖赏忠诚度低的武将
		for _, gid := range city.GetOfficerIds() {
			g := w.General(gid)
			if g != nil && g.Loyalty < 80 && city.Money >= 100 {
				city.Reward(w, gid, false)
			}
		}
		// 简单征兵
		if city.Money > 500 {
			n := city.GetMaxConscriptSoldierNum(w)
			if n > 0 {
				conscriptNum := n
				if 500 < n {
					conscriptNum = 500
				}
				city.Conscript(conscriptNum)
			}
		}
		// 发薪（仅 AI 回合内一次；月度统一结算在 _monthly_income）
		city.PaySalaries(w)
	}
	// 输送资源到前线（简化：把钱粮集中到第一城）
	if len(country.CityIDs) > 1 {
		firstCityID := country.CityIDs[0]
		for _, cityID := range country.CityIDs {
			if cityID == firstCityID {
				continue
			}
			city := w.City(cityID)
			if city != nil && city.Money > 1000 {
				transfer := (city.Money - 1000) / 2
				transferFood := (city.Grain - 1000) / 2
				if transferFood < 0 {
					transferFood = 0
				}
				if transfer < 0 {
					transfer = 0
				}
				w.TransportBetweenCitys(cityID, firstCityID, transferFood, transfer)
			}
		}
	}
	// 可能发动战争（简化）
	w.aiMaybeAttack(country)
}

// aiMaybeAttack AI 是否开战（对应 _ai_maybe_attack）
func (w *World) aiMaybeAttack(country *entities.Country) {
	if !w.Rng.Chance(0.3) {
		return
	}
	enemies := w.GetEnemyAdjacentCityIDArray(country.CountryId)
	if len(enemies) == 0 {
		return
	}
	targetCityID := enemies[w.Rng.IntN(len(enemies))]
	targetCity := w.City(targetCityID)
	if targetCity == nil {
		return
	}
	attackerGenerals := targetCity.GetOfficerIds()
	if len(attackerGenerals) == 0 {
		return
	}
	// 战力对比（修复原 bug：攻方用攻击出发城，守方用目标城）
	atkPower := w.CityBattlePowerOfAttacker(country, targetCityID)
	defPower := targetCity.GetMaxAtkPower(w, w.GameInfo.PlayerCountryId)
	if float64(atkPower) > float64(defPower)*1.1 {
		// 发起战争：AI 攻打目标城
		w.WarPrepare(true, targetCityID, targetCityID, attackerGenerals, 500, 1000, country.CountryId)
	}
}

// CityBattlePowerOfAttacker 攻方战力（取攻击势力可出动的城）
func (w *World) CityBattlePowerOfAttacker(country *entities.Country, targetCityID int) int {
	// 简化：取势力战力最强的城
	best := 0
	for _, cityID := range country.CityIDs {
		if city := w.City(cityID); city != nil {
			p := city.GetMaxAtkPower(w, w.GameInfo.PlayerCountryId)
			if p > best {
				best = p
			}
		}
	}
	return best
}

// GetEnemyAdjacentCityIDArray 获取相邻敌城数组（简化实现，对应 get_enemy_adjacent_city_id_array）
func (w *World) GetEnemyAdjacentCityIDArray(countryID int) []int {
	country := w.Country(countryID)
	if country == nil {
		return nil
	}
	var result []int
	for _, cityID := range country.CityIDs {
		city := w.City(cityID)
		if city == nil {
			continue
		}
		for _, neighID := range city.ConnectCityId {
			neigh := w.City(neighID)
			if neigh == nil || neigh.OwnerID == 0 {
				continue
			}
			if c := w.CountryByKingId(neigh.OwnerID); c != nil && c.CountryId != countryID {
				result = append(result, neighID)
			}
		}
	}
	return result
}

// TransportBetweenCitys 输送资源（对应 CityListCache.transport_between_citys）
func (w *World) TransportBetweenCitys(fromID, toID, food, gold int) {
	from := w.City(fromID)
	to := w.City(toID)
	if from == nil || to == nil {
		return
	}
	food = from.SubFood(food)
	gold = from.SubGold(gold)
	to.AddFood(food)
	to.AddGold(gold)
}

// ---- 月度推进（对应 turn_manager.add_month 及月度事件） ----

// AddMonth 推进一个月（对应 add_month）
func (w *World) AddMonth() {
	w.GameInfo.Month++
	if w.GameInfo.Month > 12 {
		w.GameInfo.Month = 1
		w.GameInfo.Years++
		w.debutByYears(w.GameInfo.Years)
	}
	w.monthlyIncome()
	w.uprising()
	w.checkDisasters()
	w.handleCityGenerals()
	w.updateAlliances()
	w.talentGenMove()
}

// monthlyIncome 月度收入（对应 _monthly_income）
func (w *World) monthlyIncome() {
	for _, country := range w.Countries {
		if country.GetHaveCityNum() <= 0 {
			continue
		}
		for _, cityID := range country.CityIDs {
			city := w.City(cityID)
			if city == nil {
				continue
			}
			city.AddGold(city.MoneyIncome())
			city.AddFood(city.FoodIncome())
			city.SoldierEatFood(w)
			city.PaySalaries(w)
		}
	}
}

// updateAlliances 同盟月数递减（对应 _update_alliances）
func (w *World) updateAlliances() {
	for _, country := range w.Countries {
		keep := country.AllianceList[:0]
		for _, alliance := range country.AllianceList {
			alliance.Months--
			if alliance.Months <= 0 {
				if other := w.Country(alliance.CountryId); other != nil {
					other.RemoveAlliance(country.CountryId)
				}
				continue
			}
			keep = append(keep, alliance)
		}
		country.AllianceList = keep
	}
}

// uprising 起义（对应 _uprising）
func (w *World) uprising() {
	for _, city := range w.Cities {
		if !city.IsRebel(w) {
			continue
		}
		general := w.General(city.PrefectID)
		if general == nil {
			continue
		}
		if oldCountry := w.CountryByKingId(city.OwnerID); oldCountry != nil {
			oldCountry.RemoveCity(w, city.CityID)
		}
		newCountry := &entities.Country{
			CountryId:     len(w.Countries) + 1,
			CountryKingId: general.GeneralId,
		}
		newCountry.SetRand(w.Rng)
		city.PrefectID = general.GeneralId
		newCountry.AddCity(w, city.CityID)
		w.Countries[newCountry.CountryId] = newCountry
		w.CountrySequence = append([]int{newCountry.CountryId}, w.CountrySequence...)
		return
	}
}

// checkDisasters 灾难判定（对应 _check_disasters）
func (w *World) checkDisasters() {
	for cityID := 1; cityID < 49; cityID++ {
		city := w.City(cityID)
		if city == nil {
			continue
		}
		if w.naturalDisasterRate(city) {
			continue
		}
		if w.plagueRate(city) {
			continue
		}
		if city.OwnerID > 0 {
			w.turmoilRate(city)
		}
	}
}

// naturalDisasterRate 自然灾（对应 _natural_disaster_rate），1/100概率
func (w *World) naturalDisasterRate(city *entities.City) bool {
	if w.Rng.IntRange(0, 499) < 5 {
		w.handleNaturalDisaster(city)
		kinds := []string{"旱灾", "洪涝", "蝗灾"}
		w.GameInfo.ShowInfo = city.CityName + "发生" + kinds[w.Rng.IntRange(0, 2)]
		return true
	}
	return false
}

// plagueRate 瘟疫（对应 _plague_rate），约1/250
func (w *World) plagueRate(city *entities.City) bool {
	if w.Rng.IntRange(0, 499) <= 2 {
		w.handlePlague(city)
		w.GameInfo.ShowInfo = city.CityName + "发生瘟疫"
		return true
	}
	return false
}

// turmoilRate 骚乱（对应 _turmoil_rate）
func (w *World) turmoilRate(city *entities.City) bool {
	rule := city.GetRule()
	chance := 1000
	if rule < 15 {
		chance = rule*10/15 + 80
	} else if rule < 30 {
		chance = (rule-15)/3 + 90
	} else if rule < 40 {
		chance = (rule-30)/5 + 98
	} else if rule < 60 {
		chance = (rule-40)/5 + 998
	}
	random := w.Rng.IntRange(0, 100)
	if rule >= 60 {
		random = w.Rng.IntRange(0, 1000)
	}
	if random >= chance {
		w.handleTurmoil(city)
		w.GameInfo.ShowInfo = city.CityName + "发生骚乱"
		return true
	}
	return false
}

// disasterLoss 灾损折算（对应 _disaster_loss）
func (w *World) disasterLoss(param, floodControl, cap int) int {
	param /= 2
	return floodControl * param / cap
}

// handleNaturalDisaster 处理自然灾（对应 _handle_natural_disaster）
func (w *World) handleNaturalDisaster(city *entities.City) {
	fc := city.GetFloodControl()
	if fc < 90 {
		city.SubGold(w.disasterLoss(city.GetMoney(), fc, 90))
		city.SubFood(w.disasterLoss(city.GetFood(), fc, 90))
		city.SubRule(w.disasterLoss(city.GetRule(), fc, 90))
	}
	if fc < 99 {
		city.SubTrade(w.disasterLoss(city.GetTrade(), fc, 99))
		city.SubAgro(w.disasterLoss(city.GetAgro(), fc, 99))
	}
	if fc > 0 {
		city.SubFloodControl(fc/10 + 1)
	}
}

// handlePlague 处理瘟疫（对应 _handle_plague）
func (w *World) handlePlague(city *entities.City) {
	fc := city.GetFloodControl()
	if fc < 90 {
		for _, gid := range city.GetOfficerIds() {
			if g := w.General(gid); g != nil {
				g.Soldiers -= w.disasterLoss(g.Soldiers, fc, 90)
			}
		}
		city.ReserveSoldiers -= w.disasterLoss(city.ReserveSoldiers, fc, 90)
		city.SubRule(w.disasterLoss(city.GetRule(), fc, 90))
	}
	if fc < 99 {
		city.SubPopulation(w.disasterLoss(city.GetPopulation(), fc, 99))
	}
	if fc > 0 {
		city.SubFloodControl(fc/10 + 1)
	}
}

// handleTurmoil 处理骚乱（对应 _handle_turmoil）
func (w *World) handleTurmoil(city *entities.City) {
	rule := city.GetRule()
	officers := city.GetOfficerIds()
	switch {
	case rule < 15:
		city.SetPopulation(city.GetPopulation() / 3)
		city.SetAgro(city.GetAgro() / 3)
		city.SetTrade(city.GetTrade() / 3)
		city.SetMoney(city.GetMoney() / 2)
		city.SetFood(city.GetFood() / 2)
		city.SubRule(w.Rng.IntRange(0, 14))
		for _, gid := range officers {
			if g := w.General(gid); g != nil {
				g.Soldiers -= w.Rng.IntRange(g.Soldiers/3, g.Soldiers*2/3)
			}
		}
	case rule < 30:
		city.SetPopulation(city.GetPopulation() / 2)
		city.SetAgro(city.GetAgro() / 2)
		city.SetTrade(city.GetTrade() / 2)
		city.SetMoney(city.GetMoney() * 3 / 7)
		city.SetFood(city.GetFood() * 3 / 7)
		city.SubRule(w.Rng.IntRange(10, 19))
		for _, gid := range officers {
			if g := w.General(gid); g != nil {
				g.Soldiers -= w.Rng.IntRange(g.Soldiers/4, g.Soldiers/2)
			}
		}
	default:
		city.SetPopulation(city.GetPopulation() * 2 / 3)
		city.SetAgro(city.GetAgro() * 2 / 3)
		city.SetTrade(city.GetTrade() * 2 / 3)
		city.SetMoney(city.GetMoney() / 7)
		city.SetFood(city.GetFood() / 7)
		city.SubRule(w.Rng.IntRange(15, 24))
		for _, gid := range officers {
			if g := w.General(gid); g != nil {
				g.Soldiers -= w.Rng.IntRange(g.Soldiers/5, g.Soldiers/4)
			}
		}
	}
}

// handleCityGenerals 月度武将处理（对应 _handle_city_generals）
func (w *World) handleCityGenerals() {
	for _, city := range w.Cities {
		for _, gid := range city.GetOfficerIds() {
			g := w.General(gid)
			if g == nil {
				continue
			}
			if g.Health < g.MaxHealth {
				g.AddHp(2)
			}
		}
		// 监狱忠诚≥80释放
		for _, gid := range city.GetCaptureList() {
			g := w.General(gid)
			if g != nil && g.Loyalty >= 80 {
				city.RemoveCapture(gid)
				city.AddOfficeGeneralID(w, gid)
			}
		}
	}
}

// talentGenMove 在野武将流动（对应 _talent_gen_move）
func (w *World) talentGenMove() {
	for _, city := range w.Cities {
		talents := city.GetTalentIds()
		if len(talents) == 0 {
			continue
		}
		gid := talents[0]
		if city.OwnerID != 0 && w.Rng.Chance(0.15) {
			officers := city.GetOfficerIds()
			doer := city.OwnerID
			if len(officers) > 0 {
				doer = officers[0]
			}
			if city.IsEmploy(w, doer, gid, w.PhaseDiff) {
				city.RemoveReservedGeneralID(gid)
			}
		}
	}
}

// debutByYears 按年登场武将（对应 GeneralListCache.debut_by_years，简化）
func (w *World) debutByYears(year int) {
	for _, g := range w.Generals {
		if g.IsDie || g.Status == 1 {
			continue
		}
		if g.DebutYear == year {
			city := w.City(g.DebutCity)
			if city != nil {
				city.AddReservedGeneralID(w, g.GeneralId)
			}
		}
	}
}
