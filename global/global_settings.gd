extends Node

var player_1_character: String = "male"
var player_2_character: String = "male"

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

var _notif_label: Label = null
var _notif_tween: Tween = null
var _dialog: Control = null
var _pending_device: int = -1

# Mapping tombol PS per action suffix
const _BINDINGS: Dictionary = {
	"left":  [{"type": "button", "index": 14}, {"type": "motion", "axis": 0, "value": -1.0}],
	"right": [{"type": "button", "index": 15}, {"type": "motion", "axis": 0, "value":  1.0}],
	"up":    [{"type": "button", "index": 12}, {"type": "motion", "axis": 1, "value": -1.0}],
	"down":  [{"type": "button", "index": 13}, {"type": "motion", "axis": 1, "value":  1.0}],
	"jump":  [{"type": "button", "index": 0}],   # Cross
	"dash":  [{"type": "button", "index": 5}],   # R1
	"skill": [{"type": "button", "index": 3}],   # Triangle
}


func _ready() -> void:
	_build_ui()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	for device in Input.get_connected_joypads():
		_on_joy_connection_changed(device, true)


func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		_handle_connect(device)
	else:
		_handle_disconnect(device)


func _handle_connect(device: int) -> void:
	var p1_free := controller_p1 == -1
	var p2_free := controller_p2 == -1

	if p1_free and p2_free:
		_show_bind_dialog(device)
	elif not p1_free and p2_free:
		_bind(2, device)
		_show_notif("Controller P2 otomatis terhubung ✓", true)
	elif p1_free and not p2_free:
		_bind(1, device)
		_show_notif("Controller P1 otomatis terhubung ✓", true)
	else:
		_show_notif("Semua slot controller sudah terisi", false)


func _handle_disconnect(device: int) -> void:
	if controller_p1 == device:
		controller_p1 = -1
		_clear_joy_bindings(1)
		_show_notif("Controller P1 terputus ✗", false)
	elif controller_p2 == device:
		controller_p2 = -1
		_clear_joy_bindings(2)
		_show_notif("Controller P2 terputus ✗", false)


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

	# Overlay gelap
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.55)
	root.add_child(overlay)

	# Panel tengah
	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -160.0
	panel.offset_top = -80.0
	panel.offset_right = 160.0
	panel.offset_bottom = 80.0
	root.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)

	var lbl := Label.new()
	lbl.text = "Controller terhubung!\nBind ke player mana?"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	vbox.add_child(lbl)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(hbox)

	var btn1 := Button.new()
	btn1.text = "Player 1"
	btn1.custom_minimum_size = Vector2(110, 40)
	btn1.pressed.connect(func(): _on_dialog_choose(1))
	hbox.add_child(btn1)

	var btn2 := Button.new()
	btn2.text = "Player 2"
	btn2.custom_minimum_size = Vector2(110, 40)
	btn2.pressed.connect(func(): _on_dialog_choose(2))
	hbox.add_child(btn2)

	# Simpan referensi tombol agar bisa di-disable
	root.set_meta("btn1", btn1)
	root.set_meta("btn2", btn2)

	return root


func _show_bind_dialog(device: int) -> void:
	_pending_device = device
	# Disable tombol slot yang sudah terisi
	var btn1: Button = _dialog.get_meta("btn1")
	var btn2: Button = _dialog.get_meta("btn2")
	btn1.disabled = controller_p1 != -1
	btn2.disabled = controller_p2 != -1
	btn1.text = "Player 1" + (" (terisi)" if controller_p1 != -1 else "")
	btn2.text = "Player 2" + (" (terisi)" if controller_p2 != -1 else "")
	_dialog.visible = true


func _on_dialog_choose(player: int) -> void:
	_dialog.visible = false
	if _pending_device == -1:
		return
	_bind(player, _pending_device)
	_show_notif("Controller P%d terhubung ✓" % player, true)
	_pending_device = -1


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
