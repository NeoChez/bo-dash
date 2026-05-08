extends Node3D

@export var obstacle_scene: PackedScene = preload("res://global/obstacle_3d.tscn")
@export var spawn_interval: float = 1.5
@export var move_speed: float = 8.0 

# Referensi ke node Ground agar Spawner bisa melapor
@export var ground_node: Node3D 

var spawn_points: Array = []
var last_spawn_index: int = -1 

func _ready() -> void:
	randomize()
	
	
	for child in get_children():
		if child is Marker3D:
			spawn_points.append(child)
	
	var timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.timeout.connect(_on_spawn_timer)
	add_child(timer)

func _on_spawn_timer():
	if spawn_points.size() == 0:
		return
	
	var lane_index = randi() % spawn_points.size()
	
	while lane_index == last_spawn_index and spawn_points.size() > 1:
		lane_index = randi() % spawn_points.size()
		
	last_spawn_index = lane_index
	var spawn_point = spawn_points[lane_index]
	
	spawn_obstacle(spawn_point)

func spawn_obstacle(spawn_point: Marker3D):
	var obs = obstacle_scene.instantiate()
	
	add_child(obs)
	obs.top_level = true
	obs.global_transform = spawn_point.global_transform
	
	if obs.has_method("set_movement"):
		obs.set_movement(Vector3(1, 0, 0), move_speed)
	else:
		obs.move_speed = move_speed
		obs.move_direction = Vector3(1, 0, 0)
	
	if not obs.is_in_group("item"):
		obs.add_to_group("item")
	if not obs.is_in_group("obstacle"):
		obs.add_to_group("obstacle")
	

	if ground_node:
		ground_node.register_obstacle(obs)
