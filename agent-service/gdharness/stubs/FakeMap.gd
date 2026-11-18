extends Reference
func is_valid_position(p): return p.x >= 0 and p.x < 32 and p.y >= 0 and p.y < 19
func get_blockCN_by_position(p): return "平原"
func get_buildCN_by_position(p): return ""
func get_position_by_buildCN(n): return Vector2(3, 9)
