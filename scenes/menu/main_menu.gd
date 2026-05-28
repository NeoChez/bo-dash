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
	var angles = [-2.0, 2.0, -1.5]
	var i = 0
	for btn in [play_btn, settings_btn, exit_btn]:
		btn.mouse_entered.connect(_on_btn_hover.bind(btn, angles[i % 3]))
		btn.mouse_exited.connect(_on_btn_unhover.bind(btn))
		btn.pivot_offset = btn.size / 2.0 # Ensure scale pivots from center
		btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
		i += 1
		
	# Establish title center pivot offset for rotation wobbling
	title.pivot_offset = title.size / 2.0
	title.resized.connect(func(): title.pivot_offset = title.size / 2.0)
	
	# 1. Floating title animation using an infinite looping Tween
	var base_y = title.position.y
	var float_tween = create_tween().set_loops()
	float_tween.tween_property(title, "position:y", base_y - 18.0, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(title, "position:y", base_y, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 2. Wobbly bouncy rotation animation (Stumble Guys logo style!)
	var wobble_tween = create_tween().set_loops()
	wobble_tween.tween_property(title, "rotation_degrees", 4.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble_tween.tween_property(title, "rotation_degrees", -4.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	# 3. Pulsating Glowing Sinar Light bloom (tweens shadow outline size)
	var glow_tween = create_tween().set_loops()
	glow_tween.tween_method(
		func(val: int): title.add_theme_constant_override("shadow_outline_size", val),
		12, 38, 1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	glow_tween.tween_method(
		func(val: int): title.add_theme_constant_override("shadow_outline_size", val),
		38, 12, 1.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

# Satisfying 3D button pressed animation (sinks flat & stays sunken inside the screen!)
func _play_press_anim(btn: Button, callback: Callable) -> void:
	if not btn:
		callback.call()
		return
		
	btn.pivot_offset = btn.size / 2.0
	btn.disabled = true
	
	# Duplicate normal stylebox so we can animate its physical 3D border thickness down to flat!
	var normal_style = btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", normal_style)
	btn.add_theme_stylebox_override("disabled", normal_style)
	
	var tween = create_tween().set_parallel(true)
	# 1. PUSH DOWN AND FLATTEN (Sinks flat into the screen!)
	# Squash scale down
	tween.tween_property(btn, "scale", Vector2(0.85, 0.85), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Sink vertically down into the frame
	tween.tween_property(btn, "position:y", btn.position.y + 16.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Flatten the 3D bottom border thickness to 1px
	tween.tween_method(
		func(val: int): normal_style.border_width_bottom = val,
		8, 1, 0.12
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	# 2. Stay sunken for a brief satisfying moment, then execute transition!
	tween.chain().set_parallel(false)
	tween.tween_interval(0.18)
	tween.tween_callback(callback)

func _on_play_pressed() -> void:
	_play_press_anim(play_btn, func():
		get_tree().change_scene_to_file("res://scenes/menu/char_select.tscn")
	)

func _on_settings_pressed() -> void:
	_play_press_anim(settings_btn, func():
		var dialog = AcceptDialog.new()
		dialog.title = "Settings"
		dialog.dialog_text = "Controls:\nPlayer Left (P2): WASD to move, W to jump.\nPlayer Right (P1): Arrow Keys to move, Up Arrow to jump."
		add_child(dialog)
		dialog.popup_centered(Vector2i(350, 150))
	)

func _on_exit_pressed() -> void:
	_play_press_anim(exit_btn, func():
		get_tree().quit()
	)

# Premium hover animations using Godot Tweens!
func _on_btn_hover(btn: Button, hover_angle: float) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "rotation_degrees", hover_angle, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "theme_override_colors/font_color", Color(1, 0.95, 0.6), 0.15)

func _on_btn_unhover(btn: Button) -> void:
	var tween = create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "rotation_degrees", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "theme_override_colors/font_color", Color(1, 1, 1), 0.15)
