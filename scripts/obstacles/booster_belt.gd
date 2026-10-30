class_name BoosterBelt
extends StaticBody3D
## Rampa com jatos de água que empurram para cima (toboágua que sobe).
## A direção (global) e a força ficam em "push".

var push := Vector3.ZERO


func belt_velocity() -> Vector3:
	return push
