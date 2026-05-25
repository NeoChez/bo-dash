extends Node3D

@export var obstacle_scene: PackedScene = preload("res://global/obstacle_3d.tscn")
@export var powerup_scene: PackedScene = preload("res://scenes/powerups/powerup.tscn")
@export var star_scene: PackedScene = preload("res://scenes/powerups/star_collectible.tscn")
@export var obstacles_enabled: bool = true
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
@export var min_spawn_interval: float = 1.35
@export var max_move_speed_multiplier: float = 1.45
@export var max_burst_chance: float = 0.55
@export var max_burst_extra_count: int = 2
@export var lane_repeat_reduction: float = 0.0
@export var pattern_double_chance: float = 0.28
@export var pattern_wall_chance: float = 0.18
@export var pattern_triplet_chance: float = 0.12
@export var early_game_spawn_scale: float = 1.2
@export var late_game_spawn_scale: float = 0.78
@export var mid_game_start: float = 0.28
@export var late_game_start: float = 0.62
@export var frenzy_start: float = 0.84

@export var powerup_spawn_interval: float = 9.0
@export var powerup_spawn_chance: float = 0.25
@export var powerup_y_offset: float = 2.0
@export var powerup_y_jitter: float = 0.05
@export var powerup_lateral_jitter: float = 0.2
@export var powerup_chance_speed: float = 0.5
@export var powerup_chance_slow: float = 0.3
@export var powerup_chance_yank: float = 0.2
@export var star_spawn_interval: float = 5.5
@export var star_spawn_chance: float = 0.7
@export var star_y_offset: float = 2.4
@export var star_y_jitter: float = 0.08
@export var star_lateral_jitter: float = 0.25

@export var skill_item_scene: PackedScene = preload("res://scenes/powerups/skill_item.tscn")
@export var skill_spawn_interval: float = 14.0
@export var skill_spawn_chance: float = 0.55

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
var star_timer: Timer
var skill_timer: Timer
var _obstacle_pool: Array[PackedScene] = []
var _obstacle_weights: Array[float] = []
var _pillar_scene: PackedScene
var _wall_scene: PackedScene
var _match_active: bool = true
var _base_spawn_interval: float = 0.0
var _base_move_speed: float = 0.0
var _base_burst_chance: float = 0.0
var _base_burst_extra_count: int = 1
var _intensity_progress: float = 0.0


func _ready() -> void:
	randomize()
	_base_spawn_interval = spawn_interval
	_base_move_speed = move_speed
	_base_burst_chance = burst_chance
	_base_burst_extra_count = burst_extra_count

	_obstacle_pool.append(obstacle_scene)
	_obstacle_weights.append(0.27)

	var pillar := load("res://global/obstacle_pillar.tscn") as PackedScene
	if pillar != null:
		_pillar_scene = pillar
		_obstacle_pool.append(pillar)
		_obstacle_weights.append(0.20)

	var wall := load("res://global/obstacle_wall.tscn") as PackedScene
	if wall != null:
		_wall_scene = wall
		_obstacle_pool.append(wall)
		_obstacle_weights.append(0.15)

	var sphere := load("res://global/obstacle_sphere.tscn") as PackedScene
	if sphere != null:
		_obstacle_pool.append(sphere)
		_obstacle_weights.append(0.17)

	var cone := load("res://global/obstacle_cone.tscn") as PackedScene
	if cone != null:
		_obstacle_pool.append(cone)
		_obstacle_weights.append(0.13)

	var arch := load("res://global/obstacle_arch.tscn") as PackedScene
	if arch != null:
		_obstacle_pool.append(arch)
		_obstacle_weights.append(0.08)
	
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

	star_timer = Timer.new()
	star_timer.autostart = false
	star_timer.wait_time = star_spawn_interval
	star_timer.timeout.connect(_on_star_timer)
	add_child(star_timer)
	star_timer.start()

	skill_timer = Timer.new()
	skill_timer.autostart = false
	skill_timer.wait_time = skill_spawn_interval
	skill_timer.timeout.connect(_on_skill_timer)
	add_child(skill_timer)
	skill_timer.start()

func _on_spawn_timer():
	if not _match_active:
		return
	if not obstacles_enabled:
		_set_next_obstacle_interval()
		return
	if spawn_points.size() == 0:
		return

	var lane_index = _pick_lane()
	var spawn_point = spawn_points[lane_index]

	_spawn_obstacle_pattern(lane_index, spawn_point)
	_set_next_obstacle_interval()

func _on_powerup_timer() -> void:
	if not _match_active:
		return
	if spawn_points.size() == 0:
		return
	if powerup_scene == null:
		return
	if randf() > powerup_spawn_chance:
		return

	var lane_index = _pick_lane()
	var spawn_point = spawn_points[lane_index]
	spawn_powerup(spawn_point)

func _on_star_timer() -> void:
	if not _match_active:
		return
	if spawn_points.size() == 0:
		return
	if star_scene == null:
		return
	if randf() > star_spawn_chance:
		return

	var lane_index = _pick_lane()
	spawn_star(spawn_points[lane_index])

