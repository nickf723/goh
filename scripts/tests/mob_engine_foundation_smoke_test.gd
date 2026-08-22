extends Node

const MoveCatalog = preload("res://scripts/mobs/mob_move_catalog.gd")
const SpeciesCatalog = preload("res://scripts/mobs/mob_species_catalog.gd")
const Evaluator = preload("res://scripts/mobs/mob_move_evaluator.gd")
const Progression = preload("res://scripts/mobs/mob_progression_service.gd")
const Augments = preload("res://scripts/mobs/mob_move_augment_catalog.gd")
const PersonalityAdapter = preload("res://scripts/mobs/mob_personality_adapter.gd")
const BrainScript = preload("res://scripts/mobs/mob_brain_component.gd")
const ExecutionState = preload("res://scripts/mobs/mob_move_execution_state.gd")
const AbilityCatalog = preload("res://scripts/summons/creature_ability_catalog.gd")

var failures: Array[String] = []
var original_profiles: Dictionary = {}


func _ready() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	_capture_profiles()
	_test_catalogs_and_shared_moves()
	_test_wolf_policy()
	_test_sheep_policy()
	_test_capybara_policy()
	_test_gorgon_policy()
	_test_personality_adaptation()
	_test_familiar_progression()
	await _test_brain_component()
	_restore_profiles()
	_finish()


func _test_catalogs_and_shared_moves() -> void:
	_expect(MoveCatalog.validate_catalog().is_empty(), "move catalog validates")
	_expect(SpeciesCatalog.validate_catalog().is_empty(), "species catalog validates")
	_expect(SpeciesCatalog.get_species_ids().size() >= 5, "foundation seeds five contrasting species")
	var bite: MobMoveDefinition = MoveCatalog.get_definition("bite")
	_expect(bite != null, "shared Bite move resolves")
	for species_id: String in ["wolf", "sheep", "capybara", "gorgon", "gremlin"]:
		var species_bite: MobMoveDefinition = AbilityCatalog.get_move_definition(species_id, "bite")
		_expect(species_bite != null, species_id + " references shared Bite")
		if species_bite != null and bite != null:
			_expect(species_bite.move_id == bite.move_id, species_id + " keeps common Bite identity")
	_expect(AbilityCatalog.get_option("gremlin", "bite") != null, "legacy Gremlin Bite execution adapter remains available")
	_expect(AbilityCatalog.get_action("gremlin", "pounce") != null, "legacy Gremlin Pounce action remains available")
	_expect(not bite.timing.is_empty(), "shared moves expose data-driven execution timing")
	var bite_execution: Variant = ExecutionState.create(bite.to_dictionary())
	_expect(str(bite_execution.phase) == "startup", "move execution begins in startup")
	bite_execution.advance(0.17)
	_expect(str(bite_execution.phase) == "active", "move execution advances into its impact window")
	_expect(not bite_execution.can_interrupt(), "authored Bite impact window resists ordinary interruption")
	_expect(Augments.is_compatible(bite, "ferocious"), "Bite accepts attack augments")
	_expect(not Augments.is_compatible(bite, "wetting"), "Bite rejects projectile-only Wetting augment")


func _test_wolf_policy() -> void:
	var decision: Dictionary = Evaluator.choose_move("wolf", {
		"target_distance": 1.2,
		"self_health_ratio": 1.0,
		"ally_count": 2,
		"enemy_count": 1,
		"context_tags": ["hostile", "hunting"],
	})
	_expect(str(decision.get("move_id", "")) == "bite", "wolf treats Bite as standard close pressure")
	var bite_row: Dictionary = _find_move(Evaluator.evaluate_species("wolf", {
		"target_distance": 1.2,
		"ally_count": 2,
		"context_tags": ["hostile", "hunting"],
	}), "bite")
	_expect(bool(bite_row.get("eligible", false)), "wolf Bite is eligible without desperation tags")


