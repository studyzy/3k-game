class_name TestCaches
extends GdUnitTestSuite
## 缓存单例（GeneralListCache / CityListCache / CountryListCache）单元测试
##
## 覆盖：
##  1. GeneralListCache：相性差、武将增删查、技能判定、经验分配
##  2. CityListCache：城池增删查、武将移动、钱粮输送
##  3. CountryListCache：势力增删查、回合顺序、可选择势力统计
##
## 说明：这些 autoload 单例是全局共享的，before_test() 中 load_all_configs()
## 重置到真实数据，保证用例隔离。涉及 GameInfo 全局状态深度改变的
## 方法（如势力灭亡 remove_country）不做会破坏状态的调用。

func before_test() -> void:
	DataManager.load_all_configs()


# ============ 1. GeneralListCache ============

## 相性差：>75 时取 150-total（环状）
func test_d_phase() -> void:
	assert_int(GeneralListCache.get_d_phase(0, 0)).is_equal(0)
	assert_int(GeneralListCache.get_d_phase(50, 50)).is_equal(0)
	assert_int(GeneralListCache.get_d_phase(10, 30)).is_equal(20)
	# 环状：0 与 140 的差=140，>=75 则 150-140=10
	assert_int(GeneralListCache.get_d_phase(0, 140)).is_equal(10)
	assert_int(GeneralListCache.get_d_phase(140, 0)).is_equal(10)
	assert_int(GeneralListCache.get_d_phase(10, 80)).is_equal(70)
	# 恰好 75 边界：不触发环状
	assert_int(GeneralListCache.get_d_phase(10, 85)).is_equal(75)


## 相性差（按武将）
func test_phase_difference() -> void:
	var a := General.new()
	var b := General.new()
	a.phase = 30
	b.phase = 50
	assert_int(GeneralListCache.get_phase_difference(a, b)).is_equal(20)


## 武将增删查与总数
func test_general_cache_ops() -> void:
	var before := GeneralListCache.get_total_general_num()
	var g := General.new()
	g.generalId = 9990
	g.generalName = "测试武将"
	GeneralListCache.add_general(g)
	assert_object(GeneralListCache.get_general(9990)).is_same(g)
	assert_int(GeneralListCache.get_total_general_num()).is_equal(before + 1)
	# 不存在返回 null
	assert_object(GeneralListCache.get_general(123456)).is_null()
	# 删除
	assert_bool(GeneralListCache.remove_general(9990)).is_true()
	assert_object(GeneralListCache.get_general(9990)).is_null()


## 技能判定 get_skill：skills[i] 位掩码
func test_get_skill() -> void:
	var g := General.new()
	g.generalId = 9991
	g.skills = [0, 0, 0, 0, 0]
	GeneralListCache.add_general(g)
	# 第4组第5位技能：skills[3] = 1 << (10-5) = 1<<5
	g.skills[3] = 1 << 5
	assert_bool(GeneralListCache.get_skill(3, 9991, 5)).is_true()
	assert_bool(GeneralListCache.get_skill(3, 9991, 4)).is_false()
	assert_bool(GeneralListCache.get_skill_4(9991, 5)).is_true()
	assert_bool(GeneralListCache.get_skill_1(9991, 1)).is_false()
	GeneralListCache.remove_general(9991)


## 经验分配 add_exp_p：按战力比 clamp 到 [0.5, 1.5]，比例加成
func test_add_exp_p() -> void:
	var atk := General.new()
	var def := General.new()
	atk.generalId = 9992
	atk.soldiers = 100
	def.generalId = 9993
	def.soldiers = 100
	# get_war_value 由 lead/wisdom/force/level 决定
	atk.lead = 100
	atk.force = 100
	atk.wisdom = 100
	atk.level = 5
	def.lead = 50
	def.force = 50
	def.wisdom = 50
	def.level = 3
	atk.experience = 0
	GeneralListCache.add_general(atk)
	GeneralListCache.add_general(def)
	GeneralListCache.add_exp_p(atk, def, 300)
	# exp = int(300 * clamp(ratio,0.5,1.5))，atk 加了 exp/3 的经验
	assert_int(atk.experience).is_greater(0)
	GeneralListCache.remove_general(9992)
	GeneralListCache.remove_general(9993)


## 武将死亡后状态标记
func test_general_die() -> void:
	# 用一个在野武将测死亡（避免破坏君主/势力）
	var g := General.new()
	g.generalId = 9994
	g.generalName = "阵亡测试"
	g.debutCity = 1
	g.status = 0
	g.soldiers = 0
	GeneralListCache.add_general(g)
	var city := CityListCache.get_city_by_city_id(1)
	city.add_not_found_general_id(9994)
	# 若成功加入隐居列表
	if city.get_city_not_found_general_num() > 0:
		GeneralListCache.general_die(9994)
		assert_bool(g.isDie).is_true()
		assert_int(g.status).is_equal(0)
	GeneralListCache.remove_general(9994)


# ============ 2. CityListCache ============

## 城池增删查与数量
func test_city_cache_ops() -> void:
	var before := CityListCache.get_city_num()
	var c := City.new()
	c.cityID = 999
	CityListCache.add_city(c)
	assert_object(CityListCache.get_city_by_city_id(999)).is_same(c)
	assert_int(CityListCache.get_city_num()).is_equal(before + 1)
	assert_object(CityListCache.get_city_by_city_id(12345)).is_null()
	CityListCache.city_dictionary.erase(999)


