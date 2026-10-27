extends Node
## Estado global do jogo (autoload "Game").
## Por enquanto os recordes ficam só na memória; o salvamento no
## aparelho chega na Etapa 9.

const TITLE_SCENE := "res://scenes/main/main.tscn"
const FIRST_LEVEL := "res://scenes/levels/level_01.tscn"

var best_times: Dictionary = {}


## Registra o tempo e devolve true se for um novo recorde.
func register_time(level_id: String, time: float) -> bool:
	if time < get_best_time(level_id):
		best_times[level_id] = time
		return true
	return false


func get_best_time(level_id: String) -> float:
	return best_times.get(level_id, INF)


func format_time(seconds: float) -> String:
	if is_inf(seconds):
		return "--:--.--"
	var minutes := int(seconds / 60.0)
	return "%02d:%05.2f" % [minutes, fmod(seconds, 60.0)]


func play_level(path: String = FIRST_LEVEL) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func go_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
