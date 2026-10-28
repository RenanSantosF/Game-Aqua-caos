class_name WorldDecor
extends Node3D
## Cenário vivo em volta do percurso: ilhas com coqueiros, torres de tobogã,
## boias flutuando, nuvens, gaivotas, golfinhos e torcida nas arquibancadas.
## Tudo feito com formas simples e em quantidade controlada (celular modesto).

var _theme: Dictionary
var _rng := RandomNumberGenerator.new()
var _time := 0.0
var _buoys: Array[Node3D] = []
var _clouds: Array[Node3D] = []
var _birds: Array[Dictionary] = []
var _dolphins: Array[Dictionary] = []
var _crowds: Array[Dictionary] = []


var _route: Array[Vector3] = []


## route: pontos do percurso em ordem. start/finish: onde ficam as torcidas.
func build(theme: Dictionary, route: Array[Vector3], start: Transform3D, finish: Transform3D, seed_value := 1) -> void:
	_theme = theme
	_rng.seed = seed_value
	_route = route
	var samples := _samples(22.0)
	_build_islands(samples)
	_build_towers(samples)
	_build_buoys(_samples(9.0))
	_build_clouds()
	_build_birds(samples)
	_build_dolphins(samples)
	_build_stands(start * Transform3D(Basis(), Vector3(0, 0, -4.0)), 13.0)
	_build_stands(finish, 13.0)
	if theme.get("night", false):
		_build_lights(_samples(12.0))


## Pontos da rota a cada "spacing" metros, com a direção local.
func _samples(spacing: float) -> Array:
	var result: Array = []
	if _route.size() < 2:
		return result
	var travelled := 0.0
	for i in range(1, _route.size()):
		var a := _route[i - 1]
		var b := _route[i]
		var step := Vector2(b.x - a.x, b.z - a.z).length()
		travelled += step
		if travelled >= spacing and step > 0.01:
			travelled = 0.0
			var direction := Vector3(b.x - a.x, 0, b.z - a.z).normalized()
			result.append({"pos": Vector3(b.x, 0, b.z), "dir": direction, "right": direction.cross(Vector3.UP)})
	return result


## Longe o bastante do percurso para não atrapalhar.
func _clear_of_route(point: Vector3, margin: float) -> bool:
	for i in range(0, _route.size(), 2):
		if Vector2(_route[i].x - point.x, _route[i].z - point.z).length() < margin:
			return false
	return true


func _bounds() -> AABB:
	var box := AABB(_route[0], Vector3.ZERO)
	for p in _route:
		box = box.expand(p)
	return box


func _process(delta: float) -> void:
	_time += delta
	for i in _buoys.size():
		var buoy := _buoys[i]
		buoy.position.y = -1.05 + sin(_time * 1.6 + i) * 0.12
		buoy.rotation.z = sin(_time * 1.2 + i * 2.0) * 0.12
	for cloud in _clouds:
		cloud.position.x += delta * 0.8
		if cloud.position.x > 120.0:
			cloud.position.x = -120.0
	for bird in _birds:
		var a: float = _time * bird.speed + bird.offset
		var node: Node3D = bird.node
		node.position = bird.center + Vector3(cos(a), sin(a * 2.0) * 0.08, sin(a)) * bird.radius
		node.rotation.y = -a
		var flap := sin(_time * 12.0 + bird.offset) * 0.6
		(bird.wing_l as Node3D).rotation.z = flap
		(bird.wing_r as Node3D).rotation.z = -flap
	for dolphin in _dolphins:
		var t := fmod(_time + dolphin.offset, dolphin.cycle)
		var node: Node3D = dolphin.node
		if t < 1.2:
			var k := t / 1.2
			node.visible = true
			node.position = dolphin.start + dolphin.direction * k * 6.0 + Vector3.UP * (sin(k * PI) * 2.5 - 1.6)
			node.rotation.x = lerpf(0.9, -0.9, k)
		else:
			node.visible = false
	for crowd in _crowds:
		var mm: MultiMesh = crowd.bodies
		var heads: MultiMesh = crowd.heads
		var base: Array = crowd.base
		for i in mm.instance_count:
			var hop := absf(sin(_time * 6.0 + i * 1.7)) * 0.25
			var p: Vector3 = base[i] + Vector3.UP * hop
			mm.set_instance_transform(i, Transform3D(Basis(), p))
			heads.set_instance_transform(i, Transform3D(Basis(), p + Vector3.UP * 0.55))


