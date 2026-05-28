extends StaticBody3D

@export var conveyor_direction: Vector3 = Vector3(-1, 0, 0)  
@export var conveyor_speed: float = 5.0 
@export var despawn_distance_from_center: float = 80.0

var active_obstacles: Array = []
var despawn_y_limit: float = -20.0  
var _despawn_x_limit: float = -80.0
var _moves_positive_x: bool = false

func _ready() -> void:
	# Setup conveyor velocity untuk mendorong player
	var push_velocity = conveyor_direction.normalized() * conveyor_speed
	constant_linear_velocity = push_velocity
	_moves_positive_x = push_velocity.x > 0.0
	_despawn_x_limit = 0.0

	# Timer untuk cleanup obstacle yang sudah lewat
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 0.5
	cleanup_timer.autostart = true
	cleanup_timer.timeout.connect(_cleanup_obstacles)
	add_child(cleanup_timer)
	
# Fungsi ini akan dipanggil oleh Spawner untuk mendaftarkan obstacle baru
func register_obstacle(obs: Node3D) -> void:
	active_obstacles.append(obs)

func _cleanup_obstacles() -> void:
	# Hapus obstacle yang sudah lewat jauh di belakang player atau jatuh terlalu jauh
	for i in range(active_obstacles.size() - 1, -1, -1):
		var obs = active_obstacles[i]
		if not is_instance_valid(obs):
			active_obstacles.remove_at(i)
		elif _should_despawn(obs):
			if obs.has_method("start_fall"):
				obs.start_fall()
			else:
				obs.queue_free()
			active_obstacles.remove_at(i)

func _should_despawn(obs: Node3D) -> bool:
	if obs.global_position.y < despawn_y_limit:
		return true
	if _moves_positive_x:
		return obs.global_position.x > _despawn_x_limit
	return obs.global_position.x < _despawn_x_limit
