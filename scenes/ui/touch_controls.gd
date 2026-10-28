extends CanvasLayer
## Controles de toque: joystick à esquerda e PULAR à direita (toque de
## novo no ar para MERGULHAR). Arraste a metade direita para girar a câmera.
## Some em aparelhos sem tela de toque (no PC: WASD, Espaço e Q/E).

@export var always_visible := false

@onready var _joystick: Node2D = $Joystick
@onready var _jump: Node2D = $Jump


func _ready() -> void:
	visible = always_visible or DisplayServer.is_touchscreen_available()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	_jump.position = Vector2(screen.x - 140, screen.y - 150)


func set_enabled(enabled: bool) -> void:
	visible = enabled and (always_visible or DisplayServer.is_touchscreen_available())
	if not enabled:
		_joystick.release()
		Input.action_release("jump")
