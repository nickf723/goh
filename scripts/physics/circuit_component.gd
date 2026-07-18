extends Node3D
class_name CircuitComponent

signal circuit_state_changed(component: CircuitComponent)

@export var component_id: String = "component"
@export var display_name: String = "Circuit Component"
@export var component_kind: String = "conductor"
@export var material_profile: PhysicalMaterialProfile
@export var resistance_ohms: float = 0.1
@export var max_current_amps: float = 20.0
@export var path_enabled: bool = true
@export var is_voltage_source: bool = false
@export var source_voltage_volts: float = 0.0
@export var source_internal_resistance_ohms: float = 0.1
@export var terminal_a_path: NodePath = NodePath("TerminalA")
@export var terminal_b_path: NodePath = NodePath("TerminalB")

var energized: bool = false
var signed_current_amps: float = 0.0
var voltage_drop_volts: float = 0.0
var overloaded: bool = false
var solution_generation: int = -1


func _ready() -> void:
	add_to_group("circuit_components")
	add_to_group("debuggable")


func get_terminal_a() -> CircuitTerminal:
	return get_node_or_null(terminal_a_path) as CircuitTerminal


func get_terminal_b() -> CircuitTerminal:
	return get_node_or_null(terminal_b_path) as CircuitTerminal


func is_path_conductive() -> bool:
	if not path_enabled or get_terminal_a() == null or get_terminal_b() == null:
		return false
	if is_voltage_source:
		return true
	return material_profile == null or material_profile.is_conductive(0.05)


func get_effective_resistance() -> float:
	var raw_resistance: float = source_internal_resistance_ohms if is_voltage_source else resistance_ohms
	return max(raw_resistance, 0.001)


func get_source_voltage() -> float:
	return source_voltage_volts if is_voltage_source and path_enabled else 0.0


func get_positive_terminal() -> CircuitTerminal:
	return get_terminal_a() if get_source_voltage() >= 0.0 else get_terminal_b()


func get_negative_terminal() -> CircuitTerminal:
	return get_terminal_b() if get_source_voltage() >= 0.0 else get_terminal_a()


func apply_circuit_state(active: bool, current: float, voltage_drop: float, generation: int) -> void:
	energized = active
	signed_current_amps = current if active else 0.0
	voltage_drop_volts = voltage_drop if active else 0.0
	overloaded = active and abs(current) > max(max_current_amps, 0.001)
	solution_generation = generation
	_on_circuit_state_applied()
	circuit_state_changed.emit(self)


func _on_circuit_state_applied() -> void:
	pass


func notify_topology_changed() -> void:
	get_tree().call_group("circuit_solvers", "request_solve")


func get_debug_data() -> Dictionary:
	return {
		"component": component_id,
		"kind": component_kind,
		"conductive": is_path_conductive(),
		"resistance": snapped(get_effective_resistance(), 0.001),
		"voltage_source": snapped(get_source_voltage(), 0.01),
		"current": snapped(signed_current_amps, 0.001),
		"voltage_drop": snapped(voltage_drop_volts, 0.001),
		"energized": energized,
		"overloaded": overloaded,
	}
