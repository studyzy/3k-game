# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/con_analog.gd
# 说明：虚拟摇杆 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

var allow_drag = false

var drag_offset = Vector2.ZERO

func _input(event):
	if not allow_drag:
		return
	if not event is InputEventMouseButton:
		return
	if event.button_index != BUTTON_LEFT:
		return
	if not event.pressed:
		return
	
	var pos = event.position
	var absPosition = rect_position * get_parent().rect_scale + get_parent().get_parent().rect_position
	var absSize = rect_size * get_parent().rect_scale * rect_scale
	if pos.x < absPosition.x or pos.y < absPosition.y:
		return
	if pos.x > absPosition.x + absSize.x:
		return
	if pos.y > absPosition.y + absSize.y:
		return
	
	drag_offset = pos - absPosition
	return

func enable_dragging():
	allow_drag = true
	for child in get_children():
		child.modulate.r = 1.0
		child.modulate.g = 0.0
		child.modulate.b = 0.0
	return

func disable_dragging():
	allow_drag = false
	for child in get_children():
		child.modulate.r = 1.0
		child.modulate.g = 1.0
		child.modulate.b = 1.0
	return

func get_drag_data(position):
	if not allow_drag:
		return null
	var d = self.duplicate(true)
	d.rect_scale = get_parent().rect_scale * rect_scale
	for child in d.get_children():
		if child is TouchScreenButton:
			child.position = - drag_offset / d.rect_scale
		elif child is Sprite:
			child.position -= drag_offset / d.rect_scale
	set_drag_preview(d)
	var ret = {"control": d, "type": "key", "self": self}
	return ret

func can_drop_data(_position, data):
	return allow_drag

func drop_data(_position, data):
	if not allow_drag:
		return
	var d = data["control"]
	var absPosition = d.rect_position - drag_offset
	rect_position = (absPosition - get_parent().get_parent().rect_position) / get_parent().rect_scale
	return
