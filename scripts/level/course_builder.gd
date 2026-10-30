class_name CourseBuilder
extends RefCounted
## Gera o percurso de uma fase a partir do número dela (fases infinitas).
## O mesmo número sempre gera a mesma fase (o número é a "semente" do
## sorteio). A dificuldade cresce aos poucos e novos trechos são liberados.
##
## Cada trecho é montado no seu próprio referencial ("frame"): andando para
## -Z local, com "z" sendo a borda da última peça. Curvas e tobogãs giram o
## referencial, por isso o percurso faz curvas de verdade. "y" é a altura do
## chão (a água fica em y = -1.2).

const WATER_Y := -1.2
const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const FLOW_SHADER := preload("res://shaders/water_flow.gdshader")
## Altura do piso do túnel submerso.
const TUNNEL_FLOOR := -4.6

## Fase mínima para cada tipo de trecho aparecer.
const UNLOCK := {
	"hops": 1, "sweeper": 1, "slide": 1, "stairs": 1, "waterslide": 1,
	"spiral": 1, "climb": 1, "floats": 1,
	"hammers": 2, "moving": 2, "bounce": 2, "serpentine": 2, "bumpers": 2, "tunnel": 2,
	"vanishing": 3, "logs": 3, "coaster": 3, "windmill": 3,
	"pushers": 4, "fans": 4,
	"balls": 5, "elevators": 5,
	"discs": 6, "ramp": 6,
	"conveyor": 7, "beams": 7,
	"geysers": 8, "drum": 9,
}

var course: Node3D
var root: Node3D
var rng := RandomNumberGenerator.new()
var level := 1
var difficulty := 0.0
var palette: Array = []
var z := 0.0
var y := 0.0
var x := 0.0
var par_time := 0.0
var spawn := Vector3.ZERO
var finish_gate: FinishGate
var checkpoints: Array[Checkpoint] = []
var segments: Array[String] = []
## Posição global do início de cada trecho (testes automáticos).
var debug_marks: Array = []
## Rota em ordem (pontos globais) e perigos: usados pelos rivais e pelo HUD.
var waypoints: Array[Vector3] = []
var hammers: Array[PendulumHammer] = []
var sweepers: Array[Sweeper] = []
var rollers: Array[BallRoller] = []
var pushers: Array[Pusher] = []
## Outros perigos com is_dangerous() (moinhos): os rivais esperam.
var hazards: Array[Node3D] = []

var _color_index := 0
var _yaw := 0.0
var _flow_material: ShaderMaterial
var _glass_material: StandardMaterial3D


func build(parent: Node3D, level_number: int, theme: Dictionary) -> Dictionary:
	course = parent
	level = level_number
	palette = theme.palette
	rng.seed = hash("aqua_caos_fase_%d" % level)
	# Sobe aos poucos até a fase ~40 e depois estabiliza (sempre jogável).
	difficulty = clampf((level - 1) / 40.0, 0.0, 0.9)

	_open_frame(Transform3D.IDENTITY)
	_start()
	var plan := _plan()
	for i in plan.size():
		_advance_frame()
		debug_marks.append([root.global_position if root.is_inside_tree() else root.position, plan[i], waypoints.size()])
		call("_seg_" + plan[i])
		segments.append(plan[i])
		if i < plan.size() - 1 and (i + 1) % 3 == 0:
			_advance_frame()
			_checkpoint()
	_advance_frame()
	_finish()

	return {
		"spawn": spawn,
		"par_time": snappedf(par_time, 0.5),
		"segments": segments,
		"waypoints": waypoints,
	}


func _plan() -> Array[String]:
	match level:
		1:
			return ["hops", "climb", "curve", "sweeper", "spiral", "hill", "floats", "hops"]
		2:
			return ["bumpers", "hill", "waterslide", "curve", "hammers", "tunnel", "stairs", "moving"]
		3:
			return ["floats", "coaster", "curve", "vanishing", "windmill", "hill", "logs", "spiral"]
	var pool: Array[String] = []
	for kind in UNLOCK:
		if level >= UNLOCK[kind]:
			pool.append(kind)
	var count := 5 + mini(level / 4, 6)
	var plan: Array[String] = []
	# A fase sempre traz o tipo de trecho liberado mais recentemente.
	for kind in UNLOCK:
		if UNLOCK[kind] == level:
			plan.append(kind)
	# Sorteio sem repetir enquanto houver tipos novos (cada fase bem diferente).
	var bag: Array[String] = []
	while plan.size() < count:
		if bag.is_empty():
			bag = pool.duplicate()
			for i in range(bag.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var tmp := bag[i]
				bag[i] = bag[j]
				bag[j] = tmp
		var kind: String = bag.pop_back()
		if not plan.has(kind) or pool.size() <= plan.size():
			plan.append(kind)
	# Entre os trechos: curvas e morros (o percurso sobe e desce bastante).
	var result: Array[String] = []
	for i in plan.size():
		result.append(plan[i])
		if i < plan.size() - 1:
			var r := rng.randf()
			if r < 0.4:
				result.append("curve")
			elif r < 0.75:
				result.append("hill")
	return result


# --- Referenciais (frames) ----------------------------------------------------------------

func _open_frame(transform: Transform3D) -> void:
	var frame := Node3D.new()
	frame.transform = transform
	course.add_child(frame)
	root = frame
	z = 0.0
	x = 0.0


## Continua em frente a partir da borda atual.
func _advance_frame() -> void:
	_open_frame(root.transform * Transform3D(Basis(), Vector3(0, 0, z)))


## Converte um ponto do referencial atual para global.
func _global(local: Vector3) -> Vector3:
	return root.transform * local


func _waypoint(local: Vector3) -> void:
	waypoints.append(_global(local))


## Escolhe o lado da curva sem deixar o percurso voltar para trás.
func _turn_sign(angle: float) -> float:
	var turn := 1.0 if rng.randf() < 0.5 else -1.0
	if absf(_yaw + turn * angle) > deg_to_rad(100.0):
		turn = -turn
	return turn


# --- Peças básicas -------------------------------------------------------------------------

func _next_color() -> Color:
	var color: Color = palette[_color_index % palette.size()]
	_color_index += 1
	return color


## Plataforma com topo em "top" (centro, local). Colunas até a água.
func _platform(top: Vector3, size: Vector3, color := Color(0, 0, 0, 0), slippery := false, pillars := true) -> StaticBody3D:
	if color.a == 0.0:
		color = _next_color()
	var body := Build.solid_box(root, size, top, color)
	_waypoint(top)
	Build.box(body, Vector3(size.x + 0.06, 0.14, size.z + 0.06), color.lightened(0.2), Vector3(0, size.y * 0.5 - 0.06, 0))
	if slippery:
		body.add_to_group("slippery")
		for i in int(size.z / 1.6):
			Build.box(body, Vector3(size.x * 0.7, 0.02, 0.18), Color("e1f5fe"), Vector3(0, size.y * 0.5 + 0.01, -size.z * 0.5 + 0.8 + i * 1.6))
	if pillars:
		_pillars(top + Vector3(0, -size.y, 0), size.x)
	return body


func _pillars(bottom_center: Vector3, width: float) -> void:
	var height := bottom_center.y - WATER_Y + 2.0
	if height <= 0.2:
		return
	for side in [-1.0, 1.0]:
		var px: float = bottom_center.x + side * maxf(width * 0.5 - 0.6, 0.0)
		Build.cylinder(root, 0.22, height, Color("90a4ae"), Vector3(px, bottom_center.y - height * 0.5, bottom_center.z))
		if width < 1.6:
			break


func _landing(length := 5.0, gap := 1.6) -> void:
	var top := Vector3(0, y, z - gap - length * 0.5)
	_platform(top, Vector3(10, 1, length))
	# Às vezes um esguicho cruza por cima da plataforma.
	if rng.randf() < 0.35:
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		_jet(side, top + Vector3(side * 4.4, 0, 0), 8.8)
	_coin_line(Vector3(0, y + 1.0, z - gap - 1.0), Vector3(0, y + 1.0, z - gap - length + 1.0), 3)
	z -= gap + length
	x = 0.0
	par_time += (gap + length) / 6.5


func _coin(position: Vector3) -> void:
	var coin := Coin.new()
	coin.position = position
	root.add_child(coin)


func _coin_line(from: Vector3, to: Vector3, count: int) -> void:
	for i in count:
		var k := 0.5 if count == 1 else float(i) / (count - 1)
		_coin(from.lerp(to, k))


## Placa de dica. "key" é a chave de tradução (veja assets/i18n).
func _sign(position: Vector3, key: String) -> void:
	var label := Label3D.new()
	label.text = key
	label.font = FONT
	label.font_size = 64
	label.outline_size = 16
	label.modulate = Color("fffde7")
	label.outline_modulate = Color("1a2340")
	label.pixel_size = 0.0045
	label.position = position + Vector3(0, 1.2, 0)
	root.add_child(label)


## Peça inclinada entre dois pontos (locais, centro do topo), com bordas.
## hidden: só a colisão do piso (usado sob os degraus das escadas).
func _ramp_piece(from: Vector3, to: Vector3, width: float, color: Color, slippery: bool, rail_height: float, hidden := false) -> StaticBody3D:
	var thickness := 0.6
	var direction := to - from
	var length := direction.length() + 0.35
	var basis := Basis.looking_at(direction.normalized(), Vector3.UP)
	var body := StaticBody3D.new()
	body.transform = Transform3D(basis, (from + to) * 0.5 - basis.y * thickness * 0.5)
	root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, thickness, length)
	shape.shape = box
	body.add_child(shape)
	if not hidden:
		Build.box(body, Vector3(width, thickness, length), color, Vector3.ZERO, true)
	if slippery:
		body.add_to_group("slippery")
		_flowing_water(body, Vector3(width * 0.85, 0.04, length), Vector3(0, thickness * 0.5 + 0.02, 0))
	if rail_height > 0.0:
		for side in [-1.0, 1.0]:
			var rail_shape := CollisionShape3D.new()
			var rail_box := BoxShape3D.new()
			rail_box.size = Vector3(0.3, rail_height, length)
			rail_shape.shape = rail_box
			rail_shape.position = Vector3(side * (width * 0.5 + 0.15), thickness * 0.5 + rail_height * 0.5 - 0.1, 0)
			body.add_child(rail_shape)
			Build.box(body, Vector3(0.3, rail_height, length), Color("fdd835"), rail_shape.position)
	return body


