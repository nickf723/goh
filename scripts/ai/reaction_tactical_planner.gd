extends RefCounted
class_name ReactionTacticalPlanner


const Evaluator = preload(
	"res://scripts/ai/squad_tactical_opportunity_evaluator.gd"
)


static func choose_best(
	candidates: Array[TacticalActionCandidate],
	snapshot: Dictionary
) -> Dictionary:
	var rows: Array[Dictionary] = []
	var best_candidate: TacticalActionCandidate = null
	var best_evaluation: Dictionary = {}
	var best_score: float = -INF
	for candidate: TacticalActionCandidate in candidates:
		if candidate == null:
			continue
		var evaluation: Dictionary = Evaluator.evaluate(candidate, snapshot)
		var tactical_delta: float = float(evaluation.get("score", -INF))
		var total_score: float = (
			-INF
			if not bool(evaluation.get("valid", false))
			else candidate.base_score + tactical_delta
		)
		var row: Dictionary = candidate.to_debug_data()
		row["valid"] = bool(evaluation.get("valid", false))
		row["tactical_delta"] = tactical_delta
		row["total_score"] = total_score
		row["reasons"] = _string_array(evaluation.get("reasons", []))
		row["penalties"] = _string_array(evaluation.get("penalties", []))
		row["opportunities"] = _dictionary_array(
			evaluation.get("opportunities", [])
		)
		rows.append(row)
		if not bool(evaluation.get("valid", false)):
			continue
		if (
			total_score > best_score
			or (
				is_equal_approx(total_score, best_score)
				and best_candidate != null
				and candidate.action_id < best_candidate.action_id
			)
		):
			best_candidate = candidate
			best_evaluation = evaluation
			best_score = total_score
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: float = float(a.get("total_score", -INF))
		var score_b: float = float(b.get("total_score", -INF))
		if not is_equal_approx(score_a, score_b):
			return score_a > score_b
		return str(a.get("action_id", "")) < str(b.get("action_id", ""))
	)
	var selected_id: String = ""
	var selected_name: String = "None"
	var primary_reason: String = "No valid tactical action"
	var opportunities: Array[Dictionary] = []
	if best_candidate != null:
		selected_id = best_candidate.action_id
		selected_name = best_candidate.display_name
		primary_reason = str(
			best_evaluation.get("primary_reason", "Highest tactical utility")
		)
		opportunities = _dictionary_array(
			best_evaluation.get("opportunities", [])
		)
	return {
		"selected_id": selected_id,
		"selected_name": selected_name,
		"selected_score": 0.0 if best_candidate == null else best_score,
		"selected_candidate": best_candidate,
		"reason": primary_reason,
		"opportunities": opportunities,
		"trace": rows,
		"snapshot": snapshot.duplicate(true),
	}


static func has_meaningful_opportunity(
	plan: Dictionary,
	minimum_tactical_score: float = 4.0
) -> bool:
	if str(plan.get("selected_id", "")) == "":
		return false
	var candidate_value: Variant = plan.get("selected_candidate", null)
	if not candidate_value is TacticalActionCandidate:
		return false
	var candidate: TacticalActionCandidate = candidate_value as TacticalActionCandidate
	var selected_score: float = float(plan.get("selected_score", 0.0))
	return (
		selected_score - candidate.base_score >= minimum_tactical_score
		and not _dictionary_array(plan.get("opportunities", [])).is_empty()
	)


static func summarize(plan: Dictionary) -> String:
	if str(plan.get("selected_id", "")) == "":
		return "No valid tactical action"
	return (
		str(plan.get("selected_name", plan.get("selected_id", "Action")))
		+ " | score="
		+ str(snappedf(float(plan.get("selected_score", 0.0)), 0.01))
		+ " | "
		+ str(plan.get("reason", "Highest tactical utility"))
	)


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append((raw as Dictionary).duplicate(true))
	return result


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "" and not result.has(text):
				result.append(text)
	return result
