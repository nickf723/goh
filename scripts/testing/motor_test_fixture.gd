extends RefCounted
class_name MotorTestFixture

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var root := Node3D.new()
	root.name = "MotorFixture"
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

	var generator_shaft := RotationalShaftState.new()
	generator_shaft.name = "GeneratorShaft"
	generator_shaft.acceleration_rpm_per_second = 1000.0
	generator_shaft.deceleration_rpm_per_second = 1000.0
	generator_shaft.maximum_abs_rpm = 1800.0
	root.add_child(generator_shaft)

	var turbine := PressureTurbine.new()
	turbine.name = "PressureTurbine"
	turbine.minimum_operating_pressure = 8.0
	turbine.full_speed_pressure = 70.0
	turbine.maximum_rpm = 1500.0
	turbine.idle_consumption_per_second = 2.0
	turbine.full_consumption_per_second = 16.0
	turbine.configure(reservoir, generator_shaft)
	root.add_child(turbine)

	var generator := RotationalGeneratorSource.new()
	generator.name = "Generator"
	generator.component_id = "motor_fixture_generator"
	generator.source_internal_resistance_ohms = 0.35
	generator.minimum_generation_rpm = 120.0
	generator.volts_per_1000_rpm = 12.0
	generator.maximum_output_voltage = 18.0
	generator.configure_shaft(generator_shaft)
	add_terminals(generator, Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0))
	root.add_child(generator)

	var lamp := CircuitComponent.new()
	lamp.name = "Lamp"
	lamp.component_id = "motor_fixture_lamp"
	lamp.material_profile = CopperProfile
	lamp.resistance_ohms = 3.0
	lamp.position = Vector3(2.0, 0.0, 1.5)
	add_terminals(lamp, Vector3(0.0, 0.0, -1.4), Vector3(0.0, 0.0, 1.4))
	root.add_child(lamp)

	var motor_shaft := RotationalShaftState.new()
	motor_shaft.name = "MotorShaft"
	motor_shaft.acceleration_rpm_per_second = 1200.0
	motor_shaft.deceleration_rpm_per_second = 500.0
	motor_shaft.maximum_abs_rpm = 1800.0
	root.add_child(motor_shaft)

	var motor := ElectricMotorComponent.new()
	motor.name = "Motor"
	motor.component_id = "motor_fixture_motor"
	motor.material_profile = CopperProfile
	motor.resistance_ohms = 2.6
	motor.rpm_per_amp = 470.0
	motor.maximum_output_rpm = 1600.0
	motor.configure_shaft(motor_shaft)
	motor.position = Vector3(0.0, 0.0, 3.0)
	add_terminals(motor, Vector3(2.0, 0.0, 0.0), Vector3(-2.0, 0.0, 0.0))
	root.add_child(motor)

	var return_wire := CircuitComponent.new()
	return_wire.name = "ReturnWire"
	return_wire.component_id = "motor_fixture_return"
	return_wire.material_profile = CopperProfile
	return_wire.resistance_ohms = 0.2
	return_wire.position = Vector3(-2.0, 0.0, 1.5)
	add_terminals(return_wire, Vector3(0.0, 0.0, 1.4), Vector3(0.0, 0.0, -1.4))
	root.add_child(return_wire)

	var solver := DCCircuitSolver.new()
	solver.name = "DCCircuitSolver"
	solver.auto_solve = false
	root.add_child(solver)

	var conveyor := RotationalConveyorDrive.new()
	conveyor.name = "Conveyor"
	conveyor.track_length = 5.0
	conveyor.revolutions_per_track_length = 5.0
	conveyor.starting_track_offset = 2.5
	var carriage := Node3D.new()
	carriage.name = "Carriage"
	carriage.position = Vector3(0.0, 0.5, 0.0)
	conveyor.add_child(carriage)
	conveyor.configure(motor_shaft, carriage)
	root.add_child(conveyor)

	await host.get_tree().process_frame
	await host.get_tree().process_frame

	test_zero_energy_baseline(reservoir, turbine, generator_shaft, generator, solver, motor, motor_shaft, conveyor, failures)
	test_full_energy_chain(state, reservoir, thermal_adapter, turbine, generator_shaft, generator, solver, lamp, motor, motor_shaft, conveyor, failures)
	test_motor_direction(generator_shaft, generator, solver, motor, motor_shaft, failures)
	test_conveyor_clutch(motor_shaft, conveyor, carriage, failures)
	test_generator_clutch(generator, solver, motor, motor_shaft, failures)
	test_condensation_shutdown(state, reservoir, thermal_adapter, turbine, generator_shaft, generator, solver, motor_shaft, failures)

	root.queue_free()
	return failures


