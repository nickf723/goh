extends RefCounted
class_name MobMoveEvaluator


static func evaluate_species(
	species_id: String,
	context_value: Variant,
	personality_overrides: Dictionary = {}
) -> Array[Dictionary]:
	var species: MobSpeciesDefinition = MobSpeciesCatalog.get_definition(
		species_id
	)
	if species == null:
		return []
	var context: MobDecisionContext = _context_from_variant(context_value)
	var personality: Dictionary = species.get_personality(
		personality_overrides
	)
	var rows: Array[Dictionary] = []
	for policy: MobMovePolicy in species.move_policies:
		if policy == null:
			continue
		var move: MobMoveDefinition = MobMoveCatalog.get_definition(
			policy.move_id
		)
		rows.append(
			_evaluate_policy(
				species,
				move,
				policy,
				context,
				personality
			)
		)
	rows.sort_custom(_sort_rows)
	for index: int in range(rows.size()):
		rows[index]["rank"] = index + 1
	return rows


static func choose_move(
	species_id: String,
	context_value: Variant,
	personality_overrides: Dictionary = {}
) -> Dictionary:
	var rows: Array[Dictionary] = evaluate_species(
		species_id,
		context_value,
		personality_overrides
	)
	for row: Dictionary in rows:
		if bool(row.get("eligible", false)):
			return row
	return {
		"species_id": species_id,
		"move_id": "",
		"eligible": false,
		"score": 0.0,
		"reasons": ["no eligible move"],
	}


static func _context_from_variant(value: Variant) -> MobDecisionContext:
	if value is MobDecisionContext:
		return value as MobDecisionContext
	if value is Dictionary:
		return MobDecisionContext.from_dictionary(value as Dictionary)
	return MobDecisionContext.from_dictionary({})


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
		return _row(
			species,
			null,
			policy,
			false,
			0.0,
			reasons,
			score_reasons
		)

	if not context.is_move_allowed(move.move_id):
		reasons.append("move is not equipped or allowed")
	if context.level < policy.minimum_level:
		reasons.append("requires level " + str(policy.minimum_level))
	if context.get_cooldown(move.move_id) > 0.0:
		reasons.append("cooldown active")
	if not move.supports_body(species.body_tags):
		reasons.append(
			"body plan lacks " + ", ".join(move.required_body_tags)
		)
	if not move.supports_locomotion(
		species.body_tags,
		species.locomotion_tags
	):
		reasons.append(
			"locomotion profile lacks "
			+ ", ".join(move.required_locomotion_tags)
		)
	if context.self_health_ratio < policy.minimum_health_ratio:
		reasons.append("health below policy minimum")
	if context.self_health_ratio > policy.maximum_health_ratio:
		reasons.append("health above policy maximum")
	if (
		context.ally_count < policy.minimum_allies
		or context.ally_count > policy.maximum_allies
	):
		reasons.append("ally count outside policy bounds")
	if (
		context.enemy_count < policy.minimum_enemies
		or context.enemy_count > policy.maximum_enemies
	):
		reasons.append("enemy count outside policy bounds")

	var minimum_distance: float = policy.get_minimum_distance(move)
	var maximum_distance: float = policy.get_maximum_distance(move)
	if (
		context.target_distance < minimum_distance
		or context.target_distance > maximum_distance
	):
		reasons.append(
			"target distance "
			+ str(snappedf(context.target_distance, 0.1))
			+ " outside "
			+ str(snappedf(minimum_distance, 0.1))
			+ "-"
			+ str(snappedf(maximum_distance, 0.1))
		)

	_check_required_tags(
		policy.required_context_tags,
		context.context_tags,
		"context",
		reasons
	)
	_check_any_tags(
		policy.any_context_tags,
		context.context_tags,
		"context",
		reasons
	)
	_check_forbidden_tags(
		policy.forbidden_context_tags,
		context.context_tags,
		"context",
		reasons
	)
	_check_required_tags(
		policy.required_self_tags,
		context.self_tags,
		"self",
		reasons
	)
	_check_forbidden_tags(
		policy.forbidden_self_tags,
		context.self_tags,
		"self",
		reasons
	)
	_check_required_tags(
		policy.required_target_tags,
		context.target_tags,
		"target",
		reasons
	)
	_check_forbidden_tags(
		policy.forbidden_target_tags,
		context.target_tags,
		"target",
		reasons
	)

	var eligible: bool = reasons.is_empty()
	var score: float = 0.0
	if eligible:
		score = move.base_utility * policy.base_weight
		score_reasons.append(
			"base "
			+ str(snappedf(move.base_utility, 0.01))
			+ " x policy "
			+ str(snappedf(policy.base_weight, 0.01))
		)

		for raw_trait: Variant in policy.personality_weights.keys():
			var trait_id: String = str(raw_trait)
			var trait_value: float = clampf(
				float(personality.get(trait_id, 0.5)),
				0.0,
				1.0
			)
			var trait_coefficient: float = float(
				policy.personality_weights[raw_trait]
			)
			var trait_delta: float = (
				trait_value - 0.5
			) * trait_coefficient
			score += trait_delta
			if not is_zero_approx(trait_delta):
				score_reasons.append(
					trait_id + " " + _signed(trait_delta)
				)

		for raw_context_tag: Variant in (
			policy.context_score_modifiers.keys()
		):
			var context_tag: String = str(raw_context_tag)
			if context.has_context_tag(context_tag):
				var context_delta: float = float(
					policy.context_score_modifiers[raw_context_tag]
				)
				score += context_delta
				score_reasons.append(
					context_tag + " " + _signed(context_delta)
				)

		var direct_modifier: float = context.get_move_score_modifier(move.move_id)
		if not is_zero_approx(direct_modifier):
			score += direct_modifier
			score_reasons.append(
				"move modifier " + _signed(direct_modifier)
			)
		for move_tag: String in move.tags:
			var tag_modifier: float = context.get_tag_score_modifier(move_tag)
			if is_zero_approx(tag_modifier):
				continue
			score += tag_modifier
			score_reasons.append(
				"tag " + move_tag + " " + _signed(tag_modifier)
			)
		for policy_tag: String in policy.policy_tags:
			var policy_modifier: float = context.get_policy_tag_score_modifier(
				policy_tag
			)
			if is_zero_approx(policy_modifier):
				continue
			score += policy_modifier
			score_reasons.append(
				"policy " + policy_tag + " " + _signed(policy_modifier)
			)

		if context.recent_move_ids.has(move.move_id):
			score *= 0.68
			score_reasons.append("recent repetition x0.68")

		var urgency_value: float = context.get_scalar("urgency", 0.0)
		if urgency_value > 0.0 and _move_responds_to_urgency(move):
			var urgency_delta: float = urgency_value * 0.25
			score += urgency_delta
			score_reasons.append(
				"urgency " + _signed(urgency_delta)
			)
		score = maxf(score, 0.0)

	return _row(
		species,
		move,
		policy,
		eligible,
		score,
		reasons,
		score_reasons
	)


