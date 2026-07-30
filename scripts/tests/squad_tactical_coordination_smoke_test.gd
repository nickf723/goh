extends Node


const Blackboard = preload(
	"res://scripts/ai/tactical_blackboard.gd"
)
const ClaimRegistry = preload(
	"res://scripts/ai/reaction_claim_registry.gd"
)
const LaneRegistry = preload(
	"res://scripts/ai/engagement_lane_registry.gd"
)
const WorldSnapshot = preload(
	"res://scripts/ai/tactical_world_snapshot.gd"
)
const ActionCandidate = preload(
	"res://scripts/ai/tactical_action_candidate.gd"
)
const Planner = preload(
	"res://scripts/ai/reaction_tactical_planner.gd"
)
const ManifestedAvatarScene: PackedScene = preload(
	"res://scenes/actors/avatars/manifested_avatar_actor.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_test_exclusive_payoff_claims()
	_test_setup_and_payoff_form_plan()
	_test_interruption_releases_claims()
	_test_expiration_prunes_claims()
	_test_squad_isolation()
	_test_emergency_defense_overrides_plan()
	_test_engagement_lane_changes_choice()
	_test_intent_broadcast_guides_setup()
	await _test_runtime_adapters()
	Blackboard.clear_all()
	_finish()


func _test_exclusive_payoff_claims() -> void:
	Blackboard.clear_all()
	var first: Dictionary = ClaimRegistry.reserve_payoff(
		"alpha",
		1,
		"Goblin A",
		"wet_conduction",
		20
	)
	var duplicate: Dictionary = ClaimRegistry.reserve_payoff(
		"alpha",
		2,
		"Goblin B",
		"wet_conduction",
		20
	)
	_expect(bool(first.get("granted", false)), "First payoff claim is granted")
	_expect(
		not bool(duplicate.get("granted", true)),
		"Second actor cannot reserve the same payoff"
	)


func _test_setup_and_payoff_form_plan() -> void:
	Blackboard.clear_all()
	var payoff: Dictionary = ClaimRegistry.reserve_payoff(
		"alpha",
		1,
		"Goblin A",
		"wet_conduction",
		20
	)
	var setup: Dictionary = ClaimRegistry.reserve_setup(
		"alpha",
		2,
		"Goblin B",
		"wet_conduction",
		20
	)
	_expect(bool(payoff.get("granted", false)), "Payoff phase reserves")
	_expect(bool(setup.get("granted", false)), "Setup phase can coexist with payoff")
	var plans: Array[Dictionary] = Blackboard.build_squad_plans("alpha", 20)
	_expect(plans.size() == 1, "Compatible phases form one squad plan")
	if not plans.is_empty():
		_expect(bool(plans[0].get("complete", false)), "Squad plan reports setup and payoff")


func _test_interruption_releases_claims() -> void:
	Blackboard.clear_all()
	ClaimRegistry.reserve_payoff(
		"alpha",
		1,
		"Goblin A",
		"shatter",
		30
	)
	var released: int = Blackboard.release_owner(
		1,
		"interrupted",
		"alpha"
	)
	var replacement: Dictionary = ClaimRegistry.reserve_payoff(
		"alpha",
		2,
		"Goblin B",
		"shatter",
		30
	)
	_expect(released == 1, "Interruption releases the owner's reservation")
	_expect(
		bool(replacement.get("granted", false)),
		"Another actor may claim the released payoff"
	)


func _test_expiration_prunes_claims() -> void:
	Blackboard.clear_all()
	var result: Dictionary = ClaimRegistry.reserve_setup(
		"alpha",
		1,
		"Goblin A",
		"wet_freeze",
		40,
		0.1
	)
	var reservation: Dictionary = _dictionary(result.get("reservation", {}))
	var expires_at: float = float(reservation.get("expires_at", 0.0))
	var pruned: int = Blackboard.prune_expired(expires_at + 0.5)
	var context: Dictionary = Blackboard.get_coordination_context(
		"alpha",
		2,
		40
	)
	_expect(pruned >= 1, "Expired claims are pruned")
	_expect(
		_string_array(context.get("claimed_setup_reactions", [])).is_empty(),
		"Expired setup disappears from squad context"
	)


func _test_squad_isolation() -> void:
	Blackboard.clear_all()
	var alpha: Dictionary = ClaimRegistry.reserve_payoff(
		"alpha",
		1,
		"Goblin A",
		"steam_burst",
		50
	)
	var beta: Dictionary = ClaimRegistry.reserve_payoff(
		"beta",
		2,
		"Gremlin B",
		"steam_burst",
		50
	)
	_expect(bool(alpha.get("granted", false)), "Alpha squad claim reserves")
	_expect(
		bool(beta.get("granted", false)),
		"Different squads do not share exclusive knowledge"
	)


func _test_emergency_defense_overrides_plan() -> void:
	Blackboard.clear_all()
	ClaimRegistry.reserve_payoff(
		"alpha",
		1,
		"Goblin A",
		"wet_conduction",
		2
	)
	var context: Dictionary = Blackboard.get_coordination_context(
		"alpha",
		2,
		2
	)
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot(
		[],
		["wet"],
		{"actor_health_fraction": 0.12}
	)
	_merge(snapshot, context)
	var lightning: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"lightning_spark",
		"attack",
		["lightning", "projectile", "ranged"],
		[],
		["damage"]
	)
	var guard: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"guard",
		"defense",
		["guard", "defense"],
		[],
		["defense"]
	)
	var plan: Dictionary = Planner.choose_best([lightning, guard], snapshot)
	_expect(
		str(plan.get("selected_id", "")) == "guard",
		"Critical defense overrides a claimed reaction plan"
	)
	_expect(
		_plan_has_type(plan, "emergency_override"),
		"Emergency override remains visible in the decision trace"
	)


