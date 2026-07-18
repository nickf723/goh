extends Node

const SteamPressureLiftScene: PackedScene = preload("res://scenes/environment/steam_pressure_lift.tscn")
const StatusReceiverScript = preload("res://scripts/combat/status_receiver.gd")

var failures: Array[String] = []
var fixture: Node3D
var reservoir: PressureReservoir
var consumer: ElementConsumer
var actuator: MechanicalActuator
var status_receiver: Node
var platform: Node3D
var initial_platform_position: Vector3 = Vector3(0.0, 0.28, 0.22)


func _ready() -> void:
	assert_machine_scene_structure()
	build_component_fixture()
	add_child(fixture)

	await get_tree().process_frame
	run_tests()

	if failures.is_empty():
		print("MECHANICAL_CONSUMER_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("MECHANICAL_CONSUMER_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func assert_machine_scene_structure() -> void:
	var machine: Node3D = SteamPressureLiftScene.instantiate() as Node3D
	if machine == null:
		failures.append("Steam pressure lift scene failed to instantiate")
		return

	for required_path: String in [
		"SteamConsumer",
		"SteamConsumer/StatusReceiver",
		"PressureReservoir",
		"MechanicalActuator",
		"LiftPlatform",
		"GaugeLabel",
		"GaugeNeedle",
	]:
		if machine.get_node_or_null(required_path) == null:
			failures.append("Steam pressure lift scene is missing " + required_path)

	machine.free()


func build_component_fixture() -> void:
	fixture = Node3D.new()
	fixture.name = "MechanicalConsumerFixture"

	reservoir = PressureReservoir.new()
	reservoir.name = "PressureReservoir"
	reservoir.maximum_pressure = 100.0
	reservoir.starting_pressure = 0.0
	reservoir.leak_per_second = 1.5
	reservoir.leak_enabled = false
	fixture.add_child(reservoir)

	platform = Node3D.new()
	platform.name = "LiftPlatform"
	platform.position = initial_platform_position
	fixture.add_child(platform)

	consumer = ElementConsumer.new()
	consumer.name = "SteamConsumer"
	consumer.accepted_statuses = ["steamed"]
	consumer.accepted_status_sources = ["steam_burst"]
	consumer.output_element = "steam"
	consumer.output_amount = 32.0
	consumer.output_target_path = NodePath("../PressureReservoir")
	consumer.event_cooldown = 0.0

	status_receiver = StatusReceiverScript.new()
	status_receiver.name = "StatusReceiver"
	consumer.add_child(status_receiver)
	fixture.add_child(consumer)

	actuator = MechanicalActuator.new()
	actuator.name = "MechanicalActuator"
	actuator.reservoir_path = NodePath("../PressureReservoir")
	actuator.moving_node_path = NodePath("../LiftPlatform")
	actuator.activation_pressure = 80.0
	actuator.deactivation_pressure = 20.0
	actuator.travel_offset = Vector3(0.0, 2.6, 0.0)
	actuator.move_duration = 0.0
	actuator.latch_when_activated = true
	fixture.add_child(actuator)


func run_tests() -> void:
	assert_fixture()
	if not failures.is_empty():
		return

	test_source_filter()
	test_pressure_accumulation()
	test_pressure_leak()
	test_lift_activation()
	test_machine_reset()


func assert_fixture() -> void:
	if reservoir == null:
		failures.append("pressure reservoir is missing")
	if consumer == null:
		failures.append("element consumer is missing")
	if actuator == null:
		failures.append("mechanical actuator is missing")
	if status_receiver == null:
		failures.append("consumer StatusReceiver is missing")
	if platform == null:
		failures.append("lift platform is missing")


func test_source_filter() -> void:
	reset_fixture()
	status_receiver.apply_status("steamed", 1.0, 1.0, "ordinary_steam_patch")
	if not is_zero_approx(reservoir.current_pressure):
		failures.append("ordinary steamed status must not charge the pressure machine")


func test_pressure_accumulation() -> void:
	reset_fixture()
	apply_steam_burst()
	if not is_equal_approx(reservoir.current_pressure, 32.0):
		failures.append(
			"one Steam Burst should add 32 pressure; found "
			+ str(reservoir.current_pressure)
		)
	if consumer.consumption_count != 1:
		failures.append("one Steam Burst should count as one consumption event")


func test_pressure_leak() -> void:
	reset_fixture()
	reservoir.add_pressure(20.0, "test charge")
	reservoir.leak_enabled = true
	reservoir._process(2.0)
	reservoir.leak_enabled = false
	if not is_equal_approx(reservoir.current_pressure, 17.0):
		failures.append(
			"pressure should leak 3 units over 2 seconds; found "
			+ str(reservoir.current_pressure)
		)


func test_lift_activation() -> void:
	reset_fixture()
	apply_steam_burst()
	apply_steam_burst()
	if actuator.is_activated:
		failures.append("two Steam Bursts should remain below the 80 pressure threshold")

	apply_steam_burst()
	if not actuator.is_activated:
		failures.append("three Steam Bursts should activate the pressure lift")
	if reservoir.current_pressure < actuator.activation_pressure:
		failures.append("activated lift should have crossed its pressure threshold")

	var expected_position: Vector3 = initial_platform_position + actuator.travel_offset
	if platform.position.distance_to(expected_position) > 0.001:
		failures.append(
			"activated platform should move to its target position; found "
			+ str(platform.position)
		)


func test_machine_reset() -> void:
	reset_fixture()
	if not is_zero_approx(reservoir.current_pressure):
		failures.append("machine reset should empty the pressure reservoir")
	if actuator.is_activated:
		failures.append("machine reset should unlatch the actuator")
	if platform.position.distance_to(initial_platform_position) > 0.001:
		failures.append("machine reset should return the platform to its initial position")
	if consumer.consumption_count != 0:
		failures.append("machine reset should clear the consumer event count")


func reset_fixture() -> void:
	consumer.reset_consumer()
	if status_receiver.has_method("clear_all_statuses"):
		status_receiver.clear_all_statuses()
	actuator.reset_actuator()
	reservoir.leak_enabled = false
	reservoir.reset_pressure()


func apply_steam_burst() -> void:
	consumer.cooldown_timer = 0.0
	status_receiver.apply_status("steamed", 1.8, 1.0, "steam_burst")
