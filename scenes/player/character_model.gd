class_name CharacterModel
extends Node3D
## Boneco cartoon 3D montado com formas simples (estilo "feijãozinho").
## Animado por código: corrida, pulo, mergulho, tombo, nado e comemoração.
## A frente do boneco aponta para -Z. Os pés ficam na origem.

@export var body_color := Color("ff7043")
@export var belly_color := Color("fff3e0")
@export var cap_color := Color("1e88e5")
@export var shoe_color := Color("ffffff")
@export var eye_color := Color("ffffff")
## Anima sozinho (menu): pula e comemora sem um Player.
@export var demo_mode := false

const BODY_HEIGHT := 0.8

var _body: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _eyes: Array[Node3D] = []
var _pupils: Array[Node3D] = []
var _mouth: MeshInstance3D
var _mode := "idle"
var _time := 0.0
var _phase := 0.0
var _squash := Vector3.ONE
var _tumble := Vector3.ZERO
var _base_rotation := Vector3.ZERO
var _tumble_speed := Vector3.ZERO
var _blink := 0.0
var _next_blink := 2.0


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if demo_mode:
		animate("celebrate", 0.0, delta)


# --- Montagem --------------------------------------------------------------------

func _build() -> void:
	_body = Node3D.new()
	_body.position.y = BODY_HEIGHT
	add_child(_body)

	Build.capsule(_body, 0.42, 1.25, body_color, Vector3(0, 0.05, 0), true)
	var belly := Build.sphere(_body, 0.3, belly_color, Vector3(0, -0.12, -0.24))
	belly.scale = Vector3(1.0, 1.1, 0.55)

	# Olhos e boca
	for side in [-1.0, 1.0]:
		var eye := Node3D.new()
		eye.position = Vector3(0.15 * side, 0.32, -0.33)
		_body.add_child(eye)
		var white := Build.sphere(eye, 0.12, eye_color, Vector3.ZERO, true)
		white.scale = Vector3(1.0, 1.1, 0.7)
		var pupil := Node3D.new()
		pupil.position = Vector3(0, 0, -0.075)
		eye.add_child(pupil)
		Build.sphere(pupil, 0.06, Color("1a2340"))
		Build.sphere(pupil, 0.022, Color.WHITE, Vector3(0.02, 0.025, -0.04))
		_eyes.append(eye)
		_pupils.append(pupil)
	_mouth = Build.sphere(_body, 0.06, Color("7b1f1f"), Vector3(0, 0.1, -0.4))
	_mouth.scale = Vector3(1.8, 0.7, 0.5)

	# Boné
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = 0.44
	cap_mesh.height = 0.44
	cap_mesh.is_hemisphere = true
	cap_mesh.radial_segments = 18
	cap_mesh.rings = 6
	var cap := MeshInstance3D.new()
	cap.mesh = cap_mesh
	cap.material_override = Mat.toon(cap_color, true)
	cap.position = Vector3(0, 0.43, 0)
	_body.add_child(cap)
	var brim := Build.cylinder(_body, 0.3, 0.05, cap_color, Vector3(0, 0.45, -0.33), -1.0, true)
	brim.rotation.x = -0.12
	Build.sphere(_body, 0.07, Color.WHITE, Vector3(0, 0.87, 0))

	# Braços e pernas (cada um num "ombro/quadril" que gira)
	_arm_l = _limb(Vector3(-0.42, 0.02, 0), 0.1, 0.48, body_color, Color.WHITE, 0.12)
	_arm_r = _limb(Vector3(0.42, 0.02, 0), 0.1, 0.48, body_color, Color.WHITE, 0.12)
	_leg_l = _limb(Vector3(-0.18, -0.48, 0), 0.12, 0.36, body_color, shoe_color, 0.13)
	_leg_r = _limb(Vector3(0.18, -0.48, 0), 0.12, 0.36, body_color, shoe_color, 0.13)
	for leg in [_leg_l, _leg_r]:
		var shoe: Node3D = leg.get_child(1)
		shoe.scale = Vector3(1.0, 0.65, 1.45)
		shoe.position.z = -0.05


