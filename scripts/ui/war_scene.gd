extends Control
## 战争场景（手动网格战斗，对应 Unity WarScene）

const CELL := 20
const ROWS := 19
const COLS := 32

var _selected_unit: UnitData = null
var _movable_cells: Dictionary = {}
var _grid_offset := Vector2.ZERO
var _grid_container: Control
var _info_label: Label
var _day_label: Label
var _resolved := false
var _plan_panel: Panel
var _current_plan: Plan = null
var _plan_target_mode := false


func _ready() -> void:
	DataManager.ensure_loaded()
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_grid_offset = Vector2((1920 - COLS * CELL) / 2, 60)
	_grid_container = Control.new()
	add_child(_grid_container)

	# 信息栏
	_day_label = UIFactory.make_label("第 %d 天" % WarManager.day, 26, Color.YELLOW)
	_day_label.position = Vector2(60, 10)
	add_child(_day_label)
	var turn_label := UIFactory.make_label("我方回合（蓝方）", 20, Color.WHITE)
	turn_label.position = Vector2(200, 14)
	add_child(turn_label)

	_info_label = UIFactory.make_label("点击我方单位选择，再点击绿色格子移动", 18, Color.WHITE)
	_info_label.position = Vector2(60, 470)
	_info_label.size = Vector2(1200, 30)
	add_child(_info_label)

	_draw_map()
	_build_menu()
	_draw_units()


func _draw_map() -> void:
	var war_map: Array = WarManager.war_map
	if war_map.is_empty():
		return
	for row in ROWS:
		for col in COLS:
			if row >= war_map.size() or col >= war_map[row].size():
				continue
			var v: int = war_map[row][col]
			var cell := ColorRect.new()
			cell.position = _grid_offset + Vector2(col * CELL, row * CELL)
			cell.size = Vector2(CELL, CELL)
			cell.color = _terrain_color(v)
			_grid_container.add_child(cell)


func _terrain_color(v: int) -> Color:
	var terrain := v & 0xF
	match terrain:
		0: return Color(0.16, 0.16, 0.16)
		2, 3, 4, 5: return Color(0.42, 0.62, 0.33)
		6, 7: return Color(0.23, 0.43, 0.23)
		8: return Color(0.58, 0.44, 0.3)
		9, 16, 17, 18: return Color(0.28, 0.48, 0.78)
		10, 11: return Color(0.48, 0.44, 0.4)
		12, 13, 14, 15: return Color(0.18, 0.33, 0.18)
		_: return Color(0.3, 0.3, 0.3)


func _draw_units() -> void:
	# 清除旧的单位/标记
	for child in _grid_container.get_children():
		if child.name.begins_with("Token") or child.name.begins_with("Move"):
			child.queue_free()
	# 可移动格高亮
	for cell in _movable_cells.keys():
		var hl := ColorRect.new()
		hl.name = "MoveHL"
		hl.position = _grid_offset + Vector2(cell.x * CELL, cell.y * CELL)
		hl.size = Vector2(CELL, CELL)
		hl.color = Color(0.2, 0.9, 0.3, 0.5)
		_grid_container.add_child(hl)
	# 单位
	for u in WarManager.hmUnits:
		_draw_unit_token(u, Color(0.2, 0.55, 1.0), true)
	for u in WarManager.aiUnits:
		_draw_unit_token(u, Color(1.0, 0.3, 0.3), false)


func _draw_unit_token(u: UnitData, color: Color, is_player_side: bool) -> void:
	var token := Button.new()
	token.name = "Token"
	token.position = _grid_offset + Vector2(u.arrayPos.x * CELL, u.arrayPos.y * CELL)
	token.size = Vector2(CELL, CELL)
	token.self_modulate = color
	token.text = ""
	token.tooltip_text = _unit_desc(u)
	if is_player_side:
		token.pressed.connect(_on_unit_selected.bind(u))
	# 若选中，加边框
	if u == _selected_unit:
		token.modulate = Color(1.2, 1.2, 0.4)
	_grid_container.add_child(token)


func _unit_desc(u: UnitData) -> String:
	var g := GeneralListCache.get_general(u.genID)
	return "%s  兵%d  机动%d" % [g.generalName, g.soldiers, u.moveBonus] if g != null else "?"


func _on_unit_selected(u: UnitData) -> void:
	if WarManager.warState != WarManager.WarState.PLAYER_TURN:
		return
	if u.isMoved:
		_info_label.text = "该单位本回合已行动过"
		return
	_selected_unit = u
	_movable_cells = MapManager.get_movable_cells_astar(u, WarManager.war_map)
	_info_label.text = "已选择 %s，机动 %d，可移动 %d 格" % [_unit_desc(u), u.moveBonus, _movable_cells.size()]
	_draw_units()


