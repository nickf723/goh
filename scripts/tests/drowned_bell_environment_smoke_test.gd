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
	if elapsed >= 10.0:
		push_error("Drowned Bell environment smoke test stalled.")
		get_tree().quit(1)


func _ready() -> void:
	GameState.reset_run()
	var mission := SceneUnderTest.instantiate()
	add_child(mission)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	var environment_pass: Node = mission.get_node_or_null("EnvironmentPass")
	var authored_root: Node3D = mission.get_node_or_null("World/AuthoredEnvironmentV2") as Node3D
	check(environment_pass != null, "environment pass is composed")
	check(authored_root != null, "authored environment root exists")
	if environment_pass != null:
		var debug_data: Dictionary = environment_pass.call("get_debug_data")
		check(bool(debug_data.get("installed", false)), "environment pass finishes installation")
		var stats: Dictionary = debug_data.get("build_stats", {})
		check(int(stats.get("static_boxes", 0)) >= 30, "builder produced a substantial collision shell")
		check(int(stats.get("visuals", 0)) >= 90, "builder produced authored dressing rather than a bare test room")
		check(int(stats.get("stair_runs", 0)) >= 3, "builder produced reusable stair runs")
		check(int(stats.get("lights", 0)) >= 5, "environment owns local lighting")

	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/ShoreAndCauseway/CausewayCore") != null, "causeway has one continuous collision core")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/ChapelShell/NaveFloor") != null, "nave has a continuous authored floor")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/ChapelShell/MainPoolStairs") != null, "pool has a broad main stair exit")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/ChapelShell/RearPoolStairs") != null, "pool has a second physical stair exit")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/Architecture/BellFrame") != null, "bell is carried by an authored frame")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/Architecture/MemorialArcade") != null, "west aisle has a memorial arcade")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/Architecture/AltarAndCrypt/CryptFrame") != null, "crypt seal has architectural framing")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/Architecture/RoseWindow") != null, "chapel has a rose-window landmark")
	check(mission.get_node_or_null("World/AuthoredEnvironmentV2/PropsAndOvergrowth/BrokenPews") != null, "nave contains composed pew dressing")
	check(mission.get_node_or_null("World/NaveWestFloor") == null, "legacy slab floor is removed")
	check(mission.get_node_or_null("World/BellTower") == null, "legacy freestanding bell cylinder is removed")

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
