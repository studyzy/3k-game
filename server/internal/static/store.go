package static

import (
	"encoding/json"
	"errors"
	"strings"

	"3k-server/internal/game"
	"github.com/glebarez/sqlite"
	"gorm.io/driver/mysql"
	"gorm.io/gorm"
)

// Store 静态数据存储接口（服务器权威数据源）。
type Store interface {
	Config() (*game.Config, error)      // 武将/城池/势力/武器 + 地图/阵型
	Texts() (*game.Texts, error)        // 文案与数值表
	AllStatic() (map[string]any, error) // 供 /game/static 下发的全量渲染数据
	Close() error
}

// GormStore 基于 gorm 的静态数据存储（SQLite/MySQL 通用）。
type GormStore struct {
	db *gorm.DB
}

// Open 打开静态数据存储并自动迁移、灌入种子数据。
// dsn 含 MySQL 特征（user:pass@tcp(...)）时用 MySQL，否则用 SQLite（文件路径或 :memory:）。
func Open(dsn string) (*GormStore, error) {
	if strings.TrimSpace(dsn) == "" {
		return nil, errors.New("empty static store dsn")
	}
	var dialector gorm.Dialector
	if isMySQL(dsn) {
		dialector = mysql.Open(dsn)
	} else {
		dialector = sqlite.Open(dsn)
	}
	db, err := gorm.Open(dialector, &gorm.Config{})
	if err != nil {
		return nil, err
	}
	if err := migrate(db); err != nil {
		return nil, err
	}
	if err := AutoSeed(db); err != nil {
		return nil, err
	}
	return &GormStore{db: db}, nil
}

// isMySQL 依据 DSN 判断是否 MySQL（user:pass@tcp(...) / @unix(...)）。
func isMySQL(dsn string) bool {
	return strings.Contains(dsn, "@tcp(") || strings.Contains(dsn, "@unix(")
}

// migrate 建 8 张静态数据表（AutoMigrate，SQLite/MySQL 通用）。
func migrate(db *gorm.DB) error {
	return db.AutoMigrate(
		&GeneralRow{}, &CityRow{}, &CountryRow{}, &WeaponRow{},
		&ChapterRow{}, &MapRow{}, &FormationRow{}, &TextRow{},
	)
}

// Config 读取全部静态配置（含地图/阵型，一次性加载）。
func (s *GormStore) Config() (*game.Config, error) {
	generals, err := findRows[GeneralRow](s.db)
	if err != nil {
		return nil, err
	}
	cities, err := findRows[CityRow](s.db)
	if err != nil {
		return nil, err
	}
	countries, err := findRows[CountryRow](s.db)
	if err != nil {
		return nil, err
	}
	weapons, err := findRows[WeaponRow](s.db)
	if err != nil {
		return nil, err
	}
	maps, err := findRows[MapRow](s.db)
	if err != nil {
		return nil, err
	}
	formations, err := findRows[FormationRow](s.db)
	if err != nil {
		return nil, err
	}
	return buildConfig(generals, cities, countries, weapons, maps, formations), nil
}

// Texts 读取文案与数值表。
func (s *GormStore) Texts() (*game.Texts, error) {
	var rows []TextRow
	if err := s.db.Find(&rows).Error; err != nil {
		return nil, err
	}
	if len(rows) == 0 {
		return nil, errors.New("game_texts 为空")
	}
	return buildTexts(rows)
}

// AllStatic 读取全量静态数据（供 /game/static 下发）。
func (s *GormStore) AllStatic() (map[string]any, error) {
	generals, err := findRows[GeneralRow](s.db)
	if err != nil {
		return nil, err
	}
	cities, err := findRows[CityRow](s.db)
	if err != nil {
		return nil, err
	}
	countries, err := findRows[CountryRow](s.db)
	if err != nil {
		return nil, err
	}
	weapons, err := findRows[WeaponRow](s.db)
	if err != nil {
		return nil, err
	}
	chapters, err := findRows[ChapterRow](s.db)
	if err != nil {
		return nil, err
	}
	maps, err := findRows[MapRow](s.db)
	if err != nil {
		return nil, err
	}
	formations, err := findRows[FormationRow](s.db)
	if err != nil {
		return nil, err
	}
	var textRows []TextRow
	if err := s.db.Find(&textRows).Error; err != nil {
		return nil, err
	}
	return map[string]any{
		"generals":   generals,
		"cities":     cities,
		"countries":  countries,
		"weapons":    weapons,
		"chapters":   chapters,
		"maps":       maps,
		"formations": formations,
		"texts":      textRowsToMap(textRows),
	}, nil
}

