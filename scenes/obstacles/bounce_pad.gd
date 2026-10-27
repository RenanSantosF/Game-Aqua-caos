@tool
extends Area2D
## Boia trampolim: quem encostar nela é lançado para o alto.
## A origem é o centro da base (no chão).

@export var bounce_velocity := -1150.0
@export var width := 90.0:
	set(value):
		width = value
		_refresh()

const OUTLINE := Color("1a2340")

var _squish := 0.0
var _cooldown := 0.0
var _time := 0.0
var _style := StyleBoxFlat.new()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node and shape_node.shape is RectangleShape2D:
		(shape_node.shape as RectangleShape2D).size = Vector2(width, 40)
		shape_node.position = Vector2(0, -20)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_time += delta
	_squish = move_toward(_squish, 0.0, delta * 3.0)
	_cooldown -= delta
	queue_redraw()
	if Engine.is_editor_hint() or _cooldown > 0.0:
		return
	for body in get_overlapping_bodies():
		if body is Player and (body as Player).velocity.y > -50.0:
			(body as Player).launch(Vector2(0, bounce_velocity))
			_squish = 1.0
			_cooldown = 0.3


func _draw() -> void:
	var h := 30.0 * (1.0 - 0.45 * _squish) + sin(_time * 4.0) * 1.5
	var w := width * (1.0 + 0.2 * _squish)
	var rect := Rect2(-w * 0.5, -h, w, h)
	_style.bg_color = Color("ff7043")
	_style.set_corner_radius_all(int(h * 0.5))
	_style.set_border_width_all(3)
	_style.border_color = OUTLINE
	_style.draw(get_canvas_item(), rect)
	for i in 3:
		var x := -w * 0.5 + w * (i + 0.75) / 3.5
		draw_rect(Rect2(x, -h + 3, w * 0.09, h - 6), Color.WHITE)
	draw_line(Vector2(-w * 0.3, -h + 6), Vector2(w * 0.1, -h + 6), Color(1, 1, 1, 0.6), 3.0)