static func test_zero_energy_baseline(
	reservoir: PressureReservoir,
	turbine: PressureTurbine,
	generator_shaft: RotationalShaftState,
	generator: RotationalGeneratorSource,
	solver: DCCircuitSolver,
	motor: ElectricMotorComponent,
	motor_shaft: RotationalShaftState,
	conveyor: RotationalConveyorDrive,
	failures: Array[String]
) -> void:
	reservoir.set_pressure(0.0, "baseline")
	turbine.step_turbine(1.0)
	generator_shaft.step_rotation(1.0)
	generator.update_generated_voltage(true)
	solver.solve_network()
	motor_shaft.step_rotation(1.0)
	conveyor.step_drive()
	if not is_zero_approx(generator_shaft.current_rpm) or not is_zero_approx(generator.generated_voltage):
		failures.append("motor: zero pressure should leave the generator shaft and voltage at zero")
	if solver.circuit_closed or motor.running or not is_zero_approx(motor_shaft.current_rpm):
		failures.append("motor: zero electrical energy should leave the motor circuit and shaft inactive")
	if conveyor.total_distance_moved > 0.0:
		failures.append("motor: an inactive shaft should not move the conveyor")


static func test_full_energy_chain(
	state: ThermalState,
	reservoir: PressureReservoir,
	thermal_adapter: ThermalPressureAdapter,
	turbine: PressureTurbine,
	generator_shaft: RotationalShaftState,
	generator: RotationalGeneratorSource,
	solver: DCCircuitSolver,
	lamp: CircuitComponent,
	motor: ElectricMotorComponent,
	motor_shaft: RotationalShaftState,
	conveyor: RotationalConveyorDrive,
	failures: Array[String]
) -> void:
	state.set_temperature(20.0, "full chain reset")
	reservoir.set_pressure(0.0, "full chain reset")
	state.receive_damage_payload(make_payload("fire", "Firebolt", 2, 1.0, ["fire", "burning"]))
	state.receive_damage_payload(make_payload("fire", "Firebolt", 2, 1.0, ["fire", "burning"]))
	if not state.is_gas():
		failures.append("motor: two tuned Firebolts should create steam")
	thermal_adapter.step_conversion(3.0)
	turbine.step_turbine(0.25)
	generator_shaft.step_rotation(2.0)
	generator.update_generated_voltage(true)
	solver.solve_network()
	motor_shaft.step_rotation(2.0)
	var travel_before: float = conveyor.total_distance_moved
	conveyor.step_drive()
	if generator.generated_voltage <= 0.0 or not solver.circuit_closed or solver.current_amps <= 0.0:
		failures.append("motor: steam-driven generator voltage should power the motor circuit")
	if not lamp.energized or not motor.energized or not motor.running:
		failures.append("motor: the generated circuit should energize both lamp and motor")
	if absf(motor_shaft.current_rpm) <= 10.0:
		failures.append("motor: solved current should accelerate the motor shaft")
	if conveyor.total_distance_moved <= travel_before:
		failures.append("motor: motor shaft rotation should perform conveyor work")


