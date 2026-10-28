class_name CoinIcon
extends Control
## Moedinha desenhada por código, com brilho girando.

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var squeeze := 0.75 + 0.25 * absf(cos(_time * 2.0))
	draw_set_transform(c, 0.0, Vector2(squeeze, 1.0))
	draw_circle(Vector2.ZERO, r, Color("1a2340"))
	draw_circle(Vector2.ZERO, r - 3.0, Color("ffc107"))
	draw_circle(Vector2.ZERO, r * 0.58, Color("ffa000"))
	draw_rect(Rect2(-r * 0.12, -r * 0.4, r * 0.24, r * 0.8), Color("fff8e1"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
