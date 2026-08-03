extends RefCounted
class_name MobIntentionResolver


static func choose_with_commitment(
	rows: Array[Dictionary],
	current_intention_id: String,
	score_tolerance: float = 0.35
) -> Dictionary:
	var best: Dictionary = _first_eligible(rows)
	if best.is_empty():
		return {}
	var normalized_intention: String = current_intention_id.to_lower().strip_edges()
	if normalized_intention == "":
		return _annotate(best, false, str(best.get("move_id", "")))
	var committed_candidate: Dictionary = {}
	for row: Dictionary in rows:
		if not bool(row.get("eligible", false)):
			continue
		if get_intention_id(row) == normalized_intention:
			committed_candidate = row
			break
	if committed_candidate.is_empty():
		return _annotate(best, false, str(best.get("move_id", "")))
	var best_score: float = float(best.get("score", 0.0))
	var committed_score: float = float(committed_candidate.get("score", 0.0))
	if committed_score + maxf(score_tolerance, 0.0) >= best_score:
		return _annotate(
			committed_candidate,
			true,
			str(best.get("move_id", ""))
		)
	return _annotate(best, false, str(best.get("move_id", "")))


static func get_intention_id(row: Dictionary) -> String:
	var policy_tags: Array[String] = _strings(row.get("policy_tags", []))
	var move_tags: Array[String] = _strings(row.get("move_tags", []))
	if (
		policy_tags.has("conditional_defense")
		or policy_tags.has("desperation_attack")
	):
		return "defend"
	if policy_tags.has("pack_support"):
		return "socialize"
	if policy_tags.has("survival"):
		return "survive"
	if move_tags.has("forage"):
		return "forage"
	if move_tags.has("retreat") or move_tags.has("survival"):
		return "survive"
	if (
		move_tags.has("social")
		or move_tags.has("support")
		or move_tags.has("pack")
	):
		return "socialize"
	if move_tags.has("habitat"):
		return "seek_habitat"
	if move_tags.has("recovery") or move_tags.has("calm"):
		return "recover"
	if move_tags.has("defense"):
		return "defend"
	if (
		move_tags.has("attack")
		or move_tags.has("control")
		or move_tags.has("gap_closer")
	):
		return "engage"
	if move_tags.has("ambient"):
		return "observe"
	var action_kind: String = str(row.get("action_kind", "")).to_lower().strip_edges()
	return action_kind if action_kind != "" else "idle"


static func _first_eligible(rows: Array[Dictionary]) -> Dictionary:
	for row: Dictionary in rows:
		if bool(row.get("eligible", false)):
			return row
	return {}


static func _annotate(
	row: Dictionary,
	retained: bool,
	uncommitted_best_move_id: String
) -> Dictionary:
	var result: Dictionary = row.duplicate(true)
	result["intention_id"] = get_intention_id(result)
	result["intention_retained"] = retained
	result["uncommitted_best_move_id"] = uncommitted_best_move_id
	return result


static func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).to_lower().strip_edges()
			if text != "" and not result.has(text):
				result.append(text)
	return result
