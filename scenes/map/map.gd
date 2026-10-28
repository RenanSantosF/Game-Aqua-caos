extends Control
## Mapa de aventuras: um caminho sinuoso (de baixo para cima) com as fases.
## Cada região de 5 fases tem as cores de uma ambientação. É infinito:
## só desenha as fases visíveis. Arraste para rolar; toque numa fase.

const SPACING := 190.0
const REGION := 5
const AMPLITUDE := 230.0

var _scroll := 0.0
var _velocity := 0.0
var _dragging := false
var _drag_moved := 0.0
var _time := 0.0
## Fase onde o boneco está (anima andando até a nova fase liberada).
var _avatar_level := 1.0
var _coins_label: Label
var _popup: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_avatar_level = float(Game.unlocked_level)
	if Game.just_completed > 0 and Game.just_completed + 1 == Game.unlocked_level:
		_avatar_level = float(Game.just_completed)
	_build_ui()
	await get_tree().process_frame
	_scroll = _level_y(int(_avatar_level)) - size.y * 0.45
	Music.play("map")
	if _avatar_level < float(Game.unlocked_level):
		await get_tree().create_timer(0.7).timeout
		_walk_to_next()
	Game.just_completed = 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if _popup:
			_close_popup()
		else:
			Game.go_to_menu()


# --- Geometria do caminho --------------------------------------------------------------

## Posição da fase no "mundo" do mapa (y cresce para cima).
func _level_y(level: int) -> float:
	return (level - 1) * SPACING


func _level_x(level: float) -> float:
	return size.x * 0.5 + sin(level * 0.85) * AMPLITUDE * minf(1.0, size.x / 1400.0) + cos(level * 0.37) * 60.0


func _to_screen(level: float) -> Vector2:
	var world_y := (level - 1.0) * SPACING
	return Vector2(_level_x(level), size.y - (world_y - _scroll) - 120.0)


func _theme_of(level: int) -> Dictionary:
	return Themes.for_level(((level - 1) / REGION) * REGION + 1)


# --- Interação ----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if _popup:
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			if button.pressed:
				_dragging = true
				_drag_moved = 0.0
				_velocity = 0.0
			else:
				_dragging = false
				if _drag_moved < 12.0:
					_tap(button.position)
		elif button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_velocity += 900.0
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_velocity -= 900.0
	elif event is InputEventMouseMotion and _dragging:
		var motion := event as InputEventMouseMotion
		_scroll += motion.relative.y
		_drag_moved += absf(motion.relative.y)
		_velocity = motion.relative.y / maxf(get_process_delta_time(), 0.001)


func _tap(point: Vector2) -> void:
	var first := maxi(1, int(_scroll / SPACING) - 1)
	for level in range(first, first + int(size.y / SPACING) + 4):
		if _to_screen(level).distance_to(point) < 62.0:
			_open_level(level)
			return


func _process(delta: float) -> void:
	_time += delta
	if not _dragging:
		_scroll += _velocity * delta
		_velocity = move_toward(_velocity, 0.0, 2600.0 * delta)
	var max_scroll := _level_y(Game.unlocked_level + 12)
	_scroll = clampf(_scroll, -200.0, max_scroll)
	queue_redraw()


# --- Desenho -------------------------------------------------------------------------------

func _draw() -> void:
	var first := maxi(1, int((_scroll - 200.0) / SPACING))
	var last := first + int(size.y / SPACING) + 4
	_draw_background(first, last)
	_draw_path(first, last)
	for level in range(first, last + 1):
		_draw_node(level)
	_draw_avatar()


