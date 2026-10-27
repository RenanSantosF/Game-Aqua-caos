@tool
class_name WaterSlide
extends StaticBody2D
## Escorregador molhado: rampa que acelera o personagem na descida.
## A origem é o topo da rampa; "drop" é onde ela termina.

@export var drop := Vector2(520, 220):
	set(value):
		drop = value
		_refresh()
@export var thickness := 36.0:
	set(value):
		thickness = value
		_refresh()
## Até onde descem as colunas (medido a partir do topo da rampa).
@export var support_depth := 280.0:
	set(value):
		support_depth = value
		queue_redraw()
@export var slide_color := Color("ffb300")
@export var rail_color := Color("e53935")

const OUTLINE := Color("1a2340")

var _time := 0.0


func _ready() -> void:
	_refresh()
	if not Engine.is_editor_hint():
		add_to_group("slippery")


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var poly := get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if poly:
		poly.polygon = _shape_points()
	queue_redraw()


func _shape_points() -> PackedVector2Array:
	return PackedVector2Array([Vector2.ZERO, drop, drop + Vector2(0, thickness), Vector2(0, thickness)])


func _draw() -> void:
	var steps := maxi(1, int(drop.x / 130.0))
	for i in steps + 1:
		var k := float(i) / steps
		var top := drop * k + Vector2(0, thickness)
		if top.y < support_depth:
			draw_rect(Rect2(top.x - 9, top.y, 18, support_depth - top.y), OUTLINE)
			draw_rect(Rect2(top.x - 6, top.y, 12, support_depth - top.y), Color("8e99b8"))

	var points := _shape_points()
	draw_colored_polygon(points, slide_color)
	var shade := PackedVector2Array([Vector2(0, thickness * 0.6), drop + Vector2(0, thickness * 0.6), drop + Vector2(0, thickness), Vector2(0, thickness)])
	draw_colored_polygon(shade, slide_color.darkened(0.2))
	points.append(points[0])
	draw_polyline(points, OUTLINE, 3.0, true)
	draw_line(Vector2(0, -2), drop + Vector2(0, -2), Color("4fc3f7"), 6.0)
	draw_line(Vector2(0, -8), drop + Vector2(0, -8), rail_color, 5.0)

	# Filetes de água descendo.
	var dir := drop.normalized()
	var length := drop.length()
	for i in 6:
		var d := fmod(_time * 260.0 + i * length / 6.0, length)
		var p := dir * d + Vector2(0, 6)
		draw_line(p, p + dir * 30.0, Color(1, 1, 1, 0.75), 3.0)
