extends Node3D
class_name ElectricalInteroperabilityLab

const LabLoadout: AbilityLoadout = preload("res://data/loadouts/electrical_interoperability_lab_loadout.tres")

@onready var base_lab: Node3D = get_node_or_null("BaseCircuitLab") as Node3D

var solver: DCCircuitSolver
var battery: CircuitVoltageSource
var coil: ElectromagneticCoilComponent
var circuit_switch: CircuitSwitch
var circuit_readout: Label3D
var copper_bridge: FieldResponsiveBody
var wood_bridge: FieldResponsiveBody
var player: Node3D
var ability_caster: Node
var excitation_port: CircuitExcitationPort
var source_selector: CircuitSourceSelector
var storm_console: EnvironmentalEmitterConsole
var status_label: Label3D


func _ready() -> void:
	process_priority = 100
	await get_tree().process_frame
	if base_lab == null:
		push_error("Electrical interoperability lab requires BaseCircuitLab.")
		return

	resolve_base_lab_nodes()
	simplify_conductive_bench()

	excitation_port = ElectricalInteroperabilityDevices.build_excitation_port(base_lab, battery)
	source_selector = ElectricalInteroperabilityDevices.build_source_selector(base_lab, battery, excitation_port)
	var storm_emitter: ElementEmitter = ElectricalInteroperabilityDevices.build_storm_emitter(base_lab, excitation_port)
	storm_console = ElectricalInteroperabilityDevices.build_storm_console(base_lab, storm_emitter)
	spread_interoperability_devices()
	build_labels()
	configure_lab_spells()

	if source_selector != null:
		source_selector.source_mode_changed.connect(_on_source_mode_changed)
	if solver != null:
		solver.request_solve()
	GameState.set_objective("Compare steady battery power with spell and environmental Lightning pulses.")
	update_presentation()


func resolve_base_lab_nodes() -> void:
	solver = base_lab.get_node_or_null("DCCircuitSolver") as DCCircuitSolver
	battery = base_lab.get_node_or_null("Circuit/Battery") as CircuitVoltageSource
	coil = base_lab.get_node_or_null("Circuit/ElectromagneticCoil") as ElectromagneticCoilComponent
	circuit_switch = base_lab.get_node_or_null("Circuit/Switch") as CircuitSwitch
	circuit_readout = base_lab.get_node_or_null("CircuitReadout") as Label3D
	copper_bridge = base_lab.get_node_or_null("CopperBridge") as FieldResponsiveBody
	wood_bridge = base_lab.get_node_or_null("WoodBridge") as FieldResponsiveBody
	player = base_lab.get_node_or_null("Player") as Node3D
	if player != null:
		ability_caster = player.get_node_or_null("AbilityCaster")


func simplify_conductive_bench() -> void:
	for label_path: String in ["Title", "Instructions", "GapLabel"]:
		var old_label: Node3D = base_lab.get_node_or_null(label_path) as Node3D
		if old_label != null:
			old_label.visible = false

	var reset_console: Node3D = base_lab.get_node_or_null("LabResetConsole") as Node3D
	if reset_console != null:
		reset_console.position = Vector3(0.0, 0.0, -8.1)

	if copper_bridge != null:
		copper_bridge.position = Vector3(0.0, 0.35, 2.5)
		copper_bridge.velocity = Vector3.ZERO
		copper_bridge.initial_transform = copper_bridge.transform
		copper_bridge.set_physics_process(false)
		copper_bridge.collision_layer = 0
		copper_bridge.collision_mask = 0
		var bridge_force: ForceReceiver = copper_bridge.get_node_or_null("ForceReceiver") as ForceReceiver
		if bridge_force != null:
			bridge_force.reset_forces()
		var bridge_label: Label3D = copper_bridge.get_node_or_null("Label3D") as Label3D
		if bridge_label != null:
			bridge_label.text = "INSTALLED\nCOPPER LINK"
		var bridge_component: CircuitComponent = copper_bridge.get_node_or_null("CircuitComponent") as CircuitComponent
		if bridge_component != null:
			for terminal: CircuitTerminal in [bridge_component.get_terminal_a(), bridge_component.get_terminal_b()]:
				if terminal != null:
					terminal.connection_radius = max(terminal.connection_radius, 0.5)

	if wood_bridge != null:
		wood_bridge.visible = false
		wood_bridge.process_mode = Node.PROCESS_MODE_DISABLED
		wood_bridge.collision_layer = 0
		wood_bridge.collision_mask = 0
		var wood_component: CircuitComponent = wood_bridge.get_node_or_null("CircuitComponent") as CircuitComponent
		if wood_component != null:
			wood_component.path_enabled = false

	if circuit_switch != null:
		circuit_switch.starts_closed = true
		circuit_switch.path_enabled = true
		circuit_switch.visible = false
		circuit_switch.monitoring = false
		circuit_switch.monitorable = false
		circuit_switch.collision_layer = 0
		circuit_switch.collision_mask = 0
		circuit_switch.notify_topology_changed()


