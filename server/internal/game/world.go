package game

import (
	"3k-server/internal/game/entities"
	"3k-server/internal/game/rng"
)

// World 权威游戏状态（对应 GDScript 多个 autoload 单例的聚合）。
// 单 goroutine 内访问，保证 RNG 顺序确定性。
type World struct {
	Rng *rng.SeededRng

	// 静态配置
	Config *Config
	Texts  *Texts

	// 动态状态
	GameInfo  GameInfoState
	Generals  map[int]*entities.General
	Cities    map[int]*entities.City
	Countries map[int]*entities.Country
	Weapons   map[int]*entities.Weapon

	CountrySequence []int

	// 活动状态（战争中/战术战斗中非 nil）
	War    *WarState
	Battle *BattleState
}

// General 通过 id 取武将
func (w *World) General(id int) *entities.General {
	return w.Generals[id]
}

// City 通过 id 取城池
func (w *World) City(id int) *entities.City {
	return w.Cities[id]
}

// Country 通过 id 取势力
func (w *World) Country(id int) *entities.Country {
	return w.Countries[id]
}

// Weapon 通过 id 取武器
func (w *World) Weapon(id int) *entities.Weapon {
	return w.Weapons[id]
}

// CountryByKingId 通过君主 id 找势力
func (w *World) CountryByKingId(kingId int) *entities.Country {
	for _, c := range w.Countries {
		if c.CountryKingId == kingId {
			return c
		}
	}
	return nil
}

// RemoveCityFromCountry 移除某君主势力的一座城池（对应 country.RemoveCity）
func (w *World) RemoveCityFromCountry(ownerKingID, cityID int) {
	for _, c := range w.Countries {
		if c.CountryKingId == ownerKingID {
			c.RemoveCity(w, cityID)
			return
		}
	}
	// 找不到势力则清空城池归属
	if city := w.City(cityID); city != nil {
		city.OwnerID = 0
		city.PrefectID = 0
	}
}

// PlayerCountryId 返回玩家势力 id（供 entities 扩展接口查询）
func (w *World) PlayerCountryId() int { return w.GameInfo.PlayerCountryId }

// CountryCount 势力总数（供 entities 扩展接口查询）
func (w *World) CountryCount() int { return len(w.Countries) }

// RngSeed 返回本局随机种子（存档/回放用）
func (w *World) RngSeed() int64 {
	if w.Rng == nil {
		return 0
	}
	return w.Rng.Seed()
}

// GeneralDie 武将死亡处理（对应 GeneralListCache.general_die）
// 注：完整死亡处理（君主继承/势力灭亡提示）后续在 cache 包移植时完善
func (w *World) GeneralDie(gid int) {
	g := w.Generals[gid]
	if g == nil {
		return
	}
	g.IsDie = true
	g.Status = 0
}
