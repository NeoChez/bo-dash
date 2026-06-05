extends Node3D

# --- Obstacle scenes ---
@export var obstacle1_scene: PackedScene = preload("res://scenes/obstacle/obstacle_box.tscn")
@export var obstacle2_scene: PackedScene = preload("res://scenes/obstacle/obstacle_wall.tscn")
@export var obstacle3_scene: PackedScene = preload("res://scenes/obstacle/obstacle_wall2.tscn")
@export var obstacle4_scene: PackedScene = preload("res://scenes/obstacle/obstacle_spike.tscn")
@export var obstacle5_scene: PackedScene = preload("res://scenes/obstacle/obstacle_chalwall.tscn")
@export var obstacle6_scene: PackedScene = preload("res://scenes/obstacle/obstacle_chalwall2.tscn")
@export var obstacle7_scene: PackedScene = preload("res://scenes/obstacle/obstacle_destruct.tscn")
@export var offset_obstacle1: Vector3 = Vector3.ZERO
@export var offset_obstacle2: Vector3 = Vector3.ZERO
@export var offset_obstacle3: Vector3 = Vector3.ZERO
@export var offset_obstacle4: Vector3 = Vector3.ZERO
@export var offset_obstacle5: Vector3 = Vector3.ZERO
@export var offset_obstacle6: Vector3 = Vector3.ZERO
@export var offset_obstacle7: Vector3 = Vector3.ZERO
@export var obstacle2_delay: float = 1.5
@export var chalwall_delay: float = 2.0

# --- Internal setup (tidak perlu diubah) ---
@export var obstacles_enabled: bool = true
@export_enum("Ke Kiri:-1", "Ke Kanan:1") var arah_x: int = -1
@export var ground_node: Node3D
@export var conveyor_wrap_node: Node3D
@export var star_scene: PackedScene = preload("res://scenes/powerups/star_collectible.tscn")
@export var skill_item_scene: PackedScene = preload("res://scenes/powerups/skill_item.tscn")
@export var star_y_offset: float = 2.4
@export var star_y_jitter: float = 0.08
@export var star_lateral_jitter: float = 0.25

# ── TWEAK: Obstacle ──────────────────────────────────────────────────────
@export_group("Tweak — Obstacle")
@export var spawn_interval: float = 3.5
@export var move_speed: float = 9.5

# ── TWEAK: Star ──────────────────────────────────────────────────────────
@export_group("Tweak — Star")
@export var star_spawn_interval: float = 4.2
@export var star_spawn_chance: float = 0.78

# ── TWEAK: Skill ─────────────────────────────────────────────────────────
@export_group("Tweak — Skill")
@export var skill_spawn_interval: float = 10.0
@export var skill_spawn_chance: float = 0.65

# --- Kurva intensitas (internal, tidak perlu diubah) ---
var min_spawn_interval: float = 0.65
var max_move_speed_multiplier: float = 3.0
var early_game_spawn_scale: float = 1.2
var late_game_spawn_scale: float = 0.38
var mid_game_start: float = 0.28
var late_game_start: float = 0.62
var frenzy_start: float = 0.84
var star_early_chance: float = 0.58
var star_late_chance: float = 0.98
var star_early_interval_scale: float = 1.18
var star_late_interval_scale: float = 0.33
var star_min_interval: float = 1.2
var skill_early_chance: float = 0.50
var skill_late_chance: float = 0.95
var skill_early_interval_scale: float = 1.22
var skill_late_interval_scale: float = 0.30
var skill_min_interval: float = 2.4

# Titik tengah untuk obstacle (node "Lane")
var _obstacle_lane: Marker3D = null
# Semua lane untuk star/skill
var _powerup_lanes: Array[Marker3D] = []
var _last_powerup_lane: int = -1

var spawn_timer: Timer
var star_timer: Timer
var skill_timer: Timer
var _match_active: bool = true
var _base_spawn_interval: float = 0.0
var _base_move_speed: float = 0.0
var _base_star_spawn_interval: float = 0.0
var _base_skill_spawn_interval: float = 0.0
var _intensity_progress: float = 0.0


