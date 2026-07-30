extends RefCounted
class_name TacticalOpportunityEvaluator


const ReactionCatalog = preload(
	"res://scripts/systems/reaction_rule_catalog.gd"
)
const StatePolicy = preload(
	"res://scripts/systems/reaction_state_policy.gd"
)

const REACTION_BASE_SCORE: float = 10.0
const SETUP_BASE_SCORE: float = 6.5
const RESERVED_PAYOFF_PENALTY: float = 18.0
const RESERVED_SETUP_PENALTY: float = 9.0
const PAIRED_SETUP_BONUS: float = 4.0
const REDUNDANT_STATE_PENALTY: float = 4.5
const FRIENDLY_FIRE_PENALTY: float = 18.0
const DANGER_APPROACH_PENALTY: float = 13.0
const DANGER_RETREAT_BONUS: float = 7.5
const LOW_HEALTH_DEFENSE_BONUS: float = 10.0
const EMERGENCY_DEFENSE_BONUS: float = 18.0
const OCCUPIED_LANE_PENALTY: float = 16.0


static func evaluate(
	candidate: TacticalActionCandidate,
	snapshot: Dictionary
) -> Dictionary:
	var reasons: Array[String] = []
	var penalties: Array[String] = []
	var opportunities: Array[Dictionary] = []
	var score: float = 0.0
	var valid: bool = candidate != null and candidate.affordable
	if candidate == null:
		return _result(false, -INF, ["Missing action candidate"], [], [])
	if not candidate.affordable:
		return _result(
			false,
			-INF,
			["Resources or cooldown make the action unavailable"],
			[],
			[]
		)

	var actor: Dictionary = _dictionary(snapshot.get("actor", {}))
	var target: Dictionary = _dictionary(snapshot.get("target", {}))
	var relation: String = str(snapshot.get("relation", "hostile")).to_lower()
	var target_statuses: Array[String] = _strings(target.get("statuses", []))
	var target_tags: Array[String] = _strings(target.get("tags", []))
	var claimed_reactions: Array[String] = _strings(
		snapshot.get("claimed_reactions", [])
	)
	var claimed_setup_reactions: Array[String] = _strings(
		snapshot.get("claimed_setup_reactions", [])
	)
	var claimed_payoff_reactions: Array[String] = _strings(
		snapshot.get("claimed_payoff_reactions", claimed_reactions)
	)

	for rule: Resource in ReactionCatalog.get_rules():
		if rule == null:
			continue
		if not _candidate_matches_rule(candidate, rule):
			continue
		if not _target_matches_rule(target_statuses, target_tags, rule):
			continue
		var reaction_id: String = str(rule.get("reaction_id"))
		var rule_id: String = str(rule.get("rule_id"))
		var priority: int = int(rule.get("priority"))
		var reaction_score: float = REACTION_BASE_SCORE + float(priority) * 0.035
		if (
			claimed_payoff_reactions.has(reaction_id)
			or claimed_payoff_reactions.has(rule_id)
		):
			reaction_score -= RESERVED_PAYOFF_PENALTY
			penalties.append("Squad payoff already reserved: " + reaction_id)
			valid = false
		elif claimed_reactions.has(reaction_id) or claimed_reactions.has(rule_id):
			reaction_score -= 6.0
			penalties.append("An ally already claimed " + reaction_id)
		if relation == "ally" and candidate.has_capability("damage"):
			reaction_score -= 4.0
		score += reaction_score
		reasons.append(
			"Exploit " + str(rule.get("reaction_name"))
			+ " on " + _describe_target_state(rule)
		)
		opportunities.append({
			"type": "reaction_payoff",
			"rule_id": rule_id,
			"reaction_id": reaction_id,
			"reaction_name": str(rule.get("reaction_name")),
			"score": reaction_score,
		})

	var preferred_tags: Array[String] = _strings(
		snapshot.get("preferred_payoff_tags", [])
	)
	_append_many(
		preferred_tags,
		_strings(snapshot.get("available_followup_tags", []))
	)
	_append_many(
		preferred_tags,
		_strings(snapshot.get("squad_intent_tags", []))
	)
	if not preferred_tags.is_empty():
		for rule: Resource in ReactionCatalog.get_rules():
			if rule == null:
				continue
			if not _candidate_sets_up_rule(candidate, rule):
				continue
			if not _tags_match_rule(preferred_tags, rule):
				continue
			var reaction_id: String = str(rule.get("reaction_id"))
			var rule_id: String = str(rule.get("rule_id"))
			var setup_score: float = (
				SETUP_BASE_SCORE + float(int(rule.get("priority"))) * 0.02
			)
			if (
				claimed_setup_reactions.has(reaction_id)
				or claimed_setup_reactions.has(rule_id)
			):
				setup_score -= RESERVED_SETUP_PENALTY
				penalties.append("Squad setup already reserved: " + reaction_id)
				valid = false
			elif (
				claimed_payoff_reactions.has(reaction_id)
				or claimed_payoff_reactions.has(rule_id)
			):
				setup_score += PAIRED_SETUP_BONUS
				reasons.append(
					"Complete the reserved "
					+ str(rule.get("reaction_name"))
					+ " plan"
				)
			score += setup_score
			reasons.append(
				"Set up " + str(rule.get("reaction_name"))
				+ " for the allied follow-up"
			)
			opportunities.append({
				"type": "reaction_setup",
				"rule_id": rule_id,
				"reaction_id": reaction_id,
				"reaction_name": str(rule.get("reaction_name")),
				"score": setup_score,
			})

	for state: String in candidate.applies_states:
		var normalized: String = StatePolicy.normalize_state(state)
		if target_statuses.has(normalized):
			score -= REDUNDANT_STATE_PENALTY
			penalties.append("Target already has " + normalized)

	var actor_health: float = float(actor.get("health_fraction", 1.0))
	if actor_health <= 0.2 and candidate.has_capability("defense"):
		score += EMERGENCY_DEFENSE_BONUS
		reasons.append("Emergency survival overrides the current squad plan")
		opportunities.append({
			"type": "emergency_override",
			"emergency_id": "critical_defense",
			"score": EMERGENCY_DEFENSE_BONUS,
		})
	elif actor_health <= 0.35:
		if candidate.has_capability("defense"):
			score += LOW_HEALTH_DEFENSE_BONUS
			reasons.append("Low health favors defense")
		elif (
			candidate.movement_mode == "away_from_target"
			or candidate.has_tag("retreat")
		):
			score += LOW_HEALTH_DEFENSE_BONUS * 0.8
			reasons.append("Low health favors retreat")
		elif candidate.has_capability("damage"):
			score -= 2.0
			penalties.append("Aggression is risky at low health")

	var target_id: int = int(target.get("instance_id", 0))
	var occupied_lanes: Array[String] = _strings(
		snapshot.get("occupied_engagement_lanes", [])
	)
	if _requires_approach(candidate) and _lane_is_occupied(
		occupied_lanes,
		"melee",
		target_id
	):
		score -= OCCUPIED_LANE_PENALTY
		penalties.append("The squad melee lane is already occupied")
		valid = false

	var path_danger: Dictionary = _dictionary(snapshot.get("path_danger", {}))
	var path_blocked: bool = bool(path_danger.get("blocked", false))
	var danger_count: int = int(path_danger.get("count", 0))
	if path_blocked or danger_count > 0:
		if _requires_approach(candidate):
			score -= DANGER_APPROACH_PENALTY
			penalties.append("Approach crosses dangerous terrain")
			if float(path_danger.get("maximum_severity", 0.0)) >= 1.0:
				valid = false
				penalties.append("Severe hazard vetoes direct approach")
		elif (
			candidate.movement_mode == "away_from_target"
			or candidate.has_tag("retreat")
		):
			score += DANGER_RETREAT_BONUS
			reasons.append("Retreat exits dangerous terrain")
		elif candidate.has_tag("ranged") or candidate.has_tag("projectile"):
			score += 2.0
			reasons.append("Ranged action avoids the hazardous route")

	if relation == "ally" and candidate.has_capability("damage"):
		score -= FRIENDLY_FIRE_PENALTY
		penalties.append("Damage action risks an ally")
		if opportunities.is_empty():
			valid = false

	var target_health: float = float(target.get("health_fraction", 1.0))
	if (
		relation == "hostile"
		and target_health <= 0.2
		and candidate.has_capability("damage")
	):
		score += 2.5
		reasons.append("Finish a weakened target")

	if opportunities.is_empty() and reasons.is_empty():
		reasons.append("No special tactical opportunity")
	return _result(valid, score, reasons, penalties, opportunities)


