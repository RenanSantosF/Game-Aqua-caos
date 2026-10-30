shader_type spatial;
// Água cartoon: ondas no vértice, cor por altura e brilhos animados.
// Leve o bastante para celulares modestos (sem texturas).

// cull_disabled: vista de baixo (de dentro do túnel submerso) também aparece.
render_mode diffuse_toon, specular_toon, cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.04, 0.36, 0.78, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.25, 0.78, 1.0, 1.0);
uniform vec4 sparkle_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float wave_height = 0.18;
uniform float wave_speed = 1.0;

varying float v_wave;
varying vec3 v_world;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float a = w.x * 0.35 + t * 1.3;
	float b = w.z * 0.27 - t * 1.1;
	float c = (w.x + w.z) * 0.6 + t * 2.0;
	float h = sin(a) * 0.6 + sin(b) * 0.5 + sin(c) * 0.25;
	VERTEX.y += h * wave_height;
	float dx = cos(a) * 0.6 * 0.35 + cos(c) * 0.25 * 0.6;
	float dz = cos(b) * 0.5 * 0.27 + cos(c) * 0.25 * 0.6;
	NORMAL = normalize(vec3(-dx * wave_height, 1.0, -dz * wave_height));
	v_wave = h;
	v_world = w;
}

void fragment() {
	float t = TIME * wave_speed;
	float k = clamp(v_wave * 0.35 + 0.5, 0.0, 1.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, k);
	float s = sin(v_world.x * 1.7 + t * 1.5) * sin(v_world.z * 1.9 - t * 1.2);
	float s2 = sin(v_world.x * 0.63 + t * 0.9) * sin(v_world.z * 0.71 + t * 0.6);
	float sparkle = smoothstep(0.93, 1.0, s) * smoothstep(0.2, 0.9, s2);
	col = mix(col, sparkle_color.rgb, clamp(sparkle, 0.0, 1.0) * 0.55);
	ALBEDO = col * 0.8;
	ROUGHNESS = 0.2;
	SPECULAR = 0.4;
}
