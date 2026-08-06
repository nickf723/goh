extends Node3D
class_name AsteroidBelt

signal belt_started(source_actor: Node3D, duration: float, asteroid_count: int)
signal asteroid_contact(target: Node, asteroid_index: int, hit_count: int, result: Dictionary)
signal belt_finished(reason: String, unique_targets: int, total_contacts: int)

const AsteroidElementVisuals = preload(
	"res://scripts/visuals/element_visuals.gd"
)

@export_group("Orbit")
@export_range(1, 12, 1) var asteroid_count: int = 6
@export_range(0.5, 8.0, 0.05) var orbit_radius: float = 2.75
@export_range(0.0, 3.0, 0.05) var orbit_height_offset: float = 0.1
@export_range(0.0, 3.0, 0.05) var vertical_bob: float = 0.28
@export_range(0.1, 8.0, 0.05) var orbit_speed_radians: float = 2.35
@export_range(0.1, 2.0, 0.05) var asteroid_radius: float = 0.48
@export_range(0.1, 2.0, 0.05) var asteroid_contact_radius: float = 0.72

@export_group("Lifetime")
@export_range(0.25, 60.0, 0.1) var duration_seconds: float = 8.0
@export_range(0.0, 2.0, 0.05) var fade_in_seconds: float = 0.22
@export_range(0.0, 2.0, 0.05) var fade_out_seconds: float = 0.42
@export_range(1, 12, 1) var maximum_global_belts: int = 4

@export_group("Contact")
@export_flags_3d_physics var collision_mask: int = 1
@export_range(1.0, 30.0, 0.5) var contact_scans_per_second: float = 10.0
@export_range(1, 256, 1) var maximum_contact_candidates: int = 64
@export_range(0.0, 2.0, 0.05) var target_contact_padding: float = 0.28
@export_range(0.05, 5.0, 0.05) var target_repeat_cooldown: float = 0.9
@export_range(1, 12, 1) var maximum_hits_per_target: int = 3
@export_range(0.0, 1.0, 0.05) var boss_knockback_multiplier: float = 0.2
@export_range(0.0, 30.0, 0.1) var rigid_body_impulse: float = 4.0

@export_group("Performance")
@export_range(5.0, 120.0, 1.0) var visual_updates_per_second: float = 30.0
@export var use_single_multimesh: bool = true
@export var replace_existing_belt_from_same_source: bool = true
@export var show_debug_messages: bool = false

var runtime_payload: DamagePayload
var source_actor: Node3D
var belt_active: bool = false
var elapsed: float = 0.0
var duration_remaining: float = 0.0
var visual_accumulator: float = 0.0
var contact_accumulator: float = 0.0
var finish_reason: String = "none"

var asteroid_multimesh: MultiMesh
var asteroid_visual: MultiMeshInstance3D
var orbit_ring: MeshInstance3D
var asteroid_local_positions: Array[Vector3] = []
var asteroid_world_positions: Array[Vector3] = []
var asteroid_scales: Array[Vector3] = []

var broadphase_shape: SphereShape3D
var broadphase_query: PhysicsShapeQueryParameters3D
var collision_exclusions: Array[RID] = []
var target_cooldowns: Dictionary = {}
var target_hit_counts: Dictionary = {}
var contacted_target_names: Array[String] = []
var total_contacts: int = 0
var contact_scan_count: int = 0
var broadphase_candidate_count: int = 0
var visual_update_count: int = 0


func _ready() -> void:
	add_to_group("asteroid_belt_effects")
	add_to_group("spell_effects")
	add_to_group("persistent_spell_effects")
	add_to_group("debuggable")
	_build_visuals()
	_build_broadphase_query()
	set_process(false)


func set_payload(new_payload: Resource) -> void:
	if not new_payload is DamagePayload:
		return
	var duplicate_value: Resource = (new_payload as DamagePayload).duplicate(true)
	runtime_payload = (
		duplicate_value as DamagePayload
		if duplicate_value is DamagePayload
		else new_payload as DamagePayload
	)


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is Node3D:
		source_actor = new_source_actor as Node3D


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if source_actor == null:
		source_actor = player
	begin_belt()


