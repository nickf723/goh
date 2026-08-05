extends Node

const PressurePlateScene: PackedScene = preload(
	"res://scenes/mechanisms/pressure_plate_switch.tscn"
)
const ValueElevatorScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_value_elevator.tscn"
)
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
	fixture.name = "MechanismValueFixture"
	add_child(fixture)
	await _test_value_signal_contract()
	await _test_pressure_plate_mass()
	await _test_value_comparators()
	await _test_proportional_output()
	await _test_production_value_wing()
	if fixture != null and is_instance_valid(fixture):
		fixture.queue_free()
	await get_tree().process_frame
	_finish()


func _test_value_signal_contract() -> void:
	var source := _make_value_source("ValueContractSource", "value_contract", 0.0, 20.0)
	await _wait_frames(2)
	source.set_mechanism_value(7.5, {"test": "numeric_contract"})
	_expect(is_equal_approx(source.get_mechanism_value(), 7.5), "signal nodes expose raw numeric values")
	_expect(is_equal_approx(source.get_mechanism_normalized_value(), 0.375), "signal nodes normalize authored value ranges")
	var packet: Dictionary = source.get_mechanism_packet()
	_expect(is_equal_approx(float(packet.get("value", 0.0)), 7.5), "signal packets carry numeric value")
	_expect(is_equal_approx(float(packet.get("minimum_value", -1.0)), 0.0), "signal packets carry minimum value")
	_expect(is_equal_approx(float(packet.get("maximum_value", -1.0)), 20.0), "signal packets carry maximum value")
	_expect(not source.is_mechanism_active(), "changing a numeric value does not force Boolean state")

	var boolean_source := MechanismManualSource.new()
	boolean_source.name = "BooleanCompatibilitySource"
	boolean_source.mechanism_id = "boolean_compatibility"
	fixture.add_child(boolean_source)
	await _wait_frames(2)
	boolean_source.set_input_active(true)
	_expect(boolean_source.is_mechanism_active(), "legacy Boolean sources remain active-compatible")
	_expect(is_equal_approx(boolean_source.get_mechanism_value(), 1.0), "legacy Boolean sources mirror ON to value one")
	boolean_source.set_input_active(false)
	_expect(is_equal_approx(boolean_source.get_mechanism_value(), 0.0), "legacy Boolean sources mirror OFF to value zero")


func _test_pressure_plate_mass() -> void:
	var plate: PressurePlateSwitch = PressurePlateScene.instantiate() as PressurePlateSwitch
	plate.name = "MassPlateFixture"
	plate.component_id = "mass_plate_fixture"
	plate.maximum_reported_mass_kg = 10.0
	fixture.add_child(plate)
	var pass_logic := MechanismLogicNode.new()
	pass_logic.name = "MassPlateBooleanPass"
	pass_logic.mechanism_id = "mass_plate_boolean_pass"
	pass_logic.operation = MechanismLogicNode.Operation.PASS
	fixture.add_child(pass_logic)
	pass_logic.bind_source(plate)
	await _wait_frames(2)

	var two_kg := RigidBody3D.new()
	two_kg.name = "TwoKilogramBody"
	two_kg.mass = 2.0
	fixture.add_child(two_kg)
	var five_kg := RigidBody3D.new()
	five_kg.name = "FiveKilogramBody"
	five_kg.mass = 5.0
	fixture.add_child(five_kg)

	plate._on_body_entered(two_kg)
	plate._on_body_entered(five_kg)
	_expect(plate.is_mechanism_active(), "weighted pressure plate remains a Boolean contact source")
	_expect(pass_logic.active, "weighted pressure plate still feeds legacy Boolean logic")
	_expect(is_equal_approx(plate.get_mechanism_value(), 7.0), "pressure plate sums rigid-body mass")
	_expect(int(plate.get_mechanism_packet().get("occupants", 0)) == 2, "pressure plate packet reports occupant count")
	_expect(is_equal_approx(float(plate.get_mechanism_packet().get("normalized_value", 0.0)), 0.7), "pressure plate normalizes against authored capacity")

	plate._on_body_exited(two_kg)
	_expect(plate.is_mechanism_active(), "removing one body keeps the plate pressed while another remains")
	_expect(is_equal_approx(plate.get_mechanism_value(), 5.0), "pressure plate updates value without a Boolean edge")
	plate._on_body_exited(five_kg)
	_expect(not plate.is_mechanism_active(), "pressure plate releases after its final body exits")
	_expect(is_equal_approx(plate.get_mechanism_value(), 0.0), "released pressure plate returns to zero kilograms")

	two_kg.queue_free()
	five_kg.queue_free()
	await get_tree().process_frame


