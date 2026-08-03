extends RefCounted
class_name MobDecisionContext

var target_distance: float = 0.0
var self_health_ratio: float = 1.0
var target_health_ratio: float = 1.0
var ally_count: int = 0
var enemy_count: int = 1
var level: int = 1
var context_tags: Array[String] = []
var self_tags: Array[String] = []
var target_tags: Array[String] = []
var allowed_move_ids: Array[String] = []
var recent_move_ids: Array[String] = []
var cooldowns: Dictionary = {}
var scalar_values: Dictionary = {}
var move_score_modifiers: Dictionary = {}
var tag_score_modifiers: Dictionary = {}
var policy_tag_score_modifiers: Dictionary = {}


static func from_dictionary(data: Dictionary) -> MobDecisionContext:
	var context := MobDecisionContext.new()
	context.target_distance = maxf(float(data.get("target_distance", 0.0)), 0.0)
	context.self_health_ratio = clampf(float(data.get("self_health_ratio", 1.0)), 0.0, 1.0)
	context.target_health_ratio = clampf(float(data.get("target_health_ratio", 1.0)), 0.0, 1.0)
	context.ally_count = maxi(int(data.get("ally_count", 0)), 0)
	context.enemy_count = maxi(int(data.get("enemy_count", 1)), 0)
	context.level = maxi(int(data.get("level", 1)), 1)
	context.context_tags = _string_array(data.get("context_tags", []))
	context.self_tags = _string_array(data.get("self_tags", []))
	context.target_tags = _string_array(data.get("target_tags", []))
	context.allowed_move_ids = _string_array(data.get("allowed_move_ids", []))
	context.recent_move_ids = _string_array(data.get("recent_move_ids", []))
	context.cooldowns = _number_dictionary(data.get("cooldowns", {}))
	context.scalar_values = _number_dictionary(data.get("scalar_values", {}))
	context.move_score_modifiers = _number_dictionary(data.get("move_score_modifiers", {}))
	context.tag_score_modifiers = _number_dictionary(data.get("tag_score_modifiers", {}))
	context.policy_tag_score_modifiers = _number_dictionary(data.get("policy_tag_score_modifiers", {}))
	return context


func has_context_tag(tag: String) -> bool:
	return context_tags.has(tag.to_lower().strip_edges())


func has_self_tag(tag: String) -> bool:
	return self_tags.has(tag.to_lower().strip_edges())


func has_target_tag(tag: String) -> bool:
	return target_tags.has(tag.to_lower().strip_edges())


func is_move_allowed(move_id: String) -> bool:
	return allowed_move_ids.is_empty() or allowed_move_ids.has(move_id)


func get_cooldown(move_id: String) -> float:
	return maxf(float(cooldowns.get(move_id, 0.0)), 0.0)


func get_scalar(key: String, fallback: float = 0.0) -> float:
	return float(scalar_values.get(key.to_lower().strip_edges(), fallback))


func get_move_score_modifier(move_id: String) -> float:
	return float(move_score_modifiers.get(move_id.to_lower().strip_edges(), 0.0))


func get_tag_score_modifier(tag: String) -> float:
	return float(tag_score_modifiers.get(tag.to_lower().strip_edges(), 0.0))


func get_policy_tag_score_modifier(tag: String) -> float:
	return float(policy_tag_score_modifiers.get(tag.to_lower().strip_edges(), 0.0))


func to_dictionary() -> Dictionary:
	return {
		"target_distance": target_distance,
		"self_health_ratio": self_health_ratio,
		"target_health_ratio": target_health_ratio,
		"ally_count": ally_count,
		"enemy_count": enemy_count,
		"level": level,
		"context_tags": context_tags.duplicate(),
		"self_tags": self_tags.duplicate(),
		"target_tags": target_tags.duplicate(),
		"allowed_move_ids": allowed_move_ids.duplicate(),
		"recent_move_ids": recent_move_ids.duplicate(),
		"cooldowns": cooldowns.duplicate(true),
		"scalar_values": scalar_values.duplicate(true),
		"move_score_modifiers": move_score_modifiers.duplicate(true),
		"tag_score_modifiers": tag_score_modifiers.duplicate(true),
		"policy_tag_score_modifiers": policy_tag_score_modifiers.duplicate(true),
	}


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
