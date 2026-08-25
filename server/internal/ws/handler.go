package ws

import (
	"encoding/json"
	"log"

	"3k-server/internal/game"
	"3k-server/internal/game/entities"
)

// ExecuteTaskRequest C2S_ExecuteTask body
type ExecuteTaskRequest struct {
	Task             int                    `json:"task"`
	DoCityId         int                    `json:"doCityId"`
	TargetCityId     int                    `json:"targetCityId"`
	DoGeneralIds     []int                  `json:"doGeneralIds"`
	TargetGeneralIds []int                  `json:"targetGeneralIds"`
	Inputs           map[string]interface{} `json:"inputs"`
}

// ExecuteTaskResponse S2C_TaskResult body
type ExecuteTaskResponse struct {
	Task         int      `json:"task"`
	Results      []string `json:"results"`
	OrderNum     int      `json:"orderNum"`
	PlayingState int      `json:"playingState"`
	Delta        *Delta   `json:"delta"`
}

// DefaultHandler 核心命令处理器。分发到 World 逻辑，单 goroutine 串行。
func DefaultHandler(s *Session, env *Envelope) ([]PushMsg, error) {
	w := s.World
	if w == nil {
		return nil, nil
	}
	switch env.Op {
	case OpPing:
		return []PushMsg{{Op: OpPong, Body: map[string]interface{}{"t": "pong"}}}, nil

	case OpSelectKing:
		var req struct {
			CountryId int `json:"countryId"`
		}
		if err := json.Unmarshal(env.Body, &req); err != nil {
			return nil, err
		}
		w.GameInfo.PlayerCountryId = req.CountryId
		if c := w.Country(req.CountryId); c != nil {
			w.GameInfo.DoCityId = c.FindKingCity(w)
			if w.GameInfo.DoCityId == 0 && len(c.CityIDs) > 0 {
				w.GameInfo.DoCityId = c.CityIDs[0]
			}
		}
		w.GameInfo.PlayerOrderNum = w.GameInfo.GetPlayerOrderNum(w)
		w.GameInfo.PlayingState = game.GameStatePLAYING
		return []PushMsg{{Op: OpDelta, Body: deltaFromWorld(w)}}, nil

	case OpExecuteTask:
		var req ExecuteTaskRequest
		if err := json.Unmarshal(env.Body, &req); err != nil {
			return nil, err
		}
		// 扣命令
		w.GameInfo.SubPlayerOrder()
		res := w.ExecuteTask(game.TaskType(req.Task), req.DoCityId, req.TargetCityId, req.DoGeneralIds, req.TargetGeneralIds, req.Inputs)
		return []PushMsg{
			{Op: OpDelta, Body: deltaFromWorld(w)},
			{Op: OpTaskResult, Body: &ExecuteTaskResponse{
				Task: req.Task, Results: res.Results, OrderNum: res.OrderNum, PlayingState: int(res.PlayingState),
			}},
		}, nil

	case OpEndTurn:
		w.EndPlayerTurn()
		gameOver := w.GameInfo.PlayingState == game.GameStateGAME_OVER || w.GameInfo.PlayingState == game.GameStateGAME_WIN
		return []PushMsg{
			{Op: OpDelta, Body: deltaFromWorld(w)},
			{Op: OpTurnResult, Body: map[string]interface{}{
				"phase": "PLAYER_TURN", "orderNum": w.GameInfo.PlayerOrderNum, "gameOver": gameOver,
			}},
		}, nil

	case OpSelectGeneral:
		// 选将：设置可选武将列表（简单回执）
		return []PushMsg{{Op: OpServerEvent, Body: map[string]interface{}{"event": "select_general_ok"}}}, nil

	case OpAttack:
		var req struct {
			DoCityId     int   `json:"doCityId"`
			TargetCityId int   `json:"targetCityId"`
			DoGeneralIds []int `json:"doGeneralIds"`
		}
		if err := json.Unmarshal(env.Body, &req); err != nil {
			return nil, err
		}
		if len(req.DoGeneralIds) == 0 || req.TargetCityId == 0 {
			return []PushMsg{{Op: OpWarStart, Body: map[string]interface{}{"error": "bad_request"}}}, nil
		}
		w.WarPrepare(false, req.TargetCityId, req.DoCityId, req.DoGeneralIds, 500, 300, w.GameInfo.PlayerCountryId)
		// 下发战争初始状态（单位 + 位置 + 地图）
		return []PushMsg{{Op: OpWarStart, Body: warSnapshotBody(w)}}, nil

	case OpBattleAdvance, OpBattleSelect, OpBattleTactic, OpWarAction, OpWarEndTurn, OpWarMove:
		return handleWarBattle(s, env)

	case OpNewGame:
		// 已在 HTTP /game/new 处理；此处支持 WS 创建
		return []PushMsg{{Op: OpServerEvent, Body: map[string]interface{}{"event": "use_http_new_game"}}}, nil

	default:
		log.Printf("session %s: unhandled op 0x%X", s.ID, env.Op)
		return []PushMsg{{Op: OpServerEvent, Body: map[string]interface{}{"event": "not_implemented", "op": env.Op}}}, nil
	}
}

