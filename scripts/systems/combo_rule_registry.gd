extends Node
class_name ComboRuleRegistry

const ReactionBurstResolverScript = preload("res://scripts/systems/reaction_burst_resolver.gd")
const IgniteOilyRule: Resource = preload("res://data/combo_rules/ignite_oily_target.tres")
const WetConductionRule: Resource = preload("res://data/combo_rules/wet_conduction.tres")
const WetFreezeRule: Resource = preload("res://data/combo_rules/wet_freeze.tres")
const FrozenShatterRule: Resource = preload("res://data/combo_rules/frozen_shatter.tres")
const FireFrozenSteamRule: Resource = preload("res://data/combo_rules/fire_frozen_steam.tres")
const ToxicIgnitionRule: Resource = preload("res://data/combo_rules/hazard_toxic_ignition.tres")
const CloudSpreadRule: Resource = preload("res://data/combo_rules/hazard_cloud_spread.tres")
const FannedFlamesRule: Resource = preload("res://data/combo_rules/hazard_fanned_flames.tres")


static func resolve_payload_reactions(target: Node, payload: DamagePayload) -> Array[Dictionary]:
	var reactions: Array[Dictionary] = []

	if target == null or payload == null:
		return reactions

	for rule: Resource in get_rules():
		if not rule_matches(rule, target, payload):
			continue

		reactions.append(apply_rule(rule, target, payload))

	return reactions


static func resolve_hazard_reactions(
	hazard: Node,
	payload: DamagePayload,
	source_position: Vector3 = Vector3.ZERO
) -> Array[Dictionary]:
	var reactions: Array[Dictionary] = []

	if hazard == null or payload == null:
		return reactions

	for rule: Resource in get_rules():
		if not hazard_rule_matches(rule, hazard, payload):
			continue

		reactions.append(apply_hazard_rule(rule, hazard, payload, source_position))

	return reactions


