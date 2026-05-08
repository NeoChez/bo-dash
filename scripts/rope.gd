extends Node2D

@export var player_a_path: NodePath
@export var player_b_path: NodePath

@export_group("Rope Shape")
@export var auto_rest_length: bool = false
@export var rest_length_buffer: float = 200.0
@export var segment_count: int = 28
@export var rest_length: float = 1500.0
@export var max_length: float = 1900.0
@export var rope_gravity: Vector2 = Vector2(0, 240)
@export var air_damping: float = 0.985
@export var iterations: int = 32

@export_group("Player Pull (when taut)")
@export var spring_constant: float = 4.0
@export var hard_spring_constant: float = 18.0
@export var damping: float = 1.6

@export_group("Obstacle Interaction")
@export var obstacle_collision_mask: int = 4
@export var obstacle_radius: float = 40.0
@export var rope_thickness: float = 14.0

@onready var line: Line2D = $Line2D

var _player_a: Node2D
var _player_b: Node2D
var _points: PackedVector2Array = PackedVector2Array()
var _prev_points: PackedVector2Array = PackedVector2Array()
var _segment_length: float = 1.0
var _shape_query: PhysicsShapeQueryParameters2D
var _circle: CircleShape2D

func _ready() -> void:
	_player_a = get_node_or_null(player_a_path)
	_player_b = get_node_or_null(player_b_path)
	if auto_rest_length and _player_a != null and _player_b != null:
		var d := _player_a.global_position.distance_to(_player_b.global_position)
		rest_length = d + rest_length_buffer
		if max_length < rest_length + 100.0:
			max_length = rest_length + 400.0
	_segment_length = rest_length / float(maxi(segment_count - 1, 1))
	_init_points()
	_init_shape_query()
	if _player_a and _player_a.has_signal("fell_into_pit"):
		_player_a.fell_into_pit.connect(_on_player_respawned)
	if _player_b and _player_b.has_signal("fell_into_pit"):
		_player_b.fell_into_pit.connect(_on_player_respawned)

func _on_player_respawned(_p) -> void:
	# Re-snap verlet points to current player positions so rope doesn't drag
	# from the old (off-conveyor / falling) location to the spawn point.
	call_deferred("_init_points")

func _init_shape_query() -> void:
	_circle = CircleShape2D.new()
	_circle.radius = rope_thickness
	_shape_query = PhysicsShapeQueryParameters2D.new()
	_shape_query.shape = _circle
	_shape_query.collide_with_areas = false
	_shape_query.collide_with_bodies = true
	_shape_query.collision_mask = obstacle_collision_mask

func _init_points() -> void:
	if _player_a == null or _player_b == null:
		return
	_points.resize(segment_count)
	_prev_points.resize(segment_count)
	var a := _player_a.global_position
	var b := _player_b.global_position
	for i in range(segment_count):
		var t := float(i) / float(segment_count - 1)
		_points[i] = a.lerp(b, t)
		_prev_points[i] = _points[i]

func reset_rope() -> void:
	_init_points()

func _physics_process(delta: float) -> void:
	if _player_a == null or _player_b == null:
		return
	if _points.size() != segment_count:
		_init_points()

	for i in range(1, segment_count - 1):
		var current := _points[i]
		var vel := (current - _prev_points[i]) * air_damping
		var new_pos := current + vel + rope_gravity * delta * delta
		_prev_points[i] = current
		_points[i] = new_pos

	var space := get_world_2d().direct_space_state
	for it in range(iterations):
		_points[0] = _player_a.global_position
		_points[segment_count - 1] = _player_b.global_position
		_solve_distance()
		if it % 4 == 0:
			_resolve_collisions(space)

	_apply_player_pull(delta)
	_render_line()

func _solve_distance() -> void:
	for i in range(segment_count - 1):
		var p1 := _points[i]
		var p2 := _points[i + 1]
		var diff := p2 - p1
		var dist := diff.length()
		if dist < 0.0001:
			continue
		var error := dist - _segment_length
		var dir := diff / dist
		var p1_pinned := (i == 0)
		var p2_pinned := (i + 1 == segment_count - 1)
		if p1_pinned and p2_pinned:
			continue
		elif p1_pinned:
			_points[i + 1] = p2 - dir * error
		elif p2_pinned:
			_points[i] = p1 + dir * error
		else:
			var correction := dir * error * 0.5
			_points[i] = p1 + correction
			_points[i + 1] = p2 - correction

func _resolve_collisions(space: PhysicsDirectSpaceState2D) -> void:
	if space == null or _shape_query == null:
		return
	for i in range(1, segment_count - 1):
		_shape_query.transform = Transform2D(0.0, _points[i])
		var hits := space.intersect_shape(_shape_query, 4)
		for hit in hits:
			var col = hit.get("collider")
			if col == null or not col is Node2D:
				continue
			var to_point: Vector2 = _points[i] - col.global_position
			var len := to_point.length()
			var dir: Vector2
			if len < 0.0001:
				dir = Vector2.UP
			else:
				dir = to_point / len
			var push_to: float = obstacle_radius + rope_thickness
			if len < push_to:
				_points[i] = col.global_position + dir * push_to

func _apply_player_pull(delta: float) -> void:
	var pos_a: Vector2 = _player_a.global_position
	var pos_b: Vector2 = _player_b.global_position
	var diff: Vector2 = pos_b - pos_a
	var dist: float = diff.length()
	if dist <= rest_length or dist < 0.001:
		return
	var dir: Vector2 = diff / dist
	var stretch: float = dist - rest_length
	var force_mag: float = stretch * spring_constant
	if dist > max_length:
		force_mag += (dist - max_length) * hard_spring_constant

	var vel_a: Vector2 = Vector2.ZERO
	var vel_b: Vector2 = Vector2.ZERO
	if "velocity" in _player_a:
		vel_a = _player_a.velocity
	if "velocity" in _player_b:
		vel_b = _player_b.velocity
	var rel_vel_along: float = (vel_b - vel_a).dot(dir)
	var damp_force: float = maxf(rel_vel_along * damping, 0.0)

	var total_impulse: float = (force_mag + damp_force) * delta
	if _player_a.has_method("apply_rope_force"):
		_player_a.apply_rope_force(dir * total_impulse)
	if _player_b.has_method("apply_rope_force"):
		_player_b.apply_rope_force(-dir * total_impulse)

func _render_line() -> void:
	if line == null:
		return
	line.clear_points()
	for p in _points:
		line.add_point(line.to_local(p))
