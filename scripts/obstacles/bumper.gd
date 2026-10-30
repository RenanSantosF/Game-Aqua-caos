class_name Bumper
extends StaticBody3D
## Pino de fliperama: quem encosta é arremessado para longe (sem cair).
## A origem é o centro da base.

@export var radius := 0.7
@export var power := 6.5
@export var color := Color("ef5350")
## Vai e volta para os lados (0 = parado).
@export var sway := 0.0
@export var sway_period := 2.6

var _visual: Node3D
var _pulse := 0.0
var _start := Vector3.ZERO
var _time := 0.0
var _detector: Area3D


func _ready() -> void:
	_start = position
	_time = randf() * sway_period
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 1.2
	shape.shape = cyl
	shape.position.y = 0.6
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	Build.cylinder(_visual, radius, 1.0, color, Vector3(0, 0.5, 0), radius * 0.85, true)
	Build.torus(_visual, radius * 0.95, radius * 1.25, Color.WHITE, Vector3(0, 0.55, 0))
	Build.sphere(_visual, radius * 0.6, Color("fff59d"), Vector3(0, 1.05, 0))
	_detector = Build.area_box(self, Vector3(radius * 2.0 + 0.5, 1.2, radius * 2.0 + 0.5), Vector3(0, 0.6, 0))
	_detector.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player:
		return
	var away := body.global_position - global_position
	away.y = 0.0
	if away.length() < 0.05:
		away = Vector3.RIGHT
	# Arremessa mais para o lado do que para trás (nunca empaca de frente).
	var side := global_transform.basis.x
	var lateral := side * signf(away.dot(side)) if absf(away.dot(side)) > 0.05 else side
	var direction := (away.normalized() * 0.4 + lateral * 0.9).normalized()
	(body as Player).launch_toward(direction * power, 3.5)
	_pulse = 1.0
	if (body as Player).is_human:
		Sfx.play("bounce", -4.0)


func _physics_process(delta: float) -> void:
	_pulse = move_toward(_pulse, 0.0, delta * 4.0)
	_visual.scale = Vector3.ONE * (1.0 + 0.25 * _pulse)
	if sway > 0.0:
		_time += delta
		position = _start + Vector3(sin(TAU * _time / sway_period) * sway, 0, 0)
