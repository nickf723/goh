extends RefCounted
class_name ReactionRuleCatalog


const LegacyRegistry = preload("res://scripts/systems/combo_rule_registry.gd")
const WaterExtinguishRule: Resource = preload(
	"res://data/combo_rules/water_extinguish_burning.tres"
)
const DeepChillFreezeRule: Resource = preload(
	"res://data/combo_rules/ice_deep_chill_freeze.tres"
)
const SoundRevealRule: Resource = preload(
	"res://data/combo_rules/sound_reveals_obscured.tres"
)
const ConductiveOverloadRule: Resource = preload(
	"res://data/combo_rules/lightning_overloads_conductive.tres"
)


static func get_rules() -> Array[Resource]:
	var rules: Array[Resource] = []
	for rule: Resource in LegacyRegistry.get_rules():
		if rule != null and not rules.has(rule):
			rules.append(rule)
	for rule: Resource in [
		WaterExtinguishRule,
		DeepChillFreezeRule,
		SoundRevealRule,
		ConductiveOverloadRule,
	]:
		if rule != null and not rules.has(rule):
			rules.append(rule)
	rules.sort_custom(_sort_rules)
	return rules


static func validate_catalog() -> Array[String]:
	var errors: Array[String] = []
	var seen_ids: Dictionary = {}
	for rule: Resource in get_rules():
		var rule_id: String = str(rule.get("rule_id"))
		if rule_id == "":
			errors.append("Reaction catalog contains a rule without rule_id.")
			continue
		if seen_ids.has(rule_id):
			errors.append("Duplicate reaction rule_id: " + rule_id)
		else:
			seen_ids[rule_id] = true
		if rule.has_method("validate_rule"):
			var result: Variant = rule.call("validate_rule")
			if result is Array:
				for raw_error: Variant in result as Array:
					errors.append(str(raw_error))
	return errors


static func get_debug_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for rule: Resource in get_rules():
		rows.append({
			"rule": str(rule.get("rule_id")),
			"reaction": str(rule.get("reaction_id")),
			"priority": int(rule.get("priority")),
			"exclusive_group": str(rule.get("exclusive_group")),
			"incoming_all": _string_array(rule.get("incoming_tags")),
			"incoming_any": _string_array(rule.get("incoming_any_tags")),
			"target_all": _string_array(rule.get("target_tags")),
			"target_statuses": _string_array(rule.get("target_statuses")),
			"consume_incoming_status": bool(rule.get("consume_incoming_status")),
		})
	return rows


static func _sort_rules(a: Resource, b: Resource) -> bool:
	var priority_a: int = int(a.get("priority")) if a != null else -999999
	var priority_b: int = int(b.get("priority")) if b != null else -999999
	if priority_a != priority_b:
		return priority_a > priority_b
	return str(a.get("rule_id")) < str(b.get("rule_id"))


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "":
				result.append(text)
	return result