func begin_belt() -> bool:
	if belt_active:
		return true
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return false

	_retire_existing_belts()
	elapsed = 0.0
	duration_remaining = maxf(duration_seconds, 0.25)
	visual_accumulator = 0.0
	contact_accumulator = 0.0
	finish_reason = "active"
	target_cooldowns.clear()
	target_hit_counts.clear()
	contacted_target_names.clear()
	total_contacts = 0
	contact_scan_count = 0
	broadphase_candidate_count = 0
	visual_update_count = 0
	_refresh_collision_exclusions()
	_follow_source()
	belt_active = true
	if asteroid_visual != null:
		asteroid_visual.visible = true
	if orbit_ring != null:
		orbit_ring.visible = true
	_update_asteroid_transforms()
	set_process(true)
	belt_started.emit(source_actor, duration_remaining, asteroid_count)
	return true


func _process(delta: float) -> void:
	if not belt_active:
		return
	if source_actor == null or not is_instance_valid(source_actor):
		finish_belt("source_lost")
		return
	if not source_actor.is_inside_tree():
		finish_belt("source_left_tree")
		return

	var safe_delta: float = maxf(delta, 0.0)
	elapsed += safe_delta
	duration_remaining = maxf(duration_remaining - safe_delta, 0.0)
	_follow_source()

	visual_accumulator += safe_delta
	var visual_interval: float = 1.0 / maxf(visual_updates_per_second, 1.0)
	if visual_accumulator >= visual_interval:
		visual_accumulator = fmod(visual_accumulator, visual_interval)
		_update_asteroid_transforms()

	contact_accumulator += safe_delta
	var contact_interval: float = 1.0 / maxf(contact_scans_per_second, 1.0)
	if contact_accumulator >= contact_interval:
		var cooldown_step: float = contact_accumulator
		contact_accumulator = fmod(contact_accumulator, contact_interval)
		_advance_target_cooldowns(cooldown_step)
		scan_contacts()

	if duration_remaining <= 0.0:
		finish_belt("duration_complete")


func finish_belt(reason: String = "finished") -> void:
	if not belt_active:
		return
	belt_active = false
	finish_reason = reason
	set_process(false)
	if asteroid_visual != null:
		asteroid_visual.visible = false
	if orbit_ring != null:
		orbit_ring.visible = false
	belt_finished.emit(reason, contacted_target_names.size(), total_contacts)
	queue_free()


func reset_target() -> void:
	finish_belt("reset")


func belongs_to_source(candidate: Node) -> bool:
	return source_actor != null and candidate == source_actor


func scan_contacts() -> int:
	if not belt_active:
		return 0
	var world: World3D = get_world_3d()
	if world == null or broadphase_query == null:
		return 0
	if asteroid_world_positions.size() != asteroid_count:
		_update_asteroid_transforms()

	broadphase_query.transform = Transform3D(Basis.IDENTITY, global_position)
	broadphase_query.exclude = collision_exclusions
	var results: Array[Dictionary] = world.direct_space_state.intersect_shape(
		broadphase_query,
		maximum_contact_candidates
	)
	contact_scan_count += 1
	broadphase_candidate_count += results.size()

	var seen_targets: Dictionary = {}
	var used_asteroids: Dictionary = {}
	var contacts_this_scan: int = 0
	for result: Dictionary in results:
		var collider_value: Variant = result.get("collider")
		if not collider_value is Node:
			continue
		var target: Node = _resolve_contact_target(collider_value as Node)
		if target == null or target == source_actor:
			continue
		var target_id: int = target.get_instance_id()
		if seen_targets.has(target_id):
			continue
		seen_targets[target_id] = true
		var asteroid_index: int = find_contacting_asteroid(
			_get_target_center(target),
			used_asteroids
		)
		if asteroid_index < 0:
			continue
		var contact_result: Dictionary = apply_contact_to_target(
			target,
			asteroid_index
		)
		if not bool(contact_result.get("contact_applied", false)):
			continue
		used_asteroids[asteroid_index] = true
		contacts_this_scan += 1
	return contacts_this_scan


