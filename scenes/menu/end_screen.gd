extends Control

@onready var title_label: Label = $TitleLabel
@onready var restart_btn: Button = $CenterContainer/VBoxContainer/RestartButton
@onready var select_btn: Button = $CenterContainer/VBoxContainer/SelectButton
@onready var exit_btn: Button = $CenterContainer/VBoxContainer/ExitButton
@onready var enemy_viewport: SubViewport = $EnemyViewport/SubViewport

var _enemy_model: Node3D = null

func _ready() -> void:
	_setup_winner_display()
	_setup_buttons()
	_animate_title()

func _setup_winner_display() -> void:
	var winner_id: int = GlobalSettings.last_winner_id

	if winner_id == 0:
		title_label.text = "DRAW!"
		title_label.add_theme_color_override("font_color", Color(1, 0.92, 0.05, 1))
	else:
		title_label.text = "PLAYER %d WIN!" % winner_id
		var color := Color(0.25, 0.95, 0.78, 1) if winner_id == 1 else Color(1, 0.6, 0.1, 1)
		title_label.add_theme_color_override("font_color", color)

	if winner_id > 0:
		_load_enemy_model(winner_id)

func _load_enemy_model(player_id: int) -> void:
	var char_name := GlobalSettings.player_1_character if player_id == 1 else GlobalSettings.player_2_character
	var model_path := "res://assets/player/%s/running.glb" % char_name
	var scene := load(model_path) as PackedScene
	if not scene:
		return
	_enemy_model = scene.instantiate() as Node3D
	_enemy_model.scale = Vector3(6, 6, 6)
	_enemy_model.rotation_degrees.y = 0.0
	enemy_viewport.add_child(_enemy_model)

	var colors: Dictionary = GlobalSettings.player_1_colors if player_id == 1 else GlobalSettings.player_2_colors
	if not colors.is_empty():
		_apply_colors(_enemy_model, colors, "female" in char_name.to_lower())

	var anim := _find_anim_player(_enemy_model)
	if anim:
		var list := anim.get_animation_list()
		if list.size() > 0:
			var a := anim.get_animation(list[0])
			if a:
				a.loop_mode = Animation.LOOP_LINEAR
			anim.play(list[0])

	var rot_tween := create_tween().set_loops()
	rot_tween.tween_property(_enemy_model, "rotation_degrees:y", 15.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	rot_tween.tween_property(_enemy_model, "rotation_degrees:y", -15.0, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null

func _apply_colors(node: Node, colors: Dictionary, is_female: bool) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				var mat := mi.get_active_material(i)
				if mat is BaseMaterial3D:
					var brightness := ((mat as BaseMaterial3D).albedo_color.r + (mat as BaseMaterial3D).albedo_color.g + (mat as BaseMaterial3D).albedo_color.b) / 3.0
					var chroma := maxf(maxf((mat as BaseMaterial3D).albedo_color.r, (mat as BaseMaterial3D).albedo_color.g), (mat as BaseMaterial3D).albedo_color.b) - minf(minf((mat as BaseMaterial3D).albedo_color.r, (mat as BaseMaterial3D).albedo_color.g), (mat as BaseMaterial3D).albedo_color.b)
					var cat := _classify_color(node.name, (mat as BaseMaterial3D).albedo_color, brightness, chroma, is_female)
					if cat != "" and colors.has(cat):
						var nm := mat.duplicate() as BaseMaterial3D
						nm.albedo_color = colors[cat]
						mi.set_surface_override_material(i, nm)
	for child in node.get_children():
		_apply_colors(child, colors, is_female)

func _classify_color(mesh_name: String, color: Color, brightness: float, chroma: float, is_female: bool) -> String:
	if is_female:
		if mesh_name == "Object_2": return "hair"
		if color.r > 0.75 and color.g > 0.55 and color.b < 0.45: return "hair"
		if brightness >= 0.35 and brightness <= 0.68 and chroma >= 0.18 and chroma <= 0.45 and color.b >= color.g: return "top"
		if brightness >= 0.38 and brightness <= 0.60 and chroma >= 0.05 and chroma < 0.18: return "pants"
		if mesh_name.begins_with("Vert_") and brightness > 0.008 and brightness < 0.07: return "shoes"
	else:
		if chroma > 0.15: return ""
		if brightness >= 0.40 and brightness <= 0.65: return "pants"
		if brightness > 0.008 and brightness < 0.08: return "shoes"
		if brightness <= 0.008: return "top" if mesh_name.begins_with("Vert_") else "hair"
	return ""

func _setup_buttons() -> void:
	var buttons: Array[Button] = [restart_btn, select_btn, exit_btn]
	var angles := [-2.0, 2.0, -1.5]
	for i in range(buttons.size()):
		var btn: Button = buttons[i]
		btn.pivot_offset = btn.size / 2.0
		btn.resized.connect(func(): btn.pivot_offset = btn.size / 2.0)
		btn.mouse_entered.connect(_on_btn_hover.bind(btn, angles[i]))
		btn.mouse_exited.connect(_on_btn_unhover.bind(btn))

	restart_btn.pressed.connect(_on_restart)
	select_btn.pressed.connect(_on_select_char)
	exit_btn.pressed.connect(_on_exit)

func _animate_title() -> void:
	title_label.pivot_offset = title_label.size / 2.0
	title_label.resized.connect(func(): title_label.pivot_offset = title_label.size / 2.0)

	var base_y := title_label.position.y
	var float_t := create_tween().set_loops()
	float_t.tween_property(title_label, "position:y", base_y - 14.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	float_t.tween_property(title_label, "position:y", base_y, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var wobble_t := create_tween().set_loops()
	wobble_t.tween_property(title_label, "rotation_degrees", 3.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble_t.tween_property(title_label, "rotation_degrees", -3.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _play_press_anim(btn: Button, callback: Callable) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.disabled = true
	var normal_style := btn.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	btn.add_theme_stylebox_override("normal", normal_style)
	btn.add_theme_stylebox_override("hover", normal_style)
	btn.add_theme_stylebox_override("disabled", normal_style)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(0.85, 0.85), 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "position:y", btn.position.y + 16.0, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(val: int): normal_style.border_width_bottom = val, 8, 1, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().set_parallel(false)
	tween.tween_interval(0.18)
	tween.tween_callback(callback)

func _on_restart() -> void:
	_play_press_anim(restart_btn, func():
		get_tree().change_scene_to_file("res://global/node_3d.tscn")
	)

func _on_select_char() -> void:
	_play_press_anim(select_btn, func():
		get_tree().change_scene_to_file("res://scenes/menu/char_select.tscn")
	)

func _on_exit() -> void:
	_play_press_anim(exit_btn, func():
		get_tree().quit()
	)

func _on_btn_hover(btn: Button, hover_angle: float) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "rotation_degrees", hover_angle, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "theme_override_colors/font_color", Color(1, 0.95, 0.6), 0.15)

func _on_btn_unhover(btn: Button) -> void:
	var tween := create_tween().set_parallel(true)
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "rotation_degrees", 0.0, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(btn, "theme_override_colors/font_color", Color(1, 1, 1), 0.15)
