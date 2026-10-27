extends CanvasLayer
## Tela de resultado: estrelas, tempo, recorde, moedas ganhas e botões.

signal next_requested
signal retry_requested
signal menu_requested

@onready var _root: Control = $Root
@onready var _panel: Control = %Panel
@onready var _stars: Array[Control] = [%Star1, %Star2, %Star3]


func _ready() -> void:
	_root.hide()
	%NextButton.pressed.connect(func(): Sfx.play("click"); next_requested.emit())
	%RetryButton.pressed.connect(func(): Sfx.play("click"); retry_requested.emit())
	%MenuButton.pressed.connect(func(): Sfx.play("click"); menu_requested.emit())


func show_result(level: int, level_name: String, time: float, falls: int, place: int, racers: int, result: Dictionary) -> void:
	%LevelLabel.text = "FASE %d · %s" % [level, level_name.to_upper()]
	%Title.text = "%dº LUGAR!" % place if place <= 3 else "CHEGOU!"
	%PlaceLabel.text = "Você chegou em %dº de %d" % [place, racers]
	%TimeLabel.text = "TEMPO: %s" % Game.format_time(time)
	%BestLabel.text = "RECORDE: %s" % Game.format_time(result.get("best_time", INF))
	%NewRecordLabel.visible = result.get("new_record", false)
	%FallsLabel.text = "QUEDAS NA ÁGUA: %d" % falls
	var lines := "Moedas coletadas: %d\nChegada: +%d" % [result.coins_collected, result.finish_bonus]
	if result.no_fall_bonus > 0:
		lines += "\nSem cair: +%d" % result.no_fall_bonus
	if result.place_bonus > 0:
		lines += "\n%dº lugar: +%d" % [place, result.place_bonus]
	%CoinsDetail.text = lines
	%CoinsTotal.text = "+%d MOEDAS" % result.coins_total

	var earned: int = result.stars
	for i in 3:
		_stars[i].modulate = Color(1, 1, 1, 0.25)
		_stars[i].scale = Vector2.ONE

	_root.show()
	_root.modulate.a = 0.0
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.6, 0.6)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(_root, "modulate:a", 1.0, 0.2)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(0.1)
	for i in earned:
		var star := _stars[i]
		star.pivot_offset = star.size * 0.5
		tween.chain().tween_callback(func(): star.modulate = Color("ffd54f"); star.scale = Vector2(1.8, 1.8); Sfx.play("coin", 0.0, 0.0))
		tween.chain().tween_property(star, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
