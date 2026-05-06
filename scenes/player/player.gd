extends CharacterBody2D

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D


# Deklarasikan SPEED sebagai konstanta di sini
const SPEED: float = 150.0 

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
	var input = Vector2.ZERO
	input.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")

	# 1. Normalisasi input awal agar pergerakan diagonal tidak lebih cepat
	if input.length() > 0:
		input = input.normalized()

	# 2. Ubah input menjadi pergerakan serong isometrik (Rasio X dan Y = 2:1)
	var iso_direction = Vector2(
		input.x - input.y,
		(input.x + input.y) * 0.5
	)



	# 3. Terapkan kecepatan dan gerakkan karakter
	velocity = iso_direction * (SPEED + dash_velocity)
	move_and_slide()
