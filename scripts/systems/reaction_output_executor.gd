extends RefCounted
class_name ReactionOutputExecutor


const LegacyRegistry = preload("res://scripts/systems/combo_rule_registry.gd")
const BurstResolver = preload("res://scripts/systems/reaction_burst_resolver.gd")


static func apply_to_target(
	rule: Resource,
	target: Node,
	parent_payload: DamagePayload,
	transaction: ReactionTransaction,
	source_position: Vector3 = Vector3.ZERO
) -> Dictionary:
	_remove_statuses(rule, target)
	_apply_status(rule, target, parent_payload)
	_apply_damage(rule, target, parent_payload, transaction)
	_call_reaction_method(rule, target, source_position)
	var area_results: Array[Dictionary] = BurstResolver.apply_area_effect(
		rule,
		target,
		_get_target_position(target)
	)
	return LegacyRegistry.build_reaction_result(rule, target, area_results)


static func _remove_statuses(rule: Resource, target: Node) -> void:
	var status_receiver: Node = target.get_node_or_null("StatusReceiver") if target != null else null
	if status_receiver == null or not status_receiver.has_method("remove_status"):
		return
	for status_name: String in _get_strings(rule, "remove_statuses"):
		status_receiver.call("remove_status", status_name)


static func _apply_status(
	rule: Resource,
	target: Node,
	parent_payload: DamagePayload
) -> void:
	var status_name: String = _get_string(rule, "output_status", "")
	var duration: float = _get_float(rule, "output_status_duration", 0.0)
	if status_name == "" or duration <= 0.0 or target == null:
		return
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")
	if status_receiver == null or not status_receiver.has_method("apply_status"):
		return
	var source_name: String = _get_string(rule, "output_status_source", "")
	if source_name == "":
		source_name = _get_string(
			rule,
			"reaction_id",
			parent_payload.source_name if parent_payload != null else "reaction"
		)
	status_receiver.call(
		"apply_status",
		status_name,
		duration,
		_get_float(rule, "output_status_strength", 1.0),
		source_name
	)


static func _apply_damage(
	rule: Resource,
	target: Node,
	parent_payload: DamagePayload,
	transaction: ReactionTransaction
) -> void:
	var damage: int = _get_int(rule, "output_damage", 0)
	var stance_damage: int = _get_int(rule, "output_stance_damage", 0)
	if target == null or (damage <= 0 and stance_damage <= 0):
		return

	var reaction_payload := DamagePayload.new()
	reaction_payload.amount = damage
	reaction_payload.stance_damage = stance_damage
	reaction_payload.element = _get_string(rule, "output_element", "neutral")
	reaction_payload.source_name = _get_string(
		rule,
		"output_source_name",
		_get_string(rule, "reaction_name", "Reaction")
	)
	reaction_payload.hit_type = _get_string(rule, "output_hit_type", "reaction")
	reaction_payload.tags = _get_strings(rule, "output_tags")
	reaction_payload.inherit_reaction_lineage(
		parent_payload,
		_get_string(rule, "rule_id", "reaction"),
		transaction.transaction_id if transaction != null else ""
	)
	reaction_payload.suppress_reactions = not _get_bool(
		rule,
		"output_triggers_reactions",
		false
	)

	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		payload_receiver.call("receive_payload", reaction_payload)
		return
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		hit_receiver.call("receive_payload", reaction_payload)


static func _call_reaction_method(
	rule: Resource,
	target: Node,
	source_position: Vector3
) -> void:
	var method_name: String = _get_string(rule, "target_reaction_method", "")
	if method_name == "" or target == null or not target.has_method(method_name):
		return
	if _get_bool(rule, "target_reaction_pass_source_position", true):
		target.call(method_name, source_position)
	else:
		target.call(method_name)


static func _get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent() if target != null else null
	return (parent as Node3D).global_position if parent is Node3D else Vector3.ZERO


static func _get_string(rule: Resource, key: String, fallback: String) -> String:
	if rule == null:
		return fallback
	var value: Variant = rule.get(key)
	return fallback if value == null else str(value)


static func _get_int(rule: Resource, key: String, fallback: int) -> int:
	if rule == null:
		return fallback
	var value: Variant = rule.get(key)
	return fallback if value == null else int(value)


static func _get_float(rule: Resource, key: String, fallback: float) -> float:
	if rule == null:
		return fallback
	var value: Variant = rule.get(key)
	return fallback if value == null else float(value)


static func _get_bool(rule: Resource, key: String, fallback: bool) -> bool:
	if rule == null:
		return fallback
	var value: Variant = rule.get(key)
	return fallback if value == null else bool(value)


static func _get_strings(rule: Resource, key: String) -> Array[String]:
	var result: Array[String] = []
	if rule == null:
		return result
	var value: Variant = rule.get(key)
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw)
			if text != "" and not result.has(text):
				result.append(text)
	return result
