extends Node3D

@export var obstacle_scene: PackedScene = preload("res://global/obstacle_3d.tscn")
@export var powerup_scene: PackedScene = preload("res://scenes/powerups/powerup.tscn")
@export var spawn_interval: float = 2.0
@export var spawn_interval_jitter: float = 0.4
@export var move_speed: float = 8.0
@export var speed_random_range: Vector2 = Vector2(0.85, 1.2)
@export var lateral_jitter: float = 0.35
@export var y_jitter: float = 0.15
@export var rotation_y_jitter: float = 12.0
@export var scale_range: Vector2 = Vector2(0.85, 1.15)
@export var burst_chance: float = 0.0
@export var burst_extra_count: int = 1

@export var powerup_spawn_interval: float = 9.0
@export var powerup_spawn_chance: float = 0.25
@export var powerup_y_offset: float = 2.0
@export var powerup_y_jitter: float = 0.05
@export var powerup_lateral_jitter: float = 0.2
@export var powerup_chance_speed: float = 0.5
@export var powerup_chance_slow: float = 0.3
@export var powerup_chance_yank: float = 0.2

# --- PENGATURAN ARAH JADI LEBIH MUDAH ---
# Ini akan membuat dropdown di Inspector untuk memilih Kiri (-1) atau Kanan (1)
@export_enum("Ke Kiri:-1", "Ke Kanan:1") var arah_x: int = -1
# ----------------------------------------

# Referensi ke node Ground agar Spawner bisa melapor
@export var ground_node: Node3D
# Node conveyor untuk info wrapping (jika berbeda dari ground_node)
@export var conveyor_wrap_node: Node3D 

var spawn_points: Array = []
var last_spawn_index: int = -1
var obstacle_timer: Timer
var powerup_timer: Timer
var _obstacle_pool: Array[PackedScene] = []


func _ready() -> void:
	randomize()
	_obstacle_pool.append(obstacle_scene)
	var pillar := load("res://global/obstacle_pillar.tscn") as PackedScene
	var wall   := load("res://global/obstacle_wall.tscn")   as PackedScene
	if pillar != null:
		_obstacle_pool.append(pillar)
	if wall != null:
		_obstacle_pool.append(wall)
	
	for child in get_children():
		if child is Marker3D:
			spawn_points.append(child)

	obstacle_timer = Timer.new()
	obstacle_timer.autostart = false
	obstacle_timer.timeout.connect(_on_spawn_timer)
	add_child(obstacle_timer)
	_set_next_obstacle_interval()
	obstacle_timer.start()

	powerup_timer = Timer.new()
	powerup_timer.autostart = false
	powerup_timer.wait_time = powerup_spawn_interval
	powerup_timer.timeout.connect(_on_powerup_timer)
	add_child(powerup_timer)
	powerup_timer.start()

func _on_spawn_timer():
	if spawn_points.size() == 0:
		return

	var lane_index = _pick_lane()
	var spawn_point = spawn_points[lane_index]

	spawn_obstacle(spawn_point)
	_try_spawn_burst(lane_index)
	_set_next_obstacle_interval()

func _on_powerup_timer() -> void:
	if spawn_points.size() == 0:
		return
	if powerup_scene == null:
		return
	if randf() > powerup_spawn_chance:
		return

	var lane_index = _pick_lane()
	var spawn_point = spawn_points[lane_index]
	spawn_powerup(spawn_point)

func _set_next_obstacle_interval() -> void:
	if obstacle_timer == null:
		return
	var jitter = randf_range(-spawn_interval_jitter, spawn_interval_jitter)
	obstacle_timer.wait_time = max(0.2, spawn_interval + jitter)

func _pick_lane() -> int:
	var lane_index = randi() % spawn_points.size()
	while lane_index == last_spawn_index and spawn_points.size() > 1:
		lane_index = randi() % spawn_points.size()
	last_spawn_index = lane_index
	return lane_index

func _try_spawn_burst(exclude_lane_index: int) -> void:
	if spawn_points.size() <= 1:
		return
	if randf() > burst_chance:
		return

	var spawned = 0
	while spawned < burst_extra_count:
		var lane_index = randi() % spawn_points.size()
		if lane_index == exclude_lane_index:
			continue
		spawn_obstacle(spawn_points[lane_index])
		spawned += 1

