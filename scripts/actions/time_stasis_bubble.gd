extends Node3D
class_name TimeStasisBubble

signal target_suspended(target: Node)
signal target_released(target: Node)
signal bubble_finished(target_count: int)

@export_group("Placement")
@export_range(1.0, 16.0, 0.25) var placement_distance: float = 5.5
@export_range(0.0, 4.0, 0.05) var center_height: float = 1.45
@export_range(1.0, 12.0, 0.25) var ground_probe_height: float = 4.0
@export_range(1.0, 20.0, 0.25) var ground_probe_depth: float = 8.0
@export_flags_3d_physics var collision_mask: int = 1

@export_group("Stasis")
@export_range(0.25, 20.0, 0.05) var duration_seconds: float = 4.6
@export_range(1.0, 10.0, 0.1) var radius: float = 3.8
@export_range(0.05, 1.0, 0.05) var refresh_interval: float = 0.15
@export_range(0.1, 2.0, 0.05) var stasis_refresh_duration: float = 0.35
@export var affect_source_actor: bool = false
@export var affects_bosses: bool = false
@export var freeze_rigid_bodies: bool = true

@export_group("Presentation")
@export_range(2, 8, 1) var ring_count: int = 5
@export_range(4, 18, 1) var mote_count: int = 9
@export_range(0.0, 6.0, 0.1) var ring_rotation_speed: float = 0.85

var source_actor: Node3D
var active: bool = false
var duration_remaining: float = 0.0
var refresh_timer: float = 0.0
var elapsed: float = 0.0
var affected_target_ids: Dictionary = {}
var last_target_names: Array[String] = []
var frozen_rigid_bodies: Dictionary = {}
var status_refresh_count: int = 0

var visual_root: Node3D
var bubble_shell: MeshInstance3D
var clock_rings: Array[MeshInstance3D] = []
var suspended_motes: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("time_stasis_fields")
	add_to_group("spell_fields")
	add_to_group("debuggable")
	_build_visuals()
	set_process(false)
	set_physics_process(false)


func _exit_tree() -> void:
	_release_all_rigid_bodies()


func _process(delta: float) -> void:
	if not active:
		return
	elapsed += maxf(delta, 0.0)
	_update_visuals(maxf(delta, 0.0))


func _physics_process(delta: float) -> void:
	if not active:
		return
	var safe_delta: float = maxf(delta, 0.0)
	duration_remaining = maxf(duration_remaining - safe_delta, 0.0)
	refresh_timer -= safe_delta
	if refresh_timer <= 0.0:
		refresh_timer = maxf(refresh_interval, 0.05)
		_refresh_stasis_targets()
	if duration_remaining <= 0.0:
		_finish_bubble()


func set_payload(_new_payload: Resource) -> void:
	# Stasis is a Time-native status field, not a damage transaction.
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
	refresh_timer = 0.0
	elapsed = 0.0
	status_refresh_count = 0
	affected_target_ids.clear()
	last_target_names.clear()
	_release_all_rigid_bodies()
	active = true
	if visual_root != null:
		visual_root.visible = true
	_update_visuals(0.0)
	set_process(true)
	set_physics_process(true)
	_refresh_stasis_targets()


func _resolve_ground_position(proposed_position: Vector3) -> Vector3:
	var world: World3D = get_world_3d()
	if world == null:
		return proposed_position + Vector3.UP * center_height
	var query := PhysicsRayQueryParameters3D.create(
		proposed_position + Vector3.UP * ground_probe_height,
		proposed_position - Vector3.UP * ground_probe_depth
	)
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


func _refresh_stasis_targets() -> void:
	var world: World3D = get_world_3d()
	if world == null:
		return
	var shape := SphereShape3D.new()
	shape.radius = maxf(radius, 0.1)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var current_rigid_ids: Dictionary = {}
	var seen_targets: Dictionary = {}
	for result: Dictionary in world.direct_space_state.intersect_shape(query, 128):
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_stasis_target(collider_value as Node)
		if target == null:
			continue
		var target_id: int = target.get_instance_id()
		if seen_targets.has(target_id):
			continue
		seen_targets[target_id] = true
		_apply_stasis_to_target(target, current_rigid_ids)

	_release_stale_rigid_bodies(current_rigid_ids)
	status_refresh_count += 1


