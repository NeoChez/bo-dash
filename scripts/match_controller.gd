extends Node3D

const MATCH_DURATION: float = 180.0
const _DEBUG_SKILL_SCENE := preload("res://scenes/powerups/skill_item.tscn")
const _CAST_BANNER := preload("res://scenes/ui/cast_banner.tscn")

# Emoji per skill id (urut sesuai GlobalSettings.skills)
const SKILL_EMOJI := {
	0: "🛡️",   # Bubble Shield
	1: "⚓",    # Iron Anchor
	2: "🎈",   # Balloon Curse
	3: "🚀",   # Slingshot Rocket
	4: "☄️",   # Meteor Strike
	5: "💨",   # Speed Boost
	6: "⚡",    # Dash Recharge
}

@export_group("Tweak — Conveyor")
@export var conveyor_start_multiplier: float = 0.92
@export var conveyor_end_multiplier: float = 3.0

@export_group("Sudden Death")
@export var sudden_death_enabled: bool = true
@export var sudden_death_duration: float = 60.0
@export var sd_conveyor_multiplier: float = 3.7
@export var sd_star_interval: float = 1.2
@export var sd_star_chance: float = 0.98
@export var sd_skill_interval: float = 2.9
@export var sd_skill_chance: float = 0.95

@onready var _skill_registry: Dictionary = GlobalSettings.skills

var _match_time_left: float = MATCH_DURATION
var _match_active: bool = true
var _scores := {1: 0, 2: 0}
var _skills := {1: -1, 2: -1}
var _carousel_active := {1: false, 2: false}
var _sudden_death_active: bool = false
var _sd_time_left: float = 0.0
var _sd_star_interval_orig: float = 0.0
var _sd_star_chance_orig: float = 0.0
var _sd_skill_interval_orig: float = 0.0
var _sd_skill_chance_orig: float = 0.0
var _sd_canvas: CanvasLayer = null
var _sd_camera_tween: Tween = null
var _sd_orig_fov: float = 75.0
var _dash_bar_left: ProgressBar = null
var _dash_bar_right: ProgressBar = null
var _slot_left_sb: StyleBoxFlat = null
var _slot_right_sb: StyleBoxFlat = null
var _score_font: Font = null

const _STAR_W := 44.0   # lebar emoji ⭐ di font_size 36
const _SCORE_GAP := 8.0 # jarak antara star dan angka

@onready var _player_1: CharacterBody3D = $Player2
@onready var _player_2: CharacterBody3D = $Player
@onready var _spawner_1: Node = $Spawner_Ground1
@onready var _spawner_2: Node = $Spawner_Ground2
@onready var _timer_label: Label = $HUD/TimerLabel
@onready var _score_left_label: Label = $HUD/ScoreLeftLabel
@onready var _score_right_label: Label = $HUD/ScoreRightLabel
@onready var _star_left_label: Label = $HUD/StarEmojiLeft
@onready var _star_right_label: Label = $HUD/StarEmojiRight
@onready var _result_label: Label = $HUD/ResultLabel
@onready var _skill_left_label: Label = $HUD/LeftSkillSlotA/SkillLabel
@onready var _skill_right_label: Label = $HUD/RightSkillSlotA/SkillLabel
@onready var _skill_left_panel: Panel = $HUD/LeftSkillSlotA
@onready var _skill_right_panel: Panel = $HUD/RightSkillSlotA


func _ready() -> void:
	add_to_group("match_controller")
	_slot_left_sb = _skill_left_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_skill_left_panel.add_theme_stylebox_override("panel", _slot_left_sb)
	_slot_right_sb = _skill_right_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_skill_right_panel.add_theme_stylebox_override("panel", _slot_right_sb)
	_score_font = load("res://assets/fonts/Wonder_Boys.ttf")
	_setup_dash_bars()
	_update_hud()
	_update_skill_slots()
	var bgm := get_node_or_null("AudioStreamPlayer")
	if bgm is AudioStreamPlayer:
		bgm.bus = "Music"


