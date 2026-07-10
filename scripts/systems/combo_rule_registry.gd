extends Node
class_name ComboRuleRegistry

const IgniteOilyRule: Resource = preload("res://data/combo_rules/ignite_oily_target.tres")
const WetConductionRule: Resource = preload("res://data/combo_rules/wet_conduction.tres")
const WetFreezeRule: Resource = preload("res://data/combo_rules/wet_freeze.tres")
const FrozenShatterRule: Resource = preload("res://data/combo_rules/frozen_shatter.tres")


static func resolve_payload_reactions(target: Node, payload: DamagePayload) -> Array[Dictionary]:
	var reactions: Array[Dictionary] = []

	if target == null or payload == null:
		return reactions

	for rule: Resource in get_rules():
		if not rule_matches(rule, target, payload):
			continue

		reactions.append(apply_rule(rule, target, payload))

	return reactions


static func get_rules() -> Array[Resource]:
	return [
		IgniteOilyRule,
		WetConductionRule,
		WetFreezeRule,
		FrozenShatterRule,
	]


static func rule_matches(rule: Resource, target: Node, payload: DamagePayload) -> bool:
	if rule == null:
		return false

	if not payload_has_all_tags(payload, get_rule_string_array(rule, "incoming_tags")):
		return false

	if not target_has_all_tags_or_statuses(target, get_rule_string_array(rule, "target_tags")):
		return false

	if not target_has_all_statuses(target, get_rule_string_array(rule, "target_statuses")):
		return false

	return true


static func apply_rule(rule: Resource, target: Node, payload: DamagePayload) -> Dictionary:
	remove_rule_statuses(rule, target)
	apply_rule_status(rule, target, payload)
	apply_rule_damage(rule, target)

	var reaction_id: String = get_rule_string(rule, "reaction_id", "reaction")
	var reaction_name: String = get_rule_string(rule, "reaction_name", reaction_id)

	return {
		"rule": get_rule_string(rule, "rule_id", reaction_id),
		"reaction": reaction_id,
		"reaction_name": reaction_name,
		"message": format_feedback_text(rule, target),
	}


static func remove_rule_statuses(rule: Resource, target: Node) -> void:
	var statuses_to_remove: Array[String] = get_rule_string_array(rule, "remove_statuses")

	if statuses_to_remove.size() <= 0:
		return

	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver == null or not status_receiver.has_method("remove_status"):
		return

	for status_name: String in statuses_to_remove:
		status_receiver.remove_status(status_name)


static func apply_rule_status(rule: Resource, target: Node, payload: DamagePayload) -> void:
	var output_status: String = get_rule_string(rule, "output_status", "")
	var output_duration: float = get_rule_float(rule, "output_status_duration", 0.0)

	if output_status == "" or output_duration <= 0.0:
		return

	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver == null or not status_receiver.has_method("apply_status"):
		return

	var status_source: String = get_rule_string(rule, "output_status_source", "")

	if status_source == "":
		status_source = get_rule_string(rule, "reaction_id", payload.source_name)

	status_receiver.apply_status(
		output_status,
		output_duration,
		get_rule_float(rule, "output_status_strength", 1.0),
		status_source
	)


static func apply_rule_damage(rule: Resource, target: Node) -> void:
	var output_damage: int = get_rule_int(rule, "output_damage", 0)
	var output_stance_damage: int = get_rule_int(rule, "output_stance_damage", 0)

	if output_damage <= 0 and output_stance_damage <= 0:
		return

	var hit_receiver: Node = target.get_node_or_null("HitReceiver")

	if hit_receiver == null or not hit_receiver.has_method("receive_payload"):
		return

	var reaction_payload: DamagePayload = DamagePayload.new()
	reaction_payload.amount = output_damage
	reaction_payload.stance_damage = output_stance_damage
	reaction_payload.element = get_rule_string(rule, "output_element", "neutral")
	reaction_payload.source_name = get_rule_string(rule, "output_source_name", get_rule_string(rule, "reaction_name", "Reaction"))
	reaction_payload.hit_type = get_rule_string(rule, "output_hit_type", "reaction")
	reaction_payload.tags = get_rule_string_array(rule, "output_tags")

	hit_receiver.receive_payload(reaction_payload)


static func payload_has_all_tags(payload: DamagePayload, required_tags: Array[String]) -> bool:
	for tag: String in required_tags:
		if not payload_has_tag(payload, tag):
			return false

	return true


static func payload_has_tag(payload: DamagePayload, tag: String) -> bool:
	if tag == "":
		return true

	if payload.element == tag:
		return true

	if payload.hit_type == tag:
		return true

	return payload.tags.has(tag)


static func target_has_all_tags_or_statuses(target: Node, required_tags: Array[String]) -> bool:
	for tag: String in required_tags:
		if not target_has_status_or_tag(target, tag):
			return false

	return true


static func target_has_all_statuses(target: Node, required_statuses: Array[String]) -> bool:
	for status_name: String in required_statuses:
		if not target_has_status(target, status_name):
			return false

	return true


static func target_has_status_or_tag(target: Node, name: String) -> bool:
	if name == "":
		return true

	if target_has_tag(target, name):
		return true

	return target_has_status(target, name)


static func target_has_tag(target: Node, tag: String) -> bool:
	var tag_component: Node = target.get_node_or_null("TagComponent")

	if tag_component != null and tag_component.has_method("has_tag"):
		return tag_component.has_tag(tag)

	return false


static func target_has_status(target: Node, status_name: String) -> bool:
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")

	if status_receiver != null and status_receiver.has_method("has_status"):
		return status_receiver.has_status(status_name)

	return false


static func get_debug_matrix_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []

	for rule: Resource in get_rules():
		rows.append({
			"rule": get_rule_string(rule, "rule_id", "combo_rule"),
			"incoming": get_rule_string_array(rule, "incoming_tags"),
			"target_tags": get_rule_string_array(rule, "target_tags"),
			"target_statuses": get_rule_string_array(rule, "target_statuses"),
			"reaction": get_rule_string(rule, "reaction_id", "reaction"),
			"priority": get_rule_int(rule, "priority", 0),
		})

	return rows


static func format_feedback_text(rule: Resource, target: Node) -> String:
	var text: String = get_rule_string(rule, "feedback_text", "")

	if text == "":
		text = "{target} reacts."

	return text.replace("{target}", target.name)


static func get_rule_string(rule: Resource, property_name: String, fallback: String = "") -> String:
	if rule == null:
		return fallback

	var value: Variant = rule.get(property_name)

	if value == null:
		return fallback

	return str(value)


static func get_rule_int(rule: Resource, property_name: String, fallback: int = 0) -> int:
	if rule == null:
		return fallback

	var value: Variant = rule.get(property_name)

	if value == null:
		return fallback

	return int(value)


static func get_rule_float(rule: Resource, property_name: String, fallback: float = 0.0) -> float:
	if rule == null:
		return fallback

	var value: Variant = rule.get(property_name)

	if value == null:
		return fallback

	return float(value)


static func get_rule_string_array(rule: Resource, property_name: String) -> Array[String]:
	var strings: Array[String] = []

	if rule == null:
		return strings

	var value: Variant = rule.get(property_name)

	if not (value is Array):
		return strings

	var values: Array = value as Array

	for item in values:
		var text: String = str(item)

		if text == "":
			continue

		strings.append(text)

	return strings
