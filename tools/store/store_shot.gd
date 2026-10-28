extends SceneTree
## Captura telas do jogo para a Play Store.
##
## Uso (precisa de tela; no servidor use xvfb-run):
##   godot --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://tools/store/store_shot.gd -- <alvo> <idioma> <saida> <tempos> [skin] [hud]
##
## <alvo>: número da fase, ou "menu", "map", "shop".
## <tempos>: segundos de corrida em que capturar, separados por vírgula
##   (ex.: 6,9.5,14). Cada captura vira <saida>_<tempo>.png.
##   Use "result" para capturar a tela de resultado depois da chegada.
## O jogador é guiado pela mesma IA dos rivais.

const SCENES := {
	"menu": "res://scenes/menu/menu.tscn",
	"map": "res://scenes/map/map.tscn",
	"shop": "res://scenes/shop/shop.tscn",
}

var _args: PackedStringArray
var _frame := 0
var _node: Node
var _times: Array = []
var _race_time := 0.0
var _finished_at := -1.0
var _wait := 0.0


func _initialize() -> void:
	_args = OS.get_cmdline_user_args()
	for t in _args[3].split(","):
		_times.append(t)


func _setup_save() -> void:
	var game := root.get_node("Game")
	game.set_language(_args[1])
	game.coins = 1250
	game.unlocked_level = 13
	for i in range(1, 13):
		game.stars[str(i)] = 3 if i % 4 != 2 else 2
	game.owned_skins = ["classic", "splash", "frog", "pirate"]
	game.rented_skins = {}
	game.equipped_skin = _args[4] if _args.size() > 4 else "classic"
	game.daily_last = game._today()
	game.just_completed = 0


func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 1:
		_setup_save()
		var target := _args[0]
		if target.is_valid_int():
			root.get_node("Game").current_level = int(target)
			_node = load("res://scenes/levels/level.tscn").instantiate()
		else:
			_node = load(SCENES[target]).instantiate()
		root.add_child(_node)
		return false
	if _frame == 3 and _node.has_method("restart"):
		_node.player.brain = load("res://scripts/level/bot_brain.gd").new(_node._builder, 0.6, 11)
		var show_hud := _args.size() > 5 and _args[5] == "hud"
		_node.hud.visible = show_hud
		_node.touch_controls.visible = show_hud
	if not _node.has_method("restart"):
		_wait += delta
		if _wait > float(_times[0]):
			_save(_args[2] + ".png")
			quit()
		return false
	if _node.running:
		_race_time = _node.elapsed
	# Depois da chegada, só resta a captura do resultado.
	if not _node.running and _node.elapsed > 1.0:
		while not _times.is_empty() and _times[0] != "result":
			_times.pop_front()
	if _times.is_empty():
		quit()
		return false
	var next: String = _times[0]
	if next == "result":
		if not _node.running and _node.elapsed > 1.0 and _finished_at < 0:
			_finished_at = _race_time
			_wait = 0.0
		if _finished_at >= 0:
			_wait += delta
			if _wait > 3.5:
				_save(_args[2] + "_result.png")
				_times.pop_front()
	elif _race_time >= float(next):
		_save("%s_%s.png" % [_args[2], next])
		_times.pop_front()
	if _race_time > 75.0:
		quit()
	return false


func _save(path: String) -> void:
	root.get_texture().get_image().save_png(path)
	print("salvo ", path)
