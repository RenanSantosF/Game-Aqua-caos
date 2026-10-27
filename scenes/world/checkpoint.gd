@tool
class_name Checkpoint
extends Area2D
## Bandeira de checkpoint: ao passar, o personagem renasce aqui ao cair.
## A origem é o pé do mastro (no chão).

signal activated

var active := false


func _ready() -> void:
	add_to_group("checkpoint")
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if active or not (body is Player):
		return
	active = true
	(body as Player).respawn_point = global_position
	activated.emit()
	queue_redraw()


func _draw() -> void:
	var o := Color("1a2340")
	draw_rect(Rect2(-5, -170, 10, 170), o)
	draw_rect(Rect2(-2, -170, 4, 170), Color("eceff1"))
	draw_circle(Vector2(0, -172), 7, Color("ffd54f"))
	var color := Color("43a047") if active else Color("ff7043")
	var top := -165.0 if active else -110.0
	var flag := PackedVector2Array([Vector2(4, top), Vector2(64, top + 20), Vector2(4, top + 40)])
	draw_colored_polygon(flag, color)
	flag.append(flag[0])
	draw_polyline(flag, o, 3.0)
