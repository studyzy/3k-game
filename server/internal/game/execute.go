package game

import "3k-server/internal/game/entities"

// ExecuteResult 执行内政/外交命令的结果
type ExecuteResult struct {
	Results      []string
	OrderNum     int
	PlayingState GameState
}

// ExecuteTask 执行玩家命令（对应 executive_panel._execute 大 match）
// 单 goroutine 串行调用，内部消费 RNG。
func (w *World) ExecuteTask(task TaskType, doCityId, targetCityId int, doGeneralIds, targetGeneralIds []int, inputs map[string]interface{}) *ExecuteResult {
	res := &ExecuteResult{}
	city := w.City(doCityId)

	switch task {
	case TaskSEARCH: // 搜索
		if city != nil {
			for _, gid := range doGeneralIds {
				g := w.General(gid)
				if g == nil {
					continue
				}
				r := city.Search(w, gid, w.Texts.SearchResultTexts())
				res.Results = append(res.Results, g.GeneralName+"："+r)
			}
		}

	case TaskREWARD: // 奖赏
		if city != nil {
			for _, gid := range doGeneralIds {
				g := w.General(gid)
				if g == nil {
					continue
				}
				delta := g.RewardAddLoyalty(true)
				city.SubGold(100)
				res.Results = append(res.Results, g.GeneralName+" 忠诚 +"+itoaStr(delta))
			}
		}

	case TaskAPPOINT: // 任命太守
		if city != nil && len(doGeneralIds) > 0 {
			gid := doGeneralIds[0]
			city.AppointPrefect(w, gid)
			if g := w.General(gid); g != nil {
				res.Results = append(res.Results, "任命 "+g.GeneralName+" 为太守")
			}
		}

	case TaskRECLAIM: // 开垦
		if city != nil && len(doGeneralIds) > 0 {
			gid := doGeneralIds[0]
			g := w.General(gid)
			if g != nil {
				money := g.GetNeedMoneyOfInterior(int(TaskRECLAIM))
				if city.Money >= money {
					val := city.Reclaim(w, g, money)
					res.Results = append(res.Results, g.GeneralName+" 开垦，农业 +"+itoaStr(val))
				} else {
					res.Results = append(res.Results, "金钱不足")
				}
			}
		}

	case TaskMERCANTILE: // 劝商
		if city != nil && len(doGeneralIds) > 0 {
			gid := doGeneralIds[0]
			g := w.General(gid)
			if g != nil {
				money := g.GetNeedMoneyOfInterior(int(TaskMERCANTILE))
				if city.Money >= money {
					val := city.Mercantile(w, g, money)
					res.Results = append(res.Results, g.GeneralName+" 劝商，商业 +"+itoaStr(val))
				} else {
					res.Results = append(res.Results, "金钱不足")
				}
			}
		}

	case TaskTAME: // 治水
		if city != nil && len(doGeneralIds) > 0 {
			gid := doGeneralIds[0]
			g := w.General(gid)
			if g != nil {
				money := g.GetNeedMoneyOfInterior(int(TaskTAME))
				if city.Money >= money {
					val := city.Tame(w, g, money)
					res.Results = append(res.Results, g.GeneralName+" 治水，防洪 +"+itoaStr(val))
				} else {
					res.Results = append(res.Results, "金钱不足")
				}
			}
		}

	case TaskPATROL: // 巡查
		if city != nil && len(doGeneralIds) > 0 {
			gid := doGeneralIds[0]
			g := w.General(gid)
			if g != nil {
				money := g.GetNeedMoneyOfInterior(int(TaskPATROL))
				if city.Money >= money {
					val := city.Patrol(w, g, money)
					res.Results = append(res.Results, g.GeneralName+" 巡查，人口 +"+itoaStr(val))
				} else {
					res.Results = append(res.Results, "金钱不足")
				}
			}
		}

	case TaskSCHOOL: // 学院学习
		if city != nil && len(doGeneralIds) > 0 {
			gid := doGeneralIds[0]
			g := w.General(gid)
			if g != nil && g.Wisdom < 120 && g.Experience >= g.GetSchoolNeedExp() {
				g.StudyUp()
				res.Results = append(res.Results, g.GeneralName+" 智力+1")
			} else {
				res.Results = append(res.Results, "经验不足，无法学习")
			}
		}

	case TaskHOSPITAL: // 医馆治疗
		if city != nil {
			healed := false
			for _, gid := range doGeneralIds {
				g := w.General(gid)
				if g == nil {
					continue
				}
				if g.Health < g.MaxHealth && city.Money >= 100 {
					city.SubGold(100)
					g.AddHp(w.Rng.IntRange(20, 34))
					res.Results = append(res.Results, g.GeneralName+" 体力恢复")
					healed = true
				}
			}
			if !healed {
				res.Results = append(res.Results, "无需治疗或金钱不足")
			}
		}

	case TaskEMPLOY: // 登用
		res.Results = w.employTask(city)

	case TaskCONSCRIPT: // 征兵
		res.Results = w.conscriptTask(city, inputs)

	case TaskSHOP: // 金粮（购粮）
		res.Results = w.shopTask(city, inputs)

	case TaskSMITHY: // 武器店
		res.Results = w.smithyTask(city, doGeneralIds)

	case TaskMOVE: // 移动
		if len(doGeneralIds) > 0 {
			isKing := w.moveTask(doCityId, targetCityId, doGeneralIds)
			if isKing {
				res.Results = append(res.Results, "移动完成（君主移动）")
			} else {
				res.Results = append(res.Results, "移动完成")
			}
		}

	case TaskTRANSPORT: // 输送
		res.Results = w.transportTask(city, targetCityId, inputs)

	case TaskALIENATE: // 离间
		res.Results = w.alienateTask(doGeneralIds, targetGeneralIds)

	case TaskBRIBE: // 招揽
		res.Results = w.bribeTask(doCityId, targetCityId, doGeneralIds, targetGeneralIds)

	default:
		res.Results = append(res.Results, "任务执行完成")
	}

	res.OrderNum = w.GameInfo.PlayerOrderNum
	res.PlayingState = w.GameInfo.PlayingState
	return res
}

