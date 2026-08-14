extends RefCounted
class_name ChainHeadContactSolver


static func find_targets(
	rig: Node3D,
	weapon_controller: WeaponController,
	attack: WeaponAttackDefinition,
	collision_mask: int,
	tip_history: Array[Vector3],
	head_position: Vector3,
	head_radius: float
) -> Dictionary:
	var output: Dictionary = {"targets": [], "strengths": {}}
	if rig == null or weapon_controller == null or attack == null:
		return output
	var actor: Node3D = weapon_controller.get_actor()
	if actor == null:
		return output
	if attack.extra_tags.has("ground_slam"):
		return _find_slam(rig, weapon_controller, actor, attack, collision_mask, head_position)
	return _find_trail(rig, weapon_controller, actor, attack, collision_mask, tip_history, head_position, head_radius)


static func _find_trail(
	rig: Node3D,
	weapon_controller: WeaponController,
	actor: Node3D,
	attack: WeaponAttackDefinition,
	collision_mask: int,
	tip_history: Array[Vector3],
	head_position: Vector3,
	head_radius: float
) -> Dictionary:
	var targets: Array[Node] = []
	var strengths: Dictionary = {}
	var seen: Dictionary = {}
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(head_radius, 0.1)
	var samples: Array[Vector3] = tip_history.duplicate()
	if samples.is_empty():
		samples.append(head_position)
	for point: Vector3 in samples:
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis(), point)
		query.collision_mask = collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = true
		if actor is CollisionObject3D:
			query.exclude = [(actor as CollisionObject3D).get_rid()]
		for result: Dictionary in rig.get_world_3d().direct_space_state.intersect_shape(query, 20):
			var target: Node = weapon_controller.find_payload_target(result.get("collider") as Node)
			if target == null or target == actor:
				continue
			var id: int = target.get_instance_id()
			strengths[id] = 1.0
			if seen.has(id):
				continue
			seen[id] = true
			targets.append(target)
			if targets.size() >= maxi(attack.max_targets, 1):
				return {"targets": targets, "strengths": strengths}
	return {"targets": targets, "strengths": strengths}


static func _find_slam(
	rig: Node3D,
	weapon_controller: WeaponController,
	actor: Node3D,
	attack: WeaponAttackDefinition,
	collision_mask: int,
	head_position: Vector3
) -> Dictionary:
	var targets: Array[Node] = []
	var strengths: Dictionary = {}
	var seen: Dictionary = {}
	var sphere := SphereShape3D.new()
	sphere.radius = minf(maxf(attack.attack_range * 0.62, 1.5), 2.75)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), head_position + Vector3.UP * 0.2)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	for result: Dictionary in rig.get_world_3d().direct_space_state.intersect_shape(query, 48):
		var target: Node = weapon_controller.find_payload_target(result.get("collider") as Node)
		if target == null or target == actor:
			continue
		var id: int = target.get_instance_id()
		strengths[id] = 1.0
		if seen.has(id):
			continue
		seen[id] = true
		targets.append(target)
		if targets.size() >= maxi(attack.max_targets, 1):
			break
	return {"targets": targets, "strengths": strengths}
