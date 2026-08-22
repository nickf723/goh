extends RefCounted
class_name MobEffectTargetResolver


static func resolve_targets(
	source_actor: Node,
	request: Dictionary,
	target_provider: Node = null,
	options: Dictionary = {}
) -> Array[Node]:
	var candidates: Array[Node] = []
	var provider_is_authoritative: bool = _append_provider_targets(
		candidates,
		target_provider,
		request
	)
	_append_explicit_targets(candidates, options)
	if candidates.is_empty() and not provider_is_authoritative:
		_append_group_targets(candidates, source_actor, request, options)
	if str(request.get("target_mode", "")) == "self" and source_actor != null:
		candidates.append(source_actor)
	return _filter_targets(source_actor, request, candidates, options)


static func resolve_primary_target(
	source_actor: Node,
	request: Dictionary,
	target_provider: Node = null,
	options: Dictionary = {}
) -> Node:
	var targets: Array[Node] = resolve_targets(
		source_actor,
		request,
		target_provider,
		options
	)
	return targets[0] if not targets.is_empty() else null


static func _append_provider_targets(
	targets: Array[Node],
	provider: Node,
	request: Dictionary
) -> bool:
	if provider == null or not provider.has_method("get_mob_effect_targets"):
		return false
	var raw_targets: Variant = provider.call("get_mob_effect_targets", request)
	_append_nodes(targets, raw_targets)
	return true


static func _append_explicit_targets(
	targets: Array[Node],
	options: Dictionary
) -> void:
	_append_nodes(targets, options.get("primary_target"))
	_append_nodes(targets, options.get("targets", []))


static func _append_group_targets(
	targets: Array[Node],
	source_actor: Node,
	request: Dictionary,
	options: Dictionary
) -> void:
	if source_actor == null or source_actor.get_tree() == null:
		return
	var target_mode: String = str(
		request.get("target_mode", "")
	).to_lower().strip_edges()
	var groups: Array[String] = []
	match target_mode:
		"enemy", "area":
			groups = _string_array(options.get("enemy_groups", []))
		"allies":
			groups = _string_array(options.get("ally_groups", []))
		"environment":
			groups = _string_array(options.get("environment_groups", []))
		_:
			return
	for group_id: String in groups:
		for candidate: Node in source_actor.get_tree().get_nodes_in_group(group_id):
			targets.append(candidate)


static func _filter_targets(
	source_actor: Node,
	request: Dictionary,
	candidates: Array[Node],
	options: Dictionary
) -> Array[Node]:
	var results: Array[Node] = []
	var seen: Dictionary = {}
	var target_mode: String = str(
		request.get("target_mode", "")
	).to_lower().strip_edges()
	var maximum_distance: float = _maximum_distance(request)
	var require_line_of_sight: bool = bool(
		(request.get("effect", {}) as Dictionary).get(
			"requires_line_of_sight",
			false
		)
	)
	for candidate: Node in candidates:
		var target: Node = _payload_target(candidate)
		if not is_instance_valid(target):
			continue
		if target == source_actor and target_mode != "self":
			continue
		if not _passes_target_filter(source_actor, target, request, options):
			continue
		if source_actor != null and source_actor.is_ancestor_of(target):
			continue
		var target_id: int = target.get_instance_id()
		if seen.has(target_id):
			continue
		if (
			maximum_distance > 0.0
			and source_actor is Node3D
			and target is Node3D
			and (source_actor as Node3D).global_position.distance_to(
				(target as Node3D).global_position
			) > maximum_distance
		):
			continue
		if (
			require_line_of_sight
			and not _has_line_of_sight(
				source_actor,
				target,
				int(options.get("collision_mask", 0xFFFFFFFF))
			)
		):
			continue
		seen[target_id] = true
		results.append(target)
	results.sort_custom(func(a: Node, b: Node) -> bool:
		return _distance_squared(source_actor, a) < _distance_squared(source_actor, b)
	)
	return results


static func _maximum_distance(request: Dictionary) -> float:
	var delivery: String = str(request.get("delivery", ""))
	if delivery == MobMoveEffectRequest.DELIVERY_AREA_PAYLOAD:
		return maxf(float(request.get("radius", 0.0)), 0.0)
	return maxf(float(request.get("maximum_range", 0.0)), 0.0)


static func _payload_target(candidate: Node) -> Node:
	if candidate == null:
		return null
	var current: Node = candidate
	while current != null:
		if _is_payload_or_recovery_target(current):
			return current
		current = current.get_parent()
	return candidate


static func _is_payload_or_recovery_target(candidate: Node) -> bool:
	if candidate.has_method("receive_damage_payload"):
		return true
	if candidate.has_method("receive_mob_recovery"):
		return true
	if candidate.has_method("receive_healing"):
		return true
	for component_name: String in [
		"PayloadReceiver",
		"HitReceiver",
		"RecoveryReceiver",
	]:
		if candidate.get_node_or_null(component_name) != null:
			return true
	return false


static func _passes_target_filter(
	source_actor: Node,
	target: Node,
	request: Dictionary,
	options: Dictionary
) -> bool:
	var raw_filter: Variant = options.get("target_filter")
	if not raw_filter is Callable:
		return true
	var target_filter: Callable = raw_filter as Callable
	if not target_filter.is_valid():
		return true
	return bool(target_filter.call(source_actor, target, request))


static func _has_line_of_sight(
	source_actor: Node,
	target: Node,
	collision_mask: int
) -> bool:
	if not source_actor is Node3D or not target is Node3D:
		return true
	var source_3d: Node3D = source_actor as Node3D
	var target_3d: Node3D = target as Node3D
	if source_3d.get_world_3d() == null:
		return true
	var exclusions: Array[RID] = []
	if source_actor is CollisionObject3D:
		exclusions.append((source_actor as CollisionObject3D).get_rid())
	var query := PhysicsRayQueryParameters3D.create(
		source_3d.global_position,
		target_3d.global_position,
		collision_mask,
		exclusions
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var hit: Dictionary = source_3d.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var collider_value: Variant = hit.get("collider")
	if not collider_value is Node:
		return false
	var collider: Node = collider_value as Node
	return (
		collider == target
		or target.is_ancestor_of(collider)
		or collider.is_ancestor_of(target)
	)


static func _append_nodes(targets: Array[Node], raw_value: Variant) -> void:
	if raw_value is Node:
		targets.append(raw_value as Node)
		return
	if raw_value is Array:
		for raw_target: Variant in raw_value as Array:
			if raw_target is Node:
				targets.append(raw_target as Node)


static func _distance_squared(source_actor: Node, target: Node) -> float:
	if source_actor is Node3D and target is Node3D:
		return (source_actor as Node3D).global_position.distance_squared_to(
			(target as Node3D).global_position
		)
	return 0.0


static func _string_array(raw_value: Variant) -> Array[String]:
	var result: Array[String] = []
	if raw_value is Array:
		for raw: Variant in raw_value as Array:
			var normalized: String = str(raw).to_lower().strip_edges()
			if normalized != "" and not result.has(normalized):
				result.append(normalized)
	return result
