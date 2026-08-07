extends "res://scripts/actions/firewall_cast.gd"
class_name FirewallCastSurfaceSafe

# Firewall keeps the generic surface-path implementation in its base action.
# This authority layer owns the player-facing camera brush, adaptive ray
# subdivision, Focus interruption, and the integer midpoint required by the
# shared fire light.

@export_group("Camera Brush")
@export_range(-89.0, -30.0, 1.0) var brush_min_pitch_degrees: float = -84.0
@export_range(30.0, 89.0, 1.0) var brush_max_pitch_degrees: float = 78.0
@export_range(0.1, 1.0, 0.05) var brush_mouse_sensitivity_scale: float = 0.5
@export_range(0.1, 1.0, 0.05) var brush_controller_sensitivity_scale: float = 0.58

@export_group("Adaptive Stroke")
@export_range(0.25, 8.0, 0.25) var maximum_ray_step_degrees: float = 1.5
@export_range(0.05, 4.0, 0.05) var maximum_ray_origin_step: float = 0.45
@export_range(1, 20, 1) var maximum_ray_subsamples: int = 12

var spell_aim_pointer: PlayerSpellAimPointer
var camera_brush_started: bool = false
var has_previous_brush_ray: bool = false
var previous_brush_ray_origin: Vector3 = Vector3.ZERO
var previous_brush_ray_direction: Vector3 = Vector3.FORWARD
var brush_sample_batch_active: bool = false
var brush_rebuild_pending: bool = false
var brush_subsample_query_count: int = 0
var brush_subdivision_pass_count: int = 0
var brush_recovered_sample_count: int = 0
var brush_recovered_stroke_count: int = 0

var test_brush_ray_override_enabled: bool = false
var test_brush_ray_origin: Vector3 = Vector3.ZERO
var test_brush_ray_direction: Vector3 = Vector3.FORWARD


func execute(player: Node3D, cast_direction: Vector3) -> void:
	_reset_brush_sampling()
	_begin_spell_pointer(player)
	super.execute(player, cast_direction)


func _exit_tree() -> void:
	_end_spell_pointer("scene_exit")
	super._exit_tree()


func finish_drawing(
	reason: String = "released",
	ignite: bool = true
) -> void:
	# Keep the brush alive through the base action's final surface sample, then
	# return the camera to its ordinary pitch as soon as the line erupts.
	super.finish_drawing(reason, ignite)
	_end_spell_pointer(reason)


func cancel_drawing(reason: String = "cancelled") -> void:
	super.cancel_drawing(reason)
	_end_spell_pointer(reason)


func finish_firewall(reason: String = "complete") -> void:
	super.finish_firewall(reason)
	_end_spell_pointer(reason)


func _drawing_interrupted() -> bool:
	if super._drawing_interrupted():
		return true
	if action_state != null and action_state.is_focus_menu_open:
		return true
	if (
		spell_aim_pointer != null
		and spell_aim_pointer.is_aim_active()
		and not spell_aim_pointer.is_owned_by(self)
	):
		return true
	if (
		camera_brush_started
		and source_actor != null
		and source_actor.has_method("is_spell_camera_brush_owned_by")
		and not bool(source_actor.call(
			"is_spell_camera_brush_owned_by",
			self
		))
	):
		return true
	return false


