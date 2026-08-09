extends Node3D
class_name CameraDirector3D

signal camera_context_changed(previous_context: String, next_context: String)
signal camera_zone_state_changed(active_zones: Array[String])

@export var profile: CameraProfile
@export var channel: String = "world"
@export var target_group: String = "player"
@export var enabled: bool = true
@export var debug_hotkeys_enabled: bool = false

var target_actor: CharacterBody3D = null
var camera_pivot: Node3D = null
var spring_arm: SpringArm3D = null
var camera: Camera3D = null
var motion_feedback: Node = null

var authored_pivot_position: Vector3 = Vector3.ZERO
var authored_spring_length: float = 6.0
var authored_fov: float = 75.0
var previous_planar_velocity: Vector3 = Vector3.ZERO
var landing_impulse: float = 0.0
var current_context: String = "uninitialized"
var active_zone_ids: Array[String] = []
var initialized: bool = false
var last_zone_signature: String = ""


func _ready() -> void:
	add_to_group("camera_director")
	add_to_group("debuggable")
	call_deferred("_initialize")


func _process(delta: float) -> void:
	if not initialized or profile == null:
		return
	if not enabled:
		return
	if target_actor == null or not is_instance_valid(target_actor):
		_resolve_target_actor()
		_resolve_camera_nodes()
		if target_actor == null or camera_pivot == null or spring_arm == null or camera == null:
			return
	_update_camera(maxf(delta, 0.0))


func _unhandled_input(event: InputEvent) -> void:
	if not debug_hotkeys_enabled or not initialized:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_F6:
		return
	set_enabled(not enabled)
	print("Camera Director: ", "ON" if enabled else "OFF")
	get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	_disconnect_motion_feedback()


func _initialize() -> void:
	if profile == null:
		push_warning("CameraDirector3D has no CameraProfile.")
		return
	_resolve_target_actor()
	_resolve_camera_nodes()
	if target_actor == null or camera_pivot == null or spring_arm == null or camera == null:
		push_warning("CameraDirector3D could not resolve Grace's camera rig.")
		return
	authored_pivot_position = camera_pivot.position
	authored_spring_length = spring_arm.spring_length
	authored_fov = camera.fov
	previous_planar_velocity = _planar_velocity()
	_connect_motion_feedback()
	initialized = true
	current_context = _resolve_context()
	set_meta("camera_director_initialized", true)
	set_meta("camera_director_context", current_context)


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		_restore_authored_camera()
		active_zone_ids.clear()
		_emit_zone_signature_if_changed()


func sample_targets() -> Dictionary:
	if not initialized or profile == null or target_actor == null:
		return {}
	return _calculate_targets(1.0 / 60.0, false)


func _update_camera(delta: float) -> void:
	var targets: Dictionary = _calculate_targets(delta, true)
	if targets.is_empty():
		return
	var next_context: String = str(targets.get("context", "exploration"))
	if next_context != current_context:
		var previous: String = current_context
		current_context = next_context
		set_meta("camera_director_context", current_context)
		camera_context_changed.emit(previous, current_context)

	var distance_alpha: float = _exp_alpha(profile.distance_smoothing, delta)
	var fov_alpha: float = _exp_alpha(profile.fov_smoothing, delta)
	var pivot_alpha: float = _exp_alpha(profile.pivot_smoothing, delta)
	var target_distance: float = float(targets.get("distance", profile.base_distance))
	var target_fov: float = float(targets.get("fov", profile.base_fov))
	var target_pivot: Vector3 = targets.get("pivot", authored_pivot_position)

	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_distance, distance_alpha)
	camera.fov = lerpf(camera.fov, target_fov, fov_alpha)
	camera_pivot.position = camera_pivot.position.lerp(target_pivot, pivot_alpha)

	landing_impulse *= exp(-profile.landing_recovery_speed * delta)
	if landing_impulse < 0.002:
		landing_impulse = 0.0


