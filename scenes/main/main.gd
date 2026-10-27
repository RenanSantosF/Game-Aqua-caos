extends Control
## Cena de teste da ETAPA 1.
## Mostra a resolução real da tela para confirmar que o modo
## horizontal e o redimensionamento adaptável estão funcionando.

@onready var info_label: Label = $Center/VBox/InfoLabel


func _ready() -> void:
	get_viewport().size_changed.connect(_atualizar_info)
	_atualizar_info()


func _atualizar_info() -> void:
	var tela: Vector2i = DisplayServer.window_get_size()
	var area_visivel: Vector2 = get_viewport_rect().size
	var orientacao := "HORIZONTAL" if tela.x >= tela.y else "VERTICAL (verifique a configuração!)"
	info_label.text = "Tela física: %d x %d\nÁrea do jogo: %d x %d\nOrientação: %s" % [
		tela.x, tela.y, int(area_visivel.x), int(area_visivel.y), orientacao
	]
