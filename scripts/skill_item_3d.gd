extends Area3D

@export_enum("Speed Boost:0", "Slow Opponent:1", "Yank Opponent:2") var skill_type: int = 0
@export var move_speed: float = 7.0
@export var move_direction: Vector3 = Vector3(-1, 0, 0)
@export var bob_height: float = 0.22
@export var bob_speed: float = 3.5
@export var spin_speed: float = 2.2

@onready var visual: MeshInstance3D = $Visual

var _base_y: float = 0.0
var _time_accum: float = 0.0


func _ready() -> void:
	_base_y = global_position.y
	body_entered.connect(_on_body_entered)
	_apply_visual()


func _physics_process(delta: float) -> void:
	global_position += move_direction * move_speed * delta


func _process(delta: float) -> void:
	_time_accum += delta
	global_position.y = _base_y + sin(_time_accum * bob_speed) * bob_height
	rotation.y += spin_speed * delta


func set_movement(direction: Vector3, speed: float) -> void:
	move_direction = direction
	move_speed = speed


func set_base_height(y: float) -> void:
	_base_y = y
	var pos := global_position
	pos.y = y
	global_position = pos


func refresh_visual() -> void:
	_apply_visual()


func _on_body_entered(body: Node) -> void:
	if body == null or not body.is_in_group("player"):
		return
	var player_id: int = int(body.get("player_id"))
	get_tree().call_group("match_controller", "on_skill_picked_up", player_id, skill_type)
	_pickup()


func _apply_visual() -> void:
	if visual == null:
		return
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission_energy_multiplier = 1.6
	match skill_type:
		0:
			mat.albedo_color = Color(0.2, 0.9, 0.4)
			mat.emission = Color(0.2, 0.9, 0.4)
		1:
			mat.albedo_color = Color(1.0, 0.45, 0.2)
			mat.emission = Color(1.0, 0.45, 0.2)
		_:
			mat.albedo_color = Color(0.2, 0.6, 1.0)
			mat.emission = Color(0.2, 0.6, 1.0)
	visual.material_override = mat


func _pickup() -> void:
	set_deferred("monitoring", false)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
