# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/keyword.gd
# 说明：信息面板-关键词。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends LineEdit

signal keyword_changed

func _gui_input(event):
	if event is InputEventKey:
		if event.pressed and event.scancode == KEY_ENTER:
			text = text.strip_edges()
			emit_signal("keyword_changed")
	return
