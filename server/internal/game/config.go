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
	GeneralId  int
	GeneralName string
	DebutYear  int
	DebutCity  int
	Phase      int
	Status     int
	Level      int
	Army       []int
	Health     int
	Lead       int
	Force      int
	Wisdom     int
	Govern     int
	Charm      int
	Loyalty    int
	Arm        int
	Armor      int
	Soldiers   int
	FollowWho  int
	Experience int
	Skills     []int
}

type CityData struct {
	CityID   int
	CityName string
	OwnerID  int
	PrefectID int
	Rule     int
	Money    int
	Grain    int
	Treasures int
	Agriculture int
	Commerce int
	Population int
	Prevention int
	ReserveSoldiers int
	CitySchool bool
	CityGrainShop bool
	CityHospital bool
	CityWeaponShop int
	WarWeaponShop int
	ConnectCityId []int
	MapPosition   []int
}

type CountryData struct {
	CountryId     int
	CountryKingId int
	CountryColor  string
	CanBeChoose   bool
	Inheritors    []int
}

type WeaponData struct {
	WeaponID   int
	WeaponName string
	Price      int
	Property   int
	Weight     int
	Kind       int
	IsUnique   bool
	Smithy     int
}
