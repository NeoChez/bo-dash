extends CharacterBody3D

const _SHIELD_SCENE := preload("res://scenes/skills/bubble_shield.tscn")
const _METEOR_SCENE := preload("res://scenes/skills/meteor.tscn")
const _SPEED_BOOST_VFX := preload("res://scenes/skills/vfx/speed_boost_vfx.tscn")
const _DASH_RECHARGE_VFX := preload("res://scenes/skills/vfx/dash_recharge_vfx.tscn")
const _IRON_ANCHOR_VFX := preload("res://scenes/skills/vfx/iron_anchor_vfx.tscn")
const _BALLOON_CURSE_VFX := preload("res://scenes/skills/vfx/balloon_curse_vfx.tscn")
const _SLINGSHOT_VFX := preload("res://scenes/skills/vfx/slingshot_vfx.tscn")
const _METEOR_CAST_VFX := preload("res://scenes/skills/vfx/meteor_cast_vfx.tscn")
const _SKILL_SFX := preload("res://assets/audio/sfx/skill.mp3")

@export_category("Player Controls")
@export var action_left: String = "ui_left"
@export var action_right: String = "ui_right"
@export var action_up: String = "ui_up"
@export var action_down: String = "ui_down"
@export var action_jump: String = "p1_jump"
@export var action_dash: String = "p1_dash"
@export var action_skill: String = "p1_skill"
@export var jump_velocity: float = 16.0
@export var gravity_scale: float = 3.2
@export var respawn_delay: float = 1.5

const SPEED = 15
const KNOCKBACK_FORCE = 0
@export var dash_speed: float = 38.0
@export var dash_cooldown: float = 0.7
@export var dash_active_duration: float = 0.1

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var is_alive = true
var can_move = true
var match_active = true
var spawn_position: Vector3
var rope_pull: Vector3 = Vector3.ZERO
@export_range(0.0, 1.0) var rope_resist_factor: float = 0.45

@export var player_id: int = 1

var boost_multiplier: float = 1.0
var slow_multiplier: float = 1.0
var boost_end_time: float = 0.0
var slow_end_time: float = 0.0
var yank_end_time: float = 0.0
var yank_strength: float = 0.0
var yank_source: Node3D = null
var _dash_timer: float = 0.0
var _dash_active_timer: float = 0.0
var _rope_constraint_pull: Vector3 = Vector3.ZERO
var _knockback_timer: float = 0.0
var shield_active: bool = false
var _shield_visual: Node3D = null
var anchor_resist: float = 0.0
var slingshot_active: bool = false
var slingshot_end_time: float = 0.0
var slingshot_dir: Vector3 = Vector3.ZERO
var slingshot_strength: float = 0.0
var anchor_end_time: float = 0.0
var balloon_curse_bonus: float = 0.0
var balloon_curse_end_time: float = 0.0
var rope_grace_timer: float = 0.0

enum PlayerState {
	RUNNING,
	JUMPING,
	FALLING,
	STANDING_UP,
	FLOATING
}
var current_state: PlayerState = PlayerState.RUNNING

var _current_model_path: String = ""
var _current_model_node: Node = null
var _state_timer: float = 0.0

@onready var animated_sprite = $AnimatedSprite3D
@onready var visuals = $Visuals
@onready var jump_sfx = $JumpSFX
@onready var dash_sfx = $DashSFX

# 3D Visuals & Procedural Animations
@export_group("3D Visuals & Animation")
@export var model_scale_factor: float = 1.0
@export var rex_model_scale: Vector3 = Vector3(4.0, 4.0, 4.0)
@export var rex_model_offset: Vector3 = Vector3(0.0, 0.0, 0.0)
@export var rotation_speed: float = 18.0
@export var base_y_offset: float = 0.53
@export var enable_procedural_animations: bool = true
@onready var dash_particles: GPUParticles3D = $Visuals/DashParticle

