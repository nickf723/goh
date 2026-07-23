extends Node
class_name GasManager

signal gas_sampled(world_position: Vector3, breakdown: Dictionary)

@export var emit_sample_signal: bool = false

var sample_count: int = 0
var last_sample_position: Vector3 = Vector3.ZERO
var last_breakdown: Dictionary = {}


func _ready() -> void:
	add_to_group("gas_manager")
	add_to_group("debuggable")


func sample_density(world_position: Vector3, gas_id: String = "") -> float:
	var total_density: float = 0.0
	for volume: Node in get_tree().get_nodes_in_group("gas_volumes"):
		if volume == null or not is_instance_valid(volume):
			continue
		if not volume.has_method("sample_density"):
			continue
		var volume_gas_id: String = str(volume.get("gas_id")) if volume.get("gas_id") != null else ""
		if gas_id != "" and volume_gas_id != gas_id:
			continue
		total_density += float(volume.call("sample_density", world_position))
	return max(total_density, 0.0)


func sample_breakdown(world_position: Vector3) -> Dictionary:
	var breakdown: Dictionary = {}
	for volume: Node in get_tree().get_nodes_in_group("gas_volumes"):
		if volume == null or not is_instance_valid(volume):
			continue
		if not volume.has_method("sample_density"):
			continue
		var volume_gas_id: String = str(volume.get("gas_id")) if volume.get("gas_id") != null else "gas"
		var density: float = float(volume.call("sample_density", world_position))
		if density <= 0.0001:
			continue
		breakdown[volume_gas_id] = float(breakdown.get(volume_gas_id, 0.0)) + density

	sample_count += 1
	last_sample_position = world_position
	last_breakdown = breakdown.duplicate(true)
	if emit_sample_signal:
		gas_sampled.emit(world_position, breakdown.duplicate(true))
	return breakdown


func find_definition(gas_id: String) -> GasDefinition:
	for volume: Node in get_tree().get_nodes_in_group("gas_volumes"):
		if volume == null or not is_instance_valid(volume):
			continue
		if str(volume.get("gas_id")) != gas_id:
			continue
		var definition_value: Variant = volume.get("gas_definition")
		if definition_value is GasDefinition:
			return definition_value as GasDefinition
	return null


func get_total_mass(gas_id: String = "") -> float:
	var total: float = 0.0
	for volume: Node in get_tree().get_nodes_in_group("gas_volumes"):
		if volume == null or not is_instance_valid(volume):
			continue
		if gas_id != "" and str(volume.get("gas_id")) != gas_id:
			continue
		if volume.has_method("get_total_density_mass"):
			total += float(volume.call("get_total_density_mass"))
	return total


func get_debug_data() -> Dictionary:
	return {
		"gas_manager": true,
		"volume_count": get_tree().get_nodes_in_group("gas_volumes").size(),
		"sample_count": sample_count,
		"last_position": last_sample_position,
		"last_breakdown": last_breakdown.duplicate(true),
	}
