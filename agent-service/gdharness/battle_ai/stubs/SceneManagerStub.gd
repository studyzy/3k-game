# 假 SceneManager：当前场景与对话可见性。
extends Node

var tips = ""
var actor_dialog = null
var _scene = null

func show_special_tips(msg): tips = str(msg)

func reset_tips(): tips = ""

func current_scene():
	if _scene == null:
		_scene = load("res://stubs/FakeScene.gd").new()
	return _scene
