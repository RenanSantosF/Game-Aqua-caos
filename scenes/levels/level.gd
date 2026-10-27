extends Node3D
## Uma fase: gera o percurso pelo número (Game.current_level), monta o
## ambiente e controla contagem, cronômetro, quedas, moedas e chegada.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const FONT := preload("res://assets/fonts/LilitaOne-Regular.ttf")
const RIVALS := [
	{"name": "Pingo", "body": Color("29b6f6"), "belly": Color("e1f5fe"), "cap": Color("ffca28")},
	{"name": "Sapeca", "body": Color("66bb6a"), "belly": Color("f1f8e9"), "cap": Color("e53935")},
	{"name": "Tubinha", "body": Color("78909c"), "belly": Color("eceff1"), "cap": Color("ff7043")},
	{"name": "Jujuba", "body": Color("ec407a"), "belly": Color("fce4ec"), "cap": Color("7e57c2")},
	{"name": "Robô Bolha", "body": Color("b0bec5"), "belly": Color("80deea"), "cap": Color("26c6da")},
]

var level := 1
var info: Dictionary
var bots: Array[Player] = []
var bots_finished := 0
var elapsed := 0.0
var running := false
var falls := 0

@onready var player: Player = $Player
@onready var camera: FollowCamera = $FollowCamera
@onready var hud: CanvasLayer = $HUD
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var result_screen: CanvasLayer = $ResultScreen
@onready var course: Node3D = $Course
@onready var decor: WorldDecor = $Decor
@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment

var _theme: Dictionary
var _builder: CourseBuilder


func _ready() -> void:
	level = Game.current_level
	_theme = Themes.for_level(level)
	_setup_environment()
	_builder = CourseBuilder.new()
	info = _builder.build(course, level, _theme)
	decor.build(_theme, 10.0, info.end_z, level)
	_setup_water()

	player.global_position = info.spawn
	player.respawn_point = info.spawn
	camera.snap()

	_spawn_rivals()

	player.fell_in_water.connect(_on_player_fell)
	player.coin_collected.connect(hud.set_coins)
	_builder.finish_gate.crossed.connect(_on_finish)
	_builder.finish_gate.bot_finished.connect(_on_bot_finished)
	for checkpoint in _builder.checkpoints:
		checkpoint.activated.connect(hud.toast.bind("CHECKPOINT!"))
	hud.restart_requested.connect(restart)
	hud.menu_requested.connect(Game.go_to_menu)
	result_screen.next_requested.connect(Game.play_next_level)
	result_screen.retry_requested.connect(restart)
	result_screen.menu_requested.connect(Game.go_to_menu)

	hud.set_level(level, Themes.level_name(level), _theme.name)
	hud.set_time(0.0)
	hud.set_coins(0)
	_start_countdown()


func _process(delta: float) -> void:
	if running:
		elapsed += delta
		hud.set_time(elapsed)
	hud.set_progress(player.global_position.z / info.finish_z)
	if running:
		hud.set_rank(_current_rank(), bots.size() + 1)


func _current_rank() -> int:
	var ahead := bots_finished
	for bot in bots:
		if bot.state != Player.State.FINISHED and bot.global_position.z < player.global_position.z:
			ahead += 1
	return ahead + 1


func restart() -> void:
	Game.play_level(level)


func _spawn_rivals() -> void:
	var count := mini(RIVALS.size(), 3 + level / 3)
	for i in count:
		var data: Dictionary = RIVALS[i]
		var bot := PLAYER_SCENE.instantiate() as Player
		bot.is_human = false
		var skill := clampf(0.45 + 0.1 * i + 0.015 * level, 0.3, 0.95)
		bot.brain = BotBrain.new(_builder, skill, level * 31 + i)
		var slots := [Vector3(-2.4, 0, 0.6), Vector3(2.4, 0, 0.6), Vector3(-4.6, 0, 1.0), Vector3(4.6, 0, 1.0), Vector3(0, 0, 1.4)]
		bot.position = info.spawn + slots[i]
		add_child(bot)
		bot.respawn_point = bot.position
		bot.model.set_colors(data)
		var tag := Label3D.new()
		tag.text = data.name
		tag.font = FONT
		tag.font_size = 48
		tag.outline_size = 12
		tag.pixel_size = 0.006
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = false
		tag.modulate = data.body.lightened(0.4)
		tag.outline_modulate = Color("1a2340")
		tag.position = Vector3(0, 2.1, 0)
		bot.add_child(tag)
		bots.append(bot)


func _on_bot_finished(bot: Node3D) -> void:
	if player.state != Player.State.FINISHED:
		bots_finished += 1
	(bot as Player).finish()


func _start_countdown() -> void:
	player.set_frozen(true)
	for bot in bots:
		bot.set_frozen(true)
	for text in ["3", "2", "1"]:
		hud.show_countdown(text)
		Sfx.play("beep", 0.0, 0.0)
		await get_tree().create_timer(0.7, false).timeout
	hud.show_countdown("JÁ!")
	Sfx.play("go", 0.0, 0.0)
	player.set_frozen(false)
	for bot in bots:
		bot.set_frozen(false)
	running = true


func _on_player_fell() -> void:
	falls += 1
	camera.shake(0.4)
	hud.toast("SPLASH!", Color("80d8ff"))


func _on_finish(_body: Node3D) -> void:
	running = false
	player.finish()
	touch_controls.set_enabled(false)
	hud.set_race_finished()
	Sfx.play("win", 0.0, 0.0)
	# A câmera dá a volta para ver o boneco comemorando.
	camera.offset = Vector3(0, 2.4, -6.5)
	camera.look_ahead = Vector3(0, 1.0, 0)
	var place := bots_finished + 1
	var result := Game.complete_level(level, elapsed, info.par_time, falls, player.coins, place)
	await get_tree().create_timer(1.6, false).timeout
	result_screen.show_result(level, Themes.level_name(level), elapsed, falls, place, bots.size() + 1, result)


func _setup_environment() -> void:
	WorldSetup.apply_environment(world_environment, sun, _theme)


func _setup_water() -> void:
	WorldSetup.add_water(self, _theme, info.end_z * 0.5, -info.end_z + 260.0)
