extends RefCounted
class_name BoomerangPathSolver


static func find_targets(
	controller: WeaponController,
	attack: WeaponAttackDefinition
) -> Array[Node]:
	if controller == null or attack == null:
		return []
	if attack.extra_tags.has("boomerang_hook_throw"):
		return _curve_targets(controller, attack, false)
	if attack.extra_tags.has("boomerang_s_curve_throw"):
		return _curve_targets(controller, attack, true)
	if attack.extra_tags.has("boomerang_orbit_throw"):
		return _orbit_targets(controller, attack)
	return []


static func _curve_targets(
	controller: WeaponController,
	attack: WeaponAttackDefinition,
	s_curve: bool
) -> Array[Node]:
	var actor: Node3D = controller.get_actor()
	if actor == null:
		return []
	var origin: Vector3 = controller._get_ranged_origin(actor)
	var forward: Vector3 = controller.get_attack_forward()
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var maximum_range: float = controller.get_effective_attack_range(attack)
	var targets: Array[Node] = []
	var previous: Vector3 = origin
	var segments: int = 12
	for step: int in range(1, segments + 1):
		var t: float = float(step) / float(segments)
		var lateral: float = (
			sin(t * TAU) * maximum_range * 0.19
			if s_curve
			else sin(t * PI) * maximum_range * 0.29
		)
		var point: Vector3 = origin + forward * maximum_range * t + right * lateral
		_trace_segment(controller, attack, actor, previous, point, targets)
		previous = point
		if targets.size() >= controller.get_effective_max_targets(attack):
			break
	return targets


static func _orbit_targets(
	controller: WeaponController,
	attack: WeaponAttackDefinition
) -> Array[Node]:
	var actor: Node3D = controller.get_actor()
	if actor == null:
		return []
	var center: Vector3 = controller._get_ranged_origin(actor)
	var forward: Vector3 = controller.get_attack_forward()
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var radius: float = minf(controller.get_effective_attack_range(attack) * 0.78, 3.8)
	var targets: Array[Node] = []
	var segments: int = 18
	var previous: Vector3 = center + forward * radius
	_trace_segment(controller, attack, actor, center, previous, targets)
	for step: int in range(1, segments + 1):
		var angle: float = TAU * float(step) / float(segments)
		var point: Vector3 = center + forward * cos(angle) * radius + right * sin(angle) * radius
		_trace_segment(controller, attack, actor, previous, point, targets)
		previous = point
		if targets.size() >= controller.get_effective_max_targets(attack):
			break
	return targets


static func _trace_segment(
	controller: WeaponController,
	attack: WeaponAttackDefinition,
	actor: Node3D,
	from: Vector3,
	to: Vector3,
	targets: Array[Node]
) -> void:
	var query := PhysicsRayQueryParameters3D.new()
	query.from = from
	query.to = to
	query.collision_mask = controller.hit_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var result: Dictionary = controller.get_world_3d().direct_space_state.intersect_ray(query)
	var trace_end: Vector3 = to
	if not result.is_empty():
		trace_end = result.get("position", to) as Vector3
		var collider: Node = result.get("collider") as Node
		var target: Node = controller.find_payload_target(collider)
		if target != null and target != actor and not targets.has(target):
			targets.append(target)
	controller._spawn_ranged_trace(from, trace_end, attack)
