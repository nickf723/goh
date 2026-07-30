extends RefCounted
class_name TacticalIntentBroadcast


var broadcast_id: String = ""
var squad_id: String = ""
var owner_id: int = 0
var owner_name: String = "Actor"
var intent_type: String = "intent"
var tags: Array[String] = []
var target_id: int = 0
var created_at: float = 0.0
var expires_at: float = 0.0
var metadata: Dictionary = {}


func configure(data: Dictionary) -> TacticalIntentBroadcast:
	broadcast_id = str(data.get("broadcast_id", broadcast_id))
	squad_id = str(data.get("squad_id", squad_id)).strip_edges().to_lower()
	owner_id = int(data.get("owner_id", owner_id))
	owner_name = str(data.get("owner_name", owner_name))
	intent_type = str(data.get("intent_type", intent_type)).strip_edges().to_lower()
	tags = _string_array(data.get("tags", []))
	target_id = int(data.get("target_id", target_id))
	created_at = float(data.get("created_at", created_at))
	expires_at = float(data.get("expires_at", expires_at))
	var metadata_value: Variant = data.get("metadata", {})
	metadata = (
		(metadata_value as Dictionary).duplicate(true)
		if metadata_value is Dictionary
		else {}
	)
	return self


func refresh(
	now_seconds: float,
	duration: float,
	new_tags: Array[String],
	new_target_id: int,
	new_metadata: Dictionary
) -> void:
	created_at = now_seconds
	expires_at = now_seconds + maxf(duration, 0.01)
	tags = _string_array(new_tags)
	target_id = new_target_id
	metadata = new_metadata.duplicate(true)


func is_expired(now_seconds: float) -> bool:
	return expires_at > 0.0 and now_seconds >= expires_at


func to_dictionary() -> Dictionary:
	return {
		"broadcast_id": broadcast_id,
		"squad_id": squad_id,
		"owner_id": owner_id,
		"owner_name": owner_name,
		"intent_type": intent_type,
		"tags": tags.duplicate(),
		"target_id": target_id,
		"created_at": created_at,
		"expires_at": expires_at,
		"metadata": metadata.duplicate(true),
	}


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var text: String = str(raw).strip_edges().to_lower()
			if text != "" and not result.has(text):
				result.append(text)
	return result
