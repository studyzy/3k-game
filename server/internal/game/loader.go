package game

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"3k-server/internal/game/entities"
	"3k-server/internal/game/rng"
)

// DataDir 服务器权威数据目录
var DataDir = "data"

// NewWorldFromData 从数据目录加载静态配置并初始化全新 WorldState。
// 对应 DataManager.load_all_configs() + _initialize()
func NewWorldFromData(dataDir string, seed int64) (*World, error) {
	w := &World{
		Rng:      rng.NewSeededRng(seed),
		Generals: map[int]*entities.General{},
		Cities:   map[int]*entities.City{},
		Countries: map[int]*entities.Country{},
		Weapons:  map[int]*entities.Weapon{},
		Config:   &Config{Maps: map[int][][]int{}, Formations: map[string][][]int{}},
		Texts:    NewTexts(),
	}
	w.GameInfo.Reset()

	if err := loadGenerals(w, filepath.Join(dataDir, "GeneralData.json")); err != nil {
		return nil, err
	}
	if err := loadCities(w, filepath.Join(dataDir, "CityData.json")); err != nil {
		return nil, err
	}
	if err := loadCountries(w, filepath.Join(dataDir, "CountryData.json")); err != nil {
		return nil, err
	}
	if err := loadWeapons(w, filepath.Join(dataDir, "WeaponData.json")); err != nil {
		return nil, err
	}

	initialize(w)
	w.injectRand()
	return w, nil
}

// injectRand 把会话随机源注入所有实体（保证单会话随机确定性）
func (w *World) injectRand() {
	for _, g := range w.Generals {
		g.SetRand(w.Rng)
	}
	for _, c := range w.Cities {
		c.SetRand(w.Rng)
	}
	for _, c := range w.Countries {
		c.SetRand(w.Rng)
	}
}

// loadGenerals 加载武将
func loadGenerals(w *World, path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var raw []map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	for _, m := range raw {
		g := &entities.General{
			GeneralId:   int(m["generalId"].(float64)),
			GeneralName: m["generalName"].(string),
			DebutYear:   int(m["debutYear"].(float64)),
			DebutCity:   int(m["debutCity"].(float64)),
			Phase:       int(m["phase"].(float64)),
			Status:      int(m["status"].(float64)),
			Level:       int(m["level"].(float64)),
			Army:        intArr(m["army"]),
			Health:      int(m["health"].(float64)),
			MaxHealth:   100,
			Lead:        int(m["lead"].(float64)),
			Force:       int(m["force"].(float64)),
			Wisdom:      int(m["wisdom"].(float64)),
			Govern:      int(m["govern"].(float64)),
			Charm:       int(m["charm"].(float64)),
			Loyalty:     int(m["loyalty"].(float64)),
			Arm:         int(m["arm"].(float64)),
			Armor:       int(m["armor"].(float64)),
			Soldiers:    int(m["soldiers"].(float64)),
			FollowWho:   int(m["followWho"].(float64)),
			Experience:  int(m["experience"].(float64)),
			Skills:      intArr(m["skills"]),
		}
		w.Generals[g.GeneralId] = g
	}
	return nil
}

// loadCities 加载城池
func loadCities(w *World, path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var raw []map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	for _, m := range raw {
		c := &entities.City{
			CityID:    int(m["cityID"].(float64)),
			CityName:  m["cityName"].(string),
			OwnerID:   int(m["ownerID"].(float64)),
			PrefectID: int(m["prefectID"].(float64)),
			Rule:      int(m["rule"].(float64)),
			Money:     int(m["money"].(float64)),
			Grain:     int(m["grain"].(float64)),
			Treasures: int(m["treasures"].(float64)),
			Agriculture: int(m["agriculture"].(float64)),
			Commerce:  int(m["commerce"].(float64)),
			Population: int(m["population"].(float64)),
			Prevention: int(m["prevention"].(float64)),
			ReserveSoldiers: int(m["reserveSoldiers"].(float64)),
			CitySchool: bool(m["citySchool"].(bool)),
			CityGrainShop: bool(m["cityGrainShop"].(bool)),
			CityHospital: bool(m["cityHospital"].(bool)),
			CityWeaponShop: int(m["cityWeaponShop"].(float64)),
			WarWeaponShop: int(m["warWeaponShop"].(float64)),
			ConnectCityId: intArr(m["connectCityId"]),
			MapPosition: intArr(m["mapPosition"]),
		}
		w.Cities[c.CityID] = c
	}
	return nil
}

