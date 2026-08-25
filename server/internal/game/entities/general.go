package entities

// General 武将，对应 scripts/data/general.gd
type General struct {
	GeneralId   int    `json:"generalId"`
	GeneralName string `json:"generalName"`
	DebutYear   int    `json:"debutYear"`
	DebutCity   int    `json:"debutCity"`
	Phase       int    `json:"phase"`
	Status      int    `json:"status"` // 1=在职 0=在野
	Level       int    `json:"level"`
	Army        []int  `json:"army"` // 平/山/水 适性 0-3
	Health      int    `json:"health"`
	MaxHealth   int    `json:"maxHealth"`
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
	Skills      []int  `json:"skills"` // 5 组 × 10bit 位掩码
	LeadExp     int    `json:"leadExp"`
	ForceExp    int    `json:"forceExp"`
	WisdomExp   int    `json:"wisdomExp"`
	CharmExp    int    `json:"charmExp"`
	GovernExp   int    `json:"governExp"`
	IsDie       bool   `json:"isDie"`

	rand Rander // 会话随机源（World 注入，不序列化）
}

const MaxAttribute = 120

var LevelUpExp = []int{6000, 10000, 14000, 18000, 22000, 26000, 30000, 32767}

// IsKingBy 判断某武将是否为指定君主id的君主
func (g *General) IsKingBy(kingId int) bool { return g.GeneralId == kingId }

// HasSkill 判断特技位掩码
func (g *General) HasSkill(kind, index int) bool {
	if kind < 1 || kind > len(g.Skills) {
		return false
	}
	return ((g.Skills[kind-1] >> (10 - index)) & 0x1) == 1
}

// HasSkill1..HasSkill5 便捷方法
func (g *General) HasSkill1(id int) bool { return g.HasSkill(1, id) }
func (g *General) HasSkill2(id int) bool { return g.HasSkill(2, id) }
func (g *General) HasSkill3(id int) bool { return g.HasSkill(3, id) }
func (g *General) HasSkill4(id int) bool { return g.HasSkill(4, id) }
func (g *General) HasSkill5(id int) bool { return g.HasSkill(5, id) }

func (g *General) GetHp() int { return g.Health }

// SetHp 设置体力（钳制0-maxHealth）
func (g *General) SetHp(v int) {
	if v < 0 {
		g.Health = 0
	} else if v > g.MaxHealth {
		g.Health = g.MaxHealth
	} else {
		g.Health = v
	}
}

// AddHp 增加体力，返回实际增量
func (g *General) AddHp(v int) int {
	old := g.Health
	g.SetHp(g.Health + v)
	return g.Health - old
}

// SubHp 减少体力，返回是否归零
func (g *General) SubHp(v int) bool {
	if g.Health <= v {
		g.Health = 0
		return true
	}
	g.Health -= v
	return false
}

// GetSalary 薪水 = 1 + level*2
func (g *General) GetSalary() int { return 1 + g.Level*2 }

// SetLoyalty 设置忠诚（钳制0-100）
func (g *General) SetLoyalty(v int) {
	if v < 0 {
		g.Loyalty = 0
	} else if v > 100 {
		g.Loyalty = 100
	} else {
		g.Loyalty = v
	}
}

// GetLoyalty 忠诚
func (g *General) GetLoyalty() int { return g.Loyalty }

// SubLoyalty 忠诚减少
func (g *General) SubLoyalty(v int) { g.SetLoyalty(g.Loyalty - v) }

// AddLoyalty 忠诚增加（由调用方传入君主id判断封顶，君主100其余99）
func (g *General) AddLoyalty(kingId int, v int) {
	if g.Loyalty+v >= 100 {
		if g.IsKingBy(kingId) {
			g.Loyalty = 100
		} else {
			g.Loyalty = 99
		}
	} else {
		g.Loyalty += v
	}
}

// GetMaxExp 当前等级升级所需经验
func (g *General) GetMaxExp() int {
	if g.Level <= 0 || g.Level > len(LevelUpExp) {
		return 32767
	}
	return LevelUpExp[g.Level-1]
}

// AllStatus 五维总和
func (g *General) AllStatus() int {
	return g.Lead + g.Govern + g.Force + g.Charm + g.Wisdom
}

// GetMaxSoldierNum 带兵上限
func (g *General) GetMaxSoldierNum() int {
	if g.HasSkill5(0) { // skills[4] bit0：特技"一骑"锁3000
		return 3000
	}
	v := 1000 + 12*g.Lead + 100*g.Level
	if v < 0 {
		return 0
	}
	if v > 3000 {
		return 3000
	}
	return v
}

