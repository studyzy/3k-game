extends Node
var iTactic = null
# 模拟 Global.load_script：返回「脚本实例」（与真实实现一致，会复用缓存实例）
func load_script(path):
	if path.find("ITactic") >= 0:
		return iTactic
	return null
