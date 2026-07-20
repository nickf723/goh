extends RefCounted
class_name ProceduralFireTestFixture

const ThermalStateScript = preload("res://scripts/physics/thermal_state.gd")
const CombustionStateScript = preload("res://scripts/physics/combustion_state.gd")
const FireEventScript = preload("res://scripts/presentation/fire_vfx_event.gd")
const FireProfileScript = preload("res://scripts/presentation/fire_presentation_profile.gd")
const FireRendererScript = preload("res://scripts/presentation/procedural_fire_renderer.gd")
const CombustionPresenterScript = preload("res://scripts/presentation/combustion_presenter.gd")


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var root := Node3D.new()
	root.name = "ProceduralFireFixture"
	host.add_child(root)

	await test_combustion_state(root, host, failures)
	await test_noncombustible_material(root, host, failures)
	await test_renderer_lifecycle(root, host, failures)
	await test_combustion_presenter(root, host, failures)
	await test_firebolt_scene(root, host, failures)

	root.queue_free()
	return failures


static func test_combustion_state(root: Node3D, host: Node, failures: Array[String]) -> void:
	var specimen := Node3D.new()
	specimen.name = "CombustibleSpecimen"
	var thermal: Node = ThermalStateScript.new()
	thermal.name = "ThermalState"
	thermal.starting_temperature_c = 20.0
	thermal.passive_ambient_exchange = false
	thermal.heat_capacity_override_j_per_c = 5.0
	specimen.add_child(thermal)
	var combustion: Node = CombustionStateScript.new()
	combustion.name = "CombustionState"
	combustion.auto_process = false
	combustion.combustible_override = true
	combustion.initial_fuel_kg_override = 0.2
	combustion.ignition_temperature_c_override = 100.0
	combustion.sustain_temperature_c_override = 60.0
	combustion.burn_rate_kg_per_second_override = 0.05
	combustion.heat_output_j_per_second_override = 20.0
	combustion.smoke_yield_override = 0.6
	combustion.ember_yield_override = 0.4
	specimen.add_child(combustion)
	root.add_child(specimen)
	await host.get_tree().process_frame

	if combustion.burning:
		failures.append("fire: cold fuel should not begin in open combustion")
	thermal.set_temperature(120.0, "Fixture Heat")
	combustion.step_combustion(0.1)
	if not combustion.burning or str(combustion.state) != "burning":
		failures.append("fire: fuel above its ignition temperature should begin combustion")
	var fuel_before: float = combustion.fuel_kg
	var temperature_before: float = thermal.temperature_c
	combustion.step_combustion(1.0)
	if combustion.fuel_kg >= fuel_before:
		failures.append("fire: active combustion should consume fuel")
	if thermal.temperature_c <= temperature_before:
		failures.append("fire: active combustion should return heat to ThermalState")
	combustion.set_airflow(Vector3(4.0, 0.0, 0.0))
	combustion.step_combustion(0.1)
	if combustion.airflow_velocity.x <= 0.0:
		failures.append("fire: combustion should preserve authored airflow for presentation")
	if not combustion.apply_extinguish(1.2, 500.0, "Fixture Water"):
		failures.append("fire: sufficient cooling should extinguish an active flame")
	if combustion.burning or str(combustion.state) != "extinguished":
		failures.append("fire: extinguished fuel should stop open flame without deleting remaining fuel")
	if combustion.fuel_kg <= 0.0:
		failures.append("fire: extinguishing should not consume all remaining fuel")

	combustion.reset_target()
	thermal.set_temperature(120.0, "Fixture Smolder")
	combustion.fuel_kg = 0.015
	combustion.step_combustion(0.1)
	if str(combustion.state) != "smoldering":
		failures.append("fire: low remaining fuel should transition through smoldering")
	combustion.step_combustion(20.0)
	if str(combustion.state) != "spent" or combustion.fuel_kg > 0.0:
		failures.append("fire: exhausted fuel should enter the spent state")
	specimen.queue_free()


static func test_noncombustible_material(root: Node3D, host: Node, failures: Array[String]) -> void:
	var specimen := Node3D.new()
	specimen.name = "StoneSpecimen"
	var thermal: Node = ThermalStateScript.new()
	thermal.name = "ThermalState"
	thermal.starting_temperature_c = 600.0
	thermal.passive_ambient_exchange = false
	specimen.add_child(thermal)
	var combustion: Node = CombustionStateScript.new()
	combustion.name = "CombustionState"
	combustion.auto_process = false
	combustion.initial_fuel_kg_override = 1.0
	combustion.ignition_temperature_c_override = 100.0
	combustion.sustain_temperature_c_override = 60.0
	combustion.burn_rate_kg_per_second_override = 0.1
	combustion.heat_output_j_per_second_override = 20.0
	specimen.add_child(combustion)
	root.add_child(specimen)
	await host.get_tree().process_frame
	combustion.step_combustion(1.0)
	if combustion.burning or str(combustion.state) != "cold":
		failures.append("fire: a hot noncombustible specimen must not create flame")
	specimen.queue_free()


