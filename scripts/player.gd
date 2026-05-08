class_name Player
extends CharacterBody2D

const SPEED: float = 400.0
const ACCELERATION: float = 2400.0
const FRICTION: float = 1800.0
const DASH_SPEED: float = 760.0
const DASH_DURATION: float = 0.18
const DASH_COOLDOWN: float = 0.55
const JUMP_DURATION: float = 0.5
const JUMP_HEIGHT: float = 1000.0
const JUMP_COOLDOWN: float = 0.15
const INVULN_TIME: float = 2.0
const FALL_GRAVITY: float = 1400.0
const CONVEYOR_LAYER_MASK: int = 8
const FALL_DEATH_Y: float = 1500.0

@export var player_id: int = 1
@export var spawn_position: Vector2 = Vector2.ZERO
@export var sprite_color: Color = Color(1, 1, 1, 1)
@export var bounds_min: Vector2 = Vector2(40, 40)
@export var bounds_max: Vector2 = Vector2(1880, 1040)

var _input_prefix: String = "p1_"
var _dash_time_left: float = 0.0
var _dash_cooldown_left: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _jump_time_left: float = 0.0
var _jump_cooldown_left: float = 0.0
var _invuln_time_left: float = 0.0
var _facing: Vector2 = Vector2.DOWN

var _own_velocity: Vector2 = Vector2.ZERO
var _fall_velocity_y: float = 0.0
var _sprite_base_offset: Vector2 = Vector2.ZERO
var _conveyor_query: PhysicsShapeQueryParameters2D

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

signal fell_into_pit(player: Player)

func _ready() -> void:
	add_to_group("player")
	_input_prefix = "p%d_" % player_id
	if spawn_position == Vector2.ZERO:
		spawn_position = global_position
	if sprite:
		sprite.modulate = sprite_color
		_sprite_base_offset = sprite.offset
	_conveyor_query = PhysicsShapeQueryParameters2D.new()
	if collision_shape and collision_shape.shape:
		_conveyor_query.shape = collision_shape.shape
	_conveyor_query.collide_with_areas = true
	_conveyor_query.collide_with_bodies = false
	_conveyor_query.collision_mask = CONVEYOR_LAYER_MASK

func _physics_process(delta: float) -> void:
	_dash_cooldown_left = maxf(_dash_cooldown_left - delta, 0.0)
	_jump_cooldown_left = maxf(_jump_cooldown_left - delta, 0.0)
	_invuln_time_left = maxf(_invuln_time_left - delta, 0.0)

	var input := Input.get_vector(
		_input_prefix + "left", _input_prefix + "right",
		_input_prefix + "up", _input_prefix + "down"
	)

	if _dash_time_left > 0.0:
		_dash_time_left -= delta
		_own_velocity = _dash_dir * DASH_SPEED
	else:
		var target_velocity := input * SPEED
		if input != Vector2.ZERO:
			_own_velocity = _own_velocity.move_toward(target_velocity, ACCELERATION * delta)
			_facing = input.normalized()
		else:
			_own_velocity = _own_velocity.move_toward(Vector2.ZERO, FRICTION * delta)

		if Input.is_action_just_pressed(_input_prefix + "dash") and _dash_cooldown_left <= 0.0:
			_dash_dir = input.normalized() if input != Vector2.ZERO else _facing
			_dash_time_left = DASH_DURATION
			_dash_cooldown_left = DASH_COOLDOWN

	if Input.is_action_just_pressed(_input_prefix + "jump") and _jump_time_left <= 0.0 and _jump_cooldown_left <= 0.0:
		_jump_time_left = JUMP_DURATION
	if _jump_time_left > 0.0:
		_jump_time_left -= delta
		if _jump_time_left <= 0.0:
			_jump_cooldown_left = JUMP_COOLDOWN

	# Phase through obstacles when jumping or invulnerable
	var should_collide_obstacle: bool = not is_jumping() and not is_invulnerable()
	set_collision_mask_value(3, should_collide_obstacle)

	# Poll which conveyors we're on (fresh every frame, no signal lag)
	var env_push: Vector2 = Vector2.ZERO
	var on_conveyor: bool = false
	if _conveyor_query and _conveyor_query.shape:
		_conveyor_query.transform = Transform2D(0.0, global_position)
		var hits := get_world_2d().direct_space_state.intersect_shape(_conveyor_query, 4)
		for hit in hits:
			var col = hit.get("collider")
			if col != null and col.is_in_group("conveyor") and "conveyor_velocity" in col:
				env_push += col.conveyor_velocity
				on_conveyor = true

	# Gravity falling when not on conveyor and not jumping
	var is_in_air := not on_conveyor and not is_jumping()
	if is_in_air:
		_fall_velocity_y += FALL_GRAVITY * delta
	else:
		_fall_velocity_y = 0.0

	velocity = _own_velocity + env_push + Vector2(0.0, _fall_velocity_y)
	move_and_slide()

	_apply_bounds(on_conveyor)

	# Backup catch: if player tunneled past the pit area while falling fast, force respawn.
	if global_position.y > FALL_DEATH_Y:
		fall_into_pit()

	_update_visuals()

