extends "res://scripts/enemies/enemy_action_selection_brain.gd"
class_name EnemyTacticalActionBrain


const WorldSnapshot = preload(
	"res://scripts/ai/tactical_world_snapshot.gd"
)
const ActionCandidate = preload(
	"res://scripts/ai/tactical_action_candidate.gd"
)
const Evaluator = preload(
	"res://scripts/ai/role_aware_squad_tactical_evaluator.gd"
)

@export_group("Reaction Tactics")
@export var enable_reaction_tactics: bool = true
@export_range(0.0, 3.0, 0.05) var tactical_score_scale: float = 1.0
@export_range(2.0, 30.0, 0.5) var tactical_hazard_scan_radius: float = 12.0
@export var ignored_hazard_tags: Array[String] = []

@export_group("Tactical Performance")
@export_range(0.0, 0.5, 0.01) var tactical_decision_interval: float = 0.0
@export_range(0.0, 0.12, 0.005) var tactical_decision_stagger: float = 0.0

var tactical_snapshot: Dictionary = {}
var tactical_frame: int = -1
var tactical_rows: Dictionary = {}
var last_tactical_decision: Dictionary = {}

var tactical_decision_timer: float = 0.0
var cached_tactical_option: EnemyActionOption = null
var cached_tactical_target_id: int = 0
var tactical_cache_initialized: bool = false
var tactical_evaluation_count: int = 0
var tactical_cache_hit_count: int = 0


func update_timers(delta: float) -> void:
	super.update_timers(delta)
	tactical_decision_timer = maxf(tactical_decision_timer - delta, 0.0)


func select_action(
	distance: float,
	retreat_interrupt_only: bool = false
) -> EnemyActionOption:
	if _can_reuse_tactical_decision(distance, retreat_interrupt_only):
		tactical_cache_hit_count += 1
		return cached_tactical_option

	_begin_tactical_evaluation()
	tactical_evaluation_count += 1
	var option: EnemyActionOption = super.select_action(
		distance,
		retreat_interrupt_only
	)
	_finalize_tactical_decision(option)

	if retreat_interrupt_only:
		invalidate_tactical_decision_cache()
	else:
		_cache_tactical_decision(option)
	return option


func score_action_option(option: EnemyActionOption, distance: float) -> float:
	var base_score: float = super.score_action_option(option, distance)
	if not enable_reaction_tactics or option == null:
		return base_score
	_ensure_tactical_snapshot()
	var candidate: TacticalActionCandidate = ActionCandidate.from_enemy_option(option)
	candidate.base_score = base_score
	candidate.current_distance = distance
	var evaluation: Dictionary = Evaluator.evaluate(candidate, tactical_snapshot)
	var valid: bool = bool(evaluation.get("valid", false))
	var tactical_delta: float = float(evaluation.get("score", 0.0))
	var total_score: float = (
		-INF
		if not valid
		else base_score + tactical_delta * maxf(tactical_score_scale, 0.0)
	)
	tactical_rows[option.get_instance_id()] = {
		"action_id": candidate.action_id,
		"display_name": candidate.display_name,
		"base_score": base_score,
		"tactical_delta": tactical_delta,
		"total_score": total_score,
		"valid": valid,
		"reason": str(evaluation.get("primary_reason", "No tactical read")),
		"reasons": _string_array(evaluation.get("reasons", [])),
		"penalties": _string_array(evaluation.get("penalties", [])),
		"opportunities": _dictionary_array(
			evaluation.get("opportunities", [])
		),
		"squad_role_id": str(
			evaluation.get(
				"squad_role_id",
				tactical_snapshot.get("squad_role_id", "generalist")
			)
		),
		"squad_role_name": str(
			evaluation.get("squad_role_name", "Generalist")
		),
		"squad_role_score": float(
			evaluation.get("squad_role_score", 0.0)
		),
	}
	return total_score


func _begin_tactical_evaluation() -> void:
	tactical_frame = -1
	tactical_rows.clear()
	_ensure_tactical_snapshot()


func _ensure_tactical_snapshot() -> void:
	var frame: int = Engine.get_process_frames()
	if tactical_frame == frame and not tactical_snapshot.is_empty():
		return
	tactical_frame = frame
	tactical_rows.clear()
	tactical_snapshot = WorldSnapshot.capture(
		actor,
		player,
		{
			"relation": "hostile",
			"hazard_scan_radius": tactical_hazard_scan_radius,
			"ignored_hazard_tags": ignored_hazard_tags,
		}
	)


