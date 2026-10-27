extends Node2D
## Joystick analógico de toque (metade esquerda da tela).
## Onde o dedo encostar vira o centro do joystick. Aperta as ações
## move_* com intensidade proporcional, então o teclado continua funcionando.

@export var radius := 95.0
## Fração da largura da tela que aceita o joystick.
@export var area_fraction := 0.45

var _touch_index := -1
var _origin := Vector2.ZERO
var _knob := Vector2.ZERO
var _rest := Vector2.ZERO


func _ready() -> void:
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	_rest = Vector2(170, screen.y - 150)
	if _touch_index == -1:
		_origin = _rest
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var screen := get_viewport().get_visible_rect().size
		if touch.pressed and _touch_index == -1 and touch.position.x < screen.x * area_fraction and touch.position.y > screen.y * 0.25:
			_touch_index = touch.index
			_origin = touch.position
			_knob = Vector2.ZERO
			_apply()
		elif not touch.pressed and touch.index == _touch_index:
			release()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _touch_index:
			_knob = (drag.position - _origin).limit_length(radius)
			_apply()


func release() -> void:
	_touch_index = -1
	_knob = Vector2.ZERO
	_origin = _rest
	_apply()


func _apply() -> void:
	var v := _knob / radius
	_set_action("move_left", maxf(0.0, -v.x))
	_set_action("move_right", maxf(0.0, v.x))
	_set_action("move_forward", maxf(0.0, -v.y))
	_set_action("move_back", maxf(0.0, v.y))
	queue_redraw()


func _set_action(action: String, strength: float) -> void:
	if strength > 0.05:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _draw() -> void:
	var active := _touch_index != -1
	draw_circle(_origin, radius, Color(0.05, 0.2, 0.47, 0.45 if active else 0.3))
	draw_arc(_origin, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.8 if active else 0.5), 5.0, true)
	draw_circle(_origin + _knob, radius * 0.42, Color(1, 1, 1, 0.85 if active else 0.55))
	draw_arc(_origin + _knob, radius * 0.42, 0.0, TAU, 32, Color(0.05, 0.2, 0.47, 0.6), 3.0, true)