func _test_sheep_policy() -> void:
	var ordinary_threat: Dictionary = {
		"target_distance": 1.0,
		"self_health_ratio": 1.0,
		"ally_count": 3,
		"enemy_count": 1,
		"context_tags": ["threatened", "predator_near", "target_close"],
	}
	var threatened_rows: Array[Dictionary] = Evaluator.evaluate_species("sheep", ordinary_threat)
	_expect(str(_first_eligible(threatened_rows).get("move_id", "")) == "flee", "threatened sheep chooses to flee")
	_expect(not bool(_find_move(threatened_rows, "bite").get("eligible", true)), "ordinary threat does not unlock sheep Bite")
	var cornered_rows: Array[Dictionary] = Evaluator.evaluate_species("sheep", {
		"target_distance": 1.0,
		"self_health_ratio": 0.7,
		"ally_count": 0,
		"enemy_count": 1,
		"context_tags": ["threatened", "cornered", "target_close"],
	})
	_expect(bool(_find_move(cornered_rows, "bite").get("eligible", false)), "cornered sheep may use shared Bite")
	_expect(bool(_find_move(cornered_rows, "headbutt").get("eligible", false)), "cornered sheep also unlocks Headbutt policy")
	var bite_only: Dictionary = Evaluator.choose_move("sheep", {
		"target_distance": 1.0,
		"self_health_ratio": 0.7,
		"context_tags": ["cornered", "threatened"],
		"allowed_move_ids": ["bite"],
	}, {"aggression": 0.95, "courage": 0.9})
	_expect(str(bite_only.get("move_id", "")) == "bite", "individual training can retain only conditional Sheep Bite")


func _test_capybara_policy() -> void:
	var calm_decision: Dictionary = Evaluator.choose_move("capybara", {
		"target_distance": 1.0,
		"ally_count": 4,
		"context_tags": ["safe", "water_near", "hot"],
	})
	_expect(["wade", "graze", "idle"].has(str(calm_decision.get("move_id", ""))), "calm capybara chooses habitat or ambient behavior")
	var water_rows: Array[Dictionary] = Evaluator.evaluate_species("capybara", {
		"target_distance": 2.0,
		"context_tags": ["water_near", "hot"],
	})
	_expect(bool(_find_move(water_rows, "wade").get("eligible", false)), "capybara recognizes water habitat opportunity")
	_expect(not bool(_find_move(water_rows, "bite").get("eligible", true)), "capybara does not casually Bite")
	var cornered_rows: Array[Dictionary] = Evaluator.evaluate_species("capybara", {
		"target_distance": 1.0,
		"context_tags": ["cornered", "threatened"],
	})
	_expect(bool(_find_move(cornered_rows, "bite").get("eligible", false)), "cornered capybara may defend itself with Bite")


func _test_gorgon_policy() -> void:
	var clear_sight: Dictionary = Evaluator.choose_move("gorgon", {
		"target_distance": 6.0,
		"self_health_ratio": 1.0,
		"context_tags": ["line_of_sight", "hostile", "target_stationary"],
	})
	_expect(str(clear_sight.get("move_id", "")) == "stone_gaze", "gorgon selects Stone Gaze with a clear midrange target")
	var immune_rows: Array[Dictionary] = Evaluator.evaluate_species("gorgon", {
		"target_distance": 6.0,
		"context_tags": ["line_of_sight", "hostile"],
		"target_tags": ["gaze_immune"],
	})
	_expect(not bool(_find_move(immune_rows, "stone_gaze").get("eligible", true)), "gorgon rejects Stone Gaze against gaze immunity")
	var crowded: Dictionary = Evaluator.choose_move("gorgon", {
		"target_distance": 2.0,
		"enemy_count": 3,
		"context_tags": ["crowded", "surrounded", "multiple_targets", "hostile"],
	})
	_expect(str(crowded.get("move_id", "")) == "tail_sweep", "crowded gorgon favors Tail Sweep")


