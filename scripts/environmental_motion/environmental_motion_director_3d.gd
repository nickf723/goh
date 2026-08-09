extends Node3D
class_name EnvironmentalMotionDirector3D

signal motion_enabled_changed(enabled: bool)
signal airflow_manager_changed(manager_name: String)

@export var profile: EnvironmentalMotionProfile
@export var channel: String = "world"
@export var enabled: bool = true
@export var debug_hotkeys_enabled: bool = false

var elapsed: float = 0.0
var targets: Dictionary = {}
var airflow_manager: Node = null
var airflow_manager_refresh_timer: float = 0.0
var last_manager_name: String = ""
var last_systemic_airflow_speed: float = 0.0
var systemic_sample_count: int = 0
var restored_target_count: int = 0


func _ready() -> void:
	add_to_group("environmental_motion_director")
	add_to_group("debuggable")
	_resolve_airflow_manager()


func _process(delta: float) -> void:
	if profile == null:
		return
	var safe_delta: float = maxf(delta, 0.0)
	elapsed += safe_delta
	airflow_manager_refresh_timer -= safe_delta
	if airflow_manager_refresh_timer <= 0.0:
		airflow_manager_refresh_timer = 0.45
		_resolve_airflow_manager()
	if not enabled:
		return
	_animate_targets(safe_delta)


func _unhandled_input(event: InputEvent) -> void:
	if not debug_hotkeys_enabled:
		return
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_F5:
		return
	set_enabled(not enabled)
	print("Environmental Motion Director: ", "ON" if enabled else "OFF")
	get_viewport().set_input_as_handled()


func set_enabled(value: bool) -> void:
	if enabled == value:
		return
	enabled = value
	if not enabled:
		_restore_all_targets()
	motion_enabled_changed.emit(enabled)


func register_target(
	target: Node3D,
	motion_kind: String,
	strength: float = 1.0,
	phase: float = 0.0,
	airflow_response: float = 1.0,
	frequency_scale: float = 1.0
) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var target_id: int = target.get_instance_id()
	targets[target_id] = {
		"ref": weakref(target),
		"kind": motion_kind.strip_edges().to_lower(),
		"strength": maxf(strength, 0.0),
		"phase": phase,
		"airflow_response": maxf(airflow_response, 0.0),
		"frequency_scale": maxf(frequency_scale, 0.05),
		"base_position": target.position,
		"base_rotation": target.rotation,
		"base_scale": target.scale,
		"cached_airflow": Vector3.ZERO,
		"next_airflow_sample": elapsed + _stagger_delay(target_id),
	}
	target.add_to_group("environmental_motion_target")
	target.set_meta("environmental_motion_kind", motion_kind)
	return true


func unregister_target(target: Node3D, restore: bool = true) -> void:
	if target == null:
		return
	var target_id: int = target.get_instance_id()
	if not targets.has(target_id):
		return
	if restore and is_instance_valid(target):
		_restore_target(target, targets[target_id] as Dictionary)
	targets.erase(target_id)


func clear_targets(restore: bool = true) -> void:
	if restore:
		_restore_all_targets()
	targets.clear()


func sample_visual_wind_at(world_position: Vector3, phase: float = 0.0) -> Vector3:
	if profile == null:
		return Vector3.ZERO
	var zone_state: Dictionary = _sample_zone_state(world_position)
	var direction: Vector3 = profile.ambient_direction
	direction.y = 0.0
	if direction.length_squared() <= 0.000001:
		direction = Vector3(1.0, 0.0, 0.0)
	direction = direction.normalized()

	var override_value: Variant = zone_state.get("direction", Vector3.ZERO)
	var influence: float = clampf(float(zone_state.get("direction_influence", 0.0)), 0.0, 1.0)
	if override_value is Vector3:
		var override_direction: Vector3 = override_value as Vector3
		override_direction.y = 0.0
		if override_direction.length_squared() > 0.000001 and influence > 0.001:
			direction = direction.lerp(override_direction.normalized(), influence).normalized()

	var wind_multiplier: float = maxf(float(zone_state.get("wind_multiplier", 1.0)), 0.0)
	var gust_multiplier: float = maxf(float(zone_state.get("gust_multiplier", 1.0)), 0.0)
	var spatial_phase: float = (
		world_position.x * 0.73
		+ world_position.y * 0.29
		+ world_position.z * 0.51
	) * profile.gust_spatial_frequency
	var gust_time: float = elapsed * TAU * profile.gust_frequency + phase + spatial_phase
	var gust_wave: float = (
		sin(gust_time)
		+ sin(gust_time * 0.47 + 1.83) * 0.42
		+ sin(gust_time * 1.91 + 4.1) * 0.16
	) / 1.58
	var gust_factor: float = maxf(
		1.0 + gust_wave * profile.gust_strength * gust_multiplier,
		0.05
	)
	var ambient: Vector3 = (
		direction
		* profile.ambient_speed
		* wind_multiplier
		* gust_factor
	)
	return _clamp_visual_wind(ambient)


