extends Area2D

@export var push_speed: float = 80.0
@export var push_direction: Vector2 = Vector2.RIGHT

var conveyor_velocity: Vector2

func _ready() -> void:
	add_to_group("conveyor")
	conveyor_velocity = push_direction.normalized() * push_speed
