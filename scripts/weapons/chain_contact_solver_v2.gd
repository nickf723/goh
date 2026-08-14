extends RefCounted
class_name ChainContactSolverV2


static func find_targets(
	rig: Node3D,
	weapon_controller: WeaponController,
	attack: WeaponAttackDefinition,
	collision_mask: int,
	tip_history: Array[Vector3],
	head_position: Vector3,
	head_radius: float,
	handle_position: Vector3,
	line_samples: Array[Dictionary]
) -> Dictionary:
	var output: Dictionary = {"targets": [], "strengths": {}}
	if rig == null or weapon_controller == null or attack == null:
		return output
	var actor: Node3D = weapon_controller.get_actor()
	if actor == null:
		return output
	var targets: Array[Node] = []
	var strengths: Dictionary = {}
	var seen: Dictionary = {}
	if attack.extra_tags.has("ground_slam"):
		_query_sphere(
			rig,
			weapon_controller,
			actor,
			head_position + Vector3.UP * 0.2,
			minf(maxf(attack.attack_range * 0.62, 1.5), 2.75),
			collision_mask,
			1.0,
			attack.max_targets,
			targets,
			strengths,
			seen
		)
	else:
		var head_samples: Array[Vector3] = tip_history.duplicate()
		if head_samples.is_empty():
			head_samples.append(head_position)
		for point: Vector3 in head_samples:
			_query_sphere(
				rig,
				weapon_controller,
				actor,
				point,
				maxf(head_radius, 0.1),
				collision_mask,
				1.0,
				attack.max_targets,
				targets,
				strengths,
				seen
			)

	# The chain is not a cosmetic line. Every link follows the weighted head and
	# can make contact. Outer links transfer more of the head's momentum; the
	# weighted tip remains the full-strength sweet spot.
	var link_radius: float = maxf(head_radius * 0.46, 0.2)
	for sample: Dictionary in line_samples:
		var fraction: float = clampf(float(sample.get("fraction", 0.0)), 0.0, 1.0)
		if fraction < 0.14 or fraction > 0.965:
			continue
		var strength: float = lerpf(0.58, 0.91, pow(fraction, 0.82))
		_query_sphere(
			rig,
			weapon_controller,
			actor,
			sample.get("position", Vector3.ZERO) as Vector3,
			link_radius,
			collision_mask,
			strength,
			attack.max_targets,
			targets,
			strengths,
			seen
		)

	# During a sweep, the links swept through all of the spokes between the hand
	# and the recent head trail. Sampling those spokes makes the hitbox agree with
	# the visible tether instead of only checking its final frame.
	for historical_tip: Vector3 in tip_history:
		for step: int in range(2, 7):
			var fraction: float = float(step) / 7.0
			var point: Vector3 = handle_position.lerp(historical_tip, fraction)
			point += Vector3.DOWN * sin(fraction * PI) * 0.18
			var strength: float = lerpf(0.58, 0.91, pow(fraction, 0.82))
			_query_sphere(
				rig,
				weapon_controller,
				actor,
				point,
				link_radius,
				collision_mask,
				strength,
				attack.max_targets,
				targets,
				strengths,
				seen
			)
	return {"targets": targets, "strengths": strengths}


static func _query_sphere(
	rig: Node3D,
	weapon_controller: WeaponController,
	actor: Node3D,
	position: Vector3,
	radius: float,
	collision_mask: int,
	strength: float,
	max_targets: int,
	targets: Array[Node],
	strengths: Dictionary,
	seen: Dictionary
) -> void:
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(radius, 0.08)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), position)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	for result: Dictionary in rig.get_world_3d().direct_space_state.intersect_shape(query, 20):
		var collider: Node = result.get("collider") as Node
		if collider == null:
			continue
		var target: Node = weapon_controller.find_payload_target(collider)
		if target == null or target == actor:
			continue
		var id: int = target.get_instance_id()
		strengths[id] = maxf(float(strengths.get(id, 0.0)), clampf(strength, 0.0, 1.0))
		if seen.has(id):
			continue
		if targets.size() >= maxi(max_targets, 1):
			continue
		seen[id] = true
		targets.append(target)
