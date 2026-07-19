extends RefCounted
class_name GeneratorTestFixture

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var root := Node3D.new()
	root.name = "GeneratorFixture"
	host.add_child(root)

	var state := ThermalState.new()
	state.name = "ThermalState"
	state.starting_temperature_c = 20.0
	state.ambient_temperature_c = 20.0
	state.passive_ambient_exchange = false
	state.heat_capacity_override_j_per_c = 8.0
	state.phase_changes_enabled = true
	state.use_material_phase_points = false
	state.freezing_point_c = 0.0
	state.boiling_point_c = 100.0
	state.phase_hysteresis_c = 1.5
	state.fire_energy_j_per_intensity = 180.0
	state.ice_energy_j_per_intensity = 180.0
	root.add_child(state)

	var reservoir := PressureReservoir.new()
	reservoir.name = "PressureReservoir"
	reservoir.maximum_pressure = 100.0
	reservoir.leak_enabled = false
	root.add_child(reservoir)

	var thermal_adapter := ThermalPressureAdapter.new()
	thermal_adapter.name = "ThermalPressureAdapter"
	thermal_adapter.base_output_per_second = 18.0
	thermal_adapter.output_per_superheat_c = 0.55
	thermal_adapter.maximum_output_per_second = 42.0
	thermal_adapter.condensation_per_second = 28.0
	thermal_adapter.configure(state, reservoir)
	root.add_child(thermal_adapter)

	var shaft := RotationalShaftState.new()
	shaft.name = "Shaft"
	shaft.acceleration_rpm_per_second = 1000.0
	shaft.deceleration_rpm_per_second = 1000.0
	shaft.maximum_abs_rpm = 1800.0
	root.add_child(shaft)

	var turbine := PressureTurbine.new()
	turbine.name = "PressureTurbine"
	turbine.minimum_operating_pressure = 8.0
	turbine.full_speed_pressure = 70.0
	turbine.maximum_rpm = 1500.0
	turbine.idle_consumption_per_second = 2.0
	turbine.full_consumption_per_second = 16.0
	turbine.configure(reservoir, shaft)
	root.add_child(turbine)

	var generator := RotationalGeneratorSource.new()
	generator.name = "Generator"
	generator.component_id = "fixture_generator"
	generator.display_name = "Fixture Generator"
	generator.source_internal_resistance_ohms = 0.35
	generator.minimum_generation_rpm = 120.0
	generator.volts_per_1000_rpm = 12.0
	generator.maximum_output_voltage = 18.0
	generator.configure_shaft(shaft)
	add_terminals(generator, Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0))
	root.add_child(generator)

	var lamp := CircuitComponent.new()
	lamp.name = "Lamp"
	lamp.component_id = "fixture_lamp"
	lamp.material_profile = CopperProfile
	lamp.resistance_ohms = 3.0
	lamp.position = Vector3(2.0, 0.0, 1.5)
	add_terminals(lamp, Vector3(0.0, 0.0, -1.4), Vector3(0.0, 0.0, 1.4))
	root.add_child(lamp)

	var coil := ElectromagneticCoilComponent.new()
	coil.name = "Coil"
	coil.component_id = "fixture_coil"
	coil.material_profile = CopperProfile
	coil.resistance_ohms = 2.2
	coil.position = Vector3(0.0, 0.0, 3.0)
	add_terminals(coil, Vector3(2.0, 0.0, 0.0), Vector3(-2.0, 0.0, 0.0))
	var field := MagneticDipoleField.new()
	field.name = "MagneticField"
	field.active = false
	coil.add_child(field)
	root.add_child(coil)

	var return_wire := CircuitComponent.new()
	return_wire.name = "ReturnWire"
	return_wire.component_id = "fixture_return"
	return_wire.material_profile = CopperProfile
	return_wire.resistance_ohms = 0.2
	return_wire.position = Vector3(-2.0, 0.0, 1.5)
	add_terminals(return_wire, Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, -1.4))
	root.add_child(return_wire)

	var solver := DCCircuitSolver.new()
	solver.name = "DCCircuitSolver"
	solver.auto_solve = false
	root.add_child(solver)

	await host.get_tree().process_frame
	await host.get_tree().process_frame

	test_no_pressure_baseline(reservoir, turbine, shaft, generator, solver, failures)
	test_fire_to_electricity(state, reservoir, thermal_adapter, turbine, shaft, generator, solver, lamp, coil, field, failures)
	test_clutch_separation(shaft, generator, solver, lamp, failures)
	test_voltage_scaling_and_polarity(shaft, generator, failures)
	test_condensation_shutdown(state, reservoir, thermal_adapter, turbine, shaft, generator, solver, failures)

	root.queue_free()
	return failures


static func test_no_pressure_baseline(
	reservoir: PressureReservoir,
	turbine: PressureTurbine,
	shaft: RotationalShaftState,
	generator: RotationalGeneratorSource,
	solver: DCCircuitSolver,
	failures: Array[String]
) -> void:
	reservoir.set_pressure(0.0, "baseline")
	turbine.step_turbine(1.0)
	shaft.step_rotation(1.0)
	generator.update_generated_voltage(true)
	solver.solve_network()
	if not is_zero_approx(shaft.current_rpm) or not is_zero_approx(generator.generated_voltage):
		failures.append("generator: zero pressure should produce zero shaft speed and zero voltage")
	if solver.circuit_closed:
		failures.append("generator: zero generated voltage should leave the circuit open")


