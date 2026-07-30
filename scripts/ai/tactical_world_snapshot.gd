extends RefCounted
class_name TacticalWorldSnapshot

const StatePolicy = preload("res://scripts/systems/reaction_state_policy.gd")

const DEFAULT_HAZARD_SCAN_RADIUS: float = 12.0
const DEFAULT_HAZARD_RADIUS: float = 2.5


static func capture(
	actor: Node3D,
	target: Node3D,
	context: Dictionary = {}
) -> Dictionary:
	var ignored_hazard_tags: Array[String] = _string_array(
		context.get("ignored_hazard_tags", [])
	)
	var hazards: Array[Dictionary] = []
	var explicit_hazards: Variant = context.get("nearby_hazards", null)
	if explicit_hazards is Array:
		hazards = _dictionary_array(explicit_hazards)
	else:
		hazards = _scan_hazards(
		actor,
		target,
		float(context.get("hazard_scan_radius", DEFAULT_HAZARD_SCAN_RADIUS)),
		ignored_hazard_tags
	)

	var actor_data: Dictionary = capture_entity(actor)
	var target_data: Dictionary = capture_entity(target)
	var path_danger: Dictionary = _summarize_path_danger(
		actor_data.get("position", Vector3.ZERO) as Vector3,
		target_data.get("position", Vector3.ZERO) as Vector3,
		hazards
	)
	return {
		"actor": actor_data,
		"target": target_data,
		"relation": str(context.get("relation", "hostile")),
		"nearby_hazards": hazards,
		"path_danger": path_danger,
		"preferred_payoff_tags": _string_array(
			context.get("preferred_payoff_tags", [])
		),
		"available_followup_tags": _string_array(
			context.get("available_followup_tags", [])
		),
		"claimed_reactions": _string_array(
			context.get("claimed_reactions", [])
		),
		"context_tags": _string_array(context.get("context_tags", [])),
	}


static func capture_entity(entity: Node) -> Dictionary:
	var state: Dictionary = StatePolicy.capture_target_state(entity)
	var position: Vector3 = Vector3.ZERO
	if entity is Node3D:
		position = (entity as Node3D).global_position
	return {
		"name": entity.name if entity != null else "none",
		"instance_id": entity.get_instance_id() if entity != null else 0,
		"position": position,
		"statuses": _string_array(state.get("statuses", [])),
		"tags": _string_array(state.get("tags", [])),
		"health_fraction": _get_health_fraction(entity),
		"alive": _is_alive(entity),
	}


static func make_test_snapshot(
	actor_statuses: Array[String],
	target_statuses: Array[String],
	context: Dictionary = {}
) -> Dictionary:
	var actor_data: Dictionary = {
		"name": "Actor",
		"instance_id": 1,
		"position": Vector3.ZERO,
		"statuses": _normalize_states(actor_statuses),
		"tags": _normalize_states(actor_statuses),
		"health_fraction": float(context.get("actor_health_fraction", 1.0)),
		"alive": true,
	}
	var target_data: Dictionary = {
		"name": "Target",
		"instance_id": 2,
		"position": Vector3(0.0, 0.0, -4.0),
		"statuses": _normalize_states(target_statuses),
		"tags": _normalize_states(target_statuses),
		"health_fraction": float(context.get("target_health_fraction", 1.0)),
		"alive": true,
	}
	var hazards: Array[Dictionary] = _dictionary_array(
		context.get("nearby_hazards", [])
	)
	return {
		"actor": actor_data,
		"target": target_data,
		"relation": str(context.get("relation", "hostile")),
		"nearby_hazards": hazards,
		"path_danger": context.get(
			"path_danger",
			_summarize_path_danger(Vector3.ZERO, Vector3(0.0, 0.0, -4.0), hazards)
		),
		"preferred_payoff_tags": _string_array(
			context.get("preferred_payoff_tags", [])
		),
		"available_followup_tags": _string_array(
			context.get("available_followup_tags", [])
		),
		"claimed_reactions": _string_array(
			context.get("claimed_reactions", [])
		),
		"context_tags": _string_array(context.get("context_tags", [])),
	}


