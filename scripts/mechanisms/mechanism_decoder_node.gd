extends MechanismSignalNode
class_name MechanismDecoderNode

enum AddressMode {
	SELECTOR_VALUE,
	BOOLEAN_BITS,
}

enum InvalidAddressBehavior {
	CLEAR_OUTPUTS,
	CLAMP,
	WRAP,
}

signal decoded_output_changed(
	selected_channel: int,
	selected_label: String,
	raw_address: int,
	packet: Dictionary
)

@export_group("Address")
@export var address_mode: AddressMode = AddressMode.SELECTOR_VALUE
@export var selector_source_id: String = ""
@export var bit_source_ids: Array[String] = []
@export var first_bit_is_most_significant: bool = true
@export var invalid_address_behavior: InvalidAddressBehavior = (
	InvalidAddressBehavior.CLEAR_OUTPUTS
)

@export_group("Outputs")
@export_range(1, 16, 1) var channel_count: int = 4
@export var channel_labels: Array[String] = []

var channel_outputs: Array[MechanismManualSource] = []
var selected_channel_index: int = -1
var raw_address: int = 0
var address_valid: bool = false
var decode_application_count: int = 0
var invalid_address_count: int = 0
var selection_change_count: int = 0
var last_selector_source_id: String = ""
var last_bit_source_ids: Array[String] = []
var last_decode_packet: Dictionary = {}


func _ready() -> void:
	evaluate_sources_as_or = false
	mirror_active_to_value = false
	channel_count = clampi(channel_count, 1, 16)
	minimum_value = 0.0
	maximum_value = float(channel_count - 1)
	value_unit = "address"
	initial_active = false
	initial_value = 0.0
	_ensure_channel_outputs()
	super._ready()
	set_process(false)


func bind_selector(source: Node) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	address_mode = AddressMode.SELECTOR_VALUE
	selector_source_id = _resolve_source_id(source)
	return bind_source(source)


func bind_bit(source: Node) -> bool:
	if source == null or not is_instance_valid(source):
		return false
	address_mode = AddressMode.BOOLEAN_BITS
	var source_id: String = _resolve_source_id(source)
	if source_id == "":
		return false
	if not bit_source_ids.has(source_id):
		bit_source_ids.append(source_id)
	return bind_source(source)


func configure_channel_count(next_channel_count: int) -> void:
	channel_count = clampi(next_channel_count, 1, 16)
	minimum_value = 0.0
	maximum_value = float(channel_count - 1)
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


func get_channel_label(channel_index: int = -1) -> String:
	var resolved_index: int = (
		selected_channel_index
		if channel_index < 0
		else channel_index
	)
	if resolved_index < 0:
		return "NO OUTPUT"
	if resolved_index < channel_labels.size():
		var authored_label: String = channel_labels[resolved_index].strip_edges()
		if authored_label != "":
			return authored_label
	return "OUTPUT " + str(resolved_index + 1)


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
		channel.initial_active = false
		channel.initial_value = 0.0
		channel.minimum_value = 0.0
		channel.maximum_value = 1.0
		channel.value_unit = "decoded"
		add_child(channel)
		channel_outputs.append(channel)

	while channel_outputs.size() > channel_count:
		var removed: MechanismManualSource = channel_outputs.pop_back()
		if removed != null and is_instance_valid(removed):
			removed.queue_free()


func _on_source_state_changed(
	_source_id: String,
	_previous_active: bool,
	_next_active: bool,
	_packet: Dictionary
) -> void:
	_evaluate_source_states()


func _evaluate_source_states() -> void:
	_ensure_channel_outputs()
	minimum_value = 0.0
	maximum_value = float(channel_count - 1)
	var address_result: Dictionary = _resolve_raw_address()
	var has_address_sources: bool = bool(address_result.get("resolved", false))
	raw_address = int(address_result.get("address", 0))
	last_selector_source_id = str(address_result.get("selector_source_id", ""))
	last_bit_source_ids.clear()
	var bits_value: Variant = address_result.get("bit_source_ids", [])
	if bits_value is Array:
		for bit_value: Variant in bits_value:
			last_bit_source_ids.append(str(bit_value))

	var next_channel: int = -1
	var next_valid: bool = false
	if has_address_sources:
		next_channel = _resolve_output_channel(raw_address)
		next_valid = next_channel >= 0
	if has_address_sources and not next_valid:
		invalid_address_count += 1

	var selection_changed_now: bool = (
		selected_channel_index != next_channel
		or address_valid != next_valid
	)
	if selection_changed_now:
		selection_change_count += 1
	selected_channel_index = next_channel
	address_valid = next_valid
	decode_application_count += 1

	var decode_packet: Dictionary = {
		"reason": "decoded_address",
		"decoder_id": get_mechanism_id(),
		"address_mode": get_address_mode_name(),
		"raw_address": raw_address,
		"address_valid": address_valid,
		"selected_channel": selected_channel_index,
		"selected_channel_label": get_channel_label(selected_channel_index),
		"channel_count": channel_count,
		"selector_source_id": last_selector_source_id,
		"bit_source_ids": last_bit_source_ids.duplicate(),
		"first_bit_is_most_significant": first_bit_is_most_significant,
		"invalid_address_behavior": get_invalid_address_behavior_name(),
		"selection_changed": selection_changed_now,
		"decode_applications": decode_application_count,
		"invalid_addresses": invalid_address_count,
	}

	for channel_index: int in range(channel_outputs.size()):
		var channel: MechanismManualSource = channel_outputs[channel_index]
		if channel == null or not is_instance_valid(channel):
			continue
		var selected: bool = address_valid and channel_index == selected_channel_index
		var channel_packet: Dictionary = decode_packet.duplicate(true)
		channel_packet["decoded_channel"] = channel_index
		channel_packet["decoded_channel_label"] = get_channel_label(channel_index)
		channel_packet["decoded_selected"] = selected
		channel.set_mechanism_active(
			selected,
			channel_packet,
			selection_changed_now
		)

	last_decode_packet = decode_packet.duplicate(true)
	set_mechanism_state(
		address_valid,
		float(raw_address),
		decode_packet,
		selection_changed_now
	)
	if selection_changed_now:
		decoded_output_changed.emit(
			selected_channel_index,
			get_channel_label(selected_channel_index),
			raw_address,
			get_mechanism_packet()
		)


