extends Node

const PressurePlateScene: PackedScene = preload(
	"res://scenes/mechanisms/pressure_plate_switch.tscn"
)
const ElementSensorScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_element_sensor.tscn"
)
const IndicatorScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_indicator.tscn"
)
const GateScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_sliding_gate.tscn"
)
const BridgeScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_bridge_output.tscn"
)
const LabScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_mechanism_network_lab_v1.tscn"
)

class FakeMechanismOutput:
	extends Node
	var active: bool = false
	var applications: int = 0
	var last_packet: Dictionary = {}

	func set_mechanism_active(next_active: bool, packet: Dictionary = {}) -> void:
		active = next_active
		applications += 1
		last_packet = packet.duplicate(true)

var failures: Array[String] = []
var fixture: Node


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	GameState.reset_run()
	fixture = Node.new()
	fixture.name = "MechanismNetworkFixture"
	add_child(fixture)
	await _test_logic_grammar()
	await _test_pressure_plate_bridge()
	await _test_element_sensor()
	await _test_output_hardware()
	await _test_production_lab()
	if fixture != null and is_instance_valid(fixture):
		fixture.queue_free()
	await get_tree().process_frame
	_finish()


func _test_logic_grammar() -> void:
	var source_a := _make_source("SourceA", "source_a")
	var source_b := _make_source("SourceB", "source_b")
	var and_logic := _make_logic(
		"AndLogic",
		"and_logic",
		MechanismLogicNode.Operation.AND,
		[source_a, source_b]
	)
	var or_logic := _make_logic(
		"OrLogic",
		"or_logic",
		MechanismLogicNode.Operation.OR,
		[source_a, source_b]
	)
	var not_logic := _make_logic(
		"NotLogic",
		"not_logic",
		MechanismLogicNode.Operation.NOT,
		[source_a]
	)
	await _wait_frames(3)
	_expect(not and_logic.active, "AND begins inactive")
	_expect(not or_logic.active, "OR begins inactive")
	_expect(not_logic.active, "NOT begins active when its source is false")

	source_a.set_input_active(true, {"test": "source_a_on"})
	await get_tree().process_frame
	_expect(not and_logic.active, "AND waits for every source")
	_expect(or_logic.active, "OR activates from one source")
	_expect(not not_logic.active, "NOT inverts an active source")

	source_b.set_input_active(true, {"test": "source_b_on"})
	await get_tree().process_frame
	_expect(and_logic.active, "AND activates when every source is true")

	var xor_logic := _make_logic(
		"XorLogic",
		"xor_logic",
		MechanismLogicNode.Operation.XOR,
		[source_a, source_b]
	)
	await _wait_frames(2)
	_expect(not xor_logic.active, "XOR rejects two simultaneous sources")
	source_b.set_input_active(false)
	await get_tree().process_frame
	_expect(xor_logic.active, "XOR accepts exactly one source")

	var timer_source := _make_source("TimerSource", "timer_source")
	var timer_logic := _make_logic(
		"TimerLogic",
		"timer_logic",
		MechanismLogicNode.Operation.TIMER,
		[timer_source]
	)
	timer_logic.timer_seconds = 0.25
	timer_source.set_input_active(true)
	await get_tree().process_frame
	_expect(timer_logic.active, "timer starts on a rising edge")
	timer_logic._process(0.3)
	_expect(not timer_logic.active, "timer expires after its configured duration")
	_expect(not timer_logic.is_processing(), "expired timer returns to event-driven sleep")

	var latch_source := _make_source("LatchSource", "latch_source")
	var latch_logic := _make_logic(
		"LatchLogic",
		"latch_logic",
		MechanismLogicNode.Operation.LATCH,
		[latch_source]
	)
	latch_source.set_input_active(true)
	latch_source.set_input_active(false)
	await get_tree().process_frame
	_expect(latch_logic.active, "latch remembers a completed pulse")
	latch_logic.reset_latch()
	_expect(not latch_logic.active, "latch resets explicitly")

	var counter_source := _make_source("CounterSource", "counter_source")
	var counter_logic := _make_logic(
		"CounterLogic",
		"counter_logic",
		MechanismLogicNode.Operation.COUNTER,
		[counter_source]
	)
	counter_logic.counter_target = 3
	for _index: int in range(3):
		_pulse_source(counter_source)
	await get_tree().process_frame
	_expect(counter_logic.active, "counter activates at its target")
	_expect(counter_logic.counter_value == 3, "counter records three rising edges")

	var toggle_source := _make_source("ToggleSource", "toggle_source")
	var toggle_logic := _make_logic(
		"ToggleLogic",
		"toggle_logic",
		MechanismLogicNode.Operation.TOGGLE,
		[toggle_source]
	)
	await _wait_frames(2)
	_pulse_source(toggle_source)
	_expect(toggle_logic.active, "toggle memory turns on from its first pulse")
	_pulse_source(toggle_source)
	_expect(not toggle_logic.active, "toggle memory turns off from its second pulse")
	_expect(toggle_logic.memory_transition_count == 2, "toggle memory records both state transitions")

	var set_source := _make_source("SetSource", "set_source")
	var reset_source := _make_source("ResetSource", "reset_source")
	var set_reset_logic := _make_logic(
		"SetResetLogic",
		"set_reset_logic",
		MechanismLogicNode.Operation.SET_RESET,
		[set_source, reset_source]
	)
	set_reset_logic.set_source_ids = Array[String]([set_source.get_mechanism_id()])
	set_reset_logic.reset_source_ids = Array[String]([reset_source.get_mechanism_id()])
	await _wait_frames(2)
	_pulse_source(set_source)
	_expect(set_reset_logic.active, "SET input stores an active memory bit")
	_pulse_source(reset_source)
	_expect(not set_reset_logic.active, "RESET input clears the stored memory bit")
	reset_source.set_input_active(true)
	set_source.set_input_active(true)
	_expect(not set_reset_logic.active, "active RESET dominates a simultaneous SET command")
	set_source.set_input_active(false)
	reset_source.set_input_active(false)

	var sequence_a := _make_source("SequenceA", "sequence_a")
	var sequence_b := _make_source("SequenceB", "sequence_b")
	var sequence_c := _make_source("SequenceC", "sequence_c")
	var sequence_logic := _make_logic(
		"SequenceLogic",
		"sequence_logic",
		MechanismLogicNode.Operation.SEQUENCE,
		[sequence_a, sequence_b, sequence_c]
	)
	sequence_logic.sequence_source_ids = Array[String]([
		sequence_a.get_mechanism_id(),
		sequence_c.get_mechanism_id(),
		sequence_b.get_mechanism_id(),
	])
	sequence_logic.sequence_wrong_input_behavior = (
		MechanismLogicNode.SequenceWrongInputBehavior.RESET
	)
	await _wait_frames(2)
	_pulse_source(sequence_a)
	_expect(sequence_logic.sequence_index == 1, "sequence memory advances after the correct first input")
	_pulse_source(sequence_b)
	_expect(sequence_logic.sequence_index == 0, "wrong sequence input resets progress")
	_expect(sequence_logic.sequence_wrong_input_count == 1, "sequence memory records wrong inputs")
	_pulse_source(sequence_a)
	_pulse_source(sequence_c)
	_pulse_source(sequence_b)
	_expect(sequence_logic.active, "ordered A C B input completes sequence memory")
	_expect(sequence_logic.sequence_index == 3, "completed sequence records full progress")
	sequence_logic.reset_sequence()
	_expect(not sequence_logic.active, "sequence memory clears explicitly")
	_expect(sequence_logic.sequence_index == 0, "sequence reset clears progress")

	var fake_output := FakeMechanismOutput.new()
	fake_output.name = "FakeOutput"
	fixture.add_child(fake_output)
	var adapter := MechanismOutputAdapter.new()
	adapter.name = "AndOutputAdapter"
	adapter.mechanism_id = "and_output_adapter"
	fixture.add_child(adapter)
	adapter.bind_source(and_logic)
	adapter.bind_target(fake_output)
	and_logic.reset_target()
	source_b.set_input_active(true)
	await _wait_frames(2)
	_expect(fake_output.active, "output adapter applies an active logic result")
	_expect(fake_output.applications > 0, "output adapter records target applications")