func find_contacting_asteroid(
	world_position: Vector3,
	used_asteroids: Dictionary = {}
) -> int:
	var threshold: float = maxf(
		asteroid_contact_radius + target_contact_padding,
		0.05
	)
	var threshold_squared: float = threshold * threshold
	var best_index: int = -1
	var best_distance_squared: float = threshold_squared
	for index: int in range(asteroid_world_positions.size()):
		if used_asteroids.has(index):
			continue
		var distance_squared: float = asteroid_world_positions[index].distance_squared_to(
			world_position
		)
		if distance_squared > best_distance_squared:
			continue
		best_distance_squared = distance_squared
		best_index = index
	return best_index


func apply_contact_to_target(
	target: Node,
	asteroid_index: int = 0,
	ignore_cooldown: bool = false
) -> Dictionary:
	if target == null or not is_instance_valid(target):
		return {"contact_applied": false, "reason": "invalid_target"}
	if target == source_actor or (
		source_actor != null
		and source_actor.is_ancestor_of(target)
	):
		return {"contact_applied": false, "reason": "source_immune"}

	var target_id: int = target.get_instance_id()
	if not ignore_cooldown and float(target_cooldowns.get(target_id, 0.0)) > 0.0:
		return {"contact_applied": false, "reason": "cooldown"}
	var previous_hits: int = int(target_hit_counts.get(target_id, 0))
	if previous_hits >= maximum_hits_per_target:
		return {"contact_applied": false, "reason": "target_hit_limit"}

	var contact_payload: DamagePayload = _make_contact_payload(target, asteroid_index)
	var result: Dictionary = _deliver_contact(target, contact_payload)
	if not bool(result.get("handled", false)):
		result["contact_applied"] = false
		return result

	var next_hits: int = previous_hits + 1
	target_hit_counts[target_id] = next_hits
	target_cooldowns[target_id] = maxf(target_repeat_cooldown, 0.05)
	total_contacts += 1
	var target_name: String = str(target.name)
	if not contacted_target_names.has(target_name):
		contacted_target_names.append(target_name)
	_spawn_contact_feedback(target)
	result["contact_applied"] = true
	result["asteroid_index"] = asteroid_index
	result["hit_count"] = next_hits
	asteroid_contact.emit(target, asteroid_index, next_hits, result.duplicate(true))
	if show_debug_messages:
		print(
			"ASTEROID_BELT contact ",
			target_name,
			" [",
			next_hits,
			"/",
			maximum_hits_per_target,
			"] asteroid=",
			asteroid_index
		)
	return result


func _make_contact_payload(target: Node, asteroid_index: int) -> DamagePayload:
	var source_payload: DamagePayload = get_payload()
	var duplicate_value: Resource = source_payload.duplicate(true)
	var contact_payload: DamagePayload = (
		duplicate_value as DamagePayload
		if duplicate_value is DamagePayload
		else source_payload
	)
	var outward: Vector3 = _get_outward_direction(target, asteroid_index)
	contact_payload.knockback_direction = outward
	if target.is_in_group("boss"):
		contact_payload.knockback_strength *= clampf(
			boss_knockback_multiplier,
			0.0,
			1.0
		)
	_append_payload_tags(contact_payload, [
		"asteroid_belt",
		"orbit_contact",
		"space_positioning",
	])
	return contact_payload


