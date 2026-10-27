@tool
extends Node2D
## Camada de cenário desenhada por código (sem imagens), usada dentro de
## um Parallax2D. Desenha um trecho de "width" pixels que se repete.

enum Kind { CLOUDS, FAR, MID }

@export var kind := Kind.FAR:
	set(value):
		kind = value
		queue_redraw()
@export var width := 1600.0
## Altura da linha do horizonte (onde ficam as bases do cenário).
@export var ground_y := 600.0
@export var random_seed := 7

const OUTLINE := Color("1a2340")
const SKY := Color("8fd3ff")


func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	match kind:
		Kind.CLOUDS:
			_draw_clouds(rng)
		Kind.FAR:
			_draw_far(rng)
		Kind.MID:
			_draw_mid(rng)


func _draw_clouds(rng: RandomNumberGenerator) -> void:
	for i in 6:
		var center := Vector2(i * width / 6.0 + rng.randf_range(0, 120), rng.randf_range(40, 220))
		var size := rng.randf_range(0.7, 1.3)
		for j in 4:
			var offset := Vector2((j - 1.5) * 34.0 * size, -absf(j - 1.5) * -8.0 * size)
			draw_circle(center + offset, (40.0 - absf(j - 1.5) * 8.0) * size, Color(1, 1, 1, 0.92))
		draw_rect(Rect2(center + Vector2(-70, 0) * size, Vector2(140, 26) * size), Color(1, 1, 1, 0.92))


func _draw_far(rng: RandomNumberGenerator) -> void:
	# Colinas
	for i in 7:
		var x := i * width / 6.0
		draw_circle(Vector2(x, ground_y + 120), rng.randf_range(220, 300), _haze(Color("66bb6a"), 0.45))
	# Torres e tobogãs do parque ao fundo
	var tower_colors := [Color("ab47bc"), Color("ff7043"), Color("29b6f6"), Color("ffca28")]
	for i in 3:
		var x := 200.0 + i * width / 3.0 + rng.randf_range(-60, 60)
		var h := rng.randf_range(260, 380)
		var color: Color = tower_colors[i % tower_colors.size()]
		draw_rect(Rect2(x - 30, ground_y - h, 60, h), _haze(Color("eceff1"), 0.4))
		for level in int(h / 60.0):
			draw_rect(Rect2(x - 38, ground_y - h + level * 60.0, 76, 10), _haze(color, 0.4))
		var roof := PackedVector2Array([Vector2(x - 50, ground_y - h), Vector2(x, ground_y - h - 50), Vector2(x + 50, ground_y - h)])
		draw_colored_polygon(roof, _haze(color, 0.35))
		# Tobogã em zigue-zague
		var tube := PackedVector2Array()
		for k in 25:
			var t := k / 24.0
			tube.append(Vector2(x + sin(t * TAU * 1.5) * 90.0 + t * 60.0, ground_y - h + 20 + t * (h - 20)))
		draw_polyline(tube, _haze(tower_colors[(i + 1) % tower_colors.size()], 0.35), 22.0, true)


func _draw_mid(rng: RandomNumberGenerator) -> void:
	for i in 5:
		var x := i * width / 5.0 + rng.randf_range(0, 150)
		_palm(Vector2(x, ground_y), rng.randf_range(170, 240), rng.randf_range(-0.25, 0.25))
	# Cerquinha
	for i in int(width / 40.0):
		var x := i * 40.0
		draw_rect(Rect2(x, ground_y - 40, 10, 40), _haze(Color.WHITE, 0.15))
	draw_rect(Rect2(0, ground_y - 32, width, 8), _haze(Color.WHITE, 0.15))


func _palm(base: Vector2, height: float, bend: float) -> void:
	var trunk := PackedVector2Array()
	for k in 9:
		var t := k / 8.0
		trunk.append(base + Vector2(sin(t * 1.4) * bend * height, -t * height))
	draw_polyline(trunk, _haze(Color("5d4037"), 0.2), 18.0, true)
	draw_polyline(trunk, _haze(Color("8d6e63"), 0.2), 12.0, true)
	var top := trunk[trunk.size() - 1]
	for angle in [-2.9, -2.3, -1.85, -1.3, -0.85, -0.25]:
		var leaf := PackedVector2Array()
		var dir := Vector2.from_angle(angle)
		var side := dir.orthogonal()
		for k in 9:
			var t := k / 8.0
			var p := top + dir * t * 100.0 + Vector2(0, t * t * 40.0)
			leaf.append(p + side * sin(t * PI) * 14.0)
		for k in range(7, 0, -1):
			var t := k / 8.0
			var p := top + dir * t * 100.0 + Vector2(0, t * t * 40.0)
			leaf.append(p - side * sin(t * PI) * 14.0)
		draw_colored_polygon(leaf, _haze(Color("43a047") if angle < -1.5 else Color("2e7d32"), 0.2))


func _haze(color: Color, amount: float) -> Color:
	return color.lerp(SKY, amount)
