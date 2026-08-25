# ==============================================================================
# 霸王的大陆（三国志2 复刻版）- 反编译工程
# 文件：cheat/cityicon.gd
# 说明：作弊面板-城市图标。
# 注：本文件由 GDRETools 从原版 APK 反编译而来，注释为后续添加，仅供学习研究。
# ==============================================================================

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
