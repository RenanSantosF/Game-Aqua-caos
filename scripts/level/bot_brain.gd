class_name BotBrain
extends RefCounted
## "Cérebro" dos rivais: segue a rota da fase, pula buracos e degraus,
## espera martelos e plataformas móveis e pula o bastão giratório.
## "skill" (0..1) muda a velocidade, o reflexo e a chance de errar.

var move := Vector3.ZERO
var jump_pressed := false
var jump_held := false
var dive_pressed := false

var _builder: CourseBuilder
var _skill := 0.7
var _rng := RandomNumberGenerator.new()
var _waypoint := 0
var _jump_time := 0.0
var _wait := 0.0
var _hesitate := 0.0
var _best_z := 0.0
var _stuck := 0.0
var _side := 0.0


func _init(builder: CourseBuilder, skill: float, seed_value: int) -> void:
	_builder = builder
	_skill = skill
	_rng.seed = seed_value
	_side = _rng.randf_range(-0.8, 0.8)


func think(player: Player, delta: float) -> void:
	jump_pressed = false
	dive_pressed = false
	if _jump_time > 0.0:
		_jump_time -= delta
	jump_held = _jump_time > 0.0

	if player.state == Player.State.IN_WATER or player.state == Player.State.FROZEN:
		move = Vector3.ZERO
		_waypoint = 0
		return
	var pos := player.global_position

	# Preso há muito tempo? Volta para o último checkpoint.
	if pos.z < _best_z - 0.5:
		_best_z = pos.z
		_stuck = 0.0
	else:
		_stuck += delta
		if _stuck > 9.0:
			_stuck = 0.0
			player.respawn()
			return

	if _hesitate > 0.0:
		_hesitate -= delta
		move = Vector3.ZERO
		return
	if _rng.randf() < 0.0015 * (1.0 - _skill):
		_hesitate = _rng.randf_range(0.3, 1.0)

	var target_x := _target_x(pos)
	var dx := clampf((target_x - pos.x) * 0.8, -1.0, 1.0)
	# Desvia das bolas que vêm rolando na direção dele.
	for roller in _builder.rollers:
		for ball in roller.ball_positions():
			if ball.z < pos.z + 0.5 and ball.z > pos.z - 7.0 and absf(ball.x - pos.x) < 1.9:
				var away := signf(pos.x - ball.x)
				if away == 0.0:
					away = 1.0 if _side >= 0.0 else -1.0
				if absf(pos.x + away * 1.5) > 2.6:
					away = -away
				dx = away
	var speed := 0.82 + 0.16 * _skill
	move = Vector3(dx, 0, -1.0).limit_length(1.0) * speed

	# Espera o martelo que está logo à frente sair do caminho.
	for hammer in _builder.hammers:
		var hz := hammer.global_position.z
		if hz < pos.z - 0.2 and hz > pos.z - 3.4 and absf(hammer.head_position().x - pos.x) < 3.0:
			move = Vector3(dx * 0.3, 0, 0.15)
			return

	if not player.is_on_floor():
		return

	# Pula o bastão giratório quando ele se aproxima.
	for sweeper in _builder.sweepers:
		var rel := pos - sweeper.global_position
		rel.y = 0.0
		if rel.length() < sweeper.radius + 0.3:
			var angle := atan2(-rel.z, rel.x)
			for i in sweeper.bars:
				var bar := sweeper.rotor_angle() + i * TAU / sweeper.bars
				var diff := wrapf(angle - bar, -PI, PI) * signf(sweeper.speed)
				if diff > 0.0 and diff < 0.3 + 0.25 * _skill:
					_jump(0.35)
					return

	var space := player.get_world_3d().direct_space_state
	var ahead := pos + Vector3(0, 0.5, -0.7)
	var gap := space.intersect_ray(PhysicsRayQueryParameters3D.create(ahead, ahead + Vector3.DOWN * 2.5, 1)).is_empty()
	var wall := false
	for side in [-0.35, 0.0, 0.35]:
		var chest := pos + Vector3(side, 0.4, 0)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(chest, chest + Vector3(0, 0, -1.0), 1)).is_empty():
			wall = true
	if gap:
		# Só pula se houver onde cair (espera plataformas móveis).
		var landing := false
		var heading := Vector3(target_x - pos.x, 0, -2.5).normalized()
		for distance in [2.0, 2.8, 3.6]:
			var from: Vector3 = pos + heading * float(distance) + Vector3.UP * 2.5
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.5, 1)).is_empty():
				landing = true
				break
		var on_belt := player._floor_node() is Conveyor
		if not landing and not on_belt and _wait < 5.0:
			_wait += delta
			move = Vector3.ZERO
			return
		_wait = 0.0
	if gap or wall:
		_jump(0.3)


func _jump(hold: float) -> void:
	jump_pressed = true
	jump_held = true
	_jump_time = hold


func _target_x(pos: Vector3) -> float:
	var points := _builder.waypoints
	while _waypoint < points.size() and points[_waypoint].z > pos.z - 0.8:
		_waypoint += 1
	if _waypoint >= points.size():
		return _side
	var point := points[_waypoint]
	var spread := 0.3 if absf(point.x) > 0.5 else 1.0
	return point.x + _side * spread