func _draw_background(first: int, last: int) -> void:
	# Faixas com a cor da água de cada região, misturadas suavemente.
	var band := 24.0
	var y := 0.0
	while y < size.y:
		var world := _scroll + (size.y - y - 120.0)
		var level := world / SPACING + 1.0
		var region := floorf((level - 1.0) / REGION)
		var k := fposmod(level - 1.0, REGION) / REGION
		var a: Dictionary = Themes.for_level(int(region) * REGION + 1)
		var b: Dictionary = Themes.for_level(int(region + 1) * REGION + 1)
		var mix := smoothstep(0.75, 1.0, k)
		var color := (a.water_shallow as Color).lerp(b.water_shallow, mix).lerp(Color.WHITE, 0.08)
		draw_rect(Rect2(0, y, size.x, band + 1), color)
		y += band
	# Ondinhas e brilhos que se movem.
	for i in 26:
		var wx := fposmod(i * 197.0 + _time * 18.0 * (1 if i % 2 == 0 else -1), size.x + 120.0) - 60.0
		var wy := fposmod(i * 131.0 + _scroll * 0.6, size.y + 60.0) - 30.0
		draw_arc(Vector2(wx, wy), 14.0, PI * 1.1, PI * 1.9, 8, Color(1, 1, 1, 0.35), 3.0)
	# Ilhas decorativas nas laterais de cada fase.
	for level in range(first, last + 1):
		var p := _to_screen(level)
		var side := -1.0 if level % 2 == 0 else 1.0
		var island := Vector2(p.x + side * (240.0 + (level % 3) * 40.0), p.y + 40.0)
		if island.x < -60.0 or island.x > size.x + 60.0:
			continue
		var theme := _theme_of(level)
		_draw_ellipse(island, Vector2(70, 26), (theme.island as Color))
		_draw_ellipse(island + Vector2(0, -6), Vector2(54, 16), (theme.grass as Color))
		if level % 2 == 1:
			_draw_palm(island + Vector2(10, -10), theme)
	# Placas das regiões.
	for level in range(first, last + 1):
		if (level - 1) % REGION == 0:
			var p := _to_screen(level)
			var theme := _theme_of(level)
			var text := tr(theme.name).to_upper()
			var banner := Rect2(Vector2(size.x * 0.5 - 170.0, p.y + 82.0), Vector2(340, 46))
			draw_rect(banner.grow(4), UiKit.OUTLINE)
			draw_rect(banner, (theme.palette[0] as Color))
			draw_string(UiKit.FONT, Vector2(banner.position.x, banner.position.y + 34), text, HORIZONTAL_ALIGNMENT_CENTER, banner.size.x, 30, Color.WHITE)


func _draw_path(first: int, last: int) -> void:
	var points := PackedVector2Array()
	var steps := 8
	for level in range(first, last):
		for s in steps:
			points.append(_to_screen(level + float(s) / steps))
	if points.size() < 2:
		return
	draw_polyline(points, UiKit.OUTLINE, 30.0, true)
	draw_polyline(points, Color("ffe0a3"), 22.0, true)
	# Pegadas pontilhadas no caminho já percorrido.
	for i in range(0, points.size(), 2):
		var level := first + float(i) / steps
		if level < float(Game.unlocked_level):
			draw_circle(points[i], 4.0, Color("c8a165"))


func _draw_node(level: int) -> void:
	var p := _to_screen(level)
	if p.y < -80.0 or p.y > size.y + 80.0:
		return
	var unlocked := level <= Game.unlocked_level
	var current := level == Game.unlocked_level
	var theme := _theme_of(level)
	var color: Color = theme.palette[level % theme.palette.size()] if unlocked else Color("90a4ae")
	var radius := 46.0 + (sin(_time * 4.0) * 4.0 if current else 0.0)
	draw_circle(p + Vector2(0, 8), radius, Color(0, 0, 0, 0.18))
	draw_circle(p, radius + 5.0, UiKit.OUTLINE)
	draw_circle(p, radius, color)
	draw_circle(p + Vector2(-radius * 0.3, -radius * 0.35), radius * 0.28, Color(1, 1, 1, 0.35))
	if unlocked:
		draw_string(UiKit.FONT, p + Vector2(-60, 14), str(level), HORIZONTAL_ALIGNMENT_CENTER, 120, 40, Color.WHITE)
		var stars := Game.get_stars(level)
		for i in 3:
			var sp := p + Vector2((i - 1) * 30.0, radius + 16.0 - (6.0 if i == 1 else 0.0))
			_draw_star(sp, 13.0, Color("ffd54f") if i < stars else Color(1, 1, 1, 0.35))
	else:
		# Cadeado
		draw_rect(Rect2(p + Vector2(-14, -2), Vector2(28, 22)), Color("eceff1"))
		draw_arc(p + Vector2(0, -2), 10.0, PI, TAU, 10, Color("eceff1"), 5.0)


func _draw_avatar() -> void:
	var p := _to_screen(_avatar_level)
	var hop := absf(sin(_time * 5.0)) * 10.0
	BeanIcon.draw_bean(self, p + Vector2(0, -92 - hop), 0.85, Game.equipped_colors())


