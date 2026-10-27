extends CanvasLayer
## HUD da corrida: cronômetro, quedas, contagem regressiva, avisos e pausa.

signal restart_requested
signal menu_requested

@onready var _time_label: Label = %TimeLabel
@onready var _falls_label: Label = %FallsLabel
@onready var _countdown: Label = %Countdown
@onready var _toast: Label = %Toast
@onready var _pause_button: Button = %PauseButton
@onready var _pause_menu: Control = %PauseMenu

var _toast_tween: Tween


func _ready() -> void:
	_countdown.hide()
	_toast.hide()
	_pause_menu.hide()
	_pause_button.pressed.connect(set_paused.bind(true))
	%ResumeButton.pressed.connect(set_paused.bind(false))
	%RestartButton.pressed.connect(_on_restart)
	%MenuButton.pressed.connect(_on_menu)


func _notification(what: int) -> void:
	# Botão "voltar" do Android pausa a corrida em vez de fechar o jogo.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and _pause_button.visible:
		set_paused(not get_tree().paused)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _pause_button.visible:
		set_paused(not get_tree().paused)


func set_time(seconds: float) -> void:
	_time_label.text = Game.format_time(seconds)


func set_falls(count: int) -> void:
	_falls_label.text = "QUEDAS: %d" % count


func show_countdown(text: String) -> void:
	_countdown.text = text
	_countdown.show()
	_countdown.pivot_offset = _countdown.size * 0.5
	_countdown.scale = Vector2(1.8, 1.8)
	_countdown.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_property(_countdown, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if text.length() > 1:
		tween.tween_interval(0.35)
		tween.tween_property(_countdown, "modulate:a", 0.0, 0.3)
		tween.tween_callback(_countdown.hide)


func toast(text: String) -> void:
	if _toast_tween:
		_toast_tween.kill()
	_toast.text = text
	_toast.show()
	_toast.modulate.a = 1.0
	_toast.pivot_offset = _toast.size * 0.5
	_toast.scale = Vector2(0.5, 0.5)
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_interval(1.0)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
	_toast_tween.tween_callback(_toast.hide)


func set_race_finished() -> void:
	_pause_button.hide()


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_pause_menu.visible = paused


func _on_restart() -> void:
	set_paused(false)
	restart_requested.emit()


func _on_menu() -> void:
	set_paused(false)
	menu_requested.emit()
