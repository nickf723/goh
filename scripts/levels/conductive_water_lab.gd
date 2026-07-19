extends Node3D
class_name ConductiveWaterLab

const WaterProfile: PhysicalMaterialProfile = preload("res://data/materials/water_physical_profile.tres")

@onready var electrical_lab: Node3D = get_node_or_null("ElectricalLab") as Node3D

var base_lab: Node3D
var solver: DCCircuitSolver
var source_selector: CircuitSourceSelector
var excitation_port: CircuitExcitationPort
var storm_console: EnvironmentalEmitterConsole
var storm_emitter: ElementEmitter
var copper_bridge: FieldResponsiveBody
var water_volume: ConductiveWaterVolume
var water_console: WaterStateConsole
var water_status: Label3D


func _ready() -> void:
	process_priority = 120
	await get_tree().process_frame
	await get_tree().process_frame
	if electrical_lab == null:
		push_error("Conductive water lab requires ElectricalLab.")
		return
	base_lab = electrical_lab.get_node_or_null("BaseCircuitLab") as Node3D
	if base_lab == null:
		push_error("Conductive water lab could not resolve the base circuit laboratory.")
		return
	resolve_nodes()
	replace_copper_link_with_water()
	reconfigure_lightning_sources()
	build_water_console()
	build_labels()
	if solver != null:
		solver.request_solve()
	GameState.set_objective("Compare a filled conductive water path, a drained gap, and Lightning striking the pool.")
	update_presentation()


func resolve_nodes() -> void:
	solver = base_lab.get_node_or_null("DCCircuitSolver") as DCCircuitSolver
	source_selector = base_lab.get_node_or_null("SourceSelector") as CircuitSourceSelector
	excitation_port = base_lab.get_node_or_null("Circuit/LightningInputPort") as CircuitExcitationPort
	storm_console = base_lab.get_node_or_null("StormPulseConsole") as EnvironmentalEmitterConsole
	storm_emitter = base_lab.get_node_or_null("StormLightningEmitter") as ElementEmitter
	copper_bridge = base_lab.get_node_or_null("CopperBridge") as FieldResponsiveBody


func replace_copper_link_with_water() -> void:
	if copper_bridge != null:
		copper_bridge.visible = false
		copper_bridge.process_mode = Node.PROCESS_MODE_DISABLED
		copper_bridge.collision_layer = 0
		copper_bridge.collision_mask = 0
		var copper_component: CircuitComponent = copper_bridge.get_node_or_null("CircuitComponent") as CircuitComponent
		if copper_component != null:
			copper_component.path_enabled = false
			for terminal: CircuitTerminal in [copper_component.get_terminal_a(), copper_component.get_terminal_b()]:
				if terminal != null:
					terminal.enabled = false

	water_volume = ConductiveWaterVolume.new()
	water_volume.name = "ConductiveWaterVolume"
	water_volume.component_id = "conductive_water_pool"
	water_volume.material_profile = WaterProfile
	water_volume.position = Vector3(0.0, 0.55, 2.5)
	water_volume.volume_size = Vector3(3.4, 0.9, 1.8)
	water_volume.conductivity_scale = WaterProfile.electrical_conductivity
	water_volume.resistance_per_meter_ohms = WaterProfile.electrical_resistivity * 0.22
	water_volume.minimum_resistance_ohms = 0.55
	base_lab.add_child(water_volume)
	water_volume.configure_excitation_port(excitation_port)
	water_volume.fill_state_changed.connect(_on_water_state_changed)
	water_volume.water_electrified.connect(_on_water_electrified)
	if source_selector != null:
		var source_callback := Callable(self, "_on_source_mode_changed")
		if not source_selector.source_mode_changed.is_connected(source_callback):
			source_selector.source_mode_changed.connect(source_callback)


func reconfigure_lightning_sources() -> void:
	if excitation_port != null:
		var rod: Node3D = excitation_port.get_node_or_null("InputRod") as Node3D
		if rod != null:
			rod.visible = false
		var label: Node3D = excitation_port.get_node_or_null("InputLabel") as Node3D
		if label != null:
			label.visible = false
		var target_area: Area3D = excitation_port.get_node_or_null("LightningTargetArea") as Area3D
		if target_area != null:
			target_area.monitorable = false
			target_area.monitoring = false

	if storm_emitter != null and water_volume != null:
		storm_emitter.position = water_volume.position
		var cloud: Node3D = storm_emitter.get_node_or_null("StormCloud") as Node3D
		if cloud != null:
			cloud.position = Vector3(0.0, 2.25, 0.0)


