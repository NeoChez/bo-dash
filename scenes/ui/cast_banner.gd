extends Control

# Banner pop-up saat skill di-cast. Dipanggil match_controller:
#   var b = preload(...).instantiate(); hud.add_child(b)
#   b.position = ...; b.setup("🚀", "Slingshot Rocket", color)
# Scene mengatur animasi (AnimationPlayer "show") lalu menghapus dirinya.

func setup(emoji: String, skill_name: String, color: Color) -> void:
	($Panel/EmojiLabel as Label).text = emoji
	var name_lbl := $Panel/NameLabel as Label
	name_lbl.text = skill_name.to_upper()
	name_lbl.add_theme_color_override("font_color", color)
	var ap := $AnimationPlayer as AnimationPlayer
	ap.animation_finished.connect(_on_anim_done)
	ap.play("show")


func _on_anim_done(_anim: StringName) -> void:
	queue_free()
