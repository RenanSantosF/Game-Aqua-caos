class_name CourseBuilder
extends RefCounted
## Gera o percurso de uma fase a partir do número dela (fases infinitas).
## O mesmo número sempre gera a mesma fase. A dificuldade cresce aos poucos
## e novos tipos de obstáculo são liberados conforme o jogador avança.
##
## O percurso segue para a frente (-Z). "z" é a borda da última plataforma
## construída e "y" a altura do chão atual. A água fica em y = -1.2.

const WATER_Y := -1.2
const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")

## Fase mínima para cada tipo de trecho aparecer.
const UNLOCK := {
	"hops": 1, "sweeper": 1, "slide": 1, "hammers": 2, "moving": 2, "bounce": 2,
	"vanishing": 3, "pushers": 4, "balls": 5, "discs": 6, "conveyor": 7, "geysers": 8,
}

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
## Início (z) de cada trecho, útil para testes automáticos.
var debug_marks: Array = []
## Rota (centro das plataformas, em ordem) e perigos: usados pelos rivais.
var waypoints: Array[Vector3] = []
var hammers: Array[PendulumHammer] = []
var sweepers: Array[Sweeper] = []
var rollers: Array[BallRoller] = []

var _color_index := 0


func build(parent: Node3D, level_number: int, theme: Dictionary) -> Dictionary:
	root = parent
	level = level_number
	palette = theme.palette
	rng.seed = hash("aqua_caos_fase_%d" % level)
	# Sobe aos poucos até a fase ~40 e depois estabiliza (sempre jogável).
	difficulty = clampf((level - 1) / 40.0, 0.0, 0.9)

	_start()
	var plan := _plan()
	for i in plan.size():
		debug_marks.append([z, plan[i]])
		call("_seg_" + plan[i])
		segments.append(plan[i])
		if i < plan.size() - 1 and (i + 1) % 2 == 0:
			_checkpoint()
	_finish()
	waypoints.sort_custom(func(a: Vector3, b: Vector3): return a.z > b.z)

	return {
		"spawn": spawn,
		"finish_z": finish_gate.position.z,
		"end_z": z,
		"par_time": snappedf(par_time, 0.5),
		"segments": segments,
	}


func _plan() -> Array[String]:
	match level:
		1:
			return ["hops", "sweeper", "slide"]
		2:
			return ["hops", "hammers", "moving", "bounce"]
		3:
			return ["vanishing", "sweeper", "hops", "slide", "hammers"]
	var pool: Array[String] = []
	for kind in UNLOCK:
		if level >= UNLOCK[kind]:
			pool.append(kind)
	var count := 4 + mini(level / 4, 6)
	var plan: Array[String] = []
	# A fase sempre traz o tipo de obstáculo liberado mais recentemente.
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
	return plan


# --- Peças básicas ---------------------------------------------------------------------

func _next_color() -> Color:
	var color: Color = palette[_color_index % palette.size()]
	_color_index += 1
	return color


## Plataforma com topo em "top" (centro). Colunas até a água dão profundidade.
func _platform(top: Vector3, size: Vector3, color := Color(0, 0, 0, 0), slippery := false, pillars := true) -> StaticBody3D:
	if color.a == 0.0:
		color = _next_color()
	var body := Build.solid_box(root, size, top, color)
	waypoints.append(top)
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


