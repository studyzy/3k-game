class_name TestTactic
extends GdUnitTestSuite
## 战术（Tactic）单元测试
##
## 覆盖：
##  1. 战术注册表：get_tactic 6 种都能构造，id/name/cost/duration 元数据正确
##  2. 战术数量 get_tactics_num：按武将智谋分档
##  3. is_enough：依据双方战术点判断是否够用
##  4. 基础类默认方法
##
## 说明：is_enough 依赖 BattleManager 单例的战术点字段，直接设置该字段测试。
## 各战术的 is_successful 依赖完整战斗环境（BattleManager 双方武将、
## SoloManager 单挑系统），本测试不做精确断言，仅覆盖可稳定验证的逻辑。

func before_test() -> void:
	DataManager.load_all_configs()


## 构造指定智谋的武将
func _make_gen(wisdom: int) -> General:
	var g := General.new()
	g.wisdom = wisdom
	return g


# ============ 1. 战术注册表 ============

## 6 种战术都能构造，元数据正确
func test_tactic_registry() -> void:
	# (id, name, cost, duration)
	var expect := [
		[1, "挑战", 2, 0], [2, "咒缚", 5, 2], [3, "连弩", 7, 4],
		[4, "呐喊", 8, 4], [5, "火矢", 10, 3], [6, "爆炎", 11, 0],
	]
	for pair in expect:
		var tactic := Tactic.get_tactic(pair[0])
		assert_object(tactic).is_not_null()
		assert_int(tactic.get_tactic_id()).is_equal(pair[0])
		assert_str(tactic.get_name()).is_equal(pair[1])
		assert_int(tactic.get_cost()).is_equal(pair[2])
		assert_int(tactic.get_duration()).is_equal(pair[3])


## 无效战术 id 返回 null
func test_tactic_registry_invalid() -> void:
	assert_object(Tactic.get_tactic(0)).is_null()
	assert_object(Tactic.get_tactic(7)).is_null()
	assert_object(Tactic.get_tactic(-1)).is_null()


## 战术描述非空
func test_tactic_description() -> void:
	for tid in [1, 2, 3, 4, 5, 6]:
		assert_str(Tactic.get_tactic(tid).get_description()).is_not_empty()


## 爆炎战术：兵力不足500时不可执行
func test_explosion_can_execute() -> void:
	var explosion := Tactic.get_tactic(6)
	var g := _make_gen(90)
	BattleManager.hmGeneral = g
	# 兵力 < 500 不可执行
	g.soldiers = 100
	assert_bool(explosion.can_execute(11, true)).is_false()
	# 战术点不足不可执行
	g.soldiers = 1000
	assert_bool(explosion.can_execute(5, true)).is_false()
	# 兵力和点数都够则执行
	assert_bool(explosion.can_execute(11, true)).is_true()


# ============ 2. 战术数量 ============

## get_tactics_num 按智谋分档
func test_tactics_num() -> void:
	# (wisdom, 期望数量)
	var expect := [
		[10, 0], [16, 1], [39, 2], [54, 3], [62, 4], [77, 5], [93, 6], [100, 6],
	]
	for pair in expect:
		assert_int(Tactic.get_tactics_num(_make_gen(pair[0]))).is_equal(pair[1])


## 智谋边界处数量正确
func test_tactics_num_boundary() -> void:
	assert_int(Tactic.get_tactics_num(_make_gen(15))).is_equal(0)
	assert_int(Tactic.get_tactics_num(_make_gen(16))).is_equal(1)
	assert_int(Tactic.get_tactics_num(_make_gen(38))).is_equal(1)
	assert_int(Tactic.get_tactics_num(_make_gen(39))).is_equal(2)
	assert_int(Tactic.get_tactics_num(_make_gen(108))).is_equal(6)
	assert_int(Tactic.get_tactics_num(_make_gen(109))).is_equal(6)


# ============ 3. is_enough ============

## 玩家方：cost <= hmTacticPoint 则够用
func test_is_enough_player() -> void:
	BattleManager.hmTacticPoint = 6
	assert_bool(Tactic.get_tactic(2).is_enough(true)).is_true()   # 咒缚 cost 5
	assert_bool(Tactic.get_tactic(3).is_enough(true)).is_false()  # 连弩 cost 7
	BattleManager.hmTacticPoint = 7
	assert_bool(Tactic.get_tactic(3).is_enough(true)).is_true()


## AI 方：cost <= aiTacticPoint 则够用
func test_is_enough_ai() -> void:
	BattleManager.aiTacticPoint = 10
	assert_bool(Tactic.get_tactic(5).is_enough(false)).is_true()   # 火矢 cost 10
	assert_bool(Tactic.get_tactic(6).is_enough(false)).is_false()  # 爆炎 cost 11
	BattleManager.aiTacticPoint = 11
	assert_bool(Tactic.get_tactic(6).is_enough(false)).is_true()


## 基础类默认方法返回值
func test_base_tactic_defaults() -> void:
	var t := Tactic.new()
	assert_int(t.get_tactic_id()).is_equal(0)
	assert_str(t.get_name()).is_equal("")
	assert_int(t.get_cost()).is_equal(0)
	assert_bool(t.is_successful(true)).is_false()
