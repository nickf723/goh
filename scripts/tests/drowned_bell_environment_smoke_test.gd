extends Node

const SceneUnderTest: PackedScene = preload("res://scenes/levels/prototypes/prototype_drowned_bell_v1.tscn")
const EnvironmentAuditor = preload("res://scripts/environment/authored_environment_auditor.gd")

var failures: Array[String] = []
var elapsed: float = 0.0
var finished: bool = false


func _process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	if elapsed >= 20.0:
		push_error("Drowned Bell environment smoke test stalled.")
		get_tree().quit(1)


func _ready() -> void:
	GameState.reset_run()
	var mission := SceneUnderTest.instantiate()
	add_child(mission)
	for _index: int in range(8):
		await get_tree().process_frame
	await get_tree().physics_frame

	var environment_pass: Node = mission.get_node_or_null("EnvironmentPass")
	var benchmark_pass: Node = mission.get_node_or_null("BenchmarkRemasterPass")
	var authored_root: Node3D = mission.get_node_or_null("World/AuthoredEnvironmentV2") as Node3D
	var benchmark_root: Node3D = mission.get_node_or_null("World/ModularChapelBenchmarkV1") as Node3D
	check(environment_pass != null, "environment pass is composed")
	check(benchmark_pass != null, "benchmark remaster pass is composed")
	check(authored_root != null, "authored environment root exists")
	check(benchmark_root != null, "modular chapel benchmark root exists")
	if environment_pass != null:
		var debug_data: Dictionary = environment_pass.call("get_debug_data")
		check(bool(debug_data.get("installed", false)), "environment pass finishes installation")
		var stats: Dictionary = debug_data.get("build_stats", {})
		check(int(stats.get("static_boxes", 0)) >= 30, "builder produced a substantial collision shell")
		check(int(stats.get("visuals", 0)) >= 90, "builder produced authored dressing rather than a bare test room")
		check(int(stats.get("stair_runs", 0)) >= 3, "builder produced reusable stair runs")
		check(int(stats.get("lights", 0)) >= 5, "environment owns local lighting")
	if benchmark_pass != null:
		var benchmark_data: Dictionary = benchmark_pass.call("get_debug_data")
		check(bool(benchmark_data.get("installed", false)), "modular benchmark finishes installation")
		check(str(benchmark_data.get("set_id", "")) == "drowned_chapel_benchmark_v1", "benchmark publishes its canonical set id")
		check(int(benchmark_data.get("module_count", 0)) >= 60, "benchmark uses a substantial repeated modular vocabulary")
		check(int(benchmark_data.get("support_shell_piece_count", 0)) >= 55, "architecture modules reuse the continuous support shell")
		check(int(benchmark_data.get("physical_prop_count", 0)) >= 3, "freestanding props retain physical collision")
		check(int(benchmark_data.get("hidden_legacy_meshes", 0)) >= 25, "replaced procedural surfaces are visually retired")
		var categories: Array = benchmark_data.get("categories", [])
		for category: String in ["architecture", "prop", "lighting", "water"]:
			check(categories.has(category), "benchmark includes modular " + category + " pieces")

	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/ShoreAndCauseway/CausewayCore") != null, "causeway keeps one continuous collision core")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/ChapelShell/NaveFloor") != null, "nave keeps a continuous authored support floor")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/ChapelShell/MainPoolStairs") != null, "pool has a broad main stair exit")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/ChapelShell/RearPoolStairs") != null, "pool has a second physical stair exit")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/Architecture/BellFrame") != null, "bespoke bell frame survives the remaster")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/Architecture/MemorialArcade") != null, "bespoke memorial arcade survives the remaster")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/Architecture/RoseWindow") != null, "bespoke rose-window landmark survives the remaster")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/PropsAndOvergrowth/BrokenPews") != null, "nave keeps authored pew dressing")
	check(mission.get_node_or_null("World/NaveWestFloor") == null, "legacy slab floor is removed")
	check(mission.get_node_or_null("World/BellTower") == null, "legacy freestanding bell cylinder is removed")

	check(mission.get_node_or_null("World/ModularChapelBenchmarkV1/CausewayModules/CausewayFloor00") != null, "causeway is surfaced with reusable floor modules")
	check(mission.get_node_or_null("World/ModularChapelBenchmarkV1/ChapelFloorModules/EntranceThreshold") != null, "chapel threshold uses a reusable floor module")
	check(mission.get_node_or_null("World/ModularChapelBenchmarkV1/WallAndThresholdModules/ModularEntranceArch") != null, "chapel entrance uses the reusable arch")
	check(mission.get_node_or_null("World/ModularChapelBenchmarkV1/WallAndThresholdModules/ModularCryptArch") != null, "crypt threshold uses the reusable arch language")
	check(mission.get_node_or_null("World/ModularChapelBenchmarkV1/NaveStructureModules/NavePillar00") != null, "nave uses reusable pillar modules")
	check(mission.get_node_or_null("World/ModularChapelBenchmarkV1/NaveStructureModules/NaveTimberFrame00") != null, "nave uses reusable timber-frame modules")
	check(mission.get_node_or_null("World/ModularChapelBenchmarkV1/PoolAndAltarModules/PoolOverflowChannel") != null, "flooded side chapel uses the modular water-transition language")
	check(mission.get_node_or_null("World/ModularChapelBenchmarkV1/PoolAndAltarModules/TuningPlatePedestal") != null, "tuning plate receives a reusable physical presentation base")
	check(mission.get_node_or_null("World/ModularChapelBenchmarkV1/FurnishingModules/VestibuleSupplyCrate") != null, "chapel dressing includes reusable physical props")

	var nave_support: StaticBody3D = mission.get_node_or_null("World/AuthoredEnvironmentV2/ChapelShell/NaveFloor") as StaticBody3D
	var nave_support_visual: MeshInstance3D
	if nave_support != null:
		nave_support_visual = nave_support.get_node_or_null("Visual") as MeshInstance3D
	check(nave_support != null and nave_support.collision_layer != 0, "hidden nave support remains physical")
	check(nave_support_visual != null and not nave_support_visual.visible, "old nave floor mesh is hidden beneath the modules")
	var entrance_module: Node = mission.get_node_or_null("World/ModularChapelBenchmarkV1/WallAndThresholdModules/ModularEntranceArch")
	check(entrance_module != null and bool(entrance_module.get_meta("uses_support_shell", false)), "architectural modules declare support-shell collision ownership")
	check(entrance_module != null and not _piece_has_active_collision(entrance_module), "support-shell entrance module does not create duplicate collision")
	var physical_crate: Node = mission.get_node_or_null("World/ModularChapelBenchmarkV1/FurnishingModules/VestibuleSupplyCrate")
	check(physical_crate != null and _piece_has_active_collision(physical_crate), "freestanding modular crate remains a physical object")

	var main_stairs: Node = mission.get_node_or_null("World/AuthoredEnvironmentV2/ChapelShell/MainPoolStairs")
	var rear_stairs: Node = mission.get_node_or_null("World/AuthoredEnvironmentV2/ChapelShell/RearPoolStairs")
	check(_count_step_bodies(main_stairs) == 7, "main pool stair run contains seven matched collision steps")
	check(_count_step_bodies(rear_stairs) == 4, "rear pool stair run contains four matched collision steps")

	var water: Area3D = mission.get_node_or_null("NaveSwimPocket") as Area3D
	check(water != null, "shared swimming volume remains present")
	if water != null:
		var water_collision: CollisionShape3D = water.get_node_or_null("CollisionShape3D") as CollisionShape3D
		check(water_collision != null and water_collision.shape is BoxShape3D, "water has one aligned collision volume")
		check(water.get_node_or_null("DeepWater") != null, "water surface is rebuilt with the authored environment")
		check(water.get_node_or_null("CurrentRibbon00") != null, "current direction is visible in the water")

	if authored_root != null:
		var report: Dictionary = EnvironmentAuditor.audit(mission)
		for error: String in report.get("errors", []):
			failures.append("environment auditor: " + error)
		check(bool(report.get("passed", false)), "authored environment auditor passes")
		check(int(report.get("surface_count", 0)) >= 30, "environment audit sees the collision surfaces")
		check(int(report.get("decor_count", 0)) >= 90, "environment audit sees the dressing layer")

	for z_value: float in [-1.5, 3.0, 8.0, 13.0, 18.0, 22.0]:
		check(_has_ground_below(mission, Vector3(0.0, 2.0, z_value), 5.0), "causeway remains supported near z=%.1f" % z_value)
	for point: Vector3 in [
		Vector3(0.0, 2.0, 24.0),
		Vector3(-5.5, 2.0, 27.0),
		Vector3(-1.4, 2.0, 31.0),
		Vector3(1.2, 2.0, 33.1),
		Vector3(-1.8, 2.0, 35.0),
	]:
		check(_has_ground_below(mission, point, 6.0), "golden-path point has supporting collision at %s" % str(point))

	mission.queue_free()
	await get_tree().process_frame
	finished = true
	if failures.is_empty():
		print("DROWNED_BELL_ENVIRONMENT_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("DROWNED_BELL_ENVIRONMENT_SMOKE_TEST: FAIL")
		get_tree().quit(1)


func _count_step_bodies(stair_run: Node) -> int:
	if stair_run == null:
		return 0
	var count: int = 0
	for child: Node in stair_run.get_children():
		if child is StaticBody3D and child.name.begins_with("Step"):
			count += 1
	return count


func _piece_has_active_collision(node: Node) -> bool:
	if node is CollisionObject3D and (node as CollisionObject3D).collision_layer != 0:
		return true
	for child: Node in node.get_children():
		if _piece_has_active_collision(child):
			return true
	return false


func _has_ground_below(mission: Node3D, point: Vector3, distance: float) -> bool:
	if mission.get_world_3d() == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * distance)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not mission.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
