extends Node
## 战争管理（autoload: WarManager）

enum WarState { NONE, PLAYER_TURN, AI_TURN, END_ROUND, WAR_WIN, WAR_LOSE, WAR_EVENT, OCCUPY, DAY_OUT, AI_RETREAT, AI_CAPTIVE, AI_DIE, AI_STARVE, PLAYER_RETREAT, PLAYER_CAPTIVE, PLAYER_DIE, PLAYER_STARVE, BATTLE }
enum BattleState { NONE, PLAYER_TURN, AI_TURN, BATTLE_WIN, BATTLE_LOSE, BATTLE_OVER, HM_RETREAT, AI_RETREAT, HM_CAPTURED, AI_CAPTURED, HM_DIE, AI_DIE }

var warState: int = WarState.NONE
var battleState: int = BattleState.NONE
var curWarCityId: int = 0
var departureCityId: int = 0
var day: int = 1
var isHmDef: bool = false
var hmKingId: int = 0
var aiKingId: int = 0
var hmGold: int = 0
var hmFood: int = 0
var aiGold: int = 0
var aiFood: int = 0
var loserId: int = 0
var isBattle: bool = false
var planIndex: int = 0
var planResult: int = 0
var hmUnitObj: Node = null
var aiUnitObj: Node = null
var attackerCountryId: int = 0
var defenderCountryId: int = 0
var war_map: Array = []          # 19x32
var hmUnits: Array = []          # UnitData
var aiUnits: Array = []          # UnitData
var unitDataList: Dictionary = {}  # genId -> UnitData


## 战前准备
func war_prepare(is_ai_atk: bool, cur_war_city_id: int, departure_city_id: int, attacker_ids: Array, food: int, gold: int, attacker_country_id: int = 0) -> void:
	isHmDef = is_ai_atk
	curWarCityId = cur_war_city_id
	departureCityId = departure_city_id
	day = 1
	warState = WarState.PLAYER_TURN
	battleState = BattleState.NONE
	isBattle = false
	planIndex = 0
	planResult = 0
	var cur_city := CityListCache.get_city_by_city_id(cur_war_city_id)
	defenderCountryId = CountryListCache.get_country_by_king_id(cur_city.ownerID).countryId if cur_city != null and cur_city.ownerID != 0 else 0
	attackerCountryId = attacker_country_id if attacker_country_id != 0 else GameInfo.playerCountryId
	# 玩家侧 hmUnits，AI 侧 aiUnits
	if is_ai_atk:
		hmUnits = _create_units(cur_city.get_officer_ids(), true)  # 守方=玩家(或盟友)
		aiUnits = _create_units(attacker_ids, false)               # 攻方=AI
		hmGold = cur_city.money if cur_city != null else 0
		hmFood = cur_city.grain if cur_city != null else 0
		aiGold = gold
		aiFood = food
	else:
		hmUnits = _create_units(attacker_ids, true)                # 攻方=玩家
		aiUnits = _create_units(cur_city.get_officer_ids(), false) # 守方=AI
		hmGold = gold
		hmFood = food
		aiGold = cur_city.money if cur_city != null else 0
		aiFood = cur_city.grain if cur_city != null else 0
	hmKingId = CountryListCache.get_country_by_country_id(GameInfo.playerCountryId).countryKingId
	aiKingId = _find_commander(_unit_ids(aiUnits))
	# 加载地图
	var map_data := DataManager.read_map_data(cur_war_city_id)
	war_map = map_data if not map_data.is_empty() else _generate_empty_map()
	# 分配初始位置（玩家左 AI 右）
	_assign_start_positions()


func _unit_ids(units: Array) -> Array:
	var ids := []
	for u in units:
		ids.append(u.genID)
	return ids


func _generate_empty_map() -> Array:
	var map: Array = []
	for row in 19:
		var line: Array = []
		for col in 32:
			line.append(0)
		map.append(line)
	return map


func _create_units(general_ids: Array, is_player: bool) -> Array:
	var units := []
	for gid in general_ids:
		var g := GeneralListCache.get_general(gid)
		if g == null:
			continue
		var u := UnitData.new()
		u.genID = gid
		u.isPlayer = is_player
		u.isCommander = gid == _find_commander(general_ids)
		u.moveBonus = 10
		units.append(u)
		unitDataList[gid] = u
	return units


func _find_commander(general_ids: Array) -> int:
	for gid in general_ids:
		var g := GeneralListCache.get_general(gid)
		if g != null and g.is_king():
			return gid
	if not general_ids.is_empty():
		return general_ids[0]
	return 0


