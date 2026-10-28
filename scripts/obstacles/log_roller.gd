class_name LogRoller
extends StaticBody3D
## Rolo giratório deitado sobre a água: a superfície gira e arrasta quem
## está em cima (para trás). Pule de rolo em rolo! A origem é o centro do eixo.

@export var radius := 0.9
@export var length := 4.5
## Velocidade da superfície (m/s). Positivo arrasta para trás (+Z local).
@export var surface_speed := 2.5
@export var color := Color("8d6e63")

var _visual: Node3D


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = length
	shape.shape = cylinder
	shape.rotation.z = PI * 0.5
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	var log_mesh := Build.cylinder(_visual, radius, length, color, Vector3.ZERO, -1.0, true)
	log_mesh.rotation.z = PI * 0.5
	for i in 4:
		var stripe := Build.box(_visual, Vector3(length + 0.04, 0.12, 0.3), Color("fdd835"), Vector3.ZERO)
		stripe.rotation.x = i * PI * 0.25
		stripe.position = Vector3(0, cos(i * PI * 0.25) * radius, sin(i * PI * 0.25) * radius)
	for side in [-1.0, 1.0]:
		var cap := Build.cylinder(self, radius * 0.55, 0.3, Color("e53935"), Vector3(side * (length * 0.5 + 0.15), 0, 0))
		cap.rotation.z = PI * 0.5


func belt_velocity() -> Vector3:
	return global_transform.basis * Vector3(0, 0, surface_speed)


func _physics_process(delta: float) -> void:
	_visual.rotation.x += surface_speed / radius * delta
