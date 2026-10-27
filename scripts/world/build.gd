class_name Build
## Atalhos para montar o mundo com formas simples (caixas, cilindros, esferas).

static func box(parent: Node, size: Vector3, color: Color, position := Vector3.ZERO, outlined := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(parent, mesh, Mat.toon(color, outlined), position)


static func cylinder(parent: Node, radius: float, height: float, color: Color, position := Vector3.ZERO, top_radius := -1.0, outlined := false) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.height = height
	mesh.radial_segments = 20
	mesh.rings = 1
	return _instance(parent, mesh, Mat.toon(color, outlined), position)


static func sphere(parent: Node, radius: float, color: Color, position := Vector3.ZERO, outlined := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 18
	mesh.rings = 9
	return _instance(parent, mesh, Mat.toon(color, outlined), position)


static func capsule(parent: Node, radius: float, height: float, color: Color, position := Vector3.ZERO, outlined := false) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 6
	return _instance(parent, mesh, Mat.toon(color, outlined), position)


static func torus(parent: Node, inner: float, outer: float, color: Color, position := Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 20
	mesh.ring_segments = 10
	return _instance(parent, mesh, Mat.toon(color), position)


## Corpo estático em forma de caixa (colisão + visual). "top" é o centro do topo.
static func solid_box(parent: Node, size: Vector3, top: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = top - Vector3(0, size.y * 0.5, 0)
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	box(body, size, color)
	return body


static func solid_cylinder(parent: Node, radius: float, height: float, top: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = top - Vector3(0, height * 0.5, 0)
	parent.add_child(body)
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	body.add_child(shape)
	cylinder(body, radius, height, color)
	return body


static func area_box(parent: Node, size: Vector3, position := Vector3.ZERO) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	area.position = position
	parent.add_child(area)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	area.add_child(shape)
	return area


static func _instance(parent: Node, mesh: Mesh, material: Material, position: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	parent.add_child(instance)
	return instance
