extends Node

const MALE_RUN  := preload("res://assets/player/male/running.glb")
const MALE_TRIP := preload("res://assets/player/male/trip.glb")
const CONVEYOR  := preload("res://global/conveyor3d_left.tscn")

@onready var camera        : Camera3D  = $Viewport3D/SubViewport/Camera3D
@onready var black_overlay : ColorRect = $UI/BlackOverlay
@onready var logo_label    : Label     = $UI/LogoLabel

var _vp   : SubViewport
var _male : Node3D
var _trip : Node3D

const CHAR_SCALE     := 2.8
const CONVEYOR_SCALE := 0.28

func _ready() -> void:
	black_overlay.color   = Color(0, 0, 0, 0)
	logo_label.modulate.a = 0.0
	_vp = $Viewport3D/SubViewport

	var conv := CONVEYOR.instantiate()
	_vp.add_child(conv)
	conv.rotation_degrees = Vector3(0, 90, 0)
	conv.scale            = Vector3.ONE * CONVEYOR_SCALE
	conv.position         = Vector3(0, 0, -4)

	_male = MALE_RUN.instantiate()
	_vp.add_child(_male)
	_male.scale            = Vector3.ONE * CHAR_SCALE
	_male.rotation_degrees = Vector3(0, 0, 0)
	_male.position         = Vector3(0, 0.3, -14)
	_play_anim(_male)

	_run_sequence()

func _play_anim(node: Node3D) -> void:
	var ap := node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if not ap or ap.get_animation_list().is_empty():
		return
	var anim_name := ap.get_animation_list()[0]
	ap.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	ap.play(anim_name)

func _run_sequence() -> void:
	var run_t := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	run_t.tween_property(_male, "position:z", 7.0, 5.0)

	await get_tree().create_timer(2.2).timeout

	run_t.kill()
	_male.visible = false
	var impact_z  := _male.position.z

	_trip = MALE_TRIP.instantiate()
	_vp.add_child(_trip)
	_trip.scale            = Vector3.ONE * CHAR_SCALE
	_trip.rotation_degrees = Vector3(0, 0, 0)
	_trip.position         = Vector3(0, 0.3, impact_z)
	_play_anim(_trip)

	var roll := create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	roll.tween_property(_trip, "position:z", 5.9, 2.8)

	var cam_t := create_tween().set_ease(Tween.EASE_IN_OUT)
	cam_t.tween_property(camera, "rotation:x", deg_to_rad(-10), 2.8)

	await get_tree().create_timer(2.5).timeout

	var fade := create_tween()
	fade.tween_property(black_overlay, "color:a", 1.0, 0.35)
	await fade.finished

	await get_tree().create_timer(0.25).timeout

	var show := create_tween()
	show.tween_property(logo_label, "modulate:a", 1.0, 0.9)
	await show.finished

	await get_tree().create_timer(2.0).timeout

	var hide := create_tween()
	hide.tween_property(logo_label, "modulate:a", 0.0, 0.7)
	await hide.finished

	await get_tree().create_timer(0.3).timeout
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")
