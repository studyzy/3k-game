package game

import "3k-server/internal/game/entities"

// ---- 自建武将（对应 scripts/ui/self_build.gd 的随机生成逻辑，随机服务器化） ----

// RandomGeneral 随机生成一个自建武将
func (w *World) RandomGeneral() *entities.General {
	g := &entities.General{
		GeneralId:   10000 + w.Rng.IntRange(0, 999),
		GeneralName: "自建武将",
		Level:       1,
		Health:      100,
		MaxHealth:   100,
		Loyalty:     99,
		DebutYear:   w.GameInfo.Years,
		DebutCity:   1,
		Arm:         1,
		Armor:       1,
		Soldiers:    1000,
		Phase:       w.Rng.IntRange(0, 149),
		Army:        []int{w.Rng.IntRange(0, 3), w.Rng.IntRange(0, 3), w.Rng.IntRange(0, 3)},
		Skills:      w.randomSkills(),
	}
	g.Lead = gaussian(w, 60, 30)
	g.Govern = gaussian(w, 60, 30)
	g.Force = gaussian(w, 60, 30)
	g.Wisdom = gaussian(w, 60, 30)
	g.Charm = gaussian(w, 60, 30)
	g.SetRand(w.Rng)
	return g
}

// gaussian 高斯分布随机属性（对应 _gaussian）
func gaussian(w *World, mean, std int) int {
	v := (w.Rng.Float64() + w.Rng.Float64() + w.Rng.Float64() + w.Rng.Float64() + w.Rng.Float64() + w.Rng.Float64() - 3.0) / 3.0 * float64(std) + float64(mean)
	return clampInt(int(v), 10, 90)
}

// randomSkills 随机 2-4 个技能（对应 _random_skills）
func (w *World) randomSkills() []int {
	skills := []int{0, 0, 0, 0, 0}
	count := w.Rng.IntRange(2, 4)
	for i := 0; i < count; i++ {
		kind := w.Rng.IntRange(0, 4)
		index := w.Rng.IntRange(1, 10)
		skills[kind] |= 1 << (10 - index)
	}
	return skills
}

// AddCustomGeneral 添加自建武将到世界（存为在野武将）
func (w *World) AddCustomGeneral(name string) (*entities.General, error) {
	g := w.RandomGeneral()
	g.GeneralName = name
	// 放入 debutCity（城1）的在野列表
	if city := w.City(g.DebutCity); city != nil {
		g.Status = 0
		g.SetRand(w.Rng)
		w.Generals[g.GeneralId] = g
		city.AddReservedGeneralID(w, g.GeneralId)
	}
	return g, nil
}