func _sample_current_surface() -> bool:
	if source_actor == null or not is_instance_valid(source_actor):
		return false

	var current_ray: Dictionary = _get_brush_ray()
	var current_origin: Vector3 = current_ray.get(
		"origin",
		_get_cast_origin()
	) as Vector3
	var current_direction: Vector3 = current_ray.get(
		"direction",
		_get_fallback_aim_direction()
	) as Vector3
	if current_direction.length_squared() <= 0.0001:
		current_direction = _get_fallback_aim_direction()
	current_direction = current_direction.normalized()

	var subdivision_count: int = _get_brush_subdivision_count(
		current_origin,
		current_direction
	)
	var changed: bool = false
	var final_hit: Dictionary = {}
	var points_before_batch: int = path_points.size()
	brush_sample_batch_active = true
	brush_rebuild_pending = false

	for subdivision_index: int in range(1, subdivision_count + 1):
		var ratio: float = (
			float(subdivision_index) / float(subdivision_count)
		)
		var ray_origin: Vector3 = current_origin
		var ray_direction: Vector3 = current_direction
		if has_previous_brush_ray:
			ray_origin = previous_brush_ray_origin.lerp(
				current_origin,
				ratio
			)
			ray_direction = previous_brush_ray_direction.slerp(
				current_direction,
				ratio
			)
			if ray_direction.length_squared() <= 0.0001:
				ray_direction = previous_brush_ray_direction.lerp(
					current_direction,
					ratio
				)
		if ray_direction.length_squared() <= 0.0001:
			ray_direction = current_direction
		ray_direction = ray_direction.normalized()

		var update_pointer_status: bool = (
			subdivision_index == subdivision_count
		)
		var hit: Dictionary = _resolve_surface_hit_from_ray(
			ray_origin,
			ray_direction,
			update_pointer_status
		)
		brush_subsample_query_count += 1
		if update_pointer_status:
			final_hit = hit
		if not bool(hit.get("valid", false)):
			continue
		var point_count_before: int = path_points.size()
		if _append_surface_hit(hit):
			changed = true
			if subdivision_index < subdivision_count:
				brush_recovered_sample_count += maxi(
					path_points.size() - point_count_before,
					1
				)

	brush_sample_batch_active = false
	if brush_rebuild_pending:
		_rebuild_surface_line()
		brush_rebuild_pending = false
	if subdivision_count > 1:
		brush_subdivision_pass_count += 1
		if path_points.size() > points_before_batch:
			brush_recovered_stroke_count += 1

	var laser_origin: Vector3 = _get_cast_origin()
	var target_position: Vector3 = final_hit.get(
		"ray_end",
		laser_origin + current_direction * targeting_range
	) as Vector3
	var final_valid: bool = bool(final_hit.get("valid", false))
	if final_valid:
		target_position = final_hit.get(
			"position",
			target_position
		) as Vector3
	_update_laser_visual(laser_origin, target_position, final_valid)

	has_previous_brush_ray = true
	previous_brush_ray_origin = current_origin
	previous_brush_ray_direction = current_direction
	return changed


func _resolve_surface_hit() -> Dictionary:
	var ray: Dictionary = _get_brush_ray()
	var ray_origin: Vector3 = ray.get(
		"origin",
		_get_cast_origin()
	) as Vector3
	var ray_direction: Vector3 = ray.get(
		"direction",
		_get_fallback_aim_direction()
	) as Vector3
	return _resolve_surface_hit_from_ray(
		ray_origin,
		ray_direction,
		true
	)


func _resolve_surface_hit_from_ray(
	ray_origin: Vector3,
	ray_direction_value: Vector3,
	update_pointer_status: bool
) -> Dictionary:
	var ray_direction: Vector3 = ray_direction_value
	if ray_direction.length_squared() <= 0.0001:
		ray_direction = _get_fallback_aim_direction()
	ray_direction = ray_direction.normalized()
	var ray_end: Vector3 = ray_origin + ray_direction * targeting_range
	var result: Dictionary = {
		"valid": false,
		"ray_origin": ray_origin,
		"ray_direction": ray_direction,
		"ray_end": ray_end,
		"position": ray_end,
		"normal": Vector3.UP,
		"collider": null,
	}
	var world: World3D = source_actor.get_world_3d() if source_actor != null else null
	if world == null:
		_set_pointer_status(
			false,
			"FIREWALL • NO WORLD SURFACE",
			update_pointer_status
		)
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
		_set_pointer_status(
			false,
			"FIREWALL • NO DRAWABLE SURFACE",
			update_pointer_status
		)
		return result

	var collider_value: Variant = hit.get("collider")
	if not collider_value is Node:
		_set_pointer_status(
			false,
			"FIREWALL • INVALID SURFACE",
			update_pointer_status
		)
		return result
	var collider: Node = collider_value as Node
	if not _is_valid_surface_collider(collider):
		_set_pointer_status(
			false,
			"FIREWALL • SURFACE REJECTED",
			update_pointer_status
		)
		return result

	var position_value: Variant = hit.get("position")
	var normal_value: Variant = hit.get("normal")
	if not position_value is Vector3 or not normal_value is Vector3:
		_set_pointer_status(
			false,
			"FIREWALL • INVALID CONTACT",
			update_pointer_status
		)
		return result
	var normal: Vector3 = normal_value as Vector3
	if normal.length_squared() <= 0.0001:
		_set_pointer_status(
			false,
			"FIREWALL • INVALID NORMAL",
			update_pointer_status
		)
		return result
	normal = normal.normalized()
	result["valid"] = true
	result["position"] = position_value as Vector3
	result["normal"] = normal
	result["collider"] = collider
	_set_pointer_status(
		true,
		"FIREWALL BRUSH • "
		+ _classify_surface_normal(normal).to_upper(),
		update_pointer_status
	)
	return result


