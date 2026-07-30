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
	_test_reserved_payoff_recruits_setup()
	_test_reserved_setup_vetoes_duplicate()
	_test_reserved_payoff_protects_state()
	_test_cover_request_recruits_ranged_response()
	_test_intent_refresh_is_unique()
	Blackboard.clear_all()
	_finish()


func _test_reserved_payoff_recruits_setup() -> void:
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
	var water: TacticalActionCandidate = _water_candidate()
	var fire: TacticalActionCandidate = _fire_candidate()
	var paired_plan: Dictionary = Planner.choose_best([fire, water], snapshot)
	_expect(
		str(paired_plan.get("selected_id", "")) == "water_jet",
		"Reserved Conduct payoff recruits Wet setup"
	)
	_expect(
		_plan_has_paired_setup(paired_plan),
		"Paired setup is identified as reservation-driven"
	)


func _test_reserved_setup_vetoes_duplicate() -> void:
	Blackboard.clear_all()
	ClaimRegistry.reserve_payoff(
		"pairing_squad",
		1,
		"Payoff Actor",
		"wet_conduction",
		2
	)
	ClaimRegistry.reserve_setup(
		"pairing_squad",
		2,
		"Setup Actor",
		"wet_conduction",
		2
	)
	var context: Dictionary = Blackboard.get_coordination_context(
		"pairing_squad",
		3,
		2
	)
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot([], [])
	_merge(snapshot, context)
	var plan: Dictionary = Planner.choose_best(
		[_water_candidate(), _fire_candidate()],
		snapshot
	)
	_expect(
		_trace_candidate_invalid(plan, "water_jet"),
		"Third actor is vetoed from duplicating reserved Wet setup"
	)


func _test_reserved_payoff_protects_state() -> void:
	Blackboard.clear_all()
	ClaimRegistry.reserve_payoff(
		"pairing_squad",
		1,
		"Hammer Actor",
		"shatter",
		2
	)
	var context: Dictionary = Blackboard.get_coordination_context(
		"pairing_squad",
		2,
		2
	)
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot(
		[],
		["frozen"]
	)
	_merge(snapshot, context)
	var fire: TacticalActionCandidate = _fire_candidate()
	var neutral: TacticalActionCandidate = (
		ActionCandidate.make_test_candidate(
			"arcane_spark",
			"spell",
			["neutral", "projectile", "ranged"],
			[],
			["damage"]
		)
	)
	var plan: Dictionary = Planner.choose_best([fire, neutral], snapshot)
	_expect(
		str(plan.get("selected_id", "")) == "arcane_spark",
		"Reserved Shatter protects Frozen from a Steam conversion"
	)
	_expect(
		_trace_candidate_invalid(plan, "firebolt"),
		"State-consuming Fire action is vetoed while Frozen is reserved"
	)


func _test_cover_request_recruits_ranged_response() -> void:
	Blackboard.clear_all()
	Blackboard.broadcast_intent(
		"pairing_squad",
		1,
		"Retreating Actor",
		"cover_request",
		["cover_requested"],
		2
	)
	var context: Dictionary = Blackboard.get_coordination_context(
		"pairing_squad",
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
		"Cover request recruits ranged pressure"
	)
	_expect(
		_plan_has_type(plan, "cover_response"),
		"Cover response remains visible in the tactical trace"
	)


func _test_intent_refresh_is_unique() -> void:
	Blackboard.clear_all()
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


func _water_candidate() -> TacticalActionCandidate:
	return ActionCandidate.make_test_candidate(
		"water_jet",
		"spell",
		["water", "projectile"],
		["wet"],
		["control", "setup"]
	)


func _fire_candidate() -> TacticalActionCandidate:
	return ActionCandidate.make_test_candidate(
		"firebolt",
		"spell",
		["fire", "projectile"],
		["burning"],
		["damage", "setup"]
	)


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
