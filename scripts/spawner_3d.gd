extends Node3D

@export var obstacle_scene: PackedScene = preload("res://global/obstacle_3d.tscn")
@export var spawn_interval: float = 1.5
@export var move_speed: float = 8.0 # Kecepatan obstacle bergerak

var spawn_points: Array = []
var spawned_obstacles: Array = []

func _ready() -> void:
	# Kumpulkan semua Marker3D sebagai spawn points
	for child in get_children():
		if child is Marker3D:
			spawn_points.append(child)
	
	print("Spawner ready dengan ", spawn_points.size(), " lanes")
	
	# Setup timer untuk spawn
	var timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.timeout.connect(_on_spawn_timer)
	add_child(timer)
	
	# Timer untuk cleanup obstacle yang sudah lewat
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 0.5
	cleanup_timer.autostart = true
	cleanup_timer.timeout.connect(_cleanup_obstacles)
	add_child(cleanup_timer)

func _on_spawn_timer():
	if spawn_points.size() == 0:
		return
	
	# Pilih lane secara random
	var lane_index = randi() % spawn_points.size()
	var spawn_point = spawn_points[lane_index]
	
	spawn_obstacle(spawn_point)

func spawn_obstacle(spawn_point: Marker3D):
	# Instance obstacle
	var obs = obstacle_scene.instantiate()
	
	# TAMBAH KE SCENE DULU sebelum set posisi
	get_parent().add_child(obs)
	
	# Baru set posisi spawn setelah masuk scene tree
	obs.global_position = spawn_point.global_position
	
	# Set kecepatan dan arah
	if obs.has_method("set_movement"):
		obs.set_movement(Vector3(-1, 0, 0), move_speed)
	else:
		obs.move_speed = move_speed
		obs.move_direction = Vector3(-1, 0, 0)
	
	# Pastikan masuk ke groups
	if not obs.is_in_group("item"):
		obs.add_to_group("item")
	if not obs.is_in_group("obstacle"):
		obs.add_to_group("obstacle")
	
	# Track obstacle
	spawned_obstacles.append(obs)

func _cleanup_obstacles():
	# Hapus obstacle yang sudah lewat jauh di belakang player
	for i in range(spawned_obstacles.size() - 1, -1, -1):
		var obs = spawned_obstacles[i]
		if not is_instance_valid(obs):
			spawned_obstacles.remove_at(i)
		elif obs.global_position.x < -25: # Jika sudah jauh di belakang player
			obs.queue_free()
			spawned_obstacles.remove_at(i)
