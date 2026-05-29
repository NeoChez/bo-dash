extends AnimatableBody3D
@export var move_speed: float = 1.0
@export var move_direction: Vector3 = Vector3(-1, 0, 0)
@export var knockback_force: float = 10.0
@onready var hit_sfx = $HitSFX
var _dying: bool = false
var _falling: bool = false
var _fall_velocity: float = 0.0
const GRAVITY: float = 9.8

func _ready() -> void:
	add_to_group("obstacle")
	add_to_group("item")
	$Area3D.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		var has_shield: bool = body.get("shield_active") == true
		if not has_shield:
			hit_sfx.play()
		var knockback_dir = (body.global_position - global_position).normalized()
		knockback_dir.y = 0.0
		knockback_dir = knockback_dir.normalized()
		if body.has_method("apply_knockback"):
			body.apply_knockback(knockback_dir * knockback_force + Vector3(0, 20.0, 0))

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
