class_name BouncePad
extends StaticBody3D
## Boia trampolim: ao pisar, o jogador é lançado bem alto.
## A origem é o centro do topo.

@export var radius := 1.2
@export var bounce_velocity := 13.0
@export var color := Color("ff7043")

var _visual: Node3D
var _squish := 0.0
var _cooldown := 0.0
var _detector: Area3D


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = 0.5
	shape.shape = cyl
	shape.position.y = -0.25
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	var ring := Build.torus(_visual, radius * 0.55, radius, color, Vector3(0, -0.2, 0))
	ring.scale = Vector3(1, 1.6, 1)
	Build.cylinder(_visual, radius * 0.6, 0.3, Color.WHITE, Vector3(0, -0.15, 0))
	for i in 4:
		var stripe := Build.box(_visual, Vector3(0.35, 0.5, radius * 0.5), Color.WHITE, Vector3(0, -0.2, 0))
		stripe.rotation.y = i * PI * 0.5 + PI * 0.25
		stripe.position = Vector3(cos(i * PI * 0.5 + PI * 0.25), -0.2, sin(i * PI * 0.5 + PI * 0.25)) * Vector3(radius * 0.78, 1, radius * 0.78)
	_detector = Build.area_box(self, Vector3(radius * 1.6, 0.5, radius * 1.6), Vector3(0, 0.25, 0))


func _physics_process(delta: float) -> void:
	_squish = move_toward(_squish, 0.0, delta * 3.0)
	_visual.scale = Vector3(1.0 + 0.25 * _squish, 1.0 - 0.5 * _squish, 1.0 + 0.25 * _squish)
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	for body in _detector.get_overlapping_bodies():
		if body is Player and (body as Player).velocity.y <= 0.5:
			(body as Player).launch(bounce_velocity)
			_squish = 1.0
			_cooldown = 0.25