var _was_on_floor: bool = true
var _anim_time: float = 0.0
var _squash_timer: float = 0.0
var _landing_recoil_time: float = 0.0
var _is_recoil_active: bool = false

const ANIM_FALL_STANDUP_SPEED: float = 3.0
const FALL_IMMUNITY_DURATION: float = 0.4
var _fall_immunity_timer: float = 0.0
const FLOOR_GRACE_TIME: float = 0.12
var _floor_grace_timer: float = 0.0

func _ready():
	spawn_position = global_position
	_build_shield_visual()

	# Aligns Visuals container with the base center of the CapsuleShape3D
	if visuals:
		visuals.position = Vector3(0.82488, base_y_offset, 0.09399593)
		
		# Clear old placeholder models if any, but keep DashParticle
		for child in visuals.get_children():
			if child.name != "DashParticle":
				child.queue_free()
				visuals.remove_child(child)
			
		# Initialize default state as running!
		current_state = PlayerState.RUNNING
		_change_model("res://assets/player/" + _get_character_name() + "/running.glb")


func _physics_process(delta: float) -> void:
	if not match_active or not is_alive:
		return

	_fall_immunity_timer = maxf(_fall_immunity_timer - delta, 0.0)
	rope_grace_timer = maxf(rope_grace_timer - delta, 0.0)

	if is_on_floor():
		_floor_grace_timer = FLOOR_GRACE_TIME
	else:
		_floor_grace_timer = maxf(_floor_grace_timer - delta, 0.0)

	# State machine: jangan override state spesial (FALLING/STANDING_UP)
	if current_state != PlayerState.FALLING and current_state != PlayerState.STANDING_UP:
		if yank_source != null:
			change_state(PlayerState.FLOATING)
		elif is_on_floor() or (_floor_grace_timer > 0.0 and current_state != PlayerState.JUMPING):
			change_state(PlayerState.RUNNING)
		elif current_state != PlayerState.JUMPING:
			change_state(PlayerState.FLOATING)

	# Terapkan gravitasi
	if slingshot_active:
		_apply_slingshot_physics(delta)
	elif not is_on_floor():
		velocity.y -= gravity * gravity_scale * delta

	# Handle jump, dash, movement inputs
	if can_move:
		# Jump: hanya via tombol jump (Right Alt P1 / Left Alt P2), BUKAN tombol gerak W/P
		if Input.is_action_just_pressed(action_jump) and is_on_floor():
			velocity.y = jump_velocity
			change_state(PlayerState.JUMPING)
			jump_sfx.play()

		# Handle dash
		if _dash_timer > 0.0:
			_dash_timer -= delta
		_dash_active_timer = maxf(_dash_active_timer - delta, 0.0)
		if Input.is_action_just_pressed(action_dash) and _dash_timer <= 0.0:
			_do_dash()

		# Handle skill use
		if Input.is_action_just_pressed(action_skill):
			get_tree().call_group("match_controller", "use_skill", player_id)

		# Pergerakan 8 arah: W/A/S/D untuk P2, P/L/;/' untuk P1
		var input_dir = Input.get_vector(action_left, action_right, action_up, action_down)
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

		if input_dir != Vector2.ZERO:
			animated_sprite.play("walk")
			if input_dir.x < 0:
				animated_sprite.flip_h = true
			elif input_dir.x > 0:
				animated_sprite.flip_h = false
		else:
			animated_sprite.stop()

		var speed_multiplier = _get_speed_multiplier()
		var target_speed = SPEED * speed_multiplier
		if _knockback_timer > 0.0:
			_knockback_timer -= delta
		elif _dash_active_timer > 0.0:
			pass
		elif direction:
			velocity.x = move_toward(velocity.x, direction.x * target_speed, target_speed * delta * 10)
			velocity.z = move_toward(velocity.z, direction.z * target_speed, target_speed * delta * 10)
		else:
			velocity.x = move_toward(velocity.x, 0, SPEED * delta * 5)
			velocity.z = move_toward(velocity.z, 0, SPEED * delta * 5)
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * delta * 10)
		velocity.z = move_toward(velocity.z, 0, SPEED * delta * 10)

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
	_apply_anchor_and_balloon()
	_clamp_to_conveyor_side()
	var just_landed = is_on_floor() and not was_on_floor_before
	
	var final_input_dir = Vector2.ZERO
	var final_direction = Vector3.ZERO
	if can_move:
		final_input_dir = Input.get_vector(action_left, action_right, action_up, action_down)
		final_direction = (transform.basis * Vector3(final_input_dir.x, 0, final_input_dir.y)).normalized()

	_update_3d_animations(delta, final_input_dir, final_direction, was_on_floor_before, just_landed)
	
	# Cek tabrakan
	_check_collisions()

