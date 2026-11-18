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
