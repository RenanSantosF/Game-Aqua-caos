class_name UiKit
## Peças de interface prontas e animações (menu, mapa, loja).

const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const OUTLINE := Color("1a2340")

const COLORS := {
	"yellow": Color("fdd835"), "green": Color("66bb6a"), "blue": Color("29b6f6"),
	"pink": Color("ff6fae"), "purple": Color("9575cd"), "orange": Color("ffa726"), "gray": Color("b0bec5"),
}


static func button(text: String, color := "yellow", font_size := 32, min_size := Vector2.ZERO) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	var base: Color = COLORS.get(color, COLORS.yellow)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = base
		match state:
			"hover":
				style.bg_color = base.lightened(0.15)
			"pressed":
				style.bg_color = base.darkened(0.12)
			"disabled":
				style.bg_color = base.lerp(Color("90a4ae"), 0.6)
		style.set_corner_radius_all(22)
		style.set_border_width_all(4)
		style.border_width_bottom = 4 if state == "pressed" else 8
		style.border_color = OUTLINE
		style.content_margin_left = 24
		style.content_margin_right = 24
		style.content_margin_top = 12 if state == "pressed" else 8
		style.content_margin_bottom = 8 if state == "pressed" else 12
		b.add_theme_stylebox_override(state, style)
	b.add_theme_color_override("font_color", OUTLINE)
	b.add_theme_color_override("font_hover_color", OUTLINE)
	b.add_theme_color_override("font_pressed_color", OUTLINE)
	b.add_theme_color_override("font_disabled_color", Color(OUTLINE, 0.6))
	b.pressed.connect(func(): Sfx.play("click"); squash(b))
	return b


static func label(text: String, font_size := 28, color := Color.WHITE, outline := 8) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func panel(color := Color(0.05, 0.21, 0.47, 0.92), radius := 26) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_border_width_all(4)
	style.border_color = Color("4fc3f7")
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 18
	style.content_margin_bottom = 20
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 6)
	p.add_theme_stylebox_override("panel", style)
	return p


## Pílula do contador de moedas.
static func coin_pill() -> Array:
	var pill := PanelContainer.new()
	pill.theme_type_variation = &"HudPanel"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pill.add_child(row)
	var icon := CoinIcon.new()
	icon.custom_minimum_size = Vector2(38, 38)
	row.add_child(icon)
	var amount := label(str(Game.coins), 34)
	row.add_child(amount)
	return [pill, amount]


## Fundo escuro de tela cheia (para janelas).
static func dim(parent: Node) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color(0, 0.03, 0.12, 0.6)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(rect)
	return rect


# --- Animações -----------------------------------------------------------------------

static func pop_in(control: Control, delay := 0.0) -> void:
	control.pivot_offset = control.size * 0.5
	control.scale = Vector2(0.4, 0.4)
	control.modulate.a = 0.0
	var tween := control.create_tween().set_parallel()
	tween.tween_property(control, "scale", Vector2.ONE, 0.4).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.2).set_delay(delay)


static func slide_in(control: Control, offset: Vector2, delay := 0.0) -> void:
	var target := control.position
	control.position = target + offset
	control.modulate.a = 0.0
	var tween := control.create_tween().set_parallel()
	tween.tween_property(control, "position", target, 0.5).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, 0.25).set_delay(delay)


static func pulse(control: Control, amount := 0.06, period := 1.0) -> void:
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween().set_loops()
	tween.tween_property(control, "scale", Vector2.ONE * (1.0 + amount), period * 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(control, "scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE)


static func squash(control: Control) -> void:
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(1.08, 0.92), 0.06)
	tween.tween_property(control, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Número que sobe aos poucos até o valor final.
static func count_to(target_label: Label, from: int, to: int, duration := 0.8) -> void:
	var tween := target_label.create_tween()
	tween.tween_method(func(v: float): target_label.text = str(int(v)), float(from), float(to), duration)


## Bolhas subindo pela tela (decoração leve).
static func bubbles(parent: Node, amount := 18) -> CPUParticles2D:
	var particles := CPUParticles2D.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)])
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	particles.texture = texture
	particles.amount = amount
	particles.lifetime = 7.0
	particles.preprocess = 7.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(900, 10)
	particles.direction = Vector2(0, -1)
	particles.spread = 15.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 40.0
	particles.initial_velocity_max = 90.0
	particles.scale_amount_min = 0.4
	particles.scale_amount_max = 1.4
	parent.add_child(particles)
	return particles


## Ancora um controle e define as margens (em pixels) a partir das âncoras.
static func place(control: Control, preset: int, left: float, top: float, right: float, bottom: float) -> void:
	control.set_anchors_preset(preset)
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom
