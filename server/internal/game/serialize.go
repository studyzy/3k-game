package game

import (
	"encoding/json"
	"strconv"

	"3k-server/internal/game/entities"
)

// ---- 状态序列化（对应 data_manager.gd + 补齐 4 处存档缺口） ----

// ToSnapshot 生成全量快照（S2C_WorldSnapshot body）
func (w *World) ToSnapshot(sessionId string, version int) map[string]interface{} {
	return map[string]interface{}{
		"sessionId":      sessionId,
		"rngSeed":        w.RngSeed(),
		"sessionVersion": version,
		"gameInfo":       w.GameInfoDict(),
		"generals":       w.generalsDict(),
		"cities":         w.citiesDict(),
		"countries":      w.countriesDict(),
		"weapons":        w.weaponsDict(),
		"countrySequence": w.CountrySequence,
	}
}

// Serialize 序列化完整状态为 JSON（存档用）
func (w *World) Serialize() ([]byte, error) {
	doc := map[string]interface{}{
		"kingName":         w.GameInfo.ShowInfo, // 保留字段（原存档有）
		"years":            w.GameInfo.Years,
		"month":            w.GameInfo.Month,
		"difficult":        w.GameInfo.Difficult,
		"playerCountryId":  w.GameInfo.PlayerCountryId,
		"playerOrderNum":   w.GameInfo.PlayerOrderNum,
		"doCityId":         w.GameInfo.DoCityId,
		"attackCount":      w.GameInfo.AttackCount,
		"playingState":     int(w.GameInfo.PlayingState),
		"curTurnIndex":     w.GameInfo.CurTurnIndex,
		"curTurnCountryId": w.GameInfo.CurTurnCountryId,
		"task":             int(w.GameInfo.Task),
		"targetCityId":     w.GameInfo.TargetCityId,
		"targetCountryId":  w.GameInfo.TargetCountryId,
		"targetGeneralIds": w.GameInfo.TargetGeneralIds,
		"optionalGeneralIds": w.GameInfo.OptionalGeneralIds,
		"doGeneralIds":     w.GameInfo.DoGeneralIds,
		"rngSeed":          w.RngSeed(),
		"countrySequence":  w.CountrySequence,
		"generalDictionary": w.generalsDict(),
		"cityDictionary":    w.citiesDict(),
		"countryDictionary": w.countriesDict(),
		"weaponDictionary":  w.weaponsDict(),
	}
	return json.Marshal(doc)
}

// ---- 各类 to_dict ----

func (w *World) GameInfoDict() map[string]interface{} {
	return map[string]interface{}{
		"years":              w.GameInfo.Years,
		"month":              w.GameInfo.Month,
		"curTurnIndex":       w.GameInfo.CurTurnIndex,
		"curTurnCountryId":   w.GameInfo.CurTurnCountryId,
		"playerCountryId":    w.GameInfo.PlayerCountryId,
		"playerOrderNum":     w.GameInfo.PlayerOrderNum,
		"difficult":          w.GameInfo.Difficult,
		"attackCount":        w.GameInfo.AttackCount,
		"playingState":       int(w.GameInfo.PlayingState),
		"doCityId":           w.GameInfo.DoCityId,
		"showInfo":           w.GameInfo.ShowInfo,
		"optionalGeneralIds": w.GameInfo.OptionalGeneralIds,
		"targetGeneralIds":   w.GameInfo.TargetGeneralIds,
		"doGeneralIds":       w.GameInfo.DoGeneralIds,
	}
}

func (w *World) generalsDict() map[string]interface{} {
	out := map[string]interface{}{}
	for id, g := range w.Generals {
		out[itoa(id)] = g
	}
	return out
}

func (w *World) citiesDict() map[string]interface{} {
	out := map[string]interface{}{}
	for id, c := range w.Cities {
		out[itoa(id)] = c
	}
	return out
}

func (w *World) countriesDict() map[string]interface{} {
	out := map[string]interface{}{}
	for id, c := range w.Countries {
		out[itoa(id)] = c
	}
	return out
}

func (w *World) weaponsDict() map[string]interface{} {
	out := map[string]interface{}{}
	for id, wp := range w.Weapons {
		out[itoa(id)] = wp
	}
	return out
}

func itoa(v int) string { return strconv.Itoa(v) }

