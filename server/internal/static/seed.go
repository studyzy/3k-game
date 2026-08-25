package static

import (
	"embed"
	"encoding/json"
	"sort"

	"3k-server/internal/game"
	"gorm.io/gorm"
)

// seedFS 内嵌权威种子 JSON（由 server/cmd/seed 生成）。
// 运行时不再读 server/data/，全部从这些内嵌数据灌库/解析。
//
//go:embed seed_data/*.json
var seedFS embed.FS

// loadRows 从内嵌 seed JSON 读取某张表的行（数组）。
func loadRows[T any](file string) ([]T, error) {
	data, err := seedFS.ReadFile("seed_data/" + file)
	if err != nil {
		return nil, err
	}
	var rows []T
	if err := json.Unmarshal(data, &rows); err != nil {
		return nil, err
	}
	return rows, nil
}

// loadTextsFromSeed 从内嵌 texts.json 解析完整文案表。
func loadTextsFromSeed() (*game.Texts, error) {
	data, err := seedFS.ReadFile("seed_data/texts.json")
	if err != nil {
		return nil, err
	}
	return game.ParseTexts(data)
}

// loadConfigFromSeed 从内嵌种子 JSON 构建静态配置（含地图/阵型，一次性全量加载）。
func loadConfigFromSeed() (*game.Config, error) {
	generals, err := loadRows[GeneralRow]("generals.json")
	if err != nil {
		return nil, err
	}
	cities, err := loadRows[CityRow]("cities.json")
	if err != nil {
		return nil, err
	}
	countries, err := loadRows[CountryRow]("countries.json")
	if err != nil {
		return nil, err
	}
	weapons, err := loadRows[WeaponRow]("weapons.json")
	if err != nil {
		return nil, err
	}
	maps, err := loadRows[MapRow]("maps.json")
	if err != nil {
		return nil, err
	}
	formations, err := loadRows[FormationRow]("formations.json")
	if err != nil {
		return nil, err
	}
	return buildConfig(generals, cities, countries, weapons, maps, formations), nil
}

// AutoSeed 表空则灌入内嵌种子 JSON（幂等）。
func AutoSeed(db *gorm.DB) error {
	if err := seedTable[GeneralRow](db, "generals.json"); err != nil {
		return err
	}
	if err := seedTable[CityRow](db, "cities.json"); err != nil {
		return err
	}
	if err := seedTable[CountryRow](db, "countries.json"); err != nil {
		return err
	}
	if err := seedTable[WeaponRow](db, "weapons.json"); err != nil {
		return err
	}
	if err := seedTable[ChapterRow](db, "chapters.json"); err != nil {
		return err
	}
	if err := seedTable[MapRow](db, "maps.json"); err != nil {
		return err
	}
	if err := seedTable[FormationRow](db, "formations.json"); err != nil {
		return err
	}
	return seedTexts(db)
}

// seedTable 若表为空，从内嵌 JSON 插入全部行。
func seedTable[T any](db *gorm.DB, file string) error {
	var model T
	var count int64
	if err := db.Model(&model).Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	rows, err := loadRows[T](file)
	if err != nil {
		return err
	}
	if len(rows) == 0 {
		return nil
	}
	return db.Create(&rows).Error
}

// seedTexts 若 game_texts 为空，把内嵌 texts.json 对象拆成 k/v 行插入。
func seedTexts(db *gorm.DB) error {
	var count int64
	if err := db.Model(&TextRow{}).Count(&count).Error; err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	data, err := seedFS.ReadFile("seed_data/texts.json")
	if err != nil {
		return err
	}
	var m map[string]json.RawMessage
	if err := json.Unmarshal(data, &m); err != nil {
		return err
	}
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	rows := make([]TextRow, 0, len(keys))
	for _, k := range keys {
		rows = append(rows, TextRow{K: k, V: string(m[k])})
	}
	return db.Create(&rows).Error
}
