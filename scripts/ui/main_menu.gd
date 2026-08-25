extends Control
## 主菜单（对应 Unity UIStart）

const CHAPTERS_PATH := "res://data/ChapterData.json"

var _chapter_panel: Panel
var _chapter_list: VBoxContainer
var _difficulty_panel: Panel
var _load_panel: Panel
var _chapters: Array = []


func _ready() -> void:
	_chapters = DataManager.load_json_list(CHAPTERS_PATH)
	SoundManager.play_bgm("1")
	_build_ui()
	# 启动时自动登录并创建新局（服务器权威状态）
	NetClient.login("p1")


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.06, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := UIFactory.make_label("霸王的大陆", 72, Color(0.95, 0.85, 0.4))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-200, 70)
	title.size = Vector2(400, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var menu := VBoxContainer.new()
	menu.set_anchors_preset(Control.PRESET_CENTER)
	menu.position = Vector2(-150, -180)
	menu.size = Vector2(300, 420)
	menu.add_theme_constant_override("separation", 16)
	add_child(menu)

	var start_btn := UIFactory.make_button("开 创 霸 业", Vector2(300, 62), 28)
	start_btn.pressed.connect(_on_start_pressed)
	menu.add_child(start_btn)

	var load_btn := UIFactory.make_button("再 续 征 程", Vector2(300, 62), 28)
	load_btn.pressed.connect(_on_load_pressed)
	menu.add_child(load_btn)

	var build_btn := UIFactory.make_button("自 建 武 将", Vector2(300, 62), 28)
	build_btn.pressed.connect(_on_self_build_pressed)
	menu.add_child(build_btn)

	var info_btn := UIFactory.make_button("游 戏 说 明", Vector2(300, 62), 28)
	info_btn.pressed.connect(_on_info_pressed)
	menu.add_child(info_btn)

	var setting_btn := UIFactory.make_button("设 置", Vector2(300, 62), 28)
	setting_btn.pressed.connect(_on_setting_pressed)
	menu.add_child(setting_btn)

	var exit_btn := UIFactory.make_button("退 出 游 戏", Vector2(300, 62), 28)
	exit_btn.pressed.connect(_on_exit_pressed)
	menu.add_child(exit_btn)

	# 章节选择面板
	_chapter_panel = Panel.new()
	_chapter_panel.visible = false
	_chapter_panel.set_anchors_preset(Control.PRESET_CENTER)
	_chapter_panel.position = Vector2(-250, -150)
	_chapter_panel.size = Vector2(500, 320)
	add_child(_chapter_panel)
	UIFactory.add_label(_chapter_panel, "选择剧本", Vector2(150, 20), 30)
	_chapter_list = VBoxContainer.new()
	_chapter_list.position = Vector2(100, 70)
	_chapter_list.size = Vector2(300, 200)
	_chapter_list.add_theme_constant_override("separation", 10)
	_chapter_panel.add_child(_chapter_list)


func _on_start_pressed() -> void:
	for child in _chapter_list.get_children():
		child.queue_free()
	for ch in _chapters:
		var b := UIFactory.make_button(str(ch.get("title", "")), Vector2(300, 52), 24)
		b.pressed.connect(_on_chapter_pressed.bind(ch))
		_chapter_list.add_child(b)
	_chapter_panel.visible = true


func _on_chapter_pressed(chapter: Dictionary) -> void:
	GameInfo.chapter = str(chapter.get("title", ""))
	_chapter_panel.visible = false
	DataManager.load_all_configs()
	_show_difficulty()


func _show_difficulty() -> void:
	if _difficulty_panel == null:
		_difficulty_panel = Panel.new()
		_difficulty_panel.set_anchors_preset(Control.PRESET_CENTER)
		_difficulty_panel.position = Vector2(-250, -150)
		_difficulty_panel.size = Vector2(500, 320)
		add_child(_difficulty_panel)
		UIFactory.add_label(_difficulty_panel, "选择难度", Vector2(150, 20), 30)
		var box := VBoxContainer.new()
		box.position = Vector2(100, 70)
		box.size = Vector2(300, 200)
		box.add_theme_constant_override("separation", 12)
		_difficulty_panel.add_child(box)
		var names := ["初 级", "中 级", "超 级"]
		for i in 3:
			var b := UIFactory.make_button(names[i], Vector2(300, 52), 24)
			b.pressed.connect(_on_difficulty_pressed.bind(i + 1))
			box.add_child(b)
	_difficulty_panel.visible = true


func _on_difficulty_pressed(difficulty: int) -> void:
	GameInfo.difficult = difficulty
	_difficulty_panel.visible = false
	SceneRouter.change_scene("res://scenes/ui/select_king.tscn")


func _on_load_pressed() -> void:
	DataManager.get_record_info()
	if _load_panel != null:
		_load_panel.queue_free()
	_load_panel = Panel.new()
	_load_panel.set_anchors_preset(Control.PRESET_CENTER)
	_load_panel.position = Vector2(-250, -200)
	_load_panel.size = Vector2(500, 420)
	add_child(_load_panel)
	UIFactory.add_label(_load_panel, "读取存档", Vector2(150, 15), 30)
	var box := VBoxContainer.new()
	box.position = Vector2(60, 60)
	box.size = Vector2(380, 300)
	box.add_theme_constant_override("separation", 10)
	_load_panel.add_child(box)
	for i in 4:
		var info: String = GameInfo.recordInfo[i]
		var b := UIFactory.make_button(info, Vector2(380, 54), 22)
		var idx := i
		b.disabled = info == "尚无存档"
		b.pressed.connect(_on_load_slot.bind(idx))
		box.add_child(b)
	var cancel := UIFactory.make_button("取消", Vector2(120, 44), 22)
	cancel.pressed.connect(func(): _load_panel.queue_free())
	_load_panel.add_child(cancel)
	cancel.position = Vector2(190, 360)


func _on_load_slot(index: int) -> void:
	DataManager.load_game(index)
	SceneRouter.change_scene("res://scenes/ui/city_scene.tscn")


func _on_self_build_pressed() -> void:
	DataManager.read_custom_general_list()
	SceneRouter.change_scene("res://scenes/ui/self_build.tscn")


func _show_tip(text: String) -> void:
	var tip := UIFactory.make_label(text, 24, Color.YELLOW)
	tip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tip.position = Vector2(-300, -120)
	tip.size = Vector2(600, 40)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tip)


