# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：cheat/cheater.gd
# 说明：作弊面板-总入口。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control
	
onready var wd = get_node("wd")
onready var tc = get_node("wd/tc")

onready var warTab = get_node("wd/tc/　大战场　")
onready var battleTab = get_node("wd/tc/　小战场　")
onready var soloTab = get_node("wd/tc/　单挑　")

func _ready():
	tc.set_tab_hidden(1, true)
	tc.set_tab_hidden(2, true)
	tc.set_tab_hidden(3, true)
	match DataManager.get_current_scene_id():
		20000:
			tc.set_tab_hidden(1, false)
		30000:
			tc.set_tab_hidden(2, false)
		40000:
			tc.set_tab_hidden(3, false)
	tc.current_tab = 0
	return

func _notification(what):
	if what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		wd.hide()
	return

func _input(event):
	
	if event is InputEventKey:
		if event.scancode == KEY_ESCAPE and event.pressed:
			wd.hide()
	return

func start() -> void :
	if SceneManager.portrait_mode:
		reset_layout_portrait()
	else:
		reset_layout_landscape()
	wd.set_as_toplevel(true)
	wd.popup_centered()
	return

func closing() -> void :
	SceneManager.cheater_finished()
	return

func tab_changed(tab: int):
	if tab == 4:
		wd.hide()
	return

func reset_layout_landscape() -> void :
	wd.rect_min_size = Vector2(800, 500)
	wd.rect_size = rect_min_size
	tc.rect_scale = Vector2(1, 1)
	tc.rect_min_size = Vector2(800, 474)
	tc.rect_position = Vector2.ZERO
	for cld in $wd / tc.get_children():
		if cld.has_method("reset_layout_landscape"):
			cld.reset_layout_landscape()
	return

func reset_layout_portrait() -> void :
	wd.rect_min_size = Vector2(980, 1080)
	wd.rect_size = rect_min_size
	tc.rect_scale = Vector2(1.2, 1.2)
	tc.rect_min_size = Vector2(800, 474)
	tc.rect_position = Vector2.ZERO
	for cld in $wd / tc.get_children():
		if cld.has_method("reset_layout_portrait"):
			cld.reset_layout_portrait()
	return

