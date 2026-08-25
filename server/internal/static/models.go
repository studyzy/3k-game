package static

// 静态数据 gorm 模型（SQLite/MySQL 通用）。
// 数组字段用 gorm serializer:json 存 text 列，JSON tag 保持 camelCase
// （与 server/data/*.json、客户端 from_dict 一致）。

// GeneralRow game_generals 表行（对齐 game.GeneralData）
type GeneralRow struct {
	GeneralId   int    `gorm:"column:general_id;primaryKey" json:"generalId"`
	GeneralName string `gorm:"column:general_name;size:64" json:"generalName"`
	DebutYear   int    `gorm:"column:debut_year" json:"debutYear"`
	DebutCity   int    `gorm:"column:debut_city" json:"debutCity"`
	Phase       int    `gorm:"column:phase" json:"phase"`
	Status      int    `gorm:"column:status" json:"status"`
	Level       int    `gorm:"column:level" json:"level"`
	Army        []int  `gorm:"column:army;type:text;serializer:json" json:"army"`
	Health      int    `gorm:"column:health" json:"health"`
	Lead        int    `gorm:"column:lead" json:"lead"`
	Force       int    `gorm:"column:force" json:"force"`
	Wisdom      int    `gorm:"column:wisdom" json:"wisdom"`
	Govern      int    `gorm:"column:govern" json:"govern"`
	Charm       int    `gorm:"column:charm" json:"charm"`
	Loyalty     int    `gorm:"column:loyalty" json:"loyalty"`
	Arm         int    `gorm:"column:arm" json:"arm"`
	Armor       int    `gorm:"column:armor" json:"armor"`
	Soldiers    int    `gorm:"column:soldiers" json:"soldiers"`
	FollowWho   int    `gorm:"column:follow_who" json:"followWho"`
	Experience  int    `gorm:"column:experience" json:"experience"`
	Skills      []int  `gorm:"column:skills;type:text;serializer:json" json:"skills"`
}

// TableName 表名
func (GeneralRow) TableName() string { return "game_generals" }

// CityRow game_cities 表行（对齐 game.CityData）
type CityRow struct {
	CityID          int    `gorm:"column:city_id;primaryKey" json:"cityID"`
	CityName        string `gorm:"column:city_name;size:64" json:"cityName"`
	OwnerID         int    `gorm:"column:owner_id" json:"ownerID"`
	PrefectID       int    `gorm:"column:prefect_id" json:"prefectID"`
	Rule            int    `gorm:"column:rule" json:"rule"`
	Money           int    `gorm:"column:money" json:"money"`
	Grain           int    `gorm:"column:grain" json:"grain"`
	Treasures       int    `gorm:"column:treasures" json:"treasures"`
	Agriculture     int    `gorm:"column:agriculture" json:"agriculture"`
	Commerce        int    `gorm:"column:commerce" json:"commerce"`
	Population      int    `gorm:"column:population" json:"population"`
	Prevention      int    `gorm:"column:prevention" json:"prevention"`
	ReserveSoldiers int    `gorm:"column:reserve_soldiers" json:"reserveSoldiers"`
	CitySchool      bool   `gorm:"column:city_school" json:"citySchool"`
	CityGrainShop   bool   `gorm:"column:city_grain_shop" json:"cityGrainShop"`
	CityHospital    bool   `gorm:"column:city_hospital" json:"cityHospital"`
	CityWeaponShop  int    `gorm:"column:city_weapon_shop" json:"cityWeaponShop"`
	WarWeaponShop   int    `gorm:"column:war_weapon_shop" json:"warWeaponShop"`
	ConnectCityId   []int  `gorm:"column:connect_city_id;type:text;serializer:json" json:"connectCityId"`
	MapPosition     []int  `gorm:"column:map_position;type:text;serializer:json" json:"mapPosition"`
}

// TableName 表名
func (CityRow) TableName() string { return "game_cities" }

// CountryRow game_countries 表行（对齐 game.CountryData）
type CountryRow struct {
	CountryId     int    `gorm:"column:country_id;primaryKey" json:"countryId"`
	CountryKingId int    `gorm:"column:country_king_id" json:"countryKingId"`
	CountryColor  string `gorm:"column:country_color;size:32" json:"countryColor"`
	CanBeChoose   bool   `gorm:"column:can_be_choose" json:"canBeChoose"`
	Inheritors    []int  `gorm:"column:inheritors;type:text;serializer:json" json:"inheritors"`
}

// TableName 表名
func (CountryRow) TableName() string { return "game_countries" }

// WeaponRow game_weapons 表行（对齐 game.WeaponData）
// 注：weaponID 从 0 开始（短剑=0），须关闭 autoIncrement 否则 gorm 会把 0 当空主键跳过。
type WeaponRow struct {
	WeaponID   int    `gorm:"column:weapon_id;primaryKey;autoIncrement:false" json:"weaponID"`
	WeaponName string `gorm:"column:weapon_name;size:64" json:"weaponName"`
	Price      int    `gorm:"column:price" json:"price"`
	Property   int    `gorm:"column:property" json:"property"`
	Weight     int    `gorm:"column:weight" json:"weight"`
	Kind       int    `gorm:"column:kind" json:"kind"`
	IsUnique   bool   `gorm:"column:is_unique" json:"isUnique"`
	Smithy     int    `gorm:"column:smithy" json:"smithy"`
}

// TableName 表名
func (WeaponRow) TableName() string { return "game_weapons" }

// ChapterRow game_chapters 表行（对齐 data/ChapterData.json）
type ChapterRow struct {
	Year         int    `gorm:"column:year;primaryKey" json:"year"`
	Title        string `gorm:"column:title;size:64" json:"title"`
	Introduction string `gorm:"column:introduction;type:text" json:"introduction"`
}

// TableName 表名
func (ChapterRow) TableName() string { return "game_chapters" }

// MapRow game_maps 表行（战争地图 19×32）
type MapRow struct {
	CityId int     `gorm:"column:city_id;primaryKey" json:"cityId"`
	Grid   [][]int `gorm:"column:grid;type:text;serializer:json" json:"grid"`
}

// TableName 表名
func (MapRow) TableName() string { return "game_maps" }

// FormationRow game_formations 表行（阵型 7×16）
type FormationRow struct {
	Name string  `gorm:"column:name;primaryKey;size:16" json:"name"`
	Grid [][]int `gorm:"column:grid;type:text;serializer:json" json:"grid"`
}

// TableName 表名
func (FormationRow) TableName() string { return "game_formations" }

// TextRow game_texts 表行（文案/数值表，k=原 GDScript 常量名，v=JSON 文本）
type TextRow struct {
	K string `gorm:"column:k;primaryKey;size:64" json:"k"`
	V string `gorm:"column:v;type:text" json:"v"`
}

// TableName 表名
func (TextRow) TableName() string { return "game_texts" }
