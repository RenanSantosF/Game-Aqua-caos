@tool
extends Node2D
## Martelo inflável em pêndulo, preso no alto de um poste.
## A origem é o eixo do pêndulo; o chão fica em y = post_height.

@export var arm_length := 230.0:
	set(value):
		arm_length = value
		_refresh()
@export var post_height := 300.0:
	set(value):
		post_height = value
		queue_redraw()
@export var max_angle_degrees := 65.0
## Segundos para ir e voltar.
@export var period := 2.6
@export_range(0.0, 1.0) var phase := 0.0
## Força do empurrão (x é invertido conforme o lado da batida).
@export var push := Vector2(450, -380)

const OUTLINE := Color("1a2340")

var _time := 0.0
var _angle := 0.0
var _previous_head := Vector2.ZERO
var _head_velocity := Vector2.ZERO

@onready var _pivot: Node2D = $Pivot
@onready var _head: Area2D = $Pivot/Head


func _ready() -> void:
	_refresh()
	_previous_head = _head.global_position


func _refresh() -> void:
	if not is_inside_tree():
		return
	var head := get_node_or_null("Pivot/Head") as Node2D
	if head:
		head.position = Vector2(0, arm_length)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_time += delta
	_angle = deg_to_rad(max_angle_degrees) * sin(TAU * (_time / period + phase))
	if Engine.is_editor_hint():
		queue_redraw()
		return
	_pivot.rotation = _angle
	var head_position := _head.global_position
	_head_velocity = (head_position - _previous_head) / delta
	_previous_head = head_position
	for body in _head.get_overlapping_bodies():
		if body.has_method("knockback"):
			var direction := signf(_head_velocity.x)
			if absf(_head_velocity.x) < 60.0:
				direction = signf(body.global_position.x - head_position.x)
			if direction == 0.0:
				direction = 1.0
			body.knockback(Vector2(push.x * direction, push.y))
	queue_redraw()


func _draw() -> void:
	# Poste (fica atrás do martelo).
	draw_rect(Rect2(-11, 0, 22, post_height), OUTLINE)
	draw_rect(Rect2(-8, 0, 16, post_height), Color("78909c"))
	draw_rect(Rect2(-40, post_height - 14, 80, 14), OUTLINE)

	var head := Vector2(0, arm_length).rotated(_angle)
	draw_line(Vector2.ZERO, head, OUTLINE, 14.0)
	draw_line(Vector2.ZERO, head, Color("b0bec5"), 8.0)
	draw_circle(Vector2.ZERO, 14.0, OUTLINE)
	draw_circle(Vector2.ZERO, 10.0, Color("fdd835"))

	draw_set_transform(head, _angle, Vector2.ONE)
	var body := Rect2(-52, -32, 104, 64)
	draw_rect(body.grow(4), OUTLINE)
	draw_rect(body, Color("e53935"))
	draw_rect(Rect2(-18, -32, 14, 64), Color.WHITE)
	draw_rect(Rect2(4, -32, 14, 64), Color.WHITE)
	draw_rect(Rect2(-52, -32, 104, 10), Color(1, 1, 1, 0.35))
	for x in [-52.0, 52.0]:
		draw_rect(Rect2(x - 6, -36, 12, 72), OUTLINE)
		draw_rect(Rect2(x - 3, -33, 6, 66), Color("b71c1c"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
