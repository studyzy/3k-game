class_name TestCity
extends GdUnitTestSuite
## 城池（City）单元测试
##
## 覆盖四类逻辑：
##  1. 数值钳制方法（统治度/金钱/粮/宝物/农业/商业/防灾/人口）
##  2. 收入公式（金钱收入 / 粮食收入）
##  3. 武将列表管理（官职/在野/隐居/监狱 的增删查）
##  4. 集成逻辑（依赖真实数据，before_test 加载配置后验证）
##
## 说明：纯公式/钳制方法直接 new City 构造测试；依赖全局单例（GeneralListCache/
## CityListCache/CountryListCache）的方法在 before_test() 里 load_all_configs() 重置。

func before_test() -> void:
	# 依赖全局缓存的用例需要真实配置；每次重置保证测试隔离
	DataManager.load_all_configs()


## 构造一个配置好基础字段的城池
func _make_city() -> City:
	var c := City.new()
	c.cityID = 1
	c.cityName = "测试城"
	c.rule = 50
	c.money = 1000
	c.grain = 1000
	c.treasures = 50
	c.agriculture = 500
	c.commerce = 500
	c.prevention = 50
	c.population = 5000
	c.reserveSoldiers = 0
	c.connectCityId = [2, 3]
	return c


# ============ 1. 数值钳制方法 ============

## 统治度钳制在 [0, 99]
func test_rule_clamp() -> void:
	var c := _make_city()
	c.set_rule(150)
	assert_int(c.get_rule()).is_equal(99)
	c.set_rule(-10)
	assert_int(c.get_rule()).is_equal(0)
	c.set_rule(50)
	c.add_rule(200)
	assert_int(c.get_rule()).is_equal(99)
	c.sub_rule(500)
	assert_int(c.get_rule()).is_equal(0)


## 金钱钳制：set_money 越界(>30000 或 <0)一律置为上限 30000
func test_money_clamp() -> void:
	var c := _make_city()
	c.set_money(50000)
	assert_int(c.get_money()).is_equal(30000)
	c.set_money(-5)
	assert_int(c.get_money()).is_equal(30000)  # 实现：负值也置上限
	# add_gold 返回实际增加量，且不超上限
	c.set_money(29990)
	assert_int(c.add_gold(100)).is_equal(10)
	assert_int(c.get_money()).is_equal(30000)
	# sub_gold 到 0 返回实际扣减量
	c.set_money(50)
	assert_int(c.sub_gold(200)).is_equal(50)
	assert_int(c.get_money()).is_equal(0)


## 粮食钳制（同金钱，上限 30000，越界置上限）
func test_food_clamp() -> void:
	var c := _make_city()
	c.set_food(50000)
	assert_int(c.get_food()).is_equal(30000)
	c.set_food(-1)
	assert_int(c.get_food()).is_equal(30000)  # 实现：负值也置上限
	c.set_food(29990)
	assert_int(c.add_food(100)).is_equal(10)
	c.set_food(50)
	assert_int(c.sub_food(200)).is_equal(50)
	assert_int(c.get_food()).is_equal(0)


## 宝物钳制在 [0, 100]
func test_treasure_clamp() -> void:
	var c := _make_city()
	c.set_treasure_num(150)
	assert_int(c.get_treasure_num()).is_equal(100)
	c.set_treasure_num(95)
	assert_int(c.add_treasure_num(10)).is_equal(5)
	assert_int(c.get_treasure_num()).is_equal(100)
	c.set_treasure_num(10)
	assert_int(c.sub_treasure_num(50)).is_equal(10)
	assert_int(c.get_treasure_num()).is_equal(0)


## 农业/商业钳制在 [0, 30000]
func test_agro_trade_clamp() -> void:
	var c := _make_city()
	c.set_agro(40000)
	assert_int(c.get_agro()).is_equal(30000)
	c.set_agro(100)
	c.add_agro(40000)
	assert_int(c.get_agro()).is_equal(30000)
	# sub_agro 每次减 num，不减到 0
	c.set_agro(30000)
	c.sub_agro(500)
	assert_int(c.get_agro()).is_equal(29500)
	# 越减到负则钳到 0
	c.set_agro(100)
	c.sub_agro(500)
	assert_int(c.get_agro()).is_equal(0)
	# 商业同理
	c.set_trade(40000)
	assert_int(c.get_trade()).is_equal(30000)
	c.set_trade(100)
	c.add_trade(-40000)
	assert_int(c.get_trade()).is_equal(0)


## 防灾钳制在 [0, 99]
func test_flood_control_clamp() -> void:
	var c := _make_city()
	c.set_flood_control(150)
	assert_int(c.get_flood_control()).is_equal(99)
	c.set_flood_control(50)
	c.add_flood_control(100)
	assert_int(c.get_flood_control()).is_equal(99)
	c.sub_flood_control(500)
	assert_int(c.get_flood_control()).is_equal(0)


