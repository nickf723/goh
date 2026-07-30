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

var tactical_snapshot: Dictionary = {}
var tactical_frame: int = -1
var tactical_rows: Dictionary = {}
var last_tactical_decision: Dictionary = {}


func select_action(
	distance: float,
	retreat_interrupt_only: bool = false
) -> EnemyActionOption:
	_begin_tactical_evaluation()
	var option: EnemyActionOption = super.select_action(
		distance,
		retreat_interrupt_only
	)
	_finalize_tactical_decision(option)
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


func _snapshot_strings(section: String, key: String) -> Array[String]:
	var section_value: Variant = tactical_snapshot.get(section, {})
	if not section_value is Dictionary:
		return []
	return _string_array((section_value as Dictionary).get(key, []))


func get_tactical_decision_trace() -> Dictionary:
	return last_tactical_decision.duplicate(true)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["tactical_ai"] = last_tactical_decision.duplicate(true)
	data["tactical_reason"] = str(
		last_tactical_decision.get("reason", "not evaluated")
	)
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
