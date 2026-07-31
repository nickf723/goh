extends Node


const TargetAllocator = preload(
	"res://scripts/ai/target_allocation_blackboard.gd"
)
const TargetEvaluator = preload(
	"res://scripts/ai/role_aware_target_evaluator.gd"
)
const EncounterScene: PackedScene = preload(
	"res://scenes/levels/prototypes/prototype_storm_drain_pack_encounter_v1.tscn"
)
const ManifestedAvatarScene: PackedScene = preload(
	"res://scenes/actors/avatars/manifested_avatar_actor.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	TargetAllocator.clear_all()
	_test_overkill_prevention()
	_test_setup_and_payoff_pairing()
	_test_duplicate_control_prevention()
	_test_focus_fire_override()
	await _test_live_storm_drain_split()
	TargetAllocator.clear_all()
	_finish()


func _test_overkill_prevention() -> void:
	TargetAllocator.clear_all()
	var squad_id: String = "overkill_test"
	var fragile: Dictionary = _candidate(101, "Fragile", 2, 4.0)
	var healthy: Dictionary = _candidate(102, "Healthy", 12, 5.0)
	TargetAllocator.claim_target(
		squad_id,
		1,
		"Committed Actor",
		101,
		"Fragile",
		"damage",
		6.0,
		[],
		5.0
	)
	var plan: Dictionary = _choose(
		[fragile, healthy],
		squad_id,
		"generalist"
	)
	_expect(
		int(plan.get("selected_id", 0)) == 102,
		"Overkill budget redirects the next attacker"
	)
	_expect(
		_trace_has_penalty(plan, 101, "already covers"),
		"Overkill rejection remains inspectable"
	)


func _test_setup_and_payoff_pairing() -> void:
	TargetAllocator.clear_all()
	var squad_id: String = "setup_payoff_test"
	var prepared: Dictionary = _candidate(201, "Prepared", 20, 4.0)
	var fresh: Dictionary = _candidate(202, "Fresh", 20, 4.3)
	TargetAllocator.claim_target(
		squad_id,
		2,
		"Primer Actor",
		201,
		"Prepared",
		"setup",
		0.0,
		["wet"],
		5.0
	)
	var primer_plan: Dictionary = _choose(
		[prepared, fresh],
		squad_id,
		"primer"
	)
	_expect(
		int(primer_plan.get("selected_id", 0)) == 202,
		"Primer avoids duplicating an existing Wet setup"
	)
	var payoff_plan: Dictionary = _choose(
		[prepared, fresh],
		squad_id,
		"payoff_specialist"
	)
	_expect(
		int(payoff_plan.get("selected_id", 0)) == 201,
		"Payoff Specialist follows the Primer's prepared target"
	)


func _test_duplicate_control_prevention() -> void:
	TargetAllocator.clear_all()
	var squad_id: String = "control_test"
	var controlled: Dictionary = _candidate(301, "Controlled", 20, 3.5)
	controlled["action_blocked"] = true
	var dangerous: Dictionary = _candidate(302, "Dangerous", 20, 4.0)
	TargetAllocator.claim_target(
		squad_id,
		3,
		"Control Actor",
		301,
		"Controlled",
		"control",
		0.0,
		["stunned"],
		5.0
	)
	var plan: Dictionary = _choose(
		[controlled, dangerous],
		squad_id,
		"disruptor"
	)
	_expect(
		int(plan.get("selected_id", 0)) == 302,
		"Disruptor controls the unclaimed dangerous target"
	)


func _test_focus_fire_override() -> void:
	TargetAllocator.clear_all()
	var squad_id: String = "focus_override_test"
	var boss: Dictionary = _candidate(401, "Boss Core", 3, 7.0)
	var add: Dictionary = _candidate(402, "Add", 20, 4.0)
	TargetAllocator.claim_target(
		squad_id,
		4,
		"Committed Actor",
		401,
		"Boss Core",
		"damage",
		8.0,
		[],
		5.0
	)
	var contexts: Dictionary = _contexts([boss, add], squad_id)
	var plan: Dictionary = TargetEvaluator.choose_best(
		[boss, add],
		contexts,
		"generalist",
		{
			"preferred_distance": 4.0,
			"distance_span": 12.0,
			"focus_fire_target_id": 401,
			"focus_fire_bonus": 100.0,
		}
	)
	_expect(
		int(plan.get("selected_id", 0)) == 401,
		"Authored boss focus-fire overrides overkill avoidance"
	)


func _test_live_storm_drain_split() -> void:
	TargetAllocator.clear_all()
	var encounter_value: Variant = EncounterScene.instantiate()
	_expect(encounter_value is Node3D, "Live multi-target encounter instantiates")
	if not encounter_value is Node3D:
		return
	var encounter: Node3D = encounter_value as Node3D
	encounter.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(encounter)
	await get_tree().process_frame
	await get_tree().process_frame
	var player: Node3D = encounter.get_node_or_null("Player") as Node3D
	var enemy_root: Node = encounter.get_node_or_null("EnemyRoot")
	_expect(player != null and enemy_root != null, "Live allocation test resolves combat actors")
	if player == null or enemy_root == null:
		encounter.queue_free()
		return

	var ruvia_value: Variant = ManifestedAvatarScene.instantiate()
	_expect(ruvia_value is Node3D, "Ruvia manifestation scene instantiates")
	if not ruvia_value is Node3D:
		encounter.queue_free()
		return
	var ruvia: Node3D = ruvia_value as Node3D
	ruvia.name = "RuviaAllocationTarget"
	ruvia.position = Vector3(3.0, 0.96, 7.0)
	encounter.add_child(ruvia)
	await get_tree().process_frame
	var definition_value: Variant = ruvia.get("avatar_definition")
	var init_value: Variant = ruvia.call(
		"initialize_manifestation",
		definition_value,
		player,
		null,
		null
	)
	var init_failures: Array[String] = _string_array(init_value)
	_expect(init_failures.is_empty(), "Ruvia initializes as a live target candidate")
	_expect(ruvia.is_in_group("enemy_targetable"), "Ruvia exposes the enemy target group")

	TargetAllocator.clear_all()
	var mire_brain: Node = _brain(enemy_root, "MireGremlin")
	var spark_brain: Node = _brain(enemy_root, "SparkGremlin")
	var runner_brain: Node = _brain(enemy_root, "RunnerGremlin")
	_expect(
		mire_brain != null and spark_brain != null and runner_brain != null,
		"Live role brains resolve"
	)
	if mire_brain == null or spark_brain == null or runner_brain == null:
		encounter.queue_free()
		return

	mire_brain.call("_refresh_target_allocation", true)
	var prepared_target_id: int = int(mire_brain.call("get_current_allocated_target_id"))
	var mire_spit: Resource = _find_option_by_name(mire_brain, "Mire Spit")
	_expect(prepared_target_id > 0 and mire_spit != null, "Primer selects and owns a live target")
	if mire_spit != null:
		mire_brain.call("_finalize_tactical_decision", mire_spit)

	spark_brain.call("_refresh_target_allocation", true)
	var payoff_target_id: int = int(spark_brain.call("get_current_allocated_target_id"))
	_expect(
		payoff_target_id == prepared_target_id,
		"Live Payoff Specialist follows Mire's prepared target"
	)
	var spark_pounce: Resource = _find_option_by_name(spark_brain, "Spark Pounce")
	if spark_pounce != null:
		spark_brain.call("_finalize_tactical_decision", spark_pounce)

	runner_brain.call("_refresh_target_allocation", true)
	var runner_target_id: int = int(runner_brain.call("get_current_allocated_target_id"))
	_expect(
		runner_target_id > 0 and runner_target_id != prepared_target_id,
		"Live Skirmisher chooses the less crowded target"
	)
	var allocation_debug_value: Variant = runner_brain.call(
		"get_target_allocation_debug_data"
	)
	var allocation_debug: Dictionary = (
		allocation_debug_value as Dictionary
		if allocation_debug_value is Dictionary
		else {}
	)
	_expect(
		not (allocation_debug.get("decision", {}) as Dictionary).is_empty(),
		"Live target decision remains inspectable"
	)

	var health_before: int = int(ruvia.get("current_health"))
	spark_brain.set("allocated_target", ruvia)
	spark_brain.set("player", ruvia)
	var payload := DamagePayload.new()
	payload.amount = 2
	payload.stance_damage = 0
	payload.element = "lightning"
	payload.source_name = "Allocation Test Strike"
	payload.hit_type = "melee"
	payload.tags = ["lightning", "melee", "enemy_attack"]
	spark_brain.call("apply_attack_to_player", payload)
	_expect(
		int(ruvia.get("current_health")) == health_before - 2,
		"Enemy contact damage routes into Ruvia's manifestation health"
	)

	TargetAllocator.clear_all()
	encounter.queue_free()
	await get_tree().process_frame


func _choose(
	candidates: Array[Dictionary],
	squad_id: String,
	role_id: String
) -> Dictionary:
	return TargetEvaluator.choose_best(
		candidates,
		_contexts(candidates, squad_id),
		role_id,
		{
			"preferred_distance": 4.0,
			"distance_span": 12.0,
			"overkill_penalty": 18.0,
			"attention_penalty": 1.7,
		}
	)


func _contexts(candidates: Array[Dictionary], squad_id: String) -> Dictionary:
	var contexts: Dictionary = {}
	for candidate: Dictionary in candidates:
		var target_id: int = int(candidate.get("target_id", 0))
		contexts[target_id] = TargetAllocator.get_target_context(
			squad_id,
			target_id
		)
	return contexts


func _candidate(
	target_id: int,
	target_name: String,
	current_health: int,
	distance: float
) -> Dictionary:
	return {
		"target_id": target_id,
		"target_name": target_name,
		"target_kind": "test",
		"distance": distance,
		"current_health": current_health,
		"maximum_health": maxi(current_health, 1),
		"health_fraction": 1.0,
		"current_stance": 0,
		"maximum_stance": 0,
		"stance_fraction": 1.0,
		"statuses": [],
		"action_blocked": false,
		"defeated": false,
		"is_player": false,
		"is_manifestation": false,
		"is_friendly_actor": true,
	}


func _trace_has_penalty(
	plan: Dictionary,
	target_id: int,
	needle: String
) -> bool:
	var trace_value: Variant = plan.get("trace", [])
	if not trace_value is Array:
		return false
	for row_value: Variant in trace_value as Array:
		if not row_value is Dictionary:
			continue
		var row: Dictionary = row_value as Dictionary
		if int(row.get("target_id", 0)) != target_id:
			continue
		for penalty: String in _string_array(row.get("penalties", [])):
			if penalty.to_lower().contains(needle.to_lower()):
				return true
	return false


func _brain(enemy_root: Node, member_name: String) -> Node:
	var member: Node = enemy_root.get_node_or_null(member_name) if enemy_root != null else null
	return member.get_node_or_null("EnemyBrain") if member != null else null


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
		if option.has_method("get_display_name") and str(option.call("get_display_name")) == option_name:
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
		print("MULTI_TARGET_ALLOCATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("MULTI_TARGET_ALLOCATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)
