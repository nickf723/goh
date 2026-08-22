extends Node
class_name MobBrainComponent

const MoveExecutionState = preload("res://scripts/mobs/mob_move_execution_state.gd")
const EffectRequest = preload("res://scripts/mobs/mob_move_effect_request.gd")

signal move_selected(move_id: String, decision: Dictionary)
signal evaluation_completed(rows: Array[Dictionary])
signal move_committed(move_id: String, cooldown: float)
signal move_started(move_id: String, execution: Dictionary)
signal move_effect_requested(move_id: String, request: Dictionary, execution: Dictionary)
signal move_phase_changed(move_id: String, previous_phase: String, phase: String, execution: Dictionary)
signal move_completed(move_id: String, outcome: Dictionary, execution: Dictionary)
signal move_interrupted(move_id: String, reason: String, execution: Dictionary)
signal intention_changed(intention_id: String)

@export var species_id: String = "gremlin"
@export var personality_profile_id: String = "balanced"
@export var personality_overrides: Dictionary = {}
@export var use_familiar_progression: bool = false
@export var automatic_decisions: bool = false
@export_range(0.1, 10.0, 0.1) var decision_interval: float = 0.8
@export var context_provider_path: NodePath
@export_range(1, 8, 1) var recent_move_memory: int = 3
@export var use_drive_state: bool = true
@export var drive_overrides: Dictionary = {}
@export_range(0.05, 2.0, 0.05) var drive_tick_interval: float = 0.25
@export_range(0.0, 10.0, 0.1) var intention_commitment_seconds: float = 1.6
@export_range(0.0, 3.0, 0.05) var intention_score_tolerance: float = 0.35
@export var print_debug: bool = false

var current_context: Dictionary = {}
var cooldowns: Dictionary = {}
var recent_move_ids: Array[String] = []
var last_evaluation: Array[Dictionary] = []
var last_decision: Dictionary = {}
var decision_timer: float = 0.0
var drive_tick_accumulator: float = 0.0
var drive_state: MobDriveState
var current_intention_id: String = ""
var intention_time_remaining: float = 0.0
var active_execution: Variant = null
var execution_serial: int = 0


func _ready() -> void:
	add_to_group("mob_brain_component")
	add_to_group("debuggable")
	decision_timer = decision_interval
	_reset_drive_state()


func _process(delta: float) -> void:
	_tick_cooldowns(delta)
	_tick_intention(delta)
	_tick_drives(delta)
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
	if has_active_move():
		interrupt_active_move("reconfigured", true)
	species_id = new_species_id
	personality_profile_id = profile_id
	personality_overrides = overrides.duplicate(true)
	_reset_drive_state()
	clear_memory()


func set_context(context: Dictionary) -> void:
	current_context = context.duplicate(true)
	if use_drive_state:
		_ensure_drive_state()
		drive_state.observe_context(current_context, _resolve_traits())


func request_decision(context_override: Dictionary = {}) -> Dictionary:
	if has_active_move():
		last_decision = {
			"species_id": species_id,
			"move_id": "",
			"eligible": false,
			"score": 0.0,
			"reasons": ["active move in progress"],
			"blocked_by_active_move": get_active_execution(),
		}
		return last_decision.duplicate(true)
	var context: Dictionary = _resolve_context()
	context.merge(context_override, true)
	var traits: Dictionary = _resolve_traits()
	if use_drive_state:
		_ensure_drive_state()
		drive_state.observe_context(context, traits)
		context = drive_state.build_context(context)
	context["cooldowns"] = cooldowns.duplicate(true)
	context["recent_move_ids"] = recent_move_ids.duplicate()
	if use_familiar_progression:
		context = MobProgressionService.get_decision_context_profile(species_id, context)
	last_evaluation = MobMoveEvaluator.evaluate_species(species_id, context, traits)
	evaluation_completed.emit(last_evaluation)

	var previous_intention: String = current_intention_id
	var commitment_active: bool = (
		intention_time_remaining > 0.0
		and current_intention_id != ""
	)
	last_decision = MobIntentionResolver.choose_with_commitment(
		last_evaluation,
		current_intention_id if commitment_active else "",
		intention_score_tolerance
	)
	if last_decision.is_empty():
		last_decision = _first_eligible(last_evaluation)

	if not last_decision.is_empty() and str(last_decision.get("move_id", "")) != "":
		var selected_intention: String = MobIntentionResolver.get_intention_id(
			last_decision
		)
		if not commitment_active or selected_intention != current_intention_id:
			current_intention_id = selected_intention
			intention_time_remaining = intention_commitment_seconds
		if current_intention_id != previous_intention:
			intention_changed.emit(current_intention_id)
		last_decision["intention_id"] = current_intention_id
		last_decision["intention_time_remaining"] = intention_time_remaining
		if use_drive_state:
			last_decision["drive_snapshot"] = drive_state.to_dictionary()
		move_selected.emit(str(last_decision["move_id"]), last_decision)
		if print_debug:
			print(
				MobSpeciesCatalog.get_definition(species_id).display_name,
				" selects ",
				last_decision.get("display_name", last_decision.get("move_id", "")),
				" [", current_intention_id, "] • ",
				last_decision.get("score", 0.0)
			)
	elif intention_time_remaining <= 0.0:
		current_intention_id = ""
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
	if use_drive_state:
		_ensure_drive_state()
		drive_state.satisfy_move(move_data)
	move_committed.emit(move_id, cooldown)
	return {
		"ok": true,
		"move_id": move_id,
		"cooldown": cooldown,
		"move": move_data,
		"intention_id": current_intention_id,
		"drive_snapshot": get_drive_snapshot(),
		"execution_adapter": CreatureAbilityCatalog.get_option(species_id, move_id),
	}


