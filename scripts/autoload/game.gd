extends Node
## Estado global do jogo (autoload "Game"): moedas, fases liberadas,
## recordes e estrelas. Tudo é salvo no próprio aparelho (offline).

signal coins_changed(total: int)

const SAVE_PATH := "user://save.cfg"
const MENU_SCENE := "res://scenes/menu/menu.tscn"
const LEVEL_SCENE := "res://scenes/levels/level.tscn"

var coins := 0
var unlocked_level := 1
var current_level := 1
var best_times: Dictionary = {}  # "12" -> segundos
var stars: Dictionary = {}       # "12" -> 0..3
var sound_enabled := true


func _ready() -> void:
	load_game()


# --- Salvamento ----------------------------------------------------------------

func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = cfg.get_value("progresso", "moedas", 0)
	unlocked_level = cfg.get_value("progresso", "fase_liberada", 1)
	best_times = cfg.get_value("progresso", "recordes", {})
	stars = cfg.get_value("progresso", "estrelas", {})
	sound_enabled = cfg.get_value("config", "som", true)


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progresso", "moedas", coins)
	cfg.set_value("progresso", "fase_liberada", unlocked_level)
	cfg.set_value("progresso", "recordes", best_times)
	cfg.set_value("progresso", "estrelas", stars)
	cfg.set_value("config", "som", sound_enabled)
	cfg.save(SAVE_PATH)


# --- Progresso -------------------------------------------------------------------

func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)
	save_game()


func get_best_time(level: int) -> float:
	return best_times.get(str(level), INF)


func get_stars(level: int) -> int:
	return stars.get(str(level), 0)


## Registra a fase concluída e devolve um resumo para a tela de resultado.
func complete_level(level: int, time: float, par_time: float, falls: int, coins_collected: int, place := 1) -> Dictionary:
	var earned_stars := 1
	if time <= par_time:
		earned_stars = 3
	elif time <= par_time * 1.5:
		earned_stars = 2

	var key := str(level)
	var new_record := time < get_best_time(level)
	if new_record:
		best_times[key] = time
	stars[key] = maxi(get_stars(level), earned_stars)
	unlocked_level = maxi(unlocked_level, level + 1)

	var finish_bonus := 10 + earned_stars * 5
	var no_fall_bonus := 15 if falls == 0 else 0
	var place_bonus: int = [25, 15, 8][place - 1] if place <= 3 else 0
	var total := coins_collected + finish_bonus + no_fall_bonus + place_bonus
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
	}


func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	save_game()


# --- Navegação --------------------------------------------------------------------

func play_level(level: int) -> void:
	current_level = maxi(1, level)
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SCENE)


func play_next_level() -> void:
	play_level(current_level + 1)


func go_to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func format_time(seconds: float) -> String:
	if is_inf(seconds):
		return "--:--.--"
	var minutes := int(seconds / 60.0)
	return "%02d:%05.2f" % [minutes, fmod(seconds, 60.0)]
