extends HBoxContainer

const CATEGORIES = {
	"人物": "people", 
	"地理": "geography", 
	"事件": "events", 
	"其他": "context"
}
const CATEGORY_ORDER = ["人物", "地理", "事件", "其他"]
const PAGE_SIZE_LANDSCAPE = 15
const PAGE_SIZE_PORTRAIT = 25
const SCROLL_STEP = 60
const MAX_HISTORY = 10

onready var menu = $menu
onready var content = $content
onready var list_panel = $content / list_panel
onready var detail_panel = $content / detail_panel
onready var nav = $content / list_panel / nav
onready var list = $content / list_panel / scroll / list
onready var breadcrumb = $content / detail_panel / nav / breadcrumb
onready var detail_content = $content / detail_panel / scroll / content
onready var detail_scroll = $content / detail_panel / scroll

var index: Array = []
var current_cat: String = "people"
var current_items: Array = []
var current_page: int = 0
var keyword: String = ""
var page_size: int = PAGE_SIZE_LANDSCAPE


var history: Array = []
var current_entry: Dictionary = {}
var _drag_start_y: int = 0
var _dragging: bool = false

func _ready():
	load_index()
	switch_category("人物")
	detail_content.connect("meta_clicked", self, "_on_content_meta_clicked")
	breadcrumb.connect("meta_clicked", self, "_on_breadcrumb_meta_clicked")
	SceneManager.VirtualKey.connect("IGNORED_INPUT", self, "ignored_input")
	return

func load_index():
	var f = File.new()
	var path = "res://packed/data/research_index.json"
	if not f.file_exists(path):
		return
	f.open(path, File.READ)
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse(text)
	if parsed.error == OK:
		index = parsed.result
	return

func switch_category(cat_name: String):
	if not cat_name in CATEGORIES:
		return
	for btn_name in CATEGORY_ORDER:
		menu.get_node(btn_name).disabled = (btn_name == cat_name)
	current_cat = CATEGORIES[cat_name]
	keyword = ""
	nav.get_node("keyword").text = ""
	current_page = 0
	history = []
	current_entry = {}
	show_list()
	return

func show_list():
	filter_items()
	render_list()
	list_panel.show()
	detail_panel.hide()
	return

func filter_items():
	current_items = []
	var is_alpha = keyword != "" and StaticManager.RE_ALPHA.search(keyword.to_lower()) != null
	for entry in index:
		if entry["category"] != current_cat:
			continue
		if keyword == "":
			current_items.append(entry)
			continue
		var name = entry["name"]
		
		if is_alpha:
			var kw = keyword.to_lower()
			var found = false
			for r in StaticManager.pinyin(name):
				if kw in r:
					found = true
					if kw == r:
						current_items.push_front(entry)
					else:
						current_items.append(entry)
					break
			if found:
				continue
		
		if keyword in name:
			current_items.append(entry)
			continue
	return

func render_list():
	Global.clearNode(list)
	var total = current_items.size()
	var max_page = max(0, int((total - 1) / page_size)) if total > 0 else 0
	if current_page < 0:
		current_page = max_page
	if current_page > max_page:
		current_page = 0

	var start_idx = current_page * page_size
	var end_idx = min(total - 1, start_idx + page_size - 1)

	if total > 0:
		for i in range(start_idx, end_idx + 1):
			var entry = current_items[i]
			var btn = Button.new()
			btn.text = entry["name"]
			btn.align = Button.ALIGN_LEFT
			btn.size_flags_horizontal = SIZE_EXPAND_FILL
			btn.connect("pressed", self, "_on_entry_clicked", [entry])
			list.add_child(btn)

	nav.get_node("page").text = str(current_page + 1) + "/" + str(max_page + 1)
	nav.get_node("total").text = "共 " + str(total) + " 条"
	return

func show_detail(entry: Dictionary):
	current_entry = entry
	var f = File.new()
	var path = "res://packed/data/research_bbcode/" + entry["file"]
	if not f.file_exists(path):
		detail_content.bbcode_text = "文件未找到: " + entry["file"]
	else:
		f.open(path, File.READ)
		var text = f.get_as_text()
		f.close()
		text = text.replace("#000000", "#FFFFFF")
		detail_content.bbcode_text = text
	update_breadcrumb()
	list_panel.hide()
	detail_panel.show()
	detail_scroll.scroll_vertical = 0
	return

func update_breadcrumb():
	var bc = "[color=#6699FF][url=go_list]列表[/url][/color]"
	
	var prev_entry = null
	for i in range(history.size() - 1, - 1, - 1):
		if history[i].get("entry") != null:
			prev_entry = history[i]["entry"]
			break
	if prev_entry != null:
		bc += " >> [color=#6699FF][url=go_back]" + prev_entry["name"] + "[/url][/color]"
	bc += " >> " + current_entry.get("name", "")
	breadcrumb.bbcode_text = bc
	return

