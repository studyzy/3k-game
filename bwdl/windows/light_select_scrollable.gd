tool
extends Control




export (int) var cursor_index: int = 0
export (int) var columns = 1
export (int) var h_separation = 4
export (int) var v_separation = 4
export (Array) var items = ["选项1"]
export (int, 25, 40) var font_size = 35
export (Color) var font_color = Color8(0, 0, 0)
export (bool) var rich = false


const CURSOR_OFFSET_LARGE = Vector2(0, 10)
const CURSOR_OFFSET_SMALL = Vector2(0, 4)
const LABEL_LEFT_MARGIN = 18

onready var _scroll_area: Control = $scroll_area
onready var _gv: GridContainer = $scroll_area / gv
onready var _cursor: TextureRect = $cursor
onready var _con_hide: Control = $Hide
onready var _con_delete_line: ColorRect = $deleted

var _cursor_offset: Vector2 = CURSOR_OFFSET_LARGE

func _ready() -> void :
	_set_data()

func _set_data(_font_size: int = - 1):
	if _font_size < 0:
		_font_size = font_size
	_cursor_offset = CURSOR_OFFSET_LARGE if _font_size >= 30 else CURSOR_OFFSET_SMALL
	$pager.hide()
	$scrollbar_track.hide()
	$scrollbar_thumb.hide()
	cursor_index = 0
	_gv.columns = columns
	_gv.set("custom_constants/vseparation", v_separation)
	_gv.set("custom_constants/hseparation", h_separation)
	Global.clearNode(_gv)
	_cursor.show()
	for i in items.size():
		var item = items[i]
		var control = Control.new()
		var font = Global.get_font(_font_size)
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
				deleted = _con_delete_line.duplicate()
			if "#C" in item:
				var color_info = item.split("#C")[1].split(",")
				item = item.split("#C")[0]
				if color_info.size() == 3:
					var color = Color8(int(color_info[0]), int(color_info[1]), int(color_info[2]))
					lbl.set("custom_colors/font_color", color)
			elif "#" in item:
				var color_info = item.split("#")[1]
				item = item.split("#")[0]
				if color_info.length() == 6:
					var color = Color("#" + color_info)
					lbl.set("custom_colors/font_color", color)
			lbl.text = str(item)
			lbl.valign = Label.VALIGN_CENTER
		lbl.name = str(i)
		lbl.rect_position = Vector2(LABEL_LEFT_MARGIN, 0)
		if deleted != null:
			deleted.rect_size = Vector2(lbl.rect_size.x, 3)
			deleted.rect_position = Vector2(lbl.rect_position.x, int(lbl.rect_size.y / 2))
			deleted.visible = true
			control.add_child(deleted)
		var con_selected = _con_hide.duplicate()
		con_selected.hide()
		control.add_child(lbl)
		control.add_child(con_selected)
		_gv.add_child(control)
	DataManager.recover_lsc_index(self)

func set_items_text(index: int, text: String):
	items[index] = text
	var last_index = cursor_index
	_set_data()
	cursor_index = last_index

func _process(_delta: float) -> void :
	_update_cursor()

func _get_cursor_grid_pos(index: int) -> Vector2:
	return Vector2(index % columns, index / columns)

func _update_cursor():
	if _gv.get_child_count() == 0:
		return
	_cursor.visible = cursor_index >= 0
	var grid_pos = _get_cursor_grid_pos(cursor_index)
	var item_y = grid_pos.y * v_separation
	
	var visible_height = _scroll_area.rect_size.y
	if visible_height > 0:
		var offset_y = _gv.rect_position.y
		var top = item_y + offset_y
		var bottom = top + v_separation
		if top < 0:
			_gv.rect_position.y = - item_y
		elif bottom > visible_height:
			_gv.rect_position.y = visible_height - item_y - v_separation
		_update_scroll_hint(visible_height)
	
	_cursor.rect_position = Vector2(
		grid_pos.x * h_separation, 
		_gv.rect_position.y + item_y
	) + _cursor_offset

func _update_scroll_hint(visible_height: float):
	var total_height = (int((items.size() - 1) / columns) + 1) * v_separation
	if total_height <= visible_height:
		$scrollbar_track.hide()
		$scrollbar_thumb.hide()
		return
	
	var bar_x = rect_size.x - 6
	var track_height = visible_height
	$scrollbar_track.rect_position = Vector2(bar_x, 0)
	$scrollbar_track.rect_size = Vector2(4, track_height)
	$scrollbar_track.show()
	var thumb_ratio = visible_height / total_height
	var thumb_height = max(track_height * thumb_ratio, 12)
	var scroll_range = total_height - visible_height
	var scroll_progress = 0.0
	if scroll_range > 0:
		scroll_progress = clamp( - _gv.rect_position.y / scroll_range, 0.0, 1.0)
	var thumb_y = scroll_progress * (track_height - thumb_height)
	$scrollbar_thumb.rect_position = Vector2(bar_x, thumb_y)
	$scrollbar_thumb.rect_size = Vector2(4, thumb_height)
	$scrollbar_thumb.show()



func move(dir: Vector2) -> void :
	var y = int(cursor_index / columns)
	var x = cursor_index % columns
	while true:
		x += int(dir.x)
		y += int(dir.y)
		if x < 0:
			x = columns - 1
		if x >= columns:
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
		newindex = y * columns + x
		if newindex >= items.size():
			x = 0
			y = 0
		newindex = y * columns + x
		if newindex < 0 or newindex >= items.size():
			break
		var item = items[newindex]
		if Global.strval(item) != "":
			break
	set_cursor(y * columns + x)

func move_up():
	move(Vector2.UP)

func move_down():
	move(Vector2.DOWN)

func move_left():
	if columns == 1:
		set_cursor(0)
	else:
		move(Vector2.LEFT)

func move_right():
	if columns == 1:
		set_cursor(items.size() - 1)
	else:
		move(Vector2.RIGHT)

func set_cursor(index: int):
	if index < 0 or index >= items.size() or items[index] == "":
		index = 0
	cursor_index = index
	DataManager.remember_lsc_index(self)

func set_pager(page: int, maxPage: int) -> void :
	if columns == 2:
		var children = _gv.get_children()
		if children.size() < 2:
			return
		var cols = int((items.size() + 1) / columns)
		$pager.rect_position = _gv.rect_position + Vector2(h_separation * 2 - $pager.rect_size.x - 40, v_separation * (cols - 1) + 4)
	else:
		$pager.rect_position = _gv.rect_position + Vector2(h_separation * 1.5, v_separation * 7.2)
	$pager.text = "{0}/{1}".format([page + 1, maxPage + 1])
	$pager.show()

func set_selected_by_array(array: PoolIntArray):
	for i in items.size():
		var node = _gv.get_child(i)
		if is_instance_valid(node):
			node.get_node("Hide").visible = (i in array)

func get_selected_list() -> Array:
	var array = []
	for i in items.size():
		var node = _gv.get_child(i)
		if is_instance_valid(node):
			if node.get_node("Hide").visible:
				array.append(i)
	return array

func set_selected_change(max_select_num = - 1):
	var node = _gv.get_child(cursor_index)
	if is_instance_valid(node):
		var show: bool = node.get_node("Hide").visible
		if not show:
			if max_select_num == 0:
				return
		node.get_node("Hide").visible = not show

func _on_hide():
	cursor_index = 0
	DataManager.discard_lsc_index(self)
