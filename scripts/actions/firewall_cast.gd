extends Node3D
class_name FirewallCast

signal drawing_started
signal surface_point_added(position: Vector3, normal: Vector3, point_count: int)
signal drawing_finished(reason: String, point_count: int, path_length: float)
signal firewall_ignited(point_count: int, segment_count: int, path_length: float)
signal firewall_finished(reason: String)
signal firewall_target_hit(target: Node, result: Dictionary)

enum FirewallPhase {
	IDLE,
	DRAWING,
	ERUPTING,
	LINGERING,
	FADING,
	FINISHED,
}

@export_group("Drawing")
@export var channel_action: StringName = &"cast_spell"
@export_range(0.25, 8.0, 0.05) var maximum_draw_seconds: float = 2.7
@export_range(1.0, 40.0, 0.5) var maximum_path_length: float = 18.0
@export_range(2, 128, 1) var maximum_path_points: int = 72
@export_range(0.01, 0.25, 0.01) var sample_interval_seconds: float = 0.04
@export_range(0.05, 1.0, 0.01) var minimum_sample_spacing: float = 0.22
@export_range(0.05, 1.5, 0.01) var resample_spacing: float = 0.34
@export_range(0.25, 6.0, 0.05) var maximum_surface_gap: float = 2.6
@export_range(-1.0, 1.0, 0.01) var corner_normal_dot_threshold: float = 0.82
@export_range(-1.0, 1.0, 0.01) var opposite_surface_rejection_dot: float = -0.35
@export_range(0.2, 3.0, 0.05) var minimum_ignition_length: float = 0.7
@export_range(1.0, 30.0, 0.5) var targeting_range: float = 12.0
@export_flags_3d_physics var targeting_collision_mask: int = 1
@export var allow_animatable_surfaces: bool = true
@export var allow_grouped_dynamic_surfaces: bool = true

@export_group("Firewall")
@export_range(0.25, 5.0, 0.05) var wall_height: float = 2.2
@export_range(0.05, 2.0, 0.05) var wall_thickness: float = 0.42
@export_range(0.0, 0.5, 0.01) var segment_overlap: float = 0.1
@export_range(0.0, 0.2, 0.005) var surface_offset: float = 0.035
@export_range(0.05, 1.0, 0.01) var eruption_seconds: float = 0.2
@export_range(0.1, 12.0, 0.1) var linger_seconds: float = 3.2
@export_range(0.05, 2.0, 0.05) var fade_seconds: float = 0.4
@export_range(4.0, 60.0, 1.0) var visual_updates_per_second: float = 24.0

@export_group("Contact")
@export_range(0.05, 2.0, 0.05) var contact_tick_seconds: float = 0.28
@export_range(0.05, 2.0, 0.05) var repeat_hit_seconds: float = 0.45
@export_range(0.1, 3.0, 0.05) var contact_depth: float = 0.8
@export_range(1, 64, 1) var maximum_contact_segments: int = 32
@export_range(0.0, 5000.0, 10.0) var heat_energy_j_per_second: float = 520.0
@export_flags_3d_physics var contact_collision_mask: int = 1

@export_group("Presentation")
@export_range(0.005, 0.15, 0.005) var laser_thickness: float = 0.025
@export_range(0.02, 0.6, 0.01) var surface_line_width: float = 0.12
@export_range(0.005, 0.1, 0.005) var surface_line_thickness: float = 0.022
@export_range(0.04, 0.8, 0.01) var joint_radius: float = 0.18

var source_actor: CharacterBody3D
var action_state: PlayerActionState
var ability_caster: Node
var runtime_payload: DamagePayload
var phase: FirewallPhase = FirewallPhase.IDLE
var owns_cast_channel: bool = false

var path_points: Array[Dictionary] = []
var visual_segments: Array[Dictionary] = []
var contact_segments: Array[Dictionary] = []
var collision_exclusions: Array[RID] = []
var target_last_hit_time: Dictionary = {}

var draw_elapsed: float = 0.0
var sample_accumulator: float = 0.0
var wall_elapsed: float = 0.0
var contact_accumulator: float = 0.0
var visual_accumulator: float = 0.0
var path_length: float = 0.0
var surface_transition_count: int = 0
var rejected_surface_jump_count: int = 0
var total_contact_queries: int = 0
var total_targets_hit: int = 0
var last_end_reason: String = "not_started"
var current_height_ratio: float = 0.0
var current_fade_alpha: float = 1.0
var path_limit_reached: bool = false

var test_cast_held_override_enabled: bool = false
var test_cast_held: bool = true

var laser_visual: MeshInstance3D
var endpoint_marker: MeshInstance3D
var surface_line_visual: MultiMeshInstance3D
var outer_flame_visual: MultiMeshInstance3D
var inner_flame_visual: MultiMeshInstance3D
var joint_flame_visual: MultiMeshInstance3D
var fire_light: OmniLight3D

var unit_box_mesh: BoxMesh
var joint_mesh: SphereMesh
var laser_material: StandardMaterial3D
var surface_line_material: StandardMaterial3D
var outer_flame_material: StandardMaterial3D
var inner_flame_material: StandardMaterial3D
var joint_flame_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("spell_effects")
	add_to_group("firewall_effects")
	add_to_group("debuggable")
	add_to_group("lab_resettable")
	global_transform = Transform3D.IDENTITY
	_build_visuals()
	_set_drawing_visuals_visible(false)
	_set_firewall_visuals_visible(false)
	set_process(false)
	set_physics_process(false)


func _exit_tree() -> void:
	_release_cast_channel()


func set_payload(new_payload: Resource) -> void:
	if new_payload is DamagePayload:
		runtime_payload = (
			(new_payload as DamagePayload).duplicate(true) as DamagePayload
		)


func set_source_actor(new_source_actor: Node) -> void:
	if new_source_actor is CharacterBody3D:
		source_actor = new_source_actor as CharacterBody3D


func belongs_to_source(candidate: Node) -> bool:
	return source_actor != null and source_actor == candidate


func execute(player: Node3D, _cast_direction: Vector3) -> void:
	if player is CharacterBody3D:
		source_actor = player as CharacterBody3D
	if source_actor == null or not is_instance_valid(source_actor):
		queue_free()
		return

	action_state = source_actor.get_node_or_null(
		"PlayerActionState"
	) as PlayerActionState
	ability_caster = source_actor.get_node_or_null("AbilityCaster")
	_collect_collision_rids(source_actor, collision_exclusions)
	_cancel_previous_firewalls()

	# AbilityCaster has already paid the authored cost and started a short cast
	# lock. Convert that lock into an owned channel so drawing blocks other actions
	# while movement, Surf, and camera control remain available.
	if action_state != null:
		action_state.end_cast()
		if not action_state.begin_cast_channel():
			last_end_reason = "channel_rejected"
			queue_free()
			return
		owns_cast_channel = true

	phase = FirewallPhase.DRAWING
	draw_elapsed = 0.0
	sample_accumulator = 0.0
	path_length = 0.0
	surface_transition_count = 0
	rejected_surface_jump_count = 0
	path_limit_reached = false
	path_points.clear()
	visual_segments.clear()
	contact_segments.clear()
	target_last_hit_time.clear()
	last_end_reason = "drawing"
	_set_drawing_visuals_visible(true)
	_set_firewall_visuals_visible(false)
	set_process(true)
	_sample_current_surface()
	drawing_started.emit()
	_show_message(
		"Firewall: hold Cast and paint a surface path. Release to ignite it."
	)


