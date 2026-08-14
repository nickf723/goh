extends RefCounted
class_name BowHeavyAimSolver

const CAMERA_AIM_DISTANCE: float = 250.0


static func get_aim_direction(controller: SafeWeaponController) -> Vector3:
	if controller == null or not controller.is_inside_tree():
		return Vector3.FORWARD
	var actor: Node3D = controller.get_actor()
	var camera: Camera3D = controller.get_viewport().get_camera_3d()
	if actor == null or camera == null:
		return _fallback_direction(controller)
	var aim_point: Vector3 = _get_reticle_world_point(controller, camera, actor)
	var bow_origin: Vector3 = controller._get_ranged_origin(actor)
	var direction: Vector3 = aim_point - bow_origin
	if direction.length_squared() <= 0.0001:
		return _fallback_direction(controller)
	return direction.normalized()


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
		target = controller.find_payload_target(result.get("collider") as Node)
	return {"origin": origin, "end": trace_end, "target": target}


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


static func _get_reticle_world_point(
	controller: SafeWeaponController,
	camera: Camera3D,
	actor: Node3D
) -> Vector3:
	var uv: Vector2 = Vector2(0.5, 0.5)
	if controller.has_method("get_bow_aim_screen_uv"):
		var value: Variant = controller.call("get_bow_aim_screen_uv")
		if value is Vector2:
			uv = value as Vector2
	var viewport_size: Vector2 = controller.get_viewport().get_visible_rect().size
	var screen_point: Vector2 = Vector2(viewport_size.x * uv.x, viewport_size.y * uv.y)
	var camera_origin: Vector3 = camera.project_ray_origin(screen_point)
	var camera_direction: Vector3 = camera.project_ray_normal(screen_point).normalized()
	var endpoint: Vector3 = camera_origin + camera_direction * CAMERA_AIM_DISTANCE
	var query := PhysicsRayQueryParameters3D.new()
	query.from = camera_origin
	query.to = endpoint
	query.collision_mask = controller.hit_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var result: Dictionary = controller.get_world_3d().direct_space_state.intersect_ray(query)
	return result.get("position", endpoint) as Vector3 if not result.is_empty() else endpoint


static func _fallback_direction(controller: SafeWeaponController) -> Vector3:
	var camera: Camera3D = controller.get_viewport().get_camera_3d() if controller != null and controller.is_inside_tree() else null
	if camera != null:
		var camera_forward: Vector3 = -camera.global_transform.basis.z
		if camera_forward.length_squared() > 0.0001:
			return camera_forward.normalized()
	var actor: Node3D = controller.get_actor() if controller != null else null
	if actor != null:
		var actor_forward: Vector3 = -actor.global_transform.basis.z
		if actor_forward.length_squared() > 0.0001:
			return actor_forward.normalized()
	return Vector3.FORWARD
