extends Node

const WorldSnapshot = preload(
	"res://scripts/ai/tactical_world_snapshot.gd"
)
const ActionCandidate = preload(
	"res://scripts/ai/tactical_action_candidate.gd"
)
const Planner = preload(
	"res://scripts/ai/reaction_tactical_planner.gd"
)
const SpellLibrary = preload(
	"res://scripts/ai/tactical_spell_library.gd"
)
const ManifestedAvatarScene: PackedScene = preload(
	"res://scenes/actors/avatars/manifested_avatar_actor.tscn"
)

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_test_wet_prefers_lightning()
	_test_frozen_prefers_shatter()
	_test_burning_ally_prefers_quench()
	_test_low_health_prefers_defense()
	_test_hazard_route_prefers_ranged()
	_test_companion_setup_coordination()
	_test_spell_library_cache()
	await _test_runtime_adapters()
	_finish()


func _test_wet_prefers_lightning() -> void:
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot([], ["wet"])
	var lightning: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"lightning_spark", "attack", ["lightning", "projectile", "ranged"], [], ["damage"]
	)
	var fire: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"firebolt", "attack", ["fire", "projectile", "ranged"], [], ["damage"]
	)
	var plan: Dictionary = Planner.choose_best([fire, lightning], snapshot)
	_expect(
		str(plan.get("selected_id", "")) == "lightning_spark",
		"Wet target selects Lightning payoff"
	)
	_expect(
		_plan_has_reaction(plan, "wet_conduction"),
		"Wet target decision names Conduct"
	)


func _test_frozen_prefers_shatter() -> void:
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot([], ["frozen"])
	var force: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"heavy_impact", "attack", ["force", "heavy_impact", "melee"], [], ["damage", "control"]
	)
	var neutral: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"quick_slash", "attack", ["physical", "melee"], [], ["damage"]
	)
	var plan: Dictionary = Planner.choose_best([neutral, force], snapshot)
	_expect(
		str(plan.get("selected_id", "")) == "heavy_impact",
		"Frozen target selects Force payoff"
	)
	_expect(_plan_has_reaction(plan, "shatter"), "Frozen target decision names Shatter")


func _test_burning_ally_prefers_quench() -> void:
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot(
		[],
		["burning"],
		{"relation": "ally"}
	)
	var water: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"water_aid", "support", ["water", "support"], ["wet"], ["control", "setup", "utility"]
	)
	var strike: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"friendly_strike", "attack", ["physical", "melee"], [], ["damage"]
	)
	var plan: Dictionary = Planner.choose_best([strike, water], snapshot)
	_expect(
		str(plan.get("selected_id", "")) == "water_aid",
		"Burning ally selects Water support"
	)
	_expect(_plan_has_reaction(plan, "quench"), "Burning ally decision names Quench")


func _test_low_health_prefers_defense() -> void:
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot(
		[],
		[],
		{"actor_health_fraction": 0.2}
	)
	var defense: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"guard", "defense", ["guard", "defense"], [], ["defense"]
	)
	var attack: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"slash", "attack", ["physical", "melee"], [], ["damage"]
	)
	var plan: Dictionary = Planner.choose_best([attack, defense], snapshot)
	_expect(
		str(plan.get("selected_id", "")) == "guard",
		"Low-health actor selects defense"
	)


func _test_hazard_route_prefers_ranged() -> void:
	var hazard: Dictionary = {
		"name": "PoisonRoute",
		"position": Vector3(0.0, 0.0, -2.0),
		"radius": 1.4,
		"severity": 1.0,
		"tags": ["poison", "gas", "hazard"],
	}
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot(
		[],
		[],
		{"nearby_hazards": [hazard]}
	)
	var melee: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"charge", "attack", ["physical", "melee"], [], ["damage"], "toward_target"
	)
	melee.maximum_distance = 1.8
	var ranged: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"arrow", "attack", ["physical", "projectile", "ranged"], [], ["damage"]
	)
	ranged.maximum_distance = 12.0
	var plan: Dictionary = Planner.choose_best([melee, ranged], snapshot)
	_expect(
		str(plan.get("selected_id", "")) == "arrow",
		"Dangerous route vetoes melee approach"
	)
	_expect(_trace_candidate_invalid(plan, "charge"), "Melee veto remains inspectable")


