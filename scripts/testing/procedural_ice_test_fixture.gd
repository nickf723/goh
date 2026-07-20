extends RefCounted
class_name ProceduralIceTestFixture

const FreezeStateScript = preload("res://scripts/physics/freeze_state.gd")
const IceEventScript = preload("res://scripts/presentation/ice_vfx_event.gd")
const IceProfileScript = preload("res://scripts/presentation/ice_presentation_profile.gd")
const IcePatternScript = preload("res://scripts/presentation/ice_pattern_generator.gd")
const IceRendererScript = preload("res://scripts/presentation/procedural_ice_renderer.gd")
const IcePayload: Resource = preload("res://data/damage_payloads/ice_lance_payload.tres")


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var root := Node3D.new()
	root.name = "ProceduralIceFixture"
	host.add_child(root)
	test_deterministic_patterns(failures)
	test_arbitrary_surface_plane(failures)
	test_crystal_generation(failures)
	await test_freeze_state(root, host, failures)
	await test_renderer_lifecycle(root, host, failures)
	await test_ice_projectile(root, host, failures)
	await test_dedicated_lab(root, host, failures)
	root.queue_free()
	Engine.time_scale = 1.0
	return failures


static func test_deterministic_patterns(failures: Array[String]) -> void:
	var event: Resource = IceEventScript.make(
		IceEventScript.KIND_FREEZE_FRONT,
		Vector3(1.0, 0.5, -2.0),
		Vector3.UP,
		1.0,
		3.0,
		7721,
		"fixture_front"
	)
	event.progress = 0.72
	var profile: Resource = IceProfileScript.make_freeze_front()
	var first: Dictionary = IcePatternScript.generate_radial_paths(event, profile)
	var second: Dictionary = IcePatternScript.generate_radial_paths(event, profile)
	if first.get("paths", []) != second.get("paths", []):
		failures.append("ice: identical seeds should reproduce identical freeze-front paths")
	if not bool(first.get("finite", false)):
		failures.append("ice: generated freeze-front coordinates must remain finite")
	if int(first.get("branch_count", 0)) < 4:
		failures.append("ice: freeze fronts should generate multiple articulated branches")


static func test_arbitrary_surface_plane(failures: Array[String]) -> void:
	var center := Vector3(4.0, 2.0, -1.0)
	var normal := Vector3.LEFT
	var event: Resource = IceEventScript.make(
		IceEventScript.KIND_FROST,
		center,
		normal,
		1.0,
		2.4,
		811,
		"fixture_wall_frost"
	)
	var result: Dictionary = IcePatternScript.generate_radial_paths(event, IceProfileScript.make_frost_wall())
	for raw_path: Variant in result.get("paths", []):
		if not raw_path is PackedVector3Array:
			failures.append("ice: frost generator returned an invalid path type")
			continue
		for point: Vector3 in raw_path as PackedVector3Array:
			var plane_distance: float = absf((point - center).dot(normal))
			if plane_distance > 0.04:
				failures.append("ice: frost paths should remain on the requested wall plane")
				return


static func test_crystal_generation(failures: Array[String]) -> void:
	var event: Resource = IceEventScript.make(
		IceEventScript.KIND_CRYSTAL_GROWTH,
		Vector3.ZERO,
		Vector3.UP,
		1.2,
		1.4,
		991,
		"fixture_crystals"
	)
	event.shard_count = 19
	var result: Dictionary = IcePatternScript.generate_crystals(event, IceProfileScript.make_crystal_garden())
	var count: int = int(result.get("count", 0))
	if count < 10 or count > 96:
		failures.append("ice: crystal generation should remain rich but bounded")
	if not bool(result.get("finite", false)):
		failures.append("ice: generated crystal transforms must remain finite")


static func test_freeze_state(root: Node3D, host: Node, failures: Array[String]) -> void:
	var specimen := Node3D.new()
	specimen.name = "FreezeStateSpecimen"
	root.add_child(specimen)
	var thermal := ThermalState.new()
	thermal.name = "ThermalState"
	thermal.starting_temperature_c = 8.0
	thermal.passive_ambient_exchange = false
	specimen.add_child(thermal)
	var freeze: Node = FreezeStateScript.new()
	freeze.name = "FreezeState"
	freeze.auto_process = false
	freeze.freeze_rate_per_second = 0.5
	freeze.thaw_rate_per_second = 0.5
	freeze.configure(thermal, false)
	specimen.add_child(freeze)
	await host.get_tree().process_frame
	thermal.set_temperature(-18.0, "Fixture cold")
	freeze.step_freezing(1.0)
	var frozen_progress: float = float(freeze.freeze_progress)
	if frozen_progress <= 0.25:
		failures.append("ice: subzero thermal state should advance freeze progress")
	thermal.set_temperature(24.0, "Fixture heat")
	freeze.step_freezing(1.0)
	if float(freeze.freeze_progress) >= frozen_progress:
		failures.append("ice: heat above the thaw threshold should recede freeze progress")
	freeze.starts_frozen = true
	freeze.reset_target()
	thermal.set_temperature(-24.0, "Fixture brittle")
	var light_result: Dictionary = freeze.apply_impact(0.08, "Light tap")
	if bool(light_result.get("shattered", false)):
		failures.append("ice: a light impact should not immediately shatter a frozen body")
	var crack_result: Dictionary = freeze.apply_impact(0.42, "Crack strike")
	if not bool(crack_result.get("cracked", false)):
		failures.append("ice: accumulated stress should cross the crack threshold")
	var shatter_result: Dictionary = freeze.apply_impact(1.2, "Heavy strike")
	if not bool(shatter_result.get("shattered", false)) or not bool(freeze.is_shattered):
		failures.append("ice: a heavy impact should shatter sufficiently frozen brittle material")
	freeze.reset_target()
	if bool(freeze.is_shattered) or float(freeze.fracture_stress) > 0.001:
		failures.append("ice: reset should restore fracture state")


