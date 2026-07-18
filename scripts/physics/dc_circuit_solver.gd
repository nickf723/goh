extends Node
class_name DCCircuitSolver

signal circuit_solved(is_closed: bool, current_amps: float, total_resistance_ohms: float)

@export var auto_solve: bool = true
@export var solve_interval: float = 0.08
@export var minimum_total_resistance: float = 0.05

var solve_timer: float = 0.0
var generation: int = 0
var circuit_closed: bool = false
var current_amps: float = 0.0
var total_resistance_ohms: float = 0.0
var active_component_ids: Array[String] = []
var contact_pairs: Array[String] = []
var last_failure_reason: String = "not solved"


func _ready() -> void:
	add_to_group("circuit_solvers")
	add_to_group("debuggable")
	request_solve()


func _process(delta: float) -> void:
	if not auto_solve:
		return
	solve_timer -= delta
	if solve_timer <= 0.0:
		solve_network()
		solve_timer = max(solve_interval, 0.02)


func request_solve() -> void:
	solve_timer = 0.0
	if not auto_solve:
		call_deferred("solve_network")


func solve_network() -> void:
	generation += 1
	var components: Array[CircuitComponent] = get_scoped_components()
	for component: CircuitComponent in components:
		component.apply_circuit_state(false, 0.0, 0.0, generation)

	var graph := CircuitGraph.new()
	graph.build(components)
	contact_pairs = graph.contact_pairs.duplicate()

	var sources: Array[CircuitComponent] = []
	for component: CircuitComponent in components:
		if component.is_voltage_source and abs(component.get_source_voltage()) > 0.001:
			sources.append(component)
	if sources.size() != 1:
		set_open_state("expected exactly one active voltage source")
		return

	var source: CircuitComponent = sources[0]
	var path: Array[Dictionary] = graph.find_lowest_resistance_path(
		source.get_positive_terminal(),
		source.get_negative_terminal()
	)
	if path.is_empty():
		set_open_state("no closed conductive return path")
		return

	var path_resistance: float = 0.0
	for edge: Dictionary in path:
		path_resistance += float(edge.get("resistance", 0.0))
	total_resistance_ohms = max(
		path_resistance + source.get_effective_resistance(),
		minimum_total_resistance
	)
	current_amps = abs(source.get_source_voltage()) / total_resistance_ohms
	current_amps = min(current_amps, max(source.max_current_amps, 0.001))
	circuit_closed = true
	last_failure_reason = ""
	active_component_ids.clear()

	var source_current: float = current_amps * signf(source.get_source_voltage())
	source.apply_circuit_state(true, source_current, abs(source_current) * source.get_effective_resistance(), generation)
	active_component_ids.append(source.component_id)

	var applied_components: Dictionary = {}
	for edge: Dictionary in path:
		var component: CircuitComponent = edge.get("component") as CircuitComponent
		if component == null or applied_components.has(component.get_instance_id()):
			continue
		var direction: float = float(edge.get("direction", 0))
		var signed_current: float = current_amps * direction
		component.apply_circuit_state(
			true,
			signed_current,
			abs(signed_current) * component.get_effective_resistance(),
			generation
		)
		applied_components[component.get_instance_id()] = true
		active_component_ids.append(component.component_id)
	active_component_ids.sort()
	circuit_solved.emit(true, current_amps, total_resistance_ohms)


func set_open_state(reason: String) -> void:
	circuit_closed = false
	current_amps = 0.0
	total_resistance_ohms = 0.0
	active_component_ids.clear()
	last_failure_reason = reason
	circuit_solved.emit(false, 0.0, 0.0)


func get_scoped_components() -> Array[CircuitComponent]:
	var components: Array[CircuitComponent] = []
	var scope_root: Node = get_parent()
	for candidate: Node in get_tree().get_nodes_in_group("circuit_components"):
		if not candidate is CircuitComponent:
			continue
		if scope_root != null and candidate != scope_root and not scope_root.is_ancestor_of(candidate):
			continue
		components.append(candidate as CircuitComponent)
	components.sort_custom(func(a: CircuitComponent, b: CircuitComponent) -> bool:
		return a.component_id < b.component_id
	)
	return components


func reset_target() -> void:
	request_solve()


func get_debug_data() -> Dictionary:
	return {
		"circuit_closed": circuit_closed,
		"current_amps": snapped(current_amps, 0.001),
		"total_resistance_ohms": snapped(total_resistance_ohms, 0.001),
		"active_components": active_component_ids.duplicate(),
		"contacts": contact_pairs.duplicate(),
		"failure": last_failure_reason,
		"generation": generation,
	}
