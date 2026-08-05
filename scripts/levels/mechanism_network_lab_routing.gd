extends "res://scripts/levels/mechanism_network_lab_soul_weights.gd"
class_name MechanismNetworkLabRouting

const RoutingWeightBlockScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_weight_block.tscn"
)
const RoutingElevatorScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_value_elevator.tscn"
)

var routing_selectors: Array[MechanismSelectorSource] = []
var routing_routers: Array[MechanismRouterNode] = []
var routing_multiplexers: Array[MechanismMultiplexerNode] = []
var routing_constant_sources: Array[MechanismManualSource] = []
var routing_output_adapters: Array[MechanismOutputAdapter] = []
var routing_presented_nodes: Array[Node] = []
var routing_labels: Dictionary = {}
var routing_instruction: Label3D


func _ready() -> void:
	super._ready()
	_build_routing_extension_environment()
	_build_two_way_power_junction(253.0)
	_build_three_stop_lift(276.0)
	_bind_routing_presentation_signals()
	_configure_label_visibility_budget(self)
	GameState.set_objective(
		"Explore Boolean logic, memory, values, and routing. In the routing wing, selectors decide where active signals and quantities travel. F8 resets everything."
	)
	_show_message(
		"Signal Routing wing online. A selector can now redirect one source or choose among several value inputs."
	)
	call_deferred("_refresh_all_presentations")


func _build_routing_extension_environment() -> void:
	_create_static_box(
		"RoutingWingFloor",
		Vector3(0.0, -0.5, 268.0),
		Vector3(24.0, 1.0, 60.0),
		Color(0.13, 0.12, 0.2)
	)
	_create_static_box(
		"RoutingWingLeftWall",
		Vector3(-12.5, 2.0, 268.0),
		Vector3(1.0, 5.0, 60.0),
		Color(0.08, 0.07, 0.14)
	)
	_create_static_box(
		"RoutingWingRightWall",
		Vector3(12.5, 2.0, 268.0),
		Vector3(1.0, 5.0, 60.0),
		Color(0.08, 0.07, 0.14)
	)
	for divider_z: float in [264.0, 287.0]:
		_create_static_box(
			"RoutingDividerLeft" + str(int(divider_z)),
			Vector3(-8.0, 1.5, divider_z),
			Vector3(7.0, 3.0, 0.5),
			Color(0.2, 0.16, 0.29)
		)
		_create_static_box(
			"RoutingDividerRight" + str(int(divider_z)),
			Vector3(8.0, 1.5, divider_z),
			Vector3(7.0, 3.0, 0.5),
			Color(0.2, 0.16, 0.29)
		)

	routing_instruction = _create_station_label(
		"SIGNAL ROUTING WING\nSelectors redirect live Boolean and numeric signals",
		Vector3(0.0, 5.1, 245.0),
		Color(0.85, 0.55, 1.0)
	)


func _build_two_way_power_junction(z: float) -> void:
	_create_station_platform(z, "12 • TWO-WAY POWER JUNCTION")
	var route_lever: MechanismToggleLever = _spawn_lever(
		"RouteSelectorLever",
		"route_selector_control",
		"CHANGE ROUTE",
		Vector3(-5.2, 0.0, z),
		true,
		0.12
	)
	var selector: MechanismSelectorSource = _create_selector(
		"TwoWayRouteSelector",
		"two_way_route_selector",
		"ROUTE SELECTOR",
		2,
		["LEFT", "RIGHT"],
		[route_lever]
	)
	var plate: PressurePlateSwitch = _spawn_pressure_plate(
		"RoutingPowerPlate",
		"routing_power_plate",
		Vector3(0.0, 0.0, z)
	)
	plate.maximum_reported_mass_kg = 10.0
	_spawn_routing_weight(
		"RoutingWeight3kg",
		Vector3(5.0, 0.75, z),
		3.0,
		Vector3(1.15, 1.15, 1.15),
		Color(0.58, 0.32, 0.78),
		"Three Kilogram Routing Weight"
	)

	var router: MechanismRouterNode = _create_router(
		"TwoWayPowerRouter",
		"two_way_power_router",
		"POWER ROUTER",
		2,
		["LEFT", "RIGHT"],
		plate,
		selector
	)
	_create_routing_label(selector, Vector3(-3.2, 3.25, z + 2.1))
	_create_routing_label(router, Vector3(3.2, 3.25, z + 2.1))

	var left_indicator: MechanismIndicator = _spawn_indicator(
		"LeftRouteIndicator",
		"LEFT ROUTE",
		Vector3(-4.2, 0.0, z + 4.1)
	)
	var right_indicator: MechanismIndicator = _spawn_indicator(
		"RightRouteIndicator",
		"RIGHT ROUTE",
		Vector3(4.2, 0.0, z + 4.1)
	)
	var left_gate: MechanismSlidingGate = _spawn_gate(
		"LeftRouteGate",
		"LEFT ROUTE GATE",
		Vector3(-4.2, 0.0, z + 8.0)
	)
	var right_gate: MechanismSlidingGate = _spawn_gate(
		"RightRouteGate",
		"RIGHT ROUTE GATE",
		Vector3(4.2, 0.0, z + 8.0)
	)
	var left_channel: MechanismManualSource = router.get_channel_output(0)
	var right_channel: MechanismManualSource = router.get_channel_output(1)
	for adapter: MechanismOutputAdapter in [
		_wire_output("LeftRouteIndicatorOutput", left_channel, left_indicator),
		_wire_output("LeftRouteGateOutput", left_channel, left_gate),
		_wire_output("RightRouteIndicatorOutput", right_channel, right_indicator),
		_wire_output("RightRouteGateOutput", right_channel, right_gate),
	]:
		routing_output_adapters.append(adapter)

	var instruction: Label3D = _create_station_label(
		"Place the Soul weight on the plate, then change route while power remains active",
		Vector3(0.0, 2.25, z - 3.4),
		Color(0.82, 0.72, 1.0)
	)
	instruction.font_size = 19
	station_states["two_way_router"] = {
		"selector": selector,
		"router": router,
		"inputs": [route_lever, plate],
		"outputs": [left_indicator, right_indicator, left_gate, right_gate],
	}


