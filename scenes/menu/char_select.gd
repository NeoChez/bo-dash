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
@onready var p2_vbox = $HBoxContainer/P2Panel/VBox
@onready var p1_vbox = $HBoxContainer/P1Panel/VBox

var characters = ["male", "female"]

# ── Outfit colour customisation ───────────────────────────────────────────
# Female-specific girly palettes
# Female — Cool & Light Cool
const PALETTE_HAIR_F: Array[Color] = [
	Color(0.05, 0.05, 0.05), Color(0.20, 0.20, 0.20),
	Color(0.48, 0.48, 0.48), Color(0.48, 0.14, 0.36),
	Color(0.38, 0.10, 0.62), Color(0.12, 0.22, 0.72),
	Color(0.84, 0.16, 0.60), Color(0.10, 0.65, 0.65),
	Color(0.10, 0.52, 0.28), Color(0.90, 0.90, 0.95),
]
const PALETTE_TOP_F: Array[Color] = [
	Color(0.84, 0.16, 0.60), Color(1.0,  0.40, 0.65),
	Color(0.38, 0.10, 0.62), Color(0.48, 0.14, 0.36),
	Color(0.10, 0.20, 0.72), Color(0.06, 0.12, 0.38),
	Color(0.08, 0.65, 0.65), Color(0.10, 0.52, 0.28),
	Color(0.72, 0.10, 0.15), Color(1.0,  1.0,  1.0),
]
const PALETTE_PANTS_F: Array[Color] = [
	Color(0.98, 0.82, 0.88), Color(0.70, 0.50, 0.58),
	Color(0.58, 0.40, 0.80), Color(0.62, 0.62, 0.90),
	Color(0.65, 0.80, 0.94), Color(0.62, 0.86, 0.80),
	Color(0.80, 0.80, 0.80), Color(0.90, 0.88, 0.82),
	Color(0.40, 0.40, 0.60), Color(0.20, 0.20, 0.20),
]
const PALETTE_SHOES_F: Array[Color] = [
	Color(0.05, 0.05, 0.05), Color(0.06, 0.12, 0.38),
	Color(0.48, 0.14, 0.36), Color(0.10, 0.20, 0.72),
	Color(0.20, 0.20, 0.20), Color(0.08, 0.52, 0.55),
	Color(0.72, 0.10, 0.15), Color(0.90, 0.88, 0.82),
]

const PALETTE_SHIRT: Array[Color] = [
	Color(0.82, 0.82, 0.82), Color(1.0, 1.0, 1.0),
	Color(0.9,  0.15, 0.15), Color(0.15, 0.4,  0.9),
	Color(0.15, 0.75, 0.2),  Color(1.0,  0.75, 0.0),
	Color(0.7,  0.15, 0.9),  Color(1.0,  0.45, 0.0),
]
const PALETTE_PANTS: Array[Color] = [
	Color(0.70, 0.52, 0.30), Color(0.80, 0.70, 0.52),
	Color(0.36, 0.40, 0.18), Color(0.14, 0.40, 0.38),
	Color(0.65, 0.72, 0.35), Color(0.52, 0.42, 0.30),
	Color(0.88, 0.80, 0.62), Color(0.22, 0.22, 0.22),
]
# Male — Warm & Light Warm
const PALETTE_HAIR: Array[Color] = [
	Color(0.05, 0.03, 0.02), Color(0.20, 0.10, 0.03),
	Color(0.32, 0.18, 0.05), Color(0.48, 0.28, 0.08),
	Color(0.65, 0.42, 0.15), Color(0.70, 0.35, 0.12),
	Color(0.70, 0.40, 0.20), Color(0.85, 0.70, 0.32),
	Color(0.22, 0.22, 0.22), Color(0.95, 0.92, 0.82),
]
const PALETTE_TOP: Array[Color] = [
	Color(0.70, 0.26, 0.10), Color(0.92, 0.46, 0.10),
	Color(0.80, 0.65, 0.10), Color(0.36, 0.42, 0.18),
	Color(0.14, 0.30, 0.14), Color(0.88, 0.48, 0.38),
	Color(0.10, 0.46, 0.44), Color(0.70, 0.52, 0.30),
	Color(0.08, 0.08, 0.08), Color(0.95, 0.92, 0.82),
]
const PALETTE_SHOES: Array[Color] = [
	Color(0.08, 0.05, 0.02), Color(0.30, 0.16, 0.05),
	Color(0.46, 0.26, 0.08), Color(0.68, 0.40, 0.20),
	Color(0.68, 0.26, 0.10), Color(0.60, 0.46, 0.30),
	Color(0.22, 0.22, 0.22), Color(0.80, 0.70, 0.52),
]
const MESH_MAP: Dictionary = {
	"male":   {"pants": ["Vert_005"],
			   "hair":  ["Cube_072"],
			   "top":   ["Vert_004"],
			   "shoes": ["Vert_006"]},
	"female": {"pants": ["Vert_028"],
			   "hair":  ["Object_2"],
			   "top":   ["Vert_029"],
			   "shoes": ["Vert_027"]},
}
const CAT_LABELS: Dictionary = {
	"male":   {"pants": "PANTS", "hair": "HAIR", "top": "SHIRT", "shoes": "SHOES"},
	"female": {"pants": "BOTTOM", "hair": "HAIR", "top": "TOP",  "shoes": "SHOES"},
}