static func _candidate_matches_rule(
	candidate: TacticalActionCandidate,
	rule: Resource
) -> bool:
	return _tags_match_rule(candidate.incoming_tags, rule)


static func _tags_match_rule(tags: Array[String], rule: Resource) -> bool:
	for required: String in _property_strings(rule, "incoming_tags"):
		if not tags.has(required):
			return false
	var any_tags: Array[String] = _property_strings(rule, "incoming_any_tags")
	if not any_tags.is_empty() and not _contains_any(tags, any_tags):
		return false
	return true


static func _target_matches_rule(
	statuses: Array[String],
	tags: Array[String],
	rule: Resource
) -> bool:
	var combined: Array[String] = tags.duplicate()
	_append_many(combined, statuses)
	for required: String in _property_strings(rule, "target_tags"):
		if not combined.has(StatePolicy.normalize_state(required)):
			return false
	var any_tags: Array[String] = _property_strings(rule, "target_any_tags")
	if not any_tags.is_empty():
		var normalized_any: Array[String] = []
		for value: String in any_tags:
			_append_unique(normalized_any, StatePolicy.normalize_state(value))
		if not _contains_any(combined, normalized_any):
			return false
	for required: String in _property_strings(rule, "target_statuses"):
		if not statuses.has(StatePolicy.normalize_state(required)):
			return false
	var any_statuses: Array[String] = _property_strings(rule, "target_any_statuses")
	if not any_statuses.is_empty():
		var found_status: bool = false
		for value: String in any_statuses:
			if statuses.has(StatePolicy.normalize_state(value)):
				found_status = true
		if not found_status:
			return false
	for absent: String in _property_strings(rule, "required_absent_statuses"):
		if statuses.has(StatePolicy.normalize_state(absent)):
			return false
	return true


