class_name TestGeneral
extends GdUnitTestSuite
## 武将（General）核心数值单元测试
##
## 覆盖 General 的纯公式函数，以及一个依赖全局缓存（WeaponListCache）的用例。
## 纯函数不依赖全局状态；依赖单例的用例在 before_test() 中加载配置。

func before_test() -> void:
	# 依赖 WeaponListCache/CountryListCache 等单例，每次重置保证隔离
	DataManager.load_all_configs()


## 构造一个五维总分为 total 的武将（每项约均分，避免单项 >=95 触发特殊规则）
func _make_general(total: int) -> General:
	var g := General.new()
	# 五项尽量均分，确保单项不触发 "任一属性 >=95 则 grade=5" 的特殊规则
	var part: int = total / 5
	var remainder: int = total % 5
	g.lead = part
	g.govern = part
	g.force = part
	g.charm = part
	g.wisdom = part + remainder
	return g


## 分级边界（score 总分 -> 等级）
func test_general_grade_boundaries() -> void:
	assert_int(_make_general(196).get_general_grade()).is_equal(0)
	assert_int(_make_general(197).get_general_grade()).is_equal(1)
	assert_int(_make_general(282).get_general_grade()).is_equal(1)
	assert_int(_make_general(283).get_general_grade()).is_equal(2)
	assert_int(_make_general(345).get_general_grade()).is_equal(2)
	assert_int(_make_general(346).get_general_grade()).is_equal(3)
	assert_int(_make_general(421).get_general_grade()).is_equal(3)
	assert_int(_make_general(422).get_general_grade()).is_equal(4)


## 任一项 >=95 且原等级 <4 时提升为怪才(5)
func test_general_grade_special_95() -> void:
	var g := _make_general(200)  # 基础等级 1
	g.lead = 95
	assert_int(g.get_general_grade()).is_equal(5)


## 等级中文名
func test_general_grade_name() -> void:
	assert_str(_make_general(100).get_general_grade_s()).is_equal("愚钝")
	assert_str(_make_general(200).get_general_grade_s()).is_equal("平庸")
	assert_str(_make_general(300).get_general_grade_s()).is_equal("良才")
	assert_str(_make_general(370).get_general_grade_s()).is_equal("精英")
	assert_str(_make_general(450).get_general_grade_s()).is_equal("奇才")
	var g := _make_general(200)
	g.lead = 95
	assert_str(g.get_general_grade_s()).is_equal("怪才")


## 薪水 = 1 + 等级 * 2
func test_salary() -> void:
	var g := General.new()
	g.level = 1
	assert_int(g.get_salary()).is_equal(3)
	g.level = 5
	assert_int(g.get_salary()).is_equal(11)
	g.level = 8
	assert_int(g.get_salary()).is_equal(17)


## 升级经验上限（按等级取 LEVEL_UP_EXP）
func test_max_exp() -> void:
	var g := General.new()
	g.level = 1
	assert_int(g.get_max_exp()).is_equal(6000)
	g.level = 3
	assert_int(g.get_max_exp()).is_equal(14000)
	g.level = 8
	assert_int(g.get_max_exp()).is_equal(32767)


## HP 钳制：set/add/sub 均在 [0, maxHealth]
func test_hp_clamp() -> void:
	var g := General.new()
	g.health = 50
	g.maxHealth = 100
	g.set_hp(120)
	assert_int(g.get_hp()).is_equal(100)
	g.set_hp(-10)
	assert_int(g.get_hp()).is_equal(0)
	# add_hp 返回实际变化量，并钳制到上限
	g.set_hp(90)
	assert_int(g.add_hp(50)).is_equal(10)
	assert_int(g.get_hp()).is_equal(100)
	# sub_hp 到 0 返回 true
	g.set_hp(10)
	assert_bool(g.sub_hp(20)).is_true()
	assert_int(g.get_hp()).is_equal(0)


## 忠诚度钳制在 [0, 100]
func test_loyalty_clamp() -> void:
	var g := General.new()
	g.set_loyalty(150)
	assert_int(g.get_loyalty()).is_equal(100)
	g.set_loyalty(-5)
	assert_int(g.get_loyalty()).is_equal(0)
	g.set_loyalty(80)
	g.sub_loyalty(200)
	assert_int(g.get_loyalty()).is_equal(0)


## 计策数量按智谋/等级分档
func test_plan_num() -> void:
	var g := General.new()
	g.level = 1
	g.wisdom = 30
	assert_int(g.get_plan_num()).is_equal(2)
	g.wisdom = 50
	assert_int(g.get_plan_num()).is_equal(4)
	g.wisdom = 60
	assert_int(g.get_plan_num()).is_equal(6)
	g.wisdom = 82
	assert_int(g.get_plan_num()).is_equal(8)
	g.wisdom = 86
	assert_int(g.get_plan_num()).is_equal(10)
	g.wisdom = 93
	g.level = 5
	assert_int(g.get_plan_num()).is_equal(14)
	g.wisdom = 100
	g.level = 8
	assert_int(g.get_plan_num()).is_equal(16)


## 带兵上限：普通 = 1000 + 12*lead + 100*level；有技能则固定 3000
func test_max_soldier() -> void:
	var g := General.new()
	g.lead = 60
	g.level = 3
	assert_int(g.get_max_soldier_num()).is_equal(1000 + 12 * 60 + 100 * 3)
	# skills[4] 第 11 位(>>10 &1)置 1 => 3000
	g.skills[4] = 1 << 10
	assert_int(g.get_max_soldier_num()).is_equal(3000)
	# 上限钳制：极高统率也不超过 3000（无技能时）
	g = General.new()
	g.lead = 300
	g.level = 8
	assert_int(g.get_max_soldier_num()).is_equal(3000)


