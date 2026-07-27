extends Node

const SceneUnderTest: PackedScene = preload("res://scenes/levels/prototypes/prototype_drowned_bell_v1.tscn")
const AuditorScript = preload("res://scripts/quality/playable_space_auditor.gd")
const SafeDestinationQueryScript = preload("res://scripts/quality/safe_destination_query.gd")

var failures: Array[String] = []


func _ready() -> void:
	GameState.reset_run()
	var mission := SceneUnderTest.instantiate()
	add_child(mission)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	var player: CharacterBody3D = mission.get_node_or_null("Player") as CharacterBody3D
	var playable_space: Node = mission.get_node_or_null("PlayableSpace")
	var recovery: Node = player.get_node_or_null("RecoveryController") if player != null else null
	check(player != null, "shared player is present")
	check(recovery != null, "shared player owns RecoveryController")
	check(playable_space != null, "Drowned Bell declares PlayableSpace3D")
	check(mission.get_node_or_null("PlayableSpace/VoidRecoveryVolume") != null, "void recovery volume exists")
	check(mission.get_node_or_null("EnvironmentPass") != null, "scene composes the authored environment pass")
	check(mission.get_node_or_null("PlayabilityPass") != null, "scene composes the playability integration pass")

	var water: Area3D = mission.get_node_or_null("NaveSwimPocket") as Area3D
	check(water != null, "nave swimming volume exists")
	var supporting_exits: Array[Node] = []
	for candidate: Node in get_tree().get_nodes_in_group("swimming_exit_anchor"):
		if mission.is_ancestor_of(candidate) and candidate.has_method("supports_volume"):
			if bool(candidate.call("supports_volume", water)):
				supporting_exits.append(candidate)
	check(supporting_exits.size() >= 2, "nave swimming volume has two authored exits")
	check(
		mission.get_node_or_null("World/AuthoredEnvironmentV2/ChapelShell/PoolExitStepLip") != null,
		"pool has a physical authored stepped exit"
	)

	var guidance_count: int = 0
	for guidance: Node in get_tree().get_nodes_in_group("quest_guidance_target"):
		if mission.is_ancestor_of(guidance):
			guidance_count += 1
	check(guidance_count >= 8, "quest route has guidance targets for every required beat")

	var audit: Dictionary = AuditorScript.audit_scene(mission)
	for error: String in audit.get("errors", []):
		failures.append("auditor: " + error)
	check(bool(audit.get("passed", false)), "playable-space auditor passes Drowned Bell")

	if player != null and playable_space != null:
		var outside_request := Vector3(80.0, 1.0, 80.0)
		var safe_result: Dictionary = SafeDestinationQueryScript.find_safe_destination(player, outside_request, {
			"playable_space": playable_space,
			"start_position": player.global_position,
			"require_ground": true,
			"search_steps": 12,
		})
		check(bool(safe_result.get("valid", false)), "safe destination query finds a fallback inside the route")
		var resolved_position: Vector3 = safe_result.get("position", outside_request)
		check(bool(playable_space.call("contains_position", resolved_position)), "safe destination remains inside playable bounds")
		check(resolved_position.distance_to(outside_request) > 10.0, "unsafe outside destination is rejected rather than accepted")

	if player != null and recovery != null:
		player.global_position = Vector3(0.0, -12.0, 0.0)
		recovery.call("request_recovery", "smoke test")
		await get_tree().physics_frame
		await get_tree().process_frame
		check(player.global_position.y > -4.4, "falling below the level restores Grace to safe ground")
		var horizontal_velocity := Vector2(player.velocity.x, player.velocity.z)
		check(
			horizontal_velocity.length() < 0.05 and absf(player.velocity.y) <= 1.0,
			"recovery clears unstable momentum while allowing one frame of gravity settling"
		)

	if player != null and water != null and not supporting_exits.is_empty():
		var swimming: Node = player.get_node_or_null("SwimmingController")
		if swimming != null:
			swimming.call("enter_water", water)
			var exit_anchor: Node3D = supporting_exits[0] as Node3D
			player.global_position = exit_anchor.global_position + Vector3(0.8, -0.4, 0.0)
			check(bool(exit_anchor.call("try_exit", player)), "authored water exit can place Grace on safe ground")
			check(not bool(swimming.call("should_handle_locomotion")), "water exit clears the swimming state")

	mission.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("GLOBAL_PLAYABILITY_FRAMEWORK_SMOKE_TEST: PASS")
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("GLOBAL_PLAYABILITY_FRAMEWORK_SMOKE_TEST: FAIL")
		get_tree().quit(1)


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
