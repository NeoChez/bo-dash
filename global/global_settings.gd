extends Node

const CONFIG_PATH := "user://settings.cfg"

var player_1_character: String = "male"
var player_2_character: String = "male"
var last_winner_id: int = 0  # 0 = draw, 1 = player1, 2 = player2
var last_scores: Dictionary = {1: 0, 2: 0}
var player_1_colors: Dictionary = {"pants": Color(0.22,0.22,0.22), "hair": Color(0.03,0.03,0.03), "top": Color(0.03,0.03,0.03), "shoes": Color(0.03,0.03,0.03)}
var player_2_colors: Dictionary = {"pants": Color(0.22,0.22,0.22), "hair": Color(0.03,0.03,0.03), "top": Color(0.03,0.03,0.03), "shoes": Color(0.03,0.03,0.03)}

# ── AUDIO ─────────────────────────────────────────────────────────────────────
var bgm_volume: float = 1.0
var sfx_volume: float = 1.0

# ── SKILL REGISTRY ───────────────────────────────────────────────────────────
# Tambah skill baru cukup dengan menambah entry di sini.
# "tier"       : "basic" (aman) atau "annoying" (bahaya)
# "name"       : teks yang tampil di HUD (sementara sampai asset jadi)
# "color"      : warna slot HUD
# "key"        : string yang dikirim ke player.apply_powerup()
# "magnitude"  : kekuatan efek
# "duration"   : durasi efek (detik)
# "scene_path" : (opsional) path ke scene/CanvasLayer untuk visual custom
var skills: Dictionary = {
	0: {
		"name": "Bubble Shield",
		"tier": "basic",
		"color": Color(0.4, 0.85, 1.0, 0.75),
		"key": "bubble_shield",
		"magnitude": 1.0,
		"duration": 0.0,   # permanent until consumed by one hit
		"scene_path": "",
	},
	1: {
		"name": "Iron Anchor",
		"tier": "basic",
		"color": Color(0.55, 0.6, 0.7, 0.75),
		"key": "iron_anchor",
		"magnitude": 0.9,  # fraction of conveyor velocity cancelled each frame
		"duration": 5.0,
		"scene_path": "",
	},
	2: {
		"name": "Balloon Curse",
		"tier": "annoying",
		"color": Color(1.0, 0.5, 0.82, 0.75),
		"key": "balloon_curse",
		"magnitude": 0.8,  # fraction of conveyor velocity added as extra push
		"duration": 3.0,
		"scene_path": "",
	},
	3: {
		"name": "Slingshot Rocket",
		"tier": "annoying",
		"color": Color(1.0, 0.28, 0.18, 0.75),
		"key": "slingshot_rocket",
		"magnitude": 55.0,
		"duration": 0.5,
		"scene_path": "",
	},
	4: {
		"name": "Meteor Strike",
		"tier": "annoying",
		"color": Color(0.95, 0.5, 0.1, 0.75),
		"key": "meteor_strike",
		"magnitude": 40.0,
		"duration": 0.0,
		"scene_path": "res://scenes/skills/meteor.tscn",
	},
	5: {
		"name": "Speed Boost",
		"tier": "basic",
		"color": Color(0.2, 0.9, 0.4, 0.75),
		"key": "speed_boost",
		"magnitude": 1.5,
		"duration": 4.0,
		"scene_path": "",
	},
	6: {
		"name": "Dash Recharge",
		"tier": "basic",
		"color": Color(0.9, 0.85, 0.2, 0.75),
		"key": "dash_recharge",
		"magnitude": 1.0,
		"duration": 0.0,
		"scene_path": "",
	},
}

# device ID yang terikat ke tiap player (-1 = tidak ada controller)
var controller_p1: int = -1
var controller_p2: int = -1

var controller_dialog_enabled: bool = false

var _notif_label: Label = null
var _notif_tween: Tween = null
var _dialog: Control = null
var _dialog_label: Label = null
var _dialog_mode: String = "bind"  # "bind" = assign free slot, "switch" = take over
var _pending_device: int = -1
var _pending_device_queue: Array[int] = []

