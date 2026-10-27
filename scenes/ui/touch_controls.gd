extends CanvasLayer
## Controles de toque: joystick à esquerda, PULAR e MERGULHAR à direita.
## Some em aparelhos sem tela de toque (no PC use WASD, Espaço e Shift).

@export var always_visible := false

@onready var _joystick: Node2D = $Joystick
@onready var _jump: Node2D = $Jump
@onready var _dive: Node2D = $Dive


func _ready() -> void:
	visible = always_visible or DisplayServer.is_touchscreen_available()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	_jump.position = Vector2(screen.x - 140, screen.y - 150)
	_dive.position = Vector2(screen.x - 310, screen.y - 95)


func set_enabled(enabled: bool) -> void:
	visible = enabled and (always_visible or DisplayServer.is_touchscreen_available())
	if not enabled:
		_joystick.release()
		for action in ["jump", "dive"]:
			Input.action_release(action)
