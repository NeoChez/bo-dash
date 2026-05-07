extends CharacterBody3D

const SPEED = 10
const JUMP_VELOCITY = 8.0
const KNOCKBACK_FORCE = 15.0 # Atur angka ini untuk mengubah kekuatan dorongan

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_alive = true

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	
	# 1. Terapkan gravitasi
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# 2. Handle jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# 3. Dapatkan input pergerakan 8 arah
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# 4. Terapkan kecepatan (dengan transisi halus menggunakan lerp/move_toward)
	if direction:
		# Gunakan move_toward agar efek dorongan tidak langsung hilang secara instan
		velocity.x = move_toward(velocity.x, direction.x * SPEED, SPEED * delta * 10)
		velocity.z = move_toward(velocity.z, direction.z * SPEED, SPEED * delta * 10)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta * 5)
	
	move_and_slide()
	
	# 5. Cek tabrakan
	_check_collisions()

func _check_collisions():
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision:
			var collider = collision.get_collider()
			
			# Jika menabrak objek di grup "obstacle"
			if collider and collider.is_in_group("obstacle"):
				# --- LOGIKA DORONGAN (KNOCKBACK) ---
				
				# Dapatkan arah dorongan (menjauh dari obstacle ke arah player)
				var push_dir = (global_position - collider.global_position).normalized()
				
				# Set Y menjadi 0 agar player tidak terlempar terbang ke atas
				push_dir.y = 0 
				
				# Terapkan gaya dorong ke velocity player
				velocity.x += push_dir.x * KNOCKBACK_FORCE
				velocity.z += push_dir.z * KNOCKBACK_FORCE

# (Fungsi die bisa dibiarkan jika sewaktu-waktu dibutuhkan untuk rintangan lain, 
#  misalnya jatuh ke jurang)
func die():
	if not is_alive:
		return
	is_alive = false
	print("Game Over! Restarting...")
	velocity = Vector3.ZERO 
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