func _draw_star(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		var a := -PI * 0.5 + i * PI / 5.0
		points.append(center + Vector2(cos(a), sin(a)) * (r + 3.0))
		inner.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(points, UiKit.OUTLINE)
	draw_colored_polygon(inner, color)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)


func _draw_palm(base: Vector2, theme: Dictionary) -> void:
	draw_line(base, base + Vector2(6, -46), Color("8d6e63"), 6.0)
	var top := base + Vector2(6, -46)
	for i in 5:
		var a := -PI + i * PI / 4.0
		var tip := top + Vector2(cos(a) * 30.0, sin(a) * 12.0 + 8.0)
		draw_line(top, tip, (theme.leaf as Color), 7.0)


# --- Animação de avanço -----------------------------------------------------------------

func _walk_to_next() -> void:
	var target := float(Game.unlocked_level)
	var tween := create_tween()
	tween.tween_method(func(v: float):
		_avatar_level = v
		_scroll = lerpf(_scroll, _level_y(int(round(v))) - size.y * 0.45, 0.08), _avatar_level, target, 1.2).set_trans(Tween.TRANS_SINE)
	for i in 3:
		tween.parallel().tween_callback(Sfx.play.bind("jump", -6.0)).set_delay(i * 0.35)
	await tween.finished
	Sfx.play("unlock")


# --- Interface ----------------------------------------------------------------------------

func _build_ui() -> void:
	var top := HBoxContainer.new()
	UiKit.place(top, Control.PRESET_TOP_WIDE, 16, 14, -16, 84)
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	var back := UiKit.button(tr("BTN_BACK"), "yellow", 26)
	back.pressed.connect(Game.go_to_menu)
	top.add_child(back)
	var title := UiKit.label(tr("MAP_TITLE"), 40, Color("ffd54f"), 12)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var shop := UiKit.button(tr("BTN_SHOP"), "pink", 26)
	shop.pressed.connect(func(): Transition.change_scene("res://scenes/shop/shop.tscn"))
	top.add_child(shop)
	var pill := UiKit.coin_pill()
	top.add_child(pill[0])
	_coins_label = pill[1]

	var play := UiKit.button(tr("MENU_PLAY_LEVEL") % Game.unlocked_level, "green", 40, Vector2(380, 90))
	UiKit.place(play, Control.PRESET_CENTER_BOTTOM, -190, -110, 190, -20)
	play.pressed.connect(func(): _open_level(Game.unlocked_level))
	add_child(play)
	await get_tree().create_timer(0.5).timeout
	UiKit.pulse(play, 0.05, 1.2)


func _open_level(level: int) -> void:
	if level > Game.unlocked_level:
		Sfx.play("hit", -6.0)
		return
	_popup = Control.new()
	_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_popup)
	var dim := UiKit.dim(_popup)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			_close_popup())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup.add_child(center)
	var panel := UiKit.panel()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(520, 0)
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var theme := Themes.for_level(level)
	column.add_child(UiKit.label(tr("MAP_LEVEL") % level, 54, Color("ffd54f"), 12))
	column.add_child(UiKit.label(Themes.level_name(level).to_upper(), 32))
	column.add_child(UiKit.label(tr(theme.name), 24, Color("b3e5fc")))
	var stars := HBoxContainer.new()
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 14)
	column.add_child(stars)
	for i in 3:
		var star := preload("res://scenes/ui/star_icon.gd").new() as Control
		star.custom_minimum_size = Vector2(60, 60)
		if i >= Game.get_stars(level):
			star.modulate = Color(1, 1, 1, 0.3)
		stars.add_child(star)
	column.add_child(UiKit.label(tr("MAP_BEST") % Game.format_time(Game.get_best_time(level)), 24))
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	var close := UiKit.button(tr("BTN_BACK"), "yellow", 30)
	close.pressed.connect(_close_popup)
	buttons.add_child(close)
	var play := UiKit.button(tr("BTN_PLAY"), "green", 42, Vector2(220, 0))
	play.pressed.connect(func(): Game.play_level(level))
	buttons.add_child(play)
	await get_tree().process_frame
	UiKit.pop_in(panel)


func _close_popup() -> void:
	if _popup:
		_popup.queue_free()
		_popup = null
