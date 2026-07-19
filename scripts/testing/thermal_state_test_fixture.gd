extends RefCounted
class_name ThermalStateTestFixture

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")
const WaterProfile: PhysicalMaterialProfile = preload("res://data/materials/water_physical_profile.tres")


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var fixture := Node3D.new()
	fixture.name = "ThermalStateFixture"
	host.add_child(fixture)

	var payload_data: Dictionary = build_payload_target(fixture)
	var contact_data: Dictionary = build_contact_pair(fixture)
	var heater_data: Dictionary = build_heater(fixture)
	var water_data: Dictionary = build_water_circuit(fixture)
	await host.get_tree().process_frame
	await host.get_tree().process_frame

	test_payload_energy(payload_data, failures)
	test_contact_transfer(contact_data, failures)
	test_resistive_heating(heater_data, failures)
	test_water_phases(water_data, failures)

	fixture.queue_free()
	return failures


static func build_payload_target(fixture: Node3D) -> Dictionary:
	var target := Node3D.new()
	target.name = "ThermalPayloadTarget"
	var receiver := PayloadReceiver.new()
	receiver.name = "PayloadReceiver"
	target.add_child(receiver)
	var state := make_state("ThermalState", 20.0, 8.0)
	target.add_child(state)
	fixture.add_child(target)
	return {"target": target, "receiver": receiver, "state": state}


static func build_contact_pair(fixture: Node3D) -> Dictionary:
	var state_a := make_state("ContactStateA", 100.0, 10.0)
	var state_b := make_state("ContactStateB", 0.0, 10.0)
	fixture.add_child(state_a)
	fixture.add_child(state_b)
	var link := ThermalContactLink.new()
	link.name = "ContactLink"
	link.enabled = false
	link.conductance_j_per_second_c = 0.5
	link.maximum_transfer_j_per_second = 1000.0
	fixture.add_child(link)
	link.configure(state_a, state_b)
	return {"a": state_a, "b": state_b, "link": link}


static func build_heater(fixture: Node3D) -> Dictionary:
	var component := CircuitComponent.new()
	component.name = "TestResistor"
	component.component_id = "thermal_test_resistor"
	component.material_profile = CopperProfile
	component.resistance_ohms = 4.0
	var state := make_state("ThermalState", 20.0, 10.0)
	component.add_child(state)
	var adapter := CircuitThermalAdapter.new()
	adapter.name = "CircuitThermalAdapter"
	adapter.enabled = false
	adapter.joule_heat_scale = 2.0
	adapter.maximum_heat_power_w = 1000.0
	component.add_child(adapter)
	fixture.add_child(component)
	adapter.configure(component, state)
	return {"component": component, "state": state, "adapter": adapter}


static func build_water_circuit(fixture: Node3D) -> Dictionary:
	var root := Node3D.new()
	root.name = "ThermalWaterCircuit"
	fixture.add_child(root)
	var solver := DCCircuitSolver.new()
	solver.name = "Solver"
	solver.auto_solve = false
	root.add_child(solver)

	var source := CircuitVoltageSource.new()
	source.name = "Source"
	source.component_id = "thermal_water_source"
	source.nominal_voltage_volts = 12.0
	source.source_internal_resistance_ohms = 0.2
	source.position = Vector3(0.0, 0.0, 0.0)
	add_terminals(source, Vector3(-2.0, 0.0, 0.0), Vector3(2.0, 0.0, 0.0))
	root.add_child(source)

	var load := CircuitComponent.new()
	load.name = "Load"
	load.component_id = "thermal_water_load"
	load.material_profile = CopperProfile
	load.resistance_ohms = 2.0
	load.position = Vector3(2.0, 0.0, 1.0)
	add_terminals(load, Vector3(0.0, 0.0, -0.9), Vector3(0.0, 0.0, 0.9))
	root.add_child(load)

	var return_wire := CircuitComponent.new()
	return_wire.name = "ReturnWire"
	return_wire.component_id = "thermal_water_return"
	return_wire.material_profile = CopperProfile
	return_wire.resistance_ohms = 0.2
	return_wire.position = Vector3(-2.0, 0.0, 1.0)
	add_terminals(return_wire, Vector3(0.0, 0.0, -0.9), Vector3(0.0, 0.0, 0.9))
	root.add_child(return_wire)

	var water := ThermalWaterVolume.new()
	water.name = "Water"
	water.component_id = "thermal_water_path"
	water.material_profile = WaterProfile
	water.volume_size = Vector3(4.5, 0.8, 1.4)
	water.position = Vector3(0.0, 0.0, 1.9)
	water.scan_interval = 9999.0
	water.resistance_per_meter_ohms = 0.45
	root.add_child(water)
	return {"root": root, "solver": solver, "source": source, "load": load, "water": water}


