extends Control

const ACTIONS_P1 := ["p1_left", "p1_right", "p1_up", "p1_down", "p1_jump", "p1_dash", "p1_skill"]
const ACTIONS_P2 := ["p2_left", "p2_right", "p2_up", "p2_down", "p2_jump", "p2_dash", "p2_skill"]
const ACTION_LABELS := ["Left", "Right", "Up", "Down", "Jump", "Dash", "Skill"]

var _listening_action: String = ""
var _listening_btn: Button = null
var _bind_btns: Dictionary = {}
var _bgm_slider: HSlider
var _sfx_slider: HSlider

const FONT_PATH := "res://assets/fonts/Wonder_Boys.ttf"


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var font: Font = load(FONT_PATH) if ResourceLoader.exists(FONT_PATH) else null

	# Semi-transparent dark overlay
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	# Popup panel — 62% lebar, 82% tinggi layar, centered via anchor
	var panel := Panel.new()
	panel.anchor_left = 0.25
	panel.anchor_right = 0.75
	panel.anchor_top = 0.14
	panel.anchor_bottom = 0.86
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.05, 0.08, 0.11, 0.97)
	panel_style.border_color = Color(0.9, 0.78, 0.46, 0.9)
	for side in [0, 1, 2, 3]: panel_style.set_border_width(side, 3)
	panel_style.border_width_bottom = 7
	for c in range(4): panel_style.set_corner_radius(c, 24)
	panel_style.shadow_color = Color(0, 0, 0, 0.45)
	panel_style.shadow_size = 16
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	# Scroll container inside panel
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 0
	scroll.offset_top = 0
	panel.add_child(scroll)

	var inner := MarginContainer.new()
	inner.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	inner.add_theme_constant_override("margin_left", 50)
	inner.add_theme_constant_override("margin_right", 50)
	inner.add_theme_constant_override("margin_top", 32)
	inner.add_theme_constant_override("margin_bottom", 32)
	scroll.add_child(inner)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 20)
	inner.add_child(content)

	# ── Title
	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	if font: title.add_theme_font_override("font", font)
	title.add_theme_color_override("font_color", Color(1, 0.92, 0.05, 1))
	title.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18, 1))
	title.add_theme_constant_override("outline_size", 12)
	content.add_child(title)

	_add_separator(content)

	# ── AUDIO SECTION
	_add_section_label(content, "AUDIO", font)

	var audio_grid := GridContainer.new()
	audio_grid.columns = 3
	audio_grid.add_theme_constant_override("h_separation", 16)
	audio_grid.add_theme_constant_override("v_separation", 12)
	content.add_child(audio_grid)

	# BGM
	_add_label(audio_grid, "BGM Music", font)
	_bgm_slider = _make_slider(GlobalSettings.bgm_volume)
	_bgm_slider.value_changed.connect(_on_bgm_changed)
	audio_grid.add_child(_bgm_slider)
	var bgm_pct := _make_pct_label(int(GlobalSettings.bgm_volume * 100))
	audio_grid.add_child(bgm_pct)
	_bgm_slider.value_changed.connect(func(v): bgm_pct.text = "%d%%" % int(v * 100))

	# SFX
	_add_label(audio_grid, "SFX", font)
	_sfx_slider = _make_slider(GlobalSettings.sfx_volume)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	audio_grid.add_child(_sfx_slider)
	var sfx_pct := _make_pct_label(int(GlobalSettings.sfx_volume * 100))
	audio_grid.add_child(sfx_pct)
	_sfx_slider.value_changed.connect(func(v): sfx_pct.text = "%d%%" % int(v * 100))

	_add_separator(content)

	# ── KEY BINDINGS SECTION
	_add_section_label(content, "KEY BINDINGS", font)

	var hint := Label.new()
	hint.text = "Click a button then press a key to remap. Press Esc to cancel."
	hint.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9, 0.8))
	hint.add_theme_font_size_override("font_size", 18)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)

	# Two-column layout: P1 | P2
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 40)
	content.add_child(columns)

	_build_player_bindings(columns, "PLAYER 1 (Left)", ACTIONS_P1, font)
	var divider := VSeparator.new()
	divider.custom_minimum_size = Vector2(2, 0)
	columns.add_child(divider)
	_build_player_bindings(columns, "PLAYER 2 (Right)", ACTIONS_P2, font)

	_add_separator(content)

	# ── CONTROLLER section
	_add_section_label(content, "CONTROLLER", font)

	var layout_lbl := Label.new()
	layout_lbl.text = "PS Controller layout (same for P1 & P2):\n🕹️ Left Stick → Move   ✕ Cross → Jump   ○ Circle → Dash   △ Triangle → Skill"
	layout_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout_lbl.add_theme_font_size_override("font_size", 17)
	layout_lbl.add_theme_color_override("font_color", Color(0.82, 0.92, 1.0, 0.9))
	layout_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	layout_lbl.add_theme_constant_override("outline_size", 3)
	content.add_child(layout_lbl)

	var p1_ctrl_lbl := Label.new()
	p1_ctrl_lbl.text = _controller_status_text(1)
	p1_ctrl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p1_ctrl_lbl.add_theme_font_size_override("font_size", 18)
	p1_ctrl_lbl.add_theme_color_override("font_color", Color(0.4, 0.88, 1.0, 1))
	content.add_child(p1_ctrl_lbl)

	var p2_ctrl_lbl := Label.new()
	p2_ctrl_lbl.text = _controller_status_text(2)
	p2_ctrl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p2_ctrl_lbl.add_theme_font_size_override("font_size", 18)
	p2_ctrl_lbl.add_theme_color_override("font_color", Color(1.0, 0.72, 0.15, 1))
	content.add_child(p2_ctrl_lbl)

	var swap_btn := _make_button("SWAP P1 ↔ P2", font)
	swap_btn.custom_minimum_size = Vector2(260, 52)
	swap_btn.pressed.connect(func():
		GlobalSettings.swap_controllers()
		p1_ctrl_lbl.text = _controller_status_text(1)
		p2_ctrl_lbl.text = _controller_status_text(2)
	)
	var swap_center := CenterContainer.new()
	swap_center.add_child(swap_btn)
	content.add_child(swap_center)

	_add_separator(content)

	# ── Back button
	var back_btn := _make_button("BACK", font)
	back_btn.custom_minimum_size = Vector2(200, 52)
	back_btn.pressed.connect(_on_back_pressed)
	var back_center := CenterContainer.new()
	back_center.add_child(back_btn)
	content.add_child(back_center)


