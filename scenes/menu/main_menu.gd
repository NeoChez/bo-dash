extends Control

@onready var play_btn = $CenterContainer/VBoxContainer/PlayButton
@onready var settings_btn = $CenterContainer/VBoxContainer/SettingsButton
@onready var exit_btn = $CenterContainer/VBoxContainer/ExitButton
@onready var title = $TitleLabel

func _ready() -> void:
	# Connect button clicks
	play_btn.pressed.connect(_on_play_pressed)
	settings_btn.pressed.connect(_on_settings_pressed)
	exit_btn.pressed.connect(_on_exit_pressed)
	
	# Connect premium hover effects for all buttons
	for btn in [play_btn, settings_btn, exit_btn]:
		btn.mouse_entered.connect(_on_btn_hover.bind(btn))
		btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
		btn.pivot_offset = btn.size / 2.0 # Ensure scale pivots from center

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/char_select.tscn")

func _on_settings_pressed() -> void:
	# Display a cute popup or placeholder setting
	var dialog = AcceptDialog.new()
	dialog.title = "Settings"
	dialog.dialog_text = "Controls:\nPlayer Left (P2): WASD to move, W to jump.\nPlayer Right (P1): Arrow Keys to move, Up Arrow to jump."
	add_child(dialog)
	dialog.popup_centered(Vector2i(350, 150))

func _on_exit_pressed() -> void:
	get_tree().quit()

# Premium hover animations using Godot Tweens!
func _on_btn_hover(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "theme_override_colors/font_color", Color(0.98, 0.8, 0.35), 0.15)

func _on_btn_unhover(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "theme_override_colors/font_color", Color(1, 1, 1), 0.15)