var p1_colors := {"pants": Color(0.22,0.22,0.22), "hair": Color(0.03,0.03,0.03), "top": Color(0.03,0.03,0.03), "shoes": Color(0.03,0.03,0.03)}
var p2_colors := {"pants": Color(0.22,0.22,0.22), "hair": Color(0.03,0.03,0.03), "top": Color(0.03,0.03,0.03), "shoes": Color(0.03,0.03,0.03)}
var _p1_swatches: Dictionary = {}
var _p2_swatches: Dictionary = {}
var _p1_swatch_section: VBoxContainer = null
var _p2_swatch_section: VBoxContainer = null

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

const SHOWCASE_SPIN_SPEED: float = 50.0  # derajat per detik

func _ready() -> void:
	countdown_lbl.visible = false

	for card in [p2_card, p1_card]:
		card.pivot_offset = card.size / 2.0
		card.resized.connect(func(): card.pivot_offset = card.size / 2.0)

	_update_p2_ui()
	_update_p1_ui()
	_build_swatch_rows(p2_vbox, 2)
	_build_swatch_rows(p1_vbox, 1)
	_setup_external_labels()
	_add_back_button()


func _add_back_button() -> void:
	var font: Font = load("res://assets/fonts/Wonder_Boys.ttf")
	var btn := Button.new()
	btn.text = "← BACK"
	btn.offset_left = 20.0
	btn.offset_top = 18.0
	btn.offset_right = 180.0
	btn.offset_bottom = 64.0
	btn.add_theme_font_size_override("font_size", 22)
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18, 1))
	btn.add_theme_constant_override("outline_size", 8)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.95, 0.56, 0.1)
	normal.border_color = Color(0.72, 0.36, 0.02)
	for s in [0, 1, 2, 3]: normal.set_border_width(s, 2)
	normal.border_width_bottom = 6
	for c in range(4): normal.set_corner_radius(c, 20)
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 14.0
	btn.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1.0, 0.68, 0.18)
	hover.border_color = Color(0.72, 0.36, 0.02)
	for s in [0, 1, 2, 3]: hover.set_border_width(s, 2)
	hover.border_width_bottom = 6
	for c in range(4): hover.set_corner_radius(c, 20)
	hover.content_margin_top = 8.0
	hover.content_margin_bottom = 14.0
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn"))
	add_child(btn)

func _input(event: InputEvent) -> void:
	if countdown_active:
		return
		
	# --- PLAYER 1 (LEFT PLAYER, p1_* = WASD) ---
	if not p2_ready:
		if event.is_action_pressed("p1_left"):
			p2_index = (p2_index - 1 + characters.size()) % characters.size()
			_update_p2_ui()
			_bounce_card(p2_card)
		elif event.is_action_pressed("p1_right"):
			p2_index = (p2_index + 1) % characters.size()
			_update_p2_ui()
			_bounce_card(p2_card)

	if event.is_action_pressed("p1_up"):
		p2_ready = !p2_ready
		_update_p2_ui()
		_check_start_countdown()

	# --- PLAYER 2 (RIGHT PLAYER, p2_* = L/P/;/') ---
	if not p1_ready:
		if event.is_action_pressed("p2_left"):
			p1_index = (p1_index - 1 + characters.size()) % characters.size()
			_update_p1_ui()
			_bounce_card(p1_card)
		elif event.is_action_pressed("p2_right"):
			p1_index = (p1_index + 1) % characters.size()
			_update_p1_ui()
			_bounce_card(p1_card)

	if event.is_action_pressed("p2_up"):
		p1_ready = !p1_ready
		_update_p1_ui()
		_check_start_countdown()

