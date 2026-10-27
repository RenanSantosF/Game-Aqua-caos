@tool
extends Node2D
## Jato d'água que sai da piscina em ciclos: desligado → aviso (bolhas) → ligado.
## Quem estiver no jato ligado é arremessado. A origem é o bico, na superfície.

@export var height := 330.0:
	set(value):
		height = value
		_refresh()
@export var width := 56.0:
	set(value):
		width = value
		_refresh()
@export var off_time := 1.6
@export var warn_time := 0.7
@export var on_time := 1.1
## Atraso do ciclo, para dessincronizar jatos vizinhos.
@export var time_offset := 0.0
@export var push := Vector2(-320, -950)

enum JetPhase { OFF, WARNING, ON }

const OUTLINE := Color("1a2340")

var _phase := JetPhase.OFF
var _time := 0.0
var _phase_time := 0.0
var _already_hit: Dictionary = {}

@onready var _column: Area2D = $Column


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var shape_node := get_node_or_null("Column/CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		(shape_node.shape as RectangleShape2D).size = Vector2(width, height)
		shape_node.position = Vector2(0, -height * 0.5)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_time += delta
	var cycle := off_time + warn_time + on_time
	var t := fposmod(_time + time_offset, cycle)
	var new_phase := JetPhase.OFF
	if t >= off_time + warn_time:
		new_phase = JetPhase.ON
		_phase_time = t - off_time - warn_time
	elif t >= off_time:
		new_phase = JetPhase.WARNING
		_phase_time = t - off_time
	if new_phase != _phase:
		_phase = new_phase
		_already_hit.clear()
	queue_redraw()

	if Engine.is_editor_hint() or _phase != JetPhase.ON:
		return
	for body in _column.get_overlapping_bodies():
		var id := body.get_instance_id()
		if body.has_method("knockback") and not _already_hit.has(id):
			_already_hit[id] = true
			body.knockback(push)


func _draw() -> void:
	match _phase:
		JetPhase.WARNING:
			for i in 5:
				var k := fmod(_phase_time * 2.5 + i * 0.2, 1.0)
				var p := Vector2(sin(i * 2.3 + _time * 6.0) * width * 0.35, -k * 60.0)
				draw_circle(p, 4.0 + i % 2 * 2.0, Color(1, 1, 1, 0.8 * (1.0 - k)))
			var spurt := 18.0 + sin(_time * 30.0) * 6.0
			draw_rect(Rect2(-width * 0.2, -spurt, width * 0.4, spurt), Color(0.8, 0.95, 1, 0.8))
		JetPhase.ON:
			var rise := minf(1.0, _phase_time / 0.12)
			var h := height * rise
			var left := PackedVector2Array()
			var right := PackedVector2Array()
			for i in 9:
				var y := -h * i / 8.0
				var wobble := sin(_time * 22.0 + i * 1.3) * 5.0
				var half := width * (0.5 - 0.12 * i / 8.0)
				left.append(Vector2(-half + wobble, y))
				right.append(Vector2(half + wobble, y))
			right.reverse()
			var column := left + right
			draw_colored_polygon(column, Color(0.6, 0.9, 1.0, 0.85))
			draw_line(Vector2(0, 0), Vector2(sin(_time * 22.0) * 4.0, -h), Color(1, 1, 1, 0.8), width * 0.18)
			for i in 4:
				var a := _time * 9.0 + i * TAU / 4.0
				draw_circle(Vector2(cos(a) * width * 0.4, -h + sin(a) * 6.0), 12.0, Color(1, 1, 1, 0.9))
	# Bico
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, width * 0.55 + 4.0, OUTLINE)
	draw_circle(Vector2.ZERO, width * 0.55, Color("90a4ae"))
	draw_circle(Vector2.ZERO, width * 0.3, Color("37474f"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
