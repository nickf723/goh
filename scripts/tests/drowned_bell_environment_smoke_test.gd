extends Node

const SceneUnderTest: PackedScene = preload("res://scenes/levels/prototypes/prototype_drowned_bell_v1.tscn")
const EnvironmentAuditor = preload("res://scripts/environment/authored_environment_auditor.gd")
const SetClearanceAuditor = preload("res://scripts/environment/authored_set_clearance_auditor.gd")

var failures: Array[String] = []
var elapsed: float = 0.0
var finished: bool = false


func _process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	if elapsed >= 24.0:
		push_error("Drowned Bell environment smoke test stalled.")
		get_tree().quit(1)


func _ready() -> void:
	GameState.reset_run()
	var mission := SceneUnderTest.instantiate()
	add_child(mission)
	for _index: int in range(12):
		await get_tree().process_frame
	await get_tree().physics_frame

	var environment_pass: Node = mission.get_node_or_null("EnvironmentPass")
	var benchmark_pass: Node = mission.get_node_or_null("BenchmarkRemasterPass")
	var crypt_layout_pass: Node = mission.get_node_or_null("CryptLayoutPass")
	var authored_root: Node3D = mission.get_node_or_null("World/AuthoredEnvironmentV2") as Node3D
	var benchmark_root: Node3D = mission.get_node_or_null("World/ModularChapelBenchmarkV1") as Node3D
	var composed_passage: Node3D = mission.get_node_or_null("World/BellBelowV3/ComposedCryptPassageV1") as Node3D
	check(environment_pass != null, "environment pass is composed")
	check(benchmark_pass != null, "benchmark remaster pass is composed")
	check(crypt_layout_pass != null, "crypt layout pass is composed")
	check(authored_root != null, "authored environment root exists")
	check(benchmark_root != null, "modular chapel benchmark root exists")
	check(composed_passage != null, "data-driven crypt passage root exists")
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
	if crypt_layout_pass != null:
		var layout_data: Dictionary = crypt_layout_pass.call("get_debug_data")
		check(bool(layout_data.get("installed", false)), "crypt layout pass finishes installation")
		check(str(layout_data.get("layout_id", "")) == "drowned_bell_crypt_passage_v1", "crypt uses the canonical authored set layout")
		var clearance_report: Dictionary = layout_data.get("audit", {})
		for error: String in clearance_report.get("errors", []):
			failures.append("set clearance: " + error)
		check(bool(clearance_report.get("passed", false)), "crypt set clearance audit passes")

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

	var corridor: Node3D = mission.get_node_or_null("World/BellBelowV3/ComposedCryptPassageV1/CollapsedBurialPassage") as Node3D
	var chamber_wall: Node3D = mission.get_node_or_null("World/BellBelowV3/ComposedCryptPassageV1/ListenerChamberFrontWall") as Node3D
	var chamber_stairs: Node3D = mission.get_node_or_null("World/BellBelowV3/ComposedCryptPassageV1/ChamberExitSteps") as Node3D
	check(corridor != null, "crypt layout composes a corridor from data")
	check(chamber_wall != null, "crypt layout composes the chamber wall from opening data")
	check(chamber_stairs != null, "crypt layout composes a walkable chamber exit")
	check(mission.get_node_or_null("World/BellBelowV3/ComposedCryptPassageV1/PassageOpeningTrim") != null, "crypt opening receives reusable modular trim")
	if corridor != null:
		check(float(corridor.get_meta("clear_width", 0.0)) >= 5.5, "swim corridor preserves camera-friendly width")
		check(float(corridor.get_meta("clear_height", 0.0)) >= 5.0, "swim corridor preserves vertical clearance")
		var direct_audit: Dictionary = SetClearanceAuditor.audit(corridor)
		check(bool(direct_audit.get("passed", false)), "corridor passes the reusable clearance auditor")
	if chamber_wall != null:
		var openings: Array = chamber_wall.get_meta("openings", [])
		check(openings.size() == 1, "chamber wall owns one aligned passage opening")
		if openings.size() == 1 and openings[0] is Dictionary:
			var opening: Dictionary = openings[0] as Dictionary
			check(is_equal_approx(float(opening.get("center_offset", 99.0)), -1.8), "chamber opening shares the corridor centerline")
			check(float(opening.get("width", 0.0)) >= 5.5, "chamber opening matches swim-corridor width")
			check(float(opening.get("height", 0.0)) >= 4.7, "chamber opening has generous vertical clearance")
	if chamber_stairs != null:
		check(chamber_stairs.get_node_or_null("WalkRamp") != null, "chamber exit stairs use continuous ramp collision")

	var old_passage: Node = mission.get_node_or_null("World/BellBelowV3/CollapsedBurialPassage")
	check(old_passage != null and not (old_passage as Node3D).visible, "hand-positioned passage geometry is visually retired")
	check(old_passage != null and not _piece_has_active_collision(old_passage), "hand-positioned passage collision is retired")
	var water: Area3D = mission.get_node_or_null("World/BellBelowV3/CryptSwimPassage") as Area3D
	check(water != null, "shared crypt swimming volume remains present")
	if water != null:
		var water_collision: CollisionShape3D = water.get_node_or_null("CollisionShape3D") as CollisionShape3D
		check(water_collision != null and water_collision.shape is BoxShape3D, "crypt water keeps one aligned box volume")
		if water_collision != null and water_collision.shape is BoxShape3D:
			var water_size: Vector3 = (water_collision.shape as BoxShape3D).size
			check(water_size.x >= 5.5, "crypt water matches the widened passage")
			check(water_size.y >= 4.5, "crypt water fills the usable swim height")
			check(water_size.z >= 10.0, "crypt water spans the full passage")
		check(water.get_node_or_null("ComposedPassageWater") != null, "composed passage owns its water presentation")
	var drained_walkway: StaticBody3D = mission.get_node_or_null("World/BellBelowV3/DrainedPassageWalkway") as StaticBody3D
	if drained_walkway != null:
		var walkway_shape: CollisionShape3D = drained_walkway.get_node_or_null("CollisionShape3D") as CollisionShape3D
		check(walkway_shape != null and walkway_shape.shape is BoxShape3D and (walkway_shape.shape as BoxShape3D).size.x >= 5.0, "drained return route inherits the wider layout")

	for sample_z: float in [46.5, 48.5, 50.5, 52.0]:
		check(_capsule_lane_is_clear(mission, Vector3(-1.8, -4.15, sample_z)), "swim capsule has clearance at z=%.1f" % sample_z)

	var main_stairs: Node = mission.get_node_or_null("World/AuthoredEnvironmentV2/ChapelShell/MainPoolStairs")
	var rear_stairs: Node = mission.get_node_or_null("World/AuthoredEnvironmentV2/ChapelShell/RearPoolStairs")
	check(_count_step_bodies(main_stairs) == 7, "main pool stair run contains seven matched collision steps")
	check(_count_step_bodies(rear_stairs) == 4, "rear pool stair run contains four matched collision steps")

	var nave_water: Area3D = mission.get_node_or_null("NaveSwimPocket") as Area3D
	check(nave_water != null, "shared nave swimming volume remains present")
	if nave_water != null:
		var water_collision: CollisionShape3D = nave_water.get_node_or_null("CollisionShape3D") as CollisionShape3D
		check(water_collision != null and water_collision.shape is BoxShape3D, "nave water has one aligned collision volume")
		check(nave_water.get_node_or_null("DeepWater") != null, "nave water surface is rebuilt with the authored environment")
		check(nave_water.get_node_or_null("CurrentRibbon00") != null, "nave current direction is visible in the water")

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
	if node is CollisionShape3D and not (node as CollisionShape3D).disabled:
		return true
	for child: Node in node.get_children():
		if _piece_has_active_collision(child):
			return true
	return false


func _capsule_lane_is_clear(mission: Node3D, position_value: Vector3) -> bool:
	if mission.get_world_3d() == null:
		return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.52
	capsule.height = 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, position_value)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return mission.get_world_3d().direct_space_state.intersect_shape(query, 8).is_empty()


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