static func _candidate_sets_up_rule(
	candidate: TacticalActionCandidate,
	rule: Resource
) -> bool:
	if candidate.applies_states.is_empty():
		return false
	var required_states: Array[String] = []
	for property_name: String in [
		"target_tags", "target_any_tags", "target_statuses", "target_any_statuses"
	]:
		for value: String in _property_strings(rule, property_name):
			var normalized: String = StatePolicy.normalize_state(value)
			if StatePolicy.STATUS_ELEMENTS.has(normalized):
				_append_unique(required_states, normalized)
	for state: String in candidate.applies_states:
		if required_states.has(StatePolicy.normalize_state(state)):
			return true
	return false


static func _requires_approach(candidate: TacticalActionCandidate) -> bool:
	if candidate.movement_mode == "toward_target":
		return true
	if candidate.has_tag("melee") and not candidate.has_tag("projectile"):
		return true
	return candidate.maximum_distance <= 2.5


static func _lane_is_occupied(
	lanes: Array[String],
	lane_id: String,
	target_id: int
) -> bool:
	var exact: String = lane_id.strip_edges().to_lower() + "@" + str(target_id)
	for lane: String in lanes:
		var normalized: String = lane.strip_edges().to_lower()
		if normalized == exact:
			return true
		if target_id == 0 and normalized.begins_with(lane_id + "@"):
			return true
	return false


static func _describe_target_state(rule: Resource) -> String:
	var states: Array[String] = []
	for property_name: String in [
		"target_tags", "target_any_tags", "target_statuses", "target_any_statuses"
	]:
		for value: String in _property_strings(rule, property_name):
			_append_unique(states, StatePolicy.normalize_state(value))
	return "the target state" if states.is_empty() else ", ".join(states)


static func _result(
	valid: bool,
	score: float,
	reasons: Array[String],
	penalties: Array[String],
	opportunities: Array[Dictionary]
) -> Dictionary:
	return {
		"valid": valid,
		"score": score,
		"reasons": reasons,
		"penalties": penalties,
		"opportunities": opportunities,
		"primary_reason": reasons[0] if not reasons.is_empty() else (
			penalties[0] if not penalties.is_empty() else "No tactical read"
		),
	}


static func _property_strings(object: Object, property_name: String) -> Array[String]:
	var result: Array[String] = []
	if object == null:
		return result
	var value: Variant = object.get(property_name)
	if value is Array:
		for raw: Variant in value as Array:
			_append_unique(result, str(raw))
	return result


static func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _strings(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			_append_unique(result, str(raw))
	return result


static func _contains_any(values: Array[String], required: Array[String]) -> bool:
	for value: String in required:
		if values.has(value):
			return true
	return false


static func _append_many(target: Array[String], values: Array[String]) -> void:
	for value: String in values:
		_append_unique(target, value)


static func _append_unique(target: Array[String], value: String) -> void:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == "" or target.has(normalized):
		return
	target.append(normalized)
