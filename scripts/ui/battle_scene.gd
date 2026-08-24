extends Control
## 逐格战术战斗（对应 Unity BattleScene，简化自动推进）

const CELL := 36
const ROWS := 7
const COLS := 16

var _grid_offset := Vector2.ZERO
var _hm_troops: Array = []  # TroopData
var _ai_troops: Array = []
var _info_label: Label
var _battle_map: Array = []  # 7x16 占位
var _turn_count := 0
var _battle_over := false
var _fast := false


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.1, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_grid_offset = Vector2((1920 - COLS * CELL) / 2, 120)

	var title := UIFactory.make_label("战 术 战 斗", 36, Color(0.9, 0.7, 0.3))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-100, 10)
	title.size = Vector2(200, 46)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_info_label = UIFactory.make_label("", 20, Color.WHITE)
	_info_label.position = Vector2(60, 470)
	_info_label.size = Vector2(1200, 40)
	add_child(_info_label)

	var fast_btn := UIFactory.make_button("加 速", Vector2(140, 50), 22)
	fast_btn.position = Vector2(700, 620)
	fast_btn.pressed.connect(func(): _fast = true)
	add_child(fast_btn)

	_init_battle()
	await get_tree().process_frame
	_draw()
	_start_battle_loop()


func _init_battle() -> void:
	var p_unit := BattleManager.pendingPlayerUnit
	var e_unit := BattleManager.pendingEnemyUnit
	if p_unit == null or e_unit == null:
		return
	var p_gen := GeneralListCache.get_general(p_unit.genID)
	var e_gen := GeneralListCache.get_general(e_unit.genID)
	BattleManager.init_battle(p_gen, e_gen, _battle_terrain(), false)
	BattleManager.activeTactics.clear()
	# 生成部队
	_hm_troops = _create_side_troops(p_gen, true)
	_ai_troops = _create_side_troops(e_gen, false)
	# 读取阵型并布阵
	var hm_formation := DataManager.get_formation("h%d" % BattleManager.formationIndex)
	var ai_formation := DataManager.get_formation("a%d" % randi_range(0, 4))
	if not hm_formation.is_empty():
		_place_troops(_hm_troops, hm_formation)
	if not ai_formation.is_empty():
		_place_troops(_ai_troops, ai_formation)
	# 初始化占位地图
	for row in ROWS:
		var line: Array = []
		for col in COLS:
			line.append(-1)
		_battle_map.append(line)
	for t in _hm_troops:
		_battle_map[t.arrayPos.y][t.arrayPos.x] = 1
	for t in _ai_troops:
		_battle_map[t.arrayPos.y][t.arrayPos.x] = 2


func _battle_terrain() -> int:
	if not WarManager.war_map.is_empty():
		return int(WarManager.war_map[9][16]) & 0xF
	return 0


func _create_side_troops(general: General, is_player: bool) -> Array:
	var troops := []
	var captain := TroopData.new()
	captain.troopType = TroopData.TroopType.CAPTAIN
	captain.generalID = general.generalId
	captain.isPlayer = is_player
	captain.health = general.health * 3
	captain.init_act_bonus()
	troops.append(captain)
	# 小兵按 CAI 比例
	var terrain_idx := _terrain_index(_battle_terrain())
	var adapt: int = general.army[terrain_idx] if terrain_idx < general.army.size() else 0
	var cai: Array = TextLibrary.CAI_PROPORTION[terrain_idx][clampi(adapt, 0, 3)]
	var total := (general.soldiers - 1) / 300 + 1
	var remaining := maxi(total, 0)
	var troop_types := [TroopData.TroopType.CAVALRY, TroopData.TroopType.ARCHER, TroopData.TroopType.INFANTRY]
	for i in 3:
		var count := int(cai[i]) * remaining / 10
		for j in count:
			var t := TroopData.new()
			t.troopType = troop_types[i]
			t.generalID = general.generalId
			t.isPlayer = is_player
			t.health = 300
			t.init_act_bonus()
			troops.append(t)
	for t in troops:
		t.init_power(general, _battle_terrain())
	return troops


func _terrain_index(terrain: int) -> int:
	if terrain == 8:
		return 3
	elif terrain == 9 or terrain == 15:
		return 2
	elif terrain in [10, 11, 12, 13, 14]:
		return 1
	return 0


