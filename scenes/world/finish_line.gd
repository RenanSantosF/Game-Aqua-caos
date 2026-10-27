@tool
class_name FinishLine
extends Area2D
## Linha de chegada com arco quadriculado. A origem fica no chão, no centro.

signal crossed(body: Node2D)

const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")

@export var width := 220.0:
	set(value):
		width = value
		queue_redraw()
@export var height := 280.0:
	set(value):
		height = value
		queue_redraw()

var _done := false


func _ready() -> void:
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _done or not (body is Player):
		return
	_done = true
	crossed.emit(body)


func _draw() -> void:
	var o := Color("1a2340")
	var half := width * 0.5
	for x in [-half, half]:
		draw_rect(Rect2(x - 12, -height, 24, height), o)
		_checker(Rect2(x - 9, -height, 18, height), 9.0)
	var banner := Rect2(-half - 20, -height - 20, width + 40, 64)
	draw_rect(banner.grow(3), o)
	_checker(banner, 16.0)
	var label := Rect2(banner.get_center() - Vector2(80, 22), Vector2(160, 44))
	draw_rect(label.grow(3), o)
	draw_rect(label, Color("e53935"))
	draw_string(FONT, Vector2(label.position.x, label.get_center().y + 12), "CHEGADA", HORIZONTAL_ALIGNMENT_CENTER, label.size.x, 32, Color.WHITE)
	# Faixa no chão.
	_checker(Rect2(-14, -4, 28, 8), 4.0)


func _checker(rect: Rect2, cell: float) -> void:
	var cols := ceili(rect.size.x / cell)
	var rows := ceili(rect.size.y / cell)
	for r in rows:
		for c in cols:
			var cell_rect := Rect2(rect.position + Vector2(c, r) * cell, Vector2(cell, cell)).intersection(rect)
			draw_rect(cell_rect, Color.WHITE if (r + c) % 2 == 0 else Color("212121"))
