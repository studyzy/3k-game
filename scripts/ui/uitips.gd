extends CanvasLayer
## 全局提示系统（autoload: UITips，对应 Unity UITips）

var _panel: Panel
var _text_label: Label
var _confirm_btn: Button
var _cancel_btn: Button
var _close_btn: Button
var _close_callback: Callable = Callable()
var _confirm_callback: Callable = Callable()
var _cancel_callback: Callable = Callable()


func _ready() -> void:
	layer = 100
	_panel = Panel.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.visible = false
	add_child(_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(dim)

	var box := Panel.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.size = Vector2(700, 300)
	_panel.add_child(box)

	_text_label = Label.new()
	_text_label.set_anchors_preset(Control.PRESET_CENTER)
	_text_label.position = Vector2(-320, -100)
	_text_label.size = Vector2(640, 140)
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.add_theme_font_size_override("font_size", 24)
	box.add_child(_text_label)

	_close_btn = UIFactory.make_button("确 定", Vector2(160, 50), 22)
	_close_btn.position = Vector2(270, 200)
	_close_btn.visible = false
	_close_btn.pressed.connect(_on_close_pressed)
	box.add_child(_close_btn)

	_confirm_btn = UIFactory.make_button("确 定", Vector2(160, 50), 22)
	_confirm_btn.position = Vector2(140, 200)
	_confirm_btn.visible = false
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	box.add_child(_confirm_btn)

	_cancel_btn = UIFactory.make_button("取 消", Vector2(160, 50), 22)
	_cancel_btn.position = Vector2(400, 200)
	_cancel_btn.visible = false
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	box.add_child(_cancel_btn)


func _hide() -> void:
	_panel.visible = false
	_close_btn.visible = false
	_confirm_btn.visible = false
	_cancel_btn.visible = false


func _on_close_pressed() -> void:
	_hide()
	if _close_callback.is_valid():
		_close_callback.call()


func _on_confirm_pressed() -> void:
	_hide()
	if _confirm_callback.is_valid():
		_confirm_callback.call(true)


func _on_cancel_pressed() -> void:
	_hide()
	if _cancel_callback.is_valid():
		_cancel_callback.call(false)


## 单确认提示
func show_notice_tips_with_confirm(text: String, on_confirm: Callable = Callable()) -> void:
	_panel.visible = true
	_text_label.text = text
	_close_btn.visible = true
	_confirm_btn.visible = false
	_cancel_btn.visible = false
	_close_callback = on_confirm


## 双选提示（callback 参数 true=确认 false=取消）
func show_optional_tips(text: String, callback: Callable) -> void:
	_panel.visible = true
	_text_label.text = text
	_close_btn.visible = false
	_confirm_btn.visible = true
	_cancel_btn.visible = true
	_confirm_callback = callback
	_cancel_callback = callback


## 回合事件提示（1.2 秒后自动确认）
func show_turn_tips_with_confirm(text: String, on_confirm: Callable = Callable()) -> void:
	_panel.visible = true
	_text_label.text = text
	_close_btn.visible = true
	_confirm_btn.visible = false
	_cancel_btn.visible = false
	_close_callback = on_confirm
	get_tree().create_timer(1.2).timeout.connect(func():
		if _panel.visible:
			_hide()
			if on_confirm.is_valid():
				on_confirm.call())
