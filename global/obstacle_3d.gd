extends AnimatableBody3D

@export var move_speed: float = 8.0
@export var move_direction: Vector3 = Vector3(-1, 0, 0)
@export var auto_move: bool = true
@export var is_full_width: bool = false

@export_group("Rope Collision")
@export var rope_push_half_x: float = 2.1
@export var rope_push_half_y: float = 0.75
@export var rope_push_half_z: float = 1.6
@export var rope_push_y_offset: float = 0.75

var current_velocity: Vector3 = Vector3.ZERO
var _last_position: Vector3 = Vector3.ZERO
var _vel_y: float = 0.0
var _dying: bool = false

const _GRAVITY: float = 16.0


func _ready() -> void:
	if not is_in_group("obstacle"):
		add_to_group("obstacle")
	if not is_in_group("item"):
		add_to_group("item")
	_last_position = global_position


func _physics_process(delta: float) -> void:
	if _dying:
		return

	_vel_y -= _GRAVITY * delta
	global_position += move_direction * move_speed * delta
	var vertical_motion := Vector3(0, _vel_y * delta, 0)
	var col: KinematicCollision3D = move_and_collide(vertical_motion)
	if col != null and col.get_normal().y > 0.5:
		_vel_y = 0.0

	if global_position.y < -15.0:
		_die()
		return

	var safe_delta: float = max(delta, 0.0001)
	current_velocity = (global_position - _last_position) / safe_delta
	_last_position = global_position


func _die() -> void:
	if _dying:
		return
	_dying = true
	remove_from_group("obstacle")
	remove_from_group("item")
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()


func start_fall() -> void:
	if _dying:
		return
	move_direction = Vector3.ZERO
	move_speed = 0.0


func get_current_velocity() -> Vector3:
	return current_velocity


func set_movement(direction: Vector3, speed: float) -> void:
	move_direction = direction
	move_speed = speed


func get_rope_push_data() -> Dictionary:
	return {"hx": rope_push_half_x, "hy": rope_push_half_y, "hz": rope_push_half_z, "yo": rope_push_y_offset}
