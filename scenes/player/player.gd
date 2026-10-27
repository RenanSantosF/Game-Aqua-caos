class_name Player
extends CharacterBody3D
## Personagem jogável em 3D: corrida, pulo, mergulho, escorregões, tombos e
## quedas na água. A câmera fica atrás; "frente" é -Z.
## Os obstáculos chamam knockback(), launch(), enter_water() e collect_coin().

signal fell_in_water
signal respawned
signal coin_collected(total: int)

enum State { NORMAL, DIVING, KNOCKED, GETTING_UP, IN_WATER, FROZEN, FINISHED }

@export_group("Corrida")
@export var run_speed := 7.5
@export var ground_accel := 45.0
@export var ground_friction := 55.0
@export var air_accel := 22.0
@export var turn_speed := 14.0

@export_group("Pulo")
@export var jump_velocity := 9.5
## Multiplica a subida quando o botão é solto cedo (pulo curto).
@export var jump_cut := 0.5
@export var fall_gravity_scale := 1.5
@export var max_fall_speed := 30.0
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.15

@export_group("Mergulho")
@export var dive_speed := 11.0
@export var dive_up := 4.5
@export var belly_slide_time := 0.45

@export_group("Superfícies molhadas")
@export var slippery_accel := 9.0
@export var slippery_friction := 2.5
@export var slope_slide_accel := 20.0
@export var max_slide_speed := 15.0

@export_group("Quedas")
@export var knock_time := 0.7
@export var get_up_time := 0.45
@export var water_level := -1.1
@export var water_respawn_delay := 1.2
@export var invulnerable_time := 1.3

const SPLASH := preload("res://scripts/world/splash.gd")

var state := State.NORMAL
var respawn_point := Vector3.ZERO
var facing_angle := 0.0
var coins := 0
var invulnerable := false
## false nos rivais controlados pelo computador.
var is_human := true
## "Cérebro" do rival (null = controlado pelo jogador).
var brain: BotBrain = null

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _coyote := 0.0
var _jump_buffer := 0.0
var _jumping := false
var _can_dive := true
var _sliding := false
var _state_timer := 0.0
var _invulnerable_timer := 0.0
var _was_on_floor := true
var _fall_speed := 0.0

@onready var model: CharacterModel = $Model
@onready var _shadow: MeshInstance3D = $BlobShadow
@onready var _shadow_ray: RayCast3D = $ShadowRay


func _ready() -> void:
	add_to_group("player")
	respawn_point = global_position
	_shadow.top_level = true


func _physics_process(delta: float) -> void:
	if brain != null:
		brain.think(self, delta)
	_update_invulnerability(delta)
	_fall_speed = velocity.y

	match state:
		State.NORMAL:
			_process_normal(delta)
		State.DIVING:
			_process_diving(delta)
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
		var strength := clampf(-_fall_speed / 18.0, 0.15, 1.0)
		model.on_landed(strength)
		if strength > 0.4:
			_sfx("land", -6.0)
	_was_on_floor = on_floor

	if state not in [State.IN_WATER, State.FINISHED] and global_position.y < water_level:
		enter_water()

	model.rotation.y = lerp_angle(model.rotation.y, facing_angle, minf(1.0, turn_speed * delta))
	var horizontal := Vector2(velocity.x, velocity.z).length()
	model.animate(_visual_mode(), horizontal / run_speed, delta)
	_update_shadow()


# --- API usada pelos obstáculos e pela fase -------------------------------------

## Empurrão que derruba (martelos, bastões, bolas...).
func knockback(impulse: Vector3) -> void:
	if invulnerable or state in [State.IN_WATER, State.FINISHED, State.FROZEN, State.KNOCKED]:
		return
	state = State.KNOCKED
	_state_timer = knock_time
	velocity = impulse
	_jumping = false
	var flat := Vector2(impulse.x, impulse.z)
	if flat.length() > 0.5:
		facing_angle = atan2(flat.x, flat.y)  # vira de frente para quem bateu
	model.on_knocked()
	_sfx("hit")


## Lançamento sem perder o controle (boias de impulso, jatos).
func launch(up_velocity: float, max_horizontal := 9.0) -> void:
	if state not in [State.NORMAL, State.DIVING, State.GETTING_UP]:
		return
	state = State.NORMAL
	var flat := Vector2(velocity.x, velocity.z).limit_length(max_horizontal)
	velocity = Vector3(flat.x, up_velocity, flat.y)
	_jumping = false
	_can_dive = true
	_coyote = 0.0
	model.on_jump()
	_sfx("bounce")


