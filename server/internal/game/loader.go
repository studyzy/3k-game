package game

import (
	"3k-server/internal/game/entities"
	"3k-server/internal/game/rng"
)

// NewWorld 用静态配置与文案表初始化全新 WorldState。
// cfg/texts 由 static.Store 提供（DB 或内存解析），不再读文件。
func NewWorld(cfg *Config, texts *Texts, seed int64) *World {
	w := &World{
		Rng:       rng.NewSeededRng(seed),
		Generals:  map[int]*entities.General{},
		Cities:    map[int]*entities.City{},
		Countries: map[int]*entities.Country{},
		Weapons:   map[int]*entities.Weapon{},
		Config:    cfg,
		Texts:     texts,
	}
	w.GameInfo.Reset()

	for _, gd := range cfg.Generals {
		g := &entities.General{
			GeneralId:   gd.GeneralId,
			GeneralName: gd.GeneralName,
			DebutYear:   gd.DebutYear,
			DebutCity:   gd.DebutCity,
			Phase:       gd.Phase,
			Status:      gd.Status,
			Level:       gd.Level,
			Army:        gd.Army,
			Health:      gd.Health,
			MaxHealth:   100,
			Lead:        gd.Lead,
			Force:       gd.Force,
			Wisdom:      gd.Wisdom,
			Govern:      gd.Govern,
			Charm:       gd.Charm,
			Loyalty:     gd.Loyalty,
			Arm:         gd.Arm,
			Armor:       gd.Armor,
			Soldiers:    gd.Soldiers,
			FollowWho:   gd.FollowWho,
			Experience:  gd.Experience,
			Skills:      gd.Skills,
		}
		w.Generals[g.GeneralId] = g
	}

	for _, cd := range cfg.Cities {
		c := &entities.City{
			CityID:          cd.CityID,
			CityName:        cd.CityName,
			OwnerID:         cd.OwnerID,
			PrefectID:       cd.PrefectID,
			Rule:            cd.Rule,
			Money:           cd.Money,
			Grain:           cd.Grain,
			Treasures:       cd.Treasures,
			Agriculture:     cd.Agriculture,
			Commerce:        cd.Commerce,
			Population:      cd.Population,
			Prevention:      cd.Prevention,
			ReserveSoldiers: cd.ReserveSoldiers,
			CitySchool:      cd.CitySchool,
			CityGrainShop:   cd.CityGrainShop,
			CityHospital:    cd.CityHospital,
			CityWeaponShop:  cd.CityWeaponShop,
			WarWeaponShop:   cd.WarWeaponShop,
			ConnectCityId:   cd.ConnectCityId,
			MapPosition:     cd.MapPosition,
		}
		w.Cities[c.CityID] = c
	}

	for _, cd := range cfg.Countries {
		c := &entities.Country{
			CountryId:     cd.CountryId,
			CountryKingId: cd.CountryKingId,
			CountryColor:  cd.CountryColor,
			CanBeChoose:   cd.CanBeChoose,
			Inheritors:    cd.Inheritors,
		}
		w.Countries[c.CountryId] = c
	}

	for _, wd := range cfg.Weapons {
		wp := &entities.Weapon{
			WeaponID:   wd.WeaponID,
			WeaponName: wd.WeaponName,
			Price:      wd.Price,
			Property:   wd.Property,
			Weight:     wd.Weight,
			Kind:       wd.Kind,
			IsUnique:   wd.IsUnique,
			Smithy:     wd.Smithy,
		}
		w.Weapons[wp.WeaponID] = wp
	}

	initialize(w)
	w.injectRand()
	return w
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

// initialize 建立城池-势力归属，分配武将到城池（对应 _initialize）
func initialize(w *World) {
	// 势力 cityIDs 从 City.ownerID 反向建立
	for _, c := range w.Countries {
		c.CityIDs = nil
		for _, city := range w.Cities {
			if city.OwnerID == c.CountryKingId {
				c.CityIDs = append(c.CityIDs, city.CityID)
			}
		}
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

// ReadWarMap 读取战争地图（19×32，数据已在 Config.Maps 中）。
func (w *World) ReadWarMap(cityID int) [][]int {
	if w.Config == nil {
		return nil
	}
	return w.Config.Maps[cityID]
}
