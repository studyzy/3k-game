# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：windows/menu/pnlSkillSet.gd
# 说明：技能设置面板 UI。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

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