## 学习所需经验 = 200 + 智谋*50
func test_school_need_exp() -> void:
	var g := General.new()
	g.wisdom = 60
	assert_int(g.get_school_need_exp()).is_equal(200 + 60 * 50)


## 战争值公式
func test_war_value() -> void:
	var g := General.new()
	g.lead = 80
	g.wisdom = 70
	g.force = 90
	g.level = 3
	var expected := int(80 * 1.42 + 70 * 0.25 + 90 * 0.33 + ((80 * 2 + 90 + 70) * (3 - 1)) * 0.04)
	assert_int(g.get_war_value()).is_equal(expected)


## 依赖 WeaponListCache 的用例：攻击力公式
func test_attack_power() -> void:
	var g := General.new()
	g.force = 90
	g.level = 3
	g.arm = 0
	var wp: int = WeaponListCache.get_weapon(g.arm).property
	var expected := int(90 * (1 + wp / 100.0) * (3 + 19) / 20.0)
	assert_int(g.get_attack_power()).is_equal(expected)


## 防御力公式（同攻击，按防具 armor 的 property）
func test_defend_power() -> void:
	var g := General.new()
	g.force = 90
	g.level = 3
	g.armor = 0
	var ap: int = WeaponListCache.get_weapon(g.armor).property
	var expected := int(90 * (1 + ap / 100.0) * (3 + 19) / 20.0)
	assert_int(g.get_defend_power()).is_equal(expected)


## 兵种适性字符串：平/山/水 + C/B/A/S
func test_army_s() -> void:
	var g := General.new()
	g.army = [0, 1, 2]
	assert_str(g.get_army_s()).is_equal("平C山B水A")
	g.army = [3, 3, 3]
	assert_str(g.get_army_s()).is_equal("平S山S水S")
	# 越界值每个输出一个 '?'（不含前缀），共3字符
	g.army = [9, 9, 9]
	assert_str(g.get_army_s()).has_length(3)


## 五维总和
func test_all_status() -> void:
	var g := General.new()
	g.lead = 80
	g.govern = 70
	g.force = 60
	g.charm = 50
	g.wisdom = 40
	assert_int(g.all_status()).is_equal(300)


## 学习：扣经验、智谋+1
func test_study_up() -> void:
	var g := General.new()
	g.wisdom = 60
	g.experience = 3000
	var cost := g.get_school_need_exp()  # 200+60*50=3200
	# 经验不足时不扣除？study_up 直接扣
	g.study_up()
	assert_int(g.wisdom).is_equal(61)
	assert_int(g.experience).is_equal(3000 - cost)


## 加经验：达到升级经验则升级并清掉溢出
func test_add_experience_levelup() -> void:
	var g := General.new()
	g.level = 1
	g.experience = 0
	# 1级升级需 6000
	g.add_experience(6000)
	# 6000 >= 6000 升级到2级，experience 归零
	assert_int(g.level).is_equal(2)
	assert_int(g.experience).is_equal(0)


## 加经验：不足不升级
func test_add_experience_no_levelup() -> void:
	var g := General.new()
	g.level = 1
	g.experience = 0
	g.add_experience(5000)
	assert_int(g.level).is_equal(1)
	assert_int(g.experience).is_equal(5000)


## 战斗战力公式：武器/防具加成 + 属性权重
func test_battle_power() -> void:
	var g := General.new()
	g.arm = 0
	g.armor = 0
	g.force = 90
	g.wisdom = 80
	g.health = 100
	g.soldiers = 1000
	var wp: float = WeaponListCache.get_weapon(0).property * 1.3
	var ap: float = WeaponListCache.get_weapon(0).property * 1.3
	var expected := wp + ap + 90 * 1.3 + 80 * 1.2 + 100 * 1.1 + 1000 * 0.2
	assert_float(g.get_battle_power()).is_equal(expected)


## 战争值公式（calculate_war_value）
func test_calculate_war_value() -> void:
	var g := General.new()
	g.force = 90
	g.wisdom = 70
	g.lead = 80
	g.soldiers = 1000
	var expected := (90 + 70 + 80 * 2) / 2 * (1000 + 150)
	assert_int(g.calculate_war_value()).is_equal(expected)


## is_king：君主武将返回 true，非君主返回 false（依赖真实数据）
func test_is_king() -> void:
	# 用真实势力的君主验证
	var c1 := CountryListCache.get_country_by_country_id(1)
	assert_bool(GeneralListCache.get_general(c1.countryKingId).is_king()).is_true()
	# 用一个确定非君主的武将（不存在的 ID 对应武将）
	var g := General.new()
	g.generalId = 99999
	assert_bool(g.is_king()).is_false()


## add_loyalty：君主上限 100，非君主上限 99
func test_add_loyalty_cap() -> void:
	var g := General.new()
	g.generalId = 1
	g.loyalty = 95
	# 非君主：加到 99 封顶
	g.add_loyalty(10)
	assert_int(g.get_loyalty()).is_equal(99)
	# 君主：加到 100 封顶
	var c1 := CountryListCache.get_country_by_country_id(1)
	var king := GeneralListCache.get_general(c1.countryKingId)
	king.set_loyalty(95)
	king.add_loyalty(10)
	assert_int(king.get_loyalty()).is_equal(100)
