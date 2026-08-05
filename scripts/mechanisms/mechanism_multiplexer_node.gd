extends MechanismSignalNode
class_name MechanismMultiplexerNode

signal selected_input_changed(
	selected_index: int,
	selected_source_id: String,
	packet: Dictionary
)

@export_group("Selection")
@export var selector_source_id: String = ""
@export var input_source_ids: Array[String] = []
@export var wraps_selection: bool = false

var selected_input_index: int = 0
var selected_input_source_id: String = ""
var selection_application_count: int = 0
var last_selector_source_id: String = ""
var last_selection_packet: Dictionary = {}


func _ready() -> void:
	evaluate_sources_as_or = false
	mirror_active_to_value = false
	initial_active = false
	initial_value = 0.0
	super._ready()
	set_process(false)


func bind_selector(source: Node) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	selector_source_id = _resolve_source_id(source)
	return bind_source(source)


func bind_input(source: Node) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	var source_id: String = _resolve_source_id(source)
	if source_id == "":
		return false
	if not input_source_ids.has(source_id):
		input_source_ids.append(source_id)
	return bind_source(source)


func get_selected_input_node() -> Node:
	if selected_input_source_id == "":
		return null
	return source_nodes.get(selected_input_source_id) as Node


func _evaluate_source_states() -> void:
	var selector_id: String = _resolve_selector_source_id()
	var inputs: Array[String] = _resolve_input_source_ids(selector_id)
	last_selector_source_id = selector_id

	if selector_id == "" or inputs.is_empty():
		selected_input_index = 0
		selected_input_source_id = ""
		last_selection_packet = {
			"reason": "multiplexer_missing_source",
			"selector_source_id": selector_id,
			"input_source_ids": inputs,
		}
		set_mechanism_state(false, 0.0, last_selection_packet, true)
		return

	var requested_index: int = roundi(get_source_value(selector_id))
	var next_index: int = _normalize_selection(requested_index, inputs.size())
	var next_source_id: String = inputs[next_index]
	var selection_changed_now: bool = (
		selected_input_index != next_index
		or selected_input_source_id != next_source_id
	)
	selected_input_index = next_index
	selected_input_source_id = next_source_id

	var selected_active: bool = get_source_state(next_source_id)
	var selected_value: float = get_source_value(next_source_id)
	minimum_value = get_source_min_value(next_source_id)
	maximum_value = get_source_max_value(next_source_id)
	value_unit = get_source_value_unit(next_source_id)
	selection_application_count += 1

	var selection_packet: Dictionary = get_source_packet(next_source_id)
	selection_packet["reason"] = "multiplexer_selected_input"
	selection_packet["multiplexer_id"] = get_mechanism_id()
	selection_packet["selector_source_id"] = selector_id
	selection_packet["requested_index"] = requested_index
	selection_packet["selected_index"] = selected_input_index
	selection_packet["selected_source_id"] = selected_input_source_id
	selection_packet["input_source_ids"] = inputs.duplicate()
	selection_packet["selection_changed"] = selection_changed_now
	selection_packet["selection_applications"] = selection_application_count
	selection_packet["selected_active"] = selected_active
	selection_packet["selected_value"] = selected_value
	last_selection_packet = selection_packet.duplicate(true)

	set_mechanism_state(
		selected_active,
		selected_value,
		selection_packet,
		selection_changed_now
	)
	if selection_changed_now:
		selected_input_changed.emit(
			selected_input_index,
			selected_input_source_id,
			get_mechanism_packet()
		)


func _resolve_selector_source_id() -> String:
	var configured: String = _normalize_id(selector_source_id)
	if configured != "" and source_nodes.has(configured):
		return configured
	for source_id: String in get_bound_source_ids():
		var source: Node = source_nodes.get(source_id) as Node
		if source is MechanismSelectorSource:
			return source_id
	return ""


func _resolve_input_source_ids(selector_id: String) -> Array[String]:
	var resolved: Array[String] = []
	for configured_id: String in input_source_ids:
		var normalized: String = _normalize_id(configured_id)
		if (
			normalized != ""
			and normalized != selector_id
			and source_nodes.has(normalized)
			and not resolved.has(normalized)
		):
			resolved.append(normalized)
	if not resolved.is_empty():
		return resolved
	for source_id: String in get_bound_source_ids():
		if source_id != selector_id:
			resolved.append(source_id)
	return resolved


func _normalize_selection(requested_index: int, input_count: int) -> int:
	var count: int = maxi(input_count, 1)
	if wraps_selection:
		var wrapped: int = requested_index % count
		if wrapped < 0:
			wrapped += count
		return wrapped
	return clampi(requested_index, 0, count - 1)


func reset_target() -> void:
	selected_input_index = 0
	selected_input_source_id = ""
	selection_application_count = 0
	last_selection_packet.clear()
	super.reset_target()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["multiplexer_node"] = true
	data["selector_source_id"] = last_selector_source_id
	data["input_source_ids"] = _resolve_input_source_ids(
		last_selector_source_id
	)
	data["selected_index"] = selected_input_index
	data["selected_source_id"] = selected_input_source_id
	data["selection_applications"] = selection_application_count
	data["selection_packet"] = last_selection_packet.duplicate(true)
	return data