func _on_info_pressed() -> void:
	var file := FileAccess.open("res://data/readMe.txt", FileAccess.READ)
	var text := file.get_as_text() if file != null else "暂无说明"
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-400, -250)
	panel.size = Vector2(800, 500)
	add_child(panel)
	UIFactory.add_label(panel, "游戏说明", Vector2(300, 10), 30)
	var text_label := Label.new()
	text_label.text = text
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.position = Vector2(20, 60)
	text_label.size = Vector2(760, 380)
	panel.add_child(text_label)
	var close := UIFactory.make_button("关闭", Vector2(120, 44), 22)
	close.pressed.connect(func(): panel.queue_free())
	panel.add_child(close)
	close.position = Vector2(340, 440)


func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_setting_pressed() -> void:
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-250, -150)
	panel.size = Vector2(500, 300)
	add_child(panel)
	UIFactory.add_label(panel, "设置", Vector2(180, 15), 30)
	UIFactory.add_label(panel, "音乐音量", Vector2(50, 80), 22)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = SoundManager.bgm_volume
	slider.position = Vector2(180, 85)
	slider.size = Vector2(260, 30)
	slider.value_changed.connect(func(v):
		SoundManager.set_bgm_volume(v))
	panel.add_child(slider)
	var close := UIFactory.make_button("关 闭", Vector2(140, 46), 22)
	close.position = Vector2(180, 220)
	close.pressed.connect(func(): panel.queue_free())
	panel.add_child(close)
