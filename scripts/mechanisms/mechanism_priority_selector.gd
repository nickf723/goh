extends MechanismSignalNode
class_name MechanismPrioritySelector

signal priority_selection_changed(
	selection_index: int,
	selection_label: String,
	winning_source_id: String,
	winning_priority: int,
	override_active: bool,
	packet: Dictionary
)

@export_group("Selection")
@export_range(1, 32, 1) var selection_count: int = 3
@export_range(0, 31, 1) var initial_selection: int = 0
@export var selection_labels: Array[String] = []
@export var wraps_selection: bool = false

@export_group("Normal Source")
@export var normal_source_id: String = ""
@export var require_normal_source_active: bool = false
@export var normal_priority: int = 0

@export_group("Override Sources")
@export var override_source_ids: Array[String] = []
@export var override_priorities: Array[int] = []
@export var override_selection_values: Array[int] = []
@export var override_labels: Array[String] = []

var selection_index: int = 0
var normal_selection_index: int = 0
var winning_source_id: String = ""
var winning_priority: int = 0
var winning_label: String = ""
var override_active: bool = false
var selection_change_count: int = 0
var winner_change_count: int = 0
var override_activation_count: int = 0
var evaluation_count: int = 0


func _ready() -> void:
	evaluate_sources_as_or = false
	mirror_active_to_value = false
	selection_count = maxi(selection_count, 1)
	selection_index = _normalize_selection(initial_selection)
	normal_selection_index = selection_index
	minimum_value = 0.0
	maximum_value = float(selection_count - 1)
	value_unit = "channel"
	initial_active = false
	initial_value = float(selection_index)
	super._ready()
	set_process(false)


func bind_normal_source(source: Node) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	normal_source_id = _resolve_source_id(source)
	return bind_source(source)


func bind_override_source(
	source: Node,
	selection_value: int,
	priority: int,
	label: String = ""
) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	var source_id: String = _resolve_source_id(source)
	if source_id == "":
		return false
	var override_index: int = override_source_ids.find(source_id)
	if override_index < 0:
		override_source_ids.append(source_id)
		override_priorities.append(priority)
		override_selection_values.append(selection_value)
		override_labels.append(label)
	else:
		_ensure_override_array_sizes()
		override_priorities[override_index] = priority
		override_selection_values[override_index] = selection_value
		override_labels[override_index] = label
	return bind_source(source)


func _on_source_state_changed(
	_source_id: String,
	_previous_active: bool,
	_next_active: bool,
	_packet: Dictionary
) -> void:
	_evaluate_source_states()


func _evaluate_source_states() -> void:
	selection_count = maxi(selection_count, 1)
	minimum_value = 0.0
	maximum_value = float(selection_count - 1)
	_ensure_override_array_sizes()
	evaluation_count += 1

	var normal_id: String = _resolve_normal_source_id()
	var normal_available: bool = normal_id != ""
	if normal_available:
		normal_selection_index = _normalize_selection(
			roundi(get_source_value(normal_id))
		)
	else:
		normal_selection_index = _normalize_selection(initial_selection)

	var next_selection: int = normal_selection_index
	var next_winner_id: String = normal_id
	var next_winner_priority: int = normal_priority
	var next_winner_label: String = (
		get_selection_label(normal_selection_index)
		if normal_available
		else "NO NORMAL SOURCE"
	)
	var next_override_active: bool = false
	var best_override_index: int = -1
	var best_override_priority: int = -2147483648

	for override_index: int in range(override_source_ids.size()):
		var source_id: String = _normalize_id(override_source_ids[override_index])
		if source_id == "" or not source_nodes.has(source_id):
			continue
		if not get_source_state(source_id):
			continue
		var priority: int = override_priorities[override_index]
		if best_override_index < 0 or priority > best_override_priority:
			best_override_index = override_index
			best_override_priority = priority

	if best_override_index >= 0:
		next_override_active = true
		next_selection = _normalize_selection(
			override_selection_values[best_override_index]
		)
		next_winner_id = _normalize_id(
			override_source_ids[best_override_index]
		)
		next_winner_priority = override_priorities[best_override_index]
		next_winner_label = override_labels[best_override_index].strip_edges()
		if next_winner_label == "":
			next_winner_label = get_selection_label(next_selection)

	var next_active: bool = next_override_active
	if normal_available:
		next_active = (
			next_active
			or not require_normal_source_active
			or get_source_state(normal_id)
		)

	var selection_changed_now: bool = selection_index != next_selection
	var winner_changed_now: bool = (
		winning_source_id != next_winner_id
		or winning_priority != next_winner_priority
		or winning_label != next_winner_label
	)
	var override_changed_now: bool = override_active != next_override_active
	if selection_changed_now:
		selection_change_count += 1
	if winner_changed_now:
		winner_change_count += 1
	if next_override_active and not override_active:
		override_activation_count += 1

	selection_index = next_selection
	winning_source_id = next_winner_id
	winning_priority = next_winner_priority
	winning_label = next_winner_label
	override_active = next_override_active

	var priority_packet: Dictionary = {
		"reason": "priority_selection",
		"selection_index": selection_index,
		"selection_count": selection_count,
		"selection_label": get_selection_label(selection_index),
		"normal_source_id": normal_id,
		"normal_selection_index": normal_selection_index,
		"normal_selection_label": get_selection_label(normal_selection_index),
		"winning_source_id": winning_source_id,
		"winning_priority": winning_priority,
		"winning_label": winning_label,
		"override_active": override_active,
		"selection_changed": selection_changed_now,
		"winner_changed": winner_changed_now,
		"override_changed": override_changed_now,
		"selection_changes": selection_change_count,
		"winner_changes": winner_change_count,
		"override_activations": override_activation_count,
		"evaluations": evaluation_count,
	}
	set_mechanism_state(
		next_active,
		float(selection_index),
		priority_packet,
		selection_changed_now or winner_changed_now or override_changed_now
	)
	if selection_changed_now or winner_changed_now or override_changed_now:
		priority_selection_changed.emit(
			selection_index,
			get_selection_label(selection_index),
			winning_source_id,
			winning_priority,
			override_active,
			get_mechanism_packet()
		)


