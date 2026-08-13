extends "res://scripts/weapons/chain_weapon_rig_v3.gd"
class_name ChainWeaponRigV4

var ground_drag_active: bool = false


func _ready() -> void:
	chain_length = 4.15
	tip_mass = 3.6
	contact_radius = 0.5
	head_max_speed = 16.0
	head_response = 6.4
	line_sag = 0.72
	super._ready()


func update_attack_pose(
	attack: WeaponAttackDefinition,
	elapsed: float,
	attack_speed: float
) -> void:
	if attack == null or controller == null or not attack.extra_tags.has("chain_ground_drag"):
		ground_drag_active = false
		super.update_attack_pose(attack, elapsed, attack_speed)
		return
	ground_drag_active = true
	_update_handle()
	var startup: float = attack.get_startup_duration(attack_speed)
	var active: float = attack.get_active_duration(attack_speed)
	var active_end: float = startup + active
	var total: float = attack.get_total_duration(attack_speed)
	var handle: Vector3 = handle_anchor.global_position
	var forward: Vector3 = _forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var side_sign: float = -1.0 if attack.extra_tags.has("reverse") else 1.0
	var reach: float = minf(chain_length, attack.attack_range)

	if elapsed < startup:
		var p: float = smoothstep(0.0, 1.0, clampf(elapsed / maxf(startup, 0.01), 0.0, 1.0))
		var drag_angle: float = lerpf(-112.0 * side_sign, -28.0 * side_sign, p)
		var radians: float = deg_to_rad(drag_angle)
		var planar: Vector3 = handle + forward * cos(radians) * reach * 0.78 + right * sin(radians) * reach * 0.78
		_desired_tip = _ground_project(planar)
		_side_bend = side_sign * (0.18 + sin(p * PI) * 0.26)
		_lift_bend = -0.22
		return

	if elapsed <= active_end:
		var p: float = clampf((elapsed - startup) / maxf(active, 0.01), 0.0, 1.0)
		if attack.extra_tags.has("ground_slam"):
			var landing: Vector3 = handle + forward * reach * 0.7
			_desired_tip = _ground_project(landing)
			_side_bend = 0.0
			_lift_bend = -0.28
		else:
			var sweep_angle: float = lerpf(-24.0 * side_sign, 132.0 * side_sign, p)
			var radians: float = deg_to_rad(sweep_angle)
			var arc_point: Vector3 = handle + forward * cos(radians) * reach + right * sin(radians) * reach
			_desired_tip = _ground_project(arc_point) + Vector3.UP * (0.12 + sin(p * PI) * 0.34)
			_side_bend = side_sign * lerpf(0.12, -0.18, p)
			_lift_bend = 0.08 + sin(p * PI) * 0.12
		return

	var recovery: float = smoothstep(0.0, 1.0, clampf((elapsed - active_end) / maxf(total - active_end, 0.01), 0.0, 1.0))
	_desired_tip = _desired_tip.lerp(_idle_tip(), recovery)
	_side_bend = lerpf(_side_bend, 0.0, recovery)
	_lift_bend = lerpf(_lift_bend, 0.0, recovery)


func end_attack() -> void:
	ground_drag_active = false
	super.end_attack()


func _idle_tip() -> Vector3:
	if handle_anchor == null:
		return global_position
	var candidate: Vector3 = handle_anchor.global_position + _forward() * 0.72 + Vector3.DOWN * 0.75
	return _ground_project(candidate)


func _update_line_points() -> void:
	if line == null or handle_anchor == null:
		return
	var handle: Vector3 = handle_anchor.global_position
	var forward: Vector3 = _forward()
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var sag_scale: float = 0.82 if ground_drag_active else (0.2 if is_attacking else 1.0)
	var points: Array[Vector3] = []
	for index: int in range(segment_count + 1):
		var t: float = float(index) / float(segment_count)
		var point: Vector3 = handle.lerp(_visual_tip, t)
		var envelope: float = sin(t * PI)
		point += right * _side_bend * envelope
		point += Vector3.UP * (_lift_bend - line_sag * sag_scale) * envelope
		points.append(point)
	line.set_points(points)