## 人口钳制在 [0, 999999]
func test_population_clamp() -> void:
	var c := _make_city()
	c.set_population(2000000)
	assert_int(c.get_population()).is_equal(999999)
	c.set_population(5000)
	assert_int(c.add_population(2000000)).is_equal(994999)
	assert_int(c.get_population()).is_equal(999999)
	assert_int(c.sub_population(9999999)).is_equal(999999)
	assert_int(c.get_population()).is_equal(0)


# ============ 2. 收入公式 ============

## 金钱收入：人口/400 + 商业加成 + 统治度加成
func test_money_income() -> void:
	# 统治度 50（无加成），无商业
	var c := _make_city()
	c.rule = 50
	c.commerce = 0
	c.population = 4000
	var l1 := 4000 / 400 + 1  # 11
	var i2 := l1 * 0 * 3 / 5 / 125
	assert_int(c.money_income()).is_equal(l1 + i2)
	# 带商业与统治度加成
	c.commerce = 500
	c.population = 8000
	c.rule = 95  # >90 加成 4/5
	var expect := 8000 / 400 + 1
	var com := expect * 500 * 3 / 5 / 125
	expect += com
	var rule_bonus := expect * 4 / 5
	assert_int(c.money_income()).is_equal(expect + rule_bonus)


## 粮食收入：人口/100 + 农业加成 + 统治度加成
func test_food_income() -> void:
	var c := _make_city()
	c.rule = 50
	c.agriculture = 0
	c.population = 5000
	var l1 := 5000 / 100  # 50
	assert_int(c.food_income()).is_equal(l1)
	# 统治度 75（>70 加成 2/5）
	c.agriculture = 600
	c.population = 10000
	c.rule = 75
	var expect := 10000 / 100
	var ag := expect * 600 * 4 / 5 / 125
	expect += ag
	var bonus := expect * 2 / 5
	assert_int(c.food_income()).is_equal(expect + bonus)


# ============ 3. 武将列表管理 ============

## 官职武将：get_officer_ids 只返回 >0 的 ID
func test_officer_ids_filter() -> void:
	var c := _make_city()
	c.cityOfficeGeneralId = [1, 0, 2, 0, 3]
	assert_int(c.get_city_officer_num()).is_equal(3)
	assert_array(c.get_officer_ids()).contains_exactly(1, 2, 3)
	# 属臣（排除君主 ownerID）
	c.ownerID = 1
	assert_array(c.get_city_subjects_general_id_array()).contains_exactly(2, 3)


## 隐居/在野武将列表过滤与数量
func test_not_found_and_reserved() -> void:
	var c := _make_city()
	c.cityNotFoundGeneralId = [5, 0, 6]
	c.cityReservedGeneralId = [7, 0, 8, 9]
	assert_int(c.get_city_not_found_general_num()).is_equal(2)
	assert_array(c.get_city_not_found_general_id_array()).contains_exactly(5, 6)
	assert_array(c.get_recluse_ids()).contains_exactly(5, 6)
	assert_int(c.get_reserved_general_num()).is_equal(3)
	assert_array(c.get_talent_ids()).contains_exactly(7, 8, 9)


## 添加官职武将：空列表时成为太守；已存在返回 true 不重复添加
func test_add_office_general() -> void:
	var c := _make_city()
	# 空列表第一个武将即太守
	assert_bool(c.add_office_general_id(10)).is_true()
	assert_int(c.prefectID).is_equal(10)
	# 重复添加返回 true 但不重复
	assert_bool(c.add_office_general_id(10)).is_true()
	assert_int(c.get_city_officer_num()).is_equal(1)
	# 添加第二个武将
	assert_bool(c.add_office_general_id(20)).is_true()
	assert_int(c.get_city_officer_num()).is_equal(2)


## 移除官职武将：移除后若为空则清空归属；非空则自动委任太守
func test_remove_office_general() -> void:
	# 使用真实数据验证
	var country := CountryListCache.get_country_by_country_id(1)
	var city := CityListCache.get_city_by_city_id(country.cityIDs[0])
	var owner := city.ownerID
	var subject := 0
	for gid in city.get_officer_ids():
		if gid != owner:
			subject = gid
			break
	# 移除属臣
	if subject != 0:
		assert_bool(city.remove_officer_id(subject)).is_true()
		assert_array(city.get_officer_ids()).not_contains(subject)


## 监狱武将增删
func test_capture() -> void:
	var c := _make_city()
	assert_bool(c.add_capture(0)).is_false()
	assert_bool(c.add_capture(30)).is_true()
	assert_bool(c.add_capture(30)).is_false()  # 重复不可
	assert_array(c.get_capture_list()).contains_exactly(30)
	assert_bool(c.remove_capture(30)).is_true()
	assert_bool(c.remove_capture(30)).is_false()  # 已移除


# ============ 4. 士兵与防御 ============

## 士兵数统计：现役(官职武将士兵)+预备
func test_soldier_counts() -> void:
	var c := _make_city()
	c.reserveSoldiers = 500
	c.cityOfficeGeneralId = []
	assert_int(c.get_city_all_soldier_num()).is_equal(500)
	assert_int(c.get_max_soldier_num()).is_equal(0)
	assert_int(c.get_already_soldier_num()).is_equal(0)
	assert_int(c.need_food_war_a_month()).is_equal(1)  # 0/8+1


