extends Node
class_name ThermalContactLink

@export var thermal_state_a_path: NodePath
@export var thermal_state_b_path: NodePath
@export var enabled: bool = true
@export var conductance_j_per_second_c: float = 0.35
@export var maximum_transfer_j_per_second: float = 500.0

var thermal_state_a: ThermalState
var thermal_state_b: ThermalState
var last_transfer_j: float = 0.0


func _ready() -> void:
	resolve_states()
	add_to_group("debuggable")


func _process(delta: float) -> void:
	step_transfer(delta)


func configure(first_state: ThermalState, second_state: ThermalState) -> void:
	thermal_state_a = first_state
	thermal_state_b = second_state


func resolve_states() -> void:
	if not thermal_state_a_path.is_empty():
		thermal_state_a = get_node_or_null(thermal_state_a_path) as ThermalState
	if not thermal_state_b_path.is_empty():
		thermal_state_b = get_node_or_null(thermal_state_b_path) as ThermalState


func step_transfer(delta: float) -> float:
	last_transfer_j = 0.0
	if not enabled or delta <= 0.0:
		return 0.0
	if thermal_state_a == null or thermal_state_b == null:
		resolve_states()
	if thermal_state_a == null or thermal_state_b == null:
		return 0.0

	var difference_c: float = thermal_state_a.temperature_c - thermal_state_b.temperature_c
	if absf(difference_c) <= 0.001:
		return 0.0

	var requested_energy_j: float = (
		difference_c
		* max(conductance_j_per_second_c, 0.0)
		* delta
	)
	var capacity_a: float = thermal_state_a.get_heat_capacity_j_per_c()
	var capacity_b: float = thermal_state_b.get_heat_capacity_j_per_c()
	var equilibrium_c: float = (
		thermal_state_a.temperature_c * capacity_a
		+ thermal_state_b.temperature_c * capacity_b
	) / max(capacity_a + capacity_b, 0.01)
	var equalization_limit_j: float = absf(
		(thermal_state_a.temperature_c - equilibrium_c) * capacity_a
	)
	var rate_limit_j: float = max(maximum_transfer_j_per_second, 0.0) * delta
	var transfer_magnitude_j: float = min(
		absf(requested_energy_j),
		min(equalization_limit_j, rate_limit_j)
	)
	if transfer_magnitude_j <= 0.0001:
		return 0.0

	var signed_transfer_j: float = transfer_magnitude_j if requested_energy_j > 0.0 else -transfer_magnitude_j
	thermal_state_a.apply_energy_j(-signed_transfer_j, "Thermal contact")
	thermal_state_b.apply_energy_j(signed_transfer_j, "Thermal contact")
	last_transfer_j = signed_transfer_j
	return signed_transfer_j


func get_debug_data() -> Dictionary:
	return {
		"thermal_contact": true,
		"enabled": enabled,
		"state_a": thermal_state_a.get_path() if thermal_state_a != null else NodePath(),
		"state_b": thermal_state_b.get_path() if thermal_state_b != null else NodePath(),
		"conductance": snapped(conductance_j_per_second_c, 0.01),
		"last_transfer_j": snapped(last_transfer_j, 0.01),
	}
