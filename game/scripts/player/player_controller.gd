extends CharacterBody2D

@export var move_speed := 220.0
@export var room_bounds := Rect2(Vector2(48, 96), Vector2(544, 240))


func _physics_process(_delta: float) -> void:
	var input_vector := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = input_vector * move_speed
	move_and_slide()
	global_position = Vector2(
		clamp(global_position.x, room_bounds.position.x, room_bounds.end.x),
		clamp(global_position.y, room_bounds.position.y, room_bounds.end.y)
	)
