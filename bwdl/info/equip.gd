# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/equip.gd
# 说明：信息面板-装备。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends HBoxContainer

const MODES = ["武器", "防具", "道具", "坐骑"]

onready var menu = get_node("menu")
onready var content = get_node("content")
onready var weaponlist = get_node("content/weaponlist")
onready var suitlist = get_node("content/suitlist")
onready var jewelrylist = get_node("content/jewelrylist")
onready var steedlist = get_node("content/steedlist")

var mode: String = ""

func _ready():
	switch_mode("武器")
	back_to_list()
	SceneManager.VirtualKey.connect("IGNORED_INPUT", self, "ignored_input")
	return

func reset_panel(pnl: Panel) -> void :
	if pnl == null:
		return
	for child in pnl.get_children():
		child.hide()
	return

func switch_mode(_mode: String = "") -> void :
	mode = ""
	for m in MODES:
		menu.get_node(m).disabled = false
	if _mode in MODES:
		mode = _mode
		menu.get_node(mode).disabled = true
	back_to_list()
	return

func weapon_list() -> void :
	reset_panel(content)
	weaponlist.reload_list()
	weaponlist.show()
	return

func suit_list() -> void :
	reset_panel(content)
	suitlist.reload_list()
	suitlist.show()
	return

func jewelry_list() -> void :
	reset_panel(content)
	jewelrylist.reload_list()
	jewelrylist.show()
	return

func steed_list() -> void :
	reset_panel(content)
	steedlist.reload_list()
	steedlist.show()
	return

func back_to_list():
	match mode:
		"武器":
			weapon_list()
		"防具":
			suit_list()
		"道具":
			jewelry_list()
		"坐骑":
			steed_list()
	return

func reset_layout_landscape() -> void :
	for lst in [weaponlist, suitlist, jewelrylist, steedlist]:
		lst.pageSize = 6
		lst.detail.rect_position = Vector2(0, 0)
	back_to_list()
	return

func reset_layout_portrait() -> void :
	for lst in [weaponlist, suitlist, jewelrylist, steedlist]:
		lst.pageSize = 15
		lst.detail.rect_position = Vector2(0, 80)
	back_to_list()
	return

func ignored_input(action: String, pressed: bool) -> void :
	if not visible:
		return
	if pressed:
		return

	var focused = get_focus_owner()
	if focused != null and (focused is LineEdit or focused is TextEdit):
		return

	match action:
		"ANALOG_UP":
			var modeIdx = MODES.find(mode)
			if modeIdx < 0:
				modeIdx = MODES.size() - 1
			else:
				modeIdx = (modeIdx + MODES.size() - 1) % MODES.size()
			switch_mode(MODES[modeIdx])
			return
		"ANALOG_DOWN":
			var modeIdx = MODES.find(mode)
			if modeIdx < 0:
				modeIdx = 0
			else:
				modeIdx = (modeIdx + 1) % MODES.size()
			switch_mode(MODES[modeIdx])
			return
	return