func _ready() -> void:
	randomize()
	_base_spawn_interval = spawn_interval
	_base_move_speed = move_speed
	_base_star_spawn_interval = star_spawn_interval
	_base_skill_spawn_interval = skill_spawn_interval

	for child in get_children():
		if child is Marker3D:
			_powerup_lanes.append(child)
			if child.name == "Lane":
				_obstacle_lane = child

	# Fallback: pakai lane pertama jika tidak ada yang bernama "Lane"
	if _obstacle_lane == null and not _powerup_lanes.is_empty():
		_obstacle_lane = _powerup_lanes[0]

	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(spawn_timer)

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


func _pick_powerup_lane() -> Marker3D:
	if _powerup_lanes.is_empty():
		return _obstacle_lane
	if _powerup_lanes.size() == 1:
		return _powerup_lanes[0]
	var index := randi() % _powerup_lanes.size()
	var tries := 0
	while index == _last_powerup_lane and tries < 5:
		index = randi() % _powerup_lanes.size()
		tries += 1
	_last_powerup_lane = index
	return _powerup_lanes[index]


# ─── OBSTACLE (fixed lane, pattern asli) ──────────────────────────────────────

func _on_spawn_timer() -> void:
	if not _match_active or not obstacles_enabled or _obstacle_lane == null:
		return

	# Stop timer dulu agar tidak fire lagi saat kita masih dalam await (pair spawn)
	spawn_timer.stop()

	var roll := randi() % 5
	if roll == 0:
		_spawn(obstacle1_scene, offset_obstacle1)
		await get_tree().create_timer(obstacle2_delay).timeout
		_spawn(obstacle2_scene, offset_obstacle2)
	elif roll == 1:
		_spawn(obstacle3_scene, offset_obstacle3)
	elif roll == 2:
		_spawn(obstacle4_scene, offset_obstacle4)
	elif roll == 3:
		_spawn(obstacle5_scene, offset_obstacle5)
		await get_tree().create_timer(chalwall_delay).timeout
		_spawn(obstacle6_scene, offset_obstacle6)
	else:
		_spawn(obstacle7_scene, offset_obstacle7)

	# Restart setelah semua obstacle selesai spawn → gap selalu >= spawn_interval
	if _match_active and obstacles_enabled:
		spawn_timer.start(spawn_interval)


func _spawn(scene: PackedScene, offset: Vector3 = Vector3.ZERO) -> void:
	if scene == null or _obstacle_lane == null:
		return
	var obs := scene.instantiate()
	add_child(obs)
	obs.top_level = true
	obs.global_position = _obstacle_lane.global_position + offset
	if ground_node:
		obs.global_position.y = ground_node.global_position.y + 1.0 + offset.y
	var direction := Vector3(arah_x, 0, 0)
	if obs.has_method("set_movement"):
		obs.set_movement(direction, move_speed)
	else:
		obs.set("move_direction", direction)
		obs.set("move_speed", move_speed)
	if ground_node and ground_node.has_method("register_obstacle"):
		ground_node.register_obstacle(obs)


# ─── STAR (multi-lane) ────────────────────────────────────────────────────────

func _on_star_timer() -> void:
	if _match_active and star_scene != null and randf() <= star_spawn_chance:
		_spawn_star()
	star_timer.wait_time = star_spawn_interval
	star_timer.start()


func _spawn_star() -> void:
	var lane := _pick_powerup_lane()
	if lane == null:
		return
	var star := star_scene.instantiate()
	add_child(star)
	star.top_level = true
	star.global_position = lane.global_position
	star.global_position.y += star_y_offset + randf_range(-star_y_jitter, star_y_jitter)
	star.global_position.z += randf_range(-star_lateral_jitter, star_lateral_jitter)
	if star.has_method("set_base_height"):
		star.set_base_height(star.global_position.y)
	var move_dir := Vector3(arah_x, 0, 0)
	if star.has_method("set_movement"):
		star.set_movement(move_dir, move_speed)
	else:
		star.set("move_direction", move_dir)
		star.set("move_speed", move_speed)
	if not star.is_in_group("item"):
		star.add_to_group("item")
	if not star.is_in_group("star"):
		star.add_to_group("star")
	if ground_node and ground_node.has_method("register_obstacle"):
		ground_node.register_obstacle(star)


