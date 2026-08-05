extends "res://scripts/levels/mechanism_network_lab_routing.gd"
class_name MechanismNetworkLabPriorityDecoder

var priority_selectors: Array[MechanismPrioritySelector] = []
var priority_decoders: Array[MechanismDecoderNode] = []
var priority_presented_nodes: Array[MechanismSignalNode] = []
var priority_output_adapters: Array[MechanismOutputAdapter] = []
var priority_labels: Dictionary = {}
var priority_instruction: Label3D


func _ready() -> void:
	super._ready()
	_build_priority_extension_environment()
	_build_emergency_override_station(300.0)
	_build_four_door_decoder_station(324.0)
	_bind_priority_presentation_signals()
	_configure_label_visibility_budget(self)
	GameState.set_objective(
		"Explore the complete puzzle grammar through routing, priority overrides, and decoded addresses. Fire can seize control; Water restores the remembered normal route. F8 resets everything."
	)
	_show_message(
		"Priority and Decoder wing online. Temporary overrides can seize a route without erasing the selection beneath them."
	)
	call_deferred("_refresh_all_presentations")


func _build_priority_extension_environment() -> void:
	_create_static_box(
		"PriorityWingFloor",
		Vector3(0.0, -0.5, 322.0),
		Vector3(24.0, 1.0, 56.0),
		Color(0.16, 0.11, 0.15)
	)
	_create_static_box(
		"PriorityWingLeftWall",
		Vector3(-12.5, 2.0, 322.0),
		Vector3(1.0, 5.0, 56.0),
		Color(0.1, 0.06, 0.1)
	)
	_create_static_box(
		"PriorityWingRightWall",
		Vector3(12.5, 2.0, 322.0),
		Vector3(1.0, 5.0, 56.0),
		Color(0.1, 0.06, 0.1)
	)
	for divider_z: float in [312.0, 336.0]:
		_create_static_box(
			"PriorityDividerLeft" + str(int(divider_z)),
			Vector3(-8.0, 1.5, divider_z),
			Vector3(7.0, 3.0, 0.5),
			Color(0.26, 0.14, 0.22)
		)
		_create_static_box(
			"PriorityDividerRight" + str(int(divider_z)),
			Vector3(8.0, 1.5, divider_z),
			Vector3(7.0, 3.0, 0.5),
			Color(0.26, 0.14, 0.22)
		)

	priority_instruction = _create_station_label(
		"PRIORITY + DECODER WING\nOverrides choose who controls the address • decoders choose exactly one output",
		Vector3(0.0, 5.1, 291.5),
		Color(1.0, 0.54, 0.72)
	)


func _build_emergency_override_station(z: float) -> void:
	_create_station_platform(z, "14 • EMERGENCY OVERRIDE: NORMAL ROUTE ↔ FIRE EXIT")
	var route_lever: MechanismToggleLever = _spawn_lever(
		"EmergencyNormalRouteLever",
		"emergency_normal_route_control",
		"CHANGE NORMAL ROUTE",
		Vector3(-5.4, 0.0, z),
		true,
		0.12
	)
	var normal_selector: MechanismSelectorSource = _create_selector(
		"EmergencyNormalSelector",
		"emergency_normal_selector",
		"NORMAL ROUTE",
		2,
		["LEFT", "RIGHT"],
		[route_lever]
	)
	var fire_sensor: MechanismElementSensor = _spawn_sensor(
		"EmergencyFireSensor",
		"emergency_fire_override",
		"FIRE OVERRIDE • WATER RESET",
		Vector3(5.4, 0.0, z)
	)
	fire_sensor.latch_when_activated = true

	var priority: MechanismPrioritySelector = _create_priority_selector(
		"EmergencyPrioritySelector",
		"emergency_priority_selector",
		"ROUTE AUTHORITY",
		3,
		["LEFT", "RIGHT", "EMERGENCY"],
		normal_selector
	)
	priority.bind_override_source(
		fire_sensor,
		2,
		100,
		"FIRE EMERGENCY"
	)
	var decoder: MechanismDecoderNode = _create_selector_decoder(
		"EmergencyRouteDecoder",
		"emergency_route_decoder",
		"EMERGENCY ROUTE DECODER",
		3,
		["LEFT", "RIGHT", "EMERGENCY"],
		priority
	)
	_create_priority_label(priority, Vector3(-3.1, 3.25, z + 2.1))
	_create_priority_label(decoder, Vector3(3.1, 3.25, z + 2.1))

	var channel_prefixes: Array[String] = ["Left", "Right", "Emergency"]
	var channel_names: Array[String] = ["LEFT ROUTE", "RIGHT ROUTE", "EMERGENCY EXIT"]
	var channel_positions: Array[float] = [-6.0, 0.0, 6.0]
	var station_outputs: Array[Node] = []
	for channel_index: int in range(3):
		var channel_source: MechanismManualSource = decoder.get_channel_output(
			channel_index
		)
		var prefix: String = channel_prefixes[channel_index]
		var display: String = channel_names[channel_index]
		var x_position: float = channel_positions[channel_index]
		var indicator: MechanismIndicator = _spawn_indicator(
			"Emergency" + prefix + "Indicator",
			display,
			Vector3(x_position, 0.0, z + 4.2)
		)
		var gate: MechanismSlidingGate = _spawn_gate(
			"Emergency" + prefix + "Gate",
			display + " GATE",
			Vector3(x_position, 0.0, z + 8.0)
		)
		priority_output_adapters.append(
			_wire_output(
				"Emergency" + prefix + "IndicatorOutput",
				channel_source,
				indicator
			)
		)
		priority_output_adapters.append(
			_wire_output(
				"Emergency" + prefix + "GateOutput",
				channel_source,
				gate
			)
		)
		station_outputs.append(indicator)
		station_outputs.append(gate)

	var instruction: Label3D = _create_station_label(
		"Choose LEFT or RIGHT. Cast Fire to force EMERGENCY; change the hidden normal route; cast Water to resume it.",
		Vector3(0.0, 2.25, z - 3.4),
		Color(1.0, 0.7, 0.82)
	)
	instruction.font_size = 18
	station_states["emergency_priority"] = {
		"normal_selector": normal_selector,
		"priority_selector": priority,
		"decoder": decoder,
		"inputs": [route_lever, fire_sensor],
		"outputs": station_outputs,
	}


