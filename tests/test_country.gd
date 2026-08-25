class_name TestCountry
extends GdUnitTestSuite
## 势力（Country）单元测试
##
## 覆盖：
##  1. 城市归属管理（add_city / remove_city）
##  2. 势力状态判断（is_destroyed / is_endangered / get_have_city_num）
##  3. 城市查询（find_king_city / find_vacant_city / get_vacant_officer_num / find_city_of_general）
##  4. 同盟管理（add_alliance / get_alliance_by_id / remove_alliance / get_alliance_size）
##  5. 继承逻辑（_inherit_score / get_inherit_general_id）
##  6. 其他（king_name / 君主名称）
##
## 说明：Country 大量方法依赖全局缓存单例（GeneralListCache/CityListCache/
## CountryListCache），故 before_test() 中 load_all_configs() 加载真实数据。

func before_test() -> void:
	DataManager.load_all_configs()


## 构造一个真实势力引用（countryId=1）
func _real_country() -> Country:
	var c := CountryListCache.get_country_by_country_id(1)
	assert_object(c).is_not_null()
	return c


## 构造一个自建势力对象（不加入缓存）
func _make_country() -> Country:
	var c := Country.new()
	c.countryId = 99
	c.countryKingId = 61  # 使用真实君主ID
	return c


# ============ 1. 城市归属管理 ============

## 添加城市：ownerID 被设为君主ID，列表加入
func test_add_city() -> void:
	var c := _make_country()
	c.cityIDs = []
	# 选择一个未被占用的真实城市
	var target_city_id := 0
	for city_id in CityListCache.city_dictionary.keys():
		if CityListCache.get_city_by_city_id(city_id).ownerID == 0:
			target_city_id = city_id
			break
	if target_city_id != 0:
		assert_bool(c.add_city(target_city_id)).is_true()
		assert_array(c.cityIDs).contains_exactly(target_city_id)
		assert_int(CityListCache.get_city_by_city_id(target_city_id).ownerID).is_equal(61)
	# 重复添加返回 true（幂等）
	assert_bool(c.add_city(target_city_id)).is_true()
	assert_int(c.get_have_city_num()).is_equal(1)


## 移除城市：城市归属清零，从列表移除
func test_remove_city() -> void:
	var c := _make_country()
	# 用真实势力的城市做移除测试
	var real := _real_country()
	var city_id: int = real.cityIDs[0]
	var before := real.get_have_city_num()
	assert_bool(real.remove_city(city_id)).is_true()
	assert_int(real.get_have_city_num()).is_equal(before - 1)
	assert_int(CityListCache.get_city_by_city_id(city_id).ownerID).is_equal(0)
	assert_int(CityListCache.get_city_by_city_id(city_id).prefectID).is_equal(0)
	# 移除不存在的城市返回 false
	assert_bool(real.remove_city(9999)).is_false()


## 移除不存在的城市返回 false
func test_remove_city_not_exists() -> void:
	var c := _make_country()
	c.cityIDs = []
	assert_bool(c.remove_city(9999)).is_false()


# ============ 2. 势力状态判断 ============

## 势力是否灭亡/濒危
func test_destroyed_endangered() -> void:
	var c := _make_country()
	c.cityIDs = []
	assert_bool(c.is_destroyed()).is_true()
	assert_bool(c.is_endangered()).is_true()
	c.cityIDs = [1, 2, 3]
	assert_bool(c.is_destroyed()).is_false()
	assert_bool(c.is_endangered()).is_false()  # >1 城不算濒危
	c.cityIDs = [1]
	assert_bool(c.is_endangered()).is_true()


## 城市数量
func test_have_city_num() -> void:
	var c := _make_country()
	c.cityIDs = [1, 2, 3]
	assert_int(c.get_have_city_num()).is_equal(3)


# ============ 3. 城市查询 ============

## 找到君主所在城
func test_find_king_city() -> void:
	var real := _real_country()
	var king_city := real.find_king_city()
	# 若势力有城，应能返回一个非0的、太守为君主的城
	if real.cityIDs.size() > 0:
		assert_int(king_city).is_not_equal(0)
		assert_int(CityListCache.get_city_by_city_id(king_city).prefectID).is_equal(real.countryKingId)
	else:
		assert_int(king_city).is_equal(0)


## 查找武将所在城
func test_find_city_of_general() -> void:
	var real := _real_country()
	var city_id: int = real.cityIDs[0]
	var city := CityListCache.get_city_by_city_id(city_id)
	var officers := city.get_officer_ids()
	if officers.size() > 0:
		var gid: int = officers[0]
		assert_int(real.find_city_of_general(gid)).is_equal(city_id)