func _test_value_comparators() -> void:
	var threshold_source := _make_value_source(
		"ThresholdValueSource",
		"threshold_value_source",
		0.0,
		20.0
	)
	var threshold_comparator := _make_comparator(
		"ThresholdComparator",
		"threshold_comparator",
		MechanismValueComparator.Comparison.GREATER_OR_EQUAL,
		[threshold_source]
	)
	threshold_comparator.primary_source_id = threshold_source.get_mechanism_id()
	threshold_comparator.threshold = 10.0
	await _wait_frames(2)
	threshold_source.set_mechanism_value(9.0)
	_expect(not threshold_comparator.active, "greater-or-equal comparator rejects values below threshold")
	threshold_source.set_mechanism_value(10.0)
	_expect(threshold_comparator.active, "greater-or-equal comparator activates at threshold")

	var range_comparator := _make_comparator(
		"RangeComparator",
		"range_comparator",
		MechanismValueComparator.Comparison.INSIDE_RANGE,
		[threshold_source]
	)
	range_comparator.primary_source_id = threshold_source.get_mechanism_id()
	range_comparator.range_minimum = 4.0
	range_comparator.range_maximum = 6.0
	await _wait_frames(2)
	threshold_source.set_mechanism_value(5.0)
	_expect(range_comparator.active, "inside-range comparator accepts an interior value")
	threshold_source.set_mechanism_value(8.0)
	_expect(not range_comparator.active, "inside-range comparator rejects an exterior value")

	var left_source := _make_value_source("LeftBalanceSource", "left_balance", 0.0, 12.0)
	var right_source := _make_value_source("RightBalanceSource", "right_balance", 0.0, 12.0)
	var balance_comparator := _make_comparator(
		"BalanceComparatorFixture",
		"balance_comparator_fixture",
		MechanismValueComparator.Comparison.SOURCES_WITHIN_TOLERANCE,
		[left_source, right_source]
	)
	balance_comparator.primary_source_id = left_source.get_mechanism_id()
	balance_comparator.secondary_source_id = right_source.get_mechanism_id()
	balance_comparator.tolerance = 0.1
	await _wait_frames(2)
	left_source.set_mechanism_value(4.0)
	right_source.set_mechanism_value(5.0)
	_expect(not balance_comparator.active, "balance comparator rejects unequal source values")
	right_source.set_mechanism_value(4.0)
	_expect(balance_comparator.active, "balance comparator accepts equal source values")
	_expect(is_equal_approx(balance_comparator.last_difference, 0.0), "balance comparator reports signed difference")


func _test_proportional_output() -> void:
	var source := _make_value_source("ElevatorValueSource", "elevator_value_source", 0.0, 10.0)
	var elevator: MechanismValueElevator = ValueElevatorScene.instantiate() as MechanismValueElevator
	elevator.name = "ValueElevatorFixture"
	elevator.input_minimum = 0.0
	elevator.input_maximum = 10.0
	elevator.movement_offset = Vector3(0.0, 6.0, 0.0)
	elevator.transition_seconds = 0.01
	fixture.add_child(elevator)
	var adapter := MechanismOutputAdapter.new()
	adapter.name = "ValueElevatorAdapter"
	adapter.mechanism_id = "value_elevator_adapter"
	adapter.forward_value = true
	adapter.also_apply_boolean_state = false
	fixture.add_child(adapter)
	adapter.bind_source(source)
	adapter.bind_target(elevator)
	await _wait_frames(2)

	source.set_mechanism_value(5.0)
	await _wait_frames(3)
	_expect(is_equal_approx(elevator.target_fraction, 0.5), "value adapter maps half input to half elevator travel")
	_expect(absf(elevator.position.y - 3.0) <= 0.05, "proportional elevator physically reaches half height")
	_expect(adapter.value_application_count > 0, "output adapter records numeric applications")

	source.set_mechanism_value(10.0)
	await _wait_frames(3)
	_expect(is_equal_approx(elevator.target_fraction, 1.0), "maximum input maps to full elevator travel")
	_expect(absf(elevator.position.y - 6.0) <= 0.05, "proportional elevator physically reaches full height")


