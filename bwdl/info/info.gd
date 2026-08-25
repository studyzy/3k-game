# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/info.gd
# 说明：信息面板-总入口。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

onready var wd = get_node("wd")
onready var tc = get_node("wd/tc")

func _ready():
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
	SceneManager.info_finished()
	return

func tab_changed(tabIdx: int):
	var tabs = tc.get_children()
	if tabIdx < 0 or tabIdx >= tabs.size():
		return
	var tab = tabs[tabIdx]
	if tab.name == "关闭":
		wd.hide()
		return
	if tab.has_method("reload_list"):
		tab.call("reload_list")
	return

func reset_layout_landscape() -> void :
	wd.rect_min_size = Vector2(910, 500)
	wd.rect_size = rect_min_size
	tc.rect_scale = Vector2(1, 1)
	tc.rect_min_size = Vector2(910, 500)
	tc.rect_position = Vector2.ZERO
	for cld in $wd / tc.get_children():
		if cld.has_method("reset_layout_landscape"):
			cld.reset_layout_landscape()
	return

func reset_layout_portrait() -> void :
	wd.rect_min_size = Vector2(1020, 1200)
	wd.rect_size = rect_min_size
	tc.rect_scale = Vector2(1.1, 1.1)
	tc.rect_min_size = Vector2(910, 1000)
	tc.rect_position = Vector2.ZERO
	for cld in $wd / tc.get_children():
		if cld.has_method("reset_layout_portrait"):
			cld.reset_layout_portrait()
	return