func _build_four_door_decoder_station(z: float) -> void:
	_create_station_platform(z, "15 • FOUR-DOOR DECODER: BIT A / BIT B → ONE OUTPUT")
	var bit_a_lever: MechanismToggleLever = _spawn_lever(
		"DecoderBitALever",
		"decoder_bit_a_control",
		"TOGGLE BIT A",
		Vector3(-4.5, 0.0, z),
		true,
		0.12
	)
	var bit_b_lever: MechanismToggleLever = _spawn_lever(
		"DecoderBitBLever",
		"decoder_bit_b_control",
		"TOGGLE BIT B",
		Vector3(4.5, 0.0, z),
		true,
		0.12
	)
	var bit_a: MechanismLogicNode = _create_logic(
		"DecoderBitAMemory",
		"decoder_bit_a_memory",
		"BIT A",
		MechanismLogicNode.Operation.TOGGLE,
		[bit_a_lever]
	)
	var bit_b: MechanismLogicNode = _create_logic(
		"DecoderBitBMemory",
		"decoder_bit_b_memory",
		"BIT B",
		MechanismLogicNode.Operation.TOGGLE,
		[bit_b_lever]
	)
	_create_logic_label(bit_a, Vector3(-3.0, 3.2, z + 1.8))
	_create_logic_label(bit_b, Vector3(3.0, 3.2, z + 1.8))

	var decoder: MechanismDecoderNode = _create_bit_decoder(
		"FourDoorDecoder",
		"four_door_decoder",
		"TWO-BIT ADDRESS DECODER",
		4,
		["AZURE", "GREEN", "AMBER", "VIOLET"],
		[bit_a, bit_b]
	)
	decoder.first_bit_is_most_significant = true
	_create_priority_label(decoder, Vector3(0.0, 4.25, z + 3.1))

	var channel_names: Array[String] = ["Azure", "Green", "Amber", "Violet"]
	var channel_positions: Array[float] = [-7.5, -2.5, 2.5, 7.5]
	var station_outputs: Array[Node] = []
	for channel_index: int in range(4):
		var channel_source: MechanismManualSource = decoder.get_channel_output(
			channel_index
		)
		var prefix: String = channel_names[channel_index]
		var display: String = prefix.to_upper() + " OUTPUT"
		var x_position: float = channel_positions[channel_index]
		var indicator: MechanismIndicator = _spawn_indicator(
			"Decoder" + prefix + "Indicator",
			display,
			Vector3(x_position, 0.0, z + 4.4)
		)
		var gate: MechanismSlidingGate = _spawn_gate(
			"Decoder" + prefix + "Gate",
			display + " GATE",
			Vector3(x_position, 0.0, z + 8.0)
		)
		priority_output_adapters.append(
			_wire_output(
				"Decoder" + prefix + "IndicatorOutput",
				channel_source,
				indicator
			)
		)
		priority_output_adapters.append(
			_wire_output(
				"Decoder" + prefix + "GateOutput",
				channel_source,
				gate
			)
		)
		station_outputs.append(indicator)
		station_outputs.append(gate)

	var instruction: Label3D = _create_station_label(
		"A B = 00 AZURE • 01 GREEN • 10 AMBER • 11 VIOLET. Exactly one address output remains active.",
		Vector3(0.0, 2.25, z - 3.4),
		Color(1.0, 0.7, 0.82)
	)
	instruction.font_size = 18
	station_states["four_door_decoder"] = {
		"bit_a": bit_a,
		"bit_b": bit_b,
		"decoder": decoder,
		"inputs": [bit_a_lever, bit_b_lever],
		"outputs": station_outputs,
	}