func _update_3d_animations(delta: float, input_dir: Vector2, direction: Vector3, was_on_floor_before: bool, just_landed: bool) -> void:
	if not visuals:
		return
		
	var base_scale = rex_model_scale
	
	# 1. Rotasi model ke arah pergerakan (Y-axis)
	# Prioritas: input direction (stabil) > velocity (osilasi saat diblok obstacle)
	var horiz_vel = Vector2(velocity.x, velocity.z)
	if input_dir != Vector2.ZERO:
		var target_angle = atan2(direction.x, direction.z)
		visuals.rotation.y = rotate_toward(visuals.rotation.y, target_angle, delta * rotation_speed)
	elif horiz_vel.length() > 0.5:
		var target_angle = atan2(velocity.x, velocity.z)
		visuals.rotation.y = rotate_toward(visuals.rotation.y, target_angle, delta * rotation_speed)
	
	# Bypass procedural animations during Falling, Standing Up, and Floating states to let keyframe animations play cleanly
	if not enable_procedural_animations or current_state == PlayerState.FALLING or current_state == PlayerState.STANDING_UP or current_state == PlayerState.FLOATING:
		visuals.scale = base_scale
		visuals.rotation.x = rotate_toward(visuals.rotation.x, 0.0, delta * 12.0)
		visuals.rotation.z = rotate_toward(visuals.rotation.z, 0.0, delta * 12.0)
		visuals.position.y = lerp(visuals.position.y, base_y_offset, delta * 10.0)
		return

	# 2. Trigger landing spring recoil
	if just_landed:
		_is_recoil_active = true
		_landing_recoil_time = 0.0
	
	# 3. Hitung posisi Y, Rotasi X/Z (Waddle/Recoil), dan Skala (Squash & Stretch)
	# Pakai state (sudah punya coyote time) bukan raw is_on_floor() agar tidak flip 1-2 frame
	var on_ground = (current_state == PlayerState.RUNNING)
	if on_ground:
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
				
		elif horiz_vel.length() > 0.5 or input_dir != Vector2.ZERO:
			# Berjalan (Waddle walk)
			# Saat input ada: pakai max(velocity, minimum) agar speed stabil saat diblok obstacle
			var speed_factor: float
			if input_dir != Vector2.ZERO:
				speed_factor = clamp(maxf(horiz_vel.length(), SPEED * 0.5) / SPEED, 0.4, 1.8)
			else:
				speed_factor = clamp(horiz_vel.length() / SPEED, 0.3, 1.8)
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
			
	else: # not on_ground
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
	# Player tidak lagi jatuh saat menabrak obstacle — cukup terdorong/terblok
	# oleh fisika (obstacle pakai sync_to_physics=true sehingga mendorong halus).
	# on_player_collision tetap dipanggil agar obstacle khusus (mis. destruct
	# yang pecah saat di-dash) tetap berfungsi.
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		if not collision:
			continue
		var collider = collision.get_collider()
		if collider and collider.is_in_group("obstacle"):
			if collider.has_method("on_player_collision"):
				collider.on_player_collision(self, collision)