func _build_player_bindings(parent: Control, title: String, actions: Array, font: Font) -> void:
	var col := VBoxContainer.new()
	col.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	col.add_theme_constant_override("separation", 8)
	parent.add_child(col)

	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30)
	if font: lbl.add_theme_font_override("font", font)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0, 1))
	col.add_child(lbl)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)

	for i in range(actions.size()):
		var action: String = actions[i]
		var row_lbl := Label.new()
		row_lbl.text = ACTION_LABELS[i]
		row_lbl.add_theme_font_size_override("font_size", 22)
		row_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
		row_lbl.custom_minimum_size = Vector2(100, 0)
		grid.add_child(row_lbl)

		var btn := _make_key_button(_get_key_label(action), font)
		btn.pressed.connect(_start_listening.bind(action, btn))
		grid.add_child(btn)
		_bind_btns[action] = btn


func _make_slider(value: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = value
	s.custom_minimum_size = Vector2(260, 36)
	s.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	return s


func _make_pct_label(pct: int) -> Label:
	var l := Label.new()
	l.text = "%d%%" % pct
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	l.custom_minimum_size = Vector2(60, 0)
	return l


func _make_button(text: String, font: Font) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 28)
	if font: btn.add_theme_font_override("font", font)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18, 1))
	btn.add_theme_constant_override("outline_size", 10)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 0.09, 0.27, 1)
	normal.border_width_bottom = 8
	normal.border_color = Color(0.69, 0.06, 0.18, 1)
	for c in range(4): normal.set_corner_radius(c, 22)
	normal.content_margin_top = 10
	normal.content_margin_bottom = 18
	btn.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1, 0.32, 0.32, 1)
	hover.border_width_bottom = 10
	hover.border_color = Color(0.84, 0.08, 0.23, 1)
	for c in range(4): hover.set_corner_radius(c, 22)
	hover.content_margin_top = 8
	hover.content_margin_bottom = 18
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	return btn


