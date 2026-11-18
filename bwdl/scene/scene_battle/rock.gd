extends Node2D

export var direction: = Vector2.DOWN
export var distance: = 40.0
export var speed: = 100.0
export var from: = Vector2(40, 0)

signal done

func _ready():
	$status.hide()
	$anim.stop(true)
	return

func play():
	position = from
	if direction == Vector2.UP:
		$status / sprite.flip_v = true
	$anim.playback_speed = 1.0 / Engine.time_scale
	$anim.play("rock")
	return

func _physics_process(delta):
	if distance > 0:
		var movement = direction * speed * delta / Engine.time_scale
		position += movement
		distance -= movement.length()
	else:
		$anim.stop()
		emit_signal("done")
		queue_free()
	return