## 查找空缺城与空缺职位数
func test_vacant_city() -> void:
	var c := _make_country()
	c.cityIDs = [1]
	var city := CityListCache.get_city_by_city_id(1)
	var officer_num := city.get_city_officer_num()
	var vacant := c.find_vacant_city()
	if officer_num < 10:
		assert_array(vacant).contains_exactly(true, 1)
		assert_int(c.get_vacant_officer_num()).is_greater_equal(10 - officer_num)
	else:
		assert_bool(vacant[0]).is_false()


# ============ 4. 同盟管理 ============

## 添加同盟：双向建立（对方也持有对己同盟）
func test_add_alliance() -> void:
	var c1 := _real_country()
	var c2 := CountryListCache.get_country_by_country_id(2)
	# 清理已有同盟，确保可加
	c1.remove_all_alliance()
	c2.remove_all_alliance()
	c1.add_alliance(c2.countryId)
	assert_object(c1.get_alliance_by_id(c2.countryId)).is_not_null()
	assert_object(c2.get_alliance_by_id(c1.countryId)).is_not_null()
	assert_int(c1.get_alliance_size()).is_equal(1)
	# 重复添加不生效
	c1.add_alliance(c2.countryId)
	assert_int(c1.get_alliance_size()).is_equal(1)


## 移除同盟：双向移除（remove_alliance 仅当移除的是玩家势力时才返回 true）
func test_remove_alliance() -> void:
	var c1 := _real_country()
	var c2 := CountryListCache.get_country_by_country_id(2)
	c1.remove_all_alliance()
	c2.remove_all_alliance()
	c1.add_alliance(c2.countryId)
	c1.remove_alliance(c2.countryId)
	# 关键：同盟对象应被双向移除
	assert_object(c1.get_alliance_by_id(c2.countryId)).is_null()
	assert_object(c2.get_alliance_by_id(c1.countryId)).is_null()
	assert_int(c1.get_alliance_size()).is_equal(0)


# ============ 5. 继承逻辑 ============

## 继承评分：智谋/统率/魅力高分加成
func test_inherit_score() -> void:
	var real := _real_country()
	# 用君主自身测评分（任意武将都行）
	var king_id: int = real.countryKingId
	var king := GeneralListCache.get_general(king_id)
	# 构造一个高智谋武将对比：_inherit_score 只加分
	# 智谋 95 以上 +100，统率 95+ +50，魅力 95+ +50
	var g := General.new()
	g.wisdom = 96
	g.lead = 96
	g.charm = 96
	g.generalId = 9999
	# 直接构造进缓存测（用 GeneralListCache）
	GeneralListCache.add_general(g)
	var score := real._inherit_score(9999)
	# 基础 = 96+96+96=288，加成 =100+50+50=200 => 488
	assert_int(score).is_equal(288 + 200)
	GeneralListCache.remove_general(9999)


## 继承继承者：势力君主死亡后由继承武将继位
func test_inherit_id() -> void:
	var real := _real_country()
	if real.cityIDs.is_empty():
		return
	var inherit_gid := real.get_inherit_general_id()
	if inherit_gid == 0:
		return
	var old_king := real.countryKingId
	var old_city := real.find_city_of_general(old_king)
	real.inherit_id(inherit_gid)
	assert_int(real.countryKingId).is_equal(inherit_gid)
	# 若原君主有城，其城 owner 应改为新君主
	if old_city != 0:
		assert_int(CityListCache.get_city_by_city_id(old_city).ownerID).is_equal(inherit_gid)


# ============ 6. 其他 ============

## 君主名称
func test_king_name() -> void:
	var real := _real_country()
	var king := GeneralListCache.get_general(real.countryKingId)
	assert_str(real.king_name()).is_equal(king.generalName)


## 输送资源到撤退城（AI 撤退后分派钱粮）
func test_ai_retreat_add_resources() -> void:
	var c := _make_country()
	c.cityIDs = [1, 2]
	var city1 := CityListCache.get_city_by_city_id(1)
	var city2 := CityListCache.get_city_by_city_id(2)
	var before2 := city2.get_money()
	c.ai_retreat_add_resources_to_city(1, 1000, 500)
	# 撤退城1 获得钱粮
	assert_int(city1.get_money()).is_greater_equal(1000)
	assert_int(city1.get_food()).is_greater_equal(500)
	# 其他城(2) 获得剩余
	assert_int(city2.get_money()).is_greater_equal(before2)
