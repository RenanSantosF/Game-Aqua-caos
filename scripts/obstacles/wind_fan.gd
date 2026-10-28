class_name WindFan
extends Node3D
## Ventilador gigante na lateral: liga e desliga, soprando o jogador para o
## lado. A origem fica na borda da passarela; "direction" aponta para dentro.

@export var direction := 1.0
## Velocidade extra (m/s) com que o vento empurra.
@export var strength := 4.0
@export var width := 6.0
@export var on_time := 1.6
@export var off_time := 1.8
@export var time_offset := 0.0

var _blades: Node3D
var _area: Area3D
var _time := 0.0
var _streaks: Array[MeshInstance3D] = []
var _on := false


func _ready() -> void:
	var housing := Build.cylinder(self, 1.5, 0.6, Color("eceff1"), Vector3(-direction * 0.6, 1.6, 0), -1.0, true)
	housing.rotation.z = PI * 0.5
	Build.box(self, Vector3(0.4, 1.6, 0.4), Color("78909c"), Vector3(-direction * 0.6, 0.6, 0))
	_blades = Node3D.new()
	_blades.position = Vector3(-direction * 0.25, 1.6, 0)
	add_child(_blades)
	for i in 3:
		var blade := Build.box(_blades, Vector3(0.08, 1.2, 0.35), Color("ff7043"), Vector3.ZERO)
		blade.rotation.x = i * TAU / 3.0
		blade.translate_object_local(Vector3(0, 0.55, 0))
	Build.sphere(_blades, 0.22, Color("fdd835"))
	for i in 6:
		var streak := Build.box(self, Vector3(0.9, 0.05, 0.05), Color.WHITE, Vector3.ZERO)
		streak.material_override = Mat.unshaded(Color(1, 1, 1, 0.7))
		streak.visible = false
		_streaks.append(streak)
	_area = Build.area_box(self, Vector3(width, 2.4, 3.0), Vector3(direction * width * 0.5, 1.2, 0))


func _physics_process(delta: float) -> void:
	_time += delta
	var cycle := on_time + off_time
	var t := fposmod(_time + time_offset, cycle)
	_on = t < on_time
	var warn := not _on and t > cycle - 0.6
	_blades.rotation.x += delta * (22.0 if _on else (6.0 if warn else 1.0))
	for i in _streaks.size():
		var streak := _streaks[i]
		streak.visible = _on
		if _on:
			var k := fmod(_time * 1.8 + i * 0.37, 1.0)
			streak.position = Vector3(direction * k * width, 0.6 + (i % 3) * 0.55, (i - 2.5) * 0.45)
	if not _on:
		return
	var push := global_transform.basis * Vector3(direction * strength, 0, 0)
	for body in _area.get_overlapping_bodies():
		if body is Player:
			(body as Player).apply_wind(push, delta)