func _create_priority_selector(
	node_name: String,
	mechanism_id: String,
	display_name_value: String,
	selection_count_value: int,
	labels: Array[String],
	normal_source: Node
) -> MechanismPrioritySelector:
	var priority := MechanismPrioritySelector.new()
	priority.name = node_name
	priority.mechanism_id = mechanism_id
	priority.display_name = display_name_value
	priority.selection_count = selection_count_value
	priority.selection_labels = labels.duplicate()
	priority.initial_selection = 0
	priority.wraps_selection = false
	network_root.add_child(priority)
	priority.bind_normal_source(normal_source)
	priority_selectors.append(priority)
	priority_presented_nodes.append(priority)
	return priority


func _create_selector_decoder(
	node_name: String,
	mechanism_id: String,
	display_name_value: String,
	channel_count_value: int,
	labels: Array[String],
	selector_source: Node
) -> MechanismDecoderNode:
	var decoder := MechanismDecoderNode.new()
	decoder.name = node_name
	decoder.mechanism_id = mechanism_id
	decoder.display_name = display_name_value
	decoder.address_mode = MechanismDecoderNode.AddressMode.SELECTOR_VALUE
	decoder.channel_count = channel_count_value
	decoder.channel_labels = labels.duplicate()
	decoder.invalid_address_behavior = (
		MechanismDecoderNode.InvalidAddressBehavior.CLEAR_OUTPUTS
	)
	network_root.add_child(decoder)
	decoder.bind_selector(selector_source)
	priority_decoders.append(decoder)
	priority_presented_nodes.append(decoder)
	return decoder


func _create_bit_decoder(
	node_name: String,
	mechanism_id: String,
	display_name_value: String,
	channel_count_value: int,
	labels: Array[String],
	bit_sources: Array
) -> MechanismDecoderNode:
	var decoder := MechanismDecoderNode.new()
	decoder.name = node_name
	decoder.mechanism_id = mechanism_id
	decoder.display_name = display_name_value
	decoder.address_mode = MechanismDecoderNode.AddressMode.BOOLEAN_BITS
	decoder.channel_count = channel_count_value
	decoder.channel_labels = labels.duplicate()
	decoder.first_bit_is_most_significant = true
	decoder.invalid_address_behavior = (
		MechanismDecoderNode.InvalidAddressBehavior.CLEAR_OUTPUTS
	)
	var authored_bit_ids: Array[String] = []
	for source_value: Variant in bit_sources:
		if source_value is MechanismSignalNode:
			authored_bit_ids.append(
				(source_value as MechanismSignalNode).get_mechanism_id()
			)
	decoder.bit_source_ids = authored_bit_ids
	network_root.add_child(decoder)
	for source_value: Variant in bit_sources:
		if source_value is Node:
			decoder.bind_bit(source_value as Node)
	priority_decoders.append(decoder)
	priority_presented_nodes.append(decoder)
	return decoder


func _create_priority_label(
	node: MechanismSignalNode,
	position_value: Vector3
) -> Label3D:
	var label: Label3D = _create_station_label(
		node.display_name,
		position_value,
		Color(1.0, 0.52, 0.72)
	)
	label.font_size = 20
	priority_labels[node.get_instance_id()] = label
	return label


func _bind_priority_presentation_signals() -> void:
	for node: MechanismSignalNode in priority_presented_nodes:
		if node == null or not is_instance_valid(node):
			continue
		var callback := Callable(
			self,
			"_on_priority_signal_changed"
		).bind(node)
		if not node.mechanism_signal_changed.is_connected(callback):
			node.mechanism_signal_changed.connect(callback)


func _on_priority_signal_changed(
	_mechanism_id: String,
	_active: bool,
	_packet: Dictionary,
	node: MechanismSignalNode
) -> void:
	_refresh_priority_presentation(node)
	_refresh_network_readout()


