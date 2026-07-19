extends Node3D
class_name BuoyancyLoadSensor

@export var half_extents: Vector3 = Vector3(2.2, 0.9, 1.7)
@export var minimum_local_y: float = -0.2
@export var maximum_local_y: float = 1.8
@export var enabled: bool = true

var last_load_kg: float = 0.0
var last_body_names: Array[String] = []


func _ready() -> void:
	add_to_group("debuggable")


func measure_external_load(host_body: FieldResponsiveBody) -> float:
	last_load_kg = 0.0
	last_body_names.clear()
	if not enabled or host_body == null or get_tree() == null:
		return 0.0

	for candidate_node: Node in get_tree().get_nodes_in_group("physical_bodies"):
		var candidate := candidate_node as FieldResponsiveBody
		if candidate == null or candidate == host_body or not is_instance_valid(candidate):
			continue
		var local_position: Vector3 = to_local(candidate.global_position)
		if absf(local_position.x) > half_extents.x:
			continue
		if absf(local_position.z) > half_extents.z:
			continue
		if local_position.y < minimum_local_y or local_position.y > maximum_local_y:
			continue
		last_load_kg += candidate.get_effective_mass()
		last_body_names.append(candidate.body_label)
	return last_load_kg


func get_debug_data() -> Dictionary:
	return {
		"buoyancy_load_sensor": true,
		"enabled": enabled,
		"load_kg": snapped(last_load_kg, 0.01),
		"bodies": last_body_names.duplicate(),
		"half_extents": half_extents,
	}
