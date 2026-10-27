extends CanvasLayer
## Posiciona os botões de toque nos cantos da tela, qualquer que seja a
## proporção do celular. Some em aparelhos sem tela de toque (ex.: PC).

## Mostra os botões mesmo sem tela de toque (útil para testar no PC).
@export var always_visible := false

@onready var _left: Node2D = $Left
@onready var _right: Node2D = $Right
@onready var _jump: Node2D = $Jump


func _ready() -> void:
	visible = always_visible or DisplayServer.is_touchscreen_available()
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	_left.position = Vector2(115, screen.y - 110)
	_right.position = Vector2(290, screen.y - 110)
	_jump.position = Vector2(screen.x - 130, screen.y - 120)


func set_enabled(enabled: bool) -> void:
	visible = enabled and (always_visible or DisplayServer.is_touchscreen_available())
	if not enabled:
		for action in ["move_left", "move_right", "jump"]:
			Input.action_release(action)
