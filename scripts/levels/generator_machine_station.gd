extends RefCounted
class_name GeneratorMachineStation

const WaterProfile: PhysicalMaterialProfile = preload("res://data/materials/water_physical_profile.tres")
const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")
const IronProfile: PhysicalMaterialProfile = preload("res://data/materials/iron_physical_profile.tres")


static func build(host: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "GeneratorMachine"
	host.add_child(root)

	var reservoir := PressureReservoir.new()
	reservoir.name = "PressureReservoir"
	reservoir.maximum_pressure = 100.0
	reservoir.leak_enabled = true
	reservoir.leak_per_second = 0.8
	root.add_child(reservoir)

	var water := ThermalWaterVolume.new()
	water.name = "BoilerWater"
	water.component_id = "generator_boiler_water"
	water.material_profile = WaterProfile
	water.volume_size = Vector3(3.4, 1.2, 2.2)
	water.position = Vector3(-5.2, 0.85, 1.35)
	water.starts_filled = true
	water.starting_water_temperature_c = 20.0
	water.water_heat_capacity_j_per_c = 8.0
	water.water_ambient_conductance = 0.015
	water.ensure_thermal_state()
	ThermalPressureStation.add_spell_capture(water)
	root.add_child(water)
	ThermalPressureStation.add_boiler_frame(root, water.position)

	var thermal_adapter := ThermalPressureAdapter.new()
	thermal_adapter.name = "ThermalPressureAdapter"
	thermal_adapter.base_output_per_second = 18.0
	thermal_adapter.output_per_superheat_c = 0.55
	thermal_adapter.maximum_output_per_second = 42.0
	thermal_adapter.condensation_per_second = 28.0
	thermal_adapter.configure(water.thermal_state, reservoir)
	root.add_child(thermal_adapter)

	var shaft := RotationalShaftState.new()
	shaft.name = "TurbineShaft"
	shaft.position = Vector3(-1.15, 1.35, 1.35)
	shaft.maximum_abs_rpm = 1800.0
	shaft.acceleration_rpm_per_second = 950.0
	shaft.deceleration_rpm_per_second = 700.0
	shaft.rotation_axis = Vector3.FORWARD
	shaft.rotor_visual_path = NodePath("Rotor")
	add_turbine_rotor(shaft)
	root.add_child(shaft)
	add_drive_pipe(root, water.position, shaft.position)

	var turbine := PressureTurbine.new()
	turbine.name = "PressureTurbine"
	turbine.minimum_operating_pressure = 8.0
	turbine.full_speed_pressure = 70.0
	turbine.maximum_rpm = 1500.0
	turbine.idle_consumption_per_second = 2.0
	turbine.full_consumption_per_second = 16.0
	turbine.configure(reservoir, shaft)
	root.add_child(turbine)

	var circuit_root := Node3D.new()
	circuit_root.name = "GeneratorCircuit"
	circuit_root.position = Vector3(2.4, 0.0, 0.2)
	root.add_child(circuit_root)

	var solver := DCCircuitSolver.new()
	solver.name = "DCCircuitSolver"
	solver.solve_interval = 0.05
	circuit_root.add_child(solver)

	var generator := RotationalGeneratorSource.new()
	generator.name = "GeneratorSource"
	generator.component_id = "rotational_generator"
	generator.display_name = "Mechanical Generator"
	generator.source_internal_resistance_ohms = 0.35
	generator.max_current_amps = 8.0
	generator.minimum_generation_rpm = 120.0
	generator.volts_per_1000_rpm = 12.0
	generator.maximum_output_voltage = 18.0
	generator.position = Vector3(0.0, 0.8, 0.0)
	generator.configure_shaft(shaft)
	ThermalLabGeometry.add_terminal(generator, "TerminalA", "positive", Vector3(-2.0, 0.0, 0.0), 0.36)
	ThermalLabGeometry.add_terminal(generator, "TerminalB", "negative", Vector3(2.0, 0.0, 0.0), 0.36)
	ThermalLabGeometry.add_box_visual(
		generator,
		"GeneratorBody",
		Vector3(1.8, 1.25, 1.1),
		Color(0.2, 0.28, 0.38, 1.0),
		true,
		1.2
	)
	add_generator_interaction(generator)
	circuit_root.add_child(generator)

	var lamp := CircuitComponent.new()
	lamp.name = "GeneratorLamp"
	lamp.component_id = "generator_lamp"
	lamp.display_name = "Generator Lamp"
	lamp.component_kind = "load"
	lamp.material_profile = CopperProfile
	lamp.resistance_ohms = 3.0
	lamp.position = Vector3(2.0, 0.8, 1.5)
	ThermalLabGeometry.add_terminal(lamp, "TerminalA", "a", Vector3(0.0, 0.0, -1.4), 0.36)
	ThermalLabGeometry.add_terminal(lamp, "TerminalB", "b", Vector3(0.0, 0.0, 1.4), 0.36)
	var bulb := MeshInstance3D.new()
	bulb.name = "Bulb"
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.48
	bulb_mesh.height = 0.96
	bulb.mesh = bulb_mesh
	bulb.material_override = ThermalLabGeometry.make_material(Color(1.0, 0.68, 0.18, 0.72), true, 3.2)
	lamp.add_child(bulb)
	var lamp_light := OmniLight3D.new()
	lamp_light.name = "LampLight"
	lamp_light.light_color = Color(1.0, 0.5, 0.08, 1.0)
	lamp_light.light_energy = 3.4
	lamp_light.omni_range = 4.5
	lamp.add_child(lamp_light)
	circuit_root.add_child(lamp)

	var coil := ElectromagneticCoilComponent.new()
	coil.name = "GeneratorCoil"
	coil.component_id = "generator_coil"
	coil.display_name = "Generator Electromagnet"
	coil.material_profile = CopperProfile
	coil.resistance_ohms = 2.2
	coil.field_strength_per_amp = 4.5
	coil.position = Vector3(0.0, 0.8, 3.0)
	ThermalLabGeometry.add_terminal(coil, "TerminalA", "a", Vector3(2.0, 0.0, 0.0), 0.36)
	ThermalLabGeometry.add_terminal(coil, "TerminalB", "b", Vector3(-2.0, 0.0, 0.0), 0.36)
	add_coil_visual(coil)
	var magnetic_field := MagneticDipoleField.new()
	magnetic_field.name = "MagneticField"
	magnetic_field.active = false
	magnetic_field.maximum_distance = 4.5
	magnetic_field.minimum_distance = 0.45
	magnetic_field.falloff_power = 1.35
	magnetic_field.maximum_field_strength = 18.0
	coil.add_child(magnetic_field)
	circuit_root.add_child(coil)

	var return_wire := CircuitComponent.new()
	return_wire.name = "ReturnWire"
	return_wire.component_id = "generator_return"
	return_wire.display_name = "Copper Return"
	return_wire.material_profile = CopperProfile
	return_wire.resistance_ohms = 0.2
	return_wire.position = Vector3(-2.0, 0.8, 1.5)
	ThermalLabGeometry.add_terminal(return_wire, "TerminalA", "a", Vector3(0.0, 0.0, 1.4), 0.36)
	ThermalLabGeometry.add_terminal(return_wire, "TerminalB", "b", Vector3(0.0, 0.0, -1.4), 0.36)
	ThermalLabGeometry.add_box_visual(
		return_wire,
		"WireBody",
		Vector3(0.14, 0.14, 2.8),
		Color(0.78, 0.3, 0.08, 1.0),
		true,
		0.7
	)
	circuit_root.add_child(return_wire)

	add_wire_visuals(circuit_root)
	var iron_puck := add_iron_puck(root, circuit_root.position + coil.position + Vector3(0.0, 0.0, 2.0))

	var valve := PressureReliefValve.new()
	valve.name = "ReliefValve"
	valve.position = Vector3(-3.15, 0.95, -0.15)
	valve.automatic_threshold_ratio = 0.92
	valve.automatic_vent_per_second = 36.0
	valve.manual_vent_amount = 1000.0
	ThermalPressureStation.add_valve_shape(valve)
	valve.configure(reservoir)
	root.add_child(valve)

	var readout := ThermalLabGeometry.add_label(
		host,
		"GeneratorReadout",
		"GENERATOR OFFLINE",
		Vector3(0.0, 4.35, 3.8),
		23,
		Color(0.72, 0.92, 1.0, 1.0)
	)
	var clutch_label := ThermalLabGeometry.add_label(
		host,
		"ClutchLabel",
		"GENERATOR CLUTCH\nINTERACT TO DISCONNECT",
		circuit_root.position + generator.position + Vector3(0.0, 1.65, 0.0),
		18,
		Color(0.82, 0.76, 1.0, 1.0)
	)

	solver.request_solve()
	return {
		"root": root,
		"water": water,
		"reservoir": reservoir,
		"thermal_adapter": thermal_adapter,
		"shaft": shaft,
		"turbine": turbine,
		"generator": generator,
		"solver": solver,
		"lamp": lamp,
		"lamp_light": lamp_light,
		"coil": coil,
		"magnetic_field": magnetic_field,
		"iron_puck": iron_puck,
		"valve": valve,
		"readout": readout,
		"clutch_label": clutch_label,
	}


static func add_turbine_rotor(shaft: RotationalShaftState) -> void:
	var rotor := MeshInstance3D.new()
	rotor.name = "Rotor"
	var rotor_mesh := CylinderMesh.new()
	rotor_mesh.top_radius = 0.72
	rotor_mesh.bottom_radius = 0.72
	rotor_mesh.height = 0.42
	rotor_mesh.radial_segments = 20
	rotor.mesh = rotor_mesh
	rotor.rotation_degrees.x = 90.0
	rotor.material_override = ThermalLabGeometry.make_material(Color(0.26, 0.58, 0.72, 1.0), true, 1.6)
	shaft.add_child(rotor)
	for angle: float in [0.0, 45.0, 90.0, 135.0]:
		var blade := ThermalLabGeometry.add_box_visual(
			rotor,
			"Blade",
			Vector3(1.85, 0.14, 0.18),
			Color(0.55, 0.82, 0.92, 1.0),
			true,
			1.2
		)
		blade.rotation_degrees.y = angle


static func add_drive_pipe(root: Node3D, boiler_position: Vector3, shaft_position: Vector3) -> void:
	var midpoint: Vector3 = (boiler_position + shaft_position) * 0.5 + Vector3(0.0, 0.35, 0.0)
	var pipe := ThermalLabGeometry.add_box_visual(
		root,
		"SteamDrivePipe",
		Vector3(absf(shaft_position.x - boiler_position.x), 0.28, 0.28),
		Color(0.46, 0.62, 0.72, 1.0),
		true,
		0.8
	)
	pipe.position = midpoint


static func add_generator_interaction(generator: RotationalGeneratorSource) -> void:
	var area := Area3D.new()
	area.name = "ClutchInteractionArea"
	area.monitoring = false
	area.monitorable = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 1.8, 1.8)
	collision.shape = shape
	area.add_child(collision)
	generator.add_child(area)
	var handle := ThermalLabGeometry.add_box_visual(
		generator,
		"ClutchHandle",
		Vector3(0.22, 1.15, 0.22),
		Color(0.7, 0.34, 0.9, 1.0),
		true,
		2.0
	)
	handle.position = Vector3(0.0, 1.05, 0.0)


