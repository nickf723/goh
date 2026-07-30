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


static func evaluate(
	candidate: TacticalActionCandidate,
	snapshot: Dictionary
) -> Dictionary:
	var result: Dictionary = BaseEvaluator.evaluate(candidate, snapshot)
	if candidate == null or not bool(result.get("valid", false)):
		return result
	var claimed_payoffs: Array[String] = _strings(
		snapshot.get(
			"claimed_payoff_reactions",
			snapshot.get("claimed_reactions", [])
		)
	)
	if claimed_payoffs.is_empty() or candidate.applies_states.is_empty():
		return result
	var claimed_setups: Array[String] = _strings(
		snapshot.get("claimed_setup_reactions", [])
	)
	var opportunities: Array[Dictionary] = _dictionary_array(
		result.get("opportunities", [])
	)
	var reasons: Array[String] = _strings_preserve_case(
		result.get("reasons", [])
	)
	var score: float = float(result.get("score", 0.0))
	for rule: Resource in ReactionCatalog.get_rules():
		if rule == null or not _candidate_sets_up_rule(candidate, rule):
			continue
		var reaction_id: String = str(rule.get("reaction_id")).to_lower()
		var rule_id: String = str(rule.get("rule_id")).to_lower()
		if not claimed_payoffs.has(reaction_id) and not claimed_payoffs.has(rule_id):
			continue
		if claimed_setups.has(reaction_id) or claimed_setups.has(rule_id):
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
	result["score"] = score
	result["reasons"] = reasons
	result["opportunities"] = opportunities
	if not reasons.is_empty():
		result["primary_reason"] = reasons[0]
	return result


static func _candidate_sets_up_rule(
	candidate: TacticalActionCandidate,
	rule: Resource
) -> bool:
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