func _deliver_contact(target: Node, contact_payload: DamagePayload) -> Dictionary:
	var target_name: String = str(target.name)
	var payload_receiver: Node = _get_component(target, "PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		return _normalize_contact_result(
			payload_receiver.call("receive_payload", contact_payload),
			target_name
		)
	if target.has_method("receive_damage_payload"):
		return _normalize_contact_result(
			target.call("receive_damage_payload", contact_payload),
			target_name
		)
	var hit_receiver: Node = _get_component(target, "HitReceiver")
	if hit_receiver != null:
		if hit_receiver.has_method("receive_payload"):
			return _normalize_contact_result(
				hit_receiver.call("receive_payload", contact_payload),
				target_name
			)
		if hit_receiver.has_method("receive_hit"):
			return _normalize_contact_result(
				hit_receiver.call("receive_hit", contact_payload.amount),
				target_name
			)
	if target.has_method("receive_magic_hit"):
		return _normalize_contact_result(
			target.call("receive_magic_hit", contact_payload.amount),
			target_name
		)

	var force_receiver: Node = _get_component(target, "ForceReceiver")
	if force_receiver != null and force_receiver.has_method("apply_impulse"):
		force_receiver.call(
			"apply_impulse",
			contact_payload.knockback_direction,
			contact_payload.knockback_strength,
			contact_payload.knockback_up_strength,
			contact_payload.source_name
		)
		return {
			"handled": true,
			"message": "",
			"objective": "",
			"force_only": true,
		}
	if target is RigidBody3D:
		var rigid_body := target as RigidBody3D
		rigid_body.apply_central_impulse(
			contact_payload.knockback_direction
			* maxf(rigid_body_impulse, 0.0)
		)
		return {
			"handled": true,
			"message": "",
			"objective": "",
			"rigid_body": true,
		}
	return {
		"handled": false,
		"message": "",
		"objective": "",
		"reason": "no_receiver",
	}


func _normalize_contact_result(value: Variant, target_name: String) -> Dictionary:
	if value is Dictionary:
		var dictionary_result: Dictionary = (value as Dictionary).duplicate(true)
		dictionary_result["handled"] = bool(
			dictionary_result.get("handled", true)
		)
		if not dictionary_result.has("message"):
			dictionary_result["message"] = ""
		if not dictionary_result.has("objective"):
			dictionary_result["objective"] = ""
		return dictionary_result
	return {
		"handled": true,
		"message": "" if value == null else str(value),
		"objective": "",
		"target": target_name,
		"receiver_return_type": type_string(typeof(value)),
	}


func _resolve_contact_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current == source_actor or (
			source_actor != null
			and source_actor.is_ancestor_of(current)
		):
			return null
		if (
			_get_component(current, "PayloadReceiver") != null
			or _get_component(current, "HitReceiver") != null
			or _get_component(current, "ForceReceiver") != null
			or current.has_method("receive_damage_payload")
			or current.has_method("receive_magic_hit")
			or current is RigidBody3D
		):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _get_component(target: Node, component_name: String) -> Node:
	if target == null:
		return null
	return target.get_node_or_null(component_name)


func _get_target_center(target: Node) -> Vector3:
	if target == null:
		return global_position
	var collision_shape: CollisionShape3D = target.get_node_or_null(
		"CollisionShape3D"
	) as CollisionShape3D
	if collision_shape != null:
		return collision_shape.global_position
	if target is Node3D:
		return (target as Node3D).global_position
	var parent: Node = target.get_parent()
	return (
		(parent as Node3D).global_position
		if parent is Node3D
		else global_position
	)


func _get_outward_direction(target: Node, asteroid_index: int) -> Vector3:
	var outward: Vector3 = _get_target_center(target) - global_position
	outward.y = 0.0
	if outward.length_squared() <= 0.0001 and (
		asteroid_index >= 0
		and asteroid_index < asteroid_world_positions.size()
	):
		outward = asteroid_world_positions[asteroid_index] - global_position
		outward.y = 0.0
	if outward.length_squared() <= 0.0001:
		outward = Vector3.FORWARD
	return outward.normalized()


func _advance_target_cooldowns(delta: float) -> void:
	if target_cooldowns.is_empty():
		return
	var expired_ids: Array[int] = []
	for target_id_value: Variant in target_cooldowns.keys():
		var target_id: int = int(target_id_value)
		var next_value: float = maxf(
			float(target_cooldowns[target_id]) - delta,
			0.0
		)
		target_cooldowns[target_id] = next_value
		if next_value <= 0.0:
			expired_ids.append(target_id)
	for target_id: int in expired_ids:
		target_cooldowns.erase(target_id)


func _follow_source() -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		return
	global_position = (
		source_actor.global_position
		+ Vector3.UP * orbit_height_offset
	)


