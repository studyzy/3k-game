extends Node
## 战斗管理（autoload: BattleManager）

enum TroopType { CAPTAIN, CAVALRY, ARCHER, INFANTRY }

var battleState: int = WarManager.BattleState.NONE
var hmGeneral: General = null
var aiGeneral: General = null
var battleMap: Array = []       # 7x16
var battleTerrain: int = 0
var formationIndex: int = 0
var isHmDef: bool = false
var hmTacticPoint: int = 0
var aiTacticPoint: int = 0
var hmTurnOrder: Array = []     # {troopType, ...}
var aiTurnOrder: Array = []
var pendingPlayerUnit: UnitData = null   # 待触发战斗的玩家单位
var pendingEnemyUnit: UnitData = null    # 待触发战斗的敌单位
var hmGeneralHurt: int = 0
var activeTactics: Dictionary = {}   # {tacticName: turnsRemaining}
var aiGeneralHurt: int = 0
var hmSoldierLoss: int = 0
var aiSoldierLoss: int = 0


func init_battle(hm_gen: General, ai_gen: General, terrain: int, is_hm_def: bool) -> void:
	hmGeneral = hm_gen
	aiGeneral = ai_gen
	battleTerrain = terrain
	isHmDef = is_hm_def
	hmTacticPoint = hm_gen.wisdom * 13 / 100
	aiTacticPoint = ai_gen.wisdom * 13 / 100
	hmGeneralHurt = 0
	aiGeneralHurt = 0
	hmSoldierLoss = 0
	aiSoldierLoss = 0


func get_troops_num(general: General) -> int:
	var num := (general.soldiers - 1) / 300 + 2
	if num <= 0:
		num = 1
	return num


## 生成兵种序列（主将 + 骑/弓/步）
func create_turn_order(general: General, is_player: bool) -> Array:
	var order := []
	var captain := {"troopType": TroopType.CAPTAIN, "generalID": general.generalId, "isPlayer": is_player}
	order.append(captain)
	var terrain_idx := _terrain_index(battleTerrain)
	var army_adapt: Array = general.army
	var cai: Array = TextLibrary.CAI_PROPORTION[terrain_idx][army_adapt[terrain_idx]]
	var total := get_troops_num(general) - 1
	var remaining := maxi(total, 0)
	for i in 3:
		var count: int = int(cai[i]) * remaining / 10
		for j in count:
			var troop_type := TroopType.CAVALRY if i == 0 else (TroopType.ARCHER if i == 1 else TroopType.INFANTRY)
			order.append({"troopType": troop_type, "generalID": general.generalId, "isPlayer": is_player})
	return order


func _terrain_index(terrain: int) -> int:
	# 0平原 1山地 2水域 3城战
	if terrain == 8:
		return 3
	elif terrain == 9 or terrain == 15:
		return 2
	elif terrain in [10, 11, 12, 13, 14]:
		return 1
	return 0


## 自动战斗（SimulatedBattle）返回 true=玩家胜
func simulated_battle() -> bool:
	var hm_power := _side_power(hmGeneral, hmTurnOrder, hmTacticPoint, true)
	var ai_power := _side_power(aiGeneral, aiTurnOrder, aiTacticPoint, false)
	hm_power /= 1000
	ai_power /= 1000
	var hm_pf := hm_power
	var ai_pf := ai_power
	hm_power = hm_pf * hmGeneral.soldiers
	ai_power = ai_pf * aiGeneral.soldiers
	var hm_initial := hmGeneral.soldiers
	var ai_initial := aiGeneral.soldiers
	var hm_win := hm_power >= ai_power
	if hm_win:
		aiGeneral.soldiers = 0
		var ends := (hm_power - ai_power) / maxi(hm_pf, 1)
		ends = clampi(ends, 0, 3000)
		hmGeneral.soldiers = ends
	else:
		hmGeneral.soldiers = 0
		var ends2 := (ai_power - hm_power) / maxi(ai_pf, 1)
		ends2 = clampi(ends2, 0, 3000)
		aiGeneral.soldiers = ends2
	# 经验结算
	hmSoldierLoss = ai_initial - aiGeneral.soldiers
	aiSoldierLoss = hm_initial - hmGeneral.soldiers
	_grant_exp(hm_win)
	return hm_win