func _animate_targets(delta: float) -> void:
	var invalid_ids: Array[int] = []
	var alpha: float = 1.0 - exp(-delta * profile.response_smoothing)
	for raw_id: Variant in targets.keys():
		var target_id: int = int(raw_id)
		var record: Dictionary = targets[target_id] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			invalid_ids.append(target_id)
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if not target_value is Node3D:
			invalid_ids.append(target_id)
			continue
		var target: Node3D = target_value as Node3D
		if not is_instance_valid(target) or not target.is_inside_tree():
			invalid_ids.append(target_id)
			continue

		if elapsed >= float(record.get("next_airflow_sample", 0.0)):
			record["cached_airflow"] = _sample_systemic_airflow(target.global_position)
			record["next_airflow_sample"] = elapsed + profile.airflow_resample_interval
			targets[target_id] = record

		_apply_target_motion(target, record, alpha)

	for target_id: int in invalid_ids:
		targets.erase(target_id)


func _apply_target_motion(target: Node3D, record: Dictionary, alpha: float) -> void:
	var kind: String = str(record.get("kind", "foliage"))
	var strength: float = float(record.get("strength", 1.0))
	var phase: float = float(record.get("phase", 0.0))
	var frequency_scale: float = float(record.get("frequency_scale", 1.0))
	var airflow_response: float = float(record.get("airflow_response", 1.0))
	var base_position: Vector3 = record.get("base_position", target.position)
	var base_rotation: Vector3 = record.get("base_rotation", target.rotation)
	var base_scale: Vector3 = record.get("base_scale", target.scale)
	var cached_airflow: Vector3 = record.get("cached_airflow", Vector3.ZERO)
	var ambient: Vector3 = sample_visual_wind_at(target.global_position, phase)
	var wind: Vector3 = ambient + cached_airflow * profile.systemic_airflow_scale * airflow_response
	wind = _clamp_visual_wind(wind)

	var reference_speed: float = maxf(profile.reference_wind_speed, 0.1)
	var wind_ratio: float = clampf(wind.length() / reference_speed, 0.0, 2.8)
	var direction: Vector3 = wind
	if direction.length_squared() <= 0.000001:
		direction = profile.ambient_direction
	if direction.length_squared() <= 0.000001:
		direction = Vector3.RIGHT
	direction = direction.normalized()

	var time_value: float = elapsed * profile.base_frequency * frequency_scale + phase
	var primary_wave: float = sin(time_value)
	var secondary_wave: float = sin(time_value * 2.37 + phase * 0.73)
	var target_position: Vector3 = base_position
	var target_rotation: Vector3 = base_rotation
	var target_scale: Vector3 = base_scale

	match kind:
		"canopy":
			var amplitude: float = deg_to_rad(profile.canopy_sway_degrees) * strength * wind_ratio
			var bend: float = amplitude * (0.68 + primary_wave * 0.24 + secondary_wave * 0.08)
			target_rotation.x += direction.z * bend
			target_rotation.z -= direction.x * bend
			var breathe: float = 1.0 + primary_wave * 0.0025 * strength
			target_scale = base_scale * breathe
		"vine":
			var amplitude: float = deg_to_rad(profile.vine_sway_degrees) * strength * wind_ratio
			var bend: float = amplitude * (0.48 + primary_wave * 0.39 + secondary_wave * 0.13)
			target_rotation.x += direction.z * bend
			target_rotation.z -= direction.x * bend
		"root":
			var amplitude: float = deg_to_rad(profile.root_sway_degrees) * strength * wind_ratio
			target_rotation.x += direction.z * amplitude * primary_wave
			target_rotation.z -= direction.x * amplitude * primary_wave
		"water":
			target_position.y += primary_wave * profile.water_bob_height * strength
			var pulse: float = 1.0 + secondary_wave * profile.water_scale_pulse * strength
			target_scale = Vector3(base_scale.x * pulse, base_scale.y, base_scale.z * pulse)
		"waterfall":
			var flutter: float = profile.waterfall_flutter_distance * strength * (0.45 + wind_ratio * 0.35)
			target_position.x += secondary_wave * flutter
			target_position.z += primary_wave * flutter * 0.28
			var width: float = 1.0 + primary_wave * profile.waterfall_width_pulse * strength
			target_scale = Vector3(base_scale.x * width, base_scale.y, base_scale.z)
		_:
			var amplitude: float = deg_to_rad(profile.foliage_sway_degrees) * strength * wind_ratio
			var flutter: float = deg_to_rad(profile.foliage_flutter_degrees) * strength
			var bend: float = amplitude * (0.58 + primary_wave * 0.30 + secondary_wave * 0.12)
			target_rotation.x += direction.z * bend + secondary_wave * flutter * 0.35
			target_rotation.z -= direction.x * bend + primary_wave * flutter * 0.28

	target.position = target.position.lerp(target_position, alpha)
	target.rotation = target.rotation.lerp(target_rotation, alpha)
	target.scale = target.scale.lerp(target_scale, alpha)


