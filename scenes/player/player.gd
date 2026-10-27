class_name Player
extends CharacterBody2D
## Personagem jogável: corrida, pulo, escorregões, tombos e quedas na água.
##
## A física é propositalmente "cartoon": aceleração rápida, pulo alto e
## queda mais pesada que a subida. Os obstáculos chamam knockback(),
## launch() e enter_water(); o personagem cuida do resto.

signal fell_in_water
signal respawned

enum State { NORMAL, KNOCKED, GETTING_UP, IN_WATER, FROZEN, FINISHED }

@export_group("Corrida")
@export var run_speed := 430.0
@export var ground_accel := 2600.0
@export var ground_friction := 3200.0
@export var air_accel := 1700.0
@export var air_friction := 500.0

@export_group("Pulo")
@export var jump_velocity := -820.0
## Multiplica a velocidade de subida quando o botão é solto cedo (pulo curto).
@export var jump_cut := 0.45
@export var fall_gravity_scale := 1.35
@export var max_fall_speed := 1400.0
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.12

@export_group("Superfícies molhadas")
@export var slippery_accel := 700.0
@export var slippery_friction := 120.0
@export var slope_slide_accel := 1500.0
@export var max_slide_speed := 820.0

@export_group("Quedas")
@export var knock_time := 0.55
@export var get_up_time := 0.35
@export var water_respawn_delay := 1.1
@export var invulnerable_time := 1.2
@export var camera_look_ahead := 140.0

var state := State.NORMAL
var respawn_point := Vector2.ZERO
var facing := 1.0
var invulnerable := false

var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var _coyote := 0.0
var _jump_buffer := 0.0
var _jumping := false
var _sliding := false
var _state_timer := 0.0
var _invulnerable_timer := 0.0
var _was_on_floor := true
var _fall_speed := 0.0

@onready var visual: PlayerVisual = $Visual
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	add_to_group("player")
	respawn_point = global_position


func _physics_process(delta: float) -> void:
	_update_invulnerability(delta)
	_fall_speed = velocity.y

	match state:
		State.NORMAL:
			_process_normal(delta)
		State.KNOCKED:
			_process_knocked(delta)
		State.GETTING_UP:
			_process_getting_up(delta)
		State.IN_WATER:
			_process_in_water(delta)
		State.FROZEN, State.FINISHED:
			_process_idle(delta)

	var on_floor := is_on_floor()
	if on_floor and not _was_on_floor and state != State.IN_WATER:
		visual.on_landed(clampf(_fall_speed / 1200.0, 0.2, 1.0))
	_was_on_floor = on_floor

	camera.offset.x = lerpf(camera.offset.x, facing * camera_look_ahead, 2.5 * delta)
	visual.facing = facing
	visual.animate(_visual_mode(), velocity, delta)


# --- API usada pelos obstáculos e pela fase -------------------------------

## Empurrão que derruba o personagem (martelos, jatos d'água...).
func knockback(impulse: Vector2) -> void:
	if invulnerable or state in [State.IN_WATER, State.FINISHED, State.FROZEN, State.KNOCKED]:
		return
	state = State.KNOCKED
	_state_timer = knock_time
	velocity = impulse
	_jumping = false
	if absf(impulse.x) > 1.0:
		facing = -signf(impulse.x)  # vira de frente para quem bateu
	visual.on_knocked(signf(impulse.x))


## Lançamento sem perder o controle (boias de impulso).
func launch(new_velocity: Vector2, keep_horizontal := true, max_horizontal := 520.0) -> void:
	if state != State.NORMAL:
		return
	if keep_horizontal:
		velocity.x = clampf(velocity.x, -max_horizontal, max_horizontal)
		velocity.y = new_velocity.y
	else:
		velocity = new_velocity
	_jumping = false
	_coyote = 0.0
	visual.on_jump()


func enter_water() -> void:
	if state in [State.IN_WATER, State.FINISHED]:
		return
	state = State.IN_WATER
	_state_timer = water_respawn_delay
	velocity *= Vector2(0.3, 0.2)
	_jumping = false
	visual.on_water()
	fell_in_water.emit()


func respawn() -> void:
	global_position = respawn_point
	velocity = Vector2.ZERO
	state = State.NORMAL
	_start_invulnerability(invulnerable_time)
	visual.on_respawn()
	camera.reset_smoothing()
	respawned.emit()