// SetSoldiers 钳制带兵数
func (g *General) SetSoldiers(v int) {
	max := g.GetMaxSoldierNum()
	if v < 0 {
		g.Soldiers = 0
	} else if v > max {
		g.Soldiers = max
	} else {
		g.Soldiers = v
	}
}

// SubSoldiers 减少带兵
func (g *General) SubSoldiers(v int) { g.SetSoldiers(g.Soldiers - v) }

// GetAttackPower 攻击力 = force*(1+wp/100)*(level+19)/20
func (g *General) GetAttackPower(w WeaponProvider) int {
	wp := 0
	if w != nil {
		wp = w.Weapon(g.Arm).Property
	}
	return int(float64(g.Force) * (1 + float64(wp)/100.0) * float64(g.Level+19) / 20.0)
}

// GetDefendPower 防御力
func (g *General) GetDefendPower(w WeaponProvider) int {
	ap := 0
	if w != nil {
		ap = w.Weapon(g.Armor).Property
	}
	return int(float64(g.Force) * (1 + float64(ap)/100.0) * float64(g.Level+19) / 20.0)
}

// WeaponProvider 提供武器查询（避免循环依赖，由 World 实现）
type WeaponProvider interface {
	Weapon(id int) *Weapon
}

// GetPlanNum 计策数
func (g *General) GetPlanNum() int {
	switch {
	case g.Wisdom >= 100 && g.Level >= 8:
		return 16
	case g.Wisdom >= 95 && g.Level >= 7:
		return 15
	case g.Wisdom >= 93 && g.Level >= 5:
		return 14
	case g.Wisdom >= 90 && g.Level >= 4:
		return 12
	case g.Wisdom >= 85:
		return 10
	case g.Wisdom >= 80:
		return 8
	case g.Wisdom >= 60:
		return 6
	case g.Wisdom < 40:
		return 2
	default:
		return 4
	}
}

// GetArmyS 适性字符串（对应 get_army_s）
func (g *General) GetArmyS() string {
	suffixes := []string{"C", "B", "A", "S"}
	prefixes := []string{"平", "山", "水"}
	result := ""
	n := len(g.Army)
	if n > len(prefixes) {
		n = len(prefixes)
	}
	for i := 0; i < n; i++ {
		a := g.Army[i]
		if a < 0 {
			a = 0
		} else if a >= len(suffixes) {
			a = len(suffixes) - 1
		}
		result += prefixes[i] + suffixes[a]
	}
	return result
}

// GetActiveSkills 激活特技名列表（对应 get_active_skills）
func (g *General) GetActiveSkills(names []string) []string {
	var active []string
	for i := 0; i < len(g.Skills); i++ {
		v := g.Skills[i]
		if v == 0 {
			continue
		}
		for bit := 0; bit < 10; bit++ {
			if (v & (1 << (10 - bit))) != 0 {
				idx := i*10 + bit
				if idx < len(names) {
					active = append(active, names[idx])
				}
			}
		}
	}
	return active
}

// ---- 经验与升级 ----

// AddExperience 增加经验，满则升级（对应 general.add_experience）
func (g *General) AddExperience(exp int) {
	if exp <= 0 {
		return
	}
	g.Experience += exp
	for g.Experience >= g.GetMaxExp() {
		g.Experience -= g.GetMaxExp()
		g.generalUpgrade()
		if g.Level >= len(LevelUpExp) {
			g.Experience = 0
			break
		}
	}
}

// GetGeneralGrade 武将评级：0愚钝 1平庸 2良才 3精英 4奇才 5怪才
func (g *General) GetGeneralGrade() int {
	score := g.AllStatus()
	grade := 0
	switch {
	case score <= 196:
		grade = 0
	case score <= 282:
		grade = 1
	case score <= 345:
		grade = 2
	case score <= 421:
		grade = 3
	default:
		grade = 4
	}
	if g.Lead >= 95 || g.Govern >= 95 || g.Force >= 95 || g.Charm >= 95 || g.Wisdom >= 95 {
		if grade < 4 {
			grade = 5
		}
	}
	return grade
}

// GetGeneralGradeS 评级名
func (g *General) GetGeneralGradeS() string {
	switch g.GetGeneralGrade() {
	case 0:
		return "愚钝"
	case 1:
		return "平庸"
	case 2:
		return "良才"
	case 3:
		return "精英"
	case 4:
		return "奇才"
	default:
		return "怪才"
	}
}

