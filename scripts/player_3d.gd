extends CharacterBody3D

const SPEED = 10
const JUMP_VELOCITY = 8.0
const KNOCKBACK_FORCE = 15.0 # Atur angka ini untuk mengubah kekuatan dorongan

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_alive = true

# 1. Tambahkan referensi ke node AnimatedSprite3D
# Pastikan nama node di scene tree kamu sama persis dengan "AnimatedSprite3D"
@onready var animated_sprite = $AnimatedSprite3D

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	
	# Terapkan gravitasi
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Dapatkan input pergerakan 8 arah
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# --- 2. LOGIKA ANIMASI & ARAH HADAP ---
	if input_dir != Vector2.ZERO:
		# Mainkan animasi walk jika ada input
		animated_sprite.play("walk")
		
		# Flip (balik) sprite berdasarkan arah X
		if input_dir.x < 0:
			animated_sprite.flip_h = true  # Menghadap kiri
		elif input_dir.x > 0:
			animated_sprite.flip_h = false # Menghadap kanan
	else:
	
		# (Atau ubah ke animated_sprite.play("idle") jika kamu punya animasi diam)
		animated_sprite.stop()
	
	# --------------------------------------
	

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

func die():
	if not is_alive:
		return
	is_alive = false
	print("Game Over! Restarting...")
	velocity = Vector3.ZERO 
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
