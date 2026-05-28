extends Node3D

var models = [
	"res://assets/things/obj__barrel_ugc_a_000_1x1.glb",
	"res://assets/things/level25__pirate_coin01.glb",
	"res://assets/things/toy__bumper_ugc_a_000_1x1.glb",
	"res://assets/things/toy_explosiveboxugc_a.glb",
	"res://assets/things/ugc_basketball_a_000.glb",
	"res://assets/things/toy__spinning_disc_ugc_a_000_1x1.glb",
	"res://assets/things/toy__seesaw_ugc_b_000_1x1.glb",
	"res://assets/things/toy__treadmill_ugc_a_000_1x1.glb",
	"res://assets/things/toy__grinder_beam_ugc_a_000_1x1.glb",
	"res://assets/things/toy__grinder_ugc_a_000_1x1.glb",
	"res://assets/things/toy__hammer_trap_sevenfold_ugc_a_000_1x1.glb",
	"res://assets/things/toy__hex_platform_sticky_ugc_a_000_1x1.glb",
	"res://assets/things/toy__hinged_door_ugc_a_000_1x1.glb",
	"res://assets/things/toy__moving_platform_ugc_a_000_1x1.glb",
	"res://assets/things/toy__moving_wall_ugc_a_000_1x1.glb",
	"res://assets/things/toy__spinning_fan_triple_ugc_a.glb",
	"res://assets/things/toy__swing_obstacle_hammer_ugc_b_000_1x1.glb",
	"res://assets/things/toy__swinging_obstacle_cage_ugc_a_000_1x1.glb"
]

var model_scales = {
	"res://assets/things/obj__barrel_ugc_a_000_1x1.glb": Vector3(1.2, 1.2, 1.2),
	"res://assets/things/level25__pirate_coin01.glb": Vector3(1.6, 1.6, 1.6),
	"res://assets/things/toy__bumper_ugc_a_000_1x1.glb": Vector3(1.4, 1.4, 1.4),
	"res://assets/things/toy_explosiveboxugc_a.glb": Vector3(1.2, 1.2, 1.2),
	"res://assets/things/ugc_basketball_a_000.glb": Vector3(0.4, 0.4, 0.4),            # Scaled down as requested
	"res://assets/things/toy__spinning_disc_ugc_a_000_1x1.glb": Vector3(0.35, 0.35, 0.35), # Scaled down
	"res://assets/things/toy__seesaw_ugc_b_000_1x1.glb": Vector3(0.25, 0.25, 0.25),       # Scaled down
	"res://assets/things/toy__treadmill_ugc_a_000_1x1.glb": Vector3(0.3, 0.3, 0.3),         # Scaled down
	"res://assets/things/toy__grinder_beam_ugc_a_000_1x1.glb": Vector3(0.4, 0.4, 0.4),
	"res://assets/things/toy__grinder_ugc_a_000_1x1.glb": Vector3(0.45, 0.45, 0.45),
	"res://assets/things/toy__hammer_trap_sevenfold_ugc_a_000_1x1.glb": Vector3(0.3, 0.3, 0.3), # Scaled down
	"res://assets/things/toy__hex_platform_sticky_ugc_a_000_1x1.glb": Vector3(0.4, 0.4, 0.4),  # Scaled down
	"res://assets/things/toy__hinged_door_ugc_a_000_1x1.glb": Vector3(0.35, 0.35, 0.35),       # Scaled down
	"res://assets/things/toy__moving_platform_ugc_a_000_1x1.glb": Vector3(0.3, 0.3, 0.3),       # Scaled down
	"res://assets/things/toy__moving_wall_ugc_a_000_1x1.glb": Vector3(0.25, 0.25, 0.25),       # Scaled down
	"res://assets/things/toy__spinning_fan_triple_ugc_a.glb": Vector3(0.35, 0.35, 0.35),       # Scaled down
	"res://assets/things/toy__swing_obstacle_hammer_ugc_b_000_1x1.glb": Vector3(0.3, 0.3, 0.3), # Scaled down
	"res://assets/things/toy__swinging_obstacle_cage_ugc_a_000_1x1.glb": Vector3(0.35, 0.35, 0.35) # Scaled down
}

var spawn_timer = 0.0
var next_spawn_time = 1.0

class FallingItem:
	var node: Node3D
	var speed: float
	var rot_speed: Vector3

var active_items: Array[FallingItem] = []

func _ready() -> void:
	# Pre-spawn 7 items at random heights immediately so the menu feels alive instantly, spanning full width
	for i in range(7):
		_spawn_item(randf_range(-10.0, 10.0), randf_range(-4.5, 4.5))
	next_spawn_time = randf_range(0.8, 1.8) # much faster falling rate

func _process(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= next_spawn_time:
		spawn_timer = 0.0
		next_spawn_time = randf_range(0.8, 1.8) # more frequent spawns
		_spawn_item(randf_range(-10.0, 10.0), 6.5) # spawn spanning full width # spawn at the top
		
	var to_remove = []
	for item in active_items:
		if is_instance_valid(item.node):
			item.node.position.y -= item.speed * delta
			item.node.rotate_x(item.rot_speed.x * delta)
			item.node.rotate_y(item.rot_speed.y * delta)
			item.node.rotate_z(item.rot_speed.z * delta)
			
			if item.node.position.y < -6.5:
				to_remove.append(item)
				item.node.queue_free()
		else:
			to_remove.append(item)
			
	for item in to_remove:
		active_items.erase(item)

func _spawn_item(x: float, y: float) -> void:
	var path = models[randi() % models.size()]
	var model_scene = load(path) as PackedScene
	if not model_scene:
		return
		
	var node = model_scene.instantiate() as Node3D
	add_child(node)
	
	# Random Z-depth layer to make the environment feel deep
	node.position = Vector3(x, y, randf_range(-2.0, 0.5))
	node.scale = model_scales.get(path, Vector3(1.0, 1.0, 1.0))
	
	var item = FallingItem.new()
	item.node = node
	item.speed = randf_range(1.2, 2.5) # slow, premium falling speed
	item.rot_speed = Vector3(
		randf_range(-1.2, 1.2),
		randf_range(-1.2, 1.2),
		randf_range(-1.2, 1.2)
	)
	
	active_items.append(item)
