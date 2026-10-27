extends Node2D
## Respingo de água: gotas (CPUParticles2D) + anel na superfície.
## Remove-se sozinho ao terminar.

const LIFETIME := 1.0

var _time := 0.0


func _ready() -> void:
	($Drops as CPUParticles2D).emitting = true


func _process(delta: float) -> void:
	_time += delta
	if _time >= LIFETIME:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := _time / LIFETIME
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
	draw_arc(Vector2.ZERO, 14.0 + k * 90.0, 0.0, TAU, 32, Color(1, 1, 1, 0.9 * (1.0 - k)), 10.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
