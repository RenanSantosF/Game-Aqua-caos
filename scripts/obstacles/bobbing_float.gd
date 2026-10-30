class_name BobbingFloat
extends AnimatableBody3D
## Boia redonda que sobe e desce na água. Pule de uma para a outra!
## A origem é o centro do topo (na posição do meio).

@export var radius := 1.5
@export var amplitude := 0.3
@export var period := 2.4
@export var color := Color("ffca28")

var _start := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	sync_to_physics = false
	_start = position
	_time = randf() * period
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 0.6
	shape.shape = cyl
	shape.position.y = -0.3
	add_child(shape)
	var ring := Build.torus(self, radius * 0.45, radius, color, Vector3(0, -0.3, 0))
	ring.scale = Vector3(1, 1.5, 1)
	Build.cylinder(self, radius * 0.55, 0.5, Color.WHITE, Vector3(0, -0.28, 0))
	for i in 4:
		var a := i * PI * 0.5 + PI * 0.25
		Build.box(self, Vector3(0.4, 0.62, 0.4), Color.WHITE, Vector3(cos(a), 0, sin(a)) * radius * 0.78 + Vector3(0, -0.3, 0))


func _physics_process(delta: float) -> void:
	_time += delta
	position = _start + Vector3.UP * sin(TAU * _time / period) * amplitude
