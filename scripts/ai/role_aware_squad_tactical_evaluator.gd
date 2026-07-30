extends RefCounted
class_name RoleAwareSquadTacticalEvaluator


const BaseEvaluator = preload("res://scripts/ai/squad_tactical_opportunity_evaluator.gd")
const RoleCatalog = preload("res://scripts/ai/squad_role_catalog.gd")


static func evaluate(candidate: Variant, snapshot: Dictionary) -> Dictionary:
	var result: Dictionary = BaseEvaluator.evaluate(candidate, snapshot)
	if candidate == null or not bool(result.get("valid", false)):
		return result
	var role_id: String = str(snapshot.get("squad_role_id", "generalist"))
	var role_result: Dictionary = RoleCatalog.evaluate_candidate(role_id, candidate, result)
	var role_score: float = float(role_result.get("score", 0.0))
	var reasons: Array[String] = _strings_preserve_case(result.get("reasons", []))
	var penalties: Array[String] = _strings_preserve_case(result.get("penalties", []))
	var role_reasons: Array[String] = _strings_preserve_case(role_result.get("reasons", []))
	var role_penalties: Array[String] = _strings_preserve_case(role_result.get("penalties", []))
	_append_many(reasons, role_reasons)
	_append_many(penalties, role_penalties)
	var opportunities: Array[Dictionary] = _dictionary_array(result.get("opportunities", []))
	var matched_traits: Array[String] = _strings_preserve_case(role_result.get("matched_traits", []))
	if not is_zero_approx(role_score) or not matched_traits.is_empty():
		opportunities.append({
			"type": "squad_role_alignment",
			"role_id": str(role_result.get("role_id", "generalist")),
			"role_name": str(role_result.get("role_name", "Generalist")),
			"score": role_score,
			"matched_traits": matched_traits,
		})
	result["score"] = float(result.get("score", 0.0)) + role_score
	result["reasons"] = reasons
	result["penalties"] = penalties
	result["opportunities"] = opportunities
	result["squad_role_id"] = str(role_result.get("role_id", "generalist"))
	result["squad_role_name"] = str(role_result.get("role_name", "Generalist"))
	result["squad_role_score"] = role_score
	if not role_reasons.is_empty():
		result["primary_reason"] = role_reasons[0]
	elif not reasons.is_empty():
		result["primary_reason"] = reasons[0]
	elif not penalties.is_empty():
		result["primary_reason"] = penalties[0]
	return result


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value:
			if raw is Dictionary:
				result.append((raw as Dictionary).duplicate(true))
	return result


static func _strings_preserve_case(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value:
			var text: String = str(raw)
			if text != "" and not result.has(text):
				result.append(text)
	return result


static func _append_many(target: Array[String], values: Array[String]) -> void:
	for value: String in values:
		if value != "" and not target.has(value):
			target.append(value)