# --- Ilhas e coqueiros ------------------------------------------------------------------

func _build_islands(samples: Array) -> void:
	for sample in samples:
		for side in [-1.0, 1.0]:
			if _rng.randf() < 0.8:
				var radius := _rng.randf_range(4.0, 7.5)
				var center: Vector3 = sample.pos + sample.right * side * _rng.randf_range(19.0, 32.0) + sample.dir * _rng.randf_range(-6.0, 6.0)
				if _clear_of_route(center, radius + 9.0):
					_island(center, radius)


func _island(center: Vector3, radius: float) -> void:
	var root := Node3D.new()
	root.position = center
	add_child(root)
	Build.cylinder(root, radius, 2.4, _theme.island, Vector3(0, -1.5, 0), radius * 0.92)
	Build.cylinder(root, radius * 0.72, 0.5, _theme.grass, Vector3(0, -0.15, 0), radius * 0.65)
	var palms := 1 + _rng.randi() % 3
	for i in palms:
		var a := _rng.randf() * TAU
		var p := Vector3(cos(a), 0, sin(a)) * radius * _rng.randf_range(0.1, 0.5)
		_palm(root, p + Vector3(0, 0.1, 0), _rng.randf_range(4.0, 6.5))
	if _rng.randf() < 0.5:
		_umbrella(root, Vector3(radius * 0.55, 0.1, radius * 0.2))
	if _rng.randf() < 0.4:
		var rock := Build.sphere(root, _rng.randf_range(0.6, 1.2), Color("8d8d9a"), Vector3(-radius * 0.6, 0.0, -radius * 0.3))
		rock.scale = Vector3(1.3, 0.7, 1.0)


func _palm(parent: Node3D, base: Vector3, height: float) -> void:
	var palm := Node3D.new()
	palm.position = base
	palm.rotation = Vector3(_rng.randf_range(-0.15, 0.15), _rng.randf() * TAU, _rng.randf_range(-0.15, 0.15))
	parent.add_child(palm)
	var segments := 4
	var top := Vector3.ZERO
	for i in segments:
		var seg_height := height / segments
		var bend := Vector3(0, 0, -0.25 * i)
		var seg := Build.cylinder(palm, 0.22 - i * 0.025, seg_height, Color("8d6e63"), top + bend + Vector3(0, seg_height * 0.5, 0), 0.2 - i * 0.025)
		seg.rotation.x = -0.08 * i
		top = Vector3(0, top.y + seg_height, 0)
	var crown := top + Vector3(0, 0, -0.25 * segments)
	for i in 7:
		var leaf := Build.box(palm, Vector3(0.55, 0.06, 2.6), _theme.leaf if i % 2 == 0 else Color(_theme.leaf).lightened(0.2), crown)
		leaf.rotation = Vector3(-0.45, i * TAU / 7.0, 0)
		leaf.translate_object_local(Vector3(0, 0, -1.2))
	for i in 3:
		Build.sphere(palm, 0.2, Color("6d4c41"), crown + Vector3(cos(i * 2.1) * 0.25, -0.2, sin(i * 2.1) * 0.25))


func _umbrella(parent: Node3D, base: Vector3) -> void:
	Build.cylinder(parent, 0.06, 2.4, Color.WHITE, base + Vector3(0, 1.2, 0))
	var colors: Array = _theme.palette
	Build.cylinder(parent, 0.05, 0.5, colors[0], base + Vector3(0, 2.5, 0), 1.6)
	var chair := Build.box(parent, Vector3(0.7, 0.15, 1.6), colors[1], base + Vector3(0.9, 0.25, 0.6))
	chair.rotation.x = 0.2


# --- Torres de tobogã ao longe ------------------------------------------------------------

func _build_towers(samples: Array) -> void:
	var index := 0
	for i in range(1, samples.size(), 4):
		var sample: Dictionary = samples[i]
		var side := -1.0 if index % 2 == 0 else 1.0
		var base: Vector3 = sample.pos + sample.right * side * _rng.randf_range(46.0, 60.0)
		if _clear_of_route(base, 14.0):
			_tower(base + Vector3(0, -1.2, 0), _rng.randf_range(14.0, 22.0), index)
			index += 1


