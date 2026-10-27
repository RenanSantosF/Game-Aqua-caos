class_name FollowCamera
extends Camera3D
## Câmera de terceira pessoa: fica atrás e acima do jogador, sempre olhando
## para a frente do percurso (-Z). Suave, mas sem atrasar demais.

@export var target_path: NodePath
@export var offset := Vector3(0, 5.2, 8.5)
@export var look_ahead := Vector3(0, 0.8, -4.0)
@export var follow_speed := 6.0
@export var min_height := 1.0

var target: Node3D
var _shake := 0.0


func _ready() -> void:
	if not target_path.is_empty():
		target = get_node(target_path)
		if target is Player:
			(target as Player).respawned.connect(snap)
	snap()


func snap() -> void:
	if target == null:
		return
	global_position = _desired_position()
	look_at(target.global_position + look_ahead)


func shake(amount := 0.3) -> void:
	_shake = maxf(_shake, amount)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	# Enquanto o jogador afunda, a câmera só observa o respingo.
	var in_water := target is Player and (target as Player).state == Player.State.IN_WATER
	if not in_water:
		var weight := 1.0 - exp(-follow_speed * delta)
		global_position = global_position.lerp(_desired_position(), weight)
	var look := target.global_position + look_ahead
	look.y = maxf(look.y, min_height - 1.0)
	look_at(look)
	if _shake > 0.0:
		_shake = move_toward(_shake, 0.0, delta * 1.5)
		h_offset = randf_range(-1.0, 1.0) * _shake * 0.3
		v_offset = randf_range(-1.0, 1.0) * _shake * 0.3


func _desired_position() -> Vector3:
	var desired := target.global_position + offset
	desired.y = maxf(desired.y, min_height + offset.y * 0.5)
	return desired
