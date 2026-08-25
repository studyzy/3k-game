class_name TestPlan
extends GdUnitTestSuite
## 计策（Plan）单元测试
##
## 覆盖：
##  1. 计策注册表：get_plan 16 种都能构造，id/name/cost/distance 元数据正确
##  2. 通用方法：use_cost / in_distance / is_applicable / is_suitable
##  3. 各计策成功率 rate（构造标准武将后精确断言，rate 公式多为确定性）
##  4. 技能对 rate 的影响（神算/冷静/火攻/军师 的方向性）
##  5. result 不变量（士兵不超上限、扣血、返回非空字符串）
##
## 说明：rate 公式（_base_rate 等）不含随机，可精确断言；result 含随机
## （_iq_damage），故只做不变量断言。涉及 WarManager 全局状态的计策
## （劫粮/烧粮/共杀等）的 result 不在此精确断言，避免依赖战斗环境。

func before_test() -> void:
	DataManager.load_all_configs()


## 构造标准武将：do(智90/统80)、be(智90/统80/武80/魅80)，无技能
func _make_do() -> General:
	var g := General.new()
	g.wisdom = 90
	g.lead = 80
	g.force = 80
	g.charm = 80
	g.army = [0, 0, 0]
	g.soldiers = 1000
	g.health = 100
	g.generalName = "施计者"
	return g


func _make_be() -> General:
	var g := General.new()
	g.wisdom = 90
	g.lead = 80
	g.force = 80
	g.charm = 80
	g.army = [0, 0, 0]
	g.soldiers = 1000
	g.health = 100
	g.generalName = "中计者"
	return g


# ============ 1. 计策注册表 ============

## 16 种计策都能构造，id 与 name 正确
func test_plan_registry() -> void:
	var expect := [
		[0, "火攻"], [1, "陷阱"], [2, "虚兵"], [3, "要击"], [4, "乱水"],
		[5, "劫粮"], [6, "共杀"], [7, "伪击转杀"], [8, "烧粮"], [9, "落石"],
		[10, "连环"], [11, "伏兵"], [12, "水攻"], [13, "箭雨"], [14, "劫火"],
		[15, "奇门遁甲"],
	]
	for pair in expect:
		var plan := Plan.get_plan(pair[0])
		assert_object(plan).is_not_null()
		assert_int(plan.get_plan_id()).is_equal(pair[0])
		assert_str(plan.get_plan_name()).is_equal(pair[1])


## 无效 id 返回 null
func test_plan_registry_invalid() -> void:
	assert_object(Plan.get_plan(-1)).is_null()
	assert_object(Plan.get_plan(16)).is_null()
	assert_object(Plan.get_plan(999)).is_null()


## 各计策消耗/距离/适用地形元数据
func test_plan_metadata() -> void:
	# (id, cost, distance)
	var expect := [
		[0, 6, 5], [1, 5, 5], [2, 4, 5], [3, 6, 5], [4, 6, 5], [5, 8, 2],
		[6, 8, 2], [7, 8, 1], [8, 10, 2], [9, 9, 2], [10, 10, 5], [11, 10, 5],
		[12, 12, 3], [13, 10, 2], [14, 12, 3], [15, 10, 9],
	]
	for pair in expect:
		var plan := Plan.get_plan(pair[0])
		assert_int(plan.get_cost()).is_equal(pair[1]).append_failure_message("计策%d cost" % pair[0])
		assert_int(plan.get_distance()).is_equal(pair[2]).append_failure_message("计策%d distance" % pair[0])


# ============ 2. 通用方法 ============

## use_cost：百出技能(技能组1第3个)减2消耗
func test_use_cost() -> void:
	var plan := Plan.get_plan(0)  # 火攻 cost=6
	var g := _make_do()
	assert_int(plan.use_cost(g)).is_equal(6)
	# 百出：skills[0] 第3位(has_skill(1,2)) => skills[0] = 1<<(10-2)=1<<8
	g.skills[0] = 1 << 8
	assert_int(plan.use_cost(g)).is_equal(4)


## in_distance：鬼谋技能(技能组1第2个)加1距离
func test_in_distance() -> void:
	var plan := Plan.get_plan(0)  # 火攻 distance=5
	var g := _make_do()
	assert_int(plan.in_distance(g)).is_equal(5)
	# 鬼谋：skills[0] 第2位(has_skill(1,1)) => 1<<(10-1)=1<<9
	g.skills[0] = 1 << 9
	assert_int(plan.in_distance(g)).is_equal(6)


## is_applicable：be 地形（低位5bit）须在 get_be_terrain 中
func test_is_applicable() -> void:
	var plan := Plan.get_plan(0)  # 火攻 be_terrain=[1,2,3,4,10,11]
	assert_bool(plan.is_applicable(2)).is_true()
	assert_bool(plan.is_applicable(10)).is_true()
	assert_bool(plan.is_applicable(7)).is_false()
	assert_bool(plan.is_applicable(9)).is_false()


## is_suitable：do 地形（get_do_terrain）为空则总是适用
func test_is_suitable() -> void:
	var plan := Plan.get_plan(0)  # 火攻无 do_terrain
	assert_bool(plan.is_suitable(0)).is_true()
	assert_bool(plan.is_suitable(99)).is_true()
	# 落石 do_terrain=[8,12]
	var luoshi := Plan.get_plan(9)
	assert_bool(luoshi.is_suitable(8)).is_true()
	assert_bool(luoshi.is_suitable(12)).is_true()
	assert_bool(luoshi.is_suitable(1)).is_false()


# ============ 3. 各计策 rate（标准武将精确值） ============

## 火攻：基准 26（无技能）
func test_huoji_rate() -> void:
	assert_int(Plan.get_plan(0).rate(_make_do(), _make_be())).is_equal(26)


