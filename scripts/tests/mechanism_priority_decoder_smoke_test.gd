extends Node

const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_mechanism_network_lab_v1.tscn"
)

var failures: Array[String] = []
var fixture: Node


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	GameState.reset_run()
	fixture = Node.new()
	fixture.name = "MechanismPriorityDecoderFixture"
	add_child(fixture)
	await _test_priority_override_restoration()
	await _test_selector_decoder_and_invalid_addresses()
	await _test_boolean_bit_decoder()
	await _test_production_priority_decoder_wing()
	if fixture != null and is_instance_valid(fixture):
		fixture.queue_free()
	await get_tree().process_frame
	_finish()


func _test_priority_override_restoration() -> void:
	var normal := MechanismSelectorSource.new()
	normal.name = "PriorityNormalSelector"
	normal.mechanism_id = "priority_normal_selector"
	normal.selection_count = 2
	normal.selection_labels = Array[String](["LEFT", "RIGHT"])
	fixture.add_child(normal)

	var low_override := _make_boolean_source(
		"LowPriorityOverride",
		"low_priority_override"
	)
	var high_override := _make_boolean_source(
		"HighPriorityOverride",
		"high_priority_override"
	)
	var priority := MechanismPrioritySelector.new()
	priority.name = "PrioritySelectorFixture"
	priority.mechanism_id = "priority_selector_fixture"
	priority.selection_count = 3
	priority.selection_labels = Array[String]([
		"LEFT",
		"RIGHT",
		"EMERGENCY",
	])
	fixture.add_child(priority)
	priority.bind_normal_source(normal)
	priority.bind_override_source(
		low_override,
		2,
		10,
		"LOW EMERGENCY"
	)
	priority.bind_override_source(
		high_override,
		1,
		20,
		"HIGH AUTHORITY"
	)
	await _wait_frames(3)

	_expect(priority.selection_index == 0, "priority selector begins on the normal LEFT route")
	_expect(not priority.override_active, "priority selector begins without an override")
	normal.set_selection(1, {"test": "normal_right"})
	_expect(priority.selection_index == 1, "normal selector controls output when no override is active")

	low_override.set_input_active(true, {"test": "low_override_on"})
	_expect(priority.override_active, "active override seizes priority control")
	_expect(priority.selection_index == 2, "low-priority override selects the emergency channel")
	normal.set_selection(0, {"test": "normal_changes_under_override"})
	_expect(priority.selection_index == 2, "override remains authoritative while normal selection changes")
	_expect(priority.normal_selection_index == 0, "priority selector remembers the changed normal route beneath the override")

	high_override.set_input_active(true, {"test": "high_override_on"})
	_expect(priority.selection_index == 1, "highest simultaneous priority wins")
	_expect(priority.winning_source_id == high_override.get_mechanism_id(), "priority packet identifies the winning override source")
	high_override.set_input_active(false, {"test": "high_override_off"})
	_expect(priority.selection_index == 2, "clearing the highest override reveals the lower active override")
	low_override.set_input_active(false, {"test": "low_override_off"})
	_expect(not priority.override_active, "clearing every override restores normal authority")
	_expect(priority.selection_index == 0, "override release restores the newest remembered normal route")

	normal.queue_free()
	low_override.queue_free()
	high_override.queue_free()
	priority.queue_free()
	await get_tree().process_frame


