extends RefCounted
class_name ThermalPressureTestFixture


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var root := Node3D.new()
	root.name = "ThermalPressureFixture"
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

	var platform := Node3D.new()
	platform.name = "Platform"
	root.add_child(platform)

	var actuator := MechanicalActuator.new()
	actuator.name = "MechanicalActuator"
	actuator.reservoir_path = NodePath("../PressureReservoir")
	actuator.moving_node_path = NodePath("../Platform")
	actuator.activation_pressure = 55.0
	actuator.deactivation_pressure = 20.0
	actuator.travel_offset = Vector3.UP * 3.0
	actuator.move_duration = 0.0
	actuator.latch_when_activated = false
	root.add_child(actuator)

	var adapter := ThermalPressureAdapter.new()
	adapter.name = "ThermalPressureAdapter"
	adapter.base_output_per_second = 18.0
	adapter.output_per_superheat_c = 0.55
	adapter.maximum_output_per_second = 42.0
	adapter.condensation_per_second = 28.0
	adapter.configure(state, reservoir)
	root.add_child(adapter)

	var valve := PressureReliefValve.new()
	valve.name = "ReliefValve"
	valve.automatic_threshold_ratio = 0.9
	valve.automatic_vent_per_second = 36.0
	valve.manual_vent_amount = 1000.0
	valve.configure(reservoir)
	root.add_child(valve)

	await host.get_tree().process_frame
	await host.get_tree().process_frame

	test_inactive_liquid(state, reservoir, adapter, failures)
	test_spell_to_lift(state, reservoir, adapter, actuator, platform, failures)
	test_condensation(state, reservoir, adapter, actuator, failures)
	test_relief_valve(reservoir, valve, failures)

	root.queue_free()
	return failures


static func test_inactive_liquid(
	state: ThermalState,
	reservoir: PressureReservoir,
	adapter: ThermalPressureAdapter,
	failures: Array[String]
) -> void:
	state.set_temperature(20.0, "baseline")
	reservoir.set_pressure(0.0, "baseline")
	adapter.step_conversion(1.0)
	if not state.is_liquid() or not is_zero_approx(reservoir.current_pressure):
		failures.append("thermal pressure: liquid water should not generate boiler pressure")


static func test_spell_to_lift(
	state: ThermalState,
	reservoir: PressureReservoir,
	adapter: ThermalPressureAdapter,
	actuator: MechanicalActuator,
	platform: Node3D,
	failures: Array[String]
) -> void:
	state.set_temperature(20.0, "reset before fire")
	reservoir.set_pressure(0.0, "reset before fire")
	state.receive_damage_payload(make_payload("fire", "Firebolt", 2, 1.0, ["fire", "burning"]))
	state.receive_damage_payload(make_payload("fire", "Firebolt", 2, 1.0, ["fire", "burning"]))
	if not state.is_gas():
		failures.append("thermal pressure: two tuned Firebolts should boil the fixture water")
	adapter.step_conversion(2.5)
	if reservoir.current_pressure <= 0.0 or not adapter.generating:
		failures.append("thermal pressure: gas-phase water should charge the pressure reservoir")
	if not actuator.is_activated or platform.position.y < 2.9:
		failures.append("thermal pressure: generated pressure should activate the existing lift actuator")
	var base_rate: float = adapter.get_generation_rate()
	state.set_temperature(140.0, "superheat")
	if adapter.get_generation_rate() <= base_rate:
		failures.append("thermal pressure: superheated steam should generate pressure faster")


static func test_condensation(
	state: ThermalState,
	reservoir: PressureReservoir,
	adapter: ThermalPressureAdapter,
	actuator: MechanicalActuator,
	failures: Array[String]
) -> void:
	reservoir.set_pressure(60.0, "condensation setup")
	state.receive_damage_payload(make_payload("ice", "Ice Lance", 1, 1.0, ["ice", "chill"]))
	if state.is_gas():
		failures.append("thermal pressure: Ice should condense the tuned steam fixture")
	adapter.step_conversion(2.0)
	if reservoir.current_pressure >= 60.0:
		failures.append("thermal pressure: condensed steam should remove stored pressure")
	if actuator.is_activated:
		failures.append("thermal pressure: falling below deactivation pressure should lower the lift")


static func test_relief_valve(
	reservoir: PressureReservoir,
	valve: PressureReliefValve,
	failures: Array[String]
) -> void:
	reservoir.set_pressure(95.0, "automatic relief setup")
	valve._process(1.0)
	if not valve.automatic_venting or reservoir.current_pressure >= 95.0:
		failures.append("thermal pressure: the relief valve should automatically vent near the cap")
	reservoir.set_pressure(40.0, "manual relief setup")
	valve.interact()
	if not is_zero_approx(reservoir.current_pressure):
		failures.append("thermal pressure: manual relief should empty the reservoir")


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
