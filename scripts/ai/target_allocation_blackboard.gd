extends RefCounted
class_name TargetAllocationBlackboard


static var claims: Dictionary = {}
static var next_claim_number: int = 1
static var release_history: Array[Dictionary] = []


static func claim_target(
	squad_id: String,
	owner_id: int,
	owner_name: String,
	target_id: int,
	target_name: String,
	claim_kind: String,
	expected_damage: float = 0.0,
	control_tags: Array = [],
	duration: float = 0.8,
	priority: float = 0.0,
	metadata: Dictionary = {}
) -> Dictionary:
	prune_expired()
	if target_id <= 0:
		return {"granted": false, "reason": "Target claim requires a target id"}
	var normalized_squad: String = _normalize(squad_id, "default_squad")
	var normalized_kind: String = _normalize(claim_kind, "attention")
	var now_seconds: float = _now_seconds()
	var existing_id: String = _find_owner_claim(
		normalized_squad,
		owner_id,
		target_id,
		normalized_kind
	)
	var row: Dictionary = {
		"claim_id": existing_id,
		"squad_id": normalized_squad,
		"owner_id": owner_id,
		"owner_name": owner_name,
		"target_id": target_id,
		"target_name": target_name,
		"claim_kind": normalized_kind,
		"expected_damage": maxf(expected_damage, 0.0),
		"control_tags": _string_array(control_tags),
		"priority": priority,
		"created_at": now_seconds,
		"expires_at": now_seconds + maxf(duration, 0.05),
		"metadata": metadata.duplicate(true),
	}
	if existing_id == "":
		existing_id = "target-claim-" + str(next_claim_number)
		next_claim_number += 1
		row["claim_id"] = existing_id
		claims[existing_id] = row
		return {"granted": true, "refreshed": false, "claim": row.duplicate(true)}
	var existing: Dictionary = claims[existing_id] as Dictionary
	row["created_at"] = float(existing.get("created_at", now_seconds))
	claims[existing_id] = row
	return {"granted": true, "refreshed": true, "claim": row.duplicate(true)}


static func get_target_context(
	squad_id: String,
	target_id: int,
	exclude_owner_id: int = 0
) -> Dictionary:
	prune_expired()
	var normalized_squad: String = _normalize(squad_id, "default_squad")
	var rows: Array[Dictionary] = []
	var expected_damage: float = 0.0
	var attention_count: int = 0
	var damage_count: int = 0
	var setup_count: int = 0
	var payoff_count: int = 0
	var control_count: int = 0
	var melee_count: int = 0
	var control_tags: Array[String] = []
	var owner_ids: Array[int] = []
	for claim_value: Variant in claims.values():
		if not claim_value is Dictionary:
			continue
		var row: Dictionary = claim_value as Dictionary
		if str(row.get("squad_id", "")) != normalized_squad:
			continue
		if int(row.get("target_id", 0)) != target_id:
			continue
		if exclude_owner_id != 0 and int(row.get("owner_id", 0)) == exclude_owner_id:
			continue
		rows.append(row.duplicate(true))
		expected_damage += float(row.get("expected_damage", 0.0))
		var owner_id: int = int(row.get("owner_id", 0))
		if owner_id != 0 and not owner_ids.has(owner_id):
			owner_ids.append(owner_id)
		var kind: String = str(row.get("claim_kind", "attention"))
		match kind:
			"attention":
				attention_count += 1
			"damage":
				damage_count += 1
			"setup":
				setup_count += 1
			"payoff":
				payoff_count += 1
			"control":
				control_count += 1
			"melee":
				melee_count += 1
		for tag: String in _string_array(row.get("control_tags", [])):
			if not control_tags.has(tag):
				control_tags.append(tag)
	return {
		"target_id": target_id,
		"claim_count": rows.size(),
		"owner_count": owner_ids.size(),
		"expected_damage": expected_damage,
		"attention_count": attention_count,
		"damage_count": damage_count,
		"setup_count": setup_count,
		"payoff_count": payoff_count,
		"control_count": control_count,
		"melee_count": melee_count,
		"control_tags": control_tags,
		"claims": rows,
	}