## Lâmina de água descendo a rampa (espuma animada).
func _flowing_water(parent: Node3D, size: Vector3, position: Vector3) -> void:
	if _flow_material == null:
		_flow_material = ShaderMaterial.new()
		_flow_material.shader = FLOW_SHADER
	var mesh := BoxMesh.new()
	mesh.size = size
	var water := MeshInstance3D.new()
	water.mesh = mesh
	water.material_override = _flow_material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = position
	parent.add_child(water)


## Anel colorido em volta do toboágua (cara de tubo, sem tampar a visão).
func _tube_ring(from: Vector3, to: Vector3, width: float, color: Color) -> void:
	var ring := Build.torus(root, width * 0.5 + 0.55, width * 0.5 + 0.85, color, (from + to) * 0.5)
	var forward := (to - from).normalized()
	ring.basis = Basis.looking_at(forward, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
	ring.position += Vector3.UP * (width * 0.5 + 0.1)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Respingo contínuo (saída de toboágua, chafarizes). Desligado nos gráficos leves.
func _splash_fx(position: Vector3, amount := 16, strength := 1.0) -> void:
	if Game.low_graphics():
		return
	var particles := CPUParticles3D.new()
	var drop := SphereMesh.new()
	drop.radius = 0.09
	drop.height = 0.18
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = Mat.unshaded(Color("e1f5fe"))
	particles.mesh = drop
	particles.amount = amount
	particles.lifetime = 0.9
	particles.direction = Vector3.UP
	particles.spread = 35.0
	particles.initial_velocity_min = 2.5 * strength
	particles.initial_velocity_max = 5.0 * strength
	particles.gravity = Vector3(0, -12, 0)
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.7
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.5
	particles.position = position
	root.add_child(particles)


## Balde gigante que enche e vira (enfeite). "yaw" aponta a cascata.
func _bucket(position: Vector3, yaw: float) -> void:
	var bucket := TippingBucket.new()
	bucket.color = _next_color()
	bucket.position = position
	bucket.rotation.y = yaw
	bucket.scale = Vector3.ONE * 1.3
	root.add_child(bucket)


## Esguicho: jato de água em arco que cruza por cima do percurso (enfeite).
func _jet(side: float, position: Vector3, reach: float) -> void:
	var nozzle := Build.cylinder(root, 0.25, 0.9, Color("eceff1"), position + Vector3(0, 0.45, 0), 0.15, true)
	Build.sphere(nozzle, 0.22, _next_color(), Vector3(0, 0.5, 0))
	if Game.low_graphics():
		return
	var stream := CPUParticles3D.new()
	var drop := SphereMesh.new()
	drop.radius = 0.11
	drop.height = 0.22
	drop.radial_segments = 6
	drop.rings = 3
	drop.material = Mat.unshaded(Color(0.7, 0.92, 1.0, 0.9))
	stream.mesh = drop
	stream.amount = 36
	stream.lifetime = 1.4
	stream.direction = Vector3(-side, 1.15, 0).normalized()
	stream.spread = 3.0
	var speed := sqrt(reach * 9.8 / 0.98)
	stream.initial_velocity_min = speed * 0.97
	stream.initial_velocity_max = speed * 1.03
	stream.gravity = Vector3(0, -9.8, 0)
	stream.scale_amount_min = 0.8
	stream.scale_amount_max = 1.3
	stream.position = position + Vector3(0, 1.0, 0)
	root.add_child(stream)


## Rampa reta. drop > 0 desce, drop < 0 sobe. Começa na borda "z" atual.
func _slope(length: float, drop: float, width: float, slippery: bool, color: Color) -> void:
	var from := Vector3(0, y, z)
	var to := Vector3(0, y - drop, z - length)
	_ramp_piece(from, to, width, color, slippery, 0.8)
	_waypoint((from + to) * 0.5)
	for i in 3:
		var k := (i + 0.5) / 3.0
		_pillars(Vector3(0, y - drop * k - 0.6, z - length * k), width)


## Arco (curva) a partir da borda atual. Gira o referencial no final.
## turn: +1 esquerda, -1 direita. drop: quanto desce ao longo do arco.
func _arc(radius: float, angle: float, turn: float, width: float, drop: float, slippery: bool, rail_height: float, color: Color, tube := false, pillar_skip := 0.0) -> void:
	var steps := maxi(4, int(angle / deg_to_rad(11.0)))
	var start_y := y
	var origin := Vector3(0, 0, z)
	var previous := origin + Vector3(0, start_y, 0)
	for i in steps:
		var phi := angle * (i + 1) / steps
		var point := origin + Vector3(turn * (-radius + radius * cos(phi)), start_y - drop * (i + 1) / steps, -radius * sin(phi))
		_ramp_piece(previous, point, width, color if i % 2 == 0 else color.lightened(0.15), slippery, rail_height)
		_waypoint((previous + point) * 0.5)
		if tube and i % 2 == 1:
			_tube_ring(previous, point, width, color.lightened(0.35))
		if i % 2 == 0 and phi > pillar_skip:
			_pillars(Vector3(point.x, point.y - 0.6, point.z), width * 0.5)
		if i % 2 == 1:
			_coin(point + Vector3(0, 1.0, 0))
		previous = point
	var end := origin + Vector3(turn * (-radius + radius * cos(angle)), 0, -radius * sin(angle))
	y = start_y - drop
	_yaw = wrapf(_yaw + turn * angle, -PI, PI)
	_open_frame(root.transform * Transform3D(Basis(Vector3.UP, turn * angle), end))
	par_time += radius * angle / 6.5


# --- Trechos fixos --------------------------------------------------------------------------

func _start() -> void:
	_platform(Vector3(0, 0, -5), Vector3(12, 1, 14), palette[0])
	spawn = Vector3(0, 0.1, 0.0)
	for side in [-1.0, 1.0]:
		Build.cylinder(root, 0.3, 4.6, Color("eceff1"), Vector3(side * 5.0, 2.3, -3.0), -1.0, true)
	Build.box(root, Vector3(10.6, 1.1, 0.5), palette[1], Vector3(0, 4.8, -3.0), true)
	_sign(Vector3(0, 4.8, -2.7), "SIGN_START")
	_coin_line(Vector3(0, 1.0, -6.0), Vector3(0, 1.0, -10.5), 3)
	_bucket(Vector3(-8.0, 0, -15.0), PI * 0.5)
	z = -12.0
	y = 0.0
	par_time += 2.0


func _checkpoint() -> void:
	_platform(Vector3(0, y, z - 2.5), Vector3(10, 1, 5))
	var cp := Checkpoint.new()
	cp.width = 9.0
	cp.position = Vector3(0, y, z - 2.5)
	root.add_child(cp)
	checkpoints.append(cp)
	z -= 5.0
	x = 0.0
	par_time += 5.0 / 7.0


func _finish() -> void:
	_platform(Vector3(0, y, z - 8.0), Vector3(14, 1, 16), palette[0])
	finish_gate = FinishGate.new()
	finish_gate.position = Vector3(0, y, z - 5.0)
	root.add_child(finish_gate)
	_bucket(Vector3(10.5, y, z - 13.0), -PI * 0.5)
	for side in [-1.0, 1.0]:
		_jet(side, Vector3(side * 6.4, y, z - 2.0), 12.0)
	z -= 16.0
	par_time += 5.0 / 7.0


# --- Trechos sorteados ------------------------------------------------------------------------

func _seg_curve() -> void:
	var angle := deg_to_rad(rng.randf_range(40.0, 80.0))
	var turn := _turn_sign(angle)
	var width := lerpf(5.0, 3.6, difficulty)
	# Curvas sobem e descem bastante (até ~4 m de altura).
	var drop := rng.randf_range(-1.8, 1.4) if level > 1 else 0.0
	drop = clampf(drop, y - 4.0, y + 0.4)
	_arc(rng.randf_range(8.0, 12.0), angle, turn, width, drop, false, 0.0, _next_color())


func _seg_serpentine() -> void:
	# Tobogã: sobe a torre e desce escorregando em zigue-zague com curvas.
	var climb := 4.2
	var steps := 4
	for i in steps:
		y += climb / steps
		_platform(Vector3(0, y, z - 1.25), Vector3(6, y + 2.4, 2.5), Color(0, 0, 0, 0), false, false)
		z -= 2.5
	_platform(Vector3(0, y, z - 1.5), Vector3(6, y + 2.4, 3), Color(0, 0, 0, 0), false, false)
	z -= 3.0
	if level <= 3:
		_sign(Vector3(0, y + 2.6, z - 0.5), "SIGN_SLIDE")
	var bends := 2 + (1 if difficulty > 0.4 else 0)
	var total_drop := climb + 0.3
	var color := _next_color()
	var turn := _turn_sign(deg_to_rad(55.0))
	for i in bends:
		var angle := deg_to_rad(rng.randf_range(45.0, 65.0))
		_arc(rng.randf_range(7.0, 9.0), angle, turn, 4.4, total_drop / bends, true, 1.1, color)
		turn = -turn
	_splash_pool()
	par_time += 14.0 / 7.0 + bends * 2.0
	_landing(6.0, 0.0)


func _seg_hops() -> void:
	var count := 4 + int(difficulty * 3.0) + rng.randi() % 2
	for i in count:
		var gap := lerpf(1.6, 3.0, difficulty) + rng.randf() * 0.5
		var width := rng.randf_range(3.0, 4.5) - difficulty
		var length := rng.randf_range(2.8, 4.0) - difficulty * 0.6
		var nx := clampf(x + rng.randf_range(-1.0, 1.0) * (1.0 + 2.0 * difficulty), -4.0, 4.0)
		var ny := clampf(y + rng.randf_range(-0.4, 0.7), -0.4, 2.2)
		var center_z := z - gap - length * 0.5
		_platform(Vector3(nx, ny, center_z), Vector3(width, 0.8, length))
		_coin(Vector3((x + nx) * 0.5, maxf(y, ny) + 1.7, z - gap * 0.5))
		z = center_z - length * 0.5
		x = nx
		y = ny
		par_time += (gap + length) / 6.5 + 0.2
	_landing(5.0, 1.6)


func _seg_sweeper() -> void:
	var radius := 5.0 + difficulty * 1.5
	_platform(Vector3(0, y, z - 1.5), Vector3(3, 1, 3))
	z -= 3.0
	var center := Vector3(0, y, z - radius - 0.8)
	var disc := Build.solid_cylinder(root, radius + 0.8, 1.0, center, _next_color())
	Build.cylinder(disc, radius + 0.85, 0.14, Color.WHITE, Vector3(0, 0.44, 0))
	Build.cylinder(disc, radius + 0.1, 0.16, _next_color(), Vector3(0, 0.45, 0))
	_pillars(center + Vector3(0, -1, 0), radius)
	var sweeper := Sweeper.new()
	sweeper.radius = radius
	sweeper.speed = (1.0 + 1.3 * difficulty) * (1.0 if rng.randf() < 0.5 else -1.0)
	sweeper.bars = 1 if difficulty < 0.35 else 2
	sweeper.position = center
	root.add_child(sweeper)
	sweepers.append(sweeper)
	_waypoint(center + Vector3(0, 0, radius * 0.5))
	_waypoint(center - Vector3(0, 0, radius * 0.5))
	for i in 6:
		var a := i * TAU / 6.0
		_coin(center + Vector3(cos(a) * radius * 0.6, 1.3, sin(a) * radius * 0.6))
	if level <= 2:
		_sign(center + Vector3(0, 3.6, -radius - 0.5), "SIGN_SWEEPER")
	z = center.z - radius - 0.8
	_platform(Vector3(0, y, z - 1.5), Vector3(3, 1, 3))
	z -= 3.0
	par_time += (radius * 2.0 + 6.0) / 6.0 + 1.5


func _seg_hammers() -> void:
	var count := 2 + int(difficulty * 3.0)
	var spacing := 4.5
	var length := count * spacing + 3.0
	_platform(Vector3(0, y, z - length * 0.5), Vector3(3.2, 1, length))
	for i in count:
		var hz := z - 2.5 - i * spacing
		var hammer := PendulumHammer.new()
		hammer.arm_length = 4.0
		hammer.period = lerpf(2.8, 2.0, difficulty)
		hammer.phase = i * 0.37 + rng.randf() * 0.2
		hammer.color = _next_color()
		hammer.position = Vector3(0, y + 4.9, hz)
		root.add_child(hammer)
		hammers.append(hammer)
		_coin(Vector3(0, y + 1.0, hz - spacing * 0.5))
	if level <= 3:
		_sign(Vector3(0, y + 6.2, z - 0.5), "SIGN_HAMMER")
	z -= length
	par_time += length / 6.0 + count * 0.8


func _seg_moving() -> void:
	var size := Vector3(3.5, 0.6, 3.5)
	if rng.randf() < 0.4:
		# Plataforma que vai e volta para a frente, atravessando um vão grande.
		var travel := 6.0 + difficulty * 3.0
		var mover := MovingPlatform.new()
		mover.size = size
		mover.travel = Vector3(0, 0, -travel)
		mover.period = lerpf(4.0, 3.0, difficulty)
		mover.color = _next_color()
		mover.position = Vector3(0, y, z - 1.2 - size.z * 0.5)
		root.add_child(mover)
		_waypoint(mover.position)
		_coin_line(Vector3(0, y + 1.0, z - 2.0), Vector3(0, y + 1.0, z - 2.0 - travel), 4)
		z -= 1.2 + size.z + travel
		par_time += mover.period + 1.0
		_landing(5.0, 1.2)
		return
	var count := 2 + int(difficulty * 2.0)
	for i in count:
		var center_z := z - 1.4 - size.z * 0.5
		var travel_x := (3.0 + 1.2 * difficulty) * (1.0 if i % 2 == 0 else -1.0)
		var mover := MovingPlatform.new()
		mover.size = size
		mover.travel = Vector3(travel_x, 0, 0)
		mover.period = lerpf(3.8, 3.0, difficulty)
		mover.phase = 0.0 if i % 2 == 0 else 0.5
		mover.color = _next_color()
		mover.position = Vector3(-travel_x * 0.5, y, center_z)
		root.add_child(mover)
		_waypoint(Vector3(0, y, center_z))
		_coin(Vector3(0, y + 1.6, center_z))
		z = center_z - size.z * 0.5
		par_time += size.z / 6.0 + mover.period * 0.5
	_landing(5.0, 1.4)


func _seg_elevators() -> void:
	# Elevadores: plataformas que sobem e descem até um patamar mais alto.
	var size := Vector3(3.4, 0.6, 3.4)
	var count := 2 + int(difficulty * 1.5)
	for i in count:
		var center_z := z - 1.3 - size.z * 0.5
		var lift := MovingPlatform.new()
		lift.size = size
		lift.travel = Vector3(0, 2.6, 0)
		lift.period = lerpf(4.0, 3.2, difficulty)
		lift.phase = i * 0.33
		lift.color = _next_color()
		lift.stripe_color = Color.WHITE
		lift.position = Vector3(0, y, center_z)
		root.add_child(lift)
		_waypoint(Vector3(0, y + 1.3, center_z))
		_coin(Vector3(0, y + 3.8, center_z))
		z = center_z - size.z * 0.5
		y += 1.3
		par_time += lift.period * 0.6
	if level <= 6:
		_sign(Vector3(0, y + 3.5, z), "SIGN_ELEVATOR")
	_landing(5.0, 1.3)


func _seg_slide() -> void:
	var end_y := maxf(y - 0.9, -0.2)
	for i in 3:
		y += 0.9
		_platform(Vector3(0, y, z - 1.25), Vector3(6, y + 2.4, 2.5), Color(0, 0, 0, 0), false, false)
		z -= 2.5
	_platform(Vector3(0, y, z - 1.5), Vector3(6, y + 2.4, 3), Color(0, 0, 0, 0), false, false)
	z -= 3.0
	var length := 14.0
	var drop := y - end_y
	_slope(length, drop, 5.0, true, _next_color())
	_coin_line(Vector3(0, y + 0.6, z - 3.0), Vector3(0, y - drop + 0.9, z - length + 1.5), 4)
	if level <= 2:
		_sign(Vector3(0, y + 2.6, z - 1.0), "SIGN_SLIDE")
	z -= length
	y -= drop
	_platform(Vector3(0, y, z - 1.5), Vector3(5, 1, 3), Color("4fc3f7"))
	var pad := BouncePad.new()
	pad.position = Vector3(0, y, z - 2.0)
	root.add_child(pad)
	_coin_line(Vector3(0, y + 3.0, z - 4.5), Vector3(0, y + 2.5, z - 7.0), 3)
	z -= 3.0
	par_time += (10.5 + length + 3.0) / 8.0
	_landing(8.0, 4.0)


## Escada de verdade: degraus coloridos com corrimão. A colisão é uma rampa
## invisível por baixo, então dá para subir andando (sem pular cada degrau).
func _stairs(rise: float, width: float) -> void:
	var steps := maxi(4, int(rise / 0.32))
	var step_h := rise / steps
	var step_d := 0.6
	var color := _next_color()
	for i in steps:
		var top := y + step_h * (i + 1)
		var height := top - y + 0.8
		var tread := color if i % 2 == 0 else color.lightened(0.25)
		Build.box(root, Vector3(width, height, step_d), tread, Vector3(0, top - height * 0.5, z - step_d * (i + 0.5)), i % 3 == 0)
		Build.box(root, Vector3(width + 0.04, 0.08, 0.14), Color.WHITE, Vector3(0, top - 0.02, z - step_d * i - 0.08))
		if i % 3 == 1:
			_coin(Vector3(0, top + 1.0, z - step_d * (i + 0.5)))
	var run := steps * step_d
	var from := Vector3(0, y, z + step_d * 0.5)
	var to := Vector3(0, y + rise, z - run + step_d * 0.5)
	_ramp_piece(from, to, width, color, false, 0.0, true)
	# Corrimãos (só enfeite) e pilares embaixo.
	for side in [-1.0, 1.0]:
		var rail := Node3D.new()
		var mid := (from + to) * 0.5 + Vector3(side * (width * 0.5 - 0.1), 1.05, 0)
		rail.transform = Transform3D(Basis.looking_at((to - from).normalized(), Vector3.UP), mid)
		root.add_child(rail)
		Build.box(rail, Vector3(0.14, 0.14, (to - from).length()), Color("fdd835"))
		for k in 4:
			var t := (k + 0.5) / 4.0
			var post := from.lerp(to, t) + Vector3(side * (width * 0.5 - 0.1), 0.5, 0)
			Build.cylinder(root, 0.06, 1.1, Color("eceff1"), post)
	_pillars(Vector3(0, y - 0.8, z - run * 0.5), width)
	_waypoint((from + to) * 0.5)
	z -= run
	y += rise
	par_time += run / 4.0


func _seg_stairs() -> void:
	# Escadaria: sobe bem alto pelos degraus e desce escorregando.
	var rise := rng.randf_range(2.8, 3.6) + difficulty * 1.2
	var width := 5.0
	_platform(Vector3(0, y, z - 1.5), Vector3(width + 1.0, 1, 3))
	z -= 3.0
	if level <= 3:
		_sign(Vector3(0, y + 2.4, z + 0.5), "SIGN_STAIRS")
	_stairs(rise, width)
	# Mirante no topo, com bandeirinhas.
	_platform(Vector3(0, y, z - 2.0), Vector3(width + 1.0, y + 2.0, 4), Color(0, 0, 0, 0), false, false)
	for side in [-1.0, 1.0]:
		Build.cylinder(root, 0.08, 2.4, Color("eceff1"), Vector3(side * (width * 0.5 + 0.2), y + 1.2, z - 2.0))
		Build.box(root, Vector3(0.05, 0.5, 0.8), _next_color(), Vector3(side * (width * 0.5 + 0.2), y + 2.1, z - 2.4))
	_coin_line(Vector3(-1.2, y + 1.0, z - 2.0), Vector3(1.2, y + 1.0, z - 2.0), 3)
	z -= 4.0
	# Descida molhada grande, mais baixa que o começo.
	var drop := clampf(rise + rng.randf_range(0.0, 0.8), 0.0, y + 0.2)
	var length := drop * 3.2 + 4.0
	_slope(length, drop, width, true, _next_color())
	_coin_line(Vector3(0, y + 0.7, z - 2.0), Vector3(0, y - drop + 0.9, z - length + 1.5), 4)
	z -= length
	y -= drop
	_splash_fx(Vector3(0, y + 0.2, z - 1.0), 12, 0.8)
	par_time += 4.0 / 6.0 + length / 9.0
	_landing(6.0, 0.0)


func _seg_waterslide() -> void:
	# Toboágua: torre alta com escada e um tubo colorido cheio de curvas e
	# água correndo, que termina numa piscina de respingos.
	var height := 5.6 + difficulty * 2.4
	var width := 3.6
	_platform(Vector3(0, y, z - 1.5), Vector3(width + 2.0, 1, 3))
	z -= 3.0
	_stairs(height, width)
	# Topo da torre com cobertura listrada.
	var top_z := z - 2.0
	_platform(Vector3(0, y, top_z), Vector3(width + 2.0, y + 2.4, 4), Color(0, 0, 0, 0), false, false)
	var roof_color := _next_color()
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			Build.cylinder(root, 0.12, 2.9, Color("eceff1"), Vector3(cx * (width * 0.5 + 0.7), y + 1.45, top_z + cz * 1.6))
	for i in 5:
		var stripe := roof_color if i % 2 == 0 else Color.WHITE
		Build.box(root, Vector3(width + 2.2, 0.18, 0.84), stripe, Vector3(0, y + 3.0, top_z - 1.68 + i * 0.84), i == 2)
	if level <= 4:
		_sign(Vector3(0, y + 3.6, top_z), "SIGN_WATERSLIDE")
	z -= 4.0
	# Tubo: curvas alternadas que descem toda a altura da torre.
	var bends := 4 + (1 if difficulty > 0.4 else 0)
	var total_drop := clampf(height + 0.3, 0.0, y + 0.2)
	var color := _next_color()
	var turn := _turn_sign(deg_to_rad(60.0))
	for i in bends:
		var angle := deg_to_rad(rng.randf_range(55.0, 75.0))
		_arc(rng.randf_range(6.5, 8.5), angle, turn, width, total_drop / bends, true, 1.5, color, true)
		turn = -turn
	# Piscina de respingos na saída.
	_splash_pool()
	par_time += height / 2.2 + 4.0 / 6.0 + bends * 1.8
	_landing(6.0, 0.0)


## Rampa de subida com jatos de água que empurram para cima (sem escorregar).
func _booster_slope(length: float, rise: float, width: float, color: Color, speed := 6.0) -> void:
	var from := Vector3(0, y, z)
	var to := Vector3(0, y + rise, z - length)
	var body := _ramp_piece(from, to, width, color, false, 1.0)
	body.set_script(BoosterBelt)
	body.set("push", (_global(to) - _global(from)).normalized() * speed)
	_flowing_water(body, Vector3(width * 0.85, 0.04, (to - from).length()), Vector3(0, 0.32, 0))
	for k in 3:
		var t := (k + 0.5) / 3.0
		_pillars(Vector3(0, y + rise * t - 0.6, z - length * t), width)
	_waypoint((from + to) * 0.5)
	_splash_fx(from + Vector3(0, 0.3, -0.6), 10, 0.7)
	z -= length
	y += rise
	par_time += length / 9.0


## Topo de torre com cobertura listrada (toboáguas).
func _tower_top(width: float, sign_key: String) -> void:
	var top_z := z - 2.0
	_platform(Vector3(0, y, top_z), Vector3(width + 2.0, y + 2.4, 4), Color(0, 0, 0, 0), false, false)
	var roof_color := _next_color()
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			Build.cylinder(root, 0.12, 2.9, Color("eceff1"), Vector3(cx * (width * 0.5 + 0.7), y + 1.45, top_z + cz * 1.6))
	for i in 5:
		var stripe := roof_color if i % 2 == 0 else Color.WHITE
		Build.box(root, Vector3(width + 2.2, 0.18, 0.84), stripe, Vector3(0, y + 3.0, top_z - 1.68 + i * 0.84), i == 2)
	if level <= 6:
		_sign(Vector3(0, y + 3.6, top_z), sign_key)
	z -= 4.0


## Piscina de respingos na saída de um toboágua.
func _splash_pool() -> void:
	# Piscina que freia (não escorrega) e com mureta: quem chega rápido não voa longe.
	_platform(Vector3(0, y, z - 2.5), Vector3(8, 1, 5), Color("4fc3f7"))
	for side in [-1.0, 1.0]:
		Build.solid_box(root, Vector3(0.3, 0.6, 5), Vector3(side * 3.85, y + 0.6, z - 2.5), Color.WHITE)
	_splash_fx(Vector3(0, y + 0.2, z - 0.8), 22, 1.0)
	for side in [-1.0, 1.0]:
		Build.torus(root, 0.35, 0.6, Color("ef5350") if side < 0 else Color("ffca28"), Vector3(side * 2.2, y + 0.15, z - 3.2))
	z -= 5.0


## Peça de túnel de vidro (vai para baixo da água). booster > 0: jatos que sobem.
func _tunnel_piece(from: Vector3, to: Vector3, width: float, slippery: bool, booster := 0.0) -> void:
	var body := _ramp_piece(from, to, width, Color("4dd0e1"), slippery, 0.9)
	var direction := to - from
	# Paredes altas invisíveis (o vidro segura o jogador dentro do túnel).
	for side in [-1.0, 1.0]:
		var wall := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(0.3, 3.0, direction.length() + 0.35)
		wall.shape = wall_box
		wall.position = Vector3(side * (width * 0.5 + 0.15), 1.6, 0)
		body.add_child(wall)
	if booster > 0.0:
		body.set_script(BoosterBelt)
		body.set("push", (_global(to) - _global(from)).normalized() * booster)
		_flowing_water(body, Vector3(width * 0.85, 0.04, direction.length()), Vector3(0, 0.32, 0))
	if _glass_material == null:
		_glass_material = StandardMaterial3D.new()
		_glass_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glass_material.albedo_color = Color(0.25, 0.7, 1.0, 0.4)
	var basis := Basis.looking_at(direction.normalized(), Vector3.UP)
	var radius := width * 0.5 + 0.9
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = direction.length() + 0.3
	mesh.radial_segments = 18
	mesh.rings = 1
	mesh.cap_top = false
	mesh.cap_bottom = false
	var glass := MeshInstance3D.new()
	glass.mesh = mesh
	glass.material_override = _glass_material
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.transform = Transform3D(basis * Basis(Vector3.RIGHT, PI * 0.5), (from + to) * 0.5 + Vector3.UP * (radius - 0.9))
	root.add_child(glass)
	var ring := Build.torus(root, radius - 0.1, radius + 0.15, Color("fdd835"), from + Vector3.UP * (radius - 0.9))
	ring.basis = basis * Basis(Vector3.RIGHT, PI * 0.5)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var zone := TunnelZone.new()
	zone.transform = Transform3D(basis, (from + to) * 0.5 + Vector3.UP * 1.4)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width + 1.0, 4.0, direction.length() + 0.6)
	shape.shape = box
	zone.add_child(shape)
	root.add_child(zone)
	_waypoint((from + to) * 0.5)


