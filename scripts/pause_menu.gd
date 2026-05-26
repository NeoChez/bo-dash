extends CanvasLayer

@onready var _overlay: ColorRect = $Overlay
@onready var _panel: Panel = $Panel
@onready var _resume_button: Button = $Panel/ResumeButton
@onready var _restart_button: Button = $Panel/RestartButton
@onready var _quit_button: Button = $Panel/QuitButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_overlay.visible = false
	_panel.visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	_restart_button.pressed.connect(_on_restart_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	_toggle_pause()
	get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if get_tree().paused:
		_resume_game()
	else:
		_pause_game()


func _pause_game() -> void:
	visible = true
	_overlay.visible = true
	_panel.visible = true
	get_tree().paused = true


func _resume_game() -> void:
	get_tree().paused = false
	visible = false
	_overlay.visible = false
	_panel.visible = false


func _on_resume_pressed() -> void:
	_resume_game()


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