func _sample_systemic_airflow(world_position: Vector3) -> Vector3:
	if airflow_manager == null or not is_instance_valid(airflow_manager):
		return Vector3.ZERO
	if not airflow_manager.has_method("sample_total_airflow_fast"):
		return Vector3.ZERO
	var value: Variant = airflow_manager.call("sample_total_airflow_fast", world_position, elapsed)
	if not value is Vector3:
		return Vector3.ZERO
	var velocity: Vector3 = value as Vector3
	last_systemic_airflow_speed = velocity.length()
	systemic_sample_count += 1
	return velocity


func _resolve_airflow_manager() -> void:
	var resolved: Node = null
	if get_tree() != null:
		resolved = get_tree().get_first_node_in_group("airflow_manager")
	if resolved != null and not is_instance_valid(resolved):
		resolved = null
	airflow_manager = resolved
	var manager_name: String = airflow_manager.name if airflow_manager != null else ""
	if manager_name == last_manager_name:
		return
	last_manager_name = manager_name
	airflow_manager_changed.emit(manager_name)


func _sample_zone_state(world_position: Vector3) -> Dictionary:
	var state: Dictionary = {
		"wind_multiplier": 1.0,
		"gust_multiplier": 1.0,
		"direction": Vector3.ZERO,
		"direction_influence": 0.0,
	}
	var zones: Array[EnvironmentalMotionZone3D] = _get_zones()
	for zone: EnvironmentalMotionZone3D in zones:
		var weight: float = zone.get_blend_weight(world_position)
		if weight <= 0.0:
			continue
		state["wind_multiplier"] = lerpf(
			float(state["wind_multiplier"]),
			zone.wind_multiplier,
			weight
		)
		state["gust_multiplier"] = lerpf(
			float(state["gust_multiplier"]),
			zone.gust_multiplier,
			weight
		)
		if zone.direction_override.length_squared() > 0.000001 and zone.direction_influence > 0.001:
			state["direction"] = zone.direction_override
			state["direction_influence"] = maxf(
				float(state["direction_influence"]),
				zone.direction_influence * weight
			)
	return state


func _get_zones() -> Array[EnvironmentalMotionZone3D]:
	var zones: Array[EnvironmentalMotionZone3D] = []
	if get_tree() == null:
		return zones
	for candidate: Node in get_tree().get_nodes_in_group("environmental_motion_zone_3d"):
		if candidate is EnvironmentalMotionZone3D:
			var zone: EnvironmentalMotionZone3D = candidate as EnvironmentalMotionZone3D
			if zone.channel == channel:
				zones.append(zone)
	zones.sort_custom(Callable(self, "_sort_zones"))
	return zones


func _sort_zones(a: EnvironmentalMotionZone3D, b: EnvironmentalMotionZone3D) -> bool:
	if a.priority == b.priority:
		return str(a.get_path()) < str(b.get_path())
	return a.priority < b.priority


func _restore_all_targets() -> void:
	restored_target_count = 0
	for raw_id: Variant in targets.keys():
		var record: Dictionary = targets[int(raw_id)] as Dictionary
		var weak_value: Variant = record.get("ref", null)
		if not weak_value is WeakRef:
			continue
		var target_value: Variant = (weak_value as WeakRef).get_ref()
		if target_value is Node3D:
			_restore_target(target_value as Node3D, record)
			restored_target_count += 1


func _restore_target(target: Node3D, record: Dictionary) -> void:
	if target == null or not is_instance_valid(target):
		return
	target.position = record.get("base_position", target.position)
	target.rotation = record.get("base_rotation", target.rotation)
	target.scale = record.get("base_scale", target.scale)


func _clamp_visual_wind(wind: Vector3) -> Vector3:
	if profile == null:
		return wind
	var limit: float = maxf(profile.maximum_visual_wind_speed, 0.0)
	if limit > 0.001 and wind.length_squared() > limit * limit:
		return wind.normalized() * limit
	return wind


func _stagger_delay(target_id: int) -> float:
	if profile == null:
		return 0.0
	var interval: float = maxf(profile.airflow_resample_interval, 0.02)
	return fmod(float(abs(target_id % 97)) / 97.0 * interval, interval)


func get_target_kind_counts() -> Dictionary:
	var counts: Dictionary = {}
	for raw_id: Variant in targets.keys():
		var record: Dictionary = targets[int(raw_id)] as Dictionary
		var kind: String = str(record.get("kind", "unknown"))
		counts[kind] = int(counts.get(kind, 0)) + 1
	return counts


func get_debug_data() -> Dictionary:
	return {
		"environmental_motion_director": true,
		"profile_id": profile.profile_id if profile != null else "",
		"channel": channel,
		"enabled": enabled,
		"debug_hotkeys": debug_hotkeys_enabled,
		"target_count": targets.size(),
		"target_kinds": get_target_kind_counts(),
		"airflow_manager": airflow_manager.name if airflow_manager != null and is_instance_valid(airflow_manager) else "",
		"systemic_sample_count": systemic_sample_count,
		"last_systemic_airflow_speed": snappedf(last_systemic_airflow_speed, 0.01),
		"restored_target_count": restored_target_count,
		"visual_only_ambient_wind": true,
		"systemic_airflow_aware": true,
	}
