# 假 Global：脚本加载与距离计算。
# 与真实 Global.load_script（bwdl/script/global.gd）一致：按路径缓存，
# 命中缓存时对同一实例再调一次 _init()，让「重入不重置」守卫真正被执行。
extends Node

var iTactic = null

var _cache = {}

func load_script(path):
	var file = str(path).get_file()
	# ITactic 在真实引擎里是按场景注入的单例实现，不参与脚本缓存。
	if file == "ITactic.gd":
		return iTactic
	var key = str(path)
	if _cache.has(key):
		var prev = _cache[key]
		if prev != null:
			prev._init()
			return prev
	var p = "res://" + file
	if not ResourceLoader.exists(p):
		return null
	var sc = load(p).new()
	_cache[key] = sc
	return sc

func get_distance(a, b) -> int:
	return int(abs(a.x - b.x)) + int(abs(a.y - b.y))
