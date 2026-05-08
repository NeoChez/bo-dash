extends CharacterBody3D

const SPEED = 10
const JUMP_VELOCITY = 8.0
const KNOCKBACK_FORCE = 15.0 

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_alive = true

@onready var animated_sprite = $AnimatedSprite3D

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	
	# Terapkan gravitasi
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump (Ubah ke action "jump")
	if Input.is_action_just_pressed("p2_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Dapatkan input pergerakan 8 arah menggunakan WASD actions
	# Format: get_vector("kiri (A)", "kanan (D)", "depan/atas (W)", "belakang/bawah (S)")
	var input_dir = Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# --- LOGIKA ANIMASI & ARAH HADAP ---
	if input_dir != Vector2.ZERO:
		animated_sprite.play("walk")
		
		if input_dir.x < 0:
			animated_sprite.flip_h = true  
		elif input_dir.x > 0:
			animated_sprite.flip_h = false 
	else:
		animated_sprite.stop()
	# --------------------------------------

	if direction:
		velocity.x = move_toward(velocity.x, direction.x * SPEED, SPEED * delta * 10)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, SPEED * delta * 10)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta * 5)
	
	move_and_slide()
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

func die():
	if not is_alive:
		return
	is_alive = false
	print("Game Over! Restarting...")
	velocity = Vector3.ZERO 
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