## 输送钱粮宝物：出城扣、入城加
func test_transport() -> void:
	var out_city := CityListCache.get_city_by_city_id(1)
	var in_city := CityListCache.get_city_by_city_id(2)
	out_city.set_money(1000)
	out_city.set_food(2000)
	out_city.set_treasure_num(50)
	in_city.set_money(500)
	in_city.set_food(500)
	in_city.set_treasure_num(10)
	CityListCache.transport_between_citys(1, 2, 300, 200, 20)
	assert_int(out_city.get_money()).is_equal(800)
	assert_int(out_city.get_food()).is_equal(1700)
	assert_int(out_city.get_treasure_num()).is_equal(30)
	assert_int(in_city.get_money()).is_equal(700)
	assert_int(in_city.get_food()).is_equal(800)
	assert_int(in_city.get_treasure_num()).is_equal(30)


## 移动武将：普通武将从源城到目标城
func test_move_task() -> void:
	var from_city := CityListCache.get_city_by_city_id(1)
	var to_city := CityListCache.get_city_by_city_id(2)
	# 找一个 from_city 的非君主属臣
	var gid := 0
	for id in from_city.get_officer_ids():
		if id != from_city.ownerID:
			gid = id
			break
	if gid != 0:
		assert_bool(CityListCache.move_task(1, 2, [gid])).is_false()  # 非君主移动
		assert_array(from_city.get_officer_ids()).not_contains(gid)
		assert_array(to_city.get_officer_ids()).contains(gid)


## 移动君主：返回 true 且君主从源城移走
func test_move_task_king() -> void:
	var from_city := CityListCache.get_city_by_city_id(1)
	var king_id := from_city.ownerID
	# 君主移动返回 true
	assert_bool(CityListCache.move_task(1, 2, [king_id])).is_true()
	# 君主已从源城移除（move_task 内部 remove_officer_id + add_office_general_id）
	assert_array(from_city.get_officer_ids()).not_contains(king_id)
	# 若君主成功加入目标城，则其应为太守
	var to_city := CityListCache.get_city_by_city_id(2)
	if king_id in to_city.get_officer_ids():
		assert_int(to_city.prefectID).is_equal(king_id)


# ============ 3. CountryListCache ============

## 势力按 ID / 君主 / 索引查询
func test_country_query() -> void:
	var c1 := CountryListCache.get_country_by_country_id(1)
	assert_object(c1).is_not_null()
	assert_int(CountryListCache.get_country_size()).is_greater_equal(3)
	# 按君主查
	var king := GeneralListCache.get_general(c1.countryKingId)
	assert_object(CountryListCache.get_country_by_king_id(c1.countryKingId)).is_same(c1)
	# 不存在返回 null
	assert_object(CountryListCache.get_country_by_country_id(999)).is_null()


## 可选择势力数量
func test_can_be_choose_country_size() -> void:
	var count := 0
	for c in CountryListCache.country_dictionary.values():
		if c.canBeChoose:
			count += 1
	assert_int(CountryListCache.get_can_be_choose_country_size()).is_equal(count)


## 添加自建势力：构建新 Country 并加入缓存
func test_add_country() -> void:
	var before := CountryListCache.get_country_size()
	var king := General.new()
	king.generalId = 9980
	king.generalName = "自建君主"
	GeneralListCache.add_general(king)
	var c := Country.new()
	c.countryId = 980
	c.countryKingId = 9980
	CountryListCache.add_country(c)
	assert_object(CountryListCache.get_country_by_country_id(980)).is_same(c)
	assert_int(CountryListCache.get_country_size()).is_equal(before + 1)
	# 君主忠诚被设为 100
	assert_int(GeneralListCache.get_general(9980).get_loyalty()).is_equal(100)
	# 清理
	CountryListCache.country_dictionary.erase(980)
	GeneralListCache.remove_general(9980)


## 回合顺序：add_sequence 追加/插入
func test_sequence() -> void:
	CountryListCache.country_sequence = []
	CountryListCache.add_sequence(1)
	CountryListCache.add_sequence(2)
	CountryListCache.add_sequence(3)
	assert_array(CountryListCache.country_sequence).contains_exactly(1, 2, 3)
	# 在 2 之后插入 5
	CountryListCache.add_sequence(5, 2)
	assert_array(CountryListCache.country_sequence).contains_exactly(1, 2, 5, 3)
	# 移除
	CountryListCache.remove_sequence(5)
	assert_array(CountryListCache.country_sequence).contains_exactly(1, 2, 3)
	# 重复添加不生效
	CountryListCache.add_sequence(2)
	assert_array(CountryListCache.country_sequence).contains_exactly(1, 2, 3)


## 回合排序：势力按城市数升序
func test_turn_sort() -> void:
	CountryListCache.country_sequence = []
	CountryListCache.turn_sort()
	# 只保留有城的势力，且按城市数升序
	var seq := CountryListCache.country_sequence
	for i in range(1, seq.size()):
		var prev := CountryListCache.get_country_by_country_id(seq[i - 1])
		var cur := CountryListCache.get_country_by_country_id(seq[i])
		assert_int(prev.get_have_city_num()).is_less_equal(cur.get_have_city_num())


## AI 命令数：按城市数 clamp 到 [3, 8]
func test_ai_order_num() -> void:
	assert_int(CountryListCache.get_ai_order_num(1)).is_greater_equal(3)
	assert_int(CountryListCache.get_ai_order_num(1)).is_less_equal(8)