## Fundo do mar perto do túnel: areia, corais, algas e peixes.
func _seabed(center: Vector3, length: float) -> void:
	var floor_y := TUNNEL_FLOOR - 2.6
	Build.box(root, Vector3(16, 0.4, length + 10), Color("ffe0b2"), Vector3(center.x, floor_y, center.z))
	for i in 14:
		var side := -1.0 if i % 2 == 0 else 1.0
		var p := Vector3(center.x + side * rng.randf_range(3.6, 7.0), floor_y, center.z + rng.randf_range(-length * 0.5, length * 0.5))
		match i % 3:
			0:
				Build.capsule(root, 0.18, rng.randf_range(1.6, 3.2), Color("43a047"), p + Vector3.UP * 1.2)
			1:
				Build.sphere(root, rng.randf_range(0.4, 0.8), [Color("ff7043"), Color("ec407a"), Color("ab47bc")][i % 3], p + Vector3.UP * 0.4, true)
			2:
				var fish := Build.box(root, Vector3(0.25, 0.35, 0.7), [Color("ffca28"), Color("ff7043"), Color("29b6f6")][rng.randi() % 3], p + Vector3.UP * rng.randf_range(1.5, 3.5), true)
				fish.rotation.y = rng.randf() * TAU
	if not Game.low_graphics():
		var bubbles := CPUParticles3D.new()
		var drop := SphereMesh.new()
		drop.radius = 0.08
		drop.height = 0.16
		drop.radial_segments = 6
		drop.rings = 3
		drop.material = Mat.unshaded(Color(0.85, 0.97, 1.0, 0.8))
		bubbles.mesh = drop
		bubbles.amount = 30
		bubbles.lifetime = 3.0
		bubbles.direction = Vector3.UP
		bubbles.spread = 10.0
		bubbles.gravity = Vector3(0, 1.5, 0)
		bubbles.initial_velocity_min = 0.3
		bubbles.initial_velocity_max = 0.8
		bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		bubbles.emission_box_extents = Vector3(6, 0.2, length * 0.5)
		bubbles.position = Vector3(center.x, floor_y + 0.5, center.z)
		root.add_child(bubbles)


