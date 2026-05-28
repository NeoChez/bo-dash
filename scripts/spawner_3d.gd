extends Node3D
@export var obstacle1_scene: PackedScene = preload("res://scenes/obstacle/obstacle_box.tscn")
@export var obstacle2_scene: PackedScene = preload("res://scenes/obstacle/obstacle_wall.tscn")
@export var obstacle3_scene: PackedScene = preload("res://scenes/obstacle/obstacle_wall2.tscn")
@export var obstacle4_scene: PackedScene = preload("res://scenes/obstacle/obstacle_spike.tscn")
@export var obstacle5_scene: PackedScene = preload("res://scenes/obstacle/obstacle_chalwall.tscn")
@export var obstacle6_scene: PackedScene = preload("res://scenes/obstacle/obstacle_chalwall2.tscn")
@export var offset_obstacle1: Vector3 = Vector3.ZERO
@export var offset_obstacle2: Vector3 = Vector3.ZERO
@export var offset_obstacle3: Vector3 = Vector3.ZERO
@export var offset_obstacle4: Vector3 = Vector3.ZERO
@export var offset_obstacle5: Vector3 = Vector3.ZERO
@export var offset_obstacle6: Vector3 = Vector3.ZERO
@export var move_speed: float = 1.0
@export var spawn_interval: float = 4.0
@export var obstacle2_delay: float = 1.5
@export var chalwall_delay: float = 1.0
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
	var roll = randi() % 4
	if roll == 0:
		_spawn(obstacle1_scene, offset_obstacle1)
		await get_tree().create_timer(obstacle2_delay).timeout
		_spawn(obstacle2_scene, offset_obstacle2)
	elif roll == 1:
		_spawn(obstacle3_scene, offset_obstacle3)
	elif roll == 2:
		_spawn_spike()
	else:
		_spawn(obstacle5_scene, offset_obstacle5)
		await get_tree().create_timer(chalwall_delay).timeout
		_spawn(obstacle6_scene, offset_obstacle6)

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

func _spawn(scene: PackedScene, offset: Vector3 = Vector3.ZERO) -> void:
	var obs = scene.instantiate()
	add_child(obs)
	obs.top_level = true
	obs.global_position = $Lane.global_position + offset
	if ground_node:
		obs.global_position.y = ground_node.global_position.y + 1 + offset.y
	var direction = Vector3(arah_x, 0, 0)
	if obs.has_method("set_movement"):
		obs.set_movement(direction, move_speed)
	else:
		obs.set("move_direction", direction)
		obs.set("move_speed", move_speed)
	if ground_node and ground_node.has_method("register_obstacle"):
		ground_node.register_obstacle(obs)
