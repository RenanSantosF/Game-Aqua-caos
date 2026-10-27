class_name Coin
extends Area3D
## Moeda que gira e flutua. Ao encostar, o jogador coleta.

var _visual: Node3D
var _taken := false
var _time := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	shape.shape = sphere
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	var disc := Build.cylinder(_visual, 0.4, 0.12, Color("ffc107"), Vector3.ZERO, -1.0, true)
	disc.rotation.x = PI * 0.5
	var inner := Build.cylinder(_visual, 0.26, 0.14, Color("ffa000"))
	inner.rotation.x = PI * 0.5
	var shine := Build.box(_visual, Vector3(0.08, 0.3, 0.16), Color("fff8e1"), Vector3(0, 0, 0))
	shine.rotation.z = 0.3
	_time = randf() * TAU
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_visual.rotation.y += delta * (3.0 if not _taken else 18.0)
	if not _taken:
		_visual.position.y = sin(_time * 2.5) * 0.12


func _on_body_entered(body: Node3D) -> void:
	if _taken or not (body is Player) or not (body as Player).is_human:
		return
	_taken = true
	(body as Player).collect_coin()
	var tween := create_tween().set_parallel()
	tween.tween_property(_visual, "position:y", 1.6, 0.35).set_ease(Tween.EASE_OUT)
	tween.tween_property(_visual, "scale", Vector3(0.1, 0.1, 0.1), 0.35).set_delay(0.1)
	tween.chain().tween_callback(queue_free)
