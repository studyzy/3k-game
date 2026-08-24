extends Control
## 自建武将（对应 Unity UISelfBuild）

var _general: General
var _name_edit: LineEdit
var _info_label: Label


func _ready() -> void:
	DataManager.ensure_loaded()
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.08, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UIFactory.make_label("自建武将", 40, Color(0.95, 0.85, 0.4))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-100, 20)
	title.size = Vector2(200, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	UIFactory.add_label(self, "姓名：", Vector2(200, 120), 24)
	_name_edit = LineEdit.new()
	_name_edit.position = Vector2(280, 120)
	_name_edit.size = Vector2(240, 40)
	add_child(_name_edit)

	_info_label = UIFactory.make_label("", 22, Color.WHITE)
	_info_label.position = Vector2(200, 200)
	_info_label.size = Vector2(400, 300)
	add_child(_info_label)

	_random_general()

	var reroll := UIFactory.make_button("重新随机", Vector2(160, 56), 22)
	reroll.position = Vector2(180, 560)
	reroll.pressed.connect(_random_general)
	add_child(reroll)

	var build := UIFactory.make_button("创 建", Vector2(160, 56), 24)
	build.position = Vector2(380, 560)
	build.pressed.connect(_on_build)
	add_child(build)

	var back := UIFactory.make_button("返 回", Vector2(160, 56), 24)
	back.position = Vector2(580, 560)
	back.pressed.connect(func(): SceneRouter.change_scene("res://scenes/main.tscn"))
	add_child(back)


func _random_general() -> void:
	var g := General.new()
	g.generalId = 10000 + randi_range(0, 999)
	g.generalName = "自建武将"
	g.level = 1
	g.health = 100
	g.maxHealth = 100
	g.loyalty = 99
	g.debutYear = GameInfo.years
	g.debutCity = 1
	g.arm = 1
	g.armor = 1
	g.soldiers = 1000
	g.lead = _gaussian(60, 30)
	g.govern = _gaussian(60, 30)
	g.force = _gaussian(60, 30)
	g.wisdom = _gaussian(60, 30)
	g.charm = _gaussian(60, 30)
	g.phase = randi_range(0, 149)
	g.army = [randi_range(0, 3), randi_range(0, 3), randi_range(0, 3)]
	g.skills = _random_skills()
	_general = g
	_refresh()


func _gaussian(mean: int, std: int) -> int:
	var v := (randf() + randf() + randf() + randf() + randf() + randf() - 3.0) / 3.0 * std + mean
	return clampi(int(v), 10, 90)


func _random_skills() -> Array:
	var skills := [0, 0, 0, 0, 0]
	# 随机给 2-4 个技能
	var count := randi_range(2, 4)
	for i in count:
		var kind := randi_range(0, 4)
		var index := randi_range(1, 10)
		skills[kind] |= 1 << (10 - index)
	return skills


func _refresh() -> void:
	var army_s := _general.get_army_s()
	_info_label.text = "%s\n\n统率：%d   武力：%d\n智谋：%d   政事：%d\n魅力：%d\n相性：%d    适性：%s\n\n特技：%s" % [
		_general.generalName, _general.lead, _general.force, _general.wisdom,
		_general.govern, _general.charm, _general.phase, army_s,
		_general.get_active_skills()]


func _on_build() -> void:
	if _name_edit.text.is_empty():
		_show_tip("请输入姓名")
		return
	_general.generalName = _name_edit.text
	DataManager.add_custom_general(_general)
	_show_tip("自建武将 %s 创建成功！" % _general.generalName)
	get_tree().create_timer(1.5).timeout.connect(func(): SceneRouter.change_scene("res://scenes/main.tscn"))


func _show_tip(text: String) -> void:
	var tip := UIFactory.make_label(text, 22, Color.YELLOW)
	tip.position = Vector2(200, 620)
	tip.size = Vector2(400, 40)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tip)