// warSnapshotBody 生成战争状态快照（单位位置/状态 + 地图 + 天数）
func warSnapshotBody(w *game.World) map[string]interface{} {
	if w.War == nil {
		return map[string]interface{}{"warState": -1}
	}
	return map[string]interface{}{
		"day":      w.War.Day,
		"warState": w.War.WarState,
		"isHmDef":  w.War.IsHmDef,
		"hmGold":   w.War.HmGold,
		"hmFood":   w.War.HmFood,
		"aiGold":   w.War.AiGold,
		"aiFood":   w.War.AiFood,
		"hmUnits":  unitBodies(w.War.HmUnits),
		"aiUnits":  unitBodies(w.War.AiUnits),
		"warMap":   w.War.WarMap,
	}
}

// unitBodies 单位列表转字典
func unitBodies(units []*entities.Unit) []map[string]interface{} {
	out := []map[string]interface{}{}
	for _, u := range units {
		out = append(out, map[string]interface{}{
			"genID": u.GenID, "isPlayer": u.IsPlayer, "isCommander": u.IsCommander,
			"pos": []int{u.ArrayPosX, u.ArrayPosY}, "state": u.UnitState, "isMoved": u.IsMoved,
		})
	}
	return out
}

// handleWarBattle 战争/战术战斗命令分发
func handleWarBattle(s *Session, env *Envelope) ([]PushMsg, error) {
	w := s.World
	switch env.Op {
	case OpWarMove:
		var req struct {
			UnitGenId int `json:"unitGenId"`
			ToCellX   int `json:"toCellX"`
			ToCellY   int `json:"toCellY"`
		}
		if err := json.Unmarshal(env.Body, &req); err != nil {
			return nil, err
		}
		if w.War == nil {
			return []PushMsg{{Op: OpWarStep, Body: map[string]interface{}{"error": "no_war"}}}, nil
		}
		var unit *entities.Unit
		for _, u := range w.War.HmUnits {
			if u.GenID == req.UnitGenId {
				unit = u
				break
			}
		}
		if unit == nil {
			return []PushMsg{{Op: OpWarStep, Body: map[string]interface{}{"error": "unit_not_found"}}}, nil
		}
		w.MoveUnitToCell(unit, game.Pos{X: req.ToCellX, Y: req.ToCellY})
		return []PushMsg{{Op: OpWarStep, Body: warSnapshotBody(w)}}, nil

	case OpWarEndTurn:
		if w.War == nil {
			return []PushMsg{{Op: OpWarStep, Body: map[string]interface{}{"error": "no_war"}}}, nil
		}
		// AI 行动
		w.SetMoveBonus(w.War.AiUnits)
		w.AiUnitsTurn()
		// 检查相邻交战
		pu, eu := w.FindAdjacentBattle()
		_ = pu
		_ = eu
		w.NextDay()
		return []PushMsg{{Op: OpWarStep, Body: warSnapshotBody(w)}}, nil

	case OpWarAction:
		var req struct {
			Action string `json:"action"`
			Args   map[string]interface{} `json:"args"`
		}
		if err := json.Unmarshal(env.Body, &req); err != nil {
			return nil, err
		}
		switch req.Action {
		case "occupy": // 攻城占领
			w.HandleWarOver(game.WarOCCUPY)
			return []PushMsg{{Op: OpWarStep, Body: map[string]interface{}{"action": "occupy_done"}}}, nil
		case "retreat":
			w.AfterWarSettlement(false, false)
			return []PushMsg{{Op: OpWarStep, Body: map[string]interface{}{"action": "retreat_done"}}}, nil
		}
		return []PushMsg{{Op: OpWarStep, Body: map[string]interface{}{"action": req.Action}}}, nil

	case OpBattleSelect:
		var req struct {
			FormationIndex int `json:"formationIndex"`
			Mode           string `json:"mode"`
		}
		if err := json.Unmarshal(env.Body, &req); err != nil {
			return nil, err
		}
		if w.War == nil || len(w.War.HmUnits) == 0 || len(w.War.AiUnits) == 0 {
			return []PushMsg{{Op: OpBattleStep, Body: map[string]interface{}{"error": "no_units"}}}, nil
		}
		hmGen := w.General(w.War.HmUnits[0].GenID)
		aiGen := w.General(w.War.AiUnits[0].GenID)
		if hmGen == nil || aiGen == nil {
			return []PushMsg{{Op: OpBattleStep, Body: map[string]interface{}{"error": "no_general"}}}, nil
		}
		w.InitBattle(hmGen, aiGen, w.BattleTerrain(), w.War.IsHmDef)
		// 自动模式：simulated battle
		if req.Mode == "auto" {
			hmWin := w.SimulatedBattle(hmGen, aiGen)
			return []PushMsg{{Op: OpBattleResult, Body: map[string]interface{}{"win": hmWin}}}, nil
		}
		// 手动模式：返回战场初始状态
		return []PushMsg{{Op: OpBattleStart, Body: map[string]interface{}{
			"hmGeneral": hmGen.GeneralName, "aiGeneral": aiGen.GeneralName,
			"terrain": w.BattleTerrain(), "formationIndex": req.FormationIndex,
		}}}, nil

	case OpBattleAdvance:
		return []PushMsg{{Op: OpBattleStep, Body: map[string]interface{}{"step": "advance"}}}, nil

	case OpBattleTactic:
		var req struct {
			TacticId  int `json:"tacticId"`
			IsPlayer  bool `json:"isPlayer"`
		}
		if err := json.Unmarshal(env.Body, &req); err != nil {
			return nil, err
		}
		t := game.TacticRef(req.TacticId)
		if t == nil {
			return []PushMsg{{Op: OpBattleStep, Body: map[string]interface{}{"error": "no_tactic"}}}, nil
		}
		success := w.TacticSuccessful(t, req.IsPlayer)
		if success && req.IsPlayer && w.Battle != nil {
			w.Battle.HmTacticPoint -= t.Cost
		}
		return []PushMsg{{Op: OpBattleStep, Body: map[string]interface{}{"tactic": t.Name, "success": success}}}, nil
	}
	return nil, nil
}

