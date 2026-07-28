extends RefCounted
class_name SpatialReadabilityTestFixture

const GraceSpatialProfile: Resource = preload("res://data/player/grace_spatial_profile.tres")
const SetComposer = preload("res://scripts/environment/authored_set_composer.gd")


static func run(_host: Node, mission: Node3D) -> Array[String]:
	var failures: Array[String] = []
	if mission == null:
		return ["spatial readability: mission is null"]

	var profile_errors: Variant = GraceSpatialProfile.call("validate_profile")
	if profile_errors is Array:
		for error: Variant in profile_errors as Array:
			failures.append("spatial profile: " + str(error))

	_assert_vector2(
		SetComposer.get_recommended_clearance("land"),
		GraceSpatialProfile.get("land_clearance") as Vector2,
		"set composer land clearance matches Grace's profile",
		failures
	)
	_assert_vector2(
		SetComposer.get_recommended_clearance("swim"),
		GraceSpatialProfile.get("swim_clearance") as Vector2,
		"set composer swim clearance matches Grace's profile",
		failures
	)
	_assert_vector2(
		SetComposer.get_recommended_clearance("camera"),
		GraceSpatialProfile.get("camera_clearance") as Vector2,
		"set composer camera clearance matches Grace's profile",
		failures
	)

	var player: CharacterBody3D = mission.get_node_or_null("Player") as CharacterBody3D
	if player == null:
		failures.append("spatial readability: shared player is missing")
		return failures
	var controller: Node = player.get_node_or_null("SpatialProfileController")
	if controller == null:
		failures.append("spatial readability: player has no SpatialProfileController")
	else:
		var debug_data: Dictionary = controller.call("get_debug_data")
		if not bool(debug_data.get("applied", false)):
			failures.append("spatial readability: player profile was not applied")
		if str(debug_data.get("profile_id", "")) != "grace_default_v1":
			failures.append("spatial readability: player uses the wrong spatial profile")

	var collision: CollisionShape3D = player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision == null or not collision.shape is CapsuleShape3D:
		failures.append("spatial readability: player collision is not a capsule")
	else:
		var capsule: CapsuleShape3D = collision.shape as CapsuleShape3D
		if not is_equal_approx(capsule.radius, float(GraceSpatialProfile.get("collision_radius"))):
			failures.append("spatial readability: capsule radius does not match the profile")
		if not is_equal_approx(capsule.height, float(GraceSpatialProfile.get("collision_height"))):
			failures.append("spatial readability: capsule height does not match the profile")

	var grace_visual: Node3D = player.get_node_or_null("GraceVisualV1") as Node3D
	if grace_visual == null:
		failures.append("spatial readability: Grace visual is missing")
	else:
		var robe: MeshInstance3D = grace_visual.get_node_or_null("VisualRoot/BodyRoot/RobeSkirt") as MeshInstance3D
		var left_arm: MeshInstance3D = grace_visual.get_node_or_null("VisualRoot/LeftShoulderPivot/LeftArm") as MeshInstance3D
		if robe == null or not robe.mesh is CylinderMesh:
			failures.append("spatial readability: Grace robe mesh is missing")
		else:
			var robe_mesh: CylinderMesh = robe.mesh as CylinderMesh
			if robe_mesh.bottom_radius > 0.505:
				failures.append("spatial readability: Grace robe hem was not slimmed")
		if left_arm == null or not left_arm.mesh is CapsuleMesh:
			failures.append("spatial readability: Grace arm mesh is missing")
		elif (left_arm.mesh as CapsuleMesh).radius > 0.078:
			failures.append("spatial readability: Grace arm silhouette was not slimmed")

	var readability_pass: Node = mission.get_node_or_null("SpatialReadabilityPass")
	if readability_pass == null:
		failures.append("spatial readability: Drowned Bell has no readability pass")
	else:
		var readability_data: Dictionary = readability_pass.call("get_debug_data")
		if not bool(readability_data.get("installed", false)):
			failures.append("spatial readability: Drowned Bell readability pass did not install")
		if str(readability_data.get("layout_id", "")) != "drowned_chapel_readability_v1":
			failures.append("spatial readability: Drowned Bell uses the wrong readability layout")
		if int(readability_data.get("visible_module_count", 999)) > 62:
			failures.append("spatial readability: Drowned Bell remains above the v1 visible-module budget")
		if (readability_data.get("retired_nodes", []) as Array).size() < 7:
			failures.append("spatial readability: expected repeated clutter was not retired")
		var audit: Dictionary = readability_data.get("audit", {})
		if not bool(audit.get("passed", false)):
			for error: Variant in audit.get("errors", []):
				failures.append("spatial readability audit: " + str(error))
		if (audit.get("routes", []) as Array).size() < 2:
			failures.append("spatial readability: protected travel routes are missing")
		if (audit.get("zones", []) as Array).size() < 7:
			failures.append("spatial readability: interaction and landmark zones are missing")

	for retired_path: String in [
		"World/ModularChapelBenchmarkV1/NaveStructureModules/NavePillar01",
		"World/ModularChapelBenchmarkV1/NaveStructureModules/NaveTimberFrame01",
		"World/ModularChapelBenchmarkV1/FurnishingModules/CollapsedAisleCrate",
	]:
		var retired: Node3D = mission.get_node_or_null(retired_path) as Node3D
		if retired == null or retired.visible:
			failures.append("spatial readability: " + retired_path + " should be retired")

	for moved_path: String in [
		"World/ModularChapelBenchmarkV1/FurnishingModules/VestibuleSupplyCrate",
		"World/ModularChapelBenchmarkV1/FurnishingModules/MemorialStorageBarrel",
	]:
		var moved: Node = mission.get_node_or_null(moved_path)
		if moved == null or not bool(moved.get_meta("readability_repositioned", false)):
			failures.append("spatial readability: " + moved_path + " was not restaged")

	return failures


static func _assert_vector2(actual: Vector2, expected: Vector2, message: String, failures: Array[String]) -> void:
	if not actual.is_equal_approx(expected):
		failures.append(message + "; expected " + str(expected) + ", found " + str(actual))
