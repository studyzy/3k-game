package game

import "3k-server/internal/game/entities"

// ---- 单挑（对应 scripts/solo_manager.gd） ----

// GeneralAtkValue 武将攻值（对应 _general_atk_value）
func GeneralAtkValue(g *entities.General, atkPower, defPower int) int {
	i := g.Force
	i *= atkPower
	if defPower < 1 {
		defPower = 1
	}
	i /= defPower
	if i > 2*g.Force {
		i = 2 * g.Force
	}
	if i < g.Force/3 {
		i = g.Force / 3
	}
	i += i / 5
	return i
}

// GetAtkDea 单次攻击伤害（对应 get_atk_dea）
func GetAtkDea(atkGen *entities.General, atk, def int) int {
	dea := GeneralAtkValue(atkGen, atk, def) / 8
	if dea < 0 {
		dea = 100
	}
	if dea < 1 {
		dea = 1
	}
	return dea
}

// GetAllAtkDea 全力攻击伤害（对应 get_all_atk_dea）
func GetAllAtkDea(atkGen *entities.General, atk, def int) int {
	dea := GeneralAtkValue(atkGen, atk, def) / 2
	if dea < 0 {
		dea = 100
	}
	if dea < 1 {
		dea = 1
	}
	return dea
}

// WeaponEffect 武器效果修正（对应 _weapon_effect）
func WeaponEffect(atkGen, defGen *entities.General, sc int, whack bool) int {
	a := atkGen.Arm
	b := defGen.Armor
	if a == 5 && whack {
		sc += 20
	}
	if (a == 6 || a == 7 || a == 14) && !whack {
		sc += 15
	}
	if b == 30 && !whack {
		sc -= 15
	}
	if b == 31 && !whack {
		sc -= 20
	} else if b == 31 && whack {
		sc = 0
	}
	return sc
}

// GetPercentage 武器命中率（对应 get_percentage）
func (w *World) GetPercentage(atkGen, defGen *entities.General, whack, hmAtk bool) int {
	sc := 0
	atkWt := 0
	if wp := w.Weapon(atkGen.Arm); wp != nil {
		atkWt = wp.Kind
	}
	defWt := 0
	if wp := w.Weapon(defGen.Arm); wp != nil {
		defWt = wp.Kind
	}
	switch {
	case atkWt == 0 && defWt == 0:
		sc = 70
	case atkWt == 0 && defWt == 1:
		sc = 75
	case atkWt == 0 && defWt == 2:
		sc = 60
	case atkWt == 1 && defWt == 0:
		sc = 55
	case atkWt == 1 && defWt == 1:
		sc = 60
	case atkWt == 1 && defWt == 2:
		sc = 70
	case atkWt == 2 && defWt == 0:
		sc = 80
	case atkWt == 2 && defWt == 1:
		sc = 50
	case atkWt == 2 && defWt == 2:
		sc = 60
	}
	if hmAtk {
		sc -= 20
	}
	if whack && hmAtk {
		sc = sc / 3
	} else if whack && !hmAtk {
		sc = sc / 2
	}
	sc = WeaponEffect(atkGen, defGen, sc, whack)
	return clampInt(sc, 0, 100)
}

// Persuade 我方招降 AI 将领（对应 persuade）
func (w *World) Persuade(doGen, beGen *entities.General) bool {
	if beGen.GetLoyalty() > 99 {
		return false
	}
	i1 := (doGen.Charm*7 + doGen.Wisdom*3) * 10 / 99
	i1 = (i1 - 70) / 5
	if i1 == 4 {
		i1 = 6
	} else if i1 == 5 {
		i1 = 8
	}
	i1 = beGen.GetHp() + beGen.GetLoyalty() - i1 + w.Rng.IntRange(0, 4)
	return i1 < 100
}

// AiPersuade AI 招降我方将领（对应 ai_persuade）
func (w *World) AiPersuade(doGen, beGen *entities.General) bool {
	if beGen.GetLoyalty() > 99 {
		return false
	}
	i1 := (doGen.Charm*7 + doGen.Wisdom*3) * 10 / 99
	i1 = (i1 - 70) / 5
	if i1 == 4 {
		i1 = 6
	} else if i1 == 5 {
		i1 = 8
	}
	i1 = beGen.GetHp() + beGen.GetLoyalty() - i1 + w.Rng.IntRange(0, 4)
	return i1 < 110
}

// SingleAtk 单次攻击（对应 single_atk），返回伤害
func (w *World) SingleAtk(atkGen, defGen *entities.General, atk, def int, hmAtk bool) int {
	if w.GetPercentage(atkGen, defGen, false, hmAtk) > w.Rng.IntRange(0, 100) {
		return GetAtkDea(atkGen, atk, def)
	}
	return 0
}
