class_name PathTracker
extends RefCounted
## Acompanha quanto alguém já avançou na rota da fase (lista de pontos em
## ordem). Usado na barra de progresso, na posição da corrida e na câmera.

var points: Array[Vector3] = []
var index := 0


func _init(route: Array[Vector3]) -> void:
	points = route


## Atualiza com a posição atual e devolve o progresso (0..1).
func update(position: Vector3) -> float:
	if points.size() < 2:
		return 0.0
	# Procura o ponto mais próximo perto do último conhecido (permite voltar
	# ao checkpoint sem "teletransportar" o progresso).
	var best := index
	var best_distance := INF
	for i in range(maxi(0, index - 25), mini(points.size(), index + 8)):
		var d := _flat_distance(points[i], position)
		if d < best_distance:
			best_distance = d
			best = i
	index = best
	return progress()


func progress() -> float:
	return float(index) / float(maxi(1, points.size() - 1))


## Direção da rota no ponto atual (para a câmera).
func heading() -> Vector3:
	var a := points[mini(index, points.size() - 2)]
	var b := points[mini(index + 2, points.size() - 1)]
	var direction := b - a
	direction.y = 0.0
	return direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD


static func yaw_of(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length() + absf(a.y - b.y) * 0.5
