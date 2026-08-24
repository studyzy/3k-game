extends Control
## 选择武将（对应 Unity UISelectGeneral）

var _general_ids: Array = []
var _selected: Dictionary = {}  # generalId -> bool
var _list_box: VBoxContainer
var _confirm_btn: Button
var _multi_select: bool = true


func _ready() -> void:
	_multi_select = GameInfo.task in [GameInfo.TaskType.MOVE, GameInfo.TaskType.ATTACK]
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.06)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UIFactory.make_label("选择武将", 40, Color(0.95, 0.85, 0.4))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-120, 20)
	title.size = Vector2(240, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_list_box = VBoxContainer.new()
	_list_box.position = Vector2(80, 90)
	_list_box.size = Vector2(520, 560)
	_list_box.add_theme_constant_override("separation", 8)
	add_child(_list_box)

	_confirm_btn = UIFactory.make_button("确 定", Vector2(180, 56), 24)
	_confirm_btn.position = Vector2(700, 640)
	_confirm_btn.pressed.connect(_on_confirm)
	add_child(_confirm_btn)

	var cancel := UIFactory.make_button("取 消", Vector2(180, 56), 24)
	cancel.position = Vector2(700, 720)
	cancel.pressed.connect(_on_cancel)
	add_child(cancel)

	_general_ids = GameInfo.optionalGeneralIds.duplicate()
	if _general_ids.is_empty():
		var city: City = CityListCache.get_city_by_city_id(GameInfo.doCityId)
		if city != null:
			_general_ids = city.get_officer_ids()
	_refresh_list()


func _refresh_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	_selected.clear()
	for gid in _general_ids:
		var g := GeneralListCache.get_general(gid)
		if g == null:
			continue
		var b := Button.new()
		b.text = "%s  Lv.%d  统%d 武%d 智%d 政%d 魅%d  兵%d  HP%d" % [
			g.generalName, g.level, g.lead, g.force, g.wisdom, g.govern, g.charm, g.soldiers, g.health]
		b.custom_minimum_size = Vector2(520, 40)
		b.add_theme_font_size_override("font_size", 18)
		b.toggle_mode = true
		b.button_group = ButtonGroup.new() if not _multi_select else null
		b.pressed.connect(_on_toggle.bind(gid))
		_list_box.add_child(b)
		_selected[gid] = false


func _on_toggle(gid: int) -> void:
	_selected[gid] = not _selected[gid]
	# 单选模式：取消其他
	if not _multi_select:
		for k in _selected.keys():
			if k != gid:
				_selected[k] = false


func _on_confirm() -> void:
	var chosen: Array = []
	for gid in _selected.keys():
		if _selected[gid]:
			chosen.append(gid)
	if chosen.is_empty():
		return
	GameInfo.doGeneralIds = chosen
	GameInfo.task = GameInfo.task
	SceneRouter.change_scene("res://scenes/ui/executive_panel.tscn")


func _on_cancel() -> void:
	if GameInfo.task == GameInfo.TaskType.MOVE or GameInfo.task == GameInfo.TaskType.ATTACK:
		GameInfo.task = GameInfo.TaskType.NONE
		SceneRouter.change_scene("res://scenes/ui/global_map.tscn")
		return
	SceneRouter.change_scene("res://scenes/ui/city_scene.tscn")