func _build_visuals() -> void:
	asteroid_count = maxi(asteroid_count, 1)
	asteroid_local_positions.resize(asteroid_count)
	asteroid_world_positions.resize(asteroid_count)
	asteroid_scales.resize(asteroid_count)

	var asteroid_mesh := SphereMesh.new()
	asteroid_mesh.radius = maxf(asteroid_radius, 0.05)
	asteroid_mesh.height = maxf(asteroid_radius * 2.0, 0.1)
	asteroid_mesh.radial_segments = 8
	asteroid_mesh.rings = 5
	asteroid_mesh.material = _make_asteroid_material()

	asteroid_multimesh = MultiMesh.new()
	asteroid_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	asteroid_multimesh.mesh = asteroid_mesh
	asteroid_multimesh.instance_count = asteroid_count
	asteroid_visual = MultiMeshInstance3D.new()
	asteroid_visual.name = "AsteroidMultiMesh"
	asteroid_visual.multimesh = asteroid_multimesh
	asteroid_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	asteroid_visual.visibility_range_end = 38.0
	asteroid_visual.visibility_range_end_margin = 4.0
	asteroid_visual.extra_cull_margin = 2.0
	asteroid_visual.visible = false
	asteroid_visual.set_meta("single_draw_orbit", use_single_multimesh)
	add_child(asteroid_visual)

	orbit_ring = MeshInstance3D.new()
	orbit_ring.name = "OrbitGuide"
	orbit_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orbit_ring.visibility_range_end = 34.0
	orbit_ring.visibility_range_end_margin = 4.0
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = maxf(orbit_radius - 0.045, 0.05)
	ring_mesh.outer_radius = orbit_radius + 0.045
	ring_mesh.rings = 40
	ring_mesh.ring_segments = 6
	ring_mesh.material = _make_orbit_material()
	orbit_ring.mesh = ring_mesh
	orbit_ring.visible = false
	add_child(orbit_ring)

	for index: int in range(asteroid_count):
		var factor: float = float(index + 1)
		asteroid_scales[index] = Vector3(
			0.76 + fmod(factor * 0.37, 0.34),
			0.68 + fmod(factor * 0.23, 0.3),
			0.82 + fmod(factor * 0.41, 0.28)
		)
	_update_asteroid_transforms()


func _make_asteroid_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.22, 0.42, 1.0)
	material.metallic = 0.22
	material.roughness = 0.82
	material.emission_enabled = true
	material.emission = Color(0.3, 0.08, 0.62)
	material.emission_energy_multiplier = 1.15
	return material


func _make_orbit_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.62, 0.34, 1.0, 0.34)
	material.emission_enabled = true
	material.emission = Color(0.46, 0.18, 1.0)
	material.emission_energy_multiplier = 1.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _update_asteroid_transforms() -> void:
	if asteroid_multimesh == null:
		return
	var count: int = mini(
		asteroid_count,
		asteroid_multimesh.instance_count
	)
	var fade: float = _get_fade_fraction()
	for index: int in range(count):
		var phase: float = TAU * float(index) / float(maxi(count, 1))
		var angle: float = phase + elapsed * orbit_speed_radians
		var radius_variation: float = 1.0 + sin(
			angle * 1.7 + float(index) * 0.83
		) * 0.055
		var local_position := Vector3(
			cos(angle) * orbit_radius * radius_variation,
			sin(angle * 2.0 + float(index) * 0.61) * vertical_bob,
			sin(angle) * orbit_radius * radius_variation
		)
		asteroid_local_positions[index] = local_position
		asteroid_world_positions[index] = global_position + local_position

		var spin := Vector3(
			elapsed * (0.75 + float(index) * 0.08),
			-angle * (0.42 + float(index) * 0.025),
			elapsed * (1.05 + float(index) * 0.06)
		)
		var basis: Basis = Basis.from_euler(spin)
		basis = basis.scaled(asteroid_scales[index] * fade)
		asteroid_multimesh.set_instance_transform(
			index,
			Transform3D(basis, local_position)
		)
	if asteroid_visual != null:
		asteroid_visual.transparency = 1.0 - fade
	if orbit_ring != null:
		orbit_ring.rotation.y = elapsed * orbit_speed_radians * 0.16
		orbit_ring.transparency = 1.0 - fade * 0.72
	visual_update_count += 1