## 征兵：预备兵增加、扣钱、扣统治度、减人口
func test_conscript() -> void:
	var c := _make_city()
	c.money = 1000
	c.population = 5000
	c.rule = 50
	c.conscript(100)
	assert_int(c.reserveSoldiers).is_equal(100)
	# sub_gold((100+4)/5=20)
	assert_int(c.money).is_equal(980)
	# sub_rule(100/500=0)
	assert_int(c.rule).is_equal(50)
	# population -= 100*3/2=150
	assert_int(c.population).is_equal(4850)


# ============ 5. 内政命令 ============

## 开垦：返回值在合理范围、扣钱、农业递增且不超 999、武将扣血
func test_reclaim() -> void:
	var c := _make_city()
	c.money = 1000
	c.agriculture = 500
	var gen := General.new()
	gen.force = 80
	gen.govern = 60
	gen.health = 100
	gen.experience = 0
	var before := c.agriculture
	var actual := c.reclaim(gen, 100)
	# 贡献=(80+60*2)/3=66，基础 val=(66*100/100)/2=33，再加随机，钳到 [0, 999-500]
	assert_int(actual).is_greater_equal(1)
	assert_int(actual).is_less_equal(999 - 500)
	assert_int(c.agriculture).is_equal(before + actual)
	assert_int(c.agriculture).is_less_equal(999)  # 不超上限
	# 扣钱
	assert_int(c.money).is_equal(900)
	# 武将扣血 2、加经验与政治经验
	assert_int(gen.health).is_equal(98)
	assert_int(gen.experience).is_greater(0)
	assert_int(gen.governExp).is_greater(0)


## 劝商：作用于商业，扣钱
func test_mercantile() -> void:
	var c := _make_city()
	c.money = 1000
	c.commerce = 500
	var gen := General.new()
	gen.wisdom = 80
	gen.govern = 60
	gen.health = 100
	var before := c.commerce
	var actual := c.mercantile(gen, 100)
	assert_int(actual).is_greater_equal(1)
	assert_int(actual).is_less_equal(999 - 500)
	assert_int(c.commerce).is_equal(before + actual)
	assert_int(c.commerce).is_less_equal(999)
	assert_int(c.money).is_equal(900)
	assert_int(gen.health).is_equal(98)


## 治水：增加防灾(不超99)，统治度依据治水值递增
func test_tame() -> void:
	var c := _make_city()
	c.money = 1000
	c.prevention = 50
	c.rule = 50
	var gen := General.new()
	gen.lead = 80
	gen.govern = 60
	gen.health = 100
	var before := c.prevention
	var rule_before := c.rule
	var actual := c.tame(gen, 100)
	assert_int(actual).is_greater_equal(1)
	assert_int(actual).is_less_equal(99 - 50)
	assert_int(c.prevention).is_equal(before + actual)
	assert_int(c.prevention).is_less_equal(99)
	# actual>=5 时 rule+2，否则 +1
	var rule_delta := c.rule - rule_before
	assert_int(rule_delta).is_greater_equal(1)
	assert_int(rule_delta).is_less_equal(2)
	assert_int(c.money).is_equal(900)
	assert_int(gen.health).is_equal(98)


## 治安巡逻：增加人口(不超999999)与统治度
func test_patrol() -> void:
	var c := _make_city()
	c.money = 1000
	c.population = 5000
	c.rule = 50
	var gen := General.new()
	gen.wisdom = 80
	gen.charm = 70
	gen.govern = 60
	gen.health = 100
	var before := c.population
	var rule_before := c.rule
	var actual := c.patrol(gen, 100)
	# 基础贡献=(80+70*2+60*2)/5=68 => val=68*100=6800，再加随机，钳到上限
	assert_int(actual).is_greater_equal(1)
	assert_int(actual).is_less_equal(999999 - 5000)
	assert_int(c.population).is_equal(before + actual)
	assert_int(c.population).is_less_equal(999999)
	# rule 依 actual 递增（3/2/1）
	var rule_delta := c.rule - rule_before
	assert_int(rule_delta).is_greater_equal(1)
	assert_int(rule_delta).is_less_equal(3)
	assert_int(c.money).is_equal(900)
	assert_int(gen.health).is_equal(98)


## 城池连通性判断
func test_connectivity() -> void:
	var c := _make_city()
	c.connectCityId = [2, 3]
	assert_bool(c.is_connected_to(2)).is_true()
	assert_bool(c.is_connected_to(5)).is_false()


## 铁匠铺判断
func test_smithy() -> void:
	var c := _make_city()
	c.cityWeaponShop = 0
	c.warWeaponShop = 0
	assert_bool(c.have_city_smithy()).is_false()
	assert_bool(c.has_war_smithy()).is_false()
	c.cityWeaponShop = 1
	c.warWeaponShop = 1
	assert_bool(c.have_city_smithy()).is_true()
	assert_bool(c.has_war_smithy()).is_true()
	c.sell_unique_weapon()
	assert_int(c.warWeaponShop).is_equal(2)
