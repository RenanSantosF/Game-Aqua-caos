class_name BotBrain
extends RefCounted
## "Cérebro" dos rivais: segue a rota da fase (em qualquer direção, com
## curvas), pula buracos e degraus, espera martelos e plataformas móveis,
## pula o bastão giratório e desvia das bolas.
## "skill" (0..1) muda a velocidade, o reflexo e a chance de errar.

var move := Vector3.ZERO
var jump_pressed := false

var _builder: CourseBuilder
var _points: Array[Vector3] = []
var _skill := 0.7
var _rng := RandomNumberGenerator.new()
var _index := 0
var _wait := 0.0
var _hesitate := 0.0
var _best_index := 0
var _stuck := 0.0
var _side := 0.0
var _jump_cooldown := 0.0
var _resync := false
var _last_fall_index := -100
var _repeat_falls := 0


func _init(builder: CourseBuilder, skill: float, seed_value: int) -> void:
	_builder = builder
	_points = builder.waypoints
	_skill = skill
	_rng.seed = seed_value
	_side = _rng.randf_range(-0.8, 0.8)


func think(player: Player, delta: float) -> void:
	jump_pressed = false
	_jump_cooldown -= delta
	if player.state == Player.State.IN_WATER or player.state == Player.State.FROZEN:
		if player.state == Player.State.IN_WATER and not _resync:
			# Caiu de novo no mesmo lugar? Conta para dar uma ajudinha.
			_repeat_falls = _repeat_falls + 1 if absi(_index - _last_fall_index) <= 6 else 1
			_last_fall_index = _index
		move = Vector3.ZERO
		_resync = true
		return
	var pos := player.global_position
	if _resync:
		_resync = false
		_index = _nearest_index(pos)
		_best_index = _index
		if _repeat_falls >= 2:
			player.protect(8.0)
	_advance(pos)

	# Preso há muito tempo? Volta para o último checkpoint.
	if _index > _best_index or player.velocity.dot(_route_direction()) > 2.0:
		_best_index = _index
		_stuck = 0.0
	else:
		_stuck += delta
		if _stuck > 10.0:
			_stuck = 0.0
			_resync = true
			player.respawn()
			return

	if _hesitate > 0.0:
		_hesitate -= delta
		move = Vector3.ZERO
		return
	if _rng.randf() < 0.0015 * (1.0 - _skill):
		_hesitate = _rng.randf_range(0.3, 1.0)

	var target := _target_point()
	var to_target := target - pos
	to_target.y = 0.0
	var forward := _route_direction()
	var right := forward.cross(Vector3.UP)
	var heading := to_target.normalized() if to_target.length() > 0.3 else forward

	# Desvia das bolas que vêm rolando na direção dele.
	for roller in _builder.rollers:
		for ball in roller.ball_positions():
			var rel := ball - pos
			var ahead := rel.dot(forward)
			var lateral := rel.dot(right)
			if ahead > -0.5 and ahead < 7.0 and absf(lateral) < 1.9:
				var away := -signf(lateral) if lateral != 0.0 else (1.0 if _side >= 0.0 else -1.0)
				heading = (forward + right * away * 1.4).normalized()

	var speed := 0.82 + 0.16 * _skill
	move = heading * speed
	# Anda contra o vento dos ventiladores para não ser soprado para fora.
	if player.wind_felt.length() > 0.1:
		move = (move - player.wind_felt / player.run_speed).limit_length(1.0)

	# Espera o martelo que está logo à frente sair do caminho.
	for hammer in _builder.hammers:
		var rel := hammer.global_position - pos
		var ahead := rel.dot(forward)
		if ahead > 0.2 and ahead < 3.4 and absf(rel.dot(right)) < 2.0:
			var head_offset := (hammer.head_position() - pos).dot(hammer.global_transform.basis.x)
			if absf(head_offset) < 3.0:
				move = -forward * 0.15
				return

	# Espera a parede de soco recolher antes de passar na frente dela.
	for pusher in _builder.pushers:
		var rel := pusher.global_position - pos
		var ahead := rel.dot(forward)
		if ahead > 0.3 and ahead < 2.6 and pusher.is_dangerous():
			move = -forward * 0.1
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
				var bar := sweeper.bar_angle(i)
				var diff := wrapf(angle - bar, -PI, PI) * signf(sweeper.speed)
				if diff > 0.0 and diff < 0.3 + 0.25 * _skill:
					_jump()
					return

	# Em cima de um rolo: pula logo para o próximo.
	if player._floor_node() is LogRoller:
		_jump()
		return

	var space := player.get_world_3d().direct_space_state
	var probe := pos + heading * 0.7 + Vector3.UP * 0.5
	var gap := space.intersect_ray(PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * 2.6, 1)).is_empty()
	var wall := false
	for offset in [-0.35, 0.0, 0.35]:
		var chest := pos + Vector3.UP * 0.4 + heading.cross(Vector3.UP) * float(offset)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(chest, chest + heading * 1.0, 1)).is_empty():
			wall = true
	if gap:
		# Só pula se houver onde cair (espera plataformas móveis).
		var landing := false
		for distance in [2.0, 2.8, 3.6]:
			var from: Vector3 = pos + heading * float(distance) + Vector3.UP * 2.5
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 4.5, 1)).is_empty():
				landing = true
				break
		var floor_node := player._floor_node()
		var on_belt := floor_node != null and floor_node.has_method("belt_velocity")
		if not landing and not on_belt and _wait < 5.0:
			_wait += delta
			move = Vector3.ZERO
			return
		_wait = 0.0
	if gap or wall:
		_jump()


func _jump() -> void:
	if _jump_cooldown > 0.0:
		return
	jump_pressed = true
	_jump_cooldown = 0.35


func _nearest_index(pos: Vector3) -> int:
	var best := 0
	var best_distance := INF
	for i in _points.size():
		var d := _points[i].distance_to(pos)
		if d < best_distance:
			best_distance = d
			best = i
	return best


## Avança na rota quando já passou do ponto atual.
func _advance(pos: Vector3) -> void:
	while _index < _points.size() - 1:
		var a := _points[_index]
		var b := _points[_index + 1]
		var along := b - a
		along.y = 0.0
		var rel := pos - a
		rel.y = 0.0
		if rel.length() < 1.4 or (along.length() > 0.01 and rel.dot(along.normalized()) > -0.3):
			_index += 1
		else:
			break


func _route_direction() -> Vector3:
	var a := _points[maxi(0, _index - 1)]
	var b := _points[mini(_index, _points.size() - 1)]
	var direction := b - a
	direction.y = 0.0
	return direction.normalized() if direction.length() > 0.05 else Vector3.FORWARD


func _target_point() -> Vector3:
	if _points.is_empty():
		return Vector3.ZERO
	var point := _points[mini(_index, _points.size() - 1)]
	var right := _route_direction().cross(Vector3.UP)
	return point + right * _side * 0.6