func _test_personality_adaptation() -> void:
	var traits: Dictionary = PersonalityAdapter.from_enemy_profile("skittish")
	_expect(float(traits.get("courage", 1.0)) < 0.25, "old Skittish profile maps to low courage")
	var decision: Dictionary = Evaluator.choose_move("wolf", {
		"target_distance": 1.4,
		"self_health_ratio": 0.2,
		"ally_count": 0,
		"enemy_count": 3,
		"context_tags": ["hostile", "injured", "overwhelmed", "alone", "outnumbered"],
	}, traits)
	_expect(str(decision.get("move_id", "")) == "flee", "skittish wounded wolf prioritizes survival over Bite")
	var bold_sheep: Dictionary = PersonalityAdapter.apply_profile_to_species("sheep", "bold")
	_expect(float(bold_sheep.get("aggression", 0.0)) > 0.75, "Bold profile can specialize a normally passive species")


func _test_familiar_progression() -> void:
	var start: Dictionary = Progression.reset_profile("gremlin")
	_expect(int(start.get("level", 0)) == 1, "Gremlin familiar begins at level one")
	_expect(_strings(start.get("learned_moves", [])).has("bite"), "Gremlin familiar begins with Bite")
	_expect(not _strings(start.get("learned_moves", [])).has("mire_spit"), "advanced move begins locked")
	var experience_result: Dictionary = Progression.gain_experience("gremlin", 22)
	_expect(int(experience_result.get("level", 0)) == 3, "experience advances familiar across generic level thresholds")
	var learned_now: Array[String] = _strings(experience_result.get("learned_moves", []))
	_expect(learned_now.has("pounce") and learned_now.has("mire_spit"), "leveling automatically learns movepool unlocks")
	_expect(bool(Progression.equip_move("gremlin", "pounce").get("ok", false)), "learned Pounce equips")
	_expect(bool(Progression.equip_move("gremlin", "mire_spit").get("ok", false)), "learned Mire Spit equips")
	var upgrade: Dictionary = Progression.upgrade_move("gremlin", "bite", 1)
	_expect(int(upgrade.get("rank", 0)) == 2, "Bite rank upgrades generically")
	_expect(bool(Progression.set_move_augment("gremlin", "bite", "primary", "ferocious").get("ok", false)), "Bite accepts Ferocious augment")
	_expect(bool(Progression.set_move_augment("gremlin", "bite", "secondary", "venomous").get("ok", false)), "Bite accepts Venomous augment")
	var resolved: Dictionary = Progression.resolve_move("gremlin", "bite")
	var effect: Dictionary = resolved.get("effect", {}) as Dictionary
	_expect(float(effect.get("damage", 0.0)) > 3.0, "rank and Ferocious augment increase Bite damage")
	_expect(_statuses_have(effect.get("statuses", []), "poisoned"), "Venomous augment adds Poison rider")
	_expect(_strings(resolved.get("applied_augments", [])).has("ferocious"), "resolved move records applied augments")
	var trait_result: Dictionary = Progression.set_personality_trait("gremlin", "aggression", 0.9)
	_expect(bool(trait_result.get("ok", false)), "familiar personality training persists")
	var profile: Dictionary = Progression.get_profile("gremlin")
	var encoded: String = JSON.stringify(profile)
	var decoded: Variant = JSON.parse_string(encoded)
	_expect(decoded is Dictionary, "familiar profile is JSON-safe")
	_expect(_strings(profile.get("equipped_moves", [])).has("pounce"), "equipped movepool persists")
	var familiar_context: Dictionary = Progression.get_decision_context_profile("gremlin", {
		"target_distance": 1.2,
		"context_tags": ["hostile"],
	})
	var familiar_choice: Dictionary = Evaluator.choose_move(
		"gremlin",
		familiar_context,
		profile.get("personality_overrides", {}) as Dictionary
	)
	_expect(str(familiar_choice.get("move_id", "")) == "bite", "trained familiar evaluator respects equipped movepool and range")