func _refresh_all_presentations() -> void:
	super._refresh_all_presentations()
	for node: MechanismSignalNode in priority_presented_nodes:
		_refresh_priority_presentation(node)
	_refresh_network_readout()


func _refresh_priority_presentation(node: MechanismSignalNode) -> void:
	if node == null or not is_instance_valid(node):
		return
	var label: Label3D = priority_labels.get(
		node.get_instance_id()
	) as Label3D
	if label == null or not is_instance_valid(label):
		return

	var detail: String = ""
	if node is MechanismPrioritySelector:
		var priority := node as MechanismPrioritySelector
		detail = priority.get_selection_label(priority.selection_index)
		if priority.override_active:
			detail += (
				" • OVERRIDE "
				+ priority.winning_label
				+ " P"
				+ str(priority.winning_priority)
			)
		else:
			detail += " • NORMAL REMEMBERED"
	elif node is MechanismDecoderNode:
		var decoder := node as MechanismDecoderNode
		detail = (
			"address "
			+ str(decoder.raw_address)
			+ " • "
			+ decoder.get_channel_label(decoder.selected_channel_index)
			+ " • outputs "
			+ str(decoder.get_active_output_count())
		)
	else:
		detail = "signal"

	var next_text: String = (
		node.display_name
		+ "\n"
		+ detail
		+ " → "
		+ ("ON" if node.active else "OFF")
	)
	var next_color: Color = (
		Color(0.42, 1.0, 0.67)
		if node.active
		else Color(1.0, 0.52, 0.72)
	)
	_apply_cached_label(
		node.get_instance_id(),
		label,
		next_text,
		next_color
	)


func _refresh_network_readout() -> void:
	if debug_readout == null or not is_instance_valid(debug_readout):
		return
	var active_logic: int = 0
	for logic: MechanismLogicNode in logic_nodes:
		if logic != null and is_instance_valid(logic) and logic.active:
			active_logic += 1
	var active_comparators: int = 0
	for comparator: MechanismValueComparator in value_comparators:
		if comparator != null and is_instance_valid(comparator) and comparator.active:
			active_comparators += 1
	var active_routes: int = 0
	for node: MechanismSignalNode in routing_presented_nodes:
		if node != null and is_instance_valid(node) and node.active:
			active_routes += 1
	var active_overrides: int = 0
	for priority: MechanismPrioritySelector in priority_selectors:
		if priority != null and is_instance_valid(priority) and priority.override_active:
			active_overrides += 1
	var active_decoders: int = 0
	for decoder: MechanismDecoderNode in priority_decoders:
		if decoder != null and is_instance_valid(decoder) and decoder.active:
			active_decoders += 1
	var next_text: String = (
		"PUZZLE SIGNAL NETWORK\n"
		+ "Inputs " + str(input_nodes.size() - 1)
		+ "   Logic " + str(active_logic) + "/" + str(logic_nodes.size())
		+ "   Values " + str(active_comparators) + "/" + str(value_comparators.size())
		+ "   Routes " + str(active_routes) + "/" + str(routing_presented_nodes.size())
		+ "   Overrides " + str(active_overrides) + "/" + str(priority_selectors.size())
		+ "   Decoders " + str(active_decoders) + "/" + str(priority_decoders.size())
		+ "\nBoolean • memory • values • routing • priority • decoded addresses • F8 resets lab"
	)
	if readout_text_cache == next_text:
		presentation_skip_count += 1
		return
	readout_text_cache = next_text
	debug_readout.text = next_text
	presentation_write_count += 1


func reset_lab() -> void:
	super.reset_lab()
	for priority: MechanismPrioritySelector in priority_selectors:
		if priority != null and is_instance_valid(priority):
			priority.reset_target()
	for decoder: MechanismDecoderNode in priority_decoders:
		if decoder != null and is_instance_valid(decoder):
			decoder.reset_target()
	for adapter: MechanismOutputAdapter in priority_output_adapters:
		if adapter != null and is_instance_valid(adapter):
			adapter.apply_target_state()
	call_deferred("_refresh_all_presentations")


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var priority_data: Dictionary = {}
	for priority: MechanismPrioritySelector in priority_selectors:
		if priority != null and is_instance_valid(priority):
			priority_data[priority.get_mechanism_id()] = priority.get_debug_data()
	var decoder_data: Dictionary = {}
	for decoder: MechanismDecoderNode in priority_decoders:
		if decoder != null and is_instance_valid(decoder):
			decoder_data[decoder.get_mechanism_id()] = decoder.get_debug_data()
	data["priority_decoder_lab"] = true
	data["priority_selectors"] = priority_data
	data["decoders"] = decoder_data
	data["priority_decoder_station_count"] = 2
	return data