func _get_fade_fraction() -> float:
	var fade: float = 1.0
	if fade_in_seconds > 0.001:
		fade = minf(fade, clampf(elapsed / fade_in_seconds, 0.0, 1.0))
	if fade_out_seconds > 0.001:
		fade = minf(
			fade,
			clampf(duration_remaining / fade_out_seconds, 0.0, 1.0)
		)
	return fade


func _build_broadphase_query() -> void:
	broadphase_shape = SphereShape3D.new()
	broadphase_shape.radius = maxf(
		orbit_radius + asteroid_contact_radius + target_contact_padding,
		0.5
	)
	broadphase_query = PhysicsShapeQueryParameters3D.new()
	broadphase_query.shape = broadphase_shape
	broadphase_query.collision_mask = collision_mask
	broadphase_query.collide_with_bodies = true
	broadphase_query.collide_with_areas = true


func _refresh_collision_exclusions() -> void:
	collision_exclusions.clear()
	_collect_collision_rids(source_actor, collision_exclusions)


func _collect_collision_rids(node: Node, destination: Array[RID]) -> void:
	if node == null or not is_instance_valid(node):
		return
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not destination.has(rid):
			destination.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, destination)


func _retire_existing_belts() -> void:
	var active_belts: Array[AsteroidBelt] = []
	for node: Node in get_tree().get_nodes_in_group("asteroid_belt_effects"):
		if node == self or not node is AsteroidBelt:
			continue
		var belt := node as AsteroidBelt
		if not belt.belt_active:
			continue
		if (
			replace_existing_belt_from_same_source
			and belt.belongs_to_source(source_actor)
		):
			belt.finish_belt("recast_replaced")
			continue
		active_belts.append(belt)

	while active_belts.size() >= maxi(maximum_global_belts, 1):
		var oldest: AsteroidBelt = active_belts[0]
		for belt: AsteroidBelt in active_belts:
			if belt.elapsed > oldest.elapsed:
				oldest = belt
		oldest.finish_belt("global_effect_budget")
		active_belts.erase(oldest)


func _spawn_contact_feedback(target: Node) -> void:
	if get_tree() == null:
		return
	AsteroidElementVisuals.spawn_impact(
		get_tree(),
		_get_target_center(target),
		"space",
		0.92
	)


func _append_payload_tags(
	active_payload: DamagePayload,
	tags_to_add: Array[String]
) -> void:
	if active_payload == null:
		return
	var next_tags: Array[String] = []
	for existing_tag: String in active_payload.tags:
		if existing_tag != "" and not next_tags.has(existing_tag):
			next_tags.append(existing_tag)
	for tag: String in tags_to_add:
		if tag != "" and not next_tags.has(tag):
			next_tags.append(tag)
	active_payload.tags = next_tags


func get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload
	var fallback := DamagePayload.new()
	fallback.amount = 2
	fallback.stance_damage = 3
	fallback.element = "space"
	fallback.source_name = "Asteroid Belt"
	fallback.hit_type = "orbit_contact"
	fallback.tags = [
		"space",
		"magic",
		"asteroid",
		"orbit",
		"force",
		"persistent",
		"positioning",
	]
	fallback.knockback_strength = 3.6
	return fallback


func get_debug_data() -> Dictionary:
	return {
		"asteroid_belt": true,
		"active": belt_active,
		"source": source_actor.name if source_actor != null else "none",
		"duration_remaining": snappedf(duration_remaining, 0.01),
		"asteroid_count": asteroid_count,
		"orbit_radius": snappedf(orbit_radius, 0.01),
		"single_multimesh": asteroid_visual != null,
		"multimesh_instances": (
			asteroid_multimesh.instance_count
			if asteroid_multimesh != null
			else 0
		),
		"individual_asteroid_nodes": 0,
		"visual_updates_per_second": visual_updates_per_second,
		"contact_scans_per_second": contact_scans_per_second,
		"visual_update_count": visual_update_count,
		"contact_scan_count": contact_scan_count,
		"broadphase_candidates": broadphase_candidate_count,
		"total_contacts": total_contacts,
		"unique_targets": contacted_target_names.size(),
		"target_hit_counts": target_hit_counts.duplicate(true),
		"finish_reason": finish_reason,
	}
