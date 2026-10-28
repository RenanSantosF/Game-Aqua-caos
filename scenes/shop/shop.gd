extends Control
## Loja: skins (moedas, grátis por anúncio por alguns dias, exclusivas) e
## pacotes de moedas. A prévia 3D mostra a skin escolhida girando.

var _selected := ""
var _preview: CharacterModel
var _preview_root: Node3D
var _coins_label: Label
var _name_label: Label
var _status_label: Label
var _action: Button
var _grid: GridContainer
var _cards: Dictionary = {}
var _toast: Label
var _tab := "skins"
var _list_holder: ScrollContainer


func _ready() -> void:
	_build()
	_select(Game.equipped_skin)
	Music.play("menu")
	Game.coins_changed.connect(func(total: int): _coins_label.text = str(total))
	Game.skins_changed.connect(_refresh)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		Game.go_to_menu()


func _process(delta: float) -> void:
	if _preview_root:
		_preview_root.rotation.y += delta * 0.8
	if _selected != "" and Game.rental_seconds_left(_selected) > 0:
		_status_label.text = tr("SHOP_RENTED_LEFT") % _format_left(Game.rental_seconds_left(_selected))


# --- Montagem --------------------------------------------------------------------------

func _build() -> void:
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color("1e88e5")
	add_child(background)
	var bubbles := UiKit.bubbles(self, 14)
	bubbles.position = Vector2(640, 760)

	var top := HBoxContainer.new()
	UiKit.place(top, Control.PRESET_TOP_WIDE, 16, 14, -16, 84)
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	var back := UiKit.button(tr("BTN_BACK"), "yellow", 26)
	back.pressed.connect(Game.go_to_menu)
	top.add_child(back)
	var title := UiKit.label(tr("SHOP_TITLE"), 44, Color("ffd54f"), 12)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var pill := UiKit.coin_pill()
	top.add_child(pill[0])
	_coins_label = pill[1]

	# Prévia 3D (esquerda)
	var left := VBoxContainer.new()
	UiKit.place(left, Control.PRESET_LEFT_WIDE, 20, 100, 440, -20)
	left.add_theme_constant_override("separation", 8)
	add_child(left)
	var frame := UiKit.panel(Color(0.05, 0.21, 0.47, 0.6))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(frame)
	var view_container := SubViewportContainer.new()
	view_container.stretch = true
	frame.add_child(view_container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	view_container.add_child(viewport)
	_build_preview(viewport)
	_name_label = UiKit.label("", 34, Color("ffd54f"), 10)
	left.add_child(_name_label)
	_status_label = UiKit.label("", 22)
	left.add_child(_status_label)
	_action = UiKit.button("", "green", 32, Vector2(0, 78))
	_action.pressed.connect(_on_action)
	left.add_child(_action)

	# Abas e lista (direita)
	var right := VBoxContainer.new()
	UiKit.place(right, Control.PRESET_FULL_RECT, 460, 100, -20, -20)
	right.add_theme_constant_override("separation", 10)
	add_child(right)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	right.add_child(tabs)
	var tab_skins := UiKit.button(tr("SHOP_TAB_SKINS"), "pink", 28)
	tab_skins.pressed.connect(func(): _show_tab("skins"))
	tabs.add_child(tab_skins)
	var tab_coins := UiKit.button(tr("SHOP_TAB_COINS"), "orange", 28)
	tab_coins.pressed.connect(func(): _show_tab("coins"))
	tabs.add_child(tab_coins)
	_list_holder = ScrollContainer.new()
	_list_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list_holder.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(_list_holder)

	_toast = UiKit.label("", 34, Color("ffd54f"), 12)
	UiKit.place(_toast, Control.PRESET_CENTER_TOP, -400, 92, 400, 150)
	_toast.modulate.a = 0.0
	add_child(_toast)
	_show_tab("skins")


func _build_preview(viewport: SubViewport) -> void:
	var world := Node3D.new()
	viewport.add_child(world)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b3e5fc")
	environment.ambient_light_energy = 0.5
	env.environment = environment
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.0
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.4, 4.2)
	camera.fov = 40.0
	world.add_child(camera)
	camera.look_at(Vector3(0, 0.85, 0))
	_preview_root = Node3D.new()
	world.add_child(_preview_root)
	Build.cylinder(_preview_root, 1.2, 0.3, Color("fdd835"), Vector3(0, -0.15, 0), 1.1, true)
	Build.cylinder(_preview_root, 1.22, 0.06, Color.WHITE, Vector3(0, 0.01, 0))
	_preview = CharacterModel.new()
	_preview.demo_mode = true
	_preview_root.add_child(_preview)


func _show_tab(tab: String) -> void:
	_tab = tab
	for child in _list_holder.get_children():
		child.queue_free()
	_cards.clear()
	if tab == "skins":
		_grid = GridContainer.new()
		_grid.columns = 4
		_grid.add_theme_constant_override("h_separation", 12)
		_grid.add_theme_constant_override("v_separation", 12)
		_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list_holder.add_child(_grid)
		var i := 0
		for skin in Skins.LIST:
			var card := _skin_card(skin)
			_grid.add_child(card)
			_cards[skin.id] = card
			_pop_later(card, i * 0.04)
			i += 1
	else:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 12)
		_list_holder.add_child(column)
		var free := UiKit.button(tr("SHOP_FREE_COINS") % 50, "green", 30, Vector2(0, 86))
		free.pressed.connect(_free_coins)
		column.add_child(free)
		for pack in Skins.COIN_PACKS:
			var button := UiKit.button("%s   %s" % [tr(pack.label) % pack.coins, Monetization.price_of(pack.product)], "orange", 30, Vector2(0, 86))
			button.pressed.connect(_buy_pack.bind(pack))
			column.add_child(button)
	_refresh()