static func add_coil_visual(coil: ElectromagneticCoilComponent) -> void:
	ThermalLabGeometry.add_box_visual(
		coil,
		"IronCore",
		Vector3(2.4, 0.7, 0.7),
		Color(0.3, 0.34, 0.4, 1.0),
		true,
		0.8
	)
	var torus := MeshInstance3D.new()
	torus.name = "CoilMesh"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.56
	mesh.outer_radius = 0.76
	mesh.rings = 20
	mesh.ring_segments = 10
	torus.mesh = mesh
	torus.rotation_degrees.z = 90.0
	torus.material_override = ThermalLabGeometry.make_material(Color(0.86, 0.28, 0.05, 1.0), true, 1.8)
	coil.add_child(torus)


static func add_wire_visuals(circuit_root: Node3D) -> void:
	var bottom := ThermalLabGeometry.add_box_visual(
		circuit_root,
		"BottomWire",
		Vector3(4.0, 0.14, 0.14),
		Color(0.78, 0.3, 0.08, 1.0),
		true,
		0.7
	)
	bottom.position = Vector3(0.0, 0.8, 0.0)
	var top := ThermalLabGeometry.add_box_visual(
		circuit_root,
		"TopWire",
		Vector3(4.0, 0.14, 0.14),
		Color(0.78, 0.3, 0.08, 1.0),
		true,
		0.7
	)
	top.position = Vector3(0.0, 0.8, 3.0)


static func add_iron_puck(root: Node3D, position_value: Vector3) -> FieldResponsiveBody:
	var body := FieldResponsiveBody.new()
	body.name = "IronPuck"
	body.body_label = "Generator Iron Puck"
	body.material_profile = IronProfile
	body.mass_override_kg = 1.2
	body.position = position_value
	body.floor_snap_length = 0.35
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.42
	shape.height = 0.8
	collision.shape = shape
	body.add_child(collision)
	var mesh_node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.42
	mesh.height = 0.8
	mesh.radial_segments = 16
	mesh_node.mesh = mesh
	mesh_node.material_override = ThermalLabGeometry.make_material(Color(0.3, 0.34, 0.4, 1.0), true, 0.6)
	body.add_child(mesh_node)
	var force_receiver := ForceReceiver.new()
	force_receiver.name = "ForceReceiver"
	force_receiver.drag = 5.0
	force_receiver.max_force_speed = 3.5
	body.add_child(force_receiver)
	var field_receiver := PhysicalFieldReceiver.new()
	field_receiver.name = "PhysicalFieldReceiver"
	field_receiver.material_profile = IronProfile
	field_receiver.field_force_scale = 7.0
	body.add_child(field_receiver)
	root.add_child(body)
	return body
