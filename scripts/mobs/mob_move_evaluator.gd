extends RefCounted
class_name MobMoveEvaluator


static func evaluate_species(
	species_id: String,
	context_value: Variant,
	personality_overrides: Dictionary = {}
) -> Array[Dictionary]:
	var species: MobSpeciesDefinition = MobSpeciesCatalog.get_definition(species_id)
	if species == null:
		return []
	var context: MobDecisionContext = (
		context_value
		if context_value is MobDecisionContext
		else MobDecisionContext.from_dictionary(
			context_value as Dictionary if context_value is Dictionary else {}
		)
	)
	var personality: Dictionary = species.get_personality(personality_overrides)
	var rows: Array[Dictionary] = []
	for policy: MobMovePolicy in species.move_policies:
		if policy == null:
			continue
		var move: MobMoveDefinition = MobMoveCatalog.get_definition(policy.move_id)
		rows.append(_evaluate_policy(species, move, policy, context, personality))
	rows.sort_custom(_sort_rows)
	for index: int in range(rows.size()):
		rows[index]["rank"] = index + 1
	return rows


static func choose_move(
	species_id: String,
	context_value: Variant,
	personality_overrides: Dictionary = {}
) -> Dictionary:
	for row: Dictionary in evaluate_species(species_id, context_value, personality_overrides):
		if bool(row.get("eligible", false)):
			return row
	return {
		"species_id": species_id,
		"move_id": "",
		"eligible": false,
		"score": 0.0,
		"reasons": ["no eligible move"],
	}


static func _evaluate_policy(
	species: MobSpeciesDefinition,
	move: MobMoveDefinition,
	policy: MobMovePolicy,
	context: MobDecisionContext,
	personality: Dictionary
) -> Dictionary:
	var reasons: Array[String] = []
	var score_reasons: Array[String] = []
	if move == null:
		reasons.append("move definition missing")
		return _row(species, null, policy, false, 0.0, reasons, score_reasons)
	if not context.is_move_allowed(move.move_id):
		reasons.append("move is not equipped or allowed")
	if context.level < policy.minimum_level:
		reasons.append("requires level " + str(policy.minimum_level))
	if context.get_cooldown(move.move_id) > 0.0:
		reasons.append("cooldown active")
	if not move.supports_body(species.body_tags):
		reasons.append("body plan lacks " + ", ".join(move.required_body_tags))
	if context.self_health_ratio < policy.minimum_health_ratio:
		reasons.append("health below policy minimum")
	if context.self_health_ratio > policy.maximum_health_ratio:
		reasons.append("health above policy maximum")
	if context.ally_count < policy.minimum_allies or context.ally_count > policy.maximum_allies:
		reasons.append("ally count outside policy bounds")
	if context.enemy_count < policy.minimum_enemies or context.enemy_count > policy.maximum_enemies:
		reasons.append("enemy count outside policy bounds")
	var minimum_distance: float = policy.get_minimum_distance(move)
	var maximum_distance: float = policy.get_maximum_distance(move)
	if context.target_distance < minimum_distance or context.target_distance > maximum_distance:
		reasons.append(
			"target distance " + str(snappedf(context.target_distance, 0.1))
			+ " outside " + str(snappedf(minimum_distance, 0.1))
			+ "-" + str(snappedf(maximum_distance, 0.1))
		)
	_check_required_tags(policy.required_context_tags, context.context_tags, "context", reasons)
	_check_any_tags(policy.any_context_tags, context.context_tags, "context", reasons)
	_check_forbidden_tags(policy.forbidden_context_tags, context.context_tags, "context", reasons)
	_check_required_tags(policy.required_self_tags, context.self_tags, "self", reasons)
	_check_forbidden_tags(policy.forbidden_self_tags, context.self_tags, "self", reasons)
	_check_required_tags(policy.required_target_tags, context.target_tags, "target", reasons)
	_check_forbidden_tags(policy.forbidden_target_tags, context.target_tags, "target", reasons)

	var eligible: bool = reasons.is_empty()
	var score: float = 0.0
	if eligible:
		score = move.base_utility * policy.base_weight
		score_reasons.append(
			"base " + str(snappedf(move.base_utility, 0.01))
			+ " x policy " + str(snappedf(policy.base_weight, 0.01))
		)
		for raw_trait: Variant in policy.personality_weights.keys():
			var trait: String = str(raw_trait)
			var trait_value: float = clampf(float(personality.get(trait, 0.5)), 0.0, 1.0)
			var coefficient: float = float(policy.personality_weights[raw_trait])
			var delta: float = (trait_value - 0.5) * coefficient
			score += delta
			if not is_zero_approx(delta):
				score_reasons.append(trait + " " + _signed(delta))
		for raw_tag: Variant in policy.context_score_modifiers.keys():
			var tag: String = str(raw_tag)
			if context.has_context_tag(tag):
				var delta: float = float(policy.context_score_modifiers[raw_tag])
				score += delta
				score_reasons.append(tag + " " + _signed(delta))
		if context.recent_move_ids.has(move.move_id):
			score *= 0.68
			score_reasons.append("recent repetition x0.68")
		var urgency: float = context.get_scalar("urgency", 0.0)
		if urgency > 0.0 and (
			move.has_tag("survival")
			or move.has_tag("defense")
			or move.has_tag("attack")
		):
			score += urgency * 0.25
			score_reasons.append("urgency " + _signed(urgency * 0.25))
		score = maxf(score, 0.0)
	return _row(species, move, policy, eligible, score, reasons, score_reasons)


