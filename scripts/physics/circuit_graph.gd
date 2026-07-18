extends RefCounted
class_name CircuitGraph

var terminals: Dictionary = {}
var adjacency: Dictionary = {}
var contact_pairs: Array[String] = []


func build(components: Array[CircuitComponent]) -> void:
	terminals.clear()
	adjacency.clear()
	contact_pairs.clear()

	for component: CircuitComponent in components:
		for terminal: CircuitTerminal in [component.get_terminal_a(), component.get_terminal_b()]:
			if terminal == null:
				continue
			var terminal_key: int = terminal.get_instance_id()
			terminals[terminal_key] = terminal
			adjacency[terminal_key] = []
			terminal.set_contact_debug([])

	var terminal_values: Array = terminals.values()
	var contact_debug: Dictionary = {}
	for terminal: CircuitTerminal in terminal_values:
		contact_debug[terminal.get_instance_id()] = []

	for first_index: int in range(terminal_values.size()):
		var first_terminal: CircuitTerminal = terminal_values[first_index] as CircuitTerminal
		for second_index: int in range(first_index + 1, terminal_values.size()):
			var second_terminal: CircuitTerminal = terminal_values[second_index] as CircuitTerminal
			if not first_terminal.can_connect_to(second_terminal):
				continue
			add_edge(first_terminal, second_terminal, 0.0, null, 0, "contact")
			var pair_key: String = first_terminal.get_terminal_key() + " <-> " + second_terminal.get_terminal_key()
			contact_pairs.append(pair_key)
			(contact_debug[first_terminal.get_instance_id()] as Array).append(second_terminal.get_terminal_key())
			(contact_debug[second_terminal.get_instance_id()] as Array).append(first_terminal.get_terminal_key())

	for component: CircuitComponent in components:
		if component.is_voltage_source or not component.is_path_conductive():
			continue
		add_edge(
			component.get_terminal_a(),
			component.get_terminal_b(),
			component.get_effective_resistance(),
			component,
			1,
			"component"
		)

	for raw_terminal: Variant in terminal_values:
		var terminal: CircuitTerminal = raw_terminal as CircuitTerminal
		var raw_contacts: Array = contact_debug.get(terminal.get_instance_id(), []) as Array
		terminal.set_contact_debug(raw_contacts)
	contact_pairs.sort()


func add_edge(
	from_terminal: CircuitTerminal,
	to_terminal: CircuitTerminal,
	resistance: float,
	component: CircuitComponent,
	direction: int,
	kind: String
) -> void:
	if from_terminal == null or to_terminal == null:
		return
	var from_key: int = from_terminal.get_instance_id()
	var to_key: int = to_terminal.get_instance_id()
	(adjacency[from_key] as Array).append({
		"to": to_key,
		"resistance": max(resistance, 0.0),
		"component": component,
		"direction": direction,
		"kind": kind,
	})
	(adjacency[to_key] as Array).append({
		"to": from_key,
		"resistance": max(resistance, 0.0),
		"component": component,
		"direction": -direction,
		"kind": kind,
	})


func find_lowest_resistance_path(
	start_terminal: CircuitTerminal,
	end_terminal: CircuitTerminal
) -> Array[Dictionary]:
	var empty_path: Array[Dictionary] = []
	if start_terminal == null or end_terminal == null:
		return empty_path

	var start_key: int = start_terminal.get_instance_id()
	var end_key: int = end_terminal.get_instance_id()
	if not adjacency.has(start_key) or not adjacency.has(end_key):
		return empty_path

	var distances: Dictionary = {}
	var previous: Dictionary = {}
	var unvisited: Array[int] = []
	for raw_key: Variant in adjacency.keys():
		var key: int = int(raw_key)
		distances[key] = INF
		unvisited.append(key)
	distances[start_key] = 0.0

	while not unvisited.is_empty():
		var current_key: int = pick_nearest(unvisited, distances)
		if current_key == -1 or float(distances[current_key]) == INF:
			break
		unvisited.erase(current_key)
		if current_key == end_key:
			break
		for edge: Dictionary in adjacency[current_key] as Array:
			var neighbor_key: int = int(edge.get("to", -1))
			if not unvisited.has(neighbor_key):
				continue
			var candidate_distance: float = float(distances[current_key]) + float(edge.get("resistance", 0.0))
			if candidate_distance < float(distances[neighbor_key]):
				distances[neighbor_key] = candidate_distance
				previous[neighbor_key] = {"from": current_key, "edge": edge}

	if start_key != end_key and not previous.has(end_key):
		return empty_path

	var reversed_path: Array[Dictionary] = []
	var cursor: int = end_key
	while cursor != start_key:
		var step: Dictionary = previous[cursor]
		reversed_path.append(step.get("edge", {}) as Dictionary)
		cursor = int(step.get("from", start_key))
	reversed_path.reverse()
	return reversed_path


func pick_nearest(unvisited: Array[int], distances: Dictionary) -> int:
	var best_key: int = -1
	var best_distance: float = INF
	for key: int in unvisited:
		var distance: float = float(distances.get(key, INF))
		if distance < best_distance:
			best_distance = distance
			best_key = key
	return best_key
