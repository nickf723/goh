extends RefCounted
class_name RoleAwareTargetEvaluator


static func evaluate(
	candidate: Dictionary,
	claim_context: Dictionary,
	role_id: String,
	options: Dictionary = {}
) -> Dictionary:
	if candidate.is_empty() or bool(candidate.get("defeated", true)):
		return {
			"valid": false,
			"score": -INF,
			"reasons": [],
			"penalties": ["Target is unavailable"],
		}
	var normalized_role: String = role_id.strip_edges().to_lower()
	var score: float = 0.0
	var reasons: Array[String] = []
	var penalties: Array[String] = []
	var distance: float = float(candidate.get("distance", 999.0))
	var preferred_distance: float = float(options.get("preferred_distance", 3.0))
	var distance_span: float = maxf(float(options.get("distance_span", 10.0)), 0.1)
	var distance_fit: float = 1.0 - clampf(
		absf(distance - preferred_distance) / distance_span,
		0.0,
		1.0
	)
	score += distance_fit * 4.0
	if distance_fit >= 0.75:
		reasons.append("Target sits in a useful action window")

	var health_fraction: float = clampf(float(candidate.get("health_fraction", 1.0)), 0.0, 1.0)
	var current_health: float = maxf(float(candidate.get("current_health", 1)), 1.0)
	score += (1.0 - health_fraction) * 3.5
	if health_fraction <= 0.35:
		reasons.append("Target is close to defeat")

	var expected_damage: float = float(claim_context.get("expected_damage", 0.0))
	var overkill_margin: float = expected_damage - current_health
	if expected_damage >= current_health:
		var overkill_penalty: float = maxf(float(options.get("overkill_penalty", 18.0)), 0.0)
		score -= overkill_penalty + maxf(overkill_margin, 0.0) * 0.35
		penalties.append("Squad damage already covers this target")
	elif expected_damage > current_health * 0.65:
		score -= 5.0
		penalties.append("Target is close to its committed damage budget")

	var owner_count: int = int(claim_context.get("owner_count", 0))
	var attention_penalty: float = float(options.get("attention_penalty", 1.7))
	if owner_count > 0:
		score -= float(owner_count) * maxf(attention_penalty, 0.0)
		penalties.append(str(owner_count) + " squadmate(s) already committed")

	var statuses: Array[String] = _string_array(candidate.get("statuses", []))
	var claimed_control_tags: Array[String] = _string_array(
		claim_context.get("control_tags", [])
	)
	var has_wet: bool = statuses.has("wet")
	var wet_claimed: bool = claimed_control_tags.has("wet")
	var target_blocked: bool = bool(candidate.get("action_blocked", false))

	match normalized_role:
		"primer":
			if not has_wet and not wet_claimed:
				score += 9.0
				reasons.append("Primer can create a fresh Wet setup")
			else:
				score -= 7.0
				penalties.append("Wet setup is already present or claimed")
			if int(claim_context.get("setup_count", 0)) > 0:
				score -= 5.0
				penalties.append("Another setup claim already owns this target")
		"payoff_specialist":
			if has_wet:
				score += 13.0
				reasons.append("Wet target exposes a Lightning payoff")
			elif wet_claimed or int(claim_context.get("setup_count", 0)) > 0:
				score += 9.0
				reasons.append("Payoff follows an allied setup claim")
			else:
				score -= 4.0
				penalties.append("No prepared payoff state")
			if int(claim_context.get("payoff_count", 0)) > 0:
				score -= 8.0
				penalties.append("Another payoff specialist already owns this target")
		"protector":
			if bool(candidate.get("is_player", false)):
				score += 2.0
				reasons.append("Primary aggressor remains a useful pressure target")
			if owner_count >= 2:
				score -= 4.0
				penalties.append("Protector avoids joining a crowded target")
		"disruptor":
			if target_blocked:
				score -= 10.0
				penalties.append("Target is already action-blocked")
			elif int(claim_context.get("control_count", 0)) <= 0:
				score += 7.0
				reasons.append("Dangerous target has no control claim")
			else:
				score -= 6.0
				penalties.append("Control is already assigned")
		"skirmisher":
			var melee_count: int = int(claim_context.get("melee_count", 0))
			if melee_count <= 0:
				score += 5.0
				reasons.append("Skirmisher finds an open pressure lane")
			else:
				score -= float(melee_count) * 5.0
				penalties.append("Melee pressure is already crowded")
			if distance >= 2.5 and distance <= 9.0:
				score += 3.0
				reasons.append("Target supports mobile harassment")
		_:
			pass

	var focus_target_id: int = int(options.get("focus_fire_target_id", 0))
	if focus_target_id > 0 and int(candidate.get("target_id", 0)) == focus_target_id:
		score += maxf(float(options.get("focus_fire_bonus", 100.0)), 0.0)
		reasons.append("Authored focus-fire override")

	return {
		"valid": true,
		"score": score,
		"reasons": reasons,
		"penalties": penalties,
		"primary_reason": (
			reasons[0]
			if not reasons.is_empty()
			else penalties[0] if not penalties.is_empty() else "Closest useful target"
		),
		"overkill": expected_damage >= current_health,
		"expected_damage": expected_damage,
		"owner_count": owner_count,
	}


static func choose_best(
	candidates: Array[Dictionary],
	contexts: Dictionary,
	role_id: String,
	options: Dictionary = {}
) -> Dictionary:
	var trace: Array[Dictionary] = []
	var best: Dictionary = {}
	var best_score: float = -INF
	for candidate: Dictionary in candidates:
		var target_id: int = int(candidate.get("target_id", 0))
		var context_value: Variant = contexts.get(target_id, {})
		var context: Dictionary = (
			(context_value as Dictionary).duplicate(true)
			if context_value is Dictionary
			else {}
		)
		var evaluation: Dictionary = evaluate(candidate, context, role_id, options)
		var row: Dictionary = candidate.duplicate(true)
		row.erase("target_ref")
		row["claim_context"] = context
		row["valid"] = bool(evaluation.get("valid", false))
		row["score"] = float(evaluation.get("score", -INF))
		row["reasons"] = evaluation.get("reasons", [])
		row["penalties"] = evaluation.get("penalties", [])
		row["reason"] = str(evaluation.get("primary_reason", "No target read"))
		trace.append(row)
		if not bool(evaluation.get("valid", false)):
			continue
		var score: float = float(evaluation.get("score", -INF))
		if score > best_score or (
			is_equal_approx(score, best_score)
			and int(candidate.get("target_id", 0)) < int(best.get("target_id", 2147483647))
		):
			best_score = score
			best = candidate.duplicate()
			best["target_score"] = score
			best["target_reason"] = str(evaluation.get("primary_reason", "Target selected"))
	trace.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var score_a: float = float(a.get("score", -INF))
		var score_b: float = float(b.get("score", -INF))
		if not is_equal_approx(score_a, score_b):
			return score_a > score_b
		return int(a.get("target_id", 0)) < int(b.get("target_id", 0))
	)
	return {
		"selected": best,
		"selected_id": int(best.get("target_id", 0)),
		"selected_name": str(best.get("target_name", "none")),
		"selected_score": best_score if not best.is_empty() else -INF,
		"reason": str(best.get("target_reason", "No target selected")),
		"trace": trace,
	}


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).strip_edges().to_lower()
			if text != "" and not result.has(text):
				result.append(text)
	return result
