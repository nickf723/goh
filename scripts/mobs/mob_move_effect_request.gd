extends RefCounted
class_name MobMoveEffectRequest

const TRIGGER_ACTIVE_START := "active_start"

const DELIVERY_EXECUTOR := "executor"
const DELIVERY_CONTACT_PAYLOAD := "contact_payload"
const DELIVERY_AREA_PAYLOAD := "area_payload"
const DELIVERY_PROJECTILE_PAYLOAD := "projectile_payload"
const DELIVERY_RECOVERY := "recovery"
const DELIVERY_CUSTOM := "custom"

const DELIVERY_BY_EFFECT_KIND: Dictionary = {
	"wait": DELIVERY_EXECUTOR,
	"movement": DELIVERY_EXECUTOR,
	"move_to_tag": DELIVERY_EXECUTOR,
	"damage": DELIVERY_CONTACT_PAYLOAD,
	"area_damage": DELIVERY_AREA_PAYLOAD,
	"projectile": DELIVERY_PROJECTILE_PAYLOAD,
	"status": DELIVERY_CONTACT_PAYLOAD,
	"buff": DELIVERY_AREA_PAYLOAD,
	"recover": DELIVERY_RECOVERY,
}


static func build(
	execution: Dictionary,
	source_context: Dictionary = {}
) -> Dictionary:
	var move_data: Dictionary = _dictionary(execution.get("move", {}))
	var effect: Dictionary = _dictionary(move_data.get("effect", {}))
	var execution_context: Dictionary = _dictionary(execution.get("context", {}))
	var source: Dictionary = execution_context.duplicate(true)
	source.merge(source_context, true)
	var move_id: String = str(
		execution.get("move_id", move_data.get("id", ""))
	).to_lower().strip_edges()
	var effect_kind: String = str(effect.get("kind", "custom")).to_lower().strip_edges()
	if effect_kind == "":
		effect_kind = "custom"
	var delivery: String = str(
		DELIVERY_BY_EFFECT_KIND.get(effect_kind, DELIVERY_CUSTOM)
	)
	var target_mode: String = str(
		move_data.get("target_mode", "self")
	).to_lower().strip_edges()
	var trigger: String = str(
		(move_data.get("timing", {}) as Dictionary).get(
			"effect_trigger",
			TRIGGER_ACTIVE_START
		)
	).to_lower().strip_edges()
	var source_name: String = str(source.get(
		"source_name",
		source.get(
			"animal_name",
			move_data.get("display_name", move_id.replace("_", " ").capitalize())
		)
	))
	var request_id: String = _build_request_id(move_id, source, execution_context)
	var maximum_range: float = maxf(float(move_data.get("maximum_range", 0.0)), 0.0)
	var radius: float = maxf(float(effect.get("radius", maximum_range)), 0.0)
	return {
		"request_id": request_id,
		"move_id": move_id,
		"display_name": str(move_data.get("display_name", move_id)),
		"effect_kind": effect_kind,
		"trigger": trigger,
		"delivery": delivery,
		"target_mode": target_mode,
		"minimum_range": maxf(float(move_data.get("minimum_range", 0.0)), 0.0),
		"maximum_range": maximum_range,
		"radius": radius,
		"move_tags": _string_array(move_data.get("tags", [])),
		"effect": effect,
		"payload": build_payload_data(move_data, source_name),
		"source": source,
		"execution_serial": int(execution_context.get("execution_serial", 0)),
	}


static func build_payload_data(
	move_data: Dictionary,
	source_name: String = ""
) -> Dictionary:
	var effect: Dictionary = _dictionary(move_data.get("effect", {}))
	var effect_kind: String = str(effect.get("kind", "")).to_lower().strip_edges()
	if not ["damage", "area_damage", "projectile", "status", "buff"].has(effect_kind):
		return {}
	var statuses: Array[Dictionary] = _dictionary_array(effect.get("statuses", []))
	var status_id: String = str(effect.get("status", ""))
	var status_duration: float = maxf(float(effect.get("duration", 0.0)), 0.0)
	var status_strength: float = maxf(
		float(effect.get("strength", effect.get("buildup", 1.0))),
		0.0
	)
	if status_id == "" and not statuses.is_empty():
		status_id = str(statuses[0].get("id", ""))
		status_duration = maxf(
			float(statuses[0].get("duration", status_duration)),
			0.0
		)
		status_strength = maxf(
			float(statuses[0].get("strength", status_strength)),
			0.0
		)
	var move_id: String = str(
		move_data.get("id", move_data.get("move_id", "mob_move"))
	)
	var tags: Array[String] = _string_array(move_data.get("tags", []))
	for required_tag: String in ["mob_move", "creature_action"]:
		if not tags.has(required_tag):
			tags.append(required_tag)
	return {
		"amount": maxi(int(round(float(effect.get("damage", 0.0)))), 0),
		"stance_damage": maxi(
			int(round(float(effect.get("stance_damage", effect.get("damage", 0.0))))),
			0
		),
		"element": str(effect.get("element", "neutral")),
		"source_name": (
			source_name
			if source_name != ""
			else str(move_data.get("display_name", move_id))
		),
		"hit_type": str(effect.get("hit_type", move_id)),
		"status_effect": status_id,
		"status_duration": status_duration,
		"status_strength": status_strength,
		"statuses": statuses,
		"knockback_strength": maxf(float(effect.get("force", 0.0)), 0.0),
		"knockback_up_strength": maxf(float(effect.get("up_force", 0.0)), 0.0),
		"critical_multiplier": maxf(float(effect.get("critical_multiplier", 1.0)), 1.0),
		"tags": tags,
	}


static func is_payload_delivery(request: Dictionary) -> bool:
	return str(request.get("delivery", "")) in [
		DELIVERY_CONTACT_PAYLOAD,
		DELIVERY_AREA_PAYLOAD,
		DELIVERY_PROJECTILE_PAYLOAD,
	]


static func validate_request(request: Dictionary) -> Array[String]:
	var failures: Array[String] = []
	if str(request.get("request_id", "")) == "":
		failures.append("effect request has no request id")
	if str(request.get("move_id", "")) == "":
		failures.append("effect request has no move id")
	if str(request.get("effect_kind", "")) == "":
		failures.append("effect request has no effect kind")
	if str(request.get("trigger", "")) != TRIGGER_ACTIVE_START:
		failures.append("unsupported effect trigger " + str(request.get("trigger", "")))
	if is_payload_delivery(request) and _dictionary(request.get("payload", {})).is_empty():
		failures.append("payload delivery has no payload data")
	return failures


static func _build_request_id(
	move_id: String,
	source: Dictionary,
	execution_context: Dictionary
) -> String:
	var species_id: String = str(source.get("species_id", "mob"))
	var actor_id: String = str(source.get(
		"actor_instance_id",
		execution_context.get("actor_instance_id", "actor")
	))
	var serial: String = str(execution_context.get("execution_serial", 0))
	return species_id + ":" + actor_id + ":" + serial + ":" + move_id


static func _dictionary(value: Variant) -> Dictionary:
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			var normalized: String = str(raw).to_lower().strip_edges()
			if normalized != "" and not result.has(normalized):
				result.append(normalized)
	return result


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append((raw as Dictionary).duplicate(true))
	return result