static func test_payload_energy(data: Dictionary, failures: Array[String]) -> void:
	var receiver: PayloadReceiver = data["receiver"] as PayloadReceiver
	var state: ThermalState = data["state"] as ThermalState
	var start_temperature: float = state.temperature_c
	var fire := make_payload("fire", "Firebolt", 2, 1.0, ["fire", "burning"])
	var fire_result: Dictionary = receiver.receive_payload(fire)
	if state.temperature_c <= start_temperature:
		failures.append("thermal: Fire payload should increase temperature")
	if str(fire_result.get("message", "")).contains("nothing receives"):
		failures.append("thermal: thermal-only targets should report energy reception instead of an empty hit")
	var heated_temperature: float = state.temperature_c
	var ice := make_payload("ice", "Ice Lance", 1, 0.35, ["ice", "chill"])
	receiver.receive_payload(ice)
	if state.temperature_c >= heated_temperature:
		failures.append("thermal: Ice payload should decrease temperature")


static func test_contact_transfer(data: Dictionary, failures: Array[String]) -> void:
	var state_a: ThermalState = data["a"] as ThermalState
	var state_b: ThermalState = data["b"] as ThermalState
	var link: ThermalContactLink = data["link"] as ThermalContactLink
	var initial_energy: float = (
		state_a.temperature_c * state_a.get_heat_capacity_j_per_c()
		+ state_b.temperature_c * state_b.get_heat_capacity_j_per_c()
	)
	link.enabled = true
	var transfer_j: float = link.step_transfer(1.0)
	var final_energy: float = (
		state_a.temperature_c * state_a.get_heat_capacity_j_per_c()
		+ state_b.temperature_c * state_b.get_heat_capacity_j_per_c()
	)
	if transfer_j <= 0.0 or state_a.temperature_c >= 100.0 or state_b.temperature_c <= 0.0:
		failures.append("thermal: contact should transfer energy from the hotter body to the colder body")
	if not is_equal_approx(initial_energy, final_energy):
		failures.append("thermal: contact transfer should conserve tracked thermal energy")


static func test_resistive_heating(data: Dictionary, failures: Array[String]) -> void:
	var component: CircuitComponent = data["component"] as CircuitComponent
	var state: ThermalState = data["state"] as ThermalState
	var adapter: CircuitThermalAdapter = data["adapter"] as CircuitThermalAdapter
	adapter.enabled = true
	component.apply_circuit_state(true, 2.0, 8.0, 1)
	var before_heat: float = state.temperature_c
	adapter.step_heating(1.0)
	if state.temperature_c <= before_heat:
		failures.append("thermal: energized resistance should create heat from current squared times resistance")
	if not is_equal_approx(adapter.last_power_w, 32.0):
		failures.append("thermal: resistive adapter should expose scaled I²R power")
	component.apply_circuit_state(false, 0.0, 0.0, 2)
	var before_open_step: float = state.temperature_c
	adapter.step_heating(1.0)
	if not is_equal_approx(state.temperature_c, before_open_step):
		failures.append("thermal: open circuits should stop resistive heating")


static func test_water_phases(data: Dictionary, failures: Array[String]) -> void:
	var solver: DCCircuitSolver = data["solver"] as DCCircuitSolver
	var load: CircuitComponent = data["load"] as CircuitComponent
	var water: ThermalWaterVolume = data["water"] as ThermalWaterVolume
	water.scan_immersed_terminals()
	solver.solve_network()
	if not water.thermal_state.is_liquid() or not solver.circuit_closed or not load.energized:
		failures.append("thermal: room-temperature liquid water should conduct through immersed electrodes")

	water.receive_damage_payload(make_payload("ice", "Ice Lance", 1, 0.35, ["ice", "chill"]))
	water.scan_immersed_terminals()
	solver.solve_network()
	if not water.thermal_state.is_solid() or solver.circuit_closed:
		failures.append("thermal: freezing water should disable the conductive circuit path")

	water.receive_damage_payload(make_payload("fire", "Firebolt", 2, 1.0, ["fire", "burning"]))
	water.scan_immersed_terminals()
	solver.solve_network()
	if not water.thermal_state.is_liquid() or not solver.circuit_closed:
		failures.append("thermal: thawing frozen water should restore circuit conduction")

	water.receive_damage_payload(make_payload("fire", "Firebolt", 2, 1.0, ["fire", "burning"]))
	water.receive_damage_payload(make_payload("fire", "Firebolt", 2, 1.0, ["fire", "burning"]))
	water.scan_immersed_terminals()
	solver.solve_network()
	if not water.thermal_state.is_gas() or solver.circuit_closed:
		failures.append("thermal: boiling water into gas should remove the liquid circuit path")


static func make_state(node_name: String, starting_temperature: float, heat_capacity: float) -> ThermalState:
	var state := ThermalState.new()
	state.name = node_name
	state.starting_temperature_c = starting_temperature
	state.ambient_temperature_c = starting_temperature
	state.heat_capacity_override_j_per_c = heat_capacity
	state.passive_ambient_exchange = false
	state.fire_energy_j_per_intensity = 180.0
	state.ice_energy_j_per_intensity = 180.0
	return state


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
	terminal_a.connection_radius = 0.3
	component.add_child(terminal_a)
	var terminal_b := CircuitTerminal.new()
	terminal_b.name = "TerminalB"
	terminal_b.terminal_id = "b"
	terminal_b.position = position_b
	terminal_b.connection_radius = 0.3
	component.add_child(terminal_b)
