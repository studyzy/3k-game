# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/menu/pnlQuestionHelp.gd
# 说明：问题帮助面板 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

const LINE_DELTA_VALUE = 32
const PAGE_DELTA_VALUE = 128

onready var gv = get_node("ScrollContainer/gv")
onready var itemSample = get_node("itemSample")
onready var answer = get_node("answer")

var cursorIndex = 0

func _ready() -> void :
	init()
	return

func bind_gv():
	Global.clearNode(gv)
	var idx = 0
	for qa in StaticManager.qa_data:
		_add_question(qa["question"], idx)
		idx += 1
	return

func init():
	bind_gv()
	cursorIndex = 0
	if gv.get_child_count() > 0:
		update_show()
	close_answer()
	return

func _process(delta: float) -> void :
	if not answer.visible:
		if Input.is_action_just_pressed("ANALOG_UP"):
			_next_item(true)
			return
		if Input.is_action_just_pressed("ANALOG_DOWN"):
			_next_item()
			return
		if Input.is_action_just_pressed("EMU_A"):
			var btns = gv.get_children()
			btns[cursorIndex].get_node("item").emit_signal("pressed")
		if Input.is_action_just_pressed("EMU_B"):
			_on_btnBack_pressed()
	else:
		var txt = answer.get_node("p/txt")
		txt.get_parent().rect_min_size.y = txt.rect_size.y + 40
		txt.get_parent().rect_size.y = txt.rect_size.y + 40
		if Input.is_action_just_pressed("EMU_B"):
			close_answer()
			return
		if Input.is_action_just_pressed("ANALOG_UP"):
			scroll_up()
			return
		if Input.is_action_just_pressed("ANALOG_DOWN"):
			scroll_down()
			return
		if Input.is_action_just_pressed("ANALOG_LEFT"):
			scroll_page_up()
			return
		if Input.is_action_just_pressed("ANALOG_RIGHT"):
			scroll_page_down()
			return
	return

func _add_question(question: String, idx: int):
	var con = HFlowContainer.new()
	con.name = str(idx)
	var item = itemSample.duplicate()
	item.name = "item"
	item.text = question
	item.connect("pressed", self, "_show_answer", [idx])
	con.add_child(item)
	item.show()
	gv.add_child(con)
	return

func update_show():
	for i in gv.get_child_count():
		var c = gv.get_child(i)
		var btn: Button = c.get_node_or_null("item")
		if btn == null:
			continue
		if i == cursorIndex:
			btn.set("custom_colors/font_color", Color.yellow)
			continue
		btn.set("custom_colors/font_color", Color.white)
	var vsb = gv.get_parent().get_v_scrollbar()
	if cursorIndex >= StaticManager.qa_data.size() / 2:
		vsb.value = int(vsb.max_value / 2)
	else:
		vsb.value = 0
	return

func _next_item(inverted: bool = false):
	if inverted:
		cursorIndex -= 1
		if cursorIndex < 0:
			cursorIndex = gv.get_child_count() - 1
	else:
		cursorIndex += 1
		if cursorIndex >= gv.get_child_count():
			cursorIndex = 0
	update_show()
	return

func _show_answer(idx: int):
	cursorIndex = idx
	if idx < 0:
		return
	if idx >= StaticManager.qa_data.size():
		return
	var qa = StaticManager.qa_data[idx]
	var txt = answer.get_node("p/txt")
	txt.bbcode_text = "[center][color=yellow]问：[/color]{question}[/center]\n\n[color=yellow]答：[/color]\n{answer}".format(qa)
	answer.show()
	gv.hide()
	update_show()
	scroll_change( - 10000)
	return

func _on_btnBack_pressed() -> void :
	if answer.visible:
		close_answer()
		return
	hide()
	return

func _on_answerText_meta_clicked(meta) -> void :
	var data = parse_json(meta)
	match str(data["code"]):
		"tong_guan_mi_ji":
			var times = int(DataManager.unify_times);
			times += 1;
			DataManager.unify_times = times;
			Global.save_file_text("user://unify_times.txt", str(times));
	return

func scroll_change(val: int) -> void :
	var vsb = answer.get_v_scrollbar()
	vsb.value += val
	vsb.value = max(vsb.value, vsb.min_value)
	vsb.value = min(vsb.value, vsb.max_value)
	return

func scroll_up():
	scroll_change( - LINE_DELTA_VALUE)
	return

func scroll_down():
	scroll_change(LINE_DELTA_VALUE)
	return

func scroll_page_up():
	scroll_change( - PAGE_DELTA_VALUE)
	return

func scroll_page_down():
	scroll_change(PAGE_DELTA_VALUE)
	return

func reset_layout_landscape() -> void :
	rect_position = Vector2(0, 0)
	rect_size = Vector2(1024, 600)
	$bg.rect_size = rect_size
	$ScrollContainer.rect_scale = Vector2(1, 1)
	answer.rect_min_size = Vector2(1024, 600)
	answer.rect_size.x = 1024
	answer.rect_scale = Vector2(1, 1)
	answer.get_node("p").rect_min_size.x = 1024
	answer.get_node("p").rect_size.x = 1024
	answer.get_node("p/txt").rect_min_size.x = 976
	answer.get_node("p/txt").rect_size.x = 976
	answer.get_node("p/txt").rect_position = Vector2(24, 20)
	return

func reset_layout_portrait() -> void :
	rect_position = Vector2(0, 0)
	rect_size = Vector2(1024, 1560)
	$bg.rect_size = rect_size
	$ScrollContainer.rect_scale = Vector2(1.6, 1.6)
	answer.rect_min_size = Vector2(640, 975)
	answer.rect_size.x = 640
	answer.rect_scale = Vector2(1.6, 1.6)
	answer.get_node("p").rect_min_size.x = 640
	answer.get_node("p").rect_size.x = 640
	answer.get_node("p/txt").rect_min_size.x = 600
	answer.get_node("p/txt").rect_size.x = 600
	answer.get_node("p/txt").rect_position = Vector2(20, 20)
	return

func close_answer() -> void :
	answer.hide()
	gv.show()
	return