static func test_fire_to_electricity(
	state: ThermalState,
	reservoir: PressureReservoir,
	thermal_adapter: ThermalPressureAdapter,
	turbine: PressureTurbine,
	shaft: RotationalShaftState,
	generator: RotationalGeneratorSource,
	solver: DCCircuitSolver,
	lamp: CircuitComponent,
	coil: ElectromagneticCoilComponent,
	field: MagneticDipoleField,
	failures: Array[String]
) -> void:
	state.set_temperature(20.0, "fire chain reset")
	reservoir.set_pressure(0.0, "fire chain reset")
	state.receive_damage_payload(make_payload("fire", "Firebolt", 2, 1.0, ["fire", "burning"]))
	state.receive_damage_payload(make_payload("fire", "Firebolt", 2, 1.0, ["fire", "burning"]))
	if not state.is_gas():
		failures.append("generator: two tuned Firebolts should create steam")
	thermal_adapter.step_conversion(3.0)
	var pressure_before_turbine: float = reservoir.current_pressure
	turbine.step_turbine(0.25)
	shaft.step_rotation(2.0)
	generator.update_generated_voltage(true)
	solver.solve_network()
	if reservoir.current_pressure >= pressure_before_turbine:
		failures.append("generator: the turbine should consume stored pressure")
	if shaft.current_rpm <= generator.minimum_generation_rpm:
		failures.append("generator: pressure should accelerate the shaft above generation speed")
	if generator.generated_voltage <= 0.0:
		failures.append("generator: shaft rotation should create generator voltage")
	if not solver.circuit_closed or solver.current_amps <= 0.0:
		failures.append("generator: generated voltage should power the ordinary DC circuit")
	if not lamp.energized or not coil.energized or not field.active:
		failures.append("generator: the generated circuit should energize both lamp and electromagnet")


static func test_clutch_separation(
	shaft: RotationalShaftState,
	generator: RotationalGeneratorSource,
	solver: DCCircuitSolver,
	lamp: CircuitComponent,
	failures: Array[String]
) -> void:
	var spinning_rpm: float = shaft.current_rpm
	generator.set_coupled(false)
	solver.solve_network()
	if shaft.current_rpm != spinning_rpm:
		failures.append("generator: disconnecting the electrical clutch should not erase shaft rotation")
	if solver.circuit_closed or lamp.energized or generator.generated_voltage > 0.0:
		failures.append("generator: a disconnected clutch should remove electrical output while the shaft remains spinning")
	generator.set_coupled(true)
	generator.update_generated_voltage(true)
	solver.solve_network()
	if not solver.circuit_closed:
		failures.append("generator: reconnecting the clutch should restore the powered circuit")


static func test_voltage_scaling_and_polarity(
	shaft: RotationalShaftState,
	generator: RotationalGeneratorSource,
	failures: Array[String]
) -> void:
	shaft.current_rpm = 500.0
	generator.update_generated_voltage(true)
	var low_voltage: float = generator.generated_voltage
	shaft.current_rpm = 1000.0
	generator.update_generated_voltage(true)
	if generator.generated_voltage <= low_voltage:
		failures.append("generator: higher shaft speed should produce higher voltage")
	shaft.current_rpm = -1000.0
	generator.update_generated_voltage(true)
	if generator.get_source_voltage() >= 0.0:
		failures.append("generator: reversing shaft direction should reverse generator polarity")
	shaft.current_rpm = 1000.0
	generator.update_generated_voltage(true)


static func test_condensation_shutdown(
	state: ThermalState,
	reservoir: PressureReservoir,
	thermal_adapter: ThermalPressureAdapter,
	turbine: PressureTurbine,
	shaft: RotationalShaftState,
	generator: RotationalGeneratorSource,
	solver: DCCircuitSolver,
	failures: Array[String]
) -> void:
	state.set_temperature(110.0, "condensation setup")
	reservoir.set_pressure(55.0, "condensation setup")
	state.receive_damage_payload(make_payload("ice", "Ice Lance", 1, 1.0, ["ice", "chill"]))
	if state.is_gas():
		failures.append("generator: Ice should condense the tuned steam source")
	thermal_adapter.step_conversion(3.0)
	turbine.step_turbine(1.0)
	shaft.step_rotation(3.0)
	generator.update_generated_voltage(true)
	solver.solve_network()
	if reservoir.current_pressure > turbine.minimum_operating_pressure:
		failures.append("generator: condensation should drain pressure below turbine operating range")
	if not is_zero_approx(shaft.current_rpm) or generator.generated_voltage > 0.0 or solver.circuit_closed:
		failures.append("generator: condensation should stop rotation, voltage, and circuit current")


static func make_payload(
	element: String,
	source_name: String,
	amount: int,
	strength: float,
	tags: Array[String]
) -> DamagePayload:
	var payload := DamagePayload.new()
	payload.element = element
	payload.source_name = source_name
	payload.amount = amount
	payload.status_strength = strength
	payload.tags = tags
	return payload


static func add_terminals(component: CircuitComponent, position_a: Vector3, position_b: Vector3) -> void:
	var terminal_a := CircuitTerminal.new()
	terminal_a.name = "TerminalA"
	terminal_a.terminal_id = "a"
	terminal_a.position = position_a
	terminal_a.connection_radius = 0.36
	component.add_child(terminal_a)
	var terminal_b := CircuitTerminal.new()
	terminal_b.name = "TerminalB"
	terminal_b.terminal_id = "b"
	terminal_b.position = position_b
	terminal_b.connection_radius = 0.36
	component.add_child(terminal_b)
