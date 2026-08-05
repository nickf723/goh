extends MechanismSignalNode
class_name MechanismSelectorSource

signal selection_changed(
	selection_index: int,
	selection_label: String,
	packet: Dictionary
)

@export_group("Selection")
@export_range(1, 32, 1) var selection_count: int = 2
@export_range(0, 31, 1) var initial_selection: int = 0
@export var selection_labels: Array[String] = []
@export var wraps_selection: bool = true
@export var advance_on_rising_edge: bool = true

var selection_index: int = 0
var selection_change_count: int = 0
var last_control_source_id: String = ""


func _ready() -> void:
	evaluate_sources_as_or = false
	mirror_active_to_value = false
	selection_count = maxi(selection_count, 1)
	minimum_value = 0.0
	maximum_value = float(selection_count - 1)
	value_unit = "channel"
	initial_active = true
	selection_index = _normalize_selection(initial_selection)
	initial_value = float(selection_index)
	super._ready()
	set_process(false)
	set_selection(selection_index, {"reason": "selector_startup"}, true)


func _on_source_state_changed(
	source_id: String,
	previous_active: bool,
	next_active: bool,
	packet: Dictionary
) -> void:
	if not advance_on_rising_edge:
		return
	if previous_active or not next_active:
		return
	last_control_source_id = source_id
	var advance_packet: Dictionary = packet.duplicate(true)
	advance_packet["reason"] = "selector_advanced"
	advance_packet["control_source_id"] = source_id
	advance_selection(1, advance_packet)


func _evaluate_source_states() -> void:
	# Control sources produce edge commands. Their held Boolean state does not
	# replace or recompute the selector's remembered channel.
	pass


func set_selection(
	next_selection: int,
	packet: Dictionary = {},
	force_emit: bool = false
) -> bool:
	selection_count = maxi(selection_count, 1)
	minimum_value = 0.0
	maximum_value = float(selection_count - 1)
	var normalized_selection: int = _normalize_selection(next_selection)
	var changed: bool = selection_index != normalized_selection
	selection_index = normalized_selection
	if changed:
		selection_change_count += 1

	var selection_packet: Dictionary = packet.duplicate(true)
	selection_packet["reason"] = str(
		selection_packet.get("reason", "selector_set")
	)
	selection_packet["selection_index"] = selection_index
	selection_packet["selection_count"] = selection_count
	selection_packet["selection_label"] = get_selection_label(selection_index)
	selection_packet["selection_changes"] = selection_change_count
	selection_packet["control_source_id"] = last_control_source_id
	set_mechanism_state(
		true,
		float(selection_index),
		selection_packet,
		force_emit or changed
	)
	if changed or force_emit:
		selection_changed.emit(
			selection_index,
			get_selection_label(selection_index),
			get_mechanism_packet()
		)
	return changed


func advance_selection(
	step: int = 1,
	packet: Dictionary = {}
) -> int:
	set_selection(selection_index + step, packet)
	return selection_index


func select_previous(packet: Dictionary = {}) -> int:
	return advance_selection(-1, packet)


func get_selected_index() -> int:
	return selection_index


func get_selection_label(index: int = -1) -> String:
	var resolved_index: int = selection_index if index < 0 else _normalize_selection(index)
	if resolved_index < selection_labels.size():
		var authored_label: String = selection_labels[resolved_index].strip_edges()
		if authored_label != "":
			return authored_label
	return "CHANNEL " + str(resolved_index + 1)


func _normalize_selection(next_selection: int) -> int:
	var count: int = maxi(selection_count, 1)
	if wraps_selection:
		var wrapped: int = next_selection % count
		if wrapped < 0:
			wrapped += count
		return wrapped
	return clampi(next_selection, 0, count - 1)


func reset_target() -> void:
	selection_change_count = 0
	last_control_source_id = ""
	selection_count = maxi(selection_count, 1)
	selection_index = _normalize_selection(initial_selection)
	initial_value = float(selection_index)
	minimum_value = 0.0
	maximum_value = float(selection_count - 1)
	super.reset_target()
	set_selection(selection_index, {"reason": "selector_reset"}, true)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["selector_source"] = true
	data["selection_index"] = selection_index
	data["selection_count"] = selection_count
	data["selection_label"] = get_selection_label(selection_index)
	data["selection_labels"] = selection_labels.duplicate()
	data["selection_changes"] = selection_change_count
	data["wraps_selection"] = wraps_selection
	data["last_control_source_id"] = last_control_source_id
	return data
