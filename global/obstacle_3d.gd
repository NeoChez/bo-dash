extends AnimatableBody3D

@export var move_speed: float = 8.0
@export var move_direction: Vector3 = Vector3(-1, 0, 0) # Bergerak ke kiri (negatif X)
@export var auto_move: bool = true

var is_on_conveyor: bool = false

func _ready() -> void:
	# Pastikan masuk ke groups
	if not is_in_group("obstacle"):
		add_to_group("obstacle")
	if not is_in_group("item"):
		add_to_group("item")
	
	# Hubungkan signal untuk deteksi conveyor
	var detector = get_node_or_null("ConveyorDetector")
	if detector:
		detector.body_entered.connect(_on_conveyor_entered)
		detector.body_exited.connect(_on_conveyor_exited)

func _physics_process(delta: float) -> void:
	if auto_move:
		# Bergerak maju secara konstan
		var motion = move_direction * move_speed * delta
		move_and_collide(motion)

func set_movement(direction: Vector3, speed: float) -> void:
	move_direction = direction
	move_speed = speed

func _on_conveyor_entered(body: Node3D) -> void:
	if body.is_in_group("conveyor"):
		is_on_conveyor = true

func _on_conveyor_exited(body: Node3D) -> void:
	if body.is_in_group("conveyor"):
		is_on_conveyor = false