func find_weapon_targets(
	weapon_controller: WeaponController,
	attack: WeaponAttackDefinition,
	collision_mask: int
) -> Array[Node]:
	if attack == null:
		return []
	if attack.extra_tags.has("chain_ground_blast"):
		return _find_ground_blast_targets(weapon_controller, attack, collision_mask)
	if attack.extra_tags.has("chain_area_sweep"):
		return _find_wide_sweep_targets(weapon_controller, attack, collision_mask)
	return super.find_weapon_targets(weapon_controller, attack, collision_mask)


func _find_ground_blast_targets(
	weapon_controller: WeaponController,
	attack: WeaponAttackDefinition,
	collision_mask: int
) -> Array[Node]:
	var actor: Node3D = weapon_controller.get_actor()
	if actor == null:
		return []
	_contact_strengths.clear()
	var sphere := SphereShape3D.new()
	sphere.radius = minf(attack.attack_range, chain_length) + 0.45
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), actor.global_position + Vector3.UP * 0.35)
	query.collision_mask = collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = true
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	return _collect_query_targets(weapon_controller, actor, query, attack.max_targets, 1.0)


func _find_wide_sweep_targets(
	weapon_controller: WeaponController,
	attack: WeaponAttackDefinition,
	collision_mask: int
) -> Array[Node]:
	var actor: Node3D = weapon_controller.get_actor()
	if actor == null:
		return []
	_contact_strengths.clear()
	var forward: Vector3 = weapon_controller.get_attack_forward()
	forward.y = 0.0
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var right: Vector3 = Vector3.UP.cross(forward).normalized()
	var reach: float = minf(attack.attack_range, chain_length)
	var half_arc: float = deg_to_rad(minf(attack.cone_angle_degrees, 360.0) * 0.5)
	var sphere := SphereShape3D.new()
	sphere.radius = contact_radius * 1.45
	var targets: Array[Node] = []
	var seen: Dictionary = {}
	var rings: Array[float] = [0.46, 0.72, 1.0]
	for ring_scale: float in rings:
		for sample_index: int in range(13):
			var t: float = float(sample_index) / 12.0
			var angle: float = lerpf(-half_arc, half_arc, t)
			var position: Vector3 = actor.global_position + Vector3.UP * 0.42
			position += forward * cos(angle) * reach * ring_scale
			position += right * sin(angle) * reach * ring_scale
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = sphere
			query.transform = Transform3D(Basis(), position)
			query.collision_mask = collision_mask
			query.collide_with_bodies = true
			query.collide_with_areas = true
			if actor is CollisionObject3D:
				query.exclude = [(actor as CollisionObject3D).get_rid()]
			for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 20):
				var target: Node = weapon_controller.find_payload_target(result.get("collider") as Node)
				if target == null or target == actor:
					continue
				var id: int = target.get_instance_id()
				_contact_strengths[id] = maxf(float(_contact_strengths.get(id, 0.0)), 0.72 + ring_scale * 0.28)
				if not seen.has(id):
					seen[id] = true
					targets.append(target)
					if targets.size() >= maxi(attack.max_targets, 1):
						return targets
	return targets


func _collect_query_targets(
	weapon_controller: WeaponController,
	actor: Node3D,
	query: PhysicsShapeQueryParameters3D,
	maximum_targets: int,
	strength: float
) -> Array[Node]:
	var targets: Array[Node] = []
	var seen: Dictionary = {}
	for result: Dictionary in get_world_3d().direct_space_state.intersect_shape(query, 48):
		var target: Node = weapon_controller.find_payload_target(result.get("collider") as Node)
		if target == null or target == actor:
			continue
		var id: int = target.get_instance_id()
		_contact_strengths[id] = strength
		if seen.has(id):
			continue
		seen[id] = true
		targets.append(target)
		if targets.size() >= maxi(maximum_targets, 1):
			break
	return targets


func _ground_project(candidate: Vector3) -> Vector3:
	if not is_inside_tree():
		return candidate
	var query := PhysicsRayQueryParameters3D.new()
	query.from = candidate + Vector3.UP * 1.8
	query.to = candidate + Vector3.DOWN * 3.8
	query.collision_mask = 0x7fffffff
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var actor: Node3D = controller.get_actor() if controller != null else null
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return candidate
	return (result.get("position", candidate) as Vector3) + Vector3.UP * 0.16


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["type"] = "colossal_chain_v4"
	data["ground_drag"] = ground_drag_active
	data["wide_sweep_queries"] = true
	data["ground_blast_queries"] = true
	data["tip_mass"] = tip_mass
	data["chain_length"] = chain_length
	return data