func _test_pressure_plate_bridge() -> void:
	var plate: PressurePlateSwitch = PressurePlateScene.instantiate() as PressurePlateSwitch
	plate.name = "PressurePlateFixture"
	plate.component_id = "fixture_pressure_plate"
	fixture.add_child(plate)
	var pass_logic := _make_logic(
		"PressurePass",
		"pressure_pass",
		MechanismLogicNode.Operation.PASS,
		[plate]
	)
	await _wait_frames(2)
	plate.set_pressed(true, true)
	await get_tree().process_frame
	_expect(plate.is_mechanism_active(), "physical pressure plate exposes its pressed state")
	_expect(pass_logic.active, "physical pressure plate feeds the puzzle signal graph")
	_expect(
		str(plate.get_mechanism_packet().get("source_type", "")) == "pressure_plate",
		"pressure plate signal packet identifies its physical source"
	)
	plate.set_pressed(false, true)
	await get_tree().process_frame
	_expect(not pass_logic.active, "releasing the plate clears the puzzle signal")


func _test_element_sensor() -> void:
	var sensor: MechanismElementSensor = ElementSensorScene.instantiate() as MechanismElementSensor
	sensor.name = "ElementSensorFixture"
	sensor.mechanism_id = "fixture_fire_sensor"
	fixture.add_child(sensor)
	await _wait_frames(2)
	var water := DamagePayload.new()
	water.element = "water"
	water.source_name = "Water Test"
	var fire := DamagePayload.new()
	fire.element = "fire"
	fire.source_name = "Fire Test"
	var wrong_result: Dictionary = sensor.receive_damage_payload(water)
	_expect(not sensor.is_mechanism_active(), "wrong/reset element does not activate a dormant fire sensor")
	_expect(str(wrong_result.get("message", "")).contains("resets"), "water reports the reset behavior")
	var fire_result: Dictionary = sensor.receive_damage_payload(fire)
	_expect(sensor.is_mechanism_active(), "fire payload activates a fire sensor")
	_expect(str(fire_result.get("message", "")).contains("answers"), "accepted element returns readable feedback")
	sensor.receive_damage_payload(water)
	_expect(not sensor.is_mechanism_active(), "water resets an active fire sensor")


