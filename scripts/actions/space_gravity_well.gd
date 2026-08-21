extends Node3D
class_name SpaceGravityWell

signal target_pulled(target: Node, pull_force: Vector3)
signal well_finished(target_count: int)

@export_group("Placement")
@export_range(1.0, 16.0, 0.25) var placement_distance: float = 6.0
@export_range(0.0, 3.0, 0.05) var center_height: float = 0.75
@export_range(1.0, 12.0, 0.25) var ground_probe_height: float = 4.0
@export_range(1.0, 20.0, 0.25) var ground_probe_depth: float = 8.0
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Gravity Field")
@export_range(0.25, 30.0, 0.05) var duration_seconds: float = 6.0
@export_range(1.0, 12.0, 0.1) var radius: float = 5.2
@export_range(0.1, 3.0, 0.05) var core_radius: float = 0.75
@export_range(0.0, 160.0, 0.5) var pull_force_strength: float = 46.0
@export_range(0.0, 60.0, 0.25) var character_pull_acceleration: float = 13.0
@export_range(0.0, 160.0, 0.5) var rigid_body_force: float = 34.0
@export_range(0.0, 0.7, 0.01) var orbit_fraction: float = 0.16
@export_range(0.1, 6.0, 0.05) var falloff_exponent: float = 1.35
@export_range(0.0, 1.0, 0.05) var boss_pull_multiplier: float = 0.28
@export var affect_source_actor: bool = false

@export_group("Presentation")
@export_range(2, 7, 1) var ring_count: int = 4
@export_range(4, 18, 1) var mote_count: int = 10
@export_range(0.0, 8.0, 0.1) var visual_rotation_speed: float = 1.7

var source_actor: Node3D
var active: bool = false
var duration_remaining: float = 0.0
var source_id: String = ""
var affected_force_receivers: Dictionary = {}
var affected_target_ids: Dictionary = {}
var last_target_names: Array[String] = []
var pull_steps: int = 0
var elapsed: float = 0.0

var visual_root: Node3D
var core_mesh: MeshInstance3D
var gravity_rings: Array[MeshInstance3D] = []
var orbit_motes: Array[MeshInstance3D] = []


func _ready() -> void:
	source_id = "gravity_well:" + str(get_instance_id())
	add_to_group("space_gravity_wells")
	add_to_group("spell_fields")
	add_to_group("debuggable")
	_build_visuals()
	set_physics_process(false)
	set_process(false)


func _exit_tree() -> void:
	_clear_all_force_receivers()


func _process(delta: float) -> void:
	if not active:
		return
	var safe_delta: float = maxf(delta, 0.0)
	elapsed += safe_delta
	_update_visuals(safe_delta)


func _physics_process(delta: float) -> void:
	if not active:
		return
	var safe_delta: float = maxf(delta, 0.0)
	duration_remaining = maxf(duration_remaining - safe_delta, 0.0)
	_apply_gravity_step(safe_delta)
	if duration_remaining <= 0.0:
		_finish_well()


func set_payload(_new_payload: Resource) -> void:
	# Gravity Well is a force field rather than a damage-payload spell.
	pass


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func execute(player: Node3D, requested_direction: Vector3) -> void:
	if player != null:
		source_actor = player
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	var direction: Vector3 = requested_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = -source_actor.global_transform.basis.z
		direction.y = 0.0
	if direction.length_squared() <= 0.0001:
		direction = Vector3.FORWARD
	direction = direction.normalized()

	var proposed_position: Vector3 = (
		source_actor.global_position
		+ direction * placement_distance
	)
	global_position = _resolve_ground_position(proposed_position)
	duration_remaining = maxf(duration_seconds, 0.25)
	elapsed = 0.0
	pull_steps = 0
	affected_target_ids.clear()
	last_target_names.clear()
	_clear_all_force_receivers()
	active = true
	if visual_root != null:
		visual_root.visible = true
	_update_visuals(0.0)
	set_process(true)
	set_physics_process(true)


func _resolve_ground_position(proposed_position: Vector3) -> Vector3:
	var world: World3D = get_world_3d()
	if world == null:
		return proposed_position + Vector3.UP * center_height
	var ray_start: Vector3 = proposed_position + Vector3.UP * ground_probe_height
	var ray_end: Vector3 = proposed_position - Vector3.UP * ground_probe_depth
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = collision_mask
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var exclusions: Array[RID] = []
	if source_actor != null:
		_collect_collision_rids(source_actor, exclusions)
	query.exclude = exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	var position_value: Variant = hit.get("position")
	if position_value is Vector3:
		return (position_value as Vector3) + Vector3.UP * center_height
	return proposed_position + Vector3.UP * center_height


