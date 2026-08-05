extends Node
class_name MechanismSignalNode

signal mechanism_signal_changed(mechanism_id: String, active: bool, packet: Dictionary)
signal mechanism_sources_bound(source_count: int)

@export_group("Identity")
@export var mechanism_id: String = "mechanism_signal"
@export var display_name: String = "Mechanism Signal"

@export_group("Sources")
@export var source_paths: Array[NodePath] = []
@export var evaluate_sources_as_or: bool = true

@export_group("State")
@export var initial_active: bool = false
@export var persist_active_state: bool = false
@export var persistence_flag: String = ""
@export var emit_initial_state: bool = true
@export var print_debug: bool = false

var active: bool = false
var last_packet: Dictionary = {}
var source_states: Dictionary = {}
var source_packets: Dictionary = {}
var source_nodes: Dictionary = {}
var initialized: bool = false


func _ready() -> void:
	add_to_group("mechanism_signal_nodes")
	add_to_group("lab_resettable")
	add_to_group("debuggable")
	active = _restore_initial_active_state()
	call_deferred("_initialize_mechanism_signal")


func _exit_tree() -> void:
	_disconnect_all_sources()


func _initialize_mechanism_signal() -> void:
	bind_exported_sources()
	initialized = true
	_on_sources_ready()
	if not source_states.is_empty():
		_evaluate_source_states()
	elif emit_initial_state:
		_emit_signal(true)
	mechanism_sources_bound.emit(source_nodes.size())


func bind_exported_sources() -> void:
	for source_path: NodePath in source_paths:
		var source: Node = _resolve_source_path(source_path)
		if source != null:
			bind_source(source)


func bind_source(source: Node) -> bool:
	if source == null or source == self or not is_instance_valid(source):
		return false
	if not source.has_signal("mechanism_signal_changed"):
		return false
	var source_id: String = _resolve_source_id(source)
	if source_id == "":
		return false
	if source_nodes.has(source_id) and source_nodes[source_id] == source:
		return true
	if source_nodes.has(source_id):
		unbind_source(source_nodes[source_id] as Node)
	var callback := Callable(self, "_on_bound_source_signal").bind(source)
	if not source.is_connected("mechanism_signal_changed", callback):
		source.connect("mechanism_signal_changed", callback)
	source_nodes[source_id] = source
	source_states[source_id] = _read_source_active(source)
	source_packets[source_id] = _read_source_packet(source)
	if initialized:
		_evaluate_source_states()
		mechanism_sources_bound.emit(source_nodes.size())
	return true


func unbind_source(source: Node) -> void:
	if source == null:
		return
	var source_id: String = _resolve_source_id(source)
	var callback := Callable(self, "_on_bound_source_signal").bind(source)
	if is_instance_valid(source) and source.has_signal("mechanism_signal_changed"):
		if source.is_connected("mechanism_signal_changed", callback):
			source.disconnect("mechanism_signal_changed", callback)
	source_nodes.erase(source_id)
	source_states.erase(source_id)
	source_packets.erase(source_id)
	if initialized:
		_evaluate_source_states()
		mechanism_sources_bound.emit(source_nodes.size())


func _disconnect_all_sources() -> void:
	var was_initialized: bool = initialized
	initialized = false
	for source_value: Variant in source_nodes.values().duplicate():
		if source_value is Node:
			unbind_source(source_value as Node)
	source_nodes.clear()
	source_states.clear()
	source_packets.clear()
	initialized = was_initialized


func set_mechanism_active(
	next_active: bool,
	packet: Dictionary = {},
	force_emit: bool = false
) -> bool:
	var changed: bool = active != next_active
	active = next_active
	last_packet = packet.duplicate(true)
	last_packet["mechanism_id"] = get_mechanism_id()
	last_packet["active"] = active
	if persist_active_state:
		_persist_active_state()
	_on_signal_state_applied(changed)
	if changed or force_emit:
		_emit_signal(force_emit)
	return changed


func is_mechanism_active() -> bool:
	return active


func get_mechanism_id() -> String:
	var normalized: String = mechanism_id.to_lower().strip_edges().replace(" ", "_")
	return normalized if normalized != "" else str(name).to_lower()


func get_mechanism_packet() -> Dictionary:
	return last_packet.duplicate(true)


func get_source_state(source_id: String) -> bool:
	return bool(source_states.get(_normalize_id(source_id), false))


