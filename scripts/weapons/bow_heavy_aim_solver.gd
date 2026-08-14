extends RefCounted
class_name BowHeavyAimSolver


static func get_aim_direction(controller: SafeWeaponController) -> Vector3:
	if controller == null or not controller.is_inside_tree():
		return Vector3.FORWARD
	var camera: Camera3D = controller.get_viewport().get_camera_3d()
	if camera != null:
		var direction: Vector3 = -camera.global_transform.basis.z
		if direction.length_squared() > 0.0001:
			return direction.normalized()
	var actor: Node3D = controller.get_actor()
	if actor != null:
		var fallback: Vector3 = -actor.global_transform.basis.z
		if fallback.length_squared() > 0.0001:
			return fallback.normalized()
	return Vector3.FORWARD


static func sample_aim(
	controller: SafeWeaponController,
	attack: WeaponAttackDefinition,
	direction: Vector3
) -> Dictionary:
	if controller == null or attack == null:
		return {}
	var actor: Node3D = controller.get_actor()
	if actor == null:
		return {}
	var resolved_direction: Vector3 = direction.normalized() if direction.length_squared() > 0.0001 else Vector3.FORWARD
	var origin: Vector3 = controller._get_ranged_origin(actor)
	var endpoint: Vector3 = origin + resolved_direction * controller.get_effective_attack_range(attack)
	var query := PhysicsRayQueryParameters3D.new()
	query.from = origin
	query.to = endpoint
	query.collision_mask = controller.hit_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var result: Dictionary = controller.get_world_3d().direct_space_state.intersect_ray(query)
	var trace_end: Vector3 = endpoint
	var target: Node = null
	if not result.is_empty():
		trace_end = result.get("position", endpoint) as Vector3
		var collider: Node = result.get("collider") as Node
		target = controller.find_payload_target(collider)
	return {
		"origin": origin,
		"end": trace_end,
		"target": target,
	}


static func find_targets(
	controller: SafeWeaponController,
	attack: WeaponAttackDefinition,
	direction: Vector3
) -> Array[Node]:
	var targets: Array[Node] = []
	var sample: Dictionary = sample_aim(controller, attack, direction)
	if sample.is_empty():
		return targets
	controller._spawn_ranged_trace(
		sample.get("origin", Vector3.ZERO) as Vector3,
		sample.get("end", Vector3.ZERO) as Vector3,
		attack
	)
	var target: Node = sample.get("target") as Node
	if target != null:
		targets.append(target)
	return targets
