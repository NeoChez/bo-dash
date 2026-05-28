extends Node3D

@export var player_a_path: NodePath
@export var player_b_path: NodePath

@export_category("Rope Physics")
## Must match actual arena scale. Players start ~60 units apart; belt pushes them in.
## Rope is slack when dist < rope_max_length, tension begins once they pull apart past this.
@export var rope_max_length: float = 25.0
## Primary spring: gentle pull per unit of stretch. Tuned to match 2D prototype feel.
@export var spring_strength: float = 8.0
## Extra units past rope_max_length before the emergency correction kicks in.
@export var hard_limit_extra: float = 5.0
## Damps SEPARATING velocity only — gives rope pull some punch without fighting closing motion.
@export var damping_strength: float = 2.0
## Force multiplier applied when either player is actively dashing — the Kinetic Yank.
@export var dash_yank_multiplier: float = 5.0
## Grace period after respawn/game-start before tension is applied (seconds).
@export var grace_duration: float = 2.0
## Seconds after grace ends to ramp spring from 0 to full — prevents snap-to-center on respawn.
@export var tension_ramp_duration: float = 3.0
@export var segment_iterations: int = 20
@export var gravity_scale: float = 70.0
@export var velocity_damping: float = 0.98

@export_category("Rope Appearance")
@export var segment_count: int = 16
@export var rope_radius: float = 0.055
@export var rope_color: Color = Color(0.6, 0.48, 0.32, 1)

@export_category("Attachment")
@export var player_a_offset: Vector3 = Vector3(0, 1.2, 0)
@export var player_b_offset: Vector3 = Vector3(0, 1.2, 0)

var player_a: CharacterBody3D
var player_b: CharacterBody3D
var points: PackedVector3Array
var prev_points: PackedVector3Array
var segment_meshes: Array[MeshInstance3D] = []
var segment_rest_length: float
var _rope_mat: StandardMaterial3D

var _grace_timer: float = 0.0
var _tension_ramp: float = 0.0
var _a_was_alive: bool = true
var _b_was_alive: bool = true


func _ready() -> void:
	add_to_group("player_rope")
	player_a = get_node_or_null(player_a_path) as CharacterBody3D
	player_b = get_node_or_null(player_b_path) as CharacterBody3D
	segment_rest_length = rope_max_length / float(segment_count)
	_grace_timer = grace_duration
	_tension_ramp = 0.0
	_init_rope()
	_build_segment_meshes()


func _init_rope() -> void:
	points.resize(segment_count + 1)
	prev_points.resize(segment_count + 1)
	var start := _attach_pos(player_a, player_a_offset, Vector3(-20, 1.5, 0))
	var end := _attach_pos(player_b, player_b_offset, Vector3(-80, 1.5, 0))
	for i in range(segment_count + 1):
		var t := float(i) / float(segment_count)
		var p := start.lerp(end, t)
		points[i] = p
		prev_points[i] = p


func _attach_pos(player: CharacterBody3D, offset: Vector3, fallback: Vector3) -> Vector3:
	if player == null:
		return fallback
	return player.global_position + player.global_basis * offset


func _build_segment_meshes() -> void:
	_rope_mat = StandardMaterial3D.new()
	_rope_mat.albedo_color = rope_color
	_rope_mat.roughness = 0.9
	_rope_mat.metallic = 0.0
	_rope_mat.emission_enabled = true
	_rope_mat.emission = Color(0, 0, 0)

	for i in range(segment_count):
		var mi := MeshInstance3D.new()
		mi.top_level = true
		var cyl := CylinderMesh.new()
		cyl.top_radius = rope_radius
		cyl.bottom_radius = rope_radius
		cyl.height = segment_rest_length
		cyl.radial_segments = 6
		cyl.cap_top = false
		cyl.cap_bottom = false
		mi.mesh = cyl
		mi.material_override = _rope_mat
		add_child(mi)
		segment_meshes.append(mi)