// employTask 登用（对应 _show_employ）
func (w *World) employTask(city *entities.City) []string {
	if city == nil {
		return []string{"无效城池"}
	}
	talents := city.GetTalentIds()
	if len(talents) == 0 {
		return []string{"城中无在野武将可登用"}
	}
	chosen := talents[0]
	doGid := 0
	// 默认用第一个可选武将
	if len(w.GameInfo.DoGeneralIds) > 0 {
		doGid = w.GameInfo.DoGeneralIds[0]
	}
	if doGid == 0 {
		doGid = w.GameInfo.PlayerCountryId // 用君主
	}
	if city.IsEmploy(w, doGid, chosen, w.PhaseDiff) {
		w.GameInfo.DoGeneralIds = []int{chosen}
		if g := w.General(chosen); g != nil {
			return []string{"成功登用 " + g.GeneralName}
		}
		return []string{"成功登用"}
	}
	return []string{"登用失败"}
}

// conscriptTask 征兵（对应 _show_conscript）
func (w *World) conscriptTask(city *entities.City, inputs map[string]interface{}) []string {
	if city == nil {
		return []string{"无效城池"}
	}
	n := intFromInput(inputs, "amount", 0)
	if n < 0 {
		n = 0
	}
	if maxN := city.GetMaxConscriptSoldierNum(w); n > maxN {
		n = maxN
	}
	if n <= 0 {
		return []string{"无法征兵（已达上限或资源不足）"}
	}
	city.Conscript(n)
	return []string{"征兵 " + itoaStr(n) + "，预备兵 " + itoaStr(city.ReserveSoldiers)}
}

// shopTask 金粮（对应 _show_shop，4粮=3金）
func (w *World) shopTask(city *entities.City, inputs map[string]interface{}) []string {
	if city == nil {
		return []string{"无效城池"}
	}
	n := intFromInput(inputs, "amount", 0)
	if n < 0 {
		n = 0
	}
	if n > 30000 {
		n = 30000
	}
	goldNeeded := n * 3 / 4
	if city.Money >= goldNeeded {
		city.SubGold(goldNeeded)
		city.AddFood(n)
		return []string{"购粮 " + itoaStr(n) + "，花费 " + itoaStr(goldNeeded) + " 金"}
	}
	return []string{"金钱不足"}
}

// smithyTask 武器店（对应 _show_smithy）
func (w *World) smithyTask(city *entities.City, doGeneralIds []int) []string {
	if city == nil || len(doGeneralIds) == 0 {
		return []string{"无效操作"}
	}
	weapons := w.GetWeaponsBySmithy(city.CityWeaponShop)
	if len(weapons) == 0 {
		return []string{"城中无武器店"}
	}
	weapon := weapons[0]
	g := w.General(doGeneralIds[0])
	if g == nil {
		return []string{"无效武将"}
	}
	if city.Money >= weapon.Price {
		if g.BuyNewWeapon(w, weapon.WeaponID, city.CityID) {
			city.SubGold(weapon.Price)
			return []string{g.GeneralName + " 购得 " + weapon.WeaponName}
		}
		return []string{"无法使用该武器"}
	}
	return []string{"金钱不足"}
}

