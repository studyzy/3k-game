package game

import (
	"testing"

	"3k-server/internal/game/entities"
)

// makePlainMap 构造 19x32 全平原(值2)地图
func makePlainMap() [][]int {
	m := make([][]int, 19)
	for row := range m {
		m[row] = make([]int, 32)
		for col := range m[row] {
			m[row][col] = 2 // 平原
		}
	}
	return m
}

// TestHeuristic 验证曼哈顿距离
func TestHeuristic(t *testing.T) {
	if v := heuristic(Pos{1, 2}, Pos{4, 6}); v != 7 {
		t.Errorf("heuristic 应得 7，实际 %d", v)
	}
	if v := heuristic(Pos{5, 5}, Pos{5, 5}); v != 0 {
		t.Errorf("相同点应得 0，实际 %d", v)
	}
}

// TestAbsMaxAbs 验证绝对值
func TestAbsMaxAbs(t *testing.T) {
	if abs(-5) != 5 || abs(3) != 3 {
		t.Error("abs 计算错误")
	}
	if maxAbs(3, -4) != 4 {
		t.Error("maxAbs 应取绝对值较大者")
	}
	if maxAbs(-1, 2) != 2 {
		t.Error("maxAbs 计算错误")
	}
}

// TestIsInRange 验证切比雪夫范围
func TestIsInRange(t *testing.T) {
	if !IsInRange(Pos{0, 0}, Pos{2, 2}, 2) {
		t.Error("切比雪夫距离2应在范围内")
	}
	if IsInRange(Pos{0, 0}, Pos{3, 3}, 2) {
		t.Error("切比雪夫距离3不应在范围2内")
	}
}

// TestIsAdjacent 验证相邻判断
func TestIsAdjacent(t *testing.T) {
	if !IsAdjacent(Pos{1, 1}, Pos{1, 2}) {
		t.Error("上下左右应相邻")
	}
	if IsAdjacent(Pos{1, 1}, Pos{2, 2}) {
		t.Error("对角不应相邻")
	}
	if IsAdjacent(Pos{1, 1}, Pos{1, 1}) {
		t.Error("同点不应相邻")
	}
}

// TestGetCellsInRange 验证范围内格子数量
func TestGetCellsInRange(t *testing.T) {
	// 距离1含中心共9格
	if v := len(GetCellsInRange(Pos{5, 5}, 1)); v != 9 {
		t.Errorf("范围1应有9格，实际 %d", v)
	}
	// 距离2含中心共25格
	if v := len(GetCellsInRange(Pos{5, 5}, 2)); v != 25 {
		t.Errorf("范围2应有25格，实际 %d", v)
	}
}

// TestGetNeighbors 验证邻居获取与出界过滤
func TestGetNeighbors(t *testing.T) {
	m := makePlainMap()
	// 内部点 4 邻居
	if v := len(getNeighbors(Pos{5, 5}, m)); v != 4 {
		t.Errorf("内部点应有4邻居，实际 %d", v)
	}
	// 角落 (0,0) 2 邻居
	if v := len(getNeighbors(Pos{0, 0}, m)); v != 2 {
		t.Errorf("角落应有2邻居，实际 %d", v)
	}
	// 空地图返回空
	if v := len(getNeighbors(Pos{0, 0}, nil)); v != 0 {
		t.Errorf("空地图应返回空，实际 %d", v)
	}
}

// TestTerrainAt 验证地形解析（低位0xF）
func TestTerrainAt(t *testing.T) {
	m := [][]int{{0x2F}}
	if v := terrainAt(m, Pos{0, 0}); v != 0xF {
		t.Errorf("0x2F 地形应解析为 0xF，实际 %d", v)
	}
}

// TestIsBlocked 验证位掩码阻挡
func TestIsBlocked(t *testing.T) {
	w := newTestWorld(t)
	m := [][]int{{0}}
	player := &entities.Unit{IsPlayer: true}
	ai := &entities.Unit{IsPlayer: false}
	// AI 单位占位(0x80)阻挡玩家
	m[0][0] = 0x80
	if !w.isBlocked(Pos{0, 0}, player, m) {
		t.Error("0x80 位应阻挡玩家")
	}
	if w.isBlocked(Pos{0, 0}, ai, m) {
		t.Error("0x80 位不应阻挡 AI 自身")
	}
	// 玩家单位占位(0x40)阻挡 AI
	m[0][0] = 0x40
	if !w.isBlocked(Pos{0, 0}, ai, m) {
		t.Error("0x40 位应阻挡 AI")
	}
}

