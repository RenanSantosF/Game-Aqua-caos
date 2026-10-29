shader_type spatial;
// Água correndo nos escorregadores e toboáguas: listras de espuma que
// descem a rampa. Sem luz e sem texturas (leve no celular).

render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec4 water_color : source_color = vec4(0.45, 0.85, 1.0, 0.8);
uniform vec4 foam_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float speed = 5.0;

varying vec3 v_local;

void vertex() {
	v_local = VERTEX;
}

void fragment() {
	// A peça aponta para -Z: a fase cresce com o tempo, então a espuma desce.
	float wave = sin(v_local.x * 4.0) * 0.12;
	float stripe = fract(v_local.z * 0.7 + TIME * speed * 0.7 + wave);
	float foam = smoothstep(0.78, 0.95, stripe) * (1.0 - smoothstep(0.95, 1.0, stripe));
	ALBEDO = mix(water_color.rgb, foam_color.rgb, foam * 0.85);
	ALPHA = mix(water_color.a, 1.0, foam);
}