func _physics_process(delta: float) -> void:
	if player_a == null or player_b == null:
		return

	var a_pos := _attach_pos(player_a, player_a_offset, Vector3.ZERO)
	var b_pos := _attach_pos(player_b, player_b_offset, Vector3.ZERO)

	var a_alive: bool = player_a.get("is_alive") != false
	var b_alive: bool = player_b.get("is_alive") != false

	if (not _a_was_alive and a_alive) or (not _b_was_alive and b_alive):
		_grace_timer = grace_duration
		_tension_ramp = 0.0
		_reinit_to(a_pos, b_pos)
	_a_was_alive = a_alive
	_b_was_alive = b_alive

	if not (a_alive and b_alive):
		for mi in segment_meshes:
			mi.visible = false
		return

	var tension_ok := a_alive and b_alive and _grace_timer <= 0.0

	if _grace_timer > 0.0:
		_grace_timer -= delta
	elif _tension_ramp < 1.0:
		_tension_ramp = minf(_tension_ramp + delta / tension_ramp_duration, 1.0)

	if not _rope_is_valid():
		_reinit_to(a_pos, b_pos)

	_verlet_step(delta)

	for _i in range(segment_iterations):
		_constrain(a_pos, b_pos)
		_push_from_bodies()
	_push_from_ground()

	if tension_ok:
		_apply_player_tension(a_pos, b_pos, delta)

	_update_rope_color(a_pos, b_pos)
	_draw_rope()


func _rope_is_valid() -> bool:
	for i in range(segment_count):
		if points[i].distance_to(points[i + 1]) > segment_rest_length * 4.0:
			return false
	return true


func _reinit_to(a_pos: Vector3, b_pos: Vector3) -> void:
	for i in range(segment_count + 1):
		var t := float(i) / float(segment_count)
		var p := a_pos.lerp(b_pos, t)
		points[i] = p
		prev_points[i] = p


func _verlet_step(delta: float) -> void:
	for i in range(1, segment_count):
		var cur := points[i]
		var vel := (cur - prev_points[i]) * velocity_damping
		prev_points[i] = cur
		points[i] = cur + vel + Vector3.DOWN * gravity_scale * delta * delta


func _constrain(a_pos: Vector3, b_pos: Vector3) -> void:
	points[0] = a_pos
	points[segment_count] = b_pos

	for i in range(segment_count):
		var p0 := points[i]
		var p1 := points[i + 1]
		var diff := p1 - p0
		var dist := diff.length()
		if dist < 0.0001 or dist <= segment_rest_length:
			continue
		var correction := diff * ((dist - segment_rest_length) / dist) * 0.5
		if i > 0:
			points[i] = p0 + correction
		if i + 1 < segment_count:
			points[i + 1] = p1 - correction


func _apply_player_tension(a_pos: Vector3, b_pos: Vector3, delta: float) -> void:
	var diff_flat := Vector2(b_pos.x - a_pos.x, b_pos.z - a_pos.z)
	var dist := diff_flat.length()

	if dist <= rope_max_length or dist < 0.001:
		return

	var dir_flat := diff_flat / dist
	var dir3d := Vector3(dir_flat.x, 0.0, dir_flat.y)

	var stretch := dist - rope_max_length

	# Soft spring — smooth elastic pull proportional to stretch, ramped up after respawn
	var force := stretch * spring_strength * _tension_ramp

	# Kinetic Yank: dash amplifies the pull so snapping away yanks your opponent hard
	var a_dashing: bool = player_a.has_method("is_dashing") and player_a.is_dashing()
	var b_dashing: bool = player_b.has_method("is_dashing") and player_b.is_dashing()
	if a_dashing or b_dashing:
		force *= dash_yank_multiplier

	# Damp only separating velocity — adds punch without fighting closing motion
	var rel_vel := (player_b.velocity - player_a.velocity).dot(dir3d)
	if rel_vel > 0.0:
		force += rel_vel * damping_strength

	var impulse := dir3d * force * delta
	player_a.apply_rope_pull(impulse)
	player_b.apply_rope_pull(-impulse)


