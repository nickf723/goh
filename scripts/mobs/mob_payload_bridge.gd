extends RefCounted
class_name MobPayloadBridge

const EffectRequest = preload(
	"res://scripts/mobs/mob_move_effect_request.gd"
)
const DamagePayloadScript = preload("res://scripts/combat/damage_payload.gd")


static func create_damage_payload(
	request: Dictionary,
	source_actor: Node = null,
	target: Node = null
) -> DamagePayload:
	var payload_data: Dictionary = _dictionary(request.get("payload", {}))
	if payload_data.is_empty():
		return null
	var payload: DamagePayload = DamagePayloadScript.new() as DamagePayload
	payload.amount = maxi(int(payload_data.get("amount", 0)), 0)
	payload.stance_damage = maxi(int(payload_data.get("stance_damage", 0)), 0)
	payload.element = str(payload_data.get("element", "neutral"))
	payload.source_name = str(payload_data.get("source_name", request.get("display_name", "Mob Move")))
	payload.hit_type = str(payload_data.get("hit_type", request.get("move_id", "mob_move")))
	payload.status_effect = str(payload_data.get("status_effect", ""))
	payload.status_duration = maxf(float(payload_data.get("status_duration", 0.0)), 0.0)
	payload.status_strength = maxf(float(payload_data.get("status_strength", 1.0)), 0.0)
	payload.knockback_strength = maxf(
		float(payload_data.get("knockback_strength", 0.0)),
		0.0
	)
	payload.knockback_up_strength = maxf(
		float(payload_data.get("knockback_up_strength", 0.0)),
		0.0
	)
	payload.critical_multiplier = maxf(
		float(payload_data.get("critical_multiplier", 1.0)),
		1.0
	)
	payload.tags = _string_array(payload_data.get("tags", []))
	var species_id: String = str(
		(request.get("source", {}) as Dictionary).get("species_id", "")
	).to_lower().strip_edges()
	if species_id != "":
		var species_tag: String = "species:" + species_id
		if not payload.tags.has(species_tag):
			payload.tags.append(species_tag)
	payload.knockback_direction = _direction_between(source_actor, target)
	return payload


static func deliver_to_target(
	request: Dictionary,
	target: Node,
	source_actor: Node = null,
	delivery_context: Dictionary = {}
) -> Dictionary:
	if target == null:
		return _failure(request, "missing target")
	if source_actor != null and (
		target == source_actor
		or source_actor.is_ancestor_of(target)
	):
		return _failure(request, "source cannot receive its own hostile payload")
	if not EffectRequest.is_payload_delivery(request):
		return {
			"ok": false,
			"request_id": str(request.get("request_id", "")),
			"move_id": str(request.get("move_id", "")),
			"requires_executor": true,
			"delivery": str(request.get("delivery", "")),
		}
	if (
		str(request.get("delivery", "")) == EffectRequest.DELIVERY_PROJECTILE_PAYLOAD
		and not bool(delivery_context.get("impact_confirmed", false))
	):
		return {
			"ok": false,
			"request_id": str(request.get("request_id", "")),
			"move_id": str(request.get("move_id", "")),
			"requires_executor": true,
			"delivery": EffectRequest.DELIVERY_PROJECTILE_PAYLOAD,
			"error": "projectile delivery requires a confirmed impact",
		}

	var payload: DamagePayload = create_damage_payload(request, source_actor, target)
	if payload == null:
		return _failure(request, "effect request has no damage payload")
	var receiver_result: Dictionary = _send_payload(target, payload)
	if not bool(receiver_result.get("_received", false)):
		return _failure(request, "target has no shared payload receiver")
	receiver_result.erase("_received")
	_apply_additional_statuses(target, request, payload.status_effect)
	return {
		"ok": true,
		"request_id": str(request.get("request_id", "")),
		"move_id": str(request.get("move_id", "")),
		"delivery": str(request.get("delivery", "")),
		"target_instance_id": target.get_instance_id(),
		"receiver_result": receiver_result,
	}


static func deliver_to_targets(
	request: Dictionary,
	targets: Array[Node],
	source_actor: Node = null,
	delivery_context: Dictionary = {}
) -> Dictionary:
	var results: Array[Dictionary] = []
	var seen: Dictionary = {}
	for target: Node in targets:
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		if seen.has(target_id):
			continue
		seen[target_id] = true
		results.append(
			deliver_to_target(request, target, source_actor, delivery_context)
		)
	var delivered_count: int = 0
	for result: Dictionary in results:
		if bool(result.get("ok", false)):
			delivered_count += 1
	return {
		"ok": delivered_count > 0,
		"request_id": str(request.get("request_id", "")),
		"move_id": str(request.get("move_id", "")),
		"delivered_count": delivered_count,
		"results": results,
	}


static func _send_payload(target: Node, payload: DamagePayload) -> Dictionary:
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return _mark_received(payload_receiver.call("receive_payload", payload))
	if target.has_method("receive_damage_payload"):
		return _mark_received(target.call("receive_damage_payload", payload))
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null and hit_receiver.has_method("receive_payload"):
		return _mark_received(hit_receiver.call("receive_payload", payload))
	if target.has_method("receive_payload"):
		return _mark_received(target.call("receive_payload", payload))
	return {}


static func _mark_received(raw_result: Variant) -> Dictionary:
	var result: Dictionary = (
		(raw_result as Dictionary).duplicate(true)
		if raw_result is Dictionary
		else {}
	)
	result["_received"] = true
	return result


static func _apply_additional_statuses(
	target: Node,
	request: Dictionary,
	primary_status_id: String
) -> void:
	var payload_data: Dictionary = _dictionary(request.get("payload", {}))
	var raw_statuses: Variant = payload_data.get("statuses", [])
	if not raw_statuses is Array:
		return
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")
	if status_receiver == null:
		return
	for raw_status: Variant in raw_statuses as Array:
		if not raw_status is Dictionary:
			continue
		var status: Dictionary = raw_status as Dictionary
		var status_id: String = str(status.get("id", ""))
		var duration: float = maxf(float(status.get("duration", 0.0)), 0.0)
		if status_id == "" or duration <= 0.0 or status_id == primary_status_id:
			continue
		var strength: float = maxf(float(status.get("strength", 1.0)), 0.0)
		if status_receiver.has_method("sustain_status"):
			status_receiver.call("sustain_status", status_id, duration, strength, str(request.get("display_name", "Mob Move")))
		elif status_receiver.has_method("apply_status"):
			status_receiver.call("apply_status", status_id, duration, strength, str(request.get("display_name", "Mob Move")))


static func _direction_between(source_actor: Node, target: Node) -> Vector3:
	if not source_actor is Node3D or not target is Node3D:
		return Vector3.ZERO
	var direction: Vector3 = (
		(target as Node3D).global_position
		- (source_actor as Node3D).global_position
	)
	return direction.normalized() if direction.length_squared() > 0.0001 else Vector3.ZERO


static func _failure(request: Dictionary, error: String) -> Dictionary:
	return {
		"ok": false,
		"request_id": str(request.get("request_id", "")),
		"move_id": str(request.get("move_id", "")),
		"error": error,
	}


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
