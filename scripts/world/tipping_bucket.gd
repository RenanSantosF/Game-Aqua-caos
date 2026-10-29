class_name TippingBucket
extends Node3D
## Balde gigante de parque aquático: enche aos poucos, vira e despeja uma
## cascata de água. Só enfeite (sem colisão).

@export var color := Color("ffca28")
@export var period := 7.0

var _time := 0.0
var _pivot: Node3D
var _water: MeshInstance3D
var _cascade: CPUParticles3D


func _ready() -> void:
	var height := 7.0
	# Torre com duas colunas e travessa.
	for side in [-1.0, 1.0]:
		Build.cylinder(self, 0.28, height + 2.0, Color("eceff1"), Vector3(side * 1.9, (height + 2.0) * 0.5 - 2.0, 0), -1.0, true)
	Build.box(self, Vector3(4.2, 0.35, 0.35), Color("ef5350"), Vector3(0, height, 0), true)
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, height - 0.3, 0)
	add_child(_pivot)
	var bucket := Build.cylinder(_pivot, 1.3, 1.8, color, Vector3(0, -0.9, 0), 1.6, true)
	bucket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Build.torus(_pivot, 1.45, 1.75, Color.WHITE, Vector3(0, 0.0, 0))
	_water = Build.cylinder(_pivot, 1.45, 0.1, Color("4fc3f7"), Vector3(0, -1.6, 0))
	if Game.low_graphics():
		return
	_cascade = CPUParticles3D.new()
	var drop := SphereMesh.new()
	drop.radius = 0.16
	drop.height = 0.32
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = Mat.unshaded(Color(0.75, 0.94, 1.0, 0.9))
	_cascade.mesh = drop
	_cascade.amount = 70
	_cascade.lifetime = 1.3
	_cascade.one_shot = true
	_cascade.emitting = false
	_cascade.explosiveness = 0.55
	_cascade.direction = Vector3(0, -0.2, 1)
	_cascade.spread = 25.0
	_cascade.initial_velocity_min = 2.0
	_cascade.initial_velocity_max = 4.0
	_cascade.gravity = Vector3(0, -14, 0)
	_cascade.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_cascade.emission_sphere_radius = 0.9
	_cascade.scale_amount_min = 0.7
	_cascade.scale_amount_max = 1.6
	_cascade.position = Vector3(0, height - 0.4, 1.4)
	add_child(_cascade)


func _process(delta: float) -> void:
	_time = fmod(_time + delta, period)
	var tip_start := period - 1.6
	var angle := 0.0
	if _time < tip_start:
		# Enchendo: a água sobe e o balde balança de leve.
		var fill := _time / tip_start
		_water.position.y = lerpf(-1.6, -0.25, fill)
		angle = sin(_time * 3.0) * 0.03 * fill
	else:
		var t := (_time - tip_start) / 1.6
		angle = sin(clampf(t * 1.6, 0.0, 1.0) * PI * 0.5) * 2.0 * (1.0 - smoothstep(0.65, 1.0, t))
		_water.position.y = lerpf(-0.25, -1.6, clampf(t * 2.5, 0.0, 1.0))
		if _cascade and t > 0.3 and not _cascade.emitting:
			_cascade.restart()
	_pivot.rotation.x = angle