func _place_troops(troops: Array, formation: Array) -> void:
	var idx := 0
	for row in ROWS:
		for col in COLS:
			if row >= formation.size() or col >= formation[row].size():
				continue
			var v := int(formation[row][col])
			if v == 255:
				continue
			if idx < troops.size():
				troops[idx].arrayPos = Vector2i(col, row)
			idx += 1


func _draw() -> void:
	# 清空旧格子
	for child in get_children():
		if child.name.begins_with("Battle") or child.name == "BattleFlash":
			child.queue_free()
	# 画网格
	for row in ROWS:
		for col in COLS:
			var cell := ColorRect.new()
			cell.name = "BattleCell"
			cell.position = _grid_offset + Vector2(col * CELL, row * CELL)
			cell.size = Vector2(CELL, CELL)
			cell.color = Color(0.25, 0.3, 0.25)
			if col % 2 == 0:
				cell.color = Color(0.27, 0.32, 0.27)
			add_child(cell)
	# 画部队
	for t in _hm_troops:
		_draw_troop(t, Color(0.2, 0.55, 1.0), "我")
	for t in _ai_troops:
		_draw_troop(t, Color(1.0, 0.3, 0.3), "敌")


func _draw_troop(t: TroopData, color: Color, side_text: String) -> void:
	var token := Label.new()
	token.name = "BattleTroop"
	token.position = _grid_offset + Vector2(t.arrayPos.x * CELL, t.arrayPos.y * CELL)
	token.size = Vector2(CELL, CELL)
	token.add_theme_color_override("font_color", Color.WHITE)
	token.add_theme_font_size_override("font_size", 12)
	token.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	token.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var text := side_text
	match t.troopType:
		TroopData.TroopType.CAPTAIN: text = "帅"
		TroopData.TroopType.CAVALRY: text = "骑"
		TroopData.TroopType.ARCHER: text = "弓"
		TroopData.TroopType.INFANTRY: text = "步"
	token.text = text
	var rect := ColorRect.new()
	rect.name = "BattleTroopBg"
	rect.position = token.position
	rect.size = token.size
	rect.color = color
	add_child(rect)
	add_child(token)


func _start_battle_loop() -> void:
	while not _battle_over:
		_turn_count += 1
		if _turn_count % 5 == 0:
			print("[Battle] 第%d回合 我方%d人 敌方%d人" % [_turn_count, _count_alive(_hm_troops), _count_alive(_ai_troops)])
		# 玩家行动
		_side_act(_hm_troops, _ai_troops, true)
		if _battle_over:
			break
		# AI 行动（先决策战术）
		_ai_use_tactic()
		_side_act(_ai_troops, _hm_troops, false)
		BattleManager.tick_tactics()
		# 任一方全灭则结束
		if _count_alive(_hm_troops) == 0 or _count_alive(_ai_troops) == 0:
			_battle_over = true
			break
		_draw()
		_info_label.text = "第 %d 回合" % _turn_count
		await get_tree().create_timer(0.6 if not _fast else 0.05).timeout
	_draw()
	_finish_battle()


func _side_act(my_troops: Array, enemy_troops: Array, is_player: bool) -> void:
	for t in my_troops:
		if t.health <= 0:
			continue
		var enemy := _nearest_enemy(t, enemy_troops)
		if enemy == null:
			continue
		if _is_adjacent(t.arrayPos, enemy.arrayPos):
			# 攻击（在防守方身上计算伤害）
			var general := GeneralListCache.get_general(t.generalID)
			var enemy_general := GeneralListCache.get_general(enemy.generalID)
			var dmg: int = enemy.battle_hurt_calculate(t, general, enemy_general, enemy.is_captain())
			enemy.health -= dmg
			if enemy.health <= 0:
				_remove_troop(enemy, enemy_troops)
		else:
			# 向敌人走一步
			var step := _step_toward(t.arrayPos, enemy.arrayPos, my_troops, enemy_troops)
			if step != t.arrayPos and _battle_map[step.y][step.x] == -1:
				_battle_map[t.arrayPos.y][t.arrayPos.x] = -1
				t.arrayPos = step
				_battle_map[step.y][step.x] = 1 if t.isPlayer else 2