static func _scan_hazards(
	actor: Node3D,
	target: Node3D,
	scan_radius: float,
	ignored_tags: Array[String]
) -> Array[Dictionary]:
	var hazards: Array[Dictionary] = []
	var tree: SceneTree = actor.get_tree() if actor != null else (
		target.get_tree() if target != null else null
	)
	if tree == null:
		return hazards
	var origin: Vector3 = actor.global_position if actor != null else target.global_position
	for node: Node in tree.get_nodes_in_group("hazard_reactive"):
		if not node is Node3D or not node.has_method("get_hazard_tags"):
			continue
		var hazard: Node3D = node as Node3D
		if origin.distance_to(hazard.global_position) > maxf(scan_radius, 0.0):
			continue
		var tags: Array[String] = _string_array(hazard.call("get_hazard_tags"))
		if _contains_any(tags, ignored_tags):
			continue
		var radius: float = DEFAULT_HAZARD_RADIUS
		var radius_value: Variant = hazard.get("radius")
		if radius_value != null:
			radius = maxf(float(radius_value), 0.25)
		hazards.append({
			"name": hazard.name,
			"position": hazard.global_position,
			"radius": radius,
			"severity": _get_hazard_severity(tags),
			"tags": tags,
		})
	return hazards


static func _summarize_path_danger(
	start: Vector3,
	finish: Vector3,
	hazards: Array[Dictionary]
) -> Dictionary:
	var intersecting: Array[String] = []
	var maximum_severity: float = 0.0
	for hazard: Dictionary in hazards:
		var position_value: Variant = hazard.get("position", Vector3.ZERO)
		var position: Vector3 = (
			position_value as Vector3 if position_value is Vector3 else Vector3.ZERO
		)
		var radius: float = maxf(float(hazard.get("radius", DEFAULT_HAZARD_RADIUS)), 0.0)
		if _distance_to_segment(position, start, finish) > radius:
			continue
		intersecting.append(str(hazard.get("name", "hazard")))
		maximum_severity = maxf(
			maximum_severity,
			float(hazard.get("severity", 1.0))
		)
	return {
		"blocked": not intersecting.is_empty() and maximum_severity >= 0.75,
		"count": intersecting.size(),
		"maximum_severity": maximum_severity,
		"hazards": intersecting,
	}


static func _get_health_fraction(entity: Node) -> float:
	if entity == null:
		return 1.0
	var receiver: Node = entity.get_node_or_null("HitReceiver")
	if receiver == null:
		receiver = entity
	var current_value: Variant = receiver.get("current_health")
	var maximum_value: Variant = receiver.get("max_health")
	if current_value == null or maximum_value == null:
		return 1.0
	var maximum: float = maxf(float(maximum_value), 1.0)
	return clampf(float(current_value) / maximum, 0.0, 1.0)


static func _is_alive(entity: Node) -> bool:
	if entity == null:
		return false
	return _get_health_fraction(entity) > 0.0


static func _get_hazard_severity(tags: Array[String]) -> float:
	if _contains_any(tags, ["poison", "gas", "fire", "burning", "explosion"]):
		return 1.0
	if _contains_any(tags, ["ice", "slow", "snare", "trap", "hazard"]):
		return 0.72
	return 0.45


static func _distance_to_segment(point: Vector3, start: Vector3, finish: Vector3) -> float:
	var segment: Vector3 = finish - start
	segment.y = 0.0
	var relative: Vector3 = point - start
	relative.y = 0.0
	var length_squared: float = segment.length_squared()
	if length_squared <= 0.0001:
		return relative.length()
	var t: float = clampf(relative.dot(segment) / length_squared, 0.0, 1.0)
	return relative.distance_to(segment * t)


static func _normalize_states(values: Array[String]) -> Array[String]:
	var result: Array[String] = []
	for value: String in values:
		_append_unique(result, StatePolicy.normalize_state(value))
	return result


static func _contains_any(values: Array[String], required: Array[String]) -> bool:
	for value: String in required:
		if values.has(value.strip_edges().to_lower()):
			return true
	return false


static func _dictionary_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for raw: Variant in value as Array:
			if raw is Dictionary:
				result.append((raw as Dictionary).duplicate(true))
	return result


static func _string_array(value: Variant) -> Array[String]:
	var result: Array[String] = []
	if value is Array:
		for raw: Variant in value as Array:
			_append_unique(result, str(raw))
	return result


static func _append_unique(target: Array[String], value: String) -> void:
	var normalized: String = value.strip_edges().to_lower()
	if normalized == "" or target.has(normalized):
		return
	target.append(normalized)