func _finalize_tactical_decision(option: EnemyActionOption) -> void:
	var selected_row: Dictionary = {}
	if option != null:
		var value: Variant = tactical_rows.get(option.get_instance_id(), {})
		if value is Dictionary:
			selected_row = (value as Dictionary).duplicate(true)
	var rows: Array[Dictionary] = []
	for value: Variant in tactical_rows.values():
		if value is Dictionary:
			rows.append((value as Dictionary).duplicate(true))
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: float = float(a.get("total_score", -INF))
		var score_b: float = float(b.get("total_score", -INF))
		if not is_equal_approx(score_a, score_b):
			return score_a > score_b
		return str(a.get("action_id", "")) < str(b.get("action_id", ""))
	)
	last_tactical_decision = {
		"enabled": enable_reaction_tactics,
		"selected": selected_row,
		"reason": str(selected_row.get("reason", "No tactical action selected")),
		"candidates": rows,
		"target_statuses": _snapshot_strings("target", "statuses"),
		"path_danger": tactical_snapshot.get("path_danger", {}),
		"squad_role_id": str(
			tactical_snapshot.get("squad_role_id", "generalist")
		),
		"squad_roles": tactical_snapshot.get("squad_roles", []),
	}


func _can_reuse_tactical_decision(
	distance: float,
	retreat_interrupt_only: bool
) -> bool:
	if (
		retreat_interrupt_only
		or tactical_decision_interval <= 0.0
		or not tactical_cache_initialized
		or tactical_decision_timer <= 0.0
	):
		return false
	if cached_tactical_target_id != _current_tactical_target_id():
		invalidate_tactical_decision_cache()
		return false
	if cached_tactical_option == null:
		return true
	if not is_instance_valid(cached_tactical_option):
		invalidate_tactical_decision_cache()
		return false
	if not action_options.has(cached_tactical_option):
		invalidate_tactical_decision_cache()
		return false
	if not cached_tactical_option.is_valid_at_distance(distance):
		invalidate_tactical_decision_cache()
		return false
	if not is_option_available(cached_tactical_option):
		invalidate_tactical_decision_cache()
		return false
	return true


func _cache_tactical_decision(option: EnemyActionOption) -> void:
	if tactical_decision_interval <= 0.0:
		invalidate_tactical_decision_cache()
		return
	cached_tactical_option = option
	cached_tactical_target_id = _current_tactical_target_id()
	tactical_cache_initialized = true
	tactical_decision_timer = (
		maxf(tactical_decision_interval, 0.0)
		+ _get_tactical_decision_stagger_seconds()
	)


func invalidate_tactical_decision_cache() -> void:
	cached_tactical_option = null
	cached_tactical_target_id = 0
	tactical_cache_initialized = false
	tactical_decision_timer = 0.0
	tactical_frame = -1
	tactical_rows.clear()


func _current_tactical_target_id() -> int:
	return player.get_instance_id() if player != null and is_instance_valid(player) else 0


func _get_tactical_decision_stagger_seconds() -> float:
	if tactical_decision_stagger <= 0.0:
		return 0.0
	var source_id: int = get_instance_id()
	if actor != null and is_instance_valid(actor):
		source_id = actor.get_instance_id()
	var bucket: int = source_id % 7
	return (
		float(bucket) / 6.0
		* maxf(tactical_decision_stagger, 0.0)
	)


func on_action_completed(action: EnemyCombatActionDefinition) -> void:
	super.on_action_completed(action)
	invalidate_tactical_decision_cache()


func interrupt_current_action(reason: String) -> bool:
	var interrupted: bool = super.interrupt_current_action(reason)
	if interrupted:
		invalidate_tactical_decision_cache()
	return interrupted


func cancel_current_action(reason: String) -> void:
	super.cancel_current_action(reason)
	invalidate_tactical_decision_cache()


func finish_action_state() -> void:
	super.finish_action_state()
	invalidate_tactical_decision_cache()


func _snapshot_strings(section: String, key: String) -> Array[String]:
	var section_value: Variant = tactical_snapshot.get(section, {})
	if not section_value is Dictionary:
		return []
	return _string_array((section_value as Dictionary).get(key, []))


func get_tactical_decision_trace() -> Dictionary:
	return last_tactical_decision.duplicate(true)


func get_tactical_performance_debug_data() -> Dictionary:
	return {
		"decision_interval": tactical_decision_interval,
		"decision_stagger": tactical_decision_stagger,
		"decision_timer": snappedf(tactical_decision_timer, 0.001),
		"cache_initialized": tactical_cache_initialized,
		"cached_action": (
			cached_tactical_option.get_display_name()
			if cached_tactical_option != null
			and is_instance_valid(cached_tactical_option)
			else "none"
		),
		"evaluations": tactical_evaluation_count,
		"cache_hits": tactical_cache_hit_count,
	}


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["tactical_ai"] = last_tactical_decision.duplicate(true)
	data["tactical_reason"] = str(
		last_tactical_decision.get("reason", "not evaluated")
	)
	data["tactical_performance"] = get_tactical_performance_debug_data()
	return data


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