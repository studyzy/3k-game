extends Control

onready var con = get_node("con");
onready var gc = get_node("GridContainer");


var words = [];

func _ready() -> void :

	pass
	
func _load_gridview():
	Global.clearNode(gc);
	for word in words:
		var c = con.duplicate();
		var lbltext: Label = c.get_node("Label");
		lbltext.text = str(word);
		c.show();
		gc.add_child(c);
	pass

func set_title(text: String):
	get_node("Label").text = text;
