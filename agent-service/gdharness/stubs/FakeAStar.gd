extends Reference
# 只做「先横后纵」的直角路径，够 StateProjection._path_stepwise 校验四邻域单步。
# 真实实现是 AStar2D 加权最短路径，这里不模拟权重，只保证路径合法。
func get_path(from: Vector2, to: Vector2):
	var out = PoolVector2Array()
	var cur = from
	out.append(cur)
	while cur.x != to.x:
		cur = Vector2(cur.x + sign(to.x - cur.x), cur.y)
		out.append(cur)
	while cur.y != to.y:
		cur = Vector2(cur.x, cur.y + sign(to.y - cur.y))
		out.append(cur)
	return out