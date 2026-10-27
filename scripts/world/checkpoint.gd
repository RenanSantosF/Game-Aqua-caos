class_name Checkpoint
extends Area3D
## Portal de checkpoint: ao passar, o jogador renasce aqui se cair.
## A origem é o centro, no chão.

signal activated

@export var width := 8.0

var active := false
var _flags: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("checkpoint")
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 4.0, 1.0)
	shape.shape = box
	shape.position.y = 2.0
	add_child(shape)
	for side in [-1.0, 1.0]:
		var x: float = side * (width * 0.5 + 0.2)
		Build.cylinder(self, 0.15, 3.6, Color("eceff1"), Vector3(x, 1.8, 0), -1.0, true)
		Build.sphere(self, 0.22, Color("ffd54f"), Vector3(x, 3.7, 0))
		var flag := Build.box(self, Vector3(0.05, 0.8, 1.2), Color("ff7043"), Vector3(x, 3.1, -0.6), true)
		_flags.append(flag)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not (body is Player):
		return
	var player := body as Player
	if not player.is_human:
		# Rivais também renascem aqui, mas sem festa.
		if player.respawn_point.z > global_position.z:
			player.respawn_point = global_position + Vector3(0, 0.2, -1.0)
		return
	if active:
		return
	active = true
	(body as Player).respawn_point = global_position + Vector3(0, 0.2, -1.0)
	for flag in _flags:
		flag.material_override = Mat.toon(Color("43a047"), true)
	Sfx.play("checkpoint")
	activated.emit()
