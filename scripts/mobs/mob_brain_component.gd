extends Node
class_name MobBrainComponent

signal move_selected(move_id: String, decision: Dictionary)
signal evaluation_completed(rows: Array[Dictionary])
signal move_committed(move_id: String, cooldown: float)

@export var species_id: String = "gremlin"
@export var personality_profile_id: String = "balanced"
@export var personality_overrides: Dictionary = {}
@export var use_familiar_progression: bool = false
@export var automatic_decisions: bool = false
@export_range(0.1, 10.0, 0.1) var decision_interval: float = 0.8
@export var context_provider_path: NodePath
@export_range(1, 8, 1) var recent_move_memory: int = 3
@export var print_debug: bool = false

var current_context: Dictionary = {}
var cooldowns: Dictionary = {}
var recent_move_ids: Array[String] = []
var last_evaluation: Array[Dictionary] = []
var last_decision: Dictionary = {}
var decision_timer: float = 0.0


func _ready() -> void:
	add_to_group("mob_brain_component")
	add_to_group("debuggable")
	decision_timer = decision_interval


func _process(delta: float) -> void:
	_tick_cooldowns(delta)
	if not automatic_decisions or get_tree().paused:
		return
	decision_timer -= delta
	if decision_timer > 0.0:
		return
	decision_timer = decision_interval
	request_decision()


func configure(
	new_species_id: String,
	profile_id: String = "balanced",
	overrides: Dictionary = {}
) -> void:
	species_id = new_species_id
	personality_profile_id = profile_id
	personality_overrides = overrides.duplicate(true)


func set_context(context: Dictionary) -> void:
	current_context = context.duplicate(true)


func request_decision(context_override: Dictionary = {}) -> Dictionary:
	var context: Dictionary = _resolve_context()
	context.merge(context_override, true)
	context["cooldowns"] = cooldowns.duplicate(true)
	context["recent_move_ids"] = recent_move_ids.duplicate()
	var traits: Dictionary = MobPersonalityAdapter.apply_profile_to_species(
		species_id,
		personality_profile_id,
		personality_overrides
	)
	if use_familiar_progression:
		var profile: Dictionary = MobProgressionService.get_profile(species_id)
		context = MobProgressionService.get_decision_context_profile(species_id, context)
		traits = MobPersonalityAdapter.merge_traits(
			traits,
			profile.get("personality_overrides", {}) as Dictionary
		)
	last_evaluation = MobMoveEvaluator.evaluate_species(species_id, context, traits)
	evaluation_completed.emit(last_evaluation)
	last_decision = _first_eligible(last_evaluation)
	if not last_decision.is_empty() and str(last_decision.get("move_id", "")) != "":
		move_selected.emit(str(last_decision["move_id"]), last_decision)
		if print_debug:
			print(
				MobSpeciesCatalog.get_definition(species_id).display_name,
				" selects ",
				last_decision.get("display_name", last_decision.get("move_id", "")),
				" • ",
				last_decision.get("score", 0.0)
			)
	return last_decision.duplicate(true)


func commit_move(move_id: String, cooldown_override: float = -1.0) -> Dictionary:
	var move_data: Dictionary = (
		MobProgressionService.resolve_move(species_id, move_id)
		if use_familiar_progression
		else _base_move_dictionary(move_id)
	)
	if move_data.is_empty():
		return {"ok": false, "error": "unknown move"}
	var cooldown: float = (
		maxf(cooldown_override, 0.0)
		if cooldown_override >= 0.0
		else maxf(float(move_data.get("cooldown", 0.0)), 0.0)
	)
	cooldowns[move_id] = cooldown
	recent_move_ids.erase(move_id)
	recent_move_ids.push_front(move_id)
	while recent_move_ids.size() > recent_move_memory:
		recent_move_ids.pop_back()
	move_committed.emit(move_id, cooldown)
	return {
		"ok": true,
		"move_id": move_id,
		"cooldown": cooldown,
		"move": move_data,
		"execution_adapter": CreatureAbilityCatalog.get_option(species_id, move_id),
	}


func clear_cooldowns() -> void:
	cooldowns.clear()


func clear_memory() -> void:
	recent_move_ids.clear()
	last_evaluation.clear()
	last_decision.clear()


func get_execution_adapter(move_id: String) -> Resource:
	return CreatureAbilityCatalog.get_option(species_id, move_id)


func get_resolved_move(move_id: String) -> Dictionary:
	return (
		MobProgressionService.resolve_move(species_id, move_id)
		if use_familiar_progression
		else _base_move_dictionary(move_id)
	)


func get_ranked_moves() -> Array[Dictionary]:
	return last_evaluation.duplicate(true)


func get_debug_data() -> Dictionary:
	return {
		"species_id": species_id,
		"personality_profile_id": personality_profile_id,
		"personality": MobPersonalityAdapter.apply_profile_to_species(
			species_id,
			personality_profile_id,
			personality_overrides
		),
		"use_familiar_progression": use_familiar_progression,
		"context": current_context.duplicate(true),
		"cooldowns": cooldowns.duplicate(true),
		"recent_moves": recent_move_ids.duplicate(),
		"last_decision": last_decision.duplicate(true),
		"ranked_moves": last_evaluation.duplicate(true),
	}


func _resolve_context() -> Dictionary:
	var provider: Node = get_node_or_null(context_provider_path) if not context_provider_path.is_empty() else null
	if provider != null and provider.has_method("get_mob_decision_context"):
		var value: Variant = provider.call("get_mob_decision_context")
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)
	return current_context.duplicate(true)


func _tick_cooldowns(delta: float) -> void:
	var expired: Array[String] = []
	for raw_move_id: Variant in cooldowns.keys():
		var move_id: String = str(raw_move_id)
		var remaining: float = maxf(float(cooldowns[raw_move_id]) - delta, 0.0)
		if remaining <= 0.0:
			expired.append(move_id)
		else:
			cooldowns[move_id] = remaining
	for move_id: String in expired:
		cooldowns.erase(move_id)


func _base_move_dictionary(move_id: String) -> Dictionary:
	var move: MobMoveDefinition = CreatureAbilityCatalog.get_move_definition(species_id, move_id)
	return move.to_dictionary() if move != null else {}


func _first_eligible(rows: Array[Dictionary]) -> Dictionary:
	for row: Dictionary in rows:
		if bool(row.get("eligible", false)):
			return row.duplicate(true)
	return {
		"species_id": species_id,
		"move_id": "",
		"eligible": false,
		"score": 0.0,
		"reasons": ["no eligible move"],
	}
