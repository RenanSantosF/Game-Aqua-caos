class_name VanishingTile
extends StaticBody3D
## Piso que treme ao ser pisado, cai e depois volta. A origem é o centro do topo.

@export var size := Vector3(2.2, 0.5, 2.2)
@export var color := Color("ec407a")
@export var warn_time := 0.5
@export var gone_time := 3.0

enum TileState { SOLID, WARNING, GONE }

var _state := TileState.SOLID
var _timer := 0.0
var _shape: CollisionShape3D
var _mesh: MeshInstance3D


func _ready() -> void:
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	_shape.shape = box
	_shape.position.y = -size.y * 0.5
	add_child(_shape)
	_mesh = Build.box(self, size, color, Vector3(0, -size.y * 0.5, 0), true)
	var detector := Build.area_box(self, Vector3(size.x - 0.1, 0.4, size.z - 0.1), Vector3(0, 0.2, 0))
	detector.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if _state == TileState.SOLID and body is Player:
		_state = TileState.WARNING
		_timer = warn_time


func _physics_process(delta: float) -> void:
	match _state:
		TileState.WARNING:
			_timer -= delta
			_mesh.position = Vector3(randf_range(-0.05, 0.05), -size.y * 0.5, randf_range(-0.05, 0.05))
			if _timer <= 0.0:
				_state = TileState.GONE
				_timer = gone_time
				_shape.set_deferred("disabled", true)
		TileState.GONE:
			_timer -= delta
			_mesh.position.y -= delta * 6.0
			_mesh.visible = _mesh.position.y > -4.0
			if _timer <= 0.0:
				_state = TileState.SOLID
				_shape.set_deferred("disabled", false)
				_mesh.position = Vector3(0, -size.y * 0.5, 0)
				_mesh.visible = true
