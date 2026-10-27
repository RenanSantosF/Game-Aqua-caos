class_name SpinningDisc
extends AnimatableBody3D
## Disco giratório: o jogador gira junto e precisa compensar para não cair.
## A origem é o centro do topo.

@export var radius := 3.0
@export var height := 0.6
@export var speed := 0.9
@export var color := Color("29b6f6")


func _ready() -> void:
	sync_to_physics = false
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position.y = -height * 0.5
	add_child(shape)
	Build.cylinder(self, radius, height, color, Vector3(0, -height * 0.5, 0), -1.0, true)
	for i in 4:
		var stripe := Build.box(self, Vector3(radius * 2.0 - 0.3, 0.05, 0.45), Color.WHITE, Vector3(0, 0.02, 0))
		stripe.rotation.y = i * PI / 4.0
	Build.cylinder(self, 0.6, 0.12, Color("fdd835"), Vector3(0, 0.05, 0))


func _physics_process(delta: float) -> void:
	rotation.y += speed * delta
