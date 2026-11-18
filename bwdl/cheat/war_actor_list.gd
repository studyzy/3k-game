extends Panel

class WarActorSorter extends Reference:

	func actor(a, b) -> bool:
		return a[3] < b[3]

	func desc_actor(a, b) -> bool:
		return a[3] > b[3]

	func hp(a, b) -> bool:
		return a[1].get_hp() > b[1].get_hp()

	func desc_hp(a, b) -> bool:
		return a[1].get_hp() < b[1].get_hp()

	func soldier(a, b) -> bool:
		return a[1].get_soldiers() > b[1].get_soldiers()

	func desc_soldier(a, b) -> bool:
		return a[1].get_soldiers() < b[1].get_soldiers()

	func ap(a, b) -> bool:
		if a[0] == null and b[0] == null:
			return actor(a, b)
		if a[0] == null:
			return false
		if b[0] == null:
			return true
		return a[0].action_point > b[0].action_point

	func desc_ap(a, b) -> bool:
		if a[0] == null and b[0] == null:
			return desc_actor(a, b)
		if a[0] == null:
			return true
		if b[0] == null:
			return false
		return a[0].action_point < b[0].action_point


export var pageSize: int = 5

onready var nav = $nav
onready var header = $header
onready var row = $row
onready var list = $list
onready var detail = $detail
onready var basics = $basics

var sorter = WarActorSorter.new()
onready var iconPos = preload("res://resource/images/ui/sorting_pos.png")
onready var iconNeg = preload("res://resource/images/ui/sorting_neg.png")


var keyword: String = ""

var page: int = 0

var sorting: String = ""

var wvId: int = - 1

signal saved

func _ready():
	init()
	return

func init() -> void :
	nav.get_node("page").connect("pager_changed", self, "pager_changed")
	nav.get_node("keyword").connect("keyword_changed", self, "search")
	sorting("actor")
	return

func reload_list(_keyword: String = "", _page: int = 0) -> void :
	row.hide()
	detail.hide()
	basics.hide()
	keyword = _keyword
	page = _page
	Global.clearNode(list)
	if wvId < 0:
		return
	var wf = DataManager.get_current_war_fight()
	if wf == null:
		return
	var wv = wf.get_war_vstate(wvId)
	if wv == null:
		return
	var records = []
	for wa in wv.get_war_actors(false):
		var actor = wa.actor()
		if keyword != "" and not keyword in actor.get_name():
			continue
		records.append([wa, actor, 0, records.size()])
	for actorId in wv.camp_actors:
		var actor = ActorHelper.actor(actorId)
		if keyword != "" and not keyword in actor.get_name():
			continue
		records.append([null, actor, 1, records.size()])
	for actorId in wv.capture_actors:
		var actor = ActorHelper.actor(actorId)
		if keyword != "" and not keyword in actor.get_name():
			continue
		records.append([null, actor, 2, records.size()])
	var maxPage = int((records.size() - 1) / pageSize)
	maxPage = max(0, maxPage)
	if page < 0:
		page = maxPage
	if page > maxPage:
		page = 0
	var method = sorting
	if method.begins_with("-"):
		method = method.replace("-", "desc_")
	if sorter.has_method(method):
		records.sort_custom(sorter, method)
	records = records.slice(page * pageSize, min(records.size() - 1, page * pageSize + pageSize - 1))
	for r in records:
		var row = create_row(r)
		row.show()
		var btn = row.get_node("operation/btn")
		Global.clear_signals(btn, ["pressed"])
		if r[0] != null:
			btn.connect("pressed", self, "modify", r)
			btn.disabled = false
		else:
			btn.disabled = true
		list.add_child(row)
	nav.get_node("page").text = str(page + 1)
	return

func create_row(record: Array) -> HBoxContainer:
	var wa = record[0]
	var actor = record[1]
	var status = record[2]
	var created = row.duplicate()
	var avatar = created.get_node("ac/avatar")
	Global.load_actor_avatar(actor.actorId, avatar, 1.5)
	created.get_node("name").text = actor.get_name()
	created.get_node("体").text = str(int(ceil(actor.get_hp())))
	created.get_node("士兵").text = str(actor.get_soldiers())
	created.get_node("机动力").text = "-" if wa == null else str(wa.action_point)
	var memo = "-"
	if status == 0 and wa != null:
		if wa.has_position():
			memo = "<{0},{1}>".format([wa.position.x, wa.position.y])
		else:
			memo = "未布阵"
	elif status == 1:
		memo = "营帐"
	elif status == 2:
		memo = "俘虏"
	created.get_node("状态").text = memo
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

func modify(wa: War_Actor, actor: ActorHelper.ActorInfo, status: int, id: int) -> void :
	basics.hide()
	detail.show()
	detail.reload_data(wvId, actor.actorId)
	return

func go_basics(_wvId: int, actorId: int):
	detail.hide()
	basics.reload_data(actorId)
	basics.show()
	return

func saved() -> void :
	emit_signal("saved")
	return

func reload() -> void :
	reload_list(keyword, page)
	return
