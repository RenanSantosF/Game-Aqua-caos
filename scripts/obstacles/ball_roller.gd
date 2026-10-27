class_name BallRoller
extends Node3D
## Canhão de bolas gigantes que rolam rampa abaixo (em direção ao jogador).
## A origem é o ponto de saída das bolas.

@export var interval := 1.8
@export var spread := 2.0
@export var ball_radius := 0.9
@export var max_balls := 4
@export var push := 8.0
@export var start_velocity := Vector3(0, 0, 4)
## Distância (rampa abaixo) em que a bola some, para não invadir outros trechos.
@export var despawn_distance := 17.0

const COLORS := [Color("e53935"), Color("fdd835"), Color("1e88e5"), Color("43a047"), Color("ff7043")]

var _timer := 0.5
var _balls: Array[RigidBody3D] = []


func _ready() -> void:
	# Pórtico por cima do caminho (o jogador passa por baixo).
	var half := spread + 1.6
	for side in [-1.0, 1.0]:
		Build.box(self, Vector3(0.5, 3.6, 0.5), Color("ffb300"), Vector3(side * half, 1.8, -0.8), true)
	Build.box(self, Vector3(half * 2.0 + 0.6, 0.8, 1.4), Color("e53935"), Vector3(0, 3.8, -0.8), true)
	for i in 3:
		Build.sphere(self, 0.35, COLORS[i + 1], Vector3((i - 1) * 1.4, 4.4, -0.8))


func _physics_process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval
		_spawn()
	for ball: RigidBody3D in _balls.duplicate():
		if not is_instance_valid(ball):
			_balls.erase(ball)
			continue
		var travelled := (ball.global_position - global_position).dot(global_transform.basis * start_velocity.normalized())
		if ball.global_position.y < -6.0 or travelled > despawn_distance:
			_balls.erase(ball)
			_pop(ball)
			continue
		var area: Area3D = ball.get_child(2)
		for body in area.get_overlapping_bodies():
			if body is Player:
				var dir: Vector3 = ball.linear_velocity
				dir.y = 0.0
				if dir.length() < 0.5:
					dir = body.global_position - ball.global_position
					dir.y = 0.0
				(body as Player).knockback(dir.normalized() * push + Vector3.UP * 6.0)


func _spawn() -> void:
	if _balls.size() >= max_balls:
		return
	var ball := RigidBody3D.new()
	ball.collision_layer = 4
	ball.collision_mask = 1 | 4
	ball.mass = 6.0
	var material := PhysicsMaterial.new()
	material.bounce = 0.25
	material.friction = 0.6
	ball.physics_material_override = material
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = ball_radius
	shape.shape = sphere
	ball.add_child(shape)
	var color: Color = COLORS[randi() % COLORS.size()]
	var mesh := Build.sphere(ball, ball_radius, color, Vector3.ZERO, true)
	var band := Build.torus(mesh, ball_radius * 0.92, ball_radius * 1.02, Color.WHITE)
	band.rotation.z = PI * 0.5
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var area_shape := CollisionShape3D.new()
	var area_sphere := SphereShape3D.new()
	area_sphere.radius = ball_radius + 0.15
	area_shape.shape = area_sphere
	area.add_child(area_shape)
	ball.add_child(area)
	get_parent().add_child(ball)
	ball.global_position = global_position + Vector3(randf_range(-spread, spread), ball_radius, 0)
	ball.linear_velocity = global_transform.basis * start_velocity
	_balls.append(ball)


func _pop(ball: RigidBody3D) -> void:
	ball.collision_layer = 0
	ball.collision_mask = 0
	ball.freeze = true
	var tween := ball.create_tween()
	tween.tween_property(ball, "scale", Vector3(1.3, 1.3, 1.3), 0.08)
	tween.tween_property(ball, "scale", Vector3(0.05, 0.05, 0.05), 0.15)
	tween.tween_callback(ball.queue_free)


func ball_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for ball in _balls:
		if is_instance_valid(ball):
			result.append(ball.global_position)
	return result
