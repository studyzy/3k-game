package game

import "3k-server/internal/game/entities"

// WarState 战争状态枚举（对应 WarManager.WarState）
const (
	WarNONE           = 0
	WarPLAYER_TURN    = 1
	WarAI_TURN        = 2
	WarEND_ROUND      = 3
	WarWAR_WIN        = 4
	WarWAR_LOSE       = 5
	WarWAR_EVENT      = 6
	WarOCCUPY         = 7
	WarDAY_OUT        = 8
	WarAI_RETREAT     = 9
	WarAI_CAPTIVE     = 10
	WarAI_DIE         = 11
	WarAI_STARVE      = 12
	WarPLAYER_RETREAT = 13
	WarPLAYER_CAPTIVE = 14
	WarPLAYER_DIE     = 15
	WarPLAYER_STARVE  = 16
	WarBATTLE         = 17
)

// BattleState 战术战斗状态枚举（对应 BattleManager.BattleState）
const (
	BattleNONE      = 0
	BattlePLAYER_TURN = 1
	BattleAI_TURN   = 2
	BattleBATTLE_WIN = 3
	BattleBATTLE_LOSE = 4
	BattleBATTLE_OVER = 5
)

// MoveBonusTable 玩家机动力表（按兵力/300）
var moveBonusTable = []int{7, 8, 10, 12, 14, 15, 16, 18, 20, 22, 24}

// AiMoveBonusTable AI 机动力表
var aiMoveBonusTable = []int{8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28}

// WarPrepare 战前准备（对应 war_prepare）
func (w *World) WarPrepare(isAIAttack bool, curWarCityID, departureCityID int, attackerIDs []int, food, gold, attackerCountryID int) {
	city := w.City(curWarCityID)

	w.War = &WarState{
		WarState:     WarPLAYER_TURN,
		BattleState:  BattleNONE,
		CurWarCityId: curWarCityID,
		DepartureCityId: departureCityID,
		Day:          1,
		IsHmDef:      isAIAttack,
	}

	defenderCountryID := 0
	if city != nil && city.OwnerID != 0 {
		if c := w.CountryByKingId(city.OwnerID); c != nil {
			defenderCountryID = c.CountryId
		}
	}
	attackerID := attackerCountryID
	if attackerID == 0 {
		attackerID = w.GameInfo.PlayerCountryId
	}
	w.War.DefenderCountryId = defenderCountryID
	w.War.AttackerCountryId = attackerID

	// 玩家侧 hmUnits，AI 侧 aiUnits
	if isAIAttack {
		// 攻方=AI，守方=玩家(或盟友)
		if city != nil {
			w.War.HmUnits = w.CreateUnits(city.GetOfficerIds(), true)
			w.War.HmGold = city.Money
			w.War.HmFood = city.Grain
		}
		w.War.AiUnits = w.CreateUnits(attackerIDs, false)
		w.War.AiGold = gold
		w.War.AiFood = food
	} else {
		// 攻方=玩家
		w.War.HmUnits = w.CreateUnits(attackerIDs, true)
		w.War.HmGold = gold
		w.War.HmFood = food
		if city != nil {
			w.War.AiUnits = w.CreateUnits(city.GetOfficerIds(), false)
			w.War.AiGold = city.Money
			w.War.AiFood = city.Grain
		}
	}
	if pc := w.Country(w.GameInfo.PlayerCountryId); pc != nil {
		w.War.HmKingId = pc.CountryKingId
	}
	w.War.AiKingId = findCommander(w, unitIDs(w.War.AiUnits))

	// 加载地图
	mapData := w.ReadWarMap(curWarCityID)
	if len(mapData) == 0 {
		mapData = generateEmptyMap()
	}
	w.War.WarMap = mapData

	w.assignStartPositions()
}

// CreateUnits 创建单位列表（对应 _create_units）
func (w *World) CreateUnits(generalIDs []int, isPlayer bool) []*entities.Unit {
	var units []*entities.Unit
	commander := findCommander(w, generalIDs)
	for _, gid := range generalIDs {
		if w.General(gid) == nil {
			continue
		}
		u := &entities.Unit{
			GenID:       gid,
			IsPlayer:    isPlayer,
			IsCommander: gid == commander,
			MoveBonus:   10,
			UnitState:   entities.UnitNone,
		}
		units = append(units, u)
	}
	return units
}

// findCommander 寻找主将（对应 _find_commander）
func findCommander(w *World, generalIDs []int) int {
	for _, gid := range generalIDs {
		if g := w.General(gid); g != nil && w.CountryByKingId(gid) != nil {
			return gid
		}
	}
	if len(generalIDs) > 0 {
		return generalIDs[0]
	}
	return 0
}

// unitIDs 提取单位 id 列表
func unitIDs(units []*entities.Unit) []int {
	var ids []int
	for _, u := range units {
		ids = append(ids, u.GenID)
	}
	return ids
}

