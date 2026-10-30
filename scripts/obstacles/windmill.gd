class_name Windmill
extends Node3D
## Moinho gigante: quatro pás giram atravessando a passarela. Passe no
## intervalo entre elas! A origem é o chão, no meio da passarela.

@export var hub_height := 3.6
@export var blade_length := 3.3
## Voltas por segundo (o sinal muda o sentido).
@export var speed := 0.22
@export var push := 9.0
@export var color := Color("ab47bc")

var _rotor: Node3D
var _blades: Array[Area3D] = []
var _angle := 0.0


func _ready() -> void:
	# Torre em "A" dos dois lados da passarela.
	for side in [-1.0, 1.0]:
		var post := Build.cylinder(self, 0.18, hub_height + 0.6, Color("eceff1"), Vector3(side * 2.6, (hub_height + 0.6) * 0.5 - 0.3, 0.6), -1.0, true)
		post.rotation.z = side * 0.12
	Build.box(self, Vector3(5.6, 0.3, 0.3), Color("fdd835"), Vector3(0, hub_height + 0.3, 0.6), true)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0, hub_height, 0)
	add_child(_rotor)
	Build.sphere(_rotor, 0.45, Color.WHITE, Vector3.ZERO, true)
	for i in 4:
		var arm := Node3D.new()
		arm.rotation.z = i * PI * 0.5
		_rotor.add_child(arm)
		var blade_color := color if i % 2 == 0 else Color.WHITE
		Build.box(arm, Vector3(0.7, blade_length, 0.25), blade_color, Vector3(0, -blade_length * 0.5 - 0.2, 0), true)
		_blades.append(Build.area_box(arm, Vector3(0.8, blade_length, 0.6), Vector3(0, -blade_length * 0.5 - 0.2, 0)))
	_angle = randf() * TAU


func _physics_process(delta: float) -> void:
	_angle = wrapf(_angle + TAU * speed * delta, 0.0, TAU)
	_rotor.rotation.z = _angle
	var side := global_transform.basis.x
	for blade in _blades:
		for body in blade.get_overlapping_bodies():
			if body is Player:
				# Joga para o lado em que a pá está girando.
				var away := signf((body.global_position - _rotor.global_position).dot(side))
				if away == 0.0:
					away = 1.0
				(body as Player).knockback(side * away * push + Vector3.UP * 5.0)


## Alguma pá passando por baixo (onde o jogador anda)? Usado pelos rivais.
func is_dangerous() -> bool:
	for i in 4:
		var a := wrapf(_angle + i * PI * 0.5, -PI, PI)
		if absf(a) < 0.42:
			return true
	return false
