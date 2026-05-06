extends Area2D

@export var speed: float = 100.0

@onready var path: Path2D = $Path2D # Mengambil node Path2D
var items_on_belt: Array = []

func _ready():
	pass
	
func _physics_process(delta):
	# Jika Path2D atau garisnya belum ada, jangan lakukan apa-apa
	if path == null or path.curve == null:
		return

	var path_length = path.curve.get_baked_length()

	# Pindahkan semua objek yang ada di atas sabuk
	for item in items_on_belt:
		# Cari tahu posisi item saat ini secara lokal terhadap Path2D
		var local_pos = path.to_local(item.global_position)
		
		# Cari jarak offset terdekat dari item ke garis Path2D
		var current_offset = path.curve.get_closest_offset(local_pos)
		
		var next_offset = min(current_offset + 5.0, path_length)
		
		# Dapatkan koordinat lokal titik sekarang dan titik di depannya
		var current_point = path.curve.sample_baked(current_offset)
		var next_point = path.curve.sample_baked(next_offset)
		
		# Ubah menjadi koordinat global agar pergerakannya pas dengan letak di layar
		var global_current = path.to_global(current_point)
		var global_next = path.to_global(next_point)
		
		# Hitung arahnya
		var move_dir = (global_next - global_current).normalized()
		
		# Jika sudah mentok di ujung garis ambil titik sedikit di belakangnya
		if move_dir == Vector2.ZERO and current_offset > 5.0:
			var prev_point = path.curve.sample_baked(current_offset - 5.0)
			var global_prev = path.to_global(prev_point)
			move_dir = (global_current - global_prev).normalized()
			
		if move_dir.length() > 0:
			item.global_position += move_dir * speed * delta

func _on_body_entered(body):
	
	if (body.is_in_group("item") or body.is_in_group("player")) and not body in items_on_belt:
		items_on_belt.append(body)

func _on_body_exited(body):
	if body in items_on_belt:
		print("Body keluar dari conveyor")
		items_on_belt.erase(body)
