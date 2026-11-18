extends Control

onready var tree: Tree = get_node("Tree");

func _ready() -> void :
	SceneManager.VirtualKey.hide();
	var root = tree.create_item()
	tree.set_hide_root(true)
	var child1 = tree.create_item(root)
	var child2 = tree.create_item(root)
	var subchild1 = tree.create_item(child1)
	subchild1.set_text(0, "Subchild1")

