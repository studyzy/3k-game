# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/basiclist.gd
# 说明：信息面板-基础列表。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Panel


export var pageSize: int = 6

onready var nav = get_node("nav")
onready var header = get_node("header")
onready var row = get_node("row")
onready var list = get_node("list")
onready var iconPos = preload("res://resource/images/ui/sorting_pos.png")
onready var iconNeg = preload("res://resource/images/ui/sorting_neg.png")
onready var detail = get_node("detail")

var sorter


var keyword: String = ""

var page: int = 0

var sorting: String = "id"

var allItems: Array = []

func _ready():
	nav.get_node("page").connect("pager_changed", self, "pager_changed")
	nav.get_node("keyword").connect("keyword_changed", self, "search")
	init()
	SceneManager.VirtualKey.connect("IGNORED_INPUT", self, "ignored_input")
	return

func init() -> void :
	return

func reload_list(_keyword: String = "", _page: int = 0) -> void :
	detail.hide()
	keyword = _keyword
	page = _page
	allItems = reload_data()
	var total = allItems.size()
	var maxPage = int((total - 1) / pageSize)
	maxPage = max(0, maxPage)
	if page < 0:
		page = maxPage
	if page > maxPage:
		page = 0
	var method = sorting
	if method.begins_with("-"):
		method = method.replace("-", "desc_")
	if sorter != null and sorter.has_method(method):
		allItems.sort_custom(sorter, method)
	var items = allItems.slice(page * pageSize, min(total - 1, page * pageSize + pageSize - 1))
	var idList = []
	for item in allItems:
		idList.append(item.id)
	Global.clearNode(list)
	var thisPage = items.size()
	for i in thisPage:
		var item = items[i]
		var row = create_row(item, idList)
		if row == null:
			break
		row.show()
		list.add_child(row)
	nav.get_node("page").text = str(page + 1)
	return

func reload_data() -> Array:
	return []

func create_row(item: Object, idList: PoolIntArray) -> HBoxContainer:
	return null

func search():
	var _keyword = nav.get_node("keyword").text
	reload_list(_keyword)
	return

func page_first():
	reload_list(keyword, 0)
	return

func page_last():
	reload_list(keyword, - 1)
	return

func page_prev():
	reload_list(keyword, page - 1)
	return

func page_next():
	reload_list(keyword, page + 1)
	return

func pager_changed():
	reload_list(keyword, int(nav.get_node("page").text) - 1)
	return

func sorting(_sorting: String):
	if sorting == _sorting:
		sorting = "-" + _sorting
	else:
		sorting = _sorting
	for btn in header.get_children():
		if not btn is Button:
			continue
		btn.icon = null
		if btn.editor_description == sorting:
			btn.icon = iconPos
		elif "-" + btn.editor_description == sorting:
			btn.icon = iconNeg
	reload_list(keyword, page)
	return

func detail(id: int, idList: PoolIntArray) -> void :
	nav.hide()
	header.hide()
	list.hide()
	detail.id = id
	detail.idList = idList
	detail.reload()
	detail.show()
	Global.clear_signals(detail, ["hide"])
	detail.connect("hide", self, "detail_hide")
	return

func detail_hide() -> void :
	nav.show()
	header.show()
	list.show()
	return

func ignored_input(action: String, pressed: bool) -> void :
	if not visible:
		return
	if pressed:
		return

	var focused = get_focus_owner()
	if focused != null and (focused is LineEdit or focused is TextEdit):
		return

	if detail.visible:
		match action:
			"ANALOG_LEFT":
				detail.nav_prev()
			"ANALOG_RIGHT":
				detail.nav_next()
			"EMU_B":
				detail.close()
		return
	if list.visible:
		match action:
			"ANALOG_LEFT":
				page_prev()
			"ANALOG_RIGHT":
				page_next()
		return
	return