func _test_brain_component() -> void:
	var brain := BrainScript.new() as MobBrainComponent
	add_child(brain)
	brain.configure("sheep", "cautious")
	brain.set_context({
		"target_distance": 1.0,
		"context_tags": ["threatened", "predator_near"],
	})
	var decision: Dictionary = brain.request_decision()
	_expect(str(decision.get("move_id", "")) == "flee", "attachable brain chooses from species policy")
	var committed: Dictionary = brain.commit_move("flee")
	_expect(bool(committed.get("ok", false)), "attachable brain commits selected move")
	_expect(float(brain.cooldowns.get("flee", 0.0)) > 0.0, "committing a move starts its cooldown")
	_expect(committed.get("execution_adapter") == null, "new species may select moves before a bespoke executor exists")
	brain.clear_cooldowns()
	var started: Dictionary = brain.begin_move("flee", {"source": "smoke_test"})
	_expect(bool(started.get("ok", false)), "brain begins a selected move lifecycle")
	_expect(brain.has_active_move(), "brain reports its committed active move")
	var blocked: Dictionary = brain.request_decision()
	_expect(bool(blocked.has("blocked_by_active_move")), "active move prevents roulette-style redecision")
	var active_step: Dictionary = brain.advance_active_move(0.08)
	_expect(str(active_step.get("phase", "")) == "active", "movement move enters active execution")
	var interrupted: Dictionary = brain.interrupt_active_move("new_threat")
	_expect(bool(interrupted.get("interrupted", false)), "interruptible movement responds to a new threat")
	_expect(not brain.has_active_move(), "interrupted move releases the brain for another decision")
	var cooldown_rejected: Dictionary = brain.begin_move("flee")
	_expect(str(cooldown_rejected.get("error", "")) == "move is on cooldown", "interrupted moves retain their authored cooldown")
	brain.clear_cooldowns()
	var idle_started: Dictionary = brain.begin_move("idle")
	_expect(bool(idle_started.get("ok", false)), "brain can start a follow-up move")
	var completed: Dictionary = brain.advance_active_move(5.0)
	_expect(bool(completed.get("completed", false)), "move lifecycle reports natural completion")
	_expect(not brain.has_active_move(), "completed move releases the action slot")
	_expect(not bool(brain.begin_move("missing_move").get("ok", true)), "unknown moves cannot enter execution")
	brain.queue_free()
	await get_tree().process_frame


func _capture_profiles() -> void:
	for species_id: String in SpeciesCatalog.get_species_ids():
		var key: String = Progression.PROFILE_PREFIX + species_id
		original_profiles[species_id] = {
			"present": GameState.story_flags.has(key),
			"value": GameState.story_flags.get(key),
		}


func _restore_profiles() -> void:
	for species_id: String in SpeciesCatalog.get_species_ids():
		var key: String = Progression.PROFILE_PREFIX + species_id
		var snapshot: Dictionary = original_profiles.get(species_id, {}) as Dictionary
		if bool(snapshot.get("present", false)):
			GameState.story_flags[key] = snapshot.get("value")
		else:
			GameState.story_flags.erase(key)


func _find_move(rows: Array[Dictionary], move_id: String) -> Dictionary:
	for row: Dictionary in rows:
		if str(row.get("move_id", "")) == move_id:
			return row
	return {}


func _first_eligible(rows: Array[Dictionary]) -> Dictionary:
	for row: Dictionary in rows:
		if bool(row.get("eligible", false)):
			return row
	return {}


func _statuses_have(value: Variant, status_id: String) -> bool:
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary and str((raw as Dictionary).get("id", "")) == status_id:
				return true
	return false


func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			result.append(str(raw))
	return result


func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)


func _finish() -> void:
	if failures.is_empty():
		print("MOB_ENGINE_FOUNDATION_SMOKE_TEST: PASS")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("MOB_ENGINE_FOUNDATION_SMOKE_TEST: " + failure)
	get_tree().quit(1)
