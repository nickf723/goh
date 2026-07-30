extends RefCounted
class_name ElementalReactionEngine


const RuleCatalog = preload("res://scripts/systems/reaction_rule_catalog.gd")
const OutputExecutor = preload("res://scripts/systems/reaction_output_executor.gd")
const StatePolicy = preload("res://scripts/systems/reaction_state_policy.gd")
const TransactionScript = preload("res://scripts/systems/reaction_transaction.gd")


static func resolve_payload_transaction(
	target: Node,
	payload: DamagePayload
) -> Dictionary:
	var snapshot: Dictionary = StatePolicy.capture_target_state(target)
	var transaction: ReactionTransaction = TransactionScript.begin(
		payload,
		target,
		snapshot,
		4
	)
	var batch: Dictionary = _empty_batch(transaction)
	if target == null or payload == null:
		return batch
	if payload.suppress_reactions:
		transaction.record_suppressed("all", target, "payload suppresses reactions")
		batch["transaction"] = transaction.get_debug_data()
		batch["suppressed"] = transaction.suppressed.duplicate(true)
		return batch

	var reactions: Array[Dictionary] = batch["reactions"] as Array[Dictionary]
	for rule: Resource in RuleCatalog.get_rules():
		if not _rule_matches(rule, snapshot, payload):
			continue
		var rule_id: String = _get_string(rule, "rule_id", "combo_rule")
		if payload.is_reaction_payload() and not _get_bool(
			rule,
			"allow_reaction_payloads",
			true
		):
			transaction.record_suppressed(rule_id, target, "reaction payload not allowed")
			continue
		var rule_depth: int = _get_int(rule, "maximum_reaction_depth", 4)
		if transaction.depth >= rule_depth:
			transaction.record_suppressed(rule_id, target, "rule depth limit")
			continue
		var exclusive_group: String = _get_string(rule, "exclusive_group", "")
		if not transaction.can_trigger(
			rule_id,
			target,
			_get_int(rule, "max_triggers_per_transaction", 1),
			exclusive_group
		):
			continue

		transaction.mark_triggered(rule_id, target, exclusive_group)
		var result: Dictionary = OutputExecutor.apply_to_target(
			rule,
			target,
			payload,
			transaction
		)
		_enrich_result(result, rule, transaction, snapshot)
		reactions.append(result)
		if _get_bool(rule, "consume_incoming_status", false):
			batch["consume_incoming_status"] = true
		if _get_bool(rule, "stop_after_match", false):
			break

	batch["transaction"] = transaction.get_debug_data()
	batch["suppressed"] = transaction.suppressed.duplicate(true)
	return batch


static func resolve_hazard_transaction(
	hazard: Node,
	payload: DamagePayload,
	source_position: Vector3 = Vector3.ZERO
) -> Dictionary:
	var snapshot: Dictionary = StatePolicy.capture_target_state(hazard)
	var transaction: ReactionTransaction = TransactionScript.begin(
		payload,
		hazard,
		snapshot,
		4
	)
	var batch: Dictionary = _empty_batch(transaction)
	if hazard == null or payload == null:
		return batch
	if payload.suppress_reactions:
		transaction.record_suppressed("all", hazard, "payload suppresses reactions")
		batch["transaction"] = transaction.get_debug_data()
		batch["suppressed"] = transaction.suppressed.duplicate(true)
		return batch

	var reactions: Array[Dictionary] = batch["reactions"] as Array[Dictionary]
	for rule: Resource in RuleCatalog.get_rules():
		if not _rule_matches(rule, snapshot, payload):
			continue
		var rule_id: String = _get_string(rule, "rule_id", "combo_rule")
		if payload.is_reaction_payload() and not _get_bool(
			rule,
			"allow_reaction_payloads",
			true
		):
			transaction.record_suppressed(rule_id, hazard, "reaction payload not allowed")
			continue
		var rule_depth: int = _get_int(rule, "maximum_reaction_depth", 4)
		if transaction.depth >= rule_depth:
			transaction.record_suppressed(rule_id, hazard, "rule depth limit")
			continue
		var exclusive_group: String = _get_string(rule, "exclusive_group", "")
		if not transaction.can_trigger(
			rule_id,
			hazard,
			_get_int(rule, "max_triggers_per_transaction", 1),
			exclusive_group
		):
			continue

		transaction.mark_triggered(rule_id, hazard, exclusive_group)
		var result: Dictionary = OutputExecutor.apply_to_target(
			rule,
			hazard,
			payload,
			transaction,
			source_position
		)
		_enrich_result(result, rule, transaction, snapshot)
		reactions.append(result)
		if _get_bool(rule, "consume_incoming_status", false):
			batch["consume_incoming_status"] = true
		if _get_bool(rule, "stop_after_match", false):
			break

	batch["transaction"] = transaction.get_debug_data()
	batch["suppressed"] = transaction.suppressed.duplicate(true)
	return batch


