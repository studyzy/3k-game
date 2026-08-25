package game

import "3k-server/internal/game/entities"

// ---- 战术战斗（对应 scripts/battle/battle_manager.gd + battle_scene.gd 逻辑部分） ----

// InitBattle 初始化战术战斗（对应 init_battle）
func (w *World) InitBattle(hmGen, aiGen *entities.General, terrain int, isHmDef bool) {
	b := &BattleState{
		Terrain:       terrain,
		HmTacticPoint: hmGen.Wisdom * 13 / 100,
		AiTacticPoint: aiGen.Wisdom * 13 / 100,
		ActiveTactics: []interface{}{},
	}
	w.Battle = b
}

// TerrainIndex 地形索引（对应 _terrain_index）：0平原 1山地 2水域 3城战
func TerrainIndex(terrain int) int {
	if terrain == 8 {
		return 3
	} else if terrain == 9 || terrain == 15 {
		return 2
	} else if terrain == 10 || terrain == 11 || terrain == 12 || terrain == 13 || terrain == 14 {
		return 1
	}
	return 0
}

// GetTroopsNum 部队数（对应 get_troops_num）
func (w *World) GetTroopsNum(g *entities.General) int {
	num := (g.Soldiers-1)/300 + 2
	if num <= 0 {
		num = 1
	}
	return num
}

// CreateTurnOrder 生成兵种序列（对应 create_turn_order）
func (w *World) CreateTurnOrder(g *entities.General, isPlayer bool) []int {
	// 返回 troopType 序列：0主将 1骑 2弓 3步
	order := []int{entities.TroopCaptain}
	terrainIdx := TerrainIndex(w.battleTerrain())
	var adapt int
	if terrainIdx < len(g.Army) {
		adapt = g.Army[terrainIdx]
	}
	if adapt < 0 {
		adapt = 0
	} else if adapt > 3 {
		adapt = 3
	}
	cai := w.Texts.CaiProportion[terrainIdx][adapt]
	total := w.GetTroopsNum(g) - 1
	remaining := total
	if remaining < 0 {
		remaining = 0
	}
	for i := 0; i < 3; i++ {
		count := cai[i] * remaining / 10
		for j := 0; j < count; j++ {
			troopType := entities.TroopCavalry
			if i == 1 {
				troopType = entities.TroopArcher
			} else if i == 2 {
				troopType = entities.TroopInfantry
			}
			order = append(order, troopType)
		}
	}
	return order
}

func (w *World) battleTerrain() int {
	if w.War != nil && len(w.War.WarMap) > 9 && len(w.War.WarMap[9]) > 16 {
		return int(w.War.WarMap[9][16]) & 0xF
	}
	return 0
}

// BattleTerrain 当前战场地形（对外暴露）
func (w *World) BattleTerrain() int { return w.battleTerrain() }

// SidePower 单侧战力（对应 _side_power）
func (w *World) SidePower(g *entities.General, order []int, tacticPoint int, isPlayer bool) int {
	power := 0
	terrain := w.battleTerrain()
	for i := 1; i < len(order); i++ {
		atk := (g.Lead*2+g.Force)/3 + (g.Lead+g.Force)*(g.Level-1)/25
		def := (g.Lead*2+g.Wisdom)/3 + (g.Lead+g.Wisdom)*(g.Level-1)/25
		if g.HasSkill2(7) && w.Rng.IntRange(0, 2) < 1 {
			def += def / 2
		}
		if g.HasSkill2(8) && w.Rng.IntRange(0, 2) < 1 {
			def += def / 2
		}
		if g.HasSkill3(9) {
			atk += atk / 2
			def += def / 2
		}
		troopType := order[i]
		switch troopType {
		case entities.TroopCavalry:
			if g.HasSkill2(0) && w.Rng.IntRange(0, 2) < 1 {
				atk += atk / 2
			} else if g.HasSkill2(1) && w.Rng.IntRange(0, 4) < 1 {
				atk += atk / 2
			}
			if (terrain == 10 || terrain == 11) && g.HasSkill2(5) && w.Rng.IntRange(0, 5) < 1 {
				atk += atk / 2
			}
			p := (atk+def)*2 + atk*w.Rng.IntRange(1, 2) + atk*tacticPoint/8
			power += p * p
		case entities.TroopArcher:
			if g.HasSkill2(6) && w.Rng.IntRange(0, 4) < 2 {
				atk += atk * 2 / 5
			}
			if g.HasSkill2(2) && w.Rng.IntRange(0, 2) < 1 {
				atk += atk / 2
			} else if g.HasSkill2(3) && w.Rng.IntRange(0, 4) < 1 {
				atk += atk / 2
			}
			if terrain == 9 && g.HasSkill2(4) && w.Rng.IntRange(0, 5) < 1 {
				atk += atk / 2
			}
			if (terrain == 10 || terrain == 11) && g.HasSkill2(5) && w.Rng.IntRange(0, 5) < 1 {
				atk += atk / 2
			}
			p2 := (atk+def)*2 + atk*w.Rng.IntRange(0, 1) + atk*tacticPoint/7
			power += p2 * p2
		default: // infantry
			if terrain == 9 && g.HasSkill2(4) && w.Rng.IntRange(0, 5) < 1 {
				atk += atk / 2
			}
			if (terrain == 10 || terrain == 11) && g.HasSkill2(5) && w.Rng.IntRange(0, 5) < 1 {
				atk += atk / 2
			}
			p3 := (atk + def) * 2 / 3
			power += p3 * p3
		}
	}
	return power
}

// SimulatedBattle 自动战斗（对应 simulated_battle），返回 true=玩家胜
func (w *World) SimulatedBattle(hmGen, aiGen *entities.General) bool {
	hmOrder := w.CreateTurnOrder(hmGen, true)
	aiOrder := w.CreateTurnOrder(aiGen, false)
	hmPower := w.SidePower(hmGen, hmOrder, hmGen.Wisdom*13/100, true)
	aiPower := w.SidePower(aiGen, aiOrder, aiGen.Wisdom*13/100, false)
	hmPower /= 1000
	aiPower /= 1000
	hmPf := hmPower
	aiPf := aiPower
	hmPower = hmPf * hmGen.Soldiers
	aiPower = aiPf * aiGen.Soldiers
	hmWin := hmPower >= aiPower
	if hmWin {
		aiGen.Soldiers = 0
		ends := (hmPower - aiPower) / maxInt(hmPf, 1)
		ends = clampInt(ends, 0, 3000)
		hmGen.Soldiers = ends
	} else {
		hmGen.Soldiers = 0
		ends2 := (aiPower - hmPower) / maxInt(aiPf, 1)
		ends2 = clampInt(ends2, 0, 3000)
		aiGen.Soldiers = ends2
	}
	return hmWin
}

// ApplyTactic 应用战术（对应 apply_tactic）
func (w *World) ApplyTactic(name string, isPlayer bool, duration int) {
	if w.Battle == nil {
		return
	}
	w.Battle.ActiveTactics = append(w.Battle.ActiveTactics, name)
}

func maxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

func clampInt(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