func _resolve_stasis_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if not affect_source_actor and source_actor != null:
			if current == source_actor or source_actor.is_ancestor_of(current):
				return null
		if _is_stasis_target(current):
			return current
		if get_tree() != null and current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _is_stasis_target(node: Node) -> bool:
	if node == null or node is StaticBody3D or node is AnimatableBody3D:
		return false
	if node.is_in_group("boss") and not affects_bosses and not bool(
		node.get_meta("stasis_vulnerable", false)
	):
		return false
	if bool(node.get_meta("stasis_immune", false)):
		return false
	return (
		node.get_node_or_null("StatusReceiver") != null
		or node is RigidBody3D
		or node.has_method("receive_time_stasis")
	)


func _apply_stasis_to_target(target: Node, current_rigid_ids: Dictionary) -> void:
	var affected: bool = false
	var status_receiver: Node = target.get_node_or_null("StatusReceiver")
	if status_receiver != null:
		if status_receiver.has_method("sustain_status"):
			status_receiver.call(
				" sustain_status".strip_edges(),
				"stasis",
				stasis_refresh_duration,
				1.0,
				"Stasis Bubble"
			)
			affected = true
		elif status_receiver.has_method("apply_status"):
			status_receiver.call(
				"apply_status",
				"stasis",
				stasis_refresh_duration,
				1.0,
				"Stasis Bubble"
			)
			affected = true

	if target.has_method("receive_time_stasis"):
		target.call(
			"receive_time_stasis",
			stasis_refresh_duration,
			self
		)
		affected = true

	if freeze_rigid_bodies and target is RigidBody3D:
		var rigid_body := target as RigidBody3D
		var rigid_id: int = rigid_body.get_instance_id()
		current_rigid_ids[rigid_id] = true
		if not frozen_rigid_bodies.has(rigid_id):
			frozen_rigid_bodies[rigid_id] = {
				"body": rigid_body,
				"was_frozen": rigid_body.freeze,
				"linear_velocity": rigid_body.linear_velocity,
				"angular_velocity": rigid_body.angular_velocity,
			}
			rigid_body.linear_velocity = Vector3.ZERO
			rigid_body.angular_velocity = Vector3.ZERO
			rigid_body.freeze = true
		affected = true

	if not affected:
		return
	var target_id: int = target.get_instance_id()
	if not affected_target_ids.has(target_id):
		affected_target_ids[target_id] = true
		last_target_names.append(str(target.name))
		target_suspended.emit(target)


func _release_stale_rigid_bodies(current_rigid_ids: Dictionary) -> void:
	var stale_ids: Array[int] = []
	for raw_id: Variant in frozen_rigid_bodies.keys():
		var rigid_id: int = int(raw_id)
		if current_rigid_ids.has(rigid_id):
			continue
		_release_rigid_body(rigid_id)
		stale_ids.append(rigid_id)
	for rigid_id: int in stale_ids:
		frozen_rigid_bodies.erase(rigid_id)


func _release_all_rigid_bodies() -> void:
	var ids: Array[int] = []
	for raw_id: Variant in frozen_rigid_bodies.keys():
		ids.append(int(raw_id))
	for rigid_id: int in ids:
		_release_rigid_body(rigid_id)
	frozen_rigid_bodies.clear()


func _release_rigid_body(rigid_id: int) -> void:
	if not frozen_rigid_bodies.has(rigid_id):
		return
	var snapshot: Dictionary = frozen_rigid_bodies[rigid_id] as Dictionary
	var body_value: Variant = snapshot.get("body")
	if not body_value is RigidBody3D:
		return
	var rigid_body := body_value as RigidBody3D
	if not is_instance_valid(rigid_body):
		return
	var was_frozen: bool = bool(snapshot.get("was_frozen", false))
	rigid_body.freeze = was_frozen
	if not was_frozen:
		var linear_value: Variant = snapshot.get("linear_velocity", Vector3.ZERO)
		var angular_value: Variant = snapshot.get("angular_velocity", Vector3.ZERO)
		if linear_value is Vector3:
			rigid_body.linear_velocity = linear_value as Vector3
		if angular_value is Vector3:
			rigid_body.angular_velocity = angular_value as Vector3
	target_released.emit(rigid_body)