static func _empty_batch(transaction: ReactionTransaction) -> Dictionary:
	var reactions: Array[Dictionary] = []
	return {
		"reactions": reactions,
		"consume_incoming_status": false,
		"transaction": transaction.get_debug_data(),
		"suppressed": [],
	}


static func _rule_matches(
	rule: Resource,
	snapshot: Dictionary,
	payload: DamagePayload
) -> bool:
	if rule == null or payload == null:
		return false
	if not _payload_has_all(payload, _get_strings(rule, "incoming_tags")):
		return false
	var incoming_any: Array[String] = _get_strings(rule, "incoming_any_tags")
	if not incoming_any.is_empty() and not _payload_has_any(payload, incoming_any):
		return false

	for required: String in _get_strings(rule, "target_tags"):
		if not StatePolicy.snapshot_has_tag_or_status(snapshot, required):
			return false
	var target_any: Array[String] = _get_strings(rule, "target_any_tags")
	if not target_any.is_empty():
		var any_tag_matches: bool = false
		for required: String in target_any:
			if StatePolicy.snapshot_has_tag_or_status(snapshot, required):
				any_tag_matches = true
				break
		if not any_tag_matches:
			return false

	for required_status: String in _get_strings(rule, "target_statuses"):
		if not StatePolicy.snapshot_has_status(snapshot, required_status):
			return false
	var any_statuses: Array[String] = _get_strings(rule, "target_any_statuses")
	if not any_statuses.is_empty():
		var any_status_matches: bool = false
		for required_status: String in any_statuses:
			if StatePolicy.snapshot_has_status(snapshot, required_status):
				any_status_matches = true
				break
		if not any_status_matches:
			return false
	for absent_status: String in _get_strings(rule, "required_absent_statuses"):
		if StatePolicy.snapshot_has_status(snapshot, absent_status):
			return false
	return true


static func _payload_has_all(payload: DamagePayload, tags: Array[String]) -> bool:
	for tag: String in tags:
		if not _payload_has_tag(payload, tag):
			return false
	return true


static func _payload_has_any(payload: DamagePayload, tags: Array[String]) -> bool:
	for tag: String in tags:
		if _payload_has_tag(payload, tag):
			return true
	return false


static func _payload_has_tag(payload: DamagePayload, tag: String) -> bool:
	var normalized: String = tag.strip_edges().to_lower()
	if normalized == "":
		return true
	if payload.element.strip_edges().to_lower() == normalized:
		return true
	if payload.hit_type.strip_edges().to_lower() == normalized:
		return true
	for payload_tag: String in payload.tags:
		if payload_tag.strip_edges().to_lower() == normalized:
			return true
	return false


static func _enrich_result(
	result: Dictionary,
	rule: Resource,
	transaction: ReactionTransaction,
	snapshot: Dictionary
) -> void:
	result["transaction_id"] = transaction.transaction_id
	result["reaction_depth"] = transaction.depth
	result["trigger_index"] = transaction.triggered_rules.size() - 1
	result["exclusive_group"] = _get_string(rule, "exclusive_group", "")
	result["consume_incoming_status"] = _get_bool(
		rule,
		"consume_incoming_status",
		false
	)
	result["pre_state"] = snapshot.duplicate(true)


static func _get_string(rule: Resource, property_name: String, fallback: String) -> String:
	if rule == null:
		return fallback
	var value: Variant = rule.get(property_name)
	return fallback if value == null else str(value)


static func _get_int(rule: Resource, property_name: String, fallback: int) -> int:
	if rule == null:
		return fallback
	var value: Variant = rule.get(property_name)
	return fallback if value == null else int(value)


static func _get_bool(rule: Resource, property_name: String, fallback: bool) -> bool:
	if rule == null:
		return fallback
	var value: Variant = rule.get(property_name)
	return fallback if value == null else bool(value)


static func _get_strings(rule: Resource, property_name: String) -> Array[String]:
	var result: Array[String] = []
	if rule == null:
		return result
	var value: Variant = rule.get(property_name)
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).strip_edges().to_lower()
			if text != "" and not result.has(text):
				result.append(text)
	return result
