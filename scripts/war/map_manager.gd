extends Node
## 战争地图管理（autoload: MapManager）


## A* 寻路：返回可达格子 {pos: 剩余移动力}
func get_movable_cells_astar(unit_data: UnitData, war_map: Array) -> Dictionary:
	var result := {}
	var start: Vector2i = unit_data.arrayPos
	var move_bonus := unit_data.moveBonus
	var open_set := [start]
	var came_from := {}
	var g_score := {start: 0}
	var f_score := {start: _heuristic(start, start)}
	while not open_set.is_empty():
		# 取 f 值最小的
		var current: Vector2i = open_set[0]
		var current_f: int = f_score.get(current, 1e9)
		for node in open_set:
			if f_score.get(node, 1e9) < current_f:
				current = node
				current_f = f_score.get(node, 1e9)
		open_set.erase(current)
		if g_score.get(current, 0) >= move_bonus:
			continue
		for neighbor in _get_neighbors(current, war_map):
			if _is_blocked(neighbor, unit_data, war_map):
				continue
			var move_cost := get_cell_need_moves(_terrain_at(war_map, neighbor), unit_data.genID, war_map, neighbor)
			if move_cost >= 100:
				continue
			var tentative: int = g_score.get(current, 0) + move_cost
			if tentative > move_bonus:
				continue
			if tentative < g_score.get(neighbor, 1e9):
				came_from[neighbor] = current
				g_score[neighbor] = tentative
				f_score[neighbor] = tentative + _heuristic(neighbor, start)
				if neighbor not in open_set:
					open_set.append(neighbor)
				result[neighbor] = move_bonus - tentative
	return result


## Dijkstra 寻路（G 优先）返回路径
func get_path_to_target(target: Vector2i, unit_data: UnitData, war_map: Array, ignore_ai: bool = false) -> Array:
	var start: Vector2i = unit_data.arrayPos
	if start == target:
		return [start]
	var open_set := [start]
	var came_from := {}
	var g_score := {start: 0}
	var closed := {}
	while not open_set.is_empty():
		open_set.sort_custom(func(a, b): return g_score.get(a, 1e9) < g_score.get(b, 1e9))
		var current: Vector2i = open_set[0]
		open_set.remove_at(0)
		closed[current] = true
		if current == target:
			# 重建路径
			var path := [current]
			while came_from.has(path[0]):
				path.insert(0, came_from[path[0]])
			return path
		for neighbor in _get_neighbors(current, war_map):
			if closed.has(neighbor):
				continue
			if _is_blocked(neighbor, unit_data, war_map):
				continue
			var move_cost := get_cell_need_moves(_terrain_at(war_map, neighbor), unit_data.genID, war_map, neighbor)
			if move_cost >= 100:
				continue
			var tentative: int = g_score.get(current, 0) + move_cost
			if tentative < g_score.get(neighbor, 1e9):
				came_from[neighbor] = current
				g_score[neighbor] = tentative
				if neighbor not in open_set:
					open_set.append(neighbor)
	return []


func _heuristic(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _get_neighbors(pos: Vector2i, war_map: Array) -> Array:
	var dirs: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var result := []
	for d in dirs:
		var np: Vector2i = pos + d
		if np.y >= 0 and np.y < war_map.size() and np.x >= 0 and np.x < war_map[0].size():
			result.append(np)
	return result


func _is_blocked(pos: Vector2i, unit_data: UnitData, war_map: Array) -> bool:
	var v: int = war_map[pos.y][pos.x]
	if unit_data.isPlayer:
		return (v & 0x80) != 0
	return (v & 0x40) != 0


func _terrain_at(war_map: Array, pos: Vector2i) -> int:
	return int(war_map[pos.y][pos.x]) & 0xF


## 地形移动消耗
func get_cell_need_moves(terrain: int, gen_id: int, war_map: Array, pos: Vector2i) -> int:
	var general := GeneralListCache.get_general(gen_id)
	var has_speed := general != null and general.has_skill(3, 5)  # 神速
	match terrain:
		2, 3, 4, 5:  # 平原
			return 2
		6, 7, 8, 9, 10, 11:  # 树林/山地
			var cost := 6
			if has_speed:
				cost -= 1
			if general != null:
				cost -= int(general.army[1])  # 山适性减免
			return maxi(cost, 2)
		12, 13, 14, 15:  # 森林
			var cost2 := 5
			if has_speed:
				cost2 -= 1
			if general != null:
				cost2 -= int(general.army[2])
			return maxi(cost2, 2)
		16, 17, 18:  # 水
			return 6
		_:
			return 120


## 判断是否在范围内（切比雪夫）
func is_in_range(start: Vector2i, end: Vector2i, distance: int) -> bool:
	return maxi(absi(start.x - end.x), absi(start.y - end.y)) <= distance


func is_adjacent(start: Vector2i, end: Vector2i) -> bool:
	return absi(start.x - end.x) + absi(start.y - end.y) == 1


## 获取范围内格子
func get_cells_in_range(pos: Vector2i, distance: int) -> Array:
	var result := []
	for y in range(pos.y - distance, pos.y + distance + 1):
		for x in range(pos.x - distance, pos.x + distance + 1):
			if maxi(absi(pos.x - x), absi(pos.y - y)) <= distance:
				result.append(Vector2i(x, y))
	return result
