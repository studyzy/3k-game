package entities

// Weapon 武器/防具，对应 scripts/data/weapon.gd
type Weapon struct {
	WeaponID   int    `json:"weaponID"`
	WeaponName string `json:"weaponName"`
	Price      int    `json:"price"`
	Property   int    `json:"property"`
	Weight     int    `json:"weight"`
	Kind       int    `json:"kind"` // 3=防具
	IsUnique   bool   `json:"isUnique"`
	Smithy     int    `json:"smithy"`
}

// CanSeized 单挑时可掉落武器
func (w *Weapon) CanSeized() bool { return true }
