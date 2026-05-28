extends CharacterBody3D


@export_category("Player Controls")
@export var action_left: String = "ui_left"
@export var action_right: String = "ui_right"
@export var action_up: String = "ui_up"
@export var action_down: String = "ui_down"
@export var action_jump: String = "ui_accept"
@export var action_dash: String = "p1_dash"
@export var action_skill: String = "p1_skill"
@export var jump_velocity: float = 16.0
@export var gravity_scale: float = 3.2

const SPEED = 15
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
@onready var visuals = $Visuals

# 3D Visuals & Procedural Animations
@export_group("3D Visuals & Animation")
@export var model_scale_factor: float = 1.0
@export var rex_model_scale: Vector3 = Vector3(25.0, 25.0, 25.0)
@export var rex_model_offset: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var rotation_speed: float = 18.0
@export var base_y_offset: float = 0.53
@export var enable_procedural_animations: bool = true

var _was_on_floor: bool = true
var _anim_time: float = 0.0
var _squash_timer: float = 0.0
var _landing_recoil_time: float = 0.0
var _is_recoil_active: bool = false

func _ready():
	spawn_position = global_position
	
	# Map action_jump to action_up (W for Player 2, Up Arrow for Player 1)
	action_jump = action_up
	
	# Aligns Visuals container with the base center of the CapsuleShape3D
	if visuals:
		visuals.position = Vector3(0.82488, base_y_offset, 0.09399593)
		
		# 1. Determine selected character (persistent autoload fallback is Rex)
		var char_name = "rex"
		var global_settings = get_node_or_null("/root/GlobalSettings")
		if global_settings:
			if player_id == 1:
				char_name = global_settings.player_1_character
			else:
				char_name = global_settings.player_2_character
			
		# 2. Remove default placeholder model
		var old_model = visuals.get_node_or_null("RexModel")
		if old_model:
			visuals.remove_child(old_model)
			old_model.queue_free()
			
		# 3. Dynamic GLB loading and calibrated dimensions applying
		var model_scene: PackedScene
		match char_name:
			"hamm":
				model_scene = load("res://assets/player/kingdom_hearts_iii_-_hamm.glb")
				rex_model_scale = Vector3(20.0, 20.0, 20.0) # Hamm scale calibration
				rex_model_offset = Vector3(0.0, 0.0, 0.0)
			"alien":
				model_scene = load("res://assets/player/kingdom_hearts_iii_-_alienlgm.glb")
				rex_model_scale = Vector3(22.0, 22.0, 22.0) # Alien uniform scale calibration (fixes flat/gepeng issue)
				rex_model_offset = Vector3(0.0, 0.0, 0.0)
			"wheezy":
				model_scene = load("res://assets/player/wii_-_toy_story_3_-_wheezy.glb")
				rex_model_scale = Vector3(0.35, 0.35, 0.35) # Wheezy scaled up slightly as requested
				rex_model_offset = Vector3(0.0, 0.0, 0.0)
			"slinky":
				model_scene = load("res://assets/player/wii_-_toy_story_3_-_slinky_dog.glb")
				rex_model_scale = Vector3(0.22, 0.22, 0.22) # Slinky Dog scaled down to fit nicely on conveyor belt
				rex_model_offset = Vector3(0.0, 0.0, 0.0)
			_:
				model_scene = load("res://assets/player/kingdom_hearts_iii_-_rex.glb")
				rex_model_scale = Vector3(25.0, 25.0, 25.0) # Rex scale calibration
				rex_model_offset = Vector3(0.0, 0.0, 0.0)
			
		if model_scene:
			var new_model = model_scene.instantiate()
			new_model.name = "RexModel" # Keep name to ensure animation lookup works seamlessly
			visuals.add_child(new_model)
			new_model.scale = rex_model_scale
			new_model.position = rex_model_offset

func _physics_process(delta: float) -> void:
	if not match_active or not is_alive or not can_move:
		return
	
	# Terapkan gravitasi
	if not is_on_floor():
		velocity.y -= gravity * gravity_scale * delta
	
	# Handle jump (Menggunakan variabel action_jump)
	if Input.is_action_just_pressed(action_jump) and is_on_floor():
		velocity.y = jump_velocity

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
	
	var was_on_floor_before = is_on_floor()
	move_and_slide()
	var just_landed = is_on_floor() and not was_on_floor_before
	
	_update_3d_animations(delta, input_dir, direction, was_on_floor_before, just_landed)
	
	# Cek tabrakan
	_check_collisions()

