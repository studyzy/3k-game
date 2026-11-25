# 假 Global：脚本加载与距离计算。
extends Node

var iTactic = null

func load_script(path):
	var file = str(path).get_file()
	if file == "ITactic.gd":
		return iTactic
	var p = "res://" + file
	if ResourceLoader.exists(p):
		return load(p).new()
	return null

func get_distance(a, b) -> int:
	return int(abs(a.x - b.x)) + int(abs(a.y - b.y))
