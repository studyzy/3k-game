extends VBoxContainer

class VstateSorter extends Reference:

	func vstate(a, b) -> bool:
		return a.id < b.id

	func desc_vstate(a, b) -> bool:
		return a.id > b.id

	func capital(a, b) -> bool:
		var ca = clCity.get_capital_city(a.id)
		var cb = clCity.get_capital_city(b.id)
		if ca == null:
			return false
		if cb == null:
			return true
		return ca.ID < cb.ID

	func desc_capital(a, b) -> bool:
		var ca = clCity.get_capital_city(a.id)
		var cb = clCity.get_capital_city(b.id)
		if ca == null:
			return true
		if cb == null:
			return false
		return ca.ID > cb.ID

	func cities(a, b) -> bool:
		var ca = clCity.all_cities([a.id]).size()
		var cb = clCity.all_cities([b.id]).size()
		return ca > cb

	func desc_cities(a, b) -> bool:
		var ca = clCity.all_cities([a.id]).size()
		var cb = clCity.all_cities([b.id]).size()
		return ca < cb

	func actors(a, b) -> bool:
		var aa = 0
		for city in clCity.all_cities([a.id]):
			aa += city.get_actor_ids().size()
		var ab = 0
		for city in clCity.all_cities([b.id]):
			ab += city.get_actor_ids().size()
		return aa > ab

	func desc_actors(a, b) -> bool:
		var aa = 0
		for city in clCity.all_cities([a.id]):
			aa += city.get_actor_ids().size()
		var ab = 0
		for city in clCity.all_cities([b.id]):
			ab += city.get_actor_ids().size()
		return aa < ab

onready var nav = get_node("nav")
onready var header = get_node("header")
onready var row = get_node("row")
onready var list = get_node("list")
onready var sorter = VstateSorter.new()
onready var iconPos = preload("res://resource/images/ui/sorting_pos.png")
onready var iconNeg = preload("res://resource/images/ui/sorting_neg.png")

export var pageSize: int = 5

export var expected: PoolIntArray = []

export var excepted: PoolIntArray = []


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
	sorting("vstate")
	return

func reload_list(_keyword: String = "", _page: int = 0) -> void :
	keyword = _keyword
	page = _page
	var vstates = []
	for vs in clVState.search_vstates(keyword):
		if expected.size() > 0 and not vs.id in expected:
			continue
		if vs.id in excepted:
			continue
		vstates.append(vs)
	var maxPage = int((vstates.size() - 1) / pageSize)
	maxPage = max(0, maxPage)
	if page < 0:
		page = maxPage
	if page > maxPage:
		page = 0
	var method = sorting
	if method.begins_with("-"):
		method = method.replace("-", "desc_")
	if sorter.has_method(method):
		vstates.sort_custom(sorter, method)
	vstates = vstates.slice(page * pageSize, min(vstates.size() - 1, page * pageSize + pageSize - 1))
	Global.clearNode(list)
	for vs in vstates:
		var row = create_row(vs.id)
		row.show()
		list.add_child(row)
	rebind_operation()
	nav.get_node("page").text = str(page + 1)
	return

func create_row(vstateId: int) -> HBoxContainer:
	var created = row.duplicate()
	var vs = clVState.vstate(vstateId)
	var icon = created.get_node("icon")
	var colors = vs.get_color()
	icon.border_color = Color(colors[0])
	icon.fill_color = Color(colors[1])
	created.get_node("lord").text = vs.get_lord_name()
	var capital = clCity.get_capital_city(vs.id)
	if capital == null:
		created.get_node("capital").text = "-"
	else:
		created.get_node("capital").text = capital.get_name()
	var cities = 0
	var actors = 0
	for city in clCity.all_cities([vs.id]):
		cities += 1
		actors += city.get_actor_ids().size()
	var allied = 0
	for v in clVState.all_vstates():
		if v.id == vs.id:
			continue
		if DataManager.is_alliance(v.id, vs.id):
			allied += 1
	created.get_node("allied").text = str(allied)
	created.get_node("cities").text = str(cities)
	created.get_node("actors").text = str(actors)
	created.get_node("operation/btn").editor_description = str(vs.id)
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
