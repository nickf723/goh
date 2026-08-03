extends Resource
class_name MobMovePolicy

@export var move_id: String = ""
@export var base_weight: float = 1.0
@export var minimum_health_ratio: float = 0.0
@export var maximum_health_ratio: float = 1.0
@export var minimum_target_distance: float = -1.0
@export var maximum_target_distance: float = -1.0
@export var minimum_allies: int = 0
@export var maximum_allies: int = 999
@export var minimum_enemies: int = 0
@export var maximum_enemies: int = 999
@export var minimum_level: int = 1
@export var required_context_tags: Array[String] = []
@export var any_context_tags: Array[String] = []
@export var forbidden_context_tags: Array[String] = []
@export var required_self_tags: Array[String] = []
@export var forbidden_self_tags: Array[String] = []
@export var required_target_tags: Array[String] = []
@export var forbidden_target_tags: Array[String] = []
@export var personality_weights: Dictionary = {}
@export var context_score_modifiers: Dictionary = {}
@export var policy_tags: Array[String] = []


static func from_dictionary(data: Dictionary) -> MobMovePolicy:
	var policy := MobMovePolicy.new()
	policy.move_id = str(data.get("move_id", data.get("id", ""))).strip_edges()
	policy.base_weight = maxf(float(data.get("base_weight", 1.0)), 0.0)
	policy.minimum_health_ratio = clampf(float(data.get("minimum_health_ratio", 0.0)), 0.0, 1.0)
	policy.maximum_health_ratio = clampf(float(data.get("maximum_health_ratio", 1.0)), policy.minimum_health_ratio, 1.0)
	policy.minimum_target_distance = float(data.get("minimum_target_distance", -1.0))
	policy.maximum_target_distance = float(data.get("maximum_target_distance", -1.0))
	policy.minimum_allies = maxi(int(data.get("minimum_allies", 0)), 0)
	policy.maximum_allies = maxi(int(data.get("maximum_allies", 999)), policy.minimum_allies)
	policy.minimum_enemies = maxi(int(data.get("minimum_enemies", 0)), 0)
	policy.maximum_enemies = maxi(int(data.get("maximum_enemies", 999)), policy.minimum_enemies)
	policy.minimum_level = maxi(int(data.get("minimum_level", 1)), 1)
	policy.required_context_tags = _string_array(data.get("required_context_tags", []))
	policy.any_context_tags = _string_array(data.get("any_context_tags", []))
	policy.forbidden_context_tags = _string_array(data.get("forbidden_context_tags", []))
	policy.required_self_tags = _string_array(data.get("required_self_tags", []))
	policy.forbidden_self_tags = _string_array(data.get("forbidden_self_tags", []))
	policy.required_target_tags = _string_array(data.get("required_target_tags", []))
	policy.forbidden_target_tags = _string_array(data.get("forbidden_target_tags", []))
	policy.personality_weights = _number_dictionary(data.get("personality_weights", {}))
	policy.context_score_modifiers = _number_dictionary(data.get("context_score_modifiers", {}))
	policy.policy_tags = _string_array(data.get("policy_tags", []))
	return policy


func duplicate_policy() -> MobMovePolicy:
	return MobMovePolicy.from_dictionary(to_dictionary())


func to_dictionary() -> Dictionary:
	return {
		"move_id": move_id,
		"base_weight": base_weight,
		"minimum_health_ratio": minimum_health_ratio,
		"maximum_health_ratio": maximum_health_ratio,
		"minimum_target_distance": minimum_target_distance,
		"maximum_target_distance": maximum_target_distance,
		"minimum_allies": minimum_allies,
		"maximum_allies": maximum_allies,
		"minimum_enemies": minimum_enemies,
		"maximum_enemies": maximum_enemies,
		"minimum_level": minimum_level,
		"required_context_tags": required_context_tags.duplicate(),
		"any_context_tags": any_context_tags.duplicate(),
		"forbidden_context_tags": forbidden_context_tags.duplicate(),
		"required_self_tags": required_self_tags.duplicate(),
		"forbidden_self_tags": forbidden_self_tags.duplicate(),
		"required_target_tags": required_target_tags.duplicate(),
		"forbidden_target_tags": forbidden_target_tags.duplicate(),
		"personality_weights": personality_weights.duplicate(true),
		"context_score_modifiers": context_score_modifiers.duplicate(true),
		"policy_tags": policy_tags.duplicate(),
	}


func get_minimum_distance(move: MobMoveDefinition) -> float:
	if minimum_target_distance >= 0.0:
		return minimum_target_distance
	return move.minimum_range if move != null else 0.0


func get_maximum_distance(move: MobMoveDefinition) -> float:
	var minimum: float = get_minimum_distance(move)
	if maximum_target_distance >= 0.0:
		return maxf(maximum_target_distance, minimum)
	return maxf(move.maximum_range, minimum) if move != null else minimum


func validate() -> Array[String]:
	var failures: Array[String] = []
	if move_id == "":
		failures.append("policy move id is empty")
	if maximum_health_ratio < minimum_health_ratio:
		failures.append(move_id + " policy has inverted health bounds")
	if maximum_allies < minimum_allies:
		failures.append(move_id + " policy has inverted ally bounds")
	if maximum_enemies < minimum_enemies:
		failures.append(move_id + " policy has inverted enemy bounds")
	return failures


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).to_lower().strip_edges()
			if text != "" and not result.has(text):
				result.append(text)
	return result


static func _number_dictionary(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if value is Dictionary:
		for raw_key: Variant in (value as Dictionary).keys():
			result[str(raw_key).to_lower().strip_edges()] = float((value as Dictionary)[raw_key])
	return result
