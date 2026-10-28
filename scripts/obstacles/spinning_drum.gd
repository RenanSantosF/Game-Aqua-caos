class_name SpinningDrum
extends StaticBody3D
## Tambor gigante deitado ao longo do caminho: gira e empurra para o lado.
## Corra no meio e compense! A origem é o centro do eixo.

@export var radius := 1.6
@export var length := 12.0
## Velocidade lateral da superfície (m/s).
@export var surface_speed := 2.0
@export var color := Color("29b6f6")

var _visual: Node3D


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = length
	shape.shape = cylinder
	shape.rotation.x = PI * 0.5
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	var body := Build.cylinder(_visual, radius, length, color, Vector3.ZERO, -1.0, true)
	body.rotation.x = PI * 0.5
	for i in 6:
		var a := i * TAU / 6.0
		var stripe := Build.box(_visual, Vector3(0.35, 0.12, length + 0.04), Color.WHITE if i % 2 == 0 else Color("fdd835"), Vector3(cos(a), sin(a), 0) * radius)
		stripe.rotation.z = a + PI * 0.5
	for side in [-1.0, 1.0]:
		var ring := Build.torus(self, radius * 0.9, radius * 1.08, Color("e53935"), Vector3(0, 0, side * length * 0.5))
		ring.rotation.x = PI * 0.5


func belt_velocity() -> Vector3:
	return global_transform.basis * Vector3(surface_speed, 0, 0)


func _physics_process(delta: float) -> void:
	_visual.rotation.z -= surface_speed / radius * delta