# Mapping tombol PS per action suffix
const _BINDINGS: Dictionary = {
	"left":  [{"type": "button", "index": 14}, {"type": "motion", "axis": 0, "value": -1.0}],
	"right": [{"type": "button", "index": 15}, {"type": "motion", "axis": 0, "value":  1.0}],
	"up":    [{"type": "button", "index": 12}, {"type": "motion", "axis": 1, "value": -1.0}],
	"down":  [{"type": "button", "index": 13}, {"type": "motion", "axis": 1, "value":  1.0}],
	"jump":  [{"type": "button", "index": 0}],   # Cross/X
	"dash":  [{"type": "button", "index": 1}],   # Circle/○
	"skill": [{"type": "button", "index": 3}],   # Triangle/△
}


func _ready() -> void:
	_setup_audio_buses()
	load_settings()
	apply_audio()
	call_deferred("_assign_menu_music_bus")
	_build_ui()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for device in Input.get_connected_joypads():
		_on_joy_connection_changed(device, true)


func _setup_audio_buses() -> void:
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "Music")
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		var idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, "SFX")
		AudioServer.set_bus_send(idx, "Master")


func _assign_menu_music_bus() -> void:
	var mm := get_node_or_null("/root/MenuMusic")
	if mm is AudioStreamPlayer:
		mm.bus = "Music"


func apply_audio() -> void:
	var music_idx := AudioServer.get_bus_index("Music")
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(bgm_volume))
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(sfx_volume))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "bgm_volume", bgm_volume)
	cfg.set_value("audio", "sfx_volume", sfx_volume)
	for action in InputMap.get_actions():
		if not (action.begins_with("p1_") or action.begins_with("p2_")):
			continue
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				var kc: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
				cfg.set_value("keybindings", action, [kc, ev.location])
				break
	cfg.save(CONFIG_PATH)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	bgm_volume = cfg.get_value("audio", "bgm_volume", 1.0)
	sfx_volume = cfg.get_value("audio", "sfx_volume", 1.0)
	for action in InputMap.get_actions():
		if not (action.begins_with("p1_") or action.begins_with("p2_")):
			continue
		var stored = cfg.get_value("keybindings", action, null)
		if stored == null:
			continue
		var keycode: int = 0
		var location: int = 0
		if stored is Array and stored.size() >= 2:
			keycode = stored[0]
			location = stored[1]
		elif stored is int:
			keycode = stored  # format lama, location tidak diketahui
		if keycode == 0:
			continue
		for ev in InputMap.action_get_events(action).duplicate():
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		var new_ev := InputEventKey.new()
		new_ev.physical_keycode = keycode
		new_ev.location = location
		InputMap.action_add_event(action, new_ev)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_handle_connect(device)
	else:
		_handle_disconnect(device)


func enable_controller_dialog() -> void:
	controller_dialog_enabled = true
	_process_next_queued_device()


func _handle_connect(device: int) -> void:
	var p1_free := controller_p1 == -1
	var p2_free := controller_p2 == -1

	if not controller_dialog_enabled:
		if not _pending_device_queue.has(device):
			_pending_device_queue.append(device)
		return

	if _dialog.visible:
		# Dialog sudah terbuka untuk device lain — antre
		if not _pending_device_queue.has(device):
			_pending_device_queue.append(device)
		return

	if p1_free and p2_free:
		_dialog_mode = "bind"
		_show_bind_dialog(device)
	elif not p1_free and p2_free:
		_bind(2, device)
		_show_notif("Controller P2 connected ✓", true)
	elif p1_free and not p2_free:
		_bind(1, device)
		_show_notif("Controller P1 connected ✓", true)
	else:
		_dialog_mode = "switch"
		_show_bind_dialog(device)


func _handle_disconnect(device: int) -> void:
	_pending_device_queue.erase(device)
	if controller_p1 == device:
		controller_p1 = -1
		_clear_joy_bindings(1)
		_show_notif("Controller P1 disconnected ✗", false)
	elif controller_p2 == device:
		controller_p2 = -1
		_clear_joy_bindings(2)
		_show_notif("Controller P2 disconnected ✗", false)


