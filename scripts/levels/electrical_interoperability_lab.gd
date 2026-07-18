extends Node3D
class_name ElectricalInteroperabilityLab

@onready var base_lab: Node3D = get_node_or_null("BaseCircuitLab") as Node3D

var solver: DCCircuitSolver
var battery: CircuitVoltageSource
var coil: ElectromagneticCoilComponent
var circuit_readout: Label3D
var excitation_port: CircuitExcitationPort
var source_selector: CircuitSourceSelector
var storm_console: EnvironmentalEmitterConsole
var interoperability_label: Label3D


func _ready() -> void:
	process_priority = 100
	await get_tree().process_frame
	if base_lab == null:
		push_error("Electrical interoperability lab requires BaseCircuitLab.")
		return

	solver = base_lab.get_node_or_null("DCCircuitSolver") as DCCircuitSolver
	battery = base_lab.get_node_or_null("Circuit/Battery") as CircuitVoltageSource
	coil = base_lab.get_node_or_null("Circuit/ElectromagneticCoil") as ElectromagneticCoilComponent
	circuit_readout = base_lab.get_node_or_null("CircuitReadout") as Label3D

	excitation_port = ElectricalInteroperabilityDevices.build_excitation_port(base_lab, battery)
	source_selector = ElectricalInteroperabilityDevices.build_source_selector(base_lab, battery, excitation_port)
	var storm_emitter: ElementEmitter = ElectricalInteroperabilityDevices.build_storm_emitter(base_lab, excitation_port)
	storm_console = ElectricalInteroperabilityDevices.build_storm_console(base_lab, storm_emitter)
	build_labels()

	if source_selector != null:
		source_selector.source_mode_changed.connect(_on_source_mode_changed)
	if solver != null:
		solver.request_solve()
	GameState.set_objective("Build the circuit, then power it with the battery, Grace's Lightning, or environmental Lightning.")
	update_presentation()


func _process(_delta: float) -> void:
	update_presentation()


func build_labels() -> void:
	interoperability_label = LabGeometryFactory.add_label(
		base_lab,
		"InteroperabilityReadout",
		"ELECTRICAL INTEROPERABILITY",
		Vector3(6.3, 3.5, -5.2),
		25,
		Color(0.78, 0.84, 1.0, 1.0)
	)
	LabGeometryFactory.add_label(
		base_lab,
		"InteroperabilityInstructions",
		"SELECT BATTERY OR LIGHTNING  •  SHOOT THE INPUT ROD  •  TRIGGER THE STORM CONSOLE",
		Vector3(0.0, 4.45, -6.0),
		24,
		Color(0.82, 0.74, 1.0, 1.0)
	)


func _on_source_mode_changed(mode: String) -> void:
	match mode:
		"battery":
			GameState.set_objective("Use the battery to provide steady current through the completed circuit.")
		"lightning":
			GameState.set_objective("Strike the Lightning input rod or release an environmental storm pulse.")
		_:
			GameState.set_objective("The circuit source is disconnected. Select a power source.")


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
			+ "\nSOURCE MODE: " + source_selector.source_mode.to_upper()
			+ "   ACTIVE: " + active_source
			+ "\nCOIL: " + ("MAGNETIC" if coil != null and coil.energized else "OFF")
		)

	if interoperability_label != null:
		interoperability_label.text = (
			"ELECTRICAL INTEROPERABILITY"
			+ "\nPORT: " + ("ENERGIZED" if excitation_port.pulse_timer > 0.0 else "READY")
			+ "   " + str(snapped(max(excitation_port.pulse_timer, 0.0), 0.01)) + " s"
			+ "\nSPELL / STORM PULSES: " + str(excitation_port.accepted_pulse_count)
			+ "\nLAST SOURCE: " + excitation_port.last_excitation_source
		)


func get_debug_data() -> Dictionary:
	return {
		"electrical_interoperability_lab": true,
		"source_mode": source_selector.source_mode if source_selector != null else "missing",
		"excitation_port": excitation_port.get_debug_data() if excitation_port != null else {},
		"storm_console": storm_console.get_debug_data() if storm_console != null else {},
		"solver": solver.get_debug_data() if solver != null else {},
	}
