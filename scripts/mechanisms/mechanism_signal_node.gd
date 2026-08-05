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

@export_group("Value")
@export var mirror_active_to_value: bool = true
@export var initial_value: float = 0.0
@export var minimum_value: float = 0.0
@export var maximum_value: float = 1.0
@export var value_unit: String = ""
@export var clamp_value_to_range: bool = false
@export_range(0.000001, 1.0, 0.000001) var value_change_epsilon: float = 0.0001

var active: bool = false
var value: float = 0.0
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
	value = _sanitize_value(
		(1.0 if active else 0.0)
		if mirror_active_to_value
		else initial_value
	)
	last_packet = _decorate_packet({"reason": "startup"})
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
	var previous_active: bool = active
	var next_value: float = value
	if mirror_active_to_value:
		next_value = 1.0 if next_active else 0.0
	_apply_mechanism_state(next_active, next_value, packet, force_emit)
	return previous_active != active


func set_mechanism_value(
	next_value: float,
	packet: Dictionary = {},
	force_emit: bool = false
) -> bool:
	var previous_value: float = value
	_apply_mechanism_state(active, next_value, packet, force_emit)
	return absf(previous_value - value) > value_change_epsilon


func set_mechanism_state(
	next_active: bool,
	next_value: float,
	packet: Dictionary = {},
	force_emit: bool = false
) -> bool:
	var previous_active: bool = active
	var previous_value: float = value
	_apply_mechanism_state(next_active, next_value, packet, force_emit)
	return (
		previous_active != active
		or absf(previous_value - value) > value_change_epsilon
	)


func _apply_mechanism_state(
	next_active: bool,
	next_value: float,
	packet: Dictionary,
	force_emit: bool
) -> void:
	var state_changed: bool = active != next_active
	var sanitized_value: float = _sanitize_value(next_value)
	var value_changed: bool = absf(value - sanitized_value) > value_change_epsilon
	active = next_active
	value = sanitized_value
	last_packet = _decorate_packet(packet)
	if persist_active_state:
		_persist_active_state()
	_on_signal_state_applied(state_changed)
	_on_signal_value_applied(value_changed)
	if state_changed or value_changed or force_emit:
		_emit_signal(force_emit)


func is_mechanism_active() -> bool:
	return active


func get_mechanism_value() -> float:
	return value


func get_mechanism_min_value() -> float:
	return minf(minimum_value, maximum_value)


func get_mechanism_max_value() -> float:
	return maxf(minimum_value, maximum_value)


func get_mechanism_normalized_value() -> float:
	var minimum: float = get_mechanism_min_value()
	var maximum: float = get_mechanism_max_value()
	if is_equal_approx(minimum, maximum):
		return 0.0
	return clampf(inverse_lerp(minimum, maximum, value), 0.0, 1.0)


func get_mechanism_value_unit() -> String:
	return value_unit


func get_mechanism_id() -> String:
	var normalized: String = mechanism_id.to_lower().strip_edges().replace(" ", "_")
	return normalized if normalized != "" else str(name).to_lower()


func get_mechanism_packet() -> Dictionary:
	return _decorate_packet(last_packet)


func get_source_state(source_id: String) -> bool:
	return bool(source_states.get(_normalize_id(source_id), false))


func get_source_value(source_id: String) -> float:
	var normalized_id: String = _normalize_id(source_id)
	var source: Node = source_nodes.get(normalized_id) as Node
	if source != null and is_instance_valid(source):
		if source.has_method("get_mechanism_value"):
			return float(source.call("get_mechanism_value"))
	var packet: Dictionary = get_source_packet(normalized_id)
	if packet.has("value"):
		return float(packet.get("value", 0.0))
	return 1.0 if get_source_state(normalized_id) else 0.0


func get_source_min_value(source_id: String) -> float:
	var normalized_id: String = _normalize_id(source_id)
	var source: Node = source_nodes.get(normalized_id) as Node
	if source != null and is_instance_valid(source):
		if source.has_method("get_mechanism_min_value"):
			return float(source.call("get_mechanism_min_value"))
	return float(get_source_packet(normalized_id).get("minimum_value", 0.0))


func get_source_max_value(source_id: String) -> float:
	var normalized_id: String = _normalize_id(source_id)
	var source: Node = source_nodes.get(normalized_id) as Node
	if source != null and is_instance_valid(source):
		if source.has_method("get_mechanism_max_value"):
			return float(source.call("get_mechanism_max_value"))
	return float(get_source_packet(normalized_id).get("maximum_value", 1.0))


func get_source_normalized_value(source_id: String) -> float:
	var normalized_id: String = _normalize_id(source_id)
	var source: Node = source_nodes.get(normalized_id) as Node
	if source != null and is_instance_valid(source):
		if source.has_method("get_mechanism_normalized_value"):
			return float(source.call("get_mechanism_normalized_value"))
	var packet: Dictionary = get_source_packet(normalized_id)
	if packet.has("normalized_value"):
		return clampf(float(packet.get("normalized_value", 0.0)), 0.0, 1.0)
	var minimum: float = get_source_min_value(normalized_id)
	var maximum: float = get_source_max_value(normalized_id)
	if is_equal_approx(minimum, maximum):
		return 0.0
	return clampf(
		inverse_lerp(minimum, maximum, get_source_value(normalized_id)),
		0.0,
		1.0
	)


