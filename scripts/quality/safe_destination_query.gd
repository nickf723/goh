extends RefCounted
class_name SafeDestinationQuery

const ALL_COLLISION_LAYERS: int = 0x7fffffff


static func find_safe_destination(
	actor: CharacterBody3D,
	desired_position: Vector3,
	options: Dictionary = {}
) -> Dictionary:
	if actor == null or actor.get_world_3d() == null:
		return _failure(desired_position, "no_actor")

	var playable_space: Node = options.get("playable_space") as Node
	if playable_space == null:
		playable_space = _find_playable_space(actor)

	var start_position: Vector3 = options.get("start_position", actor.global_position)
	var search_steps: int = maxi(int(options.get("search_steps", 8)), 0)
	var candidates: Array[Vector3] = [desired_position]
	if search_steps > 0 and start_position.distance_squared_to(desired_position) > 0.0001:
		for step: int in range(1, search_steps + 1):
			candidates.append(desired_position.lerp(start_position, float(step) / float(search_steps)))

	for candidate: Vector3 in candidates:
		var result: Dictionary = _evaluate_candidate(actor, candidate, playable_space, options)
		if bool(result.get("valid", false)):
			result["requested_position"] = desired_position
			result["snapped"] = candidate.distance_to(desired_position) > 0.05
			return result

	return _failure(desired_position, "no_safe_candidate")


static func validate_current_position(
	actor: CharacterBody3D,
	options: Dictionary = {}
) -> Dictionary:
	if actor == null:
		return _failure(Vector3.ZERO, "no_actor")
	var resolved_options: Dictionary = options.duplicate(true)
	resolved_options["start_position"] = actor.global_position
	resolved_options["search_steps"] = 0
	return find_safe_destination(actor, actor.global_position, resolved_options)


static func _evaluate_candidate(
	actor: CharacterBody3D,
	candidate: Vector3,
	playable_space: Node,
	options: Dictionary
) -> Dictionary:
	if playable_space != null and playable_space.has_method("is_position_allowed"):
		if not bool(playable_space.call("is_position_allowed", candidate)):
			return _failure(candidate, "outside_playable_space")

	var require_ground: bool = bool(options.get("require_ground", true))
	var collision_mask: int = int(options.get("collision_mask", actor.collision_mask))
	var clearance_margin: float = maxf(float(options.get("clearance_margin", 0.06)), 0.01)
	var resolved_position: Vector3 = candidate
	var ground_rid: RID = RID()
	var floor_normal: Vector3 = Vector3.UP

	if require_ground:
		var max_rise: float = maxf(float(options.get("max_rise", 1.75)), 0.1)
		var max_drop: float = maxf(float(options.get("max_drop", 5.0)), 0.1)
		var ray_query := PhysicsRayQueryParameters3D.create(
			candidate + Vector3.UP * max_rise,
			candidate + Vector3.DOWN * max_drop,
			collision_mask
		)
		ray_query.collide_with_bodies = true
		ray_query.collide_with_areas = false
		ray_query.exclude = [actor.get_rid()]
		var ground_hit: Dictionary = actor.get_world_3d().direct_space_state.intersect_ray(ray_query)
		if ground_hit.is_empty():
			return _failure(candidate, "no_supporting_ground")
		floor_normal = ground_hit.get("normal", Vector3.UP)
		var minimum_floor_dot: float = clampf(float(options.get("minimum_floor_dot", 0.62)), -1.0, 1.0)
		if floor_normal.dot(Vector3.UP) < minimum_floor_dot:
			return _failure(candidate, "floor_too_steep")
		ground_rid = ground_hit.get("rid", RID())
		resolved_position = (
			ground_hit.get("position", candidate)
			+ Vector3.UP * (_get_actor_floor_offset(actor) + clearance_margin * 1.5)
		)

	if playable_space != null and playable_space.has_method("is_position_allowed"):
		if not bool(playable_space.call("is_position_allowed", resolved_position)):
			return _failure(resolved_position, "resolved_position_outside_playable_space")
	elif _position_hits_forbidden_volume(actor, resolved_position):
		return _failure(resolved_position, "forbidden_volume")

	var collision_shape: CollisionShape3D = _get_actor_collision_shape(actor)
	if collision_shape != null and collision_shape.shape != null and not collision_shape.disabled:
		var shape_query := PhysicsShapeQueryParameters3D.new()
		shape_query.shape = collision_shape.shape
		var actor_candidate_transform: Transform3D = actor.global_transform
		actor_candidate_transform.origin = resolved_position
		var relative_shape_transform: Transform3D = actor.global_transform.affine_inverse() * collision_shape.global_transform
		shape_query.transform = actor_candidate_transform * relative_shape_transform
		shape_query.margin = clearance_margin
		shape_query.collision_mask = collision_mask
		shape_query.collide_with_bodies = true
		shape_query.collide_with_areas = false
		var excluded: Array[RID] = [actor.get_rid()]
		if ground_rid.is_valid():
			excluded.append(ground_rid)
		shape_query.exclude = excluded
		var overlaps: Array[Dictionary] = actor.get_world_3d().direct_space_state.intersect_shape(shape_query, 16)
		if not overlaps.is_empty():
			return _failure(resolved_position, "insufficient_clearance")

	return {
		"valid": true,
		"position": resolved_position,
		"reason": "safe",
		"floor_normal": floor_normal,
		"snapped": false,
	}


static func _find_playable_space(actor: Node) -> Node:
	if actor == null or actor.get_tree() == null:
		return null
	var current_scene: Node = actor.get_tree().current_scene
	for candidate: Node in actor.get_tree().get_nodes_in_group("playable_space"):
		if current_scene == null or candidate == current_scene or current_scene.is_ancestor_of(candidate):
			return candidate
	return null


static func _position_hits_forbidden_volume(actor: CharacterBody3D, position: Vector3) -> bool:
	if actor == null or actor.get_world_3d() == null:
		return false
	var point_query := PhysicsPointQueryParameters3D.new()
	point_query.position = position
	point_query.collision_mask = ALL_COLLISION_LAYERS
	point_query.collide_with_bodies = false
	point_query.collide_with_areas = true
	point_query.exclude = [actor.get_rid()]
	for hit: Dictionary in actor.get_world_3d().direct_space_state.intersect_point(point_query, 32):
		var collider: Node = hit.get("collider") as Node
		if collider != null and collider.is_in_group("playable_forbidden_volume"):
			return true
	return false


static func _get_actor_collision_shape(actor: CharacterBody3D) -> CollisionShape3D:
	if actor == null:
		return null
	var direct: CollisionShape3D = actor.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if direct != null:
		return direct
	for child: Node in actor.get_children():
		if child is CollisionShape3D:
			return child as CollisionShape3D
	return null


static func _get_actor_floor_offset(actor: CharacterBody3D) -> float:
	var collision_shape: CollisionShape3D = _get_actor_collision_shape(actor)
	if collision_shape == null or collision_shape.shape == null:
		return 1.0
	if collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		return maxf(capsule.height * 0.5, capsule.radius)
	if collision_shape.shape is BoxShape3D:
		return (collision_shape.shape as BoxShape3D).size.y * 0.5
	if collision_shape.shape is SphereShape3D:
		return (collision_shape.shape as SphereShape3D).radius
	if collision_shape.shape is CylinderShape3D:
		return (collision_shape.shape as CylinderShape3D).height * 0.5
	return 1.0


static func _failure(position: Vector3, reason: String) -> Dictionary:
	return {
		"valid": false,
		"position": position,
		"reason": reason,
		"floor_normal": Vector3.UP,
		"snapped": false,
	}
