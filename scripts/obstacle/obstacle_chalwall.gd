extends AnimatableBody3D

@export var move_speed: float = 1.0
@export var move_direction: Vector3 = Vector3(-1, 0, 0)

var _dying: bool = false
var _falling: bool = false
var _fall_velocity: float = 0.0
const GRAVITY: float = 9.8

func _ready() -> void:
	add_to_group("obstacle")
	add_to_group("item")

func _physics_process(delta: float) -> void:
	if _dying:
		return
	if _falling:
		_fall_velocity += GRAVITY * delta
		global_position.y -= _fall_velocity * delta
	else:
		global_position += move_direction * move_speed * delta
	if global_position.y < -4.0:
		_die()

func _die() -> void:
	if _dying:
		return
	_dying = true
	queue_free()

func set_movement(direction: Vector3, speed: float) -> void:
	move_direction = direction
	move_speed = speed

func start_falling() -> void:
	if _falling:
		return
	_falling = true
	move_direction = Vector3.ZERO
