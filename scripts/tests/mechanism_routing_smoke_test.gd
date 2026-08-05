extends Node

const PressurePlateScene: PackedScene = preload(
	"res://scenes/mechanisms/pressure_plate_switch.tscn"
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
	fixture.name = "MechanismRoutingFixture"
	add_child(fixture)
	await _test_pressure_plate_static_filter()
	await _test_selector_and_router()
	await _test_multiplexer()
	await _test_production_routing_wing()
	if fixture != null and is_instance_valid(fixture):
		fixture.queue_free()
	await get_tree().process_frame
	_finish()


func _test_pressure_plate_static_filter() -> void:
	var plate: PressurePlateSwitch = (
		PressurePlateScene.instantiate() as PressurePlateSwitch
	)
	plate.name = "StaticFilterPlate"
	plate.component_id = "static_filter_plate"
	fixture.add_child(plate)
	await _wait_frames(2)

	var floor := StaticBody3D.new()
	floor.name = "SyntheticLabFloor"
	fixture.add_child(floor)
	var platform := StaticBody3D.new()
	platform.name = "SyntheticStationPlatform"
	fixture.add_child(platform)
	plate._on_body_entered(floor)
	plate._on_body_entered(platform)

	_expect(not plate.is_mechanism_active(), "static support geometry cannot press a pressure plate")
	_expect(is_equal_approx(plate.get_mechanism_value(), 0.0), "two static bodies no longer produce a phantom 140 kg load")
	_expect(int(plate.get_mechanism_packet().get("occupants", -1)) == 0, "rejected static bodies never enter the occupant ledger")
	_expect(plate.rejected_body_entry_count == 2, "pressure plate records both rejected support bodies for debugging")

	var actor := CharacterBody3D.new()
	actor.name = "SyntheticGrace"
	actor.add_to_group("player")
	fixture.add_child(actor)
	plate._on_body_entered(actor)
	_expect(plate.is_mechanism_active(), "a CharacterBody3D actor still presses the plate")
	_expect(is_equal_approx(plate.get_mechanism_value(), 70.0), "actor fallback mass remains available after static filtering")
	plate._on_body_exited(actor)
	_expect(not plate.is_mechanism_active(), "plate releases after its movable actor exits")

	plate.queue_free()
	floor.queue_free()
	platform.queue_free()
	actor.queue_free()
	await get_tree().process_frame


func _test_selector_and_router() -> void:
	var control := MechanismManualSource.new()
	control.name = "RouterControl"
	control.mechanism_id = "router_control"
	fixture.add_child(control)

	var input := _make_value_source(
		"RouterInput",
		"router_input",
		0.0,
		10.0,
		"power"
	)
	var selector := MechanismSelectorSource.new()
	selector.name = "RouterSelector"
	selector.mechanism_id = "router_selector"
	selector.selection_count = 2
	selector.selection_labels = Array[String](["LEFT", "RIGHT"])
	fixture.add_child(selector)
	selector.bind_source(control)

	var router := MechanismRouterNode.new()
	router.name = "TwoWayRouter"
	router.mechanism_id = "two_way_router"
	router.channel_count = 2
	router.channel_labels = Array[String](["LEFT", "RIGHT"])
	fixture.add_child(router)
	router.bind_input(input)
	router.bind_selector(selector)
	await _wait_frames(3)

	var left: MechanismManualSource = router.get_channel_output(0)
	var right: MechanismManualSource = router.get_channel_output(1)
	_expect(left != null and right != null, "router creates two ordinary mechanism channel outputs")
	if left == null or right == null:
		return

	input.set_mechanism_state(true, 6.0, {"test": "router_power_on"})
	_expect(left.active and not right.active, "initial selector routes active input only to the left channel")
	_expect(is_equal_approx(left.get_mechanism_value(), 6.0), "selected router channel preserves numeric value")
	_expect(is_equal_approx(right.get_mechanism_value(), 0.0), "unselected router channel clears its value")

	_pulse_source(control)
	_expect(selector.selection_index == 1, "selector advances on a rising control edge")
	_expect(not left.active and right.active, "changing selection transfers live power between channels")
	_expect(is_equal_approx(right.get_mechanism_value(), 6.0), "newly selected channel receives the existing input value immediately")

	input.set_mechanism_state(true, 8.0, {"test": "router_value_changed"})
	_expect(is_equal_approx(right.get_mechanism_value(), 8.0), "router forwards value changes without requiring a Boolean edge")
	selector.set_selection(0, {"test": "router_select_left"})
	_expect(left.active and not right.active, "direct selector assignment reroutes the signal deterministically")
	_expect(is_equal_approx(left.get_mechanism_value(), 8.0), "rerouted channel preserves the latest value")

	control.queue_free()
	input.queue_free()
	selector.queue_free()
	router.queue_free()
	await get_tree().process_frame


func _test_multiplexer() -> void:
	var selector := MechanismSelectorSource.new()
	selector.name = "MultiplexerSelector"
	selector.mechanism_id = "multiplexer_selector"
	selector.selection_count = 3
	selector.selection_labels = Array[String](["LOW", "MIDDLE", "HIGH"])
	fixture.add_child(selector)

	var low := _make_constant_source("LowInput", "low_input", 0.0)
	var middle := _make_constant_source("MiddleInput", "middle_input", 1.0)
	var high := _make_constant_source("HighInput", "high_input", 2.0)
	var multiplexer := MechanismMultiplexerNode.new()
	multiplexer.name = "ThreeInputMultiplexer"
	multiplexer.mechanism_id = "three_input_multiplexer"
	multiplexer.selector_source_id = selector.get_mechanism_id()
	multiplexer.input_source_ids = Array[String]([
		low.get_mechanism_id(),
		middle.get_mechanism_id(),
		high.get_mechanism_id(),
	])
	fixture.add_child(multiplexer)
	multiplexer.bind_selector(selector)
	multiplexer.bind_input(low)
	multiplexer.bind_input(middle)
	multiplexer.bind_input(high)
	await _wait_frames(3)

	_expect(multiplexer.active, "multiplexer mirrors the selected active input")
	_expect(is_equal_approx(multiplexer.get_mechanism_value(), 0.0), "multiplexer begins with the low value")
	selector.set_selection(1, {"test": "select_middle"})
	_expect(multiplexer.selected_input_source_id == middle.get_mechanism_id(), "selector chooses the authored middle input")
	_expect(is_equal_approx(multiplexer.get_mechanism_value(), 1.0), "middle selection forwards its numeric value")

	middle.set_mechanism_state(true, 1.5, {"test": "middle_value_changed"})
	_expect(is_equal_approx(multiplexer.get_mechanism_value(), 1.5), "selected input changes propagate through the multiplexer")
	selector.set_selection(2, {"test": "select_high"})
	_expect(multiplexer.selected_input_source_id == high.get_mechanism_id(), "selector chooses the authored high input")
	_expect(is_equal_approx(multiplexer.get_mechanism_value(), 2.0), "high selection forwards the high value")

	selector.reset_target()
	multiplexer.reset_target()
	_expect(selector.selection_index == 0, "selector reset restores its authored channel")
	_expect(is_equal_approx(multiplexer.get_mechanism_value(), 0.0), "multiplexer reset returns to the low input")

	selector.queue_free()
	low.queue_free()
	middle.queue_free()
	high.queue_free()
	multiplexer.queue_free()
	await get_tree().process_frame


func _test_production_routing_wing() -> void:
	var lab: Node = LabScene.instantiate()
	_expect(lab != null, "production mechanism laboratory instantiates")
	if lab == null:
		return
	lab.name = "MechanismRoutingLabFixture"
	add_child(lab)
	await _wait_physics_frames(14)
	await _wait_frames(4)

	_expect(lab is MechanismNetworkLabRouting, "production laboratory installs the routing runtime")
	var plate_count: int = 0
	for candidate: Node in get_tree().get_nodes_in_group("mechanism_inputs"):
		if not lab.is_ancestor_of(candidate) or not candidate is PressurePlateSwitch:
			continue
		var plate := candidate as PressurePlateSwitch
		plate_count += 1
		_expect(not plate.is_mechanism_active(), plate.name + " begins released instead of phantom-pressed")
		_expect(is_equal_approx(plate.get_mechanism_value(), 0.0), plate.name + " begins at zero kilograms")
	_expect(plate_count >= 6, "production lab exposes all expected pressure plates to the static-load regression")

	var routing_plate: PressurePlateSwitch = lab.get_node_or_null(
		"Mechanisms/RoutingPowerPlate"
	) as PressurePlateSwitch
	var route_selector: MechanismSelectorSource = lab.get_node_or_null(
		"SignalNetwork/TwoWayRouteSelector"
	) as MechanismSelectorSource
	var left_gate: MechanismSlidingGate = lab.get_node_or_null(
		"Mechanisms/LeftRouteGate"
	) as MechanismSlidingGate
	var right_gate: MechanismSlidingGate = lab.get_node_or_null(
		"Mechanisms/RightRouteGate"
	) as MechanismSlidingGate
	_expect(
		routing_plate != null
		and route_selector != null
		and left_gate != null
		and right_gate != null,
		"production two-way routing station is complete"
	)
	if (
		routing_plate != null
		and route_selector != null
		and left_gate != null
		and right_gate != null
	):
		routing_plate.set_simulated_mass_kg(3.0)
		await _wait_frames(2)
		_expect(left_gate.active and not right_gate.active, "production router initially powers the left gate")
		route_selector.set_selection(1, {"test": "production_route_right"})
		await _wait_frames(2)
		_expect(not left_gate.active and right_gate.active, "production router transfers held plate power to the right gate")

	var floor_selector: MechanismSelectorSource = lab.get_node_or_null(
		"SignalNetwork/LiftFloorSelector"
	) as MechanismSelectorSource
	var multiplexer: MechanismMultiplexerNode = lab.get_node_or_null(
		"SignalNetwork/LiftFloorMultiplexer"
	) as MechanismMultiplexerNode
	var lift: MechanismValueElevator = lab.get_node_or_null(
		"Mechanisms/MultiplexerLift"
	) as MechanismValueElevator
	_expect(
		floor_selector != null and multiplexer != null and lift != null,
		"production three-stop multiplexer station is complete"
	)
	if floor_selector != null and multiplexer != null and lift != null:
		lift.transition_seconds = 0.01
		floor_selector.set_selection(1, {"test": "production_middle_floor"})
		await _wait_frames(3)
		_expect(is_equal_approx(multiplexer.get_mechanism_value(), 1.0), "production multiplexer selects the middle floor value")
		_expect(is_equal_approx(lift.target_fraction, 0.5), "middle floor sends the lift to half height")
		floor_selector.set_selection(2, {"test": "production_high_floor"})
		await _wait_frames(3)
		_expect(is_equal_approx(lift.target_fraction, 1.0), "high floor sends the lift to full height")

	lab.call("reset_lab")
	await _wait_physics_frames(4)
	await _wait_frames(3)
	if route_selector != null:
		_expect(route_selector.selection_index == 0, "lab reset restores the left route")
	if left_gate != null and right_gate != null:
		_expect(not left_gate.active and not right_gate.active, "lab reset clears both routed gates")
	if floor_selector != null:
		_expect(floor_selector.selection_index == 0, "lab reset restores the low floor")
	if lift != null:
		_expect(is_equal_approx(lift.current_fraction, 0.0), "lab reset lowers the multiplexer lift")

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
	_expect(bool(debug.get("routing_lab", false)), "lab debug data advertises routing support")
	_expect(int(debug.get("routing_station_count", 0)) == 2, "lab debug data reports both routing stations")

	lab.queue_free()
	await get_tree().process_frame


func _make_value_source(
	node_name: String,
	mechanism_id: String,
	minimum: float,
	maximum: float,
	unit: String
) -> MechanismManualSource:
	var source := MechanismManualSource.new()
	source.name = node_name
	source.mechanism_id = mechanism_id
	source.display_name = node_name
	source.mirror_active_to_value = false
	source.initial_active = false
	source.initial_value = minimum
	source.minimum_value = minimum
	source.maximum_value = maximum
	source.value_unit = unit
	fixture.add_child(source)
	return source


func _make_constant_source(
	node_name: String,
	mechanism_id: String,
	constant_value: float
) -> MechanismManualSource:
	var source := MechanismManualSource.new()
	source.name = node_name
	source.mechanism_id = mechanism_id
	source.display_name = node_name
	source.mirror_active_to_value = false
	source.initial_active = true
	source.initial_value = constant_value
	source.minimum_value = 0.0
	source.maximum_value = 2.0
	source.value_unit = "floor"
	fixture.add_child(source)
	source.set_mechanism_state(true, constant_value, {
		"test": "constant_input",
	}, true)
	return source


func _pulse_source(source: MechanismManualSource) -> void:
	source.set_input_active(true, {"test": "pulse_on"})
	source.set_input_active(false, {"test": "pulse_off"})


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
	push_error("MECHANISM_ROUTING_SMOKE_TEST: " + label)


func _finish() -> void:
	if failures.is_empty():
		print("MECHANISM_ROUTING_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("MECHANISM_ROUTING_SMOKE_TEST: " + failure)
	get_tree().quit(1)
