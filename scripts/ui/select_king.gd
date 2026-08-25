extends Control
## 选择君主（对应 Unity UIKing）

var _countries: Array = []
var _selected_index: int = -1
var _confirm_btn: Button
var _info_label: Label
var _portrait_rect: TextureRect
var _force_rect: TextureRect
var _list_box: VBoxContainer


func _ready() -> void:
	DataManager.ensure_loaded()
	_build_ui()
	_refresh_list()


func _build_ui() -> void:
	# 全屏背景（sanguo 迁移资源 bg2.jpg）
	add_child(UIFactory.make_bg("res://assets/bg/bg2.jpg"))

	var title := UIFactory.make_label("选择君主", 44, Color(0.95, 0.85, 0.4))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-150, 30)
	title.size = Vector2(300, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	_list_box = VBoxContainer.new()
	_list_box.position = Vector2(60, 120)
	_list_box.size = Vector2(420, 600)
	_list_box.add_theme_constant_override("separation", 12)
	add_child(_list_box)

	_info_label = UIFactory.make_label("请选择君主", 22, Color.WHITE)
	_info_label.position = Vector2(520, 430)
	_info_label.size = Vector2(400, 260)
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info_label)

	# 君主头像（高清立绘 360x512，等比缩放展示）
	_portrait_rect = TextureRect.new()
	_portrait_rect.position = Vector2(560, 60)
	_portrait_rect.size = Vector2(240, 342)
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_portrait_rect)

	# 势力图标（魏/蜀/吴，370x370 等比缩放）
	_force_rect = TextureRect.new()
	_force_rect.position = Vector2(820, 60)
	_force_rect.size = Vector2(150, 150)
	_force_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_force_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(_force_rect)

	_confirm_btn = UIFactory.make_button("确 定", Vector2(180, 60), 26)
	_confirm_btn.disabled = true
	_confirm_btn.position = Vector2(680, 700)
	_confirm_btn.pressed.connect(_on_confirm)
	add_child(_confirm_btn)

	var cancel := UIFactory.make_button("取 消", Vector2(180, 60), 26)
	cancel.position = Vector2(490, 700)
	cancel.pressed.connect(func(): SceneRouter.change_scene("res://scenes/main.tscn"))
	add_child(cancel)


func _refresh_list() -> void:
	for child in _list_box.get_children():
		child.queue_free()
	_countries = []
	for cid in CountryListCache.country_dictionary.keys():
		var c: Country = CountryListCache.country_dictionary[cid]
		if c.canBeChoose:
			_countries.append(c)
	for i in _countries.size():
		var c: Country = _countries[i]
		var king := GeneralListCache.get_general(c.countryKingId)
		var b := UIFactory.make_button("%s   %s" % [c.king_name(), "（" + str(king.generalName) + "）" if king != null else ""], Vector2(420, 56), 24)
		b.toggle_mode = true
		b.button_group = ButtonGroup.new()
		b.pressed.connect(_on_select.bind(i))
		_list_box.add_child(b)


func _on_select(index: int) -> void:
	_selected_index = index
	_confirm_btn.disabled = false
	var c: Country = _countries[index]
	var king := GeneralListCache.get_general(c.countryKingId)
	var city_num := c.get_have_city_num()
	var soldier_num := c.get_country_soldier_num()
	var weapon_name := "无"
	if king != null:
		var w := WeaponListCache.get_weapon(king.arm)
		if w != null:
			weapon_name = w.weaponName
		_portrait_rect.texture = GeneralListCache.get_portrait(king.generalId)
	else:
		_portrait_rect.texture = null
	# 势力图标（countryId → 魏/蜀/吴）
	var force_path := _force_icon_path(c.countryId)
	if force_path != "" and ResourceLoader.exists(force_path):
		_force_rect.texture = load(force_path) as Texture2D
	else:
		_force_rect.texture = null
	_info_label.text = "君主：%s\n\n统率：%d   武力：%d\n智谋：%d   政事：%d\n魅力：%d   等级：%d\n\n城池数：%d\n兵力：%d\n武器：%s" % [
		king.generalName if king != null else "?",
		king.lead if king != null else 0, king.force if king != null else 0,
		king.wisdom if king != null else 0, king.govern if king != null else 0,
		king.charm if king != null else 0, king.level if king != null else 1,
		city_num, soldier_num, weapon_name]


## 势力 ID → 势力图标路径（3 势力：1 魏 / 2 蜀 / 3 吴）。
func _force_icon_path(country_id: int) -> String:
	match country_id:
		1: return "res://assets/force/Wei.png"
		2: return "res://assets/force/Shu.png"
		3: return "res://assets/force/Wu.png"
		_: return ""


func _on_confirm() -> void:
	if _selected_index < 0:
		return
	var c: Country = _countries[_selected_index]
	# 通知服务器选择君主（服务器权威设置 playerCountryId / doCityId）
	NetClient.send(NetClient.C2S_SELECT_KING, {"countryId": c.countryId})
	# 等待服务器 SelectKing 响应后进入大地图
	_confirm_btn.disabled = true
	if not NetClient.server_push.is_connected(_on_select_king_result):
		NetClient.server_push.connect(_on_select_king_result)


func _on_select_king_result(op: int, body: Dictionary) -> void:
	if op != NetClient.S2C_DELTA:
		return
	# 服务器已确认，进入大地图
	NetClient.server_push.disconnect(_on_select_king_result)
	SceneRouter.change_scene("res://scenes/ui/global_map.tscn")
