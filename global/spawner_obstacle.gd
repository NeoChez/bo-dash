extends Node2D

@export var obstacle_scene: PackedScene = preload("res://scenes/obstacle/obstacle.tscn")
@export var spawn_interval: float = 2.0

var spawn_points: Array = []

func _ready() -> void:
	# Get all Marker2D children
	for child in get_children():
		if child is Marker2D:
			spawn_points.append(child)
	
	# Setup spawn timer
	var timer = Timer.new()
	timer.wait_time = spawn_interval
	timer.autostart = true
	timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(timer)

func _on_spawn_timer_timeout() -> void:
	spawn_obstacle()

func spawn_obstacle() -> void:
	if spawn_points.size() == 0:
		return
		
	# Pick a random spawn point
	var spawn_point = spawn_points[randi() % spawn_points.size()]
	
	# Instance the obstacle
	var obstacle = obstacle_scene.instantiate()
	
	# Set position
	obstacle.global_position = spawn_point.global_position
	
	# Add to "item" group so conveyor picks it up
	obstacle.add_to_group("item")
	
	# Add to the scene tree
	get_parent().add_child(obstacle)