func _on_skill_timer() -> void:
	if not _match_active:
		return
	if spawn_points.size() == 0:
		return
	if skill_item_scene == null:
		return
	if randf() > skill_spawn_chance:
		skill_timer.wait_time = skill_spawn_interval
		skill_timer.start()
		return
	var lane_index = _pick_lane()
	spawn_skill(spawn_points[lane_index])
	skill_timer.wait_time = skill_spawn_interval
	skill_timer.start()

func spawn_skill(spawn_point: Marker3D) -> void:
	var item = skill_item_scene.instantiate()
	var wrap_src: Node3D = conveyor_wrap_node if conveyor_wrap_node else ground_node

	add_child(item)
	item.top_level = true
	item.global_transform = spawn_point.global_transform
	if wrap_src != null:
		item.global_position.y = wrap_src.global_position.y + 1.0
	item.global_position.z += randf_range(-0.3, 0.3)
	if item.has_method("set_base_height"):
		item.set_base_height(item.global_position.y)

	var skill_type: int = randi() % 3
	if item.get("skill_type") != null:
		item.set("skill_type", skill_type)
	if item.has_method("refresh_visual"):
		item.refresh_visual()

	var move_direction := Vector3(arah_x, 0, 0)
	var speed := move_speed * randf_range(speed_random_range.x, speed_random_range.y)
	if item.has_method("set_movement"):
		item.set_movement(move_direction, speed)

	if not item.is_in_group("item"):
		item.add_to_group("item")

	if ground_node:
		ground_node.register_obstacle(item)
	elif wrap_src != null and wrap_src.has_method("register_obstacle"):
		wrap_src.register_obstacle(item)

func _set_next_obstacle_interval() -> void:
	if obstacle_timer == null:
		return
	var jitter = randf_range(-spawn_interval_jitter, spawn_interval_jitter)
	obstacle_timer.wait_time = max(0.2, spawn_interval + jitter)

func _pick_lane() -> int:
	var lane_index = randi() % spawn_points.size()
	while lane_index == last_spawn_index and spawn_points.size() > 1 and randf() > lane_repeat_reduction:
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


func _spawn_obstacle_pattern(lane_index: int, spawn_point: Marker3D) -> void:
	var roll: float = randf()
	var pattern_scale: float = _get_pattern_scale()
	var triplet_gate: float = pattern_triplet_chance * pattern_scale
	var wall_gate: float = triplet_gate + pattern_wall_chance * pattern_scale
	var double_gate: float = wall_gate + pattern_double_chance * pattern_scale

	if spawn_points.size() >= 3 and roll < triplet_gate:
		_spawn_triplet_pattern(lane_index)
		return
	if roll < wall_gate:
		_spawn_wall_pattern(lane_index)
		return
	if spawn_points.size() > 1 and roll < double_gate:
		_spawn_double_pattern(lane_index)
		return

	spawn_obstacle(spawn_point)
	_try_spawn_burst(lane_index)


func _spawn_double_pattern(primary_lane_index: int) -> void:
	spawn_obstacle(spawn_points[primary_lane_index])
	var options: Array[int] = []
	for i in range(spawn_points.size()):
		if i != primary_lane_index:
			options.append(i)
	if options.is_empty():
		return
	var secondary_lane_index: int = options[randi() % options.size()]
	var forced_scene: PackedScene = _pillar_scene if _pillar_scene != null and randf() < 0.65 else null
	spawn_obstacle(spawn_points[secondary_lane_index], forced_scene)


func _spawn_wall_pattern(primary_lane_index: int) -> void:
	if _wall_scene != null and randf() < 0.85:
		spawn_obstacle(spawn_points[primary_lane_index], _wall_scene)
	else:
		spawn_obstacle(spawn_points[primary_lane_index])
	if spawn_points.size() <= 1:
		return
	var escort_options: Array[int] = []
	for i in range(spawn_points.size()):
		if i != primary_lane_index:
			escort_options.append(i)
	if escort_options.is_empty():
		return
	var escort_lane_index: int = escort_options[randi() % escort_options.size()]
	var escort_scene: PackedScene = _pillar_scene if _pillar_scene != null else obstacle_scene
	spawn_obstacle(spawn_points[escort_lane_index], escort_scene)


func _spawn_triplet_pattern(primary_lane_index: int) -> void:
	var ordered_lanes: Array[int] = [primary_lane_index]
	for i in range(spawn_points.size()):
		if i != primary_lane_index:
			ordered_lanes.append(i)
	for i in range(min(ordered_lanes.size(), 3)):
		var forced_scene: PackedScene = null
		if i == 1 and _pillar_scene != null:
			forced_scene = _pillar_scene
		elif i == 2 and _wall_scene != null and randf() < 0.4:
			forced_scene = _wall_scene
		spawn_obstacle(spawn_points[ordered_lanes[i]], forced_scene)