## 陷阱：基准 26
func test_xianjing_rate() -> void:
	assert_int(Plan.get_plan(1).rate(_make_do(), _make_be())).is_equal(26)


## 虚兵：基准 13
func test_xubing_rate() -> void:
	assert_int(Plan.get_plan(2).rate(_make_do(), _make_be())).is_equal(13)


## 要击：委托虚兵 rate，同为 13
func test_yaoji_rate() -> void:
	assert_int(Plan.get_plan(3).rate(_make_do(), _make_be())).is_equal(13)


## 乱水：基准 18
func test_luanshui_rate() -> void:
	assert_int(Plan.get_plan(4).rate(_make_do(), _make_be())).is_equal(18)


## 劫粮：基准 18
func test_jieliang_rate() -> void:
	assert_int(Plan.get_plan(5).rate(_make_do(), _make_be())).is_equal(18)


## 共杀：基准 10
func test_gongsha_rate() -> void:
	assert_int(Plan.get_plan(6).rate(_make_do(), _make_be())).is_equal(10)


## 落石：基准 22
func test_luoshib_rate() -> void:
	assert_int(Plan.get_plan(9).rate(_make_do(), _make_be())).is_equal(22)


## 连环：基准 18
func test_lianhuan_rate() -> void:
	assert_int(Plan.get_plan(10).rate(_make_do(), _make_be())).is_equal(18)


## 伏兵/水攻：基准 17
func test_fubing_rate() -> void:
	assert_int(Plan.get_plan(11).rate(_make_do(), _make_be())).is_equal(17)
	assert_int(Plan.get_plan(12).rate(_make_do(), _make_be())).is_equal(17)


## 箭雨/劫火：基准 17
func test_jianyu_rate() -> void:
	assert_int(Plan.get_plan(13).rate(_make_do(), _make_be())).is_equal(17)
	assert_int(Plan.get_plan(14).rate(_make_do(), _make_be())).is_equal(17)


## 奇门遁甲：恒 99
func test_qimen_rate() -> void:
	assert_int(Plan.get_plan(15).rate(_make_do(), _make_be())).is_equal(99)


## 伪击转杀：敌人兵力较少时成功率为 0（含随机阈值 1800+randi(0,299)）
func test_weiji_rate_low_soldier() -> void:
	var be := _make_be()
	be.soldiers = 500
	# 500 <= 1800+rand => 返回 0
	assert_int(Plan.get_plan(7).rate(_make_do(), be)).is_equal(0)


## 所有 rate 钳制在 [0, 99]
func test_all_rates_in_range() -> void:
	var do_gen := _make_do()
	var be_gen := _make_be()
	for pid in 16:
		var plan := Plan.get_plan(pid)
		var r := plan.rate(do_gen, be_gen)
		assert_int(r).is_greater_equal(0).append_failure_message("计策%d rate>=0" % pid)
		assert_int(r).is_less_equal(99).append_failure_message("计策%d rate<=99" % pid)


# ============ 4. 技能对 rate 的影响 ============

## 神算（do 技能组1第6位）增强成功率
func test_shensuan_enhance() -> void:
	var do_gen := _make_do()
	var be_gen := _make_be()
	var base := Plan.get_plan(0).rate(do_gen, be_gen)
	# 神算：skills[0] 第6位(has_skill(1,5)) => 1<<(10-5)=1<<5
	do_gen.skills[0] = 1 << 5
	var enhanced := Plan.get_plan(0).rate(do_gen, be_gen)
	assert_int(enhanced).is_greater_equal(base)


## 冷静（be 技能组1第1位）削弱成功率
func test_lengjing_weaken() -> void:
	var do_gen := _make_do()
	var be_gen := _make_be()
	var base := Plan.get_plan(0).rate(do_gen, be_gen)
	# 冷静：skills[0] 第1位(has_skill(1,0)) => 1<<10
	be_gen.skills[0] = 1 << 10
	var weakened := Plan.get_plan(0).rate(do_gen, be_gen)
	assert_int(weakened).is_less_equal(base)


## 火攻技能（do 技能组1第5位）增强火攻计策
func test_huoji_skill_enhance() -> void:
	var do_gen := _make_do()
	var be_gen := _make_be()
	var base := Plan.get_plan(0).rate(do_gen, be_gen)
	# 火攻技能：skills[0] 第5位(has_skill(1,4)) => 1<<(10-4)=1<<6
	do_gen.skills[0] = 1 << 6
	assert_int(Plan.get_plan(0).rate(do_gen, be_gen)).is_greater_equal(base)


# ============ 5. result 不变量 ============

## 火攻：扣兵不超过士兵上限，返回字符串
func test_huoji_result() -> void:
	var do_gen := _make_do()
	var be_gen := _make_be()
	be_gen.soldiers = 1000
	var result := Plan.get_plan(0).result(do_gen, be_gen, true)
	assert_str(result).is_not_empty()
	assert_int(be_gen.soldiers).is_greater_equal(0)
	assert_int(be_gen.soldiers).is_less_equal(1000)


## 陷阱：扣血不低于 0，返回字符串
func test_xianjing_result() -> void:
	var do_gen := _make_do()
	var be_gen := _make_be()
	var result := Plan.get_plan(1).result(do_gen, be_gen, true)
	assert_str(result).is_not_empty()
	assert_int(be_gen.health).is_greater_equal(0)


## 落石：同时扣兵和血，返回字符串
func test_luoshi_result() -> void:
	var do_gen := _make_do()
	var be_gen := _make_be()
	var result := Plan.get_plan(9).result(do_gen, be_gen, true)
	assert_str(result).is_not_empty()
	assert_int(be_gen.soldiers).is_greater_equal(0)
	assert_int(be_gen.health).is_greater_equal(0)