func build_water_console() -> void:
	water_console = WaterStateConsole.new()
	water_console.name = "WaterStateConsole"
	water_console.position = Vector3(0.0, 0.65, -5.8)
	base_lab.add_child(water_console)
	LabGeometryFactory.add_box_interactable(
		water_console,
		Vector3(2.0, 1.0, 1.2),
		Color(0.04, 0.32, 0.58, 1.0),
		"WATER CONTROL\nDRAIN"
	)
	water_console.configure_water(water_volume)


func build_labels() -> void:
	for old_label_name: String in ["InteroperabilityTitle", "InteroperabilityInstructions", "InteroperabilityStatus"]:
		var old_label: Node3D = base_lab.get_node_or_null(old_label_name) as Node3D
		if old_label != null:
			old_label.visible = false

	LabGeometryFactory.add_label(
		base_lab,
		"ConductiveWaterTitle",
		"CONDUCTIVE WATER",
		Vector3(0.0, 4.35, -6.4),
		34,
		Color(0.58, 0.86, 1.0, 1.0)
	)
	LabGeometryFactory.add_label(
		base_lab,
		"ConductiveWaterInstructions",
		"BATTERY CROSSES FILLED WATER  •  DRAIN TO BREAK THE LOOP  •  SELECT LIGHTNING AND STRIKE THE POOL",
		Vector3(0.0, 3.72, -6.25),
		21,
		Color(0.72, 0.9, 1.0, 1.0)
	)
	water_status = LabGeometryFactory.add_label(
		base_lab,
		"ConductiveWaterStatus",
		"WATER: INITIALIZING",
		Vector3(0.0, 3.05, -6.1),
		24,
		Color(0.65, 0.86, 1.0, 1.0)
	)


func _process(_delta: float) -> void:
	update_presentation()


func _on_water_state_changed(_is_filled: bool) -> void:
	if solver != null:
		solver.request_solve()
	update_presentation()


func _on_water_electrified(_source_name: String, _duration_seconds: float) -> void:
	if solver != null:
		solver.request_solve()
	update_presentation()


func _on_source_mode_changed(mode: String) -> void:
	if mode == "battery":
		GameState.set_objective("Observe steady battery current crossing the filled water path.")
	elif mode == "lightning":
		GameState.set_objective("Strike the water with Lightning Spark or release the storm pulse.")
	else:
		GameState.set_objective("The electrical source is disconnected.")
	update_presentation()


func update_presentation() -> void:
	if water_volume == null or water_status == null:
		return
	var mode: String = source_selector.source_mode.to_upper() if source_selector != null else "MISSING"
	var circuit_state: String = "CLOSED" if solver != null and solver.circuit_closed else "OPEN"
	water_status.text = (
		"WATER: " + ("FILLED" if water_volume.filled else "DRAINED")
		+ "   ELECTRODES: " + str(water_volume.immersed_terminal_keys.size()) + "/2"
		+ "   RESISTANCE: " + str(snapped(water_volume.resistance_ohms, 0.01)) + " Ω"
		+ "\nSOURCE: " + mode
		+ "   CIRCUIT: " + circuit_state
		+ "   WATER: " + ("ELECTRIFIED" if water_volume.electrified_timer > 0.0 else "NORMAL")
	)

	if source_selector != null:
		var selector_label: Label3D = source_selector.get_node_or_null("StateLabel") as Label3D
		if selector_label != null:
			selector_label.text = "SOURCE SELECTOR\n" + (
				"BATTERY" if source_selector.source_mode == "battery"
				else "LIGHTNING → WATER" if source_selector.source_mode == "lightning"
				else "OFF"
			)


func get_debug_data() -> Dictionary:
	return {
		"conductive_water_lab": true,
		"water": water_volume.get_debug_data() if water_volume != null else {},
		"solver": solver.get_debug_data() if solver != null else {},
		"source_mode": source_selector.source_mode if source_selector != null else "missing",
	}