static func test_renderer_lifecycle(root: Node3D, host: Node, failures: Array[String]) -> void:
	var renderer: Node3D = IceRendererScript.new()
	renderer.name = "ProceduralIceRenderer"
	root.add_child(renderer)
	var event: Resource = IceEventScript.make(
		IceEventScript.KIND_FREEZE_FRONT,
		Vector3(0.0, 0.2, 0.0),
		Vector3.UP,
		1.0,
		2.0,
		442,
		"fixture_renderer"
	)
	event.progress = 0.8
	var visual: Node3D = renderer.call("render_event", event, IceProfileScript.make_freeze_front()) as Node3D
	await host.get_tree().process_frame
	if visual == null or int(renderer.get("rendered_count")) != 1:
		failures.append("ice: a valid event should create one procedural Ice effect")
	if int(renderer.get("total_generated_points")) <= 8:
		failures.append("ice: renderer instrumentation should report generated path points")
	var rejected_before: int = int(renderer.get("rejected_count"))
	var invalid: Resource = IceEventScript.make(IceEventScript.KIND_CRACK, Vector3.ZERO)
	invalid.world_position.x = INF
	if renderer.call("render_event", invalid, IceProfileScript.make_crack()) != null:
		failures.append("ice: renderer should reject non-finite events")
	if int(renderer.get("rejected_count")) <= rejected_before:
		failures.append("ice: invalid event rejection should be instrumented")
	renderer.call("reset_target")
	await host.get_tree().process_frame
	if not (renderer.get("active_effects") as Array).is_empty() or int(renderer.get("rendered_count")) != 0:
		failures.append("ice: reset should clear generated effects and counters")


static func test_ice_projectile(root: Node3D, host: Node, failures: Array[String]) -> void:
	var packed: PackedScene = load("res://scenes/actions/generic_projectile.tscn") as PackedScene
	if packed == null:
		failures.append("ice: generic projectile scene should remain loadable")
		return
	var projectile := packed.instantiate() as Node3D
	if projectile.has_method("set_payload"):
		projectile.call("set_payload", IcePayload.duplicate(true))
	root.add_child(projectile)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var vfx: Node = projectile.get_node_or_null("ProceduralIceVfx")
	var legacy_root := projectile.get_node_or_null("ElementVisualRoot") as Node3D
	if vfx == null or not bool(vfx.get("active_for_ice")):
		failures.append("ice: Ice Lance should initialize its procedural visual component")
	if legacy_root == null or legacy_root.visible:
		failures.append("ice: procedural Ice Lance should replace the legacy box-and-halo visual")
	var renderer: Node = vfx.get("renderer") if vfx != null else null
	if renderer == null or int(renderer.get("rendered_count")) <= 0:
		failures.append("ice: Ice Lance should generate a live procedural crystal body")
	projectile.queue_free()


static func test_dedicated_lab(root: Node3D, host: Node, failures: Array[String]) -> void:
	var packed: PackedScene = load("res://scenes/levels/prototypes/prototype_ice_vfx_lab_v1.tscn") as PackedScene
	if packed == null:
		failures.append("ice: dedicated Ice VFX laboratory scene should load")
		return
	var lab := packed.instantiate() as Node3D
	root.add_child(lab)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	if not lab.is_in_group("ice_vfx_lab"):
		failures.append("ice: dedicated scene should register as the Ice VFX lab")
	if lab.get_node_or_null("ProceduralIceRenderer") == null:
		failures.append("ice: dedicated lab should own the procedural Ice renderer")
	var console_count: int = 0
	for child: Node in lab.get_children():
		if child is Area3D and child.has_method("interact"):
			console_count += 1
	if console_count < 8:
		failures.append("ice: dedicated lab should expose its global and station controls")
	lab.call("handle_vfx_lab_action", "slow_motion")
	if Engine.time_scale >= 0.5:
		failures.append("ice: dedicated lab slow-motion control should reduce global time")
	lab.call("reset_target")
	if not is_equal_approx(Engine.time_scale, 1.0):
		failures.append("ice: dedicated lab reset must restore global time")
	lab.queue_free()
