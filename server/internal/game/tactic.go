package game

import "3k-server/internal/game/entities"

// ---- 战术系统（对应 scripts/data/tactic.gd 6 种战术） ----

// TacticDef 战术定义
type TacticDef struct {
	ID        int
	Name      string
	Desc      string
	Cost      int
	Duration  int
}

// 6 种战术
var tacticDefs = []TacticDef{
	{ID: 1, Name: "挑战", Desc: "向敌将发出单挑邀请.耗费2个计策点", Cost: 2, Duration: 0},
	{ID: 2, Name: "咒缚", Desc: "限制敌将行动.耗费5个计策点", Cost: 5, Duration: 2},
	{ID: 3, Name: "连弩", Desc: "箭手射程增加.耗费7个计策点", Cost: 7, Duration: 4},
	{ID: 4, Name: "呐喊", Desc: "全军攻击力增加.耗费8个计策点", Cost: 8, Duration: 4},
	{ID: 5, Name: "火矢", Desc: "箭手攻击力大大增加.耗费10个计策点", Cost: 10, Duration: 3},
	{ID: 6, Name: "爆炎", Desc: "我方兵力大于500.利用火器攻击敌军.耗费12个计策点", Cost: 11, Duration: 0},
}

// TacticRef 根据 id 获取战术定义
func TacticRef(tacticID int) *TacticDef {
	if tacticID >= 1 && tacticID <= 6 {
		return &tacticDefs[tacticID-1]
	}
	return nil
}

// GetTacticsNum 按智力的战术数量（对应 get_tactics_num）
func GetTacticsNum(g *entities.General) int {
	wisdom := g.Wisdom
	switch {
	case wisdom < 16:
		return 0
	case wisdom < 39:
		return 1
	case wisdom < 54:
		return 2
	case wisdom < 62:
		return 3
	case wisdom < 77:
		return 4
	case wisdom < 93:
		return 5
	default:
		return 6
	}
}

// IsTacticEnough 计策点是否足够（对应 is_enough）
func (w *World) IsTacticEnough(t *TacticDef, isPlayer bool) bool {
	if w.Battle == nil {
		return false
	}
	if isPlayer {
		return t.Cost <= w.Battle.HmTacticPoint
	}
	return t.Cost <= w.Battle.AiTacticPoint
}

// TacticSuccessful 战术是否成功（对应 is_successful）
func (w *World) TacticSuccessful(t *TacticDef, isPlayer bool) bool {
	if !w.IsTacticEnough(t, isPlayer) {
		return false
	}
	switch t.ID {
	case 1: // 挑战（单挑）
		if w.Battle == nil || w.Battle.PendingPlayerUnit == nil || w.Battle.PendingEnemyUnit == nil {
			return false
		}
		hmGen := w.General(w.Battle.PendingPlayerUnit.GenID)
		aiGen := w.General(w.Battle.PendingEnemyUnit.GenID)
		if hmGen == nil || aiGen == nil {
			return false
		}
		doGen := hmGen
		beGen := aiGen
		if !isPlayer {
			doGen, beGen = aiGen, hmGen
		}
		if beGen.GetHp() < 25 {
			return false
		}
		if doGen.HasSkill5(3) && beGen.Force > 80 {
			return true
		}
		beAtk := doGen.GetAttackPower(w)
		doDef := beGen.GetDefendPower(w)
		doAtk := doGen.GetAttackPower(w)
		beDef := beGen.GetDefendPower(w)
		beI := ceilDiv(GetAtkDea(beGen, beAtk, doDef)*w.GetPercentage(beGen, doGen, false, false), 100)
		doI := ceilDiv(GetAtkDea(doGen, doAtk, beDef)*w.GetPercentage(doGen, beGen, false, false), 100)
		beVal := beI * beGen.GetHp()
		doVal := doI * doGen.GetHp()
		if beVal <= doVal+25 {
			return false
		}
		return w.Rng.IntRange(0, beVal-doVal-1) > 25
	case 2: // 咒缚
		if w.Battle == nil {
			return false
		}
		hmGen := w.General(w.Battle.PendingPlayerUnit.GenID)
		aiGen := w.General(w.Battle.PendingEnemyUnit.GenID)
		if hmGen == nil || aiGen == nil {
			return false
		}
		doGen := hmGen
		beGen := aiGen
		if !isPlayer {
			doGen, beGen = aiGen, hmGen
		}
		i1 := doGen.Wisdom - beGen.Wisdom
		if doGen.HasSkill5(9) { // 束缚
			i1 += 30
		}
		if i1 < 0 {
			return false
		}
		return w.Rng.IntRange(0, 79) <= i1
	case 3, 4, 5:
		// 连弩/呐喊/火矢：无成功率判定，直接持续生效
		return true
	case 6: // 爆炎
		if w.Battle == nil {
			return false
		}
		if isPlayer {
			hmGen := w.General(w.Battle.PendingPlayerUnit.GenID)
			return hmGen != nil && hmGen.Soldiers >= 500
		}
		return false
	}
	return false
}

// ceilDiv 向上取整除法 (a*b)/d 的 ceil
func ceilDiv(product int, d int) int {
	if d <= 0 {
		return 0
	}
	if product <= 0 {
		return 0
	}
	return (product + d - 1) / d
}
