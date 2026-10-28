extends CanvasLayer
## Transição animada entre telas: um "círculo de água" fecha e abre.

const SHADER := """
shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 color : source_color = vec4(0.12, 0.53, 0.9, 1.0);
uniform vec2 screen_ratio = vec2(1.777, 1.0);
void fragment() {
	vec2 p = (UV - 0.5) * screen_ratio;
	float wave = sin(atan(p.y, p.x) * 9.0 + TIME * 6.0) * 0.02;
	float radius = (1.0 - progress) * 1.25;
	float inside = step(length(p) + wave, radius);
	COLOR = vec4(color.rgb, 1.0 - inside);
}
"""

var _rect: ColorRect
var _material: ShaderMaterial
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_rect.material = _material
	add_child(_rect)
	_set_progress(0.0)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var size := get_viewport().get_visible_rect().size
	_material.set_shader_parameter("screen_ratio", Vector2(size.x / size.y, 1.0))
	var tween := create_tween()
	tween.tween_method(_set_progress, 0.0, 1.0, 0.35).set_ease(Tween.EASE_IN)
	await tween.finished
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var back := create_tween()
	back.tween_method(_set_progress, 1.0, 0.0, 0.45).set_ease(Tween.EASE_OUT)
	await back.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false


func _set_progress(value: float) -> void:
	_material.set_shader_parameter("progress", value)
	_rect.visible = value > 0.001
