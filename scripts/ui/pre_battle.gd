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

	# 参战双方（从服务器 Mirror.war 取交战单位）
	var war: Dictionary = Mirror.war
	var hm: Array = war.get("hmUnits", [])
	var ai: Array = war.get("aiUnits", [])
	var info := UIFactory.make_label("", 24, Color.WHITE)
	info.position = Vector2(150, 100)
	info.size = Vector2(700, 120)
	add_child(info)
	var p_name := "我方"
	var e_name := "敌方"
	if not hm.is_empty():
		p_name = "武将ID %d" % int(hm[0].get("genID", 0))
	if not ai.is_empty():
		e_name = "武将ID %d" % int(ai[0].get("genID", 0))
	info.text = "我方：%s\n敌方：%s" % [p_name, e_name]

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
	var battle_info := UIFactory.make_label("选择阵型后点击手动或自动战斗", 20, Color.WHITE)
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


func _on_manual() -> void:
	if _resolved:
		return
	_resolved = true
	# 通知服务器进入手动战斗（返回 S2C_BattleStart）
	NetClient.send(NetClient.C2S_BATTLE_SELECT, {"formationIndex": _formation_index, "mode": "manual"})
	if not NetClient.server_push.is_connected(_on_battle_select_result):
		NetClient.server_push.connect(_on_battle_select_result)


func _on_fight() -> void:
	if _resolved:
		return
	_resolved = true
	# 自动战斗：服务器模拟并返回结果
	NetClient.send(NetClient.C2S_BATTLE_SELECT, {"formationIndex": _formation_index, "mode": "auto"})
	if not NetClient.server_push.is_connected(_on_battle_result):
		NetClient.server_push.connect(_on_battle_result)


func _on_battle_select_result(op: int, _body: Dictionary) -> void:
	if op != NetClient.S2C_BATTLE_START:
		return
	NetClient.server_push.disconnect(_on_battle_select_result)
	SceneRouter.change_scene("res://scenes/ui/battle_scene.tscn")


func _on_battle_result(op: int, body: Dictionary) -> void:
	if op != NetClient.S2C_BATTLE_RESULT:
		return
	NetClient.server_push.disconnect(_on_battle_result)
	SceneRouter.change_scene("res://scenes/ui/war_scene.tscn")


func _on_retreat() -> void:
	SceneRouter.change_scene("res://scenes/ui/war_scene.tscn")