func _process(delta: float) -> void:
	_debug_handle_keys()
	if Input.is_action_just_pressed("ui_home"):
		_debug_spawn_skill_items()

	if _sudden_death_active:
		_sd_time_left = max(0.0, _sd_time_left - delta)
		_update_timer_label()
		_update_dash_bars()
		if _sd_time_left <= 0.0:
			_end_sudden_death()
		return

	if not _match_active:
		return

	_match_time_left = max(0.0, _match_time_left - delta)
	_update_match_progress()
	_update_timer_label()
	_update_dash_bars()
	if _match_time_left <= 0.0:
		_finish_match()


func on_star_collected(player_id: int, score_value: int) -> void:
	if not _match_active:
		return
	if not _scores.has(player_id):
		return

	_scores[player_id] += score_value
	_update_score_labels()


func on_skill_picked_up(player_id: int, skill_type: int) -> void:
	if not _match_active:
		return
	if not _skills.has(player_id):
		return
	_skills[player_id] = skill_type
	var sb: StyleBoxFlat = _slot_left_sb if player_id == 1 else _slot_right_sb
	var label: Label = _skill_left_label if player_id == 1 else _skill_right_label
	_spin_carousel(sb, label, skill_type, player_id)


func use_skill(player_id: int) -> void:
	if not _match_active:
		return
	var skill: int = _skills.get(player_id, -1)
	if skill < 0:
		return
	var player: CharacterBody3D = _player_1 if player_id == 1 else _player_2
	var sdata: Dictionary = _skill_registry.get(skill, {})
	if player != null and player.has_method("apply_powerup") and not sdata.is_empty():
		player.apply_powerup(sdata["key"], sdata["duration"], sdata["magnitude"])
		_show_cast_banner(player_id, skill, sdata)
		_flash_slot(_skill_left_panel if player_id == 1 else _skill_right_panel)
	_skills[player_id] = -1
	_update_skill_slots()


func _show_cast_banner(player_id: int, skill: int, sdata: Dictionary) -> void:
	var banner := _CAST_BANNER.instantiate()
	$HUD.add_child(banner)
	# Player 1 = sisi kiri, Player 2 = sisi kanan (koordinat base 1920x1080)
	banner.position = Vector2(480.0 if player_id == 1 else 1440.0, 360.0)
	if banner.has_method("setup"):
		banner.setup(SKILL_EMOJI.get(skill, "✨"), sdata.get("name", "SKILL"), sdata.get("color", Color(1, 1, 1, 1)))


func _flash_slot(panel: Control) -> void:
	if panel == null:
		return
	panel.pivot_offset = panel.size / 2.0
	var tw := create_tween()
	tw.tween_property(panel, "scale", Vector2(1.3, 1.3), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_SINE)


func on_player_down(player_id: int) -> void:
	if not _match_active:
		return
	if not _scores.has(player_id):
		return

	const FALL_PENALTY := 2
	if _scores[player_id] > 0:
		var actual_penalty := mini(FALL_PENALTY, _scores[player_id])
		_scores[player_id] -= actual_penalty
		_update_score_labels()
		_show_score_change(player_id, -actual_penalty)
	_skills[player_id] = -1
	_update_skill_slots()