func _apply_bounds(on_conveyor: bool) -> void:
	# X always clamped — keeps each player on their assigned side.
	var clamped_x: float = clampf(global_position.x, bounds_min.x, bounds_max.x)
	if clamped_x != global_position.x:
		_own_velocity.x = 0.0
		velocity.x = 0.0
	# Y only clamped while standing on a conveyor. When off the belt the player
	# is in mid-air and gravity should be free to pull them down into the pit.
	var clamped_y: float = global_position.y
	if on_conveyor:
		clamped_y = clampf(global_position.y, bounds_min.y, bounds_max.y)
		if clamped_y != global_position.y:
			_own_velocity.y = 0.0
			velocity.y = 0.0
			_fall_velocity_y = 0.0
	global_position = Vector2(clamped_x, clamped_y)

func _update_visuals() -> void:
	if sprite == null:
		return
	if velocity.length() > 10.0:
		if not sprite.is_playing():
			sprite.play("walk")
		if absf(velocity.x) > 1.0:
			sprite.flip_h = velocity.x < 0
	else:
		sprite.stop()

	var lift: float = 0.0
	if _jump_time_left > 0.0:
		var t: float = 1.0 - (_jump_time_left / JUMP_DURATION)
		lift = sin(t * PI) * JUMP_HEIGHT
	sprite.offset = _sprite_base_offset + Vector2(0.0, -lift)

	var alpha: float = 1.0
	if _invuln_time_left > 0.0:
		alpha = 0.4 if int(_invuln_time_left * 12.0) % 2 == 0 else 1.0
	sprite.modulate = Color(sprite_color.r, sprite_color.g, sprite_color.b, alpha)

func fall_into_pit() -> void:
	if _invuln_time_left > 0.0 or is_jumping():
		return
	emit_signal("fell_into_pit", self)
	respawn(spawn_position)

func respawn(at_pos: Vector2) -> void:
	global_position = at_pos
	velocity = Vector2.ZERO
	_own_velocity = Vector2.ZERO
	_fall_velocity_y = 0.0
	_dash_time_left = 0.0
	_dash_cooldown_left = 0.0
	_jump_time_left = 0.0
	_invuln_time_left = INVULN_TIME
	if sprite:
		sprite.modulate = sprite_color
		sprite.offset = _sprite_base_offset

func apply_rope_force(impulse: Vector2) -> void:
	if _dash_time_left > 0.0:
		return
	_own_velocity += impulse

func apply_knockback(force: Vector2) -> void:
	if _dash_time_left > 0.0 or _invuln_time_left > 0.0 or is_jumping():
		return
	_own_velocity += force

func clamp_outward_velocity(toward_other: Vector2) -> void:
	var along := _own_velocity.dot(toward_other)
	if along < 0.0:
		_own_velocity -= toward_other * along

func is_invulnerable() -> bool:
	return _invuln_time_left > 0.0

func is_jumping() -> bool:
	return _jump_time_left > 0.0
