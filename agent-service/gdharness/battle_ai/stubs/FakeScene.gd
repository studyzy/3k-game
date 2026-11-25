# 假场景：只要 battle_state 与 actor_dialog 两个可见性开关。
extends Node

var SCENE_ID = 30000
var bgm = false
var battle_state = null
var actor_dialog = null

func _init() -> void:
	battle_state = Control.new()
	battle_state.visible = false
	actor_dialog = Control.new()
	actor_dialog.visible = false
	return
