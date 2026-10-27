class_name Sweeper
extends Node3D
## Bastão giratório (cilindro que varre a plataforma). Pule por cima!
## A origem é o centro, no chão.

@export var radius := 5.0
## Radianos por segundo (o sinal define o sentido).
@export var speed := 1.2
@export var bar_height := 0.55
@export var bars := 1
@export var push := 9.0
@export var color := Color("e53935")

var _rotor: Node3D
var _areas: Array[Area3D] = []


func _ready() -> void:
	Build.cylinder(self, 0.55, 1.5, Color("fdd835"), Vector3(0, 0.75, 0), 0.45, true)
	Build.sphere(self, 0.4, color, Vector3(0, 1.55, 0), true)
	_rotor = Node3D.new()
	add_child(_rotor)
	for i in bars:
		var arm := Node3D.new()
		arm.rotation.y = i * TAU / bars
		_rotor.add_child(arm)
		var bar := Build.cylinder(arm, 0.24, radius, color, Vector3(radius * 0.5, bar_height, 0), -1.0, true)
		bar.rotation.z = PI * 0.5
		for k in int(radius / 1.2):
			var ring := Build.cylinder(arm, 0.26, 0.25, Color.WHITE, Vector3(0.9 + k * 1.2, bar_height, 0))
			ring.rotation.z = PI * 0.5
		Build.sphere(arm, 0.3, Color("fdd835"), Vector3(radius, bar_height, 0))
		_areas.append(Build.area_box(arm, Vector3(radius, 0.6, 0.7), Vector3(radius * 0.5, bar_height, 0)))


func _physics_process(delta: float) -> void:
	_rotor.rotation.y += speed * delta
	for area in _areas:
		for body in area.get_overlapping_bodies():
			if body is Player:
				var relative := body.global_position - global_position
				relative.y = 0.0
				var tangent := Vector3.UP.cross(relative).normalized() * signf(speed)
				(body as Player).knockback(tangent * push + Vector3.UP * 6.5)


func rotor_angle() -> float:
	return _rotor.rotation.y