func _seg_hill() -> void:
	# Morro: o percurso sobe (rampa ou escada) ou desce escorregando.
	var color := _next_color()
	if y < 3.5 and (y < 0.8 or rng.randf() < 0.55):
		var rise := rng.randf_range(1.6, 3.0)
		if rng.randf() < 0.5:
			_stairs(rise, 5.0)
		else:
			var length := rise / 0.34
			_slope(length, -rise, 5.0, false, color)
			_coin_line(Vector3(0, y + 1.0, z - 1.0), Vector3(0, y + rise + 1.0, z - length + 1.0), 3)
			z -= length
			y += rise
			par_time += length / 5.5
	else:
		var drop := clampf(rng.randf_range(2.0, 3.8), 0.0, y + 0.2)
		var length := drop * 3.0 + 3.0
		_slope(length, drop, 5.0, true, color)
		_coin_line(Vector3(0, y + 0.8, z - 1.5), Vector3(0, y - drop + 0.9, z - length + 1.0), 3)
		z -= length
		y -= drop
		par_time += length / 9.0
	_landing(4.0, 0.0)


func _seg_climb() -> void:
	# Só subida: rampa, curva subindo, escada e jatos até lá no alto.
	var width := 4.6
	var color := _next_color()
	_platform(Vector3(0, y, z - 1.5), Vector3(width + 1.0, 1, 3))
	z -= 3.0
	if level <= 4:
		_sign(Vector3(0, y + 2.4, z + 0.5), "SIGN_CLIMB")
	var scale := 1.0 if y < 2.0 else 0.6
	var rise1 := 1.8 * scale
	_slope(rise1 / 0.33, -rise1, width, false, color)
	_coin_line(Vector3(0, y + 1.0, z - 1.0), Vector3(0, y + rise1 + 1.0, z - rise1 / 0.33 + 1.0), 3)
	z -= rise1 / 0.33
	y += rise1
	_arc(7.0, deg_to_rad(70.0), _turn_sign(deg_to_rad(70.0)), width, -1.4 * scale, false, 0.8, color.lightened(0.1))
	_stairs(2.2 * scale, width)
	_booster_slope(7.0, 1.8 * scale, width, color.lightened(0.2))
	# Mirante no topo, com bandeirinhas.
	_platform(Vector3(0, y, z - 2.0), Vector3(width + 1.0, y + 2.0, 4), Color(0, 0, 0, 0), false, false)
	for side in [-1.0, 1.0]:
		Build.cylinder(root, 0.08, 2.4, Color("eceff1"), Vector3(side * (width * 0.5 + 0.2), y + 1.2, z - 2.0))
		Build.box(root, Vector3(0.05, 0.5, 0.8), _next_color(), Vector3(side * (width * 0.5 + 0.2), y + 2.1, z - 2.4))
	z -= 4.0
	par_time += 3.0
	_landing(4.0, 0.0)