func spread_interoperability_devices() -> void:
	if source_selector != null:
		source_selector.position = Vector3(-6.6, 0.65, -5.8)
	if storm_console != null:
		storm_console.position = Vector3(6.6, 0.65, -5.8)


func configure_lab_spells() -> void:
	if ability_caster == null:
		push_warning("Electrical interoperability lab could not find the player's AbilityCaster.")
		return
	ability_caster.set("loadout", LabLoadout)
	ability_caster.set("current_ability_index", 0)
	var ability_changed_callback := Callable(self, "_on_ability_changed")
	if ability_caster.has_signal("ability_changed") and not ability_caster.is_connected("ability_changed", ability_changed_callback):
		ability_caster.connect("ability_changed", ability_changed_callback)
	if ability_caster.has_method("select_ability"):
		ability_caster.call("select_ability", 0, false)
	elif ability_caster.has_method("emit_current_ability"):
		ability_caster.call("emit_current_ability")


func _process(_delta: float) -> void:
	update_presentation()


func build_labels() -> void:
	LabGeometryFactory.add_label(
		base_lab,
		"InteroperabilityTitle",
		"ELECTRICAL SOURCES",
		Vector3(0.0, 4.35, -6.4),
		34,
		Color(0.86, 0.82, 1.0, 1.0)
	)
	LabGeometryFactory.add_label(
		base_lab,
		"InteroperabilityInstructions",
		"CIRCUIT PREBUILT  •  BATTERY IS STEADY  •  SELECT LIGHTNING, THEN STRIKE THE ROD OR USE THE STORM CONSOLE",
		Vector3(0.0, 3.72, -6.25),
		21,
		Color(0.82, 0.74, 1.0, 1.0)
	)
	status_label = LabGeometryFactory.add_label(
		base_lab,
		"InteroperabilityStatus",
		"ACTIVE SPELL: LIGHTNING SPARK",
		Vector3(0.0, 3.05, -6.1),
		24,
		Color(0.72, 0.9, 1.0, 1.0)
	)


func _on_source_mode_changed(mode: String) -> void:
	match mode:
		"battery":
			GameState.set_objective("Observe steady battery power through the completed circuit.")
		"lightning":
			GameState.set_objective("Strike the violet input rod with Lightning Spark or use the storm console.")
		_:
			GameState.set_objective("The circuit source is disconnected. Select a power source.")


func _on_ability_changed(_ability_name: String, _ability_index: int) -> void:
	update_presentation()


func get_active_spell_name() -> String:
	if ability_caster != null and ability_caster.has_method("get_current_ability_name"):
		return str(ability_caster.call("get_current_ability_name"))
	return "Unavailable"


func update_presentation() -> void:
	if solver == null or source_selector == null or excitation_port == null:
		return
	var circuit_state: String = "CLOSED LOOP" if solver.circuit_closed else "OPEN LOOP"
	var active_source: String = "none"
	if source_selector.source_mode == "battery" and battery != null and battery.path_enabled:
		active_source = "battery"
	elif source_selector.source_mode == "lightning" and excitation_port.pulse_timer > 0.0:
		active_source = excitation_port.last_excitation_source

	if circuit_readout != null:
		circuit_readout.text = (
			"CIRCUIT: " + circuit_state
			+ "\nCURRENT: " + str(snapped(solver.current_amps, 0.01)) + " A"
			+ "   RESISTANCE: " + str(snapped(solver.total_resistance_ohms, 0.01)) + " Ω"
			+ "\nSOURCE: " + source_selector.source_mode.to_upper()
			+ "   ACTIVE: " + active_source
			+ "\nCOIL: " + ("MAGNETIC" if coil != null and coil.energized else "OFF")
		)

	if status_label != null:
		status_label.text = (
			"ACTIVE SPELL: " + get_active_spell_name().to_upper()
			+ "\nSOURCE MODE: " + source_selector.source_mode.to_upper()
			+ "   LIGHTNING PULSES: " + str(excitation_port.accepted_pulse_count)
		)


func get_debug_data() -> Dictionary:
	return {
		"electrical_interoperability_lab": true,
		"source_mode": source_selector.source_mode if source_selector != null else "missing",
		"active_spell": get_active_spell_name(),
		"copper_link_installed": copper_bridge != null and not copper_bridge.is_physics_processing(),
		"excitation_port": excitation_port.get_debug_data() if excitation_port != null else {},
		"storm_console": storm_console.get_debug_data() if storm_console != null else {},
		"solver": solver.get_debug_data() if solver != null else {},
	}