func _process(delta: float) -> void:
	if p2_pivot:
		p2_pivot.rotation_degrees.y += SHOWCASE_SPIN_SPEED * delta
	if p1_pivot:
		p1_pivot.rotation_degrees.y += SHOWCASE_SPIN_SPEED * delta

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
	p2_char_lbl.text = raw_name.to_upper()

	_spawn_preview_model(p2_pivot, raw_name)
	if _p2_swatch_section != null:
		_build_swatch_rows(p2_vbox, 2)
	
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
	p1_char_lbl.text = raw_name.to_upper()

	_spawn_preview_model(p1_pivot, raw_name)
	if _p1_swatch_section != null:
		_build_swatch_rows(p1_vbox, 1)
	
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
		global_settings.player_1_character = characters[p2_index]
		global_settings.player_2_character = characters[p1_index]
		global_settings.player_1_colors = p2_colors.duplicate()
		global_settings.player_2_colors = p1_colors.duplicate()
	
	MenuMusic.stop()
	
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
		
		_play_first_animation(new_model)
		var colors = p2_colors if pivot == p2_pivot else p1_colors
		_apply_all_colors(new_model, char_name, colors)

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
	if not anim_player:
		return
	var anim_list = anim_player.get_animation_list()
	if anim_list.is_empty():
		return

	var chosen: String = anim_list[0]
	var anim = anim_player.get_animation(chosen)
	if anim:
		anim.loop_mode = Animation.LOOP_LINEAR
	anim_player.play(chosen)


# ── Colour customisation system ───────────────────────────────────────────

func _build_swatch_rows(vbox: VBoxContainer, player_id: int) -> void:
	# Hapus section lama supaya tidak duplikat
	var old_sec = _p1_swatch_section if player_id == 1 else _p2_swatch_section
	if old_sec and is_instance_valid(old_sec):
		old_sec.queue_free()

	var font_path := "res://assets/fonts/Wonder_Boys.ttf"
	var font: Font = load(font_path) if ResourceLoader.exists(font_path) else null

	var section := VBoxContainer.new()
	section.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	if player_id == 1:
		_p1_swatch_section = section
		_p1_swatches = {}
	else:
		_p2_swatch_section = section
		_p2_swatches = {}

	section.add_child(HSeparator.new())

	var char_name = characters[p1_index if player_id == 1 else p2_index]
	var labels: Dictionary = CAT_LABELS.get(char_name, {"pants":"PANTS","hair":"HAIR","top":"TOP","shoes":"SHOES"})
	var is_f: bool = char_name == "female"
	var rows := [
		["hair",  labels.get("hair",  ""), PALETTE_HAIR_F if is_f else PALETTE_HAIR],
		["top",   labels.get("top",   ""), PALETTE_TOP_F  if is_f else PALETTE_TOP],
		["pants", labels.get("pants", ""), PALETTE_PANTS_F if is_f else PALETTE_PANTS],
		["shoes", labels.get("shoes", ""), PALETTE_SHOES_F if is_f else PALETTE_SHOES],
	]
	var stored = p1_colors if player_id == 1 else p2_colors
	var swatch_ref = _p1_swatches if player_id == 1 else _p2_swatches

	for row_data in rows:
		var cat_key: String = row_data[0]
		var cat_label: String = row_data[1]
		var palette: Array = row_data[2]
		if cat_label.is_empty():
			continue

		var lbl := Label.new()
		lbl.text = cat_label
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		if font: lbl.add_theme_font_override("font", font)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		section.add_child(lbl)

		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 4)
		section.add_child(row)

		swatch_ref[cat_key] = []
		for i in range(palette.size()):
			var col: Color = palette[i]
			var selected := col.is_equal_approx(stored[cat_key])
			var btn := _make_swatch(col, selected)
			btn.pressed.connect(_on_swatch.bind(player_id, cat_key, col, i))
			row.add_child(btn)
			swatch_ref[cat_key].append(btn)

	vbox.add_child(section)