func _append_surface_hit(hit: Dictionary) -> bool:
	var collider_value: Variant = hit.get("collider")
	var collider_id: int = 0
	var collider_name: String = "Surface"
	if collider_value is Node:
		var collider: Node = collider_value as Node
		collider_id = collider.get_instance_id()
		collider_name = str(collider.name)
	return _append_surface_sample(
		hit.get("position", Vector3.ZERO) as Vector3,
		hit.get("normal", Vector3.UP) as Vector3,
		collider_id,
		collider_name
	)


# This mirrors the base path rule but allows an adaptive ray bundle to defer the
# expensive MultiMesh rebuild until all intermediate ray hits have been added.
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
		var first_changed: bool = _append_raw_point(
			position,
			normal,
			collider_id,
			collider_name
		)
		if first_changed:
			_request_surface_line_rebuild()
		return first_changed

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
		_request_surface_line_rebuild()
	return changed


func _request_surface_line_rebuild() -> void:
	if brush_sample_batch_active:
		brush_rebuild_pending = true
		return
	_rebuild_surface_line()


func _get_brush_subdivision_count(
	current_origin: Vector3,
	current_direction: Vector3
) -> int:
	if not has_previous_brush_ray:
		return 1
	var angular_step: float = deg_to_rad(maxf(
		maximum_ray_step_degrees,
		0.05
	))
	var angular_steps: int = maxi(
		1,
		int(ceil(
			previous_brush_ray_direction.angle_to(current_direction)
			/ angular_step
		))
	)
	var origin_steps: int = maxi(
		1,
		int(ceil(
			previous_brush_ray_origin.distance_to(current_origin)
			/ maxf(maximum_ray_origin_step, 0.01)
		))
	)
	return clampi(
		maxi(angular_steps, origin_steps),
		1,
		maxi(maximum_ray_subsamples, 1)
	)


func _get_brush_ray() -> Dictionary:
	if test_brush_ray_override_enabled:
		var test_direction: Vector3 = test_brush_ray_direction
		if test_direction.length_squared() <= 0.0001:
			test_direction = Vector3.FORWARD
		test_direction = test_direction.normalized()
		return {
			"valid": true,
			"origin": test_brush_ray_origin,
			"direction": test_direction,
			"end": (
				test_brush_ray_origin
				+ test_direction * targeting_range
			),
		}

	if spell_aim_pointer != null and spell_aim_pointer.is_owned_by(self):
		return spell_aim_pointer.get_world_ray(targeting_range)

	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera != null:
		var viewport_rect: Rect2 = camera.get_viewport().get_visible_rect()
		var screen_center: Vector2 = (
			viewport_rect.position + viewport_rect.size * 0.5
		)
		var ray_origin: Vector3 = camera.project_ray_origin(screen_center)
		var ray_direction: Vector3 = camera.project_ray_normal(screen_center)
		if ray_direction.length_squared() <= 0.0001:
			ray_direction = -camera.global_transform.basis.z
		if ray_direction.length_squared() > 0.0001:
			ray_direction = ray_direction.normalized()
			return {
				"valid": true,
				"origin": ray_origin,
				"direction": ray_direction,
				"end": ray_origin + ray_direction * targeting_range,
			}

	var fallback_origin: Vector3 = _get_cast_origin()
	var fallback_direction: Vector3 = _get_fallback_aim_direction()
	return {
		"valid": false,
		"origin": fallback_origin,
		"direction": fallback_direction,
		"end": fallback_origin + fallback_direction * targeting_range,
	}


func _set_pointer_status(
	valid: bool,
	text: String,
	should_update: bool
) -> void:
	if (
		should_update
		and spell_aim_pointer != null
		and spell_aim_pointer.is_owned_by(self)
	):
		spell_aim_pointer.set_target_state(valid, text)


