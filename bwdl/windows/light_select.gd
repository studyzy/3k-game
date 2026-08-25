# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/light_select.gd
# 说明：高亮选择 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

tool
extends Control


export (int) var cursor_index: int = 0;

export (int) var columns = 1;

export (int) var h_separation = 4;

export (int) var v_separation = 4;

export (Array) var items = ["选项1"];

export (int, 25, 40) var font_size = 35;

export (Color) var font_color = Color8(0, 0, 0);
export (Vector2) var cursor_offset = Vector2( - 5, 10)

export (bool) var rich = false

onready var gv: GridContainer = get_node("gv")
onready var cursor = get_node("cursor")
onready var conHide = get_node("Hide")
onready var conDeleteLine = get_node("deleted")

func _ready() -> void :
	_set_data()
	return

func _set_data(_fontSize: int = - 1):
	if _fontSize < 0:
		_fontSize = font_size
	cursor_offset = Vector2( - 5, 10)
	if _fontSize < 30:
		cursor_offset = Vector2( - 5, 4)
	$pager.hide()
	cursor_index = 0;
	gv.columns = columns
	gv.set("custom_constants/vseparation", v_separation)
	gv.set("custom_constants/hseparation", h_separation)
	Global.clearNode(gv)
	var i = 0
	cursor.show();
	for item in items:
		var control = Control.new()
		var font = Global.get_font(_fontSize)
		var lbl
		var deleted = null
		if rich:
			lbl = RichTextLabel.new()
			lbl.set("custom_fonts/normal_font", font)
			lbl.set("custom_colors/default_color", Color.black)
			lbl.bbcode_enabled = true
			lbl.bbcode_text = item
			lbl.rect_min_size.x = h_separation
			if columns == 1:
				lbl.rect_min_size.x = h_separation * 2
			lbl.rect_min_size.y = font_size * 1.1
			lbl.scroll_active = false
		else:
			lbl = Label.new()
			
			lbl.set("custom_fonts/font", font)
			lbl.set("custom_colors/font_color", font_color)
			if "@DEL" in item:
				item = item.split("@DEL")[0]
				deleted = conDeleteLine.duplicate()
			if "#C" in item:
				var colorInfo = item.split("#C")[1].split(",")
				item = item.split("#C")[0]
				if colorInfo.size() == 3:
					var color = Color8(int(colorInfo[0]), int(colorInfo[1]), int(colorInfo[2]))
					lbl.set("custom_colors/font_color", color)
			elif "#" in item:
				var colorInfo = item.split("#")[1]
				item = item.split("#")[0]
				if colorInfo.length() == 6:
					var color = Color("#" + colorInfo)
					lbl.set("custom_colors/font_color", color)
			lbl.text = str(item)
			lbl.valign = Label.VALIGN_CENTER
		lbl.name = str(i)
		lbl.rect_position = Vector2(10, 0)
		if deleted != null:
			deleted.rect_size = Vector2(lbl.rect_size.x, 3)
			deleted.rect_position = Vector2(lbl.rect_position.x, int(lbl.rect_size.y / 2))
			deleted.visible = true
			control.add_child(deleted)
		var con_selected = conHide.duplicate()
		con_selected.hide()
		control.add_child(lbl)
		control.add_child(con_selected)
		gv.add_child(control)
		i += 1
	DataManager.recover_lsc_index(self)
	return

func set_pager(page: int, maxPage: int) -> void :
	if columns == 2:
		
		
		var children = gv.get_children()
		if children.size() < 2:
			return
		var next = children[children.size() - 1]
		var prev = children[children.size() - 2]
		var cols = int((items.size() + 1) / columns)
		$pager.rect_position = gv.rect_position + Vector2(h_separation * 2 - $pager.rect_size.x - 40, v_separation * (cols - 1) + 4)
	else:
		
		$pager.rect_position = gv.rect_position + Vector2(h_separation * 1.5, v_separation * 7.2)
	$pager.text = "{0}/{1}".format([page + 1, maxPage + 1])
	$pager.show()
	return

func set_items_text(index: int, text: String):
	items[index] = text;
	var last_cursor_index = cursor_index;
	_set_data();
	cursor_index = last_cursor_index

func _process(delta: float) -> void :
	UpdateCursor()
	return

func get_cursor_game_position(index: int) -> Vector2:
	var cursor_y = index / columns;
	var cursor_x = index % columns;
	return Vector2(cursor_x, cursor_y);


func UpdateCursor():
	cursor = get_node("cursor");
	gv = get_node("gv");
	if (gv.get_child_count() == 0):
		return ;
	cursor.visible = cursor_index >= 0;
	var curosr_p = get_cursor_game_position(cursor_index);
	cursor.rect_position.y = gv.rect_position.y + curosr_p.y * v_separation
	cursor.rect_position.x = curosr_p.x * h_separation;
	cursor.rect_position += cursor_offset;
	return



func move(dir: Vector2) -> void :
	var y = int(cursor_index / columns)
	var x = cursor_index % columns
	while true:
		x += dir.x
		y += dir.y
		if x < 0:
			x = gv.columns - 1
		if x >= gv.columns:
			x = 0
		var newindex = y * columns + x
		if newindex < 0:
			y = int(items.size() / columns)
			newindex = y * columns + x
			if newindex >= items.size():
				y -= 1
				newindex = y * columns + x
		if newindex >= items.size():
			if dir.x == 0:
				y = 0
			elif dir.y == 0:
				x = 0
		newindex = y * gv.columns + x
		if newindex >= items.size():
			x = 0
			y = 0
		newindex = y * gv.columns + x
		if newindex < 0 or newindex >= items.size():
			break
		var item = items[newindex]
		if Global.strval(item) != "":
			break
	set_cursor(y * gv.columns + x)
	return

func move_up():
	return move(Vector2.UP)

func move_down():
	return move(Vector2.DOWN)

func move_left():
	return move(Vector2.LEFT)

func move_right():
	return move(Vector2.RIGHT)

func set_cursor(index: int):
	if index < 0 or index >= items.size() or items[index] == "":
		index = 0
	cursor_index = index;
	DataManager.remember_lsc_index(self)
	return


func set_selected_by_array(array: PoolIntArray):
	for i in items.size():
		var node = gv.get_child(i);
		if (is_instance_valid(node)):
			node.get_node("Hide").visible = (i in array);

func get_selected_list() -> Array:
	var array = [];
	for i in items.size():
		var node = gv.get_child(i);
		if (is_instance_valid(node)):
			if (node.get_node("Hide").visible):
				array.append(i);
	return array;

func set_selected_change(max_select_num = - 1):
	var node = gv.get_child(cursor_index);
	if (is_instance_valid(node)):
		var show: bool = node.get_node("Hide").visible;
		if ( not show):
			if (max_select_num == 0):
				return ;
		node.get_node("Hide").visible = not show;

func on_hide():
	cursor_index = 0
	DataManager.discard_lsc_index(self)
	return
