extends Node3D

@export var player_a_path: NodePath
@export var player_b_path: NodePath
@export var line_path: NodePath

@export var rest_length: float = 18.0
@export var max_length: float = 26.0
@export var pull_strength: float = 0.9
@export var damping: float = 0.15
@export var sag_amount: float = 0.7
@export var rope_radius: float = 0.08
@export var player_a_offset: Vector3 = Vector3(0, 1.2, 0)
@export var player_b_offset: Vector3 = Vector3(0, 1.2, 0)

var player_a: Node
var player_b: Node
var rope_line: Node

func _ready() -> void:
	player_a = get_node_or_null(player_a_path)
	player_b = get_node_or_null(player_b_path)
	rope_line = get_node_or_null(line_path)

	var rope_node = rope_line as Node3D
	if rope_node:
		rope_node.top_level = true
		rope_node.global_position = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if player_a == null or player_b == null:
		return

	var a_node = player_a as Node3D
	var b_node = player_b as Node3D
	if a_node == null or b_node == null:
		return

	var a_pos = a_node.global_position + a_node.global_basis * player_a_offset
	var b_pos = b_node.global_position + b_node.global_basis * player_b_offset
	_update_rope_line(a_pos, b_pos)
	_apply_rope_tension(a_pos, b_pos, delta)

func _apply_rope_tension(a_pos: Vector3, b_pos: Vector3, delta: float) -> void:
	var a_alive = player_a.get("is_alive")
	var b_alive = player_b.get("is_alive")
	if a_alive == false or b_alive == false:
		return
	var a_grace = player_a.get("rope_grace_timer")
	var b_grace = player_b.get("rope_grace_timer")
	if (a_grace != null and a_grace > 0.0) or (b_grace != null and b_grace > 0.0):
		return

	var delta_vec = b_pos - a_pos
	var distance = delta_vec.length()
	if distance <= rest_length:
		return

	var stretch = min(distance - rest_length, max_length)
	var dir = delta_vec.normalized()
	var pull = dir * (stretch * pull_strength) * delta

	if player_a.has_method("apply_rope_pull"):
		player_a.apply_rope_pull(pull)
	if player_b.has_method("apply_rope_pull"):
		player_b.apply_rope_pull(-pull)

	if damping > 0.0:
		if player_a is CharacterBody3D:
			player_a.velocity *= (1.0 - damping * delta)
		if player_b is CharacterBody3D:
			player_b.velocity *= (1.0 - damping * delta)

func _update_rope_line(a_pos: Vector3, b_pos: Vector3) -> void:
	if rope_line == null:
		return
	if not rope_line.has_method("clear_points"):
		_update_rope_mesh(a_pos, b_pos)
		return

	rope_line.clear_points()
	var mid = (a_pos + b_pos) * 0.5
	mid.y -= sag_amount
	rope_line.add_point(a_pos)
	rope_line.add_point(mid)
	rope_line.add_point(b_pos)

func _update_rope_mesh(a_pos: Vector3, b_pos: Vector3) -> void:
	var rope_mesh = rope_line as MeshInstance3D
	if rope_mesh == null:
		return

	var delta_vec = b_pos - a_pos
	var distance = delta_vec.length()
	if distance <= 0.01:
		rope_mesh.visible = false
		return

	rope_mesh.visible = true
	var mid = (a_pos + b_pos) * 0.5
	mid.y -= sag_amount * 0.5
	var dir = delta_vec.normalized()

	rope_mesh.global_position = mid
	rope_mesh.global_basis = _basis_from_y(dir)
	_apply_mesh_dimensions(rope_mesh, distance)

func _apply_mesh_dimensions(rope_mesh: MeshInstance3D, distance: float) -> void:
	var mesh = rope_mesh.mesh
	if mesh is CylinderMesh:
		mesh.height = distance
		mesh.top_radius = rope_radius
		mesh.bottom_radius = rope_radius
	elif mesh is CapsuleMesh:
		mesh.height = distance
		mesh.radius = rope_radius
	elif mesh is BoxMesh:
		mesh.size = Vector3(rope_radius * 2.0, distance, rope_radius * 2.0)

func _basis_from_y(dir: Vector3) -> Basis:
	var up = Vector3.UP
	if abs(dir.dot(up)) > 0.95:
		up = Vector3.FORWARD
	var x = up.cross(dir).normalized()
	var z = dir.cross(x).normalized()
	return Basis(x, dir, z)
