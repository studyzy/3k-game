package game

import "encoding/json"

// ParseTexts 从 texts.json 字节解析文案表（键与 Texts 的 json tag 一致）。
func ParseTexts(data []byte) (*Texts, error) {
	var t Texts
	if err := json.Unmarshal(data, &t); err != nil {
		return nil, err
	}
	return &t, nil
}

// mapRow 战争地图行（maps.json 单条）
type mapRow struct {
	CityID int     `json:"cityId"`
	Grid   [][]int `json:"grid"`
}

// formationRow 阵型行（formations.json 单条）
type formationRow struct {
	Name string  `json:"name"`
	Grid [][]int `json:"grid"`
}

// ParseConfig 从 6 类种子 JSON 字节解析静态配置（含地图/阵型，一次性加载）。
func ParseConfig(generals, cities, countries, weapons, maps, formations []byte) (*Config, error) {
	cfg := &Config{
		Maps:       map[int][][]int{},
		Formations: map[string][][]int{},
	}
	if err := json.Unmarshal(generals, &cfg.Generals); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(cities, &cfg.Cities); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(countries, &cfg.Countries); err != nil {
		return nil, err
	}
	if err := json.Unmarshal(weapons, &cfg.Weapons); err != nil {
		return nil, err
	}
	var mapsRows []mapRow
	if err := json.Unmarshal(maps, &mapsRows); err != nil {
		return nil, err
	}
	for _, m := range mapsRows {
		cfg.Maps[m.CityID] = m.Grid
	}
	var formationRows []formationRow
	if err := json.Unmarshal(formations, &formationRows); err != nil {
		return nil, err
	}
	for _, f := range formationRows {
		cfg.Formations[f.Name] = f.Grid
	}
	return cfg, nil
}