// generateEmptyMap 生成空地图（19x32）
func generateEmptyMap() [][]int {
	m := make([][]int, 19)
	for row := range m {
		m[row] = make([]int, 32)
	}
	return m
}

// assignStartPositions 分配初始位置（玩家左 AI 右）
func (w *World) assignStartPositions() {
	rows := len(w.War.WarMap)
	rowIdx := 0
	for _, u := range w.War.HmUnits {
		if rows == 0 {
			break
		}
		u.ArrayPosX = 1
		u.ArrayPosY = rowIdx % rows
		u.IsMoved = false
		rowIdx += 2
	}
	rowIdx = 0
	for _, u := range w.War.AiUnits {
		if rows == 0 {
			break
		}
		u.ArrayPosX = 30
		u.ArrayPosY = rowIdx % rows
		u.IsMoved = false
		rowIdx += 2
	}
}

// SetMoveBonus 设置机动力（按兵力）
func (w *World) SetMoveBonus(units []*entities.Unit) {
	for _, u := range units {
		g := w.General(u.GenID)
		if g == nil {
			continue
		}
		bl := g.Soldiers / 300
		idx := bl
		if idx < 0 {
			idx = 0
		} else if idx > 10 {
			idx = 10
		}
		u.MoveBonus = moveBonusTable[idx]
		u.IsMoved = false
	}
}

// StartPlayerTurn 开始玩家回合（对应 start_player_turn）
func (w *World) StartPlayerTurn() {
	w.War.WarState = WarPLAYER_TURN
	w.SetMoveBonus(w.War.HmUnits)
	for _, u := range w.War.AiUnits {
		u.IsMoved = false
	}
	w.ExecThreaten(w.War.HmUnits, w.War.AiUnits)
	w.ExecThreaten(w.War.AiUnits, w.War.HmUnits)
}

// MoveUnitToCell 移动单位到格子（对应 move_unit_to_cell）
func (w *World) MoveUnitToCell(u *entities.Unit, cell Pos) {
	oldV := w.War.WarMap[u.ArrayPosY][u.ArrayPosX]
	w.War.WarMap[u.ArrayPosY][u.ArrayPosX] = oldV & 0x3F
	u.ArrayPosX = cell.X
	u.ArrayPosY = cell.Y
	newV := w.War.WarMap[cell.Y][cell.X]
	if u.IsPlayer {
		newV = (newV & 0x3F) | 0x40
	} else {
		newV = (newV & 0x3F) | 0x80
	}
	w.War.WarMap[cell.Y][cell.X] = newV
	u.IsMoved = true
}

// EatFoodEveryDay 每日耗粮（对应 eat_food_every_day）
func (w *World) EatFoodEveryDay() bool {
	total := 0
	for _, u := range w.War.HmUnits {
		if g := w.General(u.GenID); g != nil {
			total += g.Soldiers
		}
	}
	need := total / 250
	if w.War.HmFood < need {
		if w.War.IsHmDef {
			w.HandleWarOver(WarAI_STARVE)
		} else {
			w.HandleWarOver(WarPLAYER_STARVE)
		}
		return false
	}
	w.War.HmFood -= need
	return true
}

// HandleWarOver 战争结束（对应 handle_war_over）
func (w *World) HandleWarOver(state int) {
	switch state {
	case WarDAY_OUT, WarPLAYER_STARVE, WarOCCUPY:
		w.AfterWarSettlement(false, false)
	case WarAI_STARVE:
		w.AfterWarSettlement(true, false)
	default:
		w.AfterWarSettlement(false, false)
	}
}

