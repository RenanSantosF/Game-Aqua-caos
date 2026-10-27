extends Control
## Tela inicial: título e botão JOGAR.

@onready var _hero: Node2D = $Hero


func _ready() -> void:
	%PlayButton.pressed.connect(Game.play_level)
	get_viewport().size_changed.connect(_layout)
	_layout()


func _notification(what: int) -> void:
	# Botão "voltar" do Android na tela inicial fecha o jogo.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		get_tree().quit()


func _layout() -> void:
	var screen := get_viewport_rect().size
	_hero.position = Vector2(screen.x * 0.16, screen.y - 200)
