extends Node


const Blackboard = preload(
	"res://scripts/ai/tactical_blackboard.gd"
)
const ClaimRegistry = preload(
	"res://scripts/ai/reaction_claim_registry.gd"
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

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	Blackboard.clear_all()
	ClaimRegistry.reserve_payoff(
		"pairing_squad",
		1,
		"Payoff Actor",
		"wet_conduction",
		2
	)
	var context: Dictionary = Blackboard.get_coordination_context(
		"pairing_squad",
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
	var paired_plan: Dictionary = Planner.choose_best([fire, water], snapshot)
	_expect(
		str(paired_plan.get("selected_id", "")) == "water_jet",
		"Reserved Conduct payoff recruits Wet setup"
	)
	_expect(
		_plan_has_paired_setup(paired_plan),
		"Paired setup is identified as reservation-driven"
	)

	ClaimRegistry.reserve_setup(
		"pairing_squad",
		2,
		"Setup Actor",
		"wet_conduction",
		2
	)
	var third_context: Dictionary = Blackboard.get_coordination_context(
		"pairing_squad",
		3,
		2
	)
	var third_snapshot: Dictionary = WorldSnapshot.make_test_snapshot([], [])
	_merge(third_snapshot, third_context)
	var third_plan: Dictionary = Planner.choose_best([water, fire], third_snapshot)
	_expect(
		_trace_candidate_invalid(third_plan, "water_jet"),
		"Third actor is vetoed from duplicating reserved Wet setup"
	)

	Blackboard.broadcast_intent(
		"pairing_squad",
		9,
		"Caller",
		"selected_spell",
		["lightning"],
		2
	)
	var refreshed: Dictionary = Blackboard.broadcast_intent(
		"pairing_squad",
		9,
		"Caller",
		"selected_spell",
		["lightning"],
		2
	)
	_expect(
		not bool(refreshed.get("created", true)),
		"Repeated owner intent refreshes one broadcast instead of duplicating it"
	)
	_expect(
		int(Blackboard.get_debug_data().get("broadcast_count", 0)) == 1,
		"Intent refresh leaves one active broadcast"
	)
	Blackboard.clear_all()
	_finish()


func _plan_has_paired_setup(plan: Dictionary) -> bool:
	for opportunity: Dictionary in _dictionary_array(
		plan.get("opportunities", [])
	):
		if (
			str(opportunity.get("type", "")) == "reaction_setup"
			and bool(opportunity.get("paired_reservation", false))
		):
			return true
	return false


func _trace_candidate_invalid(plan: Dictionary, action_id: String) -> bool:
	for row: Dictionary in _dictionary_array(plan.get("trace", [])):
		if str(row.get("action_id", "")) == action_id:
			return not bool(row.get("valid", true))
	return false


func _merge(target: Dictionary, source: Dictionary) -> void:
	for key: Variant in source.keys():
		target[key] = source[key]


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append((raw as Dictionary).duplicate(true))
	return result


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("SQUAD_TACTICAL_PAIRING_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("SQUAD_TACTICAL_PAIRING_SMOKE_TEST: " + failure)
	get_tree().quit(1)
