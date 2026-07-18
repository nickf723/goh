extends RefCounted
class_name ElectricalInteroperabilityTestFixture

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var fixture := Node3D.new()
	fixture.name = "ElectricalInteroperabilityFixture"
	host.add_child(fixture)

	var battery := CircuitVoltageSource.new()
	battery.name = "Battery"
	battery.component_id = "battery"
	battery.nominal_voltage_volts = 12.0
	battery.source_internal_resistance_ohms = 0.2
	add_terminals(battery)
	fixture.add_child(battery)

	var port := CircuitExcitationPort.new()
	port.name = "ExcitationPort"
	port.component_id = "excitation_port"
	port.material_profile = CopperProfile
	port.default_voltage_volts = 48.0
	port.default_duration_seconds = 0.5
	port.default_source_resistance_ohms = 0.6
	port.default_current_limit_amps = 14.0
	port.path_enabled = false
	add_terminals(port)
	fixture.add_child(port)

	var load := CircuitComponent.new()
	load.name = "SharedLoad"
	load.component_id = "shared_load"
	load.component_kind = "load"
	load.material_profile = CopperProfile
	load.resistance_ohms = 4.0
	add_terminals(load)
	fixture.add_child(load)

	var solver := DCCircuitSolver.new()
	solver.name = "Solver"
	solver.auto_solve = false
	fixture.add_child(solver)

	var selector := CircuitSourceSelector.new()
	selector.name = "Selector"
	selector.initial_mode = "battery"
	fixture.add_child(selector)
	selector.configure_sources(battery, port)
	await host.get_tree().process_frame

	solver.solve_network()
	if not solver.circuit_closed or not load.energized:
		failures.append("interoperability: battery mode should provide steady current to the shared load")
	var battery_current: float = solver.current_amps
	if battery_current <= 0.0:
		failures.append("interoperability: battery current should be positive")

	selector.set_mode("lightning")
	solver.solve_network()
	if solver.circuit_closed:
		failures.append("interoperability: an unexcited Lightning port should leave the circuit open")

	var lightning_payload := DamagePayload.new()
	lightning_payload.element = "lightning"
	lightning_payload.source_name = "Lightning Spark"
	lightning_payload.hit_type = "projectile"
	lightning_payload.status_duration = 0.35
	lightning_payload.status_strength = 1.0
	lightning_payload.tags = ["lightning", "shock", "magic", "projectile"]
	port.receive_damage_payload(lightning_payload)
	solver.solve_network()
	if not solver.circuit_closed or not load.energized:
		failures.append("interoperability: Lightning spell payload should power the shared circuit")
	if port.last_excitation_source != "Lightning Spark":
		failures.append("interoperability: circuit port should preserve the spell source identity")
	if solver.current_amps <= battery_current:
		failures.append("interoperability: high-voltage Lightning pulse should differ from the steady battery source")

	var accepted_before_fire: int = port.accepted_pulse_count
	var fire_payload := DamagePayload.new()
	fire_payload.element = "fire"
	fire_payload.source_name = "Firebolt"
	fire_payload.tags = ["fire", "magic", "projectile"]
	port.receive_damage_payload(fire_payload)
	if port.accepted_pulse_count != accepted_before_fire:
		failures.append("interoperability: non-electrical payloads must not excite the circuit port")

	port.clear_excitation()
	solver.solve_network()
	if solver.circuit_closed:
		failures.append("interoperability: circuit should open when transient excitation expires")

	var environmental_emitter := ElementEmitter.new()
	environmental_emitter.name = "StormEmitter"
	environmental_emitter.element = "lightning"
	environmental_emitter.display_name = "Captured Storm Lightning"
	environmental_emitter.payload_tags = ["lightning", "shock", "electrical", "environment", "storm"]
	environmental_emitter.pulse_on_ready = false
	fixture.add_child(environmental_emitter)
	await host.get_tree().process_frame
	port.receive_damage_payload(environmental_emitter.build_payload())
	solver.solve_network()
	if not solver.circuit_closed or not load.energized:
		failures.append("interoperability: environmental Lightning payload should power the same shared circuit")
	if port.last_excitation_source != "Captured Storm Lightning":
		failures.append("interoperability: environmental source identity should reach the circuit port")

	fixture.queue_free()
	return failures


static func add_terminals(component: CircuitComponent) -> void:
	var terminal_a := CircuitTerminal.new()
	terminal_a.name = "TerminalA"
	terminal_a.terminal_id = "a"
	terminal_a.position = Vector3(-2.0, 0.0, 0.0)
	component.add_child(terminal_a)
	var terminal_b := CircuitTerminal.new()
	terminal_b.name = "TerminalB"
	terminal_b.terminal_id = "b"
	terminal_b.position = Vector3(2.0, 0.0, 0.0)
	component.add_child(terminal_b)