func _resolve_normal_source_id() -> String:
	var configured: String = _normalize_id(normal_source_id)
	if configured != "" and source_nodes.has(configured):
		return configured
	for source_id: String in get_bound_source_ids():
		var source: Node = source_nodes.get(source_id) as Node
		if source is MechanismSelectorSource:
			return source_id
	for source_id: String in get_bound_source_ids():
		if not _normalized_override_source_ids().has(source_id):
			return source_id
	return ""


func _normalized_override_source_ids() -> Array[String]:
	var normalized: Array[String] = []
	for source_id: String in override_source_ids:
		var clean_id: String = _normalize_id(source_id)
		if clean_id != "" and not normalized.has(clean_id):
			normalized.append(clean_id)
	return normalized


func _ensure_override_array_sizes() -> void:
	while override_priorities.size() < override_source_ids.size():
		override_priorities.append(1)
	while override_selection_values.size() < override_source_ids.size():
		override_selection_values.append(0)
	while override_labels.size() < override_source_ids.size():
		override_labels.append("")
	while override_priorities.size() > override_source_ids.size():
		override_priorities.pop_back()
	while override_selection_values.size() > override_source_ids.size():
		override_selection_values.pop_back()
	while override_labels.size() > override_source_ids.size():
		override_labels.pop_back()


func get_selection_label(index: int = -1) -> String:
	var resolved_index: int = (
		selection_index
		if index < 0
		else _normalize_selection(index)
	)
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
	winner_change_count = 0
	override_activation_count = 0
	evaluation_count = 0
	selection_index = _normalize_selection(initial_selection)
	normal_selection_index = selection_index
	winning_source_id = ""
	winning_priority = normal_priority
	winning_label = ""
	override_active = false
	selection_count = maxi(selection_count, 1)
	minimum_value = 0.0
	maximum_value = float(selection_count - 1)
	initial_value = float(selection_index)
	super.reset_target()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["priority_selector"] = true
	data["selection_index"] = selection_index
	data["selection_count"] = selection_count
	data["selection_label"] = get_selection_label(selection_index)
	data["normal_selection_index"] = normal_selection_index
	data["normal_selection_label"] = get_selection_label(normal_selection_index)
	data["normal_source_id"] = _resolve_normal_source_id()
	data["winning_source_id"] = winning_source_id
	data["winning_priority"] = winning_priority
	data["winning_label"] = winning_label
	data["override_active"] = override_active
	data["override_source_ids"] = _normalized_override_source_ids()
	data["override_priorities"] = override_priorities.duplicate()
	data["override_selection_values"] = override_selection_values.duplicate()
	data["selection_changes"] = selection_change_count
	data["winner_changes"] = winner_change_count
	data["override_activations"] = override_activation_count
	data["evaluations"] = evaluation_count
	return data
