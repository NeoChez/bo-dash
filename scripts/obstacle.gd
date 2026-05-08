extends AnimatableBody2D

@export var move_speed: float = 220.0
@export var move_direction: Vector2 = Vector2.LEFT
@export var lifetime: float = 14.0
@export var fall_when_off_conveyor: bool = true

const GRAVITY: float = 1400.0
const CONVEYOR_LAYER_MASK: int = 8
const DESPAWN_Y: float = 1600.0

var _alive_time: float = 0.0
var _fall_velocity_y: float = 0.0
var _conveyor_query: PhysicsPointQueryParameters2D

func _ready() -> void:
	add_to_group("obstacle")
	# Keep sync_to_physics OFF here so set position from spawner is honored
	# without the engine teleport-from-origin glitch.
	sync_to_physics = false
	_conveyor_query = PhysicsPointQueryParameters2D.new()
	_conveyor_query.collide_with_areas = true
	_conveyor_query.collide_with_bodies = false
	_conveyor_query.collision_mask = CONVEYOR_LAYER_MASK
	print("[Obstacle] _ready at global=", global_position, " dir=", move_direction, " speed=", move_speed)

func _physics_process(delta: float) -> void:
	if fall_when_off_conveyor:
		_conveyor_query.position = global_position
		var hits := get_world_2d().direct_space_state.intersect_point(_conveyor_query, 1)
		if hits.is_empty():
			_fall_velocity_y += GRAVITY * delta
		else:
			_fall_velocity_y = 0.0

	position.x += move_direction.x * move_speed * delta
	position.y += move_direction.y * move_speed * delta + _fall_velocity_y * delta

	_alive_time += delta
	if _alive_time > lifetime:
		queue_free()
	elif global_position.y > DESPAWN_Y:
		queue_free()
