extends RefCounted
class_name SquadTacticalOpportunityEvaluator


const BaseEvaluator = preload(
	"res://scripts/ai/tactical_opportunity_evaluator.gd"
)
const ReactionCatalog = preload(
	"res://scripts/systems/reaction_rule_catalog.gd"
)
const StatePolicy = preload(
	"res://scripts/systems/reaction_state_policy.gd"
)

const RESERVED_PAYOFF_SETUP_BONUS: float = 10.5
const RESERVED_SETUP_VETO_PENALTY: float = 18.0
const PROTECTED_STATE_VETO_PENALTY: float = 22.0
const COVER_RESPONSE_BONUS: float = 6.0


static func evaluate(
	candidate: TacticalActionCandidate,
	snapshot: Dictionary
) -> Dictionary:
	if candidate == null:
		return BaseEvaluator.evaluate(candidate, snapshot)
	var original_maximum_distance: float = candidate.maximum_distance
	if _is_non_approach_action(candidate):
		candidate.maximum_distance = maxf(candidate.maximum_distance, 3.0)
	var result: Dictionary = BaseEvaluator.evaluate(candidate, snapshot)
	candidate.maximum_distance = original_maximum_distance
	if not bool(result.get("valid", false)):
		return result

	var claimed_setups: Array[String] = _strings(
		snapshot.get("claimed_setup_reactions", [])
	)
	var claimed_payoffs: Array[String] = _strings(
		snapshot.get(
			"claimed_payoff_reactions",
			snapshot.get("claimed_reactions", [])
		)
	)
	var opportunities: Array[Dictionary] = _dictionary_array(
		result.get("opportunities", [])
	)
	var reasons: Array[String] = _strings_preserve_case(
		result.get("reasons", [])
	)
	var penalties: Array[String] = _strings_preserve_case(
		result.get("penalties", [])
	)
	var score: float = float(result.get("score", 0.0))
	var valid: bool = bool(result.get("valid", true))

	var protected_states: Array[String] = _get_protected_states(
		claimed_payoffs
	)
	var disrupted_state: String = _find_disrupted_protected_state(
		candidate,
		opportunities,
		protected_states
	)
	if disrupted_state != "":
		score -= PROTECTED_STATE_VETO_PENALTY
		penalties.append(
			"Squad payoff protects " + disrupted_state
		)
		valid = false

	if not candidate.applies_states.is_empty():
		for rule: Resource in ReactionCatalog.get_rules():
			if rule == null or not _candidate_sets_up_rule(candidate, rule):
				continue
			var reaction_id: String = str(
				rule.get("reaction_id")
			).to_lower()
			var rule_id: String = str(rule.get("rule_id")).to_lower()
			if claimed_setups.has(reaction_id) or claimed_setups.has(rule_id):
				score -= RESERVED_SETUP_VETO_PENALTY
				penalties.append(
					"Squad setup already reserved: " + reaction_id
				)
				valid = false
				continue
			if claimed_payoffs.is_empty():
				continue
			if (
				not claimed_payoffs.has(reaction_id)
				and not claimed_payoffs.has(rule_id)
			):
				continue
			if _has_rule_opportunity(opportunities, rule_id):
				continue
			var bonus: float = (
				RESERVED_PAYOFF_SETUP_BONUS
				+ float(int(rule.get("priority"))) * 0.02
			)
			score += bonus
			reasons.append(
				"Complete the reserved "
				+ str(rule.get("reaction_name"))
				+ " plan"
			)
			opportunities.append({
				"type": "reaction_setup",
				"rule_id": rule_id,
				"reaction_id": reaction_id,
				"reaction_name": str(rule.get("reaction_name")),
				"score": bonus,
				"paired_reservation": true,
			})

	var squad_intent_tags: Array[String] = _strings(
		snapshot.get("squad_intent_tags", [])
	)
	if squad_intent_tags.has("cover_requested") and _can_provide_cover(
		candidate
	):
		score += COVER_RESPONSE_BONUS
		reasons.append("Cover an ally's withdrawal")
		opportunities.append({
			"type": "cover_response",
			"score": COVER_RESPONSE_BONUS,
		})

	result["valid"] = valid
	result["score"] = score
	result["reasons"] = reasons
	result["penalties"] = penalties
	result["opportunities"] = opportunities
	if not reasons.is_empty():
		result["primary_reason"] = reasons[0]
	elif not penalties.is_empty():
		result["primary_reason"] = penalties[0]
	return result


