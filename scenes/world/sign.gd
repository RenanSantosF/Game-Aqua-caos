@tool
extends Node2D
## Placa de tutorial no cenário. A origem é o pé da placa (no chão).

const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")

@export_multiline var text := "Placa":
	set(value):
		text = value
		queue_redraw()
@export var board_size := Vector2(230, 80):
	set(value):
		board_size = value
		queue_redraw()
@export var font_size := 22


func _draw() -> void:
	var o := Color("1a2340")
	draw_rect(Rect2(-7, -80, 14, 80), o)
	draw_rect(Rect2(-4, -80, 8, 80), Color("8d6e63"))
	var rect := Rect2(-board_size.x * 0.5, -80 - board_size.y, board_size.x, board_size.y)
	draw_rect(rect.grow(4), o)
	draw_rect(rect, Color("fffdf5"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 10)), Color("29b6f6"))
	var lines := text.split("\n").size()
	var line_height := FONT.get_height(font_size)
	var y := rect.get_center().y - line_height * lines * 0.5 + FONT.get_ascent(font_size) + 4
	draw_multiline_string(FONT, Vector2(rect.position.x + 8, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 16, font_size, -1, Color("0d47a1"))
