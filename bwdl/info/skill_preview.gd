# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：info/skill_preview.gd
# 说明：信息面板-技能预览。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

extends Panel

func _draw() -> void :
	var points = []
	points.append(Vector2(0, 0))
	points.append(Vector2(rect_size.x, 0))
	points.append(rect_size)
	points.append(Vector2(0, rect_size.y))
	points.append(Vector2(0, 0))
	draw_polyline(points, Color.white, 2)
	draw_line(Vector2(20, 70), Vector2(480, 70), Color.white, 2)
	return