func begin_move(move_id: String, execution_context: Dictionary = {}) -> Dictionary:
	if has_active_move():
		return {
			"ok": false,
			"error": "active move in progress",
			"active_execution": get_active_execution(),
		}
	var move_data: Dictionary = get_resolved_move(move_id)
	if move_data.is_empty():
		return {"ok": false, "error": "unknown move", "move_id": move_id}
	var cooldown_remaining: float = maxf(float(cooldowns.get(move_id, 0.0)), 0.0)
	if cooldown_remaining > 0.0:
		return {
			"ok": false,
			"error": "move is on cooldown",
			"move_id": move_id,
			"cooldown_remaining": cooldown_remaining,
		}
	var committed: Dictionary = commit_move(move_id)
	if not bool(committed.get("ok", false)):
		return committed
	execution_serial += 1
	var resolved_context: Dictionary = execution_context.duplicate(true)
	resolved_context["execution_serial"] = execution_serial
	resolved_context["species_id"] = species_id
	active_execution = MoveExecutionState.create(move_data, resolved_context)
	var snapshot: Dictionary = get_active_execution()
	move_started.emit(move_id, snapshot)
	var effect_request: Dictionary = _request_active_effect_if_ready()
	snapshot = get_active_execution()
	if not effect_request.is_empty():
		snapshot["effect_request"] = effect_request
	return {
		"ok": true,
		"move_id": move_id,
		"execution": snapshot,
		"effect_request": effect_request,
		"commit": committed,
	}


func advance_active_move(delta: float) -> Dictionary:
	if not has_active_move():
		return {"ok": false, "error": "no active move"}
	var snapshot: Dictionary = active_execution.advance(delta)
	var move_id: String = str(snapshot.get("move_id", ""))
	if bool(snapshot.get("phase_changed", false)):
		move_phase_changed.emit(
			move_id,
			str(snapshot.get("previous_phase", "")),
			str(snapshot.get("phase", "")),
			snapshot
		)
	var effect_request: Dictionary = _request_active_effect_if_ready()
	if not effect_request.is_empty():
		snapshot["effect_request"] = effect_request
		snapshot["effect_request_ready"] = false
		snapshot["effect_request_claimed"] = true
	if bool(snapshot.get("completed", false)):
		var outcome: Dictionary = snapshot.get("result", {}) as Dictionary
		move_completed.emit(move_id, outcome, snapshot)
		active_execution = null
	return snapshot


func complete_active_move(outcome: Dictionary = {}) -> Dictionary:
	if not has_active_move():
		return {"ok": false, "error": "no active move"}
	var snapshot: Dictionary = active_execution.finish(outcome)
	var move_id: String = str(snapshot.get("move_id", ""))
	move_phase_changed.emit(
		move_id,
		str(snapshot.get("previous_phase", "")),
		str(snapshot.get("phase", "")),
		snapshot
	)
	move_completed.emit(move_id, snapshot.get("result", {}) as Dictionary, snapshot)
	active_execution = null
	return snapshot


