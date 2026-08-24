class_name UIFactory
## UI 构建辅助

static func make_panel(rect: Rect2) -> Panel:
	var p := Panel.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	return p


static func make_label(text: String, font_size: int = 24, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


static func make_button(text: String, size: Vector2 = Vector2(260, 60), font_size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = size
	b.add_theme_font_size_override("font_size", font_size)
	return b


static func add_label(parent: Node, text: String, pos: Vector2, font_size: int = 24, color: Color = Color.WHITE) -> Label:
	var l := make_label(text, font_size, color)
	parent.add_child(l)
	l.position = pos
	return l


static func add_button(parent: Node, text: String, pos: Vector2, size: Vector2 = Vector2(260, 60)) -> Button:
	var b := make_button(text, size)
	parent.add_child(b)
	b.position = pos
	return b
