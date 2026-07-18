extends RefCounted
class_name ElectricalInteroperabilityTestFixture

const CopperProfile: PhysicalMaterialProfile = preload("res://data/materials/copper_physical_profile.tres")
const LabLoadout: AbilityLoadout = preload("res://data/loadouts/electrical_interoperability_lab_loadout.tres")
const LabScene: PackedScene = preload("res://scenes/levels/prototypes/prototype_electrical_interoperability_lab_v1.tscn")


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	test_compact_lab_loadout(failures)
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
	await host.get_tree().process_frame
	failures.append_array(await test_playable_lab_runtime(host))
	return failures


static func test_compact_lab_loadout(failures: Array[String]) -> void:
	if LabLoadout.get_equipped_ability_count() != 2:
		failures.append("interoperability lab: compact loadout should contain exactly Lightning Spark and Firebolt")
		return
	var first_ability: AbilityDefinition = LabLoadout.get_equipped_ability(0)
	var second_ability: AbilityDefinition = LabLoadout.get_equipped_ability(1)
	if first_ability == null or first_ability.element != "lightning":
		failures.append("interoperability lab: Lightning Spark should be equipped by default")
	if second_ability == null or second_ability.element != "fire":
		failures.append("interoperability lab: Firebolt should remain available as the rejection comparison")


static func test_playable_lab_runtime(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var lab: Node = LabScene.instantiate()
	host.add_child(lab)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	await host.get_tree().process_frame

	var base_lab: Node3D = lab.get_node_or_null("BaseCircuitLab") as Node3D
	if base_lab == null:
		failures.append("interoperability lab: playable scene should contain the conductive base laboratory")
		lab.queue_free()
		return failures

	var caster: Node = base_lab.get_node_or_null("Player/AbilityCaster")
	var runtime_loadout: AbilityLoadout = caster.get("loadout") as AbilityLoadout if caster != null else null
	if runtime_loadout == null or runtime_loadout.get_equipped_ability_count() != 2:
		failures.append("interoperability lab: playable player should receive the compact spell loadout")
	elif caster.has_method("get_current_ability"):
		var active_ability: AbilityDefinition = caster.call("get_current_ability") as AbilityDefinition
		if active_ability == null or active_ability.element != "lightning":
			failures.append("interoperability lab: playable scene should begin with Lightning Spark selected")

	var copper_bridge: FieldResponsiveBody = base_lab.get_node_or_null("CopperBridge") as FieldResponsiveBody
	if copper_bridge == null:
		failures.append("interoperability lab: installed copper link is missing")
	else:
		if copper_bridge.position.distance_to(Vector3(0.0, 0.35, 2.5)) > 0.02:
			failures.append("interoperability lab: copper link should begin installed in the circuit cradle")
		if copper_bridge.is_physics_processing():
			failures.append("interoperability lab: installed copper link should not require precision pushing")

	var wood_bridge: FieldResponsiveBody = base_lab.get_node_or_null("WoodBridge") as FieldResponsiveBody
	if wood_bridge != null and wood_bridge.visible:
		failures.append("interoperability lab: wood comparison should be removed from the simplified room")

	var circuit_switch: CircuitSwitch = base_lab.get_node_or_null("Circuit/Switch") as CircuitSwitch
	if circuit_switch == null or not circuit_switch.path_enabled:
		failures.append("interoperability lab: simplified bench should begin with its internal switch closed")
	elif circuit_switch.visible:
		failures.append("interoperability lab: redundant internal switch should be hidden")

	var source_selector: CircuitSourceSelector = base_lab.get_node_or_null("SourceSelector") as CircuitSourceSelector
	var storm_console: EnvironmentalEmitterConsole = base_lab.get_node_or_null("StormPulseConsole") as EnvironmentalEmitterConsole
	if source_selector == null or storm_console == null:
		failures.append("interoperability lab: source selector and storm console should both exist")
	elif source_selector.position.distance_to(storm_console.position) < 10.0:
		failures.append("interoperability lab: source controls should be spread apart for readability")

	var target_area: Area3D = base_lab.get_node_or_null("Circuit/LightningInputPort/LightningTargetArea") as Area3D
	var target_collision: CollisionShape3D = target_area.get_node_or_null("CollisionShape3D") as CollisionShape3D if target_area != null else null
	var target_shape: SphereShape3D = target_collision.shape as SphereShape3D if target_collision != null else null
	if target_shape == null or target_shape.radius < 1.2:
		failures.append("interoperability lab: Lightning input should have a generous strike target")

	lab.queue_free()
	await host.get_tree().process_frame
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
