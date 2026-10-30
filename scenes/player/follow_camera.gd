class_name FollowCamera
extends Camera3D
## Câmera de terceira pessoa que acompanha as curvas do percurso.
## Arraste o dedo na metade direita da tela (ou Q/E no PC) para girar.
## Depois de um tempo sem mexer, ela volta sozinha para trás do jogador.

@export var target_path: NodePath
@export var distance := 7.0
@export var pitch_degrees := 38.0
## Leve ângulo de lado (visão 3/4), para não ficar totalmente de costas.
@export var side_degrees := 12.0
@export var look_height := 1.0
@export var follow_speed := 8.0
@export var drag_sensitivity := 0.0065

var target: Node3D
## Direção da rota onde o jogador está (definida pela fase).
var path_yaw := 0.0
## Modo comemoração: câmera vai para a frente do boneco.
var celebrating := false

var _yaw := 0.0
var _user_yaw := 0.0
var _user_pitch := 0.0
var _idle := 99.0
var _drag_index := -1
var _shake := 0.0
## Filtro azul na tela quando a câmera está debaixo da água (túnel submarino).
var _underwater: ColorRect


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	_underwater = ColorRect.new()
	_underwater.color = Color(0.05, 0.4, 0.85, 0.3)
	_underwater.set_anchors_preset(Control.PRESET_FULL_RECT)
	_underwater.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_underwater.hide()
	layer.add_child(_underwater)
	if not target_path.is_empty():
		target = get_node(target_path)
		if target is Player:
			(target as Player).respawned.connect(snap)
	snap()


func snap() -> void:
	if target == null:
		return
	_user_yaw = 0.0
	_user_pitch = 0.0
	_yaw = _desired_yaw()
	global_position = _desired_position()
	look_at(_look_point())


func shake(amount := 0.3) -> void:
	_shake = maxf(_shake, amount)


func _input(event: InputEvent) -> void:
	var screen := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _drag_index == -1 and _is_camera_zone(touch.position, screen):
			_drag_index = touch.index
		elif not touch.pressed and touch.index == _drag_index:
			_drag_index = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _drag_index:
			_rotate_by(drag.relative)


func _is_camera_zone(point: Vector2, screen: Vector2) -> bool:
	if point.x < screen.x * 0.45:
		return false  # joystick
	if point.distance_to(Vector2(screen.x - 140, screen.y - 150)) < 130.0:
		return false  # botão de pular
	return point.y > 110.0  # deixa o HUD do topo livre


func _rotate_by(relative: Vector2) -> void:
	_user_yaw -= relative.x * drag_sensitivity
	_user_pitch = clampf(_user_pitch + relative.y * drag_sensitivity * 0.6, deg_to_rad(-22.0), deg_to_rad(30.0))
	_idle = 0.0


func _physics_process(delta: float) -> void:
	if target == null:
		return
	var keys := Input.get_axis("camera_left", "camera_right")
	if absf(keys) > 0.0:
		_rotate_by(Vector2(keys * 400.0 * delta, 0))
	_idle += delta
	if _idle > 2.5 and not celebrating:
		_user_yaw = lerp_angle(_user_yaw, 0.0, minf(1.0, 1.2 * delta))
		_user_pitch = lerpf(_user_pitch, 0.0, minf(1.0, 1.2 * delta))

	_yaw = lerp_angle(_yaw, _desired_yaw(), 1.0 - exp(-(4.0 if _idle > 0.2 else 20.0) * delta))
	if target is Player:
		# "Para frente" no joystick segue o caminho (sem o ângulo 3/4 da câmera).
		(target as Player).camera_yaw = _yaw - (0.0 if celebrating else deg_to_rad(side_degrees))

	# Enquanto o jogador afunda, a câmera só observa o respingo.
	var in_water := target is Player and (target as Player).state == Player.State.IN_WATER
	if not in_water:
		var weight := 1.0 - exp(-follow_speed * delta)
		global_position = global_position.lerp(_desired_position(), weight)
	look_at(_look_point())
	_underwater.visible = global_position.y < CourseBuilder.WATER_Y + 0.1
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 1.5)
		h_offset = randf_range(-1.0, 1.0) * _shake * 0.3
		v_offset = randf_range(-1.0, 1.0) * _shake * 0.3


func _desired_yaw() -> float:
	if celebrating:
		return path_yaw + PI + deg_to_rad(20.0)
	return path_yaw + deg_to_rad(side_degrees) + _user_yaw


func _desired_position() -> Vector3:
	var pitch := deg_to_rad(18.0 if celebrating else pitch_degrees) + _user_pitch
	var dist := 5.5 if celebrating else distance
	# Dentro do túnel submerso: câmera baixa e perto, dentro do tubo.
	var in_tunnel := target is Player and (target as Player).tunnel_count > 0 \
			and target.global_position.y < CourseBuilder.WATER_Y + 1.5
	if in_tunnel:
		pitch = deg_to_rad(12.0)
		dist = 3.6
	var offset := Vector3(0, 0, dist).rotated(Vector3.RIGHT, -pitch).rotated(Vector3.UP, _yaw)
	var desired := target.global_position + Vector3.UP * look_height + offset
	if not in_tunnel:
		desired.y = maxf(desired.y, CourseBuilder.WATER_Y + 1.0)
	return desired


func _look_point() -> Vector3:
	return target.global_position + Vector3.UP * look_height
