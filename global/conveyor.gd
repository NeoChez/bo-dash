extends StaticBody3D

@export var conveyor_speed: float = 5.0
# Arah dorongan (Contoh: Vector3(0, 0, -1) mendorong ke arah Z negatif / maju)
@export var conveyor_direction: Vector3 = Vector3(-1, 0, 0)

func _ready() -> void:
	# Mengkalikan arah dengan kecepatan
	var push_velocity = conveyor_direction.normalized() * conveyor_speed
	
	# Memberikan instruksi ke Godot untuk mendorong apapun yang menginjaknya
	constant_linear_velocity = push_velocity

# _process(delta) bisa dihapus jika tidak digunakan