func _build_three_stop_lift(z: float) -> void:
	_create_station_platform(z, "13 • MULTIPLEXER LIFT: LOW / MIDDLE / HIGH")
	var floor_lever: MechanismToggleLever = _spawn_lever(
		"LiftFloorSelectorLever",
		"lift_floor_selector_control",
		"NEXT FLOOR",
		Vector3(-5.2, 0.0, z),
		true,
		0.12
	)
	var selector: MechanismSelectorSource = _create_selector(
		"LiftFloorSelector",
		"lift_floor_selector",
		"LIFT FLOOR",
		3,
		["LOW", "MIDDLE", "HIGH"],
		[floor_lever]
	)

	var low_source: MechanismManualSource = _create_constant_value_source(
		"LowFloorValue",
		"low_floor_value",
		"LOW FLOOR",
		0.0,
		0.0,
		2.0,
		"floor"
	)
	var middle_source: MechanismManualSource = _create_constant_value_source(
		"MiddleFloorValue",
		"middle_floor_value",
		"MIDDLE FLOOR",
		1.0,
		0.0,
		2.0,
		"floor"
	)
	var high_source: MechanismManualSource = _create_constant_value_source(
		"HighFloorValue",
		"high_floor_value",
		"HIGH FLOOR",
		2.0,
		0.0,
		2.0,
		"floor"
	)
	var multiplexer: MechanismMultiplexerNode = _create_multiplexer(
		"LiftFloorMultiplexer",
		"lift_floor_multiplexer",
		"FLOOR MULTIPLEXER",
		selector,
		[low_source, middle_source, high_source]
	)
	_create_routing_label(selector, Vector3(-3.2, 3.25, z + 2.1))
	_create_routing_label(multiplexer, Vector3(3.2, 3.25, z + 2.1))

	_create_static_box(
		"RoutingLiftLeftRail",
		Vector3(1.5, 3.0, z + 2.5),
		Vector3(0.25, 6.5, 0.25),
		Color(0.42, 0.2, 0.62)
	)
	_create_static_box(
		"RoutingLiftRightRail",
		Vector3(7.0, 3.0, z + 2.5),
		Vector3(0.25, 6.5, 0.25),
		Color(0.42, 0.2, 0.62)
	)
	var elevator: MechanismValueElevator = _spawn_routing_elevator(
		"MultiplexerLift",
		"THREE-STOP LIFT",
		Vector3(4.2, 0.25, z + 2.5)
	)
	elevator.input_minimum = 0.0
	elevator.input_maximum = 2.0
	elevator.movement_offset = Vector3(0.0, 6.0, 0.0)
	var lift_adapter: MechanismOutputAdapter = _wire_value_output(
		"MultiplexerLiftOutput",
		multiplexer,
		elevator
	)
	routing_output_adapters.append(lift_adapter)

	var instruction: Label3D = _create_station_label(
		"Each pulse changes the selector. The multiplexer chooses one stored floor value for the lift.",
		Vector3(0.0, 2.25, z - 3.4),
		Color(0.82, 0.72, 1.0)
	)
	instruction.font_size = 19
	station_states["three_stop_multiplexer"] = {
		"selector": selector,
		"multiplexer": multiplexer,
		"inputs": [floor_lever, low_source, middle_source, high_source],
		"outputs": [elevator],
	}


