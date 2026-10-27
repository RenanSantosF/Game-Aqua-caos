extends Node3D
## Menu inicial em 3D: cenário vivo, boneco comemorando e câmera girando.
## Botões: JOGAR (próxima fase), FASES (escolher), som liga/desliga.

const PAGE_SIZE := 20

var _time := 0.0
var _page := 0

@onready var _camera: Camera3D = $Camera3D
@onready var _level_select: Control = %LevelSelect
@onready var _grid: GridContainer = %Grid


func _ready() -> void:
	var theme := Themes.for_level(1)
	WorldSetup.apply_environment($WorldEnvironment, $Sun, theme)
	WorldSetup.add_water(self, theme, 0.0, 240.0, 240.0)
	$Decor.build(theme, 40.0, -40.0, 7)
	_build_podium(theme)

	%PlayButton.pressed.connect(_on_play)
	%LevelsButton.pressed.connect(_open_levels)
	%CloseButton.pressed.connect(_close_levels)
	%PrevButton.pressed.connect(_change_page.bind(-1))
	%NextButton.pressed.connect(_change_page.bind(1))
	%SoundButton.pressed.connect(_toggle_sound)
	_level_select.hide()
	_refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _level_select.visible:
			_close_levels()
		else:
			get_tree().quit()


func _process(delta: float) -> void:
	_time += delta
	var angle := _time * 0.12
	_camera.position = Vector3(sin(angle) * 8.5, 3.2 + sin(_time * 0.4) * 0.3, cos(angle) * 8.5)
	_camera.look_at(Vector3(0, 1.4, 0))
	# Desloca o foco para o boneco ficar à esquerda da tela.
	_camera.position += _camera.global_transform.basis.x * 2.6


func _build_podium(theme: Dictionary) -> void:
	var palette: Array = theme.palette
	var podium := $Podium as Node3D
	Build.cylinder(podium, 2.6, 1.6, palette[1], Vector3(0, -0.8, 0), 2.4, true)
	Build.cylinder(podium, 2.65, 0.2, Color.WHITE, Vector3(0, -0.05, 0))
	for i in 8:
		var a := i * TAU / 8.0
		Build.sphere(podium, 0.22, palette[i % palette.size()], Vector3(cos(a) * 2.45, 0.1, sin(a) * 2.45))
	var ring := Build.torus(podium, 3.0, 3.6, palette[0], Vector3(0, -1.15, 0))
	ring.scale = Vector3(1, 1.5, 1)


func _refresh() -> void:
	%CoinsLabel.text = str(Game.coins)
	%PlayButton.text = "JOGAR  FASE %d" % Game.unlocked_level
	%NextLevelName.text = Themes.level_name(Game.unlocked_level).to_upper()
	var total := 0
	for key in Game.stars:
		total += int(Game.stars[key])
	%StarsLabel.text = "%d estrelas · %d fases concluídas" % [total, Game.unlocked_level - 1]
	%SoundButton.text = "SOM: SIM" if Game.sound_enabled else "SOM: NÃO"


func _on_play() -> void:
	Sfx.play("click")
	Game.play_level(Game.unlocked_level)


func _toggle_sound() -> void:
	Game.set_sound_enabled(not Game.sound_enabled)
	Sfx.play("click")
	_refresh()


func _open_levels() -> void:
	Sfx.play("click")
	_page = (Game.unlocked_level - 1) / PAGE_SIZE
	_fill_grid()
	_level_select.show()


func _close_levels() -> void:
	Sfx.play("click")
	_level_select.hide()


func _change_page(step: int) -> void:
	Sfx.play("click")
	_page = maxi(0, _page + step)
	_fill_grid()


func _fill_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	%PageLabel.text = "FASES %d – %d" % [_page * PAGE_SIZE + 1, (_page + 1) * PAGE_SIZE]
	%PrevButton.disabled = _page == 0
	for i in PAGE_SIZE:
		var level := _page * PAGE_SIZE + i + 1
		var button := Button.new()
		button.custom_minimum_size = Vector2(150, 92)
		button.focus_mode = Control.FOCUS_NONE
		var locked := level > Game.unlocked_level
		var stars := Game.get_stars(level)
		button.text = "%d\n%s" % [level, "bloqueada" if locked else "%d/3 estrelas" % stars]
		button.add_theme_font_size_override("font_size", 24)
		button.disabled = locked
		button.pressed.connect(func(): Sfx.play("click"); Game.play_level(level))
		_grid.add_child(button)
