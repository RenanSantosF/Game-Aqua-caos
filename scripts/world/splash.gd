extends Node3D
## Respingo de água: gotas (CPUParticles3D) + anel que se abre na superfície.
## Remove-se sozinho.

const LIFETIME := 1.1

var _time := 0.0
var _ring: MeshInstance3D


func _ready() -> void:
	var drops := CPUParticles3D.new()
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 0.09
	drop_mesh.height = 0.18
	drop_mesh.radial_segments = 6
	drop_mesh.rings = 3
	drop_mesh.material = Mat.unshaded(Color("e3f6ff"))
	drops.mesh = drop_mesh
	drops.amount = 26
	drops.lifetime = 0.9
	drops.one_shot = true
	drops.explosiveness = 0.95
	drops.direction = Vector3.UP
	drops.spread = 35.0
	drops.gravity = Vector3(0, -22, 0)
	drops.initial_velocity_min = 4.0
	drops.initial_velocity_max = 9.0
	drops.scale_amount_min = 0.6
	drops.scale_amount_max = 1.4
	drops.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	drops.emission_sphere_radius = 0.4
	add_child(drops)
	drops.emitting = true

	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 24
	torus.ring_segments = 6
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring.material_override = Mat.unshaded(Color(1, 1, 1, 0.8))
	_ring.scale = Vector3(0.5, 0.15, 0.5)
	add_child(_ring)


func _process(delta: float) -> void:
	_time += delta
	var k := _time / LIFETIME
	var s := 0.5 + k * 2.2
	_ring.scale = Vector3(s, 0.15, s)
	_ring.transparency = k
	if _time >= LIFETIME:
		queue_free()