func _begin_spell_pointer(player: Node3D) -> void:
	if player == null:
		return
	spell_aim_pointer = player.get_node_or_null(
		"SpellAimPointer"
	) as PlayerSpellAimPointer

	camera_brush_started = false
	if player.has_method("begin_spell_camera_brush"):
		camera_brush_started = bool(player.call(
			"begin_spell_camera_brush",
			self,
			{
				"min_pitch_degrees": brush_min_pitch_degrees,
				"max_pitch_degrees": brush_max_pitch_degrees,
				"mouse_sensitivity_scale": brush_mouse_sensitivity_scale,
				"controller_sensitivity_scale": brush_controller_sensitivity_scale,
			}
		))

	if spell_aim_pointer == null:
		return
	spell_aim_pointer.begin_aim(self, {
		"mode_id": (
			"firewall_camera_brush"
			if camera_brush_started
			else "firewall_surface_pointer"
		),
		"capture_look": not camera_brush_started,
		"initial_normalized_position": (
			Vector2(0.5, 0.5)
			if camera_brush_started
			else Vector2(0.5, 0.64)
		),
		"horizontal_overflow_screens": (
			0.0 if camera_brush_started else 0.65
		),
		"vertical_overflow_screens": (
			0.0 if camera_brush_started else 1.25
		),
		"color": Color(1.0, 0.34, 0.08, 1.0),
		"status_text": (
			"FIREWALL BRUSH • LOOK TO DRAW"
			if camera_brush_started
			else "FIREWALL • FIND A DRAWABLE SURFACE"
		),
		"target_valid": false,
	})


func _end_spell_pointer(reason: String) -> void:
	if spell_aim_pointer != null and spell_aim_pointer.is_owned_by(self):
		spell_aim_pointer.end_aim(self, reason)
	if (
		camera_brush_started
		and source_actor != null
		and is_instance_valid(source_actor)
		and source_actor.has_method("end_spell_camera_brush")
	):
		source_actor.call(
			"end_spell_camera_brush",
			self,
			reason,
			false
		)
	camera_brush_started = false


func _reset_brush_sampling() -> void:
	has_previous_brush_ray = false
	previous_brush_ray_origin = Vector3.ZERO
	previous_brush_ray_direction = Vector3.FORWARD
	brush_sample_batch_active = false
	brush_rebuild_pending = false
	brush_subsample_query_count = 0
	brush_subdivision_pass_count = 0
	brush_recovered_sample_count = 0
	brush_recovered_stroke_count = 0
	test_brush_ray_override_enabled = false
	test_brush_ray_origin = Vector3.ZERO
	test_brush_ray_direction = Vector3.FORWARD


func set_test_brush_ray_override(
	ray_origin: Vector3,
	ray_direction: Vector3,
	enabled: bool = true
) -> void:
	test_brush_ray_origin = ray_origin
	test_brush_ray_direction = ray_direction
	test_brush_ray_override_enabled = enabled


func sample_brush_ray_for_test() -> bool:
	return _sample_current_surface()


func _update_firewall_visuals(force: bool) -> void:
	# The base renderer owns all MultiMesh transforms. Temporarily withhold the
	# shared light so its legacy midpoint expression cannot index with a float,
	# then update the same light using an explicit integer midpoint below.
	var retained_light: OmniLight3D = fire_light
	fire_light = null
	super._update_firewall_visuals(force)
	fire_light = retained_light
	_update_surface_safe_fire_light()


func _update_surface_safe_fire_light() -> void:
	if fire_light == null or path_points.is_empty():
		return
	var midpoint_index: int = clampi(
		floori(float(path_points.size()) * 0.5),
		0,
		path_points.size() - 1
	)
	var midpoint_data: Dictionary = path_points[midpoint_index]
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
		* clampf(current_fade_alpha, 0.0, 1.0)
	)
	fire_light.omni_range = clampf(
		4.0 + path_length * 0.18,
		4.0,
		8.5
	)


func get_debug_data() -> Dictionary:
	var data: Dictionary = super.get_debug_data()
	data["surface_safe_renderer"] = true
	data["integer_light_midpoint"] = true
	data["focus_interrupts_drawing"] = true
	data["spell_pointer_ready"] = spell_aim_pointer != null
	data["spell_pointer_owned"] = (
		spell_aim_pointer != null and spell_aim_pointer.is_owned_by(self)
	)
	data["pointer_surface_ray"] = true
	data["camera_brush_aim"] = camera_brush_started
	data["pointer_captures_look"] = (
		spell_aim_pointer != null
		and spell_aim_pointer.captures_look_input()
	)
	data["adaptive_ray_subdivision"] = true
	data["brush_subsample_queries"] = brush_subsample_query_count
	data["brush_subdivision_passes"] = brush_subdivision_pass_count
	data["brush_recovered_samples"] = brush_recovered_sample_count
	data["brush_recovered_strokes"] = brush_recovered_stroke_count
	data["maximum_ray_subsamples"] = maximum_ray_subsamples
	data["maximum_ray_step_degrees"] = maximum_ray_step_degrees
	return data
