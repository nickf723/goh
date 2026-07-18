extends Node

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")
const WoodProfile: PhysicalMaterialProfile = preload("res://data/materials/wood_physical_profile.tres")

var failures: Array[String] = []
var solver: DCCircuitSolver
var source: CircuitVoltageSource
var circuit_switch: CircuitSwitch
var coil: ElectromagneticCoilComponent
var bridge: CircuitComponent
var magnetic_field: MagneticDipoleField


func _ready() -> void:
	build_fixture()
	await get_tree().process_frame
	run_tests()
	if failures.is_empty():
		print("CONDUCTIVE_NETWORK_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("CONDUCTIVE_NETWORK_SMOKE_TEST: " + failure)
	get_tree().quit(1)


func build_fixture() -> void:
	source = CircuitVoltageSource.new()
	source.name = "Source"
	source.component_id = "source"
	source.nominal_voltage_volts = 12.0
	source.source_internal_resistance_ohms = 0.2
	add_terminals(source, Vector3(-2, 0, 0), Vector3(2, 0, 0))
	add_child(source)

	circuit_switch = CircuitSwitch.new()
	circuit_switch.name = "Switch"
	circuit_switch.component_id = "switch"
	circuit_switch.material_profile = CopperProfile
	circuit_switch.resistance_ohms = 0.1
	circuit_switch.starts_closed = true
	add_terminals(circuit_switch, Vector3(-2, 0, 0.1), Vector3(-2, 0, 1.9))
	add_child(circuit_switch)

	coil = ElectromagneticCoilComponent.new()
	coil.name = "Coil"
	coil.component_id = "coil"
	coil.material_profile = CopperProfile
	coil.resistance_ohms = 4.0
	coil.field_strength_per_amp = 3.0
	add_terminals(coil, Vector3(-2, 0, 2.0), Vector3(2, 0, 2.0))
	magnetic_field = MagneticDipoleField.new()
	magnetic_field.name = "MagneticField"
	magnetic_field.active = false
	magnetic_field.maximum_distance = 5.0
	coil.add_child(magnetic_field)
	add_child(coil)

	bridge = CircuitComponent.new()
	bridge.name = "Bridge"
	bridge.component_id = "bridge"
	bridge.material_profile = CopperProfile
	bridge.resistance_ohms = 0.2
	add_terminals(bridge, Vector3(2, 0, 0.1), Vector3(2, 0, 1.2))
	add_child(bridge)

	solver = DCCircuitSolver.new()
	solver.name = "Solver"
	solver.auto_solve = false
	add_child(solver)


func add_terminals(component: CircuitComponent, position_a: Vector3, position_b: Vector3) -> void:
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


func run_tests() -> void:
	test_open_gap()
	test_copper_closes_loop()
	test_switch_breaks_loop()
	test_wood_does_not_conduct()
	test_reversed_current_flips_coil()


func test_open_gap() -> void:
	solver.solve_network()
	if solver.circuit_closed:
		failures.append("spatial gap should leave the circuit open")
	if not is_zero_approx(solver.current_amps):
		failures.append("open circuit should carry zero current")
	if magnetic_field.active:
		failures.append("open circuit should leave the electromagnet inactive")


func test_copper_closes_loop() -> void:
	bridge.get_terminal_b().position = Vector3(2, 0, 1.9)
	solver.solve_network()
	if not solver.circuit_closed:
		failures.append("copper contact bridge should close the circuit")
	var expected_current: float = 12.0 / 4.5
	if not is_equal_approx(solver.current_amps, expected_current):
		failures.append("closed loop current should follow total resistance; found " + str(solver.current_amps))
	if not coil.energized or not magnetic_field.active:
		failures.append("closed loop should energize the electromagnetic coil")
	if coil.signed_current_amps <= 0.0:
		failures.append("initial source orientation should drive positive coil current")


func test_switch_breaks_loop() -> void:
	circuit_switch.toggle_switch()
	solver.solve_network()
	if solver.circuit_closed or not is_zero_approx(solver.current_amps):
		failures.append("opening the physical switch should break current flow")
	circuit_switch.toggle_switch()


func test_wood_does_not_conduct() -> void:
	bridge.material_profile = WoodProfile
	solver.solve_network()
	if solver.circuit_closed:
		failures.append("wood in the same gap geometry must remain insulating")
	bridge.material_profile = CopperProfile


func test_reversed_current_flips_coil() -> void:
	solver.solve_network()
	var before_current: float = coil.signed_current_amps
	var before_polarity: float = magnetic_field.polarity
	source.reverse_polarity()
	solver.solve_network()
	if not solver.circuit_closed:
		failures.append("reversing the source should preserve a closed circuit")
	if before_current * coil.signed_current_amps >= 0.0:
		failures.append("source reversal should reverse current through the coil")
	if before_polarity * magnetic_field.polarity >= 0.0:
		failures.append("reversed current should reverse magnetic polarity")
