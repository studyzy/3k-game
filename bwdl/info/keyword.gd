extends LineEdit

signal keyword_changed

func _gui_input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_ENTER:
			text = text.strip_edges()
			emit_signal("keyword_changed")
	return