func _test_selector_decoder_and_invalid_addresses() -> void:
	var address_source := MechanismManualSource.new()
	address_source.name = "DecoderAddressSource"
	address_source.mechanism_id = "decoder_address_source"
	address_source.mirror_active_to_value = false
	address_source.initial_active = true
	address_source.initial_value = 0.0
	address_source.minimum_value = 0.0
	address_source.maximum_value = 8.0
	fixture.add_child(address_source)
	address_source.set_mechanism_state(true, 0.0, {"test": "address_zero"}, true)

	var decoder := MechanismDecoderNode.new()
	decoder.name = "SelectorDecoderFixture"
	decoder.mechanism_id = "selector_decoder_fixture"
	decoder.channel_count = 4
	decoder.channel_labels = Array[String]([
		"AZURE",
		"GREEN",
		"AMBER",
		"VIOLET",
	])
	decoder.address_mode = MechanismDecoderNode.AddressMode.SELECTOR_VALUE
	decoder.invalid_address_behavior = (
		MechanismDecoderNode.InvalidAddressBehavior.CLEAR_OUTPUTS
	)
	fixture.add_child(decoder)
	decoder.bind_selector(address_source)
	await _wait_frames(3)

	_expect(decoder.selected_channel_index == 0, "selector decoder begins at address zero")
	_expect(decoder.get_active_output_count() == 1, "valid address activates exactly one decoded output")
	address_source.set_mechanism_state(true, 2.0, {"test": "address_two"})
	_expect(decoder.selected_channel_index == 2, "selector value two selects the third output")
	_expect(decoder.get_channel_output(2).active, "decoded address activates its matching ordinary mechanism source")
	_expect(decoder.get_active_output_count() == 1, "changing address preserves one-hot output behavior")

	address_source.set_mechanism_state(true, 5.0, {"test": "invalid_address"})
	_expect(not decoder.address_valid, "clear-output decoder rejects an out-of-range address")
	_expect(decoder.selected_channel_index == -1, "invalid address exposes no selected channel")
	_expect(decoder.get_active_output_count() == 0, "invalid address clears every decoded output")
	decoder.invalid_address_behavior = MechanismDecoderNode.InvalidAddressBehavior.CLAMP
	address_source.set_mechanism_state(true, 6.0, {"test": "clamped_address"})
	_expect(decoder.selected_channel_index == 3, "clamp behavior maps a high invalid address to the final output")
	_expect(decoder.get_active_output_count() == 1, "clamped address still activates exactly one output")
	decoder.invalid_address_behavior = MechanismDecoderNode.InvalidAddressBehavior.WRAP
	address_source.set_mechanism_state(true, 5.0, {"test": "wrapped_address"})
	_expect(decoder.selected_channel_index == 1, "wrap behavior maps address five onto output one")

	address_source.queue_free()
	decoder.queue_free()
	await get_tree().process_frame


func _test_boolean_bit_decoder() -> void:
	var bit_a := _make_boolean_source("DecoderBitA", "decoder_bit_a")
	var bit_b := _make_boolean_source("DecoderBitB", "decoder_bit_b")
	var decoder := MechanismDecoderNode.new()
	decoder.name = "BitDecoderFixture"
	decoder.mechanism_id = "bit_decoder_fixture"
	decoder.address_mode = MechanismDecoderNode.AddressMode.BOOLEAN_BITS
	decoder.channel_count = 4
	decoder.channel_labels = Array[String]([
		"AZURE",
		"GREEN",
		"AMBER",
		"VIOLET",
	])
	decoder.bit_source_ids = Array[String]([
		bit_a.get_mechanism_id(),
		bit_b.get_mechanism_id(),
	])
	decoder.first_bit_is_most_significant = true
	fixture.add_child(decoder)
	decoder.bind_bit(bit_a)
	decoder.bind_bit(bit_b)
	await _wait_frames(3)

	_expect(decoder.raw_address == 0 and decoder.selected_channel_index == 0, "bit address 00 selects AZURE")
	_expect(decoder.get_active_output_count() == 1, "00 remains a one-hot decoded address")
	bit_b.set_input_active(true, {"test": "address_01"})
	_expect(decoder.raw_address == 1 and decoder.selected_channel_index == 1, "bit address 01 selects GREEN")
	bit_b.set_input_active(false, {"test": "clear_bit_b"})
	bit_a.set_input_active(true, {"test": "address_10"})
	_expect(decoder.raw_address == 2 and decoder.selected_channel_index == 2, "bit address 10 selects AMBER")
	bit_b.set_input_active(true, {"test": "address_11"})
	_expect(decoder.raw_address == 3 and decoder.selected_channel_index == 3, "bit address 11 selects VIOLET")
	_expect(decoder.get_active_output_count() == 1, "every valid two-bit address activates exactly one output")

	bit_a.queue_free()
	bit_b.queue_free()
	decoder.queue_free()
	await get_tree().process_frame


