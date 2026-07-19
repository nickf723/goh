extends RefCounted
class_name ConductiveNetworkTestFixture

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")
const WoodProfile: PhysicalMaterialProfile = preload("res://data/materials/wood_physical_profile.tres")


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var fixture := Node3D.new()
	fixture.name = "ConductiveNetworkFixture"
	host.add_child(fixture)

	var source := CircuitVoltageSource.new()
	source.name = "Source"
	source.component_id = "source"
	source.nominal_voltage_volts = 12.0
	source.source_internal_resistance_ohms = 0.2
	add_terminals(source, Vector3(-2, 0, 0), Vector3(2, 0, 0))
	fixture.add_child(source)

	var circuit_switch := CircuitSwitch.new()
	circuit_switch.name = "Switch"
	circuit_switch.component_id = "switch"
	circuit_switch.material_profile = CopperProfile
	circuit_switch.resistance_ohms = 0.1
	circuit_switch.starts_closed = true
	add_terminals(circuit_switch, Vector3(-2, 0, 0.1), Vector3(-2, 0, 1.9))
	fixture.add_child(circuit_switch)

	var coil := ElectromagneticCoilComponent.new()
	coil.name = "Coil"
	coil.component_id = "coil"
	coil.material_profile = CopperProfile
	coil.resistance_ohms = 4.0
	coil.field_strength_per_amp = 3.0
	add_terminals(coil, Vector3(-2, 0, 2.0), Vector3(2, 0, 2.0))
	var magnetic_field := MagneticDipoleField.new()
	magnetic_field.name = "MagneticField"
	magnetic_field.active = false
	magnetic_field.maximum_distance = 5.0
	coil.add_child(magnetic_field)
	fixture.add_child(coil)

	var bridge := CircuitComponent.new()
	bridge.name = "Bridge"
	bridge.component_id = "bridge"
	bridge.material_profile = CopperProfile
	bridge.resistance_ohms = 0.2
	add_terminals(bridge, Vector3(2, 0, 0.1), Vector3(2, 0, 1.2))
	fixture.add_child(bridge)

	var solver := DCCircuitSolver.new()
	solver.name = "Solver"
	solver.auto_solve = false
	fixture.add_child(solver)
	await host.get_tree().process_frame

	var generic_contacts: Array = ["fixture:test_contact"]
	source.get_terminal_a().set_contact_debug(generic_contacts)
	if source.get_terminal_a().last_contact_keys != ["fixture:test_contact"]:
		failures.append("circuit: terminal debug should normalize generic string arrays")

	solver.solve_network()
	if solver.circuit_closed:
		failures.append("circuit: spatial gap should leave the loop open")
	if not is_zero_approx(solver.current_amps):
		failures.append("circuit: open loop should carry zero current")
	if magnetic_field.active:
		failures.append("circuit: open loop should leave the electromagnet inactive")

	bridge.get_terminal_b().position = Vector3(2, 0, 1.9)
	solver.solve_network()
	if not solver.circuit_closed:
		failures.append("circuit: copper contact bridge should close the loop")
	var expected_current: float = 12.0 / 4.5
	if not is_equal_approx(solver.current_amps, expected_current):
		failures.append("circuit: current should follow total resistance; found " + str(solver.current_amps))
	if not coil.energized or not magnetic_field.active:
		failures.append("circuit: closed loop should energize the coil")
	if source.get_terminal_a().last_contact_keys.is_empty():
		failures.append("circuit: solved graph should publish terminal contact debug data")

	circuit_switch.toggle_switch()
	solver.solve_network()
	if solver.circuit_closed:
		failures.append("circuit: opening the switch should break the loop")
	circuit_switch.toggle_switch()

	bridge.material_profile = WoodProfile
	solver.solve_network()
	if solver.circuit_closed:
		failures.append("circuit: wood in identical geometry must remain insulating")
	bridge.material_profile = CopperProfile

	solver.solve_network()
	var before_current: float = coil.signed_current_amps
	var before_polarity: float = magnetic_field.polarity
	source.reverse_polarity()
	solver.solve_network()
	if before_current * coil.signed_current_amps >= 0.0:
		failures.append("circuit: source reversal should reverse coil current")
	if before_polarity * magnetic_field.polarity >= 0.0:
		failures.append("circuit: reversed current should reverse magnetic polarity")

	test_bridge_configuration(fixture, failures)

	fixture.queue_free()
	failures.append_array(await ElectricalInteroperabilityTestFixture.run(host))
	failures.append_array(await ConductiveWaterTestFixture.run(host))
	failures.append_array(await ThermalStateTestFixture.run(host))
	return failures


static func test_bridge_configuration(fixture: Node3D, failures: Array[String]) -> void:
	var lab := ConductiveNetworkLab.new()
	lab.bridge_terminal_radius = 0.36
	lab.bridge_impulse_retention = 0.0
	lab.bridge_drag = 8.5
	lab.bridge_max_speed = 4.2

	var body := FieldResponsiveBody.new()
	body.name = "ConfiguredBridge"
	body.material_profile = CopperProfile

	var receiver := ForceReceiver.new()
	receiver.name = "ForceReceiver"
	body.add_child(receiver)

	var component := CircuitComponent.new()
	component.name = "CircuitComponent"
	component.component_id = "configured_bridge"
	component.material_profile = CopperProfile
	add_terminals(component, Vector3.ZERO, Vector3(1.0, 0.0, 0.0))
	body.add_child(component)
	fixture.add_child(body)

	lab.configure_bridge(body)
	if not is_zero_approx(receiver.impulse_momentum_retention):
		failures.append("circuit: puzzle bridge hits should replace stale impulse momentum")
	if not is_equal_approx(component.get_terminal_a().connection_radius, 0.36):
		failures.append("circuit: bridge terminals should receive forgiving socket tolerance")

	receiver.apply_impulse(Vector3.RIGHT, 2.0, 0.0, "first")
	receiver.apply_impulse(Vector3.LEFT, 1.0, 0.0, "reverse")
	if receiver.external_velocity.x >= 0.0:
		failures.append("circuit: a new opposite hit should reverse bridge movement immediately")

	var socket := CircuitComponent.new()
	socket.name = "VisualSocket"
	socket.component_id = "visual_socket"
	socket.material_profile = CopperProfile
	socket.position = Vector3(0.2, 0.45, 0.0)
	add_terminals(socket, Vector3.ZERO, Vector3(0.0, 0.0, 1.0))
	fixture.add_child(socket)
	if not component.get_terminal_a().can_connect_to(socket.get_terminal_a()):
		failures.append("circuit: visually aligned floor-resting bridge should count as contact")

	lab.free()


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
