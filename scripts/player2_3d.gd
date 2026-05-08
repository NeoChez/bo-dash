extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 8.0
const LANE_DISTANCE = 2.0  # Jarak antar jalur
const LANE_SWITCH_SPEED = 12.0

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var current_lane = 1  # 0 = kiri, 1 = tengah, 2 = kanan
var target_z = 0.0
var is_alive = true

# Custom input actions untuk Player 2 (WASD + U)
var input_left = "p2_left"    # A
var input_right = "p2_right"  # D  
var input_up = "p2_up"        # W
var input_down = "p2_down"    # S
var input_jump = "p2_jump"    # U

func _ready():
	_calculate_target_z()

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# Handle jump dengan tombol U (p2_jump).
	if Input.is_action_just_pressed(input_jump) and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	# Player diam di posisi X (obstacle yang datang ke arah player).
	velocity.x = 0
	
	# Handle pindah jalur dengan A dan D.
	if Input.is_action_just_pressed(input_left):
		change_lane(-1)
	if Input.is_action_just_pressed(input_right):
		change_lane(1)
	
	# Smooth movement ke target lane (Z axis).
	_calculate_target_z()
	var z_diff = target_z - global_position.z
	velocity.z = z_diff * LANE_SWITCH_SPEED
	
	move_and_slide()
	
	# Cek collision dengan obstacle.
	_check_collisions()

func _calculate_target_z():
	# Lane 0 = -2, Lane 1 = 0, Lane 2 = +2.
	target_z = (current_lane - 1) * LANE_DISTANCE

func change_lane(direction: int):
	var new_lane = current_lane + direction
	if new_lane >= 0 and new_lane <= 2:
		current_lane = new_lane

func _check_collisions():
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if collision:
			var collider = collision.get_collider()
			# Cek jika bertabrakan dengan obstacle.
			if collider and collider.is_in_group("obstacle"):
				die()
				return

func die():
	if not is_alive:
		return
	is_alive = false
	print("Player 2 Game Over! Restarting...")
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
