extends Marker3D
class_name CircuitTerminal

@export var terminal_id: String = "terminal"
@export var connection_radius: float = 0.24
@export var network_layer: String = "default"
@export var enabled: bool = true

var last_contact_keys: Array[String] = []


func _ready() -> void:
	add_to_group("circuit_terminals")
	add_to_group("debuggable")


func get_component() -> CircuitComponent:
	var current: Node = get_parent()
	while current != null:
		if current is CircuitComponent:
			return current as CircuitComponent
		current = current.get_parent()
	return null


func get_terminal_key() -> String:
	var component: CircuitComponent = get_component()
	var component_key: String = component.component_id if component != null else "orphan"
	return component_key + ":" + terminal_id


func can_connect_to(other: CircuitTerminal) -> bool:
	if other == null or other == self or not enabled or not other.enabled:
		return false
	if network_layer != other.network_layer:
		return false

	var own_component: CircuitComponent = get_component()
	var other_component: CircuitComponent = other.get_component()
	if own_component == null or other_component == null or own_component == other_component:
		return false

	var contact_distance: float = max(connection_radius, 0.0) + max(other.connection_radius, 0.0)
	return global_position.distance_to(other.global_position) <= contact_distance


func get_contacting_terminals() -> Array[CircuitTerminal]:
	var contacts: Array[CircuitTerminal] = []
	for candidate: Node in get_tree().get_nodes_in_group("circuit_terminals"):
		if candidate is CircuitTerminal and can_connect_to(candidate as CircuitTerminal):
			contacts.append(candidate as CircuitTerminal)
	contacts.sort_custom(func(a: CircuitTerminal, b: CircuitTerminal) -> bool:
		return a.get_terminal_key() < b.get_terminal_key()
	)
	return contacts


func set_contact_debug(contacts: Array) -> void:
	last_contact_keys.clear()
	for raw_contact: Variant in contacts:
		last_contact_keys.append(str(raw_contact))


func get_debug_data() -> Dictionary:
	return {
		"terminal": get_terminal_key(),
		"position": global_position,
		"radius": snapped(connection_radius, 0.01),
		"layer": network_layer,
		"enabled": enabled,
		"contacts": last_contact_keys.duplicate(),
	}
