class_name Geyser
extends Node3D
## Gêiser: borbulha (aviso) e depois dispara um jato que joga o jogador
## para o alto. A origem é o bico, no chão.

@export var off_time := 2.0
@export var warn_time := 0.8
@export var on_time := 1.0
@export var time_offset := 0.0
@export var height := 4.5
@export var launch_velocity := 15.0

enum JetPhase { OFF, WARNING, ON }

var _phase := JetPhase.OFF
var _time := 0.0
var _column: MeshInstance3D
var _bubbles: Array[MeshInstance3D] = []
var _area: Area3D


func _ready() -> void:
	Build.cylinder(self, 0.75, 0.2, Color("78909c"), Vector3(0, 0.05, 0), 0.65, true)
	Build.cylinder(self, 0.5, 0.22, Color("263238"), Vector3(0, 0.08, 0))
	_column = Build.cylinder(self, 0.55, height, Color("b3e5fc"), Vector3(0, height * 0.5, 0), 0.35)
	_column.material_override = Mat.unshaded(Color(0.75, 0.93, 1.0, 0.85))
	_column.visible = false
	for i in 5:
		var bubble := Build.sphere(self, 0.12, Color.WHITE)
		bubble.material_override = Mat.unshaded(Color.WHITE)
		bubble.visible = false
		_bubbles.append(bubble)
	_area = Build.area_box(self, Vector3(1.2, height, 1.2), Vector3(0, height * 0.5, 0))


func _physics_process(delta: float) -> void:
	_time += delta
	var cycle := off_time + warn_time + on_time
	var t := fposmod(_time + time_offset, cycle)
	if t >= off_time + warn_time:
		_phase = JetPhase.ON
	elif t >= off_time:
		_phase = JetPhase.WARNING
	else:
		_phase = JetPhase.OFF

	_column.visible = _phase == JetPhase.ON
	if _column.visible:
		var k := minf(1.0, (t - off_time - warn_time) / 0.12)
		_column.scale = Vector3(1.0 + sin(_time * 30.0) * 0.06, k, 1.0 + cos(_time * 30.0) * 0.06)
		_column.position.y = height * 0.5 * k
	for i in _bubbles.size():
		var bubble := _bubbles[i]
		bubble.visible = _phase == JetPhase.WARNING
		if bubble.visible:
			var p := fmod(_time * 1.6 + i * 0.2, 1.0)
			bubble.position = Vector3(sin(i * 2.4) * 0.35, p * 1.2, cos(i * 2.4) * 0.35)

	if _phase == JetPhase.ON:
		for body in _area.get_overlapping_bodies():
			if body is Player and (body as Player).velocity.y < launch_velocity * 0.5:
				(body as Player).launch(launch_velocity, 4.0)