func _test_production_priority_decoder_wing() -> void:
	var lab: Node = LabScene.instantiate()
	_expect(lab != null, "production mechanism laboratory instantiates")
	if lab == null:
		return
	lab.name = "MechanismPriorityDecoderLabFixture"
	add_child(lab)
	await _wait_physics_frames(16)
	await _wait_frames(5)

	_expect(
		lab is MechanismNetworkLabPriorityDecoder,
		"production laboratory installs the priority and decoder runtime"
	)
	var normal_selector: MechanismSelectorSource = lab.get_node_or_null(
		"SignalNetwork/EmergencyNormalSelector"
	) as MechanismSelectorSource
	var fire_sensor: MechanismElementSensor = lab.get_node_or_null(
		"Mechanisms/EmergencyFireSensor"
	) as MechanismElementSensor
	var priority: MechanismPrioritySelector = lab.get_node_or_null(
		"SignalNetwork/EmergencyPrioritySelector"
	) as MechanismPrioritySelector
	var emergency_decoder: MechanismDecoderNode = lab.get_node_or_null(
		"SignalNetwork/EmergencyRouteDecoder"
	) as MechanismDecoderNode
	var left_gate: MechanismSlidingGate = lab.get_node_or_null(
		"Mechanisms/EmergencyLeftGate"
	) as MechanismSlidingGate
	var right_gate: MechanismSlidingGate = lab.get_node_or_null(
		"Mechanisms/EmergencyRightGate"
	) as MechanismSlidingGate
	var emergency_gate: MechanismSlidingGate = lab.get_node_or_null(
		"Mechanisms/EmergencyEmergencyGate"
	) as MechanismSlidingGate
	_expect(
		normal_selector != null
		and fire_sensor != null
		and priority != null
		and emergency_decoder != null
		and left_gate != null
		and right_gate != null
		and emergency_gate != null,
		"production emergency override station is complete"
	)
	if (
		normal_selector != null
		and fire_sensor != null
		and priority != null
		and emergency_decoder != null
		and left_gate != null
		and right_gate != null
		and emergency_gate != null
	):
		_expect(left_gate.active and not right_gate.active and not emergency_gate.active, "normal LEFT route begins authoritative")
		normal_selector.set_selection(1, {"test": "production_normal_right"})
		await _wait_frames(2)
		_expect(not left_gate.active and right_gate.active and not emergency_gate.active, "normal selector moves authority to RIGHT")
		fire_sensor.set_sensor_active(true, {"test": "production_fire_override"})
		await _wait_frames(2)
		_expect(priority.override_active, "production Fire sensor activates priority override")
		_expect(priority.selection_index == 2, "Fire override selects the emergency address")
		_expect(not left_gate.active and not right_gate.active and emergency_gate.active, "emergency override owns the only active gate")
		normal_selector.set_selection(0, {"test": "production_hidden_left"})
		await _wait_frames(2)
		_expect(priority.selection_index == 2 and priority.normal_selection_index == 0, "normal route can change beneath the active emergency override")
		fire_sensor.set_sensor_active(false, {"test": "production_water_reset"})
		await _wait_frames(2)
		_expect(not priority.override_active and priority.selection_index == 0, "clearing emergency restores the remembered LEFT route")
		_expect(left_gate.active and not right_gate.active and not emergency_gate.active, "restored normal route reclaims one-hot gate control")
		_expect(emergency_decoder.get_active_output_count() == 1, "emergency decoder always exposes exactly one valid route")

	var bit_a: MechanismLogicNode = lab.get_node_or_null(
		"SignalNetwork/DecoderBitAMemory"
	) as MechanismLogicNode
	var bit_b: MechanismLogicNode = lab.get_node_or_null(
		"SignalNetwork/DecoderBitBMemory"
	) as MechanismLogicNode
	var door_decoder: MechanismDecoderNode = lab.get_node_or_null(
		"SignalNetwork/FourDoorDecoder"
	) as MechanismDecoderNode
	var azure_gate: MechanismSlidingGate = lab.get_node_or_null(
		"Mechanisms/DecoderAzureGate"
	) as MechanismSlidingGate
	var green_gate: MechanismSlidingGate = lab.get_node_or_null(
		"Mechanisms/DecoderGreenGate"
	) as MechanismSlidingGate
	var amber_gate: MechanismSlidingGate = lab.get_node_or_null(
		"Mechanisms/DecoderAmberGate"
	) as MechanismSlidingGate
	var violet_gate: MechanismSlidingGate = lab.get_node_or_null(
		"Mechanisms/DecoderVioletGate"
	) as MechanismSlidingGate
	_expect(
		bit_a != null
		and bit_b != null
		and door_decoder != null
		and azure_gate != null
		and green_gate != null
		and amber_gate != null
		and violet_gate != null,
		"production four-door decoder station is complete"
	)
	if (
		bit_a != null
		and bit_b != null
		and door_decoder != null
		and azure_gate != null
		and green_gate != null
		and amber_gate != null
		and violet_gate != null
	):
		_expect(azure_gate.active and door_decoder.raw_address == 0, "production address 00 opens AZURE")
		bit_b.set_memory_active(true, "test_address_01")
		await _wait_frames(2)
		_expect(green_gate.active and door_decoder.raw_address == 1, "production address 01 opens GREEN")
		bit_a.set_memory_active(true, "test_address_11")
		await _wait_frames(2)
		_expect(violet_gate.active and door_decoder.raw_address == 3, "production address 11 opens VIOLET")
		bit_b.set_memory_active(false, "test_address_10")
		await _wait_frames(2)
		_expect(amber_gate.active and door_decoder.raw_address == 2, "production address 10 opens AMBER")
		_expect(door_decoder.get_active_output_count() == 1, "production decoder preserves one-hot output behavior")

	lab.call("reset_lab")
	await _wait_physics_frames(4)
	await _wait_frames(4)
	if normal_selector != null and priority != null and fire_sensor != null:
		_expect(normal_selector.selection_index == 0, "lab reset restores the normal LEFT selection")
		_expect(not fire_sensor.is_mechanism_active(), "lab reset clears the emergency sensor")
		_expect(not priority.override_active and priority.selection_index == 0, "lab reset clears priority override state")
	if bit_a != null and bit_b != null and door_decoder != null:
		_expect(not bit_a.memory_active and not bit_b.memory_active, "lab reset clears both decoder memory bits")
		_expect(door_decoder.raw_address == 0 and door_decoder.get_active_output_count() == 1, "lab reset returns the decoder to one-hot address zero")

	var debug_value: Variant = (
		lab.call("get_debug_data")
		if lab.has_method("get_debug_data")
		else {}
	)
	var debug: Dictionary = (
		debug_value as Dictionary
		if debug_value is Dictionary
		else {}
	)
	_expect(bool(debug.get("priority_decoder_lab", false)), "lab debug data advertises priority and decoder support")
	_expect(int(debug.get("priority_decoder_station_count", 0)) == 2, "lab debug data reports both new stations")

	lab.queue_free()
	await get_tree().process_frame


func _make_boolean_source(
	node_name: String,
	mechanism_id: String
) -> MechanismManualSource:
	var source := MechanismManualSource.new()
	source.name = node_name
	source.mechanism_id = mechanism_id
	source.display_name = node_name
	fixture.add_child(source)
	return source


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _wait_physics_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().physics_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("MECHANISM_PRIORITY_DECODER_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("MECHANISM_PRIORITY_DECODER_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("MECHANISM_PRIORITY_DECODER_SMOKE_TEST: " + failure)
	get_tree().quit(1)
