extends "res://scripts/levels/mechanism_network_lab.gd"
class_name MechanismNetworkLabComplete


func _ready() -> void:
	super._ready()
	_build_xor_extension()
	_build_memory_extension_environment()
	_build_toggle_memory_station(115.0)
	_build_set_reset_memory_station(138.0)
	_build_sequence_memory_station(161.0)
	GameState.set_objective(
		"Explore the full mechanism grammar: signals, gates, timing, counters, toggle memory, set/reset memory, and ordered sequences. F8 resets everything."
	)
	_show_message(
		"Mechanism memory wing online. Pulses can now toggle state, set or reset state, and unlock ordered-input puzzles."
	)
	call_deferred("_refresh_all_presentations")


func _build_xor_extension() -> void:
	var lever: Node = get_node_or_null("Mechanisms/OrLever")
	var sensor: Node = get_node_or_null("Mechanisms/OrFireSensor")
	if lever == null or sensor == null:
		return
	var xor_logic: MechanismLogicNode = _create_logic(
		"LeverXorFire",
		"lever_xor_fire",
		"LEVER XOR FIRE",
		MechanismLogicNode.Operation.XOR,
		[lever, sensor]
	)
	_create_logic_label(xor_logic, Vector3(0.0, 3.2, 47.2))
	var indicator: MechanismIndicator = _spawn_indicator(
		"XorIndicator",
		"XOR OUTPUT",
		Vector3(0.0, 0.0, 47.0)
	)
	_wire_output("XorIndicatorOutput", xor_logic, indicator)
	station_states["xor"] = {
		"logic": xor_logic,
		"inputs": [lever, sensor],
		"outputs": [indicator],
	}


func _build_memory_extension_environment() -> void:
	_create_static_box(
		"MemoryWingFloor",
		Vector3(0.0, -0.5, 141.0),
		Vector3(24.0, 1.0, 74.0),
		Color(0.11, 0.14, 0.2)
	)
	_create_static_box(
		"MemoryWingLeftWall",
		Vector3(-12.5, 2.0, 141.0),
		Vector3(1.0, 5.0, 74.0),
		Color(0.07, 0.09, 0.14)
	)
	_create_static_box(
		"MemoryWingRightWall",
		Vector3(12.5, 2.0, 141.0),
		Vector3(1.0, 5.0, 74.0),
		Color(0.07, 0.09, 0.14)
	)
	for divider_z: float in [126.0, 149.0, 172.0]:
		_create_static_box(
			"MemoryDividerLeft" + str(int(divider_z)),
			Vector3(-8.0, 1.5, divider_z),
			Vector3(7.0, 3.0, 0.5),
			Color(0.16, 0.18, 0.25)
		)
		_create_static_box(
			"MemoryDividerRight" + str(int(divider_z)),
			Vector3(8.0, 1.5, divider_z),
			Vector3(7.0, 3.0, 0.5),
			Color(0.16, 0.18, 0.25)
		)
	_create_station_label(
		"MEMORY WING\nSignals can remember more than ON and OFF",
		Vector3(0.0, 5.1, 107.0),
		Color(0.72, 0.65, 1.0)
	)


func _build_toggle_memory_station(z: float) -> void:
	_create_station_platform(z, "06 • TOGGLE MEMORY")
	var pulse_lever: MechanismToggleLever = _spawn_lever(
		"ToggleMemoryLever",
		"toggle_memory_input",
		"PULSE TO TOGGLE",
		Vector3(-4.2, 0.0, z),
		true,
		0.12
	)
	var toggle_memory: MechanismLogicNode = _create_logic(
		"ToggleMemory",
		"toggle_memory",
		"TOGGLE MEMORY",
		MechanismLogicNode.Operation.TOGGLE,
		[pulse_lever]
	)
	_create_logic_label(toggle_memory, Vector3(0.0, 3.2, z + 2.0))
	var indicator: MechanismIndicator = _spawn_indicator(
		"ToggleMemoryIndicator",
		"REMEMBERED STATE",
		Vector3(3.8, 0.0, z)
	)
	var gate: MechanismSlidingGate = _spawn_gate(
		"ToggleMemoryGate",
		"TOGGLE MEMORY GATE",
		Vector3(0.0, 0.0, z + 8.0)
	)
	_wire_output("ToggleMemoryIndicatorOutput", toggle_memory, indicator)
	_wire_output("ToggleMemoryGateOutput", toggle_memory, gate)
	station_states["toggle_memory"] = {
		"logic": toggle_memory,
		"inputs": [pulse_lever],
		"outputs": [indicator, gate],
	}


