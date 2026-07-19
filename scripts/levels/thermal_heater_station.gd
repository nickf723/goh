extends RefCounted
class_name ThermalHeaterStation

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")


static func build(host: Node3D) -> Dictionary:
	ThermalLabGeometry.add_label(
		host,
		"HeaterTitle",
		"CURRENT → HEAT",
		Vector3(5.25, 3.0, 3.0),
		27,
		Color(1.0, 0.56, 0.34, 1.0)
	)
	var circuit_root := Node3D.new()
	circuit_root.name = "ResistiveHeaterCircuit"
	circuit_root.position = Vector3(5.25, 0.0, 0.0)
	host.add_child(circuit_root)

	var solver := DCCircuitSolver.new()
	solver.name = "DCCircuitSolver"
	solver.solve_interval = 0.05
	circuit_root.add_child(solver)

	var source := CircuitVoltageSource.new()
	source.name = "Battery"
	source.component_id = "heater_battery"
	source.display_name = "Heater Battery"
	source.nominal_voltage_volts = 12.0
	source.source_internal_resistance_ohms = 0.2
	source.max_current_amps = 8.0
	source.position = Vector3(0.0, 0.7, 0.0)
	ThermalLabGeometry.add_terminal(source, "TerminalA", "negative", Vector3(-1.5, 0.0, 0.0))
	ThermalLabGeometry.add_terminal(source, "TerminalB", "positive", Vector3(1.5, 0.0, 0.0))
	ThermalLabGeometry.add_box_visual(source, "Body", Vector3(1.1, 0.8, 0.7), Color(0.16, 0.2, 0.28, 1.0))
	circuit_root.add_child(source)

	var heater := CircuitComponent.new()
	heater.name = "HeatingResistor"
	heater.component_id = "heating_resistor"
	heater.display_name = "Heating Resistor"
	heater.component_kind = "resistive_heater"
	heater.material_profile = CopperProfile
	heater.resistance_ohms = 4.0
	heater.position = Vector3(0.0, 0.85, 1.8)
	ThermalLabGeometry.add_terminal(heater, "TerminalA", "a", Vector3(1.5, 0.0, 0.0))
	ThermalLabGeometry.add_terminal(heater, "TerminalB", "b", Vector3(-1.5, 0.0, 0.0))
	var heater_mesh := ThermalLabGeometry.add_box_visual(
		heater,
		"Body",
		Vector3(2.4, 0.65, 0.75),
		Color(0.42, 0.18, 0.08, 1.0),
		true,
		1.6
	)
	var state := ThermalState.new()
	state.name = "ThermalState"
	state.material_profile = CopperProfile
	state.starting_temperature_c = 20.0
	state.ambient_temperature_c = 20.0
	state.heat_capacity_override_j_per_c = 15.0
	state.ambient_conductance_j_per_second_c = 0.12
	heater.add_child(state)
	var adapter := CircuitThermalAdapter.new()
	adapter.name = "CircuitThermalAdapter"
	adapter.joule_heat_scale = 1.5
	adapter.maximum_heat_power_w = 180.0
	heater.add_child(adapter)
	circuit_root.add_child(heater)

	var right_wire := build_wire(circuit_root, "RightWire", "heater_right_wire", Vector3(1.5, 0.7, 0.9))
	var left_wire := build_wire(circuit_root, "LeftWire", "heater_left_wire", Vector3(-1.5, 0.7, 0.9))

	var readout := ThermalLabGeometry.add_label(
		host,
		"HeaterReadout",
		"RESISTIVE HEATER",
		Vector3(5.25, 2.1, 3.15),
		20,
		Color(1.0, 0.78, 0.58, 1.0)
	)
	solver.request_solve()
	return {
		"root": circuit_root,
		"solver": solver,
		"source": source,
		"heater": heater,
		"state": state,
		"adapter": adapter,
		"mesh": heater_mesh,
		"right_wire": right_wire,
		"left_wire": left_wire,
		"readout": readout,
	}


static func build_wire(
	circuit_root: Node3D,
	node_name: String,
	component_id: String,
	position_value: Vector3
) -> CircuitComponent:
	var wire := CircuitComponent.new()
	wire.name = node_name
	wire.component_id = component_id
	wire.material_profile = CopperProfile
	wire.resistance_ohms = 0.2
	wire.position = position_value
	ThermalLabGeometry.add_terminal(wire, "TerminalA", "a", Vector3(0.0, 0.0, -0.8))
	ThermalLabGeometry.add_terminal(wire, "TerminalB", "b", Vector3(0.0, 0.0, 0.8))
	ThermalLabGeometry.add_box_visual(wire, "Body", Vector3(0.12, 0.12, 1.6), Color(0.72, 0.28, 0.08, 1.0))
	circuit_root.add_child(wire)
	return wire
