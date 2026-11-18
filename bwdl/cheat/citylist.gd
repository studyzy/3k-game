extends VBoxContainer

class CitySorter extends Reference:

	func city(a, b) -> bool:
		return a.ID < b.ID

	func desc_city(a, b) -> bool:
		return a.ID > b.ID

	func vstate(a, b) -> bool:
		var va = a.get_vstate_id()
		var vb = b.get_vstate_id()
		if va == - 1 and vb == - 1:
			return city(a, b)
		elif va == - 1:
			return false
		elif vb == - 1:
			return true
		return va < vb

	func desc_vstate(a, b) -> bool:
		var va = a.get_vstate_id()
		var vb = b.get_vstate_id()
		if va == - 1 and vb == - 1:
			return city(a, b)
		elif va == - 1:
			return true
		elif vb == - 1:
			return false
		return va > vb

	func gold(a, b) -> bool:
		return a.get_gold() > b.get_gold()

	func desc_gold(a, b) -> bool:
		return a.get_gold() < b.get_gold()

	func rice(a, b) -> bool:
		return a.get_rice() > b.get_rice()

	func desc_rice(a, b) -> bool:
		return a.get_rice() < b.get_rice()

	func land(a, b) -> bool:
		return a.get_land() > b.get_land()

	func desc_land(a, b) -> bool:
		return a.get_land() < b.get_land()

	func eco(a, b) -> bool:
		return a.get_eco() > b.get_eco()

	func desc_eco(a, b) -> bool:
		return a.get_eco() < b.get_eco()

onready var nav = get_node("nav")
onready var header = get_node("header")
onready var row = get_node("row")
onready var list = get_node("list")
onready var sorter = CitySorter.new()
onready var iconPos = preload("res://resource/images/ui/sorting_pos.png")
onready var iconNeg = preload("res://resource/images/ui/sorting_neg.png")

export var pageSize = 5

export var expected: PoolIntArray = []


var keyword: String = ""

var page: int = 0

var sorting: String = ""

var operations: PoolStringArray = ["修改"]

var conditioner: String

var target: Object = null

var method: String = ""

func _ready():
	nav.get_node("page").connect("pager_changed", self, "pager_changed")
	nav.get_node("keyword").connect("keyword_changed", self, "search")
	sorting("city")
	return

func reload_list(_keyword: String = "", _page: int = 0) -> void :
	keyword = _keyword
	page = _page
	var cities = []
	for city in clCity.search_cities(keyword):
		if expected.size() > 0 and not city.ID in expected:
			continue
		cities.append(city)
	var maxPage = int((cities.size() - 1) / pageSize)
	maxPage = max(0, maxPage)
	if page < 0:
		page = maxPage
	if page > maxPage:
		page = 0
	var method = sorting
	if method.begins_with("-"):
		method = method.replace("-", "desc_")
	if sorter.has_method(method):
		cities.sort_custom(sorter, method)
	cities = cities.slice(page * pageSize, min(cities.size() - 1, page * pageSize + pageSize - 1))
	Global.clearNode(list)
	for city in cities:
		var row = create_row(city.ID)
		row.show()
		list.add_child(row)
	rebind_operation()
	nav.get_node("page").text = str(page + 1)
	return

func create_row(cityId: int) -> HBoxContainer:
	var created = row.duplicate()
	var city = clCity.city(cityId)
	created.get_node("name").text = city.get_name()
	created.get_node("lord").text = city.get_lord_name()
	for attr in ["金", "米", "土地", "产业"]:
		created.get_node(attr).text = str(city.get_property(attr))
	created.get_node("operation/btn").editor_description = str(city.ID)
	return created

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

func bind_operation(_target: Object, _method: String, _operations: PoolStringArray = ["修改"], _conditioner: String = "") -> void :
	target = _target
	method = _method
	operations = _operations
	conditioner = _conditioner
	rebind_operation()
	return

func rebind_operation() -> void :
	for row in list.get_children():
		var btn = row.get_node_or_null("operation/btn")
		if btn == null:
			continue
		if target == null:
			btn.hide()
			continue
		Global.clear_signals(btn, ["pressed"])
		var id = int(btn.editor_description)
		if conditioner == "":
			btn.text = operations[0]
			btn.connect("pressed", target, method, [id])
		else:
			var formula = conditioner.replace("<ID>", str(id))
			var idx = int(Global.count_formula_number(formula))
			btn.text = operations[idx]
			btn.connect("pressed", target, method, [id, idx])
		btn.show()
	return
