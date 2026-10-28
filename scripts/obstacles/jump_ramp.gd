class_name JumpRamp
extends Node3D
## Rampa de salto: no topo, lança o jogador longe para a frente.
## A origem é o pé da rampa; ela sobe em direção a -Z local.

@export var width := 4.0
@export var length := 4.0
@export var height := 1.4
@export var launch_up := 11.0
@export var launch_forward := 12.0
@export var color := Color("ff7043")

var _area: Area3D


func _ready() -> void:
	var angle := atan2(height, length)
	var hyp := sqrt(length * length + height * height)
	var body := StaticBody3D.new()
	body.rotation.x = angle
	var normal := Vector3(0, cos(angle), sin(angle))
	body.position = Vector3(0, height * 0.5, -length * 0.5) - normal * 0.3
	add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.6, hyp)
	shape.shape = box
	body.add_child(shape)
	Build.box(body, Vector3(width, 0.6, hyp), color, Vector3.ZERO, true)
	for i in 3:
		Build.box(body, Vector3(width * 0.8, 0.04, 0.25), Color.WHITE, Vector3(0, 0.31, -hyp * 0.3 + i * hyp * 0.3))
	Build.box(self, Vector3(width, height, 0.4), color.darkened(0.3), Vector3(0, height * 0.5 - 0.1, -length + 0.2))
	_area = Build.area_box(self, Vector3(width, 1.0, 1.0), Vector3(0, height + 0.4, -length + 0.4))


func _physics_process(_delta: float) -> void:
	for body in _area.get_overlapping_bodies():
		if body is Player and (body as Player).velocity.y < 3.0:
			var forward := -global_transform.basis.z
			(body as Player).launch_toward(forward * launch_forward, launch_up)
