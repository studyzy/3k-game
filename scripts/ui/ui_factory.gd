class_name UIFactory
## UI 构建辅助
## 统一提供控件工厂：全屏背景、面板/按钮皮肤（资源迁移自 sanguo）。

# —— 皮肤缓存（静态，避免每次调用重复 load）——
static var _btn_normal: StyleBoxTexture = null
static var _btn_hover: StyleBoxTexture = null
static var _btn_pressed: StyleBoxTexture = null
static var _panel_style: StyleBoxTexture = null


## 全屏背景贴图（等比放大裁剪铺满，不按比例拉伸）。
static func make_bg(path: String) -> TextureRect:
	var r := TextureRect.new()
	var tex: Texture2D = load(path)
	r.texture = tex
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return r


## 把贴图包成九宫格样式（角不拉伸、中间拉伸）。
static func _nine_patch(tex: Texture2D, mx: int, my: int) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.texture_margin_left = mx
	sb.texture_margin_right = mx
	sb.texture_margin_top = my
	sb.texture_margin_bottom = my
	return sb


## 惰性加载按钮皮肤（button.png 为暗色半透明，白字可读）。
static func _ensure_button_skin() -> void:
	if _btn_normal != null:
		return
	var tex: Texture2D = load("res://assets/ui/button.png")
	if tex == null:
		return
	_btn_normal = _nine_patch(tex, 24, 18)
	_btn_hover = _nine_patch(tex, 24, 18)
	_btn_hover.modulate_color = Color(1.2, 1.2, 1.2, 1.0)
	_btn_pressed = _nine_patch(tex, 24, 18)
	_btn_pressed.modulate_color = Color(0.8, 0.8, 0.8, 1.0)


## 惰性加载面板皮肤（Panel.jpg 为暗色带边框面板）。
static func _ensure_panel_skin() -> void:
	if _panel_style != null:
		return
	var tex: Texture2D = load("res://assets/ui/Panel.jpg")
	if tex == null:
		return
	_panel_style = _nine_patch(tex, 32, 32)


static func make_panel(rect: Rect2) -> Panel:
	var p := Panel.new()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ensure_panel_skin()
	if _panel_style != null:
		p.add_theme_stylebox_override("panel", _panel_style)
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
	_ensure_button_skin()
	if _btn_normal != null:
		b.add_theme_stylebox_override("normal", _btn_normal)
		b.add_theme_stylebox_override("hover", _btn_hover)
		b.add_theme_stylebox_override("pressed", _btn_pressed)
		b.add_theme_stylebox_override("focus", _btn_normal)
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
