extends Sprite


var speed = 200;

var dir = Vector2()


func _ready() -> void :
	pass

remote func _set_position(pos):
	position = pos;

func _process(delta: float) -> void :
	dir = Vector2()
	
	if (Input.is_action_pressed("ui_up")):
		dir.y -= 1;
	elif (Input.is_action_pressed("ui_down")):
		dir.y += 1;
	if (Input.is_action_pressed("ui_left")):
		dir.x -= 1;
	elif (Input.is_action_pressed("ui_right")):
		dir.x += 1;
	dir = dir.normalized();
	
	if (dir != Vector2()):
		if (is_network_master()):
			position += speed * dir * delta;
		rpc("_set_position", position);
	pass