func _test_engagement_lane_changes_choice() -> void:
	Blackboard.clear_all()
	var lane: Dictionary = LaneRegistry.reserve_lane(
		"alpha",
		1,
		"Goblin A",
		"melee",
		2
	)
	_expect(bool(lane.get("granted", false)), "First melee lane reserves")
	var context: Dictionary = Blackboard.get_coordination_context(
		"alpha",
		2,
		2
	)
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot([], [])
	_merge(snapshot, context)
	var melee: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"club_charge",
		"attack",
		["physical", "melee"],
		[],
		["damage"],
		"toward_target"
	)
	melee.maximum_distance = 1.8
	var ranged: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"stone_throw",
		"attack",
		["physical", "projectile", "ranged"],
		[],
		["damage"]
	)
	var plan: Dictionary = Planner.choose_best([melee, ranged], snapshot)
	_expect(
		str(plan.get("selected_id", "")) == "stone_throw",
		"Occupied melee lane redirects the next squad member"
	)
	_expect(
		_trace_candidate_invalid(plan, "club_charge"),
		"Lane rejection is inspectable"
	)


func _test_intent_broadcast_guides_setup() -> void:
	Blackboard.clear_all()
	Blackboard.broadcast_intent(
		"grace_party",
		1,
		"Grace",
		"selected_spell",
		["lightning", "projectile"],
		2
	)
	var context: Dictionary = Blackboard.get_coordination_context(
		"grace_party",
		2,
		2
	)
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot([], [])
	_merge(snapshot, context)
	var water: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"water_jet",
		"spell",
		["water", "projectile"],
		["wet"],
		["control", "setup"]
	)
	var fire: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"firebolt",
		"spell",
		["fire", "projectile"],
		["burning"],
		["damage", "setup"]
	)
	var plan: Dictionary = Planner.choose_best([fire, water], snapshot)
	_expect(
		str(plan.get("selected_id", "")) == "water_jet",
		"Grace's announced Lightning intent raises Wet setup"
	)
	_expect(
		_plan_has_type(plan, "reaction_setup"),
		"Intent-guided setup records its reaction plan"
	)


func _test_runtime_adapters() -> void:
	var threat_script: Script = load(
		"res://scripts/enemies/enemy_threat_aware_action_brain.gd"
	) as Script
	var threat_brain: Node = (
		threat_script.new() as Node if threat_script != null else null
	)
	_expect(threat_brain != null, "Threat-aware squad brain instantiates")
	if threat_brain != null:
		_expect(
			threat_brain.has_method("get_coordination_debug_data"),
			"Threat-aware enemies expose squad coordination diagnostics"
		)
		threat_brain.free()
	var manifestation: Node = ManifestedAvatarScene.instantiate()
	add_child(manifestation)
	await get_tree().process_frame
	var driver: Node = manifestation.get_node_or_null("CompanionControlDriver")
	_expect(driver != null, "Ruvia companion driver remains installed")
	if driver != null:
		_expect(
			driver.has_method("get_tactical_squad_id"),
			"Ruvia exposes party coordination identity"
		)
	manifestation.queue_free()
	await get_tree().process_frame


func _merge(target: Dictionary, source: Dictionary) -> void:
	for key: Variant in source.keys():
		target[key] = source[key]


func _plan_has_type(plan: Dictionary, type_id: String) -> bool:
	for opportunity: Dictionary in _dictionary_array(
		plan.get("opportunities", [])
	):
		if str(opportunity.get("type", "")) == type_id:
			return true
	return false


func _trace_candidate_invalid(plan: Dictionary, action_id: String) -> bool:
	for row: Dictionary in _dictionary_array(plan.get("trace", [])):
		if str(row.get("action_id", "")) == action_id:
			return not bool(row.get("valid", true))
	return false


func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append((raw as Dictionary).duplicate(true))
	return result


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
		print("SQUAD_TACTICAL_COORDINATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SQUAD_TACTICAL_COORDINATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)
