extends Node3D
class_name MechanismNetworkLab

const PressurePlateScene: PackedScene = preload(
	"res://scenes/mechanisms/pressure_plate_switch.tscn"
)
const LeverScene: PackedScene = preload(
	"res://scenes/mechanisms/mechanism_toggle_lever.tscn"
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

@export_range(0.03, 0.5, 0.01) var debug_refresh_seconds: float = 0.1

var mechanisms_root: Node3D
var network_root: Node
var debug_readout: Label3D
var player: Node3D
var initial_player_transform: Transform3D
var reset_in_progress: bool = false
var refresh_remaining: float = 0.0

var input_nodes: Array[Node] = []
var logic_nodes: Array[MechanismLogicNode] = []
var output_adapters: Array[MechanismOutputAdapter] = []
var output_nodes: Array[Node] = []
var logic_labels: Dictionary = {}
var station_states: Dictionary = {}
var reset_lever: MechanismToggleLever


func _ready() -> void:
	add_to_group("mechanism_network_labs")
	add_to_group("debuggable")
	player = get_node_or_null("Player") as Node3D
	if player != null:
		player.add_to_group("player")
		initial_player_transform = player.transform
	_build_environment()
	_build_network_roots()
	_build_reset_station()
	_build_pressure_plate_station(-2.0)
	_build_and_station(20.0)
	_build_or_not_station(43.0)
	_build_timer_station(67.0)
	_build_counter_latch_station(91.0)
	GameState.set_objective(
		"Explore the mechanism lab: weight, AND, OR/NOT, timer, then counter + latch. F8 resets everything."
	)
	_show_message(
		"Mechanism Network v1 online. Signals may come from physics, interaction, or elemental payloads."
	)
	call_deferred("_refresh_all_presentations")


func _process(delta: float) -> void:
	refresh_remaining -= delta
	if refresh_remaining > 0.0:
		return
	refresh_remaining = maxf(debug_refresh_seconds, 0.03)
	_refresh_all_presentations()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_F8:
			reset_lab()
			get_viewport().set_input_as_handled()


func _build_network_roots() -> void:
	mechanisms_root = Node3D.new()
	mechanisms_root.name = "Mechanisms"
	add_child(mechanisms_root)
	network_root = Node.new()
	network_root.name = "SignalNetwork"
	add_child(network_root)

	debug_readout = Label3D.new()
	debug_readout.name = "NetworkReadout"
	debug_readout.position = Vector3(0.0, 5.5, -10.5)
	debug_readout.font_size = 24
	debug_readout.pixel_size = 0.006
	debug_readout.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	debug_readout.outline_size = 8
	debug_readout.modulate = Color(0.72, 0.95, 1.0)
	mechanisms_root.add_child(debug_readout)


func _build_reset_station() -> void:
	reset_lever = _spawn_lever(
		"ResetLever",
		"lab_reset",
		"RESET NETWORK",
		Vector3(7.5, 0.0, -8.0),
		true,
		0.12
	)
	var callback := Callable(self, "_on_reset_lever_toggled")
	if not reset_lever.lever_toggled.is_connected(callback):
		reset_lever.lever_toggled.connect(callback)
	_create_station_label(
		"MECHANISM NETWORK LAB\nF8 or reset lever restores every station",
		Vector3(0.0, 5.0, -8.0),
		Color(0.55, 0.9, 1.0)
	)


func _build_pressure_plate_station(z: float) -> void:
	_create_station_platform(z, "01 • WEIGHT SIGNAL")
	var plate: PressurePlateSwitch = _spawn_pressure_plate(
		"WeightPlate",
		"weight_plate",
		Vector3(-4.2, 0.0, z)
	)
	_spawn_weight_crate("WeightCrate", Vector3(0.0, 1.0, z))
	var indicator: MechanismIndicator = _spawn_indicator(
		"WeightIndicator",
		"WEIGHT SIGNAL",
		Vector3(3.8, 0.0, z)
	)
	var gate: MechanismSlidingGate = _spawn_gate(
		"WeightGate",
		"WEIGHT GATE",
		Vector3(0.0, 0.0, z + 8.0)
	)
	_wire_output("WeightIndicatorOutput", plate, indicator)
	_wire_output("WeightGateOutput", plate, gate)
	station_states["weight"] = {
		"inputs": [plate],
		"outputs": [indicator, gate],
	}


func _build_and_station(z: float) -> void:
	_create_station_platform(z, "02 • PLATE AND FIRE")
	var plate: PressurePlateSwitch = _spawn_pressure_plate(
		"AndPlate",
		"and_plate",
		Vector3(-4.5, 0.0, z)
	)
	_spawn_weight_crate("AndCrate", Vector3(-1.5, 1.0, z - 1.0))
	var sensor: MechanismElementSensor = _spawn_sensor(
		"AndFireSensor",
		"and_fire",
		"FIRE INPUT",
		Vector3(4.5, 0.0, z)
	)
	var and_logic: MechanismLogicNode = _create_logic(
		"PlateAndFire",
		"plate_and_fire",
		"PLATE AND FIRE",
		MechanismLogicNode.Operation.AND,
		[plate, sensor]
	)
	_create_logic_label(and_logic, Vector3(0.0, 3.2, z + 2.2))
	var indicator: MechanismIndicator = _spawn_indicator(
		"AndIndicator",
		"AND OUTPUT",
		Vector3(0.0, 0.0, z + 4.2)
	)
	var gate: MechanismSlidingGate = _spawn_gate(
		"AndGate",
		"AND GATE",
		Vector3(0.0, 0.0, z + 8.0)
	)
	_wire_output("AndIndicatorOutput", and_logic, indicator)
	_wire_output("AndGateOutput", and_logic, gate)
	station_states["and"] = {
		"logic": and_logic,
		"inputs": [plate, sensor],
		"outputs": [indicator, gate],
	}


func _build_or_not_station(z: float) -> void:
	_create_station_platform(z, "03 • OR + NOT")
	var lever: MechanismToggleLever = _spawn_lever(
		"OrLever",
		"or_lever",
		"OR LEVER",
		Vector3(-4.5, 0.0, z),
		false
	)
	var sensor: MechanismElementSensor = _spawn_sensor(
		"OrFireSensor",
		"or_fire",
		"OR FIRE",
		Vector3(4.5, 0.0, z)
	)
	var or_logic: MechanismLogicNode = _create_logic(
		"LeverOrFire",
		"lever_or_fire",
		"LEVER OR FIRE",
		MechanismLogicNode.Operation.OR,
		[lever, sensor]
	)
	var not_logic: MechanismLogicNode = _create_logic(
		"NotLever",
		"not_lever",
		"NOT LEVER",
		MechanismLogicNode.Operation.NOT,
		[lever]
	)
	_create_logic_label(or_logic, Vector3(-1.8, 3.2, z + 2.0))
	_create_logic_label(not_logic, Vector3(2.1, 3.2, z + 2.0))
	var bridge: MechanismBridgeOutput = _spawn_bridge(
		"OrBridge",
		"OR BRIDGE",
		Vector3(0.0, 0.0, z + 7.0)
	)
	bridge.rotation_degrees.y = 90.0
	var or_indicator: MechanismIndicator = _spawn_indicator(
		"OrIndicator",
		"OR OUTPUT",
		Vector3(-3.0, 0.0, z + 4.0)
	)
	var not_indicator: MechanismIndicator = _spawn_indicator(
		"NotIndicator",
		"NOT OUTPUT",
		Vector3(3.0, 0.0, z + 4.0)
	)
	_wire_output("OrBridgeOutput", or_logic, bridge)
	_wire_output("OrIndicatorOutput", or_logic, or_indicator)
	_wire_output("NotIndicatorOutput", not_logic, not_indicator)
	station_states["or_not"] = {
		"logic": [or_logic, not_logic],
		"inputs": [lever, sensor],
		"outputs": [bridge, or_indicator, not_indicator],
	}


func _build_timer_station(z: float) -> void:
	_create_station_platform(z, "04 • TIMED PULSE")
	var lever: MechanismToggleLever = _spawn_lever(
		"TimerLever",
		"timer_lever",
		"START 5 SECOND TIMER",
		Vector3(-4.0, 0.0, z),
		true,
		0.12
	)
	var timer_logic: MechanismLogicNode = _create_logic(
		"FiveSecondTimer",
		"five_second_timer",
		"FIVE SECOND TIMER",
		MechanismLogicNode.Operation.TIMER,
		[lever]
	)
	timer_logic.timer_seconds = 5.0
	_create_logic_label(timer_logic, Vector3(0.0, 3.2, z + 2.0))
	var indicator: MechanismIndicator = _spawn_indicator(
		"TimerIndicator",
		"TIMER OUTPUT",
		Vector3(3.5, 0.0, z)
	)
	var gate: MechanismSlidingGate = _spawn_gate(
		"TimerGate",
		"TIMED GATE",
		Vector3(0.0, 0.0, z + 8.0)
	)
	_wire_output("TimerIndicatorOutput", timer_logic, indicator)
	_wire_output("TimerGateOutput", timer_logic, gate)
	station_states["timer"] = {
		"logic": timer_logic,
		"inputs": [lever],
		"outputs": [indicator, gate],
	}


func _build_counter_latch_station(z: float) -> void:
	_create_station_platform(z, "05 • COUNTER + LATCH")
	var bell: MechanismToggleLever = _spawn_lever(
		"CounterBell",
		"counter_bell",
		"RING THREE TIMES",
		Vector3(-4.5, 0.0, z),
		true,
		0.1
	)
	var sensor: MechanismElementSensor = _spawn_sensor(
		"LatchFireSensor",
		"latch_fire",
		"LATCH FIRE",
		Vector3(4.5, 0.0, z)
	)
	sensor.latch_when_activated = false
	sensor.active_seconds = 0.25
	var counter: MechanismLogicNode = _create_logic(
		"ThreeRingCounter",
		"three_ring_counter",
		"THREE RING COUNTER",
		MechanismLogicNode.Operation.COUNTER,
		[bell]
	)
	counter.counter_target = 3
	var latch: MechanismLogicNode = _create_logic(
		"FireLatch",
		"fire_latch",
		"FIRE LATCH",
		MechanismLogicNode.Operation.LATCH,
		[sensor]
	)
	var final_and: MechanismLogicNode = _create_logic(
		"CounterAndLatch",
		"counter_and_latch",
		"COUNTER AND LATCH",
		MechanismLogicNode.Operation.AND,
		[counter, latch]
	)
	_create_logic_label(counter, Vector3(-3.6, 3.3, z + 2.5))
	_create_logic_label(latch, Vector3(0.0, 3.3, z + 2.5))
	_create_logic_label(final_and, Vector3(3.6, 3.3, z + 2.5))
	var indicator: MechanismIndicator = _spawn_indicator(
		"FinalIndicator",
		"FINAL OUTPUT",
		Vector3(0.0, 0.0, z + 4.5)
	)
	var gate: MechanismSlidingGate = _spawn_gate(
		"FinalGate",
		"FINAL MECHANISM GATE",
		Vector3(0.0, 0.0, z + 8.0)
	)
	_wire_output("FinalIndicatorOutput", final_and, indicator)
	_wire_output("FinalGateOutput", final_and, gate)
	station_states["counter_latch"] = {
		"logic": [counter, latch, final_and],
		"inputs": [bell, sensor],
		"outputs": [indicator, gate],
	}


func _create_logic(
	node_name: String,
	mechanism_id: String,
	display_name: String,
	operation: MechanismLogicNode.Operation,
	sources: Array
) -> MechanismLogicNode:
	var logic := MechanismLogicNode.new()
	logic.name = node_name
	logic.mechanism_id = mechanism_id
	logic.display_name = display_name
	logic.operation = operation
	network_root.add_child(logic)
	for source_value: Variant in sources:
		if source_value is Node:
			logic.bind_source(source_value as Node)
	logic_nodes.append(logic)
	return logic


func _wire_output(
	node_name: String,
	source: Node,
	target: Node
) -> MechanismOutputAdapter:
	var adapter := MechanismOutputAdapter.new()
	adapter.name = node_name
	adapter.mechanism_id = node_name.to_lower()
	adapter.display_name = node_name
	network_root.add_child(adapter)
	adapter.bind_source(source)
	adapter.bind_target(target)
	output_adapters.append(adapter)
	return adapter


func _spawn_pressure_plate(
	node_name: String,
	mechanism_id: String,
	position_value: Vector3
) -> PressurePlateSwitch:
	var plate: PressurePlateSwitch = PressurePlateScene.instantiate() as PressurePlateSwitch
	plate.name = node_name
	plate.component_id = mechanism_id
	plate.display_name = node_name.replace("_", " ")
	plate.position = position_value
	mechanisms_root.add_child(plate)
	input_nodes.append(plate)
	return plate


func _spawn_lever(
	node_name: String,
	mechanism_id: String,
	display_name: String,
	position_value: Vector3,
	momentary: bool,
	momentary_seconds: float = 0.35
) -> MechanismToggleLever:
	var lever: MechanismToggleLever = LeverScene.instantiate() as MechanismToggleLever
	lever.name = node_name
	lever.mechanism_id = mechanism_id
	lever.display_name = display_name
	lever.momentary = momentary
	lever.momentary_seconds = momentary_seconds
	lever.position = position_value
	mechanisms_root.add_child(lever)
	input_nodes.append(lever)
	return lever


func _spawn_sensor(
	node_name: String,
	mechanism_id: String,
	display_name: String,
	position_value: Vector3
) -> MechanismElementSensor:
	var sensor: MechanismElementSensor = ElementSensorScene.instantiate() as MechanismElementSensor
	sensor.name = node_name
	sensor.mechanism_id = mechanism_id
	sensor.display_name = display_name
	sensor.position = position_value
	mechanisms_root.add_child(sensor)
	input_nodes.append(sensor)
	return sensor


func _spawn_indicator(
	node_name: String,
	display_name: String,
	position_value: Vector3
) -> MechanismIndicator:
	var indicator: MechanismIndicator = IndicatorScene.instantiate() as MechanismIndicator
	indicator.name = node_name
	indicator.display_name = display_name
	indicator.position = position_value
	mechanisms_root.add_child(indicator)
	output_nodes.append(indicator)
	return indicator


func _spawn_gate(
	node_name: String,
	display_name: String,
	position_value: Vector3
) -> MechanismSlidingGate:
	var gate: MechanismSlidingGate = GateScene.instantiate() as MechanismSlidingGate
	gate.name = node_name
	gate.display_name = display_name
	gate.position = position_value
	mechanisms_root.add_child(gate)
	output_nodes.append(gate)
	return gate


func _spawn_bridge(
	node_name: String,
	display_name: String,
	position_value: Vector3
) -> MechanismBridgeOutput:
	var bridge: MechanismBridgeOutput = BridgeScene.instantiate() as MechanismBridgeOutput
	bridge.name = node_name
	bridge.display_name = display_name
	bridge.position = position_value
	mechanisms_root.add_child(bridge)
	output_nodes.append(bridge)
	return bridge


func _spawn_weight_crate(node_name: String, position_value: Vector3) -> RigidBody3D:
	var crate := RigidBody3D.new()
	crate.name = node_name
	crate.mass = 3.0
	crate.position = position_value
	crate.add_to_group("mechanism_weights")
	crate.add_to_group("lab_resettable")
	crate.set_meta("mechanism_initial_transform", crate.transform)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.3, 1.3, 1.3)
	collision.shape = shape
	crate.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.3, 1.3, 1.3)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(Color(0.48, 0.27, 0.11), 0.1, 0.82)
	crate.add_child(mesh_instance)
	mechanisms_root.add_child(crate)
	return crate


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.025, 0.035, 0.055)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.62, 0.75)
	environment.ambient_light_energy = 0.72
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color(1.0, 0.82, 0.64)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)

	_create_static_box(
		"LabFloor",
		Vector3(0.0, -0.5, 50.0),
		Vector3(24.0, 1.0, 132.0),
		Color(0.12, 0.15, 0.2)
	)
	_create_static_box(
		"LeftWall",
		Vector3(-12.5, 2.0, 50.0),
		Vector3(1.0, 5.0, 132.0),
		Color(0.08, 0.1, 0.14)
	)
	_create_static_box(
		"RightWall",
		Vector3(12.5, 2.0, 50.0),
		Vector3(1.0, 5.0, 132.0),
		Color(0.08, 0.1, 0.14)
	)
	for z: float in [9.0, 32.0, 55.0, 79.0, 103.0]:
		_create_static_box(
			"Divider" + str(int(z)),
			Vector3(-8.0, 1.5, z),
			Vector3(7.0, 3.0, 0.5),
			Color(0.16, 0.18, 0.23)
		)
		_create_static_box(
			"DividerRight" + str(int(z)),
			Vector3(8.0, 1.5, z),
			Vector3(7.0, 3.0, 0.5),
			Color(0.16, 0.18, 0.23)
		)


