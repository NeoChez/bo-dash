extends CharacterBody3D


@export_category("Player Controls")
@export var action_left: String = "ui_left"
@export var action_right: String = "ui_right"
@export var action_up: String = "ui_up"
@export var action_down: String = "ui_down"
@export var action_jump: String = "ui_accept"


const SPEED = 10
const JUMP_VELOCITY = 5.0
const KNOCKBACK_FORCE = 0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_alive = true
var can_move = true
var spawn_position: Vector3


@onready var animated_sprite = $AnimatedSprite3D

func _ready():
	spawn_position = global_position

func _physics_process(delta: float) -> void:
	if not is_alive or not can_move:
		return
	
	# Terapkan gravitasi
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump (Menggunakan variabel action_jump)
	if Input.is_action_just_pressed(action_jump) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
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
	
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * SPEED, SPEED * delta * 10)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, SPEED * delta * 10)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta * 5)
	
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

func fall_to_death():
	if not is_alive:
		return
	print("Player jatuh! Respawn dalam 3 detik...")
	is_alive = false
	can_move = false
	visible = false
	velocity = Vector3.ZERO
	
	await get_tree().create_timer(3.0).timeout
	respawn()

func die():
	if not is_alive:
		return
	print("Player mati! Respawn dalam 3 detik...")
	is_alive = false
	can_move = false
	visible = false
	velocity = Vector3.ZERO
	
	await get_tree().create_timer(3.0).timeout
	respawn()

func respawn():
	global_position = spawn_position
	velocity = Vector3.ZERO
	is_alive = true
	can_move = true
	visible = true
	print("Player respawn!")
