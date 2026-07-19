extends RefCounted
class_name ThermalPhaseCircuitStation

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")
const WaterProfile: PhysicalMaterialProfile = preload("res://data/materials/water_physical_profile.tres")


static func build(host: Node3D) -> Dictionary:
	ThermalLabGeometry.add_label(
		host,
		"PhaseTitle",
		"PHASE → CIRCUIT",
		Vector3(0.0, 3.0, 3.0),
		27,
		Color(0.58, 0.86, 1.0, 1.0)
	)
	var circuit_root := Node3D.new()
	circuit_root.name = "WaterPhaseCircuit"
	host.add_child(circuit_root)

	var solver := DCCircuitSolver.new()
	solver.name = "DCCircuitSolver"
	solver.solve_interval = 0.05
	circuit_root.add_child(solver)

	var source := CircuitVoltageSource.new()
	source.name = "Battery"
	source.component_id = "thermal_water_battery"
	source.display_name = "Water Test Battery"
	source.nominal_voltage_volts = 12.0
	source.source_internal_resistance_ohms = 0.2
	source.max_current_amps = 8.0
	source.position = Vector3(0.0, 0.7, -0.2)
	ThermalLabGeometry.add_terminal(source, "TerminalA", "negative", Vector3(-2.0, 0.0, 0.0))
	ThermalLabGeometry.add_terminal(source, "TerminalB", "positive", Vector3(2.0, 0.0, 0.0))
	ThermalLabGeometry.add_box_visual(source, "Body", Vector3(1.25, 0.9, 0.8), Color(0.16, 0.2, 0.28, 1.0))
	circuit_root.add_child(source)

	var lamp := CircuitComponent.new()
	lamp.name = "PhaseLamp"
	lamp.component_id = "thermal_phase_lamp"
	lamp.display_name = "Phase Lamp"
	lamp.component_kind = "load"
	lamp.material_profile = CopperProfile
	lamp.resistance_ohms = 2.0
	lamp.position = Vector3(2.0, 0.7, 0.9)
	ThermalLabGeometry.add_terminal(lamp, "TerminalA", "a", Vector3(0.0, 0.0, -1.0))
	ThermalLabGeometry.add_terminal(lamp, "TerminalB", "b", Vector3(0.0, 0.0, 1.0))
	var bulb := MeshInstance3D.new()
	bulb.name = "Bulb"
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.45
	bulb_mesh.height = 0.9
	bulb.mesh = bulb_mesh
	bulb.material_override = ThermalLabGeometry.make_material(Color(0.92, 0.72, 0.2, 0.7), true, 2.6)
	lamp.add_child(bulb)
	var lamp_light := OmniLight3D.new()
	lamp_light.name = "LampLight"
	lamp_light.light_color = Color(1.0, 0.48, 0.08, 1.0)
	lamp_light.light_energy = 3.0
	lamp_light.omni_range = 4.0
	lamp.add_child(lamp_light)
	circuit_root.add_child(lamp)

	var return_wire := CircuitComponent.new()
	return_wire.name = "ReturnWire"
	return_wire.component_id = "thermal_water_return"
	return_wire.display_name = "Copper Return"
	return_wire.material_profile = CopperProfile
	return_wire.resistance_ohms = 0.2
	return_wire.position = Vector3(-2.0, 0.7, 0.9)
	ThermalLabGeometry.add_terminal(return_wire, "TerminalA", "a", Vector3(0.0, 0.0, -1.0))
	ThermalLabGeometry.add_terminal(return_wire, "TerminalB", "b", Vector3(0.0, 0.0, 1.0))
	ThermalLabGeometry.add_box_visual(return_wire, "Body", Vector3(0.12, 0.12, 2.0), Color(0.72, 0.28, 0.08, 1.0))
	circuit_root.add_child(return_wire)

	var water := ThermalWaterVolume.new()
	water.name = "ThermalWater"
	water.component_id = "thermal_phase_water"
	water.material_profile = WaterProfile
	water.volume_size = Vector3(4.5, 0.8, 1.55)
	water.position = Vector3(0.0, 0.55, 1.9)
	water.starts_filled = true
	water.conductivity_scale = 0.28
	water.resistance_per_meter_ohms = 0.45
	water.minimum_resistance_ohms = 0.5
	var spell_capture := Area3D.new()
	spell_capture.name = "SpellCaptureArea"
	spell_capture.monitoring = false
	spell_capture.monitorable = true
	var spell_capture_collision := CollisionShape3D.new()
	spell_capture_collision.name = "CollisionShape3D"
	spell_capture_collision.position = Vector3(0.0, 0.9, 0.0)
	var spell_capture_shape := BoxShape3D.new()
	spell_capture_shape.size = Vector3(5.2, 2.6, 2.2)
	spell_capture_collision.shape = spell_capture_shape
	spell_capture.add_child(spell_capture_collision)
	water.add_child(spell_capture)
	circuit_root.add_child(water)

	var readout := ThermalLabGeometry.add_label(
		host,
		"WaterReadout",
		"WATER CIRCUIT",
		Vector3(0.0, 2.15, 3.3),
		20,
		Color(0.72, 0.92, 1.0, 1.0)
	)
	solver.request_solve()
	return {
		"root": circuit_root,
		"solver": solver,
		"source": source,
		"lamp": lamp,
		"lamp_light": lamp_light,
		"water": water,
		"spell_capture": spell_capture,
		"readout": readout,
	}