func _create_selector(
	node_name: String,
	mechanism_id: String,
	display_name_value: String,
	selection_count_value: int,
	labels: Array[String],
	control_sources: Array
) -> MechanismSelectorSource:
	var selector := MechanismSelectorSource.new()
	selector.name = node_name
	selector.mechanism_id = mechanism_id
	selector.display_name = display_name_value
	selector.selection_count = selection_count_value
	selector.selection_labels = labels.duplicate()
	selector.initial_selection = 0
	selector.wraps_selection = true
	network_root.add_child(selector)
	for source_value: Variant in control_sources:
		if source_value is Node:
			selector.bind_source(source_value as Node)
	routing_selectors.append(selector)
	routing_presented_nodes.append(selector)
	return selector


func _create_router(
	node_name: String,
	mechanism_id: String,
	display_name_value: String,
	channel_count_value: int,
	labels: Array[String],
	input_source: Node,
	selector_source: MechanismSelectorSource
) -> MechanismRouterNode:
	var router := MechanismRouterNode.new()
	router.name = node_name
	router.mechanism_id = mechanism_id
	router.display_name = display_name_value
	router.channel_count = channel_count_value
	router.channel_labels = labels.duplicate()
	network_root.add_child(router)
	router.bind_input(input_source)
	router.bind_selector(selector_source)
	routing_routers.append(router)
	routing_presented_nodes.append(router)
	return router


func _create_multiplexer(
	node_name: String,
	mechanism_id: String,
	display_name_value: String,
	selector_source: MechanismSelectorSource,
	input_sources: Array
) -> MechanismMultiplexerNode:
	var multiplexer := MechanismMultiplexerNode.new()
	multiplexer.name = node_name
	multiplexer.mechanism_id = mechanism_id
	multiplexer.display_name = display_name_value
	multiplexer.selector_source_id = selector_source.get_mechanism_id()
	var authored_input_ids: Array[String] = []
	for source_value: Variant in input_sources:
		if source_value is Node:
			authored_input_ids.append(
				str((source_value as Node).call("get_mechanism_id"))
			)
	multiplexer.input_source_ids = authored_input_ids
	network_root.add_child(multiplexer)
	multiplexer.bind_selector(selector_source)
	for source_value: Variant in input_sources:
		if source_value is Node:
			multiplexer.bind_input(source_value as Node)
	routing_multiplexers.append(multiplexer)
	routing_presented_nodes.append(multiplexer)
	return multiplexer


func _create_constant_value_source(
	node_name: String,
	mechanism_id: String,
	display_name_value: String,
	constant_value: float,
	minimum: float,
	maximum: float,
	unit: String
) -> MechanismManualSource:
	var source := MechanismManualSource.new()
	source.name = node_name
	source.mechanism_id = mechanism_id
	source.display_name = display_name_value
	source.mirror_active_to_value = false
	source.initial_active = true
	source.initial_value = constant_value
	source.minimum_value = minimum
	source.maximum_value = maximum
	source.value_unit = unit
	network_root.add_child(source)
	source.set_mechanism_state(true, constant_value, {
		"reason": "constant_routing_value",
		"constant_value": constant_value,
	}, true)
	routing_constant_sources.append(source)
	return source


func _spawn_routing_weight(
	node_name: String,
	position_value: Vector3,
	mass_kg: float,
	size_value: Vector3,
	color: Color,
	label: String
) -> MechanismWeightBlock:
	var block: MechanismWeightBlock = (
		RoutingWeightBlockScene.instantiate() as MechanismWeightBlock
	)
	block.name = node_name
	block.position = position_value
	block.configure_weight_block(mass_kg, size_value, color, label)
	mechanisms_root.add_child(block)
	return block


func _spawn_routing_elevator(
	node_name: String,
	display_name_value: String,
	position_value: Vector3
) -> MechanismValueElevator:
	var elevator: MechanismValueElevator = (
		RoutingElevatorScene.instantiate() as MechanismValueElevator
	)
	elevator.name = node_name
	elevator.display_name = display_name_value
	elevator.position = position_value
	mechanisms_root.add_child(elevator)
	output_nodes.append(elevator)
	return elevator


func _create_routing_label(node: Node, position_value: Vector3) -> Label3D:
	var label: Label3D = _create_station_label(
		str(node.get("display_name")),
		position_value,
		Color(0.84, 0.52, 1.0)
	)
	label.font_size = 20
	routing_labels[node.get_instance_id()] = label
	return label


