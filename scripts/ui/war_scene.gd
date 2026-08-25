extends Control
## 战争场景（服务器驱动，对应 Unity WarScene）
## 渲染服务器下发的 Mirror.war 状态，发送 C2S_War* 命令。

const CELL := 20
const ROWS := 19
const COLS := 32

var _selected_unit_id: int = -1
var _grid_offset := Vector2.ZERO
var _grid_container: Control
var _info_label: Label
var _day_label: Label
# 单位 sprite 缓存（sanguo 迁移资源）
var _unit_tex: Texture2D = null


func _ready() -> void:
	DataManager.ensure_loaded()
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_grid_offset = Vector2((1920 - COLS * CELL) / 2, 60)
	_grid_container = Control.new()
	add_child(_grid_container)
	# 网格点击监听（移动/攻击目标选择），只在 _ready 连接一次
	_grid_container.gui_input.connect(_on_grid_click)

	_day_label = UIFactory.make_label("第 1 天", 26, Color.YELLOW)
	_day_label.position = Vector2(60, 10)
	add_child(_day_label)

	_info_label = UIFactory.make_label("点击我方单位选择，再点击绿色格子移动", 18, Color.WHITE)
	_info_label.position = Vector2(60, 470)
	_info_label.size = Vector2(1200, 30)
	add_child(_info_label)

	_build_menu()
	_refresh()

	# 监听服务器战争状态推送
	if not NetClient.server_push.is_connected(_on_server_push):
		NetClient.server_push.connect(_on_server_push)


func _on_server_push(op: int, _body: Dictionary) -> void:
	if op == NetClient.S2C_WAR_STEP or op == NetClient.S2C_WAR_START:
		_refresh()


func _refresh() -> void:
	var war: Dictionary = Mirror.war
	if war.is_empty():
		return
	_day_label.text = "第 %d 天" % int(war.get("day", 1))
	_draw_map(war.get("warMap", []))
	_draw_units()


func _draw_map(war_map: Variant) -> void:
	# 清空旧格子
	for child in _grid_container.get_children():
		if child.name == "Cell":
			child.queue_free()
	if not war_map is Array:
		return
	var grid: Array = war_map
	for row in ROWS:
		for col in COLS:
			if row >= grid.size() or col >= grid[row].size():
				continue
			var v: int = int(grid[row][col])
			var cell := ColorRect.new()
			cell.name = "Cell"
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
	# 清空旧单位
	for child in _grid_container.get_children():
		if child.name == "Token" or child.name == "MoveHL":
			child.queue_free()
	var war: Dictionary = Mirror.war
	var hm: Array = war.get("hmUnits", [])
	var ai: Array = war.get("aiUnits", [])
	for u in hm:
		_draw_unit_token(u, Color(0.2, 0.55, 1.0), true)
	for u in ai:
		_draw_unit_token(u, Color(1.0, 0.3, 0.3), false)


func _draw_unit_token(u: Dictionary, color: Color, is_player_side: bool) -> void:
	var pos: Array = u.get("pos", [0, 0])
	var token := Button.new()
	token.name = "Token"
	token.position = _grid_offset + Vector2(int(pos[0]) * CELL, int(pos[1]) * CELL)
	token.size = Vector2(CELL, CELL)
	token.flat = true
	token.self_modulate = color
	token.text = ""
	# 单位 sprite（sanguo 迁移资源 Soldier.png），按我方蓝/敌方红着色
	if _unit_tex == null:
		_unit_tex = load("res://assets/units/Soldier.png") as Texture2D
	if _unit_tex != null:
		token.icon = _unit_tex
		token.expand_icon = true
	token.tooltip_text = "武将ID %d %s" % [int(u.get("genID", 0)), "主将" if u.get("isCommander", false) else ""]
	if is_player_side:
		token.pressed.connect(_on_unit_selected.bind(int(u.get("genID", 0))))
	if int(u.get("genID", 0)) == _selected_unit_id:
		token.modulate = Color(1.2, 1.2, 0.4)
	_grid_container.add_child(token)


func _on_unit_selected(gen_id: int) -> void:
	_selected_unit_id = gen_id
	_info_label.text = "已选择武将ID %d，点击绿色格子移动" % gen_id


func _on_grid_click(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	if _selected_unit_id < 0:
		return
	var local: Vector2 = _grid_container.get_global_transform().affine_inverse() * event.position
	var col := int((local.x - _grid_offset.x) / CELL)
	var row := int((local.y - _grid_offset.y) / CELL)
	if col < 0 or col >= COLS or row < 0 or row >= ROWS:
		return
	# 发送移动命令到服务器
	NetClient.send(NetClient.C2S_WAR_MOVE, {
		"unitGenId": _selected_unit_id, "toCellX": col, "toCellY": row,
	})
	_selected_unit_id = -1


func _build_menu() -> void:
	var bar := Panel.new()
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.position = Vector2(-450, -90)
	bar.size = Vector2(900, 70)
	add_child(bar)
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	bar.add_child(hbox)

	var menu := {
		"移动": _on_menu_move,
		"攻城": _on_menu_attack,
		"撤退": _on_menu_retreat,
		"结束回合": _on_menu_end_turn,
	}
	for name in menu.keys():
		var b := UIFactory.make_button(name, Vector2(120, 50), 22)
		b.pressed.connect(menu[name])
		hbox.add_child(b)


func _on_menu_move() -> void:
	_info_label.text = "请点击我方单位选择"


func _on_menu_attack() -> void:
	# 攻城占领：通知服务器结算占领
	NetClient.send(NetClient.C2S_WAR_ACTION, {"action": "occupy"})


func _on_menu_retreat() -> void:
	NetClient.send(NetClient.C2S_WAR_ACTION, {"action": "retreat"})


func _on_menu_end_turn() -> void:
	NetClient.send(NetClient.C2S_WAR_END_TURN, {})