func _resolve_raw_address() -> Dictionary:
	if address_mode == AddressMode.SELECTOR_VALUE:
		var selector_id: String = _resolve_selector_source_id()
		if selector_id == "":
			return {
				"resolved": false,
				"address": 0,
				"selector_source_id": "",
				"bit_source_ids": [],
			}
		return {
			"resolved": true,
			"address": roundi(get_source_value(selector_id)),
			"selector_source_id": selector_id,
			"bit_source_ids": [],
		}

	var bit_ids: Array[String] = _resolve_bit_source_ids()
	if bit_ids.is_empty():
		return {
			"resolved": false,
			"address": 0,
			"selector_source_id": "",
			"bit_source_ids": bit_ids,
		}
	var address: int = 0
	if first_bit_is_most_significant:
		for bit_id: String in bit_ids:
			address = address << 1
			if get_source_state(bit_id):
				address = address | 1
	else:
		for bit_index: int in range(bit_ids.size()):
			if get_source_state(bit_ids[bit_index]):
				address = address | (1 << bit_index)
	return {
		"resolved": true,
		"address": address,
		"selector_source_id": "",
		"bit_source_ids": bit_ids,
	}


func _resolve_selector_source_id() -> String:
	var configured: String = _normalize_id(selector_source_id)
	if configured != "" and source_nodes.has(configured):
		return configured
	for source_id: String in get_bound_source_ids():
		var source: Node = source_nodes.get(source_id) as Node
		if source is MechanismSelectorSource or source is MechanismPrioritySelector:
			return source_id
	return ""


func _resolve_bit_source_ids() -> Array[String]:
	var resolved: Array[String] = []
	for configured_id: String in bit_source_ids:
		var normalized: String = _normalize_id(configured_id)
		if (
			normalized != ""
			and source_nodes.has(normalized)
			and not resolved.has(normalized)
		):
			resolved.append(normalized)
	if not resolved.is_empty():
		return resolved
	for source_id: String in get_bound_source_ids():
		resolved.append(source_id)
	return resolved


func _resolve_output_channel(address: int) -> int:
	if address >= 0 and address < channel_count:
		return address
	match invalid_address_behavior:
		InvalidAddressBehavior.CLAMP:
			return clampi(address, 0, channel_count - 1)
		InvalidAddressBehavior.WRAP:
			var wrapped: int = address % channel_count
			if wrapped < 0:
				wrapped += channel_count
			return wrapped
		_:
			return -1


func get_address_mode_name() -> String:
	return AddressMode.keys()[address_mode].to_lower()


func get_invalid_address_behavior_name() -> String:
	return InvalidAddressBehavior.keys()[invalid_address_behavior].to_lower()


func get_active_output_count() -> int:
	var active_count: int = 0
	for channel: MechanismManualSource in channel_outputs:
		if channel != null and is_instance_valid(channel) and channel.active:
			active_count += 1
	return active_count


func reset_target() -> void:
	selected_channel_index = -1
	raw_address = 0
	address_valid = false
	decode_application_count = 0
	invalid_address_count = 0
	selection_change_count = 0
	last_selector_source_id = ""
	last_bit_source_ids.clear()
	last_decode_packet.clear()
	super.reset_target()


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var channel_data: Dictionary = {}
	for channel_index: int in range(channel_outputs.size()):
		var channel: MechanismManualSource = channel_outputs[channel_index]
		if channel != null and is_instance_valid(channel):
			channel_data[str(channel_index)] = channel.get_debug_data()
	data["decoder_node"] = true
	data["address_mode"] = get_address_mode_name()
	data["raw_address"] = raw_address
	data["address_valid"] = address_valid
	data["selected_channel"] = selected_channel_index
	data["selected_channel_label"] = get_channel_label(selected_channel_index)
	data["channel_count"] = channel_count
	data["selector_source_id"] = last_selector_source_id
	data["bit_source_ids"] = last_bit_source_ids.duplicate()
	data["first_bit_is_most_significant"] = first_bit_is_most_significant
	data["invalid_address_behavior"] = get_invalid_address_behavior_name()
	data["active_outputs"] = get_active_output_count()
	data["decode_applications"] = decode_application_count
	data["invalid_addresses"] = invalid_address_count
	data["selection_changes"] = selection_change_count
	data["channels"] = channel_data
	data["decode_packet"] = last_decode_packet.duplicate(true)
	return data