func _test_production_value_wing() -> void:
	var lab: Node = LabScene.instantiate()
	lab.name = "MechanismValueLabFixture"
	add_child(lab)
	await _wait_frames(10)
	_expect(lab is MechanismNetworkLabValue, "production mechanism lab includes the value-signal runtime")
	var debug_value: Variant = lab.call("get_debug_data") if lab.has_method("get_debug_data") else {}
	var debug: Dictionary = debug_value as Dictionary if debug_value is Dictionary else {}
	_expect(bool(debug.get("value_signal_lab", false)), "production lab exposes its value-signal debug contract")
	_expect(int(debug.get("value_comparator_count", 0)) >= 2, "production lab contains threshold and balance comparators")
	_expect(lab.get_node_or_null("Mechanisms/ThresholdWeightGate") != null, "production lab contains the weighted threshold gate")
	_expect(lab.get_node_or_null("Mechanisms/BalanceGate") != null, "production lab contains the balance-scale gate")
	_expect(lab.get_node_or_null("Mechanisms/ProportionalElevator") != null, "production lab contains the proportional elevator")

	var threshold_plate := lab.get_node_or_null("Mechanisms/ThresholdWeightPlate") as PressurePlateSwitch
	var threshold_gate := lab.get_node_or_null("Mechanisms/ThresholdWeightGate") as MechanismSlidingGate
	if threshold_plate != null and threshold_gate != null:
		threshold_plate.set_simulated_mass_kg(9.0)
		await _wait_frames(2)
		_expect(not threshold_gate.active, "production threshold gate remains closed below ten kilograms")
		threshold_plate.set_simulated_mass_kg(10.0)
		await _wait_frames(2)
		_expect(threshold_gate.active, "production threshold gate opens at ten kilograms")

	var left_plate := lab.get_node_or_null("Mechanisms/BalanceLeftPlate") as PressurePlateSwitch
	var right_plate := lab.get_node_or_null("Mechanisms/BalanceRightPlate") as PressurePlateSwitch
	var balance_gate := lab.get_node_or_null("Mechanisms/BalanceGate") as MechanismSlidingGate
	if left_plate != null and right_plate != null and balance_gate != null:
		left_plate.set_simulated_mass_kg(5.0)
		right_plate.set_simulated_mass_kg(3.0)
		await _wait_frames(2)
		_expect(not balance_gate.active, "production balance gate rejects unequal loads")
		right_plate.set_simulated_mass_kg(5.0)
		await _wait_frames(2)
		_expect(balance_gate.active, "production balance gate opens for equal loads")

	var elevator_plate := lab.get_node_or_null("Mechanisms/ElevatorWeightPlate") as PressurePlateSwitch
	var elevator := lab.get_node_or_null("Mechanisms/ProportionalElevator") as MechanismValueElevator
	if elevator_plate != null and elevator != null:
		elevator.transition_seconds = 0.01
		elevator_plate.set_simulated_mass_kg(5.0)
		await _wait_frames(3)
		_expect(is_equal_approx(elevator.target_fraction, 0.5), "production elevator receives half-scale weight")

	lab.call("reset_lab")
	await _wait_frames(3)
	if threshold_gate != null:
		_expect(not threshold_gate.active, "lab reset closes the weighted threshold gate")
	if balance_gate != null:
		_expect(not balance_gate.active, "lab reset closes the balance gate")
	if elevator != null:
		_expect(is_equal_approx(elevator.current_fraction, 0.0), "lab reset lowers the proportional elevator")
	lab.queue_free()
	await get_tree().process_frame


func _make_value_source(
	node_name: String,
	mechanism_id: String,
	minimum: float,
	maximum: float
) -> MechanismManualSource:
	var source := MechanismManualSource.new()
	source.name = node_name
	source.mechanism_id = mechanism_id
	source.display_name = node_name
	source.mirror_active_to_value = false
	source.initial_value = minimum
	source.minimum_value = minimum
	source.maximum_value = maximum
	fixture.add_child(source)
	return source


func _make_comparator(
	node_name: String,
	mechanism_id: String,
	comparison: MechanismValueComparator.Comparison,
	sources: Array
) -> MechanismValueComparator:
	var comparator := MechanismValueComparator.new()
	comparator.name = node_name
	comparator.mechanism_id = mechanism_id
	comparator.display_name = node_name
	comparator.comparison = comparison
	fixture.add_child(comparator)
	for source_value: Variant in sources:
		if source_value is Node:
			comparator.bind_source(source_value as Node)
	return comparator


func _wait_frames(count: int) -> void:
	for _index: int in range(count):
		await get_tree().process_frame


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: ", label)
		return
	failures.append(label)
	push_error("MECHANISM_VALUE_SIGNAL_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("MECHANISM_VALUE_SIGNAL_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("MECHANISM_VALUE_SIGNAL_SMOKE_TEST: " + failure)
	get_tree().quit(1)
