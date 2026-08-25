package entities

// Unit 战争单位（UnitData），对应 scripts/data/unit.gd
type Unit struct {
	GenID       int  `json:"genID"`
	IsPlayer    bool `json:"isPlayer"`
	IsCommander bool `json:"isCommander"`
	MoveBonus   int  `json:"moveBonus"`
	TrappedDay  int  `json:"trappedDay"`
	IsMoved     bool `json:"isMoved"`
	UnitState   int  `json:"unitState"`
	ArrayPosX   int  `json:"arrayPosX"`
	ArrayPosY   int  `json:"arrayPosY"`
}

// Unit 状态枚举
const (
	UnitNone    = 0
	UnitRetreat = 1
	UnitIdle    = 2
	UnitRetire  = 3
	UnitCaptive = 4
	UnitDead    = 5
	UnitTrapped = 6
)