func _show_score_change(player_id: int, delta: int) -> void:
	var left_id := _get_left_side_player_id()
	var cx: float = 170.0 if player_id == left_id else 1750.0

	var lbl := Label.new()
	lbl.text = "%+d" % delta
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color",
		Color(1.0, 0.22, 0.12, 1.0) if delta < 0 else Color(0.2, 1.0, 0.35, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 7)
	if _score_font:
		lbl.add_theme_font_override("font", _score_font)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.offset_left  = cx - 55.0
	lbl.offset_right = cx + 55.0
	lbl.offset_top    = 48.0
	lbl.offset_bottom = 102.0

	$HUD.add_child(lbl)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(lbl, "offset_top",    -20.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "offset_bottom",  34.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a",      0.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)


func _finish_match() -> void:
	if not _match_active:
		return

	_match_active = false
	_match_time_left = 0.0
	_update_timer_label()

	if sudden_death_enabled and int(_scores[1]) == int(_scores[2]):
		_start_sudden_death()
		return

	_stop_match_nodes()
	_show_result()


func _start_sudden_death() -> void:
	_sudden_death_active = true
	_sd_time_left = sudden_death_duration
	_match_active = true

	_result_label.visible = false

	# Simpan nilai original spawner
	if _spawner_1:
		_sd_star_interval_orig = _spawner_1.get("star_spawn_interval") if _spawner_1.get("star_spawn_interval") else 5.5
		_sd_star_chance_orig = _spawner_1.get("star_spawn_chance") if _spawner_1.get("star_spawn_chance") else 0.7
		_sd_skill_interval_orig = _spawner_1.get("skill_spawn_interval") if _spawner_1.get("skill_spawn_interval") else 14.0
		_sd_skill_chance_orig = _spawner_1.get("skill_spawn_chance") if _spawner_1.get("skill_spawn_chance") else 0.55

	# Terapkan setting SD ke kedua spawner
	for spawner in [_spawner_1, _spawner_2]:
		if spawner == null:
			continue
		spawner.set("star_spawn_interval", sd_star_interval)
		spawner.set("star_spawn_chance", sd_star_chance)
		spawner.set("skill_spawn_interval", sd_skill_interval)
		spawner.set("skill_spawn_chance", sd_skill_chance)
		if spawner.has_method("set_match_active"):
			spawner.set_match_active(true)

	# Conveyor + obstacle lebih cepat saat SD
	for node in get_tree().get_nodes_in_group("conveyor"):
		if node.has_method("set_speed_multiplier"):
			node.set_speed_multiplier(sd_conveyor_multiplier)
	for spawner in [_spawner_1, _spawner_2]:
		if spawner and spawner.has_method("set_speed_multiplier"):
			spawner.set_speed_multiplier(sd_conveyor_multiplier)

	_show_sd_effects()


func _show_sd_effects() -> void:
	var font = load("res://assets/fonts/Wonder_Boys.ttf")

	_sd_canvas = CanvasLayer.new()
	_sd_canvas.layer = 20
	add_child(_sd_canvas)

	# Vignette merah gradient ke transparan dengan shader
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float edge = max(abs(uv.x), abs(uv.y));
	float alpha = smoothstep(0.72, 1.05, edge) * intensity;
	COLOR = vec4(1.0, 0.0, 0.0, alpha);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("intensity", 0.0)
	vignette.material = mat
	_sd_canvas.add_child(vignette)

	# Breathing: tween shader parameter intensity
	_sd_camera_tween = create_tween().set_loops()
	_sd_camera_tween.tween_method(
		func(v: float): mat.set_shader_parameter("intensity", v),
		0.0, 0.55, 0.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_sd_camera_tween.tween_method(
		func(v: float): mat.set_shader_parameter("intensity", v),
		0.55, 0.0, 0.8
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Teks SUDDEN DEATH besar (muncul sekali lalu fade)
	var lbl := Label.new()
	lbl.text = "SUDDEN DEATH!"
	lbl.set_anchors_preset(Control.PRESET_CENTER)
	lbl.grow_horizontal = Control.GROW_DIRECTION_BOTH
	lbl.grow_vertical = Control.GROW_DIRECTION_BOTH
	lbl.offset_left = -700.0
	lbl.offset_right = 700.0
	lbl.offset_top = -100.0
	lbl.offset_bottom = 100.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 110)
	lbl.add_theme_color_override("font_color", Color(1, 0.08, 0.08, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 22)
	lbl.scale = Vector2(0.05, 0.05)
	lbl.pivot_offset = Vector2(700, 100)
	_sd_canvas.add_child(lbl)

	var tween := create_tween()
	tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.0)
	# Fade out sambil muter
	tween.set_parallel(true)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(lbl, "rotation_degrees", 360.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(lbl, "scale", Vector2(0.3, 0.3), 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(lbl.queue_free)


func _end_sudden_death() -> void:
	_sudden_death_active = false
	_match_active = false
	_result_label.visible = false

	# Hapus efek SD
	if _sd_canvas and is_instance_valid(_sd_canvas):
		_sd_canvas.queue_free()
		_sd_canvas = null
	if _sd_camera_tween:
		_sd_camera_tween.kill()
		_sd_camera_tween = null

	# Reset spawner ke nilai original
	for spawner in [_spawner_1, _spawner_2]:
		if spawner == null:
			continue
		spawner.set("star_spawn_interval", _sd_star_interval_orig)
		spawner.set("star_spawn_chance", _sd_star_chance_orig)
		spawner.set("skill_spawn_interval", _sd_skill_interval_orig)
		spawner.set("skill_spawn_chance", _sd_skill_chance_orig)

	# Reset conveyor + obstacle speed
	for node in get_tree().get_nodes_in_group("conveyor"):
		if node.has_method("set_speed_multiplier"):
			node.set_speed_multiplier(1.0)
	for spawner in [_spawner_1, _spawner_2]:
		if spawner and spawner.has_method("set_speed_multiplier"):
			spawner.set_speed_multiplier(1.0)

	_stop_match_nodes()
	_show_result()


func _stop_match_nodes() -> void:
	for player in [_player_1, _player_2]:
		if player and player.has_method("set_match_active"):
			player.set_match_active(false)

	for spawner in [_spawner_1, _spawner_2]:
		if spawner and spawner.has_method("set_match_active"):
			spawner.set_match_active(false)


func _show_result() -> void:
	var score_1: int = int(_scores[1])
	var score_2: int = int(_scores[2])
	GlobalSettings.last_scores = {1: score_1, 2: score_2}
	if score_1 > score_2:
		GlobalSettings.last_winner_id = 1
	elif score_2 > score_1:
		GlobalSettings.last_winner_id = 2
	else:
		GlobalSettings.last_winner_id = 0

	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/menu/end_screen.tscn")


func _update_skill_slots() -> void:
	_refresh_slot(_slot_left_sb, _skill_left_label, _skills.get(1, -1))
	_refresh_slot(_slot_right_sb, _skill_right_label, _skills.get(2, -1))


func _refresh_slot(sb: StyleBoxFlat, label: Label, skill: int) -> void:
	if sb == null or label == null:
		return
	if skill < 0:
		sb.bg_color = Color(0.04, 0.1, 0.16, 0.95)
		label.text = ""
	else:
		var sdata: Dictionary = _skill_registry.get(skill, {})
		sb.bg_color = sdata.get("color", Color(0.5, 0.5, 0.5, 0.75))
		label.text = SKILL_EMOJI.get(skill, "?")


func _spin_carousel(sb: StyleBoxFlat, label: Label, final_skill: int, player_id: int) -> void:
	if sb == null or label == null:
		return
	_carousel_active[player_id] = true

	const SPIN_STEPS: int = 14
	var skill_ids: Array = _skill_registry.keys()
	if skill_ids.is_empty():
		_carousel_active[player_id] = false
		return
	var current_pos: int = randi() % skill_ids.size()

	for i in range(SPIN_STEPS):
		if _skills.get(player_id, -1) < 0:
			_carousel_active[player_id] = false
			return
		var t: float = float(i) / float(SPIN_STEPS - 1)
		var interval: float = lerpf(0.05, 0.22, t * t)
		var spin_id: int = skill_ids[current_pos]
		var sdata: Dictionary = _skill_registry[spin_id]
		sb.bg_color = sdata.get("color", Color(0.5, 0.5, 0.5, 0.75))
		label.text = SKILL_EMOJI.get(spin_id, "?")
		current_pos = (current_pos + 1) % skill_ids.size()
		await get_tree().create_timer(interval).timeout

	if _skills.get(player_id, -1) < 0:
		_carousel_active[player_id] = false
		return
	var final_data: Dictionary = _skill_registry.get(final_skill, {})
	sb.bg_color = final_data.get("color", Color(0.5, 0.5, 0.5, 0.75))
	label.text = SKILL_EMOJI.get(final_skill, "?")
	_carousel_active[player_id] = false


func _update_hud() -> void:
	_update_timer_label()
	_update_score_labels()


func _update_match_progress() -> void:
	var elapsed: float = MATCH_DURATION - _match_time_left
	var progress: float = clamp(elapsed / MATCH_DURATION, 0.0, 1.0)
	for spawner in [_spawner_1, _spawner_2]:
		if spawner and spawner.has_method("set_match_progress"):
			spawner.set_match_progress(progress)
	var conv_mult: float = lerpf(conveyor_start_multiplier, conveyor_end_multiplier, progress)
	for node in get_tree().get_nodes_in_group("conveyor"):
		if node.has_method("set_speed_multiplier"):
			node.set_speed_multiplier(conv_mult)
	for spawner in [_spawner_1, _spawner_2]:
		if spawner and spawner.has_method("set_speed_multiplier"):
			spawner.set_speed_multiplier(conv_mult)


func _update_timer_label() -> void:
	if _sudden_death_active:
		var secs: int = int(ceil(_sd_time_left))
		_timer_label.text = "⚡ SD %02d:%02d" % [secs / 60, secs % 60]
		_timer_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2, 1))
	else:
		var total_seconds: int = int(ceil(_match_time_left))
		var minutes: int = total_seconds / 60
		var seconds: int = total_seconds % 60
		_timer_label.text = "Time %02d:%02d" % [minutes, seconds]
		_timer_label.remove_theme_color_override("font_color")


func _update_score_labels() -> void:
	var left_player_id: int = _get_left_side_player_id()
	var right_player_id: int = 2 if left_player_id == 1 else 1
	_score_left_label.text = "%d" % int(_scores[left_player_id])
	_score_right_label.text = "%d" % int(_scores[right_player_id])
	_reposition_score_groups()


func _reposition_score_groups() -> void:
	if _score_font == null:
		return
	# Left card: spans x 20-320, center = 170. Layout: [⭐ score]
	var sw_l: float = _score_font.get_string_size(
		_score_left_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36
	).x
	var total_l: float = _STAR_W + _SCORE_GAP + sw_l
	var gx_l: float = 170.0 - total_l * 0.5
	_star_left_label.offset_left = gx_l
	_star_left_label.offset_right = gx_l + _STAR_W
	_score_left_label.offset_left = gx_l + _STAR_W + _SCORE_GAP
	_score_left_label.offset_right = 312.0

	# Right card: spans -320 to -20, center = -170. Layout: [score ⭐]
	var sw_r: float = _score_font.get_string_size(
		_score_right_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 36
	).x
	var total_r: float = _STAR_W + _SCORE_GAP + sw_r
	var star_r: float = -170.0 + total_r * 0.5
	_star_right_label.offset_right = star_r
	_star_right_label.offset_left = star_r - _STAR_W
	_score_right_label.offset_right = _star_right_label.offset_left - _SCORE_GAP
	_score_right_label.offset_left = -312.0


func _get_left_side_player_id() -> int:
	if _player_1 == null:
		return 2
	if _player_2 == null:
		return 1
	return 1 if _player_1.global_position.x <= _player_2.global_position.x else 2


func _debug_handle_keys() -> void:
	pass


func _input(event: InputEvent) -> void:
	# DEBUG: Shift+1~7 → trigger skill id 0~6 di P1 (VFX preview). Hanya aktif di debug build.
	if not OS.is_debug_build():
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not event.shift_pressed:
		return
	const KEY_MAP := {
		KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3,
		KEY_5: 4, KEY_6: 5, KEY_7: 6,
	}
	var skill_id: int = KEY_MAP.get(event.physical_keycode, -1)
	if skill_id < 0:
		return
	var sdata: Dictionary = _skill_registry.get(skill_id, {})
	if sdata.is_empty():
		return
	if _player_1 and _player_1.has_method("apply_powerup"):
		_player_1.apply_powerup(sdata["key"], sdata["duration"], sdata["magnitude"])
		_show_cast_banner(1, skill_id, sdata)
		_flash_slot(_skill_left_panel)


func _debug_spawn_skill_items() -> void:
	for player in [_player_1, _player_2]:
		if not is_instance_valid(player):
			continue
		var item := _DEBUG_SKILL_SCENE.instantiate() as Node3D
		add_child(item)
		item.global_position = player.global_position + Vector3(0.0, 1.2, 0.0)
		if item.has_method("set_movement"):
			item.set_movement(Vector3.ZERO, 0.0)


func _setup_dash_bars() -> void:
	var hud: CanvasLayer = $HUD
	var font = load("res://assets/fonts/Wonder_Boys.ttf")

	var bg_left := StyleBoxFlat.new()
	bg_left.bg_color = Color(0.0, 0.22, 0.45, 0.92)
	for c in range(4): bg_left.set_corner_radius(c, 14)

	var bg_right := StyleBoxFlat.new()
	bg_right.bg_color = Color(0.45, 0.18, 0.0, 0.92)
	for c in range(4): bg_right.set_corner_radius(c, 14)

	_dash_bar_left = _make_dash_bar(
		hud, false,
		20.0, 108.0, 320.0, 142.0,
		Color(0.25, 0.95, 0.78, 1.0), bg_left, font
	)
	_dash_bar_right = _make_dash_bar(
		hud, true,
		-320.0, 108.0, -20.0, 142.0,
		Color(1.0, 0.72, 0.15, 1.0), bg_right, font
	)


func _make_dash_bar(hud: CanvasLayer, anchor_to_right: bool,
		ol: float, ot: float, or_: float, ob: float,
		color: Color, bg: StyleBoxFlat, font: Font = null) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = 1.0
	bar.show_percentage = false
	if anchor_to_right:
		bar.anchor_left = 1.0
		bar.anchor_right = 1.0
		bar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bar.offset_left = ol
	bar.offset_top = ot
	bar.offset_right = or_
	bar.offset_bottom = ob

	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	for c in range(4):
		fill.set_corner_radius(c, 11)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg.duplicate())

	var lbl := Label.new()
	lbl.text = "DASH"
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.08, 0.18, 1))
	lbl.add_theme_constant_override("outline_size", 5)
	if font:
		lbl.add_theme_font_override("font", font)
	bar.add_child(lbl)

	hud.add_child(bar)
	return bar


func _update_dash_bars() -> void:
	var left_id := _get_left_side_player_id()
	var left_p: CharacterBody3D = _player_1 if left_id == 1 else _player_2
	var right_p: CharacterBody3D = _player_2 if left_id == 1 else _player_1
	if _dash_bar_left and is_instance_valid(left_p) and left_p.has_method("get_dash_cooldown_ratio"):
		var ratio: float = left_p.get_dash_cooldown_ratio()
		_dash_bar_left.value = ratio
		# Dim fill color while charging; bright when ready
		var fill := _dash_bar_left.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			fill.bg_color.a = lerpf(0.45, 1.0, ratio)
	if _dash_bar_right and is_instance_valid(right_p) and right_p.has_method("get_dash_cooldown_ratio"):
		var ratio: float = right_p.get_dash_cooldown_ratio()
		_dash_bar_right.value = ratio
		var fill := _dash_bar_right.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			fill.bg_color.a = lerpf(0.45, 1.0, ratio)
