@tool
class_name PlayerVisual
extends Node2D
## Desenha o personagem com formas simples (sem sprites) e faz as
## animações exageradas: corrida, pulo, tombo, mergulho e comemoração.
##
## O nó fica no centro do corpo; os pés estão em y = +HALF_HEIGHT.
## As cores são exportadas para criar novas "skins" sem mexer no código.

const HALF_HEIGHT := 42.0

@export var skin_color := Color("ffcf9e")
@export var shirt_color := Color("1e88e5")
@export var shorts_color := Color("e53935")
@export var cap_color := Color("e53935")
@export var cap_logo_color := Color("ffffff")
@export var shoe_color := Color("ffffff")
@export var outline_color := Color("1a2340")
## Anima sozinho (usado na tela inicial, sem um Player como pai).
@export var demo_mode := false

var facing := 1.0

var _mode := "idle"
var _time := 0.0
var _run_phase := 0.0
var _squash := Vector2.ONE
var _spin := 0.0
var _spin_speed := 0.0
var _blink := 0.0
var _next_blink := 2.5
var _body_style: StyleBoxFlat
var _shorts_style: StyleBoxFlat


func _ready() -> void:
	_body_style = _make_style(shirt_color, 10)
	_shorts_style = _make_style(shorts_color, 6)


func _process(delta: float) -> void:
	if demo_mode or Engine.is_editor_hint():
		animate("celebrate" if demo_mode else "idle", Vector2.ZERO, delta)


func animate(mode: String, velocity: Vector2, delta: float) -> void:
	_mode = mode
	_time += delta

	if mode == "run":
		_run_phase += absf(velocity.x) * delta * 0.045
	else:
		_run_phase = lerpf(_run_phase, roundf(_run_phase / PI) * PI, minf(1.0, 10.0 * delta))

	match mode:
		"knocked":
			_spin += _spin_speed * delta
		"down":
			_spin = lerp_angle(_spin, -facing * PI * 0.5, minf(1.0, 14.0 * delta))
		_:
			_spin = lerp_angle(_spin, 0.0, minf(1.0, 12.0 * delta))

	var lean := 0.0
	match mode:
		"run":
			lean = 0.12
		"slide":
			lean = -0.22
		"celebrate":
			_squash.y += sin(_time * 14.0) * 0.012

	_squash = _squash.lerp(Vector2.ONE, minf(1.0, 12.0 * delta))

	_next_blink -= delta
	if _next_blink <= 0.0:
		_blink = 0.12
		_next_blink = randf_range(1.8, 4.0)
	_blink = maxf(0.0, _blink - delta)

	if not Engine.is_editor_hint():
		rotation = _spin + lean * facing
		scale = Vector2(facing * _squash.x, _squash.y)
		if not demo_mode:
			position = Vector2(0.0, -HALF_HEIGHT * _squash.y)
	queue_redraw()


# --- Eventos chamados pelo Player -----------------------------------------

func on_jump() -> void:
	_squash = Vector2(0.75, 1.3)


func on_landed(strength: float) -> void:
	_squash = Vector2(1.0 + 0.35 * strength, 1.0 - 0.3 * strength)


func on_knocked(direction: float) -> void:
	_spin_speed = 16.0 * (direction if direction != 0.0 else 1.0)
	_squash = Vector2(1.3, 0.7)


func on_water() -> void:
	_squash = Vector2(0.7, 1.35)


func on_respawn() -> void:
	_spin = 0.0
	_squash = Vector2(0.6, 1.4)


func on_celebrate() -> void:
	_squash = Vector2(0.8, 1.25)


# --- Desenho ---------------------------------------------------------------

func _draw() -> void:
	var t := _time
	var s := sin(_run_phase)

	# Pernas
	var foot_l := Vector2(-7, 40)
	var foot_r := Vector2(7, 40)
	match _mode:
		"run":
			foot_l = Vector2(-4 + s * 14.0, 40 - maxf(0.0, cos(_run_phase)) * 9.0)
			foot_r = Vector2(4 - s * 14.0, 40 - maxf(0.0, -cos(_run_phase)) * 9.0)
		"jump":
			foot_l = Vector2(-10, 34)
			foot_r = Vector2(9, 29)
		"fall":
			foot_l = Vector2(-13, 38)
			foot_r = Vector2(13, 35)
		"knocked", "down", "water":
			foot_l = Vector2(-14 + sin(t * 25.0) * 6.0, 34)
			foot_r = Vector2(14, 34 + cos(t * 25.0) * 6.0)
		"slide":
			foot_l = Vector2(12, 38)
			foot_r = Vector2(20, 35)
		"celebrate":
			var hop := absf(sin(t * 7.0)) * 6.0
			foot_l = Vector2(-9, 40 - hop)
			foot_r = Vector2(9, 40 - hop)
	_limb(Vector2(-7, 12), foot_l, skin_color, 9.0)
	_limb(Vector2(7, 12), foot_r, skin_color, 9.0)
	_shoe(foot_l)
	_shoe(foot_r)

	# Tronco
	_shorts_style.draw(get_canvas_item(), Rect2(-15, 2, 30, 16))
	_body_style.draw(get_canvas_item(), Rect2(-16, -16, 32, 26))
	draw_line(Vector2(-11, -4), Vector2(11, -4), Color(1, 1, 1, 0.8), 4.0)

	# Braços
	var hand_l := Vector2(-16, 8)
	var hand_r := Vector2(16, 8)
	match _mode:
		"run":
			hand_l = Vector2(-10 - s * 14.0, 5)
			hand_r = Vector2(10 + s * 14.0, 3)
		"jump":
			hand_l = Vector2(-22, -32)
			hand_r = Vector2(22, -34)
		"fall":
			hand_l = Vector2(-27, -20 + sin(t * 20.0) * 5.0)
			hand_r = Vector2(27, -22 + cos(t * 20.0) * 5.0)
		"knocked", "down", "water":
			hand_l = Vector2(-26 + sin(t * 30.0) * 6.0, -18 + cos(t * 30.0) * 8.0)
			hand_r = Vector2(26 + cos(t * 28.0) * 6.0, -20 + sin(t * 28.0) * 8.0)
		"slide":
			hand_l = Vector2(-22, -30)
			hand_r = Vector2(24, -32)
		"celebrate":
			hand_l = Vector2(-20, -42 + sin(t * 12.0) * 6.0)
			hand_r = Vector2(20, -42 - sin(t * 12.0) * 6.0)
	_limb(Vector2(-12, -10), hand_l, skin_color, 8.0)
	_limb(Vector2(12, -10), hand_r, skin_color, 8.0)

	# Cabeça
	var head := Vector2(2, -28)
	draw_circle(head, 20.0, outline_color)
	draw_circle(head, 17.0, skin_color)
	_draw_cap(head)
	_draw_face(head)

	if _mode in ["knocked", "down"]:
		for i in 3:
			var a := t * 6.0 + i * TAU / 3.0
			_star(head + Vector2(cos(a) * 28.0, -14.0 + sin(a) * 8.0), 6.0, Color("ffd54f"))


