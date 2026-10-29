extends Node
## Estado global do jogo (autoload "Game"): moedas, fases liberadas,
## recordes, estrelas, skins e configurações. Tudo salvo no aparelho (offline).

signal coins_changed(total: int)
signal skins_changed

const SAVE_PATH := "user://save.cfg"
const MENU_SCENE := "res://scenes/menu/menu.tscn"
const MAP_SCENE := "res://scenes/map/map.tscn"
const LEVEL_SCENE := "res://scenes/levels/level.tscn"
const LANGUAGES := ["pt_BR", "en", "es"]
## Qualidade gráfica: automática, alta ou leve (para celulares fracos).
const GRAPHICS := ["auto", "high", "low"]
## Mostra um anúncio entre fases a cada N fases concluídas.
const INTERSTITIAL_EVERY := 2

var coins := 0
var unlocked_level := 1
var current_level := 1
var best_times: Dictionary = {}  # "12" -> segundos
var stars: Dictionary = {}       # "12" -> 0..3
var sound_enabled := true
var music_enabled := true
var language := ""
var graphics := "auto"
## No modo automático: o jogo percebeu que o aparelho é fraco (FPS baixo).
var slow_device := false
var equipped_skin := "classic"
var owned_skins: Array = ["classic"]
var rented_skins: Dictionary = {}  # id -> horário (unix) em que expira
var levels_since_ad := 0
var daily_last := ""
var daily_streak := 0
## Fase recém-concluída: o mapa anima o boneco andando até a próxima.
var just_completed := 0


func _ready() -> void:
	load_game()
	_apply_language()
	Mat.outlines = not low_graphics()
	_check_rentals()


# --- Salvamento ----------------------------------------------------------------

func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = cfg.get_value("progresso", "moedas", 0)
	unlocked_level = cfg.get_value("progresso", "fase_liberada", 1)
	best_times = cfg.get_value("progresso", "recordes", {})
	stars = cfg.get_value("progresso", "estrelas", {})
	levels_since_ad = cfg.get_value("progresso", "fases_sem_anuncio", 0)
	equipped_skin = cfg.get_value("skins", "equipada", "classic")
	owned_skins = cfg.get_value("skins", "compradas", ["classic"])
	rented_skins = cfg.get_value("skins", "alugadas", {})
	sound_enabled = cfg.get_value("config", "som", true)
	music_enabled = cfg.get_value("config", "musica", true)
	language = cfg.get_value("config", "idioma", "")
	graphics = cfg.get_value("config", "graficos", "auto")
	slow_device = cfg.get_value("config", "aparelho_lento", false)
	daily_last = cfg.get_value("diario", "ultimo", "")
	daily_streak = cfg.get_value("diario", "sequencia", 0)


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progresso", "moedas", coins)
	cfg.set_value("progresso", "fase_liberada", unlocked_level)
	cfg.set_value("progresso", "recordes", best_times)
	cfg.set_value("progresso", "estrelas", stars)
	cfg.set_value("progresso", "fases_sem_anuncio", levels_since_ad)
	cfg.set_value("skins", "equipada", equipped_skin)
	cfg.set_value("skins", "compradas", owned_skins)
	cfg.set_value("skins", "alugadas", rented_skins)
	cfg.set_value("config", "som", sound_enabled)
	cfg.set_value("config", "musica", music_enabled)
	cfg.set_value("config", "idioma", language)
	cfg.set_value("config", "graficos", graphics)
	cfg.set_value("config", "aparelho_lento", slow_device)
	cfg.set_value("diario", "ultimo", daily_last)
	cfg.set_value("diario", "sequencia", daily_streak)
	cfg.save(SAVE_PATH)


# --- Idioma ----------------------------------------------------------------------

## Usa o idioma escolhido; senão o do celular; senão português.
func _apply_language() -> void:
	var chosen := language
	if chosen == "":
		var system := OS.get_locale_language()
		chosen = "pt_BR"
		if system == "en":
			chosen = "en"
		elif system == "es":
			chosen = "es"
	TranslationServer.set_locale(chosen)


func set_language(code: String) -> void:
	language = code
	_apply_language()
	save_game()


func current_language() -> String:
	var locale := TranslationServer.get_locale()
	for code in LANGUAGES:
		if locale.begins_with(code.substr(0, 2)):
			return code
	return "pt_BR"


# --- Moedas e fases -------------------------------------------------------------------

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	save_game()


func spend_coins(amount: int) -> bool:
	if coins < amount:
		return false
	coins -= amount
	coins_changed.emit(coins)
	save_game()
	return true


func get_best_time(level: int) -> float:
	return best_times.get(str(level), INF)


func get_stars(level: int) -> int:
	return stars.get(str(level), 0)


func total_stars() -> int:
	var total := 0
	for key in stars:
		total += int(stars[key])
	return total