func _apply_gravity_step(delta: float) -> void:
	var world: World3D = get_world_3d()
	if world == null or delta <= 0.0:
		return
	var shape := SphereShape3D.new()
	shape.radius = maxf(radius, 0.1)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var current_receiver_ids: Dictionary = {}
	var seen_target_ids: Dictionary = {}
	for result: Dictionary in world.direct_space_state.intersect_shape(query, 128):
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_force_target(collider_value as Node)
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		if seen_target_ids.has(target_id):
			continue
		seen_target_ids[target_id] = true
		_apply_pull_to_target(target, delta, current_receiver_ids)

	_clear_stale_force_receivers(current_receiver_ids)
	pull_steps += 1


func _resolve_force_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if not affect_source_actor and source_actor != null:
			if current == source_actor or source_actor.is_ancestor_of(current):
				return null
		if _is_force_target(current):
			return current
		if get_tree() != null and current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _is_force_target(node: Node) -> bool:
	if node == null or node is StaticBody3D or node is AnimatableBody3D:
		return false
	return (
		node is CharacterBody3D
		or node is RigidBody3D
		or node.get_node_or_null("ForceReceiver") != null
		or node.has_method("receive_gravity_pull")
	)


func _apply_pull_to_target(
	target: Node,
	delta: float,
	current_receiver_ids: Dictionary
) -> void:
	var target_position: Vector3 = _get_target_position(target)
	var offset: Vector3 = global_position - target_position
	var distance: float = offset.length()
	if distance <= 0.001 or distance > radius:
		return

	var toward_center: Vector3 = offset / distance
	var normalized_distance: float = clampf(distance / maxf(radius, 0.01), 0.0, 1.0)
	var outer_weight: float = pow(
		1.0 - normalized_distance,
		maxf(falloff_exponent, 0.1)
	)
	var core_weight: float = clampf(
		distance / maxf(core_radius, 0.05),
		0.12,
		1.0
	)
	var weight: float = outer_weight * core_weight
	if target.is_in_group("boss"):
		weight *= boss_pull_multiplier
	if target.has_meta("gravity_pull_multiplier"):
		weight *= maxf(float(target.get_meta("gravity_pull_multiplier")), 0.0)
	if weight <= 0.0001:
		return

	var tangent: Vector3 = Vector3.UP.cross(toward_center)
	if tangent.length_squared() > 0.0001:
		tangent = tangent.normalized()
	var orbit_mix: float = clampf(orbit_fraction, 0.0, 0.7)
	var pull_direction: Vector3 = (
		toward_center * (1.0 - orbit_mix)
		+ tangent * orbit_mix
	)
	if pull_direction.length_squared() <= 0.0001:
		pull_direction = toward_center
	else:
		pull_direction = pull_direction.normalized()

	var force_receiver: ForceReceiver = target.get_node_or_null(
		"ForceReceiver"
	) as ForceReceiver
	var applied_force: Vector3 = Vector3.ZERO
	if force_receiver != null:
		applied_force = pull_direction * pull_force_strength * weight
		force_receiver.set_continuous_force(source_id, applied_force)
		var receiver_id: int = force_receiver.get_instance_id()
		current_receiver_ids[receiver_id] = true
		affected_force_receivers[receiver_id] = force_receiver
	elif target is RigidBody3D:
		applied_force = pull_direction * rigid_body_force * weight
		(target as RigidBody3D).apply_central_force(applied_force)
	elif target.has_method("receive_gravity_pull"):
		applied_force = pull_direction * character_pull_acceleration * weight
		target.call(
			"receive_gravity_pull",
			global_position,
			applied_force,
			delta,
			self
		)
	elif target is CharacterBody3D:
		applied_force = pull_direction * character_pull_acceleration * weight
		var character := target as CharacterBody3D
		character.velocity += applied_force * delta

	if applied_force.length_squared() <= 0.0001:
		return
	var target_id: int = target.get_instance_id()
	if not affected_target_ids.has(target_id):
		affected_target_ids[target_id] = true
		last_target_names.append(str(target.name))
	target_pulled.emit(target, applied_force)


func _clear_stale_force_receivers(current_receiver_ids: Dictionary) -> void:
	var stale_ids: Array[int] = []
	for raw_id: Variant in affected_force_receivers.keys():
		var receiver_id: int = int(raw_id)
		if current_receiver_ids.has(receiver_id):
			continue
		var receiver_value: Variant = affected_force_receivers[raw_id]
		if receiver_value is ForceReceiver:
			var receiver := receiver_value as ForceReceiver
			if is_instance_valid(receiver):
				receiver.clear_continuous_force(source_id)
		stale_ids.append(receiver_id)
	for receiver_id: int in stale_ids:
		affected_force_receivers.erase(receiver_id)