// randRange 使用实体注入的随机源取 [min,max]，若未注入则返回 min（幂等降级）
func (g *General) randRange(min, max int) int {
	if g.rand != nil {
		return g.rand.IntRange(min, max)
	}
	return min
}

// generalUpgrade 升级：等级+1，体力回满，随机属性加点（对应 _general_upgrade）
// 注：随机加点依赖实体注入的随机源
func (g *General) generalUpgrade() {
	if g.Level >= 8 {
		return
	}
	g.Level++
	g.Health = g.MaxHealth
	grade := g.GetGeneralGrade()
	total := g.randRange(0, grade-1) + 1
	for i := 0; i < total; i++ {
		idx := g.randRange(0, 4)
		g.AddGeneralAttributeValue(idx, 0)
	}
}

// AddGeneralAttributeValue 给指定属性+1（对应 add_general_attribute_value，含递归）
func (g *General) AddGeneralAttributeValue(attrIdx, iter int) {
	if iter >= 5 {
		return
	}
	switch attrIdx {
	case 0:
		if g.Lead < MaxAttribute {
			g.Lead++
		}
	case 1:
		if g.Govern < MaxAttribute {
			g.Govern++
		}
	case 2:
		if g.Force < MaxAttribute {
			g.Force++
		}
	case 3:
		if g.Charm < MaxAttribute {
			g.Charm++
		}
	case 4:
		if g.Wisdom < MaxAttribute {
			g.Wisdom++
		}
	default:
		attrIdx = 0
	}
	if attrIdx != 0 {
		attrIdx++
		iter++
		g.AddGeneralAttributeValue(attrIdx, iter)
	}
}

// AddAttrExp 属性经验（每满100进位1点，对应 _add_attr_exp）
func (g *General) AddAttrExp(attr string, exp, cap int) {
	var value *int
	var attrExp *int
	switch attr {
	case "lead":
		value, attrExp = &g.Lead, &g.LeadExp
	case "force":
		value, attrExp = &g.Force, &g.ForceExp
	case "wisdom":
		value, attrExp = &g.Wisdom, &g.WisdomExp
	case "govern":
		value, attrExp = &g.Govern, &g.GovernExp
	case "charm":
		value, attrExp = &g.Charm, &g.CharmExp
	default:
		return
	}
	if *value >= cap {
		*attrExp = 100
		return
	}
	total := *attrExp + exp
	newVal := total / 100
	*value += newVal
	if *value >= cap {
		*value = cap
		*attrExp = 100
		return
	}
	*attrExp = total % 100
}

func (g *General) AddLeadExp(e int)   { g.AddAttrExp("lead", e, MaxAttribute) }
func (g *General) AddForceExp(e int)  { g.AddAttrExp("force", e, MaxAttribute) }
func (g *General) AddIqExp(e int)     { g.AddAttrExp("wisdom", e, MaxAttribute) }
func (g *General) AddPoliticalExp(e int) { g.AddAttrExp("govern", e, MaxAttribute) }
func (g *General) AddMoralExp(e int)  { g.AddAttrExp("charm", e, MaxAttribute) }

// GetSchoolNeedExp 学院学习所需经验（对应 get_school_need_exp）
func (g *General) GetSchoolNeedExp() int { return 200 + g.Wisdom*50 }

// StudyUp 学院学习：扣经验，智谋+1（对应 study_up）
func (g *General) StudyUp() {
	g.Experience -= g.GetSchoolNeedExp()
	g.Wisdom++
}

// GetLearnNeedExp 可学习所需经验（city 用）
func (g *General) GetLearnNeedExp() int { return g.GetSchoolNeedExp() }

// ---- 战斗力 ----

// CalculateWarValue 战力争（对应 calculate_war_value）
func (g *General) CalculateWarValue() int {
	return (g.Force + g.Wisdom + g.Lead*2) / 2 * (g.Soldiers + 150)
}

// GetBattlePower 战斗战力（浮点，对应 get_battle_power）
func (g *General) GetBattlePower(w WorldRef) float64 {
	power := 0.0
	if wp := w.Weapon(g.Arm); wp != nil {
		power += float64(wp.Property) * 1.3
	}
	if ap := w.Weapon(g.Armor); ap != nil {
		power += float64(ap.Property) * 1.3
	}
	power += float64(g.Force)*1.3 + float64(g.Wisdom)*1.2 + float64(g.Health)*1.1 + float64(g.Soldiers)*0.2
	return power
}

