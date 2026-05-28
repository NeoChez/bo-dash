extends Control

@onready var p2_card = $HBoxContainer/P2Panel
@onready var p2_char_lbl = $HBoxContainer/P2Panel/VBox/CharLabel
@onready var p2_status_lbl = $HBoxContainer/P2Panel/VBox/StatusLabel
@onready var p2_pivot = $HBoxContainer/P2Panel/VBox/ViewportContainer/SubViewport/ModelPivot

@onready var p1_card = $HBoxContainer/P1Panel
@onready var p1_char_lbl = $HBoxContainer/P1Panel/VBox/CharLabel
@onready var p1_status_lbl = $HBoxContainer/P1Panel/VBox/StatusLabel
@onready var p1_pivot = $HBoxContainer/P1Panel/VBox/ViewportContainer/SubViewport/ModelPivot

@onready var countdown_lbl = $CountdownLabel

var characters = ["rex", "hamm", "alien", "wheezy", "slinky"]

var char_config = {
	"rex": {
		"scene": "res://assets/player/kingdom_hearts_iii_-_rex.glb",
		"scale": Vector3(11.0, 11.0, 11.0),
		"offset": Vector3(0.0, -0.5, 0.0)
	},
	"hamm": {
		"scene": "res://assets/player/kingdom_hearts_iii_-_hamm.glb",
		"scale": Vector3(18.0, 18.0, 18.0),
		"offset": Vector3(0.0, -0.2, 0.0)
	},
	"alien": {
		"scene": "res://assets/player/kingdom_hearts_iii_-_alienlgm.glb",
		"scale": Vector3(20.0, 20.0, 20.0),
		"offset": Vector3(0.0, -0.1, 0.0)
	},
	"wheezy": {
		"scene": "res://assets/player/wii_-_toy_story_3_-_wheezy.glb",
		"scale": Vector3(0.32, 0.32, 0.32),
		"offset": Vector3(0.0, -0.2, 0.0)
	},
	"slinky": {
		"scene": "res://assets/player/wii_-_toy_story_3_-_slinky_dog.glb",
		"scale": Vector3(0.18, 0.18, 0.18),
		"offset": Vector3(0.0, -0.1, 0.0)
	}
}
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
		if event.is_action_pressed("p2_left"):
			p2_index = (p2_index - 1 + characters.size()) % characters.size()
			_update_p2_ui()
		elif event.is_action_pressed("p2_right"):
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
	# Rotate the preview models gently
	if p2_pivot and p2_pivot.get_child_count() > 0:
		p2_pivot.rotate_y(delta * 1.2)
	if p1_pivot and p1_pivot.get_child_count() > 0:
		p1_pivot.rotate_y(delta * 1.2)
		
	if countdown_active:
		countdown_timer -= delta
		countdown_lbl.text = "STARTING IN: %d..." % ceil(countdown_timer)
		if countdown_timer <= 0.0:
			countdown_active = false
			_start_game()

func _get_char_style(char_name: String) -> Dictionary:
	var bg_color = Color(0.1, 0.22, 0.2, 0.95)
	var border_color = Color(0.38, 0.95, 0.75)
	var font_color = Color(0.38, 0.95, 0.75)
	
	match char_name:
		"rex":
			bg_color = Color(0.08, 0.20, 0.18, 0.95)
			border_color = Color(0.38, 0.95, 0.75)
			font_color = Color(0.38, 0.95, 0.75)
		"hamm":
			bg_color = Color(0.24, 0.14, 0.16, 0.95)
			border_color = Color(1.0, 0.58, 0.62)
			font_color = Color(1.0, 0.58, 0.62)
		"alien":
			bg_color = Color(0.12, 0.20, 0.12, 0.95)
			border_color = Color(0.5, 0.95, 0.3)
			font_color = Color(0.5, 0.95, 0.3)
		"wheezy":
			bg_color = Color(0.08, 0.12, 0.24, 0.95)
			border_color = Color(0.4, 0.75, 1.0)
			font_color = Color(0.4, 0.75, 1.0)
		"slinky":
			bg_color = Color(0.22, 0.15, 0.08, 0.95)
			border_color = Color(0.95, 0.65, 0.3)
			font_color = Color(0.95, 0.65, 0.3)
			
	return {
		"bg_color": bg_color,
		"border_color": border_color,
		"font_color": font_color
	}

func _update_p2_ui() -> void:
	var raw_name = characters[p2_index]
	p2_char_lbl.text = raw_name.to_upper()
	
	_spawn_preview_model(p2_pivot, raw_name)
	
	var style = _get_char_style(raw_name)
	var style_box = p2_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style_box.bg_color = style["bg_color"]
	style_box.border_color = style["border_color"]
	p2_card.add_theme_stylebox_override("panel", style_box)
	p2_char_lbl.add_theme_color_override("font_color", style["font_color"])
	
	# Status Ready
	if p2_ready:
		p2_status_lbl.text = "READY"
		p2_status_lbl.add_theme_color_override("font_color", Color(0.2, 0.9, 0.4))
	else:
		p2_status_lbl.text = "PRESS 'W' TO READY"
		p2_status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))

func _update_p1_ui() -> void:
	var raw_name = characters[p1_index]
	p1_char_lbl.text = raw_name.to_upper()
	
	_spawn_preview_model(p1_pivot, raw_name)
	
	var style = _get_char_style(raw_name)
	var style_box = p1_card.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	style_box.bg_color = style["bg_color"]
	style_box.border_color = style["border_color"]
	p1_card.add_theme_stylebox_override("panel", style_box)
	p1_char_lbl.add_theme_color_override("font_color", style["font_color"])
	
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

func _spawn_preview_model(pivot: Node3D, char_name: String) -> void:
	if not pivot:
		return
	# Clear old children
	for child in pivot.get_children():
		child.queue_free()
		pivot.remove_child(child)
		
	var config = char_config.get(char_name)
	if not config:
		return
		
	var model_scene = load(config["scene"]) as PackedScene
	if model_scene:
		var new_model = model_scene.instantiate()
		pivot.add_child(new_model)
		new_model.scale = config["scale"]
		new_model.position = config["offset"]