func _build_menu() -> void:
	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.position = Vector2(-450, -90)
	bar.size = Vector2(900, 80)
	add_child(bar)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	bar.add_child(hbox)

	var menu := {
		"移动": _on_menu_move,
		"计策": _on_menu_plan,
		"攻城": _on_menu_attack,
		"情报": _on_menu_intelligence,
		"待机": _on_menu_idle,
		"撤退": _on_menu_retreat,
		"结束回合": _on_menu_end_turn,
	}
	for name in menu.keys():
		var b := UIFactory.make_button(name, Vector2(120, 54), 22)
		b.pressed.connect(menu[name])
		hbox.add_child(b)


func _on_menu_move() -> void:
	# 移动模式：允许选择单位后点格子移动
	_grid_container.gui_input.connect(_on_grid_click)
	if _selected_unit != null:
		_check_village(_selected_unit)


func _on_menu_attack() -> void:
	if _selected_unit == null:
		_info_label.text = "请先选择单位"
		return
	# 检查选中单位是否与敌人相邻，相邻则触发战斗
	var enemy := _adjacent_enemy(_selected_unit)
	if enemy == null:
		_info_label.text = "该单位周围没有相邻敌军"
		return
	_trigger_battle(_selected_unit, enemy)


func _on_menu_plan() -> void:
	if _selected_unit == null:
		_info_label.text = "请先选择施放计策的单位"
		return
	if _plan_panel != null:
		_plan_panel.queue_free()
		_plan_panel = null
	var general := GeneralListCache.get_general(_selected_unit.genID)
	var plan_num := general.get_plan_num()
	_plan_panel = Panel.new()
	_plan_panel.set_anchors_preset(Control.PRESET_CENTER)
	_plan_panel.position = Vector2(-220, -250)
	_plan_panel.size = Vector2(440, 500)
	add_child(_plan_panel)
	UIFactory.add_label(_plan_panel, "选择计策（%s 机动%d）" % [general.generalName, _selected_unit.moveBonus], Vector2(40, 10), 24)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(20, 50)
	scroll.size = Vector2(400, 380)
	_plan_panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size = Vector2(380, 0)
	scroll.add_child(box)
	for pid in plan_num:
		var plan := Plan.get_plan(pid)
		if plan == null:
			continue
		if not plan.is_suitable(int(WarManager.war_map[_selected_unit.arrayPos.y][_selected_unit.arrayPos.x]) & 0xF):
			continue
		var cost: int = plan.use_cost(general)
		if cost > _selected_unit.moveBonus:
			continue
		var b := UIFactory.make_button("%s（机动%d）" % [plan.get_plan_name(), cost], Vector2(370, 46), 20)
		b.pressed.connect(_on_plan_selected.bind(plan))
		box.add_child(b)
	var close := UIFactory.make_button("关闭", Vector2(100, 40), 20)
	close.pressed.connect(func(): _plan_panel.queue_free(); _plan_panel = null)
	_plan_panel.add_child(close)
	close.position = Vector2(170, 440)


func _on_plan_selected(plan: Plan) -> void:
	_current_plan = plan
	_plan_target_mode = true
	if _plan_panel != null:
		_plan_panel.queue_free()
		_plan_panel = null
	_info_label.text = "已选择 %s，点击范围内敌军目标施放" % plan.get_plan_name()
	_draw_plan_cells(plan)


func _draw_plan_cells(plan: Plan) -> void:
	for child in _grid_container.get_children():
		if child.name == "PlanHL":
			child.queue_free()
	var range_cells := MapManager.get_cells_in_range(_selected_unit.arrayPos, plan.in_distance(GeneralListCache.get_general(_selected_unit.genID)))
	for cell in range_cells:
		if cell.y >= 0 and cell.y < ROWS and cell.x >= 0 and cell.x < COLS:
			var hl := ColorRect.new()
			hl.name = "PlanHL"
			hl.position = _grid_offset + Vector2(cell.x * CELL, cell.y * CELL)
			hl.size = Vector2(CELL, CELL)
			hl.color = Color(0.9, 0.5, 0.1, 0.4)
			_grid_container.add_child(hl)


