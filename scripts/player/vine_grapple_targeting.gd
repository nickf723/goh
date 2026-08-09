extends RefCounted
class_name VineGrappleTargeting

const SOURCE_HARD_LOCK: String = "hard_lock"
const SOURCE_DIRECT: String = "direct"
const SOURCE_SOFT_ASSIST: String = "soft_assist"
const SOURCE_SOFT_SCAN: String = "soft_scan"


static func resolve_target(
	source_actor: Node3D,
	maximum_range: float = 22.0,
	maximum_rigidbody_mass: float = 180.0,
	soft_aim_angle_degrees: float = 20.0,
	require_line_of_sight: bool = true
) -> Dictionary:
	if source_actor == null or not is_instance_valid(source_actor):
		return _empty_result("no_source")

	var hard_target: Node3D = _get_hard_target(source_actor)
	if hard_target != null:
		return evaluate_target(
			source_actor,
			hard_target,
			get_target_point(source_actor, hard_target),
			maximum_range,
			maximum_rigidbody_mass,
			require_line_of_sight,
			SOURCE_HARD_LOCK
		)

	var direct_result: Dictionary = _raycast_camera_target(
		source_actor,
		maximum_range,
		maximum_rigidbody_mass,
		require_line_of_sight
	)
	if not direct_result.is_empty():
		return direct_result

	var soft_target: Node3D = _get_soft_target(source_actor)
	if soft_target != null:
		var soft_result: Dictionary = evaluate_target(
			source_actor,
			soft_target,
			get_target_point(source_actor, soft_target),
			maximum_range,
			maximum_rigidbody_mass,
			require_line_of_sight,
			SOURCE_SOFT_ASSIST
		)
		if bool(soft_result.get("valid", false)):
			return soft_result

	return _find_soft_target(
		source_actor,
		maximum_range,
		maximum_rigidbody_mass,
		soft_aim_angle_degrees,
		require_line_of_sight
	)


static func evaluate_target(
	source_actor: Node3D,
	target: Node3D,
	point: Vector3,
	maximum_range: float,
	maximum_rigidbody_mass: float,
	require_line_of_sight: bool,
	source_kind: String = "manual"
) -> Dictionary:
	if target == null or not is_instance_valid(target):
		return _empty_result("no_target")

	var distance: float = source_actor.global_position.distance_to(point)
	var reason: String = get_rejection_reason(
		target,
		source_actor,
		maximum_rigidbody_mass
	)
	if reason == "" and distance > maximum_range:
		reason = "out_of_range"
	if (
		reason == ""
		and require_line_of_sight
		and not has_line_of_sight(source_actor, point, target)
	):
		reason = "blocked"

	return {
		"target": target,
		"point": point,
		"valid": reason == "",
		"reason": reason,
		"source": source_kind,
		"distance": distance,
	}


static func get_rejection_reason(
	target: Node3D,
	source_actor: Node3D,
	maximum_rigidbody_mass: float
) -> String:
	if target == null or target == source_actor:
		return "not_pullable"
	if target.is_in_group("vine_grapple_immune"):
		return "immune"
	if target.has_method("can_accept_vine_grapple"):
		return "" if bool(target.call("can_accept_vine_grapple", source_actor)) else "resists"
	if target.is_in_group("vine_grapple_target"):
		return ""
	if target is RigidBody3D:
		var rigid_body: RigidBody3D = target as RigidBody3D
		if rigid_body.freeze:
			return "anchored"
		if rigid_body.mass > maximum_rigidbody_mass:
			return "too_heavy"
		return ""
	if target is CharacterBody3D and target.is_in_group("enemy"):
		return ""
	if find_force_receiver(target) != null:
		return ""
	return "not_pullable"


static func is_pullable(
	target: Node3D,
	source_actor: Node3D,
	maximum_rigidbody_mass: float
) -> bool:
	return get_rejection_reason(
		target,
		source_actor,
		maximum_rigidbody_mass
	) == ""


static func get_target_point(source_actor: Node3D, target: Node3D) -> Vector3:
	if target == null or not is_instance_valid(target):
		return source_actor.global_position if source_actor != null and is_instance_valid(source_actor) else Vector3.ZERO
	if target.has_method("get_vine_grapple_anchor_position"):
		var custom_value: Variant = target.call("get_vine_grapple_anchor_position")
		if custom_value is Vector3:
			return custom_value as Vector3

	var assist: Node = source_actor.get_node_or_null("CombatTargetingAssist") if source_actor != null and is_instance_valid(source_actor) else null
	if assist != null and is_instance_valid(assist) and assist.has_method("get_target_aim_point"):
		var assist_value: Variant = assist.call("get_target_aim_point", target)
		if assist_value is Vector3:
			return assist_value as Vector3

	if target.has_method("get_tether_anchor_position"):
		var tether_value: Variant = target.call("get_tether_anchor_position")
		if tether_value is Vector3:
			return tether_value as Vector3
	return target.global_position + Vector3.UP * 0.55


