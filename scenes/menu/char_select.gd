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

var characters = ["male", "female"]

var char_config = {
	"male": {
		"scene": "res://assets/player/male/idle.glb",
		"scale": Vector3(8.5, 8.5, 8.5),
		"offset": Vector3(0.0, -2.0, 0.0),
		"rotation": Vector3(0.0, 0.0, 0.0)
	},
	"female": {
		"scene": "res://assets/player/female/idle.glb",
		"scale": Vector3(8.5, 8.5, 8.5),
		"offset": Vector3(0.0, -2.0, 0.0),
		"rotation": Vector3(0.0, 0.0, 0.0)
	}
}
var p2_index = 0
var p1_index = 0

var p2_ready = false
var p1_ready = false

var countdown_active = false
var countdown_timer = 1.0

var p2_pulse_tween: Tween = null
var p1_pulse_tween: Tween = null

func _ready() -> void:
	countdown_lbl.visible = false
	
	# Set up pivots and automatic center tracking on resizing
	for card in [p2_card, p1_card]:
		card.pivot_offset = card.size / 2.0
		card.resized.connect(func(): card.pivot_offset = card.size / 2.0)
		
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
			_bounce_card(p2_card)
		elif event.is_action_pressed("p2_right"):
			p2_index = (p2_index + 1) % characters.size()
			_update_p2_ui()
			_bounce_card(p2_card)

	# Ready trigger for P2
	if event.is_action_pressed("p2_up"):
		p2_ready = !p2_ready
		_update_p2_ui()
		_check_start_countdown()

	# --- PLAYER 1 (RIGHT PLAYER) ---
	if not p1_ready:
		if event.is_action_pressed("p1_left"):
			p1_index = (p1_index - 1 + characters.size()) % characters.size()
			_update_p1_ui()
			_bounce_card(p1_card)
		elif event.is_action_pressed("p1_right"):
			p1_index = (p1_index + 1) % characters.size()
			_update_p1_ui()
			_bounce_card(p1_card)

	# Ready trigger for P1
	if event.is_action_pressed("p1_up"):
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

# Candy-colored dynamic card configurations (Stumble Guys vibe)
func _get_char_style(char_name: String) -> Dictionary:
	var bg_color = Color(0.95, 0.56, 0.1)        # Warm Candy Orange
	var border_color = Color(0.72, 0.36, 0.02)
	var font_color = Color(1.0, 0.93, 0.8)
	return {
		"bg_color": bg_color,
		"border_color": border_color,
		"font_color": font_color
	}

func _update_p2_ui() -> void:
	var raw_name = characters[p2_index]
	if characters.size() > 1:
		p2_char_lbl.text = "< " + raw_name.to_upper() + " >"
	else:
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
		p2_status_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 0.45))
		p2_status_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.35, 0.12))
		p2_status_lbl.add_theme_constant_override("outline_size", 12)
		
		# Pulsating breathing animation
		if p2_pulse_tween:
			p2_pulse_tween.kill()
		p2_pulse_tween = create_tween().set_loops()
		p2_pulse_tween.tween_property(p2_card, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		p2_pulse_tween.tween_property(p2_card, "scale", Vector2(1.01, 1.01), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		p2_status_lbl.text = "PRESS W TO READY"
		p2_status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		p2_status_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18))
		p2_status_lbl.add_theme_constant_override("outline_size", 10)
		
		# Stop pulse and reset scale
		if p2_pulse_tween:
			p2_pulse_tween.kill()
			p2_pulse_tween = null
		create_tween().tween_property(p2_card, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)

func _update_p1_ui() -> void:
	var raw_name = characters[p1_index]
	if characters.size() > 1:
		p1_char_lbl.text = "< " + raw_name.to_upper() + " >"
	else:
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
		p1_status_lbl.add_theme_color_override("font_color", Color(0.2, 0.95, 0.45))
		p1_status_lbl.add_theme_color_override("font_outline_color", Color(0.02, 0.35, 0.12))
		p1_status_lbl.add_theme_constant_override("outline_size", 12)
		
		# Pulsating breathing animation
		if p1_pulse_tween:
			p1_pulse_tween.kill()
		p1_pulse_tween = create_tween().set_loops()
		p1_pulse_tween.tween_property(p1_card, "scale", Vector2(1.06, 1.06), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		p1_pulse_tween.tween_property(p1_card, "scale", Vector2(1.01, 1.01), 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	else:
		p1_status_lbl.text = "PRESS P TO READY"
		p1_status_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		p1_status_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18))
		p1_status_lbl.add_theme_constant_override("outline_size", 10)
		
		# Stop pulse and reset scale
		if p1_pulse_tween:
			p1_pulse_tween.kill()
			p1_pulse_tween = null
		create_tween().tween_property(p1_card, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)

# Juicy bouncy squash-and-stretch animation for card swaps
func _bounce_card(card: Control) -> void:
	if not card:
		return
	card.pivot_offset = card.size / 2.0
	
	# Scale punch and wiggle using Tween
	var tween = create_tween()
	tween.tween_property(card, "scale", Vector2(0.88, 0.88), 0.05).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.14, 1.14), 0.14).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "scale", Vector2(1.0, 1.0), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _check_start_countdown() -> void:
	if p1_ready and p2_ready:
		countdown_active = true
		countdown_timer = 2.0 # 2-second epic countdown
		countdown_lbl.visible = true
		
		# Add a fun scale pop to the countdown label
		countdown_lbl.pivot_offset = countdown_lbl.size / 2.0
		var tween = create_tween()
		tween.tween_property(countdown_lbl, "scale", Vector2(1.3, 1.3), 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(countdown_lbl, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_SINE)
	else:
		countdown_active = false
		countdown_lbl.visible = false

func _start_game() -> void:
	# Clean up active Tweens to prevent memory leaks
	if p2_pulse_tween:
		p2_pulse_tween.kill()
	if p1_pulse_tween:
		p1_pulse_tween.kill()
		
	# Save selections to the autoload GlobalSettings
	var global_settings = get_node_or_null("/root/GlobalSettings")
	if global_settings:
		# Left panel (P2Panel) uses A/D and is now Player 1
		global_settings.player_1_character = characters[p2_index]
		# Right panel (P1Panel) uses L/' and is now Player 2
		global_settings.player_2_character = characters[p1_index]
	
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
		if config.has("rotation"):
			pivot.rotation = config["rotation"]
		else:
			pivot.rotation = Vector3.ZERO
		
		# Play idletofight loop animation
		_play_first_animation(new_model)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found = _find_animation_player(child)
		if found:
			return found
	return null

func _play_first_animation(model: Node) -> void:
	var anim_player = _find_animation_player(model)
	if anim_player:
		var anim_list = anim_player.get_animation_list()
		if anim_list.size() > 0:
			var anim_name = anim_list[0]
			var anim = anim_player.get_animation(anim_name)
			if anim:
				anim.loop_mode = Animation.LOOP_LINEAR
			anim_player.play(anim_name)