func set_frozen(frozen: bool) -> void:
	if frozen:
		state = State.FROZEN
	elif state == State.FROZEN:
		state = State.NORMAL


func finish() -> void:
	state = State.FINISHED
	visual.on_celebrate()


# --- Estados ---------------------------------------------------------------

func _process_normal(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()
	var slippery := on_floor and _is_floor_slippery()

	if on_floor:
		_coyote = coyote_time
		_jumping = false
	else:
		_coyote -= delta
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer -= delta

	_apply_gravity(delta)

	var accel := air_accel
	var friction := air_friction
	if on_floor:
		accel = slippery_accel if slippery else ground_accel
		friction = slippery_friction if slippery else ground_friction

	if direction != 0.0:
		# Acima da velocidade normal (ex.: vindo do escorregador) só freia
		# se o jogador apontar para o lado contrário.
		if signf(velocity.x) != direction or absf(velocity.x) < run_speed:
			velocity.x = move_toward(velocity.x, direction * run_speed, accel * delta)
		facing = direction
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)

	_sliding = false
	if slippery:
		var normal := get_floor_normal()
		if absf(normal.x) > 0.05:
			velocity.x += normal.x * slope_slide_accel * delta
			_sliding = true
		velocity.x = clampf(velocity.x, -max_slide_speed, max_slide_speed)
		_sliding = _sliding or absf(velocity.x) > run_speed * 0.9
	elif on_floor and absf(velocity.x) > run_speed:
		velocity.x = move_toward(velocity.x, signf(velocity.x) * run_speed, friction * 0.5 * delta)

	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_jumping = true
		visual.on_jump()

	if _jumping and velocity.y < 0.0 and not Input.is_action_pressed("jump"):
		velocity.y *= jump_cut
		_jumping = false

	move_and_slide()


func _process_knocked(delta: float) -> void:
	_state_timer -= delta
	_apply_gravity(delta)
	var friction := ground_friction * 0.6 if is_on_floor() else 200.0
	velocity.x = move_toward(velocity.x, 0.0, friction * delta)
	move_and_slide()
	if _state_timer <= 0.0 and is_on_floor():
		state = State.GETTING_UP
		_state_timer = get_up_time


func _process_getting_up(delta: float) -> void:
	_state_timer -= delta
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	move_and_slide()
	if _state_timer <= 0.0:
		state = State.NORMAL
		_start_invulnerability(0.6)


func _process_in_water(delta: float) -> void:
	_state_timer -= delta
	velocity.y = move_toward(velocity.y, 70.0, 1200.0 * delta)
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	position += velocity * delta  # afunda sem colidir com nada
	if _state_timer <= 0.0:
		respawn()


func _process_idle(delta: float) -> void:
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	move_and_slide()


# --- Auxiliares ------------------------------------------------------------

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		return
	var gravity_scale := fall_gravity_scale if velocity.y > 0.0 else 1.0
	velocity.y = minf(velocity.y + _gravity * gravity_scale * delta, max_fall_speed)


func _is_floor_slippery() -> bool:
	# Teste curto para baixo (sem mover) para descobrir em que chão estamos.
	var collision := move_and_collide(Vector2(0, 6), true, 0.08, true)
	if collision == null:
		return false
	var collider := collision.get_collider()
	return collider is Node and (collider as Node).is_in_group("slippery")


func _start_invulnerability(duration: float) -> void:
	invulnerable = true
	_invulnerable_timer = duration


func _update_invulnerability(delta: float) -> void:
	if not invulnerable:
		return
	_invulnerable_timer -= delta
	visual.modulate.a = 0.35 if fmod(_invulnerable_timer, 0.16) < 0.08 else 1.0
	if _invulnerable_timer <= 0.0:
		invulnerable = false
		visual.modulate.a = 1.0


func _visual_mode() -> String:
	match state:
		State.KNOCKED:
			return "down" if is_on_floor() else "knocked"
		State.GETTING_UP:
			return "getup"
		State.IN_WATER:
			return "water"
		State.FINISHED:
			return "celebrate"
		State.FROZEN:
			return "idle"
	if not is_on_floor():
		return "jump" if velocity.y < 0.0 else "fall"
	if _sliding:
		return "slide"
	if absf(velocity.x) > 30.0:
		return "run"
	return "idle"
