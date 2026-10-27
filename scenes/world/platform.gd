@tool
class_name Platform
extends StaticBody2D
## Plataforma fixa feita de blocos coloridos (estilo brinquedo inflável).
## A origem é o canto superior esquerdo; ajuste "size" no Inspetor.

@export var size := Vector2(400, 40):
	set(value):
		size = value
		_refresh()
@export var colors: PackedColorArray = [Color("e53935"), Color("1e88e5"), Color("fdd835")]
@export var block_width := 80.0:
	set(value):
		block_width = maxf(value, 10.0)
		queue_redraw()
## Altura das colunas de apoio desenhadas abaixo da plataforma (0 = sem colunas).
@export var pillar_depth := 140.0:
	set(value):
		pillar_depth = value
		queue_redraw()
## Superfície molhada: o personagem escorrega.
@export var slippery := false:
	set(value):
		slippery = value
		queue_redraw()

const OUTLINE := Color("1a2340")
const ROW_HEIGHT := 40.0


func _ready() -> void:
	_refresh()
	if slippery and not Engine.is_editor_hint():
		add_to_group("slippery")


func _refresh() -> void:
	if not is_inside_tree():
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		(shape_node.shape as RectangleShape2D).size = size
		shape_node.position = size * 0.5
	queue_redraw()


func _draw() -> void:
	if pillar_depth > 0.0:
		var pillars := [size.x * 0.5] if size.x < 220.0 else [size.x * 0.2, size.x * 0.8]
		for x in pillars:
			draw_rect(Rect2(x - 11, size.y - 2, 22, pillar_depth), OUTLINE)
			draw_rect(Rect2(x - 8, size.y - 2, 16, pillar_depth), Color("5c6f99"))

	var count := maxi(1, roundi(size.x / block_width))
	var bw := size.x / count
	var rows := maxi(1, ceili(size.y / ROW_HEIGHT))
	var rh := size.y / rows
	for row in rows:
		var offset := bw * 0.5 if row % 2 == 1 else 0.0
		for i in range(-1, count + 1):
			var x0 := clampf(i * bw + offset, 0.0, size.x)
			var x1 := clampf((i + 1) * bw + offset, 0.0, size.x)
			if x1 - x0 < 1.0:
				continue
			var color: Color = colors[posmod(i + row, colors.size())] if colors.size() > 0 else Color.WHITE
			var rect := Rect2(x0, row * rh, x1 - x0, rh)
			draw_rect(rect, color)
			if row == 0:
				draw_rect(Rect2(rect.position, Vector2(rect.size.x, minf(8.0, rh * 0.3))), color.lightened(0.4))
			draw_rect(Rect2(rect.position + Vector2(0, rh - 5), Vector2(rect.size.x, 5)), color.darkened(0.25))
			draw_rect(rect, OUTLINE, false, 2.0)

	if slippery:
		for i in int(size.x / 60.0):
			var x := 20.0 + i * 60.0
			draw_line(Vector2(x, 4), Vector2(x + 24, 4), Color(1, 1, 1, 0.8), 3.0)
	draw_rect(Rect2(Vector2.ZERO, size), OUTLINE, false, 3.0)
