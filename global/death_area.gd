extends Area3D

func _ready():
	# Hubungkan signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D):
	# Cek jika yang masuk adalah player
	if body.is_in_group("player"):
		# Panggil fungsi fall_to_death pada player
		if body.has_method("fall_to_death"):
			body.fall_to_death()