static func _get_protected_states(
	claimed_payoffs: Array[String]
) -> Array[String]:
	var protected: Array[String] = []
	if claimed_payoffs.is_empty():
		return protected
	for rule: Resource in ReactionCatalog.get_rules():
		if rule == null:
			continue
		var reaction_id: String = str(
			rule.get("reaction_id")
		).to_lower()
		var rule_id: String = str(rule.get("rule_id")).to_lower()
		if (
			not claimed_payoffs.has(reaction_id)
			and not claimed_payoffs.has(rule_id)
		):
			continue
		for state: String in _get_rule_required_states(rule):
			_append_unique(protected, state)
	return protected


static func _find_disrupted_protected_state(
	candidate: TacticalActionCandidate,
	opportunities: Array[Dictionary],
	protected_states: Array[String]
) -> String:
	if protected_states.is_empty():
		return ""
	for state: String in candidate.applies_states:
		for conflict: String in StatePolicy.get_conflicts_for(state):
			if protected_states.has(conflict):
				return conflict
	for opportunity: Dictionary in opportunities:
		var rule: Resource = _find_rule(
			str(opportunity.get("rule_id", "")),
			str(opportunity.get("reaction_id", ""))
		)
		if rule == null:
			continue
		for removed: String in _property_strings(rule, "remove_statuses"):
			var normalized_removed: String = StatePolicy.normalize_state(
				removed
			)
			if protected_states.has(normalized_removed):
				return normalized_removed
		var output_state: String = StatePolicy.normalize_state(
			str(rule.get("output_status"))
		)
		if output_state != "":
			for conflict: String in StatePolicy.get_conflicts_for(output_state):
				if protected_states.has(conflict):
					return conflict
	return ""


static func _find_rule(
	rule_id: String,
	reaction_id: String
) -> Resource:
	var normalized_rule: String = rule_id.strip_edges().to_lower()
	var normalized_reaction: String = reaction_id.strip_edges().to_lower()
	for rule: Resource in ReactionCatalog.get_rules():
		if rule == null:
			continue
		if (
			str(rule.get("rule_id")).to_lower() == normalized_rule
			or str(rule.get("reaction_id")).to_lower()
			== normalized_reaction
		):
			return rule
	return null


static func _get_rule_required_states(rule: Resource) -> Array[String]:
	var required_states: Array[String] = []
	for property_name: String in [
		"target_tags",
		"target_any_tags",
		"target_statuses",
		"target_any_statuses",
	]:
		for value: String in _property_strings(rule, property_name):
			var normalized: String = StatePolicy.normalize_state(value)
			if StatePolicy.STATUS_ELEMENTS.has(normalized):
				_append_unique(required_states, normalized)
	return required_states


static func _can_provide_cover(
	candidate: TacticalActionCandidate
) -> bool:
	return (
		candidate.has_tag("ranged")
		or candidate.has_tag("projectile")
		or candidate.has_capability("control")
		or candidate.action_kind == "support"
	)


static func _is_non_approach_action(
	candidate: TacticalActionCandidate
) -> bool:
	return (
		candidate.action_kind in ["defense", "support"]
		or candidate.movement_mode == "away_from_target"
		or candidate.has_tag("retreat")
	)


static func _candidate_sets_up_rule(
	candidate: TacticalActionCandidate,
	rule: Resource
) -> bool:
	var required_states: Array[String] = _get_rule_required_states(rule)
	for state: String in candidate.applies_states:
		if required_states.has(StatePolicy.normalize_state(state)):
			return true
	return false


static func _has_rule_opportunity(
	opportunities: Array[Dictionary],
	rule_id: String
) -> bool:
	for opportunity: Dictionary in opportunities:
		if str(opportunity.get("rule_id", "")).to_lower() == rule_id:
			return true
	return false


static func _property_strings(
	object: Object,
	property_name: String
) -> Array[String]:
	var result: Array[String] = []
	if object == null:
		return result
	var value: Variant = object.get(property_name)
	if value is Array:
		for raw: Variant in value as Array:
			_append_unique(result, str(raw))
	return result


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append((raw as Dictionary).duplicate(true))
	return result


static func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			_append_unique(result, str(raw))
	return result


static func _strings_preserve_case(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "" and not result.has(text):
				result.append(text)
	return result


static func _append_unique(target: Array[String], value: String) -> void:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == "" or target.has(normalized):
		return
	target.append(normalized)
