extends MeshInstance3D

@export var scroll_speed: float = 2.0
@export var scroll_direction: Vector3 = Vector3(1, 0, 0) # Scroll texture

var mat: StandardMaterial3D

func _ready() -> void:
	# Tambahkan ke group conveyor
	
	
	# Visual setup - duplikasi material agar bisa di-scroll
	var original_mat = get_active_material(0)
	if original_mat and original_mat is StandardMaterial3D:
		mat = original_mat.duplicate()
		set_surface_override_material(0, mat)

func _physics_process(delta: float) -> void:
	# Animasi texture conveyor (bergerak)
	if mat:
		mat.uv1_offset += scroll_direction * (scroll_speed * delta)
