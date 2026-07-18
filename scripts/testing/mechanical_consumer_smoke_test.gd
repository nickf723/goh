extends Node

const SteamPressureLiftScene: PackedScene = preload("res://scenes/environment/steam_pressure_lift.tscn")

var failures: Array[String] = []
var machine: Node3D
var reservoir: PressureReservoir
var consumer: ElementConsumer
var actuator: MechanicalActuator
var status_receiver: Node
var platform: Node3D
var initial_platform_position: Vector3


func _ready() -> void:
	machine = SteamPressureLiftScene.instantiate() as Node3D
	machine.name = "MechanicalConsumerFixture"
	add_child(machine)

	await get_tree().process_frame

	reservoir = machine.get_node_or_null("PressureReservoir") as PressureReservoir
	consumer = machine.get_node_or_null("SteamConsumer") as ElementConsumer
	actuator = machine.get_node_or_null("MechanicalActuator") as MechanicalActuator
	status_receiver = machine.get_node_or_null("SteamConsumer/StatusReceiver")
	platform = machine.get_node_or_null("LiftPlatform") as Node3D

	if platform != null:
		initial_platform_position = platform.position
	if consumer != null:
		consumer.event_cooldown = 0.0
	if actuator != null:
		actuator.move_duration = 0.0

	run_tests()

	if failures.is_empty():
		print("MECHANICAL_CONSUMER_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("MECHANICAL_CONSUMER_SMOKE_TEST: " + failure)
	get_tree().quit(1)


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
	machine.call("reset_target")
	status_receiver.apply_status("steamed", 1.0, 1.0, "ordinary_steam_patch")
	if not is_zero_approx(reservoir.current_pressure):
		failures.append("ordinary steamed status must not charge the pressure machine")


func test_pressure_accumulation() -> void:
	machine.call("reset_target")
	apply_steam_burst()
	if not is_equal_approx(reservoir.current_pressure, 32.0):
		failures.append(
			"one Steam Burst should add 32 pressure; found "
			+ str(reservoir.current_pressure)
		)
	if consumer.consumption_count != 1:
		failures.append("one Steam Burst should count as one consumption event")


func test_pressure_leak() -> void:
	machine.call("reset_target")
	reservoir.add_pressure(20.0, "test charge")
	reservoir._process(2.0)
	if not is_equal_approx(reservoir.current_pressure, 17.0):
		failures.append(
			"pressure should leak 3 units over 2 seconds; found "
			+ str(reservoir.current_pressure)
		)


func test_lift_activation() -> void:
	machine.call("reset_target")
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
	machine.call("reset_target")
	if not is_zero_approx(reservoir.current_pressure):
		failures.append("machine reset should empty the pressure reservoir")
	if actuator.is_activated:
		failures.append("machine reset should unlatch the actuator")
	if platform.position.distance_to(initial_platform_position) > 0.001:
		failures.append("machine reset should return the platform to its initial position")
	if consumer.consumption_count != 0:
		failures.append("machine reset should clear the consumer event count")


func apply_steam_burst() -> void:
	consumer.cooldown_timer = 0.0
	status_receiver.apply_status("steamed", 1.8, 1.0, "steam_burst")