// Deserialize 从存档 JSON 恢复 World 状态（对应 load_game）
func (w *World) Deserialize(data []byte) error {
	var doc map[string]interface{}
	if err := json.Unmarshal(data, &doc); err != nil {
		return err
	}
	w.GameInfo.Years = intNum(doc["years"])
	w.GameInfo.Month = intNum(doc["month"])
	w.GameInfo.Difficult = intNum(doc["difficult"])
	w.GameInfo.PlayerCountryId = intNum(doc["playerCountryId"])
	w.GameInfo.PlayerOrderNum = intNum(doc["playerOrderNum"])
	w.GameInfo.DoCityId = intNum(doc["doCityId"])
	w.GameInfo.AttackCount = intNum(doc["attackCount"])
	w.GameInfo.PlayingState = GameState(intNum(doc["playingState"]))
	w.GameInfo.CurTurnIndex = intNum(doc["curTurnIndex"])
	w.GameInfo.CurTurnCountryId = intNum(doc["curTurnCountryId"])
	w.GameInfo.Task = TaskType(intNum(doc["task"]))
	w.GameInfo.TargetCityId = intNum(doc["targetCityId"])
	w.GameInfo.TargetCountryId = intNum(doc["targetCountryId"])
	w.GameInfo.ShowInfo = strNum(doc["kingName"])
	w.CountrySequence = intSlice(doc["countrySequence"])

	// 恢复武将/城池/势力（覆盖已有实体字段）
	if gd, ok := doc["generalDictionary"].(map[string]interface{}); ok {
		for k, v := range gd {
			if id := atoiSafe(k, 0); id != 0 {
				if g := w.Generals[id]; g != nil {
					applyGeneralFields(g, v)
				}
			}
		}
	}
	if cd, ok := doc["cityDictionary"].(map[string]interface{}); ok {
		for k, v := range cd {
			if id := atoiSafe(k, 0); id != 0 {
				if c := w.Cities[id]; c != nil {
					applyCityFields(c, v)
				}
			}
		}
	}
	if cd, ok := doc["countryDictionary"].(map[string]interface{}); ok {
		for k, v := range cd {
			if id := atoiSafe(k, 0); id != 0 {
				if c := w.Countries[id]; c != nil {
					applyCountryFields(c, v)
				}
			}
		}
	}
	w.injectRand()
	return nil
}

// applyGeneralFields 从 JSON 恢复武将字段
func applyGeneralFields(g *entities.General, v interface{}) {
	m, ok := v.(map[string]interface{})
	if !ok {
		return
	}
	g.GeneralName = strNum(m["generalName"])
	g.Status = intNum(m["status"])
	g.Level = intNum(m["level"])
	g.Health = intNum(m["health"])
	g.MaxHealth = intNum(m["maxHealth"])
	g.Lead = intNum(m["lead"])
	g.Force = intNum(m["force"])
	g.Wisdom = intNum(m["wisdom"])
	g.Govern = intNum(m["govern"])
	g.Charm = intNum(m["charm"])
	g.Loyalty = intNum(m["loyalty"])
	g.Arm = intNum(m["arm"])
	g.Armor = intNum(m["armor"])
	g.Soldiers = intNum(m["soldiers"])
	g.Experience = intNum(m["experience"])
	g.DebutCity = intNum(m["debutCity"])
	g.LeadExp = intNum(m["leadExp"])
	g.ForceExp = intNum(m["forceExp"])
	g.WisdomExp = intNum(m["wisdomExp"])
	g.CharmExp = intNum(m["charmExp"])
	g.GovernExp = intNum(m["governExp"])
	g.IsDie = boolNum(m["isDie"])
}

// applyCityFields 从 JSON 恢复城池字段（含4缺口数组）
func applyCityFields(c *entities.City, v interface{}) {
	m, ok := v.(map[string]interface{})
	if !ok {
		return
	}
	c.OwnerID = intNum(m["ownerID"])
	c.PrefectID = intNum(m["prefectID"])
	c.Rule = intNum(m["rule"])
	c.Money = intNum(m["money"])
	c.Grain = intNum(m["grain"])
	c.Treasures = intNum(m["treasures"])
	c.Agriculture = intNum(m["agriculture"])
	c.Commerce = intNum(m["commerce"])
	c.Population = intNum(m["population"])
	c.Prevention = intNum(m["prevention"])
	c.ReserveSoldiers = intNum(m["reserveSoldiers"])
	c.CitySchool = boolNum(m["citySchool"])
	c.CityGrainShop = boolNum(m["cityGrainShop"])
	c.CityHospital = boolNum(m["cityHospital"])
	c.CityWeaponShop = intNum(m["cityWeaponShop"])
	c.WarWeaponShop = intNum(m["warWeaponShop"])
	c.OfficeGeneralId = intSlice(m["officeGeneralId"])
	c.ReservedGeneralId = intSlice(m["reservedGeneralId"])
	c.NotFoundGeneralId = intSlice(m["notFoundGeneralId"])
	c.JailGeneralId = intSlice(m["jailGeneralId"])
}

// applyCountryFields 从 JSON 恢复势力字段
func applyCountryFields(c *entities.Country, v interface{}) {
	m, ok := v.(map[string]interface{})
	if !ok {
		return
	}
	c.CountryKingId = intNum(m["countryKingId"])
	c.CountryColor = strNum(m["countryColor"])
	c.CanBeChoose = boolNum(m["canBeChoose"])
	c.CityIDs = intSlice(m["cityIDs"])
	c.Inheritors = intSlice(m["inheritors"])
}

// 数值转换辅助
func intNum(v interface{}) int {
	switch t := v.(type) {
	case float64:
		return int(t)
	case int:
		return t
	case string:
		return atoiSafe(t, 0)
	}
	return 0
}

func strNum(v interface{}) string {
	if s, ok := v.(string); ok {
		return s
	}
	return ""
}

func boolNum(v interface{}) bool {
	if b, ok := v.(bool); ok {
		return b
	}
	return false
}

func intSlice(v interface{}) []int {
	arr, ok := v.([]interface{})
	if !ok {
		return nil
	}
	var out []int
	for _, x := range arr {
		out = append(out, intNum(x))
	}
	return out
}
