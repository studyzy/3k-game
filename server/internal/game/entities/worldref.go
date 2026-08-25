package entities

import "strconv"

// WorldRef 实体逻辑所需的缓存查询接口。
// 由 game.World 实现，避免 entities 反向依赖 game 造成循环导入。
type WorldRef interface {
	General(id int) *General
	City(id int) *City
	Weapon(id int) *Weapon
	// CountryByKingId 通过君主武将ID找势力（供 IsKingOf 等判断）
	CountryByKingId(kingId int) *Country
	// RemoveCityFromCountry 移除某君主势力的一座城池（供 RemoveOfficerID 城池失主时调用）
	RemoveCityFromCountry(ownerKingID, cityID int)
	// GeneralDie 武将死亡处理（供 AddNotFoundGeneralID 隐居满员时触发）
	GeneralDie(gid int)
	// CountryCount 势力总数（供 IsRebel 阈值计算）
	CountryCount() int
}

// Rander 随机数源接口，由 game.World 的 Rng 实现。
// 实体内的随机调用统一走它，保证单会话顺序确定性。
type Rander interface {
	IntRange(min, max int) int
	IntN(n int) int
	Float64() float64
	Chance(p float64) bool
}

// SetRand 供 World 注入当前会话的随机源。
func (g *General) SetRand(r Rander) { g.rand = r }

// SetRand 供 World 注入当前会话的随机源（City 版本）。
func (c *City) SetRand(r Rander) { c.rand = r }

// SetRand 供 World 注入当前会话的随机源（Country 版本）。
func (c *Country) SetRand(r Rander) { c.rand = r }

// itoa 整数转字符串（统一辅助）
func itoa(v int) string { return strconv.Itoa(v) }