func _create_station_platform(z: float, title: String) -> void:
	_create_static_box(
		"StationPlatform" + str(int(z)),
		Vector3(0.0, 0.05, z + 2.0),
		Vector3(20.0, 0.2, 16.0),
		Color(0.17, 0.2, 0.26)
	)
	_create_station_label(title, Vector3(0.0, 4.7, z - 4.5), Color(0.8, 0.9, 1.0))


func _create_station_label(text: String, position_value: Vector3, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = position_value
	label.font_size = 28
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.modulate = color
	add_child(label)
	return label


func _create_logic_label(logic: MechanismLogicNode, position_value: Vector3) -> Label3D:
	var label := _create_station_label(logic.display_name, position_value, Color(1.0, 0.76, 0.32))
	label.font_size = 20
	logic_labels[logic.get_instance_id()] = label
	return label


func _create_static_box(
	node_name: String,
	position_value: Vector3,
	size_value: Vector3,
	color: Color
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position_value
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color, 0.15, 0.82)
	body.add_child(mesh_instance)
	add_child(body)
	return body


func _make_material(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	return material


func _on_reset_lever_toggled(active: bool) -> void:
	if active:
		call_deferred("reset_lab")


func reset_lab() -> void:
	if reset_in_progress:
		return
	reset_in_progress = true
	if player != null and is_instance_valid(player):
		player.transform = initial_player_transform
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	for input: Node in input_nodes:
		if input != reset_lever and input != null and is_instance_valid(input):
			if input.has_method("reset_target"):
				input.call("reset_target")
	for logic: MechanismLogicNode in logic_nodes:
		if logic != null and is_instance_valid(logic):
			logic.reset_target()
	for adapter: MechanismOutputAdapter in output_adapters:
		if adapter != null and is_instance_valid(adapter):
			adapter.reset_target()
	for output: Node in output_nodes:
		if output != null and is_instance_valid(output) and output.has_method("reset_target"):
			output.call("reset_target")
	for crate: Node in get_tree().get_nodes_in_group("mechanism_weights"):
		if crate is RigidBody3D and is_ancestor_of(crate):
			var body := crate as RigidBody3D
			var initial_transform: Variant = body.get_meta("mechanism_initial_transform", body.transform)
			if initial_transform is Transform3D:
				body.transform = initial_transform as Transform3D
			body.linear_velocity = Vector3.ZERO
			body.angular_velocity = Vector3.ZERO
	if reset_lever != null and is_instance_valid(reset_lever):
		reset_lever.set_lever_active(false, true)
	reset_in_progress = false
	refresh_remaining = 0.0
	call_deferred("_refresh_all_presentations")
	GameState.set_objective("Mechanism lab reset. Begin with the weight plate.")
	_show_message("All mechanism inputs, logic memory, timers, counters, gates, and bridge outputs were reset.")


func _refresh_all_presentations() -> void:
	for logic: MechanismLogicNode in logic_nodes:
		if logic == null or not is_instance_valid(logic):
			continue
		var label: Label3D = logic_labels.get(logic.get_instance_id()) as Label3D
		if label == null:
			continue
		var data: Dictionary = logic.get_debug_data()
		var detail: String = (
			str(data.get("counter", 0)) + "/" + str(data.get("counter_target", 0))
			if logic.operation == MechanismLogicNode.Operation.COUNTER
			else str(snappedf(float(data.get("timer_remaining", 0.0)), 0.1)) + "s"
			if logic.operation == MechanismLogicNode.Operation.TIMER
			else str(data.get("active_sources", 0)) + "/" + str(data.get("source_count", 0))
		)
		label.text = logic.display_name + "\n" + detail + " → " + ("ON" if logic.active else "OFF")
		label.modulate = Color(0.35, 1.0, 0.55) if logic.active else Color(1.0, 0.65, 0.25)
	if debug_readout != null:
		var active_logic: int = 0
		for logic: MechanismLogicNode in logic_nodes:
			if logic != null and logic.active:
				active_logic += 1
		debug_readout.text = (
			"PUZZLE SIGNAL NETWORK\n"
			+ "Inputs " + str(input_nodes.size() - 1)
			+ "   Logic " + str(active_logic) + "/" + str(logic_nodes.size())
			+ "   Outputs " + str(output_nodes.size())
			+ "\nFire sensors accept Fire and reset with Water • F8 resets lab"
		)


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	var logic_data: Dictionary = {}
	for logic: MechanismLogicNode in logic_nodes:
		if logic != null and is_instance_valid(logic):
			logic_data[logic.get_mechanism_id()] = logic.get_debug_data()
	return {
		"mechanism_network_lab": true,
		"inputs": input_nodes.size() - 1,
		"logic_nodes": logic_data,
		"output_adapters": output_adapters.size(),
		"outputs": output_nodes.size(),
		"stations": station_states.keys(),
		"reset_in_progress": reset_in_progress,
	}