func _pick_obstacle_scene() -> PackedScene:
	var n := _obstacle_pool.size()
	if n <= 1:
		return _obstacle_pool[0]
	var roll: float = randf()
	if n == 2:
		return _obstacle_pool[0] if roll < 0.55 else _obstacle_pool[1]
	# 3 types: slab 40%, pillar 40%, wall 20%
	if roll < 0.40: return _obstacle_pool[0]
	if roll < 0.80: return _obstacle_pool[1]
	return _obstacle_pool[2]


func spawn_obstacle(spawn_point: Marker3D):
	var obs: Node3D = _pick_obstacle_scene().instantiate()

	add_child(obs)
	obs.top_level = true
	obs.global_transform = spawn_point.global_transform

	var full_width: bool = obs.get("is_full_width") == true
	if full_width:
		_apply_spawn_juice(obs)
	else:
		_apply_spawn_jitter(obs)
		_apply_spawn_juice(obs)

	# Snap to conveyor surface so obstacles rest on it
	var wrap_src: Node3D = conveyor_wrap_node if conveyor_wrap_node else ground_node
	if wrap_src != null:
		obs.global_position.y = wrap_src.global_position.y + 1.0

	var move_direction: Vector3 = Vector3(arah_x, 0, 0)
	var speed: float = move_speed * randf_range(speed_random_range.x, speed_random_range.y)

	if obs.has_method("set_movement"):
		obs.set_movement(move_direction, speed)
	else:
		obs.set("move_speed", speed)
		obs.set("move_direction", move_direction)

	if not obs.is_in_group("item"):
		obs.add_to_group("item")
	if not obs.is_in_group("obstacle"):
		obs.add_to_group("obstacle")

	if ground_node:
		ground_node.register_obstacle(obs)

	if wrap_src != null and obs.has_method("set_conveyor_info"):
		var g_pos: Vector3 = wrap_src.global_position
		var end_x: float = g_pos.x + float(arah_x) * 50.0
		obs.set_conveyor_info(end_x, g_pos.y, 2.0)

func spawn_powerup(spawn_point: Marker3D) -> void:
	var powerup = powerup_scene.instantiate()

	add_child(powerup)
	powerup.top_level = true
	powerup.global_transform = spawn_point.global_transform
	powerup.global_position.y += powerup_y_offset
	_apply_powerup_jitter(powerup)
	_apply_spawn_juice(powerup)
	if powerup.has_method("set_base_height"):
		powerup.set_base_height(powerup.global_position.y)

	if powerup.get("powerup_type") != null:
		powerup.set("powerup_type", _pick_powerup_type())
		if powerup.has_method("refresh_visual"):
			powerup.refresh_visual()

	var move_direction = Vector3(arah_x, 0, 0)
	var speed = move_speed * randf_range(speed_random_range.x, speed_random_range.y)
	if powerup.has_method("set_movement"):
		powerup.set_movement(move_direction, speed)
	elif powerup.has_variable("move_direction"):
		powerup.move_direction = move_direction
		powerup.move_speed = speed

	if not powerup.is_in_group("item"):
		powerup.add_to_group("item")
	if not powerup.is_in_group("powerup"):
		powerup.add_to_group("powerup")

	if ground_node:
		ground_node.register_obstacle(powerup)

func _pick_powerup_type() -> int:
	var total = powerup_chance_speed + powerup_chance_slow + powerup_chance_yank
	if total <= 0.0:
		return 0
	var roll = randf() * total
	if roll < powerup_chance_speed:
		return 0
	if roll < powerup_chance_speed + powerup_chance_slow:
		return 1
	return 2

func _apply_spawn_jitter(node: Node3D) -> void:
	var offset = Vector3(0, randf_range(-y_jitter, y_jitter), randf_range(-lateral_jitter, lateral_jitter))
	node.global_position += offset
	node.rotation.y += deg_to_rad(randf_range(-rotation_y_jitter, rotation_y_jitter))

func _apply_powerup_jitter(node: Node3D) -> void:
	var offset = Vector3(0, randf_range(-powerup_y_jitter, powerup_y_jitter), randf_range(-powerup_lateral_jitter, powerup_lateral_jitter))
	node.global_position += offset

func _apply_spawn_juice(node: Node3D) -> void:
	var base_scale = randf_range(scale_range.x, scale_range.y)
	var target_scale = Vector3.ONE * base_scale
	var start_scale = target_scale * 0.7
	node.scale = start_scale
	var tween = create_tween()
	tween.tween_property(node, "scale", target_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
