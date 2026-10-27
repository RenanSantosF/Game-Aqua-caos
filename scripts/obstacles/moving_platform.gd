class_name MovingPlatform
extends AnimatableBody3D
## Boia-plataforma que vai e volta, levando o jogador junto.
## A origem é o centro do topo na posição inicial.

@export var size := Vector3(3.5, 0.6, 3.5)
@export var travel := Vector3(6, 0, 0)
## Segundos para ir e voltar.
@export var period := 3.5
@export_range(0.0, 1.0) var phase := 0.0
@export var color := Color("fdd835")
@export var stripe_color := Color("e53935")

var _start := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	sync_to_physics = false
	_start = position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = -size.y * 0.5
	add_child(shape)
	Build.box(self, size, color, Vector3(0, -size.y * 0.5, 0), true)
	for i in 3:
		var x := (i - 1) * size.x * 0.3
		Build.box(self, Vector3(size.x * 0.12, size.y + 0.04, size.z + 0.04), stripe_color, Vector3(x, -size.y * 0.5, 0))
	_update(0.0)


func _physics_process(delta: float) -> void:
	_time += delta
	_update(_time)


func _update(t: float) -> void:
	var k := 0.5 - 0.5 * cos(TAU * (t / period + phase))
	position = _start + travel * k