func _seg_spiral() -> void:
	# Toboágua em espiral: torre bem alta, uma volta inteira descendo e saída.
	var base_y := y
	var height := 7.2 + difficulty * 2.0
	var width := 3.6
	_platform(Vector3(0, y, z - 1.5), Vector3(width + 2.0, 1, 3))
	z -= 3.0
	_stairs(height, width)
	_tower_top(width, "SIGN_SPIRAL")
	var color := _next_color()
	# Reta de entrada sem pilares: o fim da espiral passa embaixo dela.
	var from := Vector3(0, y, z)
	var to := Vector3(0, y - 0.6, z - 6.0)
	_ramp_piece(from, to, width, color, true, 1.3)
	_waypoint((from + to) * 0.5)
	z -= 6.0
	y -= 0.6
	var turn := 1.0 if rng.randf() < 0.5 else -1.0
	_arc(5.2, TAU, turn, width, 5.0, true, 1.3, color, false, deg_to_rad(85.0))
	var drop := clampf(y - maxf(base_y - 0.5, 0.0), 0.0, y + 0.2)
	if drop > 0.2:
		var length := drop * 2.8 + 3.0
		_slope(length, drop, width, true, color.lightened(0.2))
		z -= length
		y -= drop
	_splash_pool()
	par_time += height / 2.2 + 8.0
	_landing(6.0, 0.0)