func _pop_later(control: Control, delay: float) -> void:
	await get_tree().process_frame
	UiKit.pop_in(control, delay)


func _skin_card(skin: Dictionary) -> Button:
	var card := UiKit.button("", "blue", 20, Vector2(230, 230))
	card.pressed.connect(_select.bind(skin.id))
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var icon := BeanIcon.new()
	icon.skin_id = skin.id
	icon.custom_minimum_size = Vector2(0, 140)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(icon)
	var name := UiKit.label(tr(skin.name), 22, Color.WHITE, 6)
	name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name)
	var tag := UiKit.label("", 18, Color("fff59d"), 5)
	tag.name = "Tag"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(tag)
	return card


# --- Lógica ----------------------------------------------------------------------------

func _select(id: String) -> void:
	_selected = id
	_preview.set_colors(Skins.appearance(id))
	_preview.on_jump()
	_refresh()


func _refresh() -> void:
	for id in _cards:
		var card: Button = _cards[id]
		var skin := Skins.get_skin(id)
		var tag: Label = card.find_child("Tag", true, false)
		tag.text = tr("SHOP_AD_SHORT") if skin.unlock == "ad" and not Game.has_skin(id) else _tag_text(skin)
		card.modulate = Color(1.15, 1.15, 1.15) if id == _selected else Color.WHITE
	if _selected == "":
		return
	var skin := Skins.get_skin(_selected)
	_name_label.text = tr(skin.name)
	_status_label.text = _tag_text(skin)
	if Game.has_skin(_selected):
		var equipped := Game.equipped_skin == _selected
		_action.text = tr("BTN_EQUIPPED") if equipped else tr("BTN_EQUIP")
		_action.disabled = equipped
		return
	_action.disabled = false
	match skin.unlock:
		"coins":
			_action.text = tr("SHOP_BUY_COINS") % skin.price
		"ad":
			_action.text = tr("SHOP_WATCH_AD") % Skins.RENT_DAYS
		"premium":
			_action.text = "%s  %s" % [tr("BTN_BUY"), Monetization.price_of(skin.product)]


func _tag_text(skin: Dictionary) -> String:
	if Game.equipped_skin == skin.id:
		return tr("BTN_EQUIPPED")
	if Game.rental_seconds_left(skin.id) > 0:
		return tr("SHOP_RENTED_LEFT") % _format_left(Game.rental_seconds_left(skin.id))
	if Game.has_skin(skin.id):
		return tr("SHOP_OWNED")
	match skin.unlock:
		"coins":
			return tr("SHOP_COINS") % skin.price
		"ad":
			return tr("SHOP_AD_RENT") % Skins.RENT_DAYS
		"premium":
			return tr("SHOP_PREMIUM") + " · " + Monetization.price_of(skin.product)
	return tr("SHOP_FREE")


func _on_action() -> void:
	var skin := Skins.get_skin(_selected)
	if Game.has_skin(_selected):
		Game.equip_skin(_selected)
		_preview.on_jump()
		return
	match skin.unlock:
		"coins":
			if Game.spend_coins(skin.price):
				Game.unlock_skin(_selected)
				_celebrate()
			else:
				_show_toast(tr("SHOP_NOT_ENOUGH"))
				Sfx.play("hit", -6.0)
		"ad":
			if await Monetization.show_rewarded():
				Game.rent_skin(_selected)
				_celebrate()
		"premium":
			if await Monetization.purchase(skin.product):
				Game.unlock_skin(_selected)
				_celebrate()


func _celebrate() -> void:
	Game.equip_skin(_selected)
	Sfx.play("unlock")
	_preview.on_jump()
	_show_toast(tr("SHOP_UNLOCKED"))
	_refresh()


func _free_coins() -> void:
	if await Monetization.show_rewarded():
		var before := Game.coins
		Game.add_coins(50)
		UiKit.count_to(_coins_label, before, Game.coins)
		Sfx.play("coin")


func _buy_pack(pack: Dictionary) -> void:
	if await Monetization.purchase(pack.product):
		var before := Game.coins
		Game.add_coins(pack.coins)
		UiKit.count_to(_coins_label, before, Game.coins)
		Sfx.play("unlock")


func _show_toast(text: String) -> void:
	_toast.text = text
	var tween := create_tween()
	tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	tween.tween_interval(1.2)
	tween.tween_property(_toast, "modulate:a", 0.0, 0.4)


func _format_left(seconds: int) -> String:
	var days := seconds / 86400
	var hours := (seconds % 86400) / 3600
	if days > 0:
		return tr("SHOP_DAYS_HOURS") % [days, hours]
	return tr("SHOP_HOURS_MIN") % [hours, (seconds % 3600) / 60]