// GetWarValue 战力争（对应 get_war_value）
func (g *General) GetWarValue() int {
	return int(float64(g.Lead)*1.42 + float64(g.Wisdom)*0.25 + float64(g.Force)*0.33 +
		float64((g.Lead*2+g.Force+g.Wisdom)*(g.Level-1))*0.04)
}

// GetGeneralPower 综合势力（对应 get_general_power）
func (g *General) GetGeneralPower() int {
	power := 1
	satrapValue := g.GetWarValue()
	adjusted := 1 + float64(satrapValue*satrapValue*satrapValue)/100000.0
	if g.Soldiers < 100 {
		if adjusted > 100 {
			adjusted = 100
		}
		return 0
	}
	if adjusted < 20 {
		m := float64(g.Soldiers) / 150.0
		if m > adjusted {
			adjusted = m
		}
	}
	power += int(adjusted * float64(g.Soldiers+1))
	return power
}

// CapturedGeneralTo 俘虏转任（对应 captured_general_to）
func (g *General) CapturedGeneralTo(w WorldRef, cityID int) {
	add := 100 - g.GetLoyalty()
	base := 60 + add
	if base >= 99 || base <= 0 {
		g.SetLoyalty(99)
	} else {
		g.SetLoyalty(g.randRange(70, 90))
	}
	if city := w.City(cityID); city != nil {
		city.OfficeGeneralId = append(city.OfficeGeneralId, g.GeneralId)
	}
}

// GetNewWeapon 获得武器（对应 get_new_weapon）
func (g *General) GetNewWeapon(w WorldRef, weaponID int) {
	wp := w.Weapon(weaponID)
	if wp == nil {
		return
	}
	if wp.Kind == 3 {
		g.Armor = weaponID
	} else {
		g.Arm = weaponID
	}
}

// BuyNewWeapon 购买武器（含名器武力/智谋门槛，对应 buy_new_weapon）
func (g *General) BuyNewWeapon(w WorldRef, weaponID, cityID int) bool {
	wp := w.Weapon(weaponID)
	if wp == nil {
		return false
	}
	city := w.City(cityID)
	if city == nil {
		return false
	}
	if wp.IsUnique {
		pass := false
		switch wp.WeaponID {
		case 15, 21: // 青龙偃月刀/方天画戟 武力≥95
			pass = g.Force >= 95
		case 22: // 狼牙棒 武力≥90
			pass = g.Force >= 90
		case 23: // 丈八蛇矛 武力≥95
			pass = g.Force >= 95
		case 30: // 圣者之衣 智谋≥90
			pass = g.Wisdom >= 90
		}
		if pass {
			g.GetNewWeapon(w, weaponID)
			city.WarWeaponShop = 2
			return true
		}
		return false
	}
	g.GetNewWeapon(w, weaponID)
	return true
}

// RewardAddLoyalty 奖赏忠诚增加（对应 reward_add_loyalty）
func (g *General) RewardAddLoyalty(useMoney bool) int {
	temp := g.Loyalty
	switch {
	case g.Loyalty < 30:
		g.Loyalty += g.randRange(0, 10) + 20
	case g.Loyalty < 50:
		g.Loyalty += g.randRange(0, 10) + 10
	case g.Loyalty < 70:
		g.Loyalty += g.randRange(0, 10) + 5
	case g.Loyalty < 80:
		g.Loyalty += g.randRange(0, 7) + 3
	case g.Loyalty < 85:
		g.Loyalty += g.randRange(0, 6) + 1
	case g.Loyalty < 90:
		g.Loyalty += g.randRange(0, 4) + 1
	}
	if !useMoney {
		g.Loyalty += g.randRange(5, 14)
	}
	if g.Loyalty > 99 {
		g.Loyalty = 99
	}
	return g.Loyalty - temp
}

// GetNeedMoneyOfInterior 内政命令花费（对应 get_need_money_of_interior）
func (g *General) GetNeedMoneyOfInterior(task int) int {
	gold := 0
	switch task {
	case 29: // RECLAIM 开垦
		gold = (g.Force + g.Govern) / 2
	case 31: // MERCANTILE 劝商
		gold = (g.Wisdom + g.Govern) / 2
	case 33: // TAME 治水
		gold = (g.Lead + g.Govern) / 2
	case 35: // PATROL 巡查
		gold = (g.Charm + g.Govern) / 2
	}
	need := 10
	need += gold / 10
	need += 2 * (g.randRange(0, 4) + 1)
	return need
}
