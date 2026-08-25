package game

// Config 静态游戏配置（从 data/ 加载的 JSON 表）
type Config struct {
	Generals []*GeneralData
	Cities   []*CityData
	Countries []*CountryData
	Weapons  []*WeaponData
	// 地图与阵型懒加载缓存
	Maps      map[int][][]int
	Formations map[string][][]int
}

type GeneralData struct {
	GeneralId   int    `json:"generalId"`
	GeneralName string `json:"generalName"`
	DebutYear   int    `json:"debutYear"`
	DebutCity   int    `json:"debutCity"`
	Phase       int    `json:"phase"`
	Status      int    `json:"status"`
	Level       int    `json:"level"`
	Army        []int  `json:"army"`
	Health      int    `json:"health"`
	Lead        int    `json:"lead"`
	Force       int    `json:"force"`
	Wisdom      int    `json:"wisdom"`
	Govern      int    `json:"govern"`
	Charm       int    `json:"charm"`
	Loyalty     int    `json:"loyalty"`
	Arm         int    `json:"arm"`
	Armor       int    `json:"armor"`
	Soldiers    int    `json:"soldiers"`
	FollowWho   int    `json:"followWho"`
	Experience  int    `json:"experience"`
	Skills      []int  `json:"skills"`
}

type CityData struct {
	CityID          int    `json:"cityID"`
	CityName        string `json:"cityName"`
	OwnerID         int    `json:"ownerID"`
	PrefectID       int    `json:"prefectID"`
	Rule            int    `json:"rule"`
	Money           int    `json:"money"`
	Grain           int    `json:"grain"`
	Treasures       int    `json:"treasures"`
	Agriculture     int    `json:"agriculture"`
	Commerce        int    `json:"commerce"`
	Population      int    `json:"population"`
	Prevention      int    `json:"prevention"`
	ReserveSoldiers int    `json:"reserveSoldiers"`
	CitySchool      bool   `json:"citySchool"`
	CityGrainShop   bool   `json:"cityGrainShop"`
	CityHospital    bool   `json:"cityHospital"`
	CityWeaponShop  int    `json:"cityWeaponShop"`
	WarWeaponShop   int    `json:"warWeaponShop"`
	ConnectCityId   []int  `json:"connectCityId"`
	MapPosition     []int  `json:"mapPosition"`
}

type CountryData struct {
	CountryId     int    `json:"countryId"`
	CountryKingId int    `json:"countryKingId"`
	CountryColor  string `json:"countryColor"`
	CanBeChoose   bool   `json:"canBeChoose"`
	Inheritors    []int  `json:"inheritors"`
}

type WeaponData struct {
	WeaponID   int    `json:"weaponID"`
	WeaponName string `json:"weaponName"`
	Price      int    `json:"price"`
	Property   int    `json:"property"`
	Weight     int    `json:"weight"`
	Kind       int    `json:"kind"`
	IsUnique   bool   `json:"isUnique"`
	Smithy     int    `json:"smithy"`
}