func _finish_bubble() -> void:
	if not active:
		return
	active = false
	set_process(false)
	set_physics_process(false)
	_release_all_rigid_bodies()
	if visual_root != null:
		visual_root.visible = false
	bubble_finished.emit(affected_target_ids.size())
	queue_free()


func _collect_collision_rids(node: Node, target: Array[RID]) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _build_visuals() -> void:
	visual_root = Node3D.new()
	visual_root.name = "StasisVisuals"
	add_child(visual_root)

	bubble_shell = MeshInstance3D.new()
	bubble_shell.name = "StasisShell"
	var shell := SphereMesh.new()
	shell.radius = radius
	shell.height = radius * 2.0
	shell.radial_segments = 32
	shell.rings = 16
	bubble_shell.mesh = shell
	bubble_shell.material_override = _make_time_material(
		Color(0.08, 0.42, 0.65, 0.08),
		Color(0.16, 0.78, 1.0, 1.0),
		0.65
	)
	visual_root.add_child(bubble_shell)

	clock_rings.clear()
	for index: int in range(ring_count):
		var ring := MeshInstance3D.new()
		ring.name = "ClockRing" + str(index + 1)
		var torus := TorusMesh.new()
		var ring_radius: float = radius * (0.36 + 0.11 * float(index))
		torus.inner_radius = maxf(ring_radius - 0.025, 0.01)
		torus.outer_radius = ring_radius + 0.025
		torus.rings = 32
		torus.ring_segments = 6
		ring.mesh = torus
		ring.rotation_degrees = Vector3(
			float(index) * 27.0,
			float(index) * 41.0,
			18.0 + float(index) * 13.0
		)
		ring.material_override = _make_time_material(
			Color(0.9, 0.65, 0.2, 0.42),
			Color(1.0, 0.78, 0.32, 1.0),
			1.8
		)
		visual_root.add_child(ring)
		clock_rings.append(ring)

	suspended_motes.clear()
	for index: int in range(mote_count):
		var mote := MeshInstance3D.new()
		mote.name = "SuspendedTick" + str(index + 1)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.035, 0.16, 0.035)
		mote.mesh = mesh
		mote.material_override = _make_time_material(
			Color(0.28, 0.82, 1.0, 0.7),
			Color(0.45, 0.9, 1.0, 1.0),
			2.1
		)
		var phase: float = TAU * float(index) / maxf(float(mote_count), 1.0)
		mote.position = Vector3(
			cos(phase) * radius * 0.68,
			sin(phase * 1.7) * radius * 0.35,
			sin(phase) * radius * 0.68
		)
		visual_root.add_child(mote)
		suspended_motes.append(mote)

	visual_root.visible = false


func _update_visuals(delta: float) -> void:
	if visual_root == null:
		return
	if bubble_shell != null:
		var pulse: float = 1.0 + sin(elapsed * 2.6) * 0.018
		bubble_shell.scale = Vector3.ONE * pulse
	for index: int in range(clock_rings.size()):
		var ring: MeshInstance3D = clock_rings[index]
		var sign: float = 1.0 if index % 2 == 0 else -1.0
		ring.rotation.y += ring_rotation_speed * sign * delta
		ring.rotation.x += ring_rotation_speed * 0.27 * delta
	for index: int in range(suspended_motes.size()):
		var mote: MeshInstance3D = suspended_motes[index]
		mote.rotation.y += delta * 0.35


func _make_time_material(
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
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.roughness = 0.2
	return material


func get_debug_data() -> Dictionary:
	return {
		"spell": "stasis_bubble",
		"time_stasis_contract": true,
		"native_time_status": true,
		"direct_damage": false,
		"active": active,
		"duration_remaining": snappedf(duration_remaining, 0.01),
		"radius": radius,
		"affected_targets": affected_target_ids.size(),
		"target_names": last_target_names.duplicate(),
		"frozen_rigid_bodies": frozen_rigid_bodies.size(),
		"status_refresh_count": status_refresh_count,
	}
