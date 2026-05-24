extends Area3D

@export_enum("Speed Boost", "Slow Opponent", "Yank Opponent") var powerup_type: int = 0
@export var duration: float = 4.0
@export var speed_multiplier: float = 1.5
@export var slow_multiplier: float = 0.5
@export var yank_strength: float = 18.0
@export var move_speed: float = 7.5
@export var move_direction: Vector3 = Vector3(-1, 0, 0)
@export var bob_height: float = 0.2
@export var bob_speed: float = 4.0
@export var spin_speed: float = 1.8

@onready var visual: MeshInstance3D = $Visual

var _base_y: float = 0.0
var _time_accum: float = 0.0

func _ready() -> void:
	_base_y = global_position.y
	body_entered.connect(_on_body_entered)
	_apply_color()

func _physics_process(delta: float) -> void:
	global_position += move_direction * move_speed * delta

func _process(delta: float) -> void:
	_time_accum += delta
	var bob = sin(_time_accum * bob_speed) * bob_height
	global_position.y = _base_y + bob
	rotation.y += spin_speed * delta

func set_movement(direction: Vector3, speed: float) -> void:
	move_direction = direction
	move_speed = speed

func _on_body_entered(body: Node) -> void:
	if body and body.is_in_group("player"):
		if body.has_method("apply_powerup"):
			body.apply_powerup(_get_type_key(), duration, _get_magnitude())
		_pickup()

func _get_type_key() -> String:
	if powerup_type == 0:
		return "speed_boost"
	if powerup_type == 1:
		return "slow_opponent"
	return "yank_opponent"

func _get_magnitude() -> float:
	if powerup_type == 0:
		return speed_multiplier
	if powerup_type == 1:
		return slow_multiplier
	return yank_strength

func _apply_color() -> void:
	if visual == null:
		return
	var mat = StandardMaterial3D.new()
	if powerup_type == 0:
		mat.albedo_color = Color(0.2, 0.9, 0.4, 1)
		mat.emission = Color(0.2, 0.9, 0.4, 1)
	elif powerup_type == 1:
		mat.albedo_color = Color(1.0, 0.45, 0.2, 1)
		mat.emission = Color(1.0, 0.45, 0.2, 1)
	else:
		mat.albedo_color = Color(0.2, 0.6, 1.0, 1)
		mat.emission = Color(0.2, 0.6, 1.0, 1)
	mat.emission_energy = 1.2
	visual.material_override = mat

func refresh_visual() -> void:
	_apply_color()

func set_base_height(y: float) -> void:
	_base_y = y
	var pos = global_position
	pos.y = y
	global_position = pos

func _pickup() -> void:
	set_deferred("monitoring", false)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
