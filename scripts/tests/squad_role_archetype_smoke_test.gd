extends Node


const RoleCatalog = preload("res://scripts/ai/squad_role_catalog.gd")
const RoleAllocator = preload("res://scripts/ai/squad_role_allocator.gd")
const WorldSnapshot = preload("res://scripts/ai/tactical_world_snapshot.gd")
const ActionCandidate = preload("res://scripts/ai/tactical_action_candidate.gd")
const Planner = preload("res://scripts/ai/reaction_tactical_planner.gd")
const GremlinBiteOption: EnemyActionOption = preload(
	"res://data/enemy_action_options/gremlin_bite_option.tres"
)
const GremlinPounceOption: EnemyActionOption = preload(
	"res://data/enemy_action_options/gremlin_pounce_option.tres"
)
const GremlinBackstepOption: EnemyActionOption = preload(
	"res://data/enemy_action_options/gremlin_backstep_option.tres"
)
const ManifestedAvatarScene: PackedScene = preload(
	"res://scenes/actors/avatars/manifested_avatar_actor.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_test_catalog_contract()
	_test_complementary_assignment()
	_test_role_driven_choices()
	await _test_runtime_adapters()
	RoleAllocator.clear_all()
	_finish()


func _test_catalog_contract() -> void:
	var errors: Array[String] = RoleCatalog.validate_catalog()
	_expect(errors.is_empty(), "Squad role catalog validates")
	_expect(
		RoleCatalog.get_profiles(true).size() == 6,
		"Catalog exposes five specialties and one fallback"
	)
	_expect(
		RoleCatalog.normalize_role_id("detonator") == "payoff_specialist",
		"Payoff aliases normalize"
	)
	_expect(
		RoleCatalog.get_profile("primer").is_assignment_eligible(
			[_primer_candidate()]
		),
		"Primer accepts a setup-capable action library"
	)
	_expect(
		not RoleCatalog.get_profile("primer").is_assignment_eligible(
			[_neutral_damage_candidate()]
		),
		"Primer rejects a damage-only action library"
	)


func _test_complementary_assignment() -> void:
	RoleAllocator.clear_all()
	var squad_id: String = "archetype_smoke"
	var primer: Dictionary = RoleAllocator.assign_role(
		squad_id,
		1,
		"Primer Actor",
		"auto",
		[_primer_candidate()]
	)
	var payoff: Dictionary = RoleAllocator.assign_role(
		squad_id,
		2,
		"Payoff Actor",
		"auto",
		[_payoff_candidate()]
	)
	var protector: Dictionary = RoleAllocator.assign_role(
		squad_id,
		3,
		"Protector Actor",
		"auto",
		[_protector_candidate()]
	)
	var disruptor: Dictionary = RoleAllocator.assign_role(
		squad_id,
		4,
		"Disruptor Actor",
		"auto",
		[_disruptor_candidate()]
	)
	var skirmisher: Dictionary = RoleAllocator.assign_role(
		squad_id,
		5,
		"Skirmisher Actor",
		"auto",
		[_skirmisher_candidate()]
	)
	_expect(str(primer.get("role_id", "")) == "primer", "Setup library becomes Primer")
	_expect(
		str(payoff.get("role_id", "")) == "payoff_specialist",
		"Detonator library becomes Payoff Specialist"
	)
	_expect(
		str(protector.get("role_id", "")) == "protector",
		"Defense library becomes Protector"
	)
	_expect(
		str(disruptor.get("role_id", "")) == "disruptor",
		"Control library becomes Disruptor"
	)
	_expect(
		str(skirmisher.get("role_id", "")) == "skirmisher",
		"Mobile ranged library becomes Skirmisher"
	)
	var duplicate_setup: Dictionary = RoleAllocator.assign_role(
		squad_id,
		6,
		"Second Setup Actor",
		"auto",
		[_primer_candidate()]
	)
	_expect(
		str(duplicate_setup.get("role_id", "")) != "primer",
		"Primer cap prevents duplicate automatic setup roles"
	)
	var explicit: Dictionary = RoleAllocator.assign_role(
		squad_id,
		7,
		"Authored Guardian",
		"protector",
		[_neutral_damage_candidate()]
	)
	_expect(
		str(explicit.get("role_id", "")) == "protector"
		and bool(explicit.get("explicit", false)),
		"Explicit encounter role overrides automatic eligibility"
	)
	var context: Dictionary = RoleAllocator.get_squad_context(squad_id)
	var counts: Dictionary = _dictionary(context.get("squad_role_counts", {}))
	_expect(int(counts.get("primer", 0)) == 1, "Squad context counts Primer once")
	_expect(
		RoleAllocator.release_owner(7, squad_id) == 1,
		"Role assignment releases with its owner"
	)


func _test_role_driven_choices() -> void:
	var primer_plan: Dictionary = _choose(
		"primer",
		[],
		[_neutral_damage_candidate(), _primer_candidate()]
	)
	_expect(
		str(primer_plan.get("selected_id", "")) == "water_setup",
		"Primer chooses setup over plain damage"
	)
	var payoff_plan: Dictionary = _choose(
		"payoff_specialist",
		["wet"],
		[_neutral_damage_candidate(), _payoff_candidate()]
	)
	_expect(
		str(payoff_plan.get("selected_id", "")) == "lightning_payoff",
		"Payoff Specialist converts Wet with Lightning"
	)
	var protector_plan: Dictionary = _choose(
		"protector",
		[],
		[_neutral_damage_candidate(), _protector_candidate()]
	)
	_expect(
		str(protector_plan.get("selected_id", "")) == "guard_ally",
		"Protector prefers defense without requiring critical health"
	)
	var disruptor_plan: Dictionary = _choose(
		"disruptor",
		[],
		[_neutral_damage_candidate(), _disruptor_candidate()]
	)
	_expect(
		str(disruptor_plan.get("selected_id", "")) == "stun_wave",
		"Disruptor prefers control pressure"
	)
	var skirmisher_plan: Dictionary = _choose(
		"skirmisher",
		[],
		[_melee_candidate(), _skirmisher_candidate()]
	)
	_expect(
		str(skirmisher_plan.get("selected_id", "")) == "ranged_retreat",
		"Skirmisher prefers mobile ranged pressure"
	)
	_expect(
		_plan_has_opportunity(skirmisher_plan, "squad_role_alignment"),
		"Role contribution remains visible in the plan trace"
	)


func _test_runtime_adapters() -> void:
	RoleAllocator.clear_all()
	var threat_script: Script = load(
		"res://scripts/enemies/enemy_threat_aware_action_brain.gd"
	) as Script
	var threat_brain: Node = (
		threat_script.new() as Node if threat_script != null else null
	)
	_expect(threat_brain != null, "Threat-aware enemy brain instantiates")
	if threat_brain != null:
		threat_brain.set("tactical_squad_id", "runtime_role_smoke")
		threat_brain.set(
			"action_options",
			[GremlinBiteOption, GremlinPounceOption, GremlinBackstepOption]
		)
		var assignment_value: Variant = threat_brain.call(
			"refresh_tactical_squad_role"
		)
		var assignment: Dictionary = _dictionary(assignment_value)
		_expect(
			RoleCatalog.has_role(str(assignment.get("role_id", ""))),
			"Enemy brain resolves an authored squad role"
		)
		_expect(
			threat_brain.has_method("get_tactical_squad_role_assignment"),
			"Enemy brain exposes role diagnostics"
		)
		RoleAllocator.release_owner(
			threat_brain.get_instance_id(),
			"runtime_role_smoke"
		)
		threat_brain.free()

	var manifestation: Node = ManifestedAvatarScene.instantiate()
	add_child(manifestation)
	await get_tree().process_frame
	var driver: Node = manifestation.get_node_or_null("CompanionControlDriver")
	_expect(driver != null, "Ruvia companion driver remains installed")
	if driver != null:
		_expect(
			driver.has_method("get_tactical_squad_role_id"),
			"Ruvia exposes her squad role"
		)
		_expect(
			str(driver.call("get_tactical_squad_role_id"))
			== "payoff_specialist",
			"Ruvia is authored as the party Payoff Specialist"
		)
	manifestation.queue_free()
	await get_tree().process_frame


func _choose(
	role_id: String,
	target_statuses: Array[String],
	candidates: Array[TacticalActionCandidate]
) -> Dictionary:
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot(
		[],
		target_statuses
	)
	snapshot["squad_role_id"] = role_id
	return Planner.choose_best(candidates, snapshot)


func _primer_candidate() -> TacticalActionCandidate:
	return ActionCandidate.make_test_candidate(
		"water_setup",
		"spell",
		["water"],
		["wet"],
		["setup", "control"]
	)


func _payoff_candidate() -> TacticalActionCandidate:
	return ActionCandidate.make_test_candidate(
		"lightning_payoff",
		"attack",
		["lightning"],
		[],
		["damage", "payoff"]
	)


func _protector_candidate() -> TacticalActionCandidate:
	return ActionCandidate.make_test_candidate(
		"guard_ally",
		"defense",
		["guard", "shield"],
		[],
		["defense"]
	)


func _disruptor_candidate() -> TacticalActionCandidate:
	return ActionCandidate.make_test_candidate(
		"stun_wave",
		"attack",
		["stun", "force"],
		[],
		["control"]
	)


func _skirmisher_candidate() -> TacticalActionCandidate:
	return ActionCandidate.make_test_candidate(
		"ranged_retreat",
		"attack",
		["ranged", "projectile", "retreat"],
		[],
		["movement", "damage"],
		"away_from_target"
	)


func _neutral_damage_candidate() -> TacticalActionCandidate:
	return ActionCandidate.make_test_candidate(
		"neutral_strike",
		"attack",
		["neutral"],
		[],
		["damage"]
	)


func _melee_candidate() -> TacticalActionCandidate:
	return ActionCandidate.make_test_candidate(
		"melee_rush",
		"attack",
		["melee"],
		[],
		["damage"],
		"toward_target"
	)


func _plan_has_opportunity(plan: Dictionary, type_id: String) -> bool:
	var opportunities: Variant = plan.get("opportunities", [])
	if opportunities is Array:
		for raw: Variant in opportunities as Array:
			if raw is Dictionary and str((raw as Dictionary).get("type", "")) == type_id:
				return true
	return false


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("SQUAD_ROLE_ARCHETYPE_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SQUAD_ROLE_ARCHETYPE_SMOKE_TEST: " + failure)
	get_tree().quit(1)
