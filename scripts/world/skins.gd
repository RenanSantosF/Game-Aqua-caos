class_name Skins
## Catálogo de skins (aparências). Nenhuma dá vantagem na corrida.
##
## unlock:
##   "free"    já vem liberada
##   "coins"   compra com moedas do jogo (price)
##   "ad"      grátis por tempo limitado assistindo a um anúncio (rent_days)
##   "premium" compra com dinheiro real (product = id na Google Play)

const RENT_DAYS := 3

const LIST := [
	{"id": "classic", "name": "SKIN_CLASSIC", "unlock": "free",
		"colors": {"body": Color("ff7043"), "belly": Color("fff3e0"), "cap": Color("1e88e5")}, "extras": ["cap"]},
	{"id": "splash", "name": "SKIN_SPLASH", "unlock": "coins", "price": 150,
		"colors": {"body": Color("29b6f6"), "belly": Color("e1f5fe"), "cap": Color("ffca28")}, "extras": ["cap"]},
	{"id": "melon", "name": "SKIN_MELON", "unlock": "coins", "price": 250,
		"colors": {"body": Color("43a047"), "belly": Color("ef5350"), "cap": Color("2e7d32")}, "extras": ["seeds"]},
	{"id": "frog", "name": "SKIN_FROG", "unlock": "coins", "price": 350,
		"colors": {"body": Color("7cb342"), "belly": Color("f0f4c3"), "cap": Color("558b2f")}, "extras": ["frog_eyes"]},
	{"id": "duck", "name": "SKIN_DUCK", "unlock": "ad",
		"colors": {"body": Color("ffd54f"), "belly": Color("fff8e1"), "cap": Color("ff8f00")}, "extras": ["beak", "float_ring"]},
	{"id": "penguin", "name": "SKIN_PENGUIN", "unlock": "coins", "price": 450,
		"colors": {"body": Color("37474f"), "belly": Color("fafafa"), "cap": Color("ff9800")}, "extras": ["beak"]},
	{"id": "unicorn", "name": "SKIN_UNICORN", "unlock": "ad",
		"colors": {"body": Color("f8bbd0"), "belly": Color("ffffff"), "cap": Color("ba68c8")}, "extras": ["horn"]},
	{"id": "pirate", "name": "SKIN_PIRATE", "unlock": "coins", "price": 600,
		"colors": {"body": Color("c62828"), "belly": Color("ffe0b2"), "cap": Color("212121")}, "extras": ["pirate_hat"]},
	{"id": "dj", "name": "SKIN_DJ", "unlock": "ad",
		"colors": {"body": Color("26a69a"), "belly": Color("b2dfdb"), "cap": Color("212121")}, "extras": ["headphones", "cap"]},
	{"id": "astronaut", "name": "SKIN_ASTRONAUT", "unlock": "coins", "price": 900,
		"colors": {"body": Color("eceff1"), "belly": Color("90caf9"), "cap": Color("1e88e5")}, "extras": ["visor", "antenna"]},
	{"id": "shark", "name": "SKIN_SHARK", "unlock": "premium", "product": "skin_shark",
		"colors": {"body": Color("78909c"), "belly": Color("eceff1"), "cap": Color("546e7a")}, "extras": ["fin"]},
	{"id": "robot", "name": "SKIN_ROBOT", "unlock": "premium", "product": "skin_robot",
		"colors": {"body": Color("b0bec5"), "belly": Color("80deea"), "cap": Color("26c6da")}, "extras": ["antenna", "visor"]},
	{"id": "king", "name": "SKIN_KING", "unlock": "premium", "product": "skin_king",
		"colors": {"body": Color("7e57c2"), "belly": Color("ede7f6"), "cap": Color("ffca28")}, "extras": ["crown"]},
	{"id": "lava", "name": "SKIN_LAVA", "unlock": "premium", "product": "skin_lava",
		"colors": {"body": Color("ff5722"), "belly": Color("ffeb3b"), "cap": Color("b71c1c")}, "extras": ["horn", "fin"]},
]

## Pacotes de moedas com dinheiro real (ids da Google Play).
const COIN_PACKS := [
	{"product": "coins_small", "coins": 500, "label": "PACK_SMALL"},
	{"product": "coins_big", "coins": 1500, "label": "PACK_BIG"},
	{"product": "coins_mega", "coins": 4000, "label": "PACK_MEGA"},
]


static func get_skin(id: String) -> Dictionary:
	for skin in LIST:
		if skin.id == id:
			return skin
	return LIST[0]


## Dados prontos para CharacterModel.set_colors().
static func appearance(id: String) -> Dictionary:
	var skin := get_skin(id)
	var data: Dictionary = skin.colors.duplicate()
	data["extras"] = skin.extras
	return data