func _side_power(general: General, order: Array, tactic_point: int, is_player: bool) -> int:
	var power := 0
	for i in range(1, order.size()):
		var atk := (general.lead * 2 + general.force) / 3 + (general.lead + general.force) * (general.level - 1) / 25
		var def := (general.lead * 2 + general.wisdom) / 3 + (general.lead + general.wisdom) * (general.level - 1) / 25
		if general.has_skill(2, 7) and randi_range(0, 2) < 1:
			def += def / 2
		if general.has_skill(2, 8) and randi_range(0, 2) < 1:
			def += def / 2
		if general.has_skill(3, 9):
			atk += atk / 2
			def += def / 2
		var troop_type: int = order[i]["troopType"]
		if troop_type == TroopType.CAVALRY:
			if general.has_skill(2, 0) and randi_range(0, 2) < 1:
				atk += atk / 2
			elif general.has_skill(2, 1) and randi_range(0, 4) < 1:
				atk += atk / 2
			if (battleTerrain == 10 or battleTerrain == 11) and general.has_skill(2, 5) and randi_range(0, 5) < 1:
				atk += atk / 2
			var p := (atk + def) * 2 + atk * randi_range(1, 2) + atk * tactic_point / 8
			power += p * p
		elif troop_type == TroopType.ARCHER:
			if general.has_skill(2, 6) and randi_range(0, 4) < 2:
				atk += atk * 2 / 5
			if general.has_skill(2, 2) and randi_range(0, 2) < 1:
				atk += atk / 2
			elif general.has_skill(2, 3) and randi_range(0, 4) < 1:
				atk += atk / 2
			if battleTerrain == 9 and general.has_skill(2, 4) and randi_range(0, 5) < 1:
				atk += atk / 2
			if (battleTerrain == 10 or battleTerrain == 11) and general.has_skill(2, 5) and randi_range(0, 5) < 1:
				atk += atk / 2
			var p2 := (atk + def) * 2 + atk * randi_range(0, 1) + atk * tactic_point / 7
			power += p2 * p2
		else:
			if battleTerrain == 9 and general.has_skill(2, 4) and randi_range(0, 5) < 1:
				atk += atk / 2
			if (battleTerrain == 10 or battleTerrain == 11) and general.has_skill(2, 5) and randi_range(0, 5) < 1:
				atk += atk / 2
			var p3 := (atk + def) * 2 / 3
			power += p3 * p3
	return power


func _grant_exp(hm_win: bool) -> void:
	var atk_gen := hmGeneral if hm_win else aiGeneral
	var def_gen := aiGeneral if hm_win else hmGeneral
	var total_exp := maxi(hmSoldierLoss, aiSoldierLoss)
	GeneralListCache.add_exp_p(atk_gen, def_gen, total_exp)
	atk_gen.add_lead_exp(hmSoldierLoss / 300 if hm_win else aiSoldierLoss / 300)
	atk_gen.add_force_exp(hmGeneralHurt / 50 if hm_win else aiGeneralHurt / 50)


## 战术生效判定
func _tactic_active(tactic_name: String, is_player: bool) -> bool:
	var key := ("hm_" if is_player else "ai_") + tactic_name
	return activeTactics.get(key, 0) > 0


## 应用战术（持续 duration 轮）
func apply_tactic(tactic_name: String, is_player: bool, duration: int) -> void:
	var key := ("hm_" if is_player else "ai_") + tactic_name
	activeTactics[key] = duration


## 回合结束时递减战术持续
func tick_tactics() -> void:
	for key in activeTactics.keys():
		activeTactics[key] = int(activeTactics[key]) - 1
		if activeTactics[key] <= 0:
			activeTactics.erase(key)
