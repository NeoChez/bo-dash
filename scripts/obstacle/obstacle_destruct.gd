extends AnimatableBody3D

@export var move_speed: float = 1.0
@export var move_direction: Vector3 = Vector3(-1, 0, 0)

var _dying: bool = false
var _falling: bool = false
var _fall_velocity: float = 0.0
const GRAVITY: float = 9.8

var _right_broken: bool = false
var _left_broken: bool = false

@onready var _col_undestruct: CollisionShape3D = $CollisionShape3D_undestruct
@onready var _col_right: CollisionShape3D = $CollisionShape3D_right
@onready var _col_left: CollisionShape3D = $CollisionShape3D_left
@onready var _visual_right: Node3D = $destructible
@onready var _visual_left: Node3D = $destructible2

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

# Called from player_3d._check_collisions().
# Returns true  → trigger normal FALLING state on the player.
# Returns false → obstacle handled the interaction (block or break); no FALLING.
func on_player_collision(player: Node3D, collision: KinematicCollision3D) -> bool:
	var zone := _get_hit_zone(collision)
	match zone:
		"center":
			return true
		"right":
			if not _right_broken and player.is_dashing():
				_break_wall("right", player)
			return false
		"left":
			if not _left_broken and player.is_dashing():
				_break_wall("left", player)
			return false
	return false

func _get_hit_zone(collision: KinematicCollision3D) -> String:
	var local_z := to_local(collision.get_position()).z
	if local_z < -4.0:
		return "right"
	if local_z > 4.0:
		return "left"
	return "center"

func _break_wall(side: String, player: Node3D) -> void:
	if side == "right":
		_right_broken = true
		if _col_right:
			_col_right.set_deferred("disabled", true)
		if _visual_right:
			_spawn_break_particles(_visual_right.global_position)
			_visual_right.visible = false
	else:
		_left_broken = true
		if _col_left:
			_col_left.set_deferred("disabled", true)
		if _visual_left:
			_spawn_break_particles(_visual_left.global_position)
			_visual_left.visible = false
	# Small velocity rebound so player feels impact while passing through
	player.velocity *= 0.7

func _spawn_break_particles(world_pos: Vector3) -> void:
	var scene_root := get_tree().current_scene
	if not scene_root:
		return
	var particles := CPUParticles3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.1
	sphere.height = 0.2
	particles.mesh = sphere
	scene_root.add_child(particles)
	particles.global_position = world_pos
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 30
	particles.lifetime = 0.9
	particles.spread = 55.0
	particles.direction = Vector3(0, 1, 0)
	particles.gravity = Vector3(0, -9.8, 0)
	particles.initial_velocity_min = 4.0
	particles.initial_velocity_max = 10.0
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.2
	var color_ramp := Gradient.new()
	color_ramp.set_color(0, Color(0.85, 0.75, 0.55, 1.0))
	color_ramp.set_color(1, Color(0.6, 0.5, 0.35, 0.0))
	particles.color_ramp = color_ramp
	get_tree().create_timer(particles.lifetime + 0.5).timeout.connect(particles.queue_free)
