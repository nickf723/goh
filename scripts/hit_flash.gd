extends Node3D

@export var lifetime: float = 0.18
@export var grow_speed: float = 4.0

var age: float = 0.0


func _process(delta: float) -> void:
	age += delta
	scale += Vector3.ONE * grow_speed * delta

	if age >= lifetime:
		queue_free()
