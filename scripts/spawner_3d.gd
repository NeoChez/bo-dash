extends Node3D
@export var obstacle1_scene: PackedScene = preload("res://scenes/obstacle/obstacle_box.tscn")
@export var obstacle2_scene: PackedScene = preload("res://scenes/obstacle/obstacle_wall.tscn")
@export var obstacle3_scene: PackedScene = preload("res://scenes/obstacle/obstacle_wall2.tscn")
@export var obstacle4_scene: PackedScene = preload("res://scenes/obstacle/obstacle_spike.tscn")
@export var move_speed: float = 1.0
@export var spawn_interval: float = 4.0
@export var obstacle2_delay: float = 0.7
@export_enum("Ke Kiri:-1", "Ke Kanan:1") var arah_x: int = -1
@export var ground_node: Node3D
var spawn_timer: Timer

func _ready() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timer)
	add_child(spawn_timer)

func _on_spawn_timer() -> void:
	var roll = randi() % 3
	if roll == 0:
		_spawn(obstacle1_scene)
		await get_tree().create_timer(obstacle2_delay).timeout
		_spawn(obstacle2_scene)
	elif roll == 1:
		_spawn(obstacle3_scene)
	else:
		_spawn_spike()

func _spawn_spike() -> void:
	var obs = obstacle4_scene.instantiate()
	add_child(obs)
	obs.top_level = true
	obs.global_position = $Lane.global_position
	obs.global_position.z = randf_range(-5.0, 5.0)
	if ground_node:
		obs.global_position.y = ground_node.global_position.y + 1
	var direction = Vector3(arah_x, 0, 0)
	if obs.has_method("set_movement"):
		obs.set_movement(direction, move_speed)
	else:
		obs.set("move_direction", direction)
		obs.set("move_speed", move_speed)

func _spawn(scene: PackedScene) -> void:
	var obs = scene.instantiate()
	add_child(obs)
	obs.top_level = true
	obs.global_position = $Lane.global_position
	if ground_node:
		obs.global_position.y = ground_node.global_position.y + 1
	var direction = Vector3(arah_x, 0, 0)
	if obs.has_method("set_movement"):
		obs.set_movement(direction, move_speed)
	else:
		obs.set("move_direction", direction)
		obs.set("move_speed", move_speed)
	if ground_node and ground_node.has_method("register_obstacle"):
		ground_node.register_obstacle(obs)
