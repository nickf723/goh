extends RefCounted
class_name PerceptionTargetResolver

const PERCEPTION_TARGET_GROUP: StringName = &"perception_targets"


static func resolve_target(
	tree: SceneTree,
	observer: Node3D,
	canonical_target: Node3D,
	maximum_range: float = 24.0
) -> Node3D:
	if observer == null or tree == null:
		return canonical_target
	var candidates: Array[Node3D] = []
	if canonical_target != null and is_instance_valid(canonical_target):
		candidates.append(canonical_target)
	for node: Node in tree.get_nodes_in_group(PERCEPTION_TARGET_GROUP):
		if not node is Node3D:
			continue
		var candidate := node as Node3D
		if candidate == observer or not is_instance_valid(candidate) or candidate.is_queued_for_deletion():
			continue
		if not candidates.has(candidate):
			candidates.append(candidate)

	var best: Node3D = canonical_target
	var best_score: float = -INF
	for candidate: Node3D in candidates:
		var distance: float = observer.global_position.distance_to(
			get_perceived_position(candidate, observer)
		)
		if maximum_range > 0.0 and distance > maximum_range:
			continue
		if not _has_line_of_sight(observer, candidate):
			continue
		var score: float = get_salience(candidate, observer, maximum_range, distance)
		if score > best_score:
			best_score = score
			best = candidate
	return best


static func get_perceived_position(
	target: Node3D,
	observer: Node3D = null
) -> Vector3:
	if target == null:
		return Vector3.ZERO
	if target.has_method("get_perceived_target_position"):
		var value: Variant = target.call("get_perceived_target_position", observer)
		if value is Vector3:
			return value as Vector3
	return target.global_position


static func get_salience(
	target: Node3D,
	observer: Node3D,
	maximum_range: float,
	distance_override: float = -1.0
) -> float:
	if target == null:
		return -INF
	var distance: float = distance_override
	if distance < 0.0 and observer != null:
		distance = observer.global_position.distance_to(
			get_perceived_position(target, observer)
		)
	var threat: float = 1.0
	if target.has_method("get_perceived_threat_score"):
		threat = maxf(float(target.call("get_perceived_threat_score", observer)), 0.0)
	else:
		threat = maxf(float(target.get_meta("perceived_threat_score", 1.0)), 0.0)
	var priority: float = maxf(float(target.get_meta("perception_priority", 1.0)), 0.0)
	var proximity: float = 0.0
	if maximum_range > 0.0:
		proximity = clampf(1.0 - distance / maximum_range, 0.0, 1.0)
	return threat * 2.0 + priority + proximity


static func is_authentic(target: Node3D) -> bool:
	if target == null:
		return false
	if target.has_method("get_perception_authenticity"):
		return float(target.call("get_perception_authenticity")) >= 0.5
	return float(target.get_meta("perception_authenticity", 1.0)) >= 0.5


static func is_perceived_threatening(target: Node3D) -> bool:
	if target == null:
		return false
	if target.has_method("is_perceived_threatening"):
		return bool(target.call("is_perceived_threatening"))
	return bool(target.get_meta("perceived_threatening", false))


static func _has_line_of_sight(observer: Node3D, target: Node3D) -> bool:
	if observer == null or target == null:
		return false
	var world: World3D = observer.get_world_3d()
	if world == null:
		return true
	var start: Vector3 = observer.global_position + Vector3.UP * 0.9
	var finish: Vector3 = get_perceived_position(target, observer) + Vector3.UP * 0.85
	var query := PhysicsRayQueryParameters3D.create(start, finish)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	if observer is CollisionObject3D:
		query.exclude = [(observer as CollisionObject3D).get_rid()]
	var result: Dictionary = world.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return true
	var collider_value: Variant = result.get("collider")
	if collider_value == target:
		return true
	if collider_value is Node:
		var collider := collider_value as Node
		if target.is_ancestor_of(collider):
			return true
	return false
