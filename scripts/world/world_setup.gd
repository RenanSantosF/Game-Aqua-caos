class_name WorldSetup
## Céu, luz do sol e água conforme o tema. Usado nas fases e no menu.

const WATER_SHADER := preload("res://shaders/water.gdshader")
const WATER_Y := -1.2


static func apply_environment(world_environment: WorldEnvironment, sun: DirectionalLight3D, theme: Dictionary) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = theme.sky_top
	sky_material.sky_horizon_color = theme.sky_horizon
	sky_material.ground_horizon_color = theme.sky_horizon
	sky_material.ground_bottom_color = theme.water_deep
	sky_material.sun_angle_max = 25.0
	sky_material.sky_curve = 0.12
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = (theme.sky_horizon as Color).lerp(theme.sky_top, 0.5)
	env.ambient_light_energy = theme.ambient
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = env

	sun.light_color = theme.sun
	sun.light_energy = theme.sun_energy
	sun.rotation_degrees = Vector3(theme.sun_pitch, theme.sun_yaw, 0)
	sun.shadow_enabled = true
	# Sombras nítidas perto da câmera: distância curta = mais detalhe.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 32.0
	sun.directional_shadow_split_1 = 0.25
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2


static func add_water(parent: Node3D, theme: Dictionary, center: Vector3, size: Vector2) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	# Ondas precisam de vértices; limitado para não pesar no celular.
	plane.subdivide_width = clampi(int(size.x / 5.0), 8, 90)
	plane.subdivide_depth = clampi(int(size.y / 5.0), 8, 110)
	var material := ShaderMaterial.new()
	material.shader = WATER_SHADER
	material.set_shader_parameter("deep_color", theme.water_deep)
	material.set_shader_parameter("shallow_color", theme.water_shallow)
	var water := MeshInstance3D.new()
	water.mesh = plane
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	water.position = Vector3(center.x, WATER_Y, center.z)
	parent.add_child(water)
	return water
