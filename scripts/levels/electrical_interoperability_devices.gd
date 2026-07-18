extends RefCounted
class_name ElectricalInteroperabilityDevices

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")


static func build_excitation_port(
	base_lab: Node3D,
	battery: CircuitVoltageSource
) -> CircuitExcitationPort:
	var circuit_root: Node3D = base_lab.get_node_or_null("Circuit") as Node3D
	if circuit_root == null or battery == null:
		return null

	var port := CircuitExcitationPort.new()
	port.name = "LightningInputPort"
	port.component_id = "lightning_input_port"
	port.display_name = "Lightning Input Port"
	port.material_profile = CopperProfile
	port.position = battery.position
	port.path_enabled = false
	port.default_voltage_volts = 48.0
	port.default_duration_seconds = 0.6
	port.default_source_resistance_ohms = 0.6
	port.default_current_limit_amps = 14.0
	circuit_root.add_child(port)

	LabGeometryFactory.add_terminal(port, "TerminalA", "positive", Vector3(0.0, 0.0, 2.5))
	LabGeometryFactory.add_terminal(port, "TerminalB", "negative", Vector3(0.0, 0.0, -2.5))
	LabGeometryFactory.add_sphere_area(port, "LightningTargetArea", 1.25, Vector3(0.0, 1.7, 0.0))

	var rod := MeshInstance3D.new()
	rod.name = "InputRod"
	var rod_mesh := CylinderMesh.new()
	rod_mesh.top_radius = 0.24
	rod_mesh.bottom_radius = 0.24
	rod_mesh.height = 2.8
	rod_mesh.radial_segments = 14
	rod.mesh = rod_mesh
	rod.material_override = LabGeometryFactory.make_material(Color(0.45, 0.28, 0.95, 1.0), true, 3.4)
	rod.position = Vector3(0.0, 1.7, 0.0)
	port.add_child(rod)
	LabGeometryFactory.add_label(
		port,
		"InputLabel",
		"LIGHTNING INPUT\nSHOOT VIOLET ROD",
		Vector3(0.0, 3.45, 0.0),
		25,
		Color(0.72, 0.66, 1.0, 1.0)
	)
	return port


static func build_source_selector(
	base_lab: Node3D,
	battery: CircuitVoltageSource,
	port: CircuitExcitationPort
) -> CircuitSourceSelector:
	var selector := CircuitSourceSelector.new()
	selector.name = "SourceSelector"
	selector.position = Vector3(-6.6, 0.65, -5.0)
	selector.initial_mode = "battery"
	base_lab.add_child(selector)
	LabGeometryFactory.add_box_interactable(
		selector,
		Vector3(1.8, 1.0, 1.2),
		Color(0.18, 0.1, 0.34, 1.0),
		"SOURCE SELECTOR\nBATTERY"
	)
	selector.configure_sources(battery, port)
	return selector


static func build_storm_emitter(
	base_lab: Node3D,
	port: CircuitExcitationPort
) -> ElementEmitter:
	var emitter := ElementEmitter.new()
	emitter.name = "StormLightningEmitter"
	emitter.emitter_id = "storm_lightning"
	emitter.display_name = "Captured Storm Lightning"
	emitter.element = "lightning"
	emitter.payload_tags = ["lightning", "shock", "electrical", "environment", "storm"]
	emitter.pulse_on_ready = false
	emitter.pulse_interval = 9999.0
	emitter.active = true
	emitter.position = port.position + Vector3(0.0, 1.7, 0.0)
	base_lab.add_child(emitter)

	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.95
	collision.shape = shape
	emitter.add_child(collision)

	var cloud := MeshInstance3D.new()
	cloud.name = "StormCloud"
	var cloud_mesh := SphereMesh.new()
	cloud_mesh.radius = 0.55
	cloud_mesh.height = 1.1
	cloud_mesh.radial_segments = 12
	cloud_mesh.rings = 7
	cloud.mesh = cloud_mesh
	cloud.scale = Vector3(1.55, 0.65, 1.0)
	cloud.position = Vector3(0.0, 1.85, 0.0)
	cloud.material_override = LabGeometryFactory.make_material(Color(0.23, 0.18, 0.38, 0.72), true, 1.7)
	emitter.add_child(cloud)
	return emitter


static func build_storm_console(
	base_lab: Node3D,
	emitter: ElementEmitter
) -> EnvironmentalEmitterConsole:
	var console := EnvironmentalEmitterConsole.new()
	console.name = "StormPulseConsole"
	console.position = Vector3(-3.8, 0.65, -5.0)
	base_lab.add_child(console)
	LabGeometryFactory.add_box_interactable(
		console,
		Vector3(1.8, 1.0, 1.2),
		Color(0.12, 0.2, 0.42, 1.0),
		"STORM CONSOLE\nRELEASE PULSE"
	)
	console.configure_emitter(emitter)
	return console