func _seg_coaster() -> void:
	# Montanha-russa aquática: desce, sobe empurrado pelos jatos e desce de novo.
	var width := 4.2
	var color := _next_color()
	_platform(Vector3(0, y, z - 1.5), Vector3(width + 1.0, 1, 3))
	z -= 3.0
	if level <= 6:
		_sign(Vector3(0, y + 2.4, z + 0.5), "SIGN_COASTER")
	var low := maxf(y - 2.5, -0.2)
	var first_drop := y - low
	if first_drop > 0.3:
		var length := first_drop * 3.0 + 3.0
		_slope(length, first_drop, width, true, color)
		z -= length
		y = low
	var rise := rng.randf_range(3.4, 4.4) + difficulty
	_booster_slope(rise * 2.6, rise, width, color.lightened(0.15))
	var turn := _turn_sign(deg_to_rad(70.0))
	_arc(7.5, deg_to_rad(70.0), turn, width, rise * 0.65, true, 1.4, color, true)
	var rise2 := rise * 0.45
	_booster_slope(rise2 * 2.6, rise2, width, color.lightened(0.15))
	var final_drop := clampf(y - maxf(low, 0.0), 0.0, y + 0.2)
	_arc(7.5, deg_to_rad(60.0), -turn, width, final_drop, true, 1.4, color, true)
	_splash_pool()
	par_time += 10.0
	_landing(5.0, 0.0)


func _seg_tunnel() -> void:
	# Túnel de vidro que mergulha embaixo da água e volta subindo com jatos.
	var width := 4.0
	var start_y := y
	_platform(Vector3(0, y, z - 1.5), Vector3(width + 2.0, 1, 3))
	z -= 3.0
	if level <= 6:
		_sign(Vector3(0, y + 2.6, z + 0.5), "SIGN_TUNNEL")
	var drop := y - TUNNEL_FLOOR
	var down := drop * 2.4
	_tunnel_piece(Vector3(0, y, z), Vector3(0, TUNNEL_FLOOR, z - down), width, true)
	z -= down
	y = TUNNEL_FLOOR
	var run := 12.0 + difficulty * 6.0
	_tunnel_piece(Vector3(0, y, z), Vector3(0, y, z - run), width, false)
	_coin_line(Vector3(0, y + 1.0, z - 1.5), Vector3(0, y + 1.0, z - run + 1.5), 5)
	_seabed(Vector3(0, y, z - run * 0.5), run + down)
	z -= run
	var rise := maxf(start_y, 0.0) + 0.2 - y
	var up := rise * 2.6
	_tunnel_piece(Vector3(0, y, z), Vector3(0, y + rise, z - up), width, false, 7.0)
	z -= up
	y += rise
	par_time += (down + run + up) / 7.0
	_landing(5.0, 0.0)


