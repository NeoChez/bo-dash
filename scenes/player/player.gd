extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


# Deklarasikan SPEED sebagai konstanta di sini
const SPEED: float = 200.0 

var _last_anim = "front_idle"
var dash : float
var tween: Tween
var dash_velocity = 0
const dashLength = .1
var can_dash = true
var is_talisman = false

@export var max_health: int = 10
var current_health: int = max_health

var invincible: bool = false
@export var invincible_time: float = 0.6
var invincible_timer: float = 0.0

signal health_changed(current: int, max: int)
signal died

var flash_toggle: bool = false

func _physics_process(delta: float) -> void:
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	input_dir = input_dir.round().normalized()

	velocity = input_dir * (SPEED + dash_velocity)
	move_and_slide()