func _tower(base: Vector3, height: float, index: int) -> void:
	var palette: Array = _theme.palette
	var root := Node3D.new()
	root.position = base
	add_child(root)
	Build.cylinder(root, 1.6, height, Color("eceff1"), Vector3(0, height * 0.5, 0), 1.3)
	var floors := int(height / 4.0)
	for f in floors:
		Build.cylinder(root, 2.6, 0.4, palette[(f + index) % palette.size()], Vector3(0, 3.0 + f * 4.0, 0))
	var roof := Build.cylinder(root, 0.1, 3.0, palette[index % palette.size()], Vector3(0, height + 1.5, 0), 0.0)
	roof.mesh = roof.mesh.duplicate()
	(roof.mesh as CylinderMesh).bottom_radius = 3.0
	# Tobogã em espiral
	var color: Color = palette[(index + 2) % palette.size()]
	var steps := 26
	for s in steps:
		var k := float(s) / steps
		var a := k * TAU * 2.0
		var pos := Vector3(cos(a) * 4.2, height - k * (height - 0.5), sin(a) * 4.2)
		var seg := Build.sphere(root, 0.9, color, pos)
		seg.scale = Vector3(1.0, 0.75, 1.0)


# --- Água viva ----------------------------------------------------------------------------

func _build_buoys(samples: Array) -> void:
	var palette: Array = _theme.palette
	for sample in samples:
		if _rng.randf() < 0.35:
			continue
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var point: Vector3 = sample.pos + sample.right * side * _rng.randf_range(9.0, 16.0)
		if not _clear_of_route(point, 6.5):
			continue
		var buoy := Node3D.new()
		buoy.position = Vector3(point.x, -1.05, point.z)
		add_child(buoy)
		var ring := Build.torus(buoy, 0.45, 0.95, palette[_rng.randi() % palette.size()])
		ring.scale = Vector3(1, 1.4, 1)
		for k in 4:
			var stripe := Build.box(buoy, Vector3(0.3, 0.42, 0.55), Color.WHITE, Vector3(cos(k * PI * 0.5) * 0.7, 0, sin(k * PI * 0.5) * 0.7))
			stripe.rotation.y = -k * PI * 0.5
		_buoys.append(buoy)


func _build_dolphins(samples: Array) -> void:
	if samples.is_empty():
		return
	for i in 4:
		var node := Node3D.new()
		add_child(node)
		var body := Build.capsule(node, 0.35, 1.8, Color("5c7fa8"), Vector3.ZERO, true)
		body.rotation.x = PI * 0.5
		var belly := Build.capsule(node, 0.25, 1.3, Color("dfe8f2"), Vector3(0, -0.12, 0.05))
		belly.rotation.x = PI * 0.5
		var fin := Build.box(node, Vector3(0.08, 0.45, 0.4), Color("5c7fa8"), Vector3(0, 0.4, 0.1))
		fin.rotation.x = 0.5
		Build.box(node, Vector3(0.9, 0.06, 0.3), Color("5c7fa8"), Vector3(0, 0, 0.95))
		var sample: Dictionary = samples[_rng.randi() % samples.size()]
		var side := -1.0 if i % 2 == 0 else 1.0
		var start: Vector3 = sample.pos + sample.right * side * _rng.randf_range(11.0, 18.0) + Vector3(0, -1.2, 0)
		var direction: Vector3 = (sample.dir as Vector3).rotated(Vector3.UP, _rng.randf_range(-0.6, 0.6))
		node.look_at_from_position(start, start + direction, Vector3.UP)
		node.rotation.y += PI
		node.visible = false
		_dolphins.append({"node": node, "start": start, "direction": direction, "cycle": _rng.randf_range(5.0, 9.0), "offset": _rng.randf() * 5.0})


# --- Céu ----------------------------------------------------------------------------------

func _build_clouds() -> void:
	var box := _bounds()
	var white := Color.WHITE if not _theme.get("night", false) else Color("5a5f9a")
	for i in 14:
		var cloud := Node3D.new()
		cloud.position = Vector3(_rng.randf_range(box.position.x - 90.0, box.end.x + 90.0), _rng.randf_range(26.0, 42.0), _rng.randf_range(box.position.z - 60.0, box.end.z + 40.0))
		add_child(cloud)
		for k in 4:
			var puff := Build.sphere(cloud, _rng.randf_range(2.5, 4.5), white, Vector3((k - 1.5) * 3.2, _rng.randf_range(-0.5, 1.2), _rng.randf_range(-1.5, 1.5)))
			puff.material_override = Mat.unshaded(white)
			puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_clouds.append(cloud)


