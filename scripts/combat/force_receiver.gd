extends Node
class_name ForceReceiver

@export var drag: float = 10.0
@export var max_force_speed: float = 8.0

var external_velocity: Vector3 = Vector3.ZERO
var last_force_summary: String = "none"

func _ready() -> void:
	add_to_group("debuggable")

func apply_impulse(direction: Vector3, strength: float, up_strength: float = 0.0, source_name: String = "unknown") -> void:
	if strength <= 0.0 and up_strength <= 0.0:
		return

	direction.y = 0.0

	if direction.length() > 0.01:
		direction = direction.normalized()
	else:
		direction = Vector3.FORWARD

	external_velocity += direction * strength
	external_velocity.y += up_strength

	if external_velocity.length() > max_force_speed:
		external_velocity = external_velocity.normalized() * max_force_speed

	last_force_summary = source_name + " | " + str(snapped(strength, 0.1))

func consume_external_velocity(delta: float) -> Vector3:
	var current_velocity: Vector3 = external_velocity

	external_velocity = external_velocity.move_toward(Vector3.ZERO, drag * delta)

	return current_velocity

func has_force() -> bool:
	return external_velocity.length() > 0.05

func get_debug_data() -> Dictionary:
	return {
		"force": snapped(external_velocity.length(), 0.01),
		"last": last_force_summary,
	}