func _process(delta: float) -> void:
	match phase:
		FirewallPhase.DRAWING:
			advance_drawing(delta, _is_cast_held())
		FirewallPhase.ERUPTING, FirewallPhase.LINGERING, FirewallPhase.FADING:
			_advance_firewall_visuals(delta)
		_:
			pass


func _physics_process(delta: float) -> void:
	if phase not in [
		FirewallPhase.ERUPTING,
		FirewallPhase.LINGERING,
		FirewallPhase.FADING,
	]:
		return
	if current_height_ratio <= 0.2 or current_fade_alpha <= 0.05:
		return
	contact_accumulator -= maxf(delta, 0.0)
	if contact_accumulator > 0.0:
		return
	contact_accumulator += maxf(contact_tick_seconds, 0.05)
	_scan_firewall_contacts()


func advance_drawing(delta: float, cast_held: bool = true) -> bool:
	if phase != FirewallPhase.DRAWING:
		return false
	if not cast_held:
		finish_drawing("released", true)
		return false
	if _drawing_interrupted():
		cancel_drawing("interrupted")
		return false
	if not _is_firewall_still_equipped():
		cancel_drawing("spell_changed")
		return false

	var step: float = maxf(delta, 0.0)
	draw_elapsed += step
	sample_accumulator += step
	var interval: float = maxf(sample_interval_seconds, 0.01)
	var sample_safety: int = 0
	while sample_accumulator >= interval and sample_safety < 4:
		sample_accumulator -= interval
		_sample_current_surface()
		sample_safety += 1

	if (
		draw_elapsed >= maximum_draw_seconds
		or path_limit_reached
		or path_points.size() >= maximum_path_points
	):
		finish_drawing(
			"time_limit" if draw_elapsed >= maximum_draw_seconds else "path_limit",
			true
		)
		return false
	return true


func finish_drawing(
	reason: String = "released",
	ignite: bool = true
) -> void:
	if phase != FirewallPhase.DRAWING:
		return
	_sample_current_surface()
	_release_cast_channel()
	_set_drawing_visuals_visible(false)
	drawing_finished.emit(reason, path_points.size(), path_length)
	if not ignite or not _ensure_minimum_path():
		last_end_reason = reason if not ignite else "no_surface_path"
		phase = FirewallPhase.FINISHED
		set_process(false)
		set_physics_process(false)
		queue_free()
		return
	_begin_firewall(reason)


func finish_drawing_for_test(reason: String = "test_release") -> void:
	finish_drawing(reason, true)


func cancel_drawing(reason: String = "cancelled") -> void:
	if phase != FirewallPhase.DRAWING:
		return
	_release_cast_channel()
	last_end_reason = reason
	phase = FirewallPhase.FINISHED
	_set_drawing_visuals_visible(false)
	set_process(false)
	set_physics_process(false)
	drawing_finished.emit(reason, path_points.size(), path_length)
	queue_free()


func finish_firewall(reason: String = "complete") -> void:
	if phase == FirewallPhase.DRAWING:
		cancel_drawing(reason)
		return
	if phase == FirewallPhase.FINISHED:
		return
	phase = FirewallPhase.FINISHED
	last_end_reason = reason
	set_process(false)
	set_physics_process(false)
	_set_firewall_visuals_visible(false)
	if is_in_group("persistent_spell_effects"):
		remove_from_group("persistent_spell_effects")
	firewall_finished.emit(reason)
	queue_free()


func reset_target() -> void:
	if phase == FirewallPhase.DRAWING:
		cancel_drawing("reset")
	else:
		finish_firewall("reset")


func set_test_cast_held_override(
	held: bool,
	enabled: bool = true
) -> void:
	test_cast_held = held
	test_cast_held_override_enabled = enabled


func append_surface_sample_for_test(
	position: Vector3,
	normal: Vector3,
	collider_name: String = "TestSurface",
	collider_id: int = 0
) -> bool:
	if phase != FirewallPhase.DRAWING:
		return false
	return _append_surface_sample(
		position,
		normal,
		collider_id,
		collider_name
	)


func get_path_snapshot() -> Array[Dictionary]:
	return path_points.duplicate(true)


func _begin_firewall(reason: String) -> void:
	_build_visual_segments()
	_build_contact_segments()
	if visual_segments.is_empty():
		last_end_reason = "no_segments"
		phase = FirewallPhase.FINISHED
		queue_free()
		return

	phase = FirewallPhase.ERUPTING
	wall_elapsed = 0.0
	visual_accumulator = 0.0
	contact_accumulator = 0.0
	current_height_ratio = 0.0
	current_fade_alpha = 1.0
	last_end_reason = reason
	if not is_in_group("persistent_spell_effects"):
		add_to_group("persistent_spell_effects")
	_set_firewall_visuals_visible(true)
	_prepare_firewall_multimeshes()
	_update_firewall_visuals(true)
	_write_firewall_metadata(reason)
	set_process(true)
	set_physics_process(true)
	firewall_ignited.emit(
		path_points.size(),
		visual_segments.size(),
		path_length
	)
	_show_message(
		"Firewall ignites across "
		+ str(snappedf(path_length, 0.1))
		+ " meters of surface."
	)


func _advance_firewall_visuals(delta: float) -> void:
	var step: float = maxf(delta, 0.0)
	wall_elapsed += step
	var eruption_end: float = maxf(eruption_seconds, 0.01)
	var linger_end: float = eruption_end + maxf(linger_seconds, 0.0)
	var total_end: float = linger_end + maxf(fade_seconds, 0.01)

	if wall_elapsed < eruption_end:
		phase = FirewallPhase.ERUPTING
		var eruption_ratio: float = clampf(
			wall_elapsed / eruption_end,
			0.0,
			1.0
		)
		current_height_ratio = 1.0 - pow(1.0 - eruption_ratio, 3.0)
		current_fade_alpha = 1.0
	elif wall_elapsed < linger_end:
		phase = FirewallPhase.LINGERING
		current_height_ratio = 1.0
		current_fade_alpha = 1.0
	elif wall_elapsed < total_end:
		phase = FirewallPhase.FADING
		current_height_ratio = 1.0
		current_fade_alpha = 1.0 - clampf(
			(wall_elapsed - linger_end) / maxf(fade_seconds, 0.01),
			0.0,
			1.0
		)
	else:
		finish_firewall("expired")
		return

	visual_accumulator += step
	var visual_interval: float = 1.0 / maxf(
		visual_updates_per_second,
		1.0
	)
	if visual_accumulator >= visual_interval:
		visual_accumulator = fmod(visual_accumulator, visual_interval)
		_update_firewall_visuals(false)