static func test_renderer_lifecycle(root: Node3D, host: Node, failures: Array[String]) -> void:
	var renderer: Node3D = FireRendererScript.new() as Node3D
	renderer.name = "ProceduralFireRenderer"
	root.add_child(renderer)
	var profile: Resource = FireProfileScript.new()
	profile.apply_kind("bonfire")
	var event: RefCounted = FireEventScript.make(
		FireEventScript.KIND_BURST,
		Vector3(2.0, 1.0, 0.0),
		1.25,
		0.8,
		"fixture_fire",
		["fire", "fixture"]
	)
	event.smoke_strength = 0.8
	event.ember_strength = 1.0
	event.wind_velocity = Vector3(2.0, 0.0, 0.0)
	var visual: Node3D = renderer.render_event(event, profile)
	if visual == null or renderer.rendered_count != 1:
		failures.append("fire: a finite Fire event should create one procedural visual")
	elif visual.flame_nodes.size() < 3:
		failures.append("fire: a bonfire should generate multiple shader-driven flame licks")
	if visual.smoke_particles == null or visual.ember_particles == null or visual.fire_light == null:
		failures.append("fire: generated Fire should include smoke, embers, and flickering light")
	if not visual.wind_velocity.is_equal_approx(Vector3(2.0, 0.0, 0.0)):
		failures.append("fire: renderer should propagate airflow into the procedural visual")

	var rejected_before: int = renderer.rejected_count
	var invalid: RefCounted = FireEventScript.make(FireEventScript.KIND_FLAME, Vector3.ZERO)
	invalid.world_position.x = INF
	if renderer.render_event(invalid, profile) != null or renderer.rejected_count <= rejected_before:
		failures.append("fire: renderer should reject non-finite events safely")
	renderer.reset_target()
	await host.get_tree().process_frame
	if not renderer.active_visuals.is_empty() or renderer.rendered_count != 0:
		failures.append("fire: reset should clear procedural visuals and counters")


static func test_combustion_presenter(root: Node3D, host: Node, failures: Array[String]) -> void:
	var specimen := Node3D.new()
	specimen.name = "PresentedCombustion"
	var thermal: Node = ThermalStateScript.new()
	thermal.name = "ThermalState"
	thermal.starting_temperature_c = 220.0
	thermal.passive_ambient_exchange = false
	specimen.add_child(thermal)
	var combustion: Node = CombustionStateScript.new()
	combustion.name = "CombustionState"
	combustion.combustible_override = true
	combustion.initial_fuel_kg_override = 0.4
	combustion.ignition_temperature_c_override = 100.0
	combustion.sustain_temperature_c_override = 60.0
	combustion.burn_rate_kg_per_second_override = 0.01
	combustion.heat_output_j_per_second_override = 15.0
	combustion.starts_ignited = true
	specimen.add_child(combustion)
	var presenter: Node3D = CombustionPresenterScript.new() as Node3D
	presenter.name = "CombustionPresenter"
	presenter.profile_kind = "torch"
	specimen.add_child(presenter)
	root.add_child(specimen)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if presenter.persistent_visual == null:
		failures.append("fire: CombustionPresenter should create a persistent procedural visual")
	elif presenter.persistent_visual.current_intensity <= 0.0:
		failures.append("fire: a burning CombustionState should drive visible flame intensity")
	combustion.apply_extinguish(1.2, 600.0, "Fixture Water")
	await host.get_tree().process_frame
	if presenter.persistent_visual.current_intensity > 0.01:
		failures.append("fire: extinguishing should remove open flame from the state-driven presenter")
	if presenter.burst_renderer.rendered_count <= 0:
		failures.append("fire: extinguishing should create a procedural dying-smoke event")
	specimen.queue_free()


static func test_firebolt_scene(root: Node3D, host: Node, failures: Array[String]) -> void:
	var packed: PackedScene = load("res://scenes/abilities/legacy_projectiles/firebolt.tscn") as PackedScene
	if packed == null:
		failures.append("fire: Firebolt scene should remain loadable")
		return
	var projectile := packed.instantiate() as Area3D
	root.add_child(projectile)
	if projectile.has_method("launch"):
		projectile.call("launch", Vector3.FORWARD)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var vfx: Node = projectile.get_node_or_null("ProceduralFireVfx")
	var legacy_mesh := projectile.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if vfx == null or vfx.visual == null:
		failures.append("fire: Firebolt should own the procedural Fire visual component")
	if legacy_mesh == null or legacy_mesh.visible:
		failures.append("fire: procedural Firebolt should replace the old visible sphere")
	elif vfx.visual.flame_nodes.is_empty():
		failures.append("fire: launched Firebolt should generate shader flame geometry")
	projectile.queue_free()