static func _move_responds_to_urgency(move: MobMoveDefinition) -> bool:
	return (
		move.has_tag("survival")
		or move.has_tag("defense")
		or move.has_tag("attack")
	)


static func _row(
	species: MobSpeciesDefinition,
	move: MobMoveDefinition,
	policy: MobMovePolicy,
	eligible: bool,
	score: float,
	reasons: Array[String],
	score_reasons: Array[String]
) -> Dictionary:
	var species_id: String = ""
	if species != null:
		species_id = species.species_id
	var move_id: String = policy.move_id
	var display_name: String = policy.move_id.capitalize()
	var action_kind: String = "none"
	var move_tags: Array[String] = []
	var move_data: Dictionary = {}
	if move != null:
		move_id = move.move_id
		display_name = move.display_name
		action_kind = move.action_kind
		move_tags = move.tags.duplicate()
		move_data = move.to_dictionary()
	return {
		"species_id": species_id,
		"move_id": move_id,
		"display_name": display_name,
		"action_kind": action_kind,
		"move_tags": move_tags,
		"policy_tags": policy.policy_tags.duplicate(),
		"eligible": eligible,
		"score": snappedf(score, 0.001),
		"reasons": reasons.duplicate(),
		"score_reasons": score_reasons.duplicate(),
		"move": move_data,
		"policy": policy.to_dictionary(),
	}


static func _check_required_tags(
	required: Array[String],
	available: Array[String],
	label: String,
	reasons: Array[String]
) -> void:
	for required_tag: String in required:
		if not available.has(required_tag):
			reasons.append(
				label + " missing required tag " + required_tag
			)


static func _check_any_tags(
	accepted: Array[String],
	available: Array[String],
	label: String,
	reasons: Array[String]
) -> void:
	if accepted.is_empty():
		return
	for accepted_tag: String in accepted:
		if available.has(accepted_tag):
			return
	reasons.append(
		label + " needs one of " + ", ".join(accepted)
	)


static func _check_forbidden_tags(
	forbidden: Array[String],
	available: Array[String],
	label: String,
	reasons: Array[String]
) -> void:
	for forbidden_tag: String in forbidden:
		if available.has(forbidden_tag):
			reasons.append(
				label + " contains forbidden tag " + forbidden_tag
			)


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
	var rounded_value: float = snappedf(value, 0.01)
	var prefix: String = "+" if rounded_value >= 0.0 else ""
	return prefix + str(rounded_value)
