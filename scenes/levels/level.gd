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
var _player_tracker: PathTracker
var _bot_trackers: Array[PathTracker] = []
## Medição de FPS no começo da corrida (modo gráfico automático).
var _fps_time := 0.0
var _fps_frames := 0


func _ready() -> void:
	level = Game.current_level
	_theme = Themes.for_level(level)
	_setup_environment()
	_builder = CourseBuilder.new()
	info = _builder.build(course, level, _theme)
	decor.build(_theme, _builder.waypoints, Transform3D.IDENTITY, _builder.finish_gate.global_transform, level)
	_setup_water()
	_player_tracker = PathTracker.new(_builder.waypoints)

	player.model.set_colors(Game.equipped_colors())
	player.global_position = info.spawn
	player.set_respawn(info.spawn, 0.0)
	camera.path_yaw = 0.0
	camera.snap()

	_spawn_rivals()

	player.fell_in_water.connect(_on_player_fell)
	player.coin_collected.connect(hud.set_coins)
	_builder.finish_gate.crossed.connect(_on_finish)
	_builder.finish_gate.bot_finished.connect(_on_bot_finished)
	for checkpoint in _builder.checkpoints:
		checkpoint.activated.connect(hud.toast.bind(tr("HUD_CHECKPOINT")))
	hud.restart_requested.connect(restart)
	hud.menu_requested.connect(Game.go_to_map)
	result_screen.next_requested.connect(Game.play_next_level)
	result_screen.retry_requested.connect(func(): Game.continue_after_level(Game.LEVEL_SCENE))
	result_screen.menu_requested.connect(func(): Game.continue_after_level(Game.MAP_SCENE))

	hud.set_level(level, Themes.level_name(level), tr(_theme.name))
	Music.play("race" if level % 2 == 1 else "race2")
	hud.set_time(0.0)
	hud.set_coins(0)
	_start_countdown()


func _process(delta: float) -> void:
	if running:
		elapsed += delta
		hud.set_time(elapsed)
	var progress := _player_tracker.update(player.global_position)
	hud.set_progress(progress)
	# A câmera segue a direção do percurso onde o jogador está.
	var target_yaw := PathTracker.yaw_of(_player_tracker.heading())
	camera.path_yaw = lerp_angle(camera.path_yaw, target_yaw, minf(1.0, 2.5 * delta))
	if running:
		hud.set_rank(_current_rank(progress), bots.size() + 1)
		_watch_fps(delta)


## Se o celular não aguenta (FPS baixo), troca sozinho para gráficos leves.
func _watch_fps(delta: float) -> void:
	if Game.graphics != "auto" or Game.low_graphics() or elapsed < 2.0 or _fps_time > 6.0:
		return
	_fps_time += delta
	_fps_frames += 1
	if _fps_time > 6.0 and _fps_frames / _fps_time < 26.0:
		Game.mark_slow_device()
		Game.apply_graphics(get_viewport(), sun)


func _current_rank(progress: float) -> int:
	var ahead := bots_finished
	for i in bots.size():
		var bot := bots[i]
		if bot.state != Player.State.FINISHED and _bot_trackers[i].update(bot.global_position) > progress:
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
		bot.set_respawn(bot.position, 0.0)
		bot.model.set_colors(data)
		_bot_trackers.append(PathTracker.new(_builder.waypoints))
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
	await get_tree().create_timer(0.6, false).timeout
	for text in ["3", "2", "1"]:
		hud.show_countdown(text)
		Sfx.play("beep", 0.0, 0.0)
		await get_tree().create_timer(0.7, false).timeout
	hud.show_countdown(tr("HUD_GO"))
	Sfx.play("go", 0.0, 0.0)
	player.set_frozen(false)
	for bot in bots:
		bot.set_frozen(false)
	running = true
	if level <= 2:
		await get_tree().create_timer(2.5, false).timeout
		hud.hint(tr("HUD_HINT_DIVE"))


func _on_player_fell() -> void:
	falls += 1
	camera.shake(0.4)
	hud.toast(tr("HUD_SPLASH"), Color("80d8ff"))


func _on_finish(_body: Node3D) -> void:
	running = false
	player.finish()
	touch_controls.set_enabled(false)
	hud.set_race_finished()
	# A câmera dá a volta para ver o boneco comemorando.
	camera.celebrating = true
	player.facing_angle = camera.path_yaw + PI
	var place := bots_finished + 1
	Music.play_jingle("victory" if place <= 3 else "finish")
	var result := Game.complete_level(level, elapsed, info.par_time, falls, player.coins, place)
	await get_tree().create_timer(1.6, false).timeout
	result_screen.show_result(level, Themes.level_name(level), elapsed, falls, place, bots.size() + 1, result)


func _setup_environment() -> void:
	WorldSetup.apply_environment(world_environment, sun, _theme)
	Game.apply_graphics(get_viewport(), sun)


func _setup_water() -> void:
	var box := AABB(_builder.waypoints[0], Vector3.ZERO)
	for point in _builder.waypoints:
		box = box.expand(point)
	var center := box.get_center()
	WorldSetup.add_water(self, _theme, Vector3(center.x, 0, center.z), Vector2(box.size.x + 240.0, box.size.z + 240.0))