static func get_source_anchor_position(source_actor: Node3D) -> Vector3:
	if source_actor == null or not is_instance_valid(source_actor):
		return Vector3.ZERO
	for anchor_path: String in [
		"GraceVisualV1/RightHandAnchor",
		"RightHandAnchor",
		"CastingHandAnchor",
	]:
		var anchor: Node3D = source_actor.get_node_or_null(anchor_path) as Node3D
		if anchor != null:
			return anchor.global_position
	var recursive_anchor: Node = source_actor.find_child(
		"RightHandAnchor",
		true,
		false
	)
	if recursive_anchor is Node3D:
		return (recursive_anchor as Node3D).global_position
	return source_actor.global_position + Vector3.UP * 0.72


static func get_target_display_name(target: Node) -> String:
	if target == null or not is_instance_valid(target):
		return "Target"
	var display_value: Variant = target.get("display_name")
	if display_value != null and str(display_value).strip_edges() != "":
		return str(display_value)
	var brain: Node = target.get_node_or_null("EnemyBrain")
	if brain != null and brain.has_method("get_definition"):
		var definition: Variant = brain.call("get_definition")
		if definition != null:
			var brain_name: Variant = definition.get("display_name")
			if brain_name != null and str(brain_name).strip_edges() != "":
				return str(brain_name)
	var source_label: Variant = target.get("source_label")
	if source_label != null and str(source_label).strip_edges() != "":
		return str(source_label)
	return target.name.capitalize()


static func get_reason_label(reason: String) -> String:
	match reason:
		"too_heavy":
			return "TOO HEAVY"
		"anchored":
			return "ANCHORED"
		"immune":
			return "IMMUNE"
		"resists":
			return "RESISTS"
		"out_of_range":
			return "OUT OF RANGE"
		"blocked":
			return "BLOCKED"
		"not_pullable":
			return "CAN'T GRAPPLE"
		_:
			return "NO TARGET"


static func find_force_receiver(target: Node) -> Node:
	if target == null or not is_instance_valid(target):
		return null
	if target is ForceReceiver:
		return target
	var direct: Node = target.get_node_or_null("ForceReceiver")
	if direct != null:
		return direct
	for child: Node in target.get_children():
		if child is ForceReceiver:
			return child
	return null


static func has_line_of_sight(
	source_actor: Node3D,
	point: Vector3,
	target: Node3D
) -> bool:
	if source_actor == null or not is_instance_valid(source_actor):
		return false
	if target == null or not is_instance_valid(target):
		return false
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return false
	var camera: Camera3D = source_actor.get_viewport().get_camera_3d()
	var origin: Vector3 = camera.global_position if camera != null else get_source_anchor_position(source_actor)
	var query := PhysicsRayQueryParameters3D.create(origin, point)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = get_source_collision_exclusions(source_actor)
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider: Node = result.get("collider") as Node
	return _node_belongs_to_target(collider, target)


static func get_source_collision_exclusions(source_actor: Node) -> Array[RID]:
	var exclusions: Array[RID] = []
	_collect_collision_rids(source_actor, exclusions)
	return exclusions


static func _get_hard_target(source_actor: Node3D) -> Node3D:
	if source_actor == null or not is_instance_valid(source_actor):
		return null
	var lock_target: Node3D = _valid_node3d_reference(
		source_actor.get("lock_on_target")
	)
	if lock_target != null:
		return _resolve_candidate(lock_target, source_actor)
	var assist: Node = source_actor.get_node_or_null("CombatTargetingAssist")
	if assist != null and is_instance_valid(assist):
		var assist_target: Node3D = _valid_node3d_reference(
			assist.get("hard_target")
		)
		if assist_target != null:
			return _resolve_candidate(assist_target, source_actor)
	return null


static func _get_soft_target(source_actor: Node3D) -> Node3D:
	if source_actor == null or not is_instance_valid(source_actor):
		return null
	var assist: Node = source_actor.get_node_or_null("CombatTargetingAssist")
	if assist == null or not is_instance_valid(assist):
		return null
	var target: Node3D = _valid_node3d_reference(assist.get("soft_target"))
	if target == null:
		return null
	return _resolve_candidate(target, source_actor)


static func _valid_node3d_reference(value: Variant) -> Node3D:
	# A target may be freed between the enemy update and the player's targeting
	# preview update. Never ask GDScript `value is Node3D` until validity has been
	# established, because type-testing a freed Object reference raises at runtime.
	if typeof(value) != TYPE_OBJECT:
		return null
	if not is_instance_valid(value):
		return null
	return value as Node3D if value is Node3D else null


