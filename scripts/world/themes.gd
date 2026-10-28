class_name Themes
## Ambientações das fases. Cada fase usa uma, em rodízio, com nome próprio.

const LIST := [
	{
		"name": "THEME_TROPICAL",
		"sky_top": Color("2f7fe0"), "sky_horizon": Color("a8e4ff"),
		"sun": Color("fff4d6"), "sun_energy": 0.90, "sun_pitch": -52.0, "sun_yaw": 35.0,
		"ambient": 0.33,
		"water_deep": Color("0b4fb0"), "water_shallow": Color("1fa8e8"),
		"palette": [Color("e53935"), Color("1e88e5"), Color("fdd835"), Color("43a047"), Color("ff7043")],
		"island": Color("f3d58b"), "grass": Color("5cbf4a"), "leaf": Color("2e9d4b"),
		"night": false,
	},
	{
		"name": "THEME_SUNSET",
		"sky_top": Color("5b3a9e"), "sky_horizon": Color("ffab6b"),
		"sun": Color("ffc38a"), "sun_energy": 0.80, "sun_pitch": -22.0, "sun_yaw": 150.0,
		"ambient": 0.30,
		"water_deep": Color("3a3c9e"), "water_shallow": Color("ff9e7a"),
		"palette": [Color("ff7043"), Color("ab47bc"), Color("ffca28"), Color("26c6da"), Color("ec407a")],
		"island": Color("e8c27a"), "grass": Color("8bbf4a"), "leaf": Color("3f8f3a"),
		"night": false,
	},
	{
		"name": "THEME_NEON",
		"sky_top": Color("0b1036"), "sky_horizon": Color("3a2a7a"),
		"sun": Color("a7b8ff"), "sun_energy": 0.50, "sun_pitch": -60.0, "sun_yaw": -40.0,
		"ambient": 0.38,
		"water_deep": Color("0b1a4a"), "water_shallow": Color("2fb8ff"),
		"palette": [Color("00e5ff"), Color("ff4081"), Color("76ff03"), Color("ffea00"), Color("d500f9")],
		"island": Color("6a5acd"), "grass": Color("3949ab"), "leaf": Color("00bfa5"),
		"night": true,
	},
	{
		"name": "THEME_CANDY",
		"sky_top": Color("ff9ccf"), "sky_horizon": Color("fff0f7"),
		"sun": Color("fff8f0"), "sun_energy": 0.87, "sun_pitch": -48.0, "sun_yaw": 10.0,
		"ambient": 0.38,
		"water_deep": Color("2f7fd8"), "water_shallow": Color("6fd6ff"),
		"palette": [Color("ff4fa3"), Color("a259ff"), Color("29b6f6"), Color("ffc93f"), Color("26d9b0")],
		"island": Color("ffd59e"), "grass": Color("f06292"), "leaf": Color("ab47bc"),
		"night": false,
	},
	{
		"name": "THEME_CORAL",
		"sky_top": Color("1f9e9a"), "sky_horizon": Color("c5fff4"),
		"sun": Color("fffbe0"), "sun_energy": 0.94, "sun_pitch": -58.0, "sun_yaw": 70.0,
		"ambient": 0.30,
		"water_deep": Color("00796b"), "water_shallow": Color("4dffd6"),
		"palette": [Color("ff7043"), Color("ffca28"), Color("ec407a"), Color("26a69a"), Color("7e57c2")],
		"island": Color("ffe9a8"), "grass": Color("66bb6a"), "leaf": Color("2e7d32"),
		"night": false,
	},
]

const ADJECTIVE_COUNT := 10
const PLACE_COUNT := 12


static func for_level(level: int) -> Dictionary:
	return LIST[(level - 1) % LIST.size()]


## Nome da fase no idioma atual (ex.: "Festa das Ondas").
static func level_name(level: int) -> String:
	if level == 1:
		return TranslationServer.translate("LEVEL_FIRST")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("nome_%d" % level)
	var adjective := TranslationServer.translate("ADJ_%d" % (rng.randi() % ADJECTIVE_COUNT + 1))
	var place := TranslationServer.translate("PLACE_%d" % (rng.randi() % PLACE_COUNT + 1))
	if TranslationServer.get_locale().begins_with("en") and not place.begins_with("of "):
		return "%s %s" % [place, adjective]
	return "%s %s" % [adjective, place]


## Posição no idioma atual: 1º / 1st / 1º.
static func ordinal(n: int) -> String:
	if TranslationServer.get_locale().begins_with("en"):
		var suffix := "th"
		if n % 100 < 11 or n % 100 > 13:
			suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
		return "%d%s" % [n, suffix]
	return "%dº" % n