func _test_output_hardware() -> void:
	var source := _make_source("HardwareSource", "hardware_source")
	var indicator: MechanismIndicator = IndicatorScene.instantiate() as MechanismIndicator
	indicator.name = "IndicatorFixture"
	fixture.add_child(indicator)
	var gate: MechanismSlidingGate = GateScene.instantiate() as MechanismSlidingGate
	gate.name = "GateFixture"
	fixture.add_child(gate)
	var bridge: MechanismBridgeOutput = BridgeScene.instantiate() as MechanismBridgeOutput
	bridge.name = "BridgeFixture"
	fixture.add_child(bridge)
	var indicator_adapter := _wire_fixture_output("IndicatorAdapter", source, indicator)
	var gate_adapter := _wire_fixture_output("GateAdapter", source, gate)
	var bridge_adapter := _wire_fixture_output("BridgeAdapter", source, bridge)
	await _wait_frames(2)
	source.set_input_active(true, {"test": "hardware_on"})
	await _wait_frames(2)
	_expect(indicator.active, "indicator follows an active signal")
	_expect(gate.active and gate.collision_layer == 0, "active gate opens and disables collision")
	_expect(bridge.active, "active bridge extends")
	_expect(indicator_adapter.active and gate_adapter.active and bridge_adapter.active, "output adapters mirror the source")
	source.set_input_active(false, {"test": "hardware_off"})
	await _wait_frames(2)
	_expect(not indicator.active, "indicator clears with the signal")
	_expect(not gate.active and gate.collision_layer != 0, "gate closes and restores collision")
	_expect(not bridge.active, "bridge retracts with the signal")