static func _row(
	species: MobSpeciesDefinition,
	move: MobMoveDefinition,
	policy: MobMovePolicy,
	eligible: bool,
	score: float,
	reasons: Array[String],
	score_reasons: Array[String]
) -> Dictionary:
	return {
		"species_id": species.species_id if species != null else "",
		"move_id": move.move_id if move != null else policy.move_id,
		"display_name": move.display_name if move != null else policy.move_id.capitalize(),
		"action_kind": move.action_kind if move != null else "none",
		"move_tags": move.tags.duplicate() if move != null else [],
		"policy_tags": policy.policy_tags.duplicate(),
		"eligible": eligible,
		"score": snappedf(score, 0.001),
		"reasons": reasons.duplicate(),
		"score_reasons": score_reasons.duplicate(),
		"move": move.to_dictionary() if move != null else {},
		"policy": policy.to_dictionary(),
	}


static func _check_required_tags(
	required: Array[String],
	available: Array[String],
	label: String,
	reasons: Array[String]
) -> void:
	for tag: String in required:
		if not available.has(tag):
			reasons.append(label + " missing required tag " + tag)


static func _check_any_tags(
	accepted: Array[String],
	available: Array[String],
	label: String,
	reasons: Array[String]
) -> void:
	if accepted.is_empty():
		return
	for tag: String in accepted:
		if available.has(tag):
			return
	reasons.append(label + " needs one of " + ", ".join(accepted))


static func _check_forbidden_tags(
	forbidden: Array[String],
	available: Array[String],
	label: String,
	reasons: Array[String]
) -> void:
	for tag: String in forbidden:
		if available.has(tag):
			reasons.append(label + " contains forbidden tag " + tag)


static func _sort_rows(a: Dictionary, b: Dictionary) -> bool:
	var a_eligible: bool = bool(a.get("eligible", false))
	var b_eligible: bool = bool(b.get("eligible", false))
	if a_eligible != b_eligible:
		return a_eligible
	var a_score: float = float(a.get("score", 0.0))
	var b_score: float = float(b.get("score", 0.0))
	if not is_equal_approx(a_score, b_score):
		return a_score > b_score
	return str(a.get("move_id", "")) < str(b.get("move_id", ""))


static func _signed(value: float) -> String:
	var snapped: float = snappedf(value, 0.01)
	return ("+" if snapped >= 0.0 else "") + str(snapped)
