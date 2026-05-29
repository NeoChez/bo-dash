extends Node3D

@onready var camera = $"../Camera3D"

var sphere_mesh: SphereMesh = null
var current_color_index = 0
var colors = [
	Color(1.0, 0.18, 0.35),  # Red
	Color(0.0, 0.73, 1.0),   # Bright Cyan
	Color(1.0, 0.55, 0.0),   # Orange
	Color(0.4, 0.92, 0.1),   # Lime Green
	Color(0.75, 0.22, 1.0),  # Purple
	Color(1.0, 0.88, 0.0),   # Yellow
	Color(0.0, 0.88, 0.7),   # Turquoise
	Color(1.0, 0.32, 0.88),  # Hot Pink
	Color(0.18, 0.48, 1.0),  # Deep Blue
	Color(1.0, 0.48, 0.22),  # Coral
]

var last_spawn_pos = Vector3.ZERO
var is_drawing = false
var draw_depth = 5.2 # distance from camera (camera Z is 8.0, so this Z will be 2.8, in front of the background but behind UI)

var materials = []

func _ready() -> void:
	sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.22
	sphere_mesh.height = 0.44
	sphere_mesh.radial_segments = 32
	sphere_mesh.rings = 16

	# Smooth glossy plastic materials — low roughness, soft rim for 3D depth
	for col in colors:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = col
		mat.roughness = 0.08
		mat.metallic = 0.05
		mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		mat.rim_enabled = true
		mat.rim = 0.35
		mat.rim_tint = 0.5
		materials.append(mat)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				is_drawing = true
				last_spawn_pos = _get_3d_mouse_pos(event.position)
				_spawn_sphere(last_spawn_pos)
				# Rotate to the next color for the next stroke
				current_color_index = (current_color_index + 1) % colors.size()
			else:
				is_drawing = false
				
	elif event is InputEventMouseMotion and is_drawing:
		var target_pos = _get_3d_mouse_pos(event.position)
		var dist = last_spawn_pos.distance_to(target_pos)
		
		# If mouse is dragged quickly, interpolate to ensure a solid 3D line
		if dist > 0.014:
			var segments = ceil(dist / 0.014)
			for i in range(1, segments + 1):
				var t = float(i) / float(segments)
				var interp_pos = last_spawn_pos.lerp(target_pos, t)
				_spawn_sphere(interp_pos)
			last_spawn_pos = target_pos

func _get_3d_mouse_pos(screen_pos: Vector2) -> Vector3:
	if not camera:
		return Vector3.ZERO
	return camera.project_position(screen_pos, draw_depth)

func _spawn_sphere(pos: Vector3) -> void:
	var instance = MeshInstance3D.new()
	instance.mesh = sphere_mesh
	instance.material_override = materials[current_color_index]
	add_child(instance)
	instance.position = pos
	
	# Inflating bounce scale effect on spawn (highly satisfying fluid feel!)
	instance.scale = Vector3(0.1, 0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(instance, "scale", Vector3(1.0, 1.0, 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	# Automatic cleanup: bouncily shrink and delete after 12 seconds
	var cleanup_tween = create_tween()
	cleanup_tween.tween_interval(12.0)
	cleanup_tween.tween_property(instance, "scale", Vector3(0.0, 0.0, 0.0), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	cleanup_tween.tween_callback(instance.queue_free)