func _bind_routing_presentation_signals() -> void:
	for node: Node in routing_presented_nodes:
		if node == null or not is_instance_valid(node):
			continue
		var callback := Callable(
			self,
			"_on_routing_signal_changed"
		).bind(node)
		if not node.mechanism_signal_changed.is_connected(callback):
			node.mechanism_signal_changed.connect(callback)


func _on_routing_signal_changed(
	_mechanism_id: String,
	_active: bool,
	_packet: Dictionary,
	node: Node
) -> void:
	_refresh_routing_presentation(node)
	_refresh_network_readout()


func _refresh_all_presentations() -> void:
	super._refresh_all_presentations()
	for node: Node in routing_presented_nodes:
		_refresh_routing_presentation(node)
	_refresh_network_readout()


func _refresh_routing_presentation(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	var label: Label3D = routing_labels.get(node.get_instance_id()) as Label3D
	if label == null or not is_instance_valid(label):
		return

	var detail: String = ""
	var state_active: bool = bool(node.call("is_mechanism_active"))
	if node is MechanismSelectorSource:
		var selector := node as MechanismSelectorSource
		detail = (
			selector.get_selection_label(selector.selection_index)
			+ " • "
			+ str(selector.selection_index + 1)
			+ "/"
			+ str(selector.selection_count)
		)
	elif node is MechanismRouterNode:
		var router := node as MechanismRouterNode
		detail = (
			router.get_channel_label(router.selected_channel_index)
			+ " • input "
			+ ("ON" if router.active else "OFF")
		)
	elif node is MechanismMultiplexerNode:
		var multiplexer := node as MechanismMultiplexerNode
		detail = (
			multiplexer.selected_input_source_id.to_upper()
			+ " • value "
			+ str(snappedf(multiplexer.get_mechanism_value(), 0.1))
		)
	else:
		detail = "signal"

	var next_text: String = (
		str(node.get("display_name"))
		+ "\n"
		+ detail
		+ " → "
		+ ("ON" if state_active else "OFF")
	)
	var next_color: Color = (
		Color(0.45, 1.0, 0.68)
		if state_active
		else Color(0.84, 0.52, 1.0)
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
	for node: Node in routing_presented_nodes:
		if (
			node != null
			and is_instance_valid(node)
			and bool(node.call("is_mechanism_active"))
		):
			active_routes += 1
	var next_text: String = (
		"PUZZLE SIGNAL NETWORK\n"
		+ "Inputs " + str(input_nodes.size() - 1)
		+ "   Logic " + str(active_logic) + "/" + str(logic_nodes.size())
		+ "   Values " + str(active_comparators) + "/" + str(value_comparators.size())
		+ "   Routes " + str(active_routes) + "/" + str(routing_presented_nodes.size())
		+ "   Outputs " + str(output_nodes.size())
		+ "\nBoolean • memory • quantities • selectors • routers • multiplexers • F8 resets lab"
	)
	if readout_text_cache == next_text:
		presentation_skip_count += 1
		return
	readout_text_cache = next_text
	debug_readout.text = next_text
	presentation_write_count += 1


func reset_lab() -> void:
	super.reset_lab()
	for source: MechanismManualSource in routing_constant_sources:
		if source != null and is_instance_valid(source):
			source.reset_target()
	for selector: MechanismSelectorSource in routing_selectors:
		if selector != null and is_instance_valid(selector):
			selector.reset_target()
	for router: MechanismRouterNode in routing_routers:
		if router != null and is_instance_valid(router):
			router.reset_target()
	for multiplexer: MechanismMultiplexerNode in routing_multiplexers:
		if multiplexer != null and is_instance_valid(multiplexer):
			multiplexer.reset_target()
	for adapter: MechanismOutputAdapter in routing_output_adapters:
		if adapter != null and is_instance_valid(adapter):
			adapter.apply_target_state()
	call_deferred("_refresh_all_presentations")


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	var selector_data: Dictionary = {}
	for selector: MechanismSelectorSource in routing_selectors:
		if selector != null and is_instance_valid(selector):
			selector_data[selector.get_mechanism_id()] = selector.get_debug_data()
	var router_data: Dictionary = {}
	for router: MechanismRouterNode in routing_routers:
		if router != null and is_instance_valid(router):
			router_data[router.get_mechanism_id()] = router.get_debug_data()
	var multiplexer_data: Dictionary = {}
	for multiplexer: MechanismMultiplexerNode in routing_multiplexers:
		if multiplexer != null and is_instance_valid(multiplexer):
			multiplexer_data[multiplexer.get_mechanism_id()] = multiplexer.get_debug_data()
	data["routing_lab"] = true
	data["routing_selectors"] = selector_data
	data["routing_routers"] = router_data
	data["routing_multiplexers"] = multiplexer_data
	data["routing_station_count"] = 2
	return data
