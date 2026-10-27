class_name Conveyor
extends StaticBody3D
## Esteira molhada que puxa o jogador para trás. A origem é o centro do topo.

@export var size := Vector3(4, 0.5, 12)
## Velocidade da esteira (positivo = empurra para trás, em +Z).
@export var speed := 3.0

var _stripes: Array[MeshInstance3D] = []


func belt_velocity() -> Vector3:
	return global_transform.basis * Vector3(0, 0, speed)


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = -size.y * 0.5
	add_child(shape)
	Build.box(self, size, Color("37474f"), Vector3(0, -size.y * 0.5, 0), true)
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(0.3, size.y + 0.3, size.z), Color("fdd835"), Vector3(side * (size.x * 0.5 + 0.15), -size.y * 0.5 + 0.15, 0))
	var count := int(size.z / 1.5)
	for i in count:
		var stripe := Build.box(self, Vector3(size.x * 0.8, 0.04, 0.35), Color("4fc3f7"), Vector3(0, 0.01, 0))
		_stripes.append(stripe)


func _process(delta: float) -> void:
	var count := _stripes.size()
	for i in count:
		var z := fposmod(i * size.z / count + Time.get_ticks_msec() * 0.001 * speed, size.z) - size.z * 0.5
		_stripes[i].position.z = z
