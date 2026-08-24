extends Control
## 战前布阵（对应 Unity UIPreBattle）

var _formation_index: int = 0
var _selected_formation: Button = null
var _resolved := false


func _ready() -> void:
	DataManager.ensure_loaded()
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.08, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UIFactory.make_label("战 前 布 阵", 40, Color(0.95, 0.85, 0.4))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-120, 20)
	title.size = Vector2(240, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# 参战双方
	var p_gen := GeneralListCache.get_general(BattleManager.pendingPlayerUnit.genID)
	var e_gen := GeneralListCache.get_general(BattleManager.pendingEnemyUnit.genID)
	var info := UIFactory.make_label("", 24, Color.WHITE)
	info.position = Vector2(150, 100)
	info.size = Vector2(700, 120)
	add_child(info)
	info.text = "我方：%s（兵%d）\n敌方：%s（兵%d）" % [
		p_gen.generalName, p_gen.soldiers, e_gen.generalName, e_gen.soldiers]

	UIFactory.add_label(self, "选择阵型：", Vector2(150, 260), 24)

	# 阵型选择
	var form_box := HBoxContainer.new()
	form_box.position = Vector2(150, 310)
	form_box.size = Vector2(700, 80)
	form_box.add_theme_constant_override("separation", 16)
	add_child(form_box)
	var form_names := ["锥形", "锋矢", "鱼鳞", "鹤翼", "方圆"]
	for i in 5:
		var b := UIFactory.make_button(form_names[i], Vector2(110, 70), 22)
		b.toggle_mode = true
		b.button_group = ButtonGroup.new()
		var idx := i
		b.pressed.connect(_on_formation.bind(idx))
		form_box.add_child(b)
		if i == 0:
			b.button_pressed = true
			_selected_formation = b

	# 参战信息
	var battle_info := UIFactory.make_label(_battle_power_text(p_gen, e_gen), 20, Color.WHITE)
	battle_info.position = Vector2(150, 420)
	battle_info.size = Vector2(700, 100)
	add_child(battle_info)

	# 按钮
	var manual_btn := UIFactory.make_button("手动战斗", Vector2(200, 60), 26)
	manual_btn.position = Vector2(250, 560)
	manual_btn.pressed.connect(_on_manual)
	add_child(manual_btn)

	var auto_btn := UIFactory.make_button("自动战斗", Vector2(200, 60), 26)
	auto_btn.position = Vector2(520, 560)
	auto_btn.pressed.connect(_on_fight)
	add_child(auto_btn)

	var retreat_btn := UIFactory.make_button("撤 退", Vector2(200, 60), 26)
	retreat_btn.position = Vector2(790, 560)
	retreat_btn.pressed.connect(_on_retreat)
	add_child(retreat_btn)


func _on_formation(index: int) -> void:
	_formation_index = index
	BattleManager.formationIndex = index


func _battle_power_text(p_gen: General, e_gen: General) -> String:
	var p_power := p_gen.get_war_value()
	var e_power := e_gen.get_war_value()
	return "我方战力：%d    敌方战力：%d\n（战力仅为参考，实战受阵型、地形、特技影响）" % [p_power, e_power]


func _on_manual() -> void:
	if _resolved:
		return
	_resolved = true
	SceneRouter.change_scene("res://scenes/ui/battle_scene.tscn")


func _on_fight() -> void:
	if _resolved:
		return
	_resolved = true
	var p_unit := BattleManager.pendingPlayerUnit
	var e_unit := BattleManager.pendingEnemyUnit
	var p_gen := GeneralListCache.get_general(p_unit.genID)
	var e_gen := GeneralListCache.get_general(e_unit.genID)
	if p_gen == null or e_gen == null:
		SceneRouter.change_scene("res://scenes/ui/war_scene.tscn")
		return
	var terrain := 0
	if not WarManager.war_map.is_empty():
		terrain = int(WarManager.war_map[p_unit.arrayPos.y][p_unit.arrayPos.x]) & 0xF
	BattleManager.init_battle(p_gen, e_gen, terrain, false)
	BattleManager.hmTurnOrder = BattleManager.create_turn_order(p_gen, true)
	BattleManager.aiTurnOrder = BattleManager.create_turn_order(e_gen, false)
	var win := BattleManager.simulated_battle()
	# 移除败方单位
	if win:
		WarManager.aiUnits.erase(e_unit)
		_clear_map_occupy(e_unit)
		GameInfo.show_info = "我军击败 %s！" % e_gen.generalName
	else:
		WarManager.hmUnits.erase(p_unit)
		_clear_map_occupy(p_unit)
		GameInfo.show_info = "%s 战败！" % p_gen.generalName
	BattleManager.pendingPlayerUnit = null
	BattleManager.pendingEnemyUnit = null
	# 检查战争结束
	if WarManager.aiUnits.is_empty():
		WarManager.after_war_settlement(true, true, true)
		return
	if WarManager.hmUnits.is_empty():
		WarManager.after_war_settlement(false, false, true)
		return
	SceneRouter.change_scene("res://scenes/ui/war_scene.tscn")


func _clear_map_occupy(u: UnitData) -> void:
	if u.arrayPos.y < WarManager.war_map.size() and u.arrayPos.x < WarManager.war_map[u.arrayPos.y].size():
		var v: int = WarManager.war_map[u.arrayPos.y][u.arrayPos.x]
		WarManager.war_map[u.arrayPos.y][u.arrayPos.x] = v & 0x3F


func _on_retreat() -> void:
	SceneRouter.change_scene("res://scenes/ui/war_scene.tscn")
