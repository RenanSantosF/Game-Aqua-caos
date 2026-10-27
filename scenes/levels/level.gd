extends Node2D
## Controla uma fase: contagem regressiva, cronômetro, quedas, checkpoints,
## chegada e resultado. Reaproveitável em todas as fases.

@export var level_id := "parque_aquatico"
@export var level_name := "Parque Aquático"
## Tempo máximo (segundos) para medalha de ouro e de prata.
@export var gold_time := 30.0
@export var silver_time := 55.0
@export var camera_limit_right := 6300
## Abaixo desta altura o personagem conta como caído (segurança extra).
@export var fall_limit_y := 1100.0

var elapsed := 0.0
var running := false
var falls := 0

@onready var player: Player = $Player
@onready var hud: CanvasLayer = $HUD
@onready var touch_controls: CanvasLayer = $TouchControls
@onready var result_screen: CanvasLayer = $ResultScreen
@onready var finish_line: FinishLine = $FinishLine


func _ready() -> void:
	player.camera.limit_right = camera_limit_right
	player.fell_in_water.connect(_on_player_fell)
	finish_line.crossed.connect(_on_finish_crossed)
	for checkpoint in get_tree().get_nodes_in_group("checkpoint"):
		checkpoint.activated.connect(_on_checkpoint_activated)
	hud.restart_requested.connect(restart)
	hud.menu_requested.connect(Game.go_to_title)
	result_screen.retry_requested.connect(restart)
	result_screen.menu_requested.connect(Game.go_to_title)
	hud.set_time(0.0)
	hud.set_falls(0)
	_start_countdown()


func _process(delta: float) -> void:
	if running:
		elapsed += delta
		hud.set_time(elapsed)


func _physics_process(_delta: float) -> void:
	if player.global_position.y > fall_limit_y and player.state != Player.State.IN_WATER:
		player.enter_water()


func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _start_countdown() -> void:
	player.set_frozen(true)
	for text in ["3", "2", "1"]:
		hud.show_countdown(text)
		await get_tree().create_timer(0.7, false).timeout
	hud.show_countdown("JÁ!")
	player.set_frozen(false)
	running = true


func _on_player_fell() -> void:
	falls += 1
	hud.set_falls(falls)


func _on_checkpoint_activated() -> void:
	hud.toast("CHECKPOINT!")


func _on_finish_crossed(_body: Node2D) -> void:
	running = false
	player.finish()
	touch_controls.set_enabled(false)
	hud.set_race_finished()
	var new_record := Game.register_time(level_id, elapsed)
	var medal := "bronze"
	if elapsed <= gold_time:
		medal = "gold"
	elif elapsed <= silver_time:
		medal = "silver"
	await get_tree().create_timer(1.2, false).timeout
	result_screen.show_result({
		"level_name": level_name,
		"time": elapsed,
		"best_time": Game.get_best_time(level_id),
		"new_record": new_record,
		"falls": falls,
		"medal": medal,
	})
