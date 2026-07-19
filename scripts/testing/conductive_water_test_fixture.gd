extends RefCounted
class_name ConductiveWaterTestFixture

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")
const WaterProfile: PhysicalMaterialProfile = preload("res://data/materials/water_physical_profile.tres")


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var fixture := Node3D.new()
	fixture.name = "ConductiveWaterFixture"
	host.add_child(fixture)

	var battery := CircuitVoltageSource.new()
	battery.name = "Battery"
	battery.component_id = "water_test_battery"
	battery.nominal_voltage_volts = 12.0
	battery.source_internal_resistance_ohms = 0.2
	add_terminals(battery, Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0))
	fixture.add_child(battery)

	var port := CircuitExcitationPort.new()
	port.name = "ExcitationPort"
	port.component_id = "water_test_excitation"
	port.default_voltage_volts = 48.0
	port.default_duration_seconds = 0.5
	port.default_source_resistance_ohms = 0.6
	port.path_enabled = false
	add_terminals(port, Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0))
	fixture.add_child(port)

	var load := CircuitComponent.new()
	load.name = "Load"
	load.component_id = "water_test_load"
	load.component_kind = "load"
	load.material_profile = CopperProfile
	load.resistance_ohms = 3.0
	add_terminals(load, Vector3(-2.0, 0.0, 0.0), Vector3(-2.0, 0.0, 2.0))
	fixture.add_child(load)

	var return_wire := CircuitComponent.new()
	return_wire.name = "ReturnWire"
	return_wire.component_id = "water_test_return"
	return_wire.material_profile = CopperProfile
	return_wire.resistance_ohms = 0.2
	add_terminals(return_wire, Vector3(2.0, 0.0, 2.0), Vector3(2.0, 0.0, 0.0))
	fixture.add_child(return_wire)

	var water := ConductiveWaterVolume.new()
	water.name = "Water"
	water.component_id = "water_test_pool"
	water.material_profile = WaterProfile
	water.position = Vector3(0.0, 0.0, 2.0)
	water.volume_size = Vector3(4.8, 1.0, 1.0)
	water.conductivity_scale = WaterProfile.electrical_conductivity
	water.resistance_per_meter_ohms = WaterProfile.electrical_resistivity * 0.22
	fixture.add_child(water)
	water.configure_excitation_port(port)

	var selector := CircuitSourceSelector.new()
	selector.name = "Selector"
	selector.initial_mode = "battery"
	fixture.add_child(selector)
	selector.configure_sources(battery, port)

	var solver := DCCircuitSolver.new()
	solver.name = "Solver"
	solver.auto_solve = false
	fixture.add_child(solver)
	await host.get_tree().process_frame
	await host.get_tree().process_frame

	water.scan_immersed_terminals()
	solver.solve_network()
	if water.immersed_terminal_keys.size() != 2:
		failures.append("conductive water: a filled pool should discover exactly two immersed electrodes")
	if not solver.circuit_closed or not load.energized:
		failures.append("conductive water: filled water should close the battery circuit")
	if water.resistance_ohms <= return_wire.resistance_ohms:
		failures.append("conductive water: water should resist current more than the copper return wire")

	water.set_filled(false)
	solver.solve_network()
	if solver.circuit_closed:
		failures.append("conductive water: draining the pool should open the circuit")

	water.set_filled(true)
	selector.set_mode("lightning")
	water.scan_immersed_terminals()
	solver.solve_network()
	if solver.circuit_closed:
		failures.append("conductive water: unexcited water in Lightning mode should remain unpowered")

	var lightning_payload := DamagePayload.new()
	lightning_payload.element = "lightning"
	lightning_payload.source_name = "Lightning Spark"
	lightning_payload.hit_type = "projectile"
	lightning_payload.status_duration = 0.35
	lightning_payload.tags = ["lightning", "shock", "magic", "projectile"]
	water.receive_damage_payload(lightning_payload)
	solver.solve_network()
	if not solver.circuit_closed or not load.energized:
		failures.append("conductive water: Lightning striking the pool should power the shared circuit")
	if not water.get_hazard_tags().has("electrified"):
		failures.append("conductive water: Lightning should expose an electrified water state")

	var accepted_before_fire: int = port.accepted_pulse_count
	var fire_payload := DamagePayload.new()
	fire_payload.element = "fire"
	fire_payload.source_name = "Firebolt"
	fire_payload.tags = ["fire", "magic", "projectile"]
	water.receive_damage_payload(fire_payload)
	if port.accepted_pulse_count != accepted_before_fire:
		failures.append("conductive water: Fire must not become electrical excitation")

	return_wire.get_terminal_a().position = Vector3(4.0, 0.0, 2.0)
	water.scan_immersed_terminals()
	solver.solve_network()
	if solver.circuit_closed:
		failures.append("conductive water: moving an electrode outside the pool should break the path")

	fixture.queue_free()
	return failures


static func add_terminals(
	component: CircuitComponent,
	position_a: Vector3,
	position_b: Vector3
) -> void:
	var terminal_a := CircuitTerminal.new()
	terminal_a.name = "TerminalA"
	terminal_a.terminal_id = "a"
	terminal_a.position = position_a
	component.add_child(terminal_a)
	var terminal_b := CircuitTerminal.new()
	terminal_b.name = "TerminalB"
	terminal_b.terminal_id = "b"
	terminal_b.position = position_b
	component.add_child(terminal_b)
