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

## Fase mínima para cada tipo de trecho aparecer.
const UNLOCK := {
	"hops": 1, "sweeper": 1, "slide": 1,
	"hammers": 2, "moving": 2, "bounce": 2, "serpentine": 2,
	"vanishing": 3, "logs": 3,
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

var _color_index := 0
var _yaw := 0.0


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
			return ["hops", "curve", "sweeper", "slide", "curve", "hops"]
		2:
			return ["hops", "serpentine", "hammers", "curve", "moving", "bounce"]
		3:
			return ["vanishing", "curve", "logs", "sweeper", "serpentine", "hops", "hammers"]
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
	while plan.size() < count:
		var kind: String = pool[rng.randi() % pool.size()]
		if plan.is_empty() or plan[plan.size() - 1] != kind:
			plan.append(kind)
	if plan.size() > 1 and rng.randf() < 0.5:
		var first: String = plan.pop_front()
		plan.insert(rng.randi_range(0, plan.size()), first)
	# Curvas entre os trechos deixam o percurso sinuoso.
	var result: Array[String] = []
	for i in plan.size():
		result.append(plan[i])
		if i < plan.size() - 1 and rng.randf() < 0.55:
			result.append("curve")
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
func _ramp_piece(from: Vector3, to: Vector3, width: float, color: Color, slippery: bool, rail_height: float) -> StaticBody3D:
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
	Build.box(body, Vector3(width, thickness, length), color, Vector3.ZERO, true)
	if slippery:
		body.add_to_group("slippery")
		Build.box(body, Vector3(width * 0.8, 0.04, length), Color("81d4fa"), Vector3(0, thickness * 0.5 + 0.01, 0))
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
func _arc(radius: float, angle: float, turn: float, width: float, drop: float, slippery: bool, rail_height: float, color: Color) -> void:
	var steps := maxi(4, int(angle / deg_to_rad(11.0)))
	var start_y := y
	var origin := Vector3(0, 0, z)
	var previous := origin + Vector3(0, start_y, 0)
	for i in steps:
		var phi := angle * (i + 1) / steps
		var point := origin + Vector3(turn * (-radius + radius * cos(phi)), start_y - drop * (i + 1) / steps, -radius * sin(phi))
		_ramp_piece(previous, point, width, color if i % 2 == 0 else color.lightened(0.15), slippery, rail_height)
		_waypoint((previous + point) * 0.5)
		if i % 2 == 0:
			_pillars(Vector3(point.x, point.y - 0.6, point.z), width * 0.5)
		if i % 2 == 1:
			_coin(point + Vector3(0, 1.0, 0))
		previous = point
	var end := origin + Vector3(turn * (-radius + radius * cos(angle)), 0, -radius * sin(angle))
	y = start_y - drop
	_yaw += turn * angle
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
	z -= 16.0
	par_time += 5.0 / 7.0


# --- Trechos sorteados ------------------------------------------------------------------------

func _seg_curve() -> void:
	var angle := deg_to_rad(rng.randf_range(40.0, 80.0))
	var turn := _turn_sign(angle)
	var width := lerpf(5.0, 3.6, difficulty)
	var drop := rng.randf_range(-0.6, 0.9) if level > 2 else 0.0
	drop = clampf(drop, y - 2.5, y + 0.4)
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
	_platform(Vector3(0, y, z - 2.0), Vector3(5, 1, 4), Color("4fc3f7"), true)
	z -= 4.0
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
	_platform(Vector3(0, y, z - 1.5), Vector3(5, 1, 3), Color("4fc3f7"), true)
	var pad := BouncePad.new()
	pad.position = Vector3(0, y, z - 2.0)
	root.add_child(pad)
	_coin_line(Vector3(0, y + 3.0, z - 4.5), Vector3(0, y + 2.5, z - 7.0), 3)
	z -= 3.0
	par_time += (10.5 + length + 3.0) / 8.0
	_landing(8.0, 4.0)


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
	_landing(5.0, 1.2)


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