// moveTask 移动（对应 CityListCache.move_task 简化）
func (w *World) moveTask(fromCityID, toCityID int, generalIds []int) bool {
	isKing := false
	from := w.City(fromCityID)
	to := w.City(toCityID)
	if from == nil || to == nil {
		return false
	}
	for _, gid := range generalIds {
		if g := w.General(gid); g != nil && w.CountryByKingId(gid) != nil {
			isKing = true
			to.AddOfficeGeneralID(w, gid)
			from.RemoveOfficerID(w, gid)
			continue
		}
		to.AddOfficeGeneralID(w, gid)
		from.RemoveOfficerID(w, gid)
	}
	return isKing
}

// transportTask 输送（对应 _show_transport，含钱粮宝）
func (w *World) transportTask(city *entities.City, targetCityID int, inputs map[string]interface{}) []string {
	if city == nil || targetCityID == 0 {
		return []string{"无效目标"}
	}
	target := w.City(targetCityID)
	if target == nil {
		return []string{"无效目标"}
	}
	food := intFromInput(inputs, "food", 0)
	gold := intFromInput(inputs, "gold", 0)
	if food < 0 {
		food = 0
	}
	if gold < 0 {
		gold = 0
	}
	if food > city.GetFood() {
		food = city.GetFood()
	}
	if gold > city.GetMoney() {
		gold = city.GetMoney()
	}
	w.TransportBetweenCitys(city.CityID, targetCityID, food, gold)
	return []string{"向 " + target.CityName + " 输送粮食 " + itoaStr(food) + "，金钱 " + itoaStr(gold)}
}

// alienateTask 离间（对应 GeneralListCache.is_alienate）
func (w *World) alienateTask(doGeneralIds, targetGeneralIds []int) []string {
	if len(targetGeneralIds) == 0 {
		return []string{"离间失败（未选目标）"}
	}
	doGenID := 0
	if len(doGeneralIds) > 0 {
		doGenID = doGeneralIds[0]
	}
	if doGenID == 0 {
		doGenID = w.GameInfo.PlayerCountryId
	}
	success := w.IsAlienate(doGenID, targetGeneralIds[0])
	if success {
		return []string{"离间成功"}
	}
	return []string{"离间失败"}
}

// bribeTask 招揽（对应 GeneralListCache.is_bribe）
func (w *World) bribeTask(doCityId, targetCityId int, doGeneralIds, targetGeneralIds []int) []string {
	if len(targetGeneralIds) == 0 {
		return []string{"招揽失败（未选目标）"}
	}
	doGenID := 0
	if len(doGeneralIds) > 0 {
		doGenID = doGeneralIds[0]
	}
	if doGenID == 0 {
		doGenID = w.GameInfo.PlayerCountryId
	}
	success := w.IsBribe(doCityId, targetCityId, doGenID, targetGeneralIds[0])
	if success {
		return []string{"招揽成功"}
	}
	return []string{"招揽失败"}
}

// GetWeaponsBySmithy 按店铺位掩码筛选武器（对应 WeaponListCache.get_weapons_by_smithy）
func (w *World) GetWeaponsBySmithy(smithyMask int) []*entities.Weapon {
	var out []*entities.Weapon
	for _, wp := range w.Weapons {
		if wp.Smithy&smithyMask != 0 {
			out = append(out, wp)
		}
	}
	return out
}

// intFromInput 从 inputs 读取 int
func intFromInput(inputs map[string]interface{}, key string, def int) int {
	if inputs == nil {
		return def
	}
	if v, ok := inputs[key]; ok {
		switch t := v.(type) {
		case float64:
			return int(t)
		case int:
			return t
		case string:
			return atoiSafe(t, def)
		}
	}
	return def
}

// atoiSafe 安全字符串转 int
func atoiSafe(s string, def int) int {
	n := 0
	neg := false
	i := 0
	if len(s) > 0 && (s[0] == '-' || s[0] == '+') {
		neg = s[0] == '-'
		i = 1
	}
	for ; i < len(s); i++ {
		if s[i] < '0' || s[i] > '9' {
			return def
		}
		n = n*10 + int(s[i]-'0')
	}
	if neg {
		return -n
	}
	return n
}

// itoaStr 整数转字符串
func itoaStr(v int) string {
	if v == 0 {
		return "0"
	}
	neg := v < 0
	if neg {
		v = -v
	}
	var buf [20]byte
	pos := len(buf)
	for v > 0 {
		pos--
		buf[pos] = byte('0' + v%10)
		v /= 10
	}
	if neg {
		pos--
		buf[pos] = '-'
	}
	return string(buf[pos:])
}
