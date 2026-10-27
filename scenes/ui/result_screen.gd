extends CanvasLayer
## Tela de resultado: tempo, recorde, medalha, quedas e botões.

signal retry_requested
signal menu_requested

const MEDALS := {
	"gold": {"name": "OURO", "color": Color("ffc107")},
	"silver": {"name": "PRATA", "color": Color("b0bec5")},
	"bronze": {"name": "BRONZE", "color": Color("d7894a")},
}

@onready var _root: Control = $Root
@onready var _panel: Control = %Panel
@onready var _medal_badge: PanelContainer = %MedalBadge


func _ready() -> void:
	_root.hide()
	%RetryButton.pressed.connect(retry_requested.emit)
	%MenuButton.pressed.connect(menu_requested.emit)


## result: level_name, time, best_time, new_record, falls, medal ("gold"/"silver"/"bronze").
func show_result(result: Dictionary) -> void:
	%LevelLabel.text = result.get("level_name", "")
	%TimeLabel.text = "TEMPO: %s" % Game.format_time(result.get("time", 0.0))
	%BestLabel.text = "RECORDE: %s" % Game.format_time(result.get("best_time", INF))
	%NewRecordLabel.visible = result.get("new_record", false)
	var falls: int = result.get("falls", 0)
	%FallsLabel.text = "QUEDAS: %d" % falls
	%NoFallsLabel.visible = falls == 0

	var medal: Dictionary = MEDALS.get(result.get("medal", "bronze"), MEDALS["bronze"])
	%MedalLabel.text = medal["name"]
	var style := (_medal_badge.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	style.bg_color = medal["color"]
	_medal_badge.add_theme_stylebox_override("panel", style)

	_root.show()
	_root.modulate.a = 0.0
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.6, 0.6)
	var tween := create_tween().set_parallel()
	tween.tween_property(_root, "modulate:a", 1.0, 0.2)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