static func get_rules() -> Array[Resource]:
	return [
		FireFrozenSteamRule,
		FrozenShatterRule,
		IgniteOilyRule,
		WetConductionRule,
		WetFreezeRule,
		ToxicIgnitionRule,
		CloudSpreadRule,
		FannedFlamesRule,
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


static func hazard_rule_matches(rule: Resource, hazard: Node, payload: DamagePayload) -> bool:
	if rule == null:
		return false

	if not payload_has_all_tags(payload, get_rule_string_array(rule, "incoming_tags")):
		return false

	if not hazard_has_all_tags(hazard, get_rule_string_array(rule, "target_tags")):
		return false

	if not target_has_all_statuses(hazard, get_rule_string_array(rule, "target_statuses")):
		return false

	return true


static func apply_rule(rule: Resource, target: Node, payload: DamagePayload) -> Dictionary:
	remove_rule_statuses(rule, target)
	apply_rule_status(rule, target, payload)
	apply_rule_damage(rule, target)
	call_target_reaction_method(rule, target, Vector3.ZERO)

	var area_results: Array[Dictionary] = ReactionBurstResolverScript.apply_area_effect(
		rule,
		target,
		get_target_position(target)
	)
	return build_reaction_result(rule, target, area_results)


static func apply_hazard_rule(
	rule: Resource,
	hazard: Node,
	payload: DamagePayload,
	source_position: Vector3 = Vector3.ZERO
) -> Dictionary:
	remove_rule_statuses(rule, hazard)
	apply_rule_status(rule, hazard, payload)
	apply_rule_damage(rule, hazard)
	call_target_reaction_method(rule, hazard, source_position)

	var area_results: Array[Dictionary] = ReactionBurstResolverScript.apply_area_effect(
		rule,
		hazard,
		get_target_position(hazard)
	)
	return build_reaction_result(rule, hazard, area_results)


static func build_reaction_result(
	rule: Resource,
	target: Node,
	area_results: Array[Dictionary] = []
) -> Dictionary:
	var reaction_id: String = get_rule_string(rule, "reaction_id", "reaction")
	var reaction_name: String = get_rule_string(rule, "reaction_name", reaction_id)
	var area_target_names: Array[String] = []

	for area_result: Dictionary in area_results:
		var target_name: String = str(area_result.get("target", ""))
		if target_name != "" and not area_target_names.has(target_name):
			area_target_names.append(target_name)

	return {
		"rule": get_rule_string(rule, "rule_id", reaction_id),
		"reaction": reaction_id,
		"reaction_name": reaction_name,
		"message": format_feedback_text(rule, target),
		"visual_style": get_rule_string(rule, "visual_style", reaction_id),
		"visual_color": get_rule_color(rule, "visual_color", Color(1.0, 0.58, 0.15, 1.0)),
		"visual_radius": get_rule_float(rule, "visual_radius", 1.25),
		"visual_duration": get_rule_float(rule, "visual_duration", 0.42),
		"priority": get_rule_int(rule, "priority", 0),
		"area_effect_radius": get_rule_float(rule, "area_effect_radius", 0.0),
		"area_target_count": area_results.size(),
		"area_targets": area_target_names,
		"area_results": area_results,
	}


static func call_target_reaction_method(
	rule: Resource,
	target: Node,
	source_position: Vector3 = Vector3.ZERO
) -> void:
	var method_name: String = get_rule_string(rule, "target_reaction_method", "")

	if method_name == "":
		return
	if target == null or not target.has_method(method_name):
		return

	if get_rule_bool(rule, "target_reaction_pass_source_position", true):
		target.call(method_name, source_position)
	else:
		target.call(method_name)


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
	reaction_payload.source_name = get_rule_string(
		rule,
		"output_source_name",
		get_rule_string(rule, "reaction_name", "Reaction")
	)
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


static func hazard_has_all_tags(hazard: Node, required_tags: Array[String]) -> bool:
	for tag: String in required_tags:
		if not hazard_has_tag(hazard, tag):
			return false

	return true


static func hazard_has_tag(hazard: Node, tag: String) -> bool:
	if tag == "":
		return true

	if hazard == null or not hazard.has_method("get_hazard_tags"):
		return false

	var hazard_tags: Array = hazard.call("get_hazard_tags")
	return hazard_tags.has(tag)


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
			"visual": get_rule_string(rule, "visual_style", "reaction"),
			"target_method": get_rule_string(rule, "target_reaction_method", ""),
			"area_radius": get_rule_float(rule, "area_effect_radius", 0.0),
			"area_status": get_rule_string(rule, "area_output_status", ""),
			"priority": get_rule_int(rule, "priority", 0),
		})

	return rows


static func format_feedback_text(rule: Resource, target: Node) -> String:
	var text: String = get_rule_string(rule, "feedback_text", "")

	if text == "":
		text = "{target} reacts."

	return text.replace("{target}", target.name)


static func get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position

	var parent: Node = target.get_parent()
	if parent is Node3D:
		return (parent as Node3D).global_position

	return Vector3.ZERO


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


static func get_rule_bool(rule: Resource, property_name: String, fallback: bool = false) -> bool:
	if rule == null:
		return fallback

	var value: Variant = rule.get(property_name)

	if value == null:
		return fallback

	return bool(value)


static func get_rule_color(rule: Resource, property_name: String, fallback: Color) -> Color:
	if rule == null:
		return fallback

	var value: Variant = rule.get(property_name)

	if value is Color:
		return value as Color

	return fallback


static func get_rule_string_array(rule: Resource, property_name: String) -> Array[String]:
	var strings: Array[String] = []

	if rule == null:
		return strings

	var value: Variant = rule.get(property_name)

	if not (value is Array):
		return strings

	var values: Array = value as Array

	for item: Variant in values:
		var text: String = str(item)

		if text == "":
			continue

		strings.append(text)

	return strings