func _test_production_lab() -> void:
	var lab: Node = LabScene.instantiate()
	lab.name = "MechanismNetworkLabFixture"
	add_child(lab)
	await _wait_frames(8)
	_expect(lab.is_in_group("mechanism_network_labs"), "production mechanism lab advertises its group")
	var debug_value: Variant = lab.call("get_debug_data") if lab.has_method("get_debug_data") else {}
	var debug: Dictionary = debug_value as Dictionary if debug_value is Dictionary else {}
	_expect(bool(debug.get("mechanism_network_lab", false)), "production lab exposes a debug contract")
	_expect(int(debug.get("inputs", 0)) >= 14, "production lab contains physical, elemental, and memory inputs")
	_expect((debug.get("logic_nodes", {}) as Dictionary).size() >= 11, "production lab contains boolean, timing, and memory logic")
	_expect(int(debug.get("outputs", 0)) >= 18, "production lab contains gates, indicators, and a bridge")
	_expect(
		lab.get_node_or_null("Mechanisms/WeightPlate") != null,
		"production lab contains the weight station"
	)
	_expect(
		lab.get_node_or_null("Mechanisms/AndFireSensor") != null,
		"production lab contains the elemental AND station"
	)
	_expect(
		lab.get_node_or_null("Mechanisms/OrBridge") != null,
		"production lab contains the OR bridge"
	)
	_expect(
		lab.get_node_or_null("Mechanisms/TimerGate") != null,
		"production lab contains the timed gate"
	)
	_expect(
		lab.get_node_or_null("Mechanisms/FinalGate") != null,
		"production lab contains the counter and latch finale"
	)
	_expect(
		lab.get_node_or_null("Mechanisms/ToggleMemoryGate") != null,
		"production lab contains the toggle-memory gate"
	)
	_expect(
		lab.get_node_or_null("Mechanisms/SetResetMemoryGate") != null,
		"production lab contains the set-reset gate"
	)
	_expect(
		lab.get_node_or_null("Mechanisms/SequenceMemoryGate") != null,
		"production lab contains the ordered-sequence vault"
	)

	var toggle_lever: MechanismToggleLever = (
		lab.get_node_or_null("Mechanisms/ToggleMemoryLever") as MechanismToggleLever
	)
	var toggle_logic: MechanismLogicNode = (
		lab.get_node_or_null("SignalNetwork/ToggleMemory") as MechanismLogicNode
	)
	var toggle_gate: MechanismSlidingGate = (
		lab.get_node_or_null("Mechanisms/ToggleMemoryGate") as MechanismSlidingGate
	)
	if toggle_lever != null and toggle_logic != null and toggle_gate != null:
		toggle_lever.interact()
		await _wait_frames(2)
		_expect(toggle_logic.active and toggle_gate.active, "production toggle station remembers one pulse")

	var sequence_a: MechanismToggleLever = (
		lab.get_node_or_null("Mechanisms/SequenceInputA") as MechanismToggleLever
	)
	var sequence_b: MechanismToggleLever = (
		lab.get_node_or_null("Mechanisms/SequenceInputB") as MechanismToggleLever
	)
	var sequence_c: MechanismToggleLever = (
		lab.get_node_or_null("Mechanisms/SequenceInputC") as MechanismToggleLever
	)
	var sequence_logic: MechanismLogicNode = (
		lab.get_node_or_null("SignalNetwork/OrderedSequenceMemory") as MechanismLogicNode
	)
	if sequence_a != null and sequence_b != null and sequence_c != null and sequence_logic != null:
		sequence_a.interact()
		sequence_c.interact()
		sequence_b.interact()
		await _wait_frames(2)
		_expect(sequence_logic.active, "production sequence station accepts A C B")

	lab.call("reset_lab")
	await _wait_frames(2)
	_expect(not bool((lab.get_node("Mechanisms/FinalGate") as MechanismSlidingGate).active), "lab reset closes the counter-latch gate")
	_expect(not bool((lab.get_node("Mechanisms/ToggleMemoryGate") as MechanismSlidingGate).active), "lab reset clears toggle memory")
	_expect(not bool((lab.get_node("Mechanisms/SetResetMemoryGate") as MechanismSlidingGate).active), "lab reset clears set-reset memory")
	_expect(not bool((lab.get_node("Mechanisms/SequenceMemoryGate") as MechanismSlidingGate).active), "lab reset clears sequence memory")
	_expect(
		int((lab.get_node("SignalNetwork/OrderedSequenceMemory") as MechanismLogicNode).sequence_index) == 0,
		"lab reset clears ordered-sequence progress"
	)
	lab.queue_free()
	await get_tree().process_frame


func _make_source(node_name: String, mechanism_id: String) -> MechanismManualSource:
	var source := MechanismManualSource.new()
	source.name = node_name
	source.mechanism_id = mechanism_id
	source.display_name = node_name
	fixture.add_child(source)
	return source


func _make_logic(
	node_name: String,
	mechanism_id: String,
	operation: int,
	sources: Array
) -> MechanismLogicNode:
	var logic := MechanismLogicNode.new()
	logic.name = node_name
	logic.mechanism_id = mechanism_id
	logic.display_name = node_name
	logic.operation = operation
	fixture.add_child(logic)
	for value: Variant in sources:
		if value is Node:
			logic.bind_source(value as Node)
	return logic


func _wire_fixture_output(
	node_name: String,
	source: Node,
	target: Node
) -> MechanismOutputAdapter:
	var adapter := MechanismOutputAdapter.new()
	adapter.name = node_name
	adapter.mechanism_id = node_name.to_lower()
	fixture.add_child(adapter)
	adapter.bind_source(source)
	adapter.bind_target(target)
	return adapter


func _pulse_source(source: MechanismManualSource) -> void:
	source.set_input_active(true, {"test": "pulse_on"})
	source.set_input_active(false, {"test": "pulse_off"})


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("MECHANISM_NETWORK_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("MECHANISM_NETWORK_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("MECHANISM_NETWORK_SMOKE_TEST: " + failure)
	get_tree().quit(1)
