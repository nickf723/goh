extends Node

const Evaluator = preload("res://scripts/mobs/mob_move_evaluator.gd")
const PersonalityAdapter = preload("res://scripts/mobs/mob_personality_adapter.gd")
const DriveState = preload("res://scripts/mobs/mob_drive_state.gd")
const IntentionResolver = preload("res://scripts/mobs/mob_intention_resolver.gd")
const DecisionContext = preload("res://scripts/mobs/mob_decision_context.gd")
const BrainScript = preload("res://scripts/mobs/mob_brain_component.gd")

var failures: Array[String] = []


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_test_context_score_modifiers()
	_test_hunger_changes_habitat_choice()
	_test_fear_overrides_bold_defense()
	_test_social_need_promotes_pack_behavior()
	_test_intention_commitment()
	await _test_brain_integration()
	_finish()


func _test_context_score_modifiers() -> void:
	var context: MobDecisionContext = DecisionContext.from_dictionary({
		"move_score_modifiers": {"graze": 0.4},
		"tag_score_modifiers": {"forage": 0.6},
		"policy_tag_score_modifiers": {"pack_support": 0.8},
	})
	_expect(is_equal_approx(context.get_move_score_modifier("graze"), 0.4), "decision context stores exact move modifiers")
	_expect(is_equal_approx(context.get_tag_score_modifier("forage"), 0.6), "decision context stores move-tag modifiers")
	_expect(is_equal_approx(context.get_policy_tag_score_modifier("pack_support"), 0.8), "decision context stores policy-tag modifiers")
	var round_trip: Dictionary = context.to_dictionary()
	_expect(round_trip.has("tag_score_modifiers"), "score modifiers survive context serialization")


func _test_hunger_changes_habitat_choice() -> void:
	var calm_context: Dictionary = {
		"target_distance": 1.0,
		"ally_count": 4,
		"context_tags": ["safe", "water_near", "hot"],
	}
	var baseline: Dictionary = Evaluator.choose_move("capybara", calm_context)
	_expect(str(baseline.get("move_id", "")) == "wade", "hot calm capybara normally prefers Wade")
	var traits: Dictionary = PersonalityAdapter.apply_profile_to_species("capybara", "balanced")
	var drives: MobDriveState = DriveState.create_for_species("capybara", traits)
	drives.set_drive("hunger", 1.0)
	drives.set_drive("curiosity", 0.0)
	drives.set_drive("fatigue", 0.0)
	var hungry_context: Dictionary = drives.build_context(calm_context)
	var hungry_choice: Dictionary = Evaluator.choose_move("capybara", hungry_context, traits)
	_expect(str(hungry_choice.get("move_id", "")) == "graze", "hunger can outweigh an attractive habitat action")
	_expect(_score_reason_has(hungry_choice, "tag forage"), "drive bonus remains visible in score reasons")


func _test_fear_overrides_bold_defense() -> void:
	var traits: Dictionary = PersonalityAdapter.apply_profile_to_species("sheep", "bold")
	var context: Dictionary = {
		"target_distance": 1.0,
		"ally_count": 0,
		"enemy_count": 1,
		"context_tags": ["threatened", "cornered", "target_close"],
		"allowed_move_ids": ["flee", "headbutt"],
	}
	var baseline: Dictionary = Evaluator.choose_move("sheep", context, traits)
	_expect(str(baseline.get("move_id", "")) == "headbutt", "bold cornered sheep initially stands its ground")
	var drives: MobDriveState = DriveState.create_for_species("sheep", traits)
	drives.set_drive("fear", 1.0)
	drives.set_drive("fatigue", 0.0)
	var frightened_choice: Dictionary = Evaluator.choose_move(
		"sheep",
		drives.build_context(context),
		traits
	)
	_expect(str(frightened_choice.get("move_id", "")) == "flee", "persistent fear can override a bold defensive impulse")


