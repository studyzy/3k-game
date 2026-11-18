extends VBoxContainer

class ActorSorter extends Reference:

	func actor(a, b) -> bool:
		return a.actorId < b.actorId

	func desc_actor(a, b) -> bool:
		return a.actorId > b.actorId

	func hp(a, b) -> bool:
		return a.get_hp() > b.get_hp()

	func desc_hp(a, b) -> bool:
		return a.get_hp() < b.get_hp()

	func power(a, b) -> bool:
		var key = "武"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_power(a, b) -> bool:
		var key = "武"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)

	func wisdom(a, b) -> bool:
		var key = "知"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_wisdom(a, b) -> bool:
		var key = "知"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)

	func leadership(a, b) -> bool:
		var key = "统"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_leadership(a, b) -> bool:
		var key = "统"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)

	func politics(a, b) -> bool:
		var key = "政"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_politics(a, b) -> bool:
		var key = "政"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)

	func loyalty(a, b) -> bool:
		var key = "忠"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_loyalty(a, b) -> bool:
		var key = "忠"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)

	func guts(a, b) -> bool:
		var key = "胆"
		return a._get_attr_int_original(key) > b._get_attr_int_original(key)

	func desc_guts(a, b) -> bool:
		var key = "胆"
		return a._get_attr_int_original(key) < b._get_attr_int_original(key)


export var pageSize: int = 5

var nav
var header
var row
var list
var sorter
var iconPos
var iconNeg


var keyword: String = ""

var page: int = 0

var sorting: String = ""

var operation: String = "改"

var target: Object = null

var method: String = ""


var vstateId: int = - 1

var excepted: PoolIntArray = []

func _ready():
	init()
	return

func init() -> void :
	nav = get_node("nav")
	header = get_node("header")
	row = get_node("row")
	list = get_node("list")
	sorter = ActorSorter.new()
	iconPos = preload("res://resource/images/ui/sorting_pos.png")
	iconNeg = preload("res://resource/images/ui/sorting_neg.png")
	nav.get_node("page").connect("pager_changed", self, "pager_changed")
	nav.get_node("keyword").connect("keyword_changed", self, "search")
	sorting("actor")
	return

func reload_list(_keyword: String = "", _page: int = 0) -> void :
	keyword = _keyword
	page = _page
	var actors = []
	
	var expected = []
	if vstateId >= 0:
		for city in clCity.all_cities([vstateId]):
			expected.append_array(city.get_actor_ids())
	for actor in ActorHelper.search_actors(keyword):
		if expected.size() > 0 and not actor.actorId in expected:
			continue
		
		if actor.actorId in excepted:
			continue
		actors.append(actor)
	var maxPage = int((actors.size() - 1) / pageSize)
	maxPage = max(0, maxPage)
	if page < 0:
		page = maxPage
	if page > maxPage:
		page = 0
	var method = sorting
	if method.begins_with("-"):
		method = method.replace("-", "desc_")
	if sorter.has_method(method):
		actors.sort_custom(sorter, method)
	actors = actors.slice(page * pageSize, min(actors.size() - 1, page * pageSize + pageSize - 1))
	Global.clearNode(list)
	for actor in actors:
		var row = create_row(actor.actorId)
		row.show()
		list.add_child(row)
	rebind_operation()
	nav.get_node("page").text = str(page + 1)
	return

func create_row(actorId: int) -> HBoxContainer:
	var created = row.duplicate()
	var avatar = created.get_node("ac/avatar")
	var actor = ActorHelper.actor(actorId)
	Global.load_actor_avatar(actorId, avatar, 1.5)
	created.get_node("name").text = actor.get_name()
	for attr in ["体", "武", "知", "统", "政", "胆", "忠"]:
		created.get_node(attr).text = str(actor._get_attr_int_original(attr))
	created.get_node("operation/btn").editor_description = str(actor.actorId)
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

func bind_operation(_target: Object, _method: String, _operation: String = "改") -> void :
	target = _target
	method = _method
	operation = _operation
	rebind_operation()

func rebind_operation() -> void :
	if target == null:
		return
	for row in list.get_children():
		var btn = row.get_node_or_null("operation/btn")
		if btn == null:
			continue
		btn.text = operation
		Global.clear_signals(btn, ["pressed"])
		btn.connect("pressed", target, method, [int(btn.editor_description)])
	return

