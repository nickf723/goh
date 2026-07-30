extends Resource
class_name SquadRoleProfile


@export var role_id: String = "generalist"
@export var display_name: String = "Generalist"
@export_multiline var description: String = "Flexible squad member without a narrow tactical specialty."
@export_range(-10.0, 10.0, 0.25) var assignment_priority: float = 0.0
@export_range(1, 12, 1) var maximum_per_squad: int = 2
@export_range(0.0, 20.0, 0.25) var duplicate_penalty: float = 4.0

@export_group("Assignment Requirements")
@export var assignment_required_any_capabilities: Array[String] = []
@export var assignment_required_any_tags: Array[String] = []
@export var assignment_required_any_action_kinds: Array[String] = []

@export_group("Preferred Traits")
@export var preferred_capabilities: Array[String] = []
@export var preferred_tags: Array[String] = []
@export var preferred_opportunity_types: Array[String] = []
@export var preferred_action_kinds: Array[String] = []
@export var preferred_movement_modes: Array[String] = []

@export_group("Discouraged Traits")
@export var discouraged_capabilities: Array[String] = []
@export var discouraged_tags: Array[String] = []
@export var discouraged_opportunity_types: Array[String] = []

@export_group("Scoring")
@export_range(-10.0, 10.0, 0.25) var base_score_bias: float = 0.0
@export_range(0.0, 10.0, 0.25) var capability_bonus: float = 2.5
@export_range(0.0, 10.0, 0.25) var tag_bonus: float = 1.5
@export_range(0.0, 12.0, 0.25) var opportunity_bonus: float = 4.0
@export_range(0.0, 10.0, 0.25) var action_kind_bonus: float = 1.5
@export_range(0.0, 10.0, 0.25) var movement_bonus: float = 1.5
@export_range(0.0, 12.0, 0.25) var discouraged_penalty: float = 3.0


func evaluate_candidate(candidate: Variant, evaluation: Dictionary = {}) -> Dictionary:
	if candidate == null:
		return {
			"score": 0.0,
			"reasons": [],
			"penalties": [],
			"matched_traits": [],
		}
	var score: float = base_score_bias
	var reasons: Array[String] = []
	var penalties: Array[String] = []
	var matched_traits: Array[String] = []

	for capability: String in preferred_capabilities:
		if _candidate_has_capability(candidate, capability):
			score += capability_bonus
			_append_match(reasons, matched_traits, "Role favors " + _label(capability), "capability:" + _normalize(capability))
	for tag_name: String in preferred_tags:
		if _candidate_has_tag(candidate, tag_name):
			score += tag_bonus
			_append_match(reasons, matched_traits, "Role favors " + _label(tag_name), "tag:" + _normalize(tag_name))

	var action_kind: String = _candidate_string(candidate, "action_kind")
	if preferred_action_kinds.has(_normalize(action_kind)):
		score += action_kind_bonus
		_append_match(reasons, matched_traits, "Role favors " + _label(action_kind) + " actions", "kind:" + _normalize(action_kind))
	var movement_mode: String = _candidate_string(candidate, "movement_mode")
	if preferred_movement_modes.has(_normalize(movement_mode)):
		score += movement_bonus
		_append_match(reasons, matched_traits, "Role favors " + _label(movement_mode) + " movement", "movement:" + _normalize(movement_mode))

	for opportunity: Dictionary in _dictionary_array(evaluation.get("opportunities", [])):
		var type_id: String = _normalize(str(opportunity.get("type", "")))
		if preferred_opportunity_types.has(type_id):
			score += opportunity_bonus
			_append_match(reasons, matched_traits, "Role claims " + _label(type_id), "opportunity:" + type_id)
		if discouraged_opportunity_types.has(type_id):
			score -= discouraged_penalty
			_append_unique(penalties, "Role avoids " + _label(type_id))

	for capability: String in discouraged_capabilities:
		if _candidate_has_capability(candidate, capability):
			score -= discouraged_penalty
			_append_unique(penalties, "Role avoids " + _label(capability))
	for tag_name: String in discouraged_tags:
		if _candidate_has_tag(candidate, tag_name):
			score -= discouraged_penalty
			_append_unique(penalties, "Role avoids " + _label(tag_name))

	return {
		"score": score,
		"reasons": reasons,
		"penalties": penalties,
		"matched_traits": matched_traits,
	}


func is_assignment_eligible(candidates: Array) -> bool:
	if assignment_required_any_capabilities.is_empty() and assignment_required_any_tags.is_empty() and assignment_required_any_action_kinds.is_empty():
		return true
	for candidate: Variant in candidates:
		if candidate == null:
			continue
		for capability: String in assignment_required_any_capabilities:
			if _candidate_has_capability(candidate, capability):
				return true
		for tag_name: String in assignment_required_any_tags:
			if _candidate_has_tag(candidate, tag_name):
				return true
		if assignment_required_any_action_kinds.has(_normalize(_candidate_string(candidate, "action_kind"))):
			return true
	return false


func get_assignment_fit(candidates: Array) -> float:
	if not is_assignment_eligible(candidates):
		return -INF
	var best_fit: float = base_score_bias
	for candidate: Variant in candidates:
		if candidate == null:
			continue
		best_fit = maxf(best_fit, float(evaluate_candidate(candidate).get("score", 0.0)))
	return best_fit + assignment_priority


func validate_profile() -> Array[String]:
	var errors: Array[String] = []
	if _normalize(role_id) == "":
		errors.append("role_id must not be empty")
	if display_name.strip_edges() == "":
		errors.append("display_name must not be empty")
	if maximum_per_squad <= 0:
		errors.append("maximum_per_squad must be positive")
	return errors


func to_debug_data() -> Dictionary:
	return {
		"role_id": _normalize(role_id),
		"display_name": display_name,
		"description": description,
		"assignment_priority": assignment_priority,
		"maximum_per_squad": maximum_per_squad,
		"assignment_required_any_capabilities": assignment_required_any_capabilities.duplicate(),
		"assignment_required_any_tags": assignment_required_any_tags.duplicate(),
		"assignment_required_any_action_kinds": assignment_required_any_action_kinds.duplicate(),
		"preferred_capabilities": preferred_capabilities.duplicate(),
		"preferred_tags": preferred_tags.duplicate(),
		"preferred_opportunity_types": preferred_opportunity_types.duplicate(),
		"preferred_action_kinds": preferred_action_kinds.duplicate(),
		"preferred_movement_modes": preferred_movement_modes.duplicate(),
	}


func _candidate_has_capability(candidate: Variant, capability: String) -> bool:
	return candidate is Object and candidate.has_method("has_capability") and bool(candidate.call("has_capability", capability))


func _candidate_has_tag(candidate: Variant, tag_name: String) -> bool:
	return candidate is Object and candidate.has_method("has_tag") and bool(candidate.call("has_tag", tag_name))


func _candidate_string(candidate: Variant, property_name: String) -> String:
	if not candidate is Object:
		return ""
	return str(candidate.get(property_name))


func _append_match(reasons: Array[String], matched_traits: Array[String], reason: String, trait_id: String) -> void:
	_append_unique(reasons, reason)
	_append_unique(matched_traits, trait_id)


func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value:
			if raw is Dictionary:
				result.append((raw as Dictionary).duplicate(true))
	return result


func _append_unique(values: Array[String], value: String) -> void:
	if value != "" and not values.has(value):
		values.append(value)


func _normalize(value: String) -> String:
	return value.strip_edges().to_lower()


func _label(value: String) -> String:
	return _normalize(value).replace("_", " ")
