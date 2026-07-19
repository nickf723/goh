extends Node
class_name CircuitThermalAdapter

@export var circuit_component_path: NodePath = NodePath("..")
@export var thermal_state_path: NodePath = NodePath("../ThermalState")
@export var enabled: bool = true
@export var joule_heat_scale: float = 12.0
@export var maximum_heat_power_w: float = 1200.0

var circuit_component: CircuitComponent
var thermal_state: ThermalState
var last_power_w: float = 0.0
var accumulated_energy_j: float = 0.0


func _ready() -> void:
	resolve_targets()
	add_to_group("debuggable")


func _process(delta: float) -> void:
	step_heating(delta)


func configure(component: CircuitComponent, state: ThermalState) -> void:
	circuit_component = component
	thermal_state = state


func resolve_targets() -> void:
	circuit_component = get_node_or_null(circuit_component_path) as CircuitComponent
	thermal_state = get_node_or_null(thermal_state_path) as ThermalState


func step_heating(delta: float) -> float:
	last_power_w = 0.0
	if not enabled or delta <= 0.0:
		return 0.0
	if circuit_component == null or thermal_state == null:
		resolve_targets()
	if circuit_component == null or thermal_state == null:
		return 0.0
	if not circuit_component.energized:
		return 0.0

	var current_amps: float = absf(circuit_component.signed_current_amps)
	var resistance_ohms: float = circuit_component.get_effective_resistance()
	var physical_power_w: float = current_amps * current_amps * resistance_ohms
	last_power_w = min(
		physical_power_w * max(joule_heat_scale, 0.0),
		max(maximum_heat_power_w, 0.0)
	)
	var energy_j: float = last_power_w * delta
	if energy_j > 0.0:
		thermal_state.apply_energy_j(energy_j, "Resistive heating")
		accumulated_energy_j += energy_j
	return energy_j


func reset_target() -> void:
	last_power_w = 0.0
	accumulated_energy_j = 0.0


func get_debug_data() -> Dictionary:
	return {
		"circuit_thermal_adapter": true,
		"component": circuit_component.component_id if circuit_component != null else "missing",
		"thermal_state": thermal_state.get_path() if thermal_state != null else NodePath(),
		"last_power_w": snapped(last_power_w, 0.01),
		"accumulated_energy_j": snapped(accumulated_energy_j, 0.01),
	}