func _cast_plan_on(target_cell: Vector2i) -> void:
	var plan := _current_plan
	_current_plan = null
	_plan_target_mode = false
	for child in _grid_container.get_children():
		if child.name == "PlanHL":
			child.queue_free()
	# 找到目标敌军
	var target_unit: UnitData = null
	for e in WarManager.aiUnits:
		if e.arrayPos == target_cell:
			target_unit = e
			break
	if target_unit == null:
		_info_label.text = "该格没有敌军目标"
		return
	var do_gen := GeneralListCache.get_general(_selected_unit.genID)
	var be_gen := GeneralListCache.get_general(target_unit.genID)
	if do_gen == null or be_gen == null:
		return
	# 地形判定
	var be_terrain: int = int(WarManager.war_map[target_cell.y][target_cell.x]) & 0xF
	if not plan.is_applicable(be_terrain):
		_info_label.text = "%s 不能用于此地形" % plan.get_plan_name()
		return
	# 范围判定
	if not MapManager.is_in_range(_selected_unit.arrayPos, target_cell, plan.in_distance(do_gen)):
		_info_label.text = "目标超出计策范围"
		return
	# 多目标条件
	if not plan.is_multiple_target(be_gen, true):
		_info_label.text = "目标周围没有足够的友军"
		return
	# 扣机动力并施放
	var cost: int = plan.use_cost(do_gen)
	_selected_unit.moveBonus -= cost
	if plan.is_execute(do_gen, be_gen, true):
		_info_label.text = plan.result(do_gen, be_gen, true)
	else:
		_info_label.text = "计策施展失败"
	_selected_unit = null
	_draw_units()

func _handle_village(terrain: int) -> void:
	if _selected_unit == null:
		return
	var general := GeneralListCache.get_general(_selected_unit.genID)
	if terrain == 7:
		# 医馆：100金恢复20-35体力
		var city := CityListCache.get_city_by_city_id(WarManager.curWarCityId)
		if WarManager.hmGold < 100:
			_info_label.text = "金钱不足，无法进入医馆"
			return
		WarManager.hmGold -= 100
		general.add_hp(randi_range(20, 34))
		_info_label.text = "%s 在医馆恢复体力（现%d）" % [general.generalName, general.health]
		return
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-250, -180)
	panel.size = Vector2(500, 360)
	add_child(panel)
	if terrain == 6:
		# 粮店：买粮（4粮=3金）
		UIFactory.add_label(panel, "村庄粮店（4粮=3金）", Vector2(60, 15), 26)
		var city := CityListCache.get_city_by_city_id(WarManager.curWarCityId)
		_show_village_buy(panel, "粮草", WarManager.hmFood, WarManager.hmGold, func(amount: int, gold: int):
			WarManager.hmGold -= gold
			WarManager.hmFood += amount
			_info_label.text = "购粮 %d，花费 %d 金" % [amount, gold])
	elif terrain == 5:
		# 武器店
		UIFactory.add_label(panel, "村庄武器店", Vector2(60, 15), 26)
		var weapons := WeaponListCache.get_weapons_by_smithy(1)
		if weapons.is_empty():
			UIFactory.add_label(panel, "店中暂无武器", Vector2(60, 70), 22)
		else:
			var box := VBoxContainer.new()
			box.position = Vector2(40, 60)
			box.size = Vector2(420, 220)
			box.add_theme_constant_override("separation", 8)
			panel.add_child(box)
			for w in weapons:
				var b := UIFactory.make_button("%s（%d金）" % [w.weaponName, w.price], Vector2(420, 44), 20)
				b.pressed.connect(func():
					if WarManager.hmGold >= w.price:
						WarManager.hmGold -= w.price
						general.get_new_weapon(w.weaponID)
						_info_label.text = "%s 购得 %s" % [general.generalName, w.weaponName]
					else:
						_info_label.text = "金钱不足")
				box.add_child(b)
	var close := UIFactory.make_button("离开", Vector2(120, 44), 22)
	close.pressed.connect(func(): panel.queue_free())
	panel.add_child(close)
	close.position = Vector2(190, 300)


func _show_village_buy(panel: Panel, item_name: String, food: int, gold: int, callback: Callable) -> void:
	var line_edit := LineEdit.new()
	line_edit.text = "100"
	line_edit.position = Vector2(60, 70)
	line_edit.size = Vector2(200, 40)
	panel.add_child(line_edit)
	var buy := UIFactory.make_button("购 买", Vector2(120, 44), 22)
	buy.position = Vector2(280, 68)
	buy.pressed.connect(func():
		var n := clampi(int(line_edit.text), 0, 30000)
		var gold_needed := n * 3 / 4
		if gold >= gold_needed:
			callback.call(n, gold_needed)
			panel.queue_free()
		else:
			_info_label.text = "金钱不足")
	panel.add_child(buy)


