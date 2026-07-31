extends RefCounted
class_name TacticalTargetCandidate


static func capture(actor: Node3D, target: Node3D) -> Dictionary:
	if target == null or not is_instance_valid(target):
		return {}
	var health: Dictionary = _capture_health(target)
	var stance: Dictionary = _capture_stance(target)
	var statuses: Array[String] = _capture_statuses(target)
	var target_position: Vector3 = _target_position(target)
	var actor_position: Vector3 = actor.global_position if actor != null else Vector3.ZERO
	var target_kind: String = _target_kind(target)
	return {
		"target_ref": target,
		"target_id": target.get_instance_id(),
		"target_name": _target_name(target),
		"target_kind": target_kind,
		"position": target_position,
		"distance": actor_position.distance_to(target_position),
		"current_health": int(health.get("current", 1)),
		"maximum_health": int(health.get("maximum", 1)),
		"health_fraction": float(health.get("fraction", 1.0)),
		"current_stance": int(stance.get("current", 0)),
		"maximum_stance": int(stance.get("maximum", 0)),
		"stance_fraction": float(stance.get("fraction", 1.0)),
		"statuses": statuses,
		"action_blocked": _actions_blocked(target),
		"defeated": is_defeated(target),
		"is_player": target.is_in_group("player"),
		"is_manifestation": target.is_in_group("manifested_avatar"),
		"is_friendly_actor": target.is_in_group("friendly_actor"),
	}


static func sanitize(candidate: Dictionary) -> Dictionary:
	var copy: Dictionary = candidate.duplicate(false)
	copy.erase("target_ref")
	var position_value: Variant = copy.get("position", Vector3.ZERO)
	if position_value is Vector3:
		var position: Vector3 = position_value
		copy["position"] = {
			"x": position.x,
			"y": position.y,
			"z": position.z,
		}
	var status_value: Variant = copy.get("statuses", [])
	if status_value is Array:
		copy["statuses"] = (status_value as Array).duplicate()
	return copy


static func is_defeated(target: Node) -> bool:
	if target == null or not is_instance_valid(target):
		return true
	if target.has_method("is_target_defeated"):
		return bool(target.call("is_target_defeated"))
	if _has_property(target, "defeated") and bool(target.get("defeated")):
		return true
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if hit_receiver != null and _has_property(hit_receiver, "current_health"):
		if int(hit_receiver.get("current_health")) <= 0:
			return true
	if target.is_in_group("player"):
		return GameState.get_stat("health") <= 0
	return false


static func _capture_health(target: Node) -> Dictionary:
	var current: int = 1
	var maximum: int = 1
	if target.is_in_group("player"):
		current = GameState.get_stat("health")
		maximum = maxi(GameState.get_stat("max_health"), 1)
	elif _has_property(target, "current_health") and _has_property(target, "maximum_health"):
		current = int(target.get("current_health"))
		maximum = maxi(int(target.get("maximum_health")), 1)
	else:
		var hit_receiver: Node = target.get_node_or_null("HitReceiver")
		if (
			hit_receiver != null
			and _has_property(hit_receiver, "current_health")
			and _has_property(hit_receiver, "max_health")
		):
			current = int(hit_receiver.get("current_health"))
			maximum = maxi(int(hit_receiver.get("max_health")), 1)
	return {
		"current": maxi(current, 0),
		"maximum": maximum,
		"fraction": clampf(float(maxi(current, 0)) / float(maximum), 0.0, 1.0),
	}


static func _capture_stance(target: Node) -> Dictionary:
	var current: int = 0
	var maximum: int = 0
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if (
		hit_receiver != null
		and _has_property(hit_receiver, "current_stance")
		and _has_property(hit_receiver, "max_stance")
	):
		current = maxi(int(hit_receiver.get("current_stance")), 0)
		maximum = maxi(int(hit_receiver.get("max_stance")), 0)
	return {
		"current": current,
		"maximum": maximum,
		"fraction": (
			clampf(float(current) / float(maximum), 0.0, 1.0)
			if maximum > 0
			else 1.0
		),
	}


static func _capture_statuses(target: Node) -> Array[String]:
	var statuses: Array[String] = []
	var receiver: Node = target.get_node_or_null("StatusReceiver")
	if receiver == null or not receiver.has_method("get_active_status_names"):
		return statuses
	var value: Variant = receiver.call("get_active_status_names")
	if value is Array:
		for raw: Variant in value as Array:
			var status_name: String = str(raw).strip_edges().to_lower()
			if status_name != "" and not statuses.has(status_name):
				statuses.append(status_name)
	return statuses


static func _actions_blocked(target: Node) -> bool:
	var receiver: Node = target.get_node_or_null("StatusReceiver")
	return (
		receiver != null
		and receiver.has_method("blocks_actions")
		and bool(receiver.call("blocks_actions"))
	)


static func _target_position(target: Node3D) -> Vector3:
	if target.has_method("get_targeting_aim_point"):
		var value: Variant = target.call("get_targeting_aim_point")
		if value is Vector3:
			return value
	return target.global_position


static func _target_name(target: Node) -> String:
	if target.has_meta("active_avatar_display_name"):
		var metadata_name: String = str(target.get_meta("active_avatar_display_name"))
		if metadata_name != "":
			return metadata_name
	if _has_property(target, "display_name"):
		var display_name: String = str(target.get("display_name"))
		if display_name != "":
			return display_name
	return str(target.name)


static func _target_kind(target: Node) -> String:
	if target.is_in_group("player"):
		return "player"
	if target.is_in_group("manifested_avatar"):
		return "manifestation"
	if target.is_in_group("summon"):
		return "summon"
	if target.is_in_group("friendly_actor"):
		return "ally"
	return "target"


static func _has_property(value: Object, property_name: String) -> bool:
	if value == null or not is_instance_valid(value):
		return false
	for property_value: Variant in value.get_property_list():
		if property_value is Dictionary and str((property_value as Dictionary).get("name", "")) == property_name:
			return true
	return false
