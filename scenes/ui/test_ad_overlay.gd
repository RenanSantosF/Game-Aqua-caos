extends CanvasLayer
## Tela simulada de anúncio/compra (MODO DE TESTE). Não é um anúncio real:
## serve para testar o fluxo do jogo antes de integrar os SDKs oficiais.

signal done(result: bool)

var _kind := ""
var _time := 0.0
var _duration := 5.0
var _close: Button
var _action: Button
var _timer_label: Label
var _ball: Panel
var _result := false


func run(kind: String, price: String) -> bool:
	_kind = kind
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_build(price)
	var result: bool = await done
	get_tree().paused = false
	return result


func _build(price: String) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0.02, 0.1, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(620, 0)
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	var badge := Label.new()
	badge.text = tr("AD_TEST_BADGE")
	badge.add_theme_color_override("font_color", Color("ffd54f"))
	badge.add_theme_font_size_override("font_size", 22)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(badge)

	var title := Label.new()
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var stage := Control.new()
	stage.custom_minimum_size = Vector2(0, 150)
	box.add_child(stage)
	_ball = Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("ff7043")
	style.set_corner_radius_all(40)
	_ball.add_theme_stylebox_override("panel", style)
	_ball.size = Vector2(80, 80)
	stage.add_child(_ball)

	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 26)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_timer_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_close = Button.new()
	_close.focus_mode = Control.FOCUS_NONE
	buttons.add_child(_close)
	_action = Button.new()
	_action.focus_mode = Control.FOCUS_NONE
	buttons.add_child(_action)

	match _kind:
		"interstitial":
			title.text = tr("AD_TEST_TITLE")
			_close.text = tr("BTN_CLOSE")
			_close.disabled = true
			_action.visible = false
			_close.pressed.connect(_finish.bind(true))
		"rewarded":
			title.text = tr("AD_REWARD_TITLE")
			_close.text = tr("BTN_CANCEL")
			_action.text = tr("AD_REWARD_CLAIM")
			_action.disabled = true
			_close.pressed.connect(_finish.bind(false))
			_action.pressed.connect(_finish.bind(true))
		"purchase":
			title.text = tr("BUY_TEST_TITLE")
			_duration = 0.0
			_timer_label.text = tr("BUY_TEST_PRICE") % price
			_close.text = tr("BTN_CANCEL")
			_action.text = tr("BTN_BUY")
			_close.pressed.connect(_finish.bind(false))
			_action.pressed.connect(_finish.bind(true))
	panel.pivot_offset = Vector2(310, 200)
	panel.scale = Vector2(0.7, 0.7)
	create_tween().tween_property(panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if _ball == null:
		return
	_time += delta
	var stage_width := 540.0
	_ball.position = Vector2(20 + (sin(_time * 2.0) * 0.5 + 0.5) * stage_width, 60 - absf(sin(_time * 6.0)) * 60)
	if _kind == "purchase":
		return
	var left := maxf(0.0, _duration - _time)
	if left > 0.0:
		_timer_label.text = tr("AD_TEST_WAIT") % ceili(left)
	else:
		_timer_label.text = tr("AD_TEST_DONE")
	if _kind == "interstitial":
		_close.disabled = _time < 3.0
	elif _kind == "rewarded":
		_action.disabled = left > 0.0


func _finish(result: bool) -> void:
	Sfx.play("click")
	done.emit(result)