func get_source_value_unit(source_id: String) -> String:
	var normalized_id: String = _normalize_id(source_id)
	var source: Node = source_nodes.get(normalized_id) as Node
	if source != null and is_instance_valid(source):
		if source.has_method("get_mechanism_value_unit"):
			return str(source.call("get_mechanism_value_unit"))
	return str(get_source_packet(normalized_id).get("unit", ""))


func get_source_packet(source_id: String) -> Dictionary:
	var normalized_id: String = _normalize_id(source_id)
	var packet_value: Variant = source_packets.get(normalized_id, {})
	if packet_value is Dictionary:
		return (packet_value as Dictionary).duplicate(true)
	return {}


func get_bound_source_ids() -> Array[String]:
	var source_ids: Array[String] = []
	for source_id_value: Variant in source_nodes.keys():
		source_ids.append(str(source_id_value))
	source_ids.sort()
	return source_ids


func get_primary_source_id(preferred_source_id: String = "") -> String:
	var preferred: String = _normalize_id(preferred_source_id)
	if preferred != "" and source_nodes.has(preferred):
		return preferred
	var source_ids: Array[String] = get_bound_source_ids()
	return source_ids[0] if not source_ids.is_empty() else ""


func get_active_source_count() -> int:
	var count: int = 0
	for source_active_value: Variant in source_states.values():
		if bool(source_active_value):
			count += 1
	return count


func get_bound_source_count() -> int:
	return source_nodes.size()


func reset_target() -> void:
	var reset_value: float = (
		(1.0 if initial_active else 0.0)
		if mirror_active_to_value
		else initial_value
	)
	set_mechanism_state(initial_active, reset_value, {
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
	source_packets[source_id] = _decorate_source_packet(source, packet)
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


func _on_signal_value_applied(_changed: bool) -> void:
	pass


func _emit_signal(force_emit: bool = false) -> void:
	var packet: Dictionary = _decorate_packet(last_packet)
	packet["display_name"] = display_name
	packet["force_emit"] = force_emit
	if print_debug:
		print(
			"MECHANISM ",
			get_mechanism_id(),
			" = ",
			active,
			" value=",
			value,
			" ",
			packet
		)
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
	var packet: Dictionary = {}
	if source != null and is_instance_valid(source):
		if source.has_method("get_mechanism_packet"):
			var packet_value: Variant = source.call("get_mechanism_packet")
			if packet_value is Dictionary:
				packet = (packet_value as Dictionary).duplicate(true)
	return _decorate_source_packet(source, packet)


func _decorate_source_packet(source: Node, packet: Dictionary) -> Dictionary:
	var decorated: Dictionary = packet.duplicate(true)
	if source == null or not is_instance_valid(source):
		return decorated
	if source.has_method("get_mechanism_value"):
		decorated["value"] = float(source.call("get_mechanism_value"))
	if source.has_method("get_mechanism_min_value"):
		decorated["minimum_value"] = float(source.call("get_mechanism_min_value"))
	if source.has_method("get_mechanism_max_value"):
		decorated["maximum_value"] = float(source.call("get_mechanism_max_value"))
	if source.has_method("get_mechanism_normalized_value"):
		decorated["normalized_value"] = float(
			source.call("get_mechanism_normalized_value")
		)
	if source.has_method("get_mechanism_value_unit"):
		decorated["unit"] = str(source.call("get_mechanism_value_unit"))
	return decorated


func _decorate_packet(packet: Dictionary) -> Dictionary:
	var decorated: Dictionary = packet.duplicate(true)
	decorated["mechanism_id"] = get_mechanism_id()
	decorated["active"] = active
	decorated["value"] = value
	decorated["minimum_value"] = get_mechanism_min_value()
	decorated["maximum_value"] = get_mechanism_max_value()
	decorated["normalized_value"] = get_mechanism_normalized_value()
	decorated["unit"] = value_unit
	return decorated


func _sanitize_value(next_value: float) -> float:
	if not clamp_value_to_range:
		return next_value
	return clampf(
		next_value,
		get_mechanism_min_value(),
		get_mechanism_max_value()
	)


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


func _normalize_id(id_value: String) -> String:
	return id_value.to_lower().strip_edges().replace(" ", "_")


func get_debug_data() -> Dictionary:
	return {
		"mechanism_id": get_mechanism_id(),
		"display_name": display_name,
		"active": active,
		"value": value,
		"minimum_value": get_mechanism_min_value(),
		"maximum_value": get_mechanism_max_value(),
		"normalized_value": get_mechanism_normalized_value(),
		"unit": value_unit,
		"source_count": source_nodes.size(),
		"active_sources": get_active_source_count(),
		"source_states": source_states.duplicate(true),
		"source_packets": source_packets.duplicate(true),
		"packet": _decorate_packet(last_packet),
		"persistent": persist_active_state,
		"persistence_flag": _resolved_persistence_flag() if persist_active_state else "",
		"initialized": initialized,
	}