func _draw_cap(head: Vector2) -> void:
	var points := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		points.append(head + Vector2(cos(a), sin(a)) * 19.0 + Vector2(0, -3))
	draw_colored_polygon(points, cap_color)
	points.append(points[0])
	draw_polyline(points, outline_color, 3.0, true)
	draw_rect(Rect2(head + Vector2(6, -7), Vector2(20, 6)), cap_color)
	draw_rect(Rect2(head + Vector2(6, -7), Vector2(20, 6)), outline_color, false, 2.5)
	draw_circle(head + Vector2(5, -13), 4.5, cap_logo_color)


func _draw_face(head: Vector2) -> void:
	var o := outline_color
	var eye_l := head + Vector2(3, -1)
	var eye_r := head + Vector2(12, -1)
	match _mode:
		"knocked", "down":
			for e in [eye_l, eye_r]:
				draw_line(e + Vector2(-4, -4), e + Vector2(4, 4), o, 3.0)
				draw_line(e + Vector2(-4, 4), e + Vector2(4, -4), o, 3.0)
		"water":
			draw_line(eye_l + Vector2(-4, -3), eye_l + Vector2(3, 0), o, 3.0)
			draw_line(eye_l + Vector2(3, 0), eye_l + Vector2(-4, 3), o, 3.0)
			draw_line(eye_r + Vector2(4, -3), eye_r + Vector2(-3, 0), o, 3.0)
			draw_line(eye_r + Vector2(-3, 0), eye_r + Vector2(4, 3), o, 3.0)
		"celebrate":
			draw_arc(eye_l + Vector2(0, 2), 4.0, PI, TAU, 8, o, 3.0)
			draw_arc(eye_r + Vector2(0, 2), 4.0, PI, TAU, 8, o, 3.0)
		_:
			if _blink > 0.0:
				draw_line(eye_l + Vector2(-4, 0), eye_l + Vector2(4, 0), o, 3.0)
				draw_line(eye_r + Vector2(-4, 0), eye_r + Vector2(4, 0), o, 3.0)
			else:
				var look := Vector2(1.5, 1.5 if _mode == "fall" else 0.0)
				for e in [eye_l, eye_r]:
					draw_circle(e, 6.5, o)
					draw_circle(e, 5.0, Color.WHITE)
					draw_circle(e + look, 2.8, o)

	draw_circle(head + Vector2(-3, 7), 3.5, Color(1, 0.45, 0.5, 0.5))

	var mouth := head + Vector2(8, 9)
	match _mode:
		"jump", "fall", "water", "slide":
			draw_circle(mouth, 4.5, o)
			draw_circle(mouth + Vector2(0, 1), 2.5, Color("c62828"))
		"knocked", "down":
			var wave := PackedVector2Array()
			for i in 6:
				wave.append(mouth + Vector2(-6 + i * 2.4, sin(i * 2.0 + _time * 20.0) * 1.8))
			draw_polyline(wave, o, 2.5)
		"celebrate":
			var grin := PackedVector2Array()
			for i in 9:
				var a := PI * i / 8.0
				grin.append(mouth + Vector2(cos(a) * 6.0, sin(a) * 6.0 - 1.0))
			draw_colored_polygon(grin, o)
		_:
			draw_arc(mouth + Vector2(0, -2), 5.0, 0.3, PI - 0.3, 8, o, 2.5)


func _limb(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	draw_line(from, to, outline_color, width + 5.0)
	draw_circle(from, (width + 5.0) * 0.5, outline_color)
	draw_circle(to, (width + 5.0) * 0.5, outline_color)
	draw_line(from, to, color, width)
	draw_circle(from, width * 0.5, color)
	draw_circle(to, width * 0.5, color)


func _shoe(at: Vector2) -> void:
	draw_circle(at + Vector2(2, 0), 7.5, outline_color)
	draw_circle(at + Vector2(2, 0), 5.0, shoe_color)


func _star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var a := -PI * 0.5 + i * PI / 5.0
		points.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(points, color)


func _make_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(3)
	style.border_color = outline_color
	return style
