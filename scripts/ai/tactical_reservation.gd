extends RefCounted
class_name TacticalReservation


var reservation_id: String = ""
var squad_id: String = ""
var owner_id: int = 0
var owner_name: String = "Actor"
var reservation_kind: String = "payoff"
var reservation_key: String = ""
var plan_id: String = ""
var reaction_id: String = ""
var target_id: int = 0
var priority: float = 0.0
var created_at: float = 0.0
var expires_at: float = 0.0
var exclusive: bool = true
var metadata: Dictionary = {}
var release_reason: String = ""


func configure(data: Dictionary) -> TacticalReservation:
	reservation_id = str(data.get("reservation_id", reservation_id))
	squad_id = str(data.get("squad_id", squad_id)).strip_edges().to_lower()
	owner_id = int(data.get("owner_id", owner_id))
	owner_name = str(data.get("owner_name", owner_name))
	reservation_kind = str(
		data.get("reservation_kind", reservation_kind)
	).strip_edges().to_lower()
	reservation_key = str(data.get("reservation_key", reservation_key))
	plan_id = str(data.get("plan_id", plan_id))
	reaction_id = str(data.get("reaction_id", reaction_id)).strip_edges().to_lower()
	target_id = int(data.get("target_id", target_id))
	priority = float(data.get("priority", priority))
	created_at = float(data.get("created_at", created_at))
	expires_at = float(data.get("expires_at", expires_at))
	exclusive = bool(data.get("exclusive", exclusive))
	var metadata_value: Variant = data.get("metadata", {})
	metadata = (
		(metadata_value as Dictionary).duplicate(true)
		if metadata_value is Dictionary
		else {}
	)
	return self


func refresh(now_seconds: float, duration: float, new_priority: float) -> void:
	created_at = now_seconds
	expires_at = now_seconds + maxf(duration, 0.01)
	priority = maxf(priority, new_priority)
	release_reason = ""


func is_expired(now_seconds: float) -> bool:
	return expires_at > 0.0 and now_seconds >= expires_at


func matches_slot(
	requested_squad: String,
	requested_kind: String,
	requested_key: String
) -> bool:
	return (
		squad_id == requested_squad.strip_edges().to_lower()
		and reservation_kind == requested_kind.strip_edges().to_lower()
		and reservation_key == requested_key
	)


func belongs_to(requested_owner_id: int) -> bool:
	return owner_id == requested_owner_id


func release(reason: String) -> void:
	release_reason = reason


func to_dictionary() -> Dictionary:
	return {
		"reservation_id": reservation_id,
		"squad_id": squad_id,
		"owner_id": owner_id,
		"owner_name": owner_name,
		"kind": reservation_kind,
		"key": reservation_key,
		"plan_id": plan_id,
		"reaction_id": reaction_id,
		"target_id": target_id,
		"priority": priority,
		"created_at": created_at,
		"expires_at": expires_at,
		"exclusive": exclusive,
		"metadata": metadata.duplicate(true),
		"release_reason": release_reason,
	}