func _make_key_button(label: String, font: Font) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(190, 48)
	btn.add_theme_font_size_override("font_size", 20)
	if font: btn.add_theme_font_override("font", font)
	btn.add_theme_color_override("font_color", Color(1, 1, 0.8, 1))
	btn.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18, 1))
	btn.add_theme_constant_override("outline_size", 4)
	return btn


func _add_label(parent: Control, text: String, font: Font) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	l.custom_minimum_size = Vector2(160, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)


func _add_section_label(parent: Control, text: String, font: Font) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 32)
	if font: l.add_theme_font_override("font", font)
	l.add_theme_color_override("font_color", Color(0.4, 0.88, 1.0, 1))
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18, 1))
	l.add_theme_constant_override("outline_size", 6)
	parent.add_child(l)


func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)


const SYMBOL_MAP := {
	KEY_SEMICOLON: ";",
	KEY_APOSTROPHE: "'",
	KEY_QUOTELEFT: "`",
	KEY_BRACKETLEFT: "[",
	KEY_BRACKETRIGHT: "]",
	KEY_BACKSLASH: "\\",
	KEY_SLASH: "/",
	KEY_COMMA: ",",
	KEY_PERIOD: ".",
	KEY_MINUS: "-",
	KEY_EQUAL: "=",
	KEY_PLUS: "+",
	KEY_ASTERISK: "*",
}

# Keys that exist in Left and Right variants
const SIDED_KEYS := [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]


func _get_key_label(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var kc: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			var label: String = SYMBOL_MAP.get(kc, OS.get_keycode_string(kc))
			if kc in SIDED_KEYS:
				if ev.location == 1:    # KEY_LOCATION_LEFT
					label += " (L)"
				elif ev.location == 2:  # KEY_LOCATION_RIGHT
					label += " (R)"
			return label
	return "---"


func _start_listening(action: String, btn: Button) -> void:
	if _listening_action != "":
		if _listening_btn:
			_listening_btn.text = _get_key_label(_listening_action)
	_listening_action = action
	_listening_btn = btn
	btn.text = "[ Press... ]"


func _cancel_listening() -> void:
	_listening_action = ""
	_listening_btn = null


func _input(event: InputEvent) -> void:
	if _listening_action == "":
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	if event.physical_keycode == KEY_ESCAPE:
		if _listening_btn:
			_listening_btn.text = _get_key_label(_listening_action)
		_cancel_listening()
		get_viewport().set_input_as_handled()
		return

	# Remap: remove old keyboard event, add new
	for ev in InputMap.action_get_events(_listening_action).duplicate():
		if ev is InputEventKey:
			InputMap.action_erase_event(_listening_action, ev)

	var new_ev := InputEventKey.new()
	new_ev.physical_keycode = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	new_ev.location = event.location  # preserve Left/Right side info
	InputMap.action_add_event(_listening_action, new_ev)

	if _listening_btn:
		_listening_btn.text = _get_key_label(_listening_action)
	_cancel_listening()
	GlobalSettings.save_settings()
	get_viewport().set_input_as_handled()


func _on_bgm_changed(value: float) -> void:
	GlobalSettings.bgm_volume = value
	GlobalSettings.apply_audio()
	GlobalSettings.save_settings()


func _on_sfx_changed(value: float) -> void:
	GlobalSettings.sfx_volume = value
	GlobalSettings.apply_audio()
	GlobalSettings.save_settings()


func _controller_status_text(player: int) -> String:
	var device: int = GlobalSettings.controller_p1 if player == 1 else GlobalSettings.controller_p2
	if device < 0:
		return "Player %d: Keyboard only" % player
	var joy_name := Input.get_joy_name(device)
	return "Player %d: %s" % [player, joy_name if joy_name != "" else "Controller #%d" % (device + 1)]


func _on_back_pressed() -> void:
	queue_free()
