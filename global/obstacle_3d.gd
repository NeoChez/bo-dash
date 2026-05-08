extends AnimatableBody3D

@export var move_speed: float = 8.0
@export var move_direction: Vector3 = Vector3(-1, 0, 0) # Bergerak ke kiri (negatif X)
@export var auto_move: bool = true
@export var fall_gravity: float = 20.0  # Gravitasi saat jatuh

var is_on_ground: bool = false
var ground_count: int = 0
var is_falling: bool = false
var fall_velocity: float = 0.0

func _ready() -> void:
	# Pastikan masuk ke groups
	if not is_in_group("obstacle"):
		add_to_group("obstacle")
	if not is_in_group("item"):
		add_to_group("item")
	
	# Hubungkan signal untuk deteksi ground
	var ground_detector = get_node_or_null("GroundDetector")
	if ground_detector:
		ground_detector.body_entered.connect(_on_ground_entered)
		ground_detector.body_exited.connect(_on_ground_exited)

func _physics_process(delta: float) -> void:
	if is_falling:
		# Jatuh ke bawah
		fall_velocity += fall_gravity * delta
		position.y -= fall_velocity * delta
	elif auto_move:
		# Bergerak maju secara konstan
		var motion = move_direction * move_speed * delta
		move_and_collide(motion)

func set_movement(direction: Vector3, speed: float) -> void:
	move_direction = direction
	move_speed = speed

func _on_ground_entered(body: Node3D) -> void:
	# Cek jika body adalah ground (StaticBody3D dengan group ground)
	if body.is_in_group("ground"):
		ground_count += 1
		is_on_ground = true
		is_falling = false
		fall_velocity = 0.0

func _on_ground_exited(body: Node3D) -> void:
	# Cek jika body adalah ground
	if body.is_in_group("ground"):
		ground_count -= 1
		if ground_count <= 0:
			ground_count = 0
			is_on_ground = false
			# Mulai jatuh saat keluar dari ground
			is_falling = true
			print("Obstacle keluar dari ground, mulai jatuh...")