func _calculate_targets(delta: float, update_history: bool) -> Dictionary:
	var planar_velocity: Vector3 = _planar_velocity()
	var planar_speed: float = planar_velocity.length()
	var speed_ratio: float = clampf(
		planar_speed / maxf(profile.reference_run_speed, 0.1),
		0.0,
		1.35
	)
	var context: String = _resolve_context()
	var distance: float = profile.base_distance + profile.speed_distance_bonus * speed_ratio
	var fov: float = profile.base_fov + profile.speed_fov_bonus * minf(speed_ratio, 1.0)
	var pivot_height: float = profile.pivot_height
	var allow_lead: bool = true

	match context:
		"aim":
			distance = profile.aim_distance
			fov = profile.aim_fov
			pivot_height = profile.aim_pivot_height
			allow_lead = false
		"lock_on":
			var target_distance: float = _get_lock_on_distance()
			var range_t: float = inverse_lerp(
				profile.lock_on_near_range,
				profile.lock_on_far_range,
				clampf(target_distance, profile.lock_on_near_range, profile.lock_on_far_range)
			)
			distance = lerpf(profile.lock_on_min_distance, profile.lock_on_max_distance, range_t)
			fov = lerpf(profile.lock_on_min_fov, profile.lock_on_max_fov, range_t)
			pivot_height = profile.lock_on_pivot_height
			allow_lead = false
		"climb":
			distance = profile.climb_distance
			fov = profile.climb_fov
			pivot_height = profile.climb_pivot_height
			allow_lead = false
		"swim":
			distance = profile.swim_distance + profile.speed_distance_bonus * speed_ratio * 0.35
			fov = profile.swim_fov + profile.speed_fov_bonus * speed_ratio * 0.25
			pivot_height = profile.swim_pivot_height
		"flight":
			distance = profile.flight_distance + profile.speed_distance_bonus * speed_ratio * 0.70
			fov = profile.flight_fov + profile.speed_fov_bonus * speed_ratio * 0.55
			pivot_height = profile.flight_pivot_height
		"dodge":
			distance = profile.dodge_distance
			fov = profile.dodge_fov
		"defeated":
			distance = profile.defeated_distance
			fov = profile.defeated_fov
			allow_lead = false
		"focus":
			allow_lead = false
		_:
			pass

	var acceleration_ratio: float = 0.0
	if delta > 0.0001:
		var acceleration: float = (planar_velocity - previous_planar_velocity).length() / delta
		acceleration_ratio = clampf(
			acceleration / maxf(profile.reference_run_speed * 3.2, 0.1),
			0.0,
			1.0
		)
	if context in ["exploration", "flight", "dodge"]:
		fov += acceleration_ratio * profile.acceleration_fov_bonus

	var vertical_ratio: float = clampf(
		target_actor.velocity.y / maxf(profile.vertical_reference_speed, 0.1),
		-1.0,
		1.0
	)
	if vertical_ratio > 0.0:
		pivot_height += vertical_ratio * profile.upward_pivot_bonus
	elif vertical_ratio < 0.0:
		pivot_height += vertical_ratio * profile.falling_pivot_drop

	distance -= landing_impulse * profile.landing_distance_compression
	pivot_height -= landing_impulse * profile.landing_pivot_drop

	var zone_state: Dictionary = _apply_camera_zones(
		target_actor.global_position,
		distance,
		fov,
		pivot_height
	)
	distance = float(zone_state.get("distance", distance))
	fov = float(zone_state.get("fov", fov))
	pivot_height = float(zone_state.get("pivot_height", pivot_height))
	var lead_scale: float = float(zone_state.get("lead_scale", 1.0))

	var target_pivot: Vector3 = authored_pivot_position
	target_pivot.y = pivot_height
	if allow_lead:
		var local_velocity: Vector3 = target_actor.global_transform.basis.inverse() * planar_velocity
		var lateral_ratio: float = clampf(
			local_velocity.x / maxf(profile.reference_run_speed, 0.1),
			-1.0,
			1.0
		)
		var forward_ratio: float = clampf(
			-local_velocity.z / maxf(profile.reference_run_speed, 0.1),
			-1.0,
			1.0
		)
		target_pivot.x += lateral_ratio * profile.lateral_lead * lead_scale
		target_pivot.z -= forward_ratio * profile.forward_lead * lead_scale

	if update_history:
		previous_planar_velocity = planar_velocity

	return {
		"context": context,
		"distance": clampf(distance, 3.6, 9.2),
		"fov": clampf(fov, 58.0, 84.0),
		"pivot": target_pivot,
		"speed_ratio": speed_ratio,
		"acceleration_ratio": acceleration_ratio,
		"landing_impulse": landing_impulse,
		"active_zones": active_zone_ids.duplicate(),
	}


