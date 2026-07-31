extends Node


const EncounterScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_storm_drain_pack_encounter_v1.tscn"
)
const MireSpitAttack: Resource = preload(
	"res://data/enemy_attacks/storm_drain_mire_spit_attack.tres"
)
const SparkPounceAttack: Resource = preload(
	"res://data/enemy_attacks/storm_drain_spark_pounce_attack.tres"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	var encounter_value: Variant = EncounterScene.instantiate()
	_expect(encounter_value is Node3D, "Dedicated encounter scene instantiates")
	if not encounter_value is Node3D:
		_finish()
		return
	var encounter: Node3D = encounter_value as Node3D
	encounter.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(encounter)
	await get_tree().process_frame
	await get_tree().process_frame

	var enemy_root: Node = encounter.get_node_or_null("EnemyRoot")
	_expect(enemy_root != null, "Encounter exposes EnemyRoot")
	if enemy_root != null:
		_expect(enemy_root.get_child_count() == 4, "Encounter spawns four pack members")
	_test_encounter_activation(encounter, enemy_root)

	_test_member(
		enemy_root,
		"MireGremlin",
		"primer",
		"cautious",
		["Mire Spit", "Gremlin Bite", "Backstep"]
	)
	_test_member(
		enemy_root,
		"SparkGremlin",
		"payoff_specialist",
		"bold",
		["Spark Pounce", "Gremlin Bite", "Backstep"]
	)
	_test_member(
		enemy_root,
		"ShieldGremlin",
		"protector",
		"brute",
		["Guard Screech", "Gremlin Bite", "Backstep"]
	)
	_test_member(
		enemy_root,
		"RunnerGremlin",
		"skirmisher",
		"skittish",
		["Hookstep", "Gremlin Pounce", "Gremlin Bite"]
	)

	_expect(
		encounter.get_node_or_null("WaterChannel") != null,
		"Encounter includes the shallow reactive water channel"
	)
	_expect(
		encounter.get_node_or_null("TacticalDecisionOverlay") != null,
		"Encounter includes tactical telemetry"
	)
	_expect(
		encounter.get_node_or_null("LabResourceRegenerator") != null,
		"Encounter regenerates testing resources"
	)
	_expect(
		str(MireSpitAttack.call("get_action_id")) == "storm_drain_mire_spit",
		"Mire Spit exposes a stable action id"
	)
	_expect(
		MireSpitAttack.has_method("is_projectile_delivery")
		and bool(MireSpitAttack.call("is_projectile_delivery")),
		"Mire Spit uses projectile delivery"
	)
	_expect(
		MireSpitAttack.get("projectile_scene") is PackedScene,
		"Mire Spit owns a projectile scene"
	)
	_expect(
		str(SparkPounceAttack.call("get_action_id")) == "storm_drain_spark_pounce",
		"Spark Pounce exposes a stable action id"
	)
	_expect(
		SparkPounceAttack.has_method("is_projectile_delivery")
		and not bool(SparkPounceAttack.call("is_projectile_delivery")),
		"Spark Pounce remains a contact payoff"
	)
	_test_guard_support(enemy_root)
	_test_cover_request_broadcast(enemy_root)
	_test_tactical_decision_cadence(enemy_root)
	_test_freed_lock_on_target(encounter)

	if encounter.has_method("reset_lab"):
		encounter.call("reset_lab")
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		_expect(
			enemy_root != null and enemy_root.get_child_count() == 4,
			"Reset creates a fresh four-member pack"
		)
		_test_encounter_activation(encounter, enemy_root)
	else:
		_expect(false, "Encounter exposes reset_lab")

	encounter.queue_free()
	await get_tree().process_frame
	_finish()


func _test_encounter_activation(encounter: Node, enemy_root: Node) -> void:
	var player: Node = encounter.get_node_or_null("Player")
	_expect(player != null, "Encounter exposes Player")
	if player == null or enemy_root == null:
		return
	_expect(player.is_in_group("player"), "Storm Drain encounter registers Player group")
	var resolved_count: int = 0
	var chase_count: int = 0
	for member: Node in enemy_root.get_children():
		var brain: Node = member.get_node_or_null("EnemyBrain")
		if brain == null:
			continue
		if brain.has_method("_resolve_encounter_player"):
			brain.call("_resolve_encounter_player")
		if brain.get("player") == player:
			resolved_count += 1
		if int(brain.get("state")) == 1:
			chase_count += 1
		_expect(
			float(brain.get("encounter_join_radius")) >= 20.0,
			member.name + " can join from across the dedicated arena"
		)
	_expect(resolved_count == 4, "Every pack brain resolves Grace as its target")
	_expect(chase_count == 4, "Every pack member begins the encounter in CHASE")


func _test_member(
	enemy_root: Node,
	member_name: String,
	expected_role: String,
	expected_personality: String,
	expected_actions: Array[String]
) -> void:
	if enemy_root == null:
		return
	var member: Node = enemy_root.get_node_or_null(member_name)
	_expect(member != null, member_name + " exists")
	if member == null:
		return
	var brain: Node = member.get_node_or_null("EnemyBrain")
	_expect(brain != null, member_name + " has a tactical brain")
	if brain == null:
		return
	_expect(
		str(brain.get("tactical_squad_role_id")) == expected_role,
		member_name + " keeps its authored squad role"
	)
	_expect(
		str(brain.get("personality_id")) == expected_personality,
		member_name + " keeps its personality"
	)
	_expect(
		float(brain.get("tactical_decision_interval")) >= 0.1,
		member_name + " uses throttled tactical reconsideration"
	)
	var action_names: Array[String] = []
	var options_value: Variant = brain.get("action_options")
	if options_value is Array:
		for option_value: Variant in options_value as Array:
			if not option_value is Resource:
				continue
			var option: Resource = option_value as Resource
			if not option.has_method("get_action"):
				continue
			var action_value: Variant = option.call("get_action")
			if not action_value is Resource:
				continue
			var action: Resource = action_value as Resource
			if action.has_method("get_display_name"):
				action_names.append(str(action.call("get_display_name")))
	action_names.sort()
	var expected_sorted: Array[String] = expected_actions.duplicate()
	expected_sorted.sort()
	_expect(
		action_names == expected_sorted,
		member_name + " receives its intended action library"
	)


func _test_guard_support(enemy_root: Node) -> void:
	if enemy_root == null:
		return
	var shield: Node = enemy_root.get_node_or_null("ShieldGremlin")
	var mire: Node = enemy_root.get_node_or_null("MireGremlin")
	if shield == null or mire == null:
		return
	var brain: Node = shield.get_node_or_null("EnemyBrain")
	var hit_receiver: Node = mire.get_node_or_null("HitReceiver")
	_expect(brain != null and hit_receiver != null, "Guard support test components exist")
	if brain == null or hit_receiver == null:
		return
	hit_receiver.set("current_stance", 1)
	_expect(
		int(brain.call("get_nearby_missing_stance")) > 0,
		"Protector detects damaged allied stance"
	)
	var restored: bool = bool(brain.call("_restore_ally_stance", mire))
	_expect(restored, "Guard Screech restores allied stance")
	_expect(int(hit_receiver.get("current_stance")) > 1, "Guard support changes stance state")


func _test_cover_request_broadcast(enemy_root: Node) -> void:
	if enemy_root == null:
		return
	var runner: Node = enemy_root.get_node_or_null("RunnerGremlin")
	if runner == null:
		return
	var brain: Node = runner.get_node_or_null("EnemyBrain")
	var hookstep: Resource = _find_option_by_name(brain, "Hookstep")
	_expect(brain != null and hookstep != null, "Hookstep broadcast test components exist")
	if brain == null or hookstep == null:
		return
	brain.call("_reserve_selected_option", hookstep)
	var coordination_value: Variant = brain.call("get_coordination_debug_data")
	var coordination: Dictionary = (
		(coordination_value as Dictionary)
		if coordination_value is Dictionary
		else {}
	)
	var blackboard_value: Variant = coordination.get("blackboard", {})
	var blackboard: Dictionary = (
		(blackboard_value as Dictionary)
		if blackboard_value is Dictionary
		else {}
	)
	var intent_tags: Array[String] = _string_array(
		blackboard.get("squad_intent_tags", [])
	)
	_expect(
		intent_tags.has("cover_requested"),
		"Hookstep broadcasts its typed cover request through callv"
	)
	brain.call("_release_coordination", "cover smoke cleanup", false)


func _test_tactical_decision_cadence(enemy_root: Node) -> void:
	if enemy_root == null:
		return
	var mire: Node = enemy_root.get_node_or_null("MireGremlin")
	if mire == null:
		return
	var brain: Node = mire.get_node_or_null("EnemyBrain")
	_expect(brain != null, "Cadence test finds Mire tactical brain")
	if brain == null:
		return
	brain.call("invalidate_tactical_decision_cache")
	var evaluations_before: int = int(brain.get("tactical_evaluation_count"))
	var cache_hits_before: int = int(brain.get("tactical_cache_hit_count"))
	brain.call("select_action", 8.0, false)
	var evaluations_after_first: int = int(brain.get("tactical_evaluation_count"))
	brain.call("select_action", 8.0, false)
	var evaluations_after_second: int = int(brain.get("tactical_evaluation_count"))
	var cache_hits_after: int = int(brain.get("tactical_cache_hit_count"))
	_expect(
		evaluations_after_first == evaluations_before + 1,
		"First tactical request performs one evaluation"
	)
	_expect(
		evaluations_after_second == evaluations_after_first,
		"Immediate repeated request reuses the tactical decision"
	)
	_expect(
		cache_hits_after == cache_hits_before + 1,
		"Tactical cadence records one cache hit"
	)
	brain.call("_release_coordination", "cadence smoke cleanup", false)
	brain.call("invalidate_tactical_decision_cache")


func _test_freed_lock_on_target(encounter: Node) -> void:
	var player: Node = encounter.get_node_or_null("Player")
	if player == null:
		return
	var driver: Node = player.get_node_or_null("PlayerControlDriver")
	_expect(driver != null, "Player avatar control driver exists")
	if driver == null:
		return
	var stale_target := Node3D.new()
	stale_target.name = "FreedLockTarget"
	add_child(stale_target)
	player.set("lock_on_target", stale_target)
	stale_target.free()
	var resolved_target: Variant = driver.call("_get_valid_lock_on_target")
	_expect(
		resolved_target == null,
		"Player avatar intent ignores a previously freed lock-on target"
	)
	driver.call("sample_intent", 0.0)
	player.set("lock_on_target", null)


func _find_option_by_name(brain: Node, option_name: String) -> Resource:
	if brain == null:
		return null
	var options_value: Variant = brain.get("action_options")
	if not options_value is Array:
		return null
	for option_value: Variant in options_value as Array:
		if not option_value is Resource:
			continue
		var option: Resource = option_value as Resource
		if option.has_method("get_display_name") and (
			str(option.call("get_display_name")) == option_name
		):
			return option
	return null


func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "" and not result.has(text):
				result.append(text)
	return result


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("STORM_DRAIN_PACK_ENCOUNTER_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("STORM_DRAIN_PACK_ENCOUNTER_SMOKE_TEST: " + failure)
	get_tree().quit(1)