func _process_next_queued_device() -> void:
	if _pending_device_queue.is_empty():
		return
	var next: int = _pending_device_queue.pop_front()
	_handle_connect(next)


func _bind(player: int, device: int) -> void:
	if player == 1:
		controller_p1 = device
	else:
		controller_p2 = device

	for suffix in _BINDINGS.keys():
		var action := "p%d_%s" % [player, suffix]
		if not InputMap.has_action(action):
			continue
		# Hapus event joypad lama untuk player ini
		for ev in InputMap.action_get_events(action).duplicate():
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(action, ev)
		# Tambah event baru dengan device ID yang benar
		for b in _BINDINGS[suffix]:
			var ev: InputEvent
			if b["type"] == "button":
				var btn := InputEventJoypadButton.new()
				btn.device = device
				btn.button_index = b["index"]
				ev = btn
			else:
				var mot := InputEventJoypadMotion.new()
				mot.device = device
				mot.axis = b["axis"]
				mot.axis_value = b["value"]
				ev = mot
			InputMap.action_add_event(action, ev)


func _clear_joy_bindings(player: int) -> void:
	for suffix in _BINDINGS.keys():
		var action := "p%d_%s" % [player, suffix]
		if not InputMap.has_action(action):
			continue
		for ev in InputMap.action_get_events(action).duplicate():
			if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
				InputMap.action_erase_event(action, ev)


# ── UI ──────────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	# Notifikasi kecil di atas tengah
	_notif_label = Label.new()
	_notif_label.visible = false
	_notif_label.anchor_left = 0.5
	_notif_label.anchor_right = 0.5
	_notif_label.offset_left = -180.0
	_notif_label.offset_right = 180.0
	_notif_label.offset_top = 16.0
	_notif_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notif_label.add_theme_font_size_override("font_size", 18)
	_notif_label.add_theme_constant_override("shadow_offset_x", 2)
	_notif_label.add_theme_constant_override("shadow_offset_y", 2)
	_notif_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	canvas.add_child(_notif_label)

	# Dialog pilih player — awalnya tersembunyi
	_dialog = _build_dialog()
	canvas.add_child(_dialog)


func _build_dialog() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false

	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.60)
	root.add_child(overlay)

	var panel := Panel.new()
	panel.anchor_left = 0.5; panel.anchor_top = 0.5
	panel.anchor_right = 0.5; panel.anchor_bottom = 0.5
	panel.offset_left = -200.0; panel.offset_top = -108.0
	panel.offset_right = 200.0; panel.offset_bottom = 108.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.08, 0.11, 0.97)
	for s in [0,1,2,3]: ps.set_border_width(s, 2)
	ps.border_width_bottom = 6
	ps.border_color = Color(0.9, 0.78, 0.46, 0.9)
	for c in range(4): ps.set_corner_radius(c, 22)
	ps.shadow_color = Color(0, 0, 0, 0.5)
	ps.shadow_size = 14
	panel.add_theme_stylebox_override("panel", ps)
	root.add_child(panel)

	var font := load("res://assets/fonts/Wonder_Boys.ttf") as Font

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24; vbox.offset_right = -24
	vbox.offset_top = 18; vbox.offset_bottom = -18
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Controller connected!\nAssign to which player?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	if font: lbl.add_theme_font_override("font", font)
	lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.8, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 5)
	vbox.add_child(lbl)
	_dialog_label = lbl

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 10)
	vbox.add_child(hbox)

	var btn1 := _make_dialog_btn("Player 1", Color(0.0, 0.52, 0.88), Color(0.0, 0.32, 0.60), font)
	btn1.pressed.connect(func(): _on_dialog_choose(1))
	hbox.add_child(btn1)

	var btn2 := _make_dialog_btn("Player 2", Color(0.88, 0.44, 0.06), Color(0.60, 0.26, 0.02), font)
	btn2.pressed.connect(func(): _on_dialog_choose(2))
	hbox.add_child(btn2)

	var cancel_btn := _make_dialog_btn("Cancel", Color(0.30, 0.30, 0.35), Color(0.18, 0.18, 0.22), font)
	cancel_btn.pressed.connect(func():
		_dialog.visible = false
		_pending_device = -1
		_dialog_mode = "bind"
		_process_next_queued_device()
	)
	hbox.add_child(cancel_btn)

	root.set_meta("btn1", btn1)
	root.set_meta("btn2", btn2)
	return root