## 每日耗粮
func eat_food_every_day() -> bool:
	var total_soldiers := 0
	for u in hmUnits:
		total_soldiers += GeneralListCache.get_general(u.genID).soldiers
	var need := total_soldiers / 250
	if hmFood < need:
		handle_war_over(WarState.AI_STARVE if isHmDef else WarState.PLAYER_STARVE)
		return false
	hmFood -= need
	return true


## 战争结算
func after_war_settlement(is_hm_win: bool, loser_have_commander: bool, change_scene: bool = false) -> void:
	var city := CityListCache.get_city_by_city_id(curWarCityId)
	if city == null:
		return
	# 判断胜者是攻方还是守方
	var attacker_won := (not isHmDef and is_hm_win) or (isHmDef and not is_hm_win)
	var winner_country_id: int = attackerCountryId if attacker_won else defenderCountryId
	var loser_country_id: int = defenderCountryId if attacker_won else attackerCountryId
	var loser_units: Array = hmUnits if not is_hm_win else aiUnits
	var winner_units: Array = aiUnits if not is_hm_win else hmUnits

	var winner_country := CountryListCache.get_country_by_country_id(winner_country_id)
	var loser_country := CountryListCache.get_country_by_country_id(loser_country_id)
	if loser_country != null:
		loser_country.remove_city(curWarCityId)
	if winner_country == null:
		return
	# 转移城市
	city.ownerID = winner_country.countryKingId
	city.prefectID = 0
	city.clear_all_office_general()
	# 败方武将被俘（君主死亡/继承，其余入狱）
	for u in loser_units:
		var g := GeneralListCache.get_general(u.genID)
		if g == null:
			continue
		if g.is_king():
			GeneralListCache.general_die(u.genID)
		else:
			city.add_capture(u.genID)
	# 胜方武将入城
	for u in winner_units:
		var g := GeneralListCache.get_general(u.genID)
		if g != null and g.generalId != winner_country.countryKingId:
			city.add_office_general_id(u.genID)
	city.auto_appoint_prefect()
	winner_country.add_city(curWarCityId)
	var king := GeneralListCache.get_general(winner_country.countryKingId)
	GameInfo.show_info = "%s 占领了 %s" % [king.generalName if king != null else "", city.cityName]
	# 清空战争状态
	hmUnits = []
	aiUnits = []
	unitDataList.clear()
	war_map = []
	if change_scene:
		SceneRouter.change_scene("res://scenes/ui/global_map.tscn")


## 战争结束
func handle_war_over(state: int) -> void:
	match state:
		WarState.DAY_OUT:
			# 30天撤退
			after_war_settlement(false, false)
		WarState.PLAYER_STARVE:
			GameInfo.show_info = "我军粮尽，被迫撤退！"
			after_war_settlement(false, false)
		WarState.AI_STARVE:
			GameInfo.show_info = "敌军粮尽，胜利！"
			after_war_settlement(true, false)
		WarState.OCCUPY:
			after_war_settlement(true, false)
		_:
			after_war_settlement(false, false)


## 玩家撤退到城
func retreat_general_to_city(general_id: int, city_id: int, is_player: bool, is_captured: bool) -> void:
	var city := CityListCache.get_city_by_city_id(city_id)
	if is_captured:
		city.add_capture(general_id)
	else:
		city.add_office_general_id(general_id)


## 模拟整个战争（自动战斗流程）
func simulate_war(hm_units: Array, ai_units: Array) -> int:
	# 返回 1=玩家胜, -1=玩家败, 0=平
	var hm_power := _side_power(hm_units)
	var ai_power := _side_power(ai_units)
	var ratio := float(hm_power) / maxi(ai_power, 1)
	if ratio > 1.5:
		return 1
	elif ratio < 0.5:
		return -1
	return 1 if randf() < ratio / (1.0 + ratio) else -1


func _side_power(units: Array) -> int:
	var total := 0
	for u in units:
		var g := GeneralListCache.get_general(u.genID)
		if g != null:
			total += g.get_battle_power() + g.soldiers
	return total


func _assign_start_positions() -> void:
	var rows := war_map.size()
	var row_idx := 0
	for u in hmUnits:
		if rows == 0:
			break
		u.arrayPos = Vector2i(1, (row_idx % rows))
		u.isMoved = false
		row_idx += 2
	row_idx = 0
	for u in aiUnits:
		if rows == 0:
			break
		u.arrayPos = Vector2i(30, (row_idx % rows))
		u.isMoved = false
		row_idx += 2


