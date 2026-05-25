extends CharacterBody3D


@export_category("Player Controls")
@export var action_left: String = "ui_left"
@export var action_right: String = "ui_right"
@export var action_up: String = "ui_up"
@export var action_down: String = "ui_down"
@export var action_jump: String = "ui_accept"
@export var action_dash: String = "p1_dash"
@export var action_skill: String = "p1_skill"


const SPEED = 15
const JUMP_VELOCITY = 10.0
const KNOCKBACK_FORCE = 0
const DASH_SPEED: float = 22.0
const DASH_COOLDOWN: float = 0.7

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_alive = true
var can_move = true
var match_active = true
var spawn_position: Vector3
var rope_pull: Vector3 = Vector3.ZERO
@export_range(0.0, 1.0) var rope_resist_factor: float = 0.65

@export var player_id: int = 1

var boost_multiplier: float = 1.0
var slow_multiplier: float = 1.0
var boost_end_time: float = 0.0
var slow_end_time: float = 0.0
var yank_end_time: float = 0.0
var yank_strength: float = 0.0
var yank_source: Node3D = null
var _dash_timer: float = 0.0
var _rope_constraint_pull: Vector3 = Vector3.ZERO


@onready var animated_sprite = $AnimatedSprite3D

func _ready():
	spawn_position = global_position

func _physics_process(delta: float) -> void:
	if not match_active or not is_alive or not can_move:
		return
	
	# Terapkan gravitasi
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump (Menggunakan variabel action_jump)
	if Input.is_action_just_pressed(action_jump) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Handle dash
	if _dash_timer > 0.0:
		_dash_timer -= delta
	if Input.is_action_just_pressed(action_dash) and _dash_timer <= 0.0:
		_do_dash()

	# Handle skill use
	if Input.is_action_just_pressed(action_skill):
		get_tree().call_group("match_controller", "use_skill", player_id)

	# Dapatkan input pergerakan 8 arah menggunakan variabel export
	var input_dir = Input.get_vector(action_left, action_right, action_up, action_down)
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if input_dir != Vector2.ZERO:
		# Mainkan animasi walk jika ada input
		animated_sprite.play("walk")
		
		# Flip (balik) sprite berdasarkan arah X
		if input_dir.x < 0:
			animated_sprite.flip_h = true  # Menghadap kiri
		elif input_dir.x > 0:
			animated_sprite.flip_h = false # Menghadap kanan
	else:
		animated_sprite.stop()
	
	var speed_multiplier = _get_speed_multiplier()
	var target_speed = SPEED * speed_multiplier
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * target_speed, target_speed * delta * 10)
		velocity.z = move_toward(velocity.z, direction.z * target_speed, target_speed * delta * 10)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta * 5)

	if rope_pull != Vector3.ZERO:
		velocity.x += rope_pull.x
		velocity.z += rope_pull.z
		rope_pull = Vector3.ZERO
	if _rope_constraint_pull != Vector3.ZERO:
		velocity.x += _rope_constraint_pull.x
		velocity.z += _rope_constraint_pull.z
		_rope_constraint_pull = Vector3.ZERO

	_apply_yank_force(delta)
	
	move_and_slide()
	
	# Cek tabrakan
	_check_collisions()

func _check_collisions():
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision:
			var collider = collision.get_collider()
			
			if collider and collider.is_in_group("obstacle"):
				var push_dir = (global_position - collider.global_position).normalized()
				push_dir.y = 0 
				
				velocity.x += push_dir.x * KNOCKBACK_FORCE
				velocity.z += push_dir.z * KNOCKBACK_FORCE

func _do_dash() -> void:
	var input_dir := Input.get_vector(action_left, action_right, action_up, action_down)
	var dir: Vector3
	if input_dir.length() > 0.1:
		dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		var facing := -1.0 if animated_sprite.flip_h else 1.0
		dir = (transform.basis * Vector3(facing, 0, 0)).normalized()
	dir.y = 0.0
	velocity.x = dir.x * DASH_SPEED
	velocity.z = dir.z * DASH_SPEED
	_dash_timer = DASH_COOLDOWN