func _clear_all_force_receivers() -> void:
	for receiver_value: Variant in affected_force_receivers.values():
		if receiver_value is ForceReceiver:
			var receiver := receiver_value as ForceReceiver
			if is_instance_valid(receiver):
				receiver.clear_continuous_force(source_id)
	affected_force_receivers.clear()


func _finish_well() -> void:
	if not active:
		return
	active = false
	set_process(false)
	set_physics_process(false)
	_clear_all_force_receivers()
	if visual_root != null:
		visual_root.visible = false
	well_finished.emit(affected_target_ids.size())
	queue_free()


func _get_target_position(target: Node) -> Vector3:
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	if parent is Node3D:
		return (parent as Node3D).global_position
	return global_position


func _collect_collision_rids(node: Node, target: Array[RID]) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "GravityWellVisuals"
	add_child(visual_root)

	core_mesh = MeshInstance3D.new()
	core_mesh.name = "GravityCore"
	var sphere := SphereMesh.new()
	sphere.radius = 0.34
	sphere.height = 0.68
	sphere.radial_segments = 16
	sphere.rings = 8
	core_mesh.mesh = sphere
	core_mesh.material_override = _make_space_material(
		Color(0.035, 0.02, 0.08, 0.98),
		Color(0.42, 0.16, 0.9, 1.0),
		2.8
	)
	visual_root.add_child(core_mesh)

	gravity_rings.clear()
	for index: int in range(ring_count):
		var ring := MeshInstance3D.new()
		ring.name = "GravityRing" + str(index + 1)
		var torus := TorusMesh.new()
		var ring_radius: float = 0.7 + float(index) * 0.52
		torus.inner_radius = ring_radius - 0.035
		torus.outer_radius = ring_radius + 0.035
		torus.rings = 28
		torus.ring_segments = 7
		ring.mesh = torus
		ring.rotation_degrees = Vector3(
			18.0 + float(index) * 17.0,
			float(index) * 29.0,
			8.0 + float(index) * 21.0
		)
		ring.material_override = _make_space_material(
			Color(0.24, 0.08, 0.54, 0.58),
			Color(0.58, 0.23, 1.0, 1.0),
			2.2
		)
		visual_root.add_child(ring)
		gravity_rings.append(ring)

	orbit_motes.clear()
	for index: int in range(mote_count):
		var mote := MeshInstance3D.new()
		mote.name = "GravityMote" + str(index + 1)
		var mote_mesh := SphereMesh.new()
		mote_mesh.radius = 0.045
		mote_mesh.height = 0.09
		mote_mesh.radial_segments = 6
		mote_mesh.rings = 3
		mote.mesh = mote_mesh
		mote.material_override = _make_space_material(
			Color(0.58, 0.28, 1.0, 0.85),
			Color(0.72, 0.42, 1.0, 1.0),
			3.0
		)
		visual_root.add_child(mote)
		orbit_motes.append(mote)

	visual_root.visible = false


func _update_visuals(delta: float) -> void:
	if visual_root == null:
		return
	if core_mesh != null:
		var pulse: float = 1.0 + sin(elapsed * 4.6) * 0.08
		core_mesh.scale = Vector3.ONE * pulse
	for index: int in range(gravity_rings.size()):
		var ring: MeshInstance3D = gravity_rings[index]
		var direction_sign: float = 1.0 if index % 2 == 0 else -1.0
		ring.rotation.y += visual_rotation_speed * direction_sign * delta
		ring.rotation.z += visual_rotation_speed * 0.5 * delta
	for index: int in range(orbit_motes.size()):
		var mote: MeshInstance3D = orbit_motes[index]
		var phase: float = TAU * float(index) / maxf(float(orbit_motes.size()), 1.0)
		var orbit_radius: float = 1.0 + 0.42 * float(index % 4)
		var angle: float = phase + elapsed * (1.2 + float(index % 3) * 0.13)
		mote.position = Vector3(
			cos(angle) * orbit_radius,
			sin(angle * 1.7 + phase) * 0.42,
			sin(angle) * orbit_radius
		)


func _make_space_material(
	albedo: Color,
	emission: Color,
	emission_energy: float
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = emission_energy
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 0.28
	return material


func get_debug_data() -> Dictionary:
	return {
		"spell": "gravity_well",
		"gravity_field_contract": true,
		"direct_damage": false,
		"active": active,
		"duration_remaining": snappedf(duration_remaining, 0.01),
		"radius": radius,
		"pull_force": pull_force_strength,
		"orbit_fraction": orbit_fraction,
		"affected_targets": affected_target_ids.size(),
		"target_names": last_target_names.duplicate(),
		"active_force_receivers": affected_force_receivers.size(),
		"pull_steps": pull_steps,
	}