func _sign(position: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.font = FONT
	label.font_size = 72
	label.outline_size = 18
	label.modulate = Color("fffde7")
	label.outline_modulate = Color("1a2340")
	label.pixel_size = 0.006
	label.position = position
	root.add_child(label)


## Rampa inclinada. drop > 0 desce, drop < 0 sobe. Começa na borda "z" atual.
func _slope(length: float, drop: float, width: float, slippery: bool, color: Color) -> StaticBody3D:
	waypoints.append(Vector3(0, y - drop * 0.5, z - length * 0.5))
	var angle := atan2(drop, length)
	var hyp := sqrt(length * length + drop * drop)
	var thickness := 0.6
	var body := StaticBody3D.new()
	body.rotation.x = -angle
	var normal := Vector3(0, cos(angle), -sin(angle))
	var middle := Vector3(0, y - drop * 0.5, z - length * 0.5)
	body.position = middle - normal * thickness * 0.5
	root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, thickness, hyp)
	shape.shape = box
	body.add_child(shape)
	Build.box(body, Vector3(width, thickness, hyp), color, Vector3.ZERO, true)
	if slippery:
		body.add_to_group("slippery")
		Build.box(body, Vector3(width * 0.8, 0.04, hyp), Color("81d4fa"), Vector3(0, thickness * 0.5 + 0.01, 0))
	for side in [-1.0, 1.0]:
		var rail_shape := CollisionShape3D.new()
		var rail_box := BoxShape3D.new()
		rail_box.size = Vector3(0.3, 0.8, hyp)
		rail_shape.shape = rail_box
		rail_shape.position = Vector3(side * (width * 0.5 + 0.15), thickness * 0.5 + 0.3, 0)
		body.add_child(rail_shape)
		Build.box(body, Vector3(0.3, 0.8, hyp), Color("fdd835"), rail_shape.position)
	for i in 3:
		var k := (i + 0.5) / 3.0
		_pillars(Vector3(0, y - drop * k - 0.6, z - length * k), width)
	return body


# --- Trechos ----------------------------------------------------------------------------

func _start() -> void:
	_platform(Vector3(0, 0, -5), Vector3(12, 1, 14), palette[0])
	spawn = Vector3(0, 0.1, 0.0)
	for side in [-1.0, 1.0]:
		Build.cylinder(root, 0.3, 4.6, Color("eceff1"), Vector3(side * 5.0, 2.3, -3.0), -1.0, true)
	Build.box(root, Vector3(10.6, 1.1, 0.5), palette[1], Vector3(0, 4.8, -3.0), true)
	_sign(Vector3(0, 4.8, -2.7), "LARGADA")
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


func _seg_hops() -> void:
	var count := 3 + int(difficulty * 3.0) + rng.randi() % 2
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
	waypoints.append(center + Vector3(0, 0, radius * 0.5))
	waypoints.append(center - Vector3(0, 0, radius * 0.5))
	for i in 6:
		var a := i * TAU / 6.0
		_coin(center + Vector3(cos(a) * radius * 0.6, 1.3, sin(a) * radius * 0.6))
	if level <= 2:
		_sign(center + Vector3(0, 3.6, -radius - 0.5), "PULE O BASTÃO!")
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
		_sign(Vector3(0, y + 6.2, z - 0.5), "ESPERE O MARTELO PASSAR")
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
		waypoints.append(mover.position)
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
		waypoints.append(Vector3(0, y, center_z))
		_coin(Vector3(0, y + 1.6, center_z))
		z = center_z - size.z * 0.5
		par_time += size.z / 6.0 + mover.period * 0.5
	_landing(5.0, 1.4)


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
		_sign(Vector3(0, y + 2.6, z - 1.0), "ESCORREGUE!")
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
		waypoints.append(pad.position)
		_pillars(Vector3(px, y - 0.5, pad_z), 1.0)
		_coin(Vector3(px, y + 3.6, pad_z - spacing * 0.5))
		z = pad_z - 1.4
		pad_z -= spacing
	if level <= 3:
		_sign(Vector3(0, y + 3.4, first_z - 2.0), "PULE NAS BOIAS!")
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
				waypoints.append(tile.position)
			if rng.randf() < 0.25:
				_coin(tile.position + Vector3(0, 1.0, 0))
	if level <= 4:
		_sign(Vector3(0, y + 2.8, z - 1.0), "O PISO CAI!")
	z -= 1.0 + rows * spacing - 0.3
	par_time += rows * spacing / 6.0
	_landing(5.0, 1.0)


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
		_sign(Vector3(0, y + 4.2, z - 1.5), "DESVIE DAS BOLAS!")
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
		waypoints.append(disc.position)
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
		waypoints.append(Vector3(-bx, y, bz))
	if level <= 8:
		_sign(Vector3(0, y + 2.8, z - 1.0), "CORRA CONTRA A ESTEIRA!")
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
		_sign(Vector3(0, ledge_y + 2.2, z - length - 0.5), "SUBA COM O JATO!")
	z -= length + 5.0
	y = ledge_y
	par_time += length / 6.0 + 4.0
