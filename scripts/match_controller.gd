extends Node3D

const MATCH_DURATION: float = 180.0

const _SKILL_NAMES: Array[String] = ["SPEED\nBOOST", "SLOW\nENEMY", "PULL\nENEMY"]
const _SKILL_COLORS: Array[Color] = [
	Color(0.2, 0.9, 0.4, 0.75),
	Color(1.0, 0.45, 0.2, 0.75),
	Color(0.2, 0.6, 1.0, 0.75),
]
const _SKILL_KEYS: Array[String] = ["speed_boost", "slow_opponent", "yank_opponent"]
const _SKILL_MAGNITUDES: Array[float] = [1.5, 0.5, 18.0]
const _SKILL_DURATION: float = 4.0

var _match_time_left: float = MATCH_DURATION
var _match_active: bool = true
var _scores := {1: 0, 2: 0}
var _skills := {1: -1, 2: -1}

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
	_update_hud()
	_update_skill_slots()


func _process(delta: float) -> void:
	if not _match_active:
		return

	_match_time_left = max(0.0, _match_time_left - delta)
	_update_match_progress()
	_update_timer_label()
	_update_speed_labels()
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
	_update_skill_slots()


func use_skill(player_id: int) -> void:
	if not _match_active:
		return
	var skill: int = _skills.get(player_id, -1)
	if skill < 0:
		return
	var player: CharacterBody3D = _player_1 if player_id == 1 else _player_2
	if player != null and player.has_method("apply_powerup"):
		player.apply_powerup(_SKILL_KEYS[skill], _SKILL_DURATION, _SKILL_MAGNITUDES[skill])
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
		color_rect.color = _SKILL_COLORS[skill]
		label.text = _SKILL_NAMES[skill]


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