func _make_swatch(col: Color, selected: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(36, 36)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = col.lightened(0.2) if state == "hover" else col
		for c in range(4): s.set_corner_radius(c, 18)
		if selected and state == "normal":
			for side in [0,1,2,3]: s.set_border_width(side, 3)
			s.border_color = Color.WHITE
		btn.add_theme_stylebox_override(state, s)
	return btn


func _on_swatch(player_id: int, cat_key: String, col: Color, btn_idx: int) -> void:
	var colors_dict = p1_colors if player_id == 1 else p2_colors
	var swatch_ref = _p1_swatches if player_id == 1 else _p2_swatches
	colors_dict[cat_key] = col

	var char_name: String = characters[p1_index if player_id == 1 else p2_index]
	var is_f: bool = char_name == "female"
	var palette: Array
	match cat_key:
		"pants": palette = PALETTE_PANTS_F if is_f else PALETTE_PANTS
		"top":   palette = PALETTE_TOP_F   if is_f else PALETTE_TOP
		"shoes": palette = PALETTE_SHOES_F if is_f else PALETTE_SHOES
		_:       palette = PALETTE_HAIR_F  if is_f else PALETTE_HAIR
	for i in range(swatch_ref[cat_key].size()):
		var b: Button = swatch_ref[cat_key][i]
		var pc: Color = palette[i]
		var sel := (i == btn_idx)
		var style := StyleBoxFlat.new()
		style.bg_color = pc
		for c in range(4): style.set_corner_radius(c, 14)
		if sel:
			for s in [0,1,2,3]: style.set_border_width(s, 3)
			style.border_color = Color.WHITE
		b.add_theme_stylebox_override("normal", style)

	var pivot = p1_pivot if player_id == 1 else p2_pivot
	for model in pivot.get_children():
		_tint_nodes(model, MESH_MAP.get(char_name, {}).get(cat_key, []), col)


func _apply_all_colors(model: Node, char_name: String, colors: Dictionary) -> void:
	if not MESH_MAP.has(char_name):
		return
	for cat in colors.keys():
		_tint_nodes(model, MESH_MAP[char_name].get(cat, []), colors[cat])


func _setup_external_labels() -> void:
	var font_path := "res://assets/fonts/Wonder_Boys.ttf"
	var font: Font = load(font_path) if ResourceLoader.exists(font_path) else null

	# Sembunyikan PlayerTitle dan StatusLabel di dalam card
	$HBoxContainer/P2Panel/VBox/PlayerTitle.visible = false
	$HBoxContainer/P1Panel/VBox/PlayerTitle.visible = false

	# Reparent status labels ke bawah card
	var p2s: Label = p2_status_lbl
	var p1s: Label = p1_status_lbl
	p2s.get_parent().remove_child(p2s)
	p1s.get_parent().remove_child(p1s)
	add_child(p2s)
	add_child(p1s)

	for lbl in [p2s, p1s]:
		lbl.anchor_left   = 0.5
		lbl.anchor_right  = 0.5
		lbl.anchor_top    = 0.5
		lbl.anchor_bottom = 0.5
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 18)
		if font: lbl.add_theme_font_override("font", font)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
		lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18, 1))
		lbl.add_theme_constant_override("outline_size", 8)

	# P2 status (kiri bawah card)
	p2s.offset_left   = -595.0;  p2s.offset_right  = -35.0
	p2s.offset_top    =  460.0;  p2s.offset_bottom =  505.0
	# P1 status (kanan bawah card)
	p1s.offset_left   =  35.0;   p1s.offset_right  =  595.0
	p1s.offset_top    =  460.0;  p1s.offset_bottom =  505.0

	# Buat label PLAYER 1 / PLAYER 2 di atas card
	var titles := [
		["PLAYER 1", -595.0, -35.0],
		["PLAYER 2",   35.0, 595.0],
	]
	for t in titles:
		var lbl := Label.new()
		lbl.text            = t[0]
		lbl.anchor_left     = 0.5;  lbl.anchor_right  = 0.5
		lbl.anchor_top      = 0.5;  lbl.anchor_bottom = 0.5
		lbl.offset_left     = t[1]; lbl.offset_right  = t[2]
		lbl.offset_top      = -348.0; lbl.offset_bottom = -295.0
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 42)
		if font: lbl.add_theme_font_override("font", font)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18, 1))
		lbl.add_theme_constant_override("outline_size", 14)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.4))
		lbl.add_theme_constant_override("shadow_offset_y", 3)
		add_child(lbl)


func _tint_nodes(node: Node, names: Array, color: Color) -> void:
	if node is MeshInstance3D and node.name in names:
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			return
		var count := mi.mesh.get_surface_count()
		for i in range(count):
			var mat = mi.get_active_material(i)
			if mat is StandardMaterial3D:
				var nm := mat.duplicate() as StandardMaterial3D
				nm.albedo_color = color
				mi.set_surface_override_material(i, nm)
	for child in node.get_children():
		_tint_nodes(child, names, color)
