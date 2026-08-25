package game

import "3k-server/internal/game/entities"

// Pos 战争地图坐标（对应 Vector2i）
type Pos struct {
	X, Y int
}

// WarMap 战争地图操作（对应 scripts/war/map_manager.gd）

// GetMovableCellsAstar A* 寻路：返回可达格子 {pos: 剩余移动力}
func (w *World) GetMovableCellsAstar(unit *entities.Unit, warMap [][]int) map[Pos]int {
	result := map[Pos]int{}
	start := Pos{unit.ArrayPosX, unit.ArrayPosY}
	moveBonus := unit.MoveBonus
	openSet := []Pos{start}
	cameFrom := map[Pos]Pos{}
	gScore := map[Pos]int{start: 0}
	fScore := map[Pos]int{start: heuristic(start, start)}

	for len(openSet) > 0 {
		// 取 f 值最小的
		current := openSet[0]
		currentF := fScore[current]
		for _, node := range openSet {
			if fScore[node] < currentF {
				current = node
				currentF = fScore[node]
			}
		}
		openSet = removeFromSlice(openSet, current)
		if gScore[current] >= moveBonus {
			continue
		}
		for _, neighbor := range getNeighbors(current, warMap) {
			if w.isBlocked(neighbor, unit, warMap) {
				continue
			}
			moveCost := w.GetCellNeedMoves(terrainAt(warMap, neighbor), unit.GenID, warMap, neighbor)
			if moveCost >= 100 {
				continue
			}
			tentative := gScore[current] + moveCost
			if tentative > moveBonus {
				continue
			}
			if tentative < gScore[neighbor] || (gScore[neighbor] == 0 && neighbor != start) {
				cameFrom[neighbor] = current
				gScore[neighbor] = tentative
				fScore[neighbor] = tentative + heuristic(neighbor, start)
				if !containsPos(openSet, neighbor) {
					openSet = append(openSet, neighbor)
				}
				result[neighbor] = moveBonus - tentative
			}
		}
	}
	return result
}

// GetPathToTarget Dijkstra 寻路（G 优先）返回路径
func (w *World) GetPathToTarget(target Pos, unit *entities.Unit, warMap [][]int, ignoreAI bool) []Pos {
	start := Pos{unit.ArrayPosX, unit.ArrayPosY}
	if start == target {
		return []Pos{start}
	}
	openSet := []Pos{start}
	cameFrom := map[Pos]Pos{}
	gScore := map[Pos]int{start: 0}
	closed := map[Pos]bool{}
	for len(openSet) > 0 {
		// 按 g 排序（冒泡取最小）
		idx := 0
		for i := 1; i < len(openSet); i++ {
			if gScore[openSet[i]] < gScore[openSet[idx]] {
				idx = i
			}
		}
		current := openSet[idx]
		openSet = removeFromSlice(openSet, current)
		closed[current] = true
		if current == target {
			path := []Pos{current}
			for {
				prev, ok := cameFrom[path[0]]
				if !ok {
					break
				}
				path = append([]Pos{prev}, path...)
			}
			return path
		}
		for _, neighbor := range getNeighbors(current, warMap) {
			if closed[neighbor] {
				continue
			}
			if w.isBlocked(neighbor, unit, warMap) {
				continue
			}
			moveCost := w.GetCellNeedMoves(terrainAt(warMap, neighbor), unit.GenID, warMap, neighbor)
			if moveCost >= 100 {
				continue
			}
			tentative := gScore[current] + moveCost
			if tentative < gScore[neighbor] || (gScore[neighbor] == 0 && neighbor != start) {
				cameFrom[neighbor] = current
				gScore[neighbor] = tentative
				if !containsPos(openSet, neighbor) {
					openSet = append(openSet, neighbor)
				}
			}
		}
	}
	return nil
}

func heuristic(a, b Pos) int {
	return abs(a.X-b.X) + abs(a.Y-b.Y)
}

func getNeighbors(pos Pos, warMap [][]int) []Pos {
	dirs := []Pos{{0, -1}, {0, 1}, {-1, 0}, {1, 0}}
	var result []Pos
	if len(warMap) == 0 || len(warMap[0]) == 0 {
		return result
	}
	for _, d := range dirs {
		np := Pos{pos.X + d.X, pos.Y + d.Y}
		if np.Y >= 0 && np.Y < len(warMap) && np.X >= 0 && np.X < len(warMap[0]) {
			result = append(result, np)
		}
	}
	return result
}

func (w *World) isBlocked(pos Pos, unit *entities.Unit, warMap [][]int) bool {
	v := warMap[pos.Y][pos.X]
	if unit.IsPlayer {
		return (v & 0x80) != 0
	}
	return (v & 0x40) != 0
}

func terrainAt(warMap [][]int, pos Pos) int {
	return int(warMap[pos.Y][pos.X]) & 0xF
}

// GetCellNeedMoves 地形移动消耗（对应 get_cell_need_moves）
func (w *World) GetCellNeedMoves(terrain, genID int, warMap [][]int, pos Pos) int {
	g := w.General(genID)
	hasSpeed := g != nil && g.HasSkill3(5) // 神速
	switch terrain {
	case 2, 3, 4, 5: // 平原
		return 2
	case 6, 7, 8, 9, 10, 11: // 树林/山地
		cost := 6
		if hasSpeed {
			cost--
		}
		if g != nil && len(g.Army) > 1 {
			cost -= g.Army[1] // 山适性减免
		}
		if cost < 2 {
			cost = 2
		}
		return cost
	case 12, 13, 14, 15: // 森林
		cost := 5
		if hasSpeed {
			cost--
		}
		if g != nil && len(g.Army) > 2 {
			cost -= g.Army[2]
		}
		if cost < 2 {
			cost = 2
		}
		return cost
	case 16, 17, 18: // 水
		return 6
	default:
		return 120
	}
}

// IsInRange 判断是否在范围内（切比雪夫）
func IsInRange(start, end Pos, distance int) bool {
	return maxAbs(start.X-end.X, start.Y-end.Y) <= distance
}

// IsAdjacent 是否相邻
func IsAdjacent(start, end Pos) bool {
	return abs(start.X-end.X)+abs(start.Y-end.Y) == 1
}

// GetCellsInRange 获取范围内格子
func GetCellsInRange(pos Pos, distance int) []Pos {
	var result []Pos
	for y := pos.Y - distance; y <= pos.Y+distance; y++ {
		for x := pos.X - distance; x <= pos.X+distance; x++ {
			if maxAbs(pos.X-x, pos.Y-y) <= distance {
				result = append(result, Pos{x, y})
			}
		}
	}
	return result
}

func abs(v int) int {
	if v < 0 {
		return -v
	}
	return v
}

func maxAbs(a, b int) int {
	if abs(a) > abs(b) {
		return abs(a)
	}
	return abs(b)
}

func removeFromSlice(s []Pos, v Pos) []Pos {
	for i, x := range s {
		if x == v {
			return append(s[:i], s[i+1:]...)
		}
	}
	return s
}

func containsPos(s []Pos, v Pos) bool {
	for _, x := range s {
		if x == v {
			return true
		}
	}
	return false
}
