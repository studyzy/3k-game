package entities

// Troop 战术战斗单位，对应 scripts/battle/troop.gd
type Troop struct {
	TroopType    int   `json:"troopType"`
	TroopState   int   `json:"troopState"`
	Health       int   `json:"health"`
	GeneralID    int   `json:"generalID"`
	IsPlayer     bool  `json:"isPlayer"`
	Index        int   `json:"index"`
	AttackPower  int   `json:"attackPower"`
	DefensePower int   `json:"defensePower"`
	ActBonus     int   `json:"actBonus"`
	Face         int   `json:"face"`
	ArrayPosX    int   `json:"arrayPosX"`
	ArrayPosY    int   `json:"arrayPosY"`
}

// Troop 兵种类型
const (
	TroopCaptain  = 0
	TroopCavalry  = 1
	TroopArcher   = 2
	TroopInfantry = 3
)

// Troop 状态
const (
	TroopStateForward   = 0
	TroopStateIdle      = 1
	TroopStateBackward  = 2
	TroopStateOutflank  = 3
	TroopStateExit      = 4
)

// IsCaptain 是否主将
func (t *Troop) IsCaptain() bool { return t.TroopType == TroopCaptain }

// InitActBonus 初始化行动次数
func (t *Troop) InitActBonus() {
	if t.TroopType == TroopCaptain || t.TroopType == TroopCavalry {
		t.ActBonus = 2
	} else {
		t.ActBonus = 1
	}
}

// TopInf 地形攻防系数，对应 TextLibrary.TOP_INF
var TopInf = []float64{0.8, 0.9, 1.0, 1.1}

// InitPower 初始化攻防，对应 TroopData.InitPower
func (t *Troop) InitPower(g *General, wp WeaponProvider, terrain int) {
	if t.IsCaptain() {
		t.AttackPower = g.GetAttackPower(wp)
		t.DefensePower = g.GetDefendPower(wp)
		return
	}
	t.AttackPower = (g.Lead*2+g.Force)/3 + (g.Lead+g.Force)*(g.Level-1)/25
	t.DefensePower = (g.Lead*2+g.Wisdom)/3 + (g.Lead+g.Wisdom)*(g.Level-1)/25
	if g.HasSkill3(7) { // 军魂
		t.AttackPower += t.AttackPower / 5
		t.DefensePower += t.DefensePower / 5
	}
	if g.HasSkill3(8) { // 军神
		t.AttackPower += t.AttackPower / 4
		t.DefensePower += t.DefensePower / 4
	}
	switch t.TroopType {
	case TroopArcher:
		t.AttackPower = t.AttackPower * 2 / 3
		t.DefensePower = t.DefensePower * 4 / 5
	case TroopInfantry:
		t.AttackPower = t.AttackPower * 4 / 5
		t.DefensePower = t.DefensePower * 6 / 5
	}
	tef := t.getTef(terrain, g)
	t.AttackPower = int(float64(t.AttackPower) * tef)
	t.DefensePower = int(float64(t.DefensePower) * tef)
	if terrain == 8 {
		if g.HasSkill3(3) { // 攻城
			t.AttackPower += t.AttackPower / 5
		}
		if g.HasSkill3(4) { // 守城
			t.DefensePower += t.DefensePower / 5
		}
		t.DefensePower += t.DefensePower / 2
	} else {
		if g.HasSkill3(1) { // 奇袭
			t.AttackPower += t.AttackPower / 7
		}
		if g.HasSkill3(2) { // 铁壁
			t.DefensePower += t.DefensePower / 7
		}
	}
}

func (t *Troop) getTef(terrain int, g *General) float64 {
	idx := 0
	if terrain == 10 || terrain == 11 || terrain == 12 {
		idx = 1
	} else if terrain == 9 || terrain == 15 {
		idx = 2
	}
	adapt := 0
	if idx < len(g.Army) {
		adapt = g.Army[idx]
	}
	if adapt < 0 {
		adapt = 0
	} else if adapt > 3 {
		adapt = 3
	}
	return TopInf[adapt]
}

// CalculateDamage 伤害计算，对应 Troop.CalculateDamage
func (t *Troop) CalculateDamage() int {
	damage := t.AttackPower
	if d := t.Health / 20; d > damage {
		damage = d
	}
	if t.Health < 200 {
		damage = int(float64(damage) * float64(t.Health) / 200.0)
	}
	if damage < 1 {
		damage = 1
	}
	return damage
}
