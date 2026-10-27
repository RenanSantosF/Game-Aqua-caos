@tool
extends TouchScreenButton
## Botão de toque redondo desenhado por código, com suporte a multitoque.
## Defina "action" no Inspetor (move_left, move_right, jump).

enum Icon { LEFT, RIGHT, UP }

@export var icon := Icon.LEFT:
	set(value):
		icon = value
		queue_redraw()
@export var radius := 70.0:
	set(value):
		radius = value
		_update_shape()
		queue_redraw()


func _ready() -> void:
	_update_shape()
	pressed.connect(queue_redraw)
	released.connect(queue_redraw)


func _update_shape() -> void:
	# A área de toque é um pouco maior que o desenho, para facilitar.
	var circle := CircleShape2D.new()
	circle.radius = radius * 1.2
	shape = circle
	shape_centered = false
	shape_visible = false


func _draw() -> void:
	var down := is_pressed()
	var r := radius * (0.92 if down else 1.0)
	draw_circle(Vector2.ZERO, r, Color(0.05, 0.2, 0.47, 0.75 if down else 0.5))
	draw_arc(Vector2.ZERO, r - 3.0, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 6.0, true)
	var arrow := PackedVector2Array([
		Vector2(-0.36, -0.12), Vector2(0.04, -0.12), Vector2(0.04, -0.32),
		Vector2(0.42, 0.0), Vector2(0.04, 0.32), Vector2(0.04, 0.12), Vector2(-0.36, 0.12),
	])
	var angle := 0.0
	match icon:
		Icon.LEFT:
			angle = PI
		Icon.UP:
			angle = -PI * 0.5
	var points := PackedVector2Array()
	for p in arrow:
		points.append((p * r).rotated(angle))
	draw_colored_polygon(points, Color(1, 1, 1, 0.95))
