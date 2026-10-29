class_name Mat
## Materiais compartilhados (cache) com visual cartoon.
## Reaproveitar materiais deixa o jogo mais leve no celular.

static var _cache: Dictionary = {}
## Contornos desligados no modo de gráficos leves (desenham tudo duas vezes).
static var outlines := true


## Material "toon" (sombreamento em degraus, estilo desenho animado).
static func toon(color: Color, outlined := false) -> StandardMaterial3D:
	outlined = outlined and outlines
	var key := "toon_%s_%s" % [color.to_html(), outlined]
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.roughness = 0.55
	mat.rim_enabled = true
	mat.rim = 0.25
	mat.rim_tint = 0.6
	if outlined:
		mat.next_pass = outline()
	_cache[key] = mat
	return mat


## Contorno escuro (casca invertida), dá o traço de desenho animado.
static func outline(width := 0.025) -> StandardMaterial3D:
	var key := "outline_%s" % width
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("1a2340")
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.grow = true
	mat.grow_amount = width
	_cache[key] = mat
	return mat


static func unshaded(color: Color) -> StandardMaterial3D:
	var key := "flat_%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cache[key] = mat
	return mat


static func glow(color: Color, energy := 1.5) -> StandardMaterial3D:
	var key := "glow_%s_%s" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var mat := toon(color).duplicate() as StandardMaterial3D
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	_cache[key] = mat
	return mat
