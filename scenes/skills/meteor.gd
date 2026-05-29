extends Node3D

const FALL_DELAY: float = 0.6
const AOE_RADIUS: float = 7.0
const _IMPACT_VFX := preload("res://scenes/skills/vfx/meteor_impact_vfx.tscn")
const _IMPACT_SFX := preload("res://assets/audio/sfx/meteor.mp3")
const _SCREAM_SFX := preload("res://assets/audio/sfx/scream.mp3")

@onready var _aoe: Node3D = $AOE

var _target_pos: Vector3
var _impact_strength: float = 30.0
var _travel_dir: Vector3
var _travel_speed: float
var _falling: bool = false
var _bank_side: float = 1.0
var _flight_time: float = 0.0


func setup(target_position: Vector3, strength: float) -> void:
	_target_pos = target_position
	_impact_strength = strength
	# Spawn dari sisi yang sama dengan target player, di luar layar
	var side := 1.0 if target_position.x >= 0.0 else -1.0
	var offset := Vector3(side * randf_range(55.0, 70.0), 18.0, randf_range(-4.0, 4.0))
	global_position = _target_pos + offset
	_travel_dir = (_target_pos - global_position).normalized()
	_travel_speed = global_position.distance_to(_target_pos) / FALL_DELAY
	# Flip horizontal saat spawn dari kiri
	if side < 0.0:
		scale.x = -1.0
	_setup_aoe()
	_falling = true


func _setup_aoe() -> void:
	if not _aoe:
		return
	_aoe.global_position = Vector3(_target_pos.x, _target_pos.y + 0.06, _target_pos.z)
	var tween := create_tween().set_loops()
	tween.tween_property(_aoe, "scale", Vector3(1.1, 1.0, 1.1), 0.38)
	tween.tween_property(_aoe, "scale", Vector3(0.9, 1.0, 0.9), 0.38)


func _process(delta: float) -> void:
	if not _falling:
		return
	global_position += _travel_dir * _travel_speed * delta
	if (_target_pos - global_position).dot(_travel_dir) <= 0.0:
		global_position = _target_pos
		_on_impact()


func _on_impact() -> void:
	_falling = false
	set_process(false)
	if _aoe:
		_aoe.visible = false
	var vfx := _IMPACT_VFX.instantiate()
	vfx.position = _target_pos
	get_tree().current_scene.add_child(vfx)
	# Putar SFX benturan meteor ke tanah
	var sfx := AudioStreamPlayer.new()
	sfx.stream = _IMPACT_SFX
	sfx.volume_db = -5.0
	sfx.bus = "Master"
	get_tree().current_scene.add_child(sfx)
	sfx.play()
	sfx.finished.connect(sfx.queue_free)
	# Putar SFX teriakan bersamaan dengan impact
	var scream := AudioStreamPlayer.new()
	scream.stream = _SCREAM_SFX
	scream.volume_db = -5.0
	scream.bus = "Master"
	get_tree().current_scene.add_child(scream)
	scream.play()
	scream.finished.connect(scream.queue_free)
	for player in get_tree().get_nodes_in_group("player"):
		var dist := Vector2(
			player.global_position.x - _target_pos.x,
			player.global_position.z - _target_pos.z
		).length()
		if dist <= AOE_RADIUS and player.has_method("_apply_meteor_from"):
			var falloff := maxf(1.0 - dist / AOE_RADIUS, 0.4)
			player._apply_meteor_from(_target_pos, _impact_strength * falloff)
	queue_free()