// loadCountries 加载势力
func loadCountries(w *World, path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var raw []map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	for _, m := range raw {
		c := &entities.Country{
			CountryId:     int(m["countryId"].(float64)),
			CountryKingId: int(m["countryKingId"].(float64)),
			CountryColor:  m["countryColor"].(string),
			CanBeChoose:   bool(m["canBeChoose"].(bool)),
			Inheritors:    intArr(m["inheritors"]),
		}
		w.Countries[c.CountryId] = c
	}
	return nil
}

// loadWeapons 加载武器
func loadWeapons(w *World, path string) error {
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	var raw []map[string]interface{}
	if err := json.Unmarshal(data, &raw); err != nil {
		return err
	}
	for _, m := range raw {
		wp := &entities.Weapon{
			WeaponID:   int(m["weaponID"].(float64)),
			WeaponName: m["weaponName"].(string),
			Price:      int(m["price"].(float64)),
			Property:   int(m["property"].(float64)),
			Weight:     int(m["weight"].(float64)),
			Kind:       int(m["kind"].(float64)),
			IsUnique:   bool(m["isUnique"].(bool)),
			Smithy:     int(m["smithy"].(float64)),
		}
		w.Weapons[wp.WeaponID] = wp
	}
	return nil
}

// intArr 把 JSON 数组转 []int
func intArr(v interface{}) []int {
	var out []int
	if arr, ok := v.([]interface{}); ok {
		for _, x := range arr {
			out = append(out, int(x.(float64)))
		}
	}
	return out
}

// initialize 建立城池-势力归属，分配武将到城池（对应 _initialize）
func initialize(w *World) {
	// 势力 cityIDs 从 City.ownerID 反向建立
	for id, c := range w.Countries {
		c.CityIDs = nil
		for _, city := range w.Cities {
			if city.OwnerID == c.CountryKingId {
				c.CityIDs = append(c.CityIDs, city.CityID)
			}
		}
		_ = id
	}
	// 分配武将到 debutCity
	for _, g := range w.Generals {
		city := w.Cities[g.DebutCity]
		if city == nil {
			continue
		}
		if g.Status == 1 {
			city.OfficeGeneralId = append(city.OfficeGeneralId, g.GeneralId)
		} else {
			city.ReservedGeneralId = append(city.ReservedGeneralId, g.GeneralId)
		}
	}
	// 自动任命太守（简化：首个在职武将）
	for _, city := range w.Cities {
		if len(city.OfficeGeneralId) > 0 && city.PrefectID == 0 {
			city.PrefectID = city.OfficeGeneralId[0]
		}
	}
}

// ReadWarMap 读取战争地图 CSV（19×32，对外暴露）
func (w *World) ReadWarMap(cityID int) [][]int {
	return w.readMapData(cityID)
}

// readMapData 读取战争地图 CSV（19×32）
func (w *World) readMapData(cityID int) [][]int {
	if m, ok := w.Config.Maps[cityID]; ok {
		return m
	}
	data, err := os.ReadFile(filepath.Join(DataDir, strconv.Itoa(cityID)+".CSV"))
	if err != nil {
		return nil
	}
	grid, _ := parseCSVInt(string(data))
	w.Config.Maps[cityID] = grid
	return grid
}

// parseCSVInt 解析 CSV 为 int 二维数组
func parseCSVInt(s string) ([][]int, error) {
	lines := strings.Split(strings.TrimSpace(s), "\n")
	var grid [][]int
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		var row []int
		for _, cell := range strings.Split(line, ",") {
			cell = strings.TrimSpace(cell)
			v, err := strconv.Atoi(cell)
			if err != nil {
				return nil, err
			}
			row = append(row, v)
		}
		grid = append(grid, row)
	}
	return grid, nil
}

// readFormation 读取阵型 CSV（7×16）
func (w *World) readFormation(name string) [][]int {
	if f, ok := w.Config.Formations[name]; ok {
		return f
	}
	data, err := os.ReadFile(filepath.Join(DataDir, name+".csv"))
	if err != nil {
		return nil
	}
	grid, _ := parseCSVInt(string(data))
	w.Config.Formations[name] = grid
	return grid
}
