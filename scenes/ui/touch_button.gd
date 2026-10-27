extends TouchScreenButton
## Botão de toque redondo desenhado por código, com suporte a multitoque.
## Defina "action" (jump, dive) no Inspetor.

enum Icon { JUMP, DIVE }

@export var icon := Icon.JUMP
@export var radius := 80.0
@export var label := ""
@export var color := Color(0.05, 0.2, 0.47)

const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")


func _ready() -> void:
	var circle := CircleShape2D.new()
	circle.radius = radius * 1.15
	shape = circle
	shape_centered = false
	shape_visible = false
	pressed.connect(queue_redraw)
	released.connect(queue_redraw)


func _draw() -> void:
	var down := is_pressed()
	var r := radius * (0.92 if down else 1.0)
	draw_circle(Vector2.ZERO, r, Color(color, 0.8 if down else 0.55))
	draw_arc(Vector2.ZERO, r - 3.0, 0.0, TAU, 48, Color(1, 1, 1, 0.9), 6.0, true)
	var white := Color(1, 1, 1, 0.95)
	match icon:
		Icon.JUMP:
			var arrow := PackedVector2Array([
				Vector2(-0.12, 0.34), Vector2(-0.12, -0.02), Vector2(-0.32, -0.02),
				Vector2(0.0, -0.38), Vector2(0.32, -0.02), Vector2(0.12, -0.02), Vector2(0.12, 0.34),
			])
			var points := PackedVector2Array()
			for p in arrow:
				points.append(p * r)
			draw_colored_polygon(points, white)
		Icon.DIVE:
			for k in 2:
				var off := (k - 0.5) * 0.3 * r
				var chevron := PackedVector2Array([
					Vector2(-0.18 * r + off, -0.3 * r), Vector2(0.12 * r + off, 0.0),
					Vector2(-0.18 * r + off, 0.3 * r),
				])
				draw_polyline(chevron, white, r * 0.13, true)
	if label != "":
		draw_string(FONT, Vector2(-r, r + 30), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 24, Color.WHITE)