func _build_birds(samples: Array) -> void:
	if samples.is_empty():
		return
	for i in 6:
		var node := Node3D.new()
		add_child(node)
		var body := Build.capsule(node, 0.12, 0.6, Color.WHITE, Vector3.ZERO)
		body.rotation.x = PI * 0.5
		var wing_l := Node3D.new()
		node.add_child(wing_l)
		Build.box(wing_l, Vector3(0.9, 0.04, 0.3), Color("eceff1"), Vector3(-0.45, 0, 0))
		var wing_r := Node3D.new()
		node.add_child(wing_r)
		Build.box(wing_r, Vector3(0.9, 0.04, 0.3), Color("eceff1"), Vector3(0.45, 0, 0))
		var sample: Dictionary = samples[_rng.randi() % samples.size()]
		var center: Vector3 = sample.pos + Vector3(_rng.randf_range(-15.0, 15.0), _rng.randf_range(12.0, 18.0), _rng.randf_range(-15.0, 15.0))
		_birds.append({"node": node, "wing_l": wing_l, "wing_r": wing_r, "center": center, "radius": _rng.randf_range(6.0, 12.0), "speed": _rng.randf_range(0.3, 0.6), "offset": _rng.randf() * TAU})


# --- Torcida ------------------------------------------------------------------------------

func _build_stands(place: Transform3D, offset_x: float) -> void:
	var palette: Array = _theme.palette
	for side in [-1.0, 1.0]:
		var root := Node3D.new()
		root.transform = place * Transform3D(Basis(), Vector3(side * offset_x, -1.2, 0))
		add_child(root)
		for row in 3:
			Build.box(root, Vector3(2.0, 1.0 + row * 1.0, 10.0), Color("eceff1") if row % 2 == 0 else Color("b0bec5"), Vector3(side * row * 2.0, (1.0 + row) * 0.5, 0))
		var count := 24
		var body_mesh := CapsuleMesh.new()
		body_mesh.radius = 0.28
		body_mesh.height = 0.9
		body_mesh.radial_segments = 8
		body_mesh.rings = 3
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.24
		head_mesh.height = 0.48
		head_mesh.radial_segments = 8
		head_mesh.rings = 4
		var bodies := MultiMesh.new()
		bodies.transform_format = MultiMesh.TRANSFORM_3D
		bodies.use_colors = true
		bodies.mesh = body_mesh
		bodies.instance_count = count
		var heads := MultiMesh.new()
		heads.transform_format = MultiMesh.TRANSFORM_3D
		heads.mesh = head_mesh
		heads.instance_count = count
		var base: Array = []
		for i in count:
			var row := i % 3
			var p := Vector3(side * row * 2.0, 1.0 + row * 1.0 + 0.45, -4.4 + (i / 3) * 1.25 + _rng.randf_range(-0.2, 0.2))
			base.append(p)
			bodies.set_instance_transform(i, Transform3D(Basis(), p))
			bodies.set_instance_color(i, palette[_rng.randi() % palette.size()])
			heads.set_instance_transform(i, Transform3D(Basis(), p + Vector3.UP * 0.55))
		var body_material := Mat.toon(Color.WHITE).duplicate() as StandardMaterial3D
		body_material.vertex_color_use_as_albedo = true
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = bodies
		mmi.material_override = body_material
		root.add_child(mmi)
		var hmi := MultiMeshInstance3D.new()
		hmi.multimesh = heads
		hmi.material_override = Mat.toon(Color("ffcc99"))
		root.add_child(hmi)
		_crowds.append({"bodies": bodies, "heads": heads, "base": base})


func _build_lights(samples: Array) -> void:
	var palette: Array = _theme.palette
	var i := 0
	for sample in samples:
		for side in [-1.0, 1.0]:
			var point: Vector3 = sample.pos + sample.right * side * 10.0
			if not _clear_of_route(point, 7.0):
				continue
			Build.cylinder(self, 0.08, 3.5, Color("455a64"), point + Vector3(0, 0.55, 0))
			var bulb := Build.sphere(self, 0.28, palette[i % palette.size()], point + Vector3(0, 2.4, 0))
			bulb.material_override = Mat.glow(palette[i % palette.size()], 3.0)
			i += 1
