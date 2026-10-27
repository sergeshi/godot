extends CharacterBody2D
class_name RPGPlayer

## Top-down movement controller. Supports keyboard movement and click-to-move.
signal arrived_at_destination

@export var move_speed: float = 205.0
@export var click_arrival_radius: float = 9.0
var destination: Vector2
var click_move_enabled := true
var movement_locked := false

func _ready() -> void:
	destination = global_position
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if movement_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var keyboard := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if keyboard.length_squared() > 0.01:
		destination = global_position
		velocity = keyboard.normalized() * move_speed
	else:
		var offset := destination - global_position
		if click_move_enabled and offset.length() > click_arrival_radius:
			velocity = offset.normalized() * minf(move_speed, offset.length() * 5.0)
		else:
			velocity = Vector2.ZERO
			if offset.length() <= click_arrival_radius:
				arrived_at_destination.emit()
	move_and_slide()

func set_destination(world_position: Vector2) -> void:
	destination = world_position

func stop() -> void:
	destination = global_position
	velocity = Vector2.ZERO

func _draw() -> void:
	# Simple placeholder character silhouette; replace with sprite/animated rig.
	draw_circle(Vector2(0, 3), 13.0, Color(0.05, 0.06, 0.07, 0.35))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-9, -2), Vector2(-8, -13), Vector2(-4, -18),
		Vector2(5, -18), Vector2(9, -11), Vector2(10, 1),
		Vector2(7, 12), Vector2(-7, 12)
	]), Color("#c5b7a0"))
	draw_circle(Vector2(0, -22), 8.5, Color("#d9c9b2"))
	draw_arc(Vector2(0, -22), 8.5, PI, TAU, 16, Color("#393c40"), 4.0)
	draw_line(Vector2(-7, -3), Vector2(-12, 8), Color("#363b42"), 4.0)
	draw_line(Vector2(7, -3), Vector2(12, 8), Color("#363b42"), 4.0)