func _test_social_need_promotes_pack_behavior() -> void:
	var traits: Dictionary = PersonalityAdapter.apply_profile_to_species("wolf", "balanced")
	var context: Dictionary = {
		"target_distance": 1.2,
		"ally_count": 2,
		"enemy_count": 1,
		"context_tags": ["hunting"],
	}
	var baseline: Dictionary = Evaluator.choose_move("wolf", context, traits)
	_expect(str(baseline.get("move_id", "")) == "bite", "wolf normally attacks at close hunting range")
	var drives: MobDriveState = DriveState.create_for_species("wolf", traits)
	drives.set_drive("social_need", 1.0)
	drives.set_drive("fear", 0.0)
	drives.set_drive("fatigue", 0.0)
	var social_choice: Dictionary = Evaluator.choose_move(
		"wolf",
		drives.build_context(context),
		traits
	)
	_expect(str(social_choice.get("move_id", "")) == "howl", "social need can promote a pack-support move")


func _test_intention_commitment() -> void:
	var close_scores: Array[Dictionary] = [
		{
			"move_id": "wade",
			"eligible": true,
			"score": 2.0,
			"move_tags": ["movement", "habitat"],
			"policy_tags": [],
			"action_kind": "movement",
		},
		{
			"move_id": "graze",
			"eligible": true,
			"score": 1.8,
			"move_tags": ["forage", "calm"],
			"policy_tags": [],
			"action_kind": "utility",
		},
	]
	var retained: Dictionary = IntentionResolver.choose_with_commitment(
		close_scores,
		"forage",
		0.25
	)
	_expect(str(retained.get("move_id", "")) == "graze", "small score changes do not break a committed intention")
	_expect(bool(retained.get("intention_retained", false)), "retained decisions expose commitment metadata")
	var large_gap: Array[Dictionary] = close_scores.duplicate(true)
	large_gap[0]["score"] = 2.2
	var switched: Dictionary = IntentionResolver.choose_with_commitment(
		large_gap,
		"forage",
		0.25
	)
	_expect(str(switched.get("move_id", "")) == "wade", "a clearly better option can break intention commitment")


func _test_brain_integration() -> void:
	var brain := BrainScript.new() as MobBrainComponent
	add_child(brain)
	brain.configure("capybara", "balanced")
	brain.set_drive("hunger", 1.0)
	brain.set_drive("curiosity", 0.0)
	brain.set_drive("fatigue", 0.0)
	brain.set_context({
		"target_distance": 1.0,
		"ally_count": 3,
		"context_tags": ["safe", "water_near", "hot"],
	})
	var decision: Dictionary = brain.request_decision()
	_expect(str(decision.get("move_id", "")) == "graze", "brain injects its persistent drives into evaluation")
	_expect(str(decision.get("intention_id", "")) == "forage", "brain records the selected behavioral intention")
	var hunger_before: float = brain.get_drive("hunger")
	var committed: Dictionary = brain.commit_move("graze", 0.0)
	_expect(bool(committed.get("ok", false)), "drive-aware brain still commits moves normally")
	_expect(brain.get_drive("hunger") < hunger_before, "committing a forage move satisfies hunger")
	var debug_data: Dictionary = brain.get_debug_data()
	_expect(debug_data.has("drives"), "brain debug data exposes drive state")
	_expect(str(debug_data.get("current_intention_id", "")) == "forage", "brain debug data exposes intention state")
	brain.queue_free()
	await get_tree().process_frame


func _score_reason_has(row: Dictionary, fragment: String) -> bool:
	var reasons: Variant = row.get("score_reasons", [])
	if reasons is Array:
		for raw: Variant in reasons as Array:
			if str(raw).contains(fragment):
				return true
	return false


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("MOB_DRIVES_AND_INTENTIONS_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("MOB_DRIVES_AND_INTENTIONS_SMOKE_TEST: " + failure)
	get_tree().quit(1)