func _resolve_context() -> String:
	if target_actor == null:
		return "exploration"
	if bool(target_actor.get("is_defeated")):
		return "defeated"
	if _call_bool(target_actor, "is_spell_camera_brush_active"):
		return "aim"
	if _call_bool(target_actor, "is_spell_aim_pointer_active"):
		return "aim"
	if bool(target_actor.get_meta("shared_placement_active", false)):
		return "aim"
	if _call_bool(target_actor, "has_lock_on_target"):
		return "lock_on"
	if _node_method_true("ClimbingController", "should_handle_locomotion"):
		return "climb"
	if _node_method_true("SwimmingController", "should_handle_locomotion"):
		return "swim"
	var aerial: Node = target_actor.get_node_or_null("AerialLocomotion")
	if aerial != null and bool(aerial.get("flight_active")):
		return "flight"
	var dodge_value: Variant = target_actor.get("dodge_controller")
	if typeof(dodge_value) == TYPE_OBJECT and is_instance_valid(dodge_value):
		var dodge_node: Object = dodge_value as Object
		if dodge_node.has_method("is_dodge_active") and bool(dodge_node.call("is_dodge_active")):
			return "dodge"
	if _call_bool(target_actor, "is_focus_spell_menu_open"):
		return "focus"
	return "exploration"


func _get_lock_on_distance() -> float:
	if target_actor == null:
		return profile.lock_on_near_range
	var target_value: Variant = target_actor.get("lock_on_target")
	if typeof(target_value) != TYPE_OBJECT or not is_instance_valid(target_value):
		return profile.lock_on_near_range
	if not target_value is Node3D:
		return profile.lock_on_near_range
	return target_actor.global_position.distance_to((target_value as Node3D).global_position)


func _node_method_true(node_path: String, method_name: String) -> bool:
	if target_actor == null:
		return false
	var node: Node = target_actor.get_node_or_null(node_path)
	if node == null or not node.has_method(method_name):
		return false
	return bool(node.call(method_name))


func _call_bool(object: Object, method_name: String) -> bool:
	if object == null or not object.has_method(method_name):
		return false
	return bool(object.call(method_name))


func _apply_camera_zones(
	world_position: Vector3,
	distance: float,
	fov: float,
	pivot_height: float
) -> Dictionary:
	active_zone_ids.clear()
	var resolved_distance: float = distance
	var resolved_fov: float = fov
	var resolved_pivot_height: float = pivot_height
	var lead_scale: float = 1.0
	for zone: CameraZone3D in _get_zones():
		var weight: float = zone.get_blend_weight(world_position)
		if weight <= 0.0:
			continue
		resolved_distance += zone.distance_offset * weight
		resolved_fov += zone.fov_offset * weight
		resolved_pivot_height += zone.pivot_height_offset * weight
		lead_scale *= lerpf(1.0, zone.lead_scale, weight)
		if weight >= 0.04:
			active_zone_ids.append("%s:%.2f" % [str(zone.name), weight])
	_emit_zone_signature_if_changed()
	return {
		"distance": resolved_distance,
		"fov": resolved_fov,
		"pivot_height": resolved_pivot_height,
		"lead_scale": lead_scale,
	}


func _get_zones() -> Array[CameraZone3D]:
	var zones: Array[CameraZone3D] = []
	if get_tree() == null:
		return zones
	for candidate: Node in get_tree().get_nodes_in_group("camera_zone_3d"):
		if candidate is CameraZone3D:
			var zone: CameraZone3D = candidate as CameraZone3D
			if zone.channel == channel:
				zones.append(zone)
	zones.sort_custom(Callable(self, "_sort_zones"))
	return zones


