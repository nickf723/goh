extends RefCounted
class_name MobRecoveryBridge


static func apply_request(
	request: Dictionary,
	target: Node
) -> Dictionary:
	if target == null:
		return _failure(request, "missing recovery target")
	var effect: Dictionary = (
		(request.get("effect", {}) as Dictionary).duplicate(true)
		if request.get("effect", {}) is Dictionary
		else {}
	)
	if str(request.get("delivery", "")) != MobMoveEffectRequest.DELIVERY_RECOVERY:
		return _failure(request, "effect request is not recovery delivery")
	var receiver: Node = _find_receiver(target)
	if receiver == null:
		return {
			"ok": false,
			"request_id": str(request.get("request_id", "")),
			"move_id": str(request.get("move_id", "")),
			"requires_receiver": true,
			"effect": effect,
		}
	var raw_result: Variant
	if receiver.has_method("receive_mob_recovery"):
		raw_result = receiver.call("receive_mob_recovery", effect, request)
	elif receiver.has_method("receive_recovery"):
		raw_result = receiver.call("receive_recovery", effect)
	elif receiver.has_method("receive_healing"):
		raw_result = receiver.call(
			"receive_healing",
			maxi(int(round(float(effect.get("health", 0.0)))), 0)
		)
	else:
		return _failure(request, "recovery receiver has no compatible method")
	var result: Dictionary = (
		(raw_result as Dictionary).duplicate(true)
		if raw_result is Dictionary
		else {}
	)
	if not result.has("ok"):
		result["ok"] = true
	result["request_id"] = str(request.get("request_id", ""))
	result["move_id"] = str(request.get("move_id", ""))
	result["target_instance_id"] = target.get_instance_id()
	result["effect"] = effect
	return result


static func _find_receiver(target: Node) -> Node:
	for component_name: String in ["RecoveryReceiver", "HitReceiver"]:
		var component: Node = target.get_node_or_null(component_name)
		if component != null and (
			component.has_method("receive_mob_recovery")
			or component.has_method("receive_recovery")
			or component.has_method("receive_healing")
		):
			return component
	if (
		target.has_method("receive_mob_recovery")
		or target.has_method("receive_recovery")
		or target.has_method("receive_healing")
	):
		return target
	return null


static func _failure(request: Dictionary, error: String) -> Dictionary:
	return {
		"ok": false,
		"request_id": str(request.get("request_id", "")),
		"move_id": str(request.get("move_id", "")),
		"error": error,
	}