func _nearest_enemy(t: TroopData, enemy_troops: Array) -> TroopData:
	var nearest: TroopData = null
	var best := 1e9
	for e in enemy_troops:
		if e.health <= 0:
			continue
		var d := Vector2i(t.arrayPos - e.arrayPos).length_squared()
		if d < best:
			best = d
			nearest = e
	return nearest


func _is_adjacent(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


func _step_toward(pos: Vector2i, target: Vector2i, my_troops: Array, enemy_troops: Array) -> Vector2i:
	# 简单启发式：朝目标方向走一步，避开占用
	var dirs := [
		Vector2i(signi(target.x - pos.x), 0),
		Vector2i(0, signi(target.y - pos.y)),
	]
	dirs.shuffle()
	for d in dirs:
		var np: Vector2i = pos + d
		if np.x >= 0 and np.x < COLS and np.y >= 0 and np.y < ROWS and _battle_map[np.y][np.x] == -1:
			return np
	return pos


func _remove_troop(t: TroopData, troops: Array) -> void:
	if t.is_captain():
		_battle_over = true
	troops.erase(t)


func _finish_battle() -> void:
	# 判断胜负
	var p_unit := BattleManager.pendingPlayerUnit
	var e_unit := BattleManager.pendingEnemyUnit
	var player_alive := _count_alive(_hm_troops) > 0
	var ai_alive := _count_alive(_ai_troops) > 0
	var win := player_alive and not ai_alive
	if p_unit != null and e_unit != null:
		if win:
			WarManager.aiUnits.erase(e_unit)
			GameInfo.show_info = "我军击败 %s！" % GeneralListCache.get_general(e_unit.genID).generalName
		else:
			WarManager.hmUnits.erase(p_unit)
			GameInfo.show_info = "%s 战败！" % GeneralListCache.get_general(p_unit.genID).generalName
	BattleManager.pendingPlayerUnit = null
	BattleManager.pendingEnemyUnit = null
	_info_label.text = "战斗结束！%s" % ("我军胜利！" if win else "我军战败！")
	# 战争结束判定
	if WarManager.aiUnits.is_empty():
		WarManager.after_war_settlement(true, true, true)
		return
	if WarManager.hmUnits.is_empty():
		WarManager.after_war_settlement(false, false, true)
		return
	await get_tree().create_timer(1.0).timeout
	SceneRouter.change_scene("res://scenes/ui/war_scene.tscn")


func _has_captain(troops: Array) -> bool:
	for t in troops:
		if t.is_captain() and t.health > 0:
			return true
	return false


func _count_alive(troops: Array) -> int:
	var n := 0
	for t in troops:
		if t.health > 0:
			n += 1
	return n


## AI 战术决策（对应 Unity AIBattle）
func _ai_use_tactic() -> void:
	var ai_archers := 0
	var ai_infantry := 0
	for t in _ai_troops:
		if t.health > 0:
			if t.troopType == TroopData.TroopType.ARCHER:
				ai_archers += 1
			elif t.troopType == TroopData.TroopType.INFANTRY:
				ai_infantry += 1
	# 弓兵多时用连弩/火矢
	if ai_archers >= 3:
		if BattleManager.aiTacticPoint >= 10 and not BattleManager._tactic_active("火矢", false):
			BattleManager.aiTacticPoint -= 10
			BattleManager.apply_tactic("火矢", false, 3)
			return
		if BattleManager.aiTacticPoint >= 7 and not BattleManager._tactic_active("连弩", false):
			BattleManager.aiTacticPoint -= 7
			BattleManager.apply_tactic("连弩", false, 4)
			return
	# 步兵多时用呐喊
	if ai_infantry >= 3 and BattleManager.aiTacticPoint >= 8 and not BattleManager._tactic_active("呐喊", false):
		BattleManager.aiTacticPoint -= 8
		BattleManager.apply_tactic("呐喊", false, 4)


func _flash_cell(cell: Vector2i) -> void:
	var flash := ColorRect.new()
	flash.name = "BattleFlash"
	flash.position = _grid_offset + Vector2(cell.x * CELL, cell.y * CELL)
	flash.size = Vector2(CELL, CELL)
	flash.color = Color(1.0, 0.3, 0.2, 0.7)
	add_child(flash)
	# 在 _draw 时会被清除
