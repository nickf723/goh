extends Node
class_name ForceReceiver

@export var drag: float = 10.0
@export var max_force_speed: float = 8.0

@export_group("Continuous Influence")
@export var continuous_linear_damping: float = 1.4
@export var continuous_angular_damping: float = 2.2
@export var max_continuous_speed: float = 7.0
@export var max_angular_speed: float = 5.0

var external_velocity: Vector3 = Vector3.ZERO
var continuous_velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO
var continuous_forces: Dictionary = {}
var continuous_torques: Dictionary = {}
var last_force_summary: String = "none"
var last_torque_summary: String = "none"


func _ready() -> void:
	add_to_group("debuggable")


func apply_impulse(
	direction: Vector3,
	strength: float,
	up_strength: float = 0.0,
	source_name: String = "unknown"
) -> void:
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

	last_force_summary = source_name + " | impulse " + str(snapped(strength, 0.1))


func set_continuous_force(source_id: String, force_vector: Vector3) -> void:
	if source_id == "":
		return
	if force_vector.length() <= 0.0001:
		continuous_forces.erase(source_id)
		return
	continuous_forces[source_id] = force_vector
	last_force_summary = source_id + " | force " + str(snapped(force_vector.length(), 0.01))


func clear_continuous_force(source_id: String) -> void:
	continuous_forces.erase(source_id)


func set_continuous_torque(source_id: String, torque_vector: Vector3) -> void:
	if source_id == "":
		return
	if torque_vector.length() <= 0.0001:
		continuous_torques.erase(source_id)
		return
	continuous_torques[source_id] = torque_vector
	last_torque_summary = source_id + " | torque " + str(snapped(torque_vector.length(), 0.01))


func clear_continuous_torque(source_id: String) -> void:
	continuous_torques.erase(source_id)


func integrate_continuous_motion(
	delta: float,
	mass_kg: float = 1.0,
	angular_inertia: float = 1.0
) -> Dictionary:
	var safe_mass: float = max(mass_kg, 0.01)
	var safe_inertia: float = max(angular_inertia, 0.01)
	var total_force: Vector3 = get_total_continuous_force()
	var total_torque: Vector3 = get_total_continuous_torque()

	continuous_velocity += (total_force / safe_mass) * delta
	angular_velocity += (total_torque / safe_inertia) * delta

	continuous_velocity *= max(0.0, 1.0 - continuous_linear_damping * delta)
	angular_velocity *= max(0.0, 1.0 - continuous_angular_damping * delta)

	if continuous_velocity.length() > max_continuous_speed:
		continuous_velocity = continuous_velocity.normalized() * max_continuous_speed
	if angular_velocity.length() > max_angular_speed:
		angular_velocity = angular_velocity.normalized() * max_angular_speed

	return {
		"linear_velocity": continuous_velocity,
		"angular_velocity": angular_velocity,
		"force": total_force,
		"torque": total_torque,
	}


func get_total_continuous_force() -> Vector3:
	var total: Vector3 = Vector3.ZERO
	for raw_force: Variant in continuous_forces.values():
		if raw_force is Vector3:
			total += raw_force as Vector3
	return total


func get_total_continuous_torque() -> Vector3:
	var total: Vector3 = Vector3.ZERO
	for raw_torque: Variant in continuous_torques.values():
		if raw_torque is Vector3:
			total += raw_torque as Vector3
	return total


func consume_external_velocity(delta: float) -> Vector3:
	var current_velocity: Vector3 = external_velocity
	external_velocity = external_velocity.move_toward(Vector3.ZERO, drag * delta)
	return current_velocity


func clear_all_continuous_influences() -> void:
	continuous_forces.clear()
	continuous_torques.clear()
	continuous_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	last_torque_summary = "none"


func reset_forces() -> void:
	external_velocity = Vector3.ZERO
	continuous_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	continuous_forces.clear()
	continuous_torques.clear()
	last_force_summary = "none"
	last_torque_summary = "none"


func has_force() -> bool:
	return (
		external_velocity.length() > 0.05
		or continuous_velocity.length() > 0.05
		or not continuous_forces.is_empty()
	)


func get_debug_data() -> Dictionary:
	return {
		"force": snapped(external_velocity.length(), 0.01),
		"impulse_velocity": external_velocity,
		"continuous_velocity": continuous_velocity,
		"continuous_force": get_total_continuous_force(),
		"continuous_sources": continuous_forces.keys(),
		"angular_velocity": angular_velocity,
		"continuous_torque": get_total_continuous_torque(),
		"torque_sources": continuous_torques.keys(),
		"last": last_force_summary,
		"last_torque": last_torque_summary,
	}
