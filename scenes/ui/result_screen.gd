extends CanvasLayer
## Tela de resultado: estrelas, tempo, recorde, moedas ganhas e botões.

signal next_requested
signal retry_requested
signal menu_requested

var _result: Dictionary = {}

@onready var _root: Control = $Root
@onready var _panel: Control = %Panel
@onready var _stars: Array[Control] = [%Star1, %Star2, %Star3]


func _ready() -> void:
	_root.hide()
	%NextButton.pressed.connect(func(): Sfx.play("click"); next_requested.emit())
	%RetryButton.pressed.connect(func(): Sfx.play("click"); retry_requested.emit())
	%MenuButton.pressed.connect(func(): Sfx.play("click"); menu_requested.emit())
	%DoubleButton.pressed.connect(_on_double)


func show_result(level: int, level_name: String, time: float, falls: int, place: int, racers: int, result: Dictionary) -> void:
	_result = result
	%LevelLabel.text = tr("HUD_LEVEL") % [level, level_name.to_upper()]
	%Title.text = tr("RESULT_PLACE") % Themes.ordinal(place) if place <= 3 else tr("RESULT_FINISHED")
	%PlaceLabel.text = tr("RESULT_YOU_PLACED") % [Themes.ordinal(place), racers]
	%TimeLabel.text = tr("RESULT_TIME") % Game.format_time(time)
	%BestLabel.text = tr("RESULT_BEST") % Game.format_time(result.get("best_time", INF))
	%NewRecordLabel.visible = result.get("new_record", false)
	%FallsLabel.text = tr("RESULT_FALLS") % falls
	var lines := tr("RESULT_COINS_COLLECTED") % result.coins_collected
	# Bônus numa linha só, para o painel caber em telas baixas.
	var bonuses: Array[String] = [tr("RESULT_FINISH_BONUS") % result.finish_bonus]
	if result.no_fall_bonus > 0:
		bonuses.append(tr("RESULT_NO_FALL_BONUS") % result.no_fall_bonus)
	if result.place_bonus > 0:
		bonuses.append(tr("RESULT_PLACE_BONUS") % [Themes.ordinal(place), result.place_bonus])
	lines += "\n" + "  ·  ".join(bonuses)
	if result.get("replay", false):
		lines += "\n" + tr("RESULT_REPLAY")
	%CoinsDetail.text = lines
	%CoinsTotal.text = tr("RESULT_TOTAL") % result.coins_total
	%DoubleButton.visible = true

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


## Anúncio recompensado opcional: dobra as moedas ganhas na fase.
func _on_double() -> void:
	%DoubleButton.disabled = true
	if await Monetization.show_rewarded():
		var extra: int = _result.get("coins_total", 0)
		Game.add_coins(extra)
		%CoinsTotal.text = tr("RESULT_TOTAL") % (extra * 2)
		Sfx.play("unlock")
		%DoubleButton.visible = false
	else:
		%DoubleButton.disabled = false