func _test_companion_setup_coordination() -> void:
	var snapshot: Dictionary = WorldSnapshot.make_test_snapshot(
		[],
		[],
		{"preferred_payoff_tags": ["lightning", "projectile"]}
	)
	var water: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"water_jet", "spell", ["water", "projectile"], ["wet"], ["control", "setup"]
	)
	var fire: TacticalActionCandidate = ActionCandidate.make_test_candidate(
		"firebolt", "spell", ["fire", "projectile"], ["burning"], ["damage", "setup"]
	)
	var plan: Dictionary = Planner.choose_best([fire, water], snapshot)
	_expect(
		str(plan.get("selected_id", "")) == "water_jet",
		"Ally Lightning plan gives Water setup priority"
	)
	_expect(
		_plan_has_opportunity_type(plan, "reaction_setup"),
		"Companion setup decision records planned reaction"
	)


func _test_spell_library_cache() -> void:
	var before: Dictionary = SpellLibrary.get_debug_data()
	var firebolt: Dictionary = SpellLibrary.get_record("firebolt")
	var after: Dictionary = SpellLibrary.get_debug_data()
	_expect(not firebolt.is_empty(), "Tactical spell library exposes Firebolt")
	_expect(
		int(after.get("spell_count", 0)) >= 20,
		"Tactical spell library caches authored spells"
	)
	_expect(
		int(after.get("build_count", 0)) == int(before.get("build_count", 0)),
		"Repeated tactical spell lookup reuses the manifest cache"
	)


func _test_runtime_adapters() -> void:
	var scene: Node = ManifestedAvatarScene.instantiate()
	add_child(scene)
	await get_tree().process_frame
	var driver: Node = scene.get_node_or_null("CompanionControlDriver")
	_expect(driver != null, "Manifestation scene keeps a companion driver")
	if driver != null:
		var script: Script = driver.get_script() as Script
		_expect(
			script != null
			and script.resource_path
			== "res://scripts/avatars/reaction_aware_ruvia_control_driver.gd",
			"Ruvia installs the reaction-aware companion adapter"
		)
	scene.queue_free()
	await get_tree().process_frame
	var threat_script: Script = load(
		"res://scripts/enemies/enemy_threat_aware_action_brain.gd"
	) as Script
	var threat_brain: Node = threat_script.new() as Node if threat_script != null else null
	_expect(threat_brain != null, "Threat-aware enemy brain still instantiates")
	if threat_brain != null:
		_expect(
			threat_brain.has_method("get_tactical_decision_trace"),
			"Threat-aware enemies inherit reaction tactical scoring"
		)
		threat_brain.free()


func _plan_has_reaction(plan: Dictionary, reaction_id: String) -> bool:
	for opportunity: Dictionary in _dictionary_array(plan.get("opportunities", [])):
		if str(opportunity.get("reaction_id", "")) == reaction_id:
			return true
	return false


func _plan_has_opportunity_type(plan: Dictionary, type_id: String) -> bool:
	for opportunity: Dictionary in _dictionary_array(plan.get("opportunities", [])):
		if str(opportunity.get("type", "")) == type_id:
			return true
	return false


func _trace_candidate_invalid(plan: Dictionary, action_id: String) -> bool:
	for row: Dictionary in _dictionary_array(plan.get("trace", [])):
		if str(row.get("action_id", "")) == action_id:
			return not bool(row.get("valid", true))
	return false


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append(raw as Dictionary)
	return result


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("REACTION_TACTICAL_AI_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("REACTION_TACTICAL_AI_SMOKE_TEST: " + failure)
	get_tree().quit(1)
