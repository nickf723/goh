extends RefCounted
class_name ProceduralLightningTestFixture


static func run(host: Node) -> Array[String]:
	var failures: Array[String] = []
	var root := Node3D.new()
	root.name = "ProceduralLightningFixture"
	host.add_child(root)

	test_deterministic_fractal_path(failures)
	test_branch_budget_and_endpoints(failures)
	test_flattened_water_arcs(failures)
	await test_renderer_lifecycle(root, host, failures)
	await test_lightning_projectile_scene(root, host, failures)

	root.queue_free()
	return failures


static func test_deterministic_fractal_path(failures: Array[String]) -> void:
	var profile := LightningProfile.new()
	profile.subdivision_count = 5
	profile.jitter_amplitude = 0.55
	profile.branch_chance = 0.45
	profile.branch_depth = 2
	profile.maximum_branches = 10
	var event := LightningArcEvent.make(
		LightningArcEvent.KIND_STORM,
		Vector3(-2.0, 7.0, 1.0),
		Vector3(3.0, 0.5, -1.0),
		1.4,
		424242,
		"fixture_determinism"
	)
	profile.apply_to_event(event, event.intensity)
	var first: Dictionary = LightningPathGenerator.generate(event)
	var second: Dictionary = LightningPathGenerator.generate(event)
	var first_path: PackedVector3Array = first.get("main_path", PackedVector3Array())
	var second_path: PackedVector3Array = second.get("main_path", PackedVector3Array())
	if first_path != second_path:
		failures.append("lightning: identical seeds should reproduce the same fractal main path")
	if first.get("branches", []) != second.get("branches", []):
		failures.append("lightning: identical seeds should reproduce the same branch paths")
	if not bool(first.get("finite", false)):
		failures.append("lightning: generated paths must remain finite")


static func test_branch_budget_and_endpoints(failures: Array[String]) -> void:
	var event := LightningArcEvent.make(
		LightningArcEvent.KIND_STORM,
		Vector3(0.0, 8.0, 0.0),
		Vector3(0.0, 0.0, 0.0),
		2.0,
		9001,
		"fixture_storm"
	)
	event.subdivision_count = 6
	event.jitter_amplitude = 0.9
	event.branch_chance = 1.0
	event.branch_depth = 2
	event.branch_length_ratio = 0.3
	event.maximum_branches = 9
	var result: Dictionary = LightningPathGenerator.generate(event)
	var path: PackedVector3Array = result.get("main_path", PackedVector3Array())
	var branch_count: int = int(result.get("branch_count", 0))
	if path.size() < 3:
		failures.append("lightning: recursive subdivision should produce an articulated main path")
	elif not path[0].is_equal_approx(event.start_position) or not path[path.size() - 1].is_equal_approx(event.end_position):
		failures.append("lightning: fractal jitter must preserve exact requested endpoints")
	if branch_count <= 0:
		failures.append("lightning: a guaranteed storm profile should produce branches")
	if branch_count > event.maximum_branches:
		failures.append("lightning: generated branches must respect the authored branch budget")


static func test_flattened_water_arcs(failures: Array[String]) -> void:
	var surface_y: float = 1.75
	var event := LightningArcEvent.make(
		LightningArcEvent.KIND_WATER_SURFACE,
		Vector3(-3.0, surface_y, 0.0),
		Vector3(3.0, surface_y, 2.0),
		1.2,
		3307,
		"fixture_water_arc"
	)
	event.flatten_to_surface = true
	event.surface_y = surface_y
	event.subdivision_count = 5
	event.jitter_amplitude = 0.45
	event.branch_chance = 0.55
	event.maximum_branches = 7
	var result: Dictionary = LightningPathGenerator.generate(event)
	var all_paths: Array = [result.get("main_path", PackedVector3Array())]
	all_paths.append_array(result.get("branches", []))
	for raw_path: Variant in all_paths:
		if not raw_path is PackedVector3Array:
			failures.append("lightning: water generation returned an invalid path type")
			continue
		for point: Vector3 in raw_path as PackedVector3Array:
			if absf(point.y - surface_y) > 0.08:
				failures.append("lightning: conductive-water arcs should remain flattened to the surface")
				return


static func test_renderer_lifecycle(root: Node3D, host: Node, failures: Array[String]) -> void:
	var renderer := LightningArcRenderer.new()
	renderer.name = "LightningArcRenderer"
	root.add_child(renderer)
	var profile := LightningProfile.new()
	var event := LightningArcEvent.make(
		LightningArcEvent.KIND_DIRECT,
		Vector3.ZERO,
		Vector3(2.0, 2.0, 0.0),
		1.0,
		77,
		"fixture_renderer"
	)
	var visual: LightningArcVisual = renderer.render_arc(event, profile)
	if visual == null or renderer.rendered_count != 1:
		failures.append("lightning: a valid arc event should create one procedural visual")
	elif visual.mesh_nodes.size() < 2:
		failures.append("lightning: each arc should render a generated glow ribbon and core ribbon")
	if renderer.total_generated_points <= 2:
		failures.append("lightning: renderer instrumentation should report generated fractal points")

	var rejected_before: int = renderer.rejected_count
	var invalid := LightningArcEvent.make(
		LightningArcEvent.KIND_DIRECT,
		Vector3.ZERO,
		Vector3.ONE
	)
	invalid.end_position.x = INF
	if renderer.render_arc(invalid, profile) != null or renderer.rejected_count <= rejected_before:
		failures.append("lightning: renderer should reject non-finite arc events safely")

	renderer.reset_target()
	await host.get_tree().process_frame
	if not renderer.active_arcs.is_empty() or renderer.rendered_count != 0:
		failures.append("lightning: reset should clear active arcs and instrumentation")


static func test_lightning_projectile_scene(root: Node3D, host: Node, failures: Array[String]) -> void:
	var packed: PackedScene = load("res://scenes/abilities/legacy_projectiles/lightning_spark.tscn") as PackedScene
	if packed == null:
		failures.append("lightning: Lightning Spark scene should remain loadable")
		return
	var projectile := packed.instantiate() as Area3D
	root.add_child(projectile)
	if projectile.has_method("launch"):
		projectile.call("launch", Vector3.FORWARD)
	await host.get_tree().process_frame
	await host.get_tree().process_frame
	var vfx := projectile.get_node_or_null("ProceduralLightningVfx") as LightningProjectileVfx
	var legacy_mesh := projectile.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if vfx == null or vfx.renderer == null:
		failures.append("lightning: Lightning Spark should own the procedural Lightning visual component")
	if legacy_mesh == null or legacy_mesh.visible:
		failures.append("lightning: procedural Lightning should replace the old visible sphere presentation")
	elif vfx.renderer.rendered_count <= 0:
		failures.append("lightning: a launched Lightning Spark should generate live fractal arc geometry")
	projectile.queue_free()
