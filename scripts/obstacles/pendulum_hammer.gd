class_name PendulumHammer
extends Node3D
## Martelo inflável em pêndulo que balança atravessando a passarela.
## A origem é o eixo do pêndulo (no alto). O chão fica em y = -(arm_length + 0.9).

@export var arm_length := 4.0
@export var max_angle := 1.1
## Segundos para ir e voltar.
@export var period := 2.6
@export_range(0.0, 1.0) var phase := 0.0
@export var push := 10.0
@export var color := Color("e53935")

var _swing: Node3D
var _head: Area3D
var _time := 0.0
var _previous := Vector3.ZERO


func _ready() -> void:
	var ground := -(arm_length + 0.9)
	# Pórtico: dois postes e uma viga ao longo da passarela.
	for z in [-1.4, 1.4]:
		Build.cylinder(self, 0.18, -ground + 0.4, Color("78909c"), Vector3(2.4, ground * 0.5 + 0.2, z))
		Build.cylinder(self, 0.18, -ground + 0.4, Color("78909c"), Vector3(-2.4, ground * 0.5 + 0.2, z))
	Build.box(self, Vector3(5.2, 0.35, 0.35), Color("fdd835"), Vector3(0, 0.3, -1.4))
	Build.box(self, Vector3(5.2, 0.35, 0.35), Color("fdd835"), Vector3(0, 0.3, 1.4))
	Build.box(self, Vector3(0.35, 0.35, 3.1), Color("fdd835"), Vector3(0, 0.3, 0))

	_swing = Node3D.new()
	add_child(_swing)
	Build.cylinder(_swing, 0.1, arm_length, Color("b0bec5"), Vector3(0, -arm_length * 0.5, 0))
	var head_root := Node3D.new()
	head_root.position = Vector3(0, -arm_length, 0)
	_swing.add_child(head_root)
	var head := Build.cylinder(head_root, 0.8, 1.7, color, Vector3.ZERO, -1.0, true)
	head.rotation.x = PI * 0.5
	for z in [-0.45, 0.45]:
		var stripe := Build.cylinder(head_root, 0.82, 0.25, Color.WHITE, Vector3(0, 0, z))
		stripe.rotation.x = PI * 0.5
	_head = Build.area_box(head_root, Vector3(1.6, 1.6, 1.7))
	_update_angle()
	_previous = _head.global_position


func _physics_process(delta: float) -> void:
	_time += delta
	_update_angle()
	var head_position := _head.global_position
	var head_velocity := (head_position - _previous) / delta
	_previous = head_position
	var side := global_transform.basis.x
	for body in _head.get_overlapping_bodies():
		if body is Player:
			var along := head_velocity.dot(side)
			var direction := signf(along)
			if absf(along) < 1.0:
				direction = signf((body.global_position - head_position).dot(side))
			if direction == 0.0:
				direction = 1.0
			(body as Player).knockback(side * direction * push + Vector3.UP * 6.0)


func _update_angle() -> void:
	_swing.rotation.z = max_angle * sin(TAU * (_time / period + phase))


func head_position() -> Vector3:
	return _head.global_position
