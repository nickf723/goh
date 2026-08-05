extends MechanismSignalNode
class_name MechanismRouterNode

signal route_changed(
	selected_channel: int,
	input_active: bool,
	input_value: float,
	packet: Dictionary
)

@export_group("Routing")
@export_range(1, 16, 1) var channel_count: int = 2
@export var input_source_id: String = ""
@export var selector_source_id: String = ""
@export var channel_labels: Array[String] = []
@export var inactive_channel_value: float = 0.0

var channel_outputs: Array[MechanismManualSource] = []
var selected_channel_index: int = 0
var route_application_count: int = 0
var last_input_source_id: String = ""
var last_selector_source_id: String = ""
var last_route_packet: Dictionary = {}


func _ready() -> void:
	evaluate_sources_as_or = false
	mirror_active_to_value = false
	initial_active = false
	initial_value = inactive_channel_value
	_ensure_channel_outputs()
	super._ready()
	set_process(false)


func bind_input(source: Node) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	input_source_id = _resolve_source_id(source)
	return bind_source(source)


func bind_selector(source: Node) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	selector_source_id = _resolve_source_id(source)
	return bind_source(source)


func configure_channel_count(next_channel_count: int) -> void:
	channel_count = clampi(next_channel_count, 1, 16)
	_ensure_channel_outputs()
	if initialized:
		_evaluate_source_states()


func get_channel_output(channel_index: int) -> MechanismManualSource:
	_ensure_channel_outputs()
	if channel_index < 0 or channel_index >= channel_outputs.size():
		return null
	return channel_outputs[channel_index]


func get_selected_channel_output() -> MechanismManualSource:
	return get_channel_output(selected_channel_index)


func get_channel_label(channel_index: int) -> String:
	if channel_index >= 0 and channel_index < channel_labels.size():
		var authored_label: String = channel_labels[channel_index].strip_edges()
		if authored_label != "":
			return authored_label
	return "CHANNEL " + str(channel_index + 1)


func _ensure_channel_outputs() -> void:
	channel_count = clampi(channel_count, 1, 16)
	while channel_outputs.size() < channel_count:
		var channel_index: int = channel_outputs.size()
		var channel := MechanismManualSource.new()
		channel.name = "Channel" + str(channel_index)
		channel.mechanism_id = (
			get_mechanism_id() + "_channel_" + str(channel_index)
		)
		channel.display_name = (
			display_name + " " + get_channel_label(channel_index)
		)
		channel.mirror_active_to_value = false
		channel.initial_active = false
		channel.initial_value = inactive_channel_value
		channel.minimum_value = minimum_value
		channel.maximum_value = maximum_value
		channel.value_unit = value_unit
		add_child(channel)
		channel_outputs.append(channel)

	while channel_outputs.size() > channel_count:
		var removed: MechanismManualSource = channel_outputs.pop_back()
		if removed != null and is_instance_valid(removed):
			removed.queue_free()


func _evaluate_source_states() -> void:
	_ensure_channel_outputs()
	var selector_id: String = _resolve_selector_source_id()
	var input_id: String = _resolve_input_source_id(selector_id)
	last_selector_source_id = selector_id
	last_input_source_id = input_id

	if selector_id == "" or input_id == "":
		_clear_channels("routing_missing_source")
		set_mechanism_state(false, inactive_channel_value, {
			"reason": "routing_missing_source",
			"input_source_id": input_id,
			"selector_source_id": selector_id,
			"channel_count": channel_count,
		}, true)
		return

	var previous_channel: int = selected_channel_index
	selected_channel_index = clampi(
		roundi(get_source_value(selector_id)),
		0,
		channel_count - 1
	)
	var selection_changed_now: bool = previous_channel != selected_channel_index
	var input_active: bool = get_source_state(input_id)
	var input_value: float = get_source_value(input_id)
	minimum_value = get_source_min_value(input_id)
	maximum_value = get_source_max_value(input_id)
	value_unit = get_source_value_unit(input_id)

	var base_packet: Dictionary = get_source_packet(input_id)
	base_packet["reason"] = "routed_signal"
	base_packet["router_id"] = get_mechanism_id()
	base_packet["input_source_id"] = input_id
	base_packet["selector_source_id"] = selector_id
	base_packet["selected_channel"] = selected_channel_index
	base_packet["selected_channel_label"] = get_channel_label(
		selected_channel_index
	)
	base_packet["channel_count"] = channel_count
	base_packet["input_active"] = input_active
	base_packet["input_value"] = input_value
	base_packet["selection_changed"] = selection_changed_now

	for channel_index: int in range(channel_outputs.size()):
		var channel: MechanismManualSource = channel_outputs[channel_index]
		if channel == null or not is_instance_valid(channel):
			continue
		channel.minimum_value = minimum_value
		channel.maximum_value = maximum_value
		channel.value_unit = value_unit
		var selected: bool = channel_index == selected_channel_index
		var channel_packet: Dictionary = base_packet.duplicate(true)
		channel_packet["route_channel"] = channel_index
		channel_packet["route_channel_label"] = get_channel_label(channel_index)
		channel_packet["route_selected"] = selected
		channel.set_mechanism_state(
			input_active and selected,
			input_value if selected else inactive_channel_value,
			channel_packet,
			selection_changed_now
		)

	route_application_count += 1
	base_packet["route_applications"] = route_application_count
	last_route_packet = base_packet.duplicate(true)
	set_mechanism_state(
		input_active,
		input_value,
		base_packet,
		selection_changed_now
	)
	if selection_changed_now:
		route_changed.emit(
			selected_channel_index,
			input_active,
			input_value,
			get_mechanism_packet()
		)


func _clear_channels(reason: String) -> void:
	for channel_index: int in range(channel_outputs.size()):
		var channel: MechanismManualSource = channel_outputs[channel_index]
		if channel == null or not is_instance_valid(channel):
			continue
		channel.set_mechanism_state(false, inactive_channel_value, {
			"reason": reason,
			"router_id": get_mechanism_id(),
			"route_channel": channel_index,
			"route_selected": false,
		}, true)


func _resolve_selector_source_id() -> String:
	var configured: String = _normalize_id(selector_source_id)
	if configured != "" and source_nodes.has(configured):
		return configured
	for source_id: String in get_bound_source_ids():
		var source: Node = source_nodes.get(source_id) as Node
		if source is MechanismSelectorSource:
			return source_id
	return ""


func _resolve_input_source_id(selector_id: String) -> String:
	var configured: String = _normalize_id(input_source_id)
	if configured != "" and configured != selector_id and source_nodes.has(configured):
		return configured
	for source_id: String in get_bound_source_ids():
		if source_id != selector_id:
			return source_id
	return ""


func reset_target() -> void:
	selected_channel_index = 0
	route_application_count = 0
	last_route_packet.clear()
	super.reset_target()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var channel_data: Dictionary = {}
	for channel_index: int in range(channel_outputs.size()):
		var channel: MechanismManualSource = channel_outputs[channel_index]
		if channel != null and is_instance_valid(channel):
			channel_data[str(channel_index)] = channel.get_debug_data()
	data["router_node"] = true
	data["channel_count"] = channel_count
	data["selected_channel"] = selected_channel_index
	data["selected_channel_label"] = get_channel_label(selected_channel_index)
	data["input_source_id"] = last_input_source_id
	data["selector_source_id"] = last_selector_source_id
	data["route_applications"] = route_application_count
	data["channels"] = channel_data
	data["route_packet"] = last_route_packet.duplicate(true)
	return data
