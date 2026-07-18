extends Node
class_name PhysicalFieldReceiver

@export var material_profile: PhysicalMaterialProfile
@export var local_magnetic_axis: Vector3 = Vector3.RIGHT
@export var field_force_scale: float = 6.0
@export var field_torque_scale: float = 4.0
@export var induced_response_speed: float = 6.0
@export var induced_decay_speed: float = 2.0

var induced_magnetization: Vector3 = Vector3.ZERO
var active_field_source_ids: Array[String] = []
var last_field_samples: Array[Dictionary] = []
var last_total_field: Vector3 = Vector3.ZERO
var last_total_force: Vector3 = Vector3.ZERO
var last_total_torque: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group("debuggable")


func update_field_response(
	body: Node3D,
	force_receiver: ForceReceiver,
	delta: float
) -> void:
	if body == null or force_receiver == null:
		return

	clear_previous_field_influences(force_receiver)
	last_field_samples.clear()
	last_total_field = Vector3.ZERO
	last_total_force = Vector3.ZERO
	last_total_torque = Vector3.ZERO

	var magnetic_sample_count: int = 0
	for field_node: Node in get_tree().get_nodes_in_group("physical_fields"):
		if field_node == null or not field_node.has_method("sample_field"):
			continue
		var sample: Dictionary = field_node.sample_field(body.global_position)
		var field_vector: Vector3 = sample.get("vector", Vector3.ZERO) as Vector3
		if field_vector.length() <= 0.0001:
			continue

		last_field_samples.append(sample)
		last_total_field += field_vector
		var field_kind: String = str(sample.get("kind", "generic"))
		var source_id: String = "field:" + str(sample.get("field_id", field_node.name))
		active_field_source_ids.append(source_id)

		if field_kind == "magnetic":
			magnetic_sample_count += 1
			apply_magnetic_response(body, force_receiver, sample, source_id, delta)

	if magnetic_sample_count == 0:
		decay_induced_magnetization(delta)


func apply_magnetic_response(
	body: Node3D,
	force_receiver: ForceReceiver,
	sample: Dictionary,
	source_id: String,
	delta: float
) -> void:
	var field_vector: Vector3 = sample.get("vector", Vector3.ZERO) as Vector3
	var field_strength: float = field_vector.length()
	if field_strength <= 0.0001:
		return

	var susceptibility: float = get_material_value("magnetic_susceptibility", 0.0)
	var retention: float = get_material_value("magnetic_retention", 0.0)
	var permanent_strength: float = get_material_value("permanent_magnetic_strength", 0.0)
	if susceptibility <= 0.0 and permanent_strength <= 0.0:
		return

	var target_induced: Vector3 = field_vector.normalized() * min(
		field_strength * susceptibility,
		2.0
	)
	induced_magnetization = induced_magnetization.move_toward(
		target_induced,
		max(induced_response_speed, 0.0) * delta
	)

	var local_axis: Vector3 = local_magnetic_axis
	if local_axis.length() <= 0.001:
		local_axis = Vector3.RIGHT
	var permanent_moment: Vector3 = (
		body.global_basis * local_axis.normalized()
	) * permanent_strength
	var total_moment: Vector3 = permanent_moment + induced_magnetization
	var torque: Vector3 = total_moment.cross(field_vector) * field_torque_scale

	var source_position: Vector3 = sample.get("source_position", body.global_position) as Vector3
	var toward_source: Vector3 = source_position - body.global_position
	var distance: float = max(float(sample.get("distance", toward_source.length())), 0.25)
	if toward_source.length() > 0.001:
		toward_source = toward_source.normalized()
	else:
		toward_source = Vector3.ZERO

	var alignment: float = 0.0
	if permanent_moment.length() > 0.001:
		alignment = permanent_moment.normalized().dot(field_vector.normalized())
	var response_strength: float = susceptibility + permanent_strength * alignment
	var gradient_strength: float = field_strength / distance
	var force: Vector3 = toward_source * gradient_strength * field_force_scale * response_strength

	force_receiver.set_continuous_force(source_id, force)
	force_receiver.set_continuous_torque(source_id, torque)
	last_total_force += force
	last_total_torque += torque

	if retention > 0.0:
		var retained_target: Vector3 = field_vector.normalized() * susceptibility * retention
		induced_magnetization = induced_magnetization.lerp(retained_target, min(delta, 1.0))


func clear_previous_field_influences(force_receiver: ForceReceiver) -> void:
	for source_id: String in active_field_source_ids:
		force_receiver.clear_continuous_force(source_id)
		force_receiver.clear_continuous_torque(source_id)
	active_field_source_ids.clear()


func decay_induced_magnetization(delta: float) -> void:
	var retention: float = get_material_value("magnetic_retention", 0.0)
	var decay_multiplier: float = max(1.0 - retention, 0.02)
	induced_magnetization = induced_magnetization.move_toward(
		Vector3.ZERO,
		max(induced_decay_speed, 0.0) * decay_multiplier * delta
	)


func get_material_value(property_name: String, fallback: float) -> float:
	if material_profile == null:
		return fallback
	var value: Variant = material_profile.get(property_name)
	return fallback if value == null else float(value)


func reset_field_response(force_receiver: ForceReceiver = null) -> void:
	if force_receiver != null:
		clear_previous_field_influences(force_receiver)
	induced_magnetization = Vector3.ZERO
	last_field_samples.clear()
	last_total_field = Vector3.ZERO
	last_total_force = Vector3.ZERO
	last_total_torque = Vector3.ZERO


func get_debug_data() -> Dictionary:
	return {
		"material": material_profile.get_debug_data() if material_profile != null else {},
		"field_samples": last_field_samples.duplicate(true),
		"field": last_total_field,
		"force": last_total_force,
		"torque": last_total_torque,
		"induced_magnetization": induced_magnetization,
		"active_field_sources": active_field_source_ids.duplicate(),
	}
