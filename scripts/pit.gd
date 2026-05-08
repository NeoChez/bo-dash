extends Area2D

func _ready() -> void:
	add_to_group("pit")

func _physics_process(_delta: float) -> void:
	for body in get_overlapping_bodies():
		if body.has_method("is_jumping") and body.is_jumping():
			continue
		if body.has_method("fall_into_pit"):
			body.fall_into_pit()
