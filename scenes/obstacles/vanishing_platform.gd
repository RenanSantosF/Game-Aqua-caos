@tool
extends StaticBody2D
## Plataforma que treme ao ser pisada, some e depois volta.
## A origem é o canto superior esquerdo.

@export var size := Vector2(130, 30):
	set(value):
		size = value
		_refresh()
@export var color := Color("ec407a"):
	set(value):
		color = value
		queue_redraw()
## Tempo tremendo antes de sumir.
@export var warn_time := 0.6
## Tempo sumida antes de voltar.
@export var gone_time := 2.2

enum PlatformState { SOLID, WARNING, GONE }

const OUTLINE := Color("1a2340")

var _state := PlatformState.SOLID
var _timer := 0.0

@onready var _shape: CollisionShape2D = $CollisionShape2D
@onready var _detector: Area2D = $Detector


func _ready() -> void:
	_refresh()
	if not Engine.is_editor_hint():
		_detector.body_entered.connect(_on_body_entered)


func _refresh() -> void:
	if not is_inside_tree():
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		(shape_node.shape as RectangleShape2D).size = size
		shape_node.position = size * 0.5
	var detector_shape := get_node_or_null("Detector/CollisionShape2D") as CollisionShape2D
	if detector_shape and detector_shape.shape is RectangleShape2D:
		(detector_shape.shape as RectangleShape2D).size = Vector2(size.x - 4.0, 12.0)
		detector_shape.position = Vector2(size.x * 0.5, -4.0)
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if _state == PlatformState.SOLID and body is Player:
		_state = PlatformState.WARNING
		_timer = warn_time


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or _state == PlatformState.SOLID:
		return
	_timer -= delta
	if _timer <= 0.0:
		if _state == PlatformState.WARNING:
			_state = PlatformState.GONE
			_timer = gone_time
			_shape.set_deferred("disabled", true)
		else:
			_state = PlatformState.SOLID
			_shape.set_deferred("disabled", false)
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	match _state:
		PlatformState.GONE:
			draw_rect(rect, Color(1, 1, 1, 0.25), false, 2.0)
			return
		PlatformState.WARNING:
			rect.position.x += sin(_timer * 70.0) * 3.0
	var fill := color
	if _state == PlatformState.WARNING and fmod(_timer, 0.2) < 0.1:
		fill = color.lightened(0.5)
	draw_rect(rect.grow(3), OUTLINE)
	draw_rect(rect, fill)
	draw_rect(Rect2(rect.position, Vector2(size.x, 7)), fill.lightened(0.4))
	for i in 3:
		var x := rect.position.x + size.x * (i + 1) / 4.0
		draw_circle(Vector2(x, size.y * 0.55), 4.0, fill.darkened(0.3))
