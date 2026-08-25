# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/draggable.gd
# 说明：可拖拽控件。提供窗口拖拽能力。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Control

var startingY: int = 0
var container: ScrollContainer

func _ready():
	container = get_parent()
	return

func _input(event):
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			
			startingY = event.position.y
		else:
			
			startingY = 0
	elif event is InputEventMouseMotion and startingY > 0:
		
		var delta = event.position.y - startingY
		container.scroll_vertical -= delta
		startingY = event.position.y
	elif event is InputEventScreenTouch:
		if event.pressed:
			
			startingY = event.position.y
		else:
			
			startingY = 0
	elif event is InputEventScreenDrag and startingY > 0:
		
		var delta = event.position.y - startingY
		container.scroll_vertical -= delta
		startingY = event.position.y
	return