func _update_3d_animations(delta: float, input_dir: Vector2, direction: Vector3, was_on_floor_before: bool, just_landed: bool) -> void:
	if not visuals:
		return
		
	# Pastikan base scale model benar
	var base_scale = Vector3(model_scale_factor, model_scale_factor, model_scale_factor)
	
	# 1. Rotasi model ke arah pergerakan (Y-axis)
	var horiz_vel = Vector2(velocity.x, velocity.z)
	if horiz_vel.length() > 0.5:
		# Gunakan atan2(x, z) untuk menghitung arah hadap di plane X-Z
		var target_angle = atan2(velocity.x, velocity.z)
		visuals.rotation.y = rotate_toward(visuals.rotation.y, target_angle, delta * rotation_speed)
	
	if not enable_procedural_animations:
		visuals.scale = base_scale
		visuals.position.y = base_y_offset
		return

	# 2. Trigger landing spring recoil
	if just_landed:
		_is_recoil_active = true
		_landing_recoil_time = 0.0
	
	# 3. Hitung posisi Y, Rotasi X/Z (Waddle/Recoil), dan Skala (Squash & Stretch)
	if is_on_floor():
		# Reset rotasi X ke normal secara bertahap
		visuals.rotation.x = rotate_toward(visuals.rotation.x, 0.0, delta * 12.0)
		
		# Jika sedang membal setelah mendarat
		if _is_recoil_active:
			_landing_recoil_time += delta * 15.0 # Kecepatan pantulan pegas
			if _landing_recoil_time > PI * 2.0:
				_is_recoil_active = false
				visuals.scale = base_scale
				visuals.position.y = base_y_offset
			else:
				# Persamaan pegas: Sinus teredam secara eksponensial (Boing!)
				var amp = exp(-_landing_recoil_time * 0.6) * sin(_landing_recoil_time)
				var squash_y = 1.0 - amp * 0.40  # Amplitudo squash Y hingga 40%
				var squash_xz = 1.0 + amp * 0.18 # Amplitudo stretch X/Z
				visuals.scale.y = base_scale.y * squash_y
				visuals.scale.x = base_scale.x * squash_xz
				visuals.scale.z = base_scale.z * squash_xz
				
				# Kemiringan sedikit ke depan saat pertama menyentuh tanah, lalu membal balik
				visuals.rotation.x = rotate_toward(visuals.rotation.x, amp * 0.12, delta * 15.0)
				visuals.position.y = base_y_offset - amp * 0.16
				
		elif horiz_vel.length() > 0.5:
			# Berjalan (Waddle walk)
			# Kecepatan animasi berskala dengan pergerakan player
			var speed_factor = clamp(horiz_vel.length() / SPEED, 0.3, 1.8)
			_anim_time += delta * speed_factor * 10.0
			
			# Kemiringan badan ke samping kiri-kanan (Waddle)
			visuals.rotation.z = rotate_toward(visuals.rotation.z, sin(_anim_time) * 0.12, delta * 12.0)
			
			# Bobbing atas-bawah (naik sedikit saat waddle)
			visuals.position.y = lerp(visuals.position.y, base_y_offset + abs(sin(_anim_time)) * 0.08, delta * 15.0)
			
			# Sedikit pitching maju mundur saat berlari
			visuals.rotation.x = rotate_toward(visuals.rotation.x, abs(cos(_anim_time)) * 0.03, delta * 8.0)
			
			# Kembalikan skala ke normal
			visuals.scale = visuals.scale.lerp(base_scale, delta * 10.0)
		else:
			# Idle (Breathe effect)
			_anim_time += delta * 2.0
			visuals.rotation.z = rotate_toward(visuals.rotation.z, 0.0, delta * 10.0)
			visuals.position.y = lerp(visuals.position.y, base_y_offset, delta * 10.0)
			
			# Efek bernafas (breathe) lembut pada skala
			var breathe_y = 1.0 + sin(_anim_time) * 0.015
			var breathe_xz = 1.0 - sin(_anim_time) * 0.007
			var target_scale = Vector3(base_scale.x * breathe_xz, base_scale.y * breathe_y, base_scale.z * breathe_xz)
			visuals.scale = visuals.scale.lerp(target_scale, delta * 5.0)
			
	else:
		# Sedang melompat atau jatuh (Di udara)
		_is_recoil_active = false # matikan recoil saat lepas landas
		
		# Animasi kepak sayap/ekor bergoyang di udara agar tidak kaku
		_anim_time += delta * 8.0
		visuals.rotation.z = rotate_toward(visuals.rotation.z, sin(_anim_time) * 0.06, delta * 8.0)
		visuals.position.y = lerp(visuals.position.y, base_y_offset, delta * 10.0)
		
		if velocity.y > 0.1:
			# Naik (Melompat / Stretch Y Kuat untuk pelepasan energi)
			var stretch_y = 1.0 + clamp(velocity.y / jump_velocity, 0.0, 1.0) * 0.42
			var compress_xz = 1.0 - clamp(velocity.y / jump_velocity, 0.0, 1.0) * 0.20
			var target_scale = Vector3(base_scale.x * compress_xz, base_scale.y * stretch_y, base_scale.z * compress_xz)
			visuals.scale = visuals.scale.lerp(target_scale, delta * 15.0)
			
			# Mendongak ke atas saat melompat terbang naik
			visuals.rotation.x = rotate_toward(visuals.rotation.x, -0.28, delta * 12.0)
		elif velocity.y < -0.1:
			# Turun (Jatuh / Bersiap mendarat)
			var stretch_xz = 1.0 + clamp(abs(velocity.y) / jump_velocity, 0.0, 1.0) * 0.16
			var compress_y = 1.0 - clamp(abs(velocity.y) / jump_velocity, 0.0, 1.0) * 0.10
			var target_scale = Vector3(base_scale.x * stretch_xz, base_scale.y * compress_y, base_scale.z * stretch_xz)
			visuals.scale = visuals.scale.lerp(target_scale, delta * 10.0)
			
			# Condong maju ke bawah melihat pendaratan
			visuals.rotation.x = rotate_toward(visuals.rotation.x, 0.35, delta * 10.0)

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

func apply_knockback(force: Vector3) -> void:
	velocity += force
