class_name TestWeaponAllianceUnit
extends GdUnitTestSuite
## 武器（Weapon）、同盟（Alliance）、大地图单位（UnitData）单元测试
##
## 覆盖：
##  1. Weapon：can_seized 可掉落判定、from_dict/to_dict 序列化往返
##  2. Alliance：构造、字段赋值
##  3. UnitData：状态枚举、get_state_name 中文映射

func before_test() -> void:
	DataManager.load_all_configs()


# ============ 1. 武器 Weapon ============

## 可单挑掉落的武器：id ∈ [5,6,7,14,15,21,23,30,31]
func test_weapon_can_seized() -> void:
	var seized := [5, 6, 7, 14, 15, 21, 23, 30, 31]
	for wid in 32:
		var w := Weapon.new()
		w.weaponID = wid
		assert_bool(w.can_seized()).is_equal(wid in seized).append_failure_message("武器%d" % wid)


## 武器序列化往返：from_dict(to_dict) 各字段一致
func test_weapon_serialization_roundtrip() -> void:
	var w := Weapon.new()
	w.weaponID = 1
	w.weaponName = "短剑"
	w.price = 100
	w.property = 5
	w.weight = 1
	w.kind = 0
	w.isUnique = true
	w.smithy = 3
	var w2 := Weapon.from_dict(w.to_dict())
	assert_int(w2.weaponID).is_equal(1)
	assert_str(w2.weaponName).is_equal("短剑")
	assert_int(w2.price).is_equal(100)
	assert_int(w2.property).is_equal(5)
	assert_int(w2.weight).is_equal(1)
	assert_int(w2.kind).is_equal(0)
	assert_bool(w2.isUnique).is_true()
	assert_int(w2.smithy).is_equal(3)


## 武器 from_dict 缺失字段给默认值
func test_weapon_from_dict_defaults() -> void:
	var w := Weapon.from_dict({})
	assert_int(w.weaponID).is_equal(0)
	assert_str(w.weaponName).is_equal("")
	assert_int(w.property).is_equal(0)
	assert_bool(w.isUnique).is_false()


## 真实武器数据可加载
func test_weapon_data_loaded() -> void:
	assert_int(WeaponListCache.get_weapon_size()).is_equal(32)


# ============ 2. 同盟 Alliance ============

## 构造同盟：countryId 与 months 赋值
func test_alliance_construct() -> void:
	var a := Alliance.new(3, 12)
	assert_int(a.countryId).is_equal(3)
	assert_int(a.months).is_equal(12)
	# 默认构造
	var b := Alliance.new()
	assert_int(b.countryId).is_equal(0)
	assert_int(b.months).is_equal(0)


# ============ 3. 大地图单位 UnitData ============

## 状态枚举值
func test_unit_state_enum() -> void:
	assert_int(UnitData.UnitState.NONE).is_equal(0)
	assert_int(UnitData.UnitState.RETREAT).is_equal(1)
	assert_int(UnitData.UnitState.IDLE).is_equal(2)
	assert_int(UnitData.UnitState.RETIRE).is_equal(3)
	assert_int(UnitData.UnitState.CAPTIVE).is_equal(4)
	assert_int(UnitData.UnitState.DEAD).is_equal(5)
	assert_int(UnitData.UnitState.TRAPPED).is_equal(6)


## get_state_name 中文映射
func test_unit_state_name() -> void:
	var u := UnitData.new()
	u.unitState = UnitData.UnitState.NONE
	assert_str(u.get_state_name()).is_equal("")
	u.unitState = UnitData.UnitState.RETREAT
	assert_str(u.get_state_name()).is_equal("撤退")
	u.unitState = UnitData.UnitState.IDLE
	assert_str(u.get_state_name()).is_equal("待机")
	u.unitState = UnitData.UnitState.RETIRE
	assert_str(u.get_state_name()).is_equal("下野")
	u.unitState = UnitData.UnitState.CAPTIVE
	assert_str(u.get_state_name()).is_equal("被俘")
	u.unitState = UnitData.UnitState.DEAD
	assert_str(u.get_state_name()).is_equal("阵亡")
	u.unitState = UnitData.UnitState.TRAPPED
	assert_str(u.get_state_name()).is_equal("被陷")


## 默认字段
func test_unit_defaults() -> void:
	var u := UnitData.new()
	assert_int(u.genID).is_equal(0)
	assert_bool(u.isPlayer).is_false()
	assert_int(u.moveBonus).is_equal(0)
	assert_int(u.trappedDay).is_equal(0)
	assert_bool(u.isMoved).is_false()
	assert_int(u.unitState).is_equal(UnitData.UnitState.NONE)
	assert_vector(u.arrayPos).is_equal(Vector2i.ZERO)