func enter_water() -> void:
	if state in [State.IN_WATER, State.FINISHED]:
		return
	state = State.IN_WATER
	_state_timer = water_respawn_delay
	velocity *= Vector3(0.2, 0.15, 0.2)
	_jumping = false
	model.on_water()
	_sfx("splash")
	var splash := SPLASH.new()
	get_parent().add_child(splash)
	splash.global_position = Vector3(global_position.x, water_level + 0.2, global_position.z)
	fell_in_water.emit()


func collect_coin() -> void:
	coins += 1
	_sfx("coin", -2.0, 0.02)
	coin_collected.emit(coins)


func respawn() -> void:
	global_position = respawn_point
	velocity = Vector3.ZERO
	facing_angle = 0.0
	model.rotation.y = 0.0
	state = State.NORMAL
	_start_invulnerability(invulnerable_time)
	model.on_respawn()
	respawned.emit()


func set_frozen(frozen: bool) -> void:
	if frozen:
		state = State.FROZEN
	elif state == State.FROZEN:
		state = State.NORMAL


func finish() -> void:
	state = State.FINISHED
	facing_angle = PI  # vira para a câmera para comemorar


# --- Estados -----------------------------------------------------------------------

func _input_direction() -> Vector3:
	if brain != null:
		return brain.move
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back", 0.12)
	return Vector3(input.x, 0.0, input.y)


func _jump_pressed() -> bool:
	return brain.jump_pressed if brain != null else Input.is_action_just_pressed("jump")


func _jump_held() -> bool:
	return brain.jump_held if brain != null else Input.is_action_pressed("jump")


func _dive_pressed() -> bool:
	return brain.dive_pressed if brain != null else Input.is_action_just_pressed("dive")


func _sfx(sound: String, volume_db := 0.0, pitch_variation := 0.06) -> void:
	if is_human:
		Sfx.play(sound, volume_db, pitch_variation)


func _process_normal(delta: float) -> void:
	var direction := _input_direction()
	var on_floor := is_on_floor()
	var slippery := on_floor and _is_floor_slippery()

	if on_floor:
		_coyote = coyote_time
		_jumping = false
		_can_dive = true
	else:
		_coyote -= delta
	if _jump_pressed():
		_jump_buffer = jump_buffer_time
	else:
		_jump_buffer -= delta

	_apply_gravity(delta)

	var accel := air_accel
	var friction := air_accel * 0.4
	if on_floor:
		accel = slippery_accel if slippery else ground_accel
		friction = slippery_friction if slippery else ground_friction

	var flat := Vector2(velocity.x, velocity.z)
	var target := Vector2(direction.x, direction.z) * run_speed
	if direction.length() > 0.05:
		var keep_momentum := flat.length() > (target.length() if slippery else run_speed)
		if not keep_momentum or flat.dot(target) < 0.0:
			flat = flat.move_toward(target, accel * delta)
		else:
			# Acima da velocidade normal (escorregador): só muda a direção.
			flat = flat.move_toward(target.normalized() * flat.length(), accel * delta)
		facing_angle = atan2(-direction.x, -direction.z)
	else:
		flat = flat.move_toward(Vector2.ZERO, friction * delta)

	_sliding = false
	if slippery:
		var normal := get_floor_normal()
		var downhill := Vector2(normal.x, normal.z)
		if downhill.length() > 0.05:
			flat += downhill * slope_slide_accel * delta
			_sliding = true
		flat = flat.limit_length(max_slide_speed)
		_sliding = _sliding or flat.length() > run_speed * 1.1
	elif on_floor and flat.length() > run_speed:
		flat = flat.move_toward(flat.normalized() * run_speed, friction * 0.4 * delta)

	velocity.x = flat.x
	velocity.z = flat.y

	if _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = jump_velocity
		_jump_buffer = 0.0
		_coyote = 0.0
		_jumping = true
		model.on_jump()
		_sfx("jump", -4.0)

	if _jumping and velocity.y > 0.0 and not _jump_held():
		velocity.y *= jump_cut
		_jumping = false

	if _dive_pressed() and _can_dive:
		_start_dive()

	_move_with_belt()


func _start_dive() -> void:
	state = State.DIVING
	_state_timer = 0.0
	_can_dive = false
	var forward := Vector3(-sin(facing_angle), 0.0, -cos(facing_angle))
	var speed := maxf(Vector2(velocity.x, velocity.z).length(), dive_speed)
	var up := dive_up if is_on_floor() else maxf(velocity.y * 0.3, dive_up * 0.7)
	velocity = forward * speed + Vector3.UP * up
	model.on_dive()
	_sfx("dive")