func _sort_zones(a: CameraZone3D, b: CameraZone3D) -> bool:
	if a.priority == b.priority:
		return str(a.get_path()) < str(b.get_path())
	return a.priority < b.priority


func _resolve_target_actor() -> void:
	target_actor = null
	if get_tree() == null:
		return
	var candidate: Node = get_tree().get_first_node_in_group(target_group)
	if candidate is CharacterBody3D:
		target_actor = candidate as CharacterBody3D


func _resolve_camera_nodes() -> void:
	camera_pivot = null
	spring_arm = null
	camera = null
	if target_actor == null:
		return
	camera_pivot = target_actor.get_node_or_null("CameraPivot") as Node3D
	spring_arm = target_actor.get_node_or_null("CameraPivot/SpringArm3D") as SpringArm3D
	camera = target_actor.get_node_or_null("CameraPivot/SpringArm3D/Camera3D") as Camera3D


func _connect_motion_feedback() -> void:
	_disconnect_motion_feedback()
	if target_actor == null:
		return
	motion_feedback = target_actor.get_node_or_null("PlayerMotionFeedback")
	if motion_feedback == null:
		return
	if motion_feedback.has_signal("landing_emitted"):
		var landing_callable := Callable(self, "_on_landing_emitted")
		if not motion_feedback.is_connected("landing_emitted", landing_callable):
			motion_feedback.connect("landing_emitted", landing_callable)


func _disconnect_motion_feedback() -> void:
	if motion_feedback == null or not is_instance_valid(motion_feedback):
		motion_feedback = null
		return
	if motion_feedback.has_signal("landing_emitted"):
		var landing_callable := Callable(self, "_on_landing_emitted")
		if motion_feedback.is_connected("landing_emitted", landing_callable):
			motion_feedback.disconnect("landing_emitted", landing_callable)
	motion_feedback = null


func _on_landing_emitted(strength: float) -> void:
	landing_impulse = maxf(landing_impulse, clampf(strength, 0.0, 1.0))


func _planar_velocity() -> Vector3:
	if target_actor == null:
		return Vector3.ZERO
	return Vector3(target_actor.velocity.x, 0.0, target_actor.velocity.z)


func _restore_authored_camera() -> void:
	if camera_pivot != null:
		camera_pivot.position = authored_pivot_position
	if spring_arm != null:
		spring_arm.spring_length = authored_spring_length
	if camera != null:
		camera.fov = authored_fov
	landing_impulse = 0.0
	previous_planar_velocity = _planar_velocity()


func _emit_zone_signature_if_changed() -> void:
	var signature: String = ""
	for label: String in active_zone_ids:
		if signature != "":
			signature += "|"
		signature += label
	if signature == last_zone_signature:
		return
	last_zone_signature = signature
	camera_zone_state_changed.emit(active_zone_ids.duplicate())


func _exp_alpha(rate: float, delta: float) -> float:
	return clampf(1.0 - exp(-maxf(rate, 0.01) * maxf(delta, 0.0)), 0.0, 1.0)


func get_debug_data() -> Dictionary:
	var targets: Dictionary = sample_targets() if initialized else {}
	return {
		"camera_director": true,
		"initialized": initialized,
		"enabled": enabled,
		"debug_hotkeys": debug_hotkeys_enabled,
		"channel": channel,
		"profile_id": profile.profile_id if profile != null else "",
		"context": current_context,
		"active_zones": active_zone_ids.duplicate(),
		"authored_distance": authored_spring_length,
		"authored_fov": authored_fov,
		"current_distance": spring_arm.spring_length if spring_arm != null else 0.0,
		"current_fov": camera.fov if camera != null else 0.0,
		"target_distance": float(targets.get("distance", 0.0)),
		"target_fov": float(targets.get("fov", 0.0)),
		"landing_impulse": landing_impulse,
		"non_authoritative_rotation": true,
		"owns_camera_offsets": false,
	}
