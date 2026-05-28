extends Node3D

const MATCH_DURATION: float = 180.0

@onready var _skill_registry: Dictionary = GlobalSettings.skills

var _match_time_left: float = MATCH_DURATION
var _match_active: bool = true
var _scores := {1: 0, 2: 0}
var _skills := {1: -1, 2: -1}
var _carousel_active := {1: false, 2: false}
var _dash_bar_left: ProgressBar = null
var _dash_bar_right: ProgressBar = null

@onready var _player_1: CharacterBody3D = $Player
@onready var _player_2: CharacterBody3D = $Player2
@onready var _spawner_1: Node = $Spawner_Ground1
@onready var _spawner_2: Node = $Spawner_Ground2
@onready var _timer_label: Label = $HUD/TimerLabel
@onready var _score_left_label: Label = $HUD/ScoreLeftLabel
@onready var _score_right_label: Label = $HUD/ScoreRightLabel
@onready var _speed_left_label: Label = $HUD/SpeedLeftLabel
@onready var _speed_right_label: Label = $HUD/SpeedRightLabel
@onready var _result_label: Label = $HUD/ResultLabel
@onready var _skill_left_color: ColorRect = $HUD/LeftSkillSlotA/SkillColor
@onready var _skill_left_label: Label = $HUD/LeftSkillSlotA/SkillLabel
@onready var _skill_right_color: ColorRect = $HUD/RightSkillSlotA/SkillColor
@onready var _skill_right_label: Label = $HUD/RightSkillSlotA/SkillLabel


func _ready() -> void:
	add_to_group("match_controller")
	_setup_dash_bars()
	_update_hud()
	_update_skill_slots()


func _process(delta: float) -> void:
	if not _match_active:
		return

	_match_time_left = max(0.0, _match_time_left - delta)
	_update_match_progress()
	_update_timer_label()
	_update_speed_labels()
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
	var color_rect: ColorRect = _skill_left_color if player_id == 2 else _skill_right_color
	var label: Label = _skill_left_label if player_id == 2 else _skill_right_label
	_spin_carousel(color_rect, label, skill_type, player_id)


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
	_skills[player_id] = -1
	_update_skill_slots()


func on_player_down(player_id: int) -> void:
	if not _match_active:
		return
	if not _scores.has(player_id):
		return

	_scores[player_id] = 0
	_update_score_labels()
	_skills[player_id] = -1
	_update_skill_slots()


func _finish_match() -> void:
	if not _match_active:
		return

	_match_active = false
	_match_time_left = 0.0
	_update_timer_label()
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
	if score_1 > score_2:
		_result_label.text = "Waktu habis - Player 1 menang!"
	elif score_2 > score_1:
		_result_label.text = "Waktu habis - Player 2 menang!"
	else:
		_result_label.text = "Waktu habis - Seri!"
	_result_label.visible = true


func _update_skill_slots() -> void:
	_refresh_slot(_skill_left_color, _skill_left_label, _skills.get(2, -1))
	_refresh_slot(_skill_right_color, _skill_right_label, _skills.get(1, -1))


func _refresh_slot(color_rect: ColorRect, label: Label, skill: int) -> void:
	if color_rect == null or label == null:
		return
	if skill < 0:
		color_rect.color = Color(0, 0, 0, 0)
		label.text = ""
	else:
		var sdata: Dictionary = _skill_registry.get(skill, {})
		color_rect.color = sdata.get("color", Color(0.5, 0.5, 0.5, 0.75))
		label.text = sdata.get("name", "???")


func _spin_carousel(color_rect: ColorRect, label: Label, final_skill: int, player_id: int) -> void:
	if color_rect == null or label == null:
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
		var sdata: Dictionary = _skill_registry[skill_ids[current_pos]]
		color_rect.color = sdata.get("color", Color(0.5, 0.5, 0.5, 0.75))
		label.text = sdata.get("name", "???")
		current_pos = (current_pos + 1) % skill_ids.size()
		await get_tree().create_timer(interval).timeout

	if _skills.get(player_id, -1) < 0:
		_carousel_active[player_id] = false
		return
	var final_data: Dictionary = _skill_registry.get(final_skill, {})
	color_rect.color = final_data.get("color", Color(0.5, 0.5, 0.5, 0.75))
	label.text = final_data.get("name", "???")
	_carousel_active[player_id] = false


func _update_hud() -> void:
	_update_timer_label()
	_update_score_labels()
	_update_speed_labels()


func _update_match_progress() -> void:
	var elapsed: float = MATCH_DURATION - _match_time_left
	var progress: float = clamp(elapsed / MATCH_DURATION, 0.0, 1.0)
	for spawner in [_spawner_1, _spawner_2]:
		if spawner and spawner.has_method("set_match_progress"):
			spawner.set_match_progress(progress)


func _update_timer_label() -> void:
	var total_seconds: int = int(ceil(_match_time_left))
	var minutes: int = total_seconds / 60
	var seconds: int = total_seconds % 60
	_timer_label.text = "Time %02d:%02d" % [minutes, seconds]


func _update_score_labels() -> void:
	var left_player_id: int = _get_left_side_player_id()
	var right_player_id: int = 2 if left_player_id == 1 else 1
	_score_left_label.text = "P%d Star %d" % [left_player_id, int(_scores[left_player_id])]
	_score_right_label.text = "P%d Star %d" % [right_player_id, int(_scores[right_player_id])]


func _update_speed_labels() -> void:
	var left_player_id: int = _get_left_side_player_id()
	var right_player_id: int = 2 if left_player_id == 1 else 1
	var left_player: CharacterBody3D = _player_1 if left_player_id == 1 else _player_2
	var right_player: CharacterBody3D = _player_2 if left_player_id == 1 else _player_1
	if left_player != null:
		var left_speed: float = Vector2(left_player.velocity.x, left_player.velocity.z).length()
		_speed_left_label.text = "P%d Speed %.2f" % [left_player_id, left_speed]
	if right_player != null:
		var right_speed: float = Vector2(right_player.velocity.x, right_player.velocity.z).length()
		_speed_right_label.text = "P%d Speed %.2f" % [right_player_id, right_speed]


func _get_left_side_player_id() -> int:
	if _player_1 == null:
		return 2
	if _player_2 == null:
		return 1
	return 1 if _player_1.global_position.x <= _player_2.global_position.x else 2


func _setup_dash_bars() -> void:
	var hud: CanvasLayer = $HUD

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.08, 0.13, 0.88)
	for c in range(4):
		bg.set_corner_radius(c, 5)

	# Left card: x 30–330, extended bottom at y=148 → bar sits at y 110–142
	_dash_bar_left = _make_dash_bar(
		hud, false,
		38.0, 110.0, 322.0, 142.0,
		Color(0.25, 0.95, 0.78, 1.0), bg
	)
	# Right card: anchored to right edge, mirror of left
	_dash_bar_right = _make_dash_bar(
		hud, true,
		-322.0, 110.0, -38.0, 142.0,
		Color(1.0, 0.48, 0.5, 1.0), bg
	)


func _make_dash_bar(hud: CanvasLayer, anchor_to_right: bool,
		ol: float, ot: float, or_: float, ob: float,
		color: Color, bg: StyleBoxFlat) -> ProgressBar:
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
		fill.set_corner_radius(c, 5)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg.duplicate())

	# "DASH" label overlaid on the bar
	var lbl := Label.new()
	lbl.text = "DASH"
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
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
