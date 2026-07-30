extends RefCounted
class_name ReactionTransaction


static var next_transaction_number: int = 1

var transaction_id: String = ""
var depth: int = 0
var maximum_depth: int = 4
var triggered_keys: Dictionary = {}
var exclusive_groups: Dictionary = {}
var triggered_rules: Array[String] = []
var suppressed: Array[Dictionary] = []
var source_payload_summary: Dictionary = {}
var target_snapshot: Dictionary = {}


static func begin(
	payload: DamagePayload,
	target: Node,
	target_state: Dictionary,
	maximum_reaction_depth: int = 4
) -> ReactionTransaction:
	var transaction := ReactionTransaction.new()
	transaction.maximum_depth = maxi(maximum_reaction_depth, 0)
	transaction.transaction_id = _make_transaction_id(payload, target)
	transaction.depth = 0
	transaction.target_snapshot = target_state.duplicate(true)
	transaction.source_payload_summary = _summarize_payload(payload)
	return transaction


func can_trigger(
	rule_id: String,
	target: Node,
	max_triggers: int = 1,
	exclusive_group: String = ""
) -> bool:
	if depth > maximum_depth:
		record_suppressed(rule_id, target, "reaction depth limit")
		return false
	var key: String = make_rule_target_key(rule_id, target)
	if int(triggered_keys.get(key, 0)) >= maxi(max_triggers, 1):
		record_suppressed(rule_id, target, "transaction trigger limit")
		return false
	if exclusive_group != "" and exclusive_groups.has(exclusive_group):
		record_suppressed(
			rule_id,
			target,
			"exclusive group already claimed by " + str(exclusive_groups[exclusive_group])
		)
		return false
	return true


func mark_triggered(
	rule_id: String,
	target: Node,
	exclusive_group: String = ""
) -> void:
	var key: String = make_rule_target_key(rule_id, target)
	triggered_keys[key] = int(triggered_keys.get(key, 0)) + 1
	triggered_rules.append(rule_id)
	if exclusive_group != "":
		exclusive_groups[exclusive_group] = rule_id


func record_suppressed(rule_id: String, target: Node, reason: String) -> void:
	suppressed.append({
		"rule": rule_id,
		"target": target.name if target != null else "none",
		"reason": reason,
	})


func make_rule_target_key(rule_id: String, target: Node) -> String:
	return rule_id + "@" + str(target.get_instance_id() if target != null else 0)


func get_debug_data() -> Dictionary:
	return {
		"transaction_id": transaction_id,
		"depth": depth,
		"maximum_depth": maximum_depth,
		"triggered_rules": triggered_rules.duplicate(),
		"exclusive_groups": exclusive_groups.duplicate(true),
		"suppressed": suppressed.duplicate(true),
		"payload": source_payload_summary.duplicate(true),
		"target_snapshot": target_snapshot.duplicate(true),
	}


static func _make_transaction_id(payload: DamagePayload, target: Node) -> String:
	var number: int = next_transaction_number
	next_transaction_number += 1
	var source_name: String = payload.source_name if payload != null else "payload"
	var target_name: String = target.name if target != null else "target"
	return (
		"rx-"
		+ str(number)
		+ "-"
		+ source_name.to_snake_case()
		+ "-"
		+ target_name.to_snake_case()
	)


static func _summarize_payload(payload: DamagePayload) -> Dictionary:
	if payload == null:
		return {}
	return {
		"source": payload.source_name,
		"element": payload.element,
		"hit_type": payload.hit_type,
		"status": payload.status_effect,
		"tags": payload.tags.duplicate(),
		"damage": payload.amount,
		"stance_damage": payload.stance_damage,
	}
