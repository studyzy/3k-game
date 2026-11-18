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