## Registra a fase concluída e devolve um resumo para a tela de resultado.
func complete_level(level: int, time: float, par_time: float, falls: int, coins_collected: int, place := 1) -> Dictionary:
	var earned_stars := 1
	if time <= par_time:
		earned_stars = 3
	elif time <= par_time * 1.5:
		earned_stars = 2

	var key := str(level)
	# Repetir uma fase já vencida rende metade (não dá para "farmar" a fase 1).
	var replay := stars.has(key)
	var new_record := time < get_best_time(level)
	if new_record:
		best_times[key] = time
	stars[key] = maxi(get_stars(level), earned_stars)
	if level >= unlocked_level:
		just_completed = level
	unlocked_level = maxi(unlocked_level, level + 1)
	levels_since_ad += 1

	var finish_bonus := 5 + earned_stars * 2
	var no_fall_bonus := 5 if falls == 0 else 0
	var place_bonus: int = [10, 5, 2][place - 1] if place <= 3 else 0
	var total := coins_collected + finish_bonus + no_fall_bonus + place_bonus
	if replay:
		total = int(ceil(total * 0.5))
	coins += total
	coins_changed.emit(coins)
	save_game()

	return {
		"stars": earned_stars,
		"new_record": new_record,
		"best_time": get_best_time(level),
		"coins_collected": coins_collected,
		"finish_bonus": finish_bonus,
		"no_fall_bonus": no_fall_bonus,
		"place_bonus": place_bonus,
		"coins_total": total,
		"replay": replay,
	}


# --- Skins -------------------------------------------------------------------------

func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _check_rentals() -> void:
	var changed := false
	for id in rented_skins.keys():
		if int(rented_skins[id]) <= _now():
			rented_skins.erase(id)
			changed = true
	if not has_skin(equipped_skin):
		equipped_skin = "classic"
		changed = true
	if changed:
		save_game()
		skins_changed.emit()


func has_skin(id: String) -> bool:
	if id in owned_skins:
		return true
	return rented_skins.has(id) and int(rented_skins[id]) > _now()


## Segundos que faltam no aluguel (0 se não está alugada).
func rental_seconds_left(id: String) -> int:
	if not rented_skins.has(id):
		return 0
	return maxi(0, int(rented_skins[id]) - _now())


func unlock_skin(id: String) -> void:
	if id not in owned_skins:
		owned_skins.append(id)
	rented_skins.erase(id)
	save_game()
	skins_changed.emit()


func rent_skin(id: String, days := Skins.RENT_DAYS) -> void:
	var start := maxi(_now(), int(rented_skins.get(id, 0)))
	rented_skins[id] = start + days * 86400
	save_game()
	skins_changed.emit()


func equip_skin(id: String) -> void:
	_check_rentals()
	if has_skin(id):
		equipped_skin = id
		save_game()
		skins_changed.emit()


func equipped_colors() -> Dictionary:
	_check_rentals()
	return Skins.appearance(equipped_skin)


# --- Presente diário ---------------------------------------------------------------

func _today() -> String:
	return Time.get_date_string_from_system()


func daily_available() -> bool:
	return daily_last != _today()


## Dias seguidos aumentam o presente (até 7).
func next_daily_streak() -> int:
	var yesterday := Time.get_date_string_from_unix_time(_now() - 86400)
	return mini(daily_streak + 1, 7) if daily_last == yesterday else 1


func daily_amount(streak: int) -> int:
	return mini(20 + (streak - 1) * 10, 80)


func claim_daily() -> int:
	if not daily_available():
		return 0
	daily_streak = next_daily_streak()
	daily_last = _today()
	var amount := daily_amount(daily_streak)
	add_coins(amount)
	return amount


# --- Configurações -------------------------------------------------------------------------

func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	save_game()


func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	save_game()
	Music.refresh()


# --- Gráficos -------------------------------------------------------------------------------

## Gráficos leves: sem sombras, sem contornos, menos cenário e resolução 3D menor.
func low_graphics() -> bool:
	match graphics:
		"low":
			return true
		"high":
			return false
	return slow_device or _weak_hardware()


## Celular com pouca memória: começa direto no modo leve.
func _weak_hardware() -> bool:
	if not OS.has_feature("mobile"):
		return false
	var physical: int = OS.get_memory_info().get("physical", 0)
	return physical > 0 and physical < 3_500_000_000


func set_graphics(mode: String) -> void:
	graphics = mode
	Mat.outlines = not low_graphics()
	save_game()


## Chamado pela fase quando o FPS fica baixo no modo automático.
func mark_slow_device() -> void:
	if slow_device:
		return
	slow_device = true
	Mat.outlines = not low_graphics()
	save_game()


## Aplica a qualidade na cena 3D atual (sol e resolução).
func apply_graphics(viewport: Viewport, sun: DirectionalLight3D) -> void:
	var low := low_graphics()
	if sun:
		sun.shadow_enabled = not low
	viewport.scaling_3d_scale = 0.75 if low else 1.0


# --- Navegação --------------------------------------------------------------------------------

func play_level(level: int) -> void:
	current_level = maxi(1, level)
	_change_scene(LEVEL_SCENE)


## Depois de uma fase: a cada INTERSTITIAL_EVERY fases mostra um anúncio.
func continue_after_level(next_scene: String) -> void:
	if levels_since_ad >= INTERSTITIAL_EVERY:
		levels_since_ad = 0
		save_game()
		await Monetization.show_interstitial()
	_change_scene(next_scene)


func play_next_level() -> void:
	current_level += 1
	continue_after_level(LEVEL_SCENE)


func go_to_map() -> void:
	_change_scene(MAP_SCENE)


func go_to_menu() -> void:
	_change_scene(MENU_SCENE)


func _change_scene(path: String) -> void:
	get_tree().paused = false
	Transition.change_scene(path)


func format_time(seconds: float) -> String:
	if is_inf(seconds):
		return "--:--.--"
	var minutes := int(seconds / 60.0)
	return "%02d:%05.2f" % [minutes, fmod(seconds, 60.0)]