func _sample_current_surface() -> bool:
	if source_actor == null or not is_instance_valid(source_actor):
		return false
	var hit: Dictionary = _resolve_surface_hit()
	var laser_origin: Vector3 = _get_cast_origin()
	var target_position: Vector3 = hit.get(
		"ray_end",
		laser_origin + _get_fallback_aim_direction() * targeting_range
	) as Vector3
	var valid: bool = bool(hit.get("valid", false))
	if valid:
		target_position = hit.get("position", target_position) as Vector3
	_update_laser_visual(laser_origin, target_position, valid)
	if not valid:
		return false
	var normal: Vector3 = hit.get("normal", Vector3.UP) as Vector3
	var collider_value: Variant = hit.get("collider")
	var collider_id: int = 0
	var collider_name: String = "Surface"
	if collider_value is Node:
		var collider: Node = collider_value as Node
		collider_id = collider.get_instance_id()
		collider_name = str(collider.name)
	return _append_surface_sample(
		target_position,
		normal,
		collider_id,
		collider_name
	)


func _resolve_surface_hit() -> Dictionary:
	var ray_origin: Vector3 = _get_cast_origin()
	var ray_direction: Vector3 = _get_fallback_aim_direction()
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
		var screen_center: Vector2 = (
			viewport_rect.position + viewport_rect.size * 0.5
		)
		ray_origin = camera.project_ray_origin(screen_center)
		ray_direction = camera.project_ray_normal(screen_center)
	if ray_direction.length_squared() <= 0.0001:
		ray_direction = _get_fallback_aim_direction()
	ray_direction = ray_direction.normalized()
	var ray_end: Vector3 = ray_origin + ray_direction * targeting_range
	var result: Dictionary = {
		"valid": false,
		"ray_end": ray_end,
		"position": ray_end,
		"normal": Vector3.UP,
		"collider": null,
	}
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return result
	var query := PhysicsRayQueryParameters3D.create(
		ray_origin,
		ray_end,
		targeting_collision_mask
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = collision_exclusions
	var hit: Dictionary = world.direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return result
	var collider_value: Variant = hit.get("collider")
	if not collider_value is Node:
		return result
	var collider: Node = collider_value as Node
	if not _is_valid_surface_collider(collider):
		return result
	var position_value: Variant = hit.get("position")
	var normal_value: Variant = hit.get("normal")
	if not position_value is Vector3 or not normal_value is Vector3:
		return result
	var normal: Vector3 = normal_value as Vector3
	if normal.length_squared() <= 0.0001:
		return result
	result["valid"] = true
	result["position"] = position_value as Vector3
	result["normal"] = normal.normalized()
	result["collider"] = collider
	return result


func _is_valid_surface_collider(collider: Node) -> bool:
	if collider == null or source_actor == null:
		return false
	if collider == source_actor or source_actor.is_ancestor_of(collider):
		return false
	if collider.is_in_group("firewall_drawable_surface"):
		return true
	if collider is StaticBody3D or collider is GridMap or collider is CSGShape3D:
		return true
	if allow_animatable_surfaces and collider is AnimatableBody3D:
		return true
	if allow_grouped_dynamic_surfaces and collider.is_in_group(
		"firewall_dynamic_surface"
	):
		return true
	return false


func _append_surface_sample(
	position: Vector3,
	normal_value: Vector3,
	collider_id: int,
	collider_name: String
) -> bool:
	var normal: Vector3 = normal_value
	if normal.length_squared() <= 0.0001:
		return false
	normal = normal.normalized()
	if path_points.is_empty():
		_append_raw_point(position, normal, collider_id, collider_name)
		_rebuild_surface_line()
		return true

	var previous: Dictionary = path_points[path_points.size() - 1]
	var previous_position: Vector3 = previous.get(
		"position",
		position
	) as Vector3
	var previous_normal: Vector3 = previous.get(
		"normal",
		normal
	) as Vector3
	var distance: float = previous_position.distance_to(position)
	if distance < minimum_sample_spacing:
		return false
	if distance > maximum_surface_gap:
		rejected_surface_jump_count += 1
		return false
	var normal_dot: float = clampf(previous_normal.dot(normal), -1.0, 1.0)
	if normal_dot < opposite_surface_rejection_dot:
		rejected_surface_jump_count += 1
		return false

	var changed: bool = false
	if normal_dot >= corner_normal_dot_threshold:
		changed = _append_interpolated_to(
			position,
			normal,
			collider_id,
			collider_name
		)
	else:
		changed = _append_corner_bridge(
			position,
			normal,
			collider_id,
			collider_name
		)
		if not changed and int(previous.get("collider_id", -1)) == collider_id:
			changed = _append_interpolated_to(
				position,
				normal,
				collider_id,
				collider_name
			)

	if changed:
		_rebuild_surface_line()
	return changed


func _append_corner_bridge(
	next_position: Vector3,
	next_normal: Vector3,
	collider_id: int,
	collider_name: String
) -> bool:
	if path_points.is_empty():
		return false
	var previous: Dictionary = path_points[path_points.size() - 1]
	var previous_position: Vector3 = previous.get(
		"position",
		next_position
	) as Vector3
	var previous_normal: Vector3 = previous.get(
		"normal",
		next_normal
	) as Vector3
	var corner_from_previous: Vector3 = (
		previous_position
		- next_normal * next_normal.dot(previous_position - next_position)
	)
	var corner_from_next: Vector3 = (
		next_position
		- previous_normal * previous_normal.dot(next_position - previous_position)
	)
	var direct_distance: float = previous_position.distance_to(next_position)
	var bridge_total: float = (
		previous_position.distance_to(corner_from_previous)
		+ corner_from_previous.distance_to(corner_from_next)
		+ corner_from_next.distance_to(next_position)
	)
	var bridge_ceiling: float = maxf(
		maximum_surface_gap * 2.5,
		direct_distance * 3.0
	)
	if (
		bridge_total > bridge_ceiling
		or previous_position.distance_to(corner_from_previous)
		> maximum_surface_gap
		or corner_from_next.distance_to(next_position)
		> maximum_surface_gap
	):
		return false

	var changed: bool = false
	changed = _append_interpolated_to(
		corner_from_previous,
		previous_normal,
		int(previous.get("collider_id", collider_id)),
		str(previous.get("collider_name", collider_name))
	) or changed
	changed = _append_interpolated_to(
		corner_from_next,
		next_normal,
		collider_id,
		collider_name
	) or changed
	changed = _append_interpolated_to(
		next_position,
		next_normal,
		collider_id,
		collider_name
	) or changed
	if changed:
		surface_transition_count += 1
	return changed


func _append_interpolated_to(
	target_position: Vector3,
	target_normal: Vector3,
	collider_id: int,
	collider_name: String
) -> bool:
	if path_points.is_empty():
		return _append_raw_point(
			target_position,
			target_normal,
			collider_id,
			collider_name
		)
	var start: Dictionary = path_points[path_points.size() - 1]
	var start_position: Vector3 = start.get(
		"position",
		target_position
	) as Vector3
	var start_normal: Vector3 = start.get(
		"normal",
		target_normal
	) as Vector3
	var distance: float = start_position.distance_to(target_position)
	if distance <= 0.001:
		return false
	var step_count: int = maxi(
		1,
		int(ceil(distance / maxf(resample_spacing, 0.05)))
	)
	var changed: bool = false
	for step_index: int in range(1, step_count + 1):
		if path_points.size() >= maximum_path_points or path_limit_reached:
			break
		var ratio: float = float(step_index) / float(step_count)
		var interpolated_position: Vector3 = start_position.lerp(
			target_position,
			ratio
		)
		var interpolated_normal: Vector3 = start_normal.slerp(
			target_normal,
			ratio
		)
		if interpolated_normal.length_squared() <= 0.0001:
			interpolated_normal = target_normal
		changed = _append_raw_point(
			interpolated_position,
			interpolated_normal.normalized(),
			collider_id,
			collider_name
		) or changed
	return changed


func _append_raw_point(
	position: Vector3,
	normal: Vector3,
	collider_id: int,
	collider_name: String
) -> bool:
	if path_points.size() >= maximum_path_points:
		path_limit_reached = true
		return false
	var resolved_position: Vector3 = position
	if not path_points.is_empty():
		var previous_position: Vector3 = path_points[
			path_points.size() - 1
		].get("position", position) as Vector3
		var distance: float = previous_position.distance_to(position)
		if distance <= 0.001:
			return false
		var remaining: float = maximum_path_length - path_length
		if remaining <= 0.001:
			path_limit_reached = true
			return false
		if distance > remaining:
			resolved_position = (
				previous_position
				+ (position - previous_position).normalized() * remaining
			)
			distance = remaining
			path_limit_reached = true
		path_length += distance
	path_points.append({
		"position": resolved_position,
		"normal": normal.normalized(),
		"collider_id": collider_id,
		"collider_name": collider_name,
		"surface_kind": _classify_surface_normal(normal),
	})
	surface_point_added.emit(
		resolved_position,
		normal.normalized(),
		path_points.size()
	)
	return true


func _ensure_minimum_path() -> bool:
	if path_points.is_empty():
		return false
	if path_points.size() >= 2 and path_length >= minimum_ignition_length:
		return true
	var anchor: Dictionary = path_points[path_points.size() - 1]
	var anchor_position: Vector3 = anchor.get(
		"position",
		Vector3.ZERO
	) as Vector3
	var normal: Vector3 = anchor.get("normal", Vector3.UP) as Vector3
	var tangent: Vector3 = Vector3.RIGHT
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		tangent = camera.global_transform.basis.x
	tangent -= normal * tangent.dot(normal)
	if tangent.length_squared() <= 0.0001:
		tangent = normal.cross(Vector3.UP)
	if tangent.length_squared() <= 0.0001:
		tangent = normal.cross(Vector3.RIGHT)
	if tangent.length_squared() <= 0.0001:
		return false
	tangent = tangent.normalized()
	var extension: float = maxf(
		minimum_ignition_length - path_length,
		minimum_ignition_length
	)
	_append_raw_point(
		anchor_position + tangent * extension,
		normal,
		int(anchor.get("collider_id", 0)),
		str(anchor.get("collider_name", "Surface"))
	)
	_rebuild_surface_line()
	return path_points.size() >= 2 and path_length >= minimum_ignition_length * 0.95


func _build_visual_segments() -> void:
	visual_segments.clear()
	for point_index: int in range(path_points.size() - 1):
		var segment: Dictionary = _make_segment(
			path_points[point_index],
			path_points[point_index + 1]
		)
		if not segment.is_empty():
			segment["index"] = visual_segments.size()
			visual_segments.append(segment)


func _build_contact_segments() -> void:
	contact_segments.clear()
	for segment: Dictionary in visual_segments:
		if contact_segments.is_empty():
			contact_segments.append(segment.duplicate(true))
			continue
		var previous: Dictionary = contact_segments[
			contact_segments.size() - 1
		]
		var previous_tangent: Vector3 = previous.get(
			"tangent",
			Vector3.FORWARD
		) as Vector3
		var previous_normal: Vector3 = previous.get(
			"normal",
			Vector3.UP
		) as Vector3
		var next_tangent: Vector3 = segment.get(
			"tangent",
			Vector3.FORWARD
		) as Vector3
		var next_normal: Vector3 = segment.get(
			"normal",
			Vector3.UP
		) as Vector3
		var previous_end: Vector3 = previous.get(
			"end",
			Vector3.ZERO
		) as Vector3
		var next_start: Vector3 = segment.get(
			"start",
			Vector3.ZERO
		) as Vector3
		var can_merge: bool = (
			previous_tangent.dot(next_tangent) >= 0.975
			and previous_normal.dot(next_normal) >= 0.96
			and previous_end.distance_to(next_start) <= 0.12
		)
		if can_merge:
			var merged_start: Dictionary = {
				"position": previous.get("start", Vector3.ZERO),
				"normal": previous_normal,
			}
			var merged_end: Dictionary = {
				"position": segment.get("end", Vector3.ZERO),
				"normal": next_normal,
			}
			var merged: Dictionary = _make_segment(merged_start, merged_end)
			if not merged.is_empty():
				contact_segments[contact_segments.size() - 1] = merged
		else:
			contact_segments.append(segment.duplicate(true))


func _make_segment(
	start_point: Dictionary,
	end_point: Dictionary
) -> Dictionary:
	var start: Vector3 = start_point.get(
		"position",
		Vector3.ZERO
	) as Vector3
	var finish: Vector3 = end_point.get(
		"position",
		Vector3.ZERO
	) as Vector3
	var delta: Vector3 = finish - start
	var length: float = delta.length()
	if length <= 0.01:
		return {}
	var start_normal: Vector3 = start_point.get(
		"normal",
		Vector3.UP
	) as Vector3
	var end_normal: Vector3 = end_point.get(
		"normal",
		start_normal
	) as Vector3
	var normal: Vector3 = start_normal + end_normal
	if normal.length_squared() <= 0.0001:
		normal = start_normal
	if normal.length_squared() <= 0.0001:
		normal = Vector3.UP
	normal = normal.normalized()
	var tangent: Vector3 = delta - normal * delta.dot(normal)
	if tangent.length_squared() <= 0.0001:
		tangent = delta
	tangent = tangent.normalized()
	var binormal: Vector3 = normal.cross(tangent)
	if binormal.length_squared() <= 0.0001:
		binormal = tangent.cross(Vector3.UP)
	if binormal.length_squared() <= 0.0001:
		binormal = Vector3.RIGHT
	binormal = binormal.normalized()
	tangent = binormal.cross(normal).normalized()
	return {
		"start": start,
		"end": finish,
		"midpoint": (start + finish) * 0.5,
		"length": length,
		"tangent": tangent,
		"normal": normal,
		"binormal": binormal,
	}


func _rebuild_surface_line() -> void:
	var segments: Array[Dictionary] = []
	for point_index: int in range(path_points.size() - 1):
		var segment: Dictionary = _make_segment(
			path_points[point_index],
			path_points[point_index + 1]
		)
		if not segment.is_empty():
			segments.append(segment)
	var multimesh: MultiMesh = _ensure_multimesh(
		surface_line_visual,
		unit_box_mesh,
		segments.size()
	)
	for segment_index: int in range(segments.size()):
		var segment: Dictionary = segments[segment_index]
		var tangent: Vector3 = segment.get("tangent", Vector3.RIGHT) as Vector3
		var normal: Vector3 = segment.get("normal", Vector3.UP) as Vector3
		var binormal: Vector3 = segment.get("binormal", Vector3.FORWARD) as Vector3
		var length: float = float(segment.get("length", 0.1)) + segment_overlap
		var midpoint: Vector3 = segment.get("midpoint", Vector3.ZERO) as Vector3
		var basis := Basis(
			tangent * length,
			normal * surface_line_thickness,
			binormal * surface_line_width
		)
		multimesh.set_instance_transform(
			segment_index,
			Transform3D(
				basis,
				midpoint + normal * (surface_offset * 0.55)
			)
		)
		var ratio: float = (
			0.0 if segments.size() <= 1
			else float(segment_index) / float(segments.size() - 1)
		)
		multimesh.set_instance_color(
			segment_index,
			Color(1.0, lerpf(0.18, 0.62, ratio), 0.025, 0.9)
		)
	if endpoint_marker != null and not path_points.is_empty():
		var endpoint: Dictionary = path_points[path_points.size() - 1]
		var endpoint_position: Vector3 = endpoint.get(
			"position",
			Vector3.ZERO
		) as Vector3
		var endpoint_normal: Vector3 = endpoint.get(
			"normal",
			Vector3.UP
		) as Vector3
		endpoint_marker.global_position = (
			endpoint_position + endpoint_normal * surface_offset
		)


func _prepare_firewall_multimeshes() -> void:
	_ensure_multimesh(
		outer_flame_visual,
		unit_box_mesh,
		visual_segments.size()
	)
	_ensure_multimesh(
		inner_flame_visual,
		unit_box_mesh,
		visual_segments.size()
	)
	_ensure_multimesh(
		joint_flame_visual,
		joint_mesh,
		path_points.size()
	)
	_rebuild_surface_line()


func _update_firewall_visuals(force: bool) -> void:
	if visual_segments.is_empty():
		return
	var outer_multimesh: MultiMesh = outer_flame_visual.multimesh
	var inner_multimesh: MultiMesh = inner_flame_visual.multimesh
	var joint_multimesh: MultiMesh = joint_flame_visual.multimesh
	if outer_multimesh == null or inner_multimesh == null:
		return
	var alpha: float = clampf(current_fade_alpha, 0.0, 1.0)
	for segment_index: int in range(visual_segments.size()):
		var segment: Dictionary = visual_segments[segment_index]
		var tangent: Vector3 = segment.get("tangent", Vector3.RIGHT) as Vector3
		var normal: Vector3 = segment.get("normal", Vector3.UP) as Vector3
		var binormal: Vector3 = segment.get("binormal", Vector3.FORWARD) as Vector3
		var length: float = float(segment.get("length", 0.1)) + segment_overlap
		var midpoint: Vector3 = segment.get("midpoint", Vector3.ZERO) as Vector3
		var flicker: float = 0.92 + 0.08 * sin(
			wall_elapsed * 19.0 + float(segment_index) * 1.73
		)
		var outer_height: float = maxf(
			wall_height * current_height_ratio * flicker,
			0.01
		)
		var inner_height: float = maxf(
			outer_height * (0.64 + 0.05 * sin(
				wall_elapsed * 27.0 + float(segment_index) * 0.91
			)),
			0.01
		)
		outer_multimesh.set_instance_transform(
			segment_index,
			_make_wall_transform(
				midpoint,
				tangent,
				normal,
				binormal,
				length,
				outer_height,
				wall_thickness
			)
		)
		outer_multimesh.set_instance_color(
			segment_index,
			Color(1.0, 0.12 + 0.11 * flicker, 0.015, 0.52 * alpha)
		)
		inner_multimesh.set_instance_transform(
			segment_index,
			_make_wall_transform(
				midpoint + normal * 0.015,
				tangent,
				normal,
				binormal,
				length * 0.94,
				inner_height,
				wall_thickness * 0.48
			)
		)
		inner_multimesh.set_instance_color(
			segment_index,
			Color(1.0, 0.62 + 0.18 * flicker, 0.05, 0.82 * alpha)
		)

	if joint_multimesh != null:
		for point_index: int in range(path_points.size()):
			var point: Dictionary = path_points[point_index]
			var position: Vector3 = point.get("position", Vector3.ZERO) as Vector3
			var normal: Vector3 = point.get("normal", Vector3.UP) as Vector3
			var tangent: Vector3 = _get_point_tangent(point_index, normal)
			var binormal: Vector3 = normal.cross(tangent).normalized()
			var height: float = maxf(
				wall_height
				* current_height_ratio
				* (0.72 + 0.08 * sin(
					wall_elapsed * 23.0 + float(point_index) * 1.37
				)),
				0.01
			)
			var joint_basis := Basis(
				tangent * joint_radius,
				normal * height,
				binormal * joint_radius
			)
			joint_multimesh.set_instance_transform(
				point_index,
				Transform3D(
					joint_basis,
					position
					+ normal * (height * 0.42 + surface_offset)
				)
			)
			joint_multimesh.set_instance_color(
				point_index,
				Color(1.0, 0.36, 0.025, 0.48 * alpha)
			)

	var line_multimesh: MultiMesh = surface_line_visual.multimesh
	if line_multimesh != null:
		for segment_index: int in range(line_multimesh.instance_count):
			line_multimesh.set_instance_color(
				segment_index,
				Color(0.72, 0.09, 0.01, 0.74 * alpha)
			)

	if fire_light != null:
		var midpoint_data: Dictionary = path_points[
			path_points.size() / 2
		]
		var light_position: Vector3 = midpoint_data.get(
			"position",
			Vector3.ZERO
		) as Vector3
		var light_normal: Vector3 = midpoint_data.get(
			"normal",
			Vector3.UP
		) as Vector3
		fire_light.global_position = (
			light_position + light_normal * minf(wall_height * 0.55, 1.2)
		)
		fire_light.light_energy = (
			(2.1 + 0.35 * sin(wall_elapsed * 17.0))
			* current_height_ratio
			* alpha
		)
		fire_light.omni_range = clampf(
			4.0 + path_length * 0.18,
			4.0,
			8.5
		)
	if force:
		visual_accumulator = 0.0


func _make_wall_transform(
	midpoint: Vector3,
	tangent: Vector3,
	normal: Vector3,
	binormal: Vector3,
	length: float,
	height: float,
	thickness: float
) -> Transform3D:
	var basis := Basis(
		tangent * maxf(length, 0.01),
		normal * maxf(height, 0.01),
		binormal * maxf(thickness, 0.01)
	)
	return Transform3D(
		basis,
		midpoint + normal * (height * 0.5 + surface_offset)
	)


func _scan_firewall_contacts() -> void:
	if source_actor == null or contact_segments.is_empty():
		return
	var world: World3D = source_actor.get_world_3d()
	if world == null:
		return
	var segment_total: int = mini(
		contact_segments.size(),
		maximum_contact_segments
	)
	var target_ids: Dictionary = {}
	for segment_index: int in range(segment_total):
		var source_index: int = (
			segment_index
			if contact_segments.size() <= maximum_contact_segments
			else int(floor(
				float(segment_index)
				* float(contact_segments.size())
				/ float(maximum_contact_segments)
			))
		)
		var segment: Dictionary = contact_segments[
			clampi(source_index, 0, contact_segments.size() - 1)
		]
		var length: float = float(segment.get("length", 0.1)) + segment_overlap
		var tangent: Vector3 = segment.get("tangent", Vector3.RIGHT) as Vector3
		var normal: Vector3 = segment.get("normal", Vector3.UP) as Vector3
		var binormal: Vector3 = segment.get("binormal", Vector3.FORWARD) as Vector3
		var midpoint: Vector3 = segment.get("midpoint", Vector3.ZERO) as Vector3
		var height: float = maxf(wall_height * current_height_ratio, 0.2)
		var shape := BoxShape3D.new()
		shape.size = Vector3(
			maxf(length, 0.1),
			height,
			maxf(contact_depth, wall_thickness)
		)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = Transform3D(
			Basis(tangent, normal, binormal),
			midpoint + normal * (height * 0.5 + surface_offset)
		)
		query.collision_mask = contact_collision_mask
		query.collide_with_bodies = true
		query.collide_with_areas = true
		query.exclude = collision_exclusions
		total_contact_queries += 1
		for result: Dictionary in world.direct_space_state.intersect_shape(
			query,
			32
		):
			var collider_value: Variant = result.get("collider")
			if not collider_value is Node:
				continue
			var target: Node = _resolve_effect_target(
				collider_value as Node
			)
			if target == null:
				continue
			var target_id: int = target.get_instance_id()
			if target_ids.has(target_id):
				continue
			target_ids[target_id] = true
			var last_hit: float = float(
				target_last_hit_time.get(target_id, -1000.0)
			)
			if wall_elapsed - last_hit < repeat_hit_seconds:
				continue
			target_last_hit_time[target_id] = wall_elapsed
			_apply_firewall_to_target(target)


func _resolve_effect_target(start_node: Node) -> Node:
	var current: Node = start_node
	while current != null:
		if current == source_actor or source_actor.is_ancestor_of(current):
			return null
		if _is_effect_target(current):
			return current
		if current == get_tree().current_scene:
			break
		current = current.get_parent()
	return null


func _is_effect_target(node: Node) -> bool:
	if node == null or node is StaticBody3D or node is AnimatableBody3D:
		return false
	return (
		node.get_node_or_null("ThermalState") != null
		or node.get_node_or_null("CombustionState") != null
		or node.get_node_or_null("PayloadReceiver") != null
		or node.get_node_or_null("HitReceiver") != null
		or node.has_method("receive_damage_payload")
		or node.has_method("receive_magic_hit")
	)


func _apply_firewall_to_target(target: Node) -> void:
	var payload: DamagePayload = _get_payload().duplicate(true) as DamagePayload
	payload.source_name = "Firewall"
	payload.hit_type = "lingering_wall"
	for tag: String in [
		"firewall",
		"surface_path",
		"lingering",
		"wall",
	]:
		if not payload.tags.has(tag):
			payload.tags.append(tag)
	var result: Dictionary = {}
	var payload_receiver: Node = target.get_node_or_null("PayloadReceiver")
	if payload_receiver != null and payload_receiver.has_method("receive_payload"):
		var result_value: Variant = payload_receiver.call(
			"receive_payload",
			payload
		)
		if result_value is Dictionary:
			result = (result_value as Dictionary).duplicate(true)
	elif target.has_method("receive_damage_payload"):
		var direct_result: Variant = target.call(
			"receive_damage_payload",
			payload
		)
		if direct_result is Dictionary:
			result = (direct_result as Dictionary).duplicate(true)
	elif target.get_node_or_null("HitReceiver") != null:
		var hit_receiver: Node = target.get_node("HitReceiver")
		if hit_receiver.has_method("receive_payload"):
			var hit_result: Variant = hit_receiver.call(
				"receive_payload",
				payload
			)
			if hit_result is Dictionary:
				result = (hit_result as Dictionary).duplicate(true)
	elif target.has_method("receive_magic_hit"):
		target.call("receive_magic_hit", payload.amount)

	var thermal_state: ThermalState = target.get_node_or_null(
		"ThermalState"
	) as ThermalState
	if thermal_state != null and heat_energy_j_per_second > 0.0:
		thermal_state.apply_energy_j(
			heat_energy_j_per_second * maxf(contact_tick_seconds, 0.05),
			"Firewall"
		)
	total_targets_hit += 1
	firewall_target_hit.emit(target, result)


func _get_payload() -> DamagePayload:
	if runtime_payload != null:
		return runtime_payload
	var payload := DamagePayload.new()
	payload.amount = 2
	payload.stance_damage = 1
	payload.element = "fire"
	payload.source_name = "Firewall"
	payload.hit_type = "lingering_wall"
	payload.status_effect = "burning"
	payload.status_duration = 1.4
	payload.status_strength = 0.9
	payload.tags = ["fire", "magic", "field", "hazard", "firewall"]
	return payload


func _build_visuals() -> void:
	unit_box_mesh = BoxMesh.new()
	unit_box_mesh.size = Vector3.ONE
	joint_mesh = SphereMesh.new()
	joint_mesh.radius = 1.0
	joint_mesh.height = 2.0
	joint_mesh.radial_segments = 10
	joint_mesh.rings = 6

	laser_material = _make_emissive_material(
		Color(1.0, 0.18, 0.02, 0.9),
		Color(1.0, 0.08, 0.01),
		4.0,
		false
	)
	surface_line_material = _make_emissive_material(
		Color(1.0, 0.16, 0.02, 0.88),
		Color(1.0, 0.08, 0.01),
		3.2,
		true
	)
	outer_flame_material = _make_emissive_material(
		Color(1.0, 0.1, 0.01, 0.54),
		Color(1.0, 0.08, 0.005),
		3.8,
		true
	)
	inner_flame_material = _make_emissive_material(
		Color(1.0, 0.66, 0.04, 0.84),
		Color(1.0, 0.42, 0.02),
		5.0,
		true
	)
	joint_flame_material = _make_emissive_material(
		Color(1.0, 0.28, 0.02, 0.54),
		Color(1.0, 0.16, 0.01),
		4.2,
		true
	)

	laser_visual = MeshInstance3D.new()
	laser_visual.name = "FirewallDrawingLaser"
	laser_visual.mesh = unit_box_mesh
	laser_visual.material_override = laser_material
	laser_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(laser_visual)

	endpoint_marker = MeshInstance3D.new()
	endpoint_marker.name = "FirewallSurfaceCursor"
	var marker_mesh := SphereMesh.new()
	marker_mesh.radius = 0.09
	marker_mesh.height = 0.18
	marker_mesh.radial_segments = 10
	marker_mesh.rings = 6
	endpoint_marker.mesh = marker_mesh
	endpoint_marker.material_override = laser_material
	endpoint_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(endpoint_marker)

	surface_line_visual = _make_multimesh_visual(
		"FirewallSurfaceLine",
		surface_line_material
	)
	outer_flame_visual = _make_multimesh_visual(
		"FirewallOuterFlames",
		outer_flame_material
	)
	inner_flame_visual = _make_multimesh_visual(
		"FirewallInnerFlames",
		inner_flame_material
	)
	joint_flame_visual = _make_multimesh_visual(
		"FirewallCornerPlumes",
		joint_flame_material
	)

	fire_light = OmniLight3D.new()
	fire_light.name = "FirewallLight"
	fire_light.light_color = Color(1.0, 0.25, 0.035)
	fire_light.light_energy = 0.0
	fire_light.omni_range = 6.0
	fire_light.shadow_enabled = false
	add_child(fire_light)


func _make_multimesh_visual(
	node_name: String,
	material: Material
) -> MultiMeshInstance3D:
	var visual := MultiMeshInstance3D.new()
	visual.name = node_name
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	return visual


func _make_emissive_material(
	albedo: Color,
	emission_color: Color,
	energy: float,
	use_vertex_color: bool
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = albedo
	material.emission_enabled = true
	material.emission = emission_color
	material.emission_energy_multiplier = energy
	material.vertex_color_use_as_albedo = use_vertex_color
	return material


func _ensure_multimesh(
	visual: MultiMeshInstance3D,
	mesh: Mesh,
	instance_count: int
) -> MultiMesh:
	var multimesh: MultiMesh = visual.multimesh
	if multimesh == null:
		multimesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = mesh
		visual.multimesh = multimesh
	elif multimesh.mesh != mesh:
		multimesh.mesh = mesh
	multimesh.instance_count = maxi(instance_count, 0)
	return multimesh


func _update_laser_visual(
	start: Vector3,
	finish: Vector3,
	valid: bool
) -> void:
	if laser_visual == null:
		return
	_set_box_between(
		laser_visual,
		start,
		finish,
		laser_thickness
	)
	laser_material.albedo_color = (
		Color(1.0, 0.2, 0.025, 0.9)
		if valid
		else Color(0.48, 0.08, 0.04, 0.46)
	)
	laser_material.emission = (
		Color(1.0, 0.08, 0.01)
		if valid
		else Color(0.25, 0.02, 0.01)
	)
	endpoint_marker.visible = valid
	if valid:
		endpoint_marker.global_position = finish


func _set_box_between(
	mesh_instance: MeshInstance3D,
	start: Vector3,
	finish: Vector3,
	thickness: float
) -> void:
	var delta: Vector3 = finish - start
	var length: float = delta.length()
	if length <= 0.001:
		mesh_instance.visible = false
		return
	mesh_instance.visible = true
	var forward: Vector3 = delta / length
	var reference: Vector3 = (
		Vector3.UP
		if absf(forward.dot(Vector3.UP)) < 0.94
		else Vector3.RIGHT
	)
	var right: Vector3 = reference.cross(forward).normalized()
	var up: Vector3 = forward.cross(right).normalized()
	mesh_instance.global_transform = Transform3D(
		Basis(
			right * thickness,
			up * thickness,
			forward * length
		),
		(start + finish) * 0.5
	)


func _set_drawing_visuals_visible(value: bool) -> void:
	if laser_visual != null:
		laser_visual.visible = value
	if endpoint_marker != null:
		endpoint_marker.visible = false
	if surface_line_visual != null:
		surface_line_visual.visible = value or phase in [
			FirewallPhase.ERUPTING,
			FirewallPhase.LINGERING,
			FirewallPhase.FADING,
		]


func _set_firewall_visuals_visible(value: bool) -> void:
	if outer_flame_visual != null:
		outer_flame_visual.visible = value
	if inner_flame_visual != null:
		inner_flame_visual.visible = value
	if joint_flame_visual != null:
		joint_flame_visual.visible = value
	if surface_line_visual != null:
		surface_line_visual.visible = value or phase == FirewallPhase.DRAWING
	if fire_light != null and not value:
		fire_light.light_energy = 0.0


func _get_cast_origin() -> Vector3:
	if (
		ability_caster != null
		and ability_caster.has_method("get_player_cast_origin")
	):
		var origin_value: Variant = ability_caster.call(
			"get_player_cast_origin",
			source_actor
		)
		if origin_value is Vector3:
			return origin_value as Vector3
	return source_actor.global_position + Vector3.UP * 1.0


func _get_fallback_aim_direction() -> Vector3:
	if (
		ability_caster != null
		and ability_caster.has_method("get_cast_direction")
	):
		var direction_value: Variant = ability_caster.call(
			"get_cast_direction",
			source_actor,
			_get_cast_origin()
		)
		if direction_value is Vector3:
			var direction: Vector3 = direction_value as Vector3
			if direction.length_squared() > 0.0001:
				return direction.normalized()
	var fallback: Vector3 = -source_actor.global_transform.basis.z
	return fallback.normalized() if fallback.length_squared() > 0.0001 else Vector3.FORWARD


func _is_cast_held() -> bool:
	if test_cast_held_override_enabled:
		return test_cast_held
	return Input.is_action_pressed(channel_action)


func _drawing_interrupted() -> bool:
	if source_actor == null or not is_instance_valid(source_actor):
		return true
	if action_state == null:
		return false
	return (
		action_state.is_defeated
		or action_state.is_staggered
		or action_state.is_dodging
		or action_state.is_interacting
		or action_state.is_manipulating
		or action_state.is_guarding
		or action_state.is_using_item
		or not action_state.is_cast_channel_active()
	)


func _is_firewall_still_equipped() -> bool:
	if ability_caster == null or not ability_caster.has_method(
		"get_current_ability"
	):
		return true
	var current_value: Variant = ability_caster.call("get_current_ability")
	return (
		current_value is AbilityDefinition
		and (current_value as AbilityDefinition).get_spell_id() == "firewall"
	)


func _release_cast_channel() -> void:
	if not owns_cast_channel:
		return
	owns_cast_channel = false
	if (
		action_state != null
		and action_state.is_cast_channel_active()
	):
		action_state.end_cast()


func _cancel_previous_firewalls() -> void:
	for existing: Node in get_tree().get_nodes_in_group("firewall_effects"):
		if existing == self:
			continue
		if (
			existing.has_method("belongs_to_source")
			and bool(existing.call("belongs_to_source", source_actor))
			and existing.has_method("finish_firewall")
		):
			existing.call("finish_firewall", "replaced")


func _collect_collision_rids(
	node: Node,
	target: Array[RID]
) -> void:
	if node is CollisionObject3D:
		var rid: RID = (node as CollisionObject3D).get_rid()
		if rid.is_valid() and not target.has(rid):
			target.append(rid)
	for child: Node in node.get_children():
		_collect_collision_rids(child, target)


func _get_point_tangent(point_index: int, normal: Vector3) -> Vector3:
	var tangent: Vector3 = Vector3.RIGHT
	if path_points.size() >= 2:
		var previous_index: int = maxi(point_index - 1, 0)
		var next_index: int = mini(point_index + 1, path_points.size() - 1)
		var previous_position: Vector3 = path_points[previous_index].get(
			"position",
			Vector3.ZERO
		) as Vector3
		var next_position: Vector3 = path_points[next_index].get(
			"position",
			Vector3.RIGHT
		) as Vector3
		tangent = next_position - previous_position
	tangent -= normal * tangent.dot(normal)
	if tangent.length_squared() <= 0.0001:
		tangent = normal.cross(Vector3.UP)
	if tangent.length_squared() <= 0.0001:
		tangent = normal.cross(Vector3.RIGHT)
	return tangent.normalized() if tangent.length_squared() > 0.0001 else Vector3.RIGHT


func _classify_surface_normal(normal: Vector3) -> String:
	var normalized: Vector3 = normal.normalized()
	if normalized.y >= 0.68:
		return "floor"
	if normalized.y <= -0.68:
		return "ceiling"
	return "wall"


func _write_firewall_metadata(reason: String) -> void:
	if source_actor == null or not is_instance_valid(source_actor):
		return
	var serial: int = int(source_actor.get_meta("firewall_serial", 0)) + 1
	var point_positions: Array[Vector3] = []
	var point_normals: Array[Vector3] = []
	var surface_sequence: Array[String] = []
	for point: Dictionary in path_points:
		point_positions.append(point.get("position", Vector3.ZERO) as Vector3)
		point_normals.append(point.get("normal", Vector3.UP) as Vector3)
		var surface_kind: String = str(point.get("surface_kind", "wall"))
		if surface_sequence.is_empty() or surface_sequence[
			surface_sequence.size() - 1
		] != surface_kind:
			surface_sequence.append(surface_kind)
	source_actor.set_meta("firewall_serial", serial)
	source_actor.set_meta("firewall_path_points", point_positions)
	source_actor.set_meta("firewall_path_normals", point_normals)
	source_actor.set_meta("firewall_surface_sequence", surface_sequence)
	source_actor.set_meta("firewall_path_length", path_length)
	source_actor.set_meta(
		"firewall_surface_transitions",
		surface_transition_count
	)
	source_actor.set_meta("firewall_draw_reason", reason)
	source_actor.set_meta("firewall_visual_segments", visual_segments.size())
	source_actor.set_meta("firewall_contact_segments", contact_segments.size())


func _show_message(text: String) -> void:
	var ui: Node = get_tree().get_first_node_in_group("game_ui")
	if ui != null and ui.has_method("show_message"):
		ui.call("show_message", text)
	else:
		print(text)


func get_debug_data() -> Dictionary:
	var surface_sequence: Array[String] = []
	for point: Dictionary in path_points:
		var surface_kind: String = str(point.get("surface_kind", "wall"))
		if surface_sequence.is_empty() or surface_sequence[
			surface_sequence.size() - 1
		] != surface_kind:
			surface_sequence.append(surface_kind)
	return {
		"firewall_cast": true,
		"phase": FirewallPhase.keys()[phase].to_lower(),
		"drawing": phase == FirewallPhase.DRAWING,
		"wall_active": phase in [
			FirewallPhase.ERUPTING,
			FirewallPhase.LINGERING,
			FirewallPhase.FADING,
		],
		"owns_cast_channel": owns_cast_channel,
		"draw_elapsed": snappedf(draw_elapsed, 0.01),
		"maximum_draw_seconds": maximum_draw_seconds,
		"point_count": path_points.size(),
		"visual_segment_count": visual_segments.size(),
		"contact_segment_count": contact_segments.size(),
		"path_length": snappedf(path_length, 0.01),
		"surface_transitions": surface_transition_count,
		"surface_sequence": surface_sequence,
		"rejected_surface_jumps": rejected_surface_jump_count,
		"path_limit_reached": path_limit_reached,
		"height_ratio": snappedf(current_height_ratio, 0.01),
		"fade_alpha": snappedf(current_fade_alpha, 0.01),
		"contact_queries": total_contact_queries,
		"targets_hit": total_targets_hit,
		"visual_multimeshes": 4,
		"per_segment_nodes": 0,
		"persistent": is_in_group("persistent_spell_effects"),
		"last_end_reason": last_end_reason,
	}
