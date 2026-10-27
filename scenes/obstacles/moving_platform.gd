@tool
extends AnimatableBody2D
## Boia-plataforma que vai e volta. O personagem é carregado junto.
## A origem é o canto superior esquerdo na posição inicial.

@export var size := Vector2(180, 32):
	set(value):
		size = value
		_refresh()
## Deslocamento total até o outro extremo.
@export var travel := Vector2(400, 0):
	set(value):
		travel = value
		queue_redraw()
## Segundos para ir e voltar.
@export var period := 3.2
## 0 a 1: desloca o ciclo para dessincronizar várias plataformas.
@export_range(0.0, 1.0) var phase := 0.0

const OUTLINE := Color("1a2340")

var _start := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	_start = position
	_refresh()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	var k := 0.5 - 0.5 * cos(TAU * (_time / period + phase))
	position = _start + travel * k


func _refresh() -> void:
	if not is_inside_tree():
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		(shape_node.shape as RectangleShape2D).size = size
		shape_node.position = size * 0.5
	queue_redraw()


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(travel, size), Color(1, 1, 1, 0.4), false, 2.0)
		draw_line(size * 0.5, travel + size * 0.5, Color(1, 1, 1, 0.4), 2.0)
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect.grow(3), OUTLINE)
	draw_rect(rect, Color("fdd835"))
	var stripes := int(size.x / 36.0)
	for i in stripes:
		var x := 18.0 + i * 36.0
		draw_rect(Rect2(x, 0, 14, size.y), Color("e53935"))
	draw_rect(Rect2(0, 0, size.x, 6), Color(1, 1, 1, 0.45))
	draw_rect(Rect2(0, size.y - 6, size.x, 6), Color(0, 0, 0, 0.18))
