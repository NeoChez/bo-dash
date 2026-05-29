extends Node3D

const TARGET_GREEN := Color(0.604, 0.804, 0.196, 1.0)  # #9ACD32

func _ready() -> void:
	for mi in find_children("*", "MeshInstance3D", true, false):
		var mesh_inst := mi as MeshInstance3D
		for i in mesh_inst.get_surface_override_material_count():
			var base := mesh_inst.mesh.surface_get_material(i) as StandardMaterial3D
			if base == null:
				continue
			var c := base.albedo_color
			if c.g > c.r and c.g > c.b:
				var mat := base.duplicate() as StandardMaterial3D
				mat.albedo_color = TARGET_GREEN
				mesh_inst.set_surface_override_material(i, mat)
