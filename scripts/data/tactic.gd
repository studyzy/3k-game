class_name Tactic
extends RefCounted
## 战术系统（6 种战术，对应 Unity Tactic.cs）

func get_tactic_id() -> int: return 0
func get_name() -> String: return ""
func get_description() -> String: return ""
func get_cost() -> int: return 0
func get_duration() -> int: return 0
func execute(_is_player: bool) -> void: pass
func is_successful(_is_player: bool) -> bool: return false


func is_enough(is_player: bool) -> bool:
	if is_player:
		return get_cost() <= BattleManager.hmTacticPoint
	return get_cost() <= BattleManager.aiTacticPoint


static func get_tactic(tactic_id: int) -> Tactic:
	match tactic_id:
		1: return DuelTactic.new()
		2: return BindTactic.new()
		3: return CrossbowTactic.new()
		4: return ShoutTactic.new()
		5: return FireArrowTactic.new()
		6: return ExplosionTactic.new()
	return null


## 按智力的战术数量
static func get_tactics_num(general: General) -> int:
	var wisdom := general.wisdom
	if wisdom < 16: return 0
	if wisdom < 39: return 1
	if wisdom < 54: return 2
	if wisdom < 62: return 3
	if wisdom < 77: return 4
	if wisdom < 93: return 5
	if wisdom < 109: return 6
	return 6


# ============ 6 种战术 ============

class DuelTactic:
	extends Tactic
	func get_tactic_id() -> int: return 1
	func get_name() -> String: return "挑战"
	func get_description() -> String: return "向敌将发出单挑邀请.耗费2个计策点"
	func get_cost() -> int: return 2
	func is_successful(is_player: bool) -> bool:
		if not is_enough(is_player):
			return false
		var ai_general := BattleManager.aiGeneral
		var hm_general := BattleManager.hmGeneral
		var do_gen := hm_general if is_player else ai_general
		var be_gen := ai_general if is_player else hm_general
		if be_gen.get_hp() < 25:
			return false
		if do_gen.has_skill(5, 3) and be_gen.force > 80:
			return true
		var be_i := ceili(SoloManager.get_atk_dea(be_gen, be_gen.get_attack_power(), do_gen.get_defend_power()) * SoloManager.get_percentage(be_gen, do_gen, false, false) / 100.0)
		var do_i := ceili(SoloManager.get_atk_dea(do_gen, do_gen.get_attack_power(), be_gen.get_defend_power()) * SoloManager.get_percentage(do_gen, be_gen, false, false) / 100.0)
		var be_val := be_i * be_gen.get_hp()
		var do_val := do_i * do_gen.get_hp()
		return be_val > do_val + 25 and randi_range(0, be_val - do_val - 1) > 25


class BindTactic:
	extends Tactic
	func get_tactic_id() -> int: return 2
	func get_name() -> String: return "咒缚"
	func get_description() -> String: return "限制敌将行动.耗费5个计策点"
	func get_cost() -> int: return 5
	func get_duration() -> int: return 2
	func is_successful(is_player: bool) -> bool:
		if not is_enough(is_player):
			return false
		var do_gen := BattleManager.hmGeneral if is_player else BattleManager.aiGeneral
		var be_gen := BattleManager.aiGeneral if is_player else BattleManager.hmGeneral
		var i1 := do_gen.wisdom - be_gen.wisdom
		if do_gen.has_skill(5, 9):  # 束缚
			i1 += 30
		if i1 < 0:
			return false
		return randi_range(0, 79) <= i1
	func execute(is_player: bool) -> void:
		# 令对方主将待机（战术战斗中）
		pass


class CrossbowTactic:
	extends Tactic
	func get_tactic_id() -> int: return 3
	func get_name() -> String: return "连弩"
	func get_description() -> String: return "箭手射程增加.耗费7个计策点"
	func get_cost() -> int: return 7
	func get_duration() -> int: return 4


class ShoutTactic:
	extends Tactic
	func get_tactic_id() -> int: return 4
	func get_name() -> String: return "呐喊"
	func get_description() -> String: return "全军攻击力增加.耗费8个计策点"
	func get_cost() -> int: return 8
	func get_duration() -> int: return 4


class FireArrowTactic:
	extends Tactic
	func get_tactic_id() -> int: return 5
	func get_name() -> String: return "火矢"
	func get_description() -> String: return "箭手攻击力大大增加.耗费10个计策点"
	func get_cost() -> int: return 10
	func get_duration() -> int: return 3


class ExplosionTactic:
	extends Tactic
	func get_tactic_id() -> int: return 6
	func get_name() -> String: return "爆炎"
	func get_description() -> String: return "我方兵力大于500.利用火器攻击敌军.耗费12个计策点"
	func get_cost() -> int: return 11
	func can_execute(current_tactic_points: int, is_player: bool) -> bool:
		if current_tactic_points < get_cost():
			return false
		if is_player:
			return BattleManager.hmGeneral != null and BattleManager.hmGeneral.soldiers >= 500
		return false