func _do_dash() -> void:
	var input_dir := Input.get_vector(action_left, action_right, action_up, action_down)
	var dir: Vector3
	if input_dir.length() > 0.1:
		dir = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	else:
		var facing := -1.0 if animated_sprite.flip_h else 1.0
		dir = (transform.basis * Vector3(facing, 0, 0)).normalized()
	dir.y = 0.0
	velocity.x = dir.x * dash_speed
	velocity.z = dir.z * dash_speed
	_dash_timer = dash_cooldown
	_dash_active_timer = dash_active_duration
	dash_sfx.play()
	dash_particles.emitting = true

func apply_rope_pull(pull: Vector3) -> void:
	if _dash_active_timer > 0.0:
		rope_pull += pull * 0.2  # Partial pullback during dash — limits unbounded stretch while keeping momentum
		return
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

func is_dashing() -> bool:
	return _dash_active_timer > 0.0

func get_dash_cooldown_ratio() -> float:
	if dash_cooldown <= 0.0:
		return 1.0
	return 1.0 - clamp(_dash_timer / dash_cooldown, 0.0, 1.0)

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
		"bubble_shield":
			_apply_bubble_shield()
		"dash_recharge":
			_apply_dash_recharge()
		"iron_anchor":
			_apply_iron_anchor(magnitude, duration)
		"balloon_curse":
			_apply_balloon_curse_opponent(magnitude, duration)
		"slingshot_rocket":
			_apply_slingshot_rocket(magnitude, duration)
		"meteor_strike":
			_apply_meteor_strike(magnitude)

