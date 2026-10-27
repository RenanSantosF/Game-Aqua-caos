@tool
class_name Water
extends Area2D
## Piscina: desenha a água com ondas e derruba quem cair nela.
## A origem é o canto superior esquerdo (a superfície da água).

const SPLASH := preload("res://scenes/effects/splash.tscn")

@export var size := Vector2(2000, 300):
	set(value):
		size = value
		_refresh()
@export var deep_color := Color(0.09, 0.42, 0.85, 0.82)
@export var surface_color := Color(0.55, 0.9, 1.0, 0.95)
@export var wave_height := 6.0
@export var wave_length := 140.0

var _time := 0.0


func _ready() -> void:
	_refresh()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		# A área começa um pouco abaixo da superfície: só "cai" quem afundar.
		(shape_node.shape as RectangleShape2D).size = Vector2(size.x, size.y - 20.0)
		shape_node.position = Vector2(size.x * 0.5, size.y * 0.5 + 10.0)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("enter_water"):
		body.enter_water()
		var splash := SPLASH.instantiate() as Node2D
		add_child(splash)
		splash.global_position = Vector2(body.global_position.x, global_position.y)


func _draw() -> void:
	# Desenha só a parte visível da tela (economiza no celular).
	var x0 := 0.0
	var x1 := size.x
	if not Engine.is_editor_hint():
		var screen := get_global_transform_with_canvas().affine_inverse() * get_viewport_rect()
		x0 = clampf(screen.position.x - 40.0, 0.0, size.x)
		x1 = clampf(screen.end.x + 40.0, 0.0, size.x)
		if x1 <= x0:
			return

	var step := 28.0
	var surface := PackedVector2Array()
	var x := x0
	while true:
		surface.append(Vector2(x, sin(x / wave_length * TAU + _time * 2.2) * wave_height))
		if x >= x1:
			break
		x = minf(x + step, x1)

	var body := surface.duplicate()
	body.append(Vector2(x1, size.y))
	body.append(Vector2(x0, size.y))
	draw_colored_polygon(body, deep_color)

	# Faixa mais clara abaixo da superfície, dá profundidade.
	var band := surface.duplicate()
	for i in range(surface.size() - 1, -1, -1):
		band.append(surface[i] + Vector2(0, 26))
	draw_colored_polygon(band, Color(surface_color, 0.35))
	draw_polyline(surface, surface_color, 6.0)

	# Brilhos que deslizam na água.
	var spacing := 230.0
	var start := floorf(x0 / spacing) * spacing
	var sx := start
	while sx < x1:
		var bx := sx + fmod(_time * 25.0, spacing)
		var by := 40.0 + fmod(sx * 0.37, 120.0)
		draw_line(Vector2(bx, by), Vector2(bx + 36, by), Color(1, 1, 1, 0.35), 4.0)
		sx += spacing