func _push_from_bodies() -> void:
	var obstacles := get_tree().get_nodes_in_group("obstacle")
	for obs_node in obstacles:
		var obs := obs_node as Node3D
		if obs == null or not is_instance_valid(obs):
			continue
		var hx: float = 2.1
		var hy: float = 0.75
		var hz: float = 1.6
		var yo: float = 0.75
		if obs.has_method("get_rope_push_data"):
			var raw: Variant = obs.call("get_rope_push_data")
			if raw is Dictionary:
				hx = float(raw.get("hx", hx))
				hy = float(raw.get("hy", hy))
				hz = float(raw.get("hz", hz))
				yo = float(raw.get("yo", yo))
		var obs_center: Vector3 = obs.global_position + Vector3(0, yo, 0)
		for i in range(1, segment_count):
			var p := points[i]
			var local: Vector3 = p - obs_center
			if abs(local.x) < hx and abs(local.z) < hz and abs(local.y) < hy:
				var pen_x: float = hx - abs(local.x)
				var pen_y: float = hy - abs(local.y)
				var pen_z: float = hz - abs(local.z)
				if pen_x <= pen_z and pen_x <= pen_y:
					local.x = hx * (1.0 if local.x >= 0.0 else -1.0)
				elif pen_z <= pen_y:
					local.z = hz * (1.0 if local.z >= 0.0 else -1.0)
				else:
					local.y = hy * (1.0 if local.y >= 0.0 else -1.0)
				points[i] = obs_center + local
				prev_points[i] = points[i]

	_push_from_player(player_a, 0.1)
	_push_from_player(player_b, 0.9)


func _push_from_ground() -> void:
	for gnd_node in get_tree().get_nodes_in_group("ground"):
		var gnd := gnd_node as StaticBody3D
		if gnd == null or not is_instance_valid(gnd):
			continue
		var col_shape: CollisionShape3D = null
		for child in gnd.get_children():
			if child is CollisionShape3D:
				col_shape = child as CollisionShape3D
				break
		if col_shape == null or not (col_shape.shape is BoxShape3D):
			continue
		var box := col_shape.shape as BoxShape3D
		var half := box.size * 0.5
		var center := col_shape.global_position
		var surface_y := center.y + half.y
		for i in range(1, segment_count):
			var p := points[i]
			if p.x < center.x - half.x or p.x > center.x + half.x:
				continue
			if p.z < center.z - half.z or p.z > center.z + half.z:
				continue
			if p.y < surface_y:
				points[i].y = surface_y
				prev_points[i].y = surface_y


func _update_rope_color(a_pos: Vector3, b_pos: Vector3) -> void:
	if _rope_mat == null:
		return
	var dist: float = Vector3(a_pos.x, 0.0, a_pos.z).distance_to(Vector3(b_pos.x, 0.0, b_pos.z))
	var t: float = clamp((dist - rope_max_length) / 6.0, 0.0, 1.0)
	_rope_mat.albedo_color = rope_color.lerp(Color(1.0, 0.15, 0.05, 1.0), t)
	_rope_mat.emission = Color(1.0, 0.3, 0.05, 1.0) * (t * 0.5)


func _push_from_player(player: CharacterBody3D, near_t: float) -> void:
	if player == null:
		return
	var body_center: Vector3 = player.global_position + Vector3(0, 1.3, 0)
	for i in range(1, segment_count):
		var t: float = float(i) / float(segment_count)
		if abs(t - near_t) < 0.2:
			continue
		var p := points[i]
		var local: Vector3 = p - body_center
		var h_dist: float = Vector2(local.x, local.z).length()
		if h_dist < 0.55 and abs(local.y) < 1.3:
			if h_dist < 0.001:
				local.x = 0.55
			else:
				var push_2d: Vector2 = Vector2(local.x, local.z).normalized() * 0.55
				local.x = push_2d.x
				local.z = push_2d.y
			points[i] = body_center + local
			prev_points[i] = points[i]


func _draw_rope() -> void:
	for i in range(segment_count):
		var mi := segment_meshes[i]
		var from := points[i]
		var to := points[i + 1]
		var diff := to - from
		var dist := diff.length()

		if dist < 0.001:
			mi.visible = false
			continue

		mi.visible = true
		mi.global_position = (from + to) * 0.5

		var dir := diff / dist
		var up := Vector3.UP if abs(dir.dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
		var x_axis := up.cross(dir).normalized()
		var z_axis := dir.cross(x_axis).normalized()
		mi.global_basis = Basis(x_axis, dir, z_axis)
		(mi.mesh as CylinderMesh).height = dist