func push_history(entry):
	
	history.append({
		"cat": current_cat, 
		"keyword": keyword, 
		"page": current_page, 
		"entry": entry
	})
	if history.size() > MAX_HISTORY:
		history = history.slice(history.size() - MAX_HISTORY, history.size() - 1)
	return

func back_to_list():
	
	if history.size() > 0:
		var first = history[0]
		current_cat = first["cat"]
		keyword = first["keyword"]
		current_page = first["page"]
		nav.get_node("keyword").text = keyword
		for btn_name in CATEGORY_ORDER:
			menu.get_node(btn_name).disabled = (CATEGORIES[btn_name] == current_cat)
		filter_items()
		render_list()
	history = []
	current_entry = {}
	list_panel.show()
	detail_panel.hide()
	return

func go_back_one():
	
	if history.empty():
		return
	var prev = history.pop_back()
	if prev.get("entry") != null:
		
		current_cat = prev["cat"]
		current_entry = prev["entry"]
		show_detail(current_entry)
	else:
		
		current_cat = prev["cat"]
		keyword = prev["keyword"]
		current_page = prev["page"]
		nav.get_node("keyword").text = keyword
		for btn_name in CATEGORY_ORDER:
			menu.get_node(btn_name).disabled = (CATEGORIES[btn_name] == current_cat)
		filter_items()
		render_list()
		history = []
		current_entry = {}
		list_panel.show()
		detail_panel.hide()
	return

func _on_entry_clicked(entry: Dictionary):
	push_history(null)
	show_detail(entry)
	return

func _on_content_meta_clicked(meta):
	var meta_str = str(meta)
	var parsed = JSON.parse(meta_str)
	if parsed.error != OK:
		return
	var data = parsed.result
	if not data is Dictionary:
		return
	if not data.has("research") or not data.has("cat"):
		return
	var target_name = data["research"]
	var target_cat = data["cat"]
	for entry in index:
		if entry["name"] == target_name and entry["category"] == target_cat:
			push_history(current_entry.duplicate())
			current_cat = target_cat
			show_detail(entry)
			return
	return

func _on_breadcrumb_meta_clicked(meta):
	var action = str(meta)
	match action:
		"go_list":
			back_to_list()
		"go_back":
			go_back_one()
	return

func _on_search_pressed():
	keyword = nav.get_node("keyword").text.strip_edges()
	current_page = 0
	show_list()
	return

func _on_keyword_text_entered(_text: String):
	_on_search_pressed()
	return

func _on_prev_pressed():
	current_page -= 1
	show_list()
	return

func _on_next_pressed():
	current_page += 1
	show_list()
	return

func reload_list():
	load_index()
	switch_category("人物")
	return

func reset_layout_landscape() -> void :
	page_size = PAGE_SIZE_LANDSCAPE
	show_list()
	return

func reset_layout_portrait() -> void :
	page_size = PAGE_SIZE_PORTRAIT
	show_list()
	return

func ignored_input(action: String, pressed: bool) -> void :
	if not visible:
		return
	if pressed:
		return

	var focused = get_focus_owner()
	if focused != null and (focused is LineEdit or focused is TextEdit):
		return

	if detail_panel.visible:
		match action:
			"ANALOG_UP":
				scroll_detail( - SCROLL_STEP)
			"ANALOG_DOWN":
				scroll_detail(SCROLL_STEP)
			"ANALOG_LEFT":
				scroll_detail( - SCROLL_STEP * 5)
			"ANALOG_RIGHT":
				scroll_detail(SCROLL_STEP * 5)
			"EMU_B":
				go_back_one()
		return
	if list_panel.visible:
		match action:
			"ANALOG_LEFT":
				_on_prev_pressed()
			"ANALOG_RIGHT":
				_on_next_pressed()
		return
	return

func scroll_detail(delta: int) -> void :
	var v = detail_scroll.scroll_vertical
	detail_scroll.scroll_vertical = v + delta
	return

func _input(event):
	if not visible or not detail_panel.visible:
		return
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			_drag_start_y = int(event.position.y)
			_dragging = false
		else:
			_drag_start_y = 0
			_dragging = false
	elif event is InputEventMouseMotion and _drag_start_y > 0:
		var delta = int(event.position.y) - _drag_start_y
		if not _dragging and abs(delta) > 4:
			_dragging = true
		if _dragging:
			detail_scroll.scroll_vertical -= delta
			_drag_start_y = int(event.position.y)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_drag_start_y = int(event.position.y)
			_dragging = false
		else:
			_drag_start_y = 0
			_dragging = false
	elif event is InputEventScreenDrag:
		_dragging = true
		var delta = int(event.position.y) - _drag_start_y
		detail_scroll.scroll_vertical -= delta
		_drag_start_y = int(event.position.y)
	return
