extends RefCounted
class_name TacticalTargetCandidate


static var property_names_by_contract: Dictionary = {}
static var zero_argument_methods_by_contract: Dictionary = {}
static var reflection_build_count: int = 0
static var reflection_cache_hit_count: int = 0


static func capture(actor: Node3D, target: Node3D) -> Dictionary:
	if not is_instance_valid(target):
		return {}
	var health: Dictionary = _capture_health(target)
	var stance: Dictionary = _capture_stance(target)
	var statuses: Array[String] = _capture_statuses(target)
	var target_position: Vector3 = _target_position(target)
	var actor_position: Vector3 = actor.global_position if is_instance_valid(actor) else Vector3.ZERO
	return {
		"target_ref": target,
		"target_id": target.get_instance_id(),
		"target_name": _target_name(target),
		"target_kind": _target_kind(target),
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
		copy["position"] = {"x": position.x, "y": position.y, "z": position.z}
	var status_value: Variant = copy.get("statuses", [])
	if status_value is Array:
		copy["statuses"] = (status_value as Array).duplicate()
	return copy


static func is_defeated(target: Node) -> bool:
	if not is_instance_valid(target):
		return true
	if target.is_in_group("player"):
		return GameState.get_stat("health") <= 0
	if _can_call_without_arguments(target, "is_target_defeated"):
		return bool(target.call("is_target_defeated"))
	if _has_property(target, "defeated") and bool(target.get("defeated")):
		return true
	var hit_receiver: Node = target.get_node_or_null("HitReceiver")
	if is_instance_valid(hit_receiver) and _has_property(hit_receiver, "current_health"):
		return int(hit_receiver.get("current_health")) <= 0
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
			is_instance_valid(hit_receiver)
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
		is_instance_valid(hit_receiver)
		and _has_property(hit_receiver, "current_stance")
		and _has_property(hit_receiver, "max_stance")
	):
		current = maxi(int(hit_receiver.get("current_stance")), 0)
		maximum = maxi(int(hit_receiver.get("max_stance")), 0)
	return {
		"current": current,
		"maximum": maximum,
		"fraction": clampf(float(current) / float(maximum), 0.0, 1.0) if maximum > 0 else 1.0,
	}


static func _capture_statuses(target: Node) -> Array[String]:
	var statuses: Array[String] = []
	var receiver: Node = target.get_node_or_null("StatusReceiver")
	if not is_instance_valid(receiver) or not receiver.has_method("get_active_status_names"):
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
		is_instance_valid(receiver)
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


static func _can_call_without_arguments(value: Object, method_name: String) -> bool:
	if not is_instance_valid(value):
		return false
	var contract_key: String = _contract_key(value)
	if zero_argument_methods_by_contract.has(contract_key):
		reflection_cache_hit_count += 1
		var cached: Dictionary = zero_argument_methods_by_contract[contract_key] as Dictionary
		return bool(cached.get(method_name, false))
	var methods: Dictionary = {}
	for method_value: Variant in value.get_method_list():
		if not method_value is Dictionary:
			continue
		var method: Dictionary = method_value as Dictionary
		var name_value: String = str(method.get("name", ""))
		if name_value == "":
			continue
		var arguments_value: Variant = method.get("args", [])
		var defaults_value: Variant = method.get("default_args", [])
		var argument_count: int = (arguments_value as Array).size() if arguments_value is Array else 0
		var default_count: int = (defaults_value as Array).size() if defaults_value is Array else 0
		methods[name_value] = maxi(argument_count - default_count, 0) == 0
	zero_argument_methods_by_contract[contract_key] = methods
	reflection_build_count += 1
	return bool(methods.get(method_name, false))


static func _has_property(value: Object, property_name: String) -> bool:
	if not is_instance_valid(value):
		return false
	var contract_key: String = _contract_key(value)
	if property_names_by_contract.has(contract_key):
		reflection_cache_hit_count += 1
		var cached: Dictionary = property_names_by_contract[contract_key] as Dictionary
		return bool(cached.get(property_name, false))
	var properties: Dictionary = {}
	for property_value: Variant in value.get_property_list():
		if property_value is Dictionary:
			var name_value: String = str((property_value as Dictionary).get("name", ""))
			if name_value != "":
				properties[name_value] = true
	property_names_by_contract[contract_key] = properties
	reflection_build_count += 1
	return bool(properties.get(property_name, false))


static func _contract_key(value: Object) -> String:
	var script_value: Variant = value.get_script()
	if script_value is Script:
		var script: Script = script_value as Script
		if script.resource_path != "":
			return script.resource_path
		return "script:" + str(script.get_instance_id())
	return "native:" + value.get_class()


static func clear_contract_cache() -> void:
	property_names_by_contract.clear()
	zero_argument_methods_by_contract.clear()
	reflection_build_count = 0
	reflection_cache_hit_count = 0


static func get_performance_debug_data() -> Dictionary:
	return {
		"contract_count": property_names_by_contract.size() + zero_argument_methods_by_contract.size(),
		"reflection_builds": reflection_build_count,
		"reflection_cache_hits": reflection_cache_hit_count,
	}