static func _raycast_camera_target(
	source_actor: Node3D,
	maximum_range: float,
	maximum_rigidbody_mass: float,
	require_line_of_sight: bool
) -> Dictionary:
	var camera: Camera3D = source_actor.get_viewport().get_camera_3d()
	var world: World3D = source_actor.get_world_3d()
	if camera == null or world == null:
		return {}
	var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
	var screen_center: Vector2 = viewport_rect.position + viewport_rect.size * 0.5
	var origin: Vector3 = camera.project_ray_origin(screen_center)
	var direction: Vector3 = camera.project_ray_normal(screen_center)
	if direction.length_squared() <= 0.0001:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + direction.normalized() * maximum_range
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = get_source_collision_exclusions(source_actor)
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var collider: Node = hit.get("collider") as Node
	var candidate: Node3D = _resolve_candidate(collider, source_actor)
	if candidate == null:
		return {}
	var point_value: Variant = hit.get("position")
	var point: Vector3 = (
		point_value as Vector3
		if point_value is Vector3
		else get_target_point(source_actor, candidate)
	)
	return evaluate_target(
		source_actor,
		candidate,
		point,
		maximum_range,
		maximum_rigidbody_mass,
		require_line_of_sight,
		SOURCE_DIRECT
	)


static func _find_soft_target(
	source_actor: Node3D,
	maximum_range: float,
	maximum_rigidbody_mass: float,
	soft_aim_angle_degrees: float,
	require_line_of_sight: bool
) -> Dictionary:
	var tree: SceneTree = source_actor.get_tree()
	var camera: Camera3D = source_actor.get_viewport().get_camera_3d()
	if tree == null or camera == null:
		return _empty_result("no_target")

	var origin: Vector3 = camera.global_position
	var forward: Vector3 = -camera.global_basis.z
	if forward.length_squared() <= 0.0001:
		return _empty_result("no_target")
	forward = forward.normalized()
	var minimum_dot: float = cos(deg_to_rad(soft_aim_angle_degrees))
	var best_result: Dictionary = {}
	var best_score: float = INF
	var seen: Dictionary = {}

	for group_name: String in ["enemy", "vine_grapple_target"]:
		for raw_candidate: Node in tree.get_nodes_in_group(group_name):
			var candidate: Node3D = _resolve_candidate(raw_candidate, source_actor)
			if candidate == null:
				continue
			var candidate_id: int = candidate.get_instance_id()
			if seen.has(candidate_id):
				continue
			seen[candidate_id] = true

			var point: Vector3 = get_target_point(source_actor, candidate)
			var offset: Vector3 = point - origin
			var distance: float = source_actor.global_position.distance_to(point)
			if distance <= 0.25 or distance > maximum_range or offset.length_squared() <= 0.0001:
				continue
			var aim_dot: float = forward.dot(offset.normalized())
			if aim_dot < minimum_dot:
				continue
			var result: Dictionary = evaluate_target(
				source_actor,
				candidate,
				point,
				maximum_range,
				maximum_rigidbody_mass,
				require_line_of_sight,
				SOURCE_SOFT_SCAN
			)
			if not bool(result.get("valid", false)):
				continue
			var score: float = (
				(1.0 - aim_dot) * 30.0
				+ distance / maxf(maximum_range, 0.01)
			)
			if score < best_score:
				best_score = score
				best_result = result

	return best_result if not best_result.is_empty() else _empty_result("no_target")


static func _resolve_candidate(start_node: Node, source_actor: Node3D) -> Node3D:
	if start_node == null or not is_instance_valid(start_node):
		return null
	var current: Node = start_node
	while current != null and current != source_actor:
		if not is_instance_valid(current):
			return null
		if current is Node3D and _looks_like_candidate(current as Node3D):
			return current as Node3D
		current = current.get_parent()
	return null


static func _looks_like_candidate(candidate: Node3D) -> bool:
	if candidate == null or not is_instance_valid(candidate):
		return false
	return (
		candidate.has_method("can_accept_vine_grapple")
		or candidate.is_in_group("vine_grapple_target")
		or candidate.is_in_group("vine_grapple_immune")
		or candidate is RigidBody3D
		or (candidate is CharacterBody3D and candidate.is_in_group("enemy"))
		or find_force_receiver(candidate) != null
	)


static func _node_belongs_to_target(node: Node, target: Node) -> bool:
	if node == null or target == null:
		return false
	if not is_instance_valid(node) or not is_instance_valid(target):
		return false
	var current: Node = node
	while current != null:
		if not is_instance_valid(current):
			return false
		if current == target:
			return true
		current = current.get_parent()
	return false


static func _collect_collision_rids(node: Node, exclusions: Array[RID]) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is CollisionObject3D:
		var collision_object: CollisionObject3D = node as CollisionObject3D
		var rid: RID = collision_object.get_rid()
		if rid.is_valid() and not exclusions.has(rid):
			exclusions.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, exclusions)


static func _empty_result(reason: String) -> Dictionary:
	return {
		"target": null,
		"point": Vector3.ZERO,
		"valid": false,
		"reason": reason,
		"source": "none",
		"distance": 0.0,
	}