func _process_diving(delta: float) -> void:
	_apply_gravity(delta)
	if is_on_floor():
		_state_timer += delta
		var friction := 3.0 if _is_floor_slippery() else 14.0
		var flat := Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, friction * delta)
		velocity.x = flat.x
		velocity.z = flat.y
		if _state_timer >= belly_slide_time:
			state = State.GETTING_UP
			_state_timer = get_up_time * 0.6
	move_and_slide()


func _process_knocked(delta: float) -> void:
	_state_timer -= delta
	_apply_gravity(delta)
	var friction := ground_friction * 0.35 if is_on_floor() else 2.0
	var flat := Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, friction * delta)
	velocity.x = flat.x
	velocity.z = flat.y
	_move_with_belt()
	if _state_timer <= 0.0 and is_on_floor():
		state = State.GETTING_UP
		_state_timer = get_up_time


func _process_getting_up(delta: float) -> void:
	_state_timer -= delta
	_apply_gravity(delta)
	var flat := Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, ground_friction * delta)
	velocity.x = flat.x
	velocity.z = flat.y
	_move_with_belt()
	if _state_timer <= 0.0:
		state = State.NORMAL
		_start_invulnerability(0.5)


func _process_in_water(delta: float) -> void:
	_state_timer -= delta
	velocity.y = move_toward(velocity.y, -0.8, 20.0 * delta)
	velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
	global_position += velocity * delta  # afunda sem colidir com nada
	if _state_timer <= 0.0:
		respawn()


func _process_idle(delta: float) -> void:
	_apply_gravity(delta)
	var flat := Vector2(velocity.x, velocity.z).move_toward(Vector2.ZERO, ground_friction * delta)
	velocity.x = flat.x
	velocity.z = flat.y
	_move_with_belt()


# --- Auxiliares ----------------------------------------------------------------------

func _apply_gravity(delta: float) -> void:
	if is_on_floor() and velocity.y <= 0.0:
		return
	var gravity_scale := fall_gravity_scale if velocity.y < 0.0 else 1.0
	velocity.y = maxf(velocity.y - _gravity * gravity_scale * delta, -max_fall_speed)


func _is_floor_slippery() -> bool:
	var floor_node := _floor_node()
	return floor_node != null and floor_node.is_in_group("slippery")


## Em que objeto estamos pisando (teste curto para baixo, sem mover).
func _floor_node() -> Node:
	if not is_on_floor():
		return null
	var collision := move_and_collide(Vector3.DOWN * 0.12, true, 0.001, true)
	if collision == null:
		return null
	var collider := collision.get_collider()
	return collider as Node


## Esteiras arrastam quem está em cima.
func _move_with_belt() -> void:
	var floor_node := _floor_node()
	var belt := Vector3.ZERO
	if floor_node is Conveyor:
		belt = (floor_node as Conveyor).belt_velocity()
	velocity += belt
	move_and_slide()
	velocity -= belt


func _start_invulnerability(duration: float) -> void:
	invulnerable = true
	_invulnerable_timer = duration


func _update_invulnerability(delta: float) -> void:
	if not invulnerable:
		return
	_invulnerable_timer -= delta
	model.visible = fmod(_invulnerable_timer, 0.16) > 0.06
	if _invulnerable_timer <= 0.0:
		invulnerable = false
		model.visible = true


## Sombra redonda embaixo do boneco: ajuda muito a acertar os pulos em 3D.
func _update_shadow() -> void:
	if state == State.IN_WATER or not _shadow_ray.is_colliding():
		_shadow.visible = false
		return
	var point := _shadow_ray.get_collision_point()
	var height := global_position.y - point.y
	_shadow.visible = true
	_shadow.global_position = point + Vector3.UP * 0.03
	var size := clampf(1.0 - height * 0.08, 0.35, 1.0)
	_shadow.scale = Vector3(size, 1.0, size)


func _visual_mode() -> String:
	match state:
		State.DIVING:
			return "belly" if is_on_floor() else "dive"
		State.KNOCKED:
			return "down" if is_on_floor() and _state_timer < knock_time * 0.6 else "knocked"
		State.GETTING_UP:
			return "getup"
		State.IN_WATER:
			return "water"
		State.FINISHED:
			return "celebrate"
		State.FROZEN:
			return "idle"
	if not is_on_floor():
		return "jump" if velocity.y > 0.0 else "fall"
	if _sliding:
		return "belly" if Vector2(velocity.x, velocity.z).length() > run_speed * 1.3 else "run"
	if Vector2(velocity.x, velocity.z).length() > 0.5:
		return "run"
	return "idle"
