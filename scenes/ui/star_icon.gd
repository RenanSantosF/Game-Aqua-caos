extends Control
## Estrela desenhada por código (a fonte não tem o símbolo ★).

@export var fill := Color("ffd54f")


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var r := radius if i % 2 == 0 else radius * 0.45
		outer.append(center + Vector2(cos(a), sin(a)) * r)
		var r2 := (radius - 6.0) if i % 2 == 0 else (radius - 6.0) * 0.45
		inner.append(center + Vector2(cos(a), sin(a)) * r2)
	draw_colored_polygon(outer, Color("1a2340"))
	draw_colored_polygon(inner, fill)
