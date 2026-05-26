extends Control

@onready var p2_card = $HBoxContainer/P2Panel
@onready var p2_char_lbl = $HBoxContainer/P2Panel/VBox/CharLabel
@onready var p2_status_lbl = $HBoxContainer/P2Panel/VBox/StatusLabel

@onready var p1_card = $HBoxContainer/P1Panel
@onready var p1_char_lbl = $HBoxContainer/P1Panel/VBox/CharLabel
@onready var p1_status_lbl = $HBoxContainer/P1Panel/VBox/StatusLabel

@onready var countdown_lbl = $CountdownLabel

var characters = ["rex", "hamm"]
var p2_index = 0
var p1_index = 0

var p2_ready = false
var p1_ready = false

var countdown_active = false
var countdown_timer = 1.0

func _ready() -> void:
	countdown_lbl.visible = false
	_update_p2_ui()
	_update_p1_ui()

func _input(event: InputEvent) -> void:
	if countdown_active:
		return
		
	# --- PLAYER 2 (LEFT PLAYER) ---
	if not p2_ready:
		if event.is_action_pressed("p2_left") or event.is_action_pressed("ui_left_alternative_a"):
			p2_index = (p2_index - 1 + characters.size()) % characters.size()
			_update_p2_ui()
		elif event.is_action_pressed("p2_right") or event.is_action_pressed("ui_right_alternative_d"):
			p2_index = (p2_index + 1) % characters.size()
			_update_p2_ui()
			
	# Ready trigger for P2 (W key or p2_up)
	if event.is_action_pressed("p2_up") or (event is InputEventKey and event.pressed and event.keycode == KEY_W):
		p2_ready = !p2_ready
		_update_p2_ui()
		_check_start_countdown()

	# --- PLAYER 1 (RIGHT PLAYER) ---
	if not p1_ready:
		if event.is_action_pressed("ui_left"):
			p1_index = (p1_index - 1 + characters.size()) % characters.size()
			_update_p1_ui()
		elif event.is_action_pressed("ui_right"):
			p1_index = (p1_index + 1) % characters.size()
			_update_p1_ui()
			
	# Ready trigger for P1 (Up Arrow or ui_up)
	if event.is_action_pressed("ui_up"):
		p1_ready = !p1_ready
		_update_p1_ui()
		_check_start_countdown()

func _process(delta: float) -> void:
	if countdown_active:
		countdown_timer -= delta
		countdown_lbl.text = "STARTING IN: %d..." % ceil(countdown_timer)
		if countdown_timer <= 0.0:
			countdown_active = false
			_start_game()

func _update_p2_ui() -> void:
	var char_name = characters[p2_index].to_upper()
	p2_char_lbl.text = char_name
	
	# Stylize card background color based on selection
	var style_box = p2_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if characters[p2_index] == "rex":
		style_box.bg_color = Color(0.1, 0.22, 0.2, 0.95) # Teal for Rex
		style_box.border_color = Color(0.38, 0.95, 0.75)
		p2_char_lbl.add_theme_color_override("font_color", Color(0.38, 0.95, 0.75))
	else:
		style_box.bg_color = Color(0.24, 0.14, 0.16, 0.95) # Rose/Gold for Hamm
		style_box.border_color = Color(1.0, 0.58, 0.62)
		p2_char_lbl.add_theme_color_override("font_color", Color(1.0, 0.58, 0.62))
	p2_card.add_theme_stylebox_override("panel", style_box)
	
	# Status Ready
	if p2_ready:
		p2_status_lbl.text = "READY"
		p2_status_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	else:
		p2_status_lbl.text = "PRESS 'W' TO READY"
		p2_status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))

func _update_p1_ui() -> void:
	var char_name = characters[p1_index].to_upper()
	p1_char_lbl.text = char_name
	
	# Stylize card background color based on selection
	var style_box = p1_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if characters[p1_index] == "rex":
		style_box.bg_color = Color(0.1, 0.22, 0.2, 0.95) # Teal
		style_box.border_color = Color(0.38, 0.95, 0.75)
		p1_char_lbl.add_theme_color_override("font_color", Color(0.38, 0.95, 0.75))
	else:
		style_box.bg_color = Color(0.24, 0.14, 0.16, 0.95) # Rose/Gold
		style_box.border_color = Color(1.0, 0.58, 0.62)
		p1_char_lbl.add_theme_color_override("font_color", Color(1.0, 0.58, 0.62))
	p1_card.add_theme_stylebox_override("panel", style_box)
	
	# Status Ready
	if p1_ready:
		p1_status_lbl.text = "READY"
		p1_status_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	else:
		p1_status_lbl.text = "PRESS 'UP' TO READY"
		p1_status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))

func _check_start_countdown() -> void:
	if p1_ready and p2_ready:
		countdown_active = true
		countdown_timer = 2.0 # 2-second epic countdown
		countdown_lbl.visible = true
	else:
		countdown_active = false
		countdown_lbl.visible = false

func _start_game() -> void:
	# Save selections to the autoload GlobalSettings
	var global_settings = get_node_or_null("/root/GlobalSettings")
	if global_settings:
		global_settings.player_1_character = characters[p1_index]
		global_settings.player_2_character = characters[p2_index]
	
	# Load standard game scene
	get_tree().change_scene_to_file("res://global/node_3d.tscn")