// deltaFromWorld 生成增量（开发期简化：把全部动态状态作为 changed 下发，客户端据此渲染）
func deltaFromWorld(w *game.World) *Delta {
	d := &Delta{
		Changed: Changed{
			Generals:  map[string]map[string]interface{}{},
			Cities:    map[string]map[string]interface{}{},
			Countries: map[string]map[string]interface{}{},
		},
		Events:   []EventItem{},
		GameInfo: w.GameInfoDict(),
	}
	// 武将全量字段
	for id, g := range w.Generals {
		d.Changed.Generals[itoa(id)] = map[string]interface{}{
			"generalId": g.GeneralId, "generalName": g.GeneralName, "status": g.Status,
			"level": g.Level, "health": g.Health, "lead": g.Lead, "force": g.Force,
			"wisdom": g.Wisdom, "govern": g.Govern, "charm": g.Charm, "loyalty": g.Loyalty,
			"soldiers": g.Soldiers, "experience": g.Experience, "arm": g.Arm, "armor": g.Armor,
			"debutCity": g.DebutCity, "isDie": g.IsDie,
		}
	}
	// 城池全量字段
	for id, c := range w.Cities {
		d.Changed.Cities[itoa(id)] = map[string]interface{}{
			"cityID": c.CityID, "cityName": c.CityName, "ownerID": c.OwnerID, "prefectID": c.PrefectID,
			"rule": c.Rule, "money": c.Money, "grain": c.Grain, "treasures": c.Treasures,
			"agriculture": c.Agriculture, "commerce": c.Commerce, "population": c.Population,
			"prevention": c.Prevention, "reserveSoldiers": c.ReserveSoldiers,
			"officeGeneralId": c.OfficeGeneralId, "reservedGeneralId": c.ReservedGeneralId,
			"notFoundGeneralId": c.NotFoundGeneralId, "jailGeneralId": c.JailGeneralId,
		}
	}
	// 势力全量字段
	for id, c := range w.Countries {
		d.Changed.Countries[itoa(id)] = map[string]interface{}{
			"countryId": c.CountryId, "countryKingId": c.CountryKingId,
			"countryColor": c.CountryColor, "canBeChoose": c.CanBeChoose,
			"cityIDs": c.CityIDs, "inheritors": c.Inheritors,
		}
	}
	return d
}

// itoa 整数转字符串（ws 包内辅助）
func itoa(v int) string {
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