func get_active_source_count() -> int:
	var count: int = 0
	for value: Variant in source_states.values():
		if bool(value):
			count += 1
	return count


func get_bound_source_count() -> int:
	return source_nodes.size()


func reset_target() -> void:
	set_mechanism_active(initial_active, {
		"reason": "reset",
		"source_count": source_nodes.size(),
	}, true)
	for source_id: Variant in source_nodes.keys():
		var source: Node = source_nodes[source_id] as Node
		if source != null and is_instance_valid(source):
			source_states[source_id] = _read_source_active(source)
			source_packets[source_id] = _read_source_packet(source)
	if not source_states.is_empty():
		_evaluate_source_states()


func _on_bound_source_signal(
	source_id_from_signal: String,
	next_active: bool,
	packet: Dictionary,
	source: Node
) -> void:
	var source_id: String = _resolve_source_id(source)
	if source_id == "":
		source_id = _normalize_id(source_id_from_signal)
	var previous_active: bool = bool(source_states.get(source_id, false))
	source_states[source_id] = next_active
	source_packets[source_id] = packet.duplicate(true)
	_on_source_state_changed(source_id, previous_active, next_active, packet)


func _on_source_state_changed(
	_source_id: String,
	_previous_active: bool,
	_next_active: bool,
	_packet: Dictionary
) -> void:
	_evaluate_source_states()


func _evaluate_source_states() -> void:
	if not evaluate_sources_as_or:
		return
	set_mechanism_active(get_active_source_count() > 0, {
		"reason": "source_evaluation",
		"active_sources": get_active_source_count(),
		"source_count": source_states.size(),
	})


func _on_sources_ready() -> void:
	pass


func _on_signal_state_applied(_changed: bool) -> void:
	pass


func _emit_signal(force_emit: bool = false) -> void:
	var packet: Dictionary = last_packet.duplicate(true)
	packet["mechanism_id"] = get_mechanism_id()
	packet["display_name"] = display_name
	packet["active"] = active
	packet["force_emit"] = force_emit
	if print_debug:
		print("MECHANISM ", get_mechanism_id(), " = ", active, " ", packet)
	mechanism_signal_changed.emit(get_mechanism_id(), active, packet)


func _resolve_source_path(path: NodePath) -> Node:
	if path == NodePath():
		return null
	var source: Node = get_node_or_null(path)
	if source == null and get_parent() != null:
		source = get_parent().get_node_or_null(path)
	return source


func _resolve_source_id(source: Node) -> String:
	if source == null:
		return ""
	if source.has_method("get_mechanism_id"):
		return _normalize_id(str(source.call("get_mechanism_id")))
	return _normalize_id(str(source.name))


func _read_source_active(source: Node) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	if source.has_method("is_mechanism_active"):
		return bool(source.call("is_mechanism_active"))
	var active_value: Variant = source.get("active")
	return bool(active_value) if active_value != null else false


func _read_source_packet(source: Node) -> Dictionary:
	if source != null and is_instance_valid(source):
		if source.has_method("get_mechanism_packet"):
			var value: Variant = source.call("get_mechanism_packet")
			if value is Dictionary:
				return (value as Dictionary).duplicate(true)
	return {}


func _restore_initial_active_state() -> bool:
	if not persist_active_state:
		return initial_active
	var flag: String = _resolved_persistence_flag()
	if flag == "" or not GameState.has_method("get_flag"):
		return initial_active
	return bool(GameState.call("get_flag", flag))


func _persist_active_state() -> void:
	var flag: String = _resolved_persistence_flag()
	if flag == "" or not GameState.has_method("set_flag"):
		return
	GameState.call("set_flag", flag, active)


func _resolved_persistence_flag() -> String:
	var normalized: String = persistence_flag.to_lower().strip_edges().replace(" ", "_")
	if normalized != "":
		return normalized
	return "mechanism_" + get_mechanism_id()


func _normalize_id(value: String) -> String:
	return value.to_lower().strip_edges().replace(" ", "_")


func get_debug_data() -> Dictionary:
	return {
		"mechanism_id": get_mechanism_id(),
		"display_name": display_name,
		"active": active,
		"source_count": source_nodes.size(),
		"active_sources": get_active_source_count(),
		"source_states": source_states.duplicate(true),
		"packet": last_packet.duplicate(true),
		"persistent": persist_active_state,
		"persistence_flag": _resolved_persistence_flag() if persist_active_state else "",
		"initialized": initialized,
	}