func _limb(pivot_position: Vector3, radius: float, length: float, color: Color, end_color: Color, end_radius: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = pivot_position
	_body.add_child(pivot)
	Build.capsule(pivot, radius, length, color, Vector3(0, -length * 0.4, 0), true)
	Build.sphere(pivot, end_radius, end_color, Vector3(0, -length * 0.85, 0), true)
	return pivot


func set_colors(colors: Dictionary) -> void:
	body_color = colors.get("body", body_color)
	belly_color = colors.get("belly", belly_color)
	cap_color = colors.get("cap", cap_color)
	shoe_color = colors.get("shoe", shoe_color)
	for child in get_children():
		child.queue_free()
	_eyes.clear()
	_pupils.clear()
	_build()


# --- Eventos -----------------------------------------------------------------------

func on_jump() -> void:
	_squash = Vector3(0.8, 1.3, 0.8)


func on_landed(strength: float) -> void:
	_squash = Vector3(1.0 + 0.35 * strength, 1.0 - 0.35 * strength, 1.0 + 0.35 * strength)


func on_knocked() -> void:
	_tumble_speed = Vector3(randf_range(8.0, 14.0) * (1 if randf() > 0.5 else -1), 0, randf_range(-8.0, 8.0))
	_squash = Vector3(1.3, 0.7, 1.3)


func on_dive() -> void:
	_squash = Vector3(0.85, 1.25, 0.85)


func on_water() -> void:
	_squash = Vector3(0.75, 1.35, 0.75)


func on_respawn() -> void:
	_tumble = Vector3.ZERO
	_squash = Vector3(0.6, 1.5, 0.6)


# --- Animação ----------------------------------------------------------------------

## mode: idle, run, jump, fall, dive, belly, knocked, down, getup, water, celebrate.
## speed_ratio: 0..1+ (velocidade horizontal / velocidade de corrida).
func animate(mode: String, speed_ratio: float, delta: float) -> void:
	if _body == null:
		return
	_mode = mode
	_time += delta
	var t := _time
	var blend := minf(1.0, 14.0 * delta)

	if mode == "run":
		_phase += delta * (6.0 + 8.0 * speed_ratio)
	var s := sin(_phase)

	var body_rot := Vector3.ZERO
	var body_y := BODY_HEIGHT
	var arm_l := Vector3.ZERO
	var arm_r := Vector3.ZERO
	var leg_l := Vector3.ZERO
	var leg_r := Vector3.ZERO

	match mode:
		"idle":
			body_y += sin(t * 3.0) * 0.015
			arm_l = Vector3(0, 0, -0.15 - sin(t * 3.0) * 0.05)
			arm_r = Vector3(0, 0, 0.15 + sin(t * 3.0) * 0.05)
		"run":
			body_y += absf(s) * 0.09
			body_rot = Vector3(-0.18 * speed_ratio, 0, s * 0.08)
			leg_l = Vector3(s * 1.0, 0, 0)
			leg_r = Vector3(-s * 1.0, 0, 0)
			arm_l = Vector3(-s * 0.9, 0, -0.25)
			arm_r = Vector3(s * 0.9, 0, 0.25)
		"jump":
			arm_l = Vector3(0, 0, -2.5)
			arm_r = Vector3(0, 0, 2.5)
			leg_l = Vector3(0.7, 0, 0)
			leg_r = Vector3(-0.3, 0, 0)
		"fall":
			arm_l = Vector3(sin(t * 18.0) * 0.4, 0, -2.0 - sin(t * 20.0) * 0.4)
			arm_r = Vector3(-sin(t * 18.0) * 0.4, 0, 2.0 + cos(t * 20.0) * 0.4)
			leg_l = Vector3(0.4 + sin(t * 16.0) * 0.3, 0, -0.2)
			leg_r = Vector3(-0.2 - sin(t * 16.0) * 0.3, 0, 0.2)
		"dive", "belly":
			body_rot = Vector3(-1.4, 0, 0)
			body_y = 0.45 if mode == "belly" else BODY_HEIGHT
			arm_l = Vector3(-2.9, 0, -0.3)
			arm_r = Vector3(-2.9, 0, 0.3)
			leg_l = Vector3(-0.3 + sin(t * 20.0) * 0.2, 0, 0)
			leg_r = Vector3(-0.3 - sin(t * 20.0) * 0.2, 0, 0)
		"knocked", "down":
			arm_l = Vector3(sin(t * 25.0) * 0.8, 0, -1.6 + cos(t * 22.0) * 0.6)
			arm_r = Vector3(cos(t * 25.0) * 0.8, 0, 1.6 + sin(t * 22.0) * 0.6)
			leg_l = Vector3(sin(t * 20.0) * 0.8, 0, -0.3)
			leg_r = Vector3(-sin(t * 20.0) * 0.8, 0, 0.3)
			if mode == "down":
				body_y = 0.45
		"getup":
			body_rot = Vector3(0.2, 0, 0)
			arm_l = Vector3(0, 0, -0.6)
			arm_r = Vector3(0, 0, 0.6)
		"water":
			body_y += sin(t * 9.0) * 0.08
			arm_l = Vector3(0, 0, -2.6 + sin(t * 16.0) * 0.5)
			arm_r = Vector3(0, 0, 2.6 - sin(t * 16.0) * 0.5)
		"celebrate":
			body_y += absf(sin(t * 7.0)) * 0.35
			arm_l = Vector3(0, 0, -2.6 + sin(t * 14.0) * 0.35)
			arm_r = Vector3(0, 0, 2.6 + sin(t * 14.0) * 0.35)
			leg_l = Vector3(sin(t * 7.0) * 0.3, 0, -0.15)
			leg_r = Vector3(-sin(t * 7.0) * 0.3, 0, 0.15)
			body_rot = Vector3(0, sin(t * 3.5) * 0.3, 0)

	# Tombo: gira o corpo inteiro; ao cair no chão fica deitado de costas.
	if mode == "knocked":
		_tumble += _tumble_speed * delta
		_tumble = Vector3(wrapf(_tumble.x, -PI, PI), wrapf(_tumble.y, -PI, PI), wrapf(_tumble.z, -PI, PI))
	elif mode == "down":
		_tumble = _tumble.lerp(Vector3(1.45, 0, 0), blend)
	else:
		_tumble = _tumble.lerp(Vector3.ZERO, minf(1.0, 10.0 * delta))

	_base_rotation = _base_rotation.lerp(body_rot, blend)
	_body.rotation = _tumble if mode == "knocked" else _base_rotation + _tumble
	_body.position.y = lerpf(_body.position.y, body_y, blend)
	_arm_l.rotation = _arm_l.rotation.lerp(arm_l, blend)
	_arm_r.rotation = _arm_r.rotation.lerp(arm_r, blend)
	_leg_l.rotation = _leg_l.rotation.lerp(leg_l, blend)
	_leg_r.rotation = _leg_r.rotation.lerp(leg_r, blend)

	_squash = _squash.lerp(Vector3.ONE, minf(1.0, 10.0 * delta))
	_body.scale = _squash

	_animate_face(mode, t, delta)


func _animate_face(mode: String, t: float, delta: float) -> void:
	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.12
		_next_blink = randf_range(1.8, 4.0)
	_blink = maxf(0.0, _blink - delta)

	var eye_scale := 1.0
	var mouth_scale := Vector3(1.8, 0.7, 0.5)
	match mode:
		"jump", "fall", "dive", "water":
			mouth_scale = Vector3(1.0, 1.4, 0.6)
			eye_scale = 1.15
		"knocked", "down":
			mouth_scale = Vector3(1.4, 1.0, 0.6)
		"celebrate":
			mouth_scale = Vector3(2.2, 1.2, 0.6)
	if _blink > 0.0:
		eye_scale = 0.1
	for eye in _eyes:
		eye.scale = Vector3(1.0, eye_scale, 1.0)
	for i in _pupils.size():
		var pupil := _pupils[i]
		if mode in ["knocked", "down"]:
			var a := t * 16.0 + i * PI
			pupil.position = Vector3(cos(a) * 0.04, sin(a) * 0.04, -0.075)
		else:
			pupil.position = pupil.position.lerp(Vector3(0, -0.01 if mode == "fall" else 0.0, -0.075), 0.3)
	_mouth.scale = _mouth.scale.lerp(mouth_scale, 0.3)
