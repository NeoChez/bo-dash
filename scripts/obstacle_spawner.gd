extends Node2D

@export var obstacle_scene: PackedScene
@export var spawn_interval_min: float = 1.4
@export var spawn_interval_max: float = 2.6
@export var spawn_y_jitter: float = 150.0
@export var debug_print: bool = true

var _spawn_points: Array[Marker2D] = []
var _timer: Timer

func _ready() -> void:
	for child in get_children():
		if child is Marker2D:
			_spawn_points.append(child)
	if debug_print:
		print("[Spawner] _ready, ", _spawn_points.size(), " markers found")
		for sp in _spawn_points:
			print("  ", sp.name, " local=", sp.position, " global=", sp.global_position,
				" dir=", sp.get_meta("direction", "?"), " speed=", sp.get_meta("speed", "?"))
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_timer)
	_schedule_next()

func _schedule_next() -> void:
	_timer.start(randf_range(spawn_interval_min, spawn_interval_max))

func _on_timer() -> void:
	_spawn_one()
	_schedule_next()

func _spawn_one() -> void:
	if _spawn_points.is_empty() or obstacle_scene == null:
		return
	var sp: Marker2D = _spawn_points.pick_random()
	var pos: Vector2 = sp.global_position
	if spawn_y_jitter > 0.0:
		pos.y += randf_range(-spawn_y_jitter, spawn_y_jitter)

	var obs := obstacle_scene.instantiate()
	get_tree().current_scene.add_child(obs)
	obs.global_position = pos

	if sp.has_meta("direction") and "move_direction" in obs:
		obs.move_direction = sp.get_meta("direction")
	if sp.has_meta("speed") and "move_speed" in obs:
		obs.move_speed = sp.get_meta("speed")

	if debug_print:
		print("[Spawner] spawned at ", obs.global_position, " from ", sp.name,
			" (marker global=", sp.global_position, ")")