// Close 释放底层连接池。
func (s *GormStore) Close() error {
	sqlDB, err := s.db.DB()
	if err != nil {
		return err
	}
	return sqlDB.Close()
}

// findRows 读取某张表的全部行。
func findRows[T any](db *gorm.DB) ([]T, error) {
	var rows []T
	if err := db.Find(&rows).Error; err != nil {
		return nil, err
	}
	return rows, nil
}

// buildConfig 把表行转成 game.Config（含地图/阵型 map）。
func buildConfig(
	generals []GeneralRow,
	cities []CityRow,
	countries []CountryRow,
	weapons []WeaponRow,
	maps []MapRow,
	formations []FormationRow,
) *game.Config {
	cfg := &game.Config{
		Maps:       make(map[int][][]int, len(maps)),
		Formations: make(map[string][][]int, len(formations)),
	}
	for _, g := range generals {
		cfg.Generals = append(cfg.Generals, &game.GeneralData{
			GeneralId:   g.GeneralId,
			GeneralName: g.GeneralName,
			DebutYear:   g.DebutYear,
			DebutCity:   g.DebutCity,
			Phase:       g.Phase,
			Status:      g.Status,
			Level:       g.Level,
			Army:        g.Army,
			Health:      g.Health,
			Lead:        g.Lead,
			Force:       g.Force,
			Wisdom:      g.Wisdom,
			Govern:      g.Govern,
			Charm:       g.Charm,
			Loyalty:     g.Loyalty,
			Arm:         g.Arm,
			Armor:       g.Armor,
			Soldiers:    g.Soldiers,
			FollowWho:   g.FollowWho,
			Experience:  g.Experience,
			Skills:      g.Skills,
		})
	}
	for _, c := range cities {
		cfg.Cities = append(cfg.Cities, &game.CityData{
			CityID:          c.CityID,
			CityName:        c.CityName,
			OwnerID:         c.OwnerID,
			PrefectID:       c.PrefectID,
			Rule:            c.Rule,
			Money:           c.Money,
			Grain:           c.Grain,
			Treasures:       c.Treasures,
			Agriculture:     c.Agriculture,
			Commerce:        c.Commerce,
			Population:      c.Population,
			Prevention:      c.Prevention,
			ReserveSoldiers: c.ReserveSoldiers,
			CitySchool:      c.CitySchool,
			CityGrainShop:   c.CityGrainShop,
			CityHospital:    c.CityHospital,
			CityWeaponShop:  c.CityWeaponShop,
			WarWeaponShop:   c.WarWeaponShop,
			ConnectCityId:   c.ConnectCityId,
			MapPosition:     c.MapPosition,
		})
	}
	for _, c := range countries {
		cfg.Countries = append(cfg.Countries, &game.CountryData{
			CountryId:     c.CountryId,
			CountryKingId: c.CountryKingId,
			CountryColor:  c.CountryColor,
			CanBeChoose:   c.CanBeChoose,
			Inheritors:    c.Inheritors,
		})
	}
	for _, w := range weapons {
		cfg.Weapons = append(cfg.Weapons, &game.WeaponData{
			WeaponID:   w.WeaponID,
			WeaponName: w.WeaponName,
			Price:      w.Price,
			Property:   w.Property,
			Weight:     w.Weight,
			Kind:       w.Kind,
			IsUnique:   w.IsUnique,
			Smithy:     w.Smithy,
		})
	}
	for _, m := range maps {
		cfg.Maps[m.CityId] = m.Grid
	}
	for _, f := range formations {
		cfg.Formations[f.Name] = f.Grid
	}
	return cfg
}

// textRowsToMap 把 game_texts 行转成 map[string]any（v 反序列化为原生值）。
func textRowsToMap(rows []TextRow) map[string]any {
	m := make(map[string]any, len(rows))
	for _, r := range rows {
		var v any
		if json.Unmarshal([]byte(r.V), &v) == nil {
			m[r.K] = v
		}
	}
	return m
}

// buildTexts 把 game_texts 行合并为完整文案表。
func buildTexts(rows []TextRow) (*game.Texts, error) {
	data, err := json.Marshal(textRowsToMap(rows))
	if err != nil {
		return nil, err
	}
	return game.ParseTexts(data)
}
