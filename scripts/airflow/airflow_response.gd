extends Node
class_name AirflowResponse

const AirflowMathScript = preload("res://scripts/airflow/airflow_math.gd")

@export var mass_override_kg: float = 0.0
@export var drag_coefficient: float = 1.05
@export var cross_section_area: float = 1.0
@export var air_density: float = 1.225
@export var gameplay_force_scale: float = 3.5
@export var maximum_acceleration: float = 18.0
@export var torque_response: float = 0.0
@export var local_drag_axis: Vector3 = Vector3.FORWARD
@export var active: bool = true

var airflow_manager: Node = null
var source_id: String = ""
var last_air_velocity: Vector3 = Vector3.ZERO
var last_relative_velocity: Vector3 = Vector3.ZERO
var last_force: Vector3 = Vector3.ZERO
var last_acceleration: Vector3 = Vector3.ZERO
var last_torque: Vector3 = Vector3.ZERO


func _ready() -> void:
	source_id = "airflow:" + str(get_instance_id())
	add_to_group("airflow_responsive")
	add_to_group("debuggable")
	resolve_manager()


func resolve_manager() -> Node:
	if airflow_manager != null and is_instance_valid(airflow_manager):
		return airflow_manager
	airflow_manager = get_tree().get_first_node_in_group("airflow_manager")
	return airflow_manager


func sample_air_velocity(world_position: Vector3) -> Vector3:
	if not active:
		last_air_velocity = Vector3.ZERO
		return Vector3.ZERO
	var manager: Node = resolve_manager()
	if manager == null or not manager.has_method("sample_total_airflow"):
		last_air_velocity = Vector3.ZERO
		return Vector3.ZERO
	last_air_velocity = manager.call("sample_total_airflow", world_position) as Vector3
	return last_air_velocity


func get_effective_mass(fallback_mass: float = 1.0) -> float:
	if mass_override_kg > 0.0:
		return mass_override_kg
	return max(fallback_mass, 0.01)


func get_airflow_force(
	world_position: Vector3,
	body_velocity: Vector3,
	fallback_mass: float = 1.0,
	response_multiplier: float = 1.0
) -> Vector3:
	var air_velocity: Vector3 = sample_air_velocity(world_position)
	var mass_kg: float = get_effective_mass(fallback_mass)
	last_relative_velocity = air_velocity - body_velocity
	last_force = AirflowMathScript.compute_drag_force(
		air_velocity,
		body_velocity,
		mass_kg,
		drag_coefficient,
		cross_section_area,
		air_density,
		gameplay_force_scale * max(response_multiplier, 0.0),
		maximum_acceleration
	)
	last_acceleration = last_force / mass_kg
	return last_force


func get_airflow_acceleration(
	world_position: Vector3,
	body_velocity: Vector3,
	fallback_mass: float = 1.0,
	response_multiplier: float = 1.0
) -> Vector3:
	get_airflow_force(world_position, body_velocity, fallback_mass, response_multiplier)
	return last_acceleration


func update_force_response(
	body: Node3D,
	force_receiver: ForceReceiver,
	fallback_mass: float = 1.0,
	response_multiplier: float = 1.0
) -> void:
	if body == null or force_receiver == null:
		return
	if not active:
		clear_force_response(force_receiver)
		return
	var body_velocity: Vector3 = Vector3.ZERO
	var velocity_value: Variant = body.get("velocity")
	if velocity_value is Vector3:
		body_velocity = velocity_value as Vector3
	var force: Vector3 = get_airflow_force(
		body.global_position,
		body_velocity,
		fallback_mass,
		response_multiplier
	)
	force_receiver.set_continuous_force(source_id, force)
	last_torque = calculate_alignment_torque(body, last_relative_velocity)
	force_receiver.set_continuous_torque(source_id, last_torque)


func calculate_alignment_torque(body: Node3D, relative_velocity: Vector3) -> Vector3:
	if torque_response <= 0.001 or relative_velocity.length() <= 0.01:
		return Vector3.ZERO
	var local_axis: Vector3 = local_drag_axis
	if local_axis.length() <= 0.001:
		local_axis = Vector3.FORWARD
	var world_axis: Vector3 = body.global_transform.basis * local_axis.normalized()
	var desired_axis: Vector3 = relative_velocity.normalized()
	return world_axis.cross(desired_axis) * torque_response * relative_velocity.length()


func clear_force_response(force_receiver: ForceReceiver = null) -> void:
	last_air_velocity = Vector3.ZERO
	last_relative_velocity = Vector3.ZERO
	last_force = Vector3.ZERO
	last_acceleration = Vector3.ZERO
	last_torque = Vector3.ZERO
	if force_receiver != null and source_id != "":
		force_receiver.clear_continuous_force(source_id)
		force_receiver.clear_continuous_torque(source_id)


func has_active_airflow(world_position: Vector3, threshold: float = 0.05) -> bool:
	return sample_air_velocity(world_position).length() > threshold


func get_debug_data() -> Dictionary:
	return {
		"airflow_response": true,
		"air_velocity": last_air_velocity,
		"air_speed": snapped(last_air_velocity.length(), 0.01),
		"relative_velocity": last_relative_velocity,
		"force": last_force,
		"acceleration": last_acceleration,
		"torque": last_torque,
		"drag_coefficient": snapped(drag_coefficient, 0.01),
		"area": snapped(cross_section_area, 0.01),
	}