# ─── SKILL (multi-lane) ───────────────────────────────────────────────────────

func _on_skill_timer() -> void:
	if _match_active and skill_item_scene != null and randf() <= skill_spawn_chance:
		_spawn_skill()
	skill_timer.wait_time = skill_spawn_interval
	skill_timer.start()


func _spawn_skill() -> void:
	var lane := _pick_powerup_lane()
	if lane == null:
		return
	var item := skill_item_scene.instantiate()
	add_child(item)
	item.top_level = true
	item.global_position = lane.global_position
	item.global_position.y += 1.5
	item.global_position.z += randf_range(-0.3, 0.3)
	if item.has_method("set_base_height"):
		item.set_base_height(item.global_position.y)
	if item.get("skill_type") != null:
		item.set("skill_type", -1)
	var move_dir := Vector3(arah_x, 0, 0)
	if item.has_method("set_movement"):
		item.set_movement(move_dir, move_speed)
	else:
		item.set("move_direction", move_dir)
		item.set("move_speed", move_speed)
	if not item.is_in_group("item"):
		item.add_to_group("item")
	if ground_node and ground_node.has_method("register_obstacle"):
		ground_node.register_obstacle(item)


# ─── MATCH CONTROL ────────────────────────────────────────────────────────────

func set_speed_multiplier(mult: float) -> void:
	move_speed = _base_move_speed * mult


func set_match_active(active: bool) -> void:
	_match_active = active
	if spawn_timer != null:
		spawn_timer.paused = not active
	if star_timer != null:
		star_timer.paused = not active
	if skill_timer != null:
		skill_timer.paused = not active


func set_match_progress(progress: float) -> void:
	_intensity_progress = clamp(progress, 0.0, 1.0)
	var phase_curve: float = _get_phase_curve()

	# Obstacle speed & spawn rate
	var spawn_scale: float = lerpf(early_game_spawn_scale, late_game_spawn_scale, phase_curve)
	spawn_interval = max(min_spawn_interval, _base_spawn_interval * spawn_scale)
	move_speed = lerpf(_base_move_speed * 0.92, _base_move_speed * max_move_speed_multiplier, phase_curve)
	if spawn_timer != null:
		spawn_timer.wait_time = spawn_interval

	# Star spawn rate & chance
	var star_scale: float = lerpf(star_early_interval_scale, star_late_interval_scale, phase_curve)
	star_spawn_interval = max(star_min_interval, _base_star_spawn_interval * star_scale)
	star_spawn_chance = lerpf(star_early_chance, star_late_chance, phase_curve)

	# Skill spawn rate & chance
	var skill_scale: float = lerpf(skill_early_interval_scale, skill_late_interval_scale, phase_curve)
	skill_spawn_interval = max(skill_min_interval, _base_skill_spawn_interval * skill_scale)
	skill_spawn_chance = lerpf(skill_early_chance, skill_late_chance, phase_curve)


func _get_phase_curve() -> float:
	if _intensity_progress <= mid_game_start:
		return lerpf(0.0, 0.22, inverse_lerp(0.0, mid_game_start, _intensity_progress))
	if _intensity_progress <= late_game_start:
		return lerpf(0.22, 0.68, inverse_lerp(mid_game_start, late_game_start, _intensity_progress))
	if _intensity_progress <= frenzy_start:
		return lerpf(0.68, 0.9, inverse_lerp(late_game_start, frenzy_start, _intensity_progress))
	return lerpf(0.9, 1.0, inverse_lerp(frenzy_start, 1.0, _intensity_progress))
