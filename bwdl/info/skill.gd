extends HBoxContainer

onready var skilllist = $skilllist

func _ready():
	skilllist.reload_list()
	return
