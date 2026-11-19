extends Reference
const FakeEquip = preload("res://stubs/FakeEquip.gd")
var name = "测试武将"

func get_name(): return name
func get_hp(): return 55.0
func get_max_hp(): return 60
func get_power(): return 82
func get_wisdom(): return 71
func get_moral(): return 49
func get_politics(): return 78
func get_loyalty(): return 76
func get_leadership(): return 34
func get_courage(): return 54
func get_level(): return 2
func get_exp(): return 2000
func get_troops_type(): return "平"
func get_weapon(): return FakeEquip.new("短剑", "短剑，攻：12，重：3")
func get_suit(): return FakeEquip.new("纶巾", "防：4，重：1")
func get_jewelry(): return FakeEquip.new("兵书", "兵书")
func get_steed(): return FakeEquip.new("黄鬃", "马力：5，机动：2")
func get_equip(type):
	match type:
		"武器": return get_weapon()
		"防具": return get_suit()
		"道具": return get_jewelry()
		"坐骑": return get_steed()
	return FakeEquip.new("", "")