// TestGetCellNeedMoves 验证地形移动消耗
func TestGetCellNeedMoves(t *testing.T) {
	w := newTestWorld(t)
	gid := firstGeneralID(t, w)
	m := makePlainMap()
	// 无神速、无适性：平原2 水6 不可达120
	if v := w.GetCellNeedMoves(2, gid, m, Pos{0, 0}); v != 2 {
		t.Errorf("平原应消耗2，实际 %d", v)
	}
	if v := w.GetCellNeedMoves(16, gid, m, Pos{0, 0}); v != 6 {
		t.Errorf("水域应消耗6，实际 %d", v)
	}
	if v := w.GetCellNeedMoves(0, gid, m, Pos{0, 0}); v != 120 {
		t.Errorf("未知地形应返回120，实际 %d", v)
	}
	// 山地(6)：基础6 减去神速/山适性，下限2
	if v := w.GetCellNeedMoves(6, gid, m, Pos{0, 0}); v < 2 || v > 6 {
		t.Errorf("山地消耗应在 [2,6]，实际 %d", v)
	}
	// 给武将加神速技能后，山地消耗应降低
	g := w.General(gid)
	if len(g.Skills) < 3 {
		g.Skills = make([]int, 5)
	}
	before := w.GetCellNeedMoves(6, gid, m, Pos{0, 0})
	g.Skills[2] |= 1 << (10 - 5) // 神速
	after := w.GetCellNeedMoves(6, gid, m, Pos{0, 0})
	if after > before {
		t.Errorf("神速后山地消耗不应升高: before=%d after=%d", before, after)
	}
	if after < 2 {
		t.Errorf("神速下山地消耗应>=2，实际 %d", after)
	}
}

// firstGeneralID 返回世界第一个武将 id
func firstGeneralID(t *testing.T, w *World) int {
	t.Helper()
	for id := range w.Generals {
		return id
	}
	t.Fatal("无武将")
	return 0
}

// TestGetMovableCellsAstar 验证可达格子
func TestGetMovableCellsAstar(t *testing.T) {
	w := newTestWorld(t)
	gid := firstGeneralID(t, w)
	m := makePlainMap()
	unit := &entities.Unit{GenID: gid, IsPlayer: true, ArrayPosX: 10, ArrayPosY: 9, MoveBonus: 10}
	cells := w.GetMovableCellsAstar(unit, m)
	if len(cells) == 0 {
		t.Fatal("可达格子不应为空")
	}
	// 所有可达格子不越界
	for pos := range cells {
		if pos.X < 0 || pos.X >= 32 || pos.Y < 0 || pos.Y >= 19 {
			t.Errorf("可达格子越界: %v", pos)
		}
	}
	// 剩余移动力应非负
	for _, remain := range cells {
		if remain < 0 {
			t.Errorf("剩余移动力不应为负: %d", remain)
		}
	}
}

// TestGetPathToTarget 验证路径
func TestGetPathToTarget(t *testing.T) {
	w := newTestWorld(t)
	gid := firstGeneralID(t, w)
	m := makePlainMap()
	unit := &entities.Unit{GenID: gid, IsPlayer: true, ArrayPosX: 5, ArrayPosY: 5, MoveBonus: 10}
	target := Pos{8, 5} // 水平距离3
	path := w.GetPathToTarget(target, unit, m, true)
	if len(path) == 0 {
		t.Fatal("应有路径")
	}
	if path[0] != (Pos{5, 5}) {
		t.Errorf("路径首格应为起点，实际 %v", path[0])
	}
	if path[len(path)-1] != target {
		t.Errorf("路径末格应为目标，实际 %v", path[len(path)-1])
	}
	// 相邻格连续
	for i := 1; i < len(path); i++ {
		if !IsAdjacent(path[i-1], path[i]) {
			t.Errorf("路径 %d 处不连续: %v -> %v", i, path[i-1], path[i])
		}
	}
	// 起点即目标
	if p := w.GetPathToTarget(unitPos(unit), unit, m, true); len(p) != 1 {
		t.Errorf("起点即目标应返回单格，实际 %d", len(p))
	}
}

func unitPos(u *entities.Unit) Pos {
	return Pos{u.ArrayPosX, u.ArrayPosY}
}

// TestRemoveContainsPos 验证切片操作
func TestRemoveContainsPos(t *testing.T) {
	s := []Pos{{1, 1}, {2, 2}, {3, 3}}
	if !containsPos(s, Pos{2, 2}) {
		t.Error("应包含 (2,2)")
	}
	if containsPos(s, Pos{9, 9}) {
		t.Error("不应包含 (9,9)")
	}
	r := removeFromSlice(s, Pos{2, 2})
	if len(r) != 2 || r[0] != (Pos{1, 1}) || r[1] != (Pos{3, 3}) {
		t.Errorf("删除后应剩 (1,1),(3,3)，实际 %v", r)
	}
	// 删除不存在的元素返回原切片
	if r2 := removeFromSlice(s, Pos{9, 9}); len(r2) != 3 {
		t.Errorf("删除不存在元素应返回原切片，实际 %d", len(r2))
	}
}