// AfterWarSettlement 战争结算（对应 after_war_settlement）
func (w *World) AfterWarSettlement(isHmWin, loserHaveCommander bool) {
	if w.War == nil {
		return
	}
	city := w.City(w.War.CurWarCityId)
	if city == nil {
		return
	}
	attackerWon := (!w.War.IsHmDef && isHmWin) || (w.War.IsHmDef && !isHmWin)
	winnerCountryID := w.War.AttackerCountryId
	if !attackerWon {
		winnerCountryID = w.War.DefenderCountryId
	}
	loserCountryID := w.War.DefenderCountryId
	if !attackerWon {
		loserCountryID = w.War.AttackerCountryId
	}

	var loserUnits []*entities.Unit
	var winnerUnits []*entities.Unit
	if isHmWin {
		loserUnits = w.War.AiUnits
		winnerUnits = w.War.HmUnits
	} else {
		loserUnits = w.War.HmUnits
		winnerUnits = w.War.AiUnits
	}

	winnerCountry := w.Country(winnerCountryID)
	loserCountry := w.Country(loserCountryID)
	if loserCountry != nil {
		loserCountry.RemoveCity(w, w.War.CurWarCityId)
	}
	if winnerCountry == nil {
		return
	}
	// 转移城市
	city.OwnerID = winnerCountry.CountryKingId
	city.PrefectID = 0
	city.OfficeGeneralId = nil
	// 败方武将被俘（君主死亡，其余入狱）
	for _, u := range loserUnits {
		g := w.General(u.GenID)
		if g == nil {
			continue
		}
		if w.CountryByKingId(u.GenID) != nil {
			w.GeneralDie(u.GenID)
		} else {
			city.AddCapture(w, u.GenID)
		}
	}
	// 胜方武将入城
	for _, u := range winnerUnits {
		g := w.General(u.GenID)
		if g != nil && g.GeneralId != winnerCountry.CountryKingId {
			city.AddOfficeGeneralID(w, u.GenID)
		}
	}
	city.AutoAppointPrefect(w)
	winnerCountry.AddCity(w, w.War.CurWarCityId)
	king := w.General(winnerCountry.CountryKingId)
	kingName := ""
	if king != nil {
		kingName = king.GeneralName
	}
	w.GameInfo.ShowInfo = kingName + " 占领了 " + city.CityName

	// 清空战争状态
	w.War.HmUnits = nil
	w.War.AiUnits = nil
	w.War.WarMap = nil
}

// ExecThreaten 恐吓技能（对应 _exec_threaten）
func (w *World) ExecThreaten(doUnits, beUnits []*entities.Unit) {
	for _, doUnit := range doUnits {
		if doUnit.UnitState == entities.UnitCaptive {
			continue
		}
		doGeneral := w.General(doUnit.GenID)
		if doGeneral == nil || !doGeneral.HasSkill5(2) {
			continue
		}
		if doGeneral.Soldiers < 300 {
			continue
		}
		for _, beUnit := range beUnits {
			if beUnit.UnitState == entities.UnitCaptive {
				continue
			}
			beGeneral := w.General(beUnit.GenID)
			if beGeneral == nil || beGeneral.HasSkill5(2) {
				continue
			}
			if beGeneral.Soldiers >= 600 && doGeneral.Force >= beGeneral.Force && w.Rng.IntRange(0, 100) <= 50 {
				loss := doGeneral.Soldiers/30 + w.Rng.IntRange(0, doGeneral.Force)
				beGeneral.SubSoldiers(loss)
				doGeneral.AddExperience(int(float64(loss) * 1.2))
				w.GameInfo.ShowInfo = doGeneral.GeneralName + "对" + beGeneral.GeneralName + "发动恐吓，减少士兵" + itoaStr(loss)
			}
		}
	}
}

// NextDay 推进到第二天（对应 next_day）
func (w *World) NextDay() {
	w.War.Day++
	if w.War.Day > 30 {
		w.GameInfo.ShowInfo = "30天已过，双方各自撤军"
		w.AfterWarSettlement(false, false)
		return
	}
	if !w.EatFoodEveryDay() {
		return
	}
	w.StartPlayerTurn()
}

// FindAdjacentBattle 检查相邻可交战（对应 find_adjacent_battle）
func (w *World) FindAdjacentBattle() (*entities.Unit, *entities.Unit) {
	for _, u := range w.War.HmUnits {
		for _, e := range w.War.AiUnits {
			if abs(u.ArrayPosX-e.ArrayPosX)+abs(u.ArrayPosY-e.ArrayPosY) == 1 {
				return u, e
			}
		}
	}
	return nil, nil
}

// AiUnitsTurn AI 单位行动（对应 _ai_units_turn）
func (w *World) AiUnitsTurn() {
	for _, u := range w.War.AiUnits {
		if u.IsMoved || u.UnitState != entities.UnitNone {
			continue
		}
		var nearestEnemy *entities.Unit
		nearestDist := 1 << 30
		for _, e := range w.War.HmUnits {
			d := (u.ArrayPosX-e.ArrayPosX)*(u.ArrayPosX-e.ArrayPosX) + (u.ArrayPosY-e.ArrayPosY)*(u.ArrayPosY-e.ArrayPosY)
			if d < nearestDist {
				nearestDist = d
				nearestEnemy = e
			}
		}
		if nearestEnemy == nil {
			continue
		}
		// 相邻则待机（交给场景）
		if abs(u.ArrayPosX-nearestEnemy.ArrayPosX)+abs(u.ArrayPosY-nearestEnemy.ArrayPosY) == 1 {
			u.IsMoved = true
			continue
		}
		// A* 向敌人走一步
		target := Pos{nearestEnemy.ArrayPosX, nearestEnemy.ArrayPosY}
		path := w.GetPathToTarget(target, u, w.War.WarMap, true)
		if len(path) > 1 {
			w.MoveUnitToCell(u, path[1])
		}
		u.IsMoved = true
	}
}
