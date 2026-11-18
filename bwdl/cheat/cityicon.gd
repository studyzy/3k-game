extends Panel


const POINTS = [
	Vector2(10, 25), 
	Vector2(28, 25), 
	Vector2(28, 10), 
	Vector2(52, 10), 
	Vector2(52, 25), 
	Vector2(70, 25), 
	Vector2(70, 50), 
	Vector2(10, 50), 
]


const BG_COLOR = Color("#CCA1D5E3")


export var fill_color = Color.red

export var border_color = Color.blue

func _ready():
	return

func _draw() -> void :
	
	draw_rect(Rect2(Vector2.ZERO, rect_size), BG_COLOR)

	
	draw_polygon(POINTS, [fill_color])

	
	draw_polyline(POINTS + [POINTS[0]], border_color, 10)
	return
