extends Node
## Anúncios e compras.
##
## Anúncios: AdMob de verdade no Android (plugin AquaAds, em android_plugin/).
## No PC/editor, onde o plugin não existe, aparece uma tela simulada.
## O APK de teste (build debug do GitHub Actions) usa os blocos de TESTE do
## Google, para você poder testar à vontade sem risco para sua conta AdMob.
## A versão de publicação (build release) usa os seus blocos reais.
##
## Compras: ainda em MODO DE TESTE (tela simulada). Veja docs/MONETIZACAO.md.

signal purchase_completed(product: String)

## Seus blocos de anúncio no AdMob.
const AD_UNITS := {
	"interstitial": "ca-app-pub-4311255826061303/2764286671",  # Entre fases
	"rewarded": "ca-app-pub-4311255826061303/1946029022",  # Dobrar moedas, moedas grátis, skins
}
## Blocos de teste oficiais do Google (sempre mostram anúncio de teste).
const TEST_AD_UNITS := {
	"interstitial": "ca-app-pub-3940256099942544/1033173712",
	"rewarded": "ca-app-pub-3940256099942544/5224354917",
}
## Quanto tempo esperar um anúncio premiado terminar de carregar.
const REWARDED_WAIT := 5.0

## Preços exibidos no modo de teste (na versão real vêm da Google Play).
const TEST_PRICES := {
	"skin_shark": "R$ 4,99", "skin_robot": "R$ 4,99", "skin_king": "R$ 6,99", "skin_lava": "R$ 6,99",
	"coins_small": "R$ 2,99", "coins_big": "R$ 7,99", "coins_mega": "R$ 14,99",
}

const OVERLAY := preload("res://scenes/ui/test_ad_overlay.gd")

var _ads: Object
var _closed := false
var _earned := false
var _overlay: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Engine.has_singleton("AquaAds"):
		_ads = Engine.get_singleton("AquaAds")
		_ads.connect("interstitial_closed", _on_interstitial_closed)
		_ads.connect("rewarded_closed", _on_rewarded_closed)
		var units: Dictionary = TEST_AD_UNITS if OS.is_debug_build() else AD_UNITS
		_ads.initialize(units.interstitial, units.rewarded)


func price_of(product: String) -> String:
	return TEST_PRICES.get(product, "--")


## Anúncio entre fases. Nunca é chamado no meio de uma corrida.
## Se ainda não carregou, o jogo segue sem anúncio.
func show_interstitial() -> void:
	if _ads == null:
		await _test_overlay("interstitial", "")
		return
	if not _ads.isInterstitialReady():
		return
	_closed = false
	_mute(true)
	_ads.showInterstitial()
	await _wait_closed()
	_mute(false)


## Anúncio premiado (opcional). Devolve true se foi assistido até o fim.
func show_rewarded() -> bool:
	if _ads == null:
		return await _test_overlay("rewarded", "")
	var notice := _notice("AD_LOADING")
	var waited := 0.0
	while not _ads.isRewardedReady() and waited < REWARDED_WAIT:
		await get_tree().create_timer(0.25, true, false, true).timeout
		waited += 0.25
	if not _ads.isRewardedReady():
		notice.get_child(1).text = tr("AD_UNAVAILABLE")
		await get_tree().create_timer(1.8, true, false, true).timeout
		notice.queue_free()
		return false
	notice.queue_free()
	_closed = false
	_earned = false
	_mute(true)
	_ads.showRewarded()
	await _wait_closed()
	_mute(false)
	return _earned


## Compra com dinheiro real (ainda simulada). Devolve true se concluída.
func purchase(product: String) -> bool:
	var ok: bool = await _test_overlay("purchase", product)
	if ok:
		purchase_completed.emit(product)
	return ok


func _on_interstitial_closed() -> void:
	_closed = true


func _on_rewarded_closed(earned: bool) -> void:
	_earned = earned
	_closed = true


func _wait_closed() -> void:
	# Segurança: se o aviso de fechamento nunca chegar, o jogo não fica preso.
	var waited := 0.0
	while not _closed and waited < 180.0:
		await get_tree().process_frame
		waited += get_process_delta_time()


## O anúncio tem o próprio som; o jogo fica mudo enquanto isso.
func _mute(on: bool) -> void:
	AudioServer.set_bus_mute(0, on)


## Aviso simples no meio da tela ("Carregando anúncio...").
func _notice(key: String) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 90
	get_tree().root.add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0.02, 0.1, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var label := UiKit.label(tr(key), 40)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layer.add_child(label)
	return layer


func _test_overlay(kind: String, product: String) -> bool:
	_overlay = OVERLAY.new()
	get_tree().root.add_child(_overlay)
	var result: bool = await _overlay.run(kind, price_of(product))
	_overlay.queue_free()
	return result
