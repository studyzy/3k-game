# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/skill.gd
# 说明：信息面板-技能。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends HBoxContainer

onready var skilllist = $skilllist

func _ready():
	skilllist.reload_list()
	return
