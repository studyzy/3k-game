package game

import "3k-server/internal/game/entities"

// WarState 战争状态，对应 scripts/data/war_manager.gd 关键字段
type WarState struct {
	WarState     int
	BattleState  int
	CurWarCityId int
	DepartureCityId int
	Day          int
	IsHmDef      bool
	HmKingId     int
	AiKingId     int
	HmGold       int
	HmFood       int
	AiGold       int
	AiFood       int
	AttackerCountryId int
	DefenderCountryId int
	HmUnits      []*entities.Unit
	AiUnits      []*entities.Unit
	WarMap       [][]int
}

// BattleState 战术战斗状态，对应 scripts/data/battle_manager.gd 关键字段
type BattleState struct {
	FormationIndex int
	HmTacticPoint  int
	AiTacticPoint  int
	Terrain        int
	ActiveTactics  []interface{}
	HmTurnOrder    []*entities.Troop
	AiTurnOrder    []*entities.Troop
	PendingPlayerUnit *entities.Unit
	PendingEnemyUnit  *entities.Unit
}
