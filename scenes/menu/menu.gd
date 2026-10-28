extends Node3D
## Tela inicial: cenário 3D vivo, boneco com a skin equipada, logo animado,
## presente diário e botões JOGAR (mapa), LOJA e AJUSTES.

const SHOP_SCENE := "res://scenes/shop/shop.tscn"

var _time := 0.0
var _coins_label: Label
var _ui: Control

@onready var _camera: Camera3D = $Camera3D
@onready var _hero: CharacterModel = $Hero


func _ready() -> void:
	var theme := Themes.for_level(1)
	WorldSetup.apply_environment($WorldEnvironment, $Sun, theme)
	WorldSetup.add_water(self, theme, Vector3.ZERO, Vector2(240, 240))
	var route: Array[Vector3] = []
	for i in 48:
		var a := i * TAU / 48.0
		route.append(Vector3(cos(a) * 9.0, 0, sin(a) * 9.0))
	$Decor.build(theme, route, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, -6)), Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(0, 0, 6)), 7)
	_build_podium(theme)
	_hero.set_colors(Game.equipped_colors())
	_build_ui()
	Music.play("menu")
	Game.coins_changed.connect(func(total: int): _coins_label.text = str(total))
	if Game.daily_available():
		await get_tree().create_timer(0.8).timeout
		_show_daily()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		var popup := _ui.get_node_or_null("Popup")
		if popup:
			popup.queue_free()
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


# --- Interface --------------------------------------------------------------------------

func _build_ui() -> void:
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$UI.add_child(_ui)
	var bubbles := UiKit.bubbles(_ui, 16)
	bubbles.position = Vector2(640, 760)

	# Logo
	var logo := VBoxContainer.new()
	logo.position = Vector2(40, 18)
	logo.add_theme_constant_override("separation", -22)
	_ui.add_child(logo)
	var aqua := UiKit.label("AQUA", 104, Color("80deff"), 24)
	var caos := UiKit.label("CAOS", 124, Color("ff9800"), 24)
	logo.add_child(aqua)
	logo.add_child(caos)
	var ribbon := UiKit.panel(Color("1565c0"), 16)
	ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ribbon.add_child(UiKit.label(tr("MENU_SUBTITLE"), 34, Color.WHITE, 6))
	logo.add_child(ribbon)
	_wobble(aqua, 0.0)
	_wobble(caos, 0.4)

	# Topo direito: moedas e ajustes
	var top := HBoxContainer.new()
	UiKit.place(top, Control.PRESET_TOP_RIGHT, -470, 16, -20, 86)
	top.alignment = BoxContainer.ALIGNMENT_END
	top.add_theme_constant_override("separation", 12)
	_ui.add_child(top)
	var pill := UiKit.coin_pill()
	top.add_child(pill[0])
	_coins_label = pill[1]
	var settings := UiKit.button(tr("BTN_SETTINGS"), "blue", 24)
	settings.pressed.connect(_show_settings)
	top.add_child(settings)

	# Painel de jogar
	var play_panel := UiKit.panel()
	UiKit.place(play_panel, Control.PRESET_BOTTOM_RIGHT, -500, -380, -40, -40)
	play_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	play_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ui.add_child(play_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	play_panel.add_child(column)
	column.add_child(UiKit.label(tr("MENU_NEXT_LEVEL"), 22))
	column.add_child(UiKit.label(Themes.level_name(Game.unlocked_level).to_upper(), 32, Color("ffd54f")))
	var play := UiKit.button(tr("MENU_PLAY_LEVEL") % Game.unlocked_level, "green", 46, Vector2(0, 96))
	play.pressed.connect(Game.go_to_map)
	column.add_child(play)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	var shop := UiKit.button(tr("BTN_SHOP"), "pink", 30)
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.pressed.connect(func(): Transition.change_scene(SHOP_SCENE))
	row.add_child(shop)
	var map := UiKit.button(tr("BTN_MAP"), "yellow", 30)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.pressed.connect(Game.go_to_map)
	row.add_child(map)
	column.add_child(UiKit.label(tr("MENU_STATS") % [Game.total_stars(), Game.unlocked_level - 1], 22))

	var tagline := UiKit.label(tr("MENU_TAGLINE"), 30)
	UiKit.place(tagline, Control.PRESET_BOTTOM_LEFT, 40, -80, 760, -30)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ui.add_child(tagline)

	await get_tree().process_frame
	UiKit.slide_in(logo, Vector2(-400, 0), 0.1)
	UiKit.slide_in(play_panel, Vector2(500, 0), 0.25)
	UiKit.slide_in(top, Vector2(0, -120), 0.35)
	UiKit.slide_in(tagline, Vector2(0, 120), 0.45)
	await get_tree().create_timer(0.8).timeout
	UiKit.pulse(play, 0.05, 1.2)


func _wobble(control: Control, delay: float) -> void:
	await get_tree().create_timer(delay + 0.6).timeout
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "rotation", 0.04, 1.1).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "rotation", -0.04, 1.1).set_trans(Tween.TRANS_SINE)


func _popup(title: String) -> VBoxContainer:
	var holder := Control.new()
	holder.name = "Popup"
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(holder)
	UiKit.dim(holder)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(center)
	var panel := UiKit.panel()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(520, 0)
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	column.add_child(UiKit.label(title, 50, Color("ffd54f"), 12))
	await get_tree().process_frame
	UiKit.pop_in(panel)
	return column


func _show_daily() -> void:
	var streak := Game.next_daily_streak()
	var column: VBoxContainer = await _popup(tr("DAILY_TITLE"))
	var gift := BeanIcon.new()
	gift.skin_id = Game.equipped_skin
	gift.bounce = true
	gift.custom_minimum_size = Vector2(0, 130)
	column.add_child(gift)
	column.add_child(UiKit.label(tr("DAILY_TEXT") % [streak, Game.daily_amount(streak)], 28))
	var claim := UiKit.button(tr("BTN_CLAIM"), "green", 40)
	column.add_child(claim)
	claim.pressed.connect(func():
		var before := Game.coins
		Game.claim_daily()
		Sfx.play("unlock")
		UiKit.count_to(_coins_label, before, Game.coins)
		column.get_parent().get_parent().get_parent().queue_free())


func _show_settings() -> void:
	var column: VBoxContainer = await _popup(tr("SETTINGS_TITLE"))
	var sound := UiKit.button("", "blue", 30)
	var music := UiKit.button("", "blue", 30)
	var language := UiKit.button("", "purple", 30)
	var refresh := func():
		sound.text = tr("SETTINGS_SOUND") % tr("ON" if Game.sound_enabled else "OFF")
		music.text = tr("SETTINGS_MUSIC") % tr("ON" if Game.music_enabled else "OFF")
		language.text = tr("SETTINGS_LANGUAGE") % tr("LANG_NAME")
	refresh.call()
	sound.pressed.connect(func(): Game.set_sound_enabled(not Game.sound_enabled); refresh.call())
	music.pressed.connect(func(): Game.set_music_enabled(not Game.music_enabled); refresh.call())
	language.pressed.connect(func():
		var index := Game.LANGUAGES.find(Game.current_language())
		Game.set_language(Game.LANGUAGES[(index + 1) % Game.LANGUAGES.size()])
		Transition.change_scene(Game.MENU_SCENE))
	column.add_child(sound)
	column.add_child(music)
	column.add_child(language)
	var close := UiKit.button(tr("BTN_CLOSE"), "yellow", 30)
	close.pressed.connect(func(): column.get_parent().get_parent().get_parent().queue_free())
	column.add_child(close)
