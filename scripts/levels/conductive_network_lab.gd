extends Node3D
class_name ConductiveNetworkLab

@export var readout_refresh_interval: float = 0.08
@export var bridge_terminal_radius: float = 0.36
@export var bridge_impulse_retention: float = 0.0
@export var bridge_drag: float = 8.5
@export var bridge_max_speed: float = 4.2

@onready var solver: DCCircuitSolver = get_node_or_null("DCCircuitSolver") as DCCircuitSolver
@onready var battery: CircuitVoltageSource = get_node_or_null("Circuit/Battery") as CircuitVoltageSource
@onready var circuit_switch: CircuitSwitch = get_node_or_null("Circuit/Switch") as CircuitSwitch
@onready var coil: ElectromagneticCoilComponent = get_node_or_null("Circuit/ElectromagneticCoil") as ElectromagneticCoilComponent
@onready var lamp: CircuitComponent = get_node_or_null("Circuit/Lamp") as CircuitComponent
@onready var readout: Label3D = get_node_or_null("CircuitReadout") as Label3D
@onready var player: Node3D = get_node_or_null("Player") as Node3D
@onready var copper_bridge: FieldResponsiveBody = get_node_or_null("CopperBridge") as FieldResponsiveBody
@onready var wood_bridge: FieldResponsiveBody = get_node_or_null("WoodBridge") as FieldResponsiveBody

var refresh_timer: float = 0.0
var initial_player_transform: Transform3D
var completion_announced: bool = false


func _ready() -> void:
	add_to_group("debuggable")
	if player != null:
		player.add_to_group("player")
		initial_player_transform = player.transform
	configure_bridge(copper_bridge)
	configure_bridge(wood_bridge)
	GameState.set_objective("Bridge the circuit gap, close the switch, and energize the electromagnet.")
	if solver != null:
		solver.request_solve()
	update_presentation()


func configure_bridge(bridge: FieldResponsiveBody) -> void:
	if bridge == null:
		return
	bridge.floor_snap_length = 0.35
	bridge.floor_stop_on_slope = true

	var force_receiver: ForceReceiver = bridge.get_node_or_null("ForceReceiver") as ForceReceiver
	if force_receiver != null:
		force_receiver.impulse_momentum_retention = clampf(bridge_impulse_retention, 0.0, 1.0)
		force_receiver.drag = max(bridge_drag, 0.0)
		force_receiver.max_force_speed = max(bridge_max_speed, 0.1)

	var component: CircuitComponent = bridge.get_node_or_null("CircuitComponent") as CircuitComponent
	if component == null:
		return
	for terminal: CircuitTerminal in [component.get_terminal_a(), component.get_terminal_b()]:
		if terminal != null:
			terminal.connection_radius = max(terminal.connection_radius, bridge_terminal_radius)


func _process(delta: float) -> void:
	refresh_timer -= delta
	if refresh_timer > 0.0:
		return
	refresh_timer = max(readout_refresh_interval, 0.03)
	update_presentation()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F8:
		reset_lab()


func update_presentation() -> void:
	for component: CircuitComponent in get_scoped_components():
		var current_glow: Node3D = component.get_node_or_null("CurrentGlow") as Node3D
		if current_glow != null:
			current_glow.visible = component.energized
		var state_label: Label3D = component.get_node_or_null("StateLabel") as Label3D
		if state_label != null:
			state_label.text = get_component_state_text(component)

	var lamp_light: Light3D = lamp.get_node_or_null("LampLight") as Light3D if lamp != null else null
	if lamp_light != null:
		lamp_light.visible = lamp.energized

	if readout != null and solver != null:
		var circuit_state: String = "CLOSED LOOP" if solver.circuit_closed else "OPEN LOOP"
		var polarity_text: String = "A → B" if battery != null and battery.polarity_sign > 0 else "B → A"
		var switch_text: String = "CLOSED" if circuit_switch != null and circuit_switch.path_enabled else "OPEN"
		var coil_text: String = "MAGNETIC" if coil != null and coil.energized else "OFF"
		readout.text = (
			"CIRCUIT: " + circuit_state
			+ "\nCURRENT: " + str(snapped(solver.current_amps, 0.01)) + " A"
			+ "   RESISTANCE: " + str(snapped(solver.total_resistance_ohms, 0.01)) + " Ω"
			+ "\nSWITCH: " + switch_text + "   BATTERY: " + polarity_text
			+ "\nCOIL: " + coil_text + "   CONTACTS: " + str(solver.contact_pairs.size())
		)

	if not completion_announced and solver != null and solver.circuit_closed and coil != null and coil.energized:
		completion_announced = true
		GameState.set_objective("Reverse the battery and observe the magnetic field change direction.")
		show_message("The physical circuit now powers the electromagnet.")


func get_component_state_text(component: CircuitComponent) -> String:
	if component is CircuitSwitch:
		return "SWITCH\n" + ("CLOSED" if component.path_enabled else "OPEN")
	if component is CircuitVoltageSource:
		return "BATTERY\n" + ("A → B" if (component as CircuitVoltageSource).polarity_sign > 0 else "B → A")
	if component.overloaded:
		return component.display_name + "\nOVERLOAD"
	if component.energized:
		return component.display_name + "\n" + str(snapped(abs(component.signed_current_amps), 0.01)) + " A"
	return component.display_name + "\nOFF"


func get_scoped_components() -> Array[CircuitComponent]:
	var components: Array[CircuitComponent] = []
	for candidate: Node in get_tree().get_nodes_in_group("circuit_components"):
		if candidate is CircuitComponent and is_ancestor_of(candidate):
			components.append(candidate as CircuitComponent)
	return components


func reset_lab() -> void:
	for resettable: Node in get_tree().get_nodes_in_group("lab_resettable"):
		if resettable != null and is_ancestor_of(resettable) and resettable.has_method("reset_target"):
			resettable.reset_target()
	if battery != null:
		battery.reset_target()
	if circuit_switch != null:
		circuit_switch.reset_target()
	if player != null:
		player.transform = initial_player_transform
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
	completion_announced = false
	refresh_timer = 0.0
	if solver != null:
		solver.request_solve()
	call_deferred("update_presentation")
	show_message("Conductive network laboratory reset.")


func show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.show_message(text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	return {
		"conductive_network_lab": true,
		"solver": solver.get_debug_data() if solver != null else {},
		"battery": battery.get_debug_data() if battery != null else {},
		"switch": circuit_switch.get_debug_data() if circuit_switch != null else {},
		"coil": coil.get_debug_data() if coil != null else {},
		"copper_bridge": copper_bridge.get_debug_data() if copper_bridge != null else {},
		"wood_bridge": wood_bridge.get_debug_data() if wood_bridge != null else {},
	}