static func get_squad_context(squad_id: String) -> Dictionary:
	prune_expired()
	var normalized_squad: String = _normalize(squad_id, "default_squad")
	var rows: Array[Dictionary] = []
	var target_ids: Array[int] = []
	for claim_value: Variant in claims.values():
		if not claim_value is Dictionary:
			continue
		var row: Dictionary = claim_value as Dictionary
		if str(row.get("squad_id", "")) != normalized_squad:
			continue
		rows.append(row.duplicate(true))
		var target_id: int = int(row.get("target_id", 0))
		if target_id > 0 and not target_ids.has(target_id):
			target_ids.append(target_id)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var target_a: int = int(a.get("target_id", 0))
		var target_b: int = int(b.get("target_id", 0))
		if target_a != target_b:
			return target_a < target_b
		return int(a.get("owner_id", 0)) < int(b.get("owner_id", 0))
	)
	var summaries: Array[Dictionary] = []
	for target_id: int in target_ids:
		var context: Dictionary = get_target_context(normalized_squad, target_id)
		var target_name: String = "Target " + str(target_id)
		for row: Dictionary in rows:
			if int(row.get("target_id", 0)) == target_id:
				target_name = str(row.get("target_name", target_name))
				break
		context["target_name"] = target_name
		summaries.append(context)
	return {
		"squad_id": normalized_squad,
		"target_claim_count": rows.size(),
		"target_claims": rows,
		"target_summaries": summaries,
	}


static func release_owner(
	owner_id: int,
	squad_id: String = "",
	claim_kind: String = "",
	reason: String = "owner released"
) -> int:
	var released: int = 0
	var normalized_squad: String = _normalize(squad_id, "")
	var normalized_kind: String = _normalize(claim_kind, "")
	for claim_id: Variant in claims.keys():
		var value: Variant = claims.get(claim_id)
		if not value is Dictionary:
			continue
		var row: Dictionary = value as Dictionary
		if int(row.get("owner_id", 0)) != owner_id:
			continue
		if normalized_squad != "" and str(row.get("squad_id", "")) != normalized_squad:
			continue
		if normalized_kind != "" and str(row.get("claim_kind", "")) != normalized_kind:
			continue
		_release(str(claim_id), reason)
		released += 1
	return released


static func release_target(
	target_id: int,
	squad_id: String = "",
	reason: String = "target unavailable"
) -> int:
	var released: int = 0
	var normalized_squad: String = _normalize(squad_id, "")
	for claim_id: Variant in claims.keys():
		var value: Variant = claims.get(claim_id)
		if not value is Dictionary:
			continue
		var row: Dictionary = value as Dictionary
		if int(row.get("target_id", 0)) != target_id:
			continue
		if normalized_squad != "" and str(row.get("squad_id", "")) != normalized_squad:
			continue
		_release(str(claim_id), reason)
		released += 1
	return released


static func prune_expired(now_seconds: float = -1.0) -> int:
	var now_value: float = now_seconds if now_seconds >= 0.0 else _now_seconds()
	var expired: Array[String] = []
	for claim_id: Variant in claims.keys():
		var value: Variant = claims.get(claim_id)
		if value is Dictionary and float((value as Dictionary).get("expires_at", 0.0)) <= now_value:
			expired.append(str(claim_id))
	for claim_id: String in expired:
		_release(claim_id, "expired")
	return expired.size()


static func clear_all() -> void:
	claims.clear()
	release_history.clear()
	next_claim_number = 1


static func get_debug_data() -> Dictionary:
	prune_expired()
	return {
		"claim_count": claims.size(),
		"claims": get_squad_context("").get("target_claims", []),
		"release_history": release_history.duplicate(true),
	}


static func _find_owner_claim(
	squad_id: String,
	owner_id: int,
	target_id: int,
	claim_kind: String
) -> String:
	for claim_id: Variant in claims.keys():
		var value: Variant = claims.get(claim_id)
		if not value is Dictionary:
			continue
		var row: Dictionary = value as Dictionary
		if (
			str(row.get("squad_id", "")) == squad_id
			and int(row.get("owner_id", 0)) == owner_id
			and int(row.get("target_id", 0)) == target_id
			and str(row.get("claim_kind", "")) == claim_kind
		):
			return str(claim_id)
	return ""


static func _release(claim_id: String, reason: String) -> void:
	var value: Variant = claims.get(claim_id)
	if value is Dictionary:
		var row: Dictionary = (value as Dictionary).duplicate(true)
		row["release_reason"] = reason
		row["released_at"] = _now_seconds()
		release_history.append(row)
		if release_history.size() > 32:
			release_history.pop_front()
	claims.erase(claim_id)


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).strip_edges().to_lower()
			if text != "" and not result.has(text):
				result.append(text)
	return result


static func _normalize(value: String, fallback: String) -> String:
	var normalized: String = value.strip_edges().to_lower()
	return fallback if normalized == "" else normalized


static func _now_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0
