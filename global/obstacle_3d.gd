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

enum _State { NORMAL, ARC, UNDERSIDE }
var _state: _State = _State.NORMAL
var _arc_center: Vector3
var _arc_angle: float = 0.0
var _arc_dir: float = 1.0
var _arc_radius: float = 1.0
var _underside_timer: float = 0.0
const _UNDERSIDE_LIFETIME: float = 16.0

var _conveyor_end_x: float = 0.0
var _conveyor_center_y: float = -0.5
var _conveyor_half_height: float = 1.0
var _has_conveyor_info: bool = false

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

	match _state:
		_State.NORMAL:
			_vel_y -= _GRAVITY * delta
			var motion: Vector3 = move_direction * move_speed * delta + Vector3(0, _vel_y * delta, 0)
			var col: KinematicCollision3D = move_and_collide(motion)
			if col != null and col.get_normal().y > 0.5:
				_vel_y = 0.0
			if _has_conveyor_info and _passed_end():
				_start_arc()
			elif global_position.y < -4.0:
				_die()
				return

		_State.ARC:
			var angular_speed: float = move_speed / _arc_radius
			_arc_angle += _arc_dir * angular_speed * delta
			global_position.x = _arc_center.x + cos(_arc_angle) * _arc_radius
			global_position.y = _arc_center.y + sin(_arc_angle) * _arc_radius
			if _arc_dir > 0.0 and _arc_angle >= PI * 1.5:
				_begin_underside()
			elif _arc_dir < 0.0 and _arc_angle <= -PI / 2.0:
				_begin_underside()

		_State.UNDERSIDE:
			_underside_timer += delta
			if _underside_timer >= _UNDERSIDE_LIFETIME:
				queue_free()
				return
			global_position.x += -move_direction.x * move_speed * delta

	var safe_delta: float = max(delta, 0.0001)
	current_velocity = (global_position - _last_position) / safe_delta
	_last_position = global_position


func _passed_end() -> bool:
	# True once the obstacle has crossed the conveyor's far edge in its travel direction
	return (global_position.x - _conveyor_end_x) * move_direction.x > 0.0


func _start_arc() -> void:
	_state = _State.ARC
	# Arc center at conveyor bottom so obstacle ends fully below the conveyor
	var conveyor_bottom_y: float = _conveyor_center_y - _conveyor_half_height
	_arc_center = Vector3(_conveyor_end_x, conveyor_bottom_y, global_position.z)
	var local: Vector3 = global_position - _arc_center
	_arc_angle = atan2(local.y, local.x)
	_arc_radius = Vector2(local.x, local.y).length()
	_arc_dir = -1.0 if move_direction.x > 0.0 else 1.0


func _begin_underside() -> void:
	_state = _State.UNDERSIDE
	global_position.y = _arc_center.y - _arc_radius
	remove_from_group("obstacle")
	remove_from_group("item")
	_underside_timer = 0.0


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


func get_current_velocity() -> Vector3:
	return current_velocity


func set_movement(direction: Vector3, speed: float) -> void:
	move_direction = direction
	move_speed = speed


func set_conveyor_info(end_x: float, center_y: float, height: float) -> void:
	_conveyor_end_x = end_x
	_conveyor_center_y = center_y
	_conveyor_half_height = height / 2.0
	_has_conveyor_info = true


func get_rope_push_data() -> Dictionary:
	return {"hx": rope_push_half_x, "hy": rope_push_half_y, "hz": rope_push_half_z, "yo": rope_push_y_offset}