func _build_set_reset_memory_station(z: float) -> void:
	_create_station_platform(z, "07 • SET / RESET MEMORY")
	var set_lever: MechanismToggleLever = _spawn_lever(
		"MemorySetLever",
		"memory_set",
		"SET",
		Vector3(-4.5, 0.0, z),
		true,
		0.12
	)
	var reset_lever_input: MechanismToggleLever = _spawn_lever(
		"MemoryResetLever",
		"memory_reset",
		"RESET",
		Vector3(4.5, 0.0, z),
		true,
		0.12
	)
	var set_reset_memory: MechanismLogicNode = _create_logic(
		"SetResetMemory",
		"set_reset_memory",
		"SET / RESET MEMORY",
		MechanismLogicNode.Operation.SET_RESET,
		[set_lever, reset_lever_input]
	)
	set_reset_memory.set_source_ids = [set_lever.get_mechanism_id()]
	set_reset_memory.reset_source_ids = [reset_lever_input.get_mechanism_id()]
	set_reset_memory.reset_dominates_set = true
	_create_logic_label(set_reset_memory, Vector3(0.0, 3.2, z + 2.0))
	var indicator: MechanismIndicator = _spawn_indicator(
		"SetResetMemoryIndicator",
		"STORED BIT",
		Vector3(0.0, 0.0, z + 4.2)
	)
	var gate: MechanismSlidingGate = _spawn_gate(
		"SetResetMemoryGate",
		"SET / RESET GATE",
		Vector3(0.0, 0.0, z + 8.0)
	)
	_wire_output("SetResetMemoryIndicatorOutput", set_reset_memory, indicator)
	_wire_output("SetResetMemoryGateOutput", set_reset_memory, gate)
	station_states["set_reset_memory"] = {
		"logic": set_reset_memory,
		"inputs": [set_lever, reset_lever_input],
		"outputs": [indicator, gate],
	}


func _build_sequence_memory_station(z: float) -> void:
	_create_station_platform(z, "08 • ORDERED SEQUENCE: A → C → B")
	var input_a: MechanismToggleLever = _spawn_lever(
		"SequenceInputA",
		"sequence_a",
		"A",
		Vector3(-5.0, 0.0, z),
		true,
		0.12
	)
	var input_b: MechanismToggleLever = _spawn_lever(
		"SequenceInputB",
		"sequence_b",
		"B",
		Vector3(0.0, 0.0, z),
		true,
		0.12
	)
	var input_c: MechanismToggleLever = _spawn_lever(
		"SequenceInputC",
		"sequence_c",
		"C",
		Vector3(5.0, 0.0, z),
		true,
		0.12
	)
	var sequence_memory: MechanismLogicNode = _create_logic(
		"OrderedSequenceMemory",
		"ordered_sequence_memory",
		"A → C → B MEMORY",
		MechanismLogicNode.Operation.SEQUENCE,
		[input_a, input_b, input_c]
	)
	sequence_memory.sequence_source_ids = [
		input_a.get_mechanism_id(),
		input_c.get_mechanism_id(),
		input_b.get_mechanism_id(),
	]
	sequence_memory.sequence_wrong_input_behavior = (
		MechanismLogicNode.SequenceWrongInputBehavior.RESET
	)
	_create_logic_label(sequence_memory, Vector3(0.0, 3.2, z + 2.1))
	var indicator: MechanismIndicator = _spawn_indicator(
		"SequenceMemoryIndicator",
		"SEQUENCE COMPLETE",
		Vector3(0.0, 0.0, z + 4.5)
	)
	var gate: MechanismSlidingGate = _spawn_gate(
		"SequenceMemoryGate",
		"SEQUENCE VAULT",
		Vector3(0.0, 0.0, z + 8.0)
	)
	_wire_output("SequenceMemoryIndicatorOutput", sequence_memory, indicator)
	_wire_output("SequenceMemoryGateOutput", sequence_memory, gate)
	station_states["sequence_memory"] = {
		"logic": sequence_memory,
		"inputs": [input_a, input_b, input_c],
		"outputs": [indicator, gate],
	}