func _make_dialog_btn(text: String, bg: Color, border: Color, font: Font) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(106, 48)
	btn.add_theme_font_size_override("font_size", 18)
	if font: btn.add_theme_font_override("font", font)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	btn.add_theme_constant_override("outline_size", 6)
	var normal := StyleBoxFlat.new()
	normal.bg_color = bg; normal.border_color = border
	for s in [0,1,2,3]: normal.set_border_width(s, 2)
	normal.border_width_bottom = 6
	for c in range(4): normal.set_corner_radius(c, 16)
	normal.content_margin_top = 8.0; normal.content_margin_bottom = 14.0
	btn.add_theme_stylebox_override("normal", normal)
	var hover := StyleBoxFlat.new()
	hover.bg_color = bg.lightened(0.14); hover.border_color = border
	for s in [0,1,2,3]: hover.set_border_width(s, 2)
	hover.border_width_bottom = 6
	for c in range(4): hover.set_corner_radius(c, 16)
	hover.content_margin_top = 8.0; hover.content_margin_bottom = 14.0
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", hover)
	return btn


func _show_bind_dialog(device: int) -> void:
	_pending_device = device
	var btn1: Button = _dialog.get_meta("btn1")
	var btn2: Button = _dialog.get_meta("btn2")
	if _dialog_mode == "switch":
		btn1.disabled = false
		btn2.disabled = false
		btn1.text = "Player 1" + (" (active)" if controller_p1 != -1 else "")
		btn2.text = "Player 2" + (" (active)" if controller_p2 != -1 else "")
		if _dialog_label:
			_dialog_label.text = "New controller detected!\nTake over which player?"
	else:
		btn1.disabled = controller_p1 != -1
		btn2.disabled = controller_p2 != -1
		btn1.text = "Player 1" + (" (taken)" if controller_p1 != -1 else "")
		btn2.text = "Player 2" + (" (taken)" if controller_p2 != -1 else "")
		if _dialog_label:
			_dialog_label.text = "Controller connected!\nAssign to which player?"
	_dialog.visible = true


func _on_dialog_choose(player: int) -> void:
	_dialog.visible = false
	if _pending_device == -1:
		return
	if _dialog_mode == "switch":
		_clear_joy_bindings(player)
		if player == 1: controller_p1 = -1
		else: controller_p2 = -1
	_bind(player, _pending_device)
	_show_notif("Controller P%d connected ✓" % player, true)
	_pending_device = -1
	_dialog_mode = "bind"
	_process_next_queued_device()


func swap_controllers() -> void:
	var temp := controller_p1
	controller_p1 = controller_p2
	controller_p2 = temp
	if controller_p1 >= 0:
		_bind(1, controller_p1)
	else:
		_clear_joy_bindings(1)
	if controller_p2 >= 0:
		_bind(2, controller_p2)
	else:
		_clear_joy_bindings(2)
	_show_notif("Controller P1 ↔ P2 swapped ✓", true)


func _show_notif(msg: String, success: bool) -> void:
	if _notif_label == null:
		return
	_notif_label.text = msg
	_notif_label.modulate = Color(0.3, 1.0, 0.5) if success else Color(1.0, 0.4, 0.3)
	_notif_label.modulate.a = 1.0
	_notif_label.visible = true
	if _notif_tween:
		_notif_tween.kill()
	_notif_tween = create_tween()
	_notif_tween.tween_interval(2.0)
	_notif_tween.tween_property(_notif_label, "modulate:a", 0.0, 0.5)
	_notif_tween.tween_callback(func(): _notif_label.visible = false)
