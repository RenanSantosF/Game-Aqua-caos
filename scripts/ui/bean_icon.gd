class_name BeanIcon
extends Control
## Miniatura 2D do boneco com as cores de uma skin (loja e mapa).

var skin_id := "classic":
	set(value):
		skin_id = value
		queue_redraw()
var bounce := false
var _time := 0.0


func _process(delta: float) -> void:
	if bounce:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var hop := -absf(sin(_time * 6.0)) * 6.0 if bounce else 0.0
	draw_bean(self, size * 0.5 + Vector2(0, hop), minf(size.x, size.y) / 110.0, Skins.appearance(skin_id))


static func draw_bean(canvas: CanvasItem, center: Vector2, s: float, look: Dictionary) -> void:
	var o := Color("1a2340")
	var body: Color = look.get("body", Color("ff7043"))
	var belly: Color = look.get("belly", Color.WHITE)
	var cap: Color = look.get("cap", Color("1e88e5"))
	var extras: Array = look.get("extras", ["cap"])
	var c := center
	# Pés
	for side in [-1.0, 1.0]:
		canvas.draw_circle(c + Vector2(13 * side, 40) * s, 9 * s, o)
		canvas.draw_circle(c + Vector2(13 * side, 40) * s, 6.5 * s, Color.WHITE)
	# Corpo (cápsula)
	var rect := Rect2(c + Vector2(-26, -40) * s, Vector2(52, 82) * s)
	var style := StyleBoxFlat.new()
	style.bg_color = body
	style.set_corner_radius_all(int(26 * s))
	style.set_border_width_all(maxi(2, int(3 * s)))
	style.border_color = o
	style.draw(canvas.get_canvas_item(), rect)
	canvas.draw_circle(c + Vector2(0, 14) * s, 16 * s, belly)
	if "float_ring" in extras:
		canvas.draw_rect(Rect2(c + Vector2(-32, 12) * s, Vector2(64, 14) * s), cap)
	# Olhos e boca
	if "visor" in extras:
		canvas.draw_rect(Rect2(c + Vector2(-20, -26) * s, Vector2(40, 16) * s), Color("4fc3f7"))
	else:
		for side in [-1.0, 1.0]:
			canvas.draw_circle(c + Vector2(10 * side, -18) * s, 8 * s, o)
			canvas.draw_circle(c + Vector2(10 * side, -18) * s, 6 * s, Color.WHITE)
			canvas.draw_circle(c + Vector2(10 * side, -17) * s, 3 * s, o)
	if "beak" in extras:
		canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -6) * s, c + Vector2(8, -6) * s, c + Vector2(0, 4) * s]), cap)
	else:
		canvas.draw_arc(c + Vector2(0, -6) * s, 6 * s, 0.3, PI - 0.3, 10, o, 2.5 * s)
	# Acessórios na cabeça
	if "cap" in extras:
		canvas.draw_rect(Rect2(c + Vector2(-24, -42) * s, Vector2(48, 12) * s), cap)
		canvas.draw_rect(Rect2(c + Vector2(4, -34) * s, Vector2(26, 6) * s), cap)
	if "frog_eyes" in extras:
		for side in [-1.0, 1.0]:
			canvas.draw_circle(c + Vector2(14 * side, -42) * s, 10 * s, body)
			canvas.draw_circle(c + Vector2(14 * side, -43) * s, 6 * s, Color.WHITE)
			canvas.draw_circle(c + Vector2(14 * side, -43) * s, 3 * s, o)
	if "horn" in extras:
		canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-6, -38) * s, c + Vector2(6, -38) * s, c + Vector2(0, -62) * s]), Color("fff59d"))
	if "crown" in extras:
		canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-18, -36) * s, c + Vector2(-18, -52) * s, c + Vector2(-9, -42) * s, c + Vector2(0, -56) * s, c + Vector2(9, -42) * s, c + Vector2(18, -52) * s, c + Vector2(18, -36) * s]), Color("ffca28"))
	if "pirate_hat" in extras:
		canvas.draw_rect(Rect2(c + Vector2(-30, -42) * s, Vector2(60, 6) * s), cap)
		canvas.draw_rect(Rect2(c + Vector2(-16, -58) * s, Vector2(32, 18) * s), cap)
	if "antenna" in extras:
		canvas.draw_line(c + Vector2(8, -40) * s, c + Vector2(8, -58) * s, Color("78909c"), 3 * s)
		canvas.draw_circle(c + Vector2(8, -60) * s, 5 * s, Color("ff1744"))
	if "fin" in extras:
		canvas.draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -38) * s, c + Vector2(10, -38) * s, c + Vector2(-2, -60) * s]), body.darkened(0.15))
	if "headphones" in extras:
		canvas.draw_arc(c + Vector2(0, -22) * s, 28 * s, PI, TAU, 16, cap, 5 * s)
		for side in [-1.0, 1.0]:
			canvas.draw_circle(c + Vector2(27 * side, -20) * s, 8 * s, Color("e53935"))
