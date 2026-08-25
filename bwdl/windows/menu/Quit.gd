# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/menu/Quit.gd
# 说明：退出面板 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

var buttonCursor = 0;

onready var gv = $main / gv

onready var menuButtons = [
	$main / gv / btnBackToGame, 
	$main / gv / btnKeySetting, 
	$main / gv / btnSaveGame, 
	$main / gv / btnSoundSetting, 
	$main / gv / btnLoadGame, 
	$main / gv / btnEndGame, 
	$main / gv / btnHelp, 
	$main / gv / btnOthers, 
]

onready var submenus = [
	$pnlControl, 
	$pnlSaveLoad, 
	$pnlSound, 
	$pnlQuestionHelp, 
	$pnlEnd, 
	$pnlOthers, 
]

onready var lblHeader = $main / lblHeader

func _ready() -> void :
	hide();
	get_tree().set_quit_on_go_back(false)
	for sub in submenus:
		sub.hide()
	return

func show_menu():
	if SceneManager.popuped:
		return

	SceneManager.VirtualKey.hide()
	if visible:
		return
	
	if DataManager.cloudVersion.has("version"):
		var latest = float(DataManager.cloudVersion["version"])
		if latest > float(DataManager.VERSION):
			lblHeader.text = "游戏已更新，可下载最新版： {0}".format([latest])
			lblHeader.set("custom_colors/font_color", Color(1, 1, 1))
			var st = StyleBoxFlat.new()
			st.bg_color = Color(0, 0, 0)
			lblHeader.add_stylebox_override("normal", st)

	$pnlSaveLoad.hide()

	buttonCursor = 0
	get_tree().paused = true
	SoundManager.pause(true)
	show()
	update_color()
	set_process(true)
	return

func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		show_menu()
	return


func _on_btnBackToGame_pressed() -> void :
	if SceneManager.popuped:
		return
	SceneManager.VirtualKey.show()
	for sub in submenus:
		sub.hide()
	hide()
	Input.action_release("EMU_B")
	get_tree().paused = false
	SoundManager.pause(false)
	return

func _process(delta: float) -> void :
	if not visible:
		set_process(false)
		return
	if SceneManager.popuped:
		return
	for sub in submenus:
		if sub.visible:
			return
	$main / gv / btnSaveGame.disabled = not DataManager.game_saving_enabled()
	if Input.is_action_just_pressed("ANALOG_UP"):
		move_up()
		update_color()
	if Input.is_action_just_pressed("ANALOG_DOWN"):
		move_down()
		update_color()
	if Input.is_action_just_pressed("ANALOG_LEFT"):
		move_left()
		update_color()
	if Input.is_action_just_pressed("ANALOG_RIGHT"):
		move_right()
		update_color()
	if Input.is_action_just_pressed("EMU_A"):
		Input.action_release("EMU_A")
		var btn: Button = menuButtons[buttonCursor]
		btn.emit_signal("pressed")
		return
	if Input.is_action_just_pressed("EMU_B"):
		_on_btnBackToGame_pressed()
		return
	return

func update_color():
	for i in menuButtons.size():
		var btn: Button = menuButtons[i]
		if i == buttonCursor:
			btn.self_modulate = Color("#00ff22")
		else:
			btn.self_modulate = Color("#ffffff")
	return


func _on_btnSaveGame_pressed() -> void :
	if not DataManager.game_saving_enabled():
		return
	$pnlSaveLoad.is_save = true
	$pnlSaveLoad.init_data(StaticManager.saveIdx.page)
	$pnlSaveLoad.show()
	return


func _on_btnLoadGame_pressed() -> void :
	$pnlSaveLoad.is_save = false
	$pnlSaveLoad.init_data(StaticManager.saveIdx.page)
	$pnlSaveLoad.show()
	return

func move_up():
	var y = buttonCursor / gv.columns
	var x = buttonCursor % gv.columns
	y -= 1
	if y < 0:
		buttonCursor = gv.get_child_count() - 1
		while true:
			var x1 = buttonCursor % gv.columns
			if x == x1:
				break
			buttonCursor -= 1
	else:
		buttonCursor = y * gv.columns + x
	return

func move_down():
	var y = buttonCursor / gv.columns
	var x = buttonCursor % gv.columns
	y += 1
	var newindex = y * gv.columns + x;
	if (newindex >= gv.get_child_count()):
		y = 0;
	buttonCursor = y * gv.columns + x
	return

func move_left():
	var y = buttonCursor / gv.columns
	var x = buttonCursor % gv.columns
	x -= 1
	if x < 0:
		x = gv.columns - 1
	buttonCursor = y * gv.columns + x
	while buttonCursor >= gv.get_child_count():
		x -= 1
		buttonCursor = y * gv.columns + x
	return

func move_right():
	var y = buttonCursor / gv.columns;
	var x = buttonCursor % gv.columns;
	x += 1
	if x >= gv.columns:
		x = 0
	buttonCursor = y * gv.columns + x
	if buttonCursor >= gv.get_child_count():
		buttonCursor = y * gv.columns
	return

func _on_btnKeySetting_pressed() -> void :
	$pnlControl.init_set()
	$pnlControl.show()
	return

func _on_btnSoundSetting_pressed() -> void :
	$pnlSound.init()
	$pnlSound.show()
	return

func _on_btnOthers_pressed() -> void :
	$pnlOthers.init()
	$pnlOthers.show()
	return

func _on_btnHelp_pressed() -> void :
	$pnlQuestionHelp.init()
	$pnlQuestionHelp.show()
	return

func _on_btnEndGame_pressed() -> void :
	$pnlEnd.init()
	$pnlEnd.show()
	return

func reset_layout_landscape() -> void :
	$black.rect_size = Vector2(1024, 600)
	$main.rect_position = Vector2(212, 0)
	$main.rect_scale = Vector2(1, 1)
	for sub in submenus:
		if sub.has_method("reset_layout_landscape"):
			sub.reset_layout_landscape()
	return

func reset_layout_portrait() -> void :
	$black.rect_size = Vector2(600, 960)
	$main.rect_position = Vector2(0, 180)
	$main.rect_scale = Vector2(1.7066, 1.6)
	for sub in submenus:
		if sub.has_method("reset_layout_portrait"):
			sub.reset_layout_portrait()
	return