static func test_motor_direction(
	generator_shaft: RotationalShaftState,
	generator: RotationalGeneratorSource,
	solver: DCCircuitSolver,
	motor: ElectricMotorComponent,
	motor_shaft: RotationalShaftState,
	failures: Array[String]
) -> void:
	var initial_current: float = motor.signed_current_amps
	var initial_target: float = motor.target_output_rpm
	motor.reverse_winding()
	if initial_target * motor.target_output_rpm >= 0.0:
		failures.append("motor: reversing the winding should reverse target shaft direction without changing source current")
	if not is_equal_approx(initial_current, motor.signed_current_amps):
		failures.append("motor: reversing the winding should not alter circuit current")
	motor_shaft.step_rotation(3.0)
	if motor_shaft.current_rpm * motor.target_output_rpm <= 0.0:
		failures.append("motor: the shaft should accelerate into the reversed winding direction")

	motor.set_winding_sign(1)
	generator_shaft.current_rpm = 1000.0
	generator.update_generated_voltage(true)
	solver.solve_network()
	var forward_current: float = motor.signed_current_amps
	generator_shaft.current_rpm = -1000.0
	generator.update_generated_voltage(true)
	solver.solve_network()
	if forward_current * motor.signed_current_amps >= 0.0:
		failures.append("motor: reversing source polarity should reverse current through the motor")
	if motor.target_output_rpm * motor.signed_current_amps <= 0.0:
		failures.append("motor: motor target direction should follow signed current with forward winding")
	generator_shaft.current_rpm = 1000.0
	generator.update_generated_voltage(true)
	solver.solve_network()


static func test_conveyor_clutch(
	motor_shaft: RotationalShaftState,
	conveyor: RotationalConveyorDrive,
	carriage: Node3D,
	failures: Array[String]
) -> void:
	var shaft_rpm_before: float = motor_shaft.current_rpm
	var carriage_before: Vector3 = carriage.position
	conveyor.set_coupled(false)
	motor_shaft.step_rotation(0.25)
	conveyor.step_drive()
	if absf(motor_shaft.current_rpm) <= 10.0 or shaft_rpm_before * motor_shaft.current_rpm <= 0.0:
		failures.append("motor: disconnecting the conveyor should preserve motor shaft rotation")
	if not carriage.position.is_equal_approx(carriage_before):
		failures.append("motor: a disconnected conveyor clutch should stop mechanical work")
	conveyor.set_coupled(true)
	motor_shaft.step_rotation(0.25)
	conveyor.step_drive()
	if carriage.position.is_equal_approx(carriage_before):
		failures.append("motor: reconnecting the conveyor clutch should restore mechanical work")


static func test_generator_clutch(
	generator: RotationalGeneratorSource,
	solver: DCCircuitSolver,
	motor: ElectricMotorComponent,
	motor_shaft: RotationalShaftState,
	failures: Array[String]
) -> void:
	var spinning_rpm: float = motor_shaft.current_rpm
	generator.set_coupled(false)
	solver.solve_network()
	motor_shaft.step_rotation(0.1)
	if solver.circuit_closed or motor.energized or not is_zero_approx(motor.target_output_rpm):
		failures.append("motor: disconnecting the generator should remove current and motor drive")
	if is_zero_approx(motor_shaft.current_rpm) or absf(motor_shaft.current_rpm) >= absf(spinning_rpm):
		failures.append("motor: an unpowered motor shaft should coast down rather than stop instantly")
	generator.set_coupled(true)
	generator.update_generated_voltage(true)
	solver.solve_network()
	if not solver.circuit_closed or not motor.energized:
		failures.append("motor: reconnecting the generator should restore motor power")


static func test_condensation_shutdown(
	state: ThermalState,
	reservoir: PressureReservoir,
	thermal_adapter: ThermalPressureAdapter,
	turbine: PressureTurbine,
	generator_shaft: RotationalShaftState,
	generator: RotationalGeneratorSource,
	solver: DCCircuitSolver,
	motor_shaft: RotationalShaftState,
	failures: Array[String]
) -> void:
	state.set_temperature(110.0, "condensation setup")
	reservoir.set_pressure(55.0, "condensation setup")
	state.receive_damage_payload(make_payload("ice", "Ice Lance", 1, 1.0, ["ice", "chill"]))
	thermal_adapter.step_conversion(3.0)
	turbine.step_turbine(1.0)
	generator_shaft.step_rotation(3.0)
	generator.update_generated_voltage(true)
	solver.solve_network()
	motor_shaft.step_rotation(4.0)
	if state.is_gas() or reservoir.current_pressure > turbine.minimum_operating_pressure:
		failures.append("motor: Ice condensation should remove the steam pressure source")
	if not is_zero_approx(generator_shaft.current_rpm) or generator.generated_voltage > 0.0 or solver.circuit_closed:
		failures.append("motor: condensation should stop generator rotation, voltage, and current")
	if not is_zero_approx(motor_shaft.current_rpm):
		failures.append("motor: the motor shaft should coast to rest after upstream shutdown")


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
