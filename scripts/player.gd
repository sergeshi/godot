extends CharacterBody3D
class_name RPGPlayer

## Third-person/isometric 3D movement controller with click-to-move.
signal arrived_at_destination

@export var move_speed: float = 5.2
@export var click_arrival_radius: float = 0.16
var destination: Vector3
var click_move_enabled := true
var movement_locked := false

func _ready() -> void:
	destination = global_position

func _physics_process(_delta: float) -> void:
	if movement_locked:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keyboard.length_squared() > 0.01:
		destination = global_position
		velocity = Vector3(keyboard.x, 0.0, keyboard.y).normalized() * move_speed
	else:
		var offset := destination - global_position
		offset.y = 0.0
		if click_move_enabled and offset.length() > click_arrival_radius:
			var direction := offset.normalized()
			velocity = Vector3(direction.x, 0.0, direction.z) * minf(move_speed, offset.length() * 4.0)
		else:
			velocity = Vector3.ZERO
			if offset.length() <= click_arrival_radius:
				arrived_at_destination.emit()
	move_and_slide()
	if is_on_floor():
		global_position.y = 0.0

func set_destination(world_position: Vector3) -> void:
	destination = world_position
	destination.y = 0.0

func stop() -> void:
	destination = global_position
	velocity = Vector3.ZERO