## 设置机动力（按兵力）
func set_move_bonus(units: Array) -> void:
	for u in units:
		var g := GeneralListCache.get_general(u.genID)
		if g == null:
			continue
		var bl := g.soldiers / 300
		var table := [7, 8, 10, 12, 14, 15, 16, 18, 20, 22, 24]
		u.moveBonus = table[clampi(bl, 0, 10)]
		u.isMoved = false


## 开始玩家回合
func start_player_turn() -> void:
	warState = WarState.PLAYER_TURN
	set_move_bonus(hmUnits)
	for u in aiUnits:
		u.isMoved = false
	_exec_threaten(hmUnits, aiUnits)
	_exec_threaten(aiUnits, hmUnits)


## 玩家结束回合 -> AI 行动
func end_player_turn() -> void:
	warState = WarState.AI_TURN
	_set_ai_move_bonus()
	_ai_units_turn()


## AI 机动力
func _set_ai_move_bonus() -> void:
	for u in aiUnits:
		var g := GeneralListCache.get_general(u.genID)
		if g == null:
			continue
		var bl := g.soldiers / 300
		var table := [8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28]
		u.moveBonus = table[clampi(bl, 0, 10)]
		u.isMoved = false


## AI 单位行动：向最近的敌人移动
func _ai_units_turn() -> void:
	for u in aiUnits:
		if u.isMoved or u.unitState != UnitData.UnitState.NONE:
			continue
		var nearest_enemy: UnitData = null
		var nearest_dist := 1e9
		for e in hmUnits:
			var d := Vector2i(u.arrayPos - e.arrayPos).length_squared()
			if d < nearest_dist:
				nearest_dist = d
				nearest_enemy = e
		if nearest_enemy == null:
			continue
		# 相邻则触发战斗（交给场景）
		if absi(u.arrayPos.x - nearest_enemy.arrayPos.x) + absi(u.arrayPos.y - nearest_enemy.arrayPos.y) == 1:
			u.isMoved = true
			continue
		# A* 向敌人走一步
		var path := MapManager.get_path_to_target(nearest_enemy.arrayPos, u, war_map, true)
		if path.size() > 1:
			var next_cell: Vector2i = path[1]
			_move_unit_to_cell(u, next_cell)
		u.isMoved = true


## 移动单位到格子
func move_unit_to_cell(u: UnitData, cell: Vector2i) -> void:
	_move_unit_to_cell(u, cell)


func _move_unit_to_cell(u: UnitData, cell: Vector2i) -> void:
	# 清除旧占位
	var old_v: int = war_map[u.arrayPos.y][u.arrayPos.x]
	war_map[u.arrayPos.y][u.arrayPos.x] = old_v & 0x3F
	u.arrayPos = cell
	# 设置新占位
	var new_v: int = war_map[cell.y][cell.x]
	new_v = (new_v & 0x3F) | (0x40 if u.isPlayer else 0x80)
	war_map[cell.y][cell.x] = new_v
	u.isMoved = true


## 回合结束（AI 行动后调用）：推进到第二天
func next_day() -> void:
	day += 1
	if day > 30:
		GameInfo.show_info = "30天已过，双方各自撤军"
		after_war_settlement(false, false, true)
		return
	if not eat_food_every_day():
		return
	start_player_turn()


## 检查是否相邻可交战（供场景在移动后调用）
func find_adjacent_battle() -> Array:
	# 返回 [玩家单位, 敌单位] 相邻对
	for u in hmUnits:
		for e in aiUnits:
			if absi(u.arrayPos.x - e.arrayPos.x) + absi(u.arrayPos.y - e.arrayPos.y) == 1:
				return [u, e]
	return []


## 恐吓技能（对应 Unity ExecThreaten）
func _exec_threaten(do_units: Array, be_units: Array) -> void:
	for do_unit in do_units:
		if do_unit.unitState == UnitData.UnitState.CAPTIVE:
			continue
		var do_general := GeneralListCache.get_general(do_unit.genID)
		if do_general == null or not do_general.has_skill(5, 2):
			continue
		if do_general.soldiers < 300:
			continue
		for be_unit in be_units:
			if be_unit.unitState == UnitData.UnitState.CAPTIVE:
				continue
			var be_general := GeneralListCache.get_general(be_unit.genID)
			if be_general == null or be_general.has_skill(5, 2):
				continue
			if be_general.soldiers >= 600 and do_general.force >= be_general.force and randi_range(0, 100) <= 50:
				var loss := do_general.soldiers / 30 + randi_range(0, do_general.force)
				be_general.sub_soldier(loss)
				do_general.add_experience(int(loss * 1.2))
				GameInfo.show_info = "%s对%s发动恐吓，减少士兵%d" % [do_general.generalName, be_general.generalName, loss]
## 恐吓技能（对应 Unity ExecThreaten）