func interrupt_active_move(
	reason: String,
	force: bool = false,
	outcome: Dictionary = {}
) -> Dictionary:
	if not has_active_move():
		return {"ok": false, "error": "no active move"}
	var snapshot: Dictionary = active_execution.interrupt(reason, force, outcome)
	if not bool(snapshot.get("interrupted", false)):
		return snapshot
	var move_id: String = str(snapshot.get("move_id", ""))
	move_phase_changed.emit(
		move_id,
		str(snapshot.get("previous_phase", "")),
		str(snapshot.get("phase", "")),
		snapshot
	)
	move_interrupted.emit(move_id, reason, snapshot)
	active_execution = null
	return snapshot


func has_active_move() -> bool:
	return active_execution != null and bool(active_execution.is_active())


func get_active_execution() -> Dictionary:
	return active_execution.to_dictionary() if active_execution != null else {}


func clear_cooldowns() -> void:
	cooldowns.clear()


func clear_memory() -> void:
	recent_move_ids.clear()
	last_evaluation.clear()
	last_decision.clear()
	current_intention_id = ""
	intention_time_remaining = 0.0


func reset_drives(overrides: Dictionary = {}) -> void:
	drive_overrides = overrides.duplicate(true)
	_reset_drive_state()


func set_drive(drive_id: String, value: float) -> void:
	_ensure_drive_state()
	drive_state.set_drive(drive_id, value)


func add_drive(drive_id: String, delta: float) -> void:
	_ensure_drive_state()
	drive_state.add_drive(drive_id, delta)


func get_drive(drive_id: String, fallback: float = 0.0) -> float:
	if not use_drive_state:
		return fallback
	_ensure_drive_state()
	return drive_state.get_drive(drive_id, fallback)


func get_drive_snapshot() -> Dictionary:
	if not use_drive_state:
		return {}
	_ensure_drive_state()
	return drive_state.to_dictionary()


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
		"personality": _resolve_traits(),
		"use_familiar_progression": use_familiar_progression,
		"context": current_context.duplicate(true),
		"cooldowns": cooldowns.duplicate(true),
		"recent_moves": recent_move_ids.duplicate(),
		"drives": get_drive_snapshot(),
		"current_intention_id": current_intention_id,
		"intention_time_remaining": intention_time_remaining,
		"active_execution": get_active_execution(),
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


func _resolve_traits() -> Dictionary:
	var traits: Dictionary = MobPersonalityAdapter.apply_profile_to_species(
		species_id,
		personality_profile_id,
		personality_overrides
	)
	if use_familiar_progression:
		var profile: Dictionary = MobProgressionService.get_profile(species_id)
		traits = MobPersonalityAdapter.merge_traits(
			traits,
			profile.get("personality_overrides", {}) as Dictionary
		)
	return traits


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


func _tick_intention(delta: float) -> void:
	if intention_time_remaining <= 0.0:
		return
	intention_time_remaining = maxf(intention_time_remaining - delta, 0.0)
	if intention_time_remaining <= 0.0:
		current_intention_id = ""
		intention_changed.emit("")


func _tick_drives(delta: float) -> void:
	if not use_drive_state:
		return
	drive_tick_accumulator += delta
	if drive_tick_accumulator < drive_tick_interval:
		return
	var elapsed: float = drive_tick_accumulator
	drive_tick_accumulator = 0.0
	_ensure_drive_state()
	drive_state.tick(elapsed, _resolve_context(), _resolve_traits())


func _reset_drive_state() -> void:
	drive_tick_accumulator = 0.0
	if not use_drive_state:
		drive_state = null
		return
	drive_state = MobDriveState.create_for_species(
		species_id,
		_resolve_traits(),
		drive_overrides
	)


func _ensure_drive_state() -> void:
	if drive_state == null or drive_state.species_id != species_id.to_lower().strip_edges():
		_reset_drive_state()


func _base_move_dictionary(move_id: String) -> Dictionary:
	var move: MobMoveDefinition = CreatureAbilityCatalog.get_move_definition(species_id, move_id)
	return move.to_dictionary() if move != null else {}


func _request_active_effect_if_ready() -> Dictionary:
	if active_execution == null or not active_execution.claim_active_effect():
		return {}
	var execution: Dictionary = active_execution.to_dictionary()
	var request: Dictionary = EffectRequest.build(execution, {
		"species_id": species_id,
	})
	move_effect_requested.emit(
		str(execution.get("move_id", "")),
		request,
		execution
	)
	return request


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
