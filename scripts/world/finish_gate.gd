class_name FinishGate
extends Area3D
## Arco de chegada quadriculado com confete. A origem é o centro, no chão.

signal crossed(body: Node3D)
## Um rival cruzou a chegada.
signal bot_finished(body: Node3D)

const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")

@export var width := 10.0

var _done := false
var _bots_done: Array[Node3D] = []


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 5.0, 1.0)
	shape.shape = box
	shape.position.y = 2.5
	add_child(shape)
	for side in [-1.0, 1.0]:
		_checker_column(Vector3(side * (width * 0.5 + 0.4), 0, 0), 5.5)
	_checker_beam(Vector3(0, 5.5, 0), width + 1.6)
	var label := Label3D.new()
	label.text = "CHEGADA"
	label.font = FONT
	label.font_size = 120
	label.outline_size = 24
	label.modulate = Color("ffeb3b")
	label.outline_modulate = Color("1a2340")
	label.position = Vector3(0, 6.6, 0.05)
	label.pixel_size = 0.012
	add_child(label)
	body_entered.connect(_on_body_entered)


func _checker_column(base: Vector3, height: float) -> void:
	var count := int(height / 0.5)
	for i in count:
		for j in 2:
			var color := Color.WHITE if (i + j) % 2 == 0 else Color("212121")
			Build.box(self, Vector3(0.4, 0.5, 0.4), color, base + Vector3((j - 0.5) * 0.4, 0.25 + i * 0.5, 0))


func _checker_beam(center: Vector3, length: float) -> void:
	var count := int(length / 0.5)
	for i in count:
		for j in 2:
			var color := Color.WHITE if (i + j) % 2 == 0 else Color("212121")
			Build.box(self, Vector3(0.5, 0.45, 0.5), color, center + Vector3(-length * 0.5 + 0.25 + i * 0.5, (j - 0.5) * 0.45, 0))


func _on_body_entered(body: Node3D) -> void:
	if not (body is Player):
		return
	if not (body as Player).is_human:
		if body not in _bots_done:
			_bots_done.append(body)
			bot_finished.emit(body)
		return
	if _done:
		return
	_done = true
	_confetti()
	crossed.emit(body)


func _confetti() -> void:
	var colors := [Color("e53935"), Color("fdd835"), Color("1e88e5"), Color("43a047"), Color("ab47bc")]
	for i in colors.size():
		var particles := CPUParticles3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.18, 0.02, 0.12)
		mesh.material = Mat.unshaded(colors[i])
		particles.mesh = mesh
		particles.amount = 24
		particles.lifetime = 2.5
		particles.one_shot = true
		particles.explosiveness = 0.9
		particles.direction = Vector3.UP
		particles.spread = 50.0
		particles.gravity = Vector3(0, -6, 0)
		particles.initial_velocity_min = 6.0
		particles.initial_velocity_max = 11.0
		particles.angular_velocity_min = -400.0
		particles.angular_velocity_max = 400.0
		particles.damping_min = 1.0
		particles.damping_max = 2.0
		particles.position = Vector3((i - 2) * width * 0.2, 5.5, 0)
		add_child(particles)
		particles.emitting = true