func _seg_floats() -> void:
	# Boias redondas que sobem e descem na água.
	if y > 0.6:
		var drop := y
		var length := drop * 3.0 + 2.0
		_slope(length, drop, 4.5, true, _next_color())
		z -= length
		y = 0.0
	_platform(Vector3(0, y, z - 1.5), Vector3(4, 1, 3))
	z -= 3.0
	if level <= 4:
		_sign(Vector3(0, y + 2.4, z + 0.5), "SIGN_FLOATS")
	var count := 4 + int(difficulty * 3.0)
	for i in count:
		var radius := lerpf(1.5, 1.3, difficulty)
		# Saindo da borda, um pulo correndo alcança 4,3 a 5,1 m: com diâmetro + vão
		# acima de 5,1 m ele cai sempre na boia seguinte (nunca passa dela).
		var gap := 5.2 - radius * 2.0 + rng.randf() * 0.3
		var cx := clampf(x + rng.randf_range(-0.8, 0.8), -2.0, 2.0)
		var center_z := z - gap - radius
		var float_body := BobbingFloat.new()
		float_body.radius = radius
		float_body.amplitude = lerpf(0.2, 0.45, difficulty)
		float_body.period = rng.randf_range(2.0, 3.0)
		float_body.color = _next_color()
		float_body.position = Vector3(cx, -0.25, center_z)
		root.add_child(float_body)
		_waypoint(Vector3(cx, -0.25, center_z))
		_coin(Vector3(cx, 1.2, center_z))
		z = center_z - radius
		x = cx
		par_time += (gap + radius * 2.0) / 6.0 + 0.3
	y = 0.0
	_landing(5.0, 1.0)


func _seg_bumpers() -> void:
	# Fliperama: pinos que arremessam quem encosta, numa plataforma com muretas.
	var width := 9.0
	var length := 14.0 + difficulty * 6.0
	_platform(Vector3(0, y, z - length * 0.5), Vector3(width, 1, length))
	for side in [-1.0, 1.0]:
		Build.solid_box(root, Vector3(0.4, 0.9, length), Vector3(side * (width * 0.5 - 0.2), y + 0.9, z - length * 0.5), Color.WHITE)
	if level <= 4:
		_sign(Vector3(0, y + 2.8, z - 0.5), "SIGN_BUMPERS")
	# Zigue-zague: fileiras com pinos nas laterais e fileiras com um pino no
	# meio, sempre deixando passagem.
	var rows := int((length - 4.0) / 3.4)
	for r in rows:
		var row_z := z - 3.0 - r * 3.4
		var spots := [-2.6, 2.6] if r % 2 == 0 else [0.0]
		for sx in spots:
			var bumper := Bumper.new()
			bumper.color = _next_color()
			bumper.position = Vector3(sx, y, row_z)
			if r % 2 == 1 and rng.randf() < difficulty * 0.8:
				bumper.sway = 1.0
			root.add_child(bumper)
		# Caminho dos rivais: pelo meio nas fileiras laterais, pelo lado na do meio.
		var lane := 0.0 if r % 2 == 0 else (2.4 if r % 4 == 1 else -2.4)
		_waypoint(Vector3(lane, y, row_z))
		_coin(Vector3(lane, y + 1.0, row_z))
	_waypoint(Vector3(0, y, z - length + 1.0))
	z -= length
	par_time += length / 4.5


func _seg_windmill() -> void:
	# Moinhos gigantes: pás girando atravessam a passarela.
	var count := 1 + int(difficulty * 2.5)
	var spacing := 6.5
	var length := count * spacing + 3.0
	_platform(Vector3(0, y, z - length * 0.5), Vector3(4.2, 1, length))
	if level <= 5:
		_sign(Vector3(0, y + 5.2, z - 0.5), "SIGN_WINDMILL")
	for i in count:
		var mill := Windmill.new()
		mill.speed = (0.16 + 0.1 * difficulty) * (1.0 if rng.randf() < 0.5 else -1.0)
		mill.color = _next_color()
		mill.position = Vector3(0, y, z - 3.5 - i * spacing)
		root.add_child(mill)
		hazards.append(mill)
		_coin(Vector3(0, y + 1.0, z - 3.5 - i * spacing - spacing * 0.5))
	_waypoint(Vector3(0, y, z - length * 0.5))
	z -= length
	par_time += length / 6.0 + count * 1.0


func _seg_ramp() -> void:
	# Rampa de salto: corre, decola e voa por cima de um vão enorme.
	_platform(Vector3(0, y, z - 3.0), Vector3(5, 1, 6))
	z -= 6.0
	var ramp := JumpRamp.new()
	ramp.color = _next_color()
	ramp.position = Vector3(0, y, z)
	root.add_child(ramp)
	_waypoint(Vector3(0, y + 0.7, z - 2.0))
	z -= 4.0
	var gap := 7.5 + difficulty * 2.5
	for i in 5:
		var k := (i + 1) / 6.0
		_coin(Vector3(0, y + 1.4 + sin(k * PI) * 4.0, z - gap * k))
	if level <= 7:
		_sign(Vector3(0, y + 3.5, z + 4.0), "SIGN_RAMP")
	par_time += 3.0
	_landing(10.0, gap)


func _seg_bounce() -> void:
	# Um quique leva ~7 m para a frente segurando o direcional.
	var count := 3 + int(difficulty * 2.0)
	var spacing := 7.0
	var pad_z := z - 3.5
	var first_z := pad_z
	for i in count:
		var px := rng.randf_range(-1.5, 1.5) * difficulty
		var pad := BouncePad.new()
		pad.radius = 1.4
		pad.color = _next_color()
		pad.position = Vector3(px, y, pad_z)
		root.add_child(pad)
		_waypoint(pad.position)
		_pillars(Vector3(px, y - 0.5, pad_z), 1.0)
		_coin(Vector3(px, y + 3.6, pad_z - spacing * 0.5))
		z = pad_z - 1.4
		pad_z -= spacing
	if level <= 3:
		_sign(Vector3(0, y + 3.4, first_z - 2.0), "SIGN_BOUNCE")
	par_time += count * 1.0 + 1.0
	_landing(9.0, 3.2)


func _seg_vanishing() -> void:
	var rows := 4 + int(difficulty * 4.0)
	var spacing := 2.5
	var color := _next_color()
	var keep := 1
	for r in rows:
		var row_z := z - 1.0 - 1.1 - r * spacing
		# O caminho garantido muda no máximo uma coluna por fileira.
		keep = clampi(keep + rng.randi_range(-1, 1), 0, 2)
		for c in 3:
			if c != keep and rng.randf() < 0.18 * difficulty:
				continue
			var tile := VanishingTile.new()
			tile.color = color if (r + c) % 2 == 0 else color.lightened(0.3)
			tile.warn_time = lerpf(0.6, 0.35, difficulty)
			tile.position = Vector3((c - 1) * spacing, y, row_z)
			root.add_child(tile)
			if c == keep:
				_waypoint(tile.position)
			if rng.randf() < 0.25:
				_coin(tile.position + Vector3(0, 1.0, 0))
	if level <= 4:
		_sign(Vector3(0, y + 2.8, z - 1.0), "SIGN_VANISH")
	z -= 1.0 + rows * spacing - 0.3
	par_time += rows * spacing / 6.0
	_landing(5.0, 1.0)


func _seg_logs() -> void:
	# Rolos giratórios sobre a água: arrastam para trás, pule de um para outro.
	var count := 3 + int(difficulty * 3.0)
	var radius := 0.9
	var log_z := z - 1.2 - radius
	for i in count:
		var roll := LogRoller.new()
		roll.radius = radius
		roll.length = lerpf(5.0, 3.6, difficulty)
		roll.surface_speed = 1.8 + difficulty * 2.0
		roll.color = _next_color()
		roll.position = Vector3(0, y - radius, log_z)
		root.add_child(roll)
		_waypoint(Vector3(0, y, log_z))
		_coin(Vector3(0, y + 1.6, log_z - 1.1))
		z = log_z - radius
		log_z -= radius * 2.0 + lerpf(1.2, 1.9, difficulty)
		par_time += 1.0
	if level <= 4:
		_sign(Vector3(0, y + 2.6, z + count * 2.5), "SIGN_LOGS")
	# Plataforma encostada no último rolo: quem pula correndo não cai no vão.
	_landing(5.0, 0.3)


