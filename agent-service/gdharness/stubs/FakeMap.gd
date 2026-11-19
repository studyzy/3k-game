extends Reference
# 只在几个固定格子上给非平原地形，其余一律平原。
# 地形投影只列非平原格，所以这些格子必须能出现在 payload 的 terrain 里。
var blocks = {
	Vector2(9, 15): "树林",
	Vector2(10, 15): "米屋",
	Vector2(3, 4): "河流",
}
var aStar = null

func _init():
	aStar = load("res://stubs/FakeAStar.gd").new()

func is_valid_position(p): return p.x >= 0 and p.x < 32 and p.y >= 0 and p.y < 19
func get_blockCN_by_position(p):
	if blocks.has(Vector2(int(p.x), int(p.y))):
		return blocks[Vector2(int(p.x), int(p.y))]
	return "平原"
func get_buildCN_by_position(p):
	return ""
func get_position_by_buildCN(n): return Vector2(3, 9)