func _apply_speed_boost(multiplier: float, duration: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	boost_multiplier = max(boost_multiplier, multiplier)
	boost_end_time = max(boost_end_time, now + duration)
	_spawn_skill_vfx(_SPEED_BOOST_VFX)
	_play_skill_sfx()


# Instansiasi scene VFX sebagai child player agar mengikuti pergerakan.
# Tiap scene VFX mengatur masa hidupnya sendiri (Timer -> queue_free).
func _spawn_skill_vfx(scene: PackedScene) -> void:
	if scene == null:
		return
	add_child(scene.instantiate())


# Putar SFX skill secara dinamis agar tidak perlu node permanen.
func _play_skill_sfx() -> void:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = _SKILL_SFX
	sfx.volume_db = -5.0
	sfx.bus = "Master"
	add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func _apply_slow(multiplier: float, duration: float) -> void:
	if _check_and_consume_shield():
		return
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
	if _check_and_consume_shield():
		return
	var now = Time.get_ticks_msec() / 1000.0
	yank_source = source
	yank_strength = max(yank_strength, strength)
	yank_end_time = max(yank_end_time, now + duration)
	if current_state != PlayerState.FLOATING:
		change_state(PlayerState.FLOATING)

func _apply_yank_force(delta: float) -> void:
	if yank_source == null:
		return
	var now = Time.get_ticks_msec() / 1000.0
	if now > yank_end_time:
		yank_source = null
		yank_strength = 0.0
		if current_state == PlayerState.FLOATING:
			change_state(PlayerState.RUNNING)
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

func _get_other_player() -> Node3D:
	var fallback: Node3D = null
	for node in get_tree().get_nodes_in_group("player"):
		if node == self:
			continue
		var other_id = node.get("player_id")
		if other_id != null and other_id != player_id:
			return node
		if fallback == null:
			fallback = node
	return fallback

func _get_character_name() -> String:
	var global_settings = get_node_or_null("/root/GlobalSettings")
	if global_settings:
		if player_id == 1:
			return global_settings.player_1_character
		else:
			return global_settings.player_2_character
	return "male"

func fall_to_death():
	if not is_alive:
		return
	print("Player jatuh! Respawn dalam 3 detik...")
	_notify_match_player_down()
	is_alive = false
	can_move = false
	visible = false
	velocity = Vector3.ZERO
	
	await get_tree().create_timer(respawn_delay).timeout
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
	
	await get_tree().create_timer(respawn_delay).timeout
	if match_active:
		respawn()

func respawn():
	global_position = spawn_position
	velocity = Vector3.ZERO
	is_alive = true
	can_move = true
	visible = true
	rope_grace_timer = 2.0
	shield_active = false
	if _shield_visual:
		_shield_visual.visible = false
	slingshot_active = false
	boost_multiplier = 1.0
	boost_end_time = 0.0
	slow_multiplier = 1.0
	slow_end_time = 0.0
	yank_source = null
	yank_strength = 0.0
	yank_end_time = 0.0
	anchor_resist = 0.0
	anchor_end_time = 0.0
	balloon_curse_bonus = 0.0
	balloon_curse_end_time = 0.0
	print("Player respawn!")

func set_match_active(active: bool) -> void:
	match_active = active
	can_move = active and is_alive
	if not active:
		velocity = Vector3.ZERO


func _build_shield_visual() -> void:
	_shield_visual = _SHIELD_SCENE.instantiate()
	_shield_visual.position = Vector3(0.0, 1.0, 0.0)
	_shield_visual.visible = false
	add_child(_shield_visual)


func _check_and_consume_shield() -> bool:
	if shield_active:
		shield_active = false
		if _shield_visual:
			_shield_visual.visible = false
		return true
	return false


func _apply_bubble_shield() -> void:
	shield_active = true
	if _shield_visual:
		_shield_visual.visible = true
	_play_skill_sfx()


func _apply_dash_recharge() -> void:
	_dash_timer = 0.0
	_spawn_skill_vfx(_DASH_RECHARGE_VFX)
	_play_skill_sfx()


func _apply_iron_anchor(resist: float, duration: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	anchor_resist = max(anchor_resist, resist)
	anchor_end_time = max(anchor_end_time, now + duration)
	_spawn_skill_vfx(_IRON_ANCHOR_VFX)
	_play_skill_sfx()


func _apply_balloon_curse(bonus: float, duration: float) -> void:
	if _check_and_consume_shield():
		return
	var now := Time.get_ticks_msec() / 1000.0
	balloon_curse_bonus = max(balloon_curse_bonus, bonus)
	balloon_curse_end_time = max(balloon_curse_end_time, now + duration)
	_spawn_skill_vfx(_BALLOON_CURSE_VFX)
	_play_skill_sfx()


func _apply_balloon_curse_opponent(bonus: float, duration: float) -> void:
	var other := _get_other_player()
	if other and other.has_method("_apply_balloon_curse"):
		other._apply_balloon_curse(bonus, duration)


func _apply_slingshot_rocket(strength: float, duration: float) -> void:
	_spawn_skill_vfx(_SLINGSHOT_VFX)
	var horiz_vel := Vector3(velocity.x, 0.0, velocity.z)
	if horiz_vel.length() > 0.5:
		slingshot_dir = horiz_vel.normalized()
	else:
		slingshot_dir = Vector3(-signf(global_position.x), 0.0, 0.0)
	slingshot_strength = strength
	slingshot_active = true
	slingshot_end_time = Time.get_ticks_msec() / 1000.0 + duration
	velocity.y = 40.0  # initial lift-off


func _apply_slingshot_physics(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now > slingshot_end_time:
		slingshot_active = false
		return
	# Melayang — tahan Y di ketinggian kecil, tidak ada gravitasi
	velocity.y = lerpf(velocity.y, 1.5, delta * 6.0)
	# Dorong terus ke arah hadap
	velocity.x = slingshot_dir.x * slingshot_strength
	velocity.z = slingshot_dir.z * slingshot_strength


func _apply_meteor_from(impact_center: Vector3, strength: float) -> void:
	if _check_and_consume_shield():
		return
	var dir := global_position - impact_center
	if dir.length_squared() < 0.01:
		dir = Vector3(randf_range(-1.0, 1.0), 1.0, randf_range(-1.0, 1.0))
	dir = dir.normalized()
	dir.y = maxf(dir.y, 0.35)
	dir = dir.normalized()
	velocity = dir * strength * 2.8
	_knockback_timer = 0.4


func _apply_meteor_strike(strength: float) -> void:
	_spawn_skill_vfx(_METEOR_CAST_VFX)
	var other := _get_other_player()
	if other == null:
		return
	var meteor := _METEOR_SCENE.instantiate()
	get_tree().current_scene.add_child(meteor)
	if meteor.has_method("setup"):
		meteor.call("setup", other.global_position, strength)


func _apply_anchor_and_balloon() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var pv := get_platform_velocity()
	var flat_platform := Vector3(pv.x, 0.0, pv.z)
	if flat_platform.length_squared() < 0.01:
		return
	if now <= anchor_end_time:
		velocity.x -= flat_platform.x * anchor_resist
		velocity.z -= flat_platform.z * anchor_resist
	else:
		anchor_resist = 0.0
	if now <= balloon_curse_end_time:
		velocity.x += flat_platform.x * balloon_curse_bonus
		velocity.z += flat_platform.z * balloon_curse_bonus
	else:
		balloon_curse_bonus = 0.0


func _clamp_to_conveyor_side() -> void:
	if spawn_position.x > 0.0 and global_position.x < 0.0:
		global_position.x = 0.0
		velocity.x = maxf(velocity.x, 0.0)
	elif spawn_position.x < 0.0 and global_position.x > 0.0:
		global_position.x = 0.0
		velocity.x = minf(velocity.x, 0.0)

func _notify_match_player_down() -> void:
	get_tree().call_group("match_controller", "on_player_down", player_id)

func change_state(new_state: PlayerState) -> void:
	if current_state == new_state:
		return

	current_state = new_state

	match current_state:
		PlayerState.RUNNING:
			can_move = true
			_change_model("res://assets/player/" + _get_character_name() + "/running.glb")

		PlayerState.JUMPING:
			can_move = true
			_change_model("res://assets/player/" + _get_character_name() + "/jumping.glb")

		PlayerState.FALLING:
			can_move = false
			yank_source = null
			yank_strength = 0.0
			_change_model("res://assets/player/" + _get_character_name() + "/fall.glb", ANIM_FALL_STANDUP_SPEED)
			_connect_anim_finished_once(func(): change_state(PlayerState.STANDING_UP))

		PlayerState.STANDING_UP:
			can_move = false
			_change_model("res://assets/player/" + _get_character_name() + "/standup.glb", ANIM_FALL_STANDUP_SPEED)
			_connect_anim_finished_once(func():
				_fall_immunity_timer = FALL_IMMUNITY_DURATION
				change_state(PlayerState.RUNNING)
			)

		PlayerState.FLOATING:
			can_move = false
			_change_model("res://assets/player/" + _get_character_name() + "/floating.glb")

func _connect_anim_finished_once(callback: Callable) -> void:
	var anim_player = _find_animation_player(_current_model_node)
	if anim_player:
		anim_player.animation_finished.connect(
			func(_anim_name: StringName): callback.call(),
			CONNECT_ONE_SHOT
		)

func _change_model(path: String, speed: float = 1.0) -> void:
	if _current_model_path == path:
		var anim_player = _find_animation_player(_current_model_node)
		if anim_player:
			anim_player.speed_scale = speed
		return
		
	var model_scene = load(path) as PackedScene
	if not model_scene:
		push_error("Gagal meload model scene di: " + path)
		return
		
	if _current_model_node and is_instance_valid(_current_model_node):
		_current_model_node.queue_free()
		visuals.remove_child(_current_model_node)
		
	_current_model_path = path
	_current_model_node = model_scene.instantiate()
	visuals.add_child(_current_model_node)
	
	_current_model_node.position = Vector3.ZERO
	_current_model_node.scale = rex_model_scale
	_current_model_node.rotation = Vector3.ZERO
	
	_play_first_animation(_current_model_node, speed)
	_apply_outfit_colors(_current_model_node)

func _apply_outfit_colors(model: Node) -> void:
	var colors: Dictionary = GlobalSettings.player_1_colors if player_id == 1 else GlobalSettings.player_2_colors
	if colors.is_empty():
		return
	var is_female := "female" in _current_model_path.to_lower()
	_smart_tint_all(model, colors, is_female)

func _smart_tint_all(node: Node, colors: Dictionary, is_female: bool) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			return
		for i in range(mi.mesh.get_surface_count()):
			var mat = mi.mesh.surface_get_material(i)
			if not (mat is BaseMaterial3D):
				mat = mi.get_active_material(i)
			if mat is BaseMaterial3D:
				var orig := (mat as BaseMaterial3D).albedo_color
				var cat := _classify_by_color(node.name, orig, is_female)
				if cat != "" and colors.has(cat):
					var nm := mat.duplicate() as BaseMaterial3D
					nm.albedo_color = colors[cat]
					mi.set_surface_override_material(i, nm)
	for child in node.get_children():
		_smart_tint_all(child, colors, is_female)

func _classify_by_color(mesh_name: String, color: Color, is_female: bool) -> String:
	var brightness := (color.r + color.g + color.b) / 3.0
	var chroma := maxf(maxf(color.r, color.g), color.b) - minf(minf(color.r, color.g), color.b)

	if is_female:
		# Hair: Object_2 specifically (bisa golden atau dark setelah update model)
		if mesh_name == "Object_2":
			return "hair"
		# Golden hair fallback
		if color.r > 0.75 and color.g > 0.55 and color.b < 0.45:
			return "hair"
		# Baju pink/mauve: b >= g (cool/pink), bukan kulit hangat (g > b)
		if brightness >= 0.35 and brightness <= 0.68 and chroma >= 0.18 and chroma <= 0.45 and color.b >= color.g:
			return "top"
		# Celana pinkish-gray
		if brightness >= 0.38 and brightness <= 0.60 and chroma >= 0.05 and chroma < 0.18:
			return "pants"
		# Sepatu: dark Vert_ saja (hindari Cube_ yang bisa jadi mata/alis)
		if mesh_name.begins_with("Vert_") and brightness > 0.008 and brightness < 0.07:
			return "shoes"
		return ""
	else:
		# Male: skip colorful/skin
		if chroma > 0.15:
			return ""
		# Pants: neutral mid-gray
		if brightness >= 0.40 and brightness <= 0.65:
			return "pants"
		# Shoes: neutral very dark
		if brightness > 0.008 and brightness < 0.08:
			return "shoes"
		# Near-black: Vert_ = shirt, other = hair
		if brightness <= 0.008:
			return "top" if mesh_name.begins_with("Vert_") else "hair"
		return ""

func _tint_mesh_nodes(node: Node, names: Array, color: Color) -> void:
	if node is MeshInstance3D and node.name in names:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			return
		for i in range(mi.mesh.get_surface_count()):
			var mat = mi.get_active_material(i)
			if mat is BaseMaterial3D:
				var nm := mat.duplicate() as BaseMaterial3D
				nm.albedo_color = color
				mi.set_surface_override_material(i, nm)
	for child in node.get_children():
		_tint_mesh_nodes(child, names, color)

func _play_first_animation(model: Node, speed: float = 1.0) -> void:
	var anim_player = _find_animation_player(model)
	if anim_player:
		anim_player.speed_scale = speed
		var anim_list = anim_player.get_animation_list()
		if anim_list.size() > 0:
			var anim_name = anim_list[0]
			var anim = anim_player.get_animation(anim_name)
			if anim:
				var path_lower = _current_model_path.to_lower()
				if "running" in path_lower or "floating" in path_lower or "idle" in path_lower:
					anim.loop_mode = Animation.LOOP_LINEAR
				else:
					anim.loop_mode = Animation.LOOP_NONE
			anim_player.play(anim_name)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null

func apply_knockback(force: Vector3) -> void:
	velocity += force