func apply_rope_pull(pull: Vector3) -> void:
	if is_on_floor():
		var flat_pull := Vector3(pull.x, 0.0, pull.z)
		if flat_pull.length_squared() > 0.0001:
			var input_dir := Input.get_vector(action_left, action_right, action_up, action_down)
			if input_dir != Vector2.ZERO:
				var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
				var pull_dir := flat_pull.normalized()
				var counter: float = clamp(-move_dir.dot(pull_dir), 0.0, 1.0)
				pull = pull * (1.0 - counter * rope_resist_factor)
	rope_pull += pull

func apply_rope_constraint(pull: Vector3) -> void:
	_rope_constraint_pull += pull

func get_move_intent_world() -> Vector3:
	var input_dir := Input.get_vector(action_left, action_right, action_up, action_down)
	if input_dir == Vector2.ZERO:
		return Vector3.ZERO
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	return direction * SPEED * _get_speed_multiplier()

func apply_powerup(powerup_type: String, duration: float, magnitude: float) -> void:
	match powerup_type:
		"speed_boost":
			_apply_speed_boost(magnitude, duration)
		"slow_opponent":
			_apply_slow_opponent(magnitude, duration)
		"yank_opponent":
			_apply_yank_opponent(magnitude, duration)

func _apply_speed_boost(multiplier: float, duration: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	boost_multiplier = max(boost_multiplier, multiplier)
	boost_end_time = max(boost_end_time, now + duration)

func _apply_slow(multiplier: float, duration: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	slow_multiplier = min(slow_multiplier, multiplier)
	slow_end_time = max(slow_end_time, now + duration)
	velocity.x *= multiplier
	velocity.z *= multiplier

func _apply_slow_opponent(multiplier: float, duration: float) -> void:
	var other = _get_other_player()
	if other:
		other._apply_slow(multiplier, duration)

func _apply_yank_opponent(strength: float, duration: float) -> void:
	var other = _get_other_player()
	if other and other.has_method("_apply_yank_from"):
		other._apply_yank_from(self, strength, duration)

func _apply_yank_from(source: Node3D, strength: float, duration: float) -> void:
	if source == null:
		return
	var now = Time.get_ticks_msec() / 1000.0
	yank_source = source
	yank_strength = max(yank_strength, strength)
	yank_end_time = max(yank_end_time, now + duration)

func _apply_yank_force(delta: float) -> void:
	if yank_source == null:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now > yank_end_time:
		yank_source = null
		yank_strength = 0.0
		return

	var dir = (yank_source.global_position - global_position).normalized()
	dir.y = 0.0
	velocity.x += dir.x * yank_strength * delta
	velocity.z += dir.z * yank_strength * delta

func _get_speed_multiplier() -> float:
	var now = Time.get_ticks_msec() / 1000.0
	var boost = 1.0
	var slow = 1.0
	if now <= boost_end_time:
		boost = boost_multiplier
	else:
		boost_multiplier = 1.0
	if now <= slow_end_time:
		slow = slow_multiplier
	else:
		slow_multiplier = 1.0
	return boost * slow

func _get_other_player():
	var fallback = null
	for node in get_tree().get_nodes_in_group("player"):
		if node == self:
			continue
		var other_id = node.get("player_id")
		if other_id != null and other_id != player_id:
			return node
		if fallback == null:
			fallback = node
	return fallback

func fall_to_death():
	if not is_alive:
		return
	print("Player jatuh! Respawn dalam 3 detik...")
	_notify_match_player_down()
	is_alive = false
	can_move = false
	visible = false
	velocity = Vector3.ZERO
	
	await get_tree().create_timer(3.0).timeout
	if match_active:
		respawn()

func die():
	if not is_alive:
		return
	print("Player mati! Respawn dalam 3 detik...")
	_notify_match_player_down()
	is_alive = false
	can_move = false
	visible = false
	velocity = Vector3.ZERO
	
	await get_tree().create_timer(3.0).timeout
	if match_active:
		respawn()

func respawn():
	global_position = spawn_position
	velocity = Vector3.ZERO
	is_alive = true
	can_move = true
	visible = true
	print("Player respawn!")

func set_match_active(active: bool) -> void:
	match_active = active
	can_move = active and is_alive
	if not active:
		velocity = Vector3.ZERO


func _notify_match_player_down() -> void:
	get_tree().call_group("match_controller", "on_player_down", player_id)
