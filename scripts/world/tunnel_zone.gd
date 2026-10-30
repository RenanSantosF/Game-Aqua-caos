class_name TunnelZone
extends Area3D
## Trecho de túnel embaixo da água: quem está dentro não "cai na água"
## e a câmera pode descer junto.


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	body_entered.connect(func(body: Node3D):
		if body is Player:
			(body as Player).tunnel_count += 1)
	body_exited.connect(func(body: Node3D):
		if body is Player:
			(body as Player).tunnel_count = maxi(0, (body as Player).tunnel_count - 1))