func _on_menu_intelligence() -> void:
	if _selected_unit == null:
		_info_label.text = "请先选择要查看情报的单位"
		return
	var general := GeneralListCache.get_general(_selected_unit.genID)
	if general == null:
		return
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-250, -200)
	panel.size = Vector2(500, 400)
	add_child(panel)
	var text := "%s  Lv.%d\n\n体力：%d/%d    忠诚：%d\n统率：%d    武力：%d\n智谋：%d    政事：%d\n魅力：%d    士兵：%d\n武器：%s\n\n特技：%s" % [
		general.generalName, general.level, general.health, general.maxHealth, general.loyalty,
		general.lead, general.force, general.wisdom, general.govern, general.charm, general.soldiers,
		(WeaponListCache.get_weapon(general.arm).weaponName if WeaponListCache.get_weapon(general.arm) != null else "无"),
		general.get_active_skills()]
	var label := UIFactory.make_label(text, 20, Color.WHITE)
	label.position = Vector2(20, 20)
	label.size = Vector2(460, 320)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(label)
	var close := UIFactory.make_button("关 闭", Vector2(120, 44), 20)
	close.position = Vector2(190, 340)
	close.pressed.connect(func(): panel.queue_free())
	panel.add_child(close)


func _on_menu_idle() -> void:
	if _selected_unit != null:
		_selected_unit.isMoved = true
		_info_label.text = "%s 待机" % _selected_unit.genID
		_selected_unit = null
		_movable_cells = {}
		_draw_units()


func _on_menu_retreat() -> void:
	if _selected_unit == null:
		_info_label.text = "请先选择单位"
		return
	_remove_unit(_selected_unit)
	_selected_unit = null
	_movable_cells = {}
	_check_war_end()
	_draw_units()


func _on_menu_end_turn() -> void:
	_selected_unit = null
	_movable_cells = {}
	WarManager.end_player_turn()
	# AI 行动后可能触发交战
	_check_ai_adjacent()
	WarManager.next_day()
	_day_label.text = "第 %d 天" % WarManager.day
	_info_label.text = "我方回合"
	_draw_units()


func _on_grid_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := _screen_to_cell(event.position)
		if _plan_target_mode and _current_plan != null and _selected_unit != null:
			_cast_plan_on(cell)
			return
		if _selected_unit != null and _movable_cells.has(cell):
			WarManager.move_unit_to_cell(_selected_unit, cell)
			# 检查是否进入村庄
			_check_village(_selected_unit)
			# 移动后若与敌人相邻，自动触发战斗
			var enemy := _adjacent_enemy(_selected_unit)
			if enemy != null:
				_info_label.text = "%s 与 %s 遭遇！" % [_selected_unit.genID, enemy.genID]
				_trigger_battle(_selected_unit, enemy)
			else:
				_selected_unit = null
				_movable_cells = {}
				_info_label.text = "移动完成"
			_draw_units()


func _screen_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(int((pos.x - _grid_offset.x) / CELL), int((pos.y - _grid_offset.y) / CELL))


func _adjacent_enemy(u: UnitData) -> UnitData:
	for e in WarManager.aiUnits:
		if absi(u.arrayPos.x - e.arrayPos.x) + absi(u.arrayPos.y - e.arrayPos.y) == 1:
			return e
	return null


func _check_ai_adjacent() -> void:
	for u in WarManager.aiUnits:
		var enemy := _adjacent_enemy(u)
		if enemy != null:
			_trigger_battle(enemy, u)
			return


func _trigger_battle(player_unit: UnitData, enemy_unit: UnitData) -> void:
	BattleManager.pendingPlayerUnit = player_unit
	BattleManager.pendingEnemyUnit = enemy_unit
	SceneRouter.change_scene("res://scenes/ui/pre_battle.tscn")


func _remove_unit(u: UnitData) -> void:
	if u.isPlayer:
		WarManager.hmUnits.erase(u)
	else:
		WarManager.aiUnits.erase(u)
	# 清除地图占位
	if u.arrayPos.y < WarManager.war_map.size() and u.arrayPos.x < WarManager.war_map[u.arrayPos.y].size():
		var v: int = WarManager.war_map[u.arrayPos.y][u.arrayPos.x]
		WarManager.war_map[u.arrayPos.y][u.arrayPos.x] = v & 0x3F


func _check_war_end() -> void:
	if WarManager.aiUnits.is_empty():
		_info_label.text = "敌军全灭，我军胜利！"
		WarManager.after_war_settlement(true, true, true)
	elif WarManager.hmUnits.is_empty():
		_info_label.text = "我军全灭，战斗失败！"
		WarManager.after_war_settlement(false, false, true)


func _check_village(u: UnitData) -> void:
	if WarManager.war_map.is_empty() or u.arrayPos.y >= WarManager.war_map.size() or u.arrayPos.x >= WarManager.war_map[u.arrayPos.y].size():
		return
	var terrain := int(WarManager.war_map[u.arrayPos.y][u.arrayPos.x]) & 0xF
	if terrain == 5 or terrain == 6 or terrain == 7:
		_handle_village(terrain)
