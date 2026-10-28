extends Node
## Anúncios e compras. Hoje roda em MODO DE TESTE: mostra telas simuladas
## (marcadas como "TESTE") para validar todo o fluxo do jogo sem SDK.
##
## Para publicar, troque os métodos _real_* pelas chamadas do plugin
## oficial de cada serviço (veja docs/MONETIZACAO.md). O resto do jogo
## só usa as funções públicas abaixo e não precisa mudar.

signal purchase_completed(product: String)

const TEST_MODE := true
## Preços exibidos no modo de teste (na versão real vêm da Google Play).
const TEST_PRICES := {
	"skin_shark": "R$ 4,99", "skin_robot": "R$ 4,99", "skin_king": "R$ 6,99", "skin_lava": "R$ 6,99",
	"coins_small": "R$ 2,99", "coins_big": "R$ 7,99", "coins_mega": "R$ 14,99",
}

const OVERLAY := preload("res://scenes/ui/test_ad_overlay.gd")

var _overlay: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func price_of(product: String) -> String:
	return TEST_PRICES.get(product, "--")


## Anúncio entre fases. Nunca é chamado no meio de uma corrida.
func show_interstitial() -> void:
	if TEST_MODE:
		await _test_overlay("interstitial", "")
		return


## Anúncio recompensado (opcional). Devolve true se foi assistido até o fim.
func show_rewarded() -> bool:
	if TEST_MODE:
		return await _test_overlay("rewarded", "")
	return false


## Compra com dinheiro real. Devolve true se concluída.
func purchase(product: String) -> bool:
	var ok := false
	if TEST_MODE:
		ok = await _test_overlay("purchase", product)
	if ok:
		purchase_completed.emit(product)
	return ok


func _test_overlay(kind: String, product: String) -> bool:
	_overlay = OVERLAY.new()
	get_tree().root.add_child(_overlay)
	var result: bool = await _overlay.run(kind, price_of(product))
	_overlay.queue_free()
	return result
