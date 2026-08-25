package static

import (
	"encoding/json"

	"3k-server/internal/game"
)

// MemoryStore 内存静态数据存储：直接从内嵌种子 JSON 解析，不依赖 DB。
// 供单测与无文件/无 DB 场景使用。
type MemoryStore struct {
	cfg   *game.Config
	texts *game.Texts
}

// NewMemoryStore 从内嵌种子 JSON 构建内存存储。
func NewMemoryStore() (*MemoryStore, error) {
	cfg, err := loadConfigFromSeed()
	if err != nil {
		return nil, err
	}
	texts, err := loadTextsFromSeed()
	if err != nil {
		return nil, err
	}
	return &MemoryStore{cfg: cfg, texts: texts}, nil
}

// Config 返回静态配置。
func (m *MemoryStore) Config() (*game.Config, error) { return m.cfg, nil }

// Texts 返回文案表。
func (m *MemoryStore) Texts() (*game.Texts, error) { return m.texts, nil }

// AllStatic 返回全量静态数据（从内嵌种子 JSON 解析）。
func (m *MemoryStore) AllStatic() (map[string]any, error) {
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
	chapters, err := loadRows[ChapterRow]("chapters.json")
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
	data, err := seedFS.ReadFile("seed_data/texts.json")
	if err != nil {
		return nil, err
	}
	var texts map[string]any
	if err := json.Unmarshal(data, &texts); err != nil {
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
		"texts":      texts,
	}, nil
}

// Close 无资源需释放。
func (m *MemoryStore) Close() error { return nil }