func _seg_drum() -> void:
	# Tambor gigante girando: empurra para o lado enquanto você atravessa.
	var length := 12.0 + difficulty * 4.0
	var drum := SpinningDrum.new()
	drum.radius = 1.6
	drum.length = length
	drum.surface_speed = (1.6 + difficulty * 1.6) * (1.0 if rng.randf() < 0.5 else -1.0)
	drum.color = _next_color()
	drum.position = Vector3(0, y - 1.6, z - 1.0 - length * 0.5)
	root.add_child(drum)
	_waypoint(Vector3(0, y, z - 1.0 - length * 0.3))
	_waypoint(Vector3(0, y, z - 1.0 - length * 0.7))
	_coin_line(Vector3(0, y + 1.0, z - 3.0), Vector3(0, y + 1.0, z - length), 4)
	if level <= 10:
		_sign(Vector3(0, y + 2.8, z - 0.5), "SIGN_DRUM")
	z -= 1.0 + length
	par_time += length / 5.5
	_landing(5.0, 1.0)


func _seg_fans() -> void:
	var length := 16.0
	_platform(Vector3(0, y, z - length * 0.5), Vector3(3.4, 1, length))
	var count := 2 + int(difficulty * 2.0)
	for i in count:
		var direction := 1.0 if i % 2 == 0 else -1.0
		var fan := WindFan.new()
		fan.direction = direction
		fan.width = 4.0
		fan.strength = 3.2 + difficulty * 3.0
		fan.time_offset = rng.randf() * 3.0
		fan.position = Vector3(-direction * 1.7, y, z - length * (i + 1) / (count + 1.0))
		root.add_child(fan)
		_coin(Vector3(0, y + 1.0, fan.position.z))
	if level <= 5:
		_sign(Vector3(0, y + 3.0, z - 0.5), "SIGN_FANS")
	z -= length
	par_time += length / 6.0 + 1.0


func _seg_beams() -> void:
	# Vigas estreitas em zigue-zague, com piso pequeno nas viradas.
	var count := 3 + int(difficulty * 2.0)
	var width := lerpf(1.3, 0.9, difficulty)
	var side := 1.0 if rng.randf() < 0.5 else -1.0
	var start := Vector3(0, y, z)
	var color := _next_color()
	for i in count:
		var finish := Vector3(side * 2.2, y, start.z - 4.5)
		_ramp_piece(start, finish, width, color, false, 0.0)
		_waypoint((start + finish) * 0.5)
		Build.solid_box(root, Vector3(1.8, 0.6, 1.8), finish, color.lightened(0.25))
		_pillars(finish + Vector3(0, -0.6, 0), 1.0)
		_waypoint(finish)
		_coin(finish + Vector3(0, 1.0, 0))
		start = finish
		side = -side
		par_time += 1.0
	z = start.z
	x = start.x
	if level <= 8:
		_sign(Vector3(0, y + 2.6, -0.5), "SIGN_BEAMS")
	_landing(5.0, 1.2)


func _seg_pushers() -> void:
	var length := 16.0
	var count := 3 + int(difficulty * 2.0)
	_platform(Vector3(0, y, z - length * 0.5), Vector3(4, 1, length))
	for i in count:
		var direction := 1.0 if i % 2 == 0 else -1.0
		var pusher := Pusher.new()
		pusher.direction = direction
		pusher.reach = 2.8 + difficulty
		pusher.period = lerpf(2.6, 1.9, difficulty)
		pusher.time_offset = rng.randf() * pusher.period
		pusher.color = _next_color()
		var pz := z - length * (i + 1) / (count + 1.0)
		pusher.position = Vector3(-direction * 2.0, y, pz)
		root.add_child(pusher)
		pushers.append(pusher)
		_coin(Vector3(direction * 1.0, y + 1.0, pz - 1.5))
	z -= length
	par_time += length / 6.0 + 1.5


func _seg_balls() -> void:
	var length := 16.0
	var rise := 2.5
	_slope(length, -rise, 6.0, false, _next_color())
	_coin_line(Vector3(-1.5, y + 1.0, z - 2.0), Vector3(1.5, y + rise + 1.0, z - length + 1.0), 5)
	z -= length
	y += rise
	_platform(Vector3(0, y, z - 3.0), Vector3(8, 1, 6))
	var roller := BallRoller.new()
	roller.interval = lerpf(2.2, 1.6, difficulty)
	roller.spread = 2.0
	roller.despawn_distance = length + 1.5
	roller.position = Vector3(0, y, z - 1.5)
	root.add_child(roller)
	rollers.append(roller)
	if level <= 6:
		_sign(Vector3(0, y + 4.2, z - 1.5), "SIGN_BALLS")
	z -= 6.0
	par_time += length / 5.0 + 2.5


func _seg_discs() -> void:
	var count := 2 + int(difficulty * 2.0)
	var radius := 3.0
	for i in count:
		var center_z := z - 1.3 - radius
		var disc := SpinningDisc.new()
		disc.radius = radius
		disc.speed = (0.7 + difficulty * 0.8) * (1.0 if i % 2 == 0 else -1.0)
		disc.color = _next_color()
		disc.position = Vector3(0, y, center_z)
		root.add_child(disc)
		_waypoint(disc.position)
		_pillars(Vector3(0, y - 0.6, center_z), 0.5)
		_coin(Vector3(0, y + 1.0, center_z))
		z = center_z - radius
		par_time += 2.2
	_landing(5.0, 1.3)


func _seg_conveyor() -> void:
	var length := 14.0
	var conveyor := Conveyor.new()
	conveyor.size = Vector3(4, 0.5, length)
	conveyor.speed = 2.5 + 1.5 * difficulty
	conveyor.position = Vector3(0, y, z - length * 0.5)
	root.add_child(conveyor)
	_pillars(Vector3(0, y - 0.5, z - length * 0.3), 4.0)
	_pillars(Vector3(0, y - 0.5, z - length * 0.8), 4.0)
	# Blocos em zigue-zague: sempre sobra uma faixa livre do outro lado.
	var first_side := 1.0 if rng.randf() < 0.5 else -1.0
	for i in 3:
		var bz := z - 3.0 - i * 4.0
		var bx := 1.05 * first_side * (1.0 if i % 2 == 0 else -1.0)
		Build.solid_box(root, Vector3(1.4, 1.1, 1.1), Vector3(bx, y + 1.1, bz), _next_color())
		_coin(Vector3(-bx, y + 1.0, bz))
		_waypoint(Vector3(-bx, y, bz))
	if level <= 8:
		_sign(Vector3(0, y + 2.8, z - 1.0), "SIGN_CONVEYOR")
	z -= length
	par_time += length / maxf(7.5 - conveyor.speed, 2.0) + 0.5


func _seg_geysers() -> void:
	var length := 10.0
	_platform(Vector3(0, y, z - length * 0.5), Vector3(9, 1, length))
	var cycle_offset := rng.randf() * 3.0
	for r in 2:
		for c in 3:
			var geyser := Geyser.new()
			geyser.time_offset = cycle_offset + (r * 3 + c) * 0.45
			geyser.position = Vector3((c - 1) * 3.0, y, z - 3.0 - r * 3.5)
			root.add_child(geyser)
	# Paredão: só dá para subir usando o jato da última fileira.
	var ledge_y := y + 3.0
	var ledge := Vector3(0, ledge_y, z - length - 2.5)
	_platform(ledge, Vector3(9, ledge_y - WATER_Y + 1.0, 5), Color(0, 0, 0, 0), false, false)
	for c in 3:
		var geyser := Geyser.new()
		geyser.time_offset = cycle_offset + c * 0.6
		geyser.height = 5.0
		geyser.position = Vector3((c - 1) * 3.0, y, z - length + 1.0)
		root.add_child(geyser)
		_coin(Vector3((c - 1) * 3.0, y + 4.0, z - length + 1.0))
	if level <= 9:
		_sign(Vector3(0, ledge_y + 2.2, z - length - 0.5), "SIGN_GEYSER")
	z -= length + 5.0
	y = ledge_y
	par_time += length / 6.0 + 4.0
