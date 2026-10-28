class_name Pusher
extends Node3D
## Parede-soco: um bloco sai da lateral de repente e empurra o jogador.
## A origem fica na borda da passarela, no chão. "direction" aponta para dentro.

@export var direction := 1.0
@export var reach := 2.8
@export var period := 2.4
@export var time_offset := 0.0
@export var push := 11.0
@export var color := Color("7e57c2")

var _block: AnimatableBody3D
var _area: Area3D
var _time := 0.0
var _extension := 0.0


func _ready() -> void:
	# Torre lateral de onde o bloco sai.
	Build.box(self, Vector3(1.2, 2.6, 2.2), Color("5e35b1"), Vector3(-direction * 0.6, 1.3, 0), true)
	Build.box(self, Vector3(1.25, 0.25, 2.25), Color("fdd835"), Vector3(-direction * 0.6, 2.6, 0))
	_block = AnimatableBody3D.new()
	_block.sync_to_physics = false
	add_child(_block)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 1.6, 1.8)
	shape.shape = box
	_block.add_child(shape)
	Build.box(_block, Vector3(1.0, 1.6, 1.8), color, Vector3.ZERO, true)
	var glove := Build.sphere(_block, 0.55, Color("e53935"), Vector3(direction * 0.6, 0, 0), true)
	glove.scale = Vector3(0.7, 1, 1)
	_area = Build.area_box(_block, Vector3(0.6, 1.6, 1.9), Vector3(direction * 0.7, 0, 0))
	_update(0.0)


func _physics_process(delta: float) -> void:
	_time += delta
	var previous := _extension
	_update(_time)
	if _extension > previous + 0.01:
		for body in _area.get_overlapping_bodies():
			if body is Player:
				(body as Player).knockback(global_transform.basis * Vector3(direction * push, 5.0, 0.0))


func _update(t: float) -> void:
	# Ciclo: parado recolhido → soco rápido → segura → volta devagar.
	var k := fposmod(t + time_offset, period) / period
	if k < 0.45:
		_extension = 0.0
	elif k < 0.53:
		_extension = (k - 0.45) / 0.08
	elif k < 0.68:
		_extension = 1.0
	else:
		_extension = 1.0 - (k - 0.68) / 0.32
	_block.position = Vector3(direction * (-0.6 + _extension * reach), 0.9, 0)


## Perigoso agora ou prestes a socar (os rivais esperam).
func is_dangerous() -> bool:
	var k := fposmod(_time + time_offset, period) / period
	return (k > 0.36 and k < 0.72) or _extension > 0.05