func _pick_obstacle_scene() -> PackedScene:
	if _obstacle_pool.is_empty():
		return obstacle_scene
	if _obstacle_pool.size() == 1:
		return _obstacle_pool[0]
	var total: float = 0.0
	for i in range(min(_obstacle_pool.size(), _obstacle_weights.size())):
		total += _obstacle_weights[i]
	if total <= 0.0:
		return _obstacle_pool[randi() % _obstacle_pool.size()]
	var roll := randf() * total
	var cum := 0.0
	for i in range(_obstacle_pool.size()):
		cum += _obstacle_weights[i] if i < _obstacle_weights.size() else 1.0
		if roll < cum:
			return _obstacle_pool[i]
	return _obstacle_pool[-1]


func spawn_obstacle(spawn_point: Marker3D, forced_scene: PackedScene = null):
	var obstacle_resource: PackedScene = forced_scene if forced_scene != null else _pick_obstacle_scene()
	var obs: Node3D = obstacle_resource.instantiate()

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
	elif wrap_src != null and wrap_src.has_method("register_obstacle"):
		wrap_src.register_obstacle(obs)

	if wrap_src != null and obs.has_method("set_conveyor_info"):
		var g_pos: Vector3 = wrap_src.global_position
		var end_x: float = g_pos.x + float(arah_x) * 50.0
		obs.set_conveyor_info(end_x, g_pos.y, 2.0)

func spawn_powerup(spawn_point: Marker3D) -> void:
	var powerup = powerup_scene.instantiate()
	var wrap_src: Node3D = conveyor_wrap_node if conveyor_wrap_node else ground_node

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
	elif wrap_src != null and wrap_src.has_method("register_obstacle"):
		wrap_src.register_obstacle(powerup)

func spawn_star(spawn_point: Marker3D) -> void:
	var star = star_scene.instantiate()
	var wrap_src: Node3D = conveyor_wrap_node if conveyor_wrap_node else ground_node

	add_child(star)
	star.top_level = true
	star.global_transform = spawn_point.global_transform
	star.global_position.y += star_y_offset
	_apply_star_jitter(star)
	_apply_spawn_juice(star)
	if star.has_method("set_base_height"):
		star.set_base_height(star.global_position.y)

	var move_direction = Vector3(arah_x, 0, 0)
	var speed = move_speed * randf_range(speed_random_range.x, speed_random_range.y)
	if star.has_method("set_movement"):
		star.set_movement(move_direction, speed)
	elif star.has_variable("move_direction"):
		star.move_direction = move_direction
		star.move_speed = speed

	if not star.is_in_group("item"):
		star.add_to_group("item")
	if not star.is_in_group("star"):
		star.add_to_group("star")

	if ground_node:
		ground_node.register_obstacle(star)
	elif wrap_src != null and wrap_src.has_method("register_obstacle"):
		wrap_src.register_obstacle(star)

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

func _apply_star_jitter(node: Node3D) -> void:
	var offset = Vector3(0, randf_range(-star_y_jitter, star_y_jitter), randf_range(-star_lateral_jitter, star_lateral_jitter))
	node.global_position += offset

func _apply_spawn_juice(node: Node3D) -> void:
	var base_scale = randf_range(scale_range.x, scale_range.y)
	var target_scale = Vector3.ONE * base_scale
	var start_scale = target_scale * 0.7
	node.scale = start_scale
	var tween = create_tween()
	tween.tween_property(node, "scale", target_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func set_match_active(active: bool) -> void:
	_match_active = active
	if obstacle_timer != null:
		obstacle_timer.paused = not active
	if powerup_timer != null:
		powerup_timer.paused = not active
	if star_timer != null:
		star_timer.paused = not active
	if skill_timer != null:
		skill_timer.paused = not active

func set_match_progress(progress: float) -> void:
	_intensity_progress = clamp(progress, 0.0, 1.0)
	var phase_curve: float = _get_phase_curve()
	var spawn_scale: float = lerp(early_game_spawn_scale, late_game_spawn_scale, phase_curve)
	spawn_interval = max(min_spawn_interval, _base_spawn_interval * spawn_scale)
	move_speed = lerp(_base_move_speed * 0.92, _base_move_speed * max_move_speed_multiplier, phase_curve)
	burst_chance = lerp(_base_burst_chance, max_burst_chance, phase_curve)
	burst_extra_count = int(round(lerp(float(_base_burst_extra_count), float(max_burst_extra_count), phase_curve)))
	lane_repeat_reduction = lerp(0.0, 0.42, phase_curve)


func _get_phase_curve() -> float:
	if _intensity_progress <= mid_game_start:
		return lerp(0.0, 0.22, inverse_lerp(0.0, mid_game_start, _intensity_progress))
	if _intensity_progress <= late_game_start:
		return lerp(0.22, 0.68, inverse_lerp(mid_game_start, late_game_start, _intensity_progress))
	if _intensity_progress <= frenzy_start:
		return lerp(0.68, 0.9, inverse_lerp(late_game_start, frenzy_start, _intensity_progress))
	return lerp(0.9, 1.0, inverse_lerp(frenzy_start, 1.0, _intensity_progress))


func _get_pattern_scale() -> float:
	if _intensity_progress < mid_game_start:
		return 0.18
	if _intensity_progress < late_game_start:
		return 0.6
	if _intensity_progress < frenzy_start:
		return 0.9
	return 1.